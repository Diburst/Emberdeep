-- Mosswood: spitters among the roots; the deep well yawns below.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 27, h = 272, col = "black", a = 0.32, py = 0.25, step = 39, acc = "moss" },
    { kind = "column", x = 57, y = 0, w = 39, h = 272, col = "black", a = 0.26, py = 0.2, step = 28, acc = "moss" },
    { kind = "column", x = 130, y = 0, w = 32, h = 272, col = "black", a = 0.31, py = 0.21, step = 43, acc = "moss" },
    { kind = "column", x = 229, y = 0, w = 39, h = 272, col = "black", a = 0.28, py = 0.18, step = 30, acc = "moss" },
    { kind = "column", x = 329, y = 0, w = 34, h = 272, col = "black", a = 0.4, py = 0.27, step = 42, acc = "moss" },
    { kind = "column", x = 428, y = 0, w = 39, h = 272, col = "black", a = 0.27, py = 0.22, step = 46, acc = "moss" },
    { kind = "column", x = 515, y = 0, w = 26, h = 272, col = "black", a = 0.4, py = 0.19, step = 28, acc = "moss" },
    { kind = "column", x = 588, y = 0, w = 25, h = 272, col = "black", a = 0.4, py = 0.2, step = 42, acc = "moss" },
    { kind = "column", x = 676, y = 0, w = 30, h = 272, col = "black", a = 0.37, py = 0.24, step = 37, acc = "moss" },
    { kind = "column", x = 746, y = 0, w = 25, h = 272, col = "black", a = 0.28, py = 0.26, step = 26, acc = "moss" },
    { kind = "column", x = 813, y = 0, w = 38, h = 272, col = "black", a = 0.26, py = 0.24, step = 43, acc = "moss" },
    { kind = "column", x = 914, y = 0, w = 21, h = 272, col = "black", a = 0.35, py = 0.21, step = 33, acc = "moss" },
    { kind = "shaft", x = 847, y = 0, w = 56, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 9, ph = 1.09 },
    { kind = "shaft", x = 225, y = 0, w = 47, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 13, ph = 5 },
    { kind = "shaft", x = 723, y = 0, w = 57, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -19, ph = 0.52 },
    { kind = "shaft", x = 379, y = 0, w = 43, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -13, ph = 0.82 },
    { kind = "shaft", x = 745, y = 0, w = 44, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -18, ph = 5.65 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 936, y = 60, w = 2, h = 22, col = "moss", a = 0.46, lw = 2, sway = 6, rate = 0.36, bob = true },
    { kind = "hang", x = 298, y = 2, w = 2, h = 15, col = "moss", a = 0.66, lw = 2, sway = 3, rate = 0.44, bob = true },
    { kind = "hang", x = 602, y = 34, w = 2, h = 10, col = "moss", a = 0.53, lw = 2, sway = 3, rate = 0.3, bob = true },
    { kind = "hang", x = 557, y = 74, w = 2, h = 10, col = "moss", a = 0.61, lw = 2, sway = 3, rate = 0.35, bob = true },
    { kind = "hang", x = 697, y = 88, w = 2, h = 25, col = "moss", a = 0.59, lw = 2, sway = 6, rate = 0.34, bob = true },
    { kind = "hang", x = 903, y = 97, w = 2, h = 32, col = "moss", a = 0.48, lw = 2, sway = 4, rate = 0.38, bob = true },
    { kind = "hang", x = 810, y = 79, w = 2, h = 13, col = "moss", a = 0.68, lw = 2, sway = 3, rate = 0.24, bob = true },
    { kind = "hang", x = 914, y = 45, w = 2, h = 37, col = "moss", a = 0.49, lw = 2, sway = 4, rate = 0.44, bob = true },
    { kind = "hang", x = 561, y = 16, w = 2, h = 20, col = "moss", a = 0.71, lw = 2, sway = 5, rate = 0.49, bob = true },
    { kind = "hang", x = 754, y = 66, w = 2, h = 12, col = "moss", a = 0.51, lw = 2, sway = 3, rate = 0.38, bob = true },
    { kind = "hang", x = 789, y = 74, w = 2, h = 30, col = "moss", a = 0.44, lw = 2, sway = 2, rate = 0.25, bob = true },
    { kind = "hang", x = 449, y = 34, w = 2, h = 14, col = "moss", a = 0.74, lw = 2, sway = 5, rate = 0.38, bob = true },
    { kind = "hang", x = 641, y = 21, w = 2, h = 13, col = "moss", a = 0.44, lw = 2, sway = 6, rate = 0.43, bob = true },
    { kind = "hang", x = 635, y = 40, w = 2, h = 22, col = "moss", a = 0.73, lw = 2, sway = 3, rate = 0.49, bob = true },
    { kind = "hang", x = 537, y = 14, w = 2, h = 35, col = "moss", a = 0.55, lw = 2, sway = 2, rate = 0.47, bob = true },
    { kind = "hang", x = 438, y = 73, w = 2, h = 33, col = "moss", a = 0.53, lw = 2, sway = 3, rate = 0.24, bob = true },
    { kind = "hang", x = 598, y = 27, w = 2, h = 28, col = "moss", a = 0.47, lw = 2, sway = 4, rate = 0.34, bob = true },
    { kind = "hang", x = 406, y = 37, w = 2, h = 17, col = "moss", a = 0.48, lw = 2, sway = 4, rate = 0.28, bob = true },
    { kind = "hang", x = 9, y = 118, w = 2, h = 29, col = "moss", a = 0.59, lw = 2, sway = 6, rate = 0.31, bob = true },
    { kind = "hang", x = 438, y = 61, w = 2, h = 28, col = "moss", a = 0.55, lw = 2, sway = 2, rate = 0.23, bob = true },
    { kind = "hang", x = 388, y = 72, w = 2, h = 11, col = "moss", a = 0.74, lw = 2, sway = 2, rate = 0.49, bob = true },
    { kind = "rect", x = 903, y = 43, w = 9, h = 5, col = "fern", a = 0.2 },
    { kind = "rect", x = 305, y = 83, w = 14, h = 4, col = "lime", a = 0.27 },
    { kind = "rect", x = 858, y = 80, w = 11, h = 3, col = "moss", a = 0.45 },
    { kind = "rect", x = 403, y = 182, w = 18, h = 4, col = "moss", a = 0.4 },
    { kind = "rect", x = 680, y = 173, w = 10, h = 4, col = "fern", a = 0.42 },
    { kind = "rect", x = 697, y = 186, w = 11, h = 3, col = "moss", a = 0.34 },
    { kind = "rect", x = 349, y = 42, w = 9, h = 2, col = "moss", a = 0.38 },
    { kind = "rect", x = 840, y = 55, w = 16, h = 5, col = "moss", a = 0.44 },
    { kind = "rect", x = 751, y = 222, w = 6, h = 2, col = "lime", a = 0.29 },
    { kind = "rect", x = 834, y = 103, w = 16, h = 3, col = "moss", a = 0.4 },
    { kind = "rect", x = 556, y = 104, w = 11, h = 2, col = "lime", a = 0.24 },
    { kind = "rect", x = 803, y = 118, w = 13, h = 5, col = "moss", a = 0.4 },
    { kind = "rect", x = 449, y = 214, w = 18, h = 3, col = "moss", a = 0.43 },
    { kind = "rect", x = 100, y = 228, w = 9, h = 3, col = "lime", a = 0.29 },
    { kind = "rect", x = 568, y = 173, w = 13, h = 4, col = "lime", a = 0.28 },
    { kind = "rect", x = 340, y = 57, w = 12, h = 4, col = "moss", a = 0.29 },
    { kind = "rect", x = 100, y = 151, w = 10, h = 3, col = "moss", a = 0.36 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 13, w = 1008, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 342, y = 26, w = 2, h = 52, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.58, bob = true },
    { kind = "hang", x = 796, y = 26, w = 2, h = 34, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.68, bob = true },
    { kind = "hang", x = 62, y = 26, w = 2, h = 58, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.38, bob = true },
    { kind = "hang", x = 303, y = 26, w = 2, h = 47, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.39, bob = true },
    { kind = "hang", x = 254, y = 26, w = 2, h = 56, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.33, bob = true },
    { kind = "hang", x = 648, y = 26, w = 2, h = 63, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 6, rate = 0.62, bob = true },
    { kind = "hang", x = 830, y = 26, w = 2, h = 29, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 7, rate = 0.4, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 938, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 160, y = 43, col = { 0.80, 1.00, 0.66 }, r = 85, flicker = 2.23 },
    { x = 480, y = 43, col = { 0.80, 1.00, 0.66 }, r = 92, flicker = 2.11 },
    { x = 800, y = 43, col = { 0.80, 1.00, 0.66 }, r = 84, flicker = 1.91 },
  },
  mapPos = { x = 1, y = 2, w = 3, h = 1 },
  map = [[
############################################################
############################################################
##........................................................##
##.....................................................%%%##
##...............====...................p..............%..##
##...........................p.........####............%..##
##..........p...............====.......................%..##
##.p.......###.......p................................3%..##
####................====...........p..................##..##
#####..............................###...=====............##
A....................r....................................##
A...........4.............................................BB
A..........####....................r......................BB
###...####......####......#####......####...........########
###......................##.####......DD............########
######################################DD####################
############################################################
]],
  key = {
    ["4"] = "chest:ch_ap1:module:arcplate1",
    ["3"] = "chest:chest_moss2:scrap:8",
    ["p"] = "spitter",
    ["r"] = "rollpede",
  },
  links = {
    A = { "moss_1", "B" },
    B = { "moss_3", "B" },
    D = { "moss_well", "A" },
  },
}
