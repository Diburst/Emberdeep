-- All standard enemy types. Each registers as an entity spawnable from maps.
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"
local Proj = require "src.entities.projectile"
local Pickup = require "src.entities.pickup"
local Cam = require "src.camera"

local T = 16
local Enemy = Entity.extend()

-- ==================================================================
-- THE ENERGY ECONOMY  (COOP-PLAN 2, 7.3, 8.2)
-- ==================================================================
-- Lu's dome is the co-op verb, and its bar no longer fills itself:
-- player.lua regenerates her to a reserve and no further. Everything
-- above that has to be picked up, which makes "how much energy is in
-- this room" a LEVEL DESIGN number rather than a global constant.
--
-- So it is set PER SPAWN, not per type. `drops` used to live on the type
-- alone, so a scraphusk was worth exactly the same wherever it stood --
-- and the only lever for "this corridor is starving Lu" was to retune
-- every scraphusk in the game and hope nothing else broke. A room can
-- now say what its own fight is worth:
--
--     ["h"] = "scraphusk"                    -- the type's default
--     ["H"] = "scraphusk:energy=6"           -- a generous one
--     ["k"] = "rollpede:energy=0:shards=0"   -- scenery that pays nothing
--
-- Any drop key may be overridden. An unknown one is an ERROR rather than
-- a shrug: silently ignoring a spec you meant to matter is this
-- project's single most expensive bug class, and it has cost a
-- playthrough three separate times.
--
-- checkenergy.py audits the totals per room, which is the entire reason
-- for making this a per-spawn number in the first place.
Enemy.ENERGY_PER_SHARD = 1   -- default mote count: matches the shard count
Enemy.DROP_KEYS = { shards = true, energy = true, heart = true,
                    scrap = true, big = true }

-- PER-SPAWN PROPERTIES OF THE BODY, as opposed to of its drops. Same
-- `key=number` grammar and the same hard error on a typo, because the
-- reason that error exists -- "silently ignoring a spec you meant to
-- matter is this project's single most expensive bug class" -- is
-- exactly as true here.
--
--     ["c"] = "dragger:rail=-1"     -- its rail runs left
--     ["C"] = "dragger:rail=1"      -- ...and this one runs right
Enemy.SPAWN_KEYS = { rail = true }
function Enemy.spawnKeyList()
  local out = {}
  for k in pairs(Enemy.SPAWN_KEYS) do out[#out + 1] = k end
  table.sort(out)
  return out
end

-- ==================================================================
-- ZONE SCALING
-- ==================================================================
-- "Increase the health and damage of all minor enemies in every zone
-- EXCEPT Moss and Sky by approximately 25%" (Thomas, Aug 2026).
--
-- WHY THIS IS A MULTIPLIER AND NOT TWENTY EDITED NUMBERS.
--
-- An enemy's stats belong to its TYPE, and three types cross the line
-- the request draws: the cinderbat flies in the Furnace AND the
-- Skyroot, the rollpede crawls through Mosswood AND the Scrapyard, and
-- the sporefly is in the Skyroot AND the Undergrove. Editing `hp = 3`
-- to `hp = 4` buffs the Skyroot cinderbat too -- exactly the zone the
-- instruction excludes -- and there is no number you can write in that
-- table that says "but not over there".
--
-- Read at SPAWN, against the room the body is standing in, and the
-- conflict disappears: the same cinderbat is a 3hp bat in the Skyroot
-- and a 4hp bat in the Furnace, because it is the ROOM that is meant to
-- be harder, not the animal.
--
-- The exceptions are named, so a zone added later is scaled by default.
-- That is the direction the instruction points -- "every zone except
-- these two" -- and it is the direction a mistake is cheapest in: a new
-- zone that comes out tuned hot gets played and reported, one that
-- silently opts out of the difficulty curve does not.
Enemy.ZONE_SCALE = { mosswood = 1, skyroot = 1 }
Enemy.ZONE_SCALE_DEFAULT = 1.25

-- Not every body in this file is a minor enemy. Brassa in the Reckoning
-- is a 45hp scripted duel with its own pacing; scaling her with the
-- trash would retune a set-piece nobody asked about.
Enemy.SCALE_EXEMPT = { keeperbrassa = true }

function Enemy.zoneScale(typeName)
  if typeName and Enemy.SCALE_EXEMPT[typeName] then return 1 end
  local World = require "src.world"
  local zone = World.room and World.room.zone
  return (zone and Enemy.ZONE_SCALE[zone]) or Enemy.ZONE_SCALE_DEFAULT
end

-- ONE DOOR FOR EVERY ROUND AN ENEMY FIRES.
--
-- Contact damage is one field and scales itself; a spitter's gob, a
-- cryoturret's bolt and a stormvane's arc are fourteen separate
-- `Proj.spawn` calls scattered through this file, and "add the
-- multiplier to thirteen of them" is precisely the hand-written list
-- this project keeps getting wrong. The player side already learned it
-- -- tools/shoot_test.lua fails the build if Player:updateFire contains
-- a bare Proj.spawn -- so enemies get the same door and the same check.
function Enemy:shoot(World, x, y, cfg)
  cfg.dmg = math.floor((cfg.dmg or 0) * (self.dmgMult or 1) + 0.5)
  return Proj.spawn(World, x, y, cfg)
end

function Enemy:init(x, y, def, parts)
  Entity.init(self, x, y)
  self.kind = "enemy"
  local hpMult = ({ 0.75, 1, 1.3 })[G.run and G.run.difficulty or 2] or 1
  -- COMPOSES with difficulty rather than replacing it: the zone says how
  -- hard this stretch of the game is, the difficulty says how hard the
  -- player asked for the whole of it to be, and both are true at once.
  local zs = Enemy.zoneScale(def.typeName)
  self.zoneScale = zs
  self.dmgMult = zs
  self.maxhp = math.max(1, math.floor((def.hp or 3) * hpMult * zs + 0.5))
  self.hp = self.maxhp
  -- floor+0.5 rather than ceil, so a body with NO contact damage (the
  -- depthmine, the glowmite) still has none. 0 * anything is 0 and it
  -- must round to 0.
  self.touchDmg = math.floor((def.touchDmg or 2) * zs + 0.5)
  -- COPY before touching. `def.drops` is shared by every instance of
  -- the type, so a per-spawn override that mutated it in place would
  -- silently retune every other one of these in the game.
  local base = def.drops or { shards = 2, heart = 0.12, scrap = 0.08 }
  local d = {}
  for k, v in pairs(base) do d[k] = v end
  if d.energy == nil then
    d.energy = (d.shards or 0) * Enemy.ENERGY_PER_SHARD
  end
  for i = 2, #(parts or {}) do
    local key, val = tostring(parts[i]):match("^(%a+)=(%-?[%d%.]+)$")
    if key and Enemy.SPAWN_KEYS[key] then
      -- not a drop: a per-spawn property of the body itself, in the same
      -- key=number grammar so a typo is still an error rather than a shrug
      self[key] = tonumber(val)
    elseif not key or not Enemy.DROP_KEYS[key] then
      error(("enemy spawn '%s': bad override %q -- expected a drop "
        .. "(shards, energy, heart, scrap, big) or a spawn property "
        .. "(%s), as key=number")
        :format(tostring(parts[1]), tostring(parts[i]),
          table.concat(Enemy.spawnKeyList(), ", ")))
    else
      d[key] = tonumber(val)
    end
  end
  self.drops = d
  self.sprite = def.sprite
  self.animRate = def.animRate or 4
  self.w = def.w or 12
  self.h = def.h or 12
  self.facing = U.chance(0.5) and 1 or -1
  self.t = U.rand(0, 3)
  self.buffed = 0
  -- How a body answers a plated charge (see Player:dashImpact):
  --   "light" -- concussed and thrown  (the default, deliberately)
  --   "heavy" -- shrugs it off, small shove, Vess still bounces
  --   "fixed" -- bolted down; Vess bounces off it exactly like a wall
  -- Defaulting to light is the safe way round: a tag we forgot makes
  -- something more fun to hit, not a mini-boss we accidentally trivialised.
  self.mass = def.mass or (def.heavy and "heavy") or "light"
  self.stunT = 0
  -- Ordinary enemies are the ONLY things in the game that may stop
  -- thinking when nobody is near them. See World:asleep for why this is
  -- opt-in rather than opt-out. Boss extends Entity, not Enemy, so it
  -- cannot pick this up by inheritance; if a subclass here ever becomes
  -- something that must keep running off screen, clear it in that
  -- subclass's init.
  self.canSleep = true
end

-- ==================================================================
-- Concussion
-- ==================================================================
-- Set by Player:concuss when a plated charge connects. The important part
-- is that an attack in flight is CANCELLED rather than paused: freezing a
-- state machine mid-swing strands flags, and we have paid for that lesson
-- once already (the Bramble Maw).
function Enemy:stun(dur)
  if self.isBoss or self.stunImmune or self.dead then return false end
  self.stunT = math.max(self.stunT or 0, dur)
  if self.onStunned then self:onStunned() end
  if G.Audio then G.Audio.sfx("concuss") end
  return true
end

function Enemy:drawStun()
  local g = love.graphics
  local cx, cy = self:center()
  for i = 1, 3 do
    local a = G.time * 5 + i * math.pi * 2 / 3
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.55 + 0.35 * math.sin(G.time * 9 + i))
    g.circle("fill", cx + math.cos(a) * 8, cy - self.h / 2 - 3 + math.sin(a) * 2.5, 1.4)
  end
  g.setColor(1, 1, 1, 1)
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
  -- Lu's half of the kill. A SEPARATE mote rather than a share of the
  -- shard count, so scrap and dome energy can be tuned independently --
  -- they are different economies and one number would weld them
  -- together, which is exactly what 8.2 split apart.
  local en = math.floor(d.energy or 0)
  if en > 0 then Pickup.drop(World, cx, cy, "energy", en) end
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

-- ==================================================================
-- HUNTING: CLOSE, CONNECT, GET OUT
-- ==================================================================
-- The behaviour a boss's swarm has, as opposed to the behaviour a body
-- hung in a room has. A roosting flier bobs in place until something
-- walks within 120px of it and then swoops; in a ten-tile arena that
-- 120px never happens and the swarm decorates the ceiling. A HUNTER
-- comes for you.
--
-- Three parts, and all three are load-bearing:
--
--   CLOSE   straight at the nearest player, with the wobble on the
--           HEADING rather than on the velocity. A sine added to vy
--           cancels itself over a second and the body never descends,
--           which is the shape of the original bug.
--   STRIKE  it watches for the overlap ITSELF. Contact damage is applied
--           by the player walking its own list of overlapping bodies, so
--           nothing tells the hunter it connected. A pass eaten by
--           i-frames still counts: it touched, it should get out, and a
--           body sitting inside an invulnerable player waiting for the
--           frames to lapse is exactly the grinder this prevents.
--   RETREAT away -- randomly away, never back through the body it just
--           hit -- for one to two seconds, faster than it closes. This
--           is what turns a swarm into a rhythm of passes.
--
-- It lives HERE, on Enemy, because two different swarms want it now: the
-- Slag Golem's cinderbats and the Bramble Maw's gnats. Written twice it
-- would be tuned once, and this project has three post-mortems about a
-- second hand-written copy of something that was already published.
--
-- Speeds are per-body (`huntSpeed`, `retreatSpeed`) so a gnat can be a
-- gnat, and the defaults are the bat's -- the numbers this was tuned to.
Enemy.HUNT_SPEED   = 96
Enemy.HUNT_RETREAT = 118      -- faster than it closes: it flees
Enemy.HUNT_SPRAY   = 0.9      -- radians of slop either side of "away"
Enemy.HUNT_BACK_MIN = 1.0
Enemy.HUNT_BACK_MAX = 2.0
Enemy.HUNT_WOBBLE  = 0.35     -- radians of weave on the approach heading

-- Returns true if it handled the frame -- i.e. the caller should stop.
function Enemy:huntStep(dt)
  local World = require "src.world"
  if (self.retreatT or 0) > 0 then
    self.retreatT = self.retreatT - dt
    local sp = (self.retreatSpeed or Enemy.HUNT_RETREAT) * self:speedMult()
    self.vx = math.cos(self.retreatA) * sp
    self.vy = math.sin(self.retreatA) * sp
    self.facing = self.vx > 0 and 1 or -1
    PH.move(self, self.vx * dt, self.vy * dt)
    -- a corner would otherwise hold it there for the whole retreat
    if self.hitWall or self.hitCeil or self.onGround then
      self.retreatA = self.retreatA + math.pi * 0.5
    end
    return true
  end
  local p = World:nearestPlayer(self:center())
  if p then
    local cx, cy = self:center()
    local px, py = p:center()
    local ang = math.atan2(py - cy, px - cx)
    local sp = (self.huntSpeed or Enemy.HUNT_SPEED) * self:speedMult()
    local wob = math.sin(self.t * 5) * Enemy.HUNT_WOBBLE
    self.vx = math.cos(ang + wob) * sp
    self.vy = math.sin(ang + wob) * sp
    self.facing = self.vx > 0 and 1 or -1
  end
  PH.move(self, (self.vx or 0) * dt, (self.vy or 0) * dt)
  if self.hitWall then self.facing = -self.hitWall end
  for _, q in ipairs(World:alivePlayers()) do
    if not q.idle and not q.downed
      and U.aabb(self.x, self.y, self.w, self.h, q.x, q.y, q.w, q.h) then
      local cx, cy = self:center()
      local qx, qy = q:center()
      local away = math.atan2(cy - qy, cx - qx)
      self.retreatA = away + U.rand(-Enemy.HUNT_SPRAY, Enemy.HUNT_SPRAY)
      self.retreatT = U.rand(Enemy.HUNT_BACK_MIN, Enemy.HUNT_BACK_MAX)
      break
    end
  end
  return true
end

-- EVERY ENEMY TYPE, IN DECLARATION ORDER. The room editor needs a list
-- of what it may place, and the alternative was for it to keep its own
-- -- which is the copied-constant failure this project has three
-- post-mortems about. reg() is the only way an enemy comes into
-- existence, so this cannot go stale.
Enemy.TYPES = {}

local function reg(name, def, updateFn, drawFn)
  -- the type needs to know its own name by the time a body is built:
  -- Enemy:init reads it for SCALE_EXEMPT, and `parts` cannot be trusted
  -- for it (a boss add is made with no parts at all).
  def.typeName = name
  local C = Enemy.extend()
  C.init = function(self, x, y, parts)
    Enemy.init(self, x, y, def, parts)
    if def.init then def.init(self) end
  end
  C.update = function(self, dt)
    self.t = self.t + dt
    if self.buffed > 0 then self.buffed = self.buffed - dt end
    -- Concussed: the type's own update does not run at all. Gravity and
    -- movement still do, so a stunned flier falls -- which is the fun of
    -- it. Contact damage is suppressed player-side, so you can stand on
    -- one safely. One hook, thirty enemies, no per-type edits.
    if (self.stunT or 0) > 0 then
      self.stunT = self.stunT - dt
      self.vx = U.approach(self.vx or 0, 0, 320 * dt)
      self.vy = math.min((self.vy or 0) + 830 * dt, 300)
      PH.move(self, self.vx * dt, self.vy * dt)
      return
    end
    updateFn(self, dt)
  end
  local baseDraw = drawFn or Enemy.draw
  C.draw = function(self)
    baseDraw(self)
    if (self.stunT or 0) > 0 then Enemy.drawStun(self) end
  end
  if def.onDeathExtra then
    local base = Enemy.onDeath
    C.onDeath = function(self)
      base(self)
      def.onDeathExtra(self)
    end
  end
  -- parts reaches the constructor now: it is what carries a room's
  -- per-spawn drop tuning. It used to be dropped on the floor here.
  Enemy.TYPES[#Enemy.TYPES + 1] = name
  Entity.register(name, function(x, y, parts) return C.new(x, y, parts) end)
  return C
end

-- ==================================================================
-- Directional shields
-- ==================================================================
-- A plate that only covers the side it faces. Two things this has to get
-- right, both learned the hard way:
--
--  1. Judge the shot by the SHOOTER, not by where the bullet currently is.
--     A bolt travels 5px a frame and these bodies are 14 wide, so a round
--     blocked on the frame it touches the plate is PAST the midline on the
--     next one -- and then it reads as a hit in the back. That is why
--     small-arms fire was going straight through. (The Rusted Warden
--     already judged by the owner; that is why it never had this bug.)
--
--  2. A blocked shot must DIE. Returning false from hurt only declines the
--     damage; the projectile sails on into the body and tries again next
--     frame. Proj now asks `deflects` first and kills the round there.
--
-- The LINK blast is deliberately NOT stopped: it is the pair's answer to a
-- raised guard, and blocking it would leave a shielded enemy with no
-- counter for a player who has not found the Cinder Ram yet.
local function frontBlocked(self, srcx, srcy, opts)
  if opts and opts.link then return false end
  local ax, ay = srcx, srcy
  if opts and opts.owner then
    ax = opts.owner.x + opts.owner.w / 2
    ay = opts.owner.y + opts.owner.h        -- the shooter's feet
  end
  if not ax then return false end
  if U.sign(ax - (self.x + self.w / 2)) ~= self.facing then return false end
  -- shooting down onto its head gets through: a plate is a plate, not a roof
  if ay and ay < self.y - 2 then return false end
  return true
end

-- THE SHELL. Plated everywhere except the belly.
--
-- Where frontBlocked asks where a shot came FROM, this asks which way it
-- was GOING. "Shot from underneath" is a round still travelling upward
-- when it lands -- which is exactly the motion the player makes when
-- they stand under the thing and aim up, and is true whether the ledge
-- above them is one tile high or four. Deriving it from the shooter's
-- position instead turns the rule into a question about floor heights
-- that nothing on screen answers.
--
-- Melee and anything else with no round behind it falls back to
-- geometry: the attacker's head has to be below the belly line. And an
-- unattributed hit -- a script, a harness, something new -- always
-- lands, the same defensive default frontBlocked takes. An enemy that
-- is invulnerable because a caller forgot an argument is worse than one
-- that is too easy.
local SHELL_UP = -20      -- px/s of upward travel that counts as "from below"
local function shellBlocked(self, srcx, srcy, opts)
  if opts and opts.link then return false end     -- the link always lands
  if opts and opts.vy then return opts.vy > SHELL_UP end
  local ay = opts and opts.owner and opts.owner.y or srcy
  if not ay then return false end
  return ay < self.y + self.h
end

local function shieldSpark(self)
  local World = require "src.world"
  World:fx("spark", self.x + self.w / 2 + self.facing * 10, self.y + 6,
    { color = "gold", n = 4 })
  if G.Audio then G.Audio.sfx("deflect") end
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
    -- A GNAT OFF THE MAW IS NOT A GNAT IN A ROOM.
    --
    -- The default below is the Mosswood ambient: drift on a sine, and
    -- close only if somebody wanders within 90px. That is right for a
    -- body hung in a corridor and useless for a swarm spat into a boss
    -- arena, which has to arrive. Same flag, same behaviour, same
    -- constants as the golem's bats -- see Enemy:huntStep.
    if self.hunt then return self:huntStep(dt) end
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
        self:shoot(World, cx, cy, {
          side = "enemy", dmg = 2, kind = "orb", size = 5,
          vx = U.clamp(dx * 1.2, -110, 110), vy = -170,
          gravity = 300, life = 2.5,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("rollpede", { mass = "heavy", hp = 6, touchDmg = 3, sprite = "en_rollpede", w = 14, h = 10,
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
    -- The surface is a ceiling, not a cage. The old code reverted the
    -- WHOLE move whenever the destination was not water and flipped vx
    -- every single frame, so any finfish that was not fully submerged
    -- vibrated on the spot forever. Steer it back down instead.
    if not self.inWater then
      self.vy = math.max(self.vy or 0, 34)
    end
    self.facing = (self.vx or 1) >= 0 and 1 or -1
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then
      self.vx = -math.abs(self.vx or 40) * self.hitWall   -- turn off the wall
      self.facing = self.vx >= 0 and 1 or -1
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
          self:shoot(World, cx, cy - 4, {
            side = "enemy", dmg = 1, kind = "drop", size = 5,
            vx = i * 40, vy = -90, gravity = 60, life = 2.2,
          })
        end
        if G.Audio then G.Audio.sfx("splash") end
      end
    end
  end)

reg("crab", { mass = "heavy", hp = 10, touchDmg = 3, sprite = "en_crab", w = 16, h = 12,
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

reg("depthmine", { mass = "fixed", hp = 3, touchDmg = 0, sprite = "en_depthmine", w = 12, h = 12,
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
        p:takeDamage(3, cx)
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
-- THE SPINESHELL -- the Rusted Warden, in miniature, three rooms early
-- ==================================================================
-- Asked for (Thomas, Aug 2026): "a spiky turtle-like enemy that is immune
-- to small fire (unless shot from underneath) and has a charge attack. If
-- the charge hits a wall or Lu's shield, the enemy is stunned and
-- vulnerable for 5s. This teaches the player the same mechanics used to
-- defeat Rusted Warden, so place this enemy a few times before and after
-- Rusted Warden."
--
-- The last sentence is the design, and it is why every number here is
-- shaped by the Warden's and not chosen fresh:
--
--   THE WARDEN                          THE SPINESHELL
--   shield stops rounds from the front  plates stop rounds everywhere but the belly
--   charges, and commits to it          charges, and commits to it
--   the dome interrupts the charge      the dome interrupts the charge
--   ...and stuns it for 3s              ...and stuns it for 5s
--   a wall ends the charge (recover)    a wall ends the charge (stunned, 5s)
--   the LINK always lands               the LINK always lands
--
-- The two differences are deliberate. The stun is LONGER than the boss's
-- because this is where the lesson is learned and a lesson wants room;
-- and a wall stuns it outright, where the Warden merely recovers,
-- because "bait it into the scenery" has to work before it is worth
-- attempting on something with a health bar. A player who has taken four
-- of these apart walks into the pump hall already knowing the answer.
--
-- It is not the rammer with a shell. The rammer's plate covers its front
-- only WHILE it charges, so its lesson is timing; the spineshell is
-- always armoured, so its lesson is angle -- which is the Warden's.
local SHELL_WALK   = 26     -- px/s patrolling. The player runs at 112.
local SHELL_SEE    = 150    -- px it notices you across
local SHELL_LEVEL  = 26     -- ...and how far above/below it will still commit
local SHELL_TELL   = 0.7    -- seconds of tuck-and-rattle before it goes
local SHELL_CHARGE = 168    -- px/s once it does
local SHELL_RUN    = 1.7    -- seconds the charge lasts if it hits nothing
local SHELL_STUN   = 5.0    -- the reward for making it hit something
local SHELL_REST   = 1.1    -- breath between attempts
local SHELL_DOME_COST = 2   -- energy the bubble pays to stop one, as the
                            -- Warden's charge costs (bosses.lua, "charge")
reg("spineshell", { mass = "heavy", hp = 10, touchDmg = 3,
  sprite = "en_spineshell", w = 16, h = 13,
  drops = { shards = 4, scrap = 0.15 }, deathColor = "deepsea", animRate = 3,
  init = function(self)
    self.sstate = "walk"
    self.st = U.rand(0.6, 1.4)
  end },
  function(self, dt)
    local World = require "src.world"
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    self.st = (self.st or 0) - dt

    if self.sstate == "stunned" then
      -- OPEN. Everything lands, from anywhere -- see the deflects hook
      -- below, which asks this state first.
      self.vx = U.approach(self.vx or 0, 0, 500 * dt)
      PH.move(self, self.vx * dt, self.vy * dt)
      if self.st <= 0 then
        self.sstate = "walk"
        self.st = SHELL_REST
      end
      return
    end

    if self.sstate == "walk" then
      -- A PATROL, not a chase: it is a wall that happens to be walking.
      -- The turn at a ledge is what keeps it on the shelf you have to
      -- get under.
      self:patrol(dt, SHELL_WALK * self:speedMult())
      local p = playerNear(self, SHELL_SEE)
      if p and self.st <= 0 then
        local cx, cy = self:center()
        local px, py = p:center()
        -- only at something it could actually reach by running at it:
        -- a charge at a player two storeys up is a charge into a wall
        -- for no reason, which reads as the thing being broken
        if math.abs(py - cy) <= SHELL_LEVEL then
          local s = U.sign(px - cx)
          if s ~= 0 then self.facing = s end
          self.sstate = "tuck"
          self.st = SHELL_TELL
          self.vx = 0
        end
      end
      return
    end

    if self.sstate == "tuck" then
      -- THE TELL. It stops dead and rattles: every charge in this game
      -- is announced before it commits, and this one is announced for
      -- longer than the Warden's because it is the first one you meet.
      self.vx = U.approach(self.vx or 0, 0, 700 * dt)
      PH.move(self, self.vx * dt, self.vy * dt)
      if self.st <= 0 then
        self.sstate = "charge"
        self.st = SHELL_RUN
        if G.Audio then G.Audio.sfx("ram") end
      end
      return
    end

    -- charging
    self.vx = self.facing * SHELL_CHARGE * self:speedMult()
    World:fx("trail", self.x + self.w / 2, self.y + self.h / 2,
      { color = "deepsea", r = 2.5, t = 0.16 })

    -- LU'S BUBBLE IS A WALL. Same test the Warden's charge answers to
    -- (World:domeCovering), so a player who learns it here has learned it
    -- there -- that is the entire point of this enemy.
    local cx, cy = self:center()
    local domer = World:domeCovering(cx, cy, self.w / 2)
    if domer then
      domer:domeAbsorb(SHELL_DOME_COST)
      self.x = self.x - self.facing * 8
      World:fx("spark", cx - self.facing * self.w / 2, cy,
        { color = "cyan", n = 10 })
      self:shellStun(World, "dome")
      return
    end

    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then
      self:shellStun(World, "wall")
      self.vx = -self.hitWall * 90
      self.vy = -70
      return
    end
    if self.st <= 0 then
      -- ran out of charge without hitting anything: no reward, and it
      -- goes back to being a wall
      self.sstate = "walk"
      self.st = SHELL_REST
    end
  end,
  function(self)
    self:drawSprite()
    local g = love.graphics
    local cx, cy = self:center()
    if self.sstate == "tuck" then
      -- the rattle: spines flare and a chevron builds on the side it is
      -- about to leave from
      local ig = 1 - math.max(0, self.st) / SHELL_TELL
      g.push() g.translate(cx + U.rand(-1, 1), cy) g.scale(self.facing, 1)
      g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.3 + ig * 0.6)
      g.setLineWidth(1.5)
      g.line(5, -5, 9, 0, 5, 5)
      g.setLineWidth(1)
      g.pop()
    elseif self.sstate == "charge" then
      g.push() g.translate(cx, cy) g.scale(self.facing, 1)
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.55)
      g.polygon("fill", 3, -6, 9, -4, 9, 4, 3, 6)
      g.pop()
    elseif self.sstate == "stunned" then
      -- THE SHELL IS OFF. Drawn as the absence of the thing that was
      -- stopping your shots, not merely as stars: the belly is showing.
      g.setColor(P.vesslite[1], P.vesslite[2], P.vesslite[3],
        0.35 + 0.2 * math.sin(G.time * 9))
      g.ellipse("fill", cx, cy + 2, self.w / 2 - 1, self.h / 2 - 2)
      Enemy.drawStun(self)
    end
    g.setColor(1, 1, 1, 1)
  end)
do
  -- THE PLATES, AND WHAT TAKES THEM OFF.
  --
  -- Wired the way plateframe and rammer are: deflects() is asked by Proj
  -- BEFORE the damage pass, so a stopped round is destroyed at the shell
  -- rather than declining the damage and sailing on to try again from
  -- the other side next frame.
  local made = Entity.registry["spineshell"]
  Entity.registry["spineshell"] = function(x, y, parts)
    local c = made(x, y, parts)
    -- One door in and out of the open state, because there are three
    -- ways in (a wall, the dome, the Cinder Ram) and every one of them
    -- has to leave the state machine somewhere it can leave again.
    c.shellStun = function(self, World, how)
      self.sstate = "stunned"
      self.st = SHELL_STUN
      self.vx = 0
      local cx, cy = self:center()
      World = World or require "src.world"
      World:fx("burst", cx, cy, { color = "silver", n = 12, speed = 130 })
      Cam.shake(how == "wall" and 2 or 3, 0.2)
      if G.Audio then G.Audio.sfx(how == "dome" and "domehit" or "impact") end
      return true
    end
    -- The Cinder Ram shatters a raised guard outright, everywhere else
    -- in the game. It does here too, and it is worth the same five
    -- seconds -- a guard break IS the payload, so the dash deals no
    -- damage on the hit that lands it.
    c.guardBreak = function(self, dur)
      if self.sstate == "stunned" then return false end
      return self:shellStun(nil, "ram")
    end
    -- A concussion (Vess's plain dash on a light body, Lu's stun shot)
    -- must not leave it mid-charge: it would resume a charge it never
    -- finished, from wherever it was pushed to.
    c.onStunned = function(self)
      self.sstate = "walk"
      self.st = SHELL_REST
      self.vx = 0
    end
    c.deflects = function(self, srcx, srcy, opts)
      if self.sstate == "stunned" then return false end
      return shellBlocked(self, srcx, srcy, opts)
    end
    local baseHurt = Entity.hurt
    c.hurt = function(self, dmg, srcx, srcy, opts)
      if self:deflects(srcx, srcy, opts) then
        shieldSpark(self)
        return false
      end
      return baseHurt(self, dmg, srcx, srcy, opts)
    end
    return c
  end
end

-- ==================================================================
-- FURNACE
-- ==================================================================
-- The close/strike/retreat the golem's swarm flies on now lives on
-- Enemy:huntStep -- see the block above speedMult. The bat's numbers are
-- the defaults there, because they are the numbers it was tuned to.
reg("cinderbat", { hp = 3, touchDmg = 2, sprite = "en_cinderbat", w = 12, h = 10,
  deathColor = "magma", animRate = 10 },
  function(self, dt)
    -- HUNTING: it does not hang, it comes for you.
    --
    -- The default below is a ROOST -- bob in place until something walks
    -- within 120px, swoop for 1.2s, go back to bobbing. In a room that
    -- is ten tiles tall and a bat that spawned against the ceiling, that
    -- 120px never happens and the swarm simply decorates the roof.
    -- Reported exactly that way: "the bats spawn successfully but stay
    -- near the ceiling."
    --
    -- Set by whatever spawned it (the Slag Golem's roof swarm), so an
    -- ordinary cinderbat hung in a room is unchanged -- the roost is
    -- correct there, and it is the reason those rooms read as caves.
    if self.hunt then return self:huntStep(dt) end
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

reg("slagblob", { mass = "heavy", hp = 7, touchDmg = 3, sprite = "en_slagblob", w = 14, h = 12,
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
  -- tagged so the Crucible can count its own swarm against the cap, and
  -- so a floor flood knows what it is allowed to burn
  init = function(self) self.slagling = true end,
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

-- THE GOLD MITE. The Crucible shakes them out of the roof when it slams:
-- they drop, they land, and they run at you along the floor. No ranged
-- attack and almost no health -- the threat is that there are four more
-- of them and you are trying to read a vent window.
--
-- It falls rather than flies, deliberately. A flier would join the
-- slaglings as one more thing in the air above a fight whose whole
-- question is "am I on the ground with the boss"; a runner crosses the
-- floor you are standing on.
-- FULL SIZE, AND SLOWER THAN YOU (Thomas, Aug 2026). The threat is that
-- there are four of them between you and where you want to stand -- not
-- that they can run you down. A body you cannot outrun is a body you
-- have to fight, and this one is meant to be a body you can leave.
--
-- The ceiling is read off the PLAYER rather than written here, so it
-- stays true if the run speed is ever retuned -- and it is a ceiling on
-- the FINAL speed, after speedMult, because a buffed mite at 1.5x an
-- absolute constant is exactly how "slower than the player" quietly
-- stops being true.
local MITE_RUN = 74
local MITE_HOP = -180
local MITE_TOP = 0.8            -- of the player's run, absolute ceiling
local BASE_RUN                  -- resolved lazily; player.lua is heavy
local function playerRun()
  if not BASE_RUN then
    BASE_RUN = (require "src.entities.player").BASE.runSpeed
  end
  return BASE_RUN
end
reg("goldmite", { hp = 3, touchDmg = 2, sprite = "en_goldmite", w = 14, h = 10,
  drops = { shards = 2, scrap = 0.1 }, deathColor = "gold", animRate = 12 },
  function(self, dt)
    local World = require "src.world"
    self.vy = math.min((self.vy or 0) + 830 * dt, 320)
    if not self.onGround then
      -- still falling out of the roof: no steering, it is a dropped thing
      PH.move(self, (self.vx or 0) * dt, self.vy * dt)
      return
    end
    local p = World:nearestPlayer(self:center())
    if p then
      local s = U.sign((p.x + p.w / 2) - (self.x + self.w / 2))
      if s ~= 0 then self.facing = s end
      -- a little hop when the mark is above it, so a ledge is not a wall
      if p.y + p.h < self.y - 4 and U.chance(dt * 1.6) then
        self.vy = MITE_HOP
      end
    end
    local sp = math.min(MITE_RUN * self:speedMult(), playerRun() * MITE_TOP)
    self.vx = self.facing * sp
    PH.move(self, self.vx * dt, self.vy * dt)
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
          self:shoot(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "fireball", size = 5,
            vx = math.cos(ang) * 150, vy = math.sin(ang) * 150, life = 2,
          })
          if G.Audio then G.Audio.sfx("shoot4") end
        end
      end
    end
  end)

reg("shieldbug", { mass = "heavy", hp = 8, touchDmg = 3, sprite = "en_shieldbug", w = 14, h = 10,
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
          self:shoot(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "shard", size = 4,
            vx = math.cos(ang + off) * 130, vy = math.sin(ang + off) * 130,
            life = 1.8,
          })
        end
        if G.Audio then G.Audio.sfx("shoot4") end
      end
    end
  end)

reg("cryoturret", { mass = "fixed", hp = 7, touchDmg = 2, sprite = "en_cryoturret", w = 12, h = 12,
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
          self:shoot(World, cx, cy, {
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
          self:shoot(World, cx, cy, {
            side = "enemy", dmg = 2, kind = "shard", size = 4, chill = true,
            vx = math.cos(ang) * 150, vy = math.sin(ang) * 150, life = 1.8,
          })
          if G.Audio then G.Audio.sfx("shoot4") end
        end
      end
    end
  end)

reg("shelverbot", { mass = "heavy", hp = 8, touchDmg = 3, sprite = "en_shelverbot", w = 14, h = 14,
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
        self:shoot(World, cx, cy, {
          side = "enemy", dmg = 3, kind = "orb", size = 6,
          vx = U.clamp(dx * 1.1, -120, 120), vy = -190,
          gravity = 340, life = 2.6,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("icemaw", { mass = "heavy", hp = 9, touchDmg = 4, sprite = "en_icemaw", w = 14, h = 10,
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
reg("keeperbrassa", { mass = "heavy", hp = 45, touchDmg = 3, sprite = "npc_brassa", w = 12, h = 15,
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
      self:shoot(World, cx, cy, {
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
      self:shoot(World, self.x + 6, self.y + 6, {
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
        self:shoot(World, self.x + 6, self.y + self.h, {
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
local FANG_LATCH = 2.4      -- seconds of grip
local FANG_GAP = 0.75        -- seconds between bites
local FANG_DMG = 2          -- damage per bite (4 over a full latch)
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
        -- LET GO PROPERLY. This dropped the reference and left the pin
        -- itself on the victim -- the same care onDeathExtra takes when
        -- the BAT dies was never taken for when the VICTIM goes down.
        -- Player:goDown clears it now too, so this is belt and braces
        -- rather than the only guard, which is what it should have been
        -- from the start.
        if v.pinnedT and v.pinnedT > 0 and v.pinnedBy == self then
          v:freeFromPin(false)
        end
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
    do
      local cx, cy = self:center()
      local domer = World:domeCovering(cx, cy, self.w / 2)
      if domer then
        domer:domeAbsorb(2)
        self.recover = 0.8
        self.vx, self.vy = -self.vx, -math.abs(self.vy) - 40
        World:fx("spark", cx, cy, { color = "cyan", n = 8 })
        if G.Audio then G.Audio.sfx("domehit") end
        return
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
reg("sentinel", { mass = "heavy", hp = 8, touchDmg = 3, sprite = "en_sentinel", w = 14, h = 14,
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
        self:shoot(World, cx, cy, {
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
        self:shoot(require "src.world", cx, cy, {
          side = "enemy", dmg = 1, kind = "orb", size = 4,
          vx = U.sign(p.x - cx) * 40, vy = -30, gravity = 140, life = 2.2,
        })
        if G.Audio then G.Audio.sfx("shoot2") end
      end
    end
  end)

reg("eliteguard", { mass = "heavy", hp = 12, touchDmg = 4, sprite = "en_eliteguard", w = 14, h = 16,
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
        self:shoot(World, cx, cy, {
          side = "enemy", dmg = 3, kind = "spark", size = 5,
          vx = self.facing * (150 + i * 40), vy = -10 + i * 20, life = 1.8,
        })
      end
      if G.Audio then G.Audio.sfx("shoot1") end
    end
  end)

-- ==================================================================
-- THE SCRAPYARD
-- ==================================================================
-- Four enemies, in teaching order. The husk sets the tone, the plateframe
-- teaches that a directional shield has a back, the rammer teaches the
-- bounce read you will need against EIGHT, and the dragger teaches that
-- the worst thing that can happen to you here is not damage.

-- A caretaker frame with no legs, dragging itself by one arm. Its job is
-- tone, not threat: you should feel bad shooting the first one.
reg("scraphusk", { hp = 5, touchDmg = 2, sprite = "en_scraphusk", w = 14, h = 9,
  drops = { shards = 2, heart = 0.15 }, deathColor = "slate", animRate = 3,
  init = function(self) self.lungeT = U.rand(1.2, 2.4) end },
  function(self, dt)
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    local p = playerNear(self, 120)
    if p then
      local s = U.sign(p.x - self.x)
      if s ~= 0 then self.facing = s end
    end
    self.lungeT = self.lungeT - dt
    if self.lungeT <= 0 and self.onGround then
      -- one committed drag-lunge, then a long rest. It is trying.
      self.lungeT = U.rand(1.6, 2.8) / self:speedMult()
      self.lunging = 0.45
      self.vy = -70
    end
    if (self.lunging or 0) > 0 then
      self.lunging = self.lunging - dt
      self.vx = self.facing * 96 * self:speedMult()
    else
      self.vx = U.approach(self.vx or 0, self.facing * 16 * self:speedMult(), 200 * dt)
    end
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.hitWall then self.facing = -self.hitWall end
  end)

-- THE LESSON. Immune from the side it faces; open from behind and from
-- directly above. Slow to turn, and while it turns it is open -- so a
-- co-op pair can pin its attention and gut it, and a solo player can dash
-- past and shoot the back. Once you own the Cinder Ram the plate can be
-- shattered head-on instead.
local PLATE_TURN = 1.2      -- seconds to commit to a reversal
local PLATE_SHOT = 2.2
reg("plateframe", { mass = "heavy", hp = 12, touchDmg = 3, sprite = "en_plateframe",
  w = 14, h = 16, drops = { shards = 5, big = 0.2, scrap = 0.2 },
  deathColor = "slate", animRate = 3,
  init = function(self)
    self.turnT = 0
    self.wantFace = self.facing
    self.shotT = U.rand(0.8, PLATE_SHOT)
    self.guardT = 0            -- > 0 means the plate is shattered
  end },
  function(self, dt)
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    self.vx = U.approach(self.vx or 0, 0, 400 * dt)
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.guardT > 0 then self.guardT = self.guardT - dt end

    local p = playerNear(self, 190)
    if p then
      local want = U.sign((p.x + p.w / 2) - (self.x + self.w / 2))
      if want ~= 0 and want ~= self.wantFace then
        self.wantFace = want
        self.turnT = PLATE_TURN
      end
    end
    if self.turnT > 0 then
      self.turnT = self.turnT - dt
      if self.turnT <= 0 then self.facing = self.wantFace end
    end

    self.shotT = self.shotT - dt
    if self.shotT <= 0 and p and self.turnT <= 0 then
      self.shotT = PLATE_SHOT / self:speedMult()
      local World = require "src.world"
      self:shoot(World, self.x + self.w / 2 + self.facing * 9, self.y + 5, {
        side = "enemy", dmg = 3, kind = "bolt", size = 5,
        vx = self.facing * 150, vy = 0, life = 2.2,
      })
      if G.Audio then G.Audio.sfx("shoot1") end
    end
  end,
  function(self)
    self:drawSprite()
    local g = love.graphics
    local cx, cy = self:center()
    if self.guardT > 0 then return end     -- shattered: no plate drawn
    -- the plate itself, on the facing side, plus a tell while turning
    local f = self.facing
    g.push() g.translate(cx, cy) g.scale(f, 1)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.95)
    g.polygon("fill", 4, -8, 10, -6, 10, 6, 4, 8)
    g.setColor(P.silver)
    g.line(10, -6, 10, 6)
    g.pop()
    if self.turnT > 0 then
      g.setColor(P.gold[1], P.gold[2], P.gold[3],
        0.4 + 0.4 * math.sin(G.time * 18))
      g.circle("line", cx, cy - self.h / 2 - 4, 3)
    end
    g.setColor(1, 1, 1, 1)
  end)
do
  -- The facing side vetoes damage outright. Same shape as the shieldbug's
  -- veto, but keyed to geometry rather than a timer.
  local made = Entity.registry["plateframe"]
  Entity.registry["plateframe"] = function(x, y)
    local c = made(x, y)
    c.guardBreak = function(self, dur)
      if self.guardT > 0 then return false end
      self.guardT = dur
      self.turnT = 0
      return true
    end
    -- asked by Proj BEFORE the damage pass, so a stopped round is stopped
    c.deflects = function(self, srcx, srcy, opts)
      return self.guardT <= 0 and frontBlocked(self, srcx, srcy, opts)
    end
    local baseHurt = Entity.hurt
    c.hurt = function(self, dmg, srcx, srcy, opts)
      if self:deflects(srcx, srcy, opts) then
        shieldSpark(self)
        return false
      end
      return baseHurt(self, dmg, srcx, srcy, opts)
    end
    return c
  end
end

-- EIGHT's move, in miniature. Telegraphs, charges with frontal immunity,
-- and bounces off the far wall into a long stagger. That stagger is your
-- window -- and learning to read it here is the whole point.
local RAM_TELE = 0.55
local RAM_SPEED = 210
local RAM_STAGGER = 1.0
reg("rammer", { mass = "heavy", hp = 10, touchDmg = 3, sprite = "en_rammer",
  w = 14, h = 15, drops = { shards = 5, big = 0.2, scrap = 0.25 },
  deathColor = "vessred", animRate = 4,
  init = function(self)
    self.rstate = "stalk"
    self.rt = U.rand(0.6, 1.4)
  end },
  function(self, dt)
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    self.rt = self.rt - dt
    local World = require "src.world"

    if self.rstate == "stalk" then
      local p = playerNear(self, 200)
      if p then
        local s = U.sign((p.x + p.w / 2) - (self.x + self.w / 2))
        if s ~= 0 then self.facing = s end
      end
      self.vx = U.approach(self.vx or 0, self.facing * 34 * self:speedMult(), 300 * dt)
      if self.rt <= 0 and p then
        self.rstate = "tele"
        self.rt = RAM_TELE
        self.vx = 0
      end
    elseif self.rstate == "tele" then
      self.vx = U.approach(self.vx or 0, 0, 700 * dt)
      if self.rt <= 0 then
        self.rstate = "charge"
        self.rt = 1.6
        if G.Audio then G.Audio.sfx("ram") end
      end
    elseif self.rstate == "charge" then
      self.vx = self.facing * RAM_SPEED * self:speedMult()
      World:fx("trail", self.x + self.w / 2, self.y + self.h / 2,
        { color = "vessdark", r = 2.5, t = 0.16 })
      if self.rt <= 0 then
        self.rstate = "stalk"
        self.rt = U.rand(0.9, 1.6)
      end
    else -- stagger
      self.vx = U.approach(self.vx or 0, 0, 500 * dt)
      if self.rt <= 0 then
        self.rstate = "stalk"
        self.rt = U.rand(0.8, 1.4)
      end
    end

    PH.move(self, (self.vx or 0) * dt, self.vy * dt)
    if self.hitWall then
      if self.rstate == "charge" then
        -- it hit the wall. Same rule it lives by, same rule you live by.
        self.rstate = "stagger"
        self.rt = RAM_STAGGER
        self.vx = -self.hitWall * 120
        self.vy = -80
        Cam.shake(2, 0.15)
        World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
          { color = "slate", n = 10, speed = 140 })
        if G.Audio then G.Audio.sfx("impact") end
      else
        self.facing = -self.hitWall
      end
    end
  end,
  function(self)
    self:drawSprite()
    local g = love.graphics
    local cx, cy = self:center()
    if self.rstate == "tele" then
      local ig = 1 - math.max(0, self.rt) / RAM_TELE
      g.push() g.translate(cx, cy) g.scale(self.facing, 1)
      g.setColor(P.blood[1], P.blood[2], P.blood[3], 0.35 + ig * 0.55)
      g.setLineWidth(1.5)
      g.line(6, -5, 10, 0, 6, 5)
      g.setLineWidth(1)
      g.pop()
    elseif self.rstate == "charge" then
      g.push() g.translate(cx, cy) g.scale(self.facing, 1)
      g.setColor(P.vessdark[1], P.vessdark[2], P.vessdark[3], 0.5)
      g.polygon("fill", 4, -7, 10, -5, 10, 5, 4, 7)
      g.pop()
    elseif self.rstate == "stagger" then
      Enemy.drawStun(self)
    end
    g.setColor(1, 1, 1, 1)
  end)
do
  -- Frontal immunity while it is actually charging, and a charge that is
  -- interrupted must not leave the state machine mid-swing.
  local made = Entity.registry["rammer"]
  Entity.registry["rammer"] = function(x, y)
    local c = made(x, y)
    c.onStunned = function(self)
      self.rstate = "stalk"
      self.rt = 0.6
      self.vx = 0
    end
    c.guardBreak = function(self, dur)
      if self.rstate ~= "charge" then return false end
      self.rstate = "stagger"
      self.rt = dur
      self.vx = 0
      return true
    end
    c.deflects = function(self, srcx, srcy, opts)
      return self.rstate == "charge" and frontBlocked(self, srcx, srcy, opts)
    end
    local baseHurt = Entity.hurt
    c.hurt = function(self, dmg, srcx, srcy, opts)
      if self:deflects(srcx, srcy, opts) then
        shieldSpark(self)
        return false
      end
      return baseHurt(self, dmg, srcx, srcy, opts)
    end
    return c
  end
end

-- ==================================================================
-- THE DRAGGER  (COOP-PLAN 5)
-- ==================================================================
-- "A dragger extends the pin from HOLD to MOVE: it hauls you somewhere --
-- toward a spike sump, or simply away from your partner, straight into
-- the camera budget."
--
-- THE RULE THAT SHAPES ALL OF IT. From the design docs, and it is not
-- negotiable: *a rescue that needs a partner is a death sentence rather
-- than a mechanic.* So the grip is ALWAYS breakable alone, by mashing,
-- in the time it holds you. What the partner buys is SPEED -- every shot
-- into the claw is worth presses you did not have to make -- and that is
-- the difference between a co-op mechanic and a co-op requirement.
--
-- WHAT IT ACTUALLY THREATENS. Not damage: it does none while it has you.
-- It threatens PLACE. It hauls you back along its rail, and the level is
-- what makes that cost something -- a spike bed under the rail, a gap it
-- drags you over, a lane your partner cannot follow you down. A claw in
-- an empty corridor is a two-second inconvenience, and it should be.
--
-- THE HAUL IS BOUNDED, and by the same number the camera is: §13.5 says
-- a pin that hauls further than the wall allows would fight the camera,
-- so the rail runs out at 0.75 of a screen and the claw lets go. That is
-- also why it is a rail and not a rope -- something has to explain the
-- limit in the fiction, and "it reached the end of its track" does.
-- WHICH WAY THE RAIL RUNS IS THE ROOM'S DECISION, not the claw's.
--
-- The first version hauled the catch back to the point it dropped from,
-- which reads fine and is worth nothing: the grab window is six tiles
-- wide, so the longest haul it could ever manage was six tiles back to
-- where it started, and the camera budget it is supposed to be bounded
-- by was never within reach of binding. A claw that returns you to where
-- you were standing is not a threat, it is a pause.
--
-- So the rail has a direction, authored per spawn like the vents:
--
--     ["c"] = "dragger:rail=-1"    -- the rail runs left
--     ["C"] = "dragger:rail=1"     -- ...and this one runs right
--
-- That is what lets the level aim it: over the spike bed, out along the
-- lane the partner cannot follow, off the lip of the gap. The claw is
-- the verb; the room is the sentence.
local DRAG_WAKE   = 96     -- px: how far along the floor it watches
local DRAG_DROP   = 320    -- px/s it falls when it commits
local DRAG_HAUL   = 54     -- px/s it drags a body at -- slow enough to fight
local DRAG_HOLD   = 3.2    -- s: the grip lets go on its own after this
local DRAG_RETURN = 70     -- px/s climbing back to its rail afterwards
local DRAG_HIT    = 3      -- presses' worth of credit per partner hit
local DRAG_COOL   = 1.1    -- s of recovery after it lets go
-- 0.75 of a 480px screen, the same budget checkcoop measures separation
-- against. Read as pixels here because the claw moves in pixels.
local DRAG_BUDGET = 0.75 * 480

local Dragger = reg("dragger", { mass = "fixed", hp = 9, touchDmg = 2, sprite = "en_dragger",
  w = 12, h = 10, drops = { shards = 4, scrap = 0.2, big = 0.15 },
  deathColor = "rust", animRate = 3,
  -- FIXED mass: it is bolted to a rail. Vess's plated charge bounces off
  -- it exactly like a wall rather than concussing it, which is the right
  -- read -- you cannot shoulder-barge a gantry.
  init = function(self)
    self.dstate = "hang"
    self.homeX, self.homeY = self.x, self.y
    self.sway = U.rand(0, 6)
    -- `rail=` reaches self through Enemy.SPAWN_KEYS before init runs
    self.railDir = (self.rail and self.rail > 0) and 1 or -1
  end,
  -- reg() consumes onDeathExtra at REGISTRATION -- it wraps Enemy.onDeath
  -- once, there and then. Hanging it on the class afterwards looks
  -- identical and does nothing at all.
  onDeathExtra = function(self)
    if self.victim then self:letGo(true) end
  end },
  function(self, dt)
    local World = require "src.world"
    if not self.homeX then self.homeX, self.homeY = self.x, self.y end

    -- ---- holding: haul the catch back along the rail ---------------
    if self.dstate == "haul" then
      local v = self.victim
      -- the safety net: anything that ends the pin from the other side
      -- (a revive, a room change, the victim going down) drops the grip
      if not v or v.dead or v.pinnedT <= 0 then
        self:letGo(false)
        return
      end
      self.holdT = (self.holdT or DRAG_HOLD) - dt
      v.pinnedT = math.max(v.pinnedT, math.min(self.holdT, DRAG_HOLD))

      -- MOVE THE BODY, not just itself. Player:update returns early while
      -- pinned and zeroes its own velocity, so the haul has to go through
      -- the physics on the victim's behalf -- which is also what makes it
      -- stop at a wall instead of posting the body through one.
      if (self.hauled or 0) < DRAG_BUDGET then
        local step = (self.railDir or -1) * DRAG_HAUL * dt
        local x0 = v.x
        PH.move(v, step, 0)
        local got = math.abs(v.x - x0)
        self.hauled = (self.hauled or 0) + got
        -- IT STOPS WHEN THE BODY STOPS. Hauling into a wall used to burn
        -- the whole grip with nothing moving, which reads as a bug even
        -- though it is physically right -- the rail has run out as far as
        -- this catch is concerned, so let go and let them get on with it.
        if got < 0.05 then self:letGo(false) return end
        -- it lifts as it pulls: a claw on a rail carries, it does not plough
        PH.move(v, 0, -math.min(18, math.abs(step) * 6))
      end
      -- ride the victim so the cable reads right
      self.x = v.x + v.w / 2 - self.w / 2
      self.y = v.y - self.h + 2
      if self.holdT <= 0 or (self.hauled or 0) >= DRAG_BUDGET then
        self:letGo(false)
      end
      return
    end

    -- ---- recovering, then climbing home ---------------------------
    if self.dstate == "cool" then
      self.coolT = (self.coolT or DRAG_COOL) - dt
      if self.coolT <= 0 then self.dstate = "home" end
      return
    end
    if self.dstate == "home" then
      local dx = self.homeX - self.x
      local dy = self.homeY - self.y
      if math.abs(dx) < 1.5 and math.abs(dy) < 1.5 then
        self.x, self.y = self.homeX, self.homeY
        self.dstate = "hang"
        self.hauled = 0
        return
      end
      local n = math.max(1, math.sqrt(dx * dx + dy * dy))
      self.x = self.x + (dx / n) * DRAG_RETURN * dt
      self.y = self.y + (dy / n) * DRAG_RETURN * dt
      return
    end

    -- ---- hanging: watch the floor under the rail ------------------
    if self.dstate == "hang" then
      self.x = self.homeX
      self.y = self.homeY + math.sin(self.t * 1.6 + self.sway) * 1.5
      local best, bd
      for _, p in ipairs(World:alivePlayers()) do
        if not p.idle and not p.downed and p.pinnedT <= 0 then
          local dx = math.abs((p.x + p.w / 2) - (self.homeX + self.w / 2))
          local below = (p.y + p.h) > self.homeY
          if below and dx < DRAG_WAKE and (not bd or dx < bd) then
            best, bd = p, dx
          end
        end
      end
      if best then
        self.dstate = "drop"
        self.markX = best.x + best.w / 2
        if G.Audio then G.Audio.sfx("switch") end
      end
      return
    end

    -- ---- dropping: straight down the cable ------------------------
    if self.dstate == "drop" then
      -- it tracks a little on the way down, so a standing body is caught
      -- and a running one is usually not. That is the whole read.
      self.x = U.approach(self.x, self.markX - self.w / 2, 40 * dt)
      PH.move(self, 0, DRAG_DROP * dt)
      do
        -- A RAISED DOME TURNS IT AWAY. Lu can shield her partner out of a
        -- claw, which is the co-op answer to it and costs her the energy.
        local cx, cy = self:center()
        local domer = World:domeCovering(cx, cy, self.w / 2)
        if domer then
          domer:domeAbsorb(2)
          World:fx("spark", cx, cy, { color = "cyan", n = 8 })
          if G.Audio then G.Audio.sfx("domehit") end
          self:letGo(false)
          return
        end
      end
      for _, q in ipairs(World:alivePlayers()) do
        if not q.idle and not q.downed and q.pinnedT <= 0 and q.invuln <= 0
          and U.aabb(self.x, self.y, self.w, self.h, q.x, q.y, q.w, q.h) then
          if q:pin(self, DRAG_HOLD) then
            self.victim = q
            self.dstate = "haul"
            self.holdT = DRAG_HOLD
            self.hauled = 0
            if G.Audio then G.Audio.sfx("quake") end
            if G.game then G.game:announce("A claw has you -- MASH!", 1.4) end
          end
          return
        end
      end
      -- missed, or hit the floor
      if self.onGround or self.hitCeil then self:letGo(false) end
      return
    end
  end,
  function(self)
    -- the cable back to the rail, drawn first so the claw sits on it
    local g = love.graphics
    local cx = self.x + self.w / 2
    if self.homeY and self.y > self.homeY then
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.85)
      g.setLineWidth(1)
      g.line(self.homeX + self.w / 2, self.homeY - 4, cx, self.y + 2)
    end
    g.setColor(1, 1, 1, 1)
    G.drawSprite(self.sprite, self.victim and 2 or 1, cx, self.y + self.h + 0.5,
      { white = math.max(0, (self.white or 0) * 6) })
  end)

-- LETTING GO IS ONE FUNCTION, because there are five ways it happens --
-- the timer, the rail running out, a dome, being shot off, and the
-- victim tearing loose. The roostfang has four slightly different copies
-- of this and they do not agree with each other.
Dragger.letGo = function(self, struggled)
  local v = self.victim
  self.victim = nil
  if v and v.pinnedT and v.pinnedT > 0 then v:freeFromPin(struggled) end
  self.dstate = "cool"
  self.coolT = DRAG_COOL
  self.hauled = 0
  if G.Audio then G.Audio.sfx("deflect") end
end

-- THE PARTNER BUYS PRESSES, NOT THE RESCUE.
--
-- Shooting the claw does not open it -- that would make the grip
-- partner-dependent from the other direction, where a solo player simply
-- has no answer worth having. Each hit is worth DRAG_HIT presses of the
-- mash the victim would otherwise have made themselves, so help is a
-- speed-up and never a permission.
Dragger.onHurt = function(self, dmg, srcx)
  Enemy.onHurt(self, dmg, srcx)
  local v = self.victim
  if v and (v.pinnedT or 0) > 0 then
    v.pinnedMash = (v.pinnedMash or 0) + DRAG_HIT
    local World = require "src.world"
    World:fx("spark", v.x + v.w / 2, v.y + 2, { color = "gold", n = 4 })
  end
end

-- The victim tore loose on their own: Player:freeFromPin routes here.
Dragger.onPinReleased = function(self, p, struggled)
  if self.victim == p then
    self.victim = nil
    self.dstate = "cool"
    self.coolT = DRAG_COOL
    self.hauled = 0
  end
end

return Enemy
