-- All standard enemy types. Each registers as an entity spawnable from maps.
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"
local Proj = require "src.entities.projectile"
local Pickup = require "src.entities.pickup"

local T = 16
local Enemy = Entity.extend()

function Enemy:init(x, y, def)
  Entity.init(self, x, y)
  self.kind = "enemy"
  local hpMult = ({ 0.75, 1, 1.3 })[G.run and G.run.difficulty or 2] or 1
  self.maxhp = math.max(1, math.floor((def.hp or 3) * hpMult + 0.5))
  self.hp = self.maxhp
  self.touchDmg = def.touchDmg or 2
  self.drops = def.drops or { shards = 2, heart = 0.12, scrap = 0.08 }
  self.sprite = def.sprite
  self.animRate = def.animRate or 4
  self.w = def.w or 12
  self.h = def.h or 12
  self.facing = U.chance(0.5) and 1 or -1
  self.t = U.rand(0, 3)
  self.buffed = 0
end

function Enemy:onHurt(dmg, srcx)
  if srcx and not self.noKnockback then
    self.vx = (self.vx or 0) + U.sign(self.x - srcx) * 40
  end
end

function Enemy:onDeath()
  local World = require "src.world"
  local cx, cy = self:center()
  World:fx("burst", cx, cy, { color = self.deathColor or "ember", n = 10 })
  if G.Audio then G.Audio.sfx("enemydie") end
  local d = self.drops
  Pickup.drop(World, cx, cy, "shard", d.shards or 2)
  if U.chance(d.big or 0.1) then Pickup.drop(World, cx, cy, "bigshard", 1) end
  local heartChance = d.heart or 0.12
  -- pity: more hearts when players are hurting
  local hurtFrac = 0
  for _, p in ipairs(World.players) do
    if not p.dead then hurtFrac = math.max(hurtFrac, 1 - p.hp / p.maxhp) end
  end
  if U.chance(heartChance + hurtFrac * 0.2) then
    Pickup.drop(World, cx, cy, "heart", 1)
  end
  if U.chance(d.scrap or 0.08) then Pickup.drop(World, cx, cy, "scrap", 1) end
end

function Enemy:animFrame()
  return math.floor(self.t * self.animRate) % 2 + 1
end

function Enemy:drawSprite(opts)
  opts = opts or {}
  opts.flip = self.facing < 0
  opts.white = math.max(0, (self.white or 0) * 6)
  G.drawSprite(self.sprite, self:animFrame(), self.x + self.w / 2,
    self.y + self.h + 0.5, opts)
end

function Enemy:draw()
  self:drawSprite()
end

-- helper: grounded patrol; turns at walls and ledges
function Enemy:patrol(dt, speed)
  self.vy = math.min((self.vy or 0) + 830 * dt, 300)
  self.vx = self.facing * speed
  PH.move(self, self.vx * dt, self.vy * dt)
  if self.hitWall ~= false and self.hitWall then self.facing = -self.hitWall end
  if self.onGround then
    -- ledge check
    local aheadX = self.facing > 0 and (self.x + self.w + 2) or (self.x - 2)
    local tx = math.floor(aheadX / T)
    local ty = math.floor((self.y + self.h + 4) / T)
    local World = require "src.world"
    if not World:isSolid(tx, ty) and not World:isOneway(tx, ty) then
      self.facing = -self.facing
    end
  end
end

function Enemy:speedMult()
  return self.buffed > 0 and 1.5 or 1
end

local function reg(name, def, updateFn, drawFn)
  local C = Enemy.extend()
  C.init = function(self, x, y)
    Enemy.init(self, x, y, def)
    if def.init then def.init(self) end
  end
  C.update = function(self, dt)
    self.t = self.t + dt
    if self.buffed > 0 then self.buffed = self.buffed - dt end
    updateFn(self, dt)
  end
  if drawFn then C.draw = drawFn end
  if def.onDeathExtra then
    local base = Enemy.onDeath
    C.onDeath = function(self)
      base(self)
      def.onDeathExtra(self)
    end
  end
  Entity.register(name, function(x, y) return C.new(x, y) end)
  return C
end

local function playerNear(self, range)
  local World = require "src.world"
  local p, d = World:nearestPlayer(self:center())
  if p and d < range then return p, d end
  return nil
end

-- ==================================================================
-- MOSSWOOD
-- ==================================================================
reg("gnat", { hp = 2, touchDmg = 1, sprite = "en_gnat", w = 10, h = 8,
  drops = { shards = 1, heart = 0.1 }, deathColor = "leaf", animRate = 12 },
  function(self, dt)
    -- lazy sine drift; chases when player near
    local p = playerNear(self, 90)
    local sp = 42 * self:speedMult()
    if p then
      local cx, cy = self:center()
      local px, py = p:center()
      self.vx = U.approach(self.vx or 0, U.sign(px - cx) * sp, 120 * dt)
      self.vy = U.approach(self.vy or 0, U.sign(py - cy) * sp * 0.8, 100 * dt)
      self.facing = (self.vx or 0) >= 0 and 1 or -1
    else
      self.vx = math.cos(self.t * 1.5) * 20
      self.vy = math.sin(self.t * 3) * 14
    end
    PH.move(self, self.vx * dt, self.vy * dt)
  end)

reg("hopper", { hp = 4, touchDmg = 2, sprite = "en_hopper", w = 12, h = 10,
  deathColor = "leaf" },
  function(self, dt)
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    if self.onGround then
      self.vx = 0
      self.hopT = (self.hopT or U.rand(0.8, 1.6)) - dt
      if self.hopT <= 0 then
        self.hopT = U.rand(1.1, 1.9) / self:speedMult()
        local p = playerNear(self, 130)
        if p then self.facing = U.sign(p.x - self.x) end
        self.vy = -230
        self.vx = self.facing * 85
        if math.abs(self.vx) < 1 then self.vx = self.facing * 85 end
      end
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall end
  end)

reg("spitter", { hp = 5, touchDmg = 2, sprite = "en_spitter", w = 12, h = 14,
  drops = { shards = 3, heart = 0.15 }, deathColor = "leaf", animRate = 2 },
  function(self, dt)
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    PH.move(self, 0, self.vy * dt)
    self.spitT = (self.spitT or U.rand(1, 2)) - dt
    local p = playerNear(self, 140)
    if p then self.facing = U.sign(p.x + p.w / 2 - self.x - self.w / 2) end
    if self.spitT <= 0 then
      self.spitT = 2.2 / self:speedMult()
      if p then
        local World = require "src.world"
        local cx, cy = self.x + self.w / 2, self.y + 2
        local px, py = p:center()
        local dx = px - cx
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = 2, kind = "orb", size = 5,
          vx = U.clamp(dx * 1.2, -110, 110), vy = -170,
          gravity = 300, life = 2.5,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("rollpede", { hp = 6, touchDmg = 3, sprite = "en_rollpede", w = 14, h = 10,
  drops = { shards = 3, scrap = 0.12 }, deathColor = "moss", animRate = 8 },
  function(self, dt)
    self:patrol(dt, 68 * self:speedMult())
  end)

-- ==================================================================
-- FLOODED WORKS
-- ==================================================================
reg("finfish", { hp = 3, touchDmg = 2, sprite = "en_finfish", w = 14, h = 8,
  deathColor = "sky", animRate = 8 },
  function(self, dt)
    local World = require "src.world"
    -- stays in water; darts at players
    local p = playerNear(self, 110)
    local sp = 90 * self:speedMult()
    if p and p.inWater then
      local cx, cy = self:center()
      local px, py = p:center()
      self.vx = U.approach(self.vx or 0, U.sign(px - cx) * sp, 200 * dt)
      self.vy = U.approach(self.vy or 0, U.sign(py - cy) * sp * 0.7, 160 * dt)
    else
      self.vx = (self.vx and math.abs(self.vx) > 5) and self.vx or (self.facing * 40)
      self.vy = math.sin(self.t * 2.5) * 18
    end
    self.facing = (self.vx or 1) >= 0 and 1 or -1
    local ox, oy = self.x, self.y
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then self.vx = -self.vx self.facing = -self.facing end
    -- don't leave water
    if not self.inWater then
      self.x, self.y = ox, oy
      self.vy = math.abs(self.vy or 20)
      self.vx = -(self.vx or 40)
    end
  end)

reg("bubbler", { hp = 4, touchDmg = 2, sprite = "en_bubbler", w = 12, h = 12,
  deathColor = "ice", animRate = 3 },
  function(self, dt)
    -- bobs; periodically fires slow bubbles upward that pop
    self.vy = math.sin(self.t * 2) * 12
    PH.move(self, 0, self.vy * dt)
    self.shotT = (self.shotT or U.rand(1.5, 2.5)) - dt
    if self.shotT <= 0 then
      self.shotT = 2.8 / self:speedMult()
      local World = require "src.world"
      local p = playerNear(self, 120)
      if p then
        local cx, cy = self:center()
        for i = -1, 1 do
          Proj.spawn(World, cx, cy - 4, {
            side = "enemy", dmg = 1, kind = "drop", size = 5,
            vx = i * 40, vy = -90, gravity = 60, life = 2.2,
          })
        end
        if G.Audio then G.Audio.sfx("splash") end
      end
    end
  end)

reg("crab", { hp = 10, touchDmg = 3, sprite = "en_crab", w = 16, h = 12,
  drops = { shards = 4, scrap = 0.2 }, deathColor = "rust", animRate = 5,
  init = function(self) self.armored = true end },
  function(self, dt)
    self:patrol(dt, 30 * self:speedMult())
  end)
-- crabs take reduced frontal damage: override hurt via class tweak
do
  local CrabClass = Entity.registry["crab"]
  local made = CrabClass
  -- wrap constructor to patch hurt
  Entity.registry["crab"] = function(x, y)
    local c = made(x, y)
    local baseHurt = c.hurt
    c.hurt = function(self, dmg, srcx, srcy, opts)
      if srcx then
        local fromFront = U.sign(srcx - (self.x + self.w / 2)) == self.facing
        if fromFront then
          dmg = math.max(0, dmg - 2)
          if dmg == 0 then
            local World = require "src.world"
            World:fx("spark", self.x + self.w / 2 + self.facing * 8, self.y + 4,
              { color = "silver", n = 3 })
            return false
          end
        end
      end
      return Entity.hurt(self, dmg, srcx, srcy, opts)
    end
    return c
  end
end

reg("depthmine", { hp = 6, touchDmg = 0, sprite = "en_depthmine", w = 12, h = 12,
  drops = { shards = 2 }, deathColor = "magma", animRate = 2,
  onDeathExtra = function(self)
    -- explode: damage everything nearby
    local World = require "src.world"
    local cx, cy = self:center()
    local Cam = require "src.camera"
    Cam.shake(3, 0.25)
    if G.Audio then G.Audio.sfx("explode") end
    World:fx("burst", cx, cy, { color = "magma", n = 18, speed = 150 })
    for _, p in ipairs(World.players) do
      if not p.dead and not p.downed and U.dist(cx, cy, p.x + p.w / 2, p.y + p.h / 2) < 34 then
        p:takeDamage(4, cx)
      end
    end
    -- for _, e in ipairs(World.entities) do
    --   if e.kind == "enemy" and e ~= self and not e.dead then
    --     local ex, ey = e:center()
    --     if U.dist(cx, cy, ex, ey) < 38 then e:hurt(6, cx, cy) end
    --   end
    -- end
  end },
  function(self, dt)
    local p = playerNear(self, 150)
    local sp = 38 * self:speedMult()
    if p then
      local cx, cy = self:center()
      local px, py = p:center()
      self.vx = U.approach(self.vx or 0, U.sign(px - cx) * sp, 70 * dt)
      self.vy = U.approach(self.vy or 0, U.sign(py - cy) * sp, 70 * dt)
      -- proximity fuse
      if U.dist(cx, cy, px, py) < 20 then self:die() end
    else
      -- no idling near the ceiling: sink gently toward hunting depth
      self.vx = U.approach(self.vx or 0, 0, 30 * dt)
      self.vy = U.approach(self.vy or 0, 14 + math.sin(self.t * 1.8) * 8, 60 * dt)
    end
    PH.move(self, (self.vx or 0) * dt, (self.vy or 0) * dt)
  end)

-- ==================================================================
-- FURNACE
-- ==================================================================
reg("cinderbat", { hp = 3, touchDmg = 2, sprite = "en_cinderbat", w = 12, h = 10,
  deathColor = "magma", animRate = 10 },
  function(self, dt)
    -- hangs, then swoops in an arc at players
    if not self.swooping then
      self.vx = math.cos(self.t * 2) * 12
      self.vy = math.sin(self.t * 4) * 8
      local p = playerNear(self, 120)
      if p and U.chance(dt * 0.8) then
        self.swooping = true
        self.swoopT = 0
        local px = p:center()
        self.facing = U.sign(px - self.x)
      end
    else
      self.swoopT = self.swoopT + dt
      local sp = 130 * self:speedMult()
      self.vx = self.facing * sp * 0.8
      self.vy = math.sin(self.swoopT * 5) * sp
      if self.swoopT > 1.2 or self.hitWall then
        self.swooping = false
      end
    end
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall self.swooping = false end
  end)

reg("slagblob", { hp = 7, touchDmg = 3, sprite = "en_slagblob", w = 14, h = 12,
  drops = { shards = 3 }, deathColor = "magma", animRate = 3,
  onDeathExtra = function(self)
    if self.mini then return end
    local World = require "src.world"
    for i = -1, 1, 2 do
      local m = Entity.make("slagblob", self.x + i * 6, self.y)
      m.mini = true
      m.w, m.h = 8, 7
      m.maxhp, m.hp = 2, 2
      m.touchDmg = 2
      m.vx = i * 70
      m.vy = -140
      m.drops = { shards = 1 }
      World:add(m)
    end
  end },
  function(self, dt)
    self.vy = math.min((self.vy or 0) + 700 * dt, 280)
    if self.onGround then
      self.vx = U.approach(self.vx or 0, 0, 200 * dt)
      self.oozT = (self.oozT or U.rand(1, 2)) - dt
      if self.oozT <= 0 then
        self.oozT = 1.6 / self:speedMult()
        local p = playerNear(self, 120)
        if p then self.facing = U.sign(p.x - self.x) end
        self.vy = -150
        self.vx = self.facing * 55
      end
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall end
  end,
  function(self)
    local scale = self.mini and 0.6 or 1
    self:drawSprite({ sx = scale, sy = scale })
  end)

reg("slagling", { hp = 2, touchDmg = 2, sprite = "en_slagling", w = 8, h = 7,
  drops = { shards = 1 }, deathColor = "magma", animRate = 6 },
  function(self, dt)
    -- molten spatter: small, fast, relentless hops at the nearest bot
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    if self.onGround then
      self.vx = 0
      self.hopT = (self.hopT or U.rand(0.2, 0.6)) - dt
      if self.hopT <= 0 then
        self.hopT = U.rand(0.5, 0.9) / self:speedMult()
        local p = playerNear(self, 220)
        if p then self.facing = U.sign(p.x - self.x) ~= 0 and U.sign(p.x - self.x) or self.facing end
        self.vy = -195
        self.vx = self.facing * 105
      end
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall end
  end)

reg("welder", { hp = 5, touchDmg = 2, sprite = "en_welder", w = 12, h = 12,
  drops = { shards = 3, scrap = 0.2 }, deathColor = "ember", animRate = 6 },
  function(self, dt)
    -- hovers at spawn height, strafes, fires 3-round bursts
    self.homeY = self.homeY or self.y
    self.vx = math.cos(self.t * 1.2) * 30
    self.vy = (self.homeY - self.y) * 2 + math.sin(self.t * 3) * 6
    PH.move(self, self.vx * dt, self.vy * dt)
    local p = playerNear(self, 150)
    if p then self.facing = U.sign(p.x - self.x) end
    self.burstT = (self.burstT or U.rand(1.5, 2.5)) - dt
    if self.burstT <= 0 and p then
      self.burstT = 2.4 / self:speedMult()
      self.burstN = 3
      self.burstGap = 0
    end
    if self.burstN and self.burstN > 0 then
      self.burstGap = (self.burstGap or 0) - dt
      if self.burstGap <= 0 then
        self.burstGap = 0.14
        self.burstN = self.burstN - 1
        local World = require "src.world"
        local pp = playerNear(self, 200)
        if pp then
          local cx, cy = self:center()
          local px, py = pp:center()
          local ang = math.atan2(py - cy, px - cx)
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "fireball", size = 5,
            vx = math.cos(ang) * 150, vy = math.sin(ang) * 150, life = 2,
          })
          if G.Audio then G.Audio.sfx("shoot4") end
        end
      end
    end
  end)

reg("shieldbug", { hp = 8, touchDmg = 3, sprite = "en_shieldbug", w = 14, h = 10,
  drops = { shards = 4 }, deathColor = "gold", animRate = 5,
  init = function(self) self.shieldT = 0 end },
  function(self, dt)
    -- periodically becomes invulnerable (glowing shell)
    self.cycleT = (self.cycleT or 0) + dt
    local phase = self.cycleT % 4
    self.shielded = phase > 2.4
    self:patrol(dt, 40 * self:speedMult())
  end,
  function(self)
    self:drawSprite()
    if self.shielded then
      local g = love.graphics
      local cx, cy = self:center()
      g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.5 + math.sin(G.time * 8) * 0.2)
      g.circle("line", cx, cy, 10)
      g.setColor(1, 1, 1, 1)
    end
  end)
do
  local made = Entity.registry["shieldbug"]
  Entity.registry["shieldbug"] = function(x, y)
    local c = made(x, y)
    local baseHurt = c.hurt
    c.hurt = function(self, dmg, srcx, srcy, opts)
      if self.shielded then
        local World = require "src.world"
        World:fx("spark", self.x + self.w / 2, self.y, { color = "gold", n = 3 })
        return false
      end
      return Entity.hurt(self, dmg, srcx, srcy, opts)
    end
    return c
  end
end

-- ==================================================================
-- CRYSTAL
-- ==================================================================
reg("shardling", { hp = 9, touchDmg = 3, sprite = "en_shardling", w = 12, h = 14,
  drops = { shards = 4, big = 0.2 }, deathColor = "orchid", animRate = 4 },
  function(self, dt)
    local p = playerNear(self, 100)
    local sp = (p and 55 or 25) * self:speedMult()
    if p then self.facing = U.sign(p.x - self.x) ~= 0 and U.sign(p.x - self.x) or self.facing end
    self:patrol(dt, sp)
  end)

reg("prismwisp", { hp = 4, touchDmg = 2, sprite = "en_prismwisp", w = 10, h = 10,
  drops = { shards = 3 }, deathColor = "spark", animRate = 6,
  init = function(self) self.noKnockback = true end },
  function(self, dt)
    -- teleports around, fires refracting shards
    self.blinkT = (self.blinkT or U.rand(1.5, 2.5)) - dt
    self.vy = math.sin(self.t * 3) * 10
    PH.move(self, 0, self.vy * dt)
    if self.blinkT <= 0 then
      self.blinkT = 2.2 / self:speedMult()
      local World = require "src.world"
      World:fx("burst", self.x + 5, self.y + 5, { color = "orchid", n = 6 })
      -- teleport to a nearby air tile
      for _ = 1, 12 do
        local nx = self.x + U.rand(-70, 70)
        local ny = self.y + U.rand(-50, 50)
        if nx > 8 and ny > 8 and not PH.boxBlocked(nx, ny, self.w, self.h) then
          self.x, self.y = nx, ny
          break
        end
      end
      World:fx("burst", self.x + 5, self.y + 5, { color = "spark", n = 6 })
      if G.Audio then G.Audio.sfx("teleport") end
      local p = playerNear(self, 160)
      if p then
        local cx, cy = self:center()
        local px, py = p:center()
        local ang = math.atan2(py - cy, px - cx)
        for off = -0.25, 0.25, 0.25 do
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "shard", size = 4,
            vx = math.cos(ang + off) * 130, vy = math.sin(ang + off) * 130,
            life = 1.8,
          })
        end
        if G.Audio then G.Audio.sfx("shoot4") end
      end
    end
  end)

reg("cryoturret", { hp = 7, touchDmg = 2, sprite = "en_cryoturret", w = 12, h = 12,
  drops = { shards = 4 }, deathColor = "violet", animRate = 2,
  init = function(self) self.noKnockback = true end },
  function(self, dt)
    self.aimT = (self.aimT or U.rand(1, 2)) - dt
    if self.aimT <= 0 then
      self.aimT = 2 / self:speedMult()
      local World = require "src.world"
      local p = playerNear(self, 170)
      if p then
        local cx, cy = self:center()
        local px, py = p:center()
        if PH.lineOfSight(cx, cy, px, py) then
          local ang = math.atan2(py - cy, px - cx)
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = 3, kind = "shard", size = 5,
            vx = math.cos(ang) * 210, vy = math.sin(ang) * 210, life = 1.6,
          })
          if G.Audio then G.Audio.sfx("shoot1") end
        end
      end
    end
  end)

-- ==================================================================
-- COLDSTORE
-- ==================================================================
reg("frostwisp", { hp = 4, touchDmg = 2, sprite = "en_frostwisp", w = 10, h = 10,
  drops = { shards = 3 }, deathColor = "ice", animRate = 5,
  init = function(self) self.noKnockback = true end },
  function(self, dt)
    -- drifts on a slow sine, fires freezing shards that slow your guns
    self.vy = math.sin(self.t * 2.2) * 14
    self.vx = math.cos(self.t * 1.1) * 8
    PH.move(self, self.vx * dt, self.vy * dt)
    self.frostT = (self.frostT or U.rand(1.6, 2.6)) - dt
    if self.frostT <= 0 then
      self.frostT = 2.6 / self:speedMult()
      local World = require "src.world"
      local p = playerNear(self, 150)
      if p then
        local cx, cy = self:center()
        local px, py = p:center()
        if PH.lineOfSight(cx, cy, px, py) then
          local ang = math.atan2(py - cy, px - cx)
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "shard", size = 4, chill = true,
            vx = math.cos(ang) * 150, vy = math.sin(ang) * 150, life = 1.8,
          })
          if G.Audio then G.Audio.sfx("shoot4") end
        end
      end
    end
  end)

reg("shelverbot", { hp = 8, touchDmg = 3, sprite = "en_shelverbot", w = 14, h = 14,
  drops = { shards = 4, heart = 0.15 }, deathColor = "slate", animRate = 2 },
  function(self, dt)
    -- archive drone: patrols the stacks, lobs book-crates in arcs
    local p = playerNear(self, 150)
    self:patrol(dt, (p and 30 or 18) * self:speedMult())
    self.lobT = (self.lobT or U.rand(1.5, 2.5)) - dt
    if self.lobT <= 0 then
      self.lobT = 2.8 / self:speedMult()
      if p then
        local World = require "src.world"
        local cx, cy = self.x + self.w / 2, self.y + 2
        local px = p.x + p.w / 2
        local dx = px - cx
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = 3, kind = "orb", size = 6,
          vx = U.clamp(dx * 1.1, -120, 120), vy = -190,
          gravity = 340, life = 2.6,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("icemaw", { hp = 9, touchDmg = 4, sprite = "en_icemaw", w = 14, h = 10,
  drops = { shards = 4, big = 0.2 }, deathColor = "ice", animRate = 3,
  init = function(self) self.buried = true self.noKnockback = true end },
  function(self, dt)
    -- floor ambusher: waits as a lump in the ice, springs at passing feet
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    PH.move(self, 0, self.vy * dt)
    self.calm = math.max(0, (self.calm or 0) - dt)
    if self.buried then
      self.touchDmg = 0
      local p = playerNear(self, 40)
      if p and self.calm <= 0 and math.abs(p.x - self.x) < 34 then
        self.buried = false
        self.touchDmg = 4
        self.vy = -265
        local World = require "src.world"
        World:fx("burst", self.x + 7, self.y + 8, { color = "ice", n = 10 })
        if G.Audio then G.Audio.sfx("crack") end
      end
    elseif self.onGround then
      self.buried = true
      self.calm = 1.4
    end
  end)

-- ==================================================================
-- THE RECKONING (Ember Camp)
-- ==================================================================
reg("keeperbrassa", { hp = 45, touchDmg = 3, sprite = "npc_brassa", w = 12, h = 15,
  drops = {}, deathColor = "ember", animRate = 3,
  init = function(self) self.noKnockback = true end },
  function(self, dt)
    -- the smith fights beside her elder; stands down when he falls
    if G.run.flags.boss_maro and not self.dead then
      self.dead = true
      local World = require "src.world"
      World:fx("burst", self.x + 6, self.y + 8, { color = "slate", n = 8 })
      if G.game then G.game:announce("Brassa lowers the hammer.", 2) end
      return
    end
    local p = playerNear(self, 220)
    if p then self.facing = U.sign(p.x - self.x) ~= 0 and U.sign(p.x - self.x) or self.facing end
    self:patrol(dt, (p and 60 or 20) * self:speedMult())
    self.lobT = (self.lobT or 1) - dt
    if self.lobT <= 0 and p then
      self.lobT = 1.7
      local World = require "src.world"
      local cx, cy = self.x + self.w / 2, self.y + 2
      local dx = p.x + p.w / 2 - cx
      Proj.spawn(World, cx, cy, {
        side = "enemy", dmg = 3, kind = "orb", size = 6,
        vx = U.clamp(dx * 1.3, -140, 140), vy = -180,
        gravity = 330, life = 2.4,
      })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
  end)

-- ==================================================================
-- SKYROOT
-- ==================================================================
reg("windray", { hp = 4, touchDmg = 2, sprite = "en_windray", w = 16, h = 8,
  deathColor = "sky", animRate = 6 },
  function(self, dt)
    -- glides in wide sine waves across the room
    local sp = 70 * self:speedMult()
    self.vx = self.facing * sp
    self.vy = math.sin(self.t * 2.2) * 45
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall end
  end)

reg("sporeballoon", { hp = 3, touchDmg = 1, sprite = "en_sporeballoon", w = 12, h = 14,
  deathColor = "leaf", animRate = 3,
  onDeathExtra = function(self)
    local World = require "src.world"
    for i = -1, 1 do
      Proj.spawn(World, self.x + 6, self.y + 6, {
        side = "enemy", dmg = 1, kind = "orb", size = 4,
        vx = i * 55, vy = 30, gravity = 120, life = 2,
      })
    end
  end },
  function(self, dt)
    self.vy = math.sin(self.t * 1.4) * 16 - 4
    self.vx = math.cos(self.t * 0.9) * 12
    PH.move(self, self.vx * dt, self.vy * dt)
    -- drop seeds over players
    self.dropT = (self.dropT or U.rand(2, 3)) - dt
    if self.dropT <= 0 then
      self.dropT = 2.6 / self:speedMult()
      local p = playerNear(self, 90)
      if p and math.abs(p.x - self.x) < 30 and p.y > self.y then
        local World = require "src.world"
        Proj.spawn(World, self.x + 6, self.y + self.h, {
          side = "enemy", dmg = 2, kind = "orb", size = 5,
          vx = 0, vy = 40, gravity = 260, life = 2.5,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("skylancer", { hp = 5, touchDmg = 3, sprite = "en_skylancer", w = 14, h = 8,
  drops = { shards = 3 }, deathColor = "ice", animRate = 8 },
  function(self, dt)
    -- hovers; charges horizontally when aligned with a player
    if not self.charging then
      self.vx = math.cos(self.t * 1.6) * 20
      self.vy = math.sin(self.t * 2.4) * 14
      local World = require "src.world"
      for _, p in ipairs(World:alivePlayers()) do
        local px, py = p:center()
        local cx, cy = self:center()
        if math.abs(py - cy) < 14 and math.abs(px - cx) < 160
          and PH.lineOfSight(cx, cy, px, py) then
          self.charging = true
          self.facing = U.sign(px - cx)
          self.chargeT = 0
          if G.Audio then G.Audio.sfx("dash") end
          break
        end
      end
    else
      self.chargeT = self.chargeT + dt
      self.vx = self.facing * 210 * self:speedMult()
      self.vy = 0
      if self.chargeT > 1 or self.hitWall then
        self.charging = false
      end
    end
    PH.move(self, self.vx * dt, self.vy * dt)
  end)


-- The SKYSPIRE pair, added with the ion weapon.
--
-- STORMVANE: a wall-mounted charging coil that answers Lu's dome. It
-- fires anti-shield darts (Proj.energyDart) and it deliberately PREFERS
-- a shielded target -- standing behind the dome is what draws its fire.
-- This is the overworld lesson for the Aerie Sentinel's energy lance.
local VANE_RANGE = 210
local VANE_CYCLE = 2.8      -- seconds between shots
local VANE_CHARGE = 0.7     -- telegraph before each shot
local VANE_DRAIN = 18       -- flat energy torn out of a dome
local VANE_DMG = 3          -- damage if it reaches an unshielded body
reg("stormvane", { hp = 6, touchDmg = 2, sprite = "en_stormvane", w = 12, h = 14,
  drops = { shards = 3, heart = 0.14 }, deathColor = "ice", animRate = 5 },
  function(self, dt)
    local World = require "src.world"
    -- station-keeping drift; it never chases
    if not self.homeX then self.homeX, self.homeY = self.x, self.y end
    self.x = self.homeX + math.sin(self.t * 0.7) * 5
    self.y = self.homeY + math.sin(self.t * 1.1) * 4

    -- pick a mark: a raised dome first, then the nearest body
    local function visible(p)
      local cx, cy = self:center()
      local px, py = p:center()
      return U.dist(cx, cy, px, py) < VANE_RANGE and PH.lineOfSight(cx, cy, px, py)
    end
    local mark
    for _, p in ipairs(World:alivePlayers()) do
      if not p.idle and p.domeActive and visible(p) then mark = p break end
    end
    if not mark then
      for _, p in ipairs(World:alivePlayers()) do
        if not p.idle and visible(p) and not mark then mark = p end
      end
    end

    self.cycle = (self.cycle or U.rand(0, VANE_CYCLE)) - dt
    if self.charging then
      self.charging = self.charging - dt
      self.mark = (self.mark and not self.mark.dead) and self.mark or mark
      if self.charging <= 0 then
        self.charging = nil
        local tgt = self.mark
        if tgt then
          local cx, cy = self:center()
          local px, py = tgt:center()
          Proj.energyDart(World, cx, cy, px, py,
            { speed = 420, drain = VANE_DRAIN, dmg = VANE_DMG })
          World:fx("spark", cx, cy, { color = "cyan", n = 8 })
          if G.Audio then G.Audio.sfx("shoot4") end
        end
        self.mark = nil
      end
    elseif self.cycle <= 0 and mark then
      self.cycle = VANE_CYCLE / self:speedMult()
      self.charging = VANE_CHARGE
      self.mark = mark
      if G.Audio then G.Audio.sfx("switch") end
    end
  end,
  function(self)
    local g = love.graphics
    self:drawSprite()
    local cx, cy = self:center()
    if self.charging then
      local k = 1 - self.charging / VANE_CHARGE
      g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.3 + k * 0.5)
      g.circle("line", cx, cy, 16 * (1 - k) + 4)
      if self.mark then
        local px, py = self.mark:center()
        g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.15 + k * 0.35)
        g.line(cx, cy, px, py)
      end
      g.setColor(1, 1, 1, 1)
    end
  end)

-- ROOSTFANG: the Skyspire's bat. Hangs still until you come close, then
-- swoops, and on contact it LATCHES and eats -- the Aerie Sentinel's
-- mechanic in miniature (Player:pin). Far weaker than the boss: a short
-- grip, small bites, and only 4 presses to shake off. A raised dome
-- turns it away entirely, which is the counter it teaches.
local FANG_WAKE = 130       -- how close you must get to wake it
local FANG_DIVE = 190       -- px/sec of the swoop
local FANG_LATCH = 1.6      -- seconds of grip
local FANG_GAP = 0.5        -- seconds between bites
local FANG_DMG = 2          -- damage per bite (6 over a full latch)
local Roostfang = reg("roostfang", { hp = 4, touchDmg = 2, sprite = "en_roostfang",
  w = 12, h = 10, drops = { shards = 2, heart = 0.15 }, deathColor = "sky",
  animRate = 12,
  init = function(self)
    self.pinMash = 4          -- Player:pin reads this: easier than a boss
    self.roost = true
  end,
  onDeathExtra = function(self)
    -- never leave a victim frozen because the thing holding them died
    if self.victim and self.victim.pinnedT and self.victim.pinnedT > 0 then
      self.victim:freeFromPin(false)
    end
    self.victim = nil
  end },
  function(self, dt)
    local World = require "src.world"
    if self.victim then
      local v = self.victim
      if v.dead or v.downed or v.pinnedT <= 0 then
        self.victim = nil
        self.roost = false
        self.recover = 0.8
        return
      end
      -- ride the victim and keep the grip alive
      self.x = v.x + v.w / 2 - self.w / 2
      self.y = v.y - self.h + 4
      self.latchT = (self.latchT or FANG_LATCH) - dt
      v.pinnedT = math.max(v.pinnedT, math.min(self.latchT, FANG_LATCH))
      self.munch = (self.munch or 0) - dt
      if self.munch <= 0 then
        self.munch = FANG_GAP
        v.invuln = 0        -- see the Aerie's munch: otherwise 1.2s i-frames
        v:takeDamage(FANG_DMG, self.x + self.w / 2, { pierceDash = true })
        World:fx("burst", v.x + v.w / 2, v.y + 4, { color = "blood", n = 5 })
        if G.Audio then G.Audio.sfx("hitenemy") end
      end
      if self.latchT <= 0 then
        v:freeFromPin(false)
        self.victim = nil
        self.roost = false
        self.recover = 0.8
      end
      return
    end

    if self.recover and self.recover > 0 then
      self.recover = self.recover - dt
      self.vx = self.facing * -40
      self.vy = -30
      PH.move(self, self.vx * dt, self.vy * dt)
      return
    end

    if self.roost then
      self.vx, self.vy = 0, math.sin(self.t * 3) * 6
      PH.move(self, 0, self.vy * dt)
      local p = playerNear(self, FANG_WAKE)
      if p then
        self.roost = false
        local px = p.x + p.w / 2
        local s = U.sign(px - (self.x + self.w / 2))
        if s ~= 0 then self.facing = s end
        if G.Audio then G.Audio.sfx("shoot4") end
      end
      return
    end

    -- awake: swoop at the nearest body
    local p = playerNear(self, 260)
    if p then
      local cx, cy = self:center()
      local px, py = p:center()
      local ang = math.atan2(py - cy, px - cx)
      local sp = FANG_DIVE * self:speedMult()
      self.vx = math.cos(ang) * sp
      self.vy = math.sin(ang) * sp
      self.facing = self.vx > 0 and 1 or -1
    else
      self.vx = self.facing * 60
      self.vy = math.sin(self.t * 3) * 30
    end
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall end

    -- contact: a dome turns it away, bare skin gets bitten
    for _, q in ipairs(World:alivePlayers()) do
      if q.domeActive and not q.idle then
        local cx, cy = self:center()
        local dx, dy = cx - (q.x + q.w / 2), cy - (q.y + q.h / 2 - 4)
        if dx * dx + dy * dy < (q.domeRadius + self.w / 2) ^ 2 then
          q:domeAbsorb(2)
          self.recover = 0.8
          self.vx, self.vy = -self.vx, -math.abs(self.vy) - 40
          World:fx("spark", cx, cy, { color = "cyan", n = 8 })
          if G.Audio then G.Audio.sfx("domehit") end
          return
        end
      end
    end
    for _, q in ipairs(World:alivePlayers()) do
      if not q.idle and q.pinnedT <= 0 and q.invuln <= 0
        and U.aabb(self.x, self.y, self.w, self.h, q.x, q.y, q.w, q.h) then
        if q:pin(self, FANG_LATCH) then
          self.victim = q
          self.latchT = FANG_LATCH
          self.munch = 0.2
          if G.Audio then G.Audio.sfx("roar") end
        end
        return
      end
    end
  end,
  function(self)
    -- frames 1-2 fly, frame 3 is the bite
    local f = self.victim and 3 or (math.floor(self.t * 12) % 2 + 1)
    G.drawSprite(self.sprite, f, self.x + self.w / 2, self.y + self.h + 0.5,
      { flip = self.facing < 0, white = math.max(0, (self.white or 0) * 6) })
  end)

-- shot off its victim: being hurt makes it let go
Roostfang.onHurt = function(self, dmg, srcx)
  Enemy.onHurt(self, dmg, srcx)
  if self.victim and self.victim.pinnedT and self.victim.pinnedT > 0 then
    self.victim:freeFromPin(false)
  end
end

-- Player:freeFromPin calls this when the victim tears loose on their own.
Roostfang.onPinReleased = function(self, p, struggled)
  if self.victim == p then
    self.victim = nil
    self.roost = false
    self.recover = 0.8
  end
end

-- ==================================================================
-- CORE
-- ==================================================================
reg("sentinel", { hp = 8, touchDmg = 3, sprite = "en_sentinel", w = 14, h = 14,
  drops = { shards = 5, big = 0.25, scrap = 0.25 }, deathColor = "cyan", animRate = 5 },
  function(self, dt)
    local p = playerNear(self, 170)
    if p then
      local cx, cy = self:center()
      local px, py = p:center()
      -- keep a preferred distance, strafe
      local d = U.dist(cx, cy, px, py)
      local want = d > 90 and 1 or (d < 60 and -1 or 0)
      local ang = math.atan2(py - cy, px - cx)
      local sp = 55 * self:speedMult()
      self.vx = U.approach(self.vx or 0, math.cos(ang) * sp * want + math.cos(self.t * 2) * 20, 150 * dt)
      self.vy = U.approach(self.vy or 0, math.sin(ang) * sp * want + math.sin(self.t * 2.7) * 16, 150 * dt)
      self.facing = U.sign(px - cx) ~= 0 and U.sign(px - cx) or self.facing
      self.shotT = (self.shotT or 1.5) - dt
      if self.shotT <= 0 then
        self.shotT = 1.7 / self:speedMult()
        local World = require "src.world"
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = 3, kind = "spark", size = 5,
          vx = math.cos(ang) * 170, vy = math.sin(ang) * 170,
          homing = 1.2, life = 2.2,
        })
        if G.Audio then G.Audio.sfx("shoot4") end
      end
    else
      self.vx = math.cos(self.t) * 14
      self.vy = math.sin(self.t * 1.4) * 12
    end
    PH.move(self, (self.vx or 0) * dt, (self.vy or 0) * dt)
  end)

reg("screamer", { hp = 6, touchDmg = 1, sprite = "en_screamer", w = 12, h = 12,
  drops = { shards = 5, big = 0.3 }, deathColor = "pink", animRate = 6 },
  function(self, dt)
    -- flees players, buffs all enemies in the room while alive
    self.vy = math.sin(self.t * 3) * 12
    local p = playerNear(self, 100)
    if p then
      local cx = self.x + self.w / 2
      self.vx = U.approach(self.vx or 0, U.sign(cx - p.x) * 60, 120 * dt)
      self.facing = U.sign((self.vx or 1))
    else
      self.vx = U.approach(self.vx or 0, 0, 60 * dt)
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    self.pulseT = (self.pulseT or 1) - dt
    if self.pulseT <= 0 then
      self.pulseT = 1
      local World = require "src.world"
      for _, e in ipairs(World.entities) do
        if e.kind == "enemy" and e ~= self and not e.dead then
          e.buffed = 1.4
        end
      end
      World:fx("burst", self.x + 6, self.y + 6, { color = "pink", n = 5, speed = 60 })
    end
  end)

-- Undergrove ---------------------------------------------------------

reg("myceling", { hp = 6, touchDmg = 2, sprite = "en_myceling", w = 12, h = 10,
  drops = { shards = 1, heart = 0.08 }, deathColor = "violet",
  onDeathExtra = function(self)
    -- mycelings regrow once from their husk unless truly finished
    if self.noRegrow then return end
    local World = require "src.world"
    local bud = Entity.make("regrowbud", self.x, self.y)
    bud.respawnKind = "myceling"
    World:add(bud)
  end },
  function(self, dt)
    self:patrol(dt, 26)
  end)

-- invisible timer that regrows a slain myceling (weaker, final)
local Regrowbud = Enemy.extend()
function Regrowbud:init(x, y)
  Entity.init(self, x, y)
  self.kind = "fx"
  self.timer = 3
  self.w, self.h = 2, 2
end
function Regrowbud:update(dt)
  self.timer = self.timer - dt
  local World = require "src.world"
  if math.floor(self.timer * 5) ~= math.floor((self.timer + dt) * 5) then
    World:fx("trail", self.x + U.rand(-4, 8), self.y + U.rand(-2, 8),
      { color = "violet", r = 1.5, t = 0.3 })
  end
  if self.timer <= 0 then
    self.dead = true
    local m = Entity.make("myceling", self.x, self.y)
    m.noRegrow = true
    m.hp = 3
    World:add(m)
    World:fx("burst", self.x + 6, self.y + 5, { color = "violet", n = 8 })
  end
end
function Regrowbud:draw() end
Entity.register("regrowbud", function(x, y) return Regrowbud.new(x, y) end)

reg("glowmite", { hp = 1, touchDmg = 0, sprite = "en_glowmite", w = 8, h = 8,
  deathColor = "spark", animRate = 10,
  init = function(self)
    self.harmless = true
    self.lightR = 30
    self.bobSeed = U.rand(0, 6)
  end },
  function(self, dt)
    -- drifts lazily; panics away from players that come close
    local p = playerNear(self, 40)
    if p then
      local cx, cy = self:center()
      local px, py = p:center()
      self.vx = U.approach(self.vx or 0, U.sign(cx - px) * 60, 200 * dt)
      self.vy = U.approach(self.vy or 0, U.sign(cy - py) * 40, 160 * dt)
    else
      self.vx = math.cos(self.t * 0.9 + self.bobSeed) * 14
      self.vy = math.sin(self.t * 1.7) * 10
    end
    self.facing = (self.vx or 0) >= 0 and 1 or -1
    PH.move(self, self.vx * dt, self.vy * dt)
  end)

reg("sporefly", { hp = 3, touchDmg = 2, sprite = "en_sporefly", w = 10, h = 8,
  drops = { shards = 1 }, deathColor = "orchid", animRate = 9 },
  function(self, dt)
    self.vx = math.cos(self.t * 1.1) * 26
    self.vy = math.sin(self.t * 2.2) * 18
    PH.move(self, self.vx * dt, self.vy * dt)
    self.facing = (self.vx or 0) >= 0 and 1 or -1
    self.spitT = (self.spitT or U.rand(1.4, 2.4)) - dt
    if self.spitT <= 0 then
      self.spitT = 2.2 / self:speedMult()
      local p = playerNear(self, 110)
      if p then
        local cx, cy = self:center()
        Proj.spawn(require "src.world", cx, cy, {
          side = "enemy", dmg = 1, kind = "orb", size = 4,
          vx = U.sign(p.x - cx) * 40, vy = -30, gravity = 140, life = 2.2,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("eliteguard", { hp = 12, touchDmg = 4, sprite = "en_eliteguard", w = 14, h = 16,
  drops = { shards = 6, big = 0.3, scrap = 0.3 }, deathColor = "cyan", animRate = 5 },
  function(self, dt)
    local p = playerNear(self, 150)
    if p then self.facing = U.sign(p.x - self.x) ~= 0 and U.sign(p.x - self.x) or self.facing end
    self:patrol(dt, (p and 60 or 28) * self:speedMult())
    self.shotT = (self.shotT or 2) - dt
    if self.shotT <= 0 and p then
      self.shotT = 2.2 / self:speedMult()
      local World = require "src.world"
      local cx, cy = self.x + self.w / 2, self.y + 4
      for i = 0, 1 do
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = 3, kind = "spark", size = 5,
          vx = self.facing * (150 + i * 40), vy = -10 + i * 20, life = 1.8,
        })
      end
      if G.Audio then G.Audio.sfx("shoot1") end
    end
  end)

return Enemy
