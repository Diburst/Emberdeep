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

-- ==================================================================
-- ENERGY WEAPON (shared by bosses and enemies)
-- ==================================================================
-- Anti-shield ordnance. A normal shot that meets Lu's dome is politely
-- absorbed at the dome's forge-tier discount (Player:domeAbsorb), which
-- is what makes holding the dome up so cheap. An energy dart instead
-- bites a FLAT chunk out of her reserve via Player:domeDrain -- no
-- discount, no scaling with tier. Enough of them collapse the dome
-- outright and the rest arrive at a body with nothing in front of it.
--
-- Proj.energyDart(world, x, y, targetX, targetY, { speed, drain, dmg })
function Proj.energyDart(world, x, y, tx, ty, cfg)
  cfg = cfg or {}
  local ang = math.atan2(ty - y, tx - x)
  local sp = cfg.speed or 460
  return Proj.spawn(world, x, y, {
    side = "enemy", kind = "ionbolt", size = cfg.size or 5,
    dmg = cfg.dmg or 3,
    drain = cfg.drain or 26,        -- flat energy bitten out of a dome
    vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
    life = cfg.life or 2.5,
  })
end

-- A shell landing slower than this settles onto the floor and rolls;
-- faster and it bounces. ROLL_FRICTION is per second, and ROLL_STOP is
-- where a roll has run out of road.
local ROLL_SETTLE  = 150
local ROLL_FRICTION = 0.9
local ROLL_STOP    = 24

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
  -- anti-shield round: a flat energy bite out of a dome instead of the
  -- usual tier-discounted absorb (see Proj.energyDart above)
  self.drain = cfg.drain
  self.layer = 5
  self.trailT = 0
  self.bounces = cfg.bounces or 0
  -- BOUNCE AND ROLL. `bounces` is how many surfaces a shell survives;
  -- `restitution` is how much speed it keeps off each one; `rolls` lets
  -- it settle onto a floor it lands on gently and run along it instead
  -- of dying there. Rolling does NOT spend a bounce -- a shell that
  -- rolls the length of a corridor is the whole point of the weapon,
  -- and charging it per tile would end the roll in three feet.
  self.restitution = cfg.restitution or 0.5
  self.rolls = cfg.rolls
  self.rolling = false
end

function Proj:update(dt)
  local World = require "src.world"
  self.life = self.life - dt
  if self.life <= 0 then
    -- Running out of road is a DIFFERENT event from hitting something,
    -- and it has to look different or a shot that fell short reads as a
    -- shot that missed. A short sputter where it died is the whole tell.
    self.dead = true
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = self.side == "player" and "spark" or "ember", n = 3, r = 1 })
    return
  end

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
    -- PASS THE CAPABILITY. breakTile takes a `with` and this passed
    -- nothing, so a hard tile refused every projectile in the game --
    -- including the LINK nova, which is the one thing meant to open the
    -- lattice. Vess's dash was the only caller that ever supplied it.
    if self.breaksTiles
       and World:breakTile(tx, ty, self.link and "linkblast" or nil) then
      -- continue through broken tile
    elseif self.bounces > 0 or self.rolls then
      -- WHICH WALL DID IT HIT? The old code flipped whichever axis was
      -- moving faster, which sends a shell falling onto a floor sideways
      -- into the wall it never touched. Test the two steps separately.
      local hx = World:isSolid(math.floor((nx + self.w / 2) / T),
                               math.floor((self.y + self.h / 2) / T), self)
      local hy = World:isSolid(math.floor((self.x + self.w / 2) / T),
                               math.floor((ny + self.h / 2) / T), self)
      if not hx and not hy then hy = true end     -- clipped a corner
      local spent = false
      if hy then
        -- LANDING. Gently enough and it settles and runs along the floor
        -- instead of dying on it.
        if self.rolls and self.vy > 0 and self.vy < ROLL_SETTLE then
          self.vy = 0
          self.rolling = true
        else
          self.vy = -self.vy * self.restitution
          spent = true
          if math.abs(self.vy) < ROLL_SETTLE and self.rolls then
            self.vy = 0
            self.rolling = true
          end
        end
        ny = self.y
      end
      if hx then
        self.vx = -self.vx * self.restitution
        spent = true
        nx = self.x
      end
      if spent then
        self.bounces = self.bounces - 1
        World:fx("spark", cx, cy, { color = self.side == "player" and "ember" or "ice",
          n = 3 })
        if G.Audio then G.Audio.sfx("crack") end
      end
      if self.bounces < 0 and not self.rolling then
        self.dead = true
        return
      end
    else
      World:fx("spark", cx, cy, { color = self.side == "player" and "ember" or "blood",
        angle = math.atan2(-self.vy, -self.vx) })
      self.dead = true
      return
    end
  elseif self.rolling then
    -- ran off the end of the floor it was rolling along
    self.rolling = false
  end
  self.x, self.y = nx, ny

  -- ROLLING. Gravity is held off while it is supported, friction eats
  -- the roll, and it dies when it finally stops rather than sitting on
  -- the floor as a permanent trap.
  if self.rolling then
    local under = World:isSolid(math.floor((self.x + self.w / 2) / T),
                                math.floor((self.y + self.h + 1) / T), self)
    if under then
      self.vy = 0
      self.vx = self.vx * (1 - ROLL_FRICTION * dt)
      if math.abs(self.vx) < ROLL_STOP then
        World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
          { color = "ember", n = 6 })
        self.dead = true
        return
      end
    else
      self.rolling = false
    end
  end

  -- ------------------------------------------------------------
  -- MIRRORS bend shots, not just beams.
  --
  -- A round that leaves a mirror changes SIDES: the Conductor's own
  -- cache flush is the clearest case -- the only thing that hurts it
  -- during a flush is its own light, turned back on it off the arena's
  -- panels. `refracted` is what the boss checks; without it the flush
  -- would be four seconds of standing still again.
  -- ------------------------------------------------------------
  if not self.noRefract then
    local mtx, mty = math.floor((self.x + self.w / 2) / T),
                     math.floor((self.y + self.h / 2) / T)
    if mtx ~= self.lastMTx or mty ~= self.lastMTy then
      self.lastMTx, self.lastMTy = mtx, mty
      for _, e in ipairs(World.entities) do
        if e.beamMirror and not e.dead and e ~= self.lastMirror then
          local ex, ey = math.floor((e.x + e.w / 2) / T), math.floor((e.y + e.h / 2) / T)
          if ex == mtx and ey == mty then
            self.lastMirror = e
            local sp = math.sqrt(self.vx * self.vx + self.vy * self.vy)
            -- 1 right, 2 down, 3 left, 4 up -- the same table the beam
            -- tracer uses, so a shot and a beam bend the same way
            local dir = math.abs(self.vx) > math.abs(self.vy)
              and (self.vx > 0 and 1 or 3) or (self.vy > 0 and 2 or 4)
            local out = (e.mirror == "b") and ({ 2, 1, 4, 3 })[dir]
                                          or ({ 4, 3, 2, 1 })[dir]
            local dx = ({ 1, 0, -1, 0 })[out]
            local dy = ({ 0, 1, 0, -1 })[out]
            self.vx, self.vy = dx * sp, dy * sp
            self.grav = 0
            self.refracted = true
            if self.side == "enemy" then self.side = "player" end
            World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
              { color = "ice", n = 5 })
            break
          end
        end
      end
    end
  end

  -- trail
  self.trailT = self.trailT - dt
  if self.trailT <= 0 then
    self.trailT = 0.03
    local col = self.visual == "spark" and "spark"
      or self.visual == "lance" and "orchid"
      or self.visual == "ionbolt" and "sky"
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
        -- DIRECTIONAL SHIELDS get asked before the damage pass, and a shot
        -- they stop is destroyed here. Declining the damage is not enough:
        -- an un-consumed round keeps travelling, crosses the body's midline
        -- next frame, and lands as if it had come from behind.
        if e.deflects and e:deflects(self.x, self.y,
            { owner = self.owner, link = self.link }) then
          World:fx("spark", cx, cy,
            { color = "gold", angle = math.atan2(-self.vy, -self.vx), n = 5 })
          if G.Audio then G.Audio.sfx("deflect") end
          self.dead = true
          return
        end
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
    -- BULWARK: Vess's plate DEFLECTS a shot instead of letting it sail
    -- harmlessly through him and on into Lu. Runs before the damage pass
    -- and ignores invuln, because a deflect is not a hit -- it is the
    -- co-op verb the plate exists for.
    for _, p in ipairs(World.players) do
      if not p.dead and not p.downed and not p.idle and p.plateBlocks
        and U.aabb(self.x, self.y, self.w, self.h, p.x, p.y, p.w, p.h)
        and p:plateBlocks(cx) then
        p:onPlateBlock(cx, cy)
        World:fx("spark", cx, cy,
          { color = "vesslite", angle = math.atan2(-self.vy, -self.vx), n = 6 })
        self.dead = true
        return
      end
    end
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
          if self.drain then
            p:domeDrain(self.drain)
            World:fx("burst", cx, cy, { color = "ice", n = 12, speed = 130 })
          else
            p:domeAbsorb(self.dmg)
            World:fx("spark", cx, cy,
              { color = "cyan", angle = math.atan2(-self.vy, -self.vx), n = 7 })
          end
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
  elseif v == "ionbolt" then
    -- anti-shield lance: cold blue, white-hot core, unmistakably not a bullet
    local ang = math.atan2(self.vy, self.vx)
    g.push() g.translate(cx, cy) g.rotate(ang)
    g.setColor(P.water[1], P.water[2], P.water[3], 0.55)
    g.rectangle("fill", -11, -3, 22, 6)
    g.setColor(P.cyan)
    g.rectangle("fill", -8, -1.5, 17, 3)
    g.setColor(P.ice)
    g.rectangle("fill", -3, -1, 11, 2)
    g.setColor(P.white)
    g.rectangle("fill", 3, -0.5, 6, 1)
    g.pop()
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
