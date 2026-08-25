-- ==================================================================
-- THE ECONOMY. Every scrap cost and every benefit, in one place.
--
-- These numbers used to be scattered across four files: the costs and
-- the tier caps lived in states/forge.lua, the health-per-tier was a
-- bare `+ 4` inside the forge's purchase handler AND a `12 + tier * 4`
-- in states/testchamber.lua AND another in save.lua's migration, and
-- the dome's benefit was an anonymous `{ 2.2, 1.6, 1.0 }` in the middle
-- of player.lua. Tuning the economy meant finding all of them and
-- getting every copy right.
--
-- So: one file, and everything else reads from it. tools/economy_test.lua
-- fails the build if a raw number reappears anywhere else.
--
-- HOW TO TUNE
--   COST.*        what a tier costs in scrap
--   HP_PER_TIER   health a LIFE CAPSULE tier is worth
--   EN_PER_TIER   energy an ENERGY TANK tier is worth
--   DOME_DRAIN    Lu's shield drain multiplier per tier (lower is better)
--   REPAIR        Lu's repair pulse per tier
-- ==================================================================
local Up = {}

-- ------------------------------------------------------------------
-- COSTS, in scrap. Doubled from the originals: the old prices meant a
-- normal route through a zone paid for most of a tree, so the forge was
-- a formality rather than a choice about what to give up.
-- ------------------------------------------------------------------
Up.COST = {
  -- cost to REACH tier 2 / tier 3 of a weapon (index 1 is unused: you
  -- start at tier 1)
  --
  -- Raised 50% on top of the doubling (Thomas, Aug 2026): 25/60 -> 50/120
  -- -> 75/180, so a weapon tier is now THREE times its original price
  -- while the rest of the forge stays at two. Weapons are the track
  -- everybody buys first and the one that most changes how a fight goes;
  -- the point of the forge is choosing what to give up, and a weapon
  -- line that a zone's scrap pays for on its own is not a choice.
  weapon = { nil, 75, 180 },
  -- Lu's dome
  dome = { nil, 60, 140 },
  -- health and energy scale with how many you already own, so the tenth
  -- one is a real decision rather than loose change
  hp = function(tier) return 30 + (tier - 1) * 20 end,
  energy = function(tier) return 40 + (tier - 1) * 30 end,
  -- Lu's repair pulse. Deliberately the most expensive line in the
  -- forge: a party heal on a short cooldown is the single strongest
  -- thing scrap can buy, and it should cost like it.
  repairPulse = { nil, 90, 200 },
}

-- ------------------------------------------------------------------
-- CAPS. hp and energy tiers are additionally gated by LIFE CAPSULES and
-- ENERGY TANKS found in the world -- scrap alone never buys them.
-- ------------------------------------------------------------------
Up.MAX = {
  weapon = 3,
  dome = 3,
  hp = 8,
  energy = 4,
  repairPulse = 3,
}

-- ------------------------------------------------------------------
-- BENEFITS
-- ------------------------------------------------------------------
Up.BASE_HP = 12
Up.BASE_ENERGY = 100

-- Was 4. A capsule tier is worth less now, so eight of them is +24
-- rather than +32 -- the difference between a late-game bot that can
-- eat a boss pattern and one that still has to dodge it.
Up.HP_PER_TIER = 3
Up.EN_PER_TIER = 20

-- Lu's dome: energy drained per point of damage absorbed. Lower is
-- better, and tier 1 is the unupgraded default.
Up.DOME_DRAIN = { 2.2, 1.6, 1.0 }

-- Lu's repair pulse, per tier. Tier 1 is what she starts with, so the
-- first row here is the current behaviour and the upgrades buy a
-- bigger heal on a shorter cooldown for less energy.
Up.REPAIR = {
  { heal = 4, cost = 25, cd = 2.2, radius = 52 },
  { heal = 7, cost = 22, cd = 1.8, radius = 62 },
  { heal = 11, cost = 18, cd = 1.4, radius = 74 },
}

-- ------------------------------------------------------------------
-- Readers. Everything outside this file goes through these, so a tier
-- that is missing, nil or out of range degrades to the base value
-- instead of erroring in the middle of a fight.
-- ------------------------------------------------------------------
local function forge()
  return (G.run and G.run.forge) or {}
end

function Up.maxHp(tier)
  tier = tier or forge().hpTier or 0
  return Up.BASE_HP + tier * Up.HP_PER_TIER
end

function Up.maxEnergy(tier)
  tier = tier or forge().energyTier or 0
  return Up.BASE_ENERGY + tier * Up.EN_PER_TIER
end

function Up.domeDrain(tier)
  tier = tier or forge().dome or 1
  return Up.DOME_DRAIN[tier] or Up.DOME_DRAIN[1]
end

function Up.repair(tier)
  tier = tier or forge().repairPulse or 1
  return Up.REPAIR[tier] or Up.REPAIR[1]
end

-- cost to reach `tier` of a given track, or nil if it is not buyable
function Up.cost(track, tier)
  local c = Up.COST[track]
  if type(c) == "function" then return c(tier) end
  return c and c[tier] or nil
end

return Up
