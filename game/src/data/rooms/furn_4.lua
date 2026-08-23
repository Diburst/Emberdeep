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
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "maroon", a = 0.1, a2 = 0.42, py = 0.05 },
    { kind = "rect", x = -18, y = 113, w = 34, h = 159, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 71, y = 133, w = 34, h = 139, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 146, y = 171, w = 41, h = 101, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 225, y = 136, w = 36, h = 136, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 307, y = 121, w = 43, h = 151, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 400, y = 184, w = 40, h = 88, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 479, y = 81, w = 39, h = 191, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 552, y = 103, w = 43, h = 169, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 639, y = 102, w = 30, h = 170, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 702, y = 104, w = 43, h = 168, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 789, y = 185, w = 45, h = 87, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 865, y = 116, w = 52, h = 156, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 943, y = 160, w = 38, h = 112, col = "black", a = 0.4, py = 0.22 },
    { kind = "girder", x = -16, y = 43, w = 992, h = 14, col = "black", a = 0.42, py = 0.28, step = 33 },
    { kind = "girder", x = -16, y = 108, w = 992, h = 14, col = "black", a = 0.42, py = 0.28, step = 36 },
    { kind = "shaft", x = 600, y = 95, w = 41, h = 163, col = "magma", a = 0.2, py = 0.14, skew = -1, ph = 5.62 },
    { kind = "shaft", x = 545, y = 95, w = 41, h = 163, col = "magma", a = 0.2, py = 0.14, skew = -6, ph = 3.01 },
    { kind = "shaft", x = 507, y = 95, w = 38, h = 163, col = "magma", a = 0.2, py = 0.14, skew = -5, ph = 4.12 },
    { kind = "shaft", x = 486, y = 95, w = 49, h = 163, col = "magma", a = 0.2, py = 0.14, skew = -1, ph = 3.2 },
    { kind = "shaft", x = 430, y = 95, w = 38, h = 163, col = "magma", a = 0.2, py = 0.14, skew = 3, ph = 1.36 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 716, y = 83, w = 5, h = 26, col = "rust", a = 0.32 },
    { kind = "rect", x = 531, y = 57, w = 6, h = 14, col = "rust", a = 0.28 },
    { kind = "rect", x = 630, y = 155, w = 6, h = 19, col = "rust", a = 0.29 },
    { kind = "rect", x = 705, y = 103, w = 4, h = 26, col = "rust", a = 0.36 },
    { kind = "rect", x = 767, y = 149, w = 6, h = 13, col = "rust", a = 0.3 },
    { kind = "rect", x = 879, y = 173, w = 5, h = 20, col = "rust", a = 0.26 },
    { kind = "rect", x = 139, y = 103, w = 6, h = 21, col = "rust", a = 0.49 },
    { kind = "rect", x = 644, y = 72, w = 4, h = 18, col = "rust", a = 0.39 },
    { kind = "rect", x = 364, y = 71, w = 6, h = 11, col = "rust", a = 0.43 },
    { kind = "rect", x = 604, y = 207, w = 5, h = 28, col = "rust", a = 0.38 },
    { kind = "rect", x = 427, y = 63, w = 7, h = 19, col = "rust", a = 0.37 },
    { kind = "rect", x = 316, y = 138, w = 3, h = 27, col = "rust", a = 0.38 },
    { kind = "rect", x = 764, y = 156, w = 7, h = 19, col = "rust", a = 0.3 },
    { kind = "rect", x = 586, y = 90, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 588, y = 92, w = 4, h = 6, col = "magma", a = 1 },
    { kind = "rect", x = 398, y = 70, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 400, y = 72, w = 4, h = 6, col = "magma", a = 1 },
    { kind = "rect", x = 21, y = 105, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 23, y = 107, w = 4, h = 6, col = "magma", a = 1 },
    { kind = "rect", x = 893, y = 110, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 895, y = 112, w = 4, h = 6, col = "magma", a = 1 },
    { kind = "rect", x = 662, y = 163, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 664, y = 165, w = 4, h = 6, col = "magma", a = 1 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 13, w = 1008, h = 16, col = "black", a = 0.9, py = -0.13, step = 32 },
    { kind = "hang", x = 150, y = 29, w = 2, h = 59, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 598, y = 29, w = 2, h = 57, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 199, y = 29, w = 2, h = 59, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 463, y = 29, w = 2, h = 33, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 449, y = 29, w = 2, h = 52, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 829, y = 29, w = 2, h = 41, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "band", x = 0, y = 0, w = 24, h = 272, col = "black", a = 0.5, a2 = 0.5, py = -0.06 },
    { kind = "band", x = 936, y = 0, w = 24, h = 272, col = "black", a = 0.5, a2 = 0.5, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 590, y = 95, col = { 1.00, 0.52, 0.20 }, r = 52, flicker = 5.03 },
    { x = 402, y = 75, col = { 1.00, 0.52, 0.20 }, r = 48, flicker = 5.25 },
    { x = 25, y = 110, col = { 1.00, 0.52, 0.20 }, r = 50, flicker = 5.18 },
    { x = 897, y = 115, col = { 1.00, 0.52, 0.20 }, r = 63, flicker = 4.59 },
    { x = 666, y = 168, col = { 1.00, 0.52, 0.20 }, r = 58, flicker = 4.38 },
    { x = 649, y = 239, col = { 1.00, 0.40, 0.14 }, r = 114, flicker = 2.62 },
  },
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
