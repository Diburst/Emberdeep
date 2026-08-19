-- The two playable bots: Vess (1, gunner) and Lu (2, operator).
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local Up = require "src.upgrades"
local P = require "src.assets.palette"
local PH = require "src.physics"
local Weapons = require "src.weapons"
local Proj = require "src.entities.projectile"
local Cam = require "src.camera"
local Cold = require "src.cold"

local T = 16
local Player = Entity.extend()

-- Lava is a burn, not a delete: hits every quarter second. Shared with the
-- Crucible's pouring stream, which is the same substance in mid-air.
local LAVA_DMG = 10
local LAVA_TICK = 0.25

local BASE = {
  runSpeed = 112, accel = 950, airAccel = 620, friction = 800,
  jumpVel = -310, gravity = 830, maxFall = 300,   -- apex ~3.2 tiles measured
  -- (calibrate scenario: discrete integration eats ~4px vs the v^2/2g
  -- formula; -292 only reached 2.82 tiles, breaking 3-tile ledges)
  waterGravity = 340, waterJump = -220, waterMaxFall = 90, waterSpeed = 80,
  coyote = 0.09, jumpBuffer = 0.12,
}

-- ==================================================================
-- THE BULWARK LINE (Vess's charge upgrades)
-- ==================================================================
-- Two modules, both flags on G.run.flags:
--   `bulwark`   -- a directional plate on the charge (Scrapyard midpoint)
--   `cinderram` -- damage on the charge (dropped by VESSEL-8)
--
-- The base dash already grants blanket i-frames (see takeDamage). The plate
-- adds the four things the dash could never do: it stops `pierceDash`
-- hazards taken head-on, it DEFLECTS enemy shots instead of letting them
-- sail through, it refuses to pass through a body, and it concusses
-- anything light enough to be concussed.
--
-- INVARIANT, no exceptions: a charge never carries Vess through a body.
-- Not an enemy, not a boss, not with the ram, not at any speed. Contact
-- means bounce. See Player:dashImpact.
local DASH_SPEED = 265
local PLATE_HOLD = 0.12        -- plate stays up this long after the dash ends
local PLATE_HOLD_BOSS = 0.18   -- ...longer after bouncing off something big

-- recoil: { vx, vy, cooldown floor, plate hold, shake mag, shake t }
local BOUNCE = {
  light = { 130, -70, 0.35, PLATE_HOLD, 2.0, 0.15 },
  heavy = { 130, -70, 0.35, PLATE_HOLD, 2.0, 0.15 },
  boss  = { 190, -90, 0.45, PLATE_HOLD_BOSS, 3.5, 0.25 },
  wall  = { 110, -55, 0.30, PLATE_HOLD, 1.5, 0.12 },
}
local BOUNCE_T = 0.18          -- reduced horizontal authority during recoil
local BOUNCE_AUTHORITY = 0.35
local HITSTOP = 0.06

local STUN_DUR = 1.2           -- plate alone
local STUN_DUR_RAM = 1.6       -- with the Cinder Ram
local RAM_DMG = 6

-- ==================================================================
-- CARRYING THE EMBER
--
-- The Ember is not an item in a menu. It is a thing in your hands: a
-- shard the size of the bot's chest, bright enough to light a room, hot
-- enough that nothing living gets close to it. So carrying it costs you
-- everything a hand is for -- you cannot shoot, you cannot raise the
-- dome, you cannot charge -- and you walk at three quarters pace under
-- the weight.
--
-- What you get instead is the aura. Anything small that comes near is
-- simply gone. That trade is the whole point: the carrier stops being a
-- fighter and becomes a thing to be escorted, which is why the OTHER bot
-- suddenly matters.
-- ==================================================================
-- ------------------------------------------------------------------
-- ENCASED IN ICE
-- ------------------------------------------------------------------
-- The Archivist's indexing beam does not knock you down, it puts you
-- INSIDE something. A bot in the block cannot move or act and is being
-- worn away steadily, and the way out is the zone's own verb: the other
-- bot brings fire and melts it.
--
-- SOLO HAS TO HAVE AN ANSWER. The other bot is parked and invulnerable
-- when you play alone, so a rescue that needs a partner is a death
-- sentence rather than a mechanic -- the same rule the pin follows.
-- Mashing breaks the block; it is just far slower than a spark, so in
-- co-op the fire is always the better answer.
-- THE I-FRAME WINDOW, ONCE, WHERE EVERY HAZARD CAN SEE IT.
--
-- takeDamage grants this much mercy after a hit, so ANY hazard that
-- claims to tick faster than it is lying: the extra ticks are swallowed
-- and the hazard runs at IFRAME regardless. The Coldstore's bite told
-- this lie at 0.5s and the drown told it at 0.9s, and in both cases the
-- number in the file described a game nobody was playing. A hazard
-- interval is either IFRAME or a multiple of it.
local IFRAME     = 1.2

-- WATER. An unsealed bot starts drowning the moment it is in the water,
-- not when its head goes under: BREATH_MAX is the grace, DROWN_TICK the
-- interval after that.
local BREATH_MAX = 3.0
local DROWN_TICK = IFRAME
local DROWN_DMG  = 3
-- SWIMMING IS HARD. A held jump used to lift you steadily, which made
-- deep water a lift shaft. One stroke per press, with a cooldown, so
-- crossing water is a thing you fight rather than a thing you hold.
local STROKE_CD  = 0.34

local ICE_DUR    = 9.0     -- seconds before it gives out on its own
local ICE_TICK   = 1.3     -- seconds between bites (i-frames are 1.2)
local ICE_FRAC   = 0.12    -- of max HP per bite
local ICE_MASH   = 8       -- presses to break out unaided
-- 2 TILES of actual travel. This was a velocity that got zeroed on the
-- very next frame by the block below, so the shove moved nobody: a
-- frozen bot held still. friction is 800px/s^2, so d = v^2/2f and
-- v = sqrt(32 * 1600) ~= 230.
local ICE_KNOCK  = 230     -- px/s -> about 2 tiles before it stops

local EMBER_SLOW   = 0.75      -- of normal top speed
local EMBER_AURA_R = 36        -- px; torches anything smaller than a boss
local EMBER_AURA_DMG = 14      -- per tick, to anything too heavy to torch
local EMBER_AURA_TICK = 0.3
local EMBER_LIGHT  = 150
local GUARD_BREAK_T = 2.0      -- a ram shatters a guard instead of damaging it

-- Vault assist. `vy` is already forced to 0 for the whole dash, so an
-- air-dash is a flat 53px hop -- that is how you get behind a boss, since
-- you cannot go through one. Committing within 21px of a 22px-wide target
-- is a pixel check nobody lands, so if the dash ends directly ABOVE
-- something we carry 70% of dash speed until clear.
local VAULT_T = 0.12
local VAULT_SPEED = DASH_SPEED * 0.7
local VAULT_MAX_W = 32         -- wide bosses cannot be vaulted, by design

-- ==================================================================
-- THE DRIFT VANES (Lu's hover, made an unlockable)
-- ==================================================================
-- Flag `driftvanes`. Until she finds them Lu falls like Vess.
--
-- Hover used to be free from frame one, and Spark Jump silently doubled
-- it from 0.65s to 1.3s -- a coupling nothing in the game ever mentioned.
-- The vanes now own hover outright at a flat 1.3s, and Spark Jump is once
-- again purely a jump-height module. A finished save plays identically;
-- the early game is what changes.
--
-- Measured (tools/hover_test.lua): 1.3s of hover carries Lu 194px across
-- a hole against 80px without. roommodel's GAP_W_HOVER = 10 tiles models
-- that with two tiles of margin, and `calibrate` fails if the engine drifts.
local HOVER_T = 1.3
local HOVER_FALL = 26          -- clamped fall speed while the vanes are out

-- THERMAL COLUMNS. Riding one costs no vane charge -- it is an elevator you
-- steer, and the column's declared height is the only limit. That is what
-- lets the co-op cap in the design doc (12 tiles per column, then a shared
-- landing) be a level-design rule rather than a physics accident.
local UPDRAFT_LIFT = 110       -- pre-gravity target; ~96px/s after gravity

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
  -- NOT 9. It was a literal here while BREATH_MAX said 3.0 four hundred
  -- lines up, so the grace before the first drown tick was three times
  -- what the constant claimed and no amount of tuning the constant
  -- changed it.
  self.breath = BREATH_MAX
  self.heat = 12
  -- chill is a 0..1 meter that FILLS, the opposite sense to heat/breath.
  -- It persists across rooms on purpose: a door is not a coat.
  self.chill = 0
  self.chillBite = 0
  self.icedT = 0
  self.icedMash = 0
  self.icedBite = 0
  self.chilledT = 0

  -- Vess kit
  self.dashT = 0
  self.dashCd = 0
  self.airDashed = false
  self.grappling = nil
  -- bulwark / cinder ram
  self.bulwarkT = 0      -- plate live (dash + follow-through)
  self.bounceT = 0       -- recoil: reduced horizontal authority
  self.dashHits = nil    -- one hit per target per charge
  self.vaultT = 0        -- carry-through when a dash ends above a body
  self.vaultDir = 0
  self.vaultOver = nil
  self.hitstopT = 0
  self.chevT = 0         -- fiery chevron ignition (cinder ram)
  self.plateFlashT = 0   -- white lip flash on a deflect/block

  -- Lu kit
  self.maxenergy = pd.maxenergy or 100
  self.energy = self.maxenergy
  self.energyDelay = 0
  self.domeActive = false
  self.domeRadius = 36
  self.repairCd = 0
  self.hoverT = 0
  self.inUpdraft = false
  self.vanesT = 0        -- >0 while the fins are open (drives the draw)

  -- pinned: something has hold of you (the Aerie Sentinel's talons).
  -- No control until it lets go, a partner hurts it, or you struggle free.
  self.pinnedT = 0
  self.pinnedBy = nil
  self.pinnedMash = 0
  self.pinNeeded = nil

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

-- ==================================================================
-- The plate
-- ==================================================================
-- Live during a charge and for a short follow-through afterwards, so the
-- bounce recovery is not a free hit on you.
function Player:plateUp()
  return self.isVess and G.run.flags.bulwark and (self.bulwarkT or 0) > 0
end

-- Front arc. The plate points along `facing`; the protected region is the
-- forward half-plane. Only something strictly BEHIND you gets through --
-- which keeps a spike directly underfoot (dx == 0) covered during a run,
-- while a shot in the back is still a shot in the back.
--
-- A nil source has no direction at all: drowning, heat, cold and the other
-- environmental timers are deliberately NOT blockable by a shield.
function Player:plateBlocks(srcx)
  if not self:plateUp() then return false end
  if not srcx then return false end
  local cx = self.x + self.w / 2
  return U.sign(srcx - cx) ~= -self.facing
end

function Player:onPlateBlock(srcx, srcy)
  local World = require "src.world"
  local cx = self.x + self.w / 2 + self.facing * 8
  local cy = srcy or (self.y + self.h / 2)
  self.plateFlashT = 0.12
  World:fx("spark", cx, cy, { color = "vesslite", angle = math.pi - (self.facing > 0 and 0 or math.pi), n = 5 })
  if G.Audio then G.Audio.sfx("deflect") end
end

function Player:takeDamage(dmg, srcx, opts)
  if self.dead or self.downed or self.idle then return end
  if self.invuln > 0 or self.roomEnterProtect > 0 then return end
  if self.dashT > 0 and not (opts and opts.pierceDash) then return end
  -- BULWARK: the plate stops what the dash never could -- spikes, vents,
  -- and the boss attacks that were flagged to punch through a dash.
  if opts and opts.pierceDash and self:plateBlocks(srcx) then
    self:onPlateBlock(srcx)
    return
  end
  local mult = ({ 0.5, 1, 1.5 })[G.run.difficulty] or 1
  dmg = math.max(1, math.floor(dmg * mult + 0.5))
  self.hp = self.hp - dmg
  self.invuln = IFRAME
  self.hurtT = 0.3
  self.white = 0.12
  if not (opts and opts.noKnock) then
    local dir = srcx and U.sign(self.x + self.w / 2 - srcx) or -self.facing
    if dir == 0 then dir = -self.facing end
    self.vx = dir * 130
    self.vy = math.min(self.vy, -120)
  end
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

-- `warm` is true when the beam caught you standing in a fire's reach:
-- the heat does not save you, it just means you are thrown off it first.
function Player:encase(World, srcx, warm)
  if self.dead or self.downed or self.idle or self.icedT > 0 then return end
  self.icedT = ICE_DUR
  self.icedMash = 0
  self.icedBite = ICE_TICK
  self.invuln = 0
  if warm then
    local dir = srcx and U.sign(self.x + self.w / 2 - srcx) or -self.facing
    if dir == 0 then dir = -self.facing end
    self.x = self.x + dir * 6
    self.vx = dir * ICE_KNOCK
    self.vy = -90
  end
  World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
    { color = "ice", n = 16, speed = 90 })
  Cam.shake(3, 0.3)
  if G.Audio then G.Audio.sfx("crack") end
  if G.game and not G.run.taughtIce then
    G.run.taughtIce = true
    G.game:announce("Frozen solid! Bring a spark to melt them out.", 3)
  end
end

function Player:thaw(World, byFire)
  if self.icedT <= 0 then return end
  self.icedT = 0
  self.icedMash = 0
  self.invuln = math.max(self.invuln, 0.8)
  World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
    { color = byFire and "ember" or "ice", n = 14, speed = 110 })
  if G.Audio then G.Audio.sfx(byFire and "emitter" or "crack") end
end

function Player:iced() return (self.icedT or 0) > 0 end

-- A slab of ice around the whole bot, cracking as you fight it. The
-- cracks are the mash meter: without them there is no way to tell being
-- frozen from being stuck, and no sign that hitting buttons is doing
-- anything at all.
function Player:drawIce(g)
  if (self.icedT or 0) <= 0 then return end
  local x, y = self.x - 5, self.y - 6
  local w, h = self.w + 10, self.h + 8
  local frac = math.min(1, (self.icedMash or 0) / ICE_MASH)
  local shiver = (self.icedMash or 0) > 0 and math.sin(G.time * 40) * frac or 0

  g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.42)
  g.rectangle("fill", x + shiver, y, w, h, 3, 3)
  g.setColor(0.92, 0.98, 1.0, 0.75)
  g.rectangle("line", x + shiver, y, w, h, 3, 3)
  -- a highlight down the near face, so it reads as a solid block
  g.setColor(1, 1, 1, 0.30)
  g.rectangle("fill", x + shiver + 2, y + 2, 3, h - 4)
  g.setColor(1, 1, 1, 0.16)
  g.rectangle("fill", x + shiver + 2, y + 2, w - 4, 2)

  -- CRACKS: one more every press, spreading from the middle
  local n = math.floor(frac * 5)
  g.setColor(1, 1, 1, 0.85)
  for i = 1, n do
    local sx = x + shiver + 3 + ((i * 37) % math.max(1, w - 6))
    local sy = y + 3 + ((i * 53) % math.max(1, h - 8))
    g.line(sx, sy, sx + 3 - (i % 3) * 3, sy + 4)
  end
  g.setColor(1, 1, 1, 1)
end

function Player:goDown()
  self.downed = true
  self.icedT = 0
  -- a bot on the floor is not holding a flame
  if self:hasSpark() then
    self:dropSpark(require "src.world", nil)
  end
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

-- ==================================================================
-- Being pinned
-- ==================================================================
-- Presses needed to tear free. The partner hurting the holder is the
-- fast way out; this is the one that works when you are on your own.
Player.PIN_MASH = 8

-- A holder may set `pinMash` on itself to make its grip easier or harder
-- to break than the default. A boss's talons should cost more to shake
-- off than a bat's.
function Player:pin(by, dur)
  if self.dead or self.downed or self.idle then return false end
  self.pinnedBy = by
  self.pinnedT = dur
  self.pinnedMash = 0
  self.pinNeeded = (by and by.pinMash) or Player.PIN_MASH
  self.domeActive = false
  self.charging = false
  self.grappling = nil
  self.dashT = 0
  return true
end

-- Called by the player struggling out, by the holder letting go, and as
-- a safety net if the holder dies mid-grab.
function Player:freeFromPin(struggled)
  local by = self.pinnedBy
  self.pinnedT = 0
  self.pinnedMash = 0
  self.pinnedBy = nil
  self.pinNeeded = nil
  if by and by.onPinReleased then by:onPinReleased(self, struggled) end
  if struggled then
    self.invuln = math.max(self.invuln, 0.6)   -- brief mercy on the break
    if G.Audio then G.Audio.sfx("dash") end
  end
end

-- ANTI-SHIELD weapons bite a FLAT chunk out of the reserve. Unlike
-- domeAbsorb below there is no tier discount and no scaling with the
-- incoming damage, which is what lets a boss actually threaten a dome
-- that is being held up permanently. See Bosses.energyDart.
function Player:domeDrain(amount)
  self.energy = math.max(0, self.energy - amount)
  self.energyDelay = 1
  if self.energy <= 0 then
    self.domeActive = false
    if G.Audio then G.Audio.sfx("domeoff") end
  end
end

-- Lu's dome soaks a hit: costs energy instead of health.
function Player:domeAbsorb(dmg)
  local mult = Up.domeDrain()
  self.energy = math.max(0, self.energy - dmg * mult)
  self.energyDelay = 1
  if self.energy <= 0 then
    self.domeActive = false
    if G.Audio then G.Audio.sfx("domeoff") end
  end
end

-- ==================================================================
-- Impact: bounce, concussion, and the vault
-- ==================================================================
-- Every body falls into one of four buckets. `mass` is declared on the
-- enemy def (see enemies.lua); anything untagged is light, which is the
-- safe default -- a missed tag makes something more fun to hit rather
-- than accidentally trivialising a mini-boss.
local function massOf(e)
  if e.isBoss then return "boss" end
  if e.mass then return e.mass end
  if e.heavy then return "heavy" end
  return "light"
end

-- Recoil off a body or a wall. Ends the charge in the same frame, before
-- PH.move runs, which is what makes pass-through structurally impossible.
function Player:bounceOff(what, contactX, contactY)
  local World = require "src.world"
  local b = BOUNCE[what] or BOUNCE.light
  self.dashT = 0
  self.vx = -self.facing * b[1]
  self.vy = b[2]
  self.dashCd = math.max(self.dashCd, b[3])
  self.bulwarkT = math.max(self.bulwarkT or 0, b[4])
  self.bounceT = BOUNCE_T
  self.hitstopT = HITSTOP
  self.vaultT = 0
  self.vaultOver = nil
  Cam.shake(b[5], b[6])
  G.Input.rumble(self:controlSlot() or self.idx,
    what == "boss" and 0.7 or 0.4, what == "boss" and 0.2 or 0.12)
  if contactX then
    World:fx("burst", contactX, contactY or (self.y + self.h / 2),
      { color = G.run.flags.cinderram and "magma" or "vessred", n = 10, speed = 150 })
  end
  if G.Audio then G.Audio.sfx(what == "wall" and "impact" or "ramhit") end
end

-- Concussion. Never applied directly -- Enemy:stun cancels whatever the
-- thing was in the middle of doing, so a frozen update can't strand a
-- half-finished attack (the Bramble Maw class of bug).
function Player:concuss(e)
  local dur = G.run.flags.cinderram and STUN_DUR_RAM or STUN_DUR
  if e.stun then e:stun(dur) else e.stunT = math.max(e.stunT or 0, dur) end
  local World = require "src.world"
  World:fx("burst", e.x + e.w / 2, e.y + e.h / 2 - 2,
    { color = "spark", n = 8, speed = 110 })
end

-- Swept contact test for the frame of dash travel. Returns nothing; all
-- effects are applied in place.
function Player:dashImpact(dt, World)
  self.dashHits = self.dashHits or {}
  local travel = self.vx * dt
  local x0 = math.min(self.x, self.x + travel)
  local bw = self.w + math.abs(travel)
  -- A REFLECTOR PANEL is the one thing in the game that answers to
  -- weight and nothing else: no shot moves it, no dome, no standing on
  -- it. This is what the Bulwark plate is FOR -- the charge stops being
  -- a dash and becomes a tool.
  for _, e in ipairs(World.entities) do
    if e.kind == "panel" and not e.dead and not self.dashHits[e]
      and U.aabb(x0, self.y, bw, self.h, e.x, e.y, e.w, e.h) then
      self.dashHits[e] = true
      local moved = false
      if e.rail == "h" then
        moved = e:shove(self.facing)
      else
        -- a vertical rail is shoved by where you hit it: high shoves up
        moved = e:shove(self.y + self.h / 2 < e.y + e.h / 2 and 1 or -1)
      end
      self:bounceOff(moved and "light" or "wall", e.x + e.w / 2, e.y + e.h / 2)
      return
    end
  end
  for _, e in ipairs(World.entities) do
    if e.kind == "enemy" and not e.dead and not e.harmless and not self.dashHits[e]
      and U.aabb(x0, self.y, bw, self.h, e.x, e.y, e.w, e.h) then
      self.dashHits[e] = true
      local m = massOf(e)
      local cxe, cye = e.x + e.w / 2, e.y + e.h / 2
      -- damage / guard-break (Cinder Ram only)
      if G.run.flags.cinderram then
        if e.guardBreak and e:guardBreak(GUARD_BREAK_T) then
          -- the guard shattered; that IS the payload, no damage this hit
          World:fx("burst", cxe, cye, { color = "gold", n = 14, speed = 170 })
          if G.Audio then G.Audio.sfx("guardbreak") end
        else
          e:hurt(RAM_DMG, self.x + self.w / 2, self.y + self.h / 2, { owner = self })
        end
        self.chevT = 0.22
      end
      -- concussion: light bodies only, never bosses
      if m == "light" then
        self:concuss(e)
        if not e.noKnockback then
          e.vx = (e.vx or 0) + self.facing * 150
          e.vy = math.min(e.vy or 0, -90)
        end
      elseif m == "heavy" then
        if not e.noKnockback then e.vx = (e.vx or 0) + self.facing * 55 end
      end
      -- ...and Vess always stops. Always.
      local recoil = m
      if m == "fixed" then recoil = "wall" end
      self:bounceOff(recoil, cxe, cye)
      return
    end
  end
end

-- Called the frame a charge runs out without having hit anything. If we
-- ended up directly above a narrow body while still overlapping it
-- horizontally, carry momentum until clear rather than dropping onto its
-- head -- otherwise the vault is a pixel-perfect check nobody lands.
function Player:tryVault(World)
  for _, e in ipairs(World.entities) do
    if e.kind == "enemy" and not e.dead and not e.harmless and e.w <= VAULT_MAX_W then
      local overlapX = self.x < e.x + e.w and self.x + self.w > e.x
      local clearlyAbove = self.y + self.h <= e.y + 1
      if overlapX and clearlyAbove then
        self.vaultT = VAULT_T
        self.vaultDir = self.facing
        self.vaultOver = e
        return true
      end
    end
  end
  return false
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
  if self.bulwarkT > 0 then self.bulwarkT = self.bulwarkT - dt end
  self:updateEmber(dt, World)
  self:updateSpark(dt, World)
  if self.bounceT > 0 then self.bounceT = self.bounceT - dt end
  if self.chevT > 0 then self.chevT = self.chevT - dt end
  if self.plateFlashT > 0 then self.plateFlashT = self.plateFlashT - dt end
  if self.hitstopT > 0 then self.hitstopT = self.hitstopT - dt end
  if self.dashT <= 0 and self.vaultT <= 0 then self.dashHits = nil end

  if self.downed then
    self:updateDowned(dt, World)
    return
  end

  -- ---- encased: no movement, no weapons, only struggling or a friend
  --
  -- CHECKED BEFORE `idle`, on purpose. A parked bot that gets frozen used
  -- to return above this and never tick: its timer never ran, so swapping
  -- to it handed you a block with the full nine seconds still on it.
  if self.icedT > 0 then
    self.icedT = self.icedT - dt
    -- A BLOCK OF ICE IS STILL A BODY. It falls, and it slides to a stop
    -- rather than stopping dead -- which is what made the knockback do
    -- nothing at all: the shove was applied and then zeroed on the very
    -- next frame, one line down.
    self.vy = math.min((self.vy or 0) + BASE.gravity * dt, BASE.maxFall)
    local fr = BASE.friction * dt
    if self.vx > 0 then self.vx = math.max(0, self.vx - fr)
    else self.vx = math.min(0, self.vx + fr) end
    PH.move(self, self.vx * dt, self.vy * dt)
    if self.onGround then self.vy = 0 end
    self.anim = "idle"
    self.domeActive = false
    self.charging = false
    if self:hasSpark() then self:dropSpark(World, nil) end

    self.icedBite = self.icedBite - dt
    if self.icedBite <= 0 then
      self.icedBite = ICE_TICK
      self:takeDamage(math.max(1, math.ceil((self.maxhp or 12) * ICE_FRAC)),
        nil, { pierceDash = true, cold = true })
    end

    -- A PARTNER WITH FIRE. Touching the block with a spark spends it and
    -- the ice is gone -- which is the whole reason to be carrying one.
    for _, q in ipairs(World.players) do
      if q ~= self and not q.dead and q.hasSpark and q:hasSpark()
        and U.aabb(self.x - 10, self.y - 10, self.w + 20, self.h + 20,
                   q.x, q.y, q.w, q.h) then
        q:dropSpark(World, nil)
        self:thaw(World, true)
        return
      end
    end

    -- ANY slot counts. A frozen bot with no control slot of its own --
    -- the parked one in solo -- could never be mashed free at all.
    for s2 = 1, 2 do
      if slot == s2 or (slot == nil and s2 == 1) then
        for _, a2 in ipairs({ "jump", "fire", "special", "util", "dash" }) do
          if G.Input.pressed(s2, a2) then
            self.icedMash = self.icedMash + 1
            World:fx("spark", self.x + self.w / 2, self.y + 2,
              { color = "ice", n = 4 })
            if G.Audio then G.Audio.sfx("crack") end
          end
        end
      end
    end
    if self.icedMash >= ICE_MASH or self.icedT <= 0 then
      self:thaw(World, false)
    end
    return
  end

  if self.idle then
    -- solo uncontrolled bot: stands still, invulnerable, keeps dome if set
    self:updateIdle(dt, World)
    return
  end

  -- ---- pinned: no movement, no weapons, only struggling
  if self.pinnedT > 0 then
    self.pinnedT = self.pinnedT - dt
    self.vx, self.vy = 0, 0
    self.anim = "idle"
    -- MASH FREE: any action button counts, PIN_MASH presses breaks the grip
    if slot then
      for _, a in ipairs({ "jump", "fire", "special", "util", "dash" }) do
        if G.Input.pressed(slot, a) then
          self.pinnedMash = self.pinnedMash + 1
          World:fx("spark", self.x + self.w / 2, self.y + 2,
            { color = "gold", n = 3 })
        end
      end
    end
    local need = self.pinNeeded or Player.PIN_MASH
    if self.pinnedMash >= need or self.pinnedT <= 0 then
      self:freeFromPin(self.pinnedMash >= need)
    end
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
  if self:hasEmber() then topSpeed = topSpeed * EMBER_SLOW end
  if self:hasSpark() then topSpeed = topSpeed * Cold.CARRY_SLOW end
  topSpeed = topSpeed * self:chillSpeedMult()
  -- icy rooms (the Coldstore): grounded control goes slick
  local icy = self.onGround and not self.inWater
    and World.room and World.room.ice
  local accel = self.onGround and (icy and BASE.accel * 0.28 or BASE.accel)
    or BASE.airAccel

  if self.dashT > 0 then
    self.dashT = self.dashT - dt
    self.vx = self.facing * DASH_SPEED
    self.vy = 0
    -- The plate is live for the whole charge. Contact is resolved BEFORE
    -- the trail and the tile-breaker so that a bounce takes effect on the
    -- same frame it happens.
    if G.run.flags.bulwark then
      self.bulwarkT = math.max(self.bulwarkT, PLATE_HOLD)
      self:dashImpact(dt, World)
    end
    if self.dashT > 0 then
      World:fx("trail", self.x + self.w / 2, self.y + self.h / 2,
        { color = G.run.flags.cinderram and "magma" or "vessred", r = 3, t = 0.18 })
      -- dash breaks breakable tiles ahead
      local tx = math.floor((self.x + self.w / 2 + self.facing * 10) / T)
      local ty0 = math.floor(self.y / T)
      local ty1 = math.floor((self.y + self.h - 1) / T)
      for ty = ty0, ty1 do World:breakTile(tx, ty) end
    elseif self.bounceT <= 0 and G.run.flags.bulwark then
      -- the charge simply ran out. If we finished directly over a narrow
      -- body, carry through rather than dropping onto its head.
      self:tryVault(World)
    end
  elseif self.vaultT > 0 then
    self.vaultT = self.vaultT - dt
    self.vx = self.vaultDir * VAULT_SPEED
    self.vy = 0
    local e = self.vaultOver
    local stillOver = e and not e.dead
      and self.x < e.x + e.w and self.x + self.w > e.x
    if not stillOver then
      self.vaultT = 0
      self.vaultOver = nil
    end
  elseif self.grappling then
    -- handled below
  else
    -- recoil from an impact: reduced authority so the bounce reads as a
    -- bounce instead of being cancelled the frame it starts. Jump is not
    -- locked -- cancelling a bounce upward is the skill expression.
    local auth = self.bounceT > 0 and BOUNCE_AUTHORITY or 1
    if mx ~= 0 then
      self.vx = U.approach(self.vx, mx * topSpeed, accel * auth * dt)
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

  -- ONE STROKE PER PRESS. In water the jump buffer used to re-fire as
  -- fast as the buffer refilled, so holding it was a steady lift and a
  -- deep pool was a lift shaft. A stroke now has a cooldown: you cross
  -- water by spamming the button, and you feel every metre of it.
  if self.strokeCd and self.strokeCd > 0 then
    self.strokeCd = self.strokeCd - dt
  end
  local canStroke = not waterMode or (self.strokeCd or 0) <= 0
  if self.jumpBuf > 0 and (self.coyote > 0 or waterMode) and canStroke then
    self.vy = jumpVel
    self.jumpBuf = 0
    self.coyote = 0
    self.hoverT = 0
    if waterMode then self.strokeCd = STROKE_CD end
    if G.Audio then G.Audio.sfx("jump") end
    World:fx("puff", self.x + self.w / 2, self.y + self.h)
  end
  -- variable jump height
  if not down("jump") and self.vy < -80 and not self.grappling then
    self.vy = -80
  end

  -- ---- Lu hover: hold jump while falling. DRIFT VANES only.
  local wasHovering = self.hovering
  self.hovering = false
  self.inUpdraft = false
  if not self.isVess and G.run.flags.driftvanes and down("jump")
    and not self.onGround and not waterMode then
    local col = World:updraftAt(self)
    if col then
      -- A thermal column. She rises for as long as she holds it, and it
      -- costs no charge -- so a column's height is the designed limit.
      self.inUpdraft = true
      self.hovering = true
      self.vy = math.min(self.vy, -UPDRAFT_LIFT)
      if math.floor(G.time * 26) % 2 == 0 then
        World:fx("trail", self.x + self.w / 2 + U.rand(-5, 5), self.y + self.h,
          { color = "spark", r = 2, t = 0.28 })
      end
    elseif self.vy > 20 and self.hoverT < HOVER_T then
      self.hoverT = self.hoverT + dt
      self.vy = math.min(self.vy, HOVER_FALL)
      self.hovering = true
      if math.floor(G.time * 20) % 2 == 0 then
        World:fx("trail", self.x + self.w / 2 + U.rand(-3, 3), self.y + self.h,
          { color = "cyan", r = 1.5, t = 0.2 })
      end
    end
  end
  if self.hovering then
    if not wasHovering then
      self.vanesT = 0.001
      if G.Audio then G.Audio.sfx("vanes") end
    end
    self.vanesT = math.min(1, (self.vanesT or 0) + dt * 8)
  elseif (self.vanesT or 0) > 0 then
    -- the fins feather closed, and you HEAR it -- which matters when you
    -- are eleven tiles into a twelve-tile gap
    if wasHovering and G.Audio then G.Audio.sfx("vanesout") end
    self.vanesT = math.max(0, self.vanesT - dt * 5)
  end
  if self.onGround then self.hoverT = 0 self.airDashed = false end

  -- ---- gravity
  if self.dashT <= 0 and self.vaultT <= 0 and not self.grappling then
    local grav = waterMode and BASE.waterGravity or BASE.gravity
    if self.inUpdraft then grav = grav * 0.45 end   -- the column is winning
    local maxFall = waterMode and BASE.waterMaxFall or BASE.maxFall
    self.vy = math.min(self.vy + grav * dt, maxFall)
  end

  -- ---- Vess dash / grapple
  if self.isVess then
    if pressed("special") and self.dashCd <= 0 and self.dashT <= 0
      and not self:hasEmber() and not self:hasSpark() then
      -- try grapple first if module owned and anchor in range
      local anchor = G.run.flags.grapple and self:findAnchor(World)
      if anchor then
        self.grappling = anchor
        if G.Audio then G.Audio.sfx("grapple") end
      elseif not self.airDashed or self.onGround then
        self.dashT = 0.2
        self.dashCd = 0.65
        self.dashHits = {}
        self.vaultT = 0
        self.vaultOver = nil
        if G.run.flags.bulwark then
          self.bulwarkT = 0.2 + PLATE_HOLD
          if G.run.flags.cinderram then
            self.chevT = 0.32
            -- ...and it burns hoarfrost off the floor it crosses. This
            -- is Vess's job in the Coldstore and it is deliberately a
            -- HELP rather than a requirement: braziers alone have to be
            -- enough, or a player who took another route through the
            -- game arrives at the Threshold with no way to win.
            if World.frost then
              local tx = math.floor((self.x + self.w / 2) / T)
              Cold.frostBurn(World, tx, Cold.RAM_BURN)
              World:fx("burst", self.x + self.w / 2, self.y + self.h,
                { color = "ember", n = 8, speed = 90 })
            end
          end
        end
        if not self.onGround then self.airDashed = true end
        if G.Audio then
          G.Audio.sfx(G.run.flags.cinderram and "ram" or "dash")
          if G.run.flags.bulwark then G.Audio.sfx("plate") end
        end
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
    if pressed("special") and not self:hasEmber() and not self:hasSpark() then
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
    -- A live dome WAKES a dormant emitter it is touching. This is Lu's
    -- verb in the Crystal Hollows: the machine room is full of hardware
    -- that still works and has had nothing to run it for a century.
    -- Feed the NEAREST dormant emitter in reach, and only that one. The
    -- old loop energized every emitter the dome overlapped on the same
    -- frame, so a two-emitter circuit was one button press; now each
    -- emitter is its own two-second channel and its own half-bar, and
    -- the room in crys_5 that wants two beams genuinely wants two trips.
    -- A live emitter is topped up the same way, but for free.
    self.domeFed = false
    if self.domeActive then
      local dcx, dcy = self.x + self.w / 2, self.y + self.h / 2 - 4
      local best, bestD
      for _, e in ipairs(World.entities) do
        if e.beamEmit and e.dormant and not e.dead then
          local d = U.dist(dcx, dcy, e.x + e.w / 2, e.y + e.h / 2)
          if d < self.domeRadius + 8 then
            -- an unlit emitter always outranks a lit one, so standing
            -- between the two in crys_5 never wastes the channel on the
            -- one that is already burning
            local rank = (e.on and 1e4 or 0) + d
            if not bestD or rank < bestD then best, bestD = e, rank end
          end
        end
      end
      -- anything else in reach must not keep a stale channel alive
      for _, e in ipairs(World.entities) do
        if e.beamEmit and e ~= best and e.cancelCharge then e:cancelCharge() end
      end
      if best then best:energize(self, dt) end
    end
    if self.domeActive then
      -- While the dome is being fed into an emitter the emitter is
      -- already taking WAKE_COST/CHANNEL per second out of the same bar,
      -- so the ordinary upkeep is suspended. Charging costs exactly half
      -- a bar and not a drop more, which is what makes it a number the
      -- harness can hold the game to.
      if not self.domeFed then
        self.energy = self.energy - 11 * dt
        self.energyDelay = 0.9
      end
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
    -- REPAIR PULSE. Every number is a forge tier now, read from
    -- src/upgrades.lua rather than written here -- heal, energy cost,
    -- cooldown and radius all improve together.
    if pressed("util") and self.repairCd <= 0 and not self:hasSpark() then
      local rp = Up.repair()
      if self.energy >= rp.cost then
        self.energy = self.energy - rp.cost
        self.energyDelay = 1
        self.repairCd = rp.cd
        if G.Audio then G.Audio.sfx("repair") end
        for _, pl in ipairs(World.players) do
          if not pl.dead and not pl.downed
            and U.dist(self.x, self.y, pl.x, pl.y) < rp.radius then
            pl:heal(rp.heal)
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
  -- hit-stop: a beat of frozen travel on impact. It is what makes the
  -- bounce feel like it weighed something.
  local moveScale = (self.hitstopT or 0) > 0 and 0 or 1
  PH.move(self, self.vx * dt * moveScale, self.vy * dt * moveScale)
  if self.grappling and (self.hitWall or self.onGround or self.hitCeil) then
    self.grappling = nil
  end
  -- a plated charge into unbreakable tile RECOILS; without the plate it
  -- still just stops dead, exactly as it always has
  if self.dashT > 0 and self.hitWall and G.run.flags.bulwark then
    self:bounceOff("wall", self.x + self.w / 2 + self.facing * 6, self.y + self.h / 2)
  end
  if self.vaultT > 0 and self.hitWall then
    self.vaultT = 0
    self.vaultOver = nil
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
  -- water kills a spark. Nothing else in the zone does, on purpose:
  -- being hit while carrying is already a punishment, and taking the
  -- flame away for it would make the escort's job impossible.
  if self.inWater and self:hasSpark() then
    self:dropSpark(World, "The water takes the spark.")
  end
  self.wasInWater = self.inWater
  -- WATER IS DEADLY TO A BOT THAT IS NOT SEALED.
  --
  -- It used to wait until your HEAD went under and then chip at you.
  -- These are machines: the moment an unsealed one is in the water the
  -- clock is running, whether it is wading or swimming, and treading
  -- water at the surface does not refill anything. HYDRO SEALS are the
  -- difference between a hazard and a route.
  if self.inWater and not G.run.flags.hydroseals then
    self.breath = self.breath - dt
    if self.breath <= 0 then
      self.breath = DROWN_TICK
      -- NO KNOCKBACK. Being shoved around by the water you are drowning
      -- in made the swim unsteerable on top of being lethal.
      self:takeDamage(DROWN_DMG, nil, { pierceDash = true, noKnock = true })
    end
  else
    self.breath = math.min(BREATH_MAX, self.breath + dt * 4)
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

  -- cold rooms (the Coldstore) -- see src/cold.lua
  self:updateChill(dt, World)
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
  -- BULWARK: a plated charge SKIMS a lava surface. Only the surface --
  -- if your centre is in it you are swimming in it, and the plate has
  -- nothing to say about that.
  if self.inLava and self.dashT > 0 and self:plateUp() then
    local mcx = math.floor((self.x + self.w / 2) / T)
    local mcy = math.floor((self.y + self.h / 2) / T)
    if not World:isLava(mcx, mcy) then
      self.inLava = false
      self.vy = math.min(self.vy, -30)
      World:fx("burst", self.x + self.w / 2, self.y + self.h,
        { color = "hotcore", n = 6, speed = 120 })
      self.plateFlashT = 0.1
    end
  end
  if self.inLava then
    -- Lava BURNS now; it does not delete you. 5 damage every quarter
    -- second is twenty a second, so standing in it is still fatal in
    -- about a second at base health -- but a mistimed step is a wound
    -- and a scramble instead of an instant wreck, which is the only way
    -- a floor that floods for a few seconds can be a mechanic rather
    -- than a coin toss.
    --
    -- Note for the validators: scripts/roommodel.py still treats lava as
    -- lethal and will never route through it. That is a deliberate
    -- UNDER-approximation -- the model claims less than the engine
    -- allows, so no completability proof can be made wrong by this.
    self.lavaTick = (self.lavaTick or 0) - dt
    local cx, feet = self.x + self.w / 2, self.y + self.h
    if math.floor(G.time * 20) % 2 == 0 then
      World:fx("trail", cx + U.rand(-5, 5), feet - U.rand(0, 8),
        { color = "hotcore", r = 1.5, t = 0.25, vy = -50 })
    end
    if self.lavaTick <= 0 then
      self.lavaTick = LAVA_TICK
      World:fx("burst", cx, feet, { color = "magma", n = 10, speed = 160 })
      World:fx("burst", cx, feet - 6, { color = "hotcore", n = 6, speed = 120 })
      World:fx("burst", cx, feet - 10, { color = "slate", n = 8, speed = 60 })
      Cam.shake(2, 0.2)
      if G.Audio then G.Audio.sfx("hitenemy") end
      self.invuln = 0
      self:takeDamage(LAVA_DMG, nil, { pierceDash = true, lava = true })
    end
    -- only when it finally finishes you does the wreck get moved, and it
    -- goes to ground that is safe NOW, not ground that was safe once:
    -- the Crucible floods its own floor, so the tile you were standing
    -- on a second ago is the lava you are dying in, and sending the
    -- wreck back there kills it again, and again, forever.
    if self.downed or self.dead or self.hp <= 0 then
      local sx, sy = self.safeX, self.safeY
      if sx and self.safeRoom ~= (World.room and World.room.id) then sx = nil end
      if sx and not World:dropLegal(sx, sy, self.w, self.h) then sx = nil end
      if not sx and World.settleDrop then
        sx, sy = World:settleDrop(self.x, self.y, self.w, self.h)
        if not World:dropLegal(sx, sy, self.w, self.h) then sx = nil end
      end
      if sx then
        self.x, self.y = sx, sy
        self.safeX, self.safeY = sx, sy
        self.inLava = false
        self.vx, self.vy = 0, 0
      else
        self.vy = -240
      end
    end
  else
    self.lavaTick = 0
  end
  self:checkSpikes(World)

  -- enemy contact damage
  if self.invuln <= 0 and self.dashT <= 0 then
    for _, e in ipairs(World.entities) do
      -- a concussed body cannot hurt you: standing on one is safe, which
      -- is half the point of concussing it
      if e.kind == "enemy" and not e.dead and e.touchDmg and e.touchDmg > 0
        and not e.harmless and (e.stunT or 0) <= 0
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
  -- The arrival grace stops a door you just came out of from firing again.
  -- For an EDGE door that has to hold, because edge doors trigger on touch.
  -- A PORTAL needs a deliberate button press, so a deliberate press should
  -- always be honoured -- otherwise a portal that opens into a pocket no
  -- bigger than the doorway is inescapable: the grace clears only once you
  -- get 12px clear of the door, and in a pocket that IS the door you never
  -- can. (deep_stair_1's door E is exactly that shape.)
  if ch and not World:doorSealed(d) then
    if d.edge then
      if ch ~= self.doorGrace then World:requestTransition(ch) end
    else
      self.atPortalDoor = true
      if (pressed("interact") or pressed("up")) and not self.interactedThisFrame then
        self.doorGrace = nil
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
        self:takeDamage(14, tx * T + 8, { pierceDash = true })
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

-- ------------------------------------------------------------------
-- THE EMBER
-- ------------------------------------------------------------------
-- Which bot is holding it lives in the RUN, not on the player object, so
-- it survives a room change, a save and a bot swap.
function Player:hasEmber()
  return G.run and G.run.emberCarrier == self.idx
end

function Player:takeEmber()
  if not G.run then return end
  G.run.emberCarrier = self.idx
  G.run.emberT = 0
end

-- Anything that comes near is torched. Small bodies are simply gone --
-- the same treatment a beam gives them -- and anything too heavy to
-- vaporise burns instead, so a boss is discouraged rather than deleted.
function Player:updateEmber(dt, World)
  if not self:hasEmber() then
    self.emberGlow = nil
    return
  end
  G.run.emberT = (G.run.emberT or 0) + dt
  self.emberGlow = (self.emberGlow or 0) + dt
  self.lightR = math.max(self.lightR or 0, EMBER_LIGHT)

  self.emberTick = (self.emberTick or 0) - dt
  local tick = self.emberTick <= 0
  if tick then self.emberTick = EMBER_AURA_TICK end

  local cx, cy = self.x + self.w / 2, self.y + self.h / 2
  for _, e in ipairs(World.entities) do
    if e.kind == "enemy" and not e.dead and not e.harmless then
      local ex, ey = e.x + e.w / 2, e.y + e.h / 2
      if U.dist(cx, cy, ex, ey) < EMBER_AURA_R + math.max(e.w, e.h) / 2 then
        if not e.heavy and not e.isBoss then
          World:fx("burst", ex, ey, { color = "ember", n = 12, speed = 150 })
          e.hp = 0
          if e.onDeath then e:onDeath() end
          e.dead = true
          if G.Audio then G.Audio.sfx("hitenemy") end
        elseif tick then
          e:hurt(EMBER_AURA_DMG, cx, cy, { ember = true, owner = self })
          World:fx("spark", ex, ey, { color = "ember", n = 4 })
        end
      end
    end
  end
  -- embers coming off it
  self.emberFx = (self.emberFx or 0) - dt
  if self.emberFx <= 0 then
    self.emberFx = 0.05
    local a = U.rand(0, math.pi * 2)
    local r = EMBER_AURA_R * U.rand(0.5, 1)
    World:fx("trail", cx + math.cos(a) * r, cy + math.sin(a) * r,
      { color = U.choose({ "ember", "gold", "magma" }), r = 2, t = 0.4,
        vx = U.rand(-8, 8), vy = U.rand(-26, -10) })
  end
end

-- The shard itself, held out in front of the chest, and the ring of fire
-- that keeps the room off you.
function Player:drawEmber(g)
  if not self:hasEmber() then return end
  local cx = self.x + self.w / 2 + self.facing * 5
  local cy = self.y + self.h / 2 - 1
  local beat = 0.82 + math.sin(G.time * 3.1) * 0.12
    + math.sin(G.time * 9.7) * 0.06

  -- the ring: two rotating arcs of fire rather than a plain circle, so it
  -- reads as burning rather than as a selection marker
  for i = 0, 1 do
    local a0 = G.time * (1.4 + i * 0.7) + i * math.pi
    g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.30 * beat)
    g.setLineWidth(3)
    g.arc("line", "open", cx, cy, EMBER_AURA_R, a0, a0 + math.pi * 0.8)
    g.setLineWidth(1)
  end
  g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.16 * beat)
  g.circle("fill", cx, cy, EMBER_AURA_R * 0.9)

  -- the shard: a tall four-point crystal, white at the core
  local hh = 11 * beat
  g.setColor(P.ember)
  g.polygon("fill", cx, cy - hh, cx + 5, cy, cx, cy + hh * 0.7, cx - 5, cy)
  g.setColor(P.gold)
  g.polygon("fill", cx, cy - hh * 0.8, cx + 3, cy, cx, cy + hh * 0.5, cx - 3, cy)
  g.setColor(1, 1, 1, 0.85 * beat)
  g.polygon("fill", cx, cy - hh * 0.5, cx + 1.4, cy, cx, cy + hh * 0.3, cx - 1.4, cy)
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- CHILL
-- ------------------------------------------------------------------
-- The Coldstore's gate is not a locked door, it is the air. You walk
-- in without Cryo Coils, the edges of the screen go white, and about
-- four seconds later you are down. That explains itself in a way a
-- locked door never does.
--
-- With the Coils fitted the same air is survivable and never
-- comfortable: the meter still fills, it just fills slowly enough to
-- cross a room and reach the next fire. The Coils are not immunity.
-- They are a longer breath.
--
-- The meter does NOT reset at a door. Carrying it between rooms is what
-- makes the zone about routes instead of about rooms.
function Player:updateChill(dt, World)
  local cold = World.room and World.room.cold
  local cx, cy = self.x + self.w / 2, self.y + self.h / 2

  -- a spark in your hands is a fire in your hands
  local warm = self:hasSpark() and true or false
  if not warm and cold then
    warm = Cold.heatAt(World, cx, cy) ~= nil
  end

  -- STANDING ON HOARFROST is worse than breathing the air, and the
  -- Coils have nothing to say about it. That is the zone telling you,
  -- in the one language it has, to get off the ice.
  local onIce = Cold.onFrost(World, self)
  if onIce and not warm then
    self.chill = math.min(Cold.CHILL_MAX, self.chill + Cold.FROST_FILL * dt)
  elseif cold and not warm then
    local rate = G.run.flags.cryocoils and Cold.FILL_COILED or Cold.FILL_BARE
    self.chill = math.min(Cold.CHILL_MAX, self.chill + rate * dt)
  else
    self.chill = math.max(0, self.chill - Cold.DRAIN * dt)
  end

  if self.chill >= Cold.CHILL_MAX then
    self.chillBite = self.chillBite - dt
    if self.chillBite <= 0 then
      self.chillBite = Cold.BITE_TICK
      -- a fraction of MAX HP, so the countdown is the same length at
      -- every tier instead of instant at base and survivable when maxed
      local dmg = math.max(Cold.BITE_MIN,
        math.ceil((self.maxhp or 12) * Cold.BITE_FRAC))
      self:takeDamage(dmg, nil, { pierceDash = true, cold = true })
      if World.fx then
        World:fx("spark", cx, cy, { color = "ice", n = 5 })
      end
    end
  else
    self.chillBite = 0
  end
  if self.chilledT > 0 then self.chilledT = self.chilledT - dt end
end

-- How much the cold has taken out of your legs, 1 = untouched.
function Player:chillSpeedMult()
  if self.chill <= Cold.SLOW_AT then return 1 end
  local t = (self.chill - Cold.SLOW_AT) / (Cold.CHILL_MAX - Cold.SLOW_AT)
  return 1 - (1 - Cold.SLOW_MIN) * math.min(1, t)
end

-- ------------------------------------------------------------------
-- THE SPARK
-- ------------------------------------------------------------------
-- Fire spreads one way in this zone: somebody carries it. Which bot is
-- holding it lives in the RUN for the same reason the Ember does -- it
-- has to survive a room change and a bot swap.
function Player:hasSpark()
  return G.run and G.run.sparkCarrier == self.idx
    and (G.run.sparkT or 0) > 0
end

function Player:takeSpark()
  if not G.run then return end
  G.run.sparkCarrier = self.idx
  G.run.sparkT = Cold.SPARK_BURN
  if G.Audio then G.Audio.sfx("emitter") end
end

function Player:dropSpark(World, why)
  if not self:hasSpark() then return end
  G.run.sparkCarrier = nil
  G.run.sparkT = 0
  if World and World.fx then
    World:fx("burst", self.x + self.w / 2, self.y + self.h / 2,
      { color = "ember", n = 10, speed = 60 })
  end
  if G.Audio then G.Audio.sfx("domeoff") end
  if why and G.game then G.game:announce(why, 1.6) end
end

function Player:updateSpark(dt, World)
  if not self:hasSpark() then
    self.sparkFx = nil
    return
  end
  G.run.sparkT = math.max(0, (G.run.sparkT or 0) - dt)
  self.lightR = math.max(self.lightR or 0, Cold.SPARK_LIGHT)

  if G.run.sparkT <= 0 then
    -- Nothing punishes you but the walk. Chill starts filling and you
    -- head back to the last brazier you lit -- which is the whole
    -- reason the chain behind you matters.
    self:dropSpark(World, "The spark gutters out.")
    return
  end

  -- IT MELTS WHAT YOU WALK OVER. A bot carrying fire across a frozen
  -- floor leaves a thawed line behind it -- which is the whole reason
  -- the carry is worth the gun you gave up for it.
  self.sparkMelt = (self.sparkMelt or 0) - dt
  if self.sparkMelt <= 0 and World.frost then
    self.sparkMelt = Cold.SPARK_MELT_T
    local tx = math.floor((self.x + self.w / 2) / T)
    if Cold.frostBurn(World, tx, Cold.SPARK_MELT) > 0 then
      World:fx("spark", self.x + self.w / 2, self.y + self.h,
        { color = "ember", n = 3 })
    end
  end

  -- embers coming off the hand
  self.sparkFx = (self.sparkFx or 0) - dt
  if self.sparkFx <= 0 then
    self.sparkFx = 0.09
    World:fx("trail", self.x + self.w / 2 + self.facing * 5, self.y + 3,
      { color = U.choose({ "ember", "gold" }), r = 1, t = 0.35,
        vx = U.rand(-6, 6), vy = U.rand(-22, -8) })
  end
end

-- A small flame held out in front, and it visibly runs down.
function Player:drawSpark(g)
  if not self:hasSpark() then return end
  local t = (G.run.sparkT or 0) / Cold.SPARK_BURN
  local cx = self.x + self.w / 2 + self.facing * 5
  local cy = self.y + 3
  local low = (G.run.sparkT or 0) <= Cold.SPARK_LOW
  local beat = 0.75 + math.sin(G.time * (low and 14 or 5)) * (low and 0.25 or 0.12)
  local hh = (3 + 5 * t) * beat

  g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.18 * beat)
  g.circle("fill", cx, cy, Cold.SPARK_LIGHT * 0.22)
  g.setColor(P.ember)
  g.polygon("fill", cx, cy - hh, cx + 2.5, cy + 1, cx, cy + 2.5, cx - 2.5, cy + 1)
  g.setColor(P.gold)
  g.polygon("fill", cx, cy - hh * 0.6, cx + 1.4, cy + 1, cx, cy + 1.6, cx - 1.4, cy + 1)
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- EVERY SHOT CARRIES THE SHOT'S MOMENTUM
-- ------------------------------------------------------------------
-- A bot running at full tilt throws further than a bot standing still,
-- and a bot sprinting backwards throws shorter. It costs one line and
-- it makes movement matter to every weapon in the game rather than to
-- none of them.
--
-- It goes through ONE function on purpose. updateFire has five spawn
-- sites -- lance, mortar, radial, pellets, and the ordinary case -- and
-- adding `+ self.vx` to four of them is exactly the hand-written list
-- that this project keeps getting wrong. shoot_test asserts that
-- updateFire contains no bare Proj.spawn at all.
--
-- Horizontal is inherited in full. VERTICAL is not: terminal fall is
-- 300px/s against a bolt's 300, so a full share would point every shot
-- taken in mid-air at the floor. A third reads as weight without
-- taking the aim away.
local MOMENTUM_X = 1.0
local MOMENTUM_Y = 0.33

function Player:shoot(World, x, y, cfg)
  cfg.vx = (cfg.vx or 0) + (self.vx or 0) * MOMENTUM_X
  cfg.vy = (cfg.vy or 0) + (self.vy or 0) * MOMENTUM_Y
  return Proj.spawn(World, x, y, cfg)
end

function Player:updateFire(dt, World, slot, down, pressed)
  -- both hands are full
  if self:hasEmber() or self:hasSpark() then return end
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
        self:shoot(World, mx, my, {
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
      -- Magnet Mortar: a lobbed shell on a gravity arc that bounces off
      -- what it hits and rolls along what it lands on. Every number is
      -- in weapons.lua so the weapon can be retuned without reading this.
      self:shoot(World, mx, my, {
        side = "player", dmg = def.dmg[lvl], owner = self,
        vx = dx * def.speed,
        vy = -195 + math.min(0, dy) * 130,
        kind = def.visual, size = def.size, gravity = 640,
        life = def.life or 2.4, bounces = def.bounces,
        restitution = def.restitution, rolls = def.rolls,
      })
      self.vx = self.vx - dx * 45
      Cam.shake(0.8, 0.08)
    elseif def.radial then
      -- Pulse Bloom: a ring of pulses around Lu; works with the dome up
      local n = def.radial[lvl]
      local cx, cy = self.x + self.w / 2, self.y + self.h / 2 - 2
      for i = 1, n do
        local ang = (i / n) * math.pi * 2 + G.time
        self:shoot(World, cx, cy, {
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
        self:shoot(World, mx, my, {
          side = "player", dmg = def.dmg[lvl], owner = self,
          vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
          kind = def.visual, size = def.size, life = def.life,
        })
      end
      self.vx = self.vx - dx * 40
    else
      self:shoot(World, mx, my, {
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

  -- the Ember goes UNDER the bot, so the sprite reads as holding it
  self:drawEmber(g)
  self:drawSpark(g)
  self:drawIce(g)

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

  -- STRUGGLE METERS. Every mash-out in the game shows the same bar in
  -- the same place, so a player does not have to learn a second
  -- language for the same verb. The ice used to show only cracks, which
  -- nobody reads as a meter.
  local mashFrac
  if self.pinnedT > 0 then
    mashFrac = math.min(1, self.pinnedMash / (self.pinNeeded or Player.PIN_MASH))
  elseif (self.icedT or 0) > 0 then
    mashFrac = math.min(1, (self.icedMash or 0) / ICE_MASH)
  end
  if mashFrac then
    local cx = self.x + self.w / 2
    local by = self.y - 10
    g.setColor(P.black[1], P.black[2], P.black[3], 0.7)
    g.rectangle("fill", cx - 11, by, 22, 4)
    g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.5 + math.sin(G.time * 20) * 0.3)
    g.rectangle("fill", cx - 10, by + 1, 20 * mashFrac, 2)
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

  -- ---- the DRIFT VANES: four fins that snap open when the hover engages
  -- and feather closed when it runs out, plus a depletion arc for the last
  -- of the charge. The END of a hover is the thing worth telegraphing.
  if (self.vanesT or 0) > 0 and not self.isVess then
    local o = self.vanesT
    local cx, cy = self.x + self.w / 2, self.y + self.h / 2
    local col = self.inUpdraft and P.spark or P.cyan
    g.setColor(col[1], col[2], col[3], 0.35 + o * 0.5)
    for _, fin in ipairs({ { -1, -2, 7 }, { 1, -2, 7 }, { -1, 6, 5 }, { 1, 6, 5 } }) do
      local sx, fy, len = fin[1], fin[2], fin[3]
      local spread = 2 + o * len
      g.setLineWidth(1.5)
      g.line(cx + sx * 4, cy + fy, cx + sx * (4 + spread), cy + fy + spread * 0.45)
      g.setLineWidth(1)
    end
    -- charge remaining. Absent in a thermal column, which costs nothing.
    if not self.inUpdraft and self.hovering then
      local frac = 1 - self.hoverT / HOVER_T
      if frac < 0.35 then
        g.setColor(P.spark[1], P.spark[2], P.spark[3],
          0.55 + math.sin(G.time * 22) * 0.35)
        g.arc("line", "open", cx, self.y - 7, 5,
          -math.pi / 2, -math.pi / 2 + math.pi * 2 * math.max(0, frac / 0.35))
      end
    end
    g.setColor(1, 1, 1, 1)
  end

  -- ---- the Bulwark plate: a hard-edged wedge AHEAD of Vess. It must read
  -- as directional at a glance, because the back being open is a rule the
  -- player is expected to learn and use.
  if self:plateUp() then
    local f = self.facing
    local cx = self.x + self.w / 2
    local cy = self.y + self.h / 2
    local live = math.min(1, (self.bulwarkT or 0) / PLATE_HOLD)
    local reach = 9 + live * 2
    local half = 9
    local flash = (self.plateFlashT or 0) > 0
    g.push() g.translate(cx, cy) g.scale(f, 1)
    -- body of the wedge
    g.setColor(P.vessred[1], P.vessred[2], P.vessred[3], 0.30 + live * 0.14)
    g.polygon("fill", 2, -half, reach, -half + 3, reach, half - 3, 2, half)
    -- the lip: the bit that actually stops things
    g.setColor(flash and P.white or P.vesslite)
    g.setLineWidth(flash and 2 or 1)
    g.line(reach, -half + 3, reach, half - 3)
    g.setLineWidth(1)
    -- ...and the fiery chevrons, once the charge is an attack
    if G.run.flags.cinderram and (self.chevT or 0) > 0 then
      local ig = math.min(1, (self.chevT or 0) / 0.22)
      local strobe = 0.65 + 0.35 * math.sin(G.time * 36)
      local cols = { P.magma, P.hotcore, P.cream }
      for i = 1, 3 do
        local ox = 3 + i * 4.5
        local sc = 1 - (i - 1) * 0.18
        local c = cols[i]
        g.setColor(c[1], c[2], c[3], ig * strobe * (1 - (i - 1) * 0.2))
        g.setLineWidth(1.5)
        g.line(ox - 3, -6 * sc, ox, 0, ox - 3, 6 * sc)
        g.setLineWidth(1)
      end
    end
    g.pop()
    g.setColor(1, 1, 1, 1)
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
  -- the bar is BREATH_MAX wide and shows from the first frame under: the
  -- meter is the warning now, because the grace is short enough that a
  -- meter appearing late is a meter you never see
  if self.inWater and not G.run.flags.hydroseals then
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.9)
    local bw = 14 * math.max(0, math.min(1, self.breath / BREATH_MAX))
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
  -- cold warning. Fills rather than empties, and it is shown to a
  -- coiled bot too -- the Coils buy time, they do not buy immunity, and
  -- a player who thinks they are immune finds out at the worst moment.
  if self.chill > 0.02 then
    local full = self.chill >= Cold.CHILL_MAX
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.55)
    g.rectangle("fill", self.x + self.w / 2 - 7, self.y - 11, 14, 2)
    if full then
      g.setColor(1, 1, 1, 0.6 + math.sin(G.time * 12) * 0.4)
    else
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.9)
    end
    g.rectangle("fill", self.x + self.w / 2 - 7, self.y - 11,
      14 * (self.chill / Cold.CHILL_MAX), 2)
    g.setColor(1, 1, 1, 1)
  end
end

Player.BASE = BASE
return Player
