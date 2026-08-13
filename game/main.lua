-- EMBERDEEP — a co-op cavern story.
io.stdout:setvbuf("no")

G = {
  VW = 480, VH = 270, TILE = 16,
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
    while G.VW * scale > dw or G.VH * scale > dh do
      scale = scale - 1
      if scale <= 1 then break end
    end
    local w, h = love.graphics.getDimensions()
    if w ~= G.VW * scale or h ~= G.VH * scale then
      love.window.setMode(G.VW * scale, G.VH * scale,
        { resizable = true, vsync = s.vsync and 1 or 0, minwidth = 480, minheight = 270 })
    end
  end
  G.canvas = love.graphics.newCanvas(G.VW, G.VH)
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
  State = require "src.core.state"
  G.State = State
  G.Save = require "src.save"
  G.settings = G.Save.loadSettings()
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
    G.time = G.time + STEP
    State.update(STEP)
    if G.test then require("src.core.invariants").check() end
    if G.testStep then G.testStep() end
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
  love.graphics.setCanvas(G.canvas)
  love.graphics.clear(0.05, 0.04, 0.08, 1)
  State.draw()
  love.graphics.setCanvas()

  local ww, wh = love.graphics.getDimensions()
  local scale = math.max(1, math.floor(math.min(ww / G.VW, wh / G.VH)))
  local ox = math.floor((ww - G.VW * scale) / 2)
  local oy = math.floor((wh - G.VH * scale) / 2)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(G.canvas, ox, oy, 0, scale, scale)
end

-- ------------------------------------------------------------------
-- Event wiring
-- ------------------------------------------------------------------
function love.gamepadpressed(joy, button) Input.gamepadpressed(joy, button) end
function love.gamepadreleased(joy, button) Input.gamepadreleased(joy, button) end

function love.joystickadded(joy)
  local slot = Input.addJoystick(joy)
  State.event("joystick", "added", joy, slot)
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
