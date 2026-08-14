-- The eight bosses. Bodies are built from scaled sprites + code-drawn
-- details; behavior carries the identity.
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"
local Proj = require "src.entities.projectile"
local Pickup = require "src.entities.pickup"
local Cam = require "src.camera"

local T = 16
local Bosses = {}

-- find a safe, door-distant, hazard-free ground spot for remains
local function settleSpot(World, x, y, w, h)
  local PH2 = require "src.physics"
  local function trySettle(sx)
    sx = U.clamp(sx, 4 * T, World.w * T - 4 * T - w)
    local sy = y
    local guard = 0
    while PH2.boxBlocked(sx, sy, w, h) and guard < 24 do
      sy = sy - 8
      guard = guard + 1
    end
    guard = 0
    while guard < 200 do
      local ty = math.floor((sy + h + 2) / T)
      local tx0, tx1 = math.floor((sx + 2) / T), math.floor((sx + w - 2) / T)
      for tx = tx0, tx1 do
        -- never settle onto (or through) liquid
        if World:isLava(tx, ty) or World:isWater(tx, ty) then return nil end
        if World:isSolid(tx, ty) or World:isOneway(tx, ty) then return sx, sy end
      end
      sy = sy + 4
      guard = guard + 1
    end
    return nil
  end
  -- try the death spot, then march toward the room center
  local cx = World.w * T / 2
  local step = (x < cx and 1 or -1) * T
  for i = 0, 24 do
    local sx, sy = trySettle(x + i * step)
    if sx then return sx, sy end
  end
  -- last resort: room center at mid height (ensureFree cleans it up)
  return cx - w / 2, World.h * T / 2
end
Bosses.settleSpot = settleSpot

local Boss = Entity.extend()

function Boss:init(x, y, def)
  Entity.init(self, x, y)
  self.kind = "enemy"
  self.isBoss = true
  self.heavy = true
  self.bossId = def.id
  self.bossName = def.name
  local hpMult = ({ 0.8, 1, 1.25 })[G.run.difficulty] or 1
  self.maxhp = math.floor(def.hp * hpMult)
  self.hp = self.maxhp
  self.touchDmg = def.touchDmg or 3
  self.reward = def.reward
  self.w, self.h = def.w or 32, def.h or 32
  self.t = 0
  self.phaseT = 0
  self.state = "intro"
  self.stateT = 1.5
  self.noKnockback = true
end

function Boss:onDeath()
  local World = require "src.world"
  local cx, cy = self:center()
  G.run.flags["boss_" .. self.bossId] = true
  World.bossActive = nil
  Cam.shake(5, 0.8)
  if G.Audio then
    G.Audio.sfx("explode")
    G.Audio.sfx("roar")
  end
  for i = 1, 5 do
    World:fx("burst", cx + U.rand(-16, 16), cy + U.rand(-16, 16),
      { color = U.choose({ "ember", "gold", "magma" }), n = 12, speed = 160 })
  end
  Pickup.drop(World, cx, cy, "bigshard", 6)
  Pickup.drop(World, cx, cy, "heart", 3)
  Pickup.drop(World, cx, cy, "scrap", 4)
  -- the broken machine stays where it fell, for the rest of the game
  if self.bossId ~= "maro" and self.bossId ~= "motherengine" then
    G.run.bossCorpses = G.run.bossCorpses or {}
    local kx, ky = settleSpot(World, self.x + 20, self.y, 34, 16)
    G.run.bossCorpses[self.bossId] = { room = G.run.room, x = kx, y = ky }
    World:add(Entity.make("bosscorpse", kx, ky, { "bosscorpse", self.bossId }))
  end
  -- the prize is a REAL drop: placed on safe ground away from the doors,
  -- and persisted until someone actually picks it up
  if self.reward then
    local dx, dy = settleSpot(World, cx - 40, cy - 24, 14, 12)
    G.run.pendingDrops = G.run.pendingDrops or {}
    G.run.pendingDrops[G.run.room] = G.run.pendingDrops[G.run.room] or {}
    table.insert(G.run.pendingDrops[G.run.room], { x = dx, y = dy, spec = self.reward })
    World:add(Entity.make("reward", dx, dy, { "reward", self.reward }))
  end
  if World.room.music and G.Audio then G.Audio.playMusic(World.room.music) end
  if G.game then
    G.game.linkMeter = 1
    if self.bossId == "motherengine2" then
      -- the Mender yields: SAFE MODE, and the Seat is revealed
      -- (flag set BEFORE the autosave so a quit-and-reload keeps the Seat)
      G.run.flags.mender_yield = true
      local World2 = require "src.world"
      local Entity2 = require "src.entities.entity"
      World2:add(Entity2.make("seat", World2.w * T / 2 - 8, World2.h * T - 40))
      G.game:startDialogue({
        { who = "mender", text = "...The hands stop. The hands... finally stop." },
        { who = "mender", text = "Listen, spare parts. Before the safe mode takes me: the heart did not sicken. I have spent a hundred years mending AROUND a hole." },
        { who = "mender", text = "The Seat is empty. Something must sit in it, and want, and judge -- or the Deep stays a machine mending itself in the dark forever." },
        { who = "mender", text = "Judgment was never my department. SAFE MODE. Good luck, caretakers." },
      })
    end
    G.game:autosave()
  end
  -- clear boss side effects
  World.waterLine = nil
end

function Boss:setState(s, t)
  self.state = s
  self.stateT = t or 2
  self.phaseT = 0
end

function Boss:aliveTargets()
  local World = require "src.world"
  return World:alivePlayers()
end

function Boss:fireAt(x, y, tx, ty, speed, cfg)
  local World = require "src.world"
  local ang = math.atan2(ty - y, tx - x)
  cfg = cfg or {}
  Proj.spawn(World, x, y, {
    side = "enemy", dmg = cfg.dmg or 3, kind = cfg.kind or "orb",
    size = cfg.size or 6,
    vx = math.cos(ang) * speed, vy = math.sin(ang) * speed,
    life = cfg.life or 3, gravity = cfg.gravity,
  })
end

-- ==================================================================
-- 1. BRAMBLE MAW (Mosswood)
-- ==================================================================
local Bramblemaw = Boss.extend()
function Bramblemaw:init(x, y)
  Boss.init(self, x, y, { id = "bramblemaw", name = "BRAMBLE MAW",
    hp = 85, touchDmg = 3, w = 40, h = 44 })
  self.mouthOpen = false
end
function Bramblemaw:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.phaseT = self.phaseT + dt
  self.stateT = self.stateT - dt
  local cx, cy = self:center()

  -- rooted, not planted: the maw strains against its own vines
  -- (collision-guarded: a sway must never press it into the arena wall)
  if not self.rootX then self.rootX, self.rootY = self.x, self.y end
  local reach = 0
  if self.state == "sweep" then
    reach = math.min(1, self.phaseT / 0.45) * 26   -- lunge with the sweep
  elseif self.state == "open" then
    reach = math.max(0, 1 - self.phaseT / 0.5) * 26
  end
  local nx = self.rootX - reach + math.min(0, math.sin(self.t * 1.1) * 9)
  local ny = self.rootY + math.sin(self.t * 2.3) * 4
  if not PH.boxBlocked(nx, ny, self.w, self.h) then
    self.x, self.y = nx, ny
  end

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("volley", 2.2) end
    return
  end

  if self.state == "volley" then
    self.mouthOpen = false
    if not self.volleyN then self.volleyN = 5 self.volleyGap = 0.4 end
    self.volleyGap = self.volleyGap - dt
    if self.volleyGap <= 0 and self.volleyN > 0 then
      self.volleyGap = 0.38
      self.volleyN = self.volleyN - 1
      local px = cx - 40 - self.volleyN * 32 + U.rand(-10, 10)
      self:fireAt(cx - 10, self.y + 6, px, self.y - 120, 150,
        { kind = "orb", dmg = 2, gravity = 260, life = 3.5, size = 6 })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then
      self.volleyN = nil
      self:setState(U.chance(0.5) and "sweep" or "open", U.chance(0.5) and 1.8 or 3)
    end
  elseif self.state == "sweep" then
    self.mouthOpen = false
    if not self.swept then
      self.swept = true
      local World2 = require "src.world"
      for i = 0, 2 do
        Proj.spawn(World2, self.x - 4, self.y + self.h - 8, {
          side = "enemy", dmg = 3, kind = "shard", size = 6,
          vx = -(110 + i * 45), vy = 0, life = 3,
        })
      end
      if G.Audio then G.Audio.sfx("shoot1") end
      -- spawn a gnat harasser sometimes
      if U.chance(0.5) then
        local g = Entity.make("gnat", self.x - 60, self.y - 20)
        World:add(g)
      end
    end
    if self.stateT <= 0 then
      self.swept = nil
      self:setState("open", 3)
    end
  elseif self.state == "open" then
    self.mouthOpen = true
    if self.stateT <= 0 then
      self:setState("volley", 2.2)
    end
  end
end
function Bramblemaw:hurt(dmg, srcx, srcy, opts)
  if not self.mouthOpen then
    dmg = math.max(1, math.floor(dmg / 3))
    local World = require "src.world"
    World:fx("spark", self.x + 6, self.y + 10, { color = "fern", n = 3 })
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
function Bramblemaw:draw()
  local g = love.graphics
  local cx = self.x + self.w / 2
  local bob = math.sin(self.t * 2) * 2
  -- vines
  g.setColor(P.fern)
  for i = 0, 3 do
    local vx = self.x - 6 + i * 14
    g.rectangle("fill", vx, self.y - 14 + math.sin(self.t * 1.5 + i) * 3, 4, 26)
  end
  -- body: giant spitter head
  G.drawSprite("boss_bramblemaw",
    self.mouthOpen and 2 or (math.floor(self.t * 2.5) % 2 + 1),
    cx, self.y + self.h + bob,
    { sx = 1.3, sy = 1.6, white = math.max(0, (self.white or 0) * 6) })
  if self.mouthOpen then
    local pulse = 0.6 + math.sin(G.time * 8) * 0.3
    g.setColor(P.gold[1], P.gold[2], P.gold[3], pulse)
    g.circle("line", cx - 4, self.y + 12, 10 + pulse * 3)
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.bramblemaw = Bramblemaw

-- ==================================================================
-- 2. RUSTED WARDEN (Flooded miniboss)
-- ==================================================================
-- Shield law: the Warden's tower shield is IMPENETRABLE from the front.
-- Damage only lands from behind (after a charge, while it recovers) or
-- from any side while it is stunned (Lu's dome interrupting a charge).
-- That law holds until the ENRAGE below throws the shield away.
--
-- Movement tuning. Charge DISTANCE is not stored anywhere -- it falls out
-- of WARDEN_CHARGE x WARDEN_CHARGE_T (190 x 0.7 = ~133px). Change either
-- one and the distance moves with it.
local WARDEN_PATROL = 68     -- px/sec while stalking (the player runs at 112)
local WARDEN_CHARGE = 200    -- px/sec during the charge itself
local WARDEN_CHARGE_T = 1.2  -- seconds the charge lasts
local WARDEN_TURN = 0.8      -- seconds of hesitation before reversing

-- ENRAGE: below WARDEN_ENRAGE_AT health the Warden abandons its post. It
-- runs to the middle of the arena, throws the shield away, and from then
-- on does nothing but walk fast and throw fire with both hands. Once the
-- shield is down the front-armour rule is off -- it can be hurt anywhere.
local WARDEN_ENRAGE_AT = 0.25    -- health fraction that breaks it
local WARDEN_RUSH_SPEED = 155    -- px/sec running for the centre
local WARDEN_ENRAGE_SPEED = 96   -- px/sec once the shield is gone (patrol was 68)
local WARDEN_ENRAGE_GAP = 0.17   -- seconds between fireballs (hands alternate)
local WARDEN_ENRAGE_DMG = 2      -- damage per fireball
local WARDEN_ENRAGE_SPD = 190    -- px/sec fireball speed
local WARDEN_ENRAGE_RANGE = 46   -- px it tries to keep between itself and you

local Rustwarden = Boss.extend()
function Rustwarden:init(x, y)
  Boss.init(self, x, y, { id = "rustwarden", name = "RUSTED WARDEN",
    hp = 105, touchDmg = 3, w = 26, h = 30, reward = "module:hydroseals" })
  self.facing = -1
  self.enraged = false      -- the sequence has begun
  self.shieldGone = false   -- the shield has actually left the body
  self.hand = -1            -- which hand threw last (flips every shot)
end

-- Kick off the enrage. Called once, from update, the frame health crosses.
function Rustwarden:beginEnrage()
  self.enraged = true
  self.turnT = nil
  self.thrown = nil
  self.stunHinted = nil
  self:setState("rush", 4)
  Cam.shake(4, 0.5)
  if G.Audio then G.Audio.sfx("roar") end
  if G.game then
    G.game:announce("The Warden breaks post -- it is done guarding!", 2.2)
  end
end

-- The shield leaves the body and becomes a physical object on the floor.
function Rustwarden:dropShield()
  local World = require "src.world"
  self.shieldGone = true
  self.shield = {
    x = self.x + self.w / 2 + self.facing * 15,
    y = self.y + 14,
    vx = self.facing * 42,
    vy = -110,
    rot = 0,
    vr = self.facing * 5.2,
    groundY = self.y + self.h - 2,
    landed = false,
  }
  Cam.shake(5, 0.5)
  if G.Audio then G.Audio.sfx("crack") end
  World:fx("burst", self.x + self.w / 2 + self.facing * 14, self.y + 14,
    { color = "silver", n = 14, speed = 130 })
  if G.game then
    G.game:announce("The shield hits the floor. Hit it anywhere now.", 2.2)
  end
end
function Rustwarden:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.vy = math.min((self.vy or 0) + 700 * dt, 260)

  if self.state == "intro" then
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("stalk", 3.5) end
    return
  end

  -- the discarded shield keeps falling, then lies where it landed
  if self.shield and not self.shield.landed then
    local s = self.shield
    s.vy = s.vy + 700 * dt
    s.x = s.x + s.vx * dt
    s.y = s.y + s.vy * dt
    s.rot = s.rot + s.vr * dt
    if s.y >= s.groundY then
      s.y = s.groundY
      s.landed = true
      s.rot = self.facing * 1.35   -- comes to rest tipped on its edge
      Cam.shake(2, 0.25)
      if G.Audio then G.Audio.sfx("crumble") end
      World:fx("puff", s.x, s.y, { color = "slate", n = 10 })
    end
  end

  -- ---- ENRAGE: a one-way door, checked before any normal state runs
  if not self.enraged and self.hp <= self.maxhp * WARDEN_ENRAGE_AT then
    self:beginEnrage()
    return
  end

  local p = World:nearestPlayer(self:center())

  if self.state == "rush" then
    -- sprint for the middle of the arena. Shield still up, no attacks:
    -- this is the free window to reposition before the fight changes.
    local roomCx = World.w * T / 2
    local myCx = self.x + self.w / 2
    local d = U.sign(roomCx - myCx)
    if d ~= 0 then self.facing = d end
    self.vx = d * WARDEN_RUSH_SPEED
    PH.move(self, self.vx * dt, self.vy * dt)
    if math.abs(roomCx - myCx) < 10 or self.hitWall or self.stateT <= 0 then
      self.vx = 0
      self:setState("shielddrop", 1.1)
      self:dropShield()            -- flung in the direction it was running
      if p then
        local pd = U.sign(p.x - (self.x + self.w / 2))
        if pd ~= 0 then self.facing = pd end
      end
    end
  elseif self.state == "shielddrop" then
    -- planted while the shield tumbles away: a clean punish window, and
    -- the moment the front-armour rule stops applying
    self.vx = 0
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("rampage", 9e9) end
  elseif self.state == "rampage" then
    -- no shield, no charge, no patience: walks fast, throws constantly,
    -- turns on a dime. This state never ends.
    if p then
      local myCx = self.x + self.w / 2
      local d = U.sign(p.x - myCx)
      if d ~= 0 then self.facing = d end
      local gap = math.abs(p.x - myCx)
      if gap > WARDEN_ENRAGE_RANGE then
        self.vx = self.facing * WARDEN_ENRAGE_SPEED
      else
        self.vx = -self.facing * WARDEN_ENRAGE_SPEED * 0.45  -- back off, keep lobbing
      end
    else
      self.vx = 0
    end
    PH.move(self, self.vx * dt, self.vy * dt)

    if self.throwPose then
      self.throwPose = self.throwPose - dt
      if self.throwPose <= 0 then self.throwPose = nil end
    end
    self.fireGap = (self.fireGap or 0) - dt
    if self.fireGap <= 0 and p then
      self.fireGap = WARDEN_ENRAGE_GAP
      self.hand = -(self.hand or -1)   -- alternate: leading hand, off hand
      self.throwPose = 0.13
      local bx, by = self:center()
      local hx = bx + self.facing * self.hand * 11
      local hy = by + (self.hand > 0 and -9 or 2)
      self:fireAt(hx, hy, p.x + p.w / 2 + U.rand(-9, 9),
        p.y + p.h / 2 + U.rand(-7, 7), WARDEN_ENRAGE_SPD,
        { kind = "fireball", dmg = WARDEN_ENRAGE_DMG, size = 7, life = 2.6 })
      World:fx("burst", hx, hy, { color = "magma", n = 3, speed = 70 })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    -- heat coming off the unshielded body
    if U.chance(dt * 14) then
      World:fx("puff", self.x + U.rand(2, self.w - 2),
        self.y + U.rand(4, self.h - 6), { color = "flame", n = 1 })
    end
  elseif self.state == "stalk" then
    if p then
      local want = U.sign(p.x - self.x)
      -- slow to turn: only flip after a delay (the shield is heavy)
      if want ~= self.facing and want ~= 0 then
        self.turnT = (self.turnT or WARDEN_TURN) - dt
        if self.turnT <= 0 then
          self.facing = want
          self.turnT = nil
        end
      else
        self.turnT = nil
      end
      self.vx = self.facing * WARDEN_PATROL
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.stateT <= 0 then
      if U.chance(0.55) then
        self:setState("throw", 1.5)
        self.thrown = 0
        self.throwGap = 0.15
      else
        -- telegraph the charge: plant, rattle, roar
        self:setState("windup", 0.8)
        if p then self.facing = U.sign(p.x - self.x) ~= 0
          and U.sign(p.x - self.x) or self.facing end
        Cam.shake(2, 0.3)
        if G.Audio then G.Audio.sfx("bosswarn") end
      end
    end
  elseif self.state == "throw" then
    -- lob a trio of arcing bolts over the shield at the player
    self.vx = 0
    PH.move(self, 0, self.vy * dt)
    self.throwGap = self.throwGap - dt
    if self.throwGap <= 0 and self.thrown < 6 and p then
      self.throwGap = 0.2
      self.thrown = self.thrown + 1
      local cx = self.x + self.w / 2
      local ty = self.y - 4
      local grav = 430
      local flight = 0.75 + self.thrown * 0.12
      local tx = p.x + p.w / 2 + U.rand(-14, 14)
      local vx = (tx - cx) / flight
      local vy = ((p.y + p.h - ty) - 0.5 * grav * flight * flight) / flight
      Proj.spawn(World, cx, ty, {
        side = "enemy", dmg = 3, kind = "orb", size = 7,
        vx = vx, vy = vy, gravity = grav, life = 2.5,
      })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then
      self.thrown = nil
      self:setState("stalk", 3)
    end
  elseif self.state == "windup" then
    self.vx = 0
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then
      self:setState("charge", WARDEN_CHARGE_T)
      if G.Audio then G.Audio.sfx("roar") end
    end
  elseif self.state == "charge" then
    self.vx = self.facing * WARDEN_CHARGE
    PH.move(self, self.vx * dt, self.vy * dt)
    -- Lu's dome interrupts the charge and stuns the Warden
    local interrupted = false
    for _, pl in ipairs(World.players) do
      if pl.domeActive and not pl.dead and not pl.downed and not pl.idle then
        local dcx, dcy = pl.x + pl.w / 2, pl.y + pl.h / 2 - 4
        local bcx, bcy = self:center()
        local dx, dy = bcx - dcx, bcy - dcy
        local r = pl.domeRadius + self.w / 2
        if dx * dx + dy * dy < r * r then
          interrupted = true
          pl:domeAbsorb(2)
          -- bounce off the dome
          self.x = self.x - self.facing * 8
          World:fx("spark", bcx - self.facing * self.w / 2, bcy,
            { color = "cyan", n = 10 })
          break
        end
      end
    end
    if interrupted then
      Cam.shake(4, 0.35)
      if G.Audio then G.Audio.sfx("domehit") end
      if not self.stunHinted then
        self.stunHinted = true
        if G.game then G.game:announce("The dome staggers the Warden!", 2) end
      end
      self:setState("stunned", 3.0)
    elseif self.hitWall then
      Cam.shake(3, 0.25)
      if G.Audio then G.Audio.sfx("quake") end
      self:setState("recover", 1.0)
    elseif self.stateT <= 0 then
      self:setState("recover", 1.0)
    end
  elseif self.state == "recover" then
    -- winded after the charge: shield still up front, back wide open
    self.vx = 0
    PH.move(self, 0, self.vy * dt)
    if math.floor(self.phaseT * 6) ~= math.floor((self.phaseT + dt) * 6) then
      World:fx("trail", self.x + self.w / 2 - self.facing * 8,
        self.y + 4 + U.rand(-3, 3), { color = "silver", r = 1.5, t = 0.3 })
    end
    self.phaseT = self.phaseT + dt
    if self.stateT <= 0 then 
      self:setState("throw", 1.5)
      self.thrown = 0
      self.throwGap = 0.15
      -- self:setState("stalk", 3) end
    end
  elseif self.state == "stunned" then
    self.vx = 0
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("stalk", 3) end
  end
end
function Rustwarden:hurt(dmg, srcx, srcy, opts)
  -- shield law only applies while it still has a shield
  if self.state ~= "stunned" and not self.shieldGone then
    -- judge the attack by where it CAME from (the shooter if known --
    -- fast projectiles can tunnel past the midline before they connect)
    local ax = srcx
    if opts and opts.owner then ax = opts.owner.x + opts.owner.w / 2 end
    local side = ax and U.sign(ax - (self.x + self.w / 2)) or self.facing
    if side == self.facing or side == 0 then
      local World = require "src.world"
      World:fx("spark", self.x + self.w / 2 + self.facing * 14, self.y + 10,
        { color = "silver", n = 4 })
      if G.Audio then G.Audio.sfx("crack") end
      return false
    end
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
-- The discarded shield: tumbles when thrown, then lies on the floor for
-- the rest of the fight as a reminder of what it gave up.
function Rustwarden:drawShield()
  local s = self.shield
  if not s then return end
  local g = love.graphics
  g.push()
  g.translate(s.x, s.y)
  g.rotate(s.rot)
  g.setColor(P.gray)
  g.rectangle("fill", -4, -14, 8, 28)
  g.setColor(P.slate)
  g.rectangle("fill", -3, -13, 6, 26)
  g.setColor(P.silver[1], P.silver[2], P.silver[3], s.landed and 0.5 or 0.85)
  g.rectangle("fill", -1.5, -11, 3, 22)
  g.pop()
  g.setColor(1, 1, 1, 1)
end

function Rustwarden:draw()
  local g = love.graphics
  if self.shield and self.shield.landed then self:drawShield() end
  local wob = self.state == "charge" and love.math.random(-1, 1) or 0
  if self.state == "windup" then wob = math.sin(self.t * 40) * 1.5 end
  if self.state == "shielddrop" then wob = math.sin(self.t * 34) * 1.2 end
  local tint = { 1, 0.75, 0.55, 1 }
  if self.state == "stunned" then tint = { 1, 0.8, 0.6, 1 }
  elseif self.state == "recover" then tint = { 0.85, 0.7, 0.6, 1 } end
  -- enraged: running hot, and the sprite loses its shield column
  local frame
  if self.shieldGone then
    tint = { 1, 0.62, 0.42, 1 }
    if self.throwPose then
      frame = self.hand > 0 and 5 or 6      -- 5 overhead, 6 off hand low
    elseif self.state == "shielddrop" then
      frame = 3
    else
      frame = math.floor(self.t * 10) % 2 + 3
    end
  else
    frame = math.floor(self.t * 6) % 2 + 1
  end
  G.drawSprite("boss_rustwarden", frame,
    self.x + self.w / 2 + wob, self.y + self.h + 0.5,
    { sx = 1.3, sy = 1.3, flip = self.facing < 0,
      tint = tint,
      white = math.max(0, (self.white or 0) * 6) })
  if self.shield and not self.shield.landed then self:drawShield() end
  -- charge telegraph: flashing warning chevrons in the charge direction
  if self.state == "windup" then
    local blink = math.sin(G.time * 18) > 0
    if blink then
      g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.9)
      for i = 1, 3 do
        local bx = self.x + self.w / 2 + self.facing * (20 + i * 12)
        local by = self.y + self.h / 2
        g.polygon("fill", bx, by - 4, bx + self.facing * 5, by, bx, by + 4)
      end
      g.setColor(1, 1, 1, 1)
    end
  end
  -- shield glint on front (gone for good once the shield is thrown)
  if self.state ~= "stunned" and not self.shieldGone then
    g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
    local sx = self.x + self.w / 2 + self.facing * 15
    g.rectangle("fill", sx - 1, self.y + 2, 3, self.h - 6)
    g.setColor(1, 1, 1, 1)
  end
  -- enraged: the whole body is now a target, and it glows like one
  if self.shieldGone then
    local pulse = 0.35 + math.sin(G.time * 9) * 0.25
    g.setColor(P.magma[1], P.magma[2], P.magma[3], pulse * 0.55)
    g.rectangle("line", self.x - 1, self.y - 1, self.w + 2, self.h + 2)
    g.setColor(1, 1, 1, 1)
  end
  -- recovery: exposed back shimmer cue
  if self.state == "recover" then
    local pulse = 0.4 + math.sin(G.time * 10) * 0.3
    g.setColor(P.gold[1], P.gold[2], P.gold[3], pulse)
    local bx = self.x + self.w / 2 - self.facing * 15
    g.rectangle("line", bx - 2, self.y + 2, 4, self.h - 6)
    g.setColor(1, 1, 1, 1)
  end
end
Bosses.rustwarden = Rustwarden

-- ==================================================================
-- 3. TIDE ENGINE (Flooded boss)
-- ==================================================================
local Valve = Entity.extend()
function Valve:init(x, y, boss)
  Entity.init(self, x, y)
  self.kind = "enemy"
  self.heavy = true
  self.boss = boss
  self.w, self.h = 14, 18
  self.maxhp = 20
  self.hp = self.maxhp
  self.touchDmg = 0
  self.noKnockback = true
end
function Valve:update(dt)
  if self.regenT then
    self.regenT = self.regenT - dt
    if self.regenT <= 0 then
      self.regenT = nil
      self.hp = self.maxhp
      self.harmless = nil
      local World = require "src.world"
      World:fx("burst", self.x + 7, self.y + 9, { color = "teal", n = 8 })
    end
  end
end
function Valve:die()
  -- broken, will regen; never actually removed until boss dies
  self.hp = 0
  local World = require "src.world"
  World:fx("burst", self.x + 7, self.y + 9, { color = "sky", n = 12 })
  if G.Audio then G.Audio.sfx("break") end
  local b = self.boss
  -- TWO BOTS, TWO VALVES: with both players standing, the engine
  -- re-knits a lone broken valve in one second -- the pair must blow
  -- within half a second of each other. Solo keeps the classic rule.
  local coop2 = G.game and G.game.coop and #G.game:activePlayers() >= 2
  if coop2 then
    local other
    for _, v in ipairs(b.valves or {}) do if v ~= self then other = v end end
    if other and other.regenT and other.brokenAt
      and (b.t - other.brokenAt) <= 0.5 then
      self.regenT, self.regenMax = 13, 13
      other.regenT, other.regenMax = 13, 13
      other.brokenAt = nil
      if G.game then G.game:announce("BOTH VALVES BLOWN -- the engine is exposed!", 2.5) end
    else
      self.brokenAt = b.t
      self.regenT, self.regenMax = 1.0, 1.0
      if G.game and not b.taughtSync then
        b.taughtSync = true
        G.game:announce("A lone valve re-knits in a second. Blow BOTH together!", 3)
      end
    end
  else
    self.regenT, self.regenMax = 13, 13
  end
end
function Valve:hurt(dmg, srcx, srcy, opts)
  if self.regenT then return false end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
function Valve:draw()
  local g = love.graphics
  local broken = self.regenT ~= nil
  g.setColor(P.dark)
  g.rectangle("fill", self.x - 2, self.y - 2, self.w + 4, self.h + 4, 2, 2)
  g.setColor(broken and P.gray or P.teal)
  g.rectangle("fill", self.x, self.y, self.w, self.h, 2, 2)
  g.setColor(broken and P.slate or P.spark)
  g.circle("fill", self.x + 7, self.y + 9, broken and 2 or 4 + math.sin(G.time * 5))
  if broken then
    g.setColor(P.sky[1], P.sky[2], P.sky[3], 0.8)
    local frac = 1 - self.regenT / (self.regenMax or 13)
    g.rectangle("fill", self.x, self.y + self.h + 2, self.w * frac, 2)
  end
  g.setColor(1, 1, 1, 1)
end

-- TIDAL SURGE: each time the Engine's health crosses 75%, 50% or 25%
-- it stops fighting, inhales the arena (long, loud telegraph), then
-- fires a wall of water that crosses the room floor-to-ceiling. The
-- room offers no cover -- the ONLY safe place is inside Lu's dome.
local SURGE_AT = { 0.75, 0.5, 0.25 }  -- health fractions that trigger it
local SURGE_CHARGE = 2.0              -- seconds of telegraph before it fires
local SURGE_SPEED = 340               -- pixels/second the wall travels
local SURGE_HALFW = 16                -- half-thickness of the killing edge
local SURGE_DMG = { 4, 6, 8 }         -- Story / Normal / Veteran
local SURGE_DOME_COST = 5             -- energy bite for sheltering one body

local Tideengine = Boss.extend()
function Tideengine:init(x, y)
  Boss.init(self, x, y, { id = "tideengine", name = "TIDE ENGINE",
    hp = 125, touchDmg = 3, w = 44, h = 36 })
  self.surgeIdx = 1     -- which SURGE_AT threshold we are waiting on
  self.surgeDir = -1    -- flipped on every surge, so sides alternate
end

-- Start a surge: pick the side it comes from, park the wall off-screen,
-- and warn the players. The wall does not move until SURGE_CHARGE is up.
function Tideengine:beginSurge()
  local World = require "src.world"
  self:setState("surge", SURGE_CHARGE + 12)
  self.surgeDir = -(self.surgeDir or -1)
  self.surgeX = self.surgeDir > 0 and -SURGE_HALFW or World.w * T + SURGE_HALFW
  self.surgeFired = false
  self.surgeHit = {}
  if G.Audio then G.Audio.sfx("surgecharge") end
  if G.game then
    G.game:announce("THE TIDE ENGINE INHALES -- get inside the dome!", 2.4)
  end
end

-- One damage pass for the moving wall. Each player is hit at most once
-- per surge. A player standing inside ANY live dome is sheltered; the
-- dome's owner pays energy instead.
function Tideengine:surgeDamage(World)
  local dmg = SURGE_DMG[G.run.difficulty] or 6
  for _, pl in ipairs(World.players) do
    if not pl.dead and not pl.downed and not pl.idle and not self.surgeHit[pl] then
      local px, py = pl.x + pl.w / 2, pl.y + pl.h / 2
      if math.abs(px - self.surgeX) < SURGE_HALFW + pl.w / 2 then
        self.surgeHit[pl] = true
        local sheltered = false
        for _, q in ipairs(World.players) do
          if q.domeActive and not q.dead and not q.downed then
            local dx = px - (q.x + q.w / 2)
            local dy = py - (q.y + q.h / 2 - 4)
            if dx * dx + dy * dy < q.domeRadius * q.domeRadius then
              sheltered = true
              q:domeAbsorb(SURGE_DOME_COST)
            end
          end
        end
        if sheltered then
          World:fx("spark", px, py, { color = "cyan", n = 12 })
          if G.Audio then G.Audio.sfx("domehit") end
        else
          pl:takeDamage(dmg, self.surgeX)
          World:fx("burst", px, py, { color = "sky", n = 12, speed = 150 })
        end
      end
    end
  end
end

function Tideengine:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.phaseT = self.phaseT + dt
  self.stateT = self.stateT - dt

  if not self.valves then
    -- spawn valve pods flanking the boss
    self.valves = {}
    local roomW = World.w * T
    local floorY = World.h * T - 5 * T - 18
    local v1 = Valve.new(self.x - 90, self.y, self)
    local v2 = Valve.new(self.x + self.w + 76, self.y, self)
    World:add(v1) World:add(v2)
    self.valves = { v1, v2 }
    World.waterLine = World.h * T - 40
  end

  local exposed = true
  for _, v in ipairs(self.valves) do
    if not v.regenT then exposed = false end
  end
  self.exposed = exposed

  -- water level breathes up and down. During a surge charge the Engine
  -- is sucking the room dry; when it fires, everything comes back at once.
  local base = World.h * T
  local amp = self.exposed and 46 or (86 + math.sin(self.t * 0.5) * 40)
  if self.state == "surge" then
    if self.surgeFired then
      amp = 104
    else
      amp = math.max(6, 46 * (1 - self.phaseT / SURGE_CHARGE))
    end
  end
  World.waterLine = U.lerp(World.waterLine or base - 40, base - amp,
    dt * (self.state == "surge" and 3.5 or 1.5))

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("bubbles", 3) end
    return
  end

  -- health thresholds arm the surge; never interrupt one already running
  if self.state ~= "surge" then
    local th = SURGE_AT[self.surgeIdx]
    if th and self.hp <= self.maxhp * th then
      -- one huge hit can cross two lines at once: consume them all so the
      -- player never eats two surges back to back
      while SURGE_AT[self.surgeIdx] and self.hp <= self.maxhp * SURGE_AT[self.surgeIdx] do
        self.surgeIdx = self.surgeIdx + 1
      end
      self.minesDropped = nil
      self:beginSurge()
      return
    end
  end

  if self.state == "surge" then
    local roomW = World.w * T
    if not self.surgeFired and self.phaseT < SURGE_CHARGE then
      -- CHARGE: rattle the room and drag debris toward the intakes
      Cam.shake(1 + self.phaseT * 1.6, 0.12)
      if U.chance(dt * 26) then
        local sx = U.rand(0, roomW)
        local sy = U.rand(World.h * T - 70, World.h * T - 8)
        World:fx("spark", sx, sy, {
          color = "sky", n = 2,
          angle = math.atan2((self.y + 14) - sy, (self.x + self.w / 2) - sx),
        })
      end
    elseif not self.surgeFired then
      -- FIRE
      self.surgeFired = true
      Cam.shake(7, 0.7)
      if G.Audio then G.Audio.sfx("surgeblast") end
      World:fx("burst", self.x + self.w / 2, self.y + self.h,
        { color = "sky", n = 24, speed = 240 })
    else
      -- SWEEP: the wall crosses the room, hitting anything not domed
      self.surgeX = self.surgeX + self.surgeDir * SURGE_SPEED * dt
      self:surgeDamage(World)
      local gone = (self.surgeDir > 0 and self.surgeX > roomW + SURGE_HALFW)
                or (self.surgeDir < 0 and self.surgeX < -SURGE_HALFW)
      if gone or self.stateT <= 0 then
        self.surgeX = nil
        self.surgeFired = nil
        self.surgeHit = nil
        self:setState("bubbles", 2.5)
      end
    end
  elseif self.state == "bubbles" then
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 then
      self.gap = self.exposed and 1.1 or 0.55
      local cx = self.x + U.rand(4, self.w - 4)
      local targets = self:aliveTargets()
      if #targets > 0 then
        local p = U.choose(targets)
        self:fireAt(cx, self.y + self.h - 4, p.x + p.w / 2, p.y, 120,
          { kind = "drop", dmg = 2, size = 6, life = 3 })
        if G.Audio then G.Audio.sfx("splash") end
      end
    end
    if self.stateT <= 0 then
      self:setState(U.chance(0.4) and "mines" or "bubbles", 3)
    end
  elseif self.state == "mines" then
    if not self.minesDropped then
      self.minesDropped = true
      for i = 1, 8 do
        local mx = self.x + U.rand(-70, self.w + 70)
        local mine = Entity.make("depthmine", mx, self.y + 30)
        World:add(mine)
      end
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then
      self.minesDropped = nil
      self:setState("bubbles", 3.5)
    end
  end
end
function Tideengine:hurt(dmg, srcx, srcy, opts)
  if not self.exposed then
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "teal", n = 3 })
    return false
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
function Tideengine:onDeath()
  Boss.onDeath(self)
  for _, v in ipairs(self.valves or {}) do v.dead = true end
  -- a surge dies with the machine that was holding it
  self.surgeX = nil
  self.surgeFired = nil
  self.surgeHit = nil
end
function Tideengine:draw()
  local g = love.graphics
  local World = require "src.world"
  local cx = self.x + self.w / 2
  local charging = self.state == "surge" and not self.surgeFired
  -- pipes
  g.setColor(P.navy)
  g.rectangle("fill", cx - 30, self.y - 40, 8, 46)
  g.rectangle("fill", cx + 22, self.y - 40, 8, 46)
  -- body: big machine (frame 3 = intakes open, core white-hot)
  local frame = self.exposed and 2 or 1
  if charging then frame = 3 end
  G.drawSprite("boss_tideengine", frame, cx, self.y + self.h + 6,
    { sx = 2.4, sy = 1.9, white = math.max(0, (self.white or 0) * 6) })
  -- core glow
  if self.exposed and not charging then
    local pulse = 0.5 + math.sin(G.time * 7) * 0.3
    g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse)
    g.circle("line", cx, self.y + 14, 10 + pulse * 4)
    g.setColor(1, 1, 1, 1)
  end

  -- ---- tidal surge
  if self.state == "surge" then
    local roomW, roomH = World.w * T, World.h * T
    if charging then
      local k = math.min(1, self.phaseT / SURGE_CHARGE)
      -- intake rings collapsing into the core
      g.setColor(P.sky[1], P.sky[2], P.sky[3], 0.2 + k * 0.55)
      for i = 0, 1 do
        local r = 54 * (1 - ((self.t * 1.7 + i * 0.5) % 1)) + 6
        g.circle("line", cx, self.y + 14, r)
      end
      -- warning bar on the wall it will come from
      local ex = self.surgeDir > 0 and 0 or (roomW - 12)
      g.setColor(P.spark[1], P.spark[2], P.spark[3],
        0.15 + k * 0.3 + math.sin(G.time * 18) * 0.15)
      g.rectangle("fill", ex, 0, 12, roomH)
      g.setColor(1, 1, 1, 1)
    elseif self.surgeX then
      local x, d = self.surgeX, self.surgeDir
      -- trailing body of water, then the dark core, then the foam crest
      g.setColor(P.water[1], P.water[2], P.water[3], 0.45)
      g.rectangle("fill", math.min(x, x - d * 64), 0, 64, roomH)
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.8)
      g.rectangle("fill", math.min(x, x - d * 26), 0, 26, roomH)
      g.setColor(1, 1, 1, 1)
      local base = math.floor(G.time * 16)
      for yy = 0, roomH - 1, 16 do
        G.drawSprite("fx_surgecrest", base + math.floor(yy / 16), x, yy + 16,
          { flip = d < 0 })
      end
    end
  end
end
Bosses.tideengine = Tideengine

-- ==================================================================
-- 4. SLAG GOLEM (Furnace miniboss)
-- ==================================================================
local Slaggolem = Boss.extend()
function Slaggolem:init(x, y)
  Boss.init(self, x, y, { id = "slaggolem", name = "SLAG GOLEM",
    hp = 160, touchDmg = 8, w = 30, h = 26 })
end
function Slaggolem:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.vy = math.min((self.vy or 0) + 640 * dt, 280)

  if self.state == "intro" then
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("hop", 1) end
    return
  end

  if self.state == "hop" then
    if self.onGround then
      self.vx = 0
      if self.stateT <= 0 then
        local p = World:nearestPlayer(self:center())
        if p then self.facing = U.sign(p.x - self.x) end
        if U.chance(0.3) then
          self:setState("geyser", 1.6)
        else
          self.vy = -270
          self.vx = self.facing * 95
          self:setState("air", 4)
          if G.Audio then G.Audio.sfx("jump") end
        end
      end
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
  elseif self.state == "air" then
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.hitWall then self.vx = -self.vx self.facing = -self.facing end
    if self.onGround then
      Cam.shake(4, 0.3)
      if G.Audio then G.Audio.sfx("quake") end
      -- landing splash of lava pellets
      for i = -4, 4 do
        if i ~= 0 then
          Proj.spawn(World, self.x + self.w / 2, self.y + 4, {
            side = "enemy", dmg = 5, kind = "fireball", size = 6,
            vx = i * 55, vy = -170, gravity = 330, life = 4,
          })
        end
      end
      if U.chance(0.4) and self.hp < self.maxhp * 0.7 then
        for i = -2, 2 do
          local mini = Entity.make("slagblob", self.x + U.rand(-30, 30), self.y - 8)
          mini.mini = true
          mini.w, mini.h = 8, 7
          mini.maxhp, mini.hp = 8, 8
          mini.drops = { shards = 1 }
          World:add(mini)
        end
      end
      self:setState("hop", U.rand(0.6, 1.2))
    end
  elseif self.state == "geyser" then
    PH.move(self, 0, self.vy * dt)
    if not self.geysered and self.stateT < 1 then
      self.geysered = true
      -- telegraphed lava columns under each player
      for _, p in ipairs(self:aliveTargets()) do
        local gx = p.x + p.w / 2
        World:add({
          kind = "hazard", x = gx - 12, y = 0, w = 24, h = 0, t = 0,
          dead = false, layer = 4, warned = false,
          update = function(h, dt2)
            h.t = h.t + dt2
            local World2 = require "src.world"
            if h.t > 0.7 and not h.fired then
              h.fired = true
              Cam.shake(2, 0.2)
              for _, pl in ipairs(World2.players) do
                if not pl.dead and not pl.downed and not pl.idle
                  and pl.x + pl.w > h.x and pl.x < h.x + h.w then
                  pl:takeDamage(8, h.x)
                end
              end
              if G.Audio then G.Audio.sfx("explode") end
            end
            if h.t > 1.1 then h.dead = true end
          end,
          draw = function(h)
            local g2 = love.graphics
            local World2 = require "src.world"
            if h.t <= 0.7 then
              g2.setColor(P.magma[1], P.magma[2], P.magma[3],
                0.25 + math.sin(G.time * 12) * 0.15)
            else
              g2.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 0.85)
            end
            g2.rectangle("fill", h.x, 0, h.w, World2.h * T)
            g2.setColor(1, 1, 1, 1)
          end,
        })
      end
      if G.Audio then G.Audio.sfx("roar") end
    end
    if self.stateT <= 0 then
      self.geysered = nil
      self:setState("hop", 0.8)
    end
  end
end
function Slaggolem:draw()
  G.drawSprite("boss_slaggolem", math.floor(self.t * 4) % 2 + 1,
    self.x + self.w / 2, self.y + self.h + 0.5,
    { sx = 2.1, sy = 1.6, flip = self.facing < 0,
      white = math.max(0, (self.white or 0) * 6) })
end
Bosses.slaggolem = Slaggolem

-- ==================================================================
-- 5. THE CRUCIBLE (Furnace boss) -- link shot proves itself here
-- It hovers four tiles up between two flanking gun platforms. On its
-- vent cycle it slams down in the arena's center and vents for five
-- seconds -- the ONLY window a LINK SHOT shatters the lattice. Break
-- it there and it is stunned for five more; when it finally rises, it
-- vomits a swarm of slaglings.
-- ==================================================================
local Crucible = Boss.extend()
function Crucible:init(x, y)
  Boss.init(self, x, y, { id = "crucible", name = "THE CRUCIBLE",
    hp = 155, touchDmg = 5, w = 36, h = 36, reward = "module:corekey1" })
  self.shielded = true
  self.ventsOpen = false
  self.ventT = 9          -- hover time until the next vent slam
  self.shieldHintT = 11
  self.homeX, self.homeY = x, y
end
function Crucible:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  local cx0 = World.w * T / 2
  local floorTopY = World.h * T - 5 * T

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("spiral", 5) end
    return
  end

  local hovering = self.state == "spiral" or self.state == "wave"
  if hovering then
    -- float in a slow circle between the gun platforms
    self.x = self.homeX + math.cos(self.t * 0.7) * 24
    self.y = self.homeY + math.sin(self.t * 1.1) * 8
    self.ventT = self.ventT - dt
    self.shieldHintT = self.shieldHintT - dt
    if self.shieldHintT <= 0 then
      self.shieldHintT = 20
      if G.game then
        G.game:announce("The lattice shrugs off small arms. Wait for the slam.", 3)
      end
    end
    if self.ventT <= 0 then
      self.ventT = 11
      self:setState("ventapproach", 1.4)
      if G.Audio then G.Audio.sfx("bosswarn") end
    end
  end

  if self.state == "spiral" then
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 then
      self.gap = 0.22
      self.spiralA = (self.spiralA or 0) + 0.7
      local cx, cy = self:center()
      for k = 0, 1 do
        local a = self.spiralA + k * math.pi
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = 3, kind = "fireball", size = 6,
          vx = math.cos(a) * 110, vy = math.sin(a) * 110, life = 2.6,
        })
      end
      if G.Audio then G.Audio.sfx("shoot4") end
    end
    if self.stateT <= 0 then self:setState("wave", 2.5) end
  elseif self.state == "wave" then
    if not self.waved then
      self.waved = true
      local cx = self.x + self.w / 2
      local floorY = World.h * T - 24
      for dir = -1, 1, 2 do
        for i = 1, 3 do
          Proj.spawn(World, cx, floorY, {
            side = "enemy", dmg = 3, kind = "fireball", size = 8,
            vx = dir * (60 + i * 35), vy = 0, life = 2.8,
          })
        end
      end
      if G.Audio then G.Audio.sfx("roar") end
    end
    if self.stateT <= 0 then
      self.waved = nil
      self:setState("spiral", 5)
    end
  elseif self.state == "ventapproach" then
    -- glide to the arena's center
    self.x = U.approach(self.x, cx0 - self.w / 2, 160 * dt)
    if self.stateT <= 0 or math.abs(self.x - (cx0 - self.w / 2)) < 3 then
      self:setState("ventslam", 3)
    end
  elseif self.state == "ventslam" then
    -- drop like a foundry weight
    self.vy = (self.vy or 0) + 1000 * dt
    self.y = self.y + self.vy * dt
    if self.y + self.h >= floorTopY then
      self.y = floorTopY - self.h
      self.vy = 0
      Cam.shake(6, 0.5)
      if G.Audio then G.Audio.sfx("explode") end
      local scx = self.x + self.w / 2
      for dir = -1, 1, 2 do
        Proj.spawn(World, scx + dir * (self.w / 2 + 6), floorTopY - 8, {
          side = "enemy", dmg = 3, kind = "fireball", size = 7,
          vx = dir * 160, vy = 0, life = 1.4,
        })
      end
      self.ventsOpen = true
      self:setState("venting", 5)
      if G.game then G.game:announce("It slams down, venting -- NOW is the link window!", 2.5) end
      if G.Audio then G.Audio.sfx("domeoff") end
    end
  elseif self.state == "venting" then
    -- five grounded seconds of open vents; the only shatter window
    if self.stateT <= 0 then
      self.ventsOpen = false
      self:setState("rise", 2)
      if G.Audio then G.Audio.sfx("domeon") end
    end
  elseif self.state == "stunned" then
    -- lattice shattered mid-vent: five helpless seconds
    self.ventsOpen = false
    if self.stateT <= 0 then
      self.shielded = true
      self.spewSwarm = true
      self:setState("rise", 2)
      if G.game then G.game:announce("The shield lattice reknits...", 1.6) end
      if G.Audio then G.Audio.sfx("domeon") end
    end
  elseif self.state == "rise" then
    self.y = U.approach(self.y, self.homeY, 90 * dt)
    if math.abs(self.y - self.homeY) < 3 or self.stateT <= 0 then
      self.y = self.homeY
      if self.spewSwarm then
        -- it remembers being hurt: a swarm of slaglings
        self.spewSwarm = nil
        for i = 1, 5 do
          local e = Entity.make("slagling",
            self.x + self.w / 2 + U.rand(-40, 40), self.y + self.h)
          World:add(e)
        end
        World:fx("burst", self.x + self.w / 2, self.y + self.h,
          { color = "magma", n = 16, speed = 140 })
        if G.game then G.game:announce("It spews a tide of slaglings!", 2) end
        if G.Audio then G.Audio.sfx("roar") end
      end
      self:setState("spiral", 5)
    end
  end
end
function Crucible:hurt(dmg, srcx, srcy, opts)
  if self.state == "stunned" then
    return Entity.hurt(self, dmg, srcx, srcy, opts)
  end
  if self.shielded then
    -- ONLY a link shot, ONLY during the grounded vent, shatters it
    if opts and opts.link and self.ventsOpen then
      self.shielded = false
      self.ventsOpen = false
      self:setState("stunned", 5)
      Cam.shake(4, 0.4)
      if G.game then G.game:announce("SHIELD SHATTERED -- it reels, stunned!", 2) end
      if G.Audio then G.Audio.sfx("break") end
      return Entity.hurt(self, dmg, srcx, srcy, opts)
    end
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "magma", n = 3 })
    if opts and opts.link and not self.linkHintT then
      self.linkHintT = true
      if G.game then
        G.game:announce("The lattice held... link it while it VENTS on the ground!", 2.2)
      end
    end
    return false
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
function Crucible:draw()
  local g = love.graphics
  local cx, cy = self:center()
  G.drawSprite("boss_crucible", math.floor(self.t * 3) % 2 + 1, cx, self.y + self.h,
    { sx = 2.0, sy = 1.7, white = math.max(0, (self.white or 0) * 6) })
  -- rotating shield ring
  if self.shielded then
    for i = 0, 5 do
      local a = self.t * 2 + i * math.pi / 3
      local sx = cx + math.cos(a) * 30
      local sy = cy + math.sin(a) * 26
      g.setColor(P.hotcore)
      g.polygon("fill", sx, sy - 5, sx + 4, sy, sx, sy + 5, sx - 4, sy)
      g.setColor(P.magma)
      g.polygon("line", sx, sy - 5, sx + 4, sy, sx, sy + 5, sx - 4, sy)
    end
    if self.ventsOpen then
      local vp = 0.6 + math.sin(G.time * 12) * 0.4
      for side = -1, 1, 2 do
        local vx = cx + side * 16
        local vy = self.y + self.h - 6
        g.setColor(P.spark[1], P.spark[2], P.spark[3], vp)
        g.rectangle("fill", vx - 3, vy, 6, 8)
        g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], vp * 0.8)
        g.rectangle("line", vx - 4, vy - 1, 8, 10)
      end
      -- vent exhaust plume
      g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 0.35)
      g.circle("fill", cx, self.y - 6, 8 + math.sin(G.time * 10) * 3)
    end
  else
    local pulse = 0.5 + math.sin(G.time * 9) * 0.35
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], pulse)
    g.circle("line", cx, cy, 26 + pulse * 4)
    -- stun stars
    if self.state == "stunned" then
      for i = 0, 2 do
        local a = G.time * 3 + i * math.pi * 2 / 3
        g.setColor(P.gold)
        g.circle("fill", cx + math.cos(a) * 18, self.y - 6 + math.sin(a) * 4, 1.5)
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.crucible = Crucible

-- ==================================================================
-- 6. THE CONDUCTOR (Crystal boss)
-- Co-op bonus: after each refraction storm it hangs two resonance
-- BELLS at opposite ends of the arena. Silence both within half a
-- second of each other and the Conductor is stunned for 4s. Optional
-- teamwork -- the fight never requires it, solo is untouched.
-- ==================================================================
local Bell = Entity.extend()
function Bell:init(x, y, boss, idx)
  Entity.init(self, x, y)
  self.kind = "enemy"
  self.heavy = true
  self.noKnockback = true
  self.boss = boss
  self.idx = idx
  self.w, self.h = 12, 14
  self.maxhp = 6
  self.hp = 6
  self.touchDmg = 0
  self.harmless = true
  self.life = 7
  self.lightR = 20
end
function Bell:update(dt)
  self.t = (self.t or 0) + dt
  self.life = self.life - dt
  if self.life <= 0 or (self.boss and self.boss.dead) then self.dead = true end
end
function Bell:onDeath()
  local World = require "src.world"
  World:fx("burst", self.x + 6, self.y + 7, { color = "orchid", n = 10 })
  if G.Audio then G.Audio.sfx("crack") end
  local b = self.boss
  if not b or b.dead then return end
  b.bellBrokeAt = b.bellBrokeAt or {}
  b.bellBrokeAt[self.idx] = b.t
  local o = self.idx == 1 and 2 or 1
  if b.bellBrokeAt[o] and math.abs(b.bellBrokeAt[o] - b.t) <= 0.5 then
    b.bellBrokeAt = {}
    b:setState("stunned", 4)
    b.vx, b.vy = 0, 0
    if G.game then G.game:announce("The chord lands! The Conductor reels, silenced!", 2.5) end
    if G.Audio then G.Audio.sfx("bosswarn") end
  end
end
function Bell:draw()
  local g = love.graphics
  local cx = self.x + 6
  local swing = math.sin(G.time * 4 + self.idx) * 2
  g.setColor(P.slate)
  g.rectangle("fill", cx - 1, self.y - 6, 2, 6)
  g.setColor(P.orchid)
  g.polygon("fill", cx - 6 + swing, self.y + 10, cx + 6 + swing, self.y + 10,
    cx + 4 + swing, self.y, cx - 4 + swing, self.y)
  g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.5 + math.sin(G.time * 6) * 0.3)
  g.circle("fill", cx + swing, self.y + 11, 2)
  g.setColor(1, 1, 1, 1)
end

local Prismtyrant = Boss.extend()
function Prismtyrant:init(x, y)
  Boss.init(self, x, y, { id = "prismtyrant", name = "THE CONDUCTOR",
    hp = 145, touchDmg = 4, w = 28, h = 34, reward = "module:corekey2" })
  self.homeX, self.homeY = x, y
  self.stormAt = { 0.75, 0.5, 0.25 }
end
function Prismtyrant:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.y = self.homeY + math.sin(self.t * 1.3) * 10

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("beams", 4) end
    return
  end

  -- refraction storm at hp thresholds
  local frac = self.hp / self.maxhp
  if self.stormAt[1] and frac <= self.stormAt[1] then
    table.remove(self.stormAt, 1)
    self:setState("storm", 4)
    G.game:announce("REFRACTION STORM! Get under Lu's dome!", 2.5)
    if G.Audio then G.Audio.sfx("bosswarn") end
  end

  if self.state == "beams" then
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 then
      self.gap = 1.1
      local targets = self:aliveTargets()
      if #targets > 0 then
        local p = U.choose(targets)
        local cx, cy = self:center()
        local px, py = p:center()
        local ang = math.atan2(py - cy, px - cx)
        for off = -0.18, 0.18, 0.18 do
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = 3, kind = "shard", size = 5,
            vx = math.cos(ang + off) * 190, vy = math.sin(ang + off) * 190,
            life = 2.2,
          })
        end
        if G.Audio then G.Audio.sfx("shoot4") end
      end
    end
    if self.stateT <= 0 then
      self:setState(U.chance(0.35) and "wisps" or "blink", 1.5)
    end
  elseif self.state == "wisps" then
    if not self.spawned then
      self.spawned = true
      for i = 1, 2 do
        World:add(Entity.make("prismwisp", self.x + U.rand(-50, 50), self.y + U.rand(-20, 20)))
      end
      if G.Audio then G.Audio.sfx("teleport") end
    end
    if self.stateT <= 0 then
      self.spawned = nil
      self:setState("beams", 4)
    end
  elseif self.state == "blink" then
    if not self.blinked then
      self.blinked = true
      World:fx("burst", self:center())
      self.homeX = U.clamp(self.homeX + U.rand(-90, 90), 60, World.w * T - 90)
      self.x = self.homeX
      if G.Audio then G.Audio.sfx("teleport") end
    end
    if self.stateT <= 0 then
      self.blinked = nil
      self:setState("beams", 4)
    end
  elseif self.state == "storm" then
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 then
      self.gap = 0.12
      local rx = Cam.x + U.rand(0, G.VW)
      Proj.spawn(World, rx, Cam.y - 8, {
        side = "enemy", dmg = 2, kind = "shard", size = 4,
        vx = U.rand(-20, 20), vy = 200, life = 2.2,
      })
    end
    if self.stateT <= 0 then
      self:setState("beams", 4)
      -- co-op bonus: hang the resonance bells after each storm
      if G.game and G.game.coop and #G.game:activePlayers() >= 2 then
        local b1 = Bell.new(70, World.h * T - 7 * T, self, 1)
        local b2 = Bell.new(World.w * T - 82, World.h * T - 7 * T, self, 2)
        World:add(b1) World:add(b2)
        if not self.taughtBells then
          self.taughtBells = true
          G.game:announce("Two bells ring off-key... silence them TOGETHER.", 3)
        end
      end
    end
  elseif self.state == "stunned" then
    -- silenced by the chord: helpless and fully vulnerable
    if self.stateT <= 0 then self:setState("beams", 4) end
  end
end
function Prismtyrant:hurt(dmg, srcx, srcy, opts)
  if self.state == "storm" then
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2, self.y + 8, { color = "orchid", n = 3 })
    return false
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
function Prismtyrant:draw()
  local g = love.graphics
  local cx, cy = self:center()
  -- orbiting shards
  for i = 0, 2 do
    local a = self.t * 1.5 + i * math.pi * 2 / 3
    local sx = cx + math.cos(a) * 26
    local sy = cy + math.sin(a) * 18
    g.setColor(P.orchid)
    g.polygon("fill", sx, sy - 4, sx + 3, sy, sx, sy + 4, sx - 3, sy)
  end
  G.drawSprite("boss_prismtyrant", math.floor(self.t * 5) % 2 + 1, cx, self.y + self.h,
    { sx = 2.3, sy = 1.5, white = math.max(0, (self.white or 0) * 6) })
  if self.state == "storm" then
    local pulse = 0.5 + math.sin(G.time * 10) * 0.4
    g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse)
    g.circle("line", cx, cy, 24 + pulse * 6)
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.prismtyrant = Prismtyrant

-- ==================================================================
-- 7. AERIE SENTINEL (Skyroot boss)
-- ==================================================================
-- She never teleports. Every position change is a flight, including the way
-- back onto the figure-8, which is what the old version got wrong: it wrote
-- self.x straight from a sine of self.t, so leaving and re-entering the
-- pattern snapped her across the room. The pattern now runs on its own phase
-- clock (self.gp) and she flies onto it.
--
-- The loop: figure-8 -> fly to a corner perch -> 1s charge (her one open
-- window) -> either a 2s directional gale or a dive. The dive either latches
-- onto a player and eats them, bounces off Lu's dome and stuns her, or
-- whiffs into the floor.
local AERIE_CHARGE_T = 1.0       -- telegraph at the perch: the punish window
-- MINIMUM seconds of fight time before the next gale. She will not abandon a
-- stoop in flight or a victim in her talons, and she still has to reach a
-- perch and charge, so at this value the gale actually LANDS every ~13-15s.
-- Raising it does not stretch the gap smoothly: it jumps in ~6.5s steps,
-- because a late gale has to wait for a gap in the dive cycle.
local AERIE_GUST_EVERY = 10
local AERIE_GUST_T = 2.0         -- how long a gale blows
local AERIE_GUST_FORCE = 1250    -- px/sec^2 of shove in the open
local AERIE_GUST_SHELTER = 0.12  -- fraction of that you feel behind cover
local AERIE_SHELTER_TILES = 3    -- how far windward cover still counts
local AERIE_DIVE_EVERY = 6.5     -- seconds between dives
local AERIE_DIVE_SPEED = 620     -- px/sec of the stoop
local AERIE_LATCH_T = 4.0        -- how long she eats for
local AERIE_MUNCH_GAP = 0.5      -- seconds between bites
local AERIE_MUNCH_DMG = 3        -- damage per bite (24 over a full latch)
local AERIE_MISS_T = 1.0         -- floor time after a whiffed dive
local AERIE_DOME_STUN = 4.0      -- stun for hitting Lu's shield
local AERIE_FLY = 340            -- px/sec when repositioning

local Aerie = Boss.extend()
function Aerie:init(x, y)
  Boss.init(self, x, y, { id = "aeriesentinel", name = "AERIE SENTINEL",
    hp = 145, touchDmg = 4, w = 34, h = 20, reward = "module:corekey3" })
  self.homeY = y
  self.gp = 0              -- figure-8 phase, advances in every state
  self.gustClock = 0
  self.diveClock = 0
  self.perchSide = 1       -- flips each attack so she alternates corners
end

-- Where the figure-8 is right now.
function Aerie:glidePoint(World)
  local cx = World.w * T / 2
  return cx + math.sin(self.gp * 1.1) * (World.w * T / 2 - 80) - self.w / 2,
         self.homeY + math.sin(self.gp * 2.2) * 22
end

-- The two fixed corner perches, above every platform in the arena.
function Aerie:perchPoint(World, side)
  local margin = 5 * T
  local x = side < 0 and margin or (World.w * T - margin - self.w)
  return x, self.homeY - 16
end

-- Fly toward a point at AERIE_FLY. Returns true on arrival. The arrival
-- snap is capped at one frame of travel, so it can never read as a jump.
function Aerie:flyTo(tx, ty, dt)
  local dx, dy = tx - self.x, ty - self.y
  local d = math.sqrt(dx * dx + dy * dy)
  local step = AERIE_FLY * dt
  if d <= step then
    self.x, self.y = tx, ty
    return true
  end
  self.x = self.x + dx / d * step
  self.y = self.y + dy / d * step
  if math.abs(dx) > 2 then self.facing = dx > 0 and 1 or -1 end
  return false
end

-- Is this player behind something, on the windward side?
function Aerie:sheltered(World, p, dir)
  local ty = math.floor((p.y + p.h / 2) / T)
  local tx = math.floor((p.x + p.w / 2) / T)
  for i = 1, AERIE_SHELTER_TILES do
    local cx = tx - dir * i          -- windward = back along the wind
    if World:isSolid(cx, ty) then return true end
  end
  -- or tucked under a platform
  return World:isSolid(tx, ty - 1) or World:isOneway(tx, ty - 1)
end
-- Let go of whoever she is holding and climb back to the pattern.
function Aerie:releaseLatch(World)
  local p = self.latched
  self.latched = nil
  self.munchGap = nil
  if p and p.pinnedT and p.pinnedT > 0 then p:freeFromPin(false) end
  self:setState("climb", 6)
end

-- Called by Player:freeFromPin when the victim tears loose on their own.
function Aerie:onPinReleased(p, struggled)
  if self.latched == p then
    self.latched = nil
    self.munchGap = nil
    if struggled then
      Cam.shake(3, 0.3)
      if G.game then G.game:announce("Torn free!", 1.2) end
    end
    if self.state == "latch" then self:setState("climb", 6) end
  end
end

function Aerie:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  -- The pattern keeps running while she is away, EXCEPT during the climb
  -- home: the figure-8's peak speed is higher than her flight speed, so a
  -- moving target would be uncatchable and she would end up snapping onto
  -- it. Freezing it during the climb is what keeps the return a real flight.
  if self.state ~= "climb" then self.gp = self.gp + dt end

  if self.state == "intro" then
    -- fly onto the pattern from the spawn point rather than appearing on it
    if self.stateT <= 0 then self:setState("climb", 6) end
    return
  end

  -- Attack timers run on fight time, not glide time, so "a gale every 15
  -- seconds" means what it says regardless of what else she is busy with.
  if self.state ~= "gust" then self.gustClock = self.gustClock + dt end
  if self.state ~= "dive" and self.state ~= "latch" then
    self.diveClock = self.diveClock + dt
  end

  -- The gale keeps its own schedule and interrupts anything not already
  -- committed. It will not abandon a stoop in flight or a victim in hand.
  if self.gustClock >= AERIE_GUST_EVERY and self.nextAttack ~= "gust"
    and (self.state == "glide" or self.state == "climb"
         or self.state == "toperch") then
    self.nextAttack = "gust"
    -- perch on the side the players are ON, so the gale drives them the
    -- full width of the arena into the far spikes
    local sum, n = 0, 0
    for _, p in ipairs(World.players) do
      if not p.dead and not p.downed then sum = sum + p.x + p.w / 2 n = n + 1 end
    end
    local avg = n > 0 and sum / n or World.w * T / 2
    self.perchSide = avg < World.w * T / 2 and -1 or 1
    self:setState("toperch", 4)
  end

  if self.state == "glide" then
    self.x, self.y = self:glidePoint(World)
    self.facing = math.cos(self.gp * 1.1) >= 0 and 1 or -1
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 then
      self.gap = 1.3
      local bx, by = self:center()
      for i = -2, 2 do
        Proj.spawn(World, bx, by + 6, {
          side = "enemy", dmg = 6, kind = "shard", size = 5,
          vx = i * 60, vy = 160, life = 4,
        })
      end
      if G.Audio then G.Audio.sfx("shoot1") end
    end
    -- dives are chosen here; the gale schedules itself above
    if self.diveClock >= AERIE_DIVE_EVERY then
      self.nextAttack = "dive"
      self.perchSide = -self.perchSide     -- alternate corners
      self:setState("toperch", 4)
    end

  elseif self.state == "toperch" then
    local px, py = self:perchPoint(World, self.perchSide)
    if self:flyTo(px, py, dt) or self.stateT <= 0 then
      self.x, self.y = px, py
      self.facing = self.perchSide < 0 and 1 or -1   -- turn to face the arena
      self:setState("charge", AERIE_CHARGE_T)
      if G.Audio then G.Audio.sfx("linkcharge") end
      if G.game then
        G.game:announce(self.nextAttack == "gust"
          and "IT SETS ITS WINGS -- GET BEHIND SOMETHING!"
          or "IT FIXES ON YOU -- MOVE!", 1.4)
      end
    end

  elseif self.state == "charge" then
    -- perched, wings spread, wide open to fire. This is the trade.
    local px, py = self:perchPoint(World, self.perchSide)
    self.x, self.y = px, py + math.sin(self.t * 22) * 1.5
    if self.stateT <= 0 then
      if self.nextAttack == "gust" then
        self.gustClock = 0
        self.gustDir = -self.perchSide     -- she blows away from her corner
        self:setState("gust", AERIE_GUST_T)
        Cam.shake(3, AERIE_GUST_T)
        if G.Audio then G.Audio.sfx("roar") end
      else
        self.diveClock = 0
        local p = World:nearestPlayer(self:center())
        if p then
          self.diveTo = { x = p.x + p.w / 2 - self.w / 2, y = p.y + p.h - self.h }
          self:setState("dive", 3)
          if G.Audio then G.Audio.sfx("dash") end
        else
          self:setState("climb", 6)
        end
      end
    end

  elseif self.state == "gust" then
    local dir = self.gustDir or 1
    self.x, self.y = self:perchPoint(World, self.perchSide)
    self.y = self.y + math.sin(self.t * 30) * 2
    for _, p in ipairs(World.players) do
      if not p.dead and not p.downed and not p.idle and p.pinnedT <= 0 then
        local f = self:sheltered(World, p, dir) and AERIE_GUST_SHELTER or 1
        p.vx = p.vx + dir * AERIE_GUST_FORCE * f * dt
      end
    end
    if self.stateT <= 0 then
      self.gustDir = nil
      self:setState("climb", 6)
    end

  elseif self.state == "dive" then
    local tgt = self.diveTo
    if not tgt then
      self:setState("climb", 6)
    else
      local dx, dy = tgt.x - self.x, tgt.y - self.y
      local d = math.sqrt(dx * dx + dy * dy)
      local step = AERIE_DIVE_SPEED * dt
      if d > step then
        self.x = self.x + dx / d * step
        self.y = self.y + dy / d * step
        if math.abs(dx) > 2 then self.facing = dx > 0 and 1 or -1 end
      else
        self.x, self.y = tgt.x, tgt.y
        self.diveTo = nil
        self:resolveDive(World)
      end
      if self.stateT <= 0 and self.diveTo then
        self.diveTo = nil
        self:resolveDive(World)
      end
    end

  elseif self.state == "latch" then
    local p = self.latched
    if not p or p.dead or p.downed or p.pinnedT <= 0 then
      self:releaseLatch(World)
    else
      -- ride the victim, keep the grip alive, bite on a timer
      self.x = p.x + p.w / 2 - self.w / 2
      self.y = p.y - self.h + 8
      p.pinnedT = math.max(p.pinnedT, math.min(self.stateT, AERIE_LATCH_T))
      self.munchGap = (self.munchGap or 0) - dt
      if self.munchGap <= 0 then
        self.munchGap = AERIE_MUNCH_GAP
        p:takeDamage(AERIE_MUNCH_DMG, self.x + self.w / 2, { pierceDash = true })
        World:fx("burst", p.x + p.w / 2, p.y + 4,
          { color = "blood", n = 8, speed = 90 })
        Cam.shake(2, 0.15)
        if G.Audio then G.Audio.sfx("hitenemy") end
      end
      if self.stateT <= 0 then self:releaseLatch(World) end
    end

  elseif self.state == "missed" then
    self.vy = math.min((self.vy or 0) + 700 * dt, 260)
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self.vy = 0 self:setState("climb", 6) end

  elseif self.state == "stunned" then
    self.vy = math.min((self.vy or 0) + 700 * dt, 260)
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self.vy = 0 self:setState("climb", 6) end

  elseif self.state == "climb" then
    -- fly back onto the pattern instead of snapping to it
    local gx, gy = self:glidePoint(World)
    if self:flyTo(gx, gy, dt) or self.stateT <= 0 then
      self:setState("glide", 3)
    end
  end
end

-- What the stoop actually hit: a shield, a body, or the floor.
function Aerie:resolveDive(World)
  local cx, cy = self:center()
  Cam.shake(4, 0.3)
  -- Lu's dome first: bouncing off it is the hard counter
  for _, q in ipairs(World.players) do
    if q.domeActive and not q.dead and not q.downed then
      local dx = cx - (q.x + q.w / 2)
      local dy = cy - (q.y + q.h / 2 - 4)
      if dx * dx + dy * dy < (q.domeRadius + self.w / 2) ^ 2 then
        q:domeAbsorb(6)
        World:fx("spark", cx, cy, { color = "cyan", n = 16 })
        if G.Audio then G.Audio.sfx("domehit") end
        if G.game then G.game:announce("The dome turns it! NOW!", 1.8) end
        self:setState("stunned", AERIE_DOME_STUN)
        return
      end
    end
  end
  -- a body to grab
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle and p.pinnedT <= 0
      and U.aabb(self.x, self.y, self.w, self.h + 10, p.x, p.y, p.w, p.h) then
      if p:pin(self, AERIE_LATCH_T) then
        self.latched = p
        self.munchGap = 0.25
        self:setState("latch", AERIE_LATCH_T)
        if G.Audio then G.Audio.sfx("roar") end
        if G.game then G.game:announce("CAUGHT -- shoot it off, or mash free!", 2) end
        return
      end
    end
  end
  -- nothing but floor
  if G.Audio then G.Audio.sfx("quake") end
  World:fx("puff", cx, cy + 8, { color = "silver", n = 12 })
  self:setState("missed", AERIE_MISS_T)
end

function Aerie:hurt(dmg, srcx, srcy, opts)
  -- commented out the dmg scaler below because it's too generous
  -- if self.state == "stunned" then dmg = dmg * 2 end
  local hit = Entity.hurt(self, dmg, srcx, srcy, opts)
  -- being shot is what makes her let go
  if hit ~= false and self.state == "latch" then
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "gold", n = 10 })
    self:releaseLatch(World)
  end
  return hit
end

function Aerie:onDeath()
  -- never leave a player frozen because the thing holding them died
  if self.latched and self.latched.pinnedT and self.latched.pinnedT > 0 then
    self.latched:freeFromPin(false)
  end
  self.latched = nil
  Boss.onDeath(self)
end

-- ------------------------------------------------------------------
-- The gale: streaks and chevrons the whole width of the arena, so the
-- direction is never in doubt. Drawn during the charge (building) and
-- the gust itself (full force).
-- ------------------------------------------------------------------
function Aerie:drawWind(World, strength, dir)
  local g = love.graphics
  local roomW, roomH = World.w * T, World.h * T
  for i = 0, 55 do
    local yy = 14 + ((i * 137) % (roomH - 40))
    local speed = 300 + (i % 6) * 130
    local len = (16 + (i % 5) * 12) * strength
    local phase = (G.time * speed + i * 197) % (roomW + 160)
    local xx = -80 + phase
    if dir < 0 then xx = roomW - xx end
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.16 + 0.5 * strength)
    g.rectangle("fill", math.min(xx, xx + len * dir), yy, len, 1.5)
  end
  -- marching chevrons: the unambiguous direction cue
  for row = 0, 4 do
    local yy = roomH * (row + 0.5) / 5.5
    for k = 0, 7 do
      local phase = (G.time * 420 + k * 150 + row * 60) % (roomW + 100)
      local xx = -50 + phase
      if dir < 0 then xx = roomW - xx end
      g.setColor(P.spark[1], P.spark[2], P.spark[3], (0.2 + 0.55 * strength))
      g.polygon("fill", xx, yy - 5 * strength, xx + 9 * dir, yy, xx, yy + 5 * strength)
    end
  end
  g.setColor(1, 1, 1, 1)
end

function Aerie:draw()
  local g = love.graphics
  local World = require "src.world"
  local st = self.state

  -- wind, behind her
  if st == "gust" then
    self:drawWind(World, 1, self.gustDir or 1)
  elseif st == "charge" and self.nextAttack == "gust" then
    local k = 1 - math.max(0, self.stateT) / AERIE_CHARGE_T
    self:drawWind(World, 0.15 + k * 0.45, -self.perchSide)
  end

  -- which pose
  local frame
  if st == "stunned" then
    frame = 8
  elseif st == "latch" then
    frame = math.floor(self.t * 12) % 2 + 6      -- 6/7 munch cycle
  elseif st == "dive" or st == "missed" then
    frame = 5
  elseif st == "gust" then
    frame = 4
  elseif st == "charge" then
    frame = 3
  else
    frame = math.floor(self.t * 8) % 2 + 1       -- 1/2 flight cycle
  end

  local tint
  if st == "stunned" then tint = { 1, 0.8, 0.8, 1 }
  elseif st == "charge" then
    local k = 1 - math.max(0, self.stateT) / AERIE_CHARGE_T
    tint = { 1, 1 - k * 0.35, 1 - k * 0.55, 1 }  -- heats up as it winds up
  end

  G.drawSprite("boss_aeriesentinel", frame,
    self.x + self.w / 2, self.y + self.h + 0.5,
    { sx = 1.0, sy = 1.4, flip = self.facing < 0, tint = tint,
      white = math.max(0, (self.white or 0) * 6) })

  -- charge telegraph: a ring cinching in on the perch
  if st == "charge" then
    local cx, cy = self:center()
    local k = 1 - math.max(0, self.stateT) / AERIE_CHARGE_T
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.35 + k * 0.45)
    g.circle("line", cx, cy, 46 * (1 - k) + 12)
    if self.nextAttack == "dive" then
      -- and a line to the mark it has chosen
      local p = World:nearestPlayer(cx, cy)
      if p then
        g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.2 + k * 0.5)
        g.line(cx, cy, p.x + p.w / 2, p.y + p.h / 2)
      end
    end
    g.setColor(1, 1, 1, 1)
  end

  -- stunned: dazed sparks over the head
  if st == "stunned" then
    local cx = self.x + self.w / 2
    for i = 0, 2 do
      local a = G.time * 5 + i * (math.pi * 2 / 3)
      g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.8)
      g.circle("fill", cx + math.cos(a) * 13, self.y - 6 + math.sin(a) * 4, 1.8)
    end
    g.setColor(1, 1, 1, 1)
  end
end
Bosses.aeriesentinel = Aerie

-- ==================================================================
-- 8a. MOTHER ENGINE (Core, phase 1)
-- ==================================================================
local Mother = Boss.extend()
function Mother:init(x, y)
  Boss.init(self, x, y, { id = "motherengine", name = "MOTHER ENGINE",
    hp = 130, touchDmg = 4, w = 48, h = 48 })
  self.homeY = y
end
function Mother:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.y = self.homeY + math.sin(self.t * 0.8) * 6

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("fan", 4) end
    return
  end

  if self.state == "fan" then
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 then
      self.gap = 0.8
      local cx, cy = self:center()
      self.fanA = (self.fanA or 0) + 0.4
      for i = 0, 4 do
        local a = math.pi / 2 + (i - 2) * 0.35 + math.sin(self.fanA) * 0.3
        Proj.spawn(World, cx, cy + 10, {
          side = "enemy", dmg = 3, kind = "spark", size = 5,
          vx = math.cos(a) * 140, vy = math.sin(a) * 140, life = 2.5,
        })
      end
      if G.Audio then G.Audio.sfx("shoot4") end
    end
    if self.stateT <= 0 then
      self:setState(U.chance(0.5) and "floor" or "adds", 4)
    end
  elseif self.state == "floor" then
    -- electrify half the floor, alternating
    if not self.zapSide then
      self.zapSide = U.chance(0.5) and 1 or -1
      G.game:announce("FLOOR SURGE INCOMING!", 1.5)
      if G.Audio then G.Audio.sfx("bosswarn") end
      self.zapT = 0
    end
    self.zapT = self.zapT + dt
    if self.zapT > 1.2 then
      local cx = World.w * T / 2
      for _, p in ipairs(World.players) do
        if not p.dead and not p.downed and not p.idle and p.onGround then
          local side = U.sign(p.x + p.w / 2 - cx)
          if side == self.zapSide and math.floor(G.time * 8) % 2 == 0 then
            p:takeDamage(3, nil, { pierceDash = true })
          end
        end
      end
    end
    if self.stateT <= 0 then
      self.zapSide = nil
      self:setState("fan", 4)
    end
  elseif self.state == "adds" then
    if not self.added then
      self.added = true
      local names = { "sentinel", "screamer" }
      for i = 1, 2 do
        World:add(Entity.make(names[i], self.x + U.rand(-60, 60), self.y + 40))
      end
      if G.Audio then G.Audio.sfx("teleport") end
    end
    if self.stateT <= 0 then
      self.added = nil
      self:setState("fan", 5)
    end
  end
end
function Mother:onDeath()
  -- phase 1 down: do NOT set final flags; spawn the Mender (phase 2)
  local World = require "src.world"
  local cx, cy = self:center()
  Cam.shake(6, 1)
  if G.Audio then G.Audio.sfx("explode") end
  for i = 1, 6 do
    World:fx("burst", cx + U.rand(-24, 24), cy + U.rand(-24, 24),
      { color = "cyan", n = 12, speed = 150 })
  end
  G.run.flags.boss_motherengine = true
  World.bossActive = nil
  -- brief dialogue, then phase 2
  G.game:startDialogue({
    { who = "mender", text = "A hundred years I have held this city together. Solder and patience. Pipe by pipe. Room by room. ALONE." },
    { who = "mender", text = "And you -- two caretakers, mint-new, booted a century late. Come to 'mend' what you never once watched die." },
    { who = "mender", text = "I am the Mender. The last caretaker. And you two... are spare parts." },
    { fn = function()
      local World2 = require "src.world"
      local m = Bosses.mender2.new(cx - 8, World2.h * T - 96)
      World2:add(m)
      World2.bossActive = m
      if G.Audio then G.Audio.playMusic("finalboss") end
    end },
  })
end
function Mother:draw()
  local g = love.graphics
  local cx, cy = self:center()
  -- big scaled sentinel core + ring
  for i = 0, 7 do
    local a = self.t + i * math.pi / 4
    g.setColor(P.teal)
    g.circle("fill", cx + math.cos(a) * 34, cy + math.sin(a) * 34, 3)
  end
  G.drawSprite("boss_motherengine", math.floor(self.t * 5) % 2 + 1, cx, self.y + self.h,
    { sx = 2.7, sy = 2.5, white = math.max(0, (self.white or 0) * 6) })
  g.setColor(1, 1, 1, 1)
end
Bosses.motherengine = Mother

-- ==================================================================
-- 8b. THE MENDER (Core, phase 2 -- final)
-- ==================================================================
local Mender = Boss.extend()
function Mender:init(x, y)
  Boss.init(self, x, y, { id = "motherengine2", name = "THE MENDER",
    hp = 120, touchDmg = 4, w = 14, h = 20 })
  self.facing = -1
end
function Mender:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.vy = math.min((self.vy or 0) + 700 * dt, 280)

  if self.state == "intro" then
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("duel", 3) end
    return
  end

  local p = World:nearestPlayer(self:center())
  if self.state == "duel" then
    -- fast approach + strafe
    if p then
      self.facing = U.sign(p.x - self.x) ~= 0 and U.sign(p.x - self.x) or self.facing
      local d = math.abs(p.x - self.x)
      self.vx = self.facing * (d > 70 and 130 or -60)
      if self.onGround and U.chance(dt * 1.2) then self.vy = -240 end
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    self.gap = (self.gap or 0) - dt
    if self.gap <= 0 and p then
      self.gap = 0.9
      local cx, cy = self:center()
      local px, py = p:center()
      local ang = math.atan2(py - cy, px - cx)
      Proj.spawn(World, cx, cy, {
        side = "enemy", dmg = 3, kind = "orb", size = 6,
        vx = math.cos(ang) * 200, vy = math.sin(ang) * 200, life = 2,
      })
      if G.Audio then G.Audio.sfx("shoot1") end
    end
    if self.stateT <= 0 then
      self:setState(U.chance(0.4) and "beam" or "blinkstrike", U.chance(0.4) and 2.4 or 1.6)
    end
  elseif self.state == "beam" then
    -- telegraphed horizontal sweep at current height
    self.vx = 0
    PH.move(self, 0, self.vy * dt)
    if not self.beamY then
      self.beamY = self.y + 8
      if G.Audio then G.Audio.sfx("linkcharge") end
    end
    if self.stateT < 1.2 and not self.beamFired then
      self.beamFired = true
      Cam.shake(3, 0.3)
      if G.Audio then G.Audio.sfx("linkshot") end
      for _, pl in ipairs(World.players) do
        if not pl.dead and not pl.downed and not pl.idle
          and math.abs(pl.y + pl.h / 2 - self.beamY) < 14 then
          -- dome blocks it
          local blocked = false
          for _, q in ipairs(World.players) do
            if q.domeActive then
              local dx = pl.x + pl.w / 2 - (q.x + q.w / 2)
              local dy = pl.y + pl.h / 2 - (q.y + q.h / 2 - 4)
              if dx * dx + dy * dy < q.domeRadius * q.domeRadius then
                blocked = true
                q:domeAbsorb(4)
              end
            end
          end
          if not blocked then pl:takeDamage(5, self.x) end
        end
      end
    end
    if self.stateT <= 0 then
      self.beamY = nil
      self.beamFired = nil
      self:setState("duel", 3.5)
    end
  elseif self.state == "blinkstrike" then
    if not self.blinked and p then
      self.blinked = true
      World:fx("burst", self:center())
      self.x = p.x - self.facing * 40
      if G.Audio then G.Audio.sfx("teleport") end
      self.vx = self.facing * 240
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.stateT <= 0 or self.hitWall then
      self.blinked = nil
      self:setState("duel", 3)
    end
  end
end
function Mender:draw()
  local g = love.graphics
  -- red-visor humanoid: reuse Vess sprite, dark tint
  G.drawSprite("boss_motherengine2", math.floor(self.t * 3) % 2 + 1,
    self.x + self.w / 2, self.y + self.h + 0.5,
    { flip = self.facing < 0, sx = 1.0, sy = 1.3,
      white = math.max(0, (self.white or 0) * 6) })
  -- red visor glow
  g.setColor(P.blood)
  g.rectangle("fill", self.x + 2 + (self.facing < 0 and -1 or 1), self.y + 3, 9, 2)
  -- beam telegraph
  if self.beamY and not self.beamFired then
    g.setColor(P.blood[1], P.blood[2], P.blood[3], 0.3 + math.sin(G.time * 14) * 0.2)
    g.rectangle("fill", 0, self.beamY - 8, 4096, 16)
  elseif self.beamFired and self.state == "beam" then
    g.setColor(P.pink[1], P.pink[2], P.pink[3], 0.8)
    g.rectangle("fill", 0, self.beamY - 5, 4096, 10)
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.mender2 = Mender

-- ==================================================================
-- 9. THE MYCEL CHOIR (Undergrove boss)
-- Three fungal throats share one hunger. Only the one that is SINGING
-- (lit, mouth open) can be wounded; the song rotates. In the dark, the
-- singing throat is also the room's brightest lamp.
-- ==================================================================
local ChoirNode = Entity.extend()
function ChoirNode:init(x, y, boss, idx)
  Entity.init(self, x, y)
  self.kind = "enemy"
  self.heavy = true
  self.noKnockback = true
  self.boss = boss
  self.idx = idx
  self.w, self.h = 20, 22
  self.maxhp = 999
  self.hp = 999
  self.touchDmg = 3
  self.t = U.rand(0, 6)
  self.layer = 2
end
function ChoirNode:singing()
  return self.boss and not self.boss.dead and self.boss.singing == self.idx
end
function ChoirNode:update(dt)
  self.t = self.t + dt
  self.y = self.baseY and (self.baseY + math.sin(self.t * 1.4) * 4) or self.y
  if not self.baseY then self.baseY = self.y end
  if self.boss and self.boss.dead and not self.dead then
    self.dead = true
    local World = require "src.world"
    World:fx("burst", self.x + 10, self.y + 10, { color = "violet", n = 14 })
  end
  self.lightR = self:singing() and 64 or 10
end
function ChoirNode:hurt(dmg, srcx, srcy, opts)
  local World = require "src.world"
  if not self:singing() then
    World:fx("spark", self.x + 10, self.y + 10, { color = "plum", n = 3 })
    if G.Audio then G.Audio.sfx("crack") end
    return false
  end
  World:fx("spark", self.x + 10, self.y + 10, { color = "spark", n = 5 })
  local o = {}
  if opts then for k, v in pairs(opts) do o[k] = v end end
  o.fromNode = true
  return self.boss:hurt(dmg, srcx, srcy, o)
end
function ChoirNode:draw()
  local g = love.graphics
  local cx, cy = self.x + 10, self.y + 11
  local sing = self:singing()
  local pulse = sing and (0.6 + math.sin(G.time * 9) * 0.35) or 0.15
  -- stalk
  g.setColor(P.plum)
  g.rectangle("fill", cx - 3, cy + 4, 6, 10)
  -- head (reuse spitter head look, scaled)
  G.drawSprite("en_spitter", sing and 2 or 1, cx, self.y + self.h,
    { sx = 1.6, sy = 1.5, tint = { 0.8, 0.7, 1, 1 },
      white = math.max(0, ((self.boss and self.boss.white) or 0) * 6) })
  if sing then
    g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse)
    g.circle("line", cx, cy - 2, 12 + pulse * 5)
    g.circle("line", cx, cy - 2, 18 + pulse * 8)
  end
  g.setColor(1, 1, 1, 1)
end

local Mycelchoir = Boss.extend()
function Mycelchoir:init(x, y)
  Boss.init(self, x, y, { id = "mycelchoir", name = "THE MYCEL CHOIR",
    hp = 150, touchDmg = 3, w = 28, h = 24, reward = "weapon:pulsebloom" })
  self.singing = 0        -- 0 = none (intro / gap between verses)
  self.verseT = 0
  self.lightR = 22
end
function Mycelchoir:spawnNodes(World)
  if self.nodes then return end
  local T2 = 16
  self.nodes = {
    World:add(ChoirNode.new(6 * T2, 26 * T2 + 6, self, 1)),   -- low, west
    World:add(ChoirNode.new(3 * T2, 16 * T2, self, 2)),       -- mid, west wall
    World:add(ChoirNode.new(25 * T2, 8 * T2 + 8, self, 3)),   -- high, east
  }
end
function Mycelchoir:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self:spawnNodes(World)
  -- the heart sways gently at the loft ceiling
  self.x = self.homeX and (self.homeX + math.cos(self.t * 0.8) * 8) or self.x
  if not self.homeX then self.homeX, self.homeY = self.x, self.y end

  if self.state == "intro" then
    if self.stateT <= 0 then
      self:setState("verse", self:verseLen())
      self.singing = 1
      if G.game then
        G.game:announce("Only the SINGING throat can be wounded!", 3)
      end
      if G.Audio then G.Audio.sfx("roar") end
    end
    return
  end

  local phase2 = self.hp < self.maxhp * 0.5

  if self.state == "verse" then
    -- the singing node lobs spore arcs at the nearest player
    self.lobT = (self.lobT or 1.2) - dt
    if self.lobT <= 0 then
      self.lobT = phase2 and 1.2 or 1.8
      local node = self.nodes[self.singing]
      local p = node and World:nearestPlayer(node:center())
      if node and p then
        local cx, cy = node:center()
        local n = phase2 and 3 or 2
        for i = 1, n do
          local flight = 0.7 + i * 0.15
          local grav = 380
          local tx = p.x + p.w / 2 + U.rand(-12, 12)
          local vx = (tx - cx) / flight
          local vy = ((p.y + p.h - cy) - 0.5 * grav * flight * flight) / flight
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "orb", size = 5,
            vx = vx, vy = vy, gravity = grav, life = 2.4,
          })
        end
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
    if self.stateT <= 0 then
      self.singing = 0
      self:setState("gap", 0.8)
      if G.Audio then G.Audio.sfx("domeoff") end
    end
  elseif self.state == "gap" then
    if self.stateT <= 0 then
      self.lastSinger = ((self.lastSinger or 1) % 3) + 1
      self.singing = self.lastSinger
      self:setState("verse", self:verseLen())
      -- call a spore-fly to the loft now and then (keep the arena sane)
      if U.chance(0.4) then
        local flies = 0
        for _, e in ipairs(World.entities) do
          if not e.dead and e.kind == "enemy" and e.spitT then flies = flies + 1 end
        end
        if flies < (phase2 and 3 or 2) then
          World:add(Entity.make("sporefly", self.x + U.rand(-40, 40), self.y + 30))
        end
      end
      if G.Audio then G.Audio.sfx("domeon") end
    end
  end
end
function Mycelchoir:verseLen()
  return self.hp < self.maxhp * 0.5 and 3.2 or 4.5
end
function Mycelchoir:hurt(dmg, srcx, srcy, opts)
  if not (opts and opts.fromNode) then
    -- the heart hangs beyond harm; the throats are the way in
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "plum", n = 3 })
    return false
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end
function Mycelchoir:draw()
  local g = love.graphics
  local cx, cy = self:center()
  -- hanging mycel heart: veined mass under the loft ceiling
  g.setColor(P.plum)
  for i = -2, 2 do
    g.rectangle("fill", cx + i * 5 - 2, self.y - 14, 4, 16 + math.abs(i) * -2 + 6)
  end
  g.setColor(P.violet)
  g.ellipse("fill", cx, cy, 16, 12)
  g.setColor(P.plum)
  G.drawSprite("boss_mycelchoir", math.floor(G.time * 2) % 2 + 1, cx, cy + 20,
    { sx = 2.0, sy = 1.6, white = math.max(0, (self.white or 0) * 6) })
  g.ellipse("line", cx, cy, 16, 12)
  local beat = 0.5 + math.sin(G.time * (self.hp < self.maxhp * 0.5 and 7 or 4)) * 0.3
  g.setColor(P.spark[1], P.spark[2], P.spark[3], beat)
  g.circle("fill", cx, cy, 5)
  g.setColor(1, 1, 1, 1)
end
Bosses.mycelchoir = Mycelchoir

-- ==================================================================
-- 10. THE ARCHIVIST (Coldstore boss -- the Cradle's protector)
-- A giant catalog engine on a ceiling rail. Indexing beam sweeps,
-- crate barrages, a vault-slam -- and it is only vulnerable when it
-- stops to RE-SHELVE (its drawer opens). It fights from duty, not
-- madness: the one subsystem that never broke.
-- ==================================================================
local Archivist = Boss.extend()
function Archivist:init(x, y)
  Boss.init(self, x, y, { id = "archivist", name = "THE ARCHIVIST",
    hp = 170, touchDmg = 4, w = 40, h = 26, reward = "weapon:magnetmortar" })
  self.railY = y
  self.dir = 1
end
function Archivist:hurt(dmg, sx, sy, opts)
  local World = require "src.world"
  if self.state ~= "reshelve" then
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "ice", n = 3 })
    if G.Audio then G.Audio.sfx("crack") end
    return false
  end
  return Boss.hurt(self, dmg, sx, sy, opts)
end
function Archivist:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  local frenzy = self.hp < self.maxhp * 0.5 and 1.35 or 1
  local minX, maxX = 40, World.w * T - 40 - self.w

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("ride", 2.2) end
    return
  end

  local p = World:nearestPlayer(self:center())

  if self.state == "ride" then
    -- track the nearest player along the rail
    if p then
      local tx = U.clamp(p.x + p.w / 2 - self.w / 2, minX, maxX)
      self.x = U.approach(self.x, tx, 95 * frenzy * dt)
    end
    self.y = self.railY + math.sin(self.t * 2) * 3
    if self.stateT <= 0 then
      local roll = U.rand(0, 1)
      if roll < 0.34 then self:setState("sweep", 2.1)
      elseif roll < 0.67 then self:setState("barrage", 2.4)
      else self:setState("slam", 3.5) end
    end
  elseif self.state == "sweep" then
    -- indexing beam: telegraph, then a vertical scan column
    self.y = self.railY
    if not self.beamX then
      self.beamX = self.x + self.w / 2
      if G.Audio then G.Audio.sfx("linkcharge") end
    end
    if self.stateT < 1.1 and not self.beamFired then
      self.beamFired = true
      Cam.shake(3, 0.3)
      if G.Audio then G.Audio.sfx("linkshot") end
      for _, pl in ipairs(World.players) do
        if not pl.dead and not pl.downed and not pl.idle
          and math.abs(pl.x + pl.w / 2 - self.beamX) < 12 then
          local blocked = false
          for _, q in ipairs(World.players) do
            if q.domeActive then
              local dx = pl.x + pl.w / 2 - (q.x + q.w / 2)
              local dy = pl.y + pl.h / 2 - (q.y + q.h / 2 - 4)
              if dx * dx + dy * dy < q.domeRadius * q.domeRadius then
                blocked = true
                q:domeAbsorb(4)
              end
            end
          end
          if not blocked then pl:takeDamage(5, self.x) end
        end
      end
    end
    if self.stateT <= 0 then
      self.beamX = nil
      self.beamFired = nil
      self:setState("ride", 2.4 / frenzy)
    end
  elseif self.state == "barrage" then
    -- lob book-crates in solved arcs
    self.y = self.railY
    self.lobT = (self.lobT or 0) - dt
    if self.lobT <= 0 and p then
      self.lobT = 0.55 / frenzy
      local cx, cy = self:center()
      local px = p.x + p.w / 2 + U.rand(-24, 24)
      local dx = px - cx
      Proj.spawn(World, cx, cy + 8, {
        side = "enemy", dmg = 3, kind = "orb", size = 6,
        vx = U.clamp(dx * 1.0, -150, 150), vy = 40,
        gravity = 320, life = 3,
      })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then self:setState("ride", 2 / frenzy) end
  elseif self.state == "slam" then
    -- vault-slam: telegraph, drop, shockwave, winch back up
    if self.phaseT == 0 then
      self.phaseT = 1
      self.slamWarn = 0.8
      if G.Audio then G.Audio.sfx("bosswarn") end
    end
    if self.slamWarn and self.slamWarn > 0 then
      self.slamWarn = self.slamWarn - dt
      self.y = self.railY - math.sin(G.time * 20) * 2
    elseif not self.slammed then
      self.vy = (self.vy or 0) + 900 * dt
      PH.move(self, 0, self.vy * dt)
      if self.onGround then
        self.slammed = true
        self.vy = 0
        Cam.shake(6, 0.5)
        if G.Audio then G.Audio.sfx("explode") end
        local cx = self.x + self.w / 2
        for _, dir in ipairs({ -1, 1 }) do
          Proj.spawn(World, cx + dir * (self.w / 2 + 4), self.y + self.h - 4, {
            side = "enemy", dmg = 3, kind = "spark", size = 6,
            vx = dir * 170, vy = 0, life = 1.1,
          })
        end
      end
    else
      -- winch home
      self.y = U.approach(self.y, self.railY, 70 * dt)
      if math.abs(self.y - self.railY) < 2 then
        self.slammed = nil
        self:setState("reshelve", 3.6)
        if G.Audio then G.Audio.sfx("switch") end
        if not self.taughtShelve and G.game then
          self.taughtShelve = true
          G.game:announce("The drawer is OPEN -- it can be wounded while it re-shelves!", 3)
        end
      end
    end
    if self.stateT <= 0 and not self.slammed and not (self.slamWarn and self.slamWarn > 0) then
      -- fell into a pit-free arena: force recovery
      self.y = self.railY
      self.slammed = nil
      self:setState("reshelve", 3.6)
    end
  elseif self.state == "reshelve" then
    -- drawer open: the only damage window
    self.y = self.railY + math.sin(self.t * 6) * 1.5
    if self.stateT <= 0 then self:setState("ride", 2.2 / frenzy) end
  end
end
function Archivist:onDeath()
  Boss.onDeath(self)
  -- the protector yields -- and chooses to open the way
  if G.game then
    G.game:startDialogue({
      { who = "archivist", text = "Directive check. Keep the sleepers safe. Admit no one. ...One hundred years, zero exceptions." },
      { who = "archivist", text = "Assessment: you did not come to harm them. You came to COUNT them." },
      { who = "archivist", text = "A hundred years is long enough for a lie. Go in, caretakers. Read the record. Count them all." },
    })
  end
end
function Archivist:draw()
  local g = love.graphics
  local cx = self.x + self.w / 2
  -- ceiling rail
  g.setColor(P.slate)
  g.rectangle("fill", Cam.x, self.railY - 8, G.VW, 3)
  g.setColor(P.gray)
  g.rectangle("fill", cx - 3, self.railY - 6, 6, 8)
  -- body: scaled shelver chassis
  G.drawSprite("boss_archivist", math.floor(self.t * 3) % 2 + 1, cx, self.y + self.h,
    { sx = 2.0, sy = 1.2, white = math.max(0, (self.white or 0) * 6) })
  -- the drawer (open while re-shelving)
  if self.state == "reshelve" then
    local pulse = 0.6 + math.sin(G.time * 8) * 0.3
    g.setColor(P.gold[1], P.gold[2], P.gold[3], pulse)
    g.rectangle("fill", cx - 10, self.y + self.h - 8, 20, 8)
    g.setColor(P.ice)
    g.rectangle("line", cx - 10, self.y + self.h - 8, 20, 8)
  end
  -- beam telegraph / fire
  if self.state == "sweep" and self.beamX then
    if not self.beamFired then
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.3 + math.sin(G.time * 14) * 0.2)
      g.rectangle("fill", self.beamX - 8, 0, 16, 4096)
    else
      g.setColor(P.white[1], P.white[2], P.white[3], 0.8)
      g.rectangle("fill", self.beamX - 5, 0, 10, 4096)
    end
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.archivist = Archivist

-- ==================================================================
-- 11. EMBERKEEPER MARO (the Reckoning -- Ember Camp)
-- An old man defending the fire he damned the world to keep. Lantern
-- bolts, flame pillars, and Brassa at his side past half health.
-- Spawned by the Ember lantern, not a room trigger.
-- ==================================================================
local Maro = Boss.extend()
function Maro:init(x, y)
  Boss.init(self, x, y, { id = "maro", name = "EMBERKEEPER MARO",
    hp = 150, touchDmg = 3, w = 14, h = 20 })
  self.facing = -1
end
function Maro:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.vy = math.min((self.vy or 0) + 700 * dt, 280)
  local frenzy = self.hp < self.maxhp * 0.4 and 1.3 or 1

  -- Brassa joins at 60% (checked even mid-telegraph)
  if not self.calledBrassa and self.hp < self.maxhp * 0.6 and not self.dead then
    self.calledBrassa = true
    World:add(Entity.make("keeperbrassa", self.x - 60, self.y - 10))
    if G.game then G.game:announce("Brassa takes the field beside him!", 2.2) end
    if G.Audio then G.Audio.sfx("roar") end
  end

  if self.state == "intro" then
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("volley", 2.6) end
    return
  end

  local p = World:nearestPlayer(self:center())

  if self.state == "volley" then
    -- lantern bolts: 3-way ember fans toward the nearest bot
    if p then
      self.facing = U.sign(p.x - self.x) ~= 0 and U.sign(p.x - self.x) or self.facing
      -- keep gentle distance
      local d = math.abs(p.x - self.x)
      self.vx = self.facing * (d > 90 and 55 or -40)
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    self.gap = (self.gap or 0.6) - dt
    if self.gap <= 0 and p then
      self.gap = 1.1 / frenzy
      local cx, cy = self:center()
      local px, py = p:center()
      local ang = math.atan2(py - cy, px - cx)
      for off = -0.3, 0.3, 0.3 do
        Proj.spawn(World, cx, cy - 4, {
          side = "enemy", dmg = 3, kind = "spark", size = 5,
          vx = math.cos(ang + off) * 170, vy = math.sin(ang + off) * 170,
          life = 2,
        })
      end
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then
      self:setState(U.chance(0.55) and "pillars" or "volley", U.chance(0.55) and 3 or 2.6)
    end
  elseif self.state == "pillars" then
    -- flame pillars: telegraph at each bot's feet, then fire climbs
    PH.move(self, 0, self.vy * dt)
    if not self.marks then
      self.marks = {}
      for _, pl in ipairs(World.players) do
        if not pl.dead and not pl.idle then
          self.marks[#self.marks + 1] = { x = pl.x + pl.w / 2, t = 0.9 }
        end
      end
      if G.Audio then G.Audio.sfx("bosswarn") end
    end
    local allDone = true
    for _, mk in ipairs(self.marks) do
      if mk.t > 0 then
        mk.t = mk.t - dt
        allDone = false
        if mk.t <= 0 and not mk.fired then
          mk.fired = true
          for i = 0, 3 do
            Proj.spawn(World, mk.x, World.h * T - 24 - i * 14, {
              side = "enemy", dmg = 3, kind = "spark", size = 6,
              vx = 0, vy = -60 - i * 20, life = 0.9, gravity = -40,
            })
          end
          Cam.shake(2, 0.2)
          if G.Audio then G.Audio.sfx("shoot3") end
        end
      end
    end
    if allDone and self.stateT <= 0 then
      self.marks = nil
      self:setState("volley", 2.8 / frenzy)
    end
  end
end
function Maro:onDeath()
  Boss.onDeath(self)
  if G.game then
    G.game:startDialogue({
      { who = "elder", text = "Ha... there's fire in you two yet. There was always... fire in you two." },
      { who = "elder", text = "Do it quick, sparks. The cold is faster than mercy." },
    })
  end
end
function Maro:draw()
  local g = love.graphics
  G.drawSprite("npc_elder", math.floor(self.t * 3) % 2 + 1,
    self.x + self.w / 2, self.y + self.h + 0.5,
    { flip = self.facing < 0, sx = 1.25, sy = 1.25,
      white = math.max(0, (self.white or 0) * 6) })
  -- lantern-fire in his hand
  local flick = 0.6 + math.sin(G.time * 9) * 0.3
  g.setColor(P.ember[1], P.ember[2], P.ember[3], flick)
  g.circle("fill", self.x + (self.facing > 0 and self.w + 2 or -2), self.y + 8, 3.5)
  g.setColor(P.gold[1], P.gold[2], P.gold[3], flick)
  g.circle("fill", self.x + (self.facing > 0 and self.w + 2 or -2), self.y + 8, 1.8)
  -- flame pillar telegraphs
  if self.marks then
    local World = require "src.world"
    for _, mk in ipairs(self.marks) do
      if mk.t > 0 then
        g.setColor(P.magma[1], P.magma[2], P.magma[3], 0.35 + math.sin(G.time * 16) * 0.2)
        g.rectangle("fill", mk.x - 7, 0, 14, World.h * T)
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.maro = Maro

-- ==================================================================
-- Boss starter (called by boss triggers)
-- ==================================================================
local PLACE = {
  bramblemaw = function(World) return World.w * T - 88, World.h * T - 92 end,
  -- centred: w/2 is 13, so subtracting it puts the BODY on the midline
  rustwarden = function(World) return World.w * T / 2 - 13, World.h * T - 140 end,
  tideengine = function(World) return World.w * T / 2 - 22, 118 end,
  slaggolem = function(World) return World.w * T - 110, World.h * T - 90 end,
  crucible = function(World) return World.w * T / 2 - 18, World.h * T - 5 * T - 4 * T - 36 end,
  prismtyrant = function(World) return World.w * T / 2 - 14, 70 end,
  aeriesentinel = function(World) return World.w * T / 2 - 17, 60 end,
  motherengine = function(World) return World.w * T / 2 - 24, 64 end,
  mycelchoir = function(World) return World.w * T / 2 - 14, 56 end,
  archivist = function(World) return World.w * T / 2 - 20, 44 end,
}

-- One-line epitaphs: every boss is a repair the Mender made without
-- judgment (or, for the Choir, the wild thing that grew in the gaps).
local EPITAPH = {
  bramblemaw = "planted to feed a city. no one came to prune it.",
  rustwarden = "still at its post. relieved by no one.",
  tideengine = "the gardens drowned. it is still watering them.",
  slaggolem = "it repairs itself. it is the only order it remembers.",
  crucible = "ten thousand perfect parts. no one places orders anymore.",
  prismtyrant = "it is still calling the Core. the Core stopped answering.",
  aeriesentinel = "sky watch, day 36,512: no relief.",
  motherengine = "it mends. that is all that is left of it.",
  mycelchoir = "the deep learned to sing what the city forgot.",
  archivist = "the only one that never broke. the only one that never slept.",
}

function Bosses.start(id, World)
  local cls = Bosses[id]
  if not cls then error("unknown boss: " .. id) end
  local px, py = PLACE[id](World)
  local b = cls.new(px, py)
  -- NEVER spawn embedded in terrain (the Warden lesson, now enforced
  -- for every boss): lift out of the floor first, then spiral-search
  local PH2 = require "src.physics"
  local guard = 0
  while PH2.boxBlocked(b.x, b.y, b.w, b.h) and guard < 20 do
    b.y = b.y - 8
    guard = guard + 1
  end
  if PH2.boxBlocked(b.x, b.y, b.w, b.h) then World:ensureFree(b) end
  if b.homeY then b.homeY = b.y end
  if b.railY then b.railY = b.y end
  World:add(b)
  World.bossActive = b
  Cam.shake(3, 0.5)
  if G.Audio then
    G.Audio.sfx("roar")
    G.Audio.playMusic(id == "motherengine" and "finalboss" or "boss")
  end
  if G.game then
    G.game:announce("-- " .. b.bossName .. " --", 2.5)
    if EPITAPH[id] then G.game:announce(EPITAPH[id], 3) end
  end
  return b
end

return Bosses
