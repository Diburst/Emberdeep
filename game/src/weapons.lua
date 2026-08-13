-- Weapon definitions. Vess finds boltdriver/scatterhex/arclance;
-- Lu has sparkshot. XP thresholds per level; getting hit loses XP.
local W = {}

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
    rate = { 0.17, 0.14, 0.12 }, speed = 270, visual = "spark", size = 4,
    dmg = { 1, 2, 2 }, homing = { nil, nil, 3.5 }, thresholds = { 12, 28 },
    sfx = "shoot4",
  },
  magnetmortar = {
    name = "Magnet Mortar", icon = "icon_bolt", user = 1,
    rate = 0.95, speed = 190, visual = "orb", size = 7,
    dmg = { 8, 12, 16 }, mortar = true, thresholds = { 15, 35 },
    sfx = "shoot2",
  },
}

function W.get(id) return W.defs[id] end

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
