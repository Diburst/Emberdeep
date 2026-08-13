-- Pickups: weapon-energy shards, hearts, scrap, plus map-placed
-- life capsules / energy tanks (flag-gated, permanent).
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"

local Pickup = Entity.extend()

-- kind: shard (val 1), bigshard (5), heart (3 hp), scrap (1)
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
  if target and self.magnetDelay <= 0 and dist < 80 then
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
  end
  World:fx("spark", self.x + 3, self.y + 3,
    { color = self.sub == "heart" and "blood" or self.sub == "scrap" and "gold" or "spark", n = 4 })
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
          G.game:announce("ENERGY TANK CELL! Brassa can forge it into +20 max energy.", 3)
        end
      else
        G.run.capsules = (G.run.capsules or 0) + 1
        for _, pl in ipairs(World.players) do
          if not pl.dead then pl.hp = pl.maxhp end
        end
        if G.game then
          G.game:announce("LIFE CAPSULE CORE! Brassa can forge it into +4 max HP.", 3)
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

Pickup.Capsule = Capsule
return Pickup
