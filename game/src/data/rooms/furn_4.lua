-- THE POURING HALL. Two crucibles hang over this floor and tip on their
-- own clocks, long before the boss asks you to handle three at once.
--
-- The floor is two shallow BASINS -- row 12 is open at cols 6..28 and
-- 42..52 and solid everywhere else -- so the middle of each stretch sits
-- a tile below its ends. A pour crawls outward from the spout at one
-- tile per half second and stops dead at that higher ground, which makes
-- stepping up onto the banks the first and most obvious answer. It is
-- the same shape as the arena floor, at a fifth of the scale.
--
-- Deliberately gentler than the arena -- a 2-second dwell instead of 6,
-- a basin a fifth the width, and banks one step up instead of a climb --
-- but on a much tighter clock, because a lesson you wait half a minute
-- for is not a lesson. Neither pour can reach the vault
-- machine, the heat-plating chest, or either door. The landings at row 10
-- sit three rows above the basin -- a plain jump, no modules -- directly
-- under their pot, so the other answer, shoot it out, is one held UP
-- away.
return {
  zone = "furnace", music = "furnace",
  mapPos = { x = 8, y = 2, w = 3, h = 1 },
  gates = { G = "furnvault", H = "heatplating" },
  map = [[
############################################################
############################################################
##....................................................H...##
##..................p............................q....H...##
##....................................................H...##
##....................................................H...##
##............w..........................9............H...##
##..........=======.................#########.........H...##
##..................................G.......#.........H...##
##..................................G.......#.........H...##
AA..................=====...........G...........=====.H...BB
AA........e.........e.........M.....G...3.............H...BB
###########..................#############...........#######
############################################################
############################################################
############################################################
############################################################
]],
  floodRow = 12,
  key = {
    ["p"] = "cruciblepot:left:auto:7:6:28",
    ["q"] = "cruciblepot:right:auto:9:42:52",
    ["9"] = "chest:ch_furn_high:bigshard:6",
    ["3"] = "chest:chest_heatplate:module:heatplating",
    ["M"] = "machine:furnvault:Vault_seals_release",
    ["e"] = "shieldbug",
    ["w"] = "welder",
  },
  links = {
    A = { "furn_golem", "B" },
    B = { "furn_5", "A" },
  },
}
