-- Interactive props: save points, checkpoints, teleporters, chests,
-- signs, grapple anchors, energize machines, pressure plates, platforms,
-- boss triggers.
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"

local T = 16

-- ------------------------------------------------------------------
-- Save statue
-- ------------------------------------------------------------------
local SavePoint = Entity.extend()
function SavePoint:init(x, y)
  Entity.init(self, x, y - 8)
  self.kind = "save"
  self.w, self.h = 16, 24
  self.interactable = true
  self.hint = "save"
  self.interactRange = 24
  self.layer = -1
end
function SavePoint:interact(p)
  local World = require "src.world"
  if G.Save.sealed() then
    G.game:announce("No lantern will hold. Not while you carry the heart.", 2.5)
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  for _, pl in ipairs(World.players) do
    if not pl.dead then
      if pl.downed then pl:revive(1) end
      pl.hp = pl.maxhp
      pl.energy = pl.maxenergy
    end
  end
  G.game:setCheckpoint(World.room.id, G.run.door or "A")
  G.run.door = G.run.door
  G.game:syncRun()
  local ok = G.Save.writeSlot(G.run.slot, G.run)
  G.game:announce(ok and "* Game saved. HP restored. *" or "! Save failed !", 2)
  if G.Audio then G.Audio.sfx("save") end
  World:fx("heal", self.x + 8, self.y + 4)
end
function SavePoint:draw()
  local g = love.graphics
  local World = require "src.world"
  World.glow(self.x + 8, self.y + 6, 24, require("src.assets.palette").ember,
    0.5 + math.sin(G.time * 2) * 0.1)
  G.drawSprite("prop_save", 1, self.x + 8, self.y + self.h)
  local pulse = 0.5 + math.sin(G.time * 3) * 0.4
  g.setColor(P.ember[1], P.ember[2], P.ember[3], pulse * 0.6)
  g.circle("fill", self.x + 8, self.y + 6, 3 + pulse * 2)
  g.setColor(1, 1, 1, 1)
end
Entity.register("save", function(x, y) return SavePoint.new(x, y) end)

-- ------------------------------------------------------------------
-- Checkpoint lantern (auto, silent-ish)
-- ------------------------------------------------------------------
local Checkpoint = Entity.extend()
function Checkpoint:init(x, y)
  Entity.init(self, x + 2, y)
  self.kind = "checkpoint"
  self.w, self.h = 12, 16
  self.lit = false
  self.layer = -1
end
function Checkpoint:update(dt)
  local World = require "src.world"
  if self.lit then return end
  -- No lantern lights once the Ember is loose. This one used to: it set
  -- G.run.checkpoint directly rather than going through setCheckpoint,
  -- so it slipped past the seal every other save surface respected.
  if G.Save.sealed() then return end
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle
      and U.dist(self.x, self.y, p.x, p.y) < 20 then
      self.lit = true
      -- coordinate checkpoint: respawn exactly at this lantern
      G.run.checkpoint = { room = World.room.id, door = G.run.door,
        x = self.x - 2, y = self.y }
      G.game:autosave()
      if G.Audio then G.Audio.sfx("checkpoint") end
      World:fx("burst", self.x + 6, self.y + 4, { color = "ember", n = 8 })
      return
    end
  end
end
function Checkpoint:draw()
  local g = love.graphics
  if self.lit then
    local World = require "src.world"
    World.glow(self.x + 6, self.y + 4, 20, require("src.assets.palette").ember,
      0.55 + math.sin(G.time * 3) * 0.12)
  end
  G.drawSprite("prop_lantern", self.lit and 2 or 1, self.x + 6, self.y + 16)
  if self.lit then
    local pulse = 0.4 + math.sin(G.time * 4) * 0.25
    g.setColor(P.ember[1], P.ember[2], P.ember[3], pulse)
    g.circle("fill", self.x + 6, self.y + 5, 4)
    g.setColor(1, 1, 1, 1)
  end
end
Entity.register("checkpoint", function(x, y) return Checkpoint.new(x, y) end)

-- ------------------------------------------------------------------
-- Teleporter
-- ------------------------------------------------------------------
local Teleporter = Entity.extend()
function Teleporter:init(x, y, parts)
  Entity.init(self, x - 4, y)
  self.kind = "teleporter"
  self.w, self.h = 24, 16
  self.id = parts[2] or "camp"
  self.interactable = true
  self.hint = "warp"
  self.interactRange = 20
  self.layer = -1
end

-- Waking a pad is what puts it on the network.
--
-- This used to happen in init -- the moment the ROOM loaded -- so the
-- network quietly filled itself in with pads the player had walked past in
-- the dark and never touched, and the destination list grew entries nobody
-- remembered earning. Registering on interaction matches both the fiction
-- ("go wake it up", says Jun) and what a player thinks they did.
function Teleporter:register()
  local key = "tp_" .. self.id
  if G.run.flags[key] then return false end
  G.run.flags[key] = true
  local WM = require "src.data.worldmap"
  local label = self.id:upper()
  for _, pad in ipairs(WM.TELEPADS) do
    if pad.id == self.id then label = pad.label break end
  end
  if G.game then
    -- before Jun hands over the master key the pads are inert, so calling
    -- one "unlocked" would be a lie
    G.game:announce((G.run.flags.telenet and "TELEPORTER UNLOCKED -- " or
      "TELEPORTER FOUND -- ") .. label, 3)
  end
  if G.Audio then
    G.Audio.sfx(G.run.flags.telenet and "capsule" or "checkpoint")
  end
  return true
end

function Teleporter:interact(p)
  local firstTime = self:register()
  if G.run.flags.ember_taken then
    G.game:announce("The pad refuses the stolen heart. You carry it on foot.", 2.5)
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  if not G.run.flags.telenet then
    if not firstTime then
      G.game:announce("It hums faintly. Jun in Ember Camp might know about this.", 3)
    end
    return
  end
  G.State.push(require "src.states.teleport", self.id)
end
function Teleporter:draw()
  local g = love.graphics
  if G.run.flags.telenet then
    local World = require "src.world"
    World.glow(self.x + 12, self.y + 6, 22, require("src.assets.palette").cyan, 0.4)
  end
  G.drawSprite("prop_teleporter", 1, self.x + 12, self.y + 16)
  if G.run.flags.telenet then
    local a = 0.3 + math.sin(G.time * 5) * 0.2
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], a)
    for i = 1, 3 do
      local yy = self.y + 12 - ((G.time * 20 + i * 8) % 24)
      g.rectangle("fill", self.x + 4 + i * 3, yy, 2, 4)
    end
    g.setColor(1, 1, 1, 1)
  end
end
Entity.register("teleporter", function(x, y, parts) return Teleporter.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Chest: chest:<flag>:<give-spec...>   e.g. chest:ch1:scrap:15
-- ------------------------------------------------------------------
local Chest = Entity.extend()
function Chest:init(x, y, parts)
  Entity.init(self, x + 1, y + 4)
  self.kind = "chest"
  self.w, self.h = 14, 12
  self.flag = parts[2]
  self.give = {}
  for i = 3, #parts do self.give[#self.give + 1] = parts[i] end
  self.open = G.run and G.run.flags[self.flag]
  self.interactable = not self.open
  self.hint = "open"
  self.layer = -1
end
function Chest:interact(p)
  if self.open then return end
  self.open = true
  self.interactable = false
  G.run.flags[self.flag] = true
  if G.Audio then G.Audio.sfx("chest") end
  local Items = require "src.items"
  Items.grant(table.concat(self.give, ":"), p)
  local World = require "src.world"
  World:fx("burst", self.x + 7, self.y + 4, { color = "gold", n = 10 })
end
function Chest:draw()
  G.drawSprite("prop_chest", self.open and 2 or 1, self.x + 7, self.y + self.h)
end
Entity.register("chest", function(x, y, parts) return Chest.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Sign: sign:<dialogueId>
-- ------------------------------------------------------------------
local Sign = Entity.extend()
function Sign:init(x, y, parts)
  Entity.init(self, x + 2, y + 4)
  self.kind = "sign"
  self.w, self.h = 12, 12
  self.dlgId = parts[2]
  self.interactable = true
  self.hint = "read"
  self.layer = -2
end
function Sign:interact(p)
  local Dialogue = require "src.data.dialogue"
  local script = Dialogue.get(self.dlgId, p)
  if script then G.game:startDialogue(script, { name = "", portrait = nil }) end
end
function Sign:draw()
  G.drawSprite("prop_sign", 1, self.x + 6, self.y + self.h)
end
Entity.register("sign", function(x, y, parts) return Sign.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Dead caretaker frame: deadvess:<n>
-- ------------------------------------------------------------------
-- Sorting Yard 7 is full of these, and every one of them has Vess's
-- silhouette. Reading one posts a line of EIGHT's own filing log -- the
-- player gets six dismantling reports before meeting the thing that
-- wrote them.
local Deadvess = Entity.extend()
function Deadvess:init(x, y, parts)
  Entity.init(self, x, y + 5)
  self.kind = "deadvess"
  self.w, self.h = 14, 11
  self.variant = tonumber(parts[2]) or 1
  self.interactable = true
  self.hint = "read"
  self.layer = -2
  self.lean = ((self.variant * 37) % 7 - 3) * 0.12
end
function Deadvess:interact(p)
  local Dialogue = require "src.data.dialogue"
  local script = Dialogue.get("deadvess_" .. self.variant, p)
  if script then G.game:startDialogue(script, { name = "", portrait = nil }) end
end
function Deadvess:draw()
  local g = love.graphics
  local cx, base = self.x + self.w / 2, self.y + self.h
  g.push() g.translate(cx, base) g.rotate(self.lean)
  -- a caretaker frame, slumped. Same shape as the bot reading it.
  g.setColor(P.shadow)
  g.rectangle("fill", -6, -11, 12, 11)
  g.setColor(P.gray)
  g.rectangle("fill", -5, -17, 10, 6)
  g.setColor(P.dark)
  g.rectangle("fill", -5, -10, 10, 2)
  -- an arm, thrown out
  g.setColor(P.slate)
  g.rectangle("fill", 5, -6, 7, 2)
  g.setColor(1, 1, 1, 1)
  g.pop()
  -- some of them still have an eye. It does not look at you.
  if self.variant % 2 == 1 then
    local f = 0.25 + 0.2 * math.sin(G.time * 1.3 + self.variant)
    g.setColor(P.blood[1], P.blood[2], P.blood[3], f)
    g.circle("fill", cx + 2, base - 14, 1.2)
    g.setColor(1, 1, 1, 1)
  end
end
Entity.register("deadvess", function(x, y, parts) return Deadvess.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- The Sentinel's nest
-- ------------------------------------------------------------------
-- A hundred years of things that fell past Perch 2, matted into a spiral.
-- Lu's vanes were in it. Scenery: no interact, no collision.
local Nest = Entity.extend()
function Nest:init(x, y)
  Entity.init(self, x - 8, y - 6)
  self.kind = "prop"
  self.w, self.h = 32, 22
  self.layer = -2
end
function Nest:update(dt) end
function Nest:draw()
  local g = love.graphics
  local cx, base = self.x + self.w / 2, self.y + self.h
  -- the bowl: coarse strands, lighter toward the rim
  for i = 0, 22 do
    local a = (i / 23) * math.pi
    local rx, ry = 15 - (i % 4), 9 - (i % 3)
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.55 + (i % 3) * 0.12)
    g.setLineWidth(1)
    g.arc("line", "open", cx, base - 4, rx, math.pi + a * 0.12, math.pi * 2 - a * 0.12)
    if i % 5 == 0 then
      g.setColor(P.gray)
      g.line(cx - rx, base - 4, cx - rx + 4, base - 10 - (i % 4))
      g.line(cx + rx, base - 4, cx + rx - 4, base - 10 - (i % 4))
    end
  end
  -- salvage woven in: struts, a plate, something that was a lantern
  g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
  g.rectangle("fill", cx - 9, base - 9, 7, 2)
  g.rectangle("fill", cx + 3, base - 12, 2, 7)
  g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.30 + math.sin(G.time * 0.7) * 0.1)
  g.circle("fill", cx - 2, base - 8, 2)
  g.setColor(1, 1, 1, 1)
end
Entity.register("nest", function(x, y) return Nest.new(x, y) end)

-- ------------------------------------------------------------------
-- Thermal column: updraft:<tiles>
-- ------------------------------------------------------------------
-- The map char marks the BASE cell; the column rises `n` tiles from there,
-- inclusive. Lu rides it with the DRIFT VANES (Player:update); to anyone
-- without them it is weather. Deliberately NOT a push for the un-vaned --
-- a nudge on Vess would quietly change reachability, and roommodel would
-- never know.
local Updraft = Entity.extend()
function Updraft:init(x, y, parts)
  local n = tonumber(parts[2]) or 1
  Entity.init(self, x, y - (n - 1) * 16)
  self.kind = "updraft"
  self.tiles = n
  self.w, self.h = 16, n * 16
  self.layer = -3
end
function Updraft:update(dt) end
function Updraft:draw()
  local g = love.graphics
  local live = G.run.flags.driftvanes
  -- the column: a soft rising wash, brighter once you can use it
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], live and 0.10 or 0.05)
  g.rectangle("fill", self.x + 1, self.y, 14, self.h)
  -- motes riding it, so the direction is never in doubt
  for i = 0, self.tiles * 2 do
    local seed = i * 37
    local yy = self.y + self.h
      - ((G.time * (26 + (seed % 13)) + seed * 11) % self.h)
    local xx = self.x + 3 + ((seed * 7) % 10)
      + math.sin(G.time * 1.7 + i) * 1.5
    g.setColor(P.spark[1], P.spark[2], P.spark[3],
      (live and 0.55 or 0.28) * (0.4 + 0.6 * math.sin(i + G.time)))
    g.circle("fill", xx, yy, 1)
  end
  -- the grate it blows out of
  g.setColor(P.gray)
  g.rectangle("fill", self.x + 1, self.y + self.h - 3, 14, 3)
  g.setColor(P.slate)
  for i = 0, 3 do
    g.rectangle("fill", self.x + 2 + i * 4, self.y + self.h - 3, 2, 3)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("updraft", function(x, y, parts) return Updraft.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Grapple anchor
-- ------------------------------------------------------------------
local Anchor = Entity.extend()
function Anchor:init(x, y)
  Entity.init(self, x + 3, y + 3)
  self.kind = "anchor"
  self.w, self.h = 10, 10
  self.layer = -2
end
function Anchor:draw()
  local g = love.graphics
  local cx, cy = self.x + 5, self.y + 5
  g.setColor(P.slate)
  g.circle("line", cx, cy, 5)
  g.setColor(P.silver)
  g.circle("line", cx, cy, 3.5)
  g.setColor(G.run.flags.grapple and P.cyan or P.gray)
  g.circle("fill", cx, cy, 2)
  g.setColor(1, 1, 1, 1)
end
Entity.register("anchor", function(x, y) return Anchor.new(x, y) end)

-- ------------------------------------------------------------------
-- Energize machine: machine:<flag>[:label]  (Lu only)
-- ------------------------------------------------------------------
local Machine = Entity.extend()
function Machine:init(x, y, parts)
  Entity.init(self, x, y - 8)
  self.kind = "machine"
  self.w, self.h = 16, 24
  self.flag = parts[2]
  self.label = parts[3]
  self.on = G.run and G.run.flags[self.flag]
  self.interactable = not self.on
  self.needsLu = true
  self.hint = "energize"
  self.channel = 0
  self.layer = -1
end
function Machine:interact(p)
  if self.on or p.isVess then return end
  self.on = true
  self.interactable = false
  G.run.flags[self.flag] = true
  if G.Audio then G.Audio.sfx("energize") end
  local World = require "src.world"
  World:fx("burst", self.x + 8, self.y + 8, { color = "cyan", n = 12 })
  local Cam = require "src.camera"
  Cam.shake(2, 0.3)
  G.game:announce(self.label and (self.label:gsub("_", " ")) or "Machinery hums to life!", 2)
end
function Machine:draw()
  local g = love.graphics
  if self.on then
    local World = require "src.world"
    World.glow(self.x + 8, self.y + 8, 18, require("src.assets.palette").cyan, 0.4)
  end
  G.drawSprite("prop_machine", self.on and 2 or 1, self.x + 8, self.y + self.h)
  if self.on then
    local a = 0.4 + math.sin(G.time * 6) * 0.2
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], a)
    g.circle("fill", self.x + 8, self.y + 6, 2.5)
    g.setColor(1, 1, 1, 1)
  end
end
Entity.register("machine", function(x, y, parts) return Machine.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Pressure plate: plate:<flag>  (held down by any bot standing on it,
-- including a solo idle bot)
-- ------------------------------------------------------------------
local Plate = Entity.extend()
function Plate:init(x, y, parts)
  Entity.init(self, x, y + 12)
  self.kind = "plate"
  self.w, self.h = 16, 4
  self.flag = parts[2]
  self.latch = parts[3] == "latch"
  self.pressT = 0
  self.layer = -2
end
function Plate:update(dt)
  local World = require "src.world"
  if self.latch and G.run.flags[self.flag] then
    self.pressT = 1
    return
  end
  local pressed = false
  for _, p in ipairs(World.players) do
    if not p.dead and U.aabb(self.x, self.y - 4, self.w, 8, p.x, p.y, p.w, p.h) then
      pressed = true
      break
    end
  end
  if pressed then
    if self.pressT <= 0 then
      if G.Audio then G.Audio.sfx("switch") end
      if self.latch then
        G.run.flags[self.flag] = true
        G.game:announce("* something rumbles open *", 1.5)
        return
      end
    end
    self.pressT = 1.2
  else
    self.pressT = self.pressT - dt
  end
  -- non-latch flags are reconciled centrally in World:update so that
  -- multiple plates can share one flag (OR semantics)
end
function Plate:draw()
  local g = love.graphics
  local down = self.pressT > 0
  g.setColor(P.gray)
  g.rectangle("fill", self.x + 1, self.y + (down and 2 or 0), 14, down and 2 or 4)
  g.setColor(down and P.cyan or P.silver)
  g.rectangle("fill", self.x + 2, self.y + (down and 2 or 0), 12, 1.5)
  g.setColor(1, 1, 1, 1)
end
Entity.register("plate", function(x, y, parts) return Plate.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Moving platform: plat:<axis h|v>:<distancePx>:<speed>[:flag]
-- If flag given, only moves while flag set (lift).
-- ------------------------------------------------------------------
local Platform = Entity.extend()
function Platform:init(x, y, parts)
  Entity.init(self, x - 8, y + 4)
  self.kind = "plat"
  self.w, self.h = 32, 6
  self.axis = parts[2] or "h"
  self.dist = tonumber(parts[3]) or 64
  self.speed = tonumber(parts[4]) or 30
  self.flag = parts[5]
  self.x0, self.y0 = self.x, self.y
  self.t = 0
  self.layer = -1
end
function Platform:update(dt)
  local World = require "src.world"
  local active = not self.flag or G.run.flags[self.flag]
  local oldX, oldY = self.x, self.y
  if active then
    self.t = self.t + dt
    local ph = (self.t * self.speed) % (self.dist * 2)
    local off = ph <= self.dist and ph or (self.dist * 2 - ph)
    if self.axis == "h" then
      self.x = self.x0 + off
    else
      self.y = self.y0 - off
    end
  end
  local dx, dy = self.x - oldX, self.y - oldY
  -- carry riders
  for _, p in ipairs(World.players) do
    if not p.dead then
      local feet = p.y + p.h
      if p.x + p.w > self.x and p.x < self.x + self.w
        and feet >= self.y - 3 and feet <= self.y + 5 and p.vy >= 0 then
        p.y = self.y - p.h - 0.01
        p.vy = 0
        p.onGround = true
        p.coyote = 0.09
        p.x = p.x + dx
        if dy < 0 then p.y = p.y + dy end
      end
    end
  end
end
function Platform:draw()
  local g = love.graphics
  local World = require "src.world"
  local set = G.tiles[World.zone] or G.tiles.camp
  g.setColor(P.slate)
  g.rectangle("fill", self.x, self.y, self.w, self.h)
  g.setColor(P.silver)
  g.rectangle("fill", self.x + 1, self.y, self.w - 2, 2)
  g.setColor(P.gray)
  for i = 0, 3 do
    g.rectangle("fill", self.x + 3 + i * 8, self.y + 3, 4, 2)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("plat", function(x, y, parts) return Platform.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Boss trigger: boss:<bossId>
-- ------------------------------------------------------------------
local BossTrigger = Entity.extend()
function BossTrigger:init(x, y, parts)
  Entity.init(self, x, y)
  self.kind = "bosstrigger"
  self.w, self.h = 16, 48
  self.bossId = parts[2]
  self.layer = -5
end
function BossTrigger:update(dt)
  local World = require "src.world"
  if G.run.flags["boss_" .. self.bossId] then self.dead = true return end
  if World.bossActive then return end
  -- a full-height tripwire: crossing this column at ANY height starts
  -- the fight (jump arcs and high routes used to sail clean over it)
  for _, p in ipairs(World.players) do
    if not p.dead and not p.idle
      and U.aabb(self.x, 0, self.w, World.h * T, p.x, p.y, p.w, p.h) then
      local Bosses = require "src.entities.bosses"
      Bosses.start(self.bossId, World)
      self.dead = true
      return
    end
  end
end
function BossTrigger:draw() end
Entity.register("boss", function(x, y, parts) return BossTrigger.new(x, y, parts) end)


-- ------------------------------------------------------------------
-- Ember vent: vent:<dir>[:period] -- periodic hostile ember bursts.
-- Lu's shield dome eats the embers: huddle under it to cross.
-- ------------------------------------------------------------------
local Vent = Entity.extend()
function Vent:init(x, y, parts)
  Entity.init(self, x, y)
  self.kind = "vent"
  self.w, self.h = 16, 16
  self.dir = parts[2] or "d"
  self.period = tonumber(parts[3]) or 2.6
  self.t = ((x * 7 + y * 13) % 170) / 170 * self.period  -- staggered starts
  self.burst = 0
  self.burstT = 0
  self.layer = -1
end
function Vent:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  if self.t >= self.period then
    self.t = 0
    self.burst = 4
    self.burstT = 0
  end
  if self.burst > 0 then
    self.burstT = self.burstT - dt
    if self.burstT <= 0 then
      self.burstT = 0.16
      self.burst = self.burst - 1
      local dx = self.dir == "l" and -1 or self.dir == "r" and 1 or 0
      local dy = self.dir == "u" and -1 or (dx == 0 and 1 or 0)
      local Proj = require "src.entities.projectile"
      Proj.spawn(World, self.x + 8 + dx * 9, self.y + 8 + dy * 9, {
        side = "enemy", dmg = 2, kind = "pellet", size = 5,
        vx = dx * 140, vy = dy * 140, life = 1.8,
      })
      World:fx("spark", self.x + 8 + dx * 9, self.y + 8 + dy * 9,
        { color = "ember", n = 2 })
    end
  end
end
function Vent:draw()
  local g = love.graphics
  local hot = self.burst > 0 or self.t > self.period - 0.5
  g.setColor(P.gray)
  g.rectangle("fill", self.x + 2, self.y + 2, 12, 12, 2, 2)
  g.setColor(hot and P.magma or P.maroon)
  g.circle("fill", self.x + 8, self.y + 8, hot and 4.5 or 3)
  g.setColor(hot and P.hotcore or P.rust)
  g.circle("fill", self.x + 8, self.y + 8, 1.8)
  if hot then
    local World = require "src.world"
    World.glow(self.x + 8, self.y + 8, 14, P.magma, 0.35)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("vent", function(x, y, parts) return Vent.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Link core: linkcore:<flag> -- armored lattice node. Small arms clink
-- off it; only the charged LINK blast shatters it (sets the flag, which
-- rooms use to open gates).
-- ------------------------------------------------------------------
local Linkcore = Entity.extend()
function Linkcore:init(x, y, parts)
  Entity.init(self, x + 1, y - 8)
  self.kind = "enemy"          -- shots collide with it
  self.linkcore = true
  self.w, self.h = 14, 24
  self.flag = parts[2]
  self.hp = 1
  self.noKnockback = true
  self.pulse = 0
  self.layer = 1
  if G.run and G.run.flags[self.flag] then self.dead = true end
end
function Linkcore:update(dt)
  self.pulse = self.pulse + dt
end
function Linkcore:hurt(dmg, sx, sy, opts)
  if not (opts and opts.link) then
    -- ordinary fire clinks off the lattice
    local World = require "src.world"
    World:fx("spark", self.x + 7, self.y + 12, { color = "violet", n = 3 })
    if G.Audio then G.Audio.sfx("domehit") end
    return false
  end
  self.dead = true
  G.run.flags[self.flag] = true
  local World = require "src.world"
  World:fx("burst", self.x + 7, self.y + 12, { color = "violet", n = 18, speed = 150 })
  World:fx("burst", self.x + 7, self.y + 12, { color = "spark", n = 10 })
  local Cam = require "src.camera"
  Cam.shake(3, 0.4)
  if G.Audio then G.Audio.sfx("explode") end
  if G.game then
    G.game:announce("The lattice core SHATTERS! A seal releases.", 2.5)
    G.game:autosave()
  end
  return true
end
function Linkcore:draw()
  local g = love.graphics
  local cx = self.x + 7
  local a = 0.55 + math.sin(self.pulse * 4) * 0.25
  g.setColor(P.plum)
  g.rectangle("fill", self.x + 1, self.y + 20, 12, 4)
  g.rectangle("fill", self.x + 1, self.y, 12, 4)
  g.setColor(P.violet[1], P.violet[2], P.violet[3], a)
  g.polygon("fill", cx, self.y + 2, self.x + 12, self.y + 12, cx, self.y + 22,
    self.x + 2, self.y + 12)
  g.setColor(P.orchid)
  g.polygon("line", cx, self.y + 2, self.x + 12, self.y + 12, cx, self.y + 22,
    self.x + 2, self.y + 12)
  local World = require "src.world"
  World.glow(cx, self.y + 12, 16, P.violet, 0.3 * a)
  g.setColor(1, 1, 1, 1)
end
Entity.register("linkcore", function(x, y, parts) return Linkcore.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Spore bulb: sporebulb -- glowing pod. Shooting it lights it up for a
-- few seconds (a lamp for the lightless); destroying it bursts it into
-- drifting spores (Lu's dome eats them).
-- ------------------------------------------------------------------
local Sporebulb = Entity.extend()
function Sporebulb:init(x, y)
  Entity.init(self, x + 2, y + 4)
  self.kind = "enemy"        -- shots collide with it
  self.w, self.h = 12, 12
  self.maxhp = 4
  self.hp = self.maxhp
  self.touchDmg = 0
  self.harmless = true
  self.noKnockback = true
  self.litT = 0
  self.layer = 1
  self.pulse = U.rand(0, 6)
end
function Sporebulb:update(dt)
  self.vy = math.min((self.vy or 0) + 700 * dt, 260)
  PH.move(self, 0, self.vy * dt)
  if self.litT > 0 then
    self.litT = self.litT - dt
    self.lightR = 52
  else
    self.lightR = 10
  end
end
function Sporebulb:hurt(dmg, sx, sy, opts)
  local World = require "src.world"
  self.litT = 6
  World:fx("spark", self.x + 6, self.y + 6, { color = "spark", n = 4 })
  local r = Entity.hurt(self, dmg, sx, sy, opts)
  if self.dead then
    -- burst: drifting spores
    for i = 1, 4 do
      local Proj = require "src.entities.projectile"
      Proj.spawn(World, self.x + 6, self.y + 4, {
        side = "enemy", dmg = 6, kind = "orb", size = 4,
        vx = U.rand(-50, 50), vy = U.rand(-70, -20), gravity = 60, life = 2.0,
      })
    end
    World:fx("burst", self.x + 6, self.y + 6, { color = "violet", n = 10 })
    if G.Audio then G.Audio.sfx("crack") end
  end
  return r
end
function Sporebulb:draw()
  local g = love.graphics
  local cx, cy = self.x + 6, self.y + 6
  local glow = self.litT > 0 and (0.7 + math.sin(G.time * 10) * 0.3)
    or (0.25 + math.sin(G.time * 2 + self.pulse) * 0.1)
  g.setColor(P.plum)
  g.circle("fill", cx, cy + 2, 6)
  g.setColor(P.violet[1], P.violet[2], P.violet[3], 0.6 + glow * 0.4)
  g.circle("fill", cx, cy, 5)
  g.setColor(P.spark[1], P.spark[2], P.spark[3], glow)
  g.circle("fill", cx, cy - 1, 3)
  g.setColor(1, 1, 1, 1)
end
Entity.register("sporebulb", function(x, y) return Sporebulb.new(x, y) end)

-- ------------------------------------------------------------------
-- Mite husk: mitehusk:<flag> -- a spore husk with one of Mote's
-- glowmites stuck inside. Break it open to free the mite (sets flag).
-- ------------------------------------------------------------------
local Mitehusk = Entity.extend()
function Mitehusk:init(x, y, parts)
  Entity.init(self, x + 2, y + 2)
  self.kind = "enemy"
  self.w, self.h = 12, 13
  self.maxhp = 3
  self.hp = self.maxhp
  self.touchDmg = 0
  self.harmless = true
  self.noKnockback = true
  self.flag = parts[2]
  self.layer = 1
  if G.run and G.run.flags[self.flag] then self.dead = true end
end
function Mitehusk:update(dt)
  self.vy = math.min((self.vy or 0) + 700 * dt, 260)
  PH.move(self, 0, self.vy * dt)
  self.lightR = 18
end
function Mitehusk:onDeath()
  G.run.flags[self.flag] = true
  local World = require "src.world"
  local mite = Entity.make("glowmite", self.x + 2, self.y - 6)
  mite.vy = -60
  World:add(mite)
  World:fx("burst", self.x + 6, self.y + 6, { color = "spark", n = 12 })
  if G.Audio then G.Audio.sfx("bigshard") end
  if G.game then
    G.game:announce("A glowmite pulls free! It knows the way home.", 2.5)
    G.game:autosave()
  end
end
function Mitehusk:draw()
  local g = love.graphics
  local cx = self.x + 6
  local wob = math.sin(G.time * 6) * 0.8
  g.setColor(P.plum)
  g.ellipse("fill", cx, self.y + 7, 7, 7)
  g.setColor(P.violet)
  g.ellipse("line", cx, self.y + 7, 7, 7)
  -- the trapped mite, flickering inside
  local fl = 0.5 + math.sin(G.time * 9) * 0.4
  g.setColor(P.spark[1], P.spark[2], P.spark[3], fl)
  g.circle("fill", cx + wob, self.y + 6, 2.5)
  g.setColor(1, 1, 1, 1)
end
Entity.register("mitehusk", function(x, y, parts) return Mitehusk.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Thaw plate: thawplate:<flag> -- a latching pressure plate encased in
-- ice. A heavy hit (charged Arc Lance, Magnet Mortar shell) or the
-- LINK blast melts it free; then one press latches the flag for good.
-- ------------------------------------------------------------------
local Thawplate = Entity.extend()
function Thawplate:init(x, y, parts)
  Entity.init(self, x, y + 4)
  self.kind = "enemy"          -- shots collide while frozen
  self.w, self.h = 16, 12
  self.flag = parts[2]
  self.maxhp = 999
  self.hp = 999
  self.touchDmg = 0
  self.harmless = true
  self.noKnockback = true
  self.heavy = true
  self.frozen = not (G.run and G.run.flags[self.flag])
  self.pressT = 0
  self.layer = -2
end
function Thawplate:update(dt)
  local World = require "src.world"
  if G.run.flags[self.flag] then self.pressT = 1 return end
  if self.frozen then return end
  local pressed = false
  for _, p in ipairs(World.players) do
    if not p.dead and U.aabb(self.x, self.y - 4, self.w, 12, p.x, p.y, p.w, p.h) then
      pressed = true
      break
    end
  end
  if pressed and self.pressT <= 0 then
    if G.Audio then G.Audio.sfx("switch") end
    G.run.flags[self.flag] = true
    G.game:announce("* something rumbles open *", 1.5)
    self.pressT = 1
  end
end
function Thawplate:hurt(dmg, sx, sy, opts)
  local World = require "src.world"
  if not self.frozen then return false end
  if (opts and opts.link) or dmg >= 6 then
    self.frozen = false
    self.kind = "prop"
    World:fx("burst", self.x + 8, self.y + 4, { color = "ice", n = 14 })
    if G.Audio then G.Audio.sfx("crack") end
    G.game:announce("The ice shatters off the plate!", 1.6)
  else
    World:fx("spark", self.x + 8, self.y + 2, { color = "ice", n = 3 })
    if G.Audio then G.Audio.sfx("crack") end
  end
  return false
end
function Thawplate:draw()
  local g = love.graphics
  local down = self.pressT > 0 or (G.run and G.run.flags[self.flag])
  g.setColor(P.gray)
  g.rectangle("fill", self.x + 1, self.y + 8 + (down and 2 or 0), 14, down and 2 or 4)
  g.setColor(down and P.cyan or P.silver)
  g.rectangle("fill", self.x + 2, self.y + 8 + (down and 2 or 0), 12, 1.5)
  if self.frozen then
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.75)
    g.rectangle("fill", self.x, self.y - 2, 16, 14, 2, 2)
    g.setColor(P.white[1], P.white[2], P.white[3], 0.5 + math.sin(G.time * 3) * 0.2)
    g.rectangle("line", self.x, self.y - 2, 16, 14, 2, 2)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("thawplate", function(x, y, parts) return Thawplate.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Stasis pod: pod[:lit] -- the Cradle's sleepers. Decorative, faintly
-- lit, and very much the point.
-- ------------------------------------------------------------------
local Pod = Entity.extend()
function Pod:init(x, y, parts)
  Entity.init(self, x + 1, y - 8)
  self.kind = "prop"
  self.w, self.h = 14, 24
  self.layer = -1
  self.lightR = 20
  self.pulse = U.rand(0, 6)
end
function Pod:update(dt) end
function Pod:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  local breath = 0.35 + math.sin(G.time * 0.9 + self.pulse) * 0.12
  -- shell
  g.setColor(P.shadow)
  g.rectangle("fill", x, y, 14, 24, 4, 4)
  g.setColor(P.slate)
  g.rectangle("line", x, y, 14, 24, 4, 4)
  -- glass, faint sleeper silhouette
  g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.22 + breath * 0.2)
  g.rectangle("fill", x + 2, y + 3, 10, 16, 3, 3)
  g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.9)
  g.rectangle("fill", x + 5, y + 6, 4, 4)   -- head
  g.rectangle("fill", x + 4, y + 10, 6, 8)  -- body
  -- heartbeat light
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], breath)
  g.circle("fill", x + 7, y + 21, 1.6)
  g.setColor(1, 1, 1, 1)
end
Entity.register("pod", function(x, y, parts) return Pod.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- BRAZIER: brazier:<id>[:hearth]
-- ------------------------------------------------------------------
-- The Coldstore's only safe ground. A lit brazier drains chill, and it
-- stays lit for the rest of the run -- lighting one is permanent
-- progress, exactly like opening a shortcut, and the chain of them
-- behind you is both your route forward and your way back.
--
-- LIGHTING ONE. Fire only. Walk into it carrying a spark and it takes.
-- Nothing else in the game lights it: not the Cinder Ram, not a charged
-- lance, not a dome. That is deliberate and it is the reason the spark
-- carry exists at all -- if a charge lit braziers, carrying fire would
-- be decoration and this zone would be a corridor with a status effect
-- in it.
--
-- `:hearth` marks the one flame the archive never let go out. It is lit
-- from the start, it cannot be taken from, and every other brazier in
-- the zone descends from it.
--
-- The lit state lives in G.run.flags via src/cold.lua, NOT on the prop,
-- so it survives leaving the room, swapping bots, saving and reloading.
local Cold = require "src.cold"
local Brazier = Entity.extend()
function Brazier:init(x, y, parts)
  Entity.init(self, x + 2, y - 8)
  self.kind = "prop"
  self.w, self.h = 12, 24
  self.layer = -1
  self.id = parts[2] or "b"
  self.hearth = parts[3] == "hearth"
  self.interactable = true
  self.interactRange = 22
  self.flick = U.rand(0, 6)
  self.litT = 0
  if self.hearth then Cold.light(self.id) end
  self.hint = Cold.isLit(self.id) and "take a spark" or "cold"
end

function Brazier:lit() return Cold.isLit(self.id) end

function Brazier:update(dt)
  local World = require "src.world"
  local lit = self:lit()
  self.heatR = lit and (self.hearth and Cold.HEARTH_R or Cold.BRAZIER_R) or nil
  self.lightR = lit and (self.hearth and Cold.HEARTH_LIGHT or Cold.BRAZIER_LIGHT) or 0
  if self.litT > 0 then self.litT = self.litT - dt end
  self.hint = lit and "take a spark" or "cold"
  -- re-evaluate once on arrival too: walking back into the room with the
  -- chain already complete must open the gate, not require a re-light
  if not self.gateChecked then
    self.gateChecked = true
    Cold.checkGates(World)
  end

  -- WALKING INTO IT WITH FIRE IS ENOUGH. There is no button here: a
  -- carrier cannot shoot or shield, their hands are full, and asking
  -- them to also press interact at the end of a timed crossing turns a
  -- clean arrival into a fumble.
  if lit then return end
  for _, p in ipairs(World.players or {}) do
    if not p.dead and p.hasSpark and p:hasSpark()
      and U.aabb(self.x - Cold.SPARK_R, self.y - Cold.SPARK_R,
                 self.w + Cold.SPARK_R * 2, self.h + Cold.SPARK_R * 2,
                 p.x, p.y, p.w, p.h) then
      Cold.light(self.id)
      p:dropSpark(nil, nil)
      self.litT = 0.9
      World:fx("burst", self.x + 6, self.y + 6,
        { color = "ember", n = 18, speed = 110 })
      if G.Audio then G.Audio.sfx("emitter") end
      if G.game then G.game:announce("The brazier catches.", 1.8) end
      if Cold.checkGates(World) and G.game then
        G.game:announce("Somewhere in the stacks, ice lets go of a door.", 2.6)
        if G.Audio then G.Audio.sfx("quake") end
      end
      break
    end
  end
end

function Brazier:interact(p)
  if not self:lit() then
    G.game:startDialogue({ { who = "sys",
      text = "A cold iron bowl of old ash. It has not burned in a hundred years. Nothing you carry will start it -- fire has to be brought here." } })
    return
  end
  if p:hasSpark() then
    G.game:startDialogue({ { who = "sys",
      text = "Your hands are already full of fire." } })
    return
  end
  p:takeSpark()
  local World = require "src.world"
  World:fx("spark", self.x + 6, self.y + 2, { color = "ember", n = 8 })
  if G.game then
    G.game:announce("You lift a spark out of the fire. It will not last long.", 2.2)
  end
end

function Brazier:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  local lit = self:lit()
  -- the bowl and its legs
  g.setColor(P.shadow)
  g.rectangle("fill", x - 1, y + 15, 14, 3)
  g.setColor(P.slate)
  g.rectangle("fill", x + 2, y + 17, 2, 6)
  g.rectangle("fill", x + 8, y + 17, 2, 6)
  g.setColor(lit and P.gray or P.slate)
  g.rectangle("fill", x - 1, y + 11, 14, 5, 2, 2)
  g.setColor(P.shadow)
  g.rectangle("fill", x + 1, y + 12, 10, 2)

  if not lit then
    -- old ash, and a breath of frost off it
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.35)
    g.rectangle("fill", x + 1, y + 11, 10, 2)
    g.setColor(1, 1, 1, 1)
    return
  end

  local big = self.hearth and 1.5 or 1
  local beat = 0.8 + math.sin(G.time * 4.2 + self.flick) * 0.14
    + math.sin(G.time * 11.3 + self.flick) * 0.06
  if self.litT > 0 then beat = beat * (1 + self.litT) end
  local hh = (10 * big) * beat
  local cx, cy = x + 6, y + 11
  g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.14 * beat)
  g.circle("fill", cx, cy - hh * 0.3, (self.hearth and Cold.HEARTH_R or Cold.BRAZIER_R) * 0.45)
  g.setColor(P.ember)
  g.polygon("fill", cx, cy - hh, cx + 4 * big, cy, cx, cy + 2, cx - 4 * big, cy)
  g.setColor(P.gold)
  g.polygon("fill", cx, cy - hh * 0.66, cx + 2.4 * big, cy, cx, cy + 1.4, cx - 2.4 * big, cy)
  g.setColor(1, 1, 1, 0.8 * beat)
  g.polygon("fill", cx, cy - hh * 0.34, cx + 1.1 * big, cy, cx, cy + 1, cx - 1.1 * big, cy)
  g.setColor(1, 1, 1, 1)
end
Entity.register("brazier", function(x, y, parts) return Brazier.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- FROSTPATCH: frostpatch[:<tiles>]
-- ------------------------------------------------------------------
-- Rime creeping out from under a wall, onto floor that has no business
-- being cold. No collision, no interaction, nothing to shoot -- it is a
-- sentence about the world, not a hint about a wall.
--
-- This is the ONLY tell that the Coldstore is behind ug_secret's east
-- wall. A shootable wall with nothing to distinguish it is a pixel hunt,
-- and a glowing marker over it would be the game admitting it does not
-- trust you. Cold spilling out from behind a wall is neither: it says
-- something back there is very cold, and leaves the conclusion to you.
local Frostpatch = Entity.extend()
function Frostpatch:init(x, y, parts)
  Entity.init(self, x, y + 8)
  self.kind = "prop"
  self.tiles = tonumber(parts[2]) or 3
  self.w, self.h = self.tiles * T, 8
  self.layer = -3          -- under everything, including the players
  self.seed = (x * 13 + y * 7) % 97
end
function Frostpatch:update(dt) end
function Frostpatch:draw()
  local g = love.graphics
  -- the sheet, thinning out to the left: the cold is coming FROM the
  -- right, and the gradient is what points at the wall
  for i = 0, self.tiles - 1 do
    local t = (i + 1) / self.tiles                 -- 0 at the far end
    local a = 0.10 + 0.34 * t
    g.setColor(P.ice[1], P.ice[2], P.ice[3], a)
    g.rectangle("fill", self.x + i * T, self.y + 2, T, 6)
    -- crystals, denser toward the source
    local n = math.floor(1 + 3 * t)
    g.setColor(0.92, 0.98, 1.0, 0.20 + 0.45 * t)
    for k = 1, n do
      local h = (self.seed + i * 31 + k * 17) % 7
      local px = self.x + i * T + ((self.seed + k * 53) % T)
      g.rectangle("fill", px, self.y + 7 - h * 0.5, 1, 1 + h * 0.4)
    end
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("frostpatch", function(x, y, parts) return Frostpatch.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- TERMINAL: terminal:<dialogue id>
-- ------------------------------------------------------------------
-- A console that still has power enough to print. Mechanically it is a
-- sign; it is a separate prop because the last thing in the Cradle
-- should not look like a notice board, and because a screen that is
-- still lit in a room full of people who are not is the image.
local Terminal = Entity.extend()
function Terminal:init(x, y, parts)
  Entity.init(self, x, y - 12)
  self.kind = "prop"
  self.w, self.h = 18, 28
  self.id = parts[2]
  self.interactable = true
  self.hint = "read the log"
  self.interactRange = 26
  self.layer = -1
  self.lightR = 34
  self.seed = (x * 7) % 61
end
function Terminal:update(dt) end
function Terminal:interact(p)
  -- Through Dialogue.get, exactly like Sign. The module returns
  -- `Dialogue`, and the id table lives on `Dialogue.db` -- so indexing
  -- the module directly returns nil for every id in the game and the
  -- terminal reports itself dead. It did, on the first playthrough.
  local Dialogue = require "src.data.dialogue"
  local script = Dialogue.get(self.id, p)
  if not script then
    G.game:startDialogue({ { who = "sys",
      text = "The screen is dead." } })
    return
  end
  G.game:startDialogue(script)
  G.run.flags["read_" .. tostring(self.id)] = true
end
function Terminal:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  -- housing
  g.setColor(P.shadow)
  g.rectangle("fill", x - 1, y + 25, 20, 3)
  g.setColor(P.slate)
  g.rectangle("fill", x, y, 18, 26, 2, 2)
  g.setColor(P.gray)
  g.rectangle("line", x, y, 18, 26, 2, 2)
  -- the screen, still on after a hundred years
  local flick = 0.55 + math.sin(G.time * 2.3 + self.seed) * 0.1
    + math.sin(G.time * 17 + self.seed) * 0.04
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.22 * flick)
  g.rectangle("fill", x + 2, y + 3, 14, 12)
  -- scan lines of text that never finished printing
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.75 * flick)
  for i = 0, 3 do
    local wdt = 4 + ((self.seed + i * 29) % 9)
    g.rectangle("fill", x + 3, y + 4.5 + i * 2.6, wdt, 1)
  end
  -- keys
  g.setColor(P.gray)
  for i = 0, 4 do
    g.rectangle("fill", x + 2 + i * 3, y + 18, 2, 1.5)
    g.rectangle("fill", x + 2 + i * 3, y + 21, 2, 1.5)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("terminal", function(x, y, parts) return Terminal.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- THE EMBER LANTERN (camp_main): the great lantern Ember Camp was
-- built around -- which is to say, the stolen heart of the Core.
-- Interactable from early on. Taking it has exactly the consequences
-- the fiction promises.
-- ------------------------------------------------------------------
-- THE EMBER: the heart of the camp and the largest light in the game.
-- Everything else down here is a lantern; this is a bonfire in a cage,
-- and it is meant to pull the eye the moment you walk in.
local EMBER_W, EMBER_H = 28, 64
local Emberlantern = Entity.extend()
function Emberlantern:init(x, y)
  -- anchored so its base still rests on the tile it was placed on
  Entity.init(self, x - (EMBER_W - 14) / 2, y + 16 - EMBER_H)
  self.kind = "prop"
  self.w, self.h = EMBER_W, EMBER_H
  self.interactable = true
  self.hint = "the Ember"
  self.interactRange = 30
  self.layer = 1
  self.lightR = 190
end
function Emberlantern:update(dt)
  if G.run.flags.ember_taken or G.run.flags.camp_frozen then
    self.lightR = 0
  end
end
function Emberlantern:takeSequence()
  -- the moment itself; shared by the Reckoning path
  local World = require "src.world"
  local script = {
    { who = "sys", text = "The Ember comes loose like a tooth. For one heartbeat it sits in Vess's hands, small and impossibly heavy -- a city's worth of warm." },
    { fn = function()
      G.run.flags.ember_taken = true
      -- camp_frozen is NOT set here any more. It is what empties the camp
      -- and stands the keepers up in its place, and the camp is not
      -- supposed to empty yet: everyone comes to WATCH. World:load sets
      -- it the moment you carry the Ember out of the camp zone, which is
      -- also the moment the line "they watch you carry it away" stops
      -- being true.
      G.run.flags.camp_witness = true
      G.run.emberT = 0
      -- into the hands of whoever pulled it loose
      local W2 = require "src.world"
      local taker = W2.players and W2.players[1]
      for _, pl in ipairs(W2.players or {}) do
        if pl.emberTaker then taker = pl end
      end
      if taker and taker.takeEmber then taker:takeEmber() end
      if G.Audio then G.Audio.sfx("quake") end
      local Cam = require "src.camera"
      Cam.shake(5, 1.2)
    end },
    { who = "sys", text = "Every lantern in Ember Camp goes out at once. The cold walks in like it has been waiting a century for the invitation." },
  }
  if G.run.flags.quest_tikka_done and not G.run.flags.tikka_gift then
    script[#script + 1] = { who = "tikka", text = "...It got dark. It got dark really fast. Here -- take my music box. You have to." }
    script[#script + 1] = { who = "tikka", text = "So somebody remembers the plinky song. Okay? Promise. You're my favorite robots ever." }
    script[#script + 1] = { set = "tikka_gift" }
  else
    script[#script + 1] = { who = "sys", text = "Nobody runs. There is nowhere warm enough to run to. They stand in the dying light, and they watch you carry it away." }
  end
  script[#script + 1] = { who = "sys", text = "Carry the Ember to the Seat of the Core. No lantern will hold your progress, and the teleport pads refuse the stolen heart. There is no going back." }
  G.game:startDialogue(script)
end
function Emberlantern:interact(p)
  local W0 = require "src.world"
  for _, pl in ipairs(W0.players or {}) do pl.emberTaker = (pl == p) or nil end
  local f = G.run.flags
  if f.ember_taken or f.camp_frozen then
    G.game:startDialogue({ { who = "sys", text = "Dark. Cold. Empty. It only ever held one thing." } })
    return
  end
  if f.reckoning and not f.boss_maro then
    G.game:startDialogue({ { who = "elder", text = "NOT. YET. Pay for it first." } })
    return
  end
  if f.boss_maro then
    -- the way is paid; the price is everyone
    G.game:startDialogue({
      { choice = "Take the Ember. Everyone here dies.", yesLabel = "Take it", noLabel = "Not yet", yes = {
        { fn = function() self:takeSequence() end },
      }, no = {} },
    })
    return
  end
  -- pre-fight (or pre-knowledge) interaction
  G.game:startDialogue({
    { who = "sys", text = "The great lantern of Ember Camp. It has burned for a hundred years without wavering. Up close, it does not look like a lantern at all." },
    { choice = "Pry the Ember from the lantern?", yesLabel = "Pry it loose", noLabel = "Leave it", yes = {
      { who = "sys", text = "Everyone in Ember Camp lives by its warmth, and everyone in Ember Camp knows it." },
      { choice = "Take everything they have?", yesLabel = "Take everything", noLabel = "Step back", yes = {
        { fn = function()
          local World = require "src.world"
          if f.mender_yield and f.cradle_truth then
            -- THE RECKONING: the Emberkeepers defend their fire
            G.run.flags.reckoning = true
            G.game:startDialogue({
              { who = "elder", text = "So the deep told you. I wondered which of it would -- the archive, or the engine, or the graves." },
              { who = "elder", text = "A hundred years I kept them warm. Their faces. Their voices. That was worth the world to me. It still is." },
              { who = "elder", text = "You'll take it over an old man's fire. COME AND PAY FOR IT." },
              { fn = function()
                -- the elder and the smith take the field
                for _, e in ipairs(World.entities) do
                  if e.kind == "npc" and (e.id == "elder" or e.id == "brassa") then
                    e.dead = true
                  end
                end
                local Bosses = require "src.entities.bosses"
                local b = Bosses.maro.new(self.x + 40, self.y - 8)
                World:add(b)
                World.bossActive = b
                if G.Audio then G.Audio.playMusic("finalboss") end
                if G.game then
                  G.game:announce("-- EMBERKEEPER MARO --", 2.5)
                  G.game:announce("he kept them warm. that was worth the world. it still is.", 3)
                end
              end },
            })
          else
            -- THE COLD ACCOUNTING: too early, too ignorant
            G.run.emberBad = true
            G.game:startDialogue({
              { fn = function()
                if G.Audio then G.Audio.sfx("quake") end
                local Cam = require "src.camera"
                Cam.shake(6, 1.5)
              end },
              { who = "sys", text = "The Ember comes loose like a tooth. Every lantern in Ember Camp goes out at once." },
              { fn = function()
                G.State.switch(require "src.states.coldending")
              end },
            })
          end
        end },
      }, no = {
        { who = "sys", text = "The lantern burns on, unjudging. Somewhere behind you, someone exhales." },
      } },
    }, no = {} },
  })
end
function Emberlantern:draw()
  local g = love.graphics
  local x, y, w, h = self.x, self.y, self.w, self.h
  local cx = x + w / 2
  local out = G.run.flags.ember_taken or G.run.flags.camp_frozen
  local beat = 0.78 + math.sin(G.time * 1.5) * 0.14
       + math.sin(G.time * 4.3) * 0.05

  -- stone plinth it has stood on for a century
  g.setColor(P.shadow)
  g.rectangle("fill", x + 1, y + h - 12, w - 2, 12, 2, 2)
  g.setColor(P.gray)
  g.rectangle("fill", x + 3, y + h - 12, w - 6, 3)
  g.setColor(P.slate)
  for i = 0, 3 do
    g.rectangle("fill", x + 4 + i * 6, y + h - 8, 3, 6)
  end
  -- iron column and the ribs of the cage
  g.setColor(P.shadow)
  g.rectangle("fill", cx - 4, y + 20, 8, h - 30)
  g.setColor(P.slate)
  g.rectangle("line", x + 2, y + 2, w - 4, 34, 4, 4)
  g.rectangle("line", x + 5, y + 5, w - 10, 28, 3, 3)
  for i = 0, 2 do
    g.line(x + 2, y + 10 + i * 9, x + w - 2, y + 10 + i * 9)
  end

  if out then
    g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.85)
    g.rectangle("fill", x + 7, y + 8, w - 14, 22, 3, 3)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.5)
    g.rectangle("fill", x + 10, y + 14, w - 20, 10, 2, 2)
  else
    -- the fire itself: three nested bodies of light
    local World = require "src.world"
    World.glow(cx, y + 19, 120 * beat, P.ember, 0.20)
    World.glow(cx, y + 19, 62 * beat, P.gold, 0.26)
    g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.85)
    g.ellipse("fill", cx, y + 20, 11 * beat, 14 * beat)
    g.setColor(P.ember[1], P.ember[2], P.ember[3], beat)
    g.ellipse("fill", cx, y + 20, 8 * beat, 11 * beat)
    g.setColor(P.gold[1], P.gold[2], P.gold[3], beat)
    g.ellipse("fill", cx, y + 20, 5 * beat, 7.5 * beat)
    g.setColor(P.cream[1], P.cream[2], P.cream[3], math.min(1, beat * 1.1))
    g.ellipse("fill", cx, y + 19, 2.4 * beat, 4 * beat)
    -- heat coming off the top, forever
    for i = 0, 5 do
      local t = (G.time * 0.55 + i * 0.17) % 1
      local sway = math.sin(G.time * 1.7 + i * 2.1) * (3 + t * 7)
      g.setColor(P.ember[1], P.ember[2], P.ember[3], (1 - t) * 0.35)
      g.circle("fill", cx + sway, y + 6 - t * 34, (1 - t) * 2.2 + 0.4)
    end
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("emberlantern", function(x, y) return Emberlantern.new(x, y) end)

-- ------------------------------------------------------------------
-- THE SEAT (core_boss): the empty throne of the Core. Appears once
-- the Mender yields. Where the game ends -- one way or the other.
-- ------------------------------------------------------------------
local Seat = Entity.extend()
function Seat:init(x, y)
  Entity.init(self, x - 4, y - 8)
  self.kind = "prop"
  self.w, self.h = 24, 24
  self.interactable = true
  self.hint = "the Seat"
  self.interactRange = 26
  self.layer = 1
  self.lightR = 60
end
function Seat:interact(p)
  local f = G.run.flags
  if f.ending then return end
  if f.ember_taken then
    -- RECLAIM: give the heart back
    G.game:startDialogue({
      { who = "sys", text = "The Seat opens like a hand. The Ember settles into it the way a heart settles into a chest: greedily, gratefully, without a word." },
      { who = "mender", text = "...warm. The pipes will sing about this for YEARS." },
      { fn = function()
        G.run.flags.ember_taken = nil   -- installed, no longer carried
        G.run.flags.ending_reclaim = true
        G.run.flags.ending = true
      end },
    })
    return
  end
  local script = {
    { choice = "Take the Seat, and become the keeper of the Deep?", yesLabel = "Become", noLabel = "Not yet", yes = {
      { fn = function()
        G.run.flags.ending_become = true
        G.run.flags.ending = true
      end },
    }, no = {} },
  }
  if f.cradle_truth then
    table.insert(script, 1, { who = "sys", text = "The Seat waits. Below Ember Camp, the stolen heart burns in a lantern. Returned, it would mend everything -- for everyone who did not steal it." })
  else
    table.insert(script, 1, { who = "sys", text = "The empty Seat of the Core. Something must sit here, and want, and judge -- or the Deep stays a machine mending itself in the dark forever." })
  end
  G.game:startDialogue(script)
end
function Seat:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  local pulse = 0.4 + math.sin(G.time * 1.2) * 0.15
  g.setColor(P.shadow)
  g.rectangle("fill", x, y + 4, 24, 20, 3, 3)
  g.setColor(P.teal)
  g.rectangle("line", x, y + 4, 24, 20, 3, 3)
  -- the empty socket
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], pulse)
  g.circle("line", x + 12, y + 12, 6)
  g.circle("line", x + 12, y + 12, 9 + math.sin(G.time * 2) * 1.5)
  if G.run.flags.ember_taken then
    g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.8 + math.sin(G.time * 4) * 0.2)
    g.circle("fill", x + 12, y + 12, 4)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("seat", function(x, y)
  if not (G.run and G.run.flags.mender_yield) then return true end
  return Seat.new(x, y)
end)

-- ------------------------------------------------------------------
-- Frozen keeper: frozenkeeper:<id> -- what is left of Ember Camp
-- after the Ember leaves. Spawns only once camp_frozen is set.
-- ------------------------------------------------------------------
local FROZEN_LINES = {
  elder = "Maro, where he fell. The frost took his last word and kept it.",
  -- CURATOR LOCK, in the Cradle. He is not one of the camp's dead -- he
  -- froze here a hundred years before any of them, at his post, and this
  -- is the only line he gets. Everything else he ever says, you find
  -- written down.
  lock = "He chose to die trying to finish his task rather than flee.",
  sol = "Doc Sol. Her hands are folded, patient, as if the cold were one more thing she could sit with.",
  brassa = "Brassa, hammer still raised. The ice finished the swing for her.",
  tikka = "Tikka. Small, and still, and eight years old at last, forever.",
  root = "Root, kneeling by his crops. The frost on them looks almost like a harvest.",
  inks = "Inks. One finger extended, tracing a map only she could see to the end of.",
  vill = "Pell, facing the dark lantern. A century of watching it, and he did not look away.",
  vill2 = "Nima. She is smiling. The deep is weird, friend.",
  jun = "Jun, facing the vault road. He is the only one whose face you cannot see.",
  ferro = "Ferro's stall, folded and gone. He owed these people nothing. He knew.",
}
local Frozenkeeper = Entity.extend()
function Frozenkeeper:init(x, y, parts)
  Entity.init(self, x + 2, y + 1)
  self.kind = "prop"
  self.id = parts[2] or "vill"
  self.w, self.h = 12, 15
  self.interactable = true
  self.hint = "look"
  self.interactRange = 24
  self.layer = 1
end
function Frozenkeeper:update(dt)
  local PH2 = require "src.physics"
  self.vy = math.min((self.vy or 0) + 830 * dt, 300)
  PH2.move(self, 0, self.vy * dt)
end
function Frozenkeeper:interact(p)
  local line = FROZEN_LINES[self.id] or "One of the deep-folk. The cold was quick, at least. It owed them that."
  G.game:startDialogue({ { who = "sys", text = line } })
end
function Frozenkeeper:draw()
  local NPC2 = require "src.entities.npc"
  local name = ({ elder = "npc_elder", sol = "npc_sol", brassa = "npc_brassa",
    tikka = "npc_tikka", root = "npc_root", inks = "npc_inks",
    vill = "npc_vill", vill2 = "npc_vill2", jun = "npc_jun",
    lock = "npc_lock" })[self.id] or "npc_vill"
  local g = love.graphics
  G.drawSprite(name, 1, self.x + self.w / 2, self.y + self.h + 0.5,
    { tint = { 0.62, 0.75, 0.95, 1 } })
  -- rime
  g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.35 + math.sin(G.time + self.x) * 0.05)
  g.rectangle("fill", self.x - 1, self.y - 2, self.w + 2, self.h + 3, 2, 2)
  g.setColor(1, 1, 1, 1)
end
Entity.register("frozenkeeper", function(x, y, parts)
  if not (G.run and G.run.flags.camp_frozen) then return true end
  return Frozenkeeper.new(x, y, parts)
end)

-- ------------------------------------------------------------------
-- Reward drop: reward:<give-spec> -- a boss's prize as a REAL object.
-- Persists in G.run.pendingDrops until somebody actually picks it up.
-- ------------------------------------------------------------------
local Reward = Entity.extend()
function Reward:init(x, y, parts)
  Entity.init(self, x, y)
  self.kind = "prop"
  self.w, self.h = 14, 12
  self.give = table.concat(parts, ":", 2)
  self.t = 0
  self.baseY = y
  self.layer = 2
  self.lightR = 34
end
function Reward:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.y = self.baseY + math.sin(self.t * 2.4) * 3
  if self.t % 0.5 < dt then
    World:fx("trail", self.x + 7 + U.rand(-5, 5), self.y + U.rand(-2, 8),
      { color = "gold", r = 1.5, t = 0.4 })
  end
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle
      and U.aabb(self.x - 2, self.y - 2, self.w + 4, self.h + 4, p.x, p.y, p.w, p.h) then
      self.dead = true
      local Items = require "src.items"
      Items.grant(self.give, p)
      World:fx("burst", self.x + 7, self.y + 6, { color = "gold", n = 14, speed = 120 })
      if G.Audio then G.Audio.sfx("capsule") end
      -- consume from the persistent ledger
      local drops = G.run.pendingDrops and G.run.pendingDrops[G.run.room]
      if drops then
        for i, d in ipairs(drops) do
          if d.spec == self.give then table.remove(drops, i) break end
        end
      end
      return
    end
  end
end
function Reward:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  local pulse = 0.6 + math.sin(G.time * 3) * 0.25
  -- casing
  g.setColor(P.shadow)
  g.rectangle("fill", x, y, 14, 12, 2, 2)
  g.setColor(P.gold)
  g.rectangle("line", x, y, 14, 12, 2, 2)
  -- core
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], pulse)
  g.rectangle("fill", x + 4, y + 3, 6, 6)
  g.setColor(P.white[1], P.white[2], P.white[3], pulse)
  g.rectangle("fill", x + 6, y + 5, 2, 2)
  -- ground shadow
  g.setColor(0, 0, 0, 0.25)
  g.ellipse("fill", x + 7, self.baseY + 14, 7, 2)
  g.setColor(1, 1, 1, 1)
end
Entity.register("reward", function(x, y, parts) return Reward.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- Boss corpse: bosscorpse:<bossId> -- the broken machine stays where
-- it fell, for the rest of the game. Inspect it for its story.
-- ------------------------------------------------------------------
local CORPSE_LORE = {
  bramblemaw = { "The Bramble Maw. The Mender seeded a fast-growth cultivar to feed a city that was already gone -- and never came back to prune it.", "It was hungry because it was told to grow. Nothing else." },
  rustwarden = { "The Rusted Warden. Posted to the pump hall on the night of the Untending, and never relieved.", "Its ledger shows a hundred years of patrols. Every one is marked: NO INCIDENTS." },
  tideengine = { "The Tide Engine. The pump-heart of the waterworks and the hanging gardens.", "It watered the terraces until the terraces drowned. Then it kept watering them." },
  slaggolem = { "The Slag Golem. It recast itself from its own spare parts so many times that nothing original remains.", "Repair was the only order it remembered. It obeyed to the end." },
  crucible = { "The Crucible. Ten thousand perfect parts stand in its hoppers, forged for machines that no longer exist.", "Its work queue stretches past the century mark. Someone should have told it." },
  prismtyrant = { "The Conductor. For a hundred years it hailed the Core on the resonance band -- one long, unanswered handshake.", "The stones sang back because something had to." },
  aeriesentinel = { "The Aerie Sentinel. Sky watch, final entry: day 36,512. No relief.", "Whatever it was watching for, it believed to the last that someone was coming." },
  motherengine2 = { "The Mender kneels in safe mode, hands open. A hundred years of solder and patience, spent mending around a hole shaped like a heart.", "It does not speak anymore. The pipes are quieter than they have ever been." },
  mycelchoir = { "The Mycel Choir. Not one of the Mender's works -- the wild thing that grew where the light was allowed to die.", "Its song was a corrupted fragment of the Core's old carrier tone. The deep sang what the city forgot." },
  archivist = { "The Archivist. The only subsystem that never broke, because its orders were simple: keep the sleepers safe, admit no one.", "One hundred years. Zero exceptions. One, at the end -- and it chose to make it." },
}
local Bosscorpse = Entity.extend()
function Bosscorpse:init(x, y, parts)
  Entity.init(self, x, y)
  self.kind = "prop"
  self.bossId = parts[2]
  self.w, self.h = 34, 16
  self.interactable = true
  self.hint = "inspect"
  self.interactRange = 28
  self.layer = -1
  self.seed = (x * 31 + y * 17) % 100
end
function Bosscorpse:interact(p)
  local lore = CORPSE_LORE[self.bossId]
  if not lore then return end
  local script = {}
  for _, line in ipairs(lore) do
    script[#script + 1] = { who = "sys", text = line }
  end
  G.game:startDialogue(script)
end
function Bosscorpse:draw()
  local g = love.graphics
  local cx = self.x + self.w / 2
  local spr = "boss_" .. self.bossId
  if G.spriteExists(spr) then
    -- the machine, collapsed: squashed, dark, listing to one side
    G.drawSprite(spr, 1, cx, self.y + self.h + 0.5,
      { sx = 1, sy = 0.55, tint = { 0.42, 0.44, 0.52, 1 } })
  else
    g.setColor(P.shadow)
    g.ellipse("fill", cx, self.y + self.h - 3, self.w / 2, 6)
  end
  -- debris
  g.setColor(P.gray)
  for i = 0, 3 do
    local dx = ((self.seed + i * 37) % (self.w - 6))
    g.rectangle("fill", self.x + dx, self.y + self.h - 2 - (i % 2) * 3, 4, 3)
  end
  g.setColor(P.slate)
  g.rectangle("fill", cx - 2, self.y + 2, 4, 6)
  -- a last, dying light
  local fade = 0.25 + math.sin(G.time * 0.7 + self.seed) * 0.1
  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], fade)
  g.circle("fill", cx + 6, self.y + self.h - 6, 1.5)
  g.setColor(1, 1, 1, 1)
end
Entity.register("bosscorpse", function(x, y, parts) return Bosscorpse.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- THE POURING CRUCIBLE: cruciblepot:<side>
--
-- Two foundry pots flank the Crucible, hung over the two refuge
-- platforms. Each runs a cycle the boss drives:
--
--   idle     cold, inert
--   filling  5s of lava climbing inside it -- SHOOTABLE, 14 hp
--   tilting  1.2s of commitment; shooting it now changes nothing
--   pouring  it empties, and World:floodFloor turns the floor to lava
--   cooling  6s righting itself, cannot re-arm
--   broken   30s, if you shot it out during the fill
--
-- Placed directly above its own platform on purpose: players can only
-- aim straight up, so "climb to the safe place and shoot the thing
-- above you" is one motion. The cost is that from up there the boss is
-- fourteen tiles away and you are dealing it nothing.
-- ------------------------------------------------------------------
local POT_HP = 14
local FILL_T = 5
local TILT_T = 2.0        -- a slow, unmistakable commitment
local POUR_T = 1.4        -- the stream; it runs on while the pool spreads
local COOL_T = 6
local BROKEN_T = 20

local CruciblePot = Entity.extend()
-- cruciblepot:<side>[:auto:<period>:<x0>:<x1>]
--
-- With `auto` the pot runs its own cycle with no boss to drive it, and
-- pours only the stretch of floor between x0 and x1. That is how the
-- mechanic gets taught in the world before the Crucible asks you to
-- handle three of them at once: same pot, same tell, same answer, in a
-- room where the platform is three tiles away and the flood is four
-- seconds instead of six.
function CruciblePot:init(x, y, parts)
  Entity.init(self, x, y)
  self.kind = "enemy"            -- so shots collide with it
  self.harmless = true           -- ...but it never touches you back
  self.touchDmg = 0
  self.pot = true
  self.side = parts[2] or "left"
  self.w, self.h = 5 * T, 4 * T
  self.hp, self.maxhp = POT_HP, POT_HP
  self.noKnockback = true
  self.heavy = true
  self.state = "idle"
  self.stateT = 0
  self.tilt = 0
  self.fill = 0
  self.layer = 1
  if parts[3] == "auto" then
    self.auto = tonumber(parts[4]) or 14
    self.autoT = self.auto * 0.5      -- not immediately: let them arrive
    self.zx0 = tonumber(parts[5])
    self.zx1 = tonumber(parts[6])
    -- the teaching pots run a tight cycle: the lesson wants repetition,
    -- and a pot you wait half a minute for teaches nothing
    self.fillT = 4
    self.tiltT = 1.2
    self.floodT = 2                   -- a shorter dwell than the arena's 6
    self.coolT = 3
  end
end

function CruciblePot:ready()
  return self.state == "idle"
end

function CruciblePot:arm()
  if self.state ~= "idle" then return false end
  self.state = "filling"
  self.stateT = self.fillT or FILL_T
  self.hp = POT_HP
  if G.Audio then G.Audio.sfx("surgecharge") end
  return true
end

-- The boss holds a pot rather than pouring it onto its own vent. It has
-- to catch a pot that is already TILTING too, not just one still
-- filling: the tilt is two seconds long now, so a pot that committed
-- legally while the boss was airborne would otherwise finish its tip
-- straight into the link window.
function CruciblePot:hold()
  if self.state == "filling" and self.stateT < 0.5 then
    self.stateT = 0.5
  elseif self.state == "tilting" and self.stateT < 0.4 then
    self.stateT = 0.4          -- poised on the brink until the floor is free
  end
end

function CruciblePot:update(dt)
  local World = require "src.world"
  if self.auto and self.state == "idle" then
    self.autoT = (self.autoT or self.auto) - dt
    if self.autoT <= 0 then
      self.autoT = self.auto
      self:arm()
      if G.game then
        G.game:announce("The crucible above is filling.", 2)
      end
    end
  end
  self.stateT = self.stateT - dt
  if self.state == "filling" then
    self.fill = 1 - math.max(0, self.stateT / (self.fillT or FILL_T))
    if math.floor(G.time * 20) % 5 == 0 then
      World:fx("trail", self.x + U.rand(6, self.w - 6), self.y + 6,
        { color = "hotcore", r = 1, t = 0.3 })
    end
    if self.stateT <= 0 then
      self.state = "tilting"
      self.stateT = self.tiltT or TILT_T
      if G.game then G.game:announce("THE CRUCIBLE TIPS -- get off the floor!", 1.8) end
      if G.Audio then G.Audio.sfx("bosswarn") end
    end
  elseif self.state == "tilting" then
    -- ease in: barely moving for the first half, then it goes over. A
    -- linear tilt reads as a switch; this reads as a decision being made
    local k = 1 - math.max(0, self.stateT / (self.tiltT or TILT_T))
    self.tilt = k * k * (3 - 2 * k)
    -- it starts dribbling before it commits, which is the last warning
    if k > 0.55 then
      local lx, ly = self:lip()
      World:fx("trail", lx + U.rand(-3, 3), ly,
        { color = "magma", r = 1.5, t = 0.35, vy = 150 })
      -- it is already spilling: the column under the lip is hot
      local floorY = ((World.room and World.room.floodRow or 16) + 1) * 16
      self:scald(World, lx, ly, floorY, dt)
    end
    if self.stateT <= 0 then
      self.state = "pouring"
      self.stateT = POUR_T
      World:floodFloor(self.floodT or 6, math.floor((self.x + self.w / 2) / 16),
        self.zx0, self.zx1)
      local Cam = require "src.camera"
      Cam.shake(5, 0.6)
      if G.Audio then G.Audio.sfx("quake") end
    end
  elseif self.state == "pouring" then
    self.fill = math.max(0, self.stateT / POUR_T)
    local px, py = self:lip()
    local floorY = ((World.room and World.room.floodRow or 16) + 1) * 16
    for _ = 1, 3 do
      local fy = U.rand(py, floorY)
      World:fx("trail", px + U.rand(-3, 3), fy,
        { color = fy > py + 40 and "magma" or "hotcore",
          r = 2, t = 0.35, vy = 220 })
    end
    self:scald(World, px, py, floorY, dt)
    if self.stateT <= 0 then
      self.state = "cooling"
      self.stateT = self.coolT or COOL_T
      self.fill = 0
    end
  elseif self.state == "cooling" or self.state == "broken" then
    self.tilt = U.approach(self.tilt, 0, dt * 1.5)
    if self.stateT <= 0 then
      self.state = "idle"
      self.fill = 0
    end
  end
end

-- Where the stream leaves the pot: the spout, carried round by the tilt,
-- the way anything pours in the world. It used to fall out of the pot's
-- centre, which reads as a leak rather than a pour.
function CruciblePot:lip()
  local cx = self.x + self.w / 2
  local topY = self.y + 8
  local a = self.tilt * (self.side == "left" and 0.75 or -0.75)
  local sp = (self.side == "left") and 1 or -1
  local rx, ry = sp * (self.w / 2 - 3 + 6), 1     -- the spout, unrotated
  return cx + rx * math.cos(a) - ry * math.sin(a),
         topY + rx * math.sin(a) + ry * math.cos(a)
end

-- The cascade. Molten metal falling four tiles is not scenery: standing
-- under the spout is not free.
function CruciblePot:scald(World, lx, ly, floorY, dt)
  self.scaldT = (self.scaldT or 0) - dt
  if self.scaldT > 0 then return end
  self.scaldT = 0.25
  for _, p in ipairs(World.players or {}) do
    if not p.dead and not p.downed and not p.idle
      and U.aabb(lx - 5, ly, 10, math.max(0, floorY - ly), p.x, p.y, p.w, p.h) then
      p.invuln = 0
      p:takeDamage(10, lx, { pierceDash = true, lava = true })
      World:fx("burst", p.x + p.w / 2, p.y + p.h / 2,
        { color = "hotcore", n = 8, speed = 130 })
    end
  end
end

function CruciblePot:hurt(dmg, srcx, srcy, opts)
  local World = require "src.world"
  if self.state ~= "filling" then
    -- a cold pot, or one already committed, just rings
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "rust", n = 3 })
    if G.Audio then G.Audio.sfx("domehit") end
    return false
  end
  self.hp = self.hp - (dmg or 1)
  self.white = 0.12
  World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
    { color = "hotcore", n = 5 })
  if G.Audio then G.Audio.sfx("hitenemy") end
  if self.hp <= 0 then
    self.state = "broken"
    self.stateT = BROKEN_T
    self.fill = 0
    World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
      { color = "magma", n = 20, speed = 150 })
    local Cam = require "src.camera"
    Cam.shake(3, 0.3)
    if G.game then G.game:announce("The crucible cracks -- it dumps down the wall.", 2) end
    if G.Audio then G.Audio.sfx("break") end
  end
  return true
end

function CruciblePot:draw()
  local g = love.graphics
  local cx = self.x + self.w / 2
  local topY = self.y + 8
  local a = self.tilt * (self.side == "left" and 0.75 or -0.75)

  -- the gantry it hangs from: a beam across the ceiling and two chains
  g.setColor(P.dark)
  g.rectangle("fill", self.x - 4, self.y - 6, self.w + 8, 5)
  g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.9)
  for _, ox in ipairs({ -self.w / 2 + 6, self.w / 2 - 6 }) do
    g.rectangle("fill", cx + ox - 1, self.y - 2, 2, 10)
  end
  -- the trunnion the whole thing pivots on
  g.setColor(P.rust)
  g.circle("fill", cx, topY, 4)
  g.setColor(P.dark)
  g.circle("fill", cx, topY, 2)

  g.push()
  g.translate(cx, topY)
  g.rotate(a)

  local w2 = self.w / 2 - 3
  local hh = self.h - 14
  -- A foundry crucible: a deep bucket, narrow at the base, wide at a
  -- flared rim, banded with iron and slung in a yoke.
  local lip = w2
  local base = w2 * 0.52
  local body = {
    -lip, 0, lip, 0,                       -- rim
    base, hh, -base, hh,                   -- base
  }
  -- the yoke arms reaching down from the trunnion to the belly
  g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.95)
  g.setLineWidth(3)
  g.line(-lip - 2, hh * 0.45, -lip - 2, 2)
  g.line(lip + 2, hh * 0.45, lip + 2, 2)
  g.line(-lip - 2, 2, lip + 2, 2)
  g.setLineWidth(1)

  -- shell
  g.setColor(P.shadow)
  g.polygon("fill", body)
  g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 1)
  g.polygon("fill", -lip + 2, 2, lip - 2, 2, base - 1, hh - 1, -base + 1, hh - 1)
  -- iron bands
  g.setColor(P.rust)
  for _, k in ipairs({ 0.32, 0.62 }) do
    local hw = lip + (base - lip) * k
    g.setLineWidth(2)
    g.line(-hw, hh * k, hw, hh * k)
  end
  g.setLineWidth(1)
  g.polygon("line", body)
  -- the flared rim, drawn last so it sits proud
  g.setColor(P.slate)
  g.rectangle("fill", -lip - 2, -2, lip * 2 + 4, 4)
  g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.8)
  g.rectangle("fill", -lip - 2, -2, lip * 2 + 4, 1)
  -- the pouring spout, on the side it tips toward
  local sp = (self.side == "left") and 1 or -1
  g.setColor(P.slate)
  g.polygon("fill", sp * lip, -2, sp * (lip + 6), 1, sp * lip, 4)

  -- what is in it: a molten surface that stays LEVEL as the pot rotates,
  -- because the one thing that reads as heavy is liquid that does not
  -- tilt with its container
  if self.fill > 0.01 then
    local surf = hh - (hh - 3) * self.fill
    local hw = lip + (base - lip) * (surf / hh)
    g.push()
    g.rotate(-a)                          -- back to world-level
    local sway = math.sin(G.time * 4) * 0.6
    g.setColor(P.magma)
    g.polygon("fill", -hw, surf + sway, hw, surf + sway,
      base - 1, hh - 1, -base + 1, hh - 1)
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3],
      0.75 + math.sin(G.time * 8) * 0.25)
    g.rectangle("fill", -hw, surf + sway - 1, hw * 2, 2)
    g.pop()
    -- heat haze over the mouth
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 0.15 * self.fill)
    g.circle("fill", 0, -4, 6 + math.sin(G.time * 6) * 2)
  end

  -- while it can still be shot out, say so: a hit meter on the rim
  if self.state == "filling" then
    local frac = self.hp / self.maxhp
    g.setColor(P.dark)
    g.rectangle("fill", -lip - 2, -9, (lip + 2) * 2, 3)
    g.setColor(P.spark)
    g.rectangle("fill", -lip - 2, -9, (lip + 2) * 2 * frac, 3)
  end
  if (self.white or 0) > 0 then
    g.setColor(1, 1, 1, math.min(1, self.white * 6))
    g.polygon("fill", body)
    self.white = math.max(0, self.white - 0.02)
  end
  g.pop()

  -- the visible rope of lava, drawn from the spout to the floor so the
  -- picture and the hitbox are the same thing
  if self.state == "pouring" or (self.state == "tilting" and self.tilt > 0.55) then
    local lx, ly = self:lip()
    local World = require "src.world"
    local floorY = ((World.room and World.room.floodRow or 16) + 1) * 16
    local wob = math.sin(G.time * 9) * 1.2
    g.setColor(P.magma[1], P.magma[2], P.magma[3], 0.95)
    g.polygon("fill", lx - 3, ly, lx + 3, ly,
      lx + 4 + wob, floorY, lx - 4 + wob, floorY)
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3],
      0.8 + math.sin(G.time * 14) * 0.2)
    g.polygon("fill", lx - 1.5, ly, lx + 1.5, ly,
      lx + 2 + wob, floorY, lx - 2 + wob, floorY)
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 0.35)
    g.ellipse("fill", lx + wob, floorY, 9, 3)
  end

  if self.state == "broken" then
    -- cracked and cold, hanging crooked, dribbling down the wall
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.85)
    g.line(cx - 6, topY + 10, cx + 2, topY + 18)
    g.line(cx + 2, topY + 18, cx - 3, topY + 26)
  end
  g.setColor(1, 1, 1, 1)
end

Entity.register("cruciblepot", function(x, y, parts)
  return CruciblePot.new(x, y, parts)
end)

-- ==================================================================
-- THE COMPUTE CLUSTER (Crystal Hollows)
--
-- Emberdeep's machine room. The zone's puzzles are CIRCUITS: a beam
-- leaves an emitter, the players move the room to route it, and a node
-- at the far end closes a gate.
--
-- Three props, three verbs, and none of them cares which directions a
-- player can aim -- so a move to circular aiming later changes nothing
-- here:
--
--   PANEL    heavy reflector on a rail. Only Vess's CHARGE shoves it.
--   ROTOR    light mirror. Cycles orientation when hit by ANYTHING.
--   EMITTER  the source. Dormant ones wake to Lu's DOME, for a price.
--
-- Nodes LATCH permanently, like a latching pressure plate: solve the
-- circuit once and the gate stays open. That is friendlier on re-entry
-- and it keeps the flag a plain progression flag, which is what lets
-- checkprogress go on proving the run.
-- ==================================================================
Props = Props or {}

-- beam directions: 1 right, 2 down, 3 left, 4 up
local BDX = { 1, 0, -1, 0 }
local BDY = { 0, 1, 0, -1 }
-- a mirror maps an incoming direction to an outgoing one
local MIRROR = {
  f = { 4, 3, 2, 1 },   -- "/"  right->up  down->left  left->down  up->right
  b = { 2, 1, 4, 3 },   -- "\\" right->down down->right left->up  up->left
}
local DIRNAME = { right = 1, down = 2, left = 3, up = 4 }

local function dirtyBeams()
  local World = require "src.world"
  World.beamDirty = true
end

-- ------------------------------------------------------------------
-- MECHANISM PERSISTENCE
--
-- A solved circuit has to STAY solved. The node latches into
-- G.run.flags, so the gate it opened does stay open -- but the panel
-- and the rotor that routed the beam there are plain entities, and
-- they respawn from the room spec every time the room loads. Walk out
-- of a solved room and walk back in and the panel is at slot 0 again
-- and the rotor is turned the wrong way: the gate is open, but the
-- room in front of you says it is not, and the beam that used to be
-- pointing somewhere safe is pointing across the floor again.
--
-- So every movable beam part writes its position into
-- G.run.mech[room][tile]. The key is the SPAWN tile, which is fixed
-- for the life of the room file and unique inside a room, so it
-- survives a save, a reload, and any amount of moving the part
-- around. Emitters are deliberately NOT stored: a woken emitter is a
-- countdown, not a state, and freezing a countdown in the save is how
-- you get an emitter that has been "on" for three days.
-- ------------------------------------------------------------------
-- roomId is passed explicitly by the restore pass, because that pass runs
-- during World:load -- BEFORE G.run.room is advanced to the room being
-- loaded. Reading G.run.room there would key every restore against the
-- room the players just left.
local function mechRoom(roomId, create)
  roomId = roomId or (G.run and G.run.room)
  if not (G.run and roomId) then return nil end
  if not G.run.mech then
    if not create then return nil end
    G.run.mech = {}
  end
  local r = G.run.mech[roomId]
  if not r then
    if not create then return nil end
    r = {}
    G.run.mech[roomId] = r
  end
  return r
end

function Props.mechSave(e, tbl, roomId)
  if not e.mechKey then return end
  local room = mechRoom(roomId, true)
  if room then room[e.mechKey] = tbl end
end

function Props.mechLoad(e, roomId)
  if not e.mechKey then return nil end
  local room = mechRoom(roomId, false)
  return room and room[e.mechKey] or nil
end

-- ------------------------------------------------------------------
-- EMITTER: emitter:<dir>[:dormant[:<seconds>]]
-- ------------------------------------------------------------------
local Emitter = Entity.extend()
function Emitter:init(x, y, parts)
  Entity.init(self, x + 2, y + 2)
  self.kind = "prop"
  self.w, self.h = 12, 12
  self.beamEmit = true
  self.dir = DIRNAME[parts[2] or "right"] or 1
  self.dormant = parts[3] == "dormant"
  self.wakeFor = tonumber(parts[4]) or 9
  self.on = not self.dormant
  self.t = 0
  self.layer = -1
  self.lightR = self.on and 26 or 0
  self.chargeT = 0
end
function Emitter:update(dt)
  self.t = self.t + dt
  -- The charge is a CHANNEL, not a button. updateCharge below is driven
  -- by Lu each frame she is holding a dome on this emitter; if she is
  -- not, chargeHeld goes stale and the channel unwinds -- fast, so
  -- walking away is an obvious cancel rather than a pause.
  if self.charging and not self.chargeHeld then self:cancelCharge() end
  self.chargeHeld = false
  if self.charging then
    self.chargeT = math.min(Emitter.CHANNEL, self.chargeT + dt)
  elseif self.chargeT > 0 then
    self.chargeT = math.max(0, self.chargeT - dt * 3)
  end
  if self.dormant and self.on then
    self.wakeT = (self.wakeT or 0) - dt
    if self.wakeT <= 0 then
      self.on = false
      self.lightR = 0
      dirtyBeams()
      if G.Audio then G.Audio.sfx("domeoff") end
    end
  end
end
-- ------------------------------------------------------------------
-- WAKING AN EMITTER IS A TWO-SECOND CHANNEL, AND IT COSTS HALF A BAR.
--
-- Lu stands in reach with the dome up and holds it there. The emitter
-- shakes, the dome comes apart, and the fragments are drawn into the
-- aperture; two seconds later the machine has a century-old work order
-- and Lu has half the energy she started with.
--
-- Three rules make this a decision instead of a formality:
--
--   ONE AT A TIME. A dome overlapping three dormant emitters used to
--   wake all three for thirty apiece, on the same frame. Now the dome
--   feeds the NEAREST unlit emitter and nothing else, so a room with
--   three emitters costs three channels and three walks.
--
--   THE COST IS THE DOME. WAKE_COST is half of Lu's base bar and is
--   drained smoothly across the channel INSTEAD of the dome's normal
--   upkeep, because the fiction is that the shield itself is being
--   fed in. Half a bar, exactly, every time -- which is a number the
--   harness can measure rather than estimate.
--
--   IT IS PAYABLE AT BASE CAPACITY. One channel is 50 of 100, so no
--   circuit in the zone needs an energy upgrade to start; upgrades buy
--   back the waiting between emitters, not access.
-- ------------------------------------------------------------------
Emitter.CHANNEL = 2.0
Emitter.WAKE_COST = 50           -- half of Lu's base 100

-- Spend the beam. A charged emitter that has DONE its job has to go dark
-- immediately: the Conductor's beam runs from the floor all the way up
-- to the station, so leaving it lit after the shield breaks puts a
-- lethal column exactly where the players now need to stand. The beam is
-- ammunition, not a lamp.
function Emitter:expend()
  if not self.on then return end
  self.on = false
  self.wakeT = 0
  self.lightR = 0
  dirtyBeams()
  local World = require "src.world"
  World:fx("burst", self.x + 6, self.y + 6,
    { color = "ice", n = 8, speed = 90 })
  if G.Audio then G.Audio.sfx("domeoff") end
end

function Emitter:cancelCharge()
  if not self.charging then return end
  self.charging = nil
  self.chargeP = nil
  if G.Audio then G.Audio.sfx("deny") end
end

-- called by Lu every frame her dome is on this emitter
function Emitter:energize(p, dt)
  if not self.dormant then return false end
  if self.on then
    self.wakeT = self.wakeFor      -- topping up a live emitter is free
    return true
  end
  if (p.energy or 0) <= 0 then
    self:cancelCharge()
    return false
  end
  -- starting costs nothing, but it will not start unless the bar can
  -- actually finish the job -- half-spending and stalling out is the
  -- one failure mode that would feel like the game cheated.
  if not self.charging then
    if (p.energy or 0) < Emitter.WAKE_COST then
      if G.game then G.game:announce("Not enough charge in the dome.", 1.5) end
      if G.Audio then G.Audio.sfx("deny") end
      return false
    end
    self.charging = true
    self.chargeT = 0
    self.chargeP = p
    if G.Audio then G.Audio.sfx("domeon") end
  end
  self.chargeHeld = true
  self.chargeP = p

  local World = require "src.world"
  local cx, cy = self.x + 6, self.y + 6
  -- the shield coming apart and being pulled in: fragments spawn on the
  -- dome's rim and fly at the aperture, faster as the channel closes
  local prog = self.chargeT / Emitter.CHANNEL
  self.fragT = (self.fragT or 0) - (dt or 0)
  if self.fragT <= 0 then
    self.fragT = 0.05
    local ang = U.rand(0, math.pi * 2)
    local r = (p.domeRadius or 36)
    local fx, fy = p.x + p.w / 2 + math.cos(ang) * r,
                   p.y + p.h / 2 - 4 + math.sin(ang) * r
    local d = math.max(1, U.dist(fx, fy, cx, cy))
    local sp = 110 + prog * 190
    World:fx("trail", fx, fy, {
      color = "cyan", r = 1 + prog, t = d / sp,
      vx = (cx - fx) / d * sp, vy = (cy - fy) / d * sp,
    })
  end
  -- the sound of it, retriggered rather than looped (no loop channel here)
  self.humT = (self.humT or 0) - (dt or 0)
  if self.humT <= 0 then
    self.humT = 0.22
    if G.Audio then G.Audio.sfx("emcharge", 0.8 + prog * 0.9) end
  end

  -- drain smoothly, and suspend the dome's own upkeep for the duration
  p.energy = math.max(0, p.energy - Emitter.WAKE_COST / Emitter.CHANNEL * (dt or 0))
  p.energyDelay = 0.9
  p.domeFed = true

  if self.chargeT < Emitter.CHANNEL then return false end

  -- done
  self.charging = nil
  self.chargeP = nil
  self.chargeT = 0
  self.on = true
  self.wakeT = self.wakeFor
  self.lightR = 26
  dirtyBeams()
  World:fx("burst", cx, cy, { color = "cyan", n = 18, speed = 130 })
  local Cam = require "src.camera"
  Cam.shake(3, 0.2)
  if G.Audio then G.Audio.sfx("energize") end
  if not G.run.flags.taught_emitter then
    G.run.flags.taught_emitter = true
    if G.game then G.game:announce("The emitter takes the charge.", 2) end
  end
  return true
end
function Emitter:draw()
  local g = love.graphics
  -- GENTLE SHAKING while it is being charged, growing over the channel.
  -- Sub-pixel at the start and about a pixel and a half at the end, so
  -- it reads as a machine straining awake and not as a broken sprite.
  local prog = self.chargeT / Emitter.CHANNEL
  local sh = 0
  if self.chargeT > 0 then sh = 0.4 + prog * 1.2 end
  local ox = sh > 0 and math.sin(G.time * 47) * sh or 0
  local oy = sh > 0 and math.sin(G.time * 39 + 1.7) * sh * 0.7 or 0
  g.push()
  g.translate(ox, oy)
  local cx, cy = self.x + 6, self.y + 6
  g.setColor(P.dark)
  g.rectangle("fill", self.x, self.y, 12, 12, 2, 2)
  g.setColor(self.on and P.cyan or P.slate)
  g.rectangle("line", self.x, self.y, 12, 12, 2, 2)
  -- the aperture, pointing where the beam goes
  local dx, dy = BDX[self.dir], BDY[self.dir]
  g.setColor(self.on and P.spark or P.slate)
  g.rectangle("fill", cx + dx * 4 - 2, cy + dy * 4 - 2, 4, 4)
  -- the channel meter: a ring that closes as the charge lands
  if self.chargeT > 0 and not self.on then
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.5 + prog * 0.5)
    g.arc("line", "open", cx, cy, 10, -math.pi / 2,
      -math.pi / 2 + prog * math.pi * 2)
    g.setColor(P.spark[1], P.spark[2], P.spark[3], prog)
    g.circle("fill", cx, cy, 1 + prog * 3)
  end
  if self.on then
    local pulse = 0.5 + math.sin(G.time * 8) * 0.3
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], pulse)
    g.circle("line", cx, cy, 7 + pulse * 2)
  elseif self.dormant then
    -- a dark emitter says what would wake it
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.25 + math.sin(G.time * 2) * 0.1)
    g.circle("line", cx, cy, 9)
  end
  g.setColor(1, 1, 1, 1)
  g.pop()
end
Entity.register("emitter", function(x, y, parts) return Emitter.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- PANEL: panel:<rail h|v>:<mirror f|b>:<slots>
-- Heavy. Only a charge moves it, one slot per shove.
-- ------------------------------------------------------------------
local Panel = Entity.extend()
function Panel:init(x, y, parts)
  Entity.init(self, x, y)
  self.kind = "panel"
  self.w, self.h = 16, 16
  self.rail = parts[2] or "h"
  self.mirror = parts[3] or "f"
  self.slots = tonumber(parts[4]) or 3
  self.beamMirror = true
  self.slot = 0
  self.homeX, self.homeY = x, y
  self.layer = -1
end
function Panel:railStep()
  return self.rail == "h" and 16 or 0, self.rail == "v" and 16 or 0
end
-- Re-enter a room you already solved and the panel is where you left it.
function Panel:restoreMech(st)
  local slot = tonumber(st.slot)
  if not slot or slot < 0 or slot > self.slots then return end
  local sx, sy = self:railStep()
  self.slot = slot
  self.x, self.y = self.homeX + sx * slot, self.homeY + sy * slot
end
-- shoved by a charge; dir is the sign of the shove along the rail
function Panel:shove(dir)
  local World = require "src.world"
  -- Weight is the point. An unplated charge is speed, and speed does
  -- nothing to two hundred kilos on a rail; the BULWARK plate is what
  -- turns the charge into a shove. genprogress knows this too, so any
  -- circuit routed by a panel carries `bulwark` as a requirement and
  -- checkprogress keeps proving the run in the right order.
  if not (G.run and G.run.flags.bulwark) then
    if G.game then
      G.game:announce("Too heavy. A bare charge just rings off it.", 2)
    end
    World:fx("spark", self.x + 8, self.y + 8, { color = "slate", n = 6 })
    if G.Audio then G.Audio.sfx("ramhit") end
    return false
  end
  local sx, sy = self:railStep()
  local want = self.slot + dir
  if want < 0 or want > self.slots then
    World:fx("spark", self.x + 8, self.y + 8, { color = "slate", n = 4 })
    if G.Audio then G.Audio.sfx("ramhit") end
    return false
  end
  -- it cannot be shoved into the wall either
  local nx, ny = self.homeX + sx * want, self.homeY + sy * want
  local tx, ty = math.floor(nx / 16), math.floor(ny / 16)
  if World:isSolid(tx, ty) then
    if G.Audio then G.Audio.sfx("ramhit") end
    return false
  end
  self.slot = want
  self.x, self.y = nx, ny
  Props.mechSave(self, { slot = self.slot })
  dirtyBeams()
  World:fx("burst", self.x + 8, self.y + 8, { color = "silver", n = 8, speed = 90 })
  local Cam = require "src.camera"
  Cam.shake(2, 0.15)
  if G.Audio then G.Audio.sfx("ram") end
  return true
end
function Panel:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  -- the rail it runs on, so the room reads before you touch anything
  g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.35)
  local sx, sy = self:railStep()
  g.rectangle("fill", self.homeX + 7 - (sy > 0 and 0 or 0), self.homeY + 7,
    sx * self.slots + (sx > 0 and 2 or 2), sy * self.slots + 2)
  -- the housing
  g.setColor(P.dark)
  g.rectangle("fill", x + 1, y + 1, 14, 14, 2, 2)
  g.setColor(P.silver)
  g.rectangle("line", x + 1, y + 1, 14, 14, 2, 2)
  -- the mirror face
  g.setLineWidth(3)
  g.setColor(P.ice)
  if self.mirror == "f" then g.line(x + 3, y + 13, x + 13, y + 3)
  else g.line(x + 3, y + 3, x + 13, y + 13) end
  g.setLineWidth(1)
  g.setColor(1, 1, 1, 1)
end
Entity.register("panel", function(x, y, parts) return Panel.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- ROTOR: rotor[:<mirror f|b>]  -- cycles when hit by anything at all
-- ------------------------------------------------------------------
local Rotor = Entity.extend()
function Rotor:init(x, y, parts)
  Entity.init(self, x + 2, y + 2)
  self.kind = "enemy"          -- so shots collide with it
  self.harmless = true
  self.touchDmg = 0
  self.heavy = true            -- never knocked about, never burned
  self.noKnockback = true
  self.w, self.h = 12, 12
  self.mirror = parts[2] or "f"
  self.beamMirror = true
  self.rotT = 0
  self.layer = -1
end
function Rotor:update(dt)
  if self.rotT > 0 then self.rotT = math.max(0, self.rotT - dt) end
end
function Rotor:restoreMech(st)
  if st.mirror == "f" or st.mirror == "b" then self.mirror = st.mirror end
end
function Rotor:hurt(dmg, srcx, srcy, opts)
  if self.rotT > 0 then return false end       -- one turn per hit, not per pellet
  self.rotT = 0.18
  self.mirror = self.mirror == "f" and "b" or "f"
  Props.mechSave(self, { mirror = self.mirror })
  dirtyBeams()
  local World = require "src.world"
  World:fx("spark", self.x + 6, self.y + 6, { color = "ice", n = 6 })
  if G.Audio then G.Audio.sfx("crack") end
  return false                                  -- it never takes damage
end
function Rotor:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  local wob = self.rotT > 0 and math.sin(self.rotT * 60) * 1.5 or 0
  g.setColor(P.dark)
  g.rectangle("fill", x, y, 12, 12, 2, 2)
  g.setColor(P.violet)
  g.rectangle("line", x, y, 12, 12, 2, 2)
  g.setLineWidth(2)
  g.setColor(P.ice)
  if self.mirror == "f" then g.line(x + 2 + wob, y + 10, x + 10 + wob, y + 2)
  else g.line(x + 2 + wob, y + 2, x + 10 + wob, y + 10) end
  g.setLineWidth(1)
  g.setColor(1, 1, 1, 1)
end
Entity.register("rotor", function(x, y, parts) return Rotor.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- MIRROR: mirror:<f|b>  -- bolted down. Never moves, never turns.
--
-- The Conductor's arena needs a corner: the emitters fire DOWN from
-- their perches and the beam has to be running along the FLOOR before a
-- panel can turn it up into a station. A rotor cannot do that job --
-- rotors cycle when hit by anything at all, so a stray pellet during a
-- fight would silently un-aim the room. A panel cannot either: it is
-- the thing the players are supposed to be aiming.
--
-- So: a third mirror that is furniture. It reads as bolted hardware
-- rather than a mechanism, which is the point -- nothing about it
-- should invite you to try to move it.
-- ------------------------------------------------------------------
local Mirror = Entity.extend()
function Mirror:init(x, y, parts)
  Entity.init(self, x + 2, y + 2)
  self.kind = "prop"
  self.w, self.h = 12, 12
  self.mirror = parts[2] or "f"
  self.beamMirror = true
  self.fixed = true
  self.layer = -1
end
function Mirror:draw()
  local g = love.graphics
  local x, y = self.x, self.y
  -- a heavy plinth, so it reads as furniture and not as a mechanism
  g.setColor(P.dark)
  g.rectangle("fill", x - 1, y + 8, 14, 6)
  g.setColor(P.slate)
  g.rectangle("fill", x, y, 12, 12, 1, 1)
  g.rectangle("fill", x - 1, y + 10, 14, 3)
  g.setLineWidth(2)
  g.setColor(P.ice)
  if self.mirror == "f" then g.line(x + 2, y + 10, x + 10, y + 2)
  else g.line(x + 2, y + 2, x + 10, y + 10) end
  g.setLineWidth(1)
  -- rivets: this one is bolted down
  g.setColor(P.dark)
  g.circle("fill", x + 1, y + 11, 1)
  g.circle("fill", x + 11, y + 11, 1)
  g.setColor(1, 1, 1, 1)
end
Entity.register("mirror", function(x, y, parts) return Mirror.new(x, y, parts) end)

-- ------------------------------------------------------------------
-- NODE: node:<flag>[:<beams needed>]
-- Latches for good the first time it is satisfied.
-- ------------------------------------------------------------------
local Node = Entity.extend()
function Node:init(x, y, parts)
  Entity.init(self, x + 2, y + 2)
  self.kind = "prop"
  self.w, self.h = 12, 12
  self.beamNode = true
  self.flag = parts[2]
  self.need = tonumber(parts[3]) or 1
  self.lit = 0
  self.layer = -1
  self.latched = G.run and G.run.flags[self.flag] or false
  if self.latched then self.lightR = 22 end
end
function Node:satisfy()
  if self.latched then return end
  self.latched = true
  self.lightR = 22
  G.run.flags[self.flag] = true
  local World = require "src.world"
  World:fx("burst", self.x + 6, self.y + 6, { color = "cyan", n = 20, speed = 130 })
  if G.game then G.game:announce("Circuit closed.", 1.6) end
  if G.Audio then G.Audio.sfx("energize") end
end
function Node:draw()
  local g = love.graphics
  local cx, cy = self.x + 6, self.y + 6
  g.setColor(P.dark)
  g.rectangle("fill", self.x, self.y, 12, 12, 2, 2)
  g.setColor(self.latched and P.cyan or P.slate)
  g.rectangle("line", self.x, self.y, 12, 12, 2, 2)
  -- how many beams it wants, and how many it has
  for i = 1, self.need do
    local lx = cx - (self.need - 1) * 3 + (i - 1) * 6
    local on = self.latched or i <= self.lit
    g.setColor(on and P.spark or P.slate)
    g.circle("fill", lx, cy, 2)
  end
  if self.latched then
    local pulse = 0.4 + math.sin(G.time * 4) * 0.2
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], pulse)
    g.circle("line", cx, cy, 9)
  end
  g.setColor(1, 1, 1, 1)
end
Entity.register("node", function(x, y, parts) return Node.new(x, y, parts) end)

Props.BDX, Props.BDY, Props.MIRROR = BDX, BDY, MIRROR

return true
