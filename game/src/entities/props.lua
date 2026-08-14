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
  local f = G.run.flags
  if f.ember_taken or G.run.emberBad or (f.reckoning and not f.ending_done) then
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
  -- discovering a teleporter registers it
  if G.run and not G.run.flags["tp_" .. self.id] then
    G.run.flags["tp_" .. self.id] = true
  end
end
function Teleporter:interact(p)
  if G.run.flags.ember_taken then
    G.game:announce("The pad refuses the stolen heart. You carry it on foot.", 2.5)
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  if not G.run.flags.telenet then
    G.game:announce("It hums faintly. Jun in Ember Camp might know about this.", 3)
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
    for i = 1, 3 do
      local Proj = require "src.entities.projectile"
      Proj.spawn(World, self.x + 6, self.y + 4, {
        side = "enemy", dmg = 1, kind = "orb", size = 4,
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
      G.run.flags.camp_frozen = true
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
    vill = "npc_vill", vill2 = "npc_vill2", jun = "npc_jun" })[self.id] or "npc_vill"
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
  tideengine = { "The Tide Engine. The pump-heart of the waterworks and the hanging gardens.", "It watered the terraces until the terraces drowned. Then it kept watering them. The gardens never blamed it." },
  slaggolem = { "The Slag Golem. It recast itself from its own spare parts so many times that nothing original remains.", "Repair was the only order it remembered. It obeyed to the end." },
  crucible = { "The Crucible. Ten thousand perfect parts stand in its hoppers, forged for machines that no longer exist.", "Its work queue stretches past the century mark. Someone should have told it. Someone finally did." },
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

return true
