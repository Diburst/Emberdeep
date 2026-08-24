-- Weapon definitions. Vess finds boltdriver/scatterhex/arclance;
-- Lu has sparkshot. XP thresholds per level; getting hit loses XP.
local W = {}

-- HOW FAR AN ORDINARY SHOT CARRIES, in seconds of flight.
--
-- Vess's guns used to inherit projectile.lua's generic 2s, which at Bolt
-- Driver speed is 620px -- more than a screen and a quarter. A gun that
-- reaches past anything you can see has no range as a property at all,
-- so positioning stops mattering and every fight is fought at whatever
-- distance you happen to be standing.
--
-- Applied in W.tune to every `user = 1` weapon that does not state its
-- own, so a weapon with a deliberate lifetime keeps it -- Scatter Hex is
-- a 0.32s shotgun and the Magnet Mortar's 4.8s roll is the entire point
-- of the Magnet Mortar -- and a future Vess gun inherits the rule
-- instead of inheriting the generic default by accident.
W.SHOT_LIFE = 1.2

W.defs = {
  boltdriver = {
    name = "Bolt Driver", icon = "icon_bolt", user = 1,
    rate = 0.22, speed = 310, visual = "bolt", size = 5,
    dmg = { 2, 3, 5 }, pierce = { 0, 0, 1 }, thresholds = { 10, 25 },
    sfx = "shoot1",
  },
  scatterhex = {
    name = "Scatter Hex", icon = "icon_scatter", user = 1,
    rate = 0.55, speed = 260, visual = "pellet", size = 4,
    dmg = { 2, 3, 4 }, pellets = { 3, 4, 5 }, life = 0.32,
    spread = 0.30, thresholds = { 12, 30 },
    sfx = "shoot2",
  },
  arclance = {
    name = "Arc Lance", icon = "icon_lance", user = 1,
    rate = 0.4, speed = 460, visual = "lance", size = 6,
    dmg = { 6, 9, 14 }, pierce = { 2, 3, 6 }, charge = 0.7,
    tapdmg = 3, thresholds = { 15, 35 },
    sfx = "shoot3",
  },
  pulsebloom = {
    name = "Pulse Bloom", icon = "icon_spark", user = 2,
    rate = 0.8, speed = 150, visual = "spark", size = 5,
    dmg = { 2, 3, 4 }, radial = { 8, 10, 12 }, life = 0.22,
    thresholds = { 12, 28 },
    sfx = "shoot4",
  },
  sparkshot = {
    name = "Spark Shot", icon = "icon_spark", user = 2,
    -- luTuned: these three rates are SOLVED at load from Vess's best DPS
    -- at each tier (see W.tune). They are written out here so the file
    -- still reads as a weapon definition and so a change in the solver
    -- shows up as a diff against a number a human once agreed to.
    rate = { 0.167, 0.109, 0.138 }, luTuned = true,
    speed = 270, visual = "spark", size = 4,
    -- {1,1,2} is the only integer array where every tier is an upgrade
    -- you can feel: L2 is a FIRE-RATE upgrade, L3 is a DAMAGE upgrade.
    dmg = { 1, 1, 2 }, homing = { nil, nil, 3.5 }, thresholds = { 12, 28 },
    sfx = "shoot4",
  },
  magnetmortar = {
    name = "Magnet Mortar", icon = "icon_bolt", user = 1,
    rate = 0.95, speed = 190, visual = "orb", size = 7,
    dmg = { 8, 12, 16 }, mortar = true, thresholds = { 15, 35 },
    sfx = "shoot2",
    -- A shell that bounces off the walls and then RUNS along the floor.
    -- The lifetime is doubled (2.4 -> 4.8) because a roll that expires
    -- after two seconds is a lob with extra steps; the whole appeal is
    -- putting a shell somewhere you cannot see and having it arrive.
    -- Situationally very strong in a corridor, useless in the open --
    -- which is the trade.
    life = 4.8, bounces = 3, restitution = 0.45, rolls = true,
  },
}

function W.get(id) return W.defs[id] end

-- ------------------------------------------------------------------
-- TIER SMOOTHING, AND LU HUNG OFF VESS AT A FIXED RATIO
-- (COOP-PLAN 10.1 / 10.2)
-- ------------------------------------------------------------------
-- Two constants. Everything else is SOLVED from them at load. Hardcode
-- Lu's numbers instead and the ratio becomes a lie the first time any
-- Vess weapon is retuned -- silently, with nothing to catch it.
W.LU_DPS_RATIO = 0.40   -- Lu's share of Vess's BEST dps, per tier
W.TIER_SMOOTH  = true   -- re-derive L2 as the geometric mean of L1 and L3
W.TIERS = 3

-- Simultaneous hits on ONE target.
--
-- Pellets count: a scatter cone all lands at close range, which is where
-- the weapon is used. Radial deliberately does NOT -- Pulse Bloom throws
-- a ring outward and at most one arm of it points at anybody, so pricing
-- it at 8x would make it the strongest gun in the game on paper and
-- nerf it into uselessness in the hand.
local function hitsAt(def, lvl)
  return (def.pellets and def.pellets[lvl]) or 1
end

-- rate is a scalar on the hand-authored Vess weapons and a 3-array after
-- W.tune normalises it; every caller must go through this.
function W.rateAt(def, lvl)
  local r = def.rate
  if type(r) == "table" then return r[lvl] end
  return r
end

-- Single-target damage per second, ignoring charge time (arclance's 0.7s
-- wind-up is a handling cost, not a throughput one, and the numbers this
-- was tuned against were computed without it).
function W.dps(def, lvl)
  local r = W.rateAt(def, lvl)
  if not r or r <= 0 or not def.dmg or not def.dmg[lvl] then return 0 end
  return def.dmg[lvl] * hitsAt(def, lvl) / r
end

function W.tune(force)
  if W.tuned and not force then return end

  -- 1. Every Vess weapon gets a per-tier rate array so L2 can move,
  --    and a RANGE if it has not asked for its own.
  for _, def in pairs(W.defs) do
    if def.user == 1 then
      if type(def.rate) ~= "table" then
        def.rate = { def.rate, def.rate, def.rate }
      end
      def.life = def.life or W.SHOT_LIFE
    end
  end

  -- 2. Smooth: L1 and L3 are authored states worth keeping (the weapon
  --    as found, and the weapon fully forged). L2 was the only number
  --    that was ever arbitrary, so it is the only one that moves.
  --    scatterhex was the outlier -- it DOUBLED at L2 and then grew
  --    x1.67, and that single step was most of the lumpiness.
  if W.TIER_SMOOTH then
    for _, def in pairs(W.defs) do
      if def.user == 1 then
        local d1, d3 = W.dps(def, 1), W.dps(def, 3)
        if d1 > 0 and d3 > 0 then
          def.rate[2] = def.dmg[2] * hitsAt(def, 2) / math.sqrt(d1 * d3)
        end
      end
    end
  end

  -- 3. Vess's best dps at each tier -- what Lu is measured against.
  W.vessBest = {}
  for t = 1, W.TIERS do
    local best = 0
    for _, def in pairs(W.defs) do
      if def.user == 1 then best = math.max(best, W.dps(def, t)) end
    end
    W.vessBest[t] = best
  end

  -- 4. Solve the rate of every luTuned weapon. Damage stays an integer
  --    array (it is what the player sees in a hit); rate carries the
  --    fractional remainder.
  for _, def in pairs(W.defs) do
    if def.luTuned then
      if type(def.rate) ~= "table" then
        def.rate = { def.rate, def.rate, def.rate }
      end
      for t = 1, W.TIERS do
        local target = W.vessBest[t] * W.LU_DPS_RATIO
        if target > 0 and def.dmg[t] then
          def.rate[t] = def.dmg[t] * hitsAt(def, t) / target
        end
      end
    end
  end

  W.tuned = true
end

W.tune()

-- v2.0: weapon level = FORGE TIER, bought from Brassa with scrap.
-- (The old shard-XP auto-leveling is gone; shards are scrap now.)
function W.forge()
  if not G.run then return nil end
  if not G.run.forge then
    G.run.forge = { boltdriver = 1, scatterhex = 1, arclance = 1,
                    sparkshot = 1, pulsebloom = 1, magnetmortar = 1,
                    dome = 1, hpTier = 0, energyTier = 0 }
  end
  return G.run.forge
end

function W.levelOf(wstate)
  local f = W.forge()
  return (f and f[wstate.id]) or 1
end

return W
