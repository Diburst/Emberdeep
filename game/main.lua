-- EMBERDEEP — a co-op cavern story.
io.stdout:setvbuf("no")

G = {
  -- ----------------------------------------------------------------
  -- TWO VIEWPORTS THAT HAPPEN TO BE THE SAME SIZE.
  --
  -- VW/VH is WORLD space: how much of a room is on screen, in world
  -- units. It is a DESIGN quantity and not a rendering one -- Cam.clamp
  -- is roomH - VH, checksight.py re-derives that clamp to prove every
  -- boss is visible, and about a hundred aggro radii, light radii and
  -- speeds are written in these units. Change it and all ten boss
  -- fights are reframed, and nothing in the test suite would notice,
  -- because the scenarios assert on state and not on pixels.
  --
  -- SW/SH is SCREEN space: the logical canvas the HUD, menus, dialogue
  -- and every full-screen wash are laid out in.
  --
  -- They answer different questions. "Where does the health bar go" is
  -- not "how much of the room can you see", and the only reason one
  -- name served both for so long is that the two numbers agree. They
  -- are separated here so that the render scale in G.RS can grow the
  -- canvas without touching a single tuning constant.
  --
  -- If you are adding a G.VW or a G.VH: does it move with the camera?
  -- Then it is world. Does it sit still while the player walks? Then it
  -- is SW/SH.
  -- ----------------------------------------------------------------
  VW = 480, VH = 270,
  SW = 480, SH = 270,
  -- RENDER SCALE: canvas pixels per logical unit. Set for real in
  -- applyVideo(); this default exists so anything that reads G.RS before
  -- the settings load gets 1 rather than nil.
  RS = 1,
  TILE = 16,
  DEBUG = false,
  time = 0,
}

local State, Input

local function applyVideo()
  local s = G.settings
  if s.fullscreen then
    love.window.setFullscreen(true, "desktop")
  else
    love.window.setFullscreen(false)
    local scale = s.windowscale or 2
    local dw, dh = love.window.getDesktopDimensions()
    while G.SW * scale > dw or G.SH * scale > dh do
      scale = scale - 1
      if scale <= 1 then break end
    end
    local w, h = love.graphics.getDimensions()
    if w ~= G.SW * scale or h ~= G.SH * scale then
      love.window.setMode(G.SW * scale, G.SH * scale,
        { resizable = true, vsync = s.vsync and 1 or 0, minwidth = 480, minheight = 270 })
    end
  end
  -- THE RENDER SCALE.
  --
  -- The canvas is RS times the logical screen on each axis, and every
  -- draw call still works in logical units because love.draw pushes one
  -- scale(G.RS) over the whole frame. 480x270 x 4 = 1920x1080 exactly, so
  -- the scaling is integer and nothing lands on a half pixel.
  --
  -- This is NOT a wider lens. G.VW/G.VH -- how much of a room you can see
  -- -- do not move, and must not: the camera clamp, checksight.py and
  -- about a hundred world-pixel constants all encode them.
  G.RS = math.max(1, math.floor(tonumber(os.getenv("EMBERDEEP_RS"))
    or s.renderscale or 1))
  G.canvas = love.graphics.newCanvas(G.SW * G.RS, G.SH * G.RS)
  -- At RS=1 the canvas is blitted at a whole-number scale and nearest is
  -- the only correct filter. Above 1 it is usually being brought DOWN to
  -- the window, where nearest aliases and linear is a resolve, not a blur.
  local f = G.RS > 1 and "linear" or "nearest"
  G.canvas:setFilter(f, f)
end
G.applyVideo = applyVideo

local function makeIcon()
  -- little ember-orange robot face icon
  local d = love.image.newImageData(32, 32)
  local P = require "src.assets.palette"
  local function px(x, y, c)
    if x >= 0 and x < 32 and y >= 0 and y < 32 then
      d:setPixel(x, y, c[1], c[2], c[3], 1)
    end
  end
  for y = 0, 31 do for x = 0, 31 do px(x, y, P.dark) end end
  for y = 4, 27 do for x = 4, 27 do px(x, y, P.vessred) end end
  for y = 6, 25 do for x = 6, 25 do px(x, y, P.ember) end end
  for y = 12, 18 do for x = 9, 13 do px(x, y, P.dark) end end
  for y = 12, 18 do for x = 18, 22 do px(x, y, P.dark) end end
  for y = 13, 15 do for x = 10, 12 do px(x, y, P.spark) end end
  for y = 13, 15 do for x = 19, 21 do px(x, y, P.spark) end end
  for x = 12, 19 do px(x, 22, P.dark) px(x, 23, P.dark) end
  pcall(function() love.window.setIcon(d) end)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest", 1)
  love.keyboard.setKeyRepeat(false)
  math.randomseed(os.time())

  G.test = os.getenv("EMBERDEEP_TEST")
  -- Screenshot-regression mode. See src/shots.lua -- it takes over from
  -- the loading state once the procedural assets are built, and it drives
  -- itself from love.update/love.draw WITHOUT ever stepping the world.
  G.shots = os.getenv("EMBERDEEP_SHOTS")
  State = require "src.core.state"
  G.State = State
  G.Save = require "src.save"
  G.settings = G.Save.loadSettings()
  -- Lighting override, so the two models can be put side by side without
  -- editing a save file: EMBERDEEP_LIGHTING=buffer love .
  -- Remember what each override displaced, so Save.saveSettings can put
  -- it back and a debugging flag never becomes permanent state.
  G.settingsEnv = {}
  local lt = os.getenv("EMBERDEEP_LIGHTING")
  if lt then
    G.settingsEnv.lighting = G.settings.lighting
    G.settings.lighting = lt
  end
  local gl = tonumber(os.getenv("EMBERDEEP_GLOW") or "")
  if gl then
    G.settingsEnv.glow = G.settings.glow
    G.settings.glow = gl
  end
  local ed = tonumber(os.getenv("EMBERDEEP_EDGES") or "")
  if ed then
    G.settingsEnv.edges = G.settings.edges
    G.settings.edges = ed
  end
  local st = tonumber(os.getenv("EMBERDEEP_STRATA") or "")
  if st then
    G.settingsEnv.strata = G.settings.strata
    G.settings.strata = st
  end
  local py = tonumber(os.getenv("EMBERDEEP_PARALLAX_Y") or "")
  if py then
    G.settingsEnv.parallaxY = G.settings.parallaxY
    G.settings.parallaxY = py
  end
  Input = require "src.input"
  G.Input = Input
  Input.init(G.settings.bindings)
  G.settings.bindings = Input.bindings

  applyVideo()
  makeIcon()

  State.push(require "src.states.loading")
end

-- ------------------------------------------------------------------
-- Adaptive input labels: pad names when a pad is present, key names
-- otherwise. Used by every hint, menu, and dialogue line.
-- ------------------------------------------------------------------
function G.anyPad()
  return Input.pads[1] ~= nil or Input.pads[2] ~= nil
end

function G.btn(slot, action)
  slot = slot or 1
  local dev = Input.pads[slot] and "pad" or "kb"
  return Input.bindingLabel(slot, dev, action)
end

-- Replaces [ACTION] tokens (P1) and [ACTION2] tokens (P2) in UI text.
local TOKEN_ACTIONS = { "JUMP", "FIRE", "SPECIAL", "UTIL", "INTERACT",
  "PARTNER", "WARP", "PAUSE", "MAP", "UP", "DOWN" }
function G.fmtButtons(text)
  if not text or not text:find("%[") then return text end
  for _, A in ipairs(TOKEN_ACTIONS) do
    local action = A:lower()
    text = text:gsub("%[" .. A .. "2%]", G.btn(2, action))
    text = text:gsub("%[" .. A .. "%]", G.btn(1, action))
  end
  text = text:gsub("%[MOVE%]", Input.pads[1] and "LEFT STICK / D-PAD"
    or "A/D (WASD)")
  text = text:gsub("%[MOVE2%]", Input.pads[2] and "LEFT STICK / D-PAD"
    or "ARROW KEYS")
  text = text:gsub("%[CONFIRM%]", G.anyPad() and "A" or "ENTER")
  text = text:gsub("%[CANCEL%]", G.anyPad() and "B" or "ESC")
  text = text:gsub("%[ALT%]", G.anyPad() and "X" or "X KEY")
  text = text:gsub("%[START%]", G.anyPad() and "START" or "ENTER")
  return text
end

-- ------------------------------------------------------------------
-- Fixed timestep
-- ------------------------------------------------------------------
local STEP = 1 / 60
local acc = 0

function love.update(dt)
  dt = math.min(dt, 0.1)
  acc = acc + dt

  Input.poll()
  local presses, raws, menus = Input.drain()
  for _, ev in ipairs(raws) do State.event("raw", ev) end
  for _, ev in ipairs(menus) do State.event("menu", ev.action, ev) end
  for _, ev in ipairs(presses) do State.event("pressed", ev.player, ev.action) end

  local steps = 0
  while acc >= STEP and steps < 4 do
    if G.shotsActive then
      -- The shot harness REPLACES the update rather than passing dt = 0:
      -- ambient particles are spawned from World:update, so a single tick
      -- makes every run differ and the pixel diff becomes noise.
      require("src.shots").update()
    else
      G.time = G.time + STEP
      State.update(STEP)
      if G.test then require("src.core.invariants").check() end
      if G.testStep then G.testStep() end
    end
    steps = steps + 1
    acc = acc - STEP
    if steps == 1 then
      for slot = 1, 2 do
        Input.players[slot].pressed = {}
        Input.players[slot].released = {}
      end
    end
  end
  if acc >= STEP then acc = 0 end
  G.lastFrameSteps = steps

  if G.Audio then G.Audio.update(dt) end
  if G.testUpdate then G.testUpdate(dt) end
end

function love.draw()
  if G.shotsActive then require("src.shots").preDraw() end
  love.graphics.setCanvas(G.canvas)
  love.graphics.clear(0.05, 0.04, 0.08, 1)
  love.graphics.push()
  love.graphics.scale(G.RS)
  State.draw()
  love.graphics.pop()
  love.graphics.setCanvas()
  -- Capture happens HERE, off the canvas itself, and not from
  -- love.graphics.captureScreenshot -- that grabs the window, letterbox
  -- bars included, and the bars move with the window size.
  if G.shotsActive then require("src.shots").postDraw() end

  local ww, wh = love.graphics.getDimensions()
  local cw, ch = G.canvas:getDimensions()
  -- Whole-number scaling ONLY at RS=1, where the canvas is literal pixel
  -- art and a fractional blowup would shimmer. Above 1 the canvas is dense
  -- enough, and linear-filtered, that the exact ratio beats a truncated
  -- one: flooring 1.33 to 1 on a 1440p screen would letterbox HARDER at
  -- RS=4 than at RS=1, which is the exact opposite of the point.
  local scale = math.min(ww / cw, wh / ch)
  if G.RS == 1 and scale >= 1 then scale = math.floor(scale) end
  local ox = math.floor((ww - cw * scale) / 2)
  local oy = math.floor((wh - ch * scale) / 2)
  -- Published so anything that has to invert the blit -- the room editor's
  -- mouse-to-tile mapping is the only caller today -- reads the SAME
  -- numbers the frame was actually drawn with, rather than recomputing
  -- them and drifting the moment this rule changes again.
  G.blitScale, G.blitOX, G.blitOY = scale, ox, oy
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(G.canvas, ox, oy, 0, scale, scale)
end

-- ------------------------------------------------------------------
-- Event wiring
-- ------------------------------------------------------------------
function love.gamepadpressed(joy, button) Input.gamepadpressed(joy, button) end
function love.gamepadreleased(joy, button) Input.gamepadreleased(joy, button) end

function love.joystickadded(joy)
  -- addJoystick returns nil plus a reason when it could not seat the pad.
  -- "unmapped" is the one that matters: SDL has no gamepad mapping for
  -- this controller, so LOVE reports no buttons by name and the pad does
  -- nothing. That used to happen in complete silence, which is
  -- indistinguishable from a flat battery.
  local slot, why = Input.addJoystick(joy)
  State.event("joystick", "added", joy, slot, why)
end

function love.joystickremoved(joy)
  Input.removeJoystick(joy)
  State.event("joystick", "removed", joy)
end

function love.keypressed(key)
  if key == "f11" then
    G.settings.fullscreen = not G.settings.fullscreen
    applyVideo()
    G.Save.saveSettings()
    return
  end
  if key == "f12" then
    love.graphics.captureScreenshot("screenshot-" .. os.time() .. ".png")
    return
  end
  Input.keypressed(key)
  State.event("keypressed", key)
end

function love.keyreleased(key) Input.keyreleased(key) end
function love.textinput(t) State.event("textinput", t) end

-- Mouse goes straight to the state stack, unbound and unqueued: it is a
-- TOOL input, not a game input. No state below the editor implements
-- these, so routing them costs nothing when the editor is not open.
function love.mousepressed(x, y, b) State.event("mousepressed", x, y, b) end
function love.mousereleased(x, y, b) State.event("mousereleased", x, y, b) end
function love.mousemoved(x, y, dx, dy) State.event("mousemoved", x, y, dx, dy) end
function love.wheelmoved(x, y) State.event("wheelmoved", x, y) end

function love.resize()
end

function love.focus(focused)
  State.event("focus", focused)
end

function love.quit()
  State.event("quitting")
end

-- ------------------------------------------------------------------
-- Crash handler: log to save dir, show friendly screen
-- ------------------------------------------------------------------
function love.errorhandler(msg)
  msg = tostring(msg)
  local trace = debug.traceback(msg, 3)
  pcall(function()
    love.filesystem.write("crash.log", os.date() .. "\n" .. trace)
  end)
  pcall(function()
    local f = io.open("/tmp/emberdeep_crash.log", "w")
    if f then f:write(trace) f:close() end
  end)
  if os.getenv("EMBERDEEP_TEST") then
    print("CRASH: " .. trace)
    return function() return 1 end
  end

  -- Friendly in-window error screen
  pcall(function()
    love.graphics.reset()
    love.graphics.setCanvas()
    love.graphics.origin()
  end)
  local font = love.graphics.newFont(14)
  return function()
    love.event.pump()
    for e, a in love.event.poll() do
      if e == "quit" or e == "keypressed" or e == "gamepadpressed" then
        return 1
      end
    end
    love.graphics.clear(0.08, 0.05, 0.1)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 0.7, 0.4)
    love.graphics.print("EMBERDEEP hit a snag and had to stop.", 40, 40)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Your progress up to the last save/checkpoint is safe.", 40, 70)
    love.graphics.print("A crash.log file was written next to your save files.", 40, 90)
    love.graphics.print("Press any key to close.", 40, 120)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf(msg, 40, 160, love.graphics.getWidth() - 80)
    love.graphics.present()
    love.timer.sleep(0.05)
  end
end
