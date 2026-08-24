-- ==================================================================
-- PRESS TO JOIN -- who is playing on what.
-- ==================================================================
-- Co-op used to assign devices by guessing: pads took the lowest free
-- slot and the keyboard halves were welded to the slot index, so the
-- label on the menu ("pad 1 = Vess, pad 2 = Lu") was doing the work
-- that an interface should do.
--
-- A keyboard and two pads is FOUR devices, because the two keyboard
-- profiles are already disjoint. Any player may take any one of them.
--
-- Press order decides the bot: first to join is Vess, second is Lu.
-- That is the whole rule, and it is the one every couch game uses.
--
-- SOLO does not come through here. One person with a keyboard and a pad
-- should be able to use both without being asked to pick.
local P = require "src.assets.palette"
local Input = require "src.input"

local S = { name = "joinscreen" }

local BOTS = { { name = "VESS", col = "vessred" }, { name = "LU", col = "lublue" } }

function S:enter(prev, onReady)
  self.onReady = onReady
  self.t = 0
  self.devices = Input.availableDevices()
  self.taken = {}                  -- device index -> slot
  self.slotOf = {}                 -- slot -> device index
  self.flash = nil                 -- device index someone bumped into
  self.flashT = 0
  Input.clearClaims()
end

function S:leave() end

-- ---------------------------------------------------------------- join
function S:deviceIndex(pred)
  for i, d in ipairs(self.devices) do if pred(d) then return i end end
end

function S:claim(di)
  if self.taken[di] then
    self.flash, self.flashT = di, 0.4
    if G.Audio then G.Audio.sfx("deny") end
    return
  end
  local slot = self.slotOf[1] and 2 or 1
  if self.slotOf[slot] then return end
  local d = self.devices[di]
  if d.kind == "kb" then Input.claimKB(slot, d.prof) else Input.claimPad(slot, d.joy) end
  self.taken[di] = slot
  self.slotOf[slot] = di
  if G.Audio then G.Audio.sfx("menusel") end
end

function S:unclaim(slot)
  local di = self.slotOf[slot]
  if not di then return end
  self.taken[di] = nil
  self.slotOf[slot] = nil
  Input.claimed[slot] = nil
  Input.pads[slot] = nil
  if G.Audio then G.Audio.sfx("menuback") end
end

function S:ready() return self.slotOf[1] ~= nil and self.slotOf[2] ~= nil end

function S:start()
  if not self:ready() then return end
  -- From here a slot answers only to the device its player chose.
  Input.exclusive = true
  local cb = self.onReady
  G.State.pop()
  if cb then cb() end
end

-- ---------------------------------------------------------------- input
-- Raw, because a device that has not been claimed yet has no slot and so
-- produces no bound actions at all.
function S:raw(ev)
  if ev.kind == "rawkey" then
    if ev.id == "escape" then
      if self.slotOf[2] then self:unclaim(2)
      elseif self.slotOf[1] then self:unclaim(1)
      else G.State.pop() end
      return
    end
    if ev.id == "return" or ev.id == "space" then
      if self:ready() then self:start() end
      return
    end
    local prof = Input.profileForKey(ev.id)
    if prof then
      self:claim(self:deviceIndex(function(d) return d.kind == "kb" and d.prof == prof end))
    end
  elseif ev.kind == "rawpad" then
    if ev.id == "start" and self:ready() then self:start() return end
    if ev.id == "b" then
      for slot = 2, 1, -1 do
        local di = self.slotOf[slot]
        if di and self.devices[di].joy == ev.joy then self:unclaim(slot) return end
      end
      return
    end
    self:claim(self:deviceIndex(function(d) return d.kind == "pad" and d.joy == ev.joy end))
  end
end

function S:update(dt)
  self.t = self.t + dt
  if self.flashT > 0 then
    self.flashT = self.flashT - dt
    if self.flashT <= 0 then self.flash = nil end
  end
end

-- ---------------------------------------------------------------- draw
function S:draw()
  local g = love.graphics
  g.clear(P.black)
  if G.fonts and G.fonts.main then g.setFont(G.fonts.main) end

  g.setColor(P.ember)
  g.printf("PRESS TO JOIN", 0, 26, G.SW, "center")
  g.setColor(P.slate)
  g.printf("first to press is VESS   second is LU", 0, 40, G.SW, "center")

  -- the two seats
  for slot = 1, 2 do
    local bx = slot == 1 and 40 or G.SW / 2 + 8
    local bw = G.SW / 2 - 48
    local di = self.slotOf[slot]
    local col = P[BOTS[slot].col] or P.silver
    g.setColor(0, 0, 0, 0.5)
    g.rectangle("fill", bx, 60, bw, 46)
    g.setColor(di and col[1] or 0.3, di and col[2] or 0.3, di and col[3] or 0.35, 1)
    g.rectangle("line", bx + 0.5, 60.5, bw - 1, 45)
    g.setColor(di and col or P.slate)
    g.print(BOTS[slot].name, bx + 8, 66)
    g.setColor(di and P.cream or P.slate)
    g.printf(di and self.devices[di].label or "waiting...", bx + 8, 82, bw - 16)
  end

  -- the devices
  g.setColor(P.slate)
  g.printf("DEVICES", 0, 118, G.SW, "center")
  for i, d in ipairs(self.devices) do
    local y = 134 + (i - 1) * 20
    local slot = self.taken[i]
    local hot = self.flash == i and math.floor(self.flashT * 12) % 2 == 0
    g.setColor(0, 0, 0, 0.55)
    g.rectangle("fill", 70, y, G.SW - 140, 17)
    if hot then
      g.setColor(P.blood)
    elseif slot then
      g.setColor(P[BOTS[slot].col] or P.silver)
    else
      g.setColor(P.slate)
    end
    g.rectangle("line", 70.5, y + 0.5, G.SW - 141, 16)
    g.setColor(slot and (P[BOTS[slot].col] or P.silver) or P.cream)
    g.print(d.label, 78, y + 4)
    if slot then
      g.setColor(P[BOTS[slot].col] or P.silver)
      g.printf(BOTS[slot].name, 0, y + 4, G.SW - 78, "right")
    end
  end

  g.setColor(P.slate)
  local hint = self:ready() and "ENTER / START to begin      ESC / B to change"
    or "press any key or button on the device you want"
  g.printf(hint, 0, G.SH - 26, G.SW, "center")
  if self:ready() then
    local a = 0.55 + 0.45 * math.sin(self.t * 5)
    g.setColor(P.ember[1], P.ember[2], P.ember[3], a)
    g.printf("READY", 0, G.SH - 42, G.SW, "center")
  end
end

return S
