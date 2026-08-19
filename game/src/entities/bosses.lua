-- The eight bosses. Bodies are built from scaled sprites + code-drawn
-- details; behavior carries the identity.
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"
local Proj = require "src.entities.projectile"
local Pickup = require "src.entities.pickup"
local Cam = require "src.camera"
local Cold = require "src.cold"

local T = 16
local Bosses = {}

-- Where remains and prizes come to rest. This used to be a local hand
-- rolled fall-until-something-is-under-you, which checked for lava and
-- water and nothing else -- so it fell straight through spike beds and
-- left the Mycel Choir's reward sitting in the spikes at the bottom of
-- its shaft. The rule now lives in World:settleDrop, where the chest
-- and capsule placers can share it: real footing, no hazard touching
-- the object or the player who comes for it, and reachable from a door
-- or from where a player is standing.
local function settleSpot(World, x, y, w, h)
  return World:settleDrop(x, y, w, h)
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

-- ------------------------------------------------------------------
-- ADDS
--
-- Everything a boss puts into the world DURING its fight goes through
-- here, and Boss:onDeath clears every one of them. A fight that ends
-- with six of its own slaglings still chasing you around the corpse
-- reads as a bug, not as difficulty -- and it is worse than untidy in
-- the arenas whose exit is a door you have to walk to.
--
-- The tag is the boss's own id, so nothing else in the room is touched:
-- enemies placed by the ROOM file are the room's, and the corpse and the
-- reward drop are spawned by onDeath itself and are deliberately not
-- tagged. tools/adds_test.lua fails the build if any boss spawns an
-- enemy without coming through this function.
-- ------------------------------------------------------------------
function Boss:addSpawn(e)
  local World = require "src.world"
  if not e or e == true then return e end
  e.bossAdd = self.bossId or true
  World:add(e)
  return e
end

-- Clear them. Called by onDeath, and safe to call twice.
function Boss:clearAdds()
  local World = require "src.world"
  local n = 0
  local lists = { World.entities, World.addQueue }
  for _, list in ipairs(lists) do
    for _, e in ipairs(list or {}) do
      if e.bossAdd and not e.dead then
        -- a puff each, so a dozen things vanishing reads as the machine
        -- losing its grip rather than as a dropped frame
        local ex = (e.x or 0) + (e.w or 8) / 2
        local ey = (e.y or 0) + (e.h or 8) / 2
        World:fx("burst", ex, ey, { color = "violet", n = 6, speed = 90 })
        e.hp = 0
        e.dead = true
        n = n + 1
      end
    end
  end
  return n
end

function Boss:onDeath()
  local World = require "src.world"
  local cx, cy = self:center()
  G.run.flags["boss_" .. self.bossId] = true
  World.bossActive = nil
  -- a dead boss cannot be allowed to leave its arena on fire: the reward
  -- is about to be placed, and the players have to walk out
  if World.clearFlood then World:clearFlood() end
  for _, e in ipairs(World.entities) do
    if e.pot and not e.dead then e.dead = true end
  end
  -- every add this boss put in the room dies with it
  self:clearAdds()
  -- ...and the ice stops. A dead machine is not still freezing the room
  -- you have to walk out of.
  if World.frost then World.frost = nil end
  Cam.shake(5, 0.8)
  if G.Audio then
    G.Audio.sfx("explode")
    G.Audio.sfx("roar")
  end
  for i = 1, 5 do
    World:fx("burst", cx + U.rand(-16, 16), cy + U.rand(-16, 16),
      { color = U.choose({ "ember", "gold", "magma" }), n = 12, speed = 160 })
  end
  -- Loot falls with physics and dies after seven seconds, so it has to
  -- START somewhere you can chase it. A boss that dies over the Mycel
  -- Choir's spike floor used to scatter six bigshards, three hearts and
  -- four scrap straight into the spikes, where they simply expired.
  local lx, ly = World:settleDrop(cx - 7, cy - 6, 14, 12)
  lx, ly = lx + 7, ly + 6
  Pickup.drop(World, lx, ly, "bigshard", 6)
  Pickup.drop(World, lx, ly, "heart", 3)
  Pickup.drop(World, lx, ly, "scrap", 4)
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
  local track = World:musicName(World.room.music)
  if track and G.Audio then G.Audio.playMusic(track) end
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
-- It was never planted. The Maw drags itself after you, roots and all --
-- slowly, but it does not stop coming.
local MAW_CREEP = 34     -- px/sec while stalking
local MAW_LUNGE = 165    -- px/sec during the sweep
local MAW_SWAY = 12      -- px/sec of vine-strain wobble on top of that
local MAW_REACH = 26     -- how close it closes before it stops shoving

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

  -- Movement goes through PH.move, which resolves each axis separately.
  -- The old code wrote an ABSOLUTE pose every frame and skipped the write
  -- entirely whenever that pose was blocked -- so anywhere near a wall or
  -- the floor it advanced only on the frames the sine happened to land
  -- free, which read as the boss juddering in place. Never veto a whole
  -- step; let the physics slide it.
  local target = World:nearestPlayer(cx, cy)
  local want = 0
  if target then
    local dx = (target.x + target.w / 2) - cx
    local adx = math.abs(dx)
    -- Deadband. Without it the boss sits exactly on MAW_REACH and toggles
    -- between closing and idling every frame, which is its own kind of
    -- judder: it stops closing at MAW_REACH but will not start again until
    -- you are clearly outside it.
    if self.closing == nil then self.closing = true end
    if self.closing and adx <= MAW_REACH then self.closing = false
    elseif not self.closing and adx > MAW_REACH * 1.9 then self.closing = true end
    if self.closing then want = U.sign(dx) end
    if want ~= 0 then self.facing = want end
  end
  local speed = (self.state == "sweep") and MAW_LUNGE or MAW_CREEP
  self.vx = want * speed + math.sin(self.t * 1.1) * MAW_SWAY
  self.vy = math.min((self.vy or 0) + 700 * dt, 260)
  PH.move(self, self.vx * dt, self.vy * dt)
  cx, cy = self:center()

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
      local px = cx + self.facing * (40 + self.volleyN * 32) + U.rand(-10, 10)
      self:fireAt(cx + self.facing * 10, self.y + 6, px, self.y - 120, 150,
        { kind = "orb", dmg = 2, gravity = 260, life = 3.5, size = 6 })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then
      self.volleyN = nil
      -- one roll, not two: these were separate U.chance calls, so the
      -- state and its duration were decided independently and a sweep
      -- could run for 3s. Now that a sweep is a LUNGE, that was the
      -- difference between closing 300px and closing 500px.
      local lunge = U.chance(0.5)
      self:setState(lunge and "sweep" or "open", lunge and 1.8 or 3)
    end
  elseif self.state == "sweep" then
    self.mouthOpen = false
    if not self.swept then
      self.swept = true
      local World2 = require "src.world"
      for i = 0, 2 do
        Proj.spawn(World2, cx + self.facing * (self.w / 2 + 4),
          self.y + self.h - 8, {
          side = "enemy", dmg = 3, kind = "shard", size = 6,
          vx = self.facing * (110 + i * 45), vy = 0, life = 3,
        })
      end
      if G.Audio then G.Audio.sfx("shoot1") end
      -- spawn a gnat harasser sometimes
      if U.chance(0.5) then
        local g = Entity.make("gnat", cx + self.facing * 60, self.y - 20)
        self:addSpawn(g)
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
    hp = 145, touchDmg = 3, w = 26, h = 30, reward = "module:hydroseals" })
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

  if (self.guardT or 0) > 0 then self.guardT = self.guardT - dt end

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
-- A plated charge into the tower shield shatters the guard instead of
-- dealing damage -- the Cinder Ram is a key, not just a number.
function Rustwarden:guardBreak(dur)
  if self.shieldGone or (self.guardT or 0) > 0 then return false end
  self.guardT = dur
  local World = require "src.world"
  World:fx("burst", self.x + self.w / 2 + self.facing * 14, self.y + 10,
    { color = "silver", n = 16, speed = 150 })
  Cam.shake(3, 0.3)
  if G.game then G.game:announce("The tower shield buckles!", 1.8) end
  return true
end
-- Asked by Proj before the damage pass so a stopped round is destroyed at
-- the shield instead of sailing through the body. The LINK blast is never
-- stopped -- it is the pair's standing answer to a raised guard.
function Rustwarden:deflects(srcx, srcy, opts)
  if opts and opts.link then return false end
  if self.state == "stunned" or self.shieldGone or (self.guardT or 0) > 0 then
    return false
  end
  -- judge the attack by where it CAME from (the shooter if known --
  -- fast projectiles can tunnel past the midline before they connect)
  local ax = srcx
  if opts and opts.owner then ax = opts.owner.x + opts.owner.w / 2 end
  local side = ax and U.sign(ax - (self.x + self.w / 2)) or self.facing
  return side == self.facing or side == 0
end
function Rustwarden:hurt(dmg, srcx, srcy, opts)
  if self:deflects(srcx, srcy, opts) then
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2 + self.facing * 14, self.y + 10,
      { color = "silver", n = 4 })
    if G.Audio then G.Audio.sfx("crack") end
    return false
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
  self.maxhp = 12
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
      self.regenT, self.regenMax = 15, 15
      other.regenT, other.regenMax = 15, 15
      other.brokenAt = nil
      if G.game then G.game:announce("BOTH VALVES BLOWN -- the engine is exposed!", 2.5) end
    else
      self.brokenAt = b.t
      self.regenT, self.regenMax = 1.0, 1.0
      if G.game and not b.taughtSync then
        b.taughtSync = true
        G.game:announce("A lone valve re-seals in a second. Blow BOTH together!", 3)
      end
    end
  else
    self.regenT, self.regenMax = 15, 15
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
local SURGE_DMG = { 8, 10, 20 }         -- Story / Normal / Veteran
local SURGE_DOME_COST = 20             -- energy bite for sheltering one body

local Tideengine = Boss.extend()
function Tideengine:init(x, y)
  Boss.init(self, x, y, { id = "tideengine", name = "TIDE ENGINE",
    hp = 125, touchDmg = 3, w = 44, h = 36,
    reward = "module:resonator" })
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
    local v1 = Valve.new(self.x - 90, self.y + 3 * T, self)
    local v2 = Valve.new(self.x + self.w + 76, self.y + 3 * T, self)
    self:addSpawn(v1) self:addSpawn(v2)
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
      for i = 1, 4 do
        local mx = self.x + U.rand(-70, self.w + 70)
        local mine = Entity.make("depthmine", mx, self.y + 30)
        self:addSpawn(mine)
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
          self:addSpawn(mini)
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
        self:addSpawn({
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
-- seconds -- the ONLY window a LINK SHOT shatters the lattice.
--
-- Three things pile on top of that, in phases:
--
--   POUR-SHOT   it locks a random bot, charges for eight tenths, and
--               fires three heavy fireballs in a fan at where that bot
--               WAS. The lock does not track, so movement is the answer.
--   SLAG TIDE   every slam now spews, not just a slam you punished. Hard
--               capped, because a swarm you cannot clear inside a cycle
--               stops being difficulty and becomes arithmetic.
--   THE POTS    two crucibles over the two refuge platforms fill with
--               lava and tip, and the whole floor becomes lava for six
--               seconds. Shoot a filling pot out and it stays broken
--               for thirty.
--
-- The interlocks in armPots() are load-bearing, not polish: no pot may
-- COMMIT while the boss is on the ground, because those five grounded
-- seconds are the link window, and the link window is the entire reason
-- this fight exists. Flooding the floor during it would leave a boss
-- that checkprogress still calls completable and a player who cannot
-- read what the fight wants.
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
  self.aimT = 6.5         -- hover time until the next pour-shot
  self.potT = 8           -- no pot may arm in the opening seconds
  self.phase = 1
end

local SLAG_CAP = 14       -- concurrent slaglings; see the header
local SLAG_PER_SLAM = 8
local AIM_LOCK = 0.25
local AIM_CHARGE = 0.8

function Crucible:slagCount(World)
  local n = 0
  for _, e in ipairs(World.entities) do
    if not e.dead and e.slagling then n = n + 1 end
  end
  return n
end

function Crucible:pots(World)
  local out = {}
  for _, e in ipairs(World.entities) do
    if not e.dead and e.pot then out[#out + 1] = e end
  end
  return out
end

-- Grounded means the link window is open or about to be; nothing may
-- tip into it. A pot already filling is HELD at the brim instead, so the
-- threat does not evaporate -- it waits for you on the way back up.
function Crucible:grounded()
  local st = self.state
  return st == "ventapproach" or st == "ventslam" or st == "venting"
    or st == "stunned" or st == "rise"
end

function Crucible:armPots(World, dt)
  local pots = self:pots(World)
  if #pots == 0 then return end
  self.potT = self.potT - dt
  if self:grounded() then
    for _, p in ipairs(pots) do p:hold() end
    return
  end
  if self.phase < 2 then return end
  if self.potT > 0 then return end
  -- A wall of slaglings between you and the ladder is not a fight, it is
  -- a sentence, so a crowded floor delays the arming. It must not CANCEL
  -- it: the swarm caps at SLAG_CAP and a slam refills it, so a player who
  -- is not clearing adds would otherwise never see a pot again -- the
  -- mechanic would quietly switch itself off for exactly the player it
  -- was meant to pressure. Six seconds of grace, then it arms anyway.
  if self:slagCount(World) > 12 then
    self.potBlockT = (self.potBlockT or 0) + dt
    if self.potBlockT < 6 then self.potT = 0.5 return end
  else
    self.potBlockT = 0
  end
  local ready = {}
  for _, p in ipairs(pots) do if p:ready() then ready[#ready + 1] = p end end
  if #ready == 0 then self.potT = 2 return end
  local armed = 0
  -- phase 3 arms both at once when both are cold: the finale, and the
  -- reason the centre platform exists
  local want = (self.phase >= 3 and #ready >= 2) and 2 or 1
  for i = 1, math.min(want, #ready) do
    local p = (want == 2) and ready[i] or ready[love.math.random(1, #ready)]
    if p:arm() then armed = armed + 1 end
  end
  if armed > 0 then
    self.potBlockT = 0
    self.potT = (self.phase >= 3 and 13 or 17)
    if G.game then
      G.game:announce(armed > 1
        and "BOTH CRUCIBLES ARE FILLING -- shoot them out!"
        or "A crucible is filling. Shoot it out, or get off the floor.", 2.4)
    end
  end
end
function Crucible:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  local cx0 = World.w * T / 2
  -- the floor under the arena's CENTRE, found rather than assumed: the
  -- Crucible's floor now has a basin in the middle, and a hardcoded
  -- height left the slam hanging a tile above it
  local floorTopY = World.h * T - 5 * T
  do
    local tx = math.floor(cx0 / T)
    for ty = math.floor(floorTopY / T) - 2, World.h - 1 do
      if World:isSolid(tx, ty) then floorTopY = ty * T break end
    end
  end

  if self.state == "intro" then
    if self.stateT <= 0 then self:setState("spiral", 5) end
    return
  end

  -- phase by health: everything arrives in layers, because all of it at
  -- once is a wall rather than a fight
  local frac = self.hp / self.maxhp
  local want = frac > 0.66 and 1 or (frac > 0.33 and 2 or 3)
  if want > self.phase then
    self.phase = want
    if want == 2 and G.game then
      G.game:announce("The flanking crucibles wake up.", 2.4)
    elseif want == 3 and G.game then
      G.game:announce("It opens every vent it has.", 2.4)
    end
    if G.Audio then G.Audio.sfx("bosswarn") end
  end
  self:armPots(World, dt)

  local hovering = self.state == "spiral" or self.state == "wave"
  if hovering then
    -- float in a slow circle between the gun platforms
    self.x = self.homeX + math.cos(self.t * 0.7) * 24
    self.y = self.homeY + math.sin(self.t * 1.1) * 8
    self.ventT = self.ventT - dt
    self.shieldHintT = self.shieldHintT - dt
    self.aimT = self.aimT - dt
    -- never start a pour-shot inside the run-up to a vent: the volley
    -- would still be in the air during the link window
    if self.aimT <= 0 and self.ventT > 2.2 then
      self.aimT = (self.phase >= 3) and 5 or 6.5
      self:setState("aimlock", AIM_LOCK)
    end
    if self.shieldHintT <= 0 then
      self.shieldHintT = 20
      if G.game then
        G.game:announce("The lattice shrugs off small arms. Wait for the slam.", 3)
      end
    end
    if self.ventT <= 0 then
      self.ventT = 11
      self:setState("ventapproach", 1.4)
      -- the vent blast blows the floor clear on the way down, so the
      -- five grounded seconds are always five seconds of floor
      if World.drainFlood then World:drainFlood() end
      if G.Audio then G.Audio.sfx("bosswarn") end
    end
  end

  if self.state == "aimlock" then
    -- freeze the aim point NOW. It does not follow you: the dodge is to
    -- move, and moving ACROSS the line beats moving along it.
    if not self.lockPt then
      local p = self:randomTarget(World)
      if p then
        self.lockPt = { p.x + p.w / 2, p.y + p.h / 2 }
      else
        self.lockPt = { World.w * T / 2, World.h * T - 6 * T }
      end
      if G.Audio then G.Audio.sfx("surgecharge") end
    end
    if self.stateT <= 0 then self:setState("aimcharge", AIM_CHARGE) end
  elseif self.state == "aimcharge" then
    if self.stateT <= 0 then
      local cx, cy = self:center()
      local lp = self.lockPt
      -- atan2, NOT two-argument math.atan. LÖVE runs LuaJIT, which is
      -- Lua 5.1: math.atan there takes ONE argument and silently drops
      -- the second, so the volley left on a bearing derived from dy
      -- alone and flew nowhere near the player. Every other bearing in
      -- this codebase uses atan2; this was the one that did not.
      local a = math.atan2(lp[2] - cy, lp[1] - cx)
      for k = -1, 1 do
        local a2 = a + k * 0.157        -- +/- 9 degrees
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = 6, kind = "fireball", size = 10,
          vx = math.cos(a2) * 165, vy = math.sin(a2) * 165, life = 3.0,
        })
      end
      self.lockPt = nil
      Cam.shake(3, 0.25)
      if G.Audio then G.Audio.sfx("surgeblast") end
      self:setState("spiral", 3.5)
    end
  elseif self.state == "spiral" then
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
      self:spewSlag(World, SLAG_PER_SLAM)
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
      self:setState("rise", 2)
      if G.game then G.game:announce("The shield lattice reknits...", 1.6) end
      if G.Audio then G.Audio.sfx("domeon") end
    end
  elseif self.state == "rise" then
    self.y = U.approach(self.y, self.homeY, 90 * dt)
    if math.abs(self.y - self.homeY) < 3 or self.stateT <= 0 then
      self.y = self.homeY
      self:setState("spiral", 5)
    end
  end
end
-- a random live bot, not the nearest: the nearest is always whoever is
-- being brave, and punishing bravery every single time reads as unfair
function Crucible:randomTarget(World)
  local live = {}
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle then live[#live + 1] = p end
  end
  if #live == 0 then return nil end
  return live[love.math.random(1, #live)]
end

function Crucible:spewSlag(World, n)
  local room = SLAG_CAP - self:slagCount(World)
  if room <= 0 then return end
  n = math.min(n, room)
  local cx = self.x + self.w / 2
  for i = 1, n do
    local e = Entity.make("slagling", cx + U.rand(-52, 52), self.y + self.h - 8)
    if e and e ~= true then
      e.vy = -140 - U.rand(0, 60)
      self:addSpawn(e)
    end
  end
  World:fx("burst", cx, self.y + self.h, { color = "magma", n = 16, speed = 140 })
  if G.game then G.game:announce("It spews a tide of slaglings!", 1.6) end
  if G.Audio then G.Audio.sfx("roar") end
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
  -- the pour-shot's aim line: thin on the lock, thick and bright as it
  -- charges. It is the whole fairness of the attack -- you are told
  -- exactly where it is going a second before it goes there.
  if self.lockPt then
    local lp = self.lockPt
    local charging = self.state == "aimcharge"
    local k = charging and (1 - math.max(0, self.stateT / AIM_CHARGE)) or 0
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 0.35 + k * 0.5)
    g.setLineWidth(1 + k * 2)
    g.line(cx, cy, lp[1], lp[2])
    g.setLineWidth(1)
    local r = 4 + k * 5
    g.setColor(P.magma[1], P.magma[2], P.magma[3], 0.5 + k * 0.4)
    g.circle("line", lp[1], lp[2], r)
    if charging then
      g.setColor(P.spark[1], P.spark[2], P.spark[3], k)
      g.circle("fill", cx, cy, 4 + k * 6)
    end
    g.setColor(1, 1, 1, 1)
  end
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
-- 6. THE CONDUCTOR (Crystal boss) -- the scheduler of a dead machine
--
-- It is still dispatching work to processors that stopped answering a
-- century ago, and it will not be told.
--
-- THE PROBLEM THIS REFIT SOLVES. The old fight had mechanics but no
-- reason to use them: :hurt refused damage in exactly one state, a 4.5s
-- cache flush that ran three times, so for ~90% of the fight the
-- scheduler was a plain HP sponge. The split, the bus terminals and the
-- refracted-damage window were all optional efficiencies stacked on a
-- baseline -- stand still and shoot it -- that already worked. You could
-- gun it down having engaged with none of it.
--
-- So the shield is the DEFAULT now, and the arena's beam circuit is the
-- only thing that opens it.
--
--   SHIELDED    three images, one real, spread across three stations.
--               Nothing but a beam through the real one does anything.
--   SHATTERED   four seconds, fully vulnerable. Guns do the real damage;
--               the circuit's 10% is the opener, not the payload.
--   RECHARGE    shield back, a swarm of wisps, stations re-rolled.
--
-- WHY THE MACHINE GUN IS THE BEST PART. It taxes the exact resource the
-- solution needs. Every second Lu spends holding the dome against it is
-- energy that is not going into an emitter, and an emitter costs half
-- her bar. The fight becomes a budget rather than a reflex test, and it
-- does that without adding a single button.
--
-- WHAT WENT. The cache flush (its damage-window job belongs to the
-- circuit and its pressure job to the machine gun) and the bus terminals
-- (a second, redundant stun path). Both were removed rather than left
-- lying around, because two unrelated "turn its own light back on it"
-- mechanics in one fight is one too many.
-- ==================================================================
local Prismtyrant = Boss.extend()

-- Every number the fight is balanced on, in one place.
--
-- The window is FOUR seconds and not ten because ten is the whole boss:
-- Bolt Driver at tier 2 is 3 damage on a 0.22s cycle, about 13 dps, so
-- ten free seconds is ~130 damage. Against 280 that is half the fight
-- for one solve, and the 10% chip would be decoration. At four seconds
-- a cycle is worth ~24 chip + ~52 burst, so it takes three or four
-- solves and lands around two minutes.
Prismtyrant.MAXHP        = 280
Prismtyrant.SHATTER_T    = 4.0     -- seconds of vulnerability per solve
Prismtyrant.BEAM_CHIP    = 0.10    -- fraction of max HP the beam itself does
Prismtyrant.SWAP_T       = 40      -- seconds between station swaps
Prismtyrant.JITTER_T     = 3       -- +/- tiles, and the panel rails match it
Prismtyrant.STATION_X    = { 12, 30, 48 }   -- tile columns, evenly spread
Prismtyrant.STATION_Y    = 6                -- tile row: low enough to read
Prismtyrant.SPLIT_COUNT  = 3
Prismtyrant.SWARM_N      = 4       -- wisps spawned on every recharge
-- The teleport is a two-phase warp, not a blink. It used to cut from one
-- station to another in a single frame with a burst at each end, which
-- reads as a dropped frame rather than as a machine relocating itself.
-- Out: it flickers and comes apart into its own pixels. In: those pixels
-- pull back together at the new station.
Prismtyrant.WARP_OUT     = 0.32
Prismtyrant.WARP_IN      = 0.36
Prismtyrant.WARP_CELLS   = 54     -- blocks the body dissolves into
-- Harmless for now. Set this above zero and the two false images start
-- punishing a guess instead of only wasting it.
Prismtyrant.SPLIT_FALSE_DMG = 0
-- machine gun
Prismtyrant.MG_EVERY     = 8.0     -- seconds between bursts
Prismtyrant.MG_TELL      = 0.6     -- telegraph before the first round
Prismtyrant.MG_LEN       = 1.5     -- seconds of fire
Prismtyrant.MG_RATE      = 0.11    -- seconds between rounds
Prismtyrant.MG_DMG       = 2
Prismtyrant.MG_TRACK     = 1.5     -- radians/sec the stream re-aims

function Prismtyrant:init(x, y)
  Boss.init(self, x, y, { id = "prismtyrant", name = "THE CONDUCTOR",
    hp = Prismtyrant.MAXHP, touchDmg = 4, w = 28, h = 34,
    reward = "module:corekey2" })
  self.homeX, self.homeY = x, y
  self.shielded = true
  self.shatterT = 0
  self.swapT = Prismtyrant.SWAP_T
  self.mgT = Prismtyrant.MG_EVERY
  -- thresholds that slam the shield back up mid-window
  self.restoreAt = { 0.75, 0.5, 0.25 }
  self.images = nil
end

-- ------------------------------------------------------------------
-- stations
-- ------------------------------------------------------------------
-- Re-roll which station is real and where each one actually sits. The
-- jitter is +/- JITTER_T tiles, which is exactly the span of a panel's
-- rail -- so every cycle asks the players to re-aim, and asks it inside
-- a window the hardware can just barely satisfy.
function Prismtyrant:rollStations()
  local World = require "src.world"
  local real = love.math.random(1, Prismtyrant.SPLIT_COUNT)
  self.images = {}
  for i = 1, Prismtyrant.SPLIT_COUNT do
    local base = (Prismtyrant.STATION_X[i] or 30) * T
    local jit = love.math.random(-Prismtyrant.JITTER_T, Prismtyrant.JITTER_T) * T
    self.images[i] = {
      x = U.clamp(base + jit - self.w / 2, 2 * T, (World.w - 3) * T - self.w),
      real = (i == real), t = U.rand(0, 6), station = i,
    }
  end
  self.realImage = real
  self.homeY = Prismtyrant.STATION_Y * T
  self.x = self.images[real].x
end

-- Begin the warp. The stations are NOT rolled here: they are rolled at
-- the moment the old body finishes coming apart, so the pixels that fly
-- back together are the first sign of where it went.
function Prismtyrant:swapStations()
  if self.warpPhase then return end
  self.warpPhase = "out"
  self.warpT = Prismtyrant.WARP_OUT
  self.swapT = Prismtyrant.SWAP_T
  if G.Audio then G.Audio.sfx("warpout") end
end

-- How far through the current warp phase we are, 0..1, and how much the
-- body should be broken up: 0 whole, 1 fully scattered.
function Prismtyrant:warpBreak()
  if not self.warpPhase then return 0 end
  local dur = self.warpPhase == "out" and Prismtyrant.WARP_OUT
    or Prismtyrant.WARP_IN
  local k = 1 - U.clamp((self.warpT or 0) / dur, 0, 1)
  if self.warpPhase == "in" then k = 1 - k end
  return k
end

function Prismtyrant:updateWarp(dt)
  if not self.warpPhase then return false end
  local World = require "src.world"
  self.warpT = self.warpT - dt
  -- a few motes leaving/arriving, so the dissolve has some depth to it
  self.warpFx = (self.warpFx or 0) - dt
  if self.warpFx <= 0 then
    self.warpFx = 0.04
    local cx, cy = self:center()
    local a = U.rand(0, math.pi * 2)
    local r = 10 + self:warpBreak() * 34
    World:fx("trail", cx + math.cos(a) * r, cy + math.sin(a) * r,
      { color = U.choose({ "violet", "ice", "orchid" }), r = 1.5, t = 0.22 })
  end
  if self.warpT > 0 then return true end
  if self.warpPhase == "out" then
    -- gone. Now decide where it went.
    self:rollStations()
    self.warpPhase = "in"
    self.warpT = Prismtyrant.WARP_IN
    if G.Audio then G.Audio.sfx("warpin") end
  else
    self.warpPhase = nil
    local cx, cy = self:center()
    World:fx("burst", cx, cy, { color = "violet", n = 12, speed = 90 })
  end
  return true
end

function Prismtyrant:randomLive(World)
  local live = {}
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle then live[#live + 1] = p end
  end
  if #live == 0 then return nil end
  return live[love.math.random(1, #live)]
end
function Prismtyrant:aliveTargets()
  local World = require "src.world"
  local out = {}
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle then out[#out + 1] = p end
  end
  return out
end

-- ------------------------------------------------------------------
-- the beam strike: the only thing that opens the shield
-- ------------------------------------------------------------------
-- Called by World:updateBeams for every beam segment overlapping this
-- body. Heavy entities are immune to the outright kill a beam does to
-- small enemies, which is right -- but the Conductor still needs to know
-- it is standing in one.
function Prismtyrant:beamStrike(seg, dt)
  if self.dead or not self.shielded then return end
  if self.state == "intro" or self.warpPhase then return end
  -- one strike per beam, not one per frame
  if (self.strikeLock or 0) > 0 then return end
  self.strikeLock = 2.5
  -- SPEND THE BEAM. The beam runs from the arena floor all the way up to
  -- the station, so a beam that stays lit after it has done its job
  -- stands in a lethal column exactly where the players now have to go
  -- to use the window they just paid half a bar for. It is ammunition:
  -- it fires once, it breaks the shell, it goes out.
  if seg and seg.src and seg.src.expend then seg.src:expend() end
  self:shatter()
end

function Prismtyrant:shatter()
  local World = require "src.world"
  self.shielded = false
  self.shatterT = Prismtyrant.SHATTER_T
  local chip = math.max(1, math.floor(self.maxhp * Prismtyrant.BEAM_CHIP))
  local cx, cy = self:center()

  -- THE SHATTER. The moment the whole fight is built around, so it gets
  -- a moment: the shell's own six prisms are thrown outward from exactly
  -- where they were orbiting, a white flash, a ring, and a thud you feel
  -- more than hear. shatterFlash drives the draw side for a third of a
  -- second, which is long enough to read and short enough not to eat
  -- into a four-second window.
  self.shatterFlash = 0.35
  for i = 0, 5 do
    local a = self.t * 0.8 + i * math.pi * 2 / 6
    local px, py = cx + math.cos(a) * 26, cy + math.sin(a) * 21
    World:fx("burst", px, py, { color = "ice", n = 9, speed = 210 })
    World:fx("trail", px, py, {
      color = "ice", r = 3, t = 0.5,
      vx = math.cos(a) * 150, vy = math.sin(a) * 150 - 40,
    })
  end
  World:fx("burst", cx, cy, { color = "spark", n = 22, speed = 90 })
  Cam.shake(7, 0.5)
  if G.Audio then
    G.Audio.sfx("shieldbreak")
    G.Audio.sfx("crack")
  end
  if G.game then G.game:announce("The shield has been shattered", 2) end
  -- the chip goes through Entity.hurt so death, flash and the reward
  -- path all behave exactly as they do for any other damage
  Entity.hurt(self, chip, cx, cy, { beam = true })
end

function Prismtyrant:recharge()
  local World = require "src.world"
  if self.dead then return end
  self.shielded = true
  self.shatterT = 0
  local cx, cy = self:center()
  World:fx("burst", cx, cy, { color = "orchid", n = 20, speed = 120 })
  if G.Audio then G.Audio.sfx("energize") end
  if G.game then G.game:announce("The shield has recharged", 2) end
  -- a swarm on every recharge: lingering in the open after a window
  -- closes has to cost something, and it gives Vess work while Lu's bar
  -- comes back
  for i = 1, Prismtyrant.SWARM_N do
    local a = (i / Prismtyrant.SWARM_N) * math.pi * 2
    local w = Entity.make("prismwisp",
      U.clamp(cx + math.cos(a) * 44, 2 * T, (World.w - 3) * T),
      U.clamp(cy + math.sin(a) * 30, 2 * T, (World.h - 3) * T))
    if w and w ~= true then self:addSpawn(w) end
  end
  -- and the stations move, so the solve you just did is not reusable
  self:swapStations()
end

-- ------------------------------------------------------------------
function Prismtyrant:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  if self.strikeLock then self.strikeLock = math.max(0, self.strikeLock - dt) end
  if self.tooStrongT then self.tooStrongT = math.max(0, self.tooStrongT - dt) end
  if self.shatterFlash then
    self.shatterFlash = self.shatterFlash - dt
    if self.shatterFlash <= 0 then self.shatterFlash = nil end
  end

  if self.state == "intro" then
    if self.stateT <= 0 then
      self:rollStations()
      self:setState("run", 999)
    end
    return
  end

  if not self.images then self:rollStations() end

  -- MID-WARP the machine is not in the room. It does not shoot, it does
  -- not track, and it cannot be hit -- beamStrike checks this too, so a
  -- beam that happens to be burning through the column it left does not
  -- score a free solve on a body that is not there.
  if self:updateWarp(dt) then
    self.y = self.homeY + math.sin(self.t * 1.3) * 8
    return
  end

  -- it hangs at its station and bobs; every position change is a swap
  self.x = U.approach(self.x, self.images[self.realImage].x, 260 * dt)
  self.y = self.homeY + math.sin(self.t * 1.3) * 8

  -- ---- shield / window
  if self.shielded then
    self.swapT = self.swapT - dt
    if self.swapT <= 0 then self:swapStations() end
  else
    self.shatterT = self.shatterT - dt
    -- an HP threshold slams the shield back up with part of your prize
    -- still on the table, which is exactly what makes it felt
    local frac = self.hp / self.maxhp
    if self.restoreAt[1] and frac <= self.restoreAt[1] then
      table.remove(self.restoreAt, 1)
      if G.Audio then G.Audio.sfx("bosswarn") end
      self:recharge()
    elseif self.shatterT <= 0 then
      self:recharge()
    end
  end

  -- ---- machine gun: the reason to hold a dome, and the reason not to
  self.mgT = self.mgT - dt
  if self.mgT <= 0 and not self.mgFiring then
    self.mgFiring = true
    self.mgPhase = "tell"
    self.mgPhaseT = Prismtyrant.MG_TELL
    self.mgTarget = self:randomLive(World)
    if self.mgTarget then
      local cx, cy = self:center()
      local px, py = self.mgTarget:center()
      self.mgAim = math.atan2(py - cy, px - cx)
    end
    if G.Audio then G.Audio.sfx("bosswarn") end
  end
  if self.mgFiring then
    self.mgPhaseT = self.mgPhaseT - dt
    if self.mgPhase == "tell" then
      if self.mgPhaseT <= 0 then
        self.mgPhase = "fire"
        self.mgPhaseT = Prismtyrant.MG_LEN
        self.mgGap = 0
      end
    else
      -- the stream re-aims slowly: fast enough that standing still is
      -- fatal, slow enough that moving across it works
      local tgt = self.mgTarget
      if tgt and not tgt.dead and not tgt.downed then
        local cx, cy = self:center()
        local px, py = tgt:center()
        local want = math.atan2(py - cy, px - cx)
        local d = (want - (self.mgAim or want) + math.pi * 3) % (math.pi * 2) - math.pi
        self.mgAim = (self.mgAim or want)
          + U.clamp(d, -Prismtyrant.MG_TRACK * dt, Prismtyrant.MG_TRACK * dt)
      end
      self.mgGap = (self.mgGap or 0) - dt
      if self.mgGap <= 0 then
        self.mgGap = Prismtyrant.MG_RATE
        local cx, cy = self:center()
        local a = (self.mgAim or 0) + U.rand(-0.035, 0.035)
        Proj.spawn(World, cx, cy, {
          side = "enemy", dmg = Prismtyrant.MG_DMG, kind = "shard", size = 3,
          vx = math.cos(a) * 250, vy = math.sin(a) * 250, life = 2.2,
        })
        if G.Audio then G.Audio.sfx("shoot4") end
      end
      if self.mgPhaseT <= 0 then
        self.mgFiring = nil
        self.mgPhase = nil
        self.mgT = Prismtyrant.MG_EVERY
      end
    end
  end

  -- ---- the images keep up a light patter so the room is never quiet
  self.gap = (self.gap or 0) - dt
  if self.gap <= 0 then
    self.gap = 1.4
    for i, im in ipairs(self.images) do
      local dmg = im.real and 3 or Prismtyrant.SPLIT_FALSE_DMG
      if dmg > 0 then
        local p = self:randomLive(World)
        if p then
          local cx, cy = im.x + self.w / 2, self.y + self.h / 2
          local px, py = p:center()
          local ang = math.atan2(py - cy, px - cx)
          Proj.spawn(World, cx, cy, {
            side = "enemy", dmg = dmg, kind = "shard", size = 4,
            vx = math.cos(ang) * 170, vy = math.sin(ang) * 170, life = 2.2,
            harmlessImage = not im.real,
          })
        end
      end
    end
  end
end

function Prismtyrant:hurt(dmg, srcx, srcy, opts)
  local World = require "src.world"
  -- The shield is the default condition and the circuit is the only
  -- thing that opens it. This is the line that stops the fight being a
  -- damage race you can win by ignoring the room.
  if self.shielded and not (opts and opts.beam) then
    -- One exception, kept deliberately: its OWN light, turned back on it
    -- off a panel, still gets through for a little. It rewards a player
    -- who notices what the panels do without ever being enough on its
    -- own to replace the circuit.
    if opts and opts.refracted then
      World:fx("burst", self.x + self.w / 2, self.y + 10,
        { color = "ice", n = 10, speed = 130 })
      return Entity.hurt(self, math.max(1, math.floor(dmg * 0.5)), srcx, srcy, opts)
    end
    World:fx("spark", self.x + self.w / 2, self.y + 8, { color = "orchid", n = 3 })
    -- Said every time it happens, not once -- but throttled, because a
    -- scatter volley is five hits in one frame and the line would
    -- stutter. The clock is the boss's own, so it survives a reload.
    if (self.tooStrongT or 0) <= 0 then
      self.tooStrongT = 1.6
      if G.game then G.game:announce("The shield is too strong", 1.6) end
    end
    return false
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end

function Prismtyrant:draw()
  local g = love.graphics
  local cx, cy = self:center()

  -- MID-WARP: the whole set -- real and false alike -- comes apart and
  -- goes back together. Drawing only the real one would hand the player
  -- the answer for free every thirty seconds.
  local wk = self:warpBreak()
  if self.warpPhase then
    -- the flicker, hardest at the moment of departure and arrival
    local flick = (wk < 0.55) and (math.floor(G.time * 34) % 2 == 0)
    for i, im in ipairs(self.images or {}) do
      local icx = im.x + self.w / 2
      if flick then
        g.setColor(P.violet[1], P.violet[2], P.violet[3], (1 - wk) * 0.8)
        G.drawSprite("boss_prismtyrant", math.floor(self.t * 5) % 2 + 1,
          icx, self.y + self.h, { sx = 2.3, sy = 1.5 })
        g.setColor(1, 1, 1, 1)
      end
      self:drawDissolve(g, icx, self.y + self.h / 2, wk)
    end
    return
  end

  -- the false images: same silhouette, no shadow. That is the tell, and
  -- it is the only one -- the fight is asking you to look, not to react.
  if self.images then
    for i, im in ipairs(self.images) do
      if not im.real then
        local icx = im.x + self.w / 2
        g.setColor(P.violet[1], P.violet[2], P.violet[3],
          0.45 + math.sin(G.time * 5 + i) * 0.15)
        G.drawSprite("boss_prismtyrant", math.floor(self.t * 5) % 2 + 1,
          icx, self.y + self.h, { sx = 2.3, sy = 1.5 })
        g.setColor(1, 1, 1, 1)
        if self.shielded then self:drawShield(g, icx, self.y + self.h / 2, 0.35) end
      end
    end
    -- and the real one keeps its shadow
    g.setColor(0, 0, 0, 0.3)
    g.ellipse("fill", cx, self.y + self.h + 6, 16, 4)
  end
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

  if self.shielded then
    self:drawShield(g, cx, cy, 1)
  else
    -- the break itself: an expanding ring of what the shell used to be
    if self.shatterFlash then
      local k = 1 - (self.shatterFlash / 0.35)
      g.setColor(P.white[1], P.white[2], P.white[3], (1 - k) * 0.8)
      g.circle("fill", cx, cy, 6 + k * 10)
      g.setLineWidth(3 - k * 2)
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 1 - k)
      g.circle("line", cx, cy, 24 + k * 46)
      g.setLineWidth(1)
    end
    -- unmistakably open: the shell is gone and the seams are lit
    local pulse = 0.5 + math.sin(G.time * 14) * 0.4
    g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse * 0.8)
    g.circle("line", cx, cy, 30 + pulse * 4)
    -- a countdown arc, so the window is never a guess
    local frac = U.clamp(self.shatterT / Prismtyrant.SHATTER_T, 0, 1)
    g.setColor(P.spark)
    g.arc("line", "open", cx, cy, 34, -math.pi / 2,
      -math.pi / 2 + frac * math.pi * 2)
  end

  -- the machine gun's telegraph: a line you are given time to leave
  if self.mgFiring and self.mgPhase == "tell" and self.mgAim then
    local a = self.mgAim
    local warn = 0.35 + math.sin(G.time * 22) * 0.25
    g.setColor(P.orchid[1], P.orchid[2], P.orchid[3], warn)
    g.setLineWidth(2)
    g.line(cx, cy, cx + math.cos(a) * 400, cy + math.sin(a) * 400)
    g.setLineWidth(1)
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- THE DISSOLVE
--
-- No shader and no pixel access to the sprite, so the body is broken
-- into a fixed grid of blocks that scatter outward on a per-cell bearing
-- and pull back in on the way home. The bearings come from a hash of the
-- cell index, NOT from love.math.random: they have to be identical every
-- frame or the "pixels" boil instead of flying, and identical between
-- the out and in phases so the thing that reassembles is recognisably
-- the thing that came apart.
--
-- k = 0 is whole, k = 1 is fully scattered.
-- ------------------------------------------------------------------
local function cellHash(i, salt)
  local v = (i * 73856093 + salt * 19349663) % 65536
  return v / 65536
end

function Prismtyrant:drawDissolve(g, cx, cy, k)
  if k <= 0 then return end
  local cols, rows = 6, 9
  local bw, bh = self.w + 6, self.h + 6
  local ease = k * k                      -- slow to let go, then gone
  for i = 0, Prismtyrant.WARP_CELLS - 1 do
    local gx = i % cols
    local gy = math.floor(i / cols) % rows
    local px = cx - bw / 2 + (gx + 0.5) * (bw / cols)
    local py = cy - bh / 2 + (gy + 0.5) * (bh / rows)
    -- outward from the body's centre, with a per-cell twist so it does
    -- not read as a clean radial burst
    local ang = math.atan2(py - cy, px - cx) + (cellHash(i, 3) - 0.5) * 1.6
    local dist = (18 + cellHash(i, 7) * 46) * ease
    local lag = 0.55 + cellHash(i, 11) * 0.45      -- cells leave at
    local kk = U.clamp((k - (1 - lag)) / lag, 0, 1) -- different moments
    local ox, oy = math.cos(ang) * dist * kk, math.sin(ang) * dist * kk - kk * 6
    local a = 1 - kk * 0.85
    local col = ({ P.violet, P.orchid, P.ice })[1 + math.floor(cellHash(i, 5) * 3)]
    g.setColor(col[1], col[2], col[3], a)
    local sz = 3 - kk
    g.rectangle("fill", px + ox - sz / 2, py + oy - sz / 2, sz, sz)
  end
  g.setColor(1, 1, 1, 1)
end

-- the shell: a lattice of prisms, obviously solid, obviously a lid
function Prismtyrant:drawShield(g, cx, cy, alpha)
  local n = 6
  for i = 0, n - 1 do
    local a = self.t * 0.8 + i * math.pi * 2 / n
    local rx, ry = 26, 21
    local sx, sy = cx + math.cos(a) * rx, cy + math.sin(a) * ry
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.75 * alpha)
    g.polygon("fill", sx, sy - 5, sx + 4, sy, sx, sy + 5, sx - 4, sy)
  end
  local pulse = 0.22 + math.sin(G.time * 3) * 0.06
  g.setColor(P.ice[1], P.ice[2], P.ice[3], pulse * alpha)
  g.ellipse("fill", cx, cy, 28, 23)
  g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.6 * alpha)
  g.ellipse("line", cx, cy, 28, 23)
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
-- Calibrated against the real player physics on the sky_boss mesa, whose top
-- surface is 320px wide. A grounded player pushes back at 950 px/sec^2, so
-- only the excess over that actually moves them: at 1040, someone holding
-- into the wind drifts ~182px over the full 2s. Far enough to be shoved off
-- a downwind edge, never far enough to cross the mesa -- so the answer is to
-- stand on the upwind half. Letting go of the stick is NOT an answer: with
-- no input the only resistance is friction (800) and you are gone from
-- anywhere on the surface. There is no cover on this map any more; the wind
-- is uniform and position is the whole game.
local AERIE_GUST_FORCE = 1040
local AERIE_DIVE_EVERY = 6.5     -- seconds between dives
local AERIE_DIVE_SPEED = 620     -- px/sec of the stoop
local AERIE_LATCH_T = 4.0        -- how long she eats for
local AERIE_MUNCH_GAP = 0.5      -- seconds between bites
local AERIE_MUNCH_DMG = 3        -- damage per bite (24 over a full latch)
local AERIE_MISS_T = 1.0         -- floor time after a whiffed dive
local AERIE_DOME_STUN = 4.0      -- stun for hitting Lu's shield
local AERIE_FLY = 340            -- px/sec when repositioning
-- ENERGY LANCE: her answer to both players hiding inside the dome. Five
-- flat-drain darts against a 100-energy reserve means the shield fails on
-- roughly the fourth, and the rest arrive at an unprotected body. Turtling
-- no longer denies her a target; it just picks a different one.
local AERIE_LANCE_COUNT = 5      -- darts per burst
local AERIE_LANCE_GAP = 0.13     -- seconds between darts
local AERIE_LANCE_SPEED = 470    -- very fast: this is not a dodge check
local AERIE_LANCE_DRAIN = 26     -- flat energy torn out of the dome per hit
local AERIE_LANCE_DMG = 3        -- damage if it reaches a body instead

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

-- The nearest player who is NOT standing inside anybody's dome. She always
-- prefers an open body: the stoop is for flesh, not for shields.
function Aerie:openTarget(World)
  local cx, cy = self:center()
  local best, bd
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle and p.pinnedT <= 0 then
      local covered = false
      for _, q in ipairs(World.players) do
        if q.domeActive and not q.dead and not q.downed then
          local dx = p.x + p.w / 2 - (q.x + q.w / 2)
          local dy = p.y + p.h / 2 - (q.y + q.h / 2 - 4)
          if dx * dx + dy * dy < q.domeRadius * q.domeRadius then
            covered = true
            break
          end
        end
      end
      if not covered then
        local d = U.dist2(cx, cy, p.x + p.w / 2, p.y + p.h / 2)
        if not bd or d < bd then best, bd = p, d end
      end
    end
  end
  return best
end

-- Whoever is holding the shield up. The energy lance goes at her.
function Aerie:domeOwner(World)
  for _, p in ipairs(World.players) do
    if p.domeActive and not p.dead and not p.downed then return p end
  end
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
        -- She will only stoop on an OPEN body. If every body is tucked
        -- inside the dome there is nothing worth diving at, so she shoots
        -- the dome instead and waits for the formation to break.
        local open = self:openTarget(World)
        if open then
          self.diveTo = { x = open.x + open.w / 2 - self.w / 2,
                          y = open.y + open.h - self.h }
          self:setState("dive", 3)
          if G.Audio then G.Audio.sfx("dash") end
        else
          local holder = self:domeOwner(World)
          if holder then
            self.lanceTarget = holder
            self.lanceLeft = AERIE_LANCE_COUNT
            self.lanceGap = 0.1
            self:setState("lance", AERIE_LANCE_COUNT * AERIE_LANCE_GAP + 0.8)
            if G.Audio then G.Audio.sfx("linkcharge") end
            if G.game then
              G.game:announce("IT ANSWERS THE SHIELD -- BREAK FORMATION!", 2)
            end
          else
            self:setState("climb", 6)
          end
        end
      end
    end

  elseif self.state == "gust" then
    local dir = self.gustDir or 1
    self.x, self.y = self:perchPoint(World, self.perchSide)
    self.y = self.y + math.sin(self.t * 30) * 2
    -- uniform across the whole arena: there is nowhere to hide from it
    for _, p in ipairs(World.players) do
      if not p.dead and not p.downed and not p.idle and p.pinnedT <= 0 then
        p.vx = p.vx + dir * AERIE_GUST_FORCE * dt
      end
    end
    if self.stateT <= 0 then
      self.gustDir = nil
      self:setState("climb", 6)
    end

  elseif self.state == "lance" then
    -- perched, firing anti-shield darts at whoever is holding the dome
    local px, py = self:perchPoint(World, self.perchSide)
    self.x, self.y = px, py + math.sin(self.t * 26) * 2
    local tgt = self.lanceTarget
    if tgt and (tgt.dead or tgt.downed) then tgt = nil self.lanceTarget = nil end
    if tgt then
      self.facing = (tgt.x + tgt.w / 2) > (self.x + self.w / 2) and 1 or -1
    end
    self.lanceGap = (self.lanceGap or 0) - dt
    if self.lanceGap <= 0 and (self.lanceLeft or 0) > 0 and tgt then
      self.lanceGap = AERIE_LANCE_GAP
      self.lanceLeft = self.lanceLeft - 1
      local bx, by = self:center()
      Proj.energyDart(World, bx, by + 4,
        tgt.x + tgt.w / 2, tgt.y + tgt.h / 2,
        { speed = AERIE_LANCE_SPEED, drain = AERIE_LANCE_DRAIN,
          dmg = AERIE_LANCE_DMG })
      World:fx("spark", bx, by + 4, { color = "cyan", n = 7 })
      if G.Audio then G.Audio.sfx("shoot4") end
    end
    if not tgt or self.stateT <= 0
      or ((self.lanceLeft or 0) <= 0 and self.lanceGap <= 0) then
      self.lanceTarget = nil
      self.lanceLeft = nil
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
        -- Clear the hit-invulnerability first. takeDamage grants 1.2s of it,
        -- which would otherwise swallow every bite after the first and make
        -- the munch gap meaningless. The lava code does the same thing.
        p.invuln = 0
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
        q:domeAbsorb(50)
        World:fx("spark", cx, cy, { color = "cyan", n = 16 })
        if G.Audio then G.Audio.sfx("domehit") end
        if G.game then G.game:announce("The Aerie Sentinel is stunned!", AERIE_DOME_STUN) end
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
  elseif st == "charge" or st == "lance" then
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

  -- energy lance: a hard blue line onto the shield she is breaking
  if st == "lance" and self.lanceTarget then
    local cx, cy = self:center()
    local tx, ty = self.lanceTarget.x + self.lanceTarget.w / 2,
                   self.lanceTarget.y + self.lanceTarget.h / 2
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.25 + math.sin(G.time * 26) * 0.2)
    g.line(cx, cy + 4, tx, ty)
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.7)
    g.circle("line", tx, ty, 9 + math.sin(G.time * 18) * 3)
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
        self:addSpawn(Entity.make(names[i], self.x + U.rand(-60, 60), self.y + 40))
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
    self:addSpawn(ChoirNode.new(6 * T2, 26 * T2 + 6, self, 1)),  -- low, west
    self:addSpawn(ChoirNode.new(3 * T2, 16 * T2, self, 2)),      -- mid, west wall
    self:addSpawn(ChoirNode.new(25 * T2, 8 * T2 + 8, self, 3)),  -- high, east
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
          self:addSpawn(Entity.make("sporefly", self.x + U.rand(-40, 40), self.y + 30))
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
-- ==================================================================
-- THE ARCHIVIST -- the Threshold
-- ==================================================================
-- The old fight had the Conductor's disease: `hurt` refused damage
-- unless `state == "reshelve"`, and reshelve was reachable only through
-- a one-in-three dice roll off `ride`. So the whole fight was waiting,
-- and nothing you had learned in the zone was used to reach the window.
--
-- THE REFIT TIES IT TO THE VERB.
--
--   It does not attack the floor; it FREEZES it. Hoarfrost creeps in
--   from both walls a tile at a time, and the Archivist plants rime
--   directly beneath itself. The arena gets smaller instead of busier.
--
--   Its plating opens when the floor beneath it is CLEAR OF FROST --
--   not on a timer. There are exactly two ways to clear ground, and
--   they are the two the zone spent five rooms teaching: a lit brazier,
--   which frost will not grow near, and the Cinder Ram, which burns a
--   chevron through it. The braziers are the strategic answer and the
--   ram is the tactical one; the ram is NOT required, because a player
--   who took another route through the game must still be able to win.
--
--   At 75%, 50% and 25% it SNUFFS A BRAZIER. It is the only thing in
--   the game that puts fire out, which is exactly what "protect this
--   place" means to a machine that has been alone with the order for a
--   century. Re-lighting one means carrying a spark across an arena
--   that is closing, with no gun and no shield, while the other bot
--   keeps it off you. That is the zone's exam, and it is the same
--   co-op shape as the Ember, one size down.
--
--   IT NEVER SNUFFS THE LAST ONE. There has to be a fire left to take a
--   spark from, or the arena is a soft-lock with a boss in it.
--
-- COSTED. Bolt Driver at tier 2 is 3 damage on a 0.22s cycle, about
-- 13.6 dps. MAXHP 200 over an OPEN_T of 5s is ~68 damage a window, so
-- roughly three clean solves -- two minutes, matching the Crucible and
-- the Conductor. Change MAXHP and OPEN_T together; archivist_test
-- prints the solve count rather than asserting my arithmetic.
-- ==================================================================
local ARCH = {
  -- IT IS NEVER INVULNERABLE. The old fight refused damage outright
  -- unless the plating was open, which meant most of a two-minute fight
  -- was spent shooting something that ignored you -- the exact
  -- complaint the refit was supposed to answer, arrived at from the
  -- other direction. Plating now REDUCES damage instead of refusing it,
  -- and the HP is raised to match so the fight is the same length.
  -- archivist_test prints time-to-kill at several trigger uptimes;
  -- change MAXHP and SHIELD_MULT together and read the numbers.
  MAXHP     = 420,
  SHIELD_MULT = 0.4,  -- of your damage while the plating is shut
  OPEN_T    = 5.0,    -- seconds of open plating once the floor is clear
  RIME_SPAN = 5,      -- tiles of floor it ices beneath itself
  RIME_CD   = 4.5,    -- seconds between rime castings
  REDACT_T  = 3.0,    -- seconds a platform stays erased
  REDACT_CD = 9.0,
  RAIL_SPD  = 95,
  BEAM_DMG  = 5,
  -- Half-width of the freezing column, in px. Was 12; doubled, so it is
  -- a thing you have to dodge rather than a thing that misses you by
  -- default.
  BEAM_HALFW = 24,
  LOB_DMG   = 3,
  THRESHOLDS = { 0.75, 0.50, 0.25 },
  -- THE DIVE. It does not reach out and pinch a fire from the ceiling:
  -- it drops on the thing. Half a second of warning, a fall, a blast of
  -- frost, and then two seconds hanging there with its plating open
  -- while it drags itself back up -- which is the only time the fight
  -- GIVES you a window instead of making you earn one.
  SNUFF_CD    = 20.0,   -- seconds between dives, minimum
  DIVE_WARN   = 1.0,   -- a full second to read it and move
  DIVE_G      = 1500,
  DIVE_OPEN   = 2.0,    -- vulnerable, at the bottom
  DIVE_RISE   = 90,     -- px/s back to the rail
  BLAST_R     = 60,     -- the frost that comes off the impact
  BLAST_DMG   = 6,
  SQUISH_DMG  = 18,     -- directly underneath. Do not be there.
  BLAST_FROST = 6,      -- tiles of floor iced either side of the impact
}
Bosses.ARCH = ARCH

local Archivist = Boss.extend()
function Archivist:init(x, y)
  Boss.init(self, x, y, { id = "archivist", name = "THE ARCHIVIST",
    hp = ARCH.MAXHP, touchDmg = 4, w = 40, h = 26,
    reward = "weapon:magnetmortar" })
  self.railY = y
  self.dir = 1
  self.openT = 0
  -- the floor the ice eats. The room declares it, the way a flooding
  -- room declares `floodRow` -- deriving it from geometry guesses, and
  -- a guess here freezes a row nobody stands on.
  local World = require "src.world"
  Cold.frostInit(World, (World.room and World.room.frostRow)
    or (World.h - 6))
  self.rimeT = 2.0
  self.redactT = ARCH.REDACT_CD
  self.nextThreshold = 1
  self.snuffT = ARCH.SNUFF_CD * 0.6   -- the first one comes early
end

-- The floor row it stands over, and the span of it that has to be clear.
function Archivist:span(World)
  local cx = self.x + self.w / 2
  local half = math.floor(ARCH.RIME_SPAN / 2)
  local tx = math.floor(cx / T)
  return math.max(1, tx - half), math.min(World.w - 2, tx + half)
end

-- IT WILL NOT HANG WHERE IT CANNOT WORK.
--
-- Its rime span is five tiles and a lit brazier holds frost off two and
-- a half either side, so a boss centred exactly over a fire can never
-- ice the ground beneath itself -- floorClear() stays true, the plating
-- never shuts, and the whole fight collapses into "stand on the brazier
-- and shoot". Since it tracks the nearest bot along the rail, standing
-- on a fire is all that takes, and standing on a fire is the obvious
-- thing to do.
--
-- So it declines to park there. It slides to the nearest column where
-- its rime can actually bite, which reads exactly as it should: it will
-- come near your fire, but it will not hold station over it.
function Archivist:workableX(World, want)
  local half = math.floor(ARCH.RIME_SPAN / 2)
  local function biteable(bx)
    local tx = math.floor((bx + self.w / 2) / T)
    for t = tx - half, tx + half do
      if t >= 1 and t <= World.w - 2 then
        local px, py = t * T + 8, (World.frost and World.frost.row or 0) * T + 8
        local blocked = false
        for _, e in ipairs(World.entities) do
          if e.heatR and e.heatR > 0 and not e.dead then
            local dx = px - (e.x + (e.w or 0) / 2)
            local dy = py - (e.y + (e.h or 0) / 2)
            if dx * dx + dy * dy < Cold.FROST_BURN_R ^ 2 then blocked = true break end
          end
        end
        if not blocked then return true end
      end
    end
    return false
  end
  if biteable(want) then return want end
  for step = 1, 8 do
    local a2, b2 = want - step * T, want + step * T
    if biteable(a2) then return a2 end
    if biteable(b2) then return b2 end
  end
  return want
end

function Archivist:floorClear(World)
  local f = World.frost
  if not f then return true end
  local x0, x1 = self:span(World)
  for tx = x0, x1 do
    if f.cells[tx] then return false end
  end
  return true
end

-- IT IS ONLY VULNERABLE WITH CLEAR GROUND UNDER IT. Not on a timer, not
-- on a dice roll -- on the one thing the player controls.
-- IT ALWAYS TAKES DAMAGE. Shut plating is a discount, not a refusal --
-- so a player who never solves the floor still wins eventually, and a
-- player who does wins two and a half times faster.
function Archivist:hurt(dmg, sx, sy, opts)
  local World = require "src.world"
  if self.openT <= 0 then
    World:fx("spark", self.x + self.w / 2, self.y + self.h / 2,
      { color = "ice", n = 3 })
    if G.Audio then G.Audio.sfx("crack") end
    dmg = math.max(1, dmg * ARCH.SHIELD_MULT)
  end
  return Boss.hurt(self, dmg, sx, sy, opts)
end

-- The only thing in the game that puts fire out.
--
-- IT WILL TAKE THE LAST ONE. That used to be forbidden -- an arena with
-- no fire in it read as a soft-lock -- but it is not one: the door back
-- to the deep stacks is open, cold_5's braziers are still burning, and
-- a run that loses every light in here loses the FIGHT, not the save.
-- Making the last fire safe made the last stretch of the fight safe
-- too, and this is the one boss whose whole argument is that it will
-- put your lights out if you stop feeding them.
function Archivist:pickBrazier(World)
  local lit = {}
  for _, e in ipairs(World.entities) do
    if e.id and e.lit and e:lit() and not e.hearth then lit[#lit + 1] = e end
  end
  if #lit == 0 then return nil end
  -- the one nearest a bot, because taking the fire they are standing
  -- next to is what makes it feel like it is coming for you
  local px = World.players[1] and (World.players[1].x) or self.x
  local p = World:nearestPlayer(self:center())
  if p then px = p.x end
  local best
  for _, e in ipairs(lit) do
    if not best or math.abs(e.x - px) < math.abs(best.x - px) then best = e end
  end
  return best
end

function Archivist:beginDive(World, target)
  self.diveTarget = target
  -- centre the body on the brazier, and pick an approach speed from the
  -- distance so it ALWAYS arrives inside the telegraph. A fixed speed
  -- meant a dive started from the far wall came down beside the fire
  -- and put nothing out.
  local W2 = World.w * T
  self.diveX = U.clamp(target.x + 6 - self.w / 2, 40, W2 - 40 - self.w)
  self.diveSpd = math.max(220, math.abs(self.diveX - self.x)
    / ARCH.DIVE_WARN * 1.25)
  self.diveWarn = ARCH.DIVE_WARN
  self.diving = nil
  self.vy = 0
  self.openT = 0
  self:setState("dive", 8)
  Cam.shake(2, 0.3)
  if G.Audio then G.Audio.sfx("bosswarn") end
  if G.game and not self.taughtDive then
    self.taughtDive = true
    G.game:announce("It is coming DOWN on the fire -- get out from under it!", 3)
  end
end

-- Draw the shadow of where it is about to land, for the whole second.
function Archivist:diveMarkX() return self.diveX end

function Archivist:landDive(World)
  local cx, cy = self:center()
  local floorY = self.y + self.h

  -- SQUISHED. Directly underneath is the worst place in the room.
  --
  -- THE DOME DOES NOT HELP HERE, deliberately. Lu's shield turns the
  -- indexing beam aside because a beam is the kind of thing a shield is
  -- for; several tons of archive coming down on your head is not. So
  -- there is no domeActive check anywhere in this function -- the answer
  -- to the dive is to not be under it, which is what the telegraph is
  -- a full second long for.
  for _, p in ipairs(World.players) do
    if not p.dead and not p.downed and not p.idle then
      local pcx = p.x + p.w / 2
      local under = pcx > self.x - 4 and pcx < self.x + self.w + 4
        and p.y + p.h > self.y
      if under then
        p.invuln = 0
        p:takeDamage(ARCH.SQUISH_DMG, cx, { pierceDash = true })
      else
        local d = U.dist(pcx, p.y + p.h / 2, cx, floorY)
        if d < ARCH.BLAST_R then
          p.invuln = 0
          p:takeDamage(ARCH.BLAST_DMG, cx, { pierceDash = true, cold = true })
          p.vx = p.vx + U.sign(pcx - cx) * 120
        end
      end
    end
  end

  -- the fire goes out, and the ice takes the ground it was holding
  local b = self.diveTarget
  if b and b.lit and b:lit() then
    G.run.flags[Cold.flagFor(b.id)] = nil
    b.heatR = nil
    b.lightR = 0
    b.snuffed = true
    if G.game then
      G.game:announce("The fire is out. Carry a spark back to it.", 2.6)
    end
  end
  local tx = math.floor(cx / T)
  Cold.frostSeed(World, tx - ARCH.BLAST_FROST, tx + ARCH.BLAST_FROST)

  World:fx("burst", cx, floorY - 4, { color = "ice", n = 26, speed = 150 })
  Cam.shake(7, 0.6)
  if G.Audio then G.Audio.sfx("explode") end

  -- ...and now it is stuck on the floor, open, for two seconds
  self.openT = ARCH.DIVE_OPEN
  self.diving = nil
  self.rising = true
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

  -- the floor closes whatever else is happening
  Cold.frostUpdate(World, dt)

  -- THE WINDOW. Clear ground under it opens the plating, and it stays
  -- open for OPEN_T even if the ice comes back -- so a solve you earned
  -- is a solve you keep.
  --
  -- THE DIVE OWNS ITS OWN WINDOW. This block used to run during a dive
  -- too, decrementing openT TWICE on the same frame -- so the two
  -- seconds it hangs there stunned were really one -- and it could
  -- re-open mid-fall off floorClear(). While it is diving, the dive's
  -- clock is the only one running.
  if self.state == "dive" then       -- handled in the dive branch below
  elseif self.openT > 0 then
    self.openT = self.openT - dt
    if self.openT <= 0 then
      self.plateShut = 0.4
      if G.Audio then G.Audio.sfx("switch") end
    end
  elseif self:floorClear(World) then
    self.openT = ARCH.OPEN_T
    Cam.shake(2, 0.25)
    if G.Audio then G.Audio.sfx("shieldbreak") end
    if not self.taughtOpen and G.game then
      self.taughtOpen = true
      G.game:announce("Clear ground beneath it -- the plating is OPEN!", 3)
    end
  end
  if self.plateShut and self.plateShut > 0 then
    self.plateShut = self.plateShut - dt
  end

  -- THE DIVE. On a hard clock, and again at each health threshold --
  -- so it comes for your fires whether or not you are winning.
  self.snuffT = self.snuffT - dt
  local frac = self.hp / self.maxhp
  local threshold = self.nextThreshold <= #ARCH.THRESHOLDS
    and frac <= ARCH.THRESHOLDS[self.nextThreshold]
  if self.state ~= "dive" and (self.snuffT <= 0 or threshold) then
    if threshold then self.nextThreshold = self.nextThreshold + 1 end
    local target = self:pickBrazier(World)
    if target then
      self.snuffT = ARCH.SNUFF_CD
      self:beginDive(World, target)
    else
      self.snuffT = 4   -- nothing left to take; look again shortly
    end
  end

  if self.state == "dive" then
    if self.diveWarn and self.diveWarn > 0 then
      -- IT ONLY EVER COMES DOWN ON A FIRE. The telegraph is the boss
      -- sliding into place above the brazier and hanging there shaking,
      -- so "get out from under it" is a thing you can actually read --
      -- and the drop does not begin until it is genuinely lined up.
      self.diveWarn = self.diveWarn - dt
      self.x = U.approach(self.x, self.diveX, self.diveSpd * dt)
      self.y = self.railY + math.sin(G.time * 30) * 2
      if self.diveWarn <= 0 then
        self.diveWarn = nil
        self.x = self.diveX          -- exactly over it, never beside it
        self.diving = true
        self.vy = 0
      end
    elseif self.diving then
      -- STRAIGHT THROUGH THE SHELVES. It weighs what it weighs; a
      -- one-way ledge is not going to hold it, and stopping on one
      -- would leave the fire lit and the boss parked in mid-air. So the
      -- fall tests SOLID tiles only and ignores `=` entirely, which
      -- PH.move cannot do.
      self.vy = (self.vy or 0) + ARCH.DIVE_G * dt
      local step = self.vy * dt
      local feetX0 = math.floor((self.x + 4) / T)
      local feetX1 = math.floor((self.x + self.w - 4) / T)
      local landed = false
      local ny = self.y + step
      local fy = math.floor((ny + self.h) / T)
      for tx2 = feetX0, feetX1 do
        if World:isSolid(tx2, fy, self) then landed = true break end
      end
      if landed then
        self.y = fy * T - self.h
        self.vy = 0
        self:landDive(World)
      else
        self.y = ny
      end
    elseif self.rising then
      if self.openT > 0 then
        self.y = self.y + math.sin(G.time * 18) * 0.4   -- straining
      else
        self.y = U.approach(self.y, self.railY, ARCH.DIVE_RISE * dt)
        if math.abs(self.y - self.railY) < 2 then
          self.y = self.railY
          self.rising = nil
          self:setState("ride", 1.6)
        end
      end
    end
    if self.openT > 0 then self.openT = self.openT - dt end
    return
  end

  local p = World:nearestPlayer(self:center())

  -- RIME: it ices the floor beneath itself. This is the attack; the
  -- crates and the beam are only what keeps you honest while you deal
  -- with it.
  self.rimeT = self.rimeT - dt
  if self.rimeT <= 0 then
    self.rimeT = ARCH.RIME_CD / frenzy
    local x0, x1 = self:span(World)
    local n = Cold.frostSeed(World, x0, x1)
    if n > 0 then
      World:fx("burst", self.x + self.w / 2, self.y + self.h + 10,
        { color = "ice", n = 10, speed = 70 })
      if G.Audio then G.Audio.sfx("crack") end
    end
  end

  -- REDACT: a platform is erased for a few seconds, including one you
  -- are standing on. It is an archive; deleting things is what it does.
  self.redactT = self.redactT - dt
  if self.redactT <= 0 then
    self.redactT = ARCH.REDACT_CD
    local best
    for _, e in ipairs(World.entities) do
      if e.kind == "plat" and not e.redacted then
        if not best or (p and math.abs(e.x - p.x) < math.abs(best.x - p.x)) then
          best = e
        end
      end
    end
    if best then
      best.redacted = ARCH.REDACT_T
      World:fx("burst", best.x + (best.w or 16) / 2, best.y,
        { color = "cyan", n = 10 })
      if G.Audio then G.Audio.sfx("linkcharge") end
    end
  end

  if self.state == "ride" then
    if p then
      local tx = U.clamp(p.x + p.w / 2 - self.w / 2, minX, maxX)
      tx = U.clamp(self:workableX(World, tx), minX, maxX)
      self.x = U.approach(self.x, tx, ARCH.RAIL_SPD * frenzy * dt)
    end
    self.y = self.railY + math.sin(self.t * 2) * 3
    if self.stateT <= 0 then
      self:setState(U.chance(0.5) and "sweep" or "barrage", 2.2)
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
          and math.abs(pl.x + pl.w / 2 - self.beamX) < ARCH.BEAM_HALFW then
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
          if not blocked then
            -- ENCASED, not merely hurt. And standing next to a fire does
            -- not save you -- it just means you get thrown off it first.
            local warm = Cold.heatAt(World, pl.x + pl.w / 2,
                                     pl.y + pl.h / 2) ~= nil
            pl:takeDamage(ARCH.BEAM_DMG, self.x)
            pl:encase(World, self.beamX, warm)
          end
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
        side = "enemy", dmg = ARCH.LOB_DMG, kind = "orb", size = 6,
        vx = U.clamp(dx * 1.0, -150, 150), vy = 40,
        gravity = 320, life = 3,
      })
      if G.Audio then G.Audio.sfx("shoot2") end
    end
    if self.stateT <= 0 then self:setState("ride", 2 / frenzy) end
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
  -- THE PLATING, open. `reshelve` was deleted in the refit and this
  -- still keyed on it, so the one piece of art that tells you the boss
  -- is vulnerable had not drawn since.
  if (self.openT or 0) > 0 then
    local pulse = 0.6 + math.sin(G.time * 8) * 0.3
    g.setColor(P.gold[1], P.gold[2], P.gold[3], pulse)
    g.rectangle("fill", cx - 10, self.y + self.h - 8, 20, 8)
    g.setColor(P.ice)
    g.rectangle("line", cx - 10, self.y + self.h - 8, 20, 8)
  end

  -- THE BEAM. It comes out of the machine and it stops at the floor --
  -- it used to be drawn from y=0 to y=4096, a column across the whole
  -- screen with no source and no end. And it is drawn at the width it
  -- actually hits at: the art was 8px of telegraph and 5px of beam
  -- against a hitbox of BEAM_HALFW, so it caught you well outside
  -- anything you could see.
  if self.state == "sweep" and self.beamX then
    local World = require "src.world"
    local top = self.y + self.h - 2
    local row = (World.frost and World.frost.row)
      or (World.room and World.room.frostRow) or (World.h - 6)
    local bottom = (row + 1) * T
    local hw = ARCH.BEAM_HALFW
    if not self.beamFired then
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.22 + math.sin(G.time * 14) * 0.12)
      g.rectangle("fill", self.beamX - hw, top, hw * 2, bottom - top)
      -- the edges, so the width it will hit at is legible
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.7)
      g.rectangle("fill", self.beamX - hw, top, 1, bottom - top)
      g.rectangle("fill", self.beamX + hw - 1, top, 1, bottom - top)
    else
      g.setColor(P.white[1], P.white[2], P.white[3], 0.85)
      g.rectangle("fill", self.beamX - hw, top, hw * 2, bottom - top)
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.9)
      g.rectangle("fill", self.beamX - hw - 2, top, 2, bottom - top)
      g.rectangle("fill", self.beamX + hw, top, 2, bottom - top)
      -- where it lands
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.5)
      g.ellipse("fill", self.beamX, bottom, hw + 6, 4)
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
    self:addSpawn(Entity.make("keeperbrassa", self.x - 60, self.y - 10))
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
-- EIGHT (VESSEL-8) -- The Scrapyard
-- ==================================================================
-- The unit immediately before Vess. The last one that worked, because it
-- was the one that did the work. Three orders that cannot all be obeyed:
-- dismantle every VESSEL unit, maintain the Emberdark, never leave this
-- room. It dismantled its siblings, filed them, and stayed -- waiting on
-- the last name on the list, which is itself.
--
-- The fight teaches, in order: the plate exists (phase 1), a charge
-- bounces (phase 2), and you cannot go THROUGH a body, only over it
-- (phase 3). Its box is 22 wide precisely so Player:tryVault can clear it.
local V8_W, V8_H = 22, 30
local V8_P2 = 0.66            -- health fractions where the fight changes
local V8_P3 = 0.33
local V8_LAST = 0.15
local V8_WALK = 42            -- phase-3 advance, plate up
local V8_TURN = 1.4           -- commitment to a reversal: longer than a dash
local V8_CHARGE = 250
local V8_CHARGE_MAX = 1.5     -- per leg, before it gives up and recovers
local V8_STAGGER = 3.0        -- the wall-bounce window
local V8_TELE = 0.7
local V8_FLAK_GAP = 4.0       -- punishes a lazy vault
local V8_DART_GAP = 3.2       -- anti-dome pressure, only at a live dome

local Vessel8 = Boss.extend()
function Vessel8:init(x, y)
  Boss.init(self, x, y, { id = "vessel8", name = "EIGHT",
    hp = 190, touchDmg = 4, w = V8_W, h = V8_H, reward = "module:cinderram" })
  self.facing = -1
  self.phase = 1
  self.turnT = 0
  self.wantFace = -1
  self.legs = 0               -- charge legs used this telegraph
  self.flakT = V8_FLAK_GAP
  self.dartT = V8_DART_GAP
  self.barkT = 8
  self.barked = {}
end

-- It never leaves the room. If a charge would carry it into a door it
-- stops short and turns around -- visible mid-fight, and the whole
-- character.
function Vessel8:clampToRoom(World)
  local lo, hi = 2 * T, World.w * T - 2 * T - self.w
  if self.x < lo then self.x = lo return -1 end
  if self.x > hi then self.x = hi return 1 end
  return nil
end

-- Point the next leg at whoever is actually there.
--
-- Two things were wrong. A charge that ran out of TIME mid-room never
-- counted as a leg, so the follow-up simply repeated the same heading --
-- two charges in a row at empty floor. And nothing ever re-aimed between
-- legs, so even the wall-bounce return was blind. EIGHT is a gunner that
-- has had a century to practise; it should look before it commits.
--
-- The one thing it will not do is turn INTO the wall it is already
-- standing against: if the player has slipped behind it at the very edge,
-- the bounce heading stands and it takes the long way round.
function Vessel8:aimCharge(World)
  local p = World:nearestPlayer(self:center())
  if not p then return end
  local want = U.sign((p.x + p.w / 2) - (self.x + self.w / 2))
  if want == 0 then return end
  local lo, hi = 2 * T, World.w * T - 2 * T - self.w
  if want < 0 and self.x <= lo + 2 then return end
  if want > 0 and self.x >= hi - 2 then return end
  self.facing = want
end

function Vessel8:bark(key, text)
  if self.barked[key] then return end
  self.barked[key] = true
  if G.game then G.game:announce(text, 2.4) end
end

function Vessel8:enterPhase(n)
  self.phase = n
  Cam.shake(4, 0.5)
  if G.Audio then G.Audio.sfx("roar") end
  if n == 2 then
    self:bark("p2", "YOU ARE NOT REGISTERED. THERE IS NO VESSEL-9!")
    self:setState("tele", V8_TELE)
  elseif n == 3 then
    self:bark("p3", "I WAS TOLD THE SCRAP NEEDED KEEPING. I KEPT IT.")
    self:setState("wall", 6)
  elseif n == 4 then
    self:bark("p4", "IT IS MAINTAINED. IT IS MAINTAINED. IT IS--")
    self:setState("tele", 0.35)
  end
end

-- Phase 3: the plate is up and pointed at you. Frontal fire sparks off.
function Vessel8:plateLive()
  return self.phase >= 3 and self.state == "wall"
end

function Vessel8:update(dt)
  local World = require "src.world"
  self.t = self.t + dt
  self.stateT = self.stateT - dt
  self.vy = math.min((self.vy or 0) + 700 * dt, 280)

  if self.state == "intro" then
    PH.move(self, 0, self.vy * dt)
    if self.stateT <= 0 then self:setState("gun", 2.4) end
    return
  end

  -- phase gates: one-way doors, checked before any state runs
  local frac = self.hp / self.maxhp
  if self.phase == 1 and frac <= V8_P2 then self:enterPhase(2) return end
  if self.phase == 2 and frac <= V8_P3 then self:enterPhase(3) return end
  if self.phase == 3 and frac <= V8_LAST then self:enterPhase(4) return end

  local p = World:nearestPlayer(self:center())
  local cx, cy = self:center()

  -- ---- anti-dome pressure. Only ever aimed at a dome that is actually
  -- up, so a solo run (nobody holding one) never sees darts and eats
  -- ordinary gunfire instead -- which is dodgeable alone.
  if self.phase >= 3 then
    self.dartT = self.dartT - dt
    if self.dartT <= 0 then
      local domed
      for _, pl in ipairs(World.players) do
        if pl.domeActive and not pl.dead and not pl.downed then domed = pl break end
      end
      if domed then
        self.dartT = V8_DART_GAP
        for i = 0, 2 do
          Proj.energyDart(World, cx, cy - 4,
            domed.x + domed.w / 2 + U.rand(-6, 6), domed.y + domed.h / 2,
            { speed = 430 + i * 20, drain = 8, dmg = 3 })
        end
        if G.Audio then G.Audio.sfx("shoot2") end
      else
        self.dartT = 0.8
      end
    end
  end

  -- ---- upward flak: vaulting must not be free
  if self.phase >= 3 then
    self.flakT = self.flakT - dt
    if self.flakT <= 0 then
      self.flakT = V8_FLAK_GAP
      local airborne
      for _, pl in ipairs(World.players) do
        if not pl.dead and not pl.downed and not pl.onGround then airborne = pl break end
      end
      if airborne then
        for i = -1, 1 do
          self:fireAt(cx, self.y - 2, cx + i * 26, self.y - 60, 300,
            { dmg = 4, kind = "spark", size = 5, life = 1.4 })
        end
        if G.Audio then G.Audio.sfx("shoot1") end
      else
        self.flakT = 1.2
      end
    end
  end

  if self.state == "gun" then
    -- PHASE 1: it mirrors your Arc Lance, and it uses the plate to
    -- reposition -- you watch it work before you are allowed one.
    if p then
      local s = U.sign((p.x + p.w / 2) - cx)
      if s ~= 0 then self.facing = s end
      local d = math.abs(p.x - self.x)
      self.vx = self.facing * (d > 110 and 46 or (d < 44 and -46 or 0))
    end
    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    self:clampToRoom(World)
    self.gap = (self.gap or 0.5) - dt
    if self.gap <= 0 and p then
      self.gap = 0.9
      self.burst = 3
    end
    if (self.burst or 0) > 0 then
      self.bgap = (self.bgap or 0) - dt
      if self.bgap <= 0 and p then
        self.bgap = 0.12
        self.burst = self.burst - 1
        -- leads the target, like a gunner who has had a century to practise
        local lx = p.x + p.w / 2 + (p.vx or 0) * 0.18
        self:fireAt(cx + self.facing * 10, cy - 4, lx, p.y + p.h / 2, 330,
          { dmg = 4, kind = "bolt", size = 5, life = 2.2 })
        if G.Audio then G.Audio.sfx("shoot1") end
      end
    end
    if self.stateT <= 0 then
      if self.phase >= 2 then self:setState("tele", V8_TELE)
      else self:setState("dashmove", 0.5) end
    end

  elseif self.state == "dashmove" then
    -- a plated reposition: protected, harmless. The demonstration.
    self.vx = self.facing * 200
    PH.move(self, self.vx * dt, self.vy * dt)
    World:fx("trail", cx, cy, { color = "vessdark", r = 3, t = 0.18 })
    if self:clampToRoom(World) or self.hitWall then
      self.facing = -self.facing
      self:setState("gun", 2.6)
    elseif self.stateT <= 0 then
      self:setState("gun", 2.6)
    end

  elseif self.state == "tele" then
    -- plant, ignite the chevrons, commit
    self.vx = U.approach(self.vx or 0, 0, 900 * dt)
    PH.move(self, self.vx * dt, self.vy * dt)
    if p then
      local s = U.sign((p.x + p.w / 2) - cx)
      if s ~= 0 then self.facing = s end
      -- if you are in the air when it plants, it shoots you instead
      if not p.onGround and not self.shotUp and self.stateT < 0.2 then
        self.shotUp = true
        self:fireAt(cx, self.y - 2, p.x + p.w / 2, p.y + p.h / 2, 320,
          { dmg = 4, kind = "spark", size = 5, life = 1.6 })
      end
    end
    if self.stateT <= 0 then
      self.shotUp = nil
      self.legs = 0
      self:setState("charge", V8_CHARGE_MAX)
      if G.Audio then G.Audio.sfx("ram") end
    end

  elseif self.state == "charge" then
    self.vx = self.facing * V8_CHARGE
    PH.move(self, self.vx * dt, self.vy * dt)
    World:fx("trail", cx, cy, { color = "magma", r = 3.5, t = 0.2 })
    local edge = self:clampToRoom(World)
    local hitWall = edge or self.hitWall
    local spent = hitWall or self.stateT <= 0
    if spent then
      -- EVERY completed leg counts, whether it ended against the wall or
      -- simply ran out of road. Only counting wall hits let a charge that
      -- timed out mid-room repeat itself for free.
      self.legs = self.legs + 1
      if hitWall then
        -- it hit the wall. Same rule it lives by.
        self.facing = -self.facing
        Cam.shake(3.5, 0.3)
        World:fx("burst", cx, cy, { color = "slate", n = 16, speed = 180 })
        if G.Audio then G.Audio.sfx("impact") end
      end
      if self.phase >= 4 then
        -- desperation: wall to wall, no gap. It does not aim any more.
        self:setState("charge", V8_CHARGE_MAX)
      elseif self.legs >= 2 then
        self:setState("stagger", V8_STAGGER)
      else
        self:setState("stagger", V8_STAGGER * (hitWall and 0.5 or 0.7))
      end
    end

  elseif self.state == "stagger" then
    -- the damage window, and it is the same one the rammer taught you
    self.vx = U.approach(self.vx or 0, 0, 600 * dt)
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.stateT <= 0 then
      if self.phase >= 4 then
        self:aimCharge(World)
        self:setState("charge", V8_CHARGE_MAX)
      elseif self.legs >= 2 then
        if self.phase >= 3 then self:setState("wall", 6)
        else self:setState("gun", 2.6) end
      else
        -- second leg: look first
        self:aimCharge(World)
        self:setState("charge", V8_CHARGE_MAX)
        if G.Audio then G.Audio.sfx("ram") end
      end
    end

  elseif self.state == "wall" then
    -- PHASE 3. Plate up, walking, firing. There is no way through it;
    -- there is only over it.
    if p then
      local want = U.sign((p.x + p.w / 2) - cx)
      if want ~= 0 and want ~= self.wantFace then
        self.wantFace = want
        self.turnT = V8_TURN
      end
    end
    if self.turnT > 0 then
      self.turnT = self.turnT - dt
      self.vx = 0
      if self.turnT <= 0 then self.facing = self.wantFace end
    else
      self.vx = self.facing * V8_WALK
    end
    PH.move(self, self.vx * dt, self.vy * dt)
    self:clampToRoom(World)
    self.gap = (self.gap or 1) - dt
    if self.gap <= 0 and p and self.turnT <= 0 then
      self.gap = 1.0
      self:fireAt(cx + self.facing * 11, cy - 2,
        p.x + p.w / 2, p.y + p.h / 2, 300,
        { dmg = 4, kind = "bolt", size = 5, life = 2.2 })
      if G.Audio then G.Audio.sfx("shoot1") end
    end
    if self.stateT <= 0 then self:setState("tele", V8_TELE) end
  end

  self.barkT = self.barkT - dt
  if self.barkT <= 0 then
    self.barkT = 20
    self:bark("p1", "YOU'RE THE NEW ONE.")
  end
end

-- The plate is a plate. Frontal fire sparks off it, and only in the wall
-- phase -- everywhere else EIGHT is an honest target.
function Vessel8:deflects(srcx, srcy, opts)
  if opts and opts.link then return false end
  if not self:plateLive() or self.turnT > 0 then return false end
  local ax = srcx
  if opts and opts.owner then ax = opts.owner.x + opts.owner.w / 2 end
  local side = ax and U.sign(ax - (self.x + self.w / 2)) or self.facing
  return side == self.facing or side == 0
end
function Vessel8:hurt(dmg, srcx, srcy, opts)
  if self:deflects(srcx, srcy, opts) then
    local World = require "src.world"
    World:fx("spark", self.x + self.w / 2 + self.facing * 13, self.y + 12,
      { color = "silver", n = 4 })
    if G.Audio then G.Audio.sfx("crack") end
    return false
  end
  return Entity.hurt(self, dmg, srcx, srcy, opts)
end

function Vessel8:onDeath()
  Boss.onDeath(self)
  if G.game then
    G.game:startDialogue({
      { who = "lu", text = "All the others were dismantled. What does that make us?" },
      { who = "vess", text = "..." },
    })
  end
end

function Vessel8:draw()
  local g = love.graphics
  local cx, cy = self:center()
  G.drawSprite("boss_vessel8", math.floor(self.t * 4) % 2 + 1,
    self.x + self.w / 2, self.y + self.h + 0.5,
    { flip = self.facing < 0, white = math.max(0, (self.white or 0) * 6) })

  -- the one eye
  local eyeX = self.x + self.w / 2 + self.facing * 4
  g.setColor(P.blood[1], P.blood[2], P.blood[3], 0.6 + math.sin(G.time * 3) * 0.3)
  g.circle("fill", eyeX, self.y + 8, 2)
  g.setColor(P.cream)
  g.circle("fill", eyeX, self.y + 8, 0.9)

  -- the plate, in the wall phase
  if self:plateLive() then
    g.push() g.translate(cx, cy) g.scale(self.facing, 1)
    local turning = self.turnT > 0
    g.setColor(P.gray[1], P.gray[2], P.gray[3], turning and 0.5 or 0.95)
    g.polygon("fill", 6, -14, 13, -11, 13, 11, 6, 14)
    g.setColor(turning and P.gold or P.silver)
    g.line(13, -11, 13, 11)
    g.pop()
    if turning then
      g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.4 + 0.4 * math.sin(G.time * 16))
      g.circle("line", cx, self.y - 6, 3.5)
    end
  end

  -- chevrons while it commits to a charge
  if self.state == "tele" or self.state == "charge" then
    local ig = self.state == "charge" and 1
      or (1 - math.max(0, self.stateT) / V8_TELE)
    local strobe = 0.6 + 0.4 * math.sin(G.time * 30)
    g.push() g.translate(cx, cy) g.scale(self.facing, 1)
    local cols = { P.magma, P.hotcore, P.cream }
    for i = 1, 3 do
      local ox = 6 + i * 5
      local c = cols[i]
      g.setColor(c[1], c[2], c[3], ig * strobe * (1 - (i - 1) * 0.22))
      g.setLineWidth(2)
      g.line(ox - 4, -8, ox, 0, ox - 4, 8)
      g.setLineWidth(1)
    end
    g.pop()
  end
  g.setColor(1, 1, 1, 1)
end
Bosses.vessel8 = Vessel8

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
  -- EIGHT starts on the far side of its room, between you and nothing
  vessel8 = function(World) return World.w * T - 110, World.h * T - 96 end,
  -- The camera clamps at roomH - VH = 82 in a 22-row arena, so anything
  -- above y=82 is off-screen while you are standing on the floor. The
  -- rail was at 44: you fought a boss you could not see.
  archivist = function(World) return World.w * T / 2 - 20, 100 end,
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
  vessel8 = "VESSEL-8 dismantled the others and protected the scrap. On whose orders? Why?",
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
    G.Audio.playMusic(id == "motherengine" and "finalboss"
      or id == "vessel8" and "vessel8" or "boss")
  end
  if G.game then
    G.game:announce("-- " .. b.bossName .. " --", 2.5)
    if EPITAPH[id] then G.game:announce(EPITAPH[id], 3) end
  end
  return b
end

return Bosses
