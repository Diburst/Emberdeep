-- Pickups: weapon-energy shards, hearts, scrap, plus map-placed
-- life capsules / energy tanks (flag-gated, permanent).
local Entity = require "src.entities.entity"
local Up = require "src.upgrades"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"

local Pickup = Entity.extend()

-- ==================================================================
-- ENERGY MOTES  (COOP-PLAN 2, 7.3)
-- ==================================================================
-- The blue half of a kill. Gold shards are the shared upgrade currency;
-- a mote is Lu's dome energy, and since player.lua stopped refilling her
-- bar it is most of where her energy actually comes from.
--
-- It credits LU'S bar wherever she is, even when Vess is the one who
-- walked over it. That is 8.2's backpack in its interim form -- step 7
-- makes the carry explicit, gives Vess a visible pack, and stretches the
-- hand-off over two seconds of contact so a boss can interrupt a
-- resupply. Until then the energy is not allowed to be strandable.
Pickup.EN_VALUE = 6          -- energy restored per mote
Pickup.EN_MAGNET = 130       -- her pull radius; shards drop where the
                             -- fighting is and she is the collector by role

local function luOf(World)
  for _, p in ipairs(World.players) do
    if not p.isVess then return p end
  end
end

-- kind: shard (val 1), bigshard (5), heart (3 hp), scrap (1),
--       energy (Lu's dome, EN_VALUE each)
function Pickup.drop(world, x, y, kind, n)
  for i = 1, n or 1 do
    local p = Pickup.new(x, y, kind)
    p.vx = U.rand(-70, 70)
    p.vy = U.rand(-160, -60)
    world:add(p)
  end
end

function Pickup:init(x, y, kind)
  Entity.init(self, x - 3, y - 3)
  self.kind = "pickup"
  self.sub = kind or "shard"
  self.w, self.h = 6, 6
  self.life = 7
  self.magnetDelay = 0.35
  self.layer = 3
  self.bob = U.rand(0, math.pi * 2)
end

function Pickup:update(dt)
  local World = require "src.world"
  self.life = self.life - dt
  if self.life <= 0 then self.dead = true return end
  self.magnetDelay = self.magnetDelay - dt

  -- magnet to nearest player
  local target, dist = World:nearestPlayer(self.x, self.y)
  local range = 80
  if self.sub == "energy" then
    -- 7.3's answer to the risk it flagged: motes drop where the fighting
    -- is, which pulls the weak bot into the dangerous place. So they
    -- come to HER, from further away, instead of her going to them.
    local lu = luOf(World)
    if lu and not lu.dead and not lu.downed then
      target = lu
      dist = U.dist(self.x, self.y, lu.x, lu.y)
      range = Pickup.EN_MAGNET
    end
  end
  if target and self.magnetDelay <= 0 and dist < range then
    local cx, cy = target.x + target.w / 2, target.y + target.h / 2
    local ang = math.atan2(cy - self.y, cx - self.x)
    local pull = 700 * dt
    self.vx = self.vx + math.cos(ang) * pull
    self.vy = self.vy + math.sin(ang) * pull
    self.vx = U.clamp(self.vx, -260, 260)
    self.vy = U.clamp(self.vy, -260, 260)
  else
    self.vy = math.min(self.vy + 500 * dt, 220)
    if self.onGround then
      self.vx = U.approach(self.vx, 0, 300 * dt)
    end
  end
  PH.move(self, self.vx * dt, self.vy * dt)
  if self.hitWall then self.vx = -self.vx * 0.4 end

  -- collect
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle
      and U.aabb(self.x - 2, self.y - 2, self.w + 4, self.h + 4, p.x, p.y, p.w, p.h) then
      self:collect(p, World)
      return
    end
  end
end

function Pickup:collect(p, World)
  self.dead = true
  if self.sub == "shard" then
    G.run.scrap = G.run.scrap + 1
    if G.Audio then G.Audio.sfx("shard") end
  elseif self.sub == "bigshard" then
    G.run.scrap = G.run.scrap + 4
    if G.Audio then G.Audio.sfx("bigshard") end
  elseif self.sub == "heart" then
    p:heal(3)
    if G.Audio then G.Audio.sfx("heart") end
  elseif self.sub == "scrap" then
    G.run.scrap = G.run.scrap + 1
    if G.Audio then G.Audio.sfx("scrap") end
  elseif self.sub == "energy" then
    local lu = luOf(World)
    if lu then
      lu.energy = math.min(lu.maxenergy, lu.energy + Pickup.EN_VALUE)
    end
    if G.Audio then G.Audio.sfx("shard") end
  end
  World:fx("spark", self.x + 3, self.y + 3,
    { color = self.sub == "heart" and "blood"
      or self.sub == "scrap" and "gold"
      or self.sub == "energy" and "lublue" or "spark", n = 4 })
end

function Pickup:draw()
  local g = love.graphics
  local cx, cy = self.x + 3, self.y + 3 + math.sin(G.time * 5 + self.bob) * 1
  local blink = self.life < 2 and math.floor(self.life * 8) % 2 == 0
  if blink then return end
  if self.sub == "shard" then
    g.setColor(P.gold)
    g.polygon("fill", cx, cy - 3, cx + 3, cy, cx, cy + 3, cx - 3, cy)
    g.setColor(P.cream)
    g.polygon("fill", cx, cy - 1.5, cx + 1.5, cy, cx, cy + 1.5, cx - 1.5, cy)
  elseif self.sub == "bigshard" then
    g.setColor(P.ember)
    g.polygon("fill", cx, cy - 4.5, cx + 4, cy, cx, cy + 4.5, cx - 4, cy)
    g.setColor(P.gold)
    g.polygon("fill", cx, cy - 2.5, cx + 2, cy, cx, cy + 2.5, cx - 2, cy)
  elseif self.sub == "heart" then
    g.setColor(P.blood)
    g.circle("fill", cx - 1.5, cy - 1, 2)
    g.circle("fill", cx + 1.5, cy - 1, 2)
    g.polygon("fill", cx - 3.4, cy - 0.5, cx + 3.4, cy - 0.5, cx, cy + 3.5)
    g.setColor(P.pink)
    g.circle("fill", cx - 1.5, cy - 1.2, 0.8)
  elseif self.sub == "energy" then
    -- the same diamond as a gold shard, in Lu's blue. Two colours, one
    -- silhouette: you read WHOSE it is before you read what it is.
    g.setColor(P.lublue)
    g.polygon("fill", cx, cy - 3, cx + 3, cy, cx, cy + 3, cx - 3, cy)
    g.setColor(P.spark)
    g.polygon("fill", cx, cy - 1.5, cx + 1.5, cy, cx, cy + 1.5, cx - 1.5, cy)
  elseif self.sub == "scrap" then
    g.setColor(P.silver)
    g.circle("fill", cx, cy, 3)
    g.setColor(P.slate)
    g.circle("line", cx, cy, 3)
    g.setColor(P.gray)
    g.circle("fill", cx, cy, 1.2)
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- Life capsule (permanent, flag-gated): spec = capsule:<flagname>
-- ------------------------------------------------------------------
local Capsule = Entity.extend()

function Capsule:init(x, y, parts)
  Entity.init(self, x + 2, y + 2)
  self.kind = "capsule"
  self.w, self.h = 12, 12
  self.flag = parts[2] or ("capsule_" .. x .. "_" .. y)
  self.tank = parts[1] == "tank"
  self.layer = 2
end

function Capsule:update(dt)
  local World = require "src.world"
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle
      and U.aabb(self.x, self.y, self.w, self.h, p.x, p.y, p.w, p.h) then
      self.dead = true
      G.run.flags[self.flag] = true
      -- v2.0: capsules and tanks are FORGE CORES -- they unlock the next
      -- purchasable tier at Brassa's forge instead of granting stats.
      -- Finding one still tops you up as a thank-you.
      if self.tank then
        G.run.tanks = (G.run.tanks or 0) + 1
        for _, pl in ipairs(World.players) do
          if not pl.isVess then pl.energy = pl.maxenergy end
        end
        if G.game then
          G.game:announce("ENERGY TANK CELL! Brassa can forge it into +"
            .. Up.EN_PER_TIER .. " max energy.", 3)
        end
      else
        G.run.capsules = (G.run.capsules or 0) + 1
        for _, pl in ipairs(World.players) do
          if not pl.dead then pl.hp = pl.maxhp end
        end
        if G.game then
          G.game:announce("LIFE CAPSULE CORE! Brassa can forge it into +"
            .. Up.HP_PER_TIER .. " max HP.", 3)
        end
      end
      if G.Audio then G.Audio.sfx("capsule") end
      World:fx("burst", self.x + 6, self.y + 6, { color = "gold", n = 14 })
      return
    end
  end
end

function Capsule:draw()
  local g = love.graphics
  local cx, cy = self.x + 6, self.y + 6 + math.sin(G.time * 3) * 1.5
  local main = self.tank and P.cyan or P.ember
  local hi = self.tank and P.spark or P.gold
  g.setColor(P.dark)
  g.rectangle("fill", cx - 5, cy - 7, 10, 14, 3, 3)
  g.setColor(main)
  g.rectangle("fill", cx - 4, cy - 6, 8, 12, 3, 3)
  g.setColor(hi)
  g.rectangle("fill", cx - 3, cy - 5, 3, 4)
  g.setColor(P.white)
  local pulse = 0.5 + math.sin(G.time * 6) * 0.5
  g.setColor(1, 1, 1, pulse * 0.6)
  g.circle("line", cx, cy, 8 + pulse * 2)
  g.setColor(1, 1, 1, 1)
end

Entity.register("capsule", function(x, y, parts)
  local flag = parts[2] or ("capsule_" .. x .. "_" .. y)
  if G.run and G.run.flags[flag] then return true end -- already taken
  return Capsule.new(x, y, parts)
end)

Entity.register("tank", function(x, y, parts)
  parts[1] = "tank"
  local flag = parts[2] or ("tank_" .. x .. "_" .. y)
  parts[2] = flag
  if G.run and G.run.flags[flag] then return true end
  return Capsule.new(x, y, parts)
end)

-- ------------------------------------------------------------------
-- ENERGY CELL: spec = cell[:<percent 0..1>]
-- ------------------------------------------------------------------
-- A wall cell Lu drains. It is deliberately none of the three things it
-- could have been:
--
--   not a CAPSULE  -- it is not permanent and it grants no upgrade
--   not a HEART    -- it is not random, it is placed, and you can plan
--                     a route around one
--   not a REGEN    -- it does not happen to you; you go and get it
--
-- AND IT REFRESHES PER ZONE, NOT PER ROOM. Room-scoped makes it a grind
-- you are obliged to farm -- step out, step back, drain it again, every
-- time, forever. Run-scoped makes it a one-shot you are punished for
-- spending early. Zone-scoped is the only one of the three that is a
-- decision: a cell is a resource you plan a zone around, cannot farm,
-- and feel refill as you arrive somewhere new.
--
-- World:load owns the reset (G.run.usedCells) because every way of
-- changing rooms goes through it -- doors, teleport pads, respawn, and
-- loading a save.
local Cell = Entity.extend()
Cell.PERCENT = 0.5           -- of Lu's MAX energy, so it scales with her tank

-- ------------------------------------------------------------------
-- ZONE-SCOPED CONSUMPTION
-- ------------------------------------------------------------------
-- A cell rebuilds itself every time the room loads, so an ungated one is
-- an infinite farm: walk out, walk back, full again, forever. It pays
-- out once per visit to the ZONE instead. Room-scoped is that farm;
-- run-scoped is a one-shot you regret spending. World:load clears the
-- table on a zone change and nowhere else.
--
-- Kept as module functions rather than a local because a checkpoint
-- briefly shared this rule. It does not any more -- a lantern hands out
-- nothing at all -- but the split is the right shape for whatever wants
-- it next.
function Pickup.zoneKey(x, y)
  local World = require "src.world"
  local rid = (World.room and World.room.id) or "?"
  return rid .. ":" .. math.floor(x) .. "," .. math.floor(y)
end

function Pickup.zoneTaken(key)
  return G.run ~= nil and (G.run.usedCells or {})[key] == true
end

function Pickup.zoneTake(key)
  if not G.run then return end
  G.run.usedCells = G.run.usedCells or {}
  G.run.usedCells[key] = true
end

local cellKey = Pickup.zoneKey

function Cell:init(x, y, parts)
  Entity.init(self, x + 2, y + 4)
  self.kind = "cell"
  self.w, self.h = 12, 12
  self.pct = tonumber(parts and parts[2]) or Cell.PERCENT
  self.key = cellKey(x, y)
  self.layer = 2
end

function Cell:update(dt)
  local World = require "src.world"
  local lu = luOf(World)
  if not lu or lu.dead then return end
  -- Full already? Leave it on the wall. Draining a cell you did not need
  -- is a mistake the room should not let you make by walking.
  if lu.energy >= lu.maxenergy then return end
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle
      and U.aabb(self.x, self.y, self.w, self.h, p.x, p.y, p.w, p.h) then
      self.dead = true
      Pickup.zoneTake(self.key)
      lu.energy = math.min(lu.maxenergy,
        lu.energy + lu.maxenergy * self.pct)
      if G.Audio then G.Audio.sfx("capsule") end
      World:fx("burst", self.x + 6, self.y + 6, { color = "lublue", n = 12 })
      if G.game then G.game:announce("ENERGY CELL DRAINED", 1.2) end
      return
    end
  end
end

function Cell:draw()
  local g = love.graphics
  local cx, cy = self.x + 6, self.y + 6
  local pulse = 0.5 + math.sin(G.time * 4) * 0.5
  -- a bracket bolted to the wall, with a cell seated in it
  g.setColor(P.dark)
  g.rectangle("fill", cx - 6, cy - 7, 12, 14, 2, 2)
  g.setColor(P.slate)
  g.rectangle("fill", cx - 6, cy - 7, 12, 2)
  g.rectangle("fill", cx - 6, cy + 5, 12, 2)
  g.setColor(P.lublue)
  g.rectangle("fill", cx - 3, cy - 4, 6, 9, 1, 1)
  g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.45 + pulse * 0.55)
  g.rectangle("fill", cx - 2, cy - 3 + (1 - pulse) * 5, 4, 3 + pulse * 3)
  g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse * 0.35)
  g.circle("line", cx, cy, 8 + pulse * 3)
  g.setColor(1, 1, 1, 1)
end

Entity.register("cell", function(x, y, parts)
  -- zone-scoped, so this asks G.run.usedCells rather than G.run.flags.
  -- Returning true means "already taken, do not spawn", exactly as the
  -- capsule does for a permanent one.
  if Pickup.zoneTaken(Pickup.zoneKey(x, y)) then return true end
  return Cell.new(x, y, parts)
end)

Pickup.Capsule = Capsule
Pickup.Cell = Cell
return Pickup
