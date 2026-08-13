-- The two playable bots: Vess (1, gunner) and Lu (2, operator).
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"
local Weapons = require "src.weapons"
local Proj = require "src.entities.projectile"
local Cam = require "src.camera"

local T = 16
local Player = Entity.extend()

local BASE = {
  runSpeed = 112, accel = 950, airAccel = 620, friction = 800,
  jumpVel = -310, gravity = 830, maxFall = 300,   -- apex ~3.2 tiles measured
  -- (calibrate scenario: discrete integration eats ~4px vs the v^2/2g
  -- formula; -292 only reached 2.82 tiles, breaking 3-tile ledges)
  waterGravity = 340, waterJump = -220, waterMaxFall = 90, waterSpeed = 80,
  coyote = 0.09, jumpBuffer = 0.12,
}

function Player:init(idx, x, y)
  Entity.init(self, x, y)
  self.kind = "player"
  self.idx = idx
  self.isVess = idx == 1
  self.w, self.h = 10, 15
  self.facing = 1
  self.layer = 10

  local pd = G.run.players[idx]
  self.maxhp = pd.maxhp
  self.hp = pd.hp or pd.maxhp
  self.weapons = pd.weapons
  self.curWeapon = pd.curWeapon or 1

  -- movement state
  self.coyote = 0
  self.jumpBuf = 0
  self.dropTimer = 0
  self.anim = "idle"
  self.animT = 0
  self.frame = 1
  self.fireCd = 0
  self.charge = 0
  self.charging = false
  self.hurtT = 0
  self.breath = 9
  self.heat = 12
  self.chill = 12
  self.chilledT = 0

  -- Vess kit
  self.dashT = 0
  self.dashCd = 0
  self.airDashed = false
  self.grappling = nil

  -- Lu kit
  self.maxenergy = pd.maxenergy or 100
  self.energy = self.maxenergy
  self.energyDelay = 0
  self.domeActive = false
  self.domeRadius = 36
  self.repairCd = 0
  self.hoverT = 0

  -- co-op state
  self.downed = false
  self.bleedout = 0
  self.reviveProgress = 0
  self.idle = false      -- solo: uncontrolled bot
  self.warpHold = 0
  self.partnerHold = 0
  self.roomEnterProtect = 0
end

function Player:pdata() return G.run.players[self.idx] end

function Player:controlSlot()
  -- which input slot drives this bot (nil if uncontrolled)
  if G.game and G.game.coop then
    return self.idx
  else
    return (G.game and G.game.activeBot == self.idx) and 1 or nil
  end
end

function Player:curWeaponState()
  return self.weapons[self.curWeapon]
end

-- v2.0: weapons no longer level from shard XP -- Brassa's forge does
-- that with scrap. Shards ARE scrap now (see pickup.lua).

function Player:heal(n)
  self.hp = math.min(self.maxhp, self.hp + n)
end

function Player:takeDamage(dmg, srcx, opts)
  if self.dead or self.downed or self.idle then return end
  if self.invuln > 0 or self.roomEnterProtect > 0 then return end
  if self.dashT > 0 and not (opts and opts.pierceDash) then return end
  local mult = ({ 0.5, 1, 1.5 })[G.run.difficulty] or 1
  dmg = math.max(1, math.floor(dmg * mult + 0.5))
  self.hp = self.hp - dmg
  self.invuln = 1.2
  self.hurtT = 0.3
  self.white = 0.12
  local dir = srcx and U.sign(self.x + self.w / 2 - srcx) or -self.facing
  if dir == 0 then dir = -self.facing end
  self.vx = dir * 130
  self.vy = math.min(self.vy, -120)
  Cam.shake(2, 0.18)
  G.Input.rumble(self:controlSlot() or self.idx, 0.7, 0.2)
  if G.Audio then G.Audio.sfx("hurt") end
  local World = require "src.world"
  World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
    { color = self.isVess and "vessred" or "lublue", n = 6 })
  if self.hp <= 0 then
    self.hp = 0
    self:goDown()
  end
end

function Player:goDown()
  self.downed = true
  local times = { 60, 30, 18 }
  self.bleedout = times[G.run.difficulty] or 30
  self.reviveProgress = 0
  self.domeActive = false
  self.charging = false
  if G.Audio then G.Audio.sfx("down") end
  if G.game then G.game:onPlayerDown(self) end
end

function Player:revive(fraction)
  self.downed = false
  self.hp = math.max(1, math.floor(self.maxhp * (fraction or 0.4)))
  self.invuln = 2
  local World = require "src.world"
  World:fx("heal", self.x + self.w / 2, self.y)
  if G.Audio then G.Audio.sfx("revive") end
end

function Player:partner()
  local World = require "src.world"
  for _, p in ipairs(World.players) do
    if p ~= self then return p end
  end
end

-- Lu's dome soaks a hit: costs energy instead of health.
function Player:domeAbsorb(dmg)
  local tier = (Weapons.forge() and Weapons.forge().dome) or 1
  local mult = ({ 2.2, 1.6, 1.0 })[tier] or 2.2
  self.energy = math.max(0, self.energy - dmg * mult)
  self.energyDelay = 1
  if self.energy <= 0 then
    self.domeActive = false
    if G.Audio then G.Audio.sfx("domeoff") end
  end
end

-- ==================================================================
-- Update
-- ==================================================================
function Player:update(dt)
  local World = require "src.world"
  local slot = self:controlSlot()

  if self.roomEnterProtect > 0 then self.roomEnterProtect = self.roomEnterProtect - dt end
  if self.hurtT > 0 then self.hurtT = self.hurtT - dt end
  self.fireCd = self.fireCd - dt
  self.repairCd = self.repairCd - dt
  self.dashCd = self.dashCd - dt

  if self.downed then
    self:updateDowned(dt, World)
    return
  end

  if self.idle then
    -- solo uncontrolled bot: stands still, invulnerable, keeps dome if set
    self:updateIdle(dt, World)
    return
  end

  local mx = slot and G.Input.moveX(slot) or 0
  local pressed = function(a) return slot and G.Input.pressed(slot, a) end
  local down = function(a) return slot and G.Input.down(slot, a) end

  -- ---- horizontal movement
  local inWater = self.inWater and not G.run.flags.hydroseals
  local waterMode = self.inWater
  local topSpeed = waterMode and BASE.waterSpeed or BASE.runSpeed
  if self.domeActive then topSpeed = topSpeed * 0.55 end
  -- icy rooms (the Coldstore): grounded control goes slick
  local icy = self.onGround and not self.inWater
    and World.room and World.room.ice
  local accel = self.onGround and (icy and BASE.accel * 0.28 or BASE.accel)
    or BASE.airAccel

  if self.dashT > 0 then
    self.dashT = self.dashT - dt
    self.vx = self.facing * 265
    self.vy = 0
    World:fx("trail", self.x + self.w / 2, self.y + self.h / 2,
      { color = "vessred", r = 3, t = 0.18 })
    -- dash breaks breakable tiles ahead
    local tx = math.floor((self.x + self.w / 2 + self.facing * 10) / T)
    local ty0 = math.floor(self.y / T)
    local ty1 = math.floor((self.y + self.h - 1) / T)
    for ty = ty0, ty1 do World:breakTile(tx, ty) end
  elseif self.grappling then
    -- handled below
  else
    if mx ~= 0 then
      self.vx = U.approach(self.vx, mx * topSpeed, accel * dt)
      if not self.charging then self.facing = mx > 0 and 1 or -1 end
    else
      self.vx = U.approach(self.vx, 0,
        (self.onGround and (icy and 90 or BASE.friction) or 180) * dt)
    end
  end

  -- ---- jumping
  self.coyote = self.onGround and BASE.coyote or math.max(0, self.coyote - dt)
  self.jumpBuf = math.max(0, self.jumpBuf - dt)
  if pressed("jump") then
    self.jumpBuf = BASE.jumpBuffer
    -- drop through one-ways
    if down("down") and self.onOneway then
      self.dropThrough = 0.25
      self.jumpBuf = 0
      self.y = self.y + 2
    end
  end
  if self.dropThrough then
    self.dropThrough = self.dropThrough - dt
    if self.dropThrough <= 0 then self.dropThrough = nil end
  end

  local sparkjump = not self.isVess and G.run.flags.sparkjump
  local jumpVel = waterMode and BASE.waterJump or BASE.jumpVel
  if waterMode then
    -- surface breach: jumping with open air just above the head pops out
    -- at full strength, so climbing out of pools onto ledges is reliable
    -- (the reachability model counts on a 2-tile surface hop; calibrate
    -- verifies it)
    local tx = math.floor((self.x + self.w / 2) / 16)
    local headTy = math.floor(self.y / 16)
    if not World:isWater(tx, headTy - 1)
        and not World:isSolid(tx, headTy - 1) then
      jumpVel = BASE.jumpVel
    end
  end
  -- spark jump must clear 4-tile ledges with real margin (the moss_4
  -- vault roof is the tutorial for it); -350 measured only 4.06 tiles --
  -- a one-pixel margin nobody lands. calibrate enforces >= 4.15.
  if sparkjump then jumpVel = -365 end

  if self.jumpBuf > 0 and (self.coyote > 0 or waterMode) then
    self.vy = jumpVel
    self.jumpBuf = 0
    self.coyote = 0
    self.hoverT = 0
    if G.Audio then G.Audio.sfx("jump") end
    World:fx("puff", self.x + self.w / 2, self.y + self.h)
  end
  -- variable jump height
  if not down("jump") and self.vy < -80 and not self.grappling then
    self.vy = -80
  end

  -- Lu hover: hold jump while falling
  self.hovering = false
  if not self.isVess and down("jump") and self.vy > 20 and not self.onGround
    and not waterMode then
    local maxHover = G.run.flags.sparkjump and 1.3 or 0.65
    if self.hoverT < maxHover then
      self.hoverT = self.hoverT + dt
      self.vy = math.min(self.vy, 26)
      self.hovering = true
      if math.floor(G.time * 20) % 2 == 0 then
        World:fx("trail", self.x + self.w / 2 + U.rand(-3, 3), self.y + self.h,
          { color = "cyan", r = 1.5, t = 0.2 })
      end
    end
  end
  if self.onGround then self.hoverT = 0 self.airDashed = false end

  -- ---- gravity
  if self.dashT <= 0 and not self.grappling then
    local grav = waterMode and BASE.waterGravity or BASE.gravity
    local maxFall = waterMode and BASE.waterMaxFall or BASE.maxFall
    self.vy = math.min(self.vy + grav * dt, maxFall)
  end

  -- ---- Vess dash / grapple
  if self.isVess then
    if pressed("special") and self.dashCd <= 0 and self.dashT <= 0 then
      -- try grapple first if module owned and anchor in range
      local anchor = G.run.flags.grapple and self:findAnchor(World)
      if anchor then
        self.grappling = anchor
        if G.Audio then G.Audio.sfx("grapple") end
      elseif not self.airDashed or self.onGround then
        self.dashT = 0.2
        self.dashCd = 0.65
        if not self.onGround then self.airDashed = true end
        if G.Audio then G.Audio.sfx("dash") end
        G.Input.rumble(slot or 1, 0.3, 0.1)
      end
    end
    if self.grappling then
      local a = self.grappling
      local cx, cy = self.x + self.w / 2, self.y + self.h / 2
      local ax, ay = a.x + a.w / 2, a.y + a.h / 2
      local d = U.dist(cx, cy, ax, ay)
      if d < 14 or not down("special") then
        self.grappling = nil
        if d < 20 then self.vy = math.min(self.vy, -150) end
      else
        local ang = math.atan2(ay - cy, ax - cx)
        self.vx = math.cos(ang) * 330
        self.vy = math.sin(ang) * 330
        World:fx("trail", cx, cy, { color = "cyan", r = 2, t = 0.15 })
      end
    end
  end

  -- ---- Lu dome + repair
  if not self.isVess then
    if pressed("special") then
      if self.domeActive then
        self.domeActive = false
        if G.Audio then G.Audio.sfx("domeoff") end
      elseif self.energy > 12 then
        self.domeActive = true
        if G.Audio then G.Audio.sfx("domeon") end
      else
        if G.Audio then G.Audio.sfx("deny") end
      end
    end
    if self.domeActive then
      self.energy = self.energy - 11 * dt
      self.energyDelay = 0.9
      if self.energy <= 0 then
        self.energy = 0
        self.domeActive = false
        if G.Audio then G.Audio.sfx("domeoff") end
      end
    else
      self.energyDelay = self.energyDelay - dt
      if self.energyDelay <= 0 then
        self.energy = math.min(self.maxenergy, self.energy + 13 * dt)
      end
    end
    -- repair pulse
    if pressed("util") and self.repairCd <= 0 then
      if self.energy >= 25 then
        self.energy = self.energy - 25
        self.energyDelay = 1
        self.repairCd = 2.2
        if G.Audio then G.Audio.sfx("repair") end
        for _, pl in ipairs(World.players) do
          if not pl.dead and not pl.downed
            and U.dist(self.x, self.y, pl.x, pl.y) < 52 then
            pl:heal(4)
            World:fx("heal", pl.x + pl.w / 2, pl.y)
          end
        end
      else
        if G.Audio then G.Audio.sfx("deny") end
      end
    end
  else
    -- Vess util: weapon cycle
    if pressed("util") and #self.weapons > 1 then
      self.curWeapon = self.curWeapon % #self.weapons + 1
      self:pdata().curWeapon = self.curWeapon
      self.charging = false
      self.charge = 0
      if G.Audio then G.Audio.sfx("wswap") end
    end
  end

  -- ---- firing
  self:updateFire(dt, World, slot, down, pressed)

  -- ---- physics move
  PH.move(self, self.vx * dt, self.vy * dt)
  if self.grappling and (self.hitWall or self.onGround or self.hitCeil) then
    self.grappling = nil
  end

  -- landed effects
  if self.justLanded then
    World:fx("puff", self.x + self.w / 2, self.y + self.h, { n = 3 })
    if G.Audio then G.Audio.sfx("land") end
  end
  -- crumble triggers
  if self.onGround and self.groundTX then
    World:startCrumble(self.groundTX, self.groundTY)
    local tx2 = math.floor((self.x + 2) / T)
    local tx3 = math.floor((self.x + self.w - 2) / T)
    World:startCrumble(tx2, self.groundTY)
    World:startCrumble(tx3, self.groundTY)
  end

  -- water entry splash + breath
  if self.inWater and not self.wasInWater then
    World:fx("splash", self.x + self.w / 2, self.y + self.h / 2)
    if G.Audio then G.Audio.sfx("splash") end
  end
  self.wasInWater = self.inWater
  if self.inWater and not G.run.flags.hydroseals then
    local headTx = math.floor((self.x + self.w / 2) / T)
    local headTy = math.floor((self.y + 2) / T)
    if World:isWater(headTx, headTy) then
      self.breath = self.breath - dt
      if self.breath <= 0 then
        self.breath = 1.2
        self:takeDamage(2, nil, { pierceDash = true })
      end
    else
      self.breath = math.min(9, self.breath + dt * 4)
    end
  else
    self.breath = 9
  end

  -- heat rooms
  if World.room and World.room.hot and not G.run.flags.heatplating then
    self.heat = self.heat - dt
    if self.heat <= 0 then
      self.heat = 1.5
      self:takeDamage(2, nil, { pierceDash = true })
    end
  else
    self.heat = math.min(12, self.heat + dt * 3)
  end

  -- cold rooms (the Coldstore): mirror of heat, gated by cryo coils
  if World.room and World.room.cold and not G.run.flags.cryocoils then
    self.chill = self.chill - dt
    if self.chill <= 0 then
      self.chill = 1.5
      self:takeDamage(2, nil, { pierceDash = true })
    end
  else
    self.chill = math.min(12, self.chill + dt * 3)
  end
  if self.chilledT > 0 then self.chilledT = self.chilledT - dt end

  -- last safe footing: solid ground, out of hazard, remembered per room
  if self.onGround and not self.inLava and not self.inWater then
    local ftx = math.floor((self.x + self.w / 2) / T)
    local fty = math.floor((self.y + self.h + 2) / T)
    -- only PERMANENT footing counts (crumble tiles betray you later)
    if (World:tileAt(ftx, fty) == World.codes.SOLID or World:isOneway(ftx, fty))
      and not PH.boxBlocked(self.x, self.y, self.w, self.h) then
      self.safeX, self.safeY = self.x, self.y
      self.safeRoom = World.room and World.room.id
    end
  end

  -- hazards
  if self.inLava then
    -- lava does not negotiate: fire, smoke, and the wreck thrown back
    -- to the last solid ground it stood on
    local cx, feet = self.x + self.w / 2, self.y + self.h
    World:fx("burst", cx, feet, { color = "magma", n = 20, speed = 210 })
    World:fx("burst", cx, feet - 6, { color = "hotcore", n = 10, speed = 150 })
    World:fx("burst", cx, feet - 10, { color = "slate", n = 16, speed = 70 })
    Cam.shake(4, 0.4)
    if G.Audio then G.Audio.sfx("explode") end
    if self.safeX and self.safeRoom == (World.room and World.room.id) then
      self.x, self.y = self.safeX, self.safeY
      self.inLava = false
    else
      self.vy = -240
    end
    self.invuln = 0
    self:takeDamage(9999, nil, { pierceDash = true })
    self.vx, self.vy = 0, 0
  end
  self:checkSpikes(World)

  -- enemy contact damage
  if self.invuln <= 0 and self.dashT <= 0 then
    for _, e in ipairs(World.entities) do
      if e.kind == "enemy" and not e.dead and e.touchDmg and e.touchDmg > 0
        and not e.harmless
        and U.aabb(self.x, self.y, self.w, self.h, e.x, e.y, e.w, e.h) then
        self:takeDamage(e.touchDmg, e.x + e.w / 2)
        break
      end
    end
  end

  -- dome pushes enemies out gently (Lu)
  if self.domeActive then
    local cx, cy = self.x + self.w / 2, self.y + self.h / 2 - 4
    for _, e in ipairs(World.entities) do
      if e.kind == "enemy" and not e.dead and not e.heavy then
        local ex, ey = e.x + e.w / 2, e.y + e.h / 2
        local d = U.dist(cx, cy, ex, ey)
        if d < self.domeRadius + 6 and d > 0.01 then
          local push = (self.domeRadius + 6 - d) * 6
          e.x = e.x + (ex - cx) / d * push * dt
          e.y = e.y + (ey - cy) / d * push * dt * 0.4
        end
      end
    end
  end

  -- ---- interactions
  self:updateInteract(dt, World, slot, down, pressed)

  -- ---- co-op verbs (link, warp) & solo handled by game state via buttons
  if pressed("partner") and G.game then G.game:partnerPressed(self) end
  if G.game and G.game.coop then
    if down("warp") then
      self.warpHold = self.warpHold + dt
      if self.warpHold > 0.7 then
        self.warpHold = 0
        G.game:warpToPartner(self)
      end
    else
      self.warpHold = 0
    end
  else
    -- solo: warp button fires the Link Shot (bots must be synced up close)
    if pressed("warp") and G.game then G.game:tryLinkShot() end
  end

  -- ---- doors: edge doors auto, portal doors with up
  local ch, d = World:doorAt(self.x, self.y, self.w, self.h)
  self.atPortalDoor = false
  -- arrival grace: the door we spawned at stays inert until we have moved
  -- a comfortable distance away from it (not merely "stopped overlapping":
  -- shaft arrivals hover pixels above their door and would sink back in,
  -- and knockback beside an edge door could shove us straight back through)
  if self.doorGrace then
    local gd = World.doors[self.doorGrace]
    if not gd then
      self.doorGrace = nil
    else
      local rx0, ry0 = gd.x0 * 16, gd.y0 * 16
      local rx1, ry1 = (gd.x1 + 1) * 16, (gd.y1 + 1) * 16
      local ddx = math.max(rx0 - (self.x + self.w), self.x - rx1, 0)
      local ddy = math.max(ry0 - (self.y + self.h), self.y - ry1, 0)
      if math.max(ddx, ddy) > 12 then self.doorGrace = nil end
    end
  end
  if ch and ch ~= self.doorGrace then
    if d.edge then
      World:requestTransition(ch)
    else
      self.atPortalDoor = true
      if (pressed("interact") or pressed("up")) and not self.interactedThisFrame then
        World:requestTransition(ch)
      end
    end
  end

  -- animation
  self:updateAnim(dt)
end

function Player:checkSpikes(World)
  local tx0 = math.floor((self.x + 2) / T)
  local tx1 = math.floor((self.x + self.w - 2) / T)
  local ty0 = math.floor((self.y + 2) / T)
  local ty1 = math.floor((self.y + self.h - 2) / T)
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      if World:spikeAt(tx, ty) then
        self:takeDamage(3, tx * T + 8, { pierceDash = true })
        return
      end
    end
  end
end

function Player:findAnchor(World)
  local best, bd
  local cx, cy = self.x + self.w / 2, self.y + self.h / 2
  World:each("anchor", function(a)
    local ax, ay = a.x + a.w / 2, a.y + a.h / 2
    local d = U.dist(cx, cy, ax, ay)
    -- roughly in facing direction or above
    local dx = ax - cx
    local ok = d < 110 and (U.sign(dx) == self.facing or math.abs(dx) < 24 or ay < cy)
    if ok and PH.lineOfSight(cx, cy, ax, ay) and (not bd or d < bd) then
      best, bd = a, d
    end
  end)
  return best
end

-- ==================================================================
-- Firing
-- ==================================================================
function Player:aimDir(down)
  -- returns dx, dy (unit-ish 4-way; up always allowed, down only in air)
  if down("up") then return 0, -1 end
  if down("down") and not self.onGround then return 0, 1 end
  return self.facing, 0
end

function Player:updateFire(dt, World, slot, down, pressed)
  local ws = self:curWeaponState()
  if not ws then return end
  local def = Weapons.get(ws.id)
  local lvl = Weapons.levelOf(ws)
  local dx, dy = self:aimDir(down)

  local mx, my = self.x + self.w / 2, self.y + self.h / 2 - 1
  if dy == 0 then
    mx = mx + self.facing * 8
    my = my + 1
  else
    my = my + dy * 10
  end

  if def.charge then
    -- Arc Lance: hold to charge
    if down("fire") then
      self.charging = true
      self.charge = math.min(self.charge + dt, def.charge)
      if self.charge >= def.charge and math.floor(G.time * 12) % 3 == 0 then
        World:fx("trail", mx + U.rand(-3, 3), my + U.rand(-3, 3),
          { color = "orchid", r = 1.5, t = 0.12 })
      end
    elseif self.charging then
      self.charging = false
      if self.fireCd <= 0 then
        local full = self.charge >= def.charge
        self.fireCd = def.rate
        local dmg = full and def.dmg[lvl] or def.tapdmg
        local pierce = full and def.pierce[lvl] or 0
        Proj.spawn(World, mx, my, {
          side = "player", dmg = dmg, owner = self,
          vx = dx * def.speed, vy = dy * def.speed,
          kind = "lance", size = full and 6 or 4, pierce = pierce, life = 0.8,
        })
        if G.Audio then G.Audio.sfx(full and "shoot3" or "shoot1") end
        self.vx = self.vx - dx * (full and 60 or 15)
        Cam.shake(full and 1.5 or 0, 0.1)
      end
      self.charge = 0
    end
    return
  end

  local rate = def.rate
  if type(rate) == "table" then rate = rate[lvl] end
  if self.chilledT and self.chilledT > 0 then rate = rate * 1.6 end
  if down("fire") and self.fireCd <= 0 then
    self.fireCd = rate
    if def.mortar then
      -- Magnet Mortar: a lobbed shell on a gravity arc
      Proj.spawn(World, mx, my, {
        side = "player", dmg = def.dmg[lvl], owner = self,
        vx = dx * def.speed,
        vy = -195 + math.min(0, dy) * 130,
        kind = def.visual, size = def.size, gravity = 640, life = 2.4,
      })
      self.vx = self.vx - dx * 45
      Cam.shake(0.8, 0.08)
    elseif def.radial then
      -- Pulse Bloom: a ring of pulses around Lu; works with the dome up
      local n = def.radial[lvl]
      local cx, cy = self.x + self.w / 2, self.y + self.h / 2 - 2
      for i = 1, n do
        local ang = (i / n) * math.pi * 2 + G.time
        Proj.spawn(World, cx, cy, {
          side = "player", dmg = def.dmg[lvl], owner = self,
          vx = math.cos(ang) * def.speed, vy = math.sin(ang) * def.speed,
          kind = def.visual, size = def.size, life = def.life,
        })
      end
      local World2 = require "src.world"
      World2:fx("burst", cx, cy, { color = "cyan", n = 6, speed = 90 })
    elseif def.pellets then
      local n = def.pellets[lvl]
      for i = 1, n do
        local ang = math.atan2(dy, dx) + U.rand(-def.spread, def.spread)
        local sp = def.speed * U.rand(0.85, 1.15)
        Proj.spawn(World, mx, my, {
          side = "player", dmg = def.dmg[lvl], owner = self,
          vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
          kind = def.visual, size = def.size, life = def.life,
        })
      end
      self.vx = self.vx - dx * 40
    else
      Proj.spawn(World, mx, my, {
        side = "player", dmg = def.dmg[lvl], owner = self,
        vx = dx * def.speed, vy = dy * def.speed,
        kind = def.visual, size = def.size,
        pierce = def.pierce and def.pierce[lvl] or 0,
        homing = def.homing and def.homing[lvl] or nil,
        life = 1.2,
      })
    end
    if G.Audio then G.Audio.sfx(def.sfx) end
    self.muzzleT = 0.06
    self.muzzleDx, self.muzzleDy = dx, dy
  end
  if self.muzzleT then
    self.muzzleT = self.muzzleT - dt
    if self.muzzleT <= 0 then self.muzzleT = nil end
  end
end

-- ==================================================================
-- Interactions (talk / revive / save / energize / chest)
-- ==================================================================
function Player:updateInteract(dt, World, slot, down, pressed)
  self.interactedThisFrame = false
  self.interactHint = nil

  -- revive downed partner: hold interact nearby
  local partner = self:partner()
  if partner and partner.downed then
    local d = U.dist(self.x + self.w / 2, self.y + self.h / 2,
      partner.x + partner.w / 2, partner.y + partner.h / 2)
    if d < 26 then
      self.interactHint = "revive"
      if down("interact") then
        partner.reviveProgress = partner.reviveProgress + dt
        World:fx("heal", partner.x + partner.w / 2, partner.y + 6)
        if partner.reviveProgress >= 1.6 then
          partner:revive(0.45)
          self.interactedThisFrame = true
        end
        return
      else
        partner.reviveProgress = math.max(0, partner.reviveProgress - dt * 2)
      end
    end
  end

  -- interactable entities
  local best, bd
  for _, e in ipairs(World.entities) do
    if e.interactable and not e.dead then
      local d = U.dist(self.x + self.w / 2, self.y + self.h / 2,
        e.x + e.w / 2, e.y + e.h / 2)
      local range = e.interactRange or 22
      if d < range and (not bd or d < bd) then best, bd = e, d end
    end
  end
  if best then
    -- energize machines are Lu-only
    if best.needsLu and self.isVess then
      self.interactHint = "luonly"
    else
      self.interactHint = best.hint or "talk"
      if pressed("interact") then
        best:interact(self)
        self.interactedThisFrame = true
      end
    end
  end
end

-- ==================================================================
-- Downed / idle
-- ==================================================================
function Player:updateDowned(dt, World)
  self.bleedout = self.bleedout - dt
  self.vy = math.min(self.vy + BASE.gravity * dt, BASE.maxFall)
  self.vx = U.approach(self.vx, 0, 200 * dt)
  PH.move(self, self.vx * dt, self.vy * dt)
  if math.floor(G.time * 4) % 4 == 0 then
    World:fx("trail", self.x + U.rand(0, self.w), self.y + U.rand(0, self.h),
      { color = "blood", r = 1, t = 0.3 })
  end
  if self.bleedout <= 0 and G.game then
    G.game:onPlayerBledOut(self)
  end
end

function Player:updateIdle(dt, World)
  -- uncontrolled solo bot: gravity only, invulnerable, holds position
  self.vy = math.min(self.vy + BASE.gravity * dt, BASE.maxFall)
  self.vx = U.approach(self.vx, 0, 400 * dt)
  PH.move(self, self.vx * dt, self.vy * dt)
  -- keep dome up if it was on (drains slower when idle)
  if self.domeActive then
    self.energy = self.energy - 5 * dt
    if self.energy <= 0 then self.energy = 0 self.domeActive = false end
  elseif self.energyDelay <= 0 then
    self.energy = math.min(self.maxenergy, self.energy + 13 * dt)
  end
  self:updateAnim(dt)
end

-- ==================================================================
-- Animation + drawing
-- ==================================================================
function Player:updateAnim(dt)
  local prev = self.anim
  if self.dashT > 0 then self.anim = "dash"
  elseif self.grappling then self.anim = "jump"
  elseif not self.onGround then
    if self.hovering then self.anim = "hover"
    else self.anim = self.vy < 0 and "jump" or "fall" end
  elseif math.abs(self.vx) > 12 then self.anim = "run"
  else self.anim = "idle" end
  if self.hurtT > 0 then self.anim = "hurt" end
  if prev ~= self.anim then self.animT = 0 end
  self.animT = self.animT + dt
end

function Player:spriteName()
  local who = self.isVess and "vess" or "lu"
  local a = self.anim
  if a == "dash" then a = "run" end
  if a == "hover" then a = "jump" end
  return who .. "_" .. a
end

function Player:draw()
  local g = love.graphics
  local World = require "src.world"

  -- dome
  if self.domeActive then
    local cx, cy = self.x + self.w / 2, self.y + self.h / 2 - 4
    local r = self.domeRadius
    local pulse = math.sin(G.time * 4) * 1.5
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.12)
    g.circle("fill", cx, cy, r + pulse)
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.55)
    g.circle("line", cx, cy, r + pulse)
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.3)
    g.circle("line", cx, cy, r - 2 + pulse)
    g.setColor(1, 1, 1, 1)
  end

  local frame = 1
  local name = self:spriteName()
  if self.anim == "run" then
    frame = math.floor(self.animT * 10) % 4 + 1
  elseif self.anim == "idle" then
    frame = math.floor(self.animT * 2) % 2 + 1
  end

  local flicker = self.invuln > 0 and math.floor(G.time * 16) % 2 == 0
  if self.downed then
    -- lying flat, blinking distress light
    G.drawSprite(name, 1, self.x + self.w / 2 + (self.facing > 0 and 4 or -4),
      self.y + self.h, { rot = self.facing * math.pi / 2, white = 0 })
    if math.floor(G.time * 3) % 2 == 0 then
      g.setColor(P.blood)
      g.circle("fill", self.x + self.w / 2, self.y + 2, 1.5)
    end
    -- bleedout ring
    local frac = self.bleedout / (({ 60, 30, 18 })[G.run.difficulty] or 30)
    g.setColor(P.blood[1], P.blood[2], P.blood[3], 0.9)
    g.arc("line", "open", self.x + self.w / 2, self.y - 8, 6,
      -math.pi / 2, -math.pi / 2 + math.pi * 2 * frac)
    if self.reviveProgress > 0 then
      g.setColor(P.leaf)
      g.arc("line", "open", self.x + self.w / 2, self.y - 8, 8,
        -math.pi / 2, -math.pi / 2 + math.pi * 2 * (self.reviveProgress / 1.6))
    end
    g.setColor(1, 1, 1, 1)
    return
  end

  if not flicker then
    local opts = { flip = self.facing < 0, white = math.max(0, (self.white or 0) * 6) }
    if self.idle then opts.alpha = 0.85 end
    G.drawSprite(name, frame, self.x + self.w / 2, self.y + self.h + 0.5, opts)
    -- idle bot indicator
    if self.idle then
      g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.5 + math.sin(G.time * 3) * 0.3)
      g.circle("line", self.x + self.w / 2, self.y - 6, 3)
      g.setColor(1, 1, 1, 1)
    end
  end

  -- muzzle flash
  if self.muzzleT then
    local mx = self.x + self.w / 2 + (self.muzzleDy == 0 and self.facing * 10 or 0)
    local my = self.y + self.h / 2 - 1 + (self.muzzleDy or 0) * 11
    g.setColor(P.cream)
    g.circle("fill", mx, my, 3)
    g.setColor(P.gold)
    g.circle("fill", mx, my, 1.5)
    g.setColor(1, 1, 1, 1)
  end

  -- charge glow (arc lance)
  if self.charging then
    local full = self.charge >= (Weapons.get(self:curWeaponState().id).charge or 1)
    local cx = self.x + self.w / 2 + self.facing * 9
    local cy = self.y + self.h / 2
    g.setColor(P.orchid[1], P.orchid[2], P.orchid[3], full and 0.9 or 0.5)
    g.circle("fill", cx, cy, full and 4 or 2 + self.charge * 3)
    if full then
      g.setColor(P.white)
      g.circle("fill", cx, cy, 1.5)
    end
    g.setColor(1, 1, 1, 1)
  end

  -- interact hint
  if self.interactHint and not self.idle then
    local hx, hy = self.x + self.w / 2, self.y - 10
    g.setColor(P.black[1], P.black[2], P.black[3], 0.6)
    g.rectangle("fill", hx - 4, hy - 5, 9, 9, 2, 2)
    g.setColor(self.interactHint == "luonly" and P.cyan or P.gold)
    if self.interactHint == "revive" then
      g.setColor(P.leaf)
    end
    local font = G.fonts.main
    g.setFont(font)
    g.print(self.interactHint == "luonly" and "L" or "!", hx - 2, hy - 4)
    g.setColor(1, 1, 1, 1)
  end

  -- portal door hint
  if self.atPortalDoor and not self.idle then
    local hx, hy = self.x + self.w / 2, self.y - 9 + math.sin(G.time * 4) * 1.5
    g.setColor(P.gold)
    g.polygon("fill", hx - 3, hy + 3, hx + 3, hy + 3, hx, hy - 2)
    g.setColor(1, 1, 1, 1)
  end

  -- warp hold indicator
  if self.warpHold > 0.1 then
    g.setColor(P.spark)
    g.arc("line", "open", self.x + self.w / 2, self.y - 6, 5,
      -math.pi / 2, -math.pi / 2 + math.pi * 2 * (self.warpHold / 0.7))
    g.setColor(1, 1, 1, 1)
  end

  -- breath bubbles warning
  if self.inWater and not G.run.flags.hydroseals and self.breath < 4 then
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.9)
    local bw = 14 * (self.breath / 9)
    g.rectangle("fill", self.x + self.w / 2 - 7, self.y - 8, bw, 2)
    g.setColor(1, 1, 1, 1)
  end
  -- heat warning
  if World.room and World.room.hot and not G.run.flags.heatplating and self.heat < 8 then
    g.setColor(P.magma[1], P.magma[2], P.magma[3], 0.9)
    local bw = 14 * (self.heat / 12)
    g.rectangle("fill", self.x + self.w / 2 - 7, self.y - 11, bw, 2)
    g.setColor(1, 1, 1, 1)
  end
  -- cold warning
  if World.room and World.room.cold and not G.run.flags.cryocoils and self.chill < 8 then
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.9)
    local bw = 14 * (self.chill / 12)
    g.rectangle("fill", self.x + self.w / 2 - 7, self.y - 11, bw, 2)
    g.setColor(1, 1, 1, 1)
  end
end

Player.BASE = BASE
return Player
