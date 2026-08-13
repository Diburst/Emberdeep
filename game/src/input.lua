-- Input system: two players, gamepad (Xbox layout) + keyboard fallback,
-- rebindable, with fixed menu navigation from any device.
--
-- Actions: left,right,up,down,jump,fire,special,util,interact,partner,warp,
--          pause,map
--   special = Vess dash / Lu dome toggle
--   util    = Vess weapon switch / Lu repair pulse
--   partner = co-op: link shot; solo: swap bots (hold = recall)
--   warp    = co-op: hold to warp to partner
local U = require "src.core.util"

local Input = {}

Input.ACTIONS = { "left", "right", "up", "down", "jump", "fire", "special",
  "util", "interact", "partner", "warp", "pause", "map" }

Input.ACTION_LABELS = {
  left = "Move Left", right = "Move Right", up = "Aim Up", down = "Aim Down / Drop",
  jump = "Jump", fire = "Fire", special = "Dash / Shield Dome",
  util = "Weapon Swap / Repair", interact = "Interact / Revive",
  partner = "Link / Swap Bot", warp = "Warp to Partner (hold)",
  pause = "Pause", map = "Map",
}

local DEADZONE = 0.35
local TRIGGER_ON = 0.5

function Input.defaultBindings()
  local pad = {
    left  = { { type = "axis", id = "leftx", dir = -1 }, { type = "button", id = "dpleft" } },
    right = { { type = "axis", id = "leftx", dir = 1 }, { type = "button", id = "dpright" } },
    up    = { { type = "axis", id = "lefty", dir = -1 }, { type = "button", id = "dpup" } },
    down  = { { type = "axis", id = "lefty", dir = 1 }, { type = "button", id = "dpdown" } },
    jump  = { { type = "button", id = "a" } },
    fire  = { { type = "button", id = "x" }, { type = "axis", id = "triggerright", dir = 1 } },
    special  = { { type = "button", id = "b" } },
    util     = { { type = "button", id = "rightshoulder" } },
    interact = { { type = "button", id = "y" } },
    partner  = { { type = "button", id = "leftshoulder" } },
    warp     = { { type = "axis", id = "triggerleft", dir = 1 } },
    pause    = { { type = "button", id = "start" } },
    map      = { { type = "button", id = "back" } },
  }
  local kb1 = {
    left = { { type = "key", id = "a" } }, right = { { type = "key", id = "d" } },
    up = { { type = "key", id = "w" } }, down = { { type = "key", id = "s" } },
    jump = { { type = "key", id = "k" }, { type = "key", id = "space" } },
    fire = { { type = "key", id = "j" } },
    special = { { type = "key", id = "l" } },
    util = { { type = "key", id = "u" } },
    interact = { { type = "key", id = "i" } },
    partner = { { type = "key", id = "o" } },
    warp = { { type = "key", id = "p" } },
    pause = { { type = "key", id = "escape" } },
    map = { { type = "key", id = "tab" } },
  }
  local kb2 = {
    left = { { type = "key", id = "left" } }, right = { { type = "key", id = "right" } },
    up = { { type = "key", id = "up" } }, down = { { type = "key", id = "down" } },
    jump = { { type = "key", id = "kp2" }, { type = "key", id = "rshift" } },
    fire = { { type = "key", id = "kp1" }, { type = "key", id = "rctrl" } },
    special = { { type = "key", id = "kp3" } },
    util = { { type = "key", id = "kp5" } },
    interact = { { type = "key", id = "kp4" } },
    partner = { { type = "key", id = "kp6" } },
    warp = { { type = "key", id = "kp8" } },
    pause = { { type = "key", id = "kp9" } },
    map = { { type = "key", id = "kp7" } },
  }
  return {
    { pad = U.copy(pad), kb = kb1 },
    { pad = U.copy(pad), kb = kb2 },
  }
end

Input.bindings = Input.defaultBindings()
Input.pads = { nil, nil } -- joystick objects assigned to player slots
Input.players = {}
Input.queue = {}          -- raw event queue drained each frame
Input.menuQueue = {}      -- fixed-navigation events
Input.virtual = { {}, {} } -- test harness injected action states

local function newPlayerState()
  return { down = {}, pressed = {}, released = {}, axisHeld = {}, moveX = 0, moveY = 0 }
end

function Input.init(savedBindings)
  if savedBindings then Input.bindings = savedBindings end
  Input.players[1] = newPlayerState()
  Input.players[2] = newPlayerState()
  for _, joy in ipairs(love.joystick.getJoysticks()) do
    Input.addJoystick(joy)
  end
end

function Input.addJoystick(joy)
  if not joy:isGamepad() then return end
  for slot = 1, 2 do
    if Input.pads[slot] == nil then
      Input.pads[slot] = joy
      return slot
    end
  end
end

function Input.removeJoystick(joy)
  for slot = 1, 2 do
    if Input.pads[slot] == joy then Input.pads[slot] = nil end
  end
end

function Input.padForPlayer(p) return Input.pads[p] end

-- Which joystick fired an event -> which player slot (nil if unassigned)
local function slotOf(joy)
  for slot = 1, 2 do
    if Input.pads[slot] == joy then return slot end
  end
  return nil
end

local function bindingMatchesButton(binds, button)
  for _, b in ipairs(binds) do
    if b.type == "button" and b.id == button then return true end
  end
  return false
end

local function bindingMatchesKey(binds, key)
  for _, b in ipairs(binds) do
    if b.type == "key" and b.id == key then return true end
  end
  return false
end

-- ------------------------------------------------------------------
-- Raw LÖVE callbacks (wired from main.lua)
-- ------------------------------------------------------------------
function Input.gamepadpressed(joy, button)
  local slot = slotOf(joy)
  Input.queue[#Input.queue + 1] = { kind = "rawpad", joy = joy, slot = slot, id = button }
  if slot then
    for _, action in ipairs(Input.ACTIONS) do
      if bindingMatchesButton(Input.bindings[slot].pad[action] or {}, button) then
        Input.queue[#Input.queue + 1] = { kind = "pressed", player = slot, action = action }
      end
    end
  end
  -- fixed menu navigation from any pad
  local menuMap = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
    a = "confirm", b = "cancel", x = "alt", y = "alt2", start = "start", back = "backbtn" }
  if menuMap[button] then
    Input.menuQueue[#Input.menuQueue + 1] = { action = menuMap[button], slot = slot, joy = joy }
  end
end

function Input.gamepadreleased(joy, button)
  local slot = slotOf(joy)
  if slot then
    for _, action in ipairs(Input.ACTIONS) do
      if bindingMatchesButton(Input.bindings[slot].pad[action] or {}, button) then
        Input.queue[#Input.queue + 1] = { kind = "released", player = slot, action = action }
      end
    end
  end
end

function Input.keypressed(key)
  Input.queue[#Input.queue + 1] = { kind = "rawkey", id = key }
  for slot = 1, 2 do
    for _, action in ipairs(Input.ACTIONS) do
      if bindingMatchesKey(Input.bindings[slot].kb[action] or {}, key) then
        Input.queue[#Input.queue + 1] = { kind = "pressed", player = slot, action = action }
      end
    end
  end
  local menuMap = { up = "up", down = "down", left = "left", right = "right",
    ["return"] = "confirm", space = "confirm", escape = "cancel",
    backspace = "cancel", tab = "backbtn" }
  -- WASD menu nav too
  local wasd = { w = "up", s = "down", a = "left", d = "right", k = "confirm", j = "cancel", x = "alt" }
  local m = menuMap[key] or wasd[key]
  if m then
    Input.menuQueue[#Input.menuQueue + 1] = { action = m, slot = nil, key = key }
  end
end

function Input.keyreleased(key)
  for slot = 1, 2 do
    for _, action in ipairs(Input.ACTIONS) do
      if bindingMatchesKey(Input.bindings[slot].kb[action] or {}, key) then
        Input.queue[#Input.queue + 1] = { kind = "released", player = slot, action = action }
      end
    end
  end
end

-- ------------------------------------------------------------------
-- Per-frame polling: held state + analog + axis edge detection
-- ------------------------------------------------------------------
local function readBinding(slot, b)
  if b.type == "key" then
    return love.keyboard.isDown(b.id) and 1 or 0
  end
  local joy = Input.pads[slot]
  if not joy then return 0 end
  if b.type == "button" then
    return joy:isGamepadDown(b.id) and 1 or 0
  elseif b.type == "axis" then
    local v = joy:getGamepadAxis(b.id) * (b.dir or 1)
    if b.id:match("trigger") then
      return v > TRIGGER_ON and 1 or 0
    end
    return v > DEADZONE and v or 0
  end
  return 0
end

function Input.actionValue(slot, action)
  local pb = Input.bindings[slot]
  local best = 0
  for _, b in ipairs(pb.pad[action] or {}) do
    if b.type ~= "key" then
      local v = readBinding(slot, b)
      if v > best then best = v end
    end
  end
  for _, b in ipairs(pb.kb[action] or {}) do
    local v = readBinding(slot, b)
    if v > best then best = v end
  end
  -- test harness virtual input
  local virt = Input.virtual[slot][action]
  if virt then best = 1 end
  return best
end

-- Called once per frame before dispatching queued events.
function Input.poll()
  for slot = 1, 2 do
    local ps = Input.players[slot]
    -- NOTE: pressed/released are NOT wiped here; they persist until a
    -- physics step consumes them (main.lua clears after the first step).
    -- This keeps taps from being lost on frames that run zero steps.
    for _, action in ipairs(Input.ACTIONS) do
      local v = Input.actionValue(slot, action)
      local was = ps.down[action]
      local now = v > 0
      ps.down[action] = now
      -- axis-driven edges (buttons/keys already produce queue events, but
      -- duplicates are fine because we collapse into pressed[] set)
      if now and not was then ps.pressed[action] = true end
      if was and not now then ps.released[action] = true end
    end
    ps.moveX = Input.actionValue(slot, "right") - Input.actionValue(slot, "left")
    ps.moveY = Input.actionValue(slot, "down") - Input.actionValue(slot, "up")
  end
end

-- Drain event queue, returning list of {player, action} presses for the frame.
function Input.drain()
  local presses, raws = {}, {}
  for _, ev in ipairs(Input.queue) do
    if ev.kind == "pressed" then
      presses[#presses + 1] = ev
    elseif ev.kind == "rawpad" or ev.kind == "rawkey" then
      raws[#raws + 1] = ev
    end
  end
  Input.queue = {}
  local menus = Input.menuQueue
  Input.menuQueue = {}
  return presses, raws, menus
end

function Input.down(player, action)
  return Input.players[player].down[action] or false
end

function Input.pressed(player, action)
  return Input.players[player].pressed[action] or false
end

function Input.moveX(player) return Input.players[player].moveX end
function Input.moveY(player) return Input.players[player].moveY end

function Input.rumble(player, strength, duration)
  if not (G and G.settings and G.settings.rumble) then return end
  local joy = Input.pads[player]
  if joy and joy.setVibration then
    pcall(function() joy:setVibration(strength, strength, duration) end)
  end
end

-- ------------------------------------------------------------------
-- Rebinding support
-- ------------------------------------------------------------------
-- Assign a new primary binding (replaces the first entry, keeps alternates).
function Input.rebind(slot, device, action, binding)
  local tbl = Input.bindings[slot][device]
  tbl[action] = tbl[action] or {}
  tbl[action][1] = binding
end

function Input.bindingLabel(slot, device, action)
  local tbl = Input.bindings[slot][device][action]
  if not tbl or not tbl[1] then return "---" end
  local b = tbl[1]
  if b.type == "key" then return b.id:upper() end
  if b.type == "button" then
    local names = { a = "A", b = "B", x = "X", y = "Y", back = "BACK", start = "START",
      leftshoulder = "LB", rightshoulder = "RB", leftstick = "LS", rightstick = "RS",
      dpup = "D-UP", dpdown = "D-DOWN", dpleft = "D-LEFT", dpright = "D-RIGHT",
      guide = "GUIDE" }
    return names[b.id] or b.id:upper()
  end
  if b.type == "axis" then
    local names = { leftx = "L-STICK X", lefty = "L-STICK Y", rightx = "R-STICK X",
      righty = "R-STICK Y", triggerleft = "LT", triggerright = "RT" }
    local n = names[b.id] or b.id:upper()
    if not b.id:match("trigger") then
      n = n .. ((b.dir or 1) > 0 and "+" or "-")
    end
    return n
  end
  return "?"
end

return Input
