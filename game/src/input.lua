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

-- ------------------------------------------------------------------
-- KEYBOARD AND A PAD, AT THE SAME TIME
-- ------------------------------------------------------------------
-- actionValue already reads a slot's pad bindings AND its keyboard
-- bindings every frame and takes the max, and the two slots have
-- separate keyboard sets (slot 1 is WASD, slot 2 is the arrows). So one
-- person on the keyboard and one on a pad has always been possible.
--
-- What was NOT possible is having it land on the right players. This
-- assigned every new pad to the lowest free slot, so a single Bluetooth
-- controller always took SLOT 1 -- the seat the keyboard player was
-- already sitting in. Both inputs then drove player one, and the pad
-- player was left on player two's arrow keys.
--
-- So a pad now avoids a slot somebody is actively typing in.
-- Input.kbUsed[slot] is the timestamp of the last keypress bound to
-- that slot; a slot touched within KB_CLAIM seconds is treated as taken
-- by a human, and the pad goes elsewhere.
Input.kbUsed = { 0, 0 }

-- ------------------------------------------------------------------
-- FOUR DEVICES, NOT THREE
-- ------------------------------------------------------------------
-- A keyboard and two pads is not three input devices, it is FOUR: the
-- two keyboard profiles (WASD+JKL and arrows+numpad) are already
-- disjoint sets, so two people can share one keyboard.
--
-- Which profile a slot reads used to be the slot's own index, welded
-- shut. `Input.kbSet` breaks that: slot 1 may read profile 2 and vice
-- versa, so either player can take either half of the keyboard.
--
-- It is an INDIRECTION and not a swap of the tables, deliberately:
-- Input.bindings is what gets persisted into settings, and a device
-- choice made for one session must not rewrite the player's saved
-- key map.
Input.kbSet = { 1, 2 }

-- What each slot has explicitly claimed on the join screen: "kb", "pad"
-- or nil for "not chosen, read anything".
Input.claimed = { nil, nil }

-- Solo reads every device at once, which is a convenience. Co-op does
-- not: once two people have chosen their tools, a slot must answer to
-- its own device only, or one player's keyboard drives the other's bot.
Input.exclusive = false

function Input.kbBindings(slot)
  local prof = Input.kbSet[slot] or slot
  return Input.bindings[prof] and Input.bindings[prof].kb or {}
end

function Input.clearClaims()
  Input.claimed = { nil, nil }
  Input.kbSet = { 1, 2 }
  Input.exclusive = false
end

function Input.claimKB(slot, prof)
  local other = slot == 1 and 2 or 1
  if Input.kbSet[other] == prof then Input.kbSet[other] = Input.kbSet[slot] end
  Input.kbSet[slot] = prof
  Input.claimed[slot] = "kb"
  Input.pads[slot] = nil
end

function Input.claimPad(slot, joy)
  for s = 1, 2 do
    if Input.pads[s] == joy then Input.pads[s] = nil end
  end
  Input.pads[slot] = joy
  Input.claimed[slot] = "pad"
end

-- Everything a player could choose on the join screen.
function Input.availableDevices()
  local out = {
    { kind = "kb", prof = 1, label = "KEYBOARD  WASD" },
    { kind = "kb", prof = 2, label = "KEYBOARD  ARROWS" },
  }
  local seen = {}
  for _, joy in ipairs(love.joystick.getJoysticks()) do
    if joy:isGamepad() and not seen[joy] then
      seen[joy] = true
      out[#out + 1] = { kind = "pad", joy = joy, label = joy:getName() }
    end
  end
  return out
end
Input.KB_CLAIM = 20         -- seconds a keyboard press holds a seat

-- Pads that connected but that SDL has no gamepad mapping for. They used
-- to be dropped on the floor in silence, which is indistinguishable from
-- a flat battery. Kept here so the game can say so.
Input.unmapped = {}

local function padSlotFor()
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
  local free = {}
  for slot = 1, 2 do
    if Input.pads[slot] == nil then free[#free + 1] = slot end
  end
  if #free == 0 then return nil end
  -- prefer a free slot nobody is typing in; among those, the lowest
  for _, slot in ipairs(free) do
    if now - (Input.kbUsed[slot] or 0) > Input.KB_CLAIM then return slot end
  end
  -- every free slot is keyboard-active: take the one used longest ago
  local best = free[1]
  for _, slot in ipairs(free) do
    if (Input.kbUsed[slot] or 0) < (Input.kbUsed[best] or 0) then best = slot end
  end
  return best
end

function Input.addJoystick(joy)
  if not joy:isGamepad() then
    -- No SDL mapping. Keep it and let the caller tell the player, rather
    -- than failing silently -- "my controller does nothing" is the least
    -- debuggable bug report there is.
    Input.unmapped[#Input.unmapped + 1] = joy
    return nil, "unmapped"
  end
  local slot = padSlotFor()
  if not slot then return nil, "full" end
  Input.pads[slot] = joy
  return slot
end

-- Move the pads between slots. The assignment above is a good guess and
-- a guess is not a promise, so there has to be a way to correct it
-- without unpairing a controller.
function Input.swapPads()
  Input.pads[1], Input.pads[2] = Input.pads[2], Input.pads[1]
  return Input.pads[1], Input.pads[2]
end

-- Which device is actually driving a slot right now.
function Input.deviceFor(slot)
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
  local pad = Input.pads[slot] ~= nil
  local kb = now - (Input.kbUsed[slot] or 0) <= Input.KB_CLAIM
  if pad and kb then return "both" end
  if pad then return "pad" end
  if kb then return "kb" end
  return "none"
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

-- Which keyboard profile owns this key, or nil. The join screen needs it
-- to turn a keypress into "that player wants the WASD half".
--
-- DECLARED HERE, not up with the other kb helpers: bindingMatchesKey is
-- a file local, and a Lua local does not exist above its own
-- declaration. Calling it earlier compiles perfectly well and then
-- resolves to a nil global at runtime -- which luac -p cannot see.
function Input.profileForKey(key)
  for prof = 1, 2 do
    for _, action in ipairs(Input.ACTIONS) do
      if bindingMatchesKey(Input.bindings[prof].kb[action] or {}, key) then
        return prof
      end
    end
  end
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
      if bindingMatchesKey(Input.kbBindings(slot)[action] or {}, key) then
        Input.queue[#Input.queue + 1] = { kind = "pressed", player = slot, action = action }
        -- this seat has a human in it; a pad connecting later goes
        -- somewhere else. See padSlotFor.
        Input.kbUsed[slot] = (love and love.timer and love.timer.getTime
          and love.timer.getTime()) or 0
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
      if bindingMatchesKey(Input.kbBindings(slot)[action] or {}, key) then
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
  -- In exclusive mode a slot answers ONLY to what it claimed. Solo stays
  -- permissive: one person, every device, which is a convenience with
  -- nobody to take it away from.
  local want = Input.exclusive and Input.claimed[slot] or nil
  if want ~= "kb" then
    for _, b in ipairs(pb.pad[action] or {}) do
      if b.type ~= "key" then
        local v = readBinding(slot, b)
        if v > best then best = v end
      end
    end
  end
  if want ~= "pad" then
    for _, b in ipairs(Input.kbBindings(slot)[action] or {}) do
      local v = readBinding(slot, b)
      if v > best then best = v end
    end
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
