-- Projectiles for both sides. Visuals are code-drawn per kind.
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"

local T = 16
local Proj = Entity.extend()

-- cfg: side("player"/"enemy"), dmg, vx, vy, life, pierce, size, kind,
--      gravity, homing, owner (player entity for xp credit), breaksTiles
function Proj.spawn(world, x, y, cfg)
  local p = Proj.new(x, y, cfg)
  world:add(p)
  return p
end

function Proj:init(x, y, cfg)
  Entity.init(self, x, y)
  self.kind = "proj"
  self.side = cfg.side or "enemy"
  self.dmg = cfg.dmg or 1
  self.vx = cfg.vx or 0
  self.vy = cfg.vy or 0
  self.life = cfg.life or 2
  self.pierce = cfg.pierce or 0
  self.size = cfg.size or 4
  self.w, self.h = self.size, self.size
  self.x, self.y = x - self.w / 2, y - self.h / 2
  self.visual = cfg.kind or "bolt"
  self.grav = cfg.gravity or 0
  self.homing = cfg.homing
  self.owner = cfg.owner
  self.breaksTiles = cfg.breaksTiles ~= false and self.side == "player"
  self.hitList = {}
  self.link = cfg.link  -- fired by the LINK blast (breaks link-cores)
  self.chill = cfg.chill  -- freezing shot: briefly slows the target's fire rate
  self.layer = 5
  self.trailT = 0
  self.bounces = cfg.bounces or 0
end

function Proj:update(dt)
  local World = require "src.world"
  self.life = self.life - dt
  if self.life <= 0 then self.dead = true return end

  self.vy = self.vy + self.grav * dt

  if self.homing then
    local target
    if self.side == "player" then
      local best, bd
      for _, e in ipairs(World.entities) do
        if e.kind == "enemy" and not e.dead then
          local d = U.dist2(self.x, self.y, e.x + e.w / 2, e.y + e.h / 2)
          if d < 120 * 120 and (not bd or d < bd) then best, bd = e, d end
        end
      end
      target = best
    else
      target = World:nearestPlayer(self.x, self.y)
    end
    if target then
      local cx, cy = self.x + self.w / 2, self.y + self.h / 2
      local txx, tyy = target.x + target.w / 2, target.y + target.h / 2
      local ang = math.atan2(tyy - cy, txx - cx)
      local sp = math.sqrt(self.vx * self.vx + self.vy * self.vy)
      local cur = math.atan2(self.vy, self.vx)
      local diff = U.angleDiff(cur, ang)
      local turn = (self.homing or 2) * dt
      cur = cur + U.clamp(diff, -turn, turn)
      self.vx, self.vy = math.cos(cur) * sp, math.sin(cur) * sp
    end
  end

  local nx = self.x + self.vx * dt
  local ny = self.y + self.vy * dt

  -- tile collision (point check at center)
  local cx, cy = nx + self.w / 2, ny + self.h / 2
  local tx, ty = math.floor(cx / T), math.floor(cy / T)
  if World:isSolid(tx, ty, self) then
    if self.breaksTiles and World:breakTile(tx, ty) then
      -- continue through broken tile
    elseif self.bounces > 0 then
      self.bounces = self.bounces - 1
      -- crude bounce: flip the dominant axis
      if math.abs(self.vx) > math.abs(self.vy) then self.vx = -self.vx
      else self.vy = -self.vy end
      nx, ny = self.x, self.y
    else
      World:fx("spark", cx, cy, { color = self.side == "player" and "ember" or "blood",
        angle = math.atan2(-self.vy, -self.vx) })
      self.dead = true
      return
    end
  end
  self.x, self.y = nx, ny

  -- trail
  self.trailT = self.trailT - dt
  if self.trailT <= 0 then
    self.trailT = 0.03
    local col = self.visual == "spark" and "spark"
      or self.visual == "lance" and "orchid"
      or self.side == "enemy" and "blood" or "ember"
    if self.visual ~= "pellet" then
      World:fx("trail", cx, cy, { color = col, r = self.size >= 6 and 2 or 1.5, t = 0.12 })
    end
  end

  -- target collision
  if self.side == "player" then
    for _, e in ipairs(World.entities) do
      if e.kind == "enemy" and not e.dead and not self.hitList[e]
        and U.aabb(self.x, self.y, self.w, self.h, e.x, e.y, e.w, e.h) then
        local hurt = e:hurt(self.dmg, self.x, self.y,
          { owner = self.owner, link = self.link })
        if hurt ~= false then
          self.hitList[e] = true
          World:fx("spark", cx, cy, { color = "gold", angle = math.atan2(-self.vy, -self.vx) })
          if G.Audio then G.Audio.sfx("hitenemy") end
          if self.pierce <= 0 then self.dead = true return end
          self.pierce = self.pierce - 1
        end
      end
    end
  else
    for _, p in ipairs(World.players) do
      if not p.dead and not p.downed and not p.idle and p.invuln <= 0
        and U.aabb(self.x, self.y, self.w, self.h, p.x, p.y, p.w, p.h) then
        p:takeDamage(self.dmg, self.x + self.w / 2)
        if self.chill then
          p.chilledT = 2.5
          World:fx("burst", p.x + p.w / 2, p.y + 4, { color = "ice", n = 6 })
        end
        self.dead = true
        return
      end
    end
    -- Lu's shield dome eats enemy projectiles
    for _, p in ipairs(World.players) do
      if p.domeActive and not p.dead and not p.downed then
        local dx = cx - (p.x + p.w / 2)
        local dy = cy - (p.y + p.h / 2 - 4)
        if dx * dx + dy * dy < p.domeRadius * p.domeRadius then
          p:domeAbsorb(self.dmg)
          World:fx("spark", cx, cy, { color = "cyan", angle = math.atan2(-self.vy, -self.vx), n = 7 })
          if G.Audio then G.Audio.sfx("domehit") end
          self.dead = true
          return
        end
      end
    end
  end
end

function Proj:draw()
  local g = love.graphics
  local cx, cy = self.x + self.w / 2, self.y + self.h / 2
  local v = self.visual
  if v == "bolt" then
    g.setColor(P.gold)
    local ang = math.atan2(self.vy, self.vx)
    g.push() g.translate(cx, cy) g.rotate(ang)
    g.rectangle("fill", -4, -1.5, 8, 3)
    g.setColor(P.cream)
    g.rectangle("fill", 0, -1, 4, 2)
    g.pop()
  elseif v == "pellet" then
    g.setColor(P.ember)
    g.circle("fill", cx, cy, 2)
    g.setColor(P.cream)
    g.circle("fill", cx, cy, 1)
  elseif v == "lance" then
    local ang = math.atan2(self.vy, self.vx)
    g.push() g.translate(cx, cy) g.rotate(ang)
    g.setColor(P.plum)
    g.rectangle("fill", -10, -2.5, 20, 5)
    g.setColor(P.orchid)
    g.rectangle("fill", -8, -1.5, 18, 3)
    g.setColor(P.white)
    g.rectangle("fill", 2, -0.5, 8, 1)
    g.pop()
  elseif v == "spark" then
    g.setColor(P.cyan)
    g.circle("fill", cx, cy, 2.2)
    g.setColor(P.spark)
    g.circle("fill", cx, cy, 1.2)
  elseif v == "orb" then
    g.setColor(P.blood)
    g.circle("fill", cx, cy, self.size / 2 + 1)
    g.setColor(P.pink)
    g.circle("fill", cx, cy, self.size / 2 - 1)
  elseif v == "fireball" then
    g.setColor(P.magma)
    g.circle("fill", cx, cy, self.size / 2 + 1)
    g.setColor(P.hotcore)
    g.circle("fill", cx, cy, self.size / 2 - 1)
  elseif v == "shard" then
    g.setColor(P.orchid)
    local ang = math.atan2(self.vy, self.vx)
    g.push() g.translate(cx, cy) g.rotate(ang)
    g.polygon("fill", 5, 0, -4, -3, -4, 3)
    g.setColor(P.spark)
    g.polygon("fill", 3, 0, -2, -1.5, -2, 1.5)
    g.pop()
  elseif v == "drop" then
    g.setColor(P.water)
    g.circle("fill", cx, cy, 2.5)
    g.setColor(P.ice)
    g.circle("fill", cx, cy - 0.5, 1)
  else
    g.setColor(P.white)
    g.circle("fill", cx, cy, self.size / 2)
  end
  g.setColor(1, 1, 1, 1)
end

Entity.register("proj", function(x, y) return Proj.new(x, y, {}) end)

return Proj
