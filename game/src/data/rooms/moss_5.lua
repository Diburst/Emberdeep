-- Mosswood: the overgrown gardens. A giant moldcap hides below.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 32, h = 272, col = "black", a = 0.4, py = 0.15, step = 30, acc = "moss" },
    { kind = "column", x = 79, y = 0, w = 22, h = 272, col = "black", a = 0.35, py = 0.16, step = 27, acc = "moss" },
    { kind = "column", x = 169, y = 0, w = 33, h = 272, col = "black", a = 0.29, py = 0.23, step = 40, acc = "moss" },
    { kind = "column", x = 238, y = 0, w = 23, h = 272, col = "black", a = 0.34, py = 0.15, step = 37, acc = "moss" },
    { kind = "column", x = 315, y = 0, w = 37, h = 272, col = "black", a = 0.24, py = 0.21, step = 41, acc = "moss" },
    { kind = "column", x = 395, y = 0, w = 34, h = 272, col = "black", a = 0.29, py = 0.18, step = 28, acc = "moss" },
    { kind = "column", x = 487, y = 0, w = 36, h = 272, col = "black", a = 0.35, py = 0.2, step = 26, acc = "moss" },
    { kind = "column", x = 563, y = 0, w = 32, h = 272, col = "black", a = 0.35, py = 0.27, step = 27, acc = "moss" },
    { kind = "column", x = 627, y = 0, w = 20, h = 272, col = "black", a = 0.3, py = 0.16, step = 33, acc = "moss" },
    { kind = "column", x = 698, y = 0, w = 36, h = 272, col = "black", a = 0.26, py = 0.16, step = 42, acc = "moss" },
    { kind = "column", x = 804, y = 0, w = 37, h = 272, col = "black", a = 0.29, py = 0.2, step = 30, acc = "moss" },
    { kind = "column", x = 877, y = 0, w = 25, h = 272, col = "black", a = 0.31, py = 0.27, step = 28, acc = "moss" },
    { kind = "shaft", x = 769, y = 0, w = 65, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 19, ph = 4.39 },
    { kind = "shaft", x = 462, y = 0, w = 63, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 1, ph = 3.78 },
    { kind = "shaft", x = 110, y = 0, w = 74, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 3, ph = 4.28 },
    { kind = "shaft", x = 254, y = 0, w = 65, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -18, ph = 0.63 },
    { kind = "shaft", x = 335, y = 0, w = 51, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -16, ph = 1.4 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 919, y = 119, w = 2, h = 40, col = "moss", a = 0.59, lw = 2, sway = 4, rate = 0.23, bob = true },
    { kind = "hang", x = 690, y = 1, w = 2, h = 15, col = "moss", a = 0.45, lw = 2, sway = 5, rate = 0.46, bob = true },
    { kind = "hang", x = 548, y = 84, w = 2, h = 13, col = "moss", a = 0.73, lw = 2, sway = 3, rate = 0.34, bob = true },
    { kind = "hang", x = 184, y = 40, w = 2, h = 33, col = "moss", a = 0.71, lw = 2, sway = 2, rate = 0.48, bob = true },
    { kind = "hang", x = 49, y = 37, w = 2, h = 38, col = "moss", a = 0.57, lw = 2, sway = 4, rate = 0.35, bob = true },
    { kind = "hang", x = 434, y = 59, w = 2, h = 16, col = "moss", a = 0.47, lw = 2, sway = 3, rate = 0.28, bob = true },
    { kind = "hang", x = 22, y = 86, w = 2, h = 11, col = "moss", a = 0.5, lw = 2, sway = 4, rate = 0.31, bob = true },
    { kind = "hang", x = 310, y = 101, w = 2, h = 15, col = "moss", a = 0.53, lw = 2, sway = 4, rate = 0.29, bob = true },
    { kind = "hang", x = 802, y = 57, w = 2, h = 23, col = "moss", a = 0.64, lw = 2, sway = 2, rate = 0.38, bob = true },
    { kind = "hang", x = 572, y = 110, w = 2, h = 30, col = "moss", a = 0.55, lw = 2, sway = 4, rate = 0.46, bob = true },
    { kind = "hang", x = 349, y = 35, w = 2, h = 36, col = "moss", a = 0.68, lw = 2, sway = 2, rate = 0.47, bob = true },
    { kind = "hang", x = 402, y = 119, w = 2, h = 24, col = "moss", a = 0.64, lw = 2, sway = 2, rate = 0.25, bob = true },
    { kind = "hang", x = 404, y = 6, w = 2, h = 39, col = "moss", a = 0.49, lw = 2, sway = 3, rate = 0.32, bob = true },
    { kind = "hang", x = 809, y = 24, w = 2, h = 28, col = "moss", a = 0.55, lw = 2, sway = 5, rate = 0.23, bob = true },
    { kind = "hang", x = 652, y = 97, w = 2, h = 22, col = "moss", a = 0.64, lw = 2, sway = 6, rate = 0.39, bob = true },
    { kind = "hang", x = 182, y = 81, w = 2, h = 40, col = "moss", a = 0.44, lw = 2, sway = 3, rate = 0.34, bob = true },
    { kind = "hang", x = 220, y = 107, w = 2, h = 14, col = "moss", a = 0.66, lw = 2, sway = 4, rate = 0.22, bob = true },
    { kind = "hang", x = 711, y = 63, w = 2, h = 21, col = "moss", a = 0.74, lw = 2, sway = 2, rate = 0.2, bob = true },
    { kind = "hang", x = 906, y = 38, w = 2, h = 14, col = "moss", a = 0.45, lw = 2, sway = 5, rate = 0.37, bob = true },
    { kind = "hang", x = 34, y = 84, w = 2, h = 35, col = "moss", a = 0.59, lw = 2, sway = 2, rate = 0.34, bob = true },
    { kind = "hang", x = 538, y = 16, w = 2, h = 23, col = "moss", a = 0.61, lw = 2, sway = 2, rate = 0.35, bob = true },
    { kind = "rect", x = 905, y = 61, w = 16, h = 5, col = "lime", a = 0.23 },
    { kind = "rect", x = 48, y = 230, w = 6, h = 5, col = "moss", a = 0.38 },
    { kind = "rect", x = 137, y = 227, w = 11, h = 5, col = "lime", a = 0.26 },
    { kind = "rect", x = 473, y = 118, w = 10, h = 4, col = "moss", a = 0.33 },
    { kind = "rect", x = 402, y = 205, w = 16, h = 3, col = "moss", a = 0.37 },
    { kind = "rect", x = 595, y = 110, w = 11, h = 3, col = "fern", a = 0.27 },
    { kind = "rect", x = 860, y = 158, w = 10, h = 2, col = "lime", a = 0.29 },
    { kind = "rect", x = 412, y = 54, w = 18, h = 4, col = "moss", a = 0.32 },
    { kind = "rect", x = 343, y = 230, w = 13, h = 5, col = "lime", a = 0.38 },
    { kind = "rect", x = 373, y = 61, w = 11, h = 3, col = "moss", a = 0.32 },
    { kind = "rect", x = 234, y = 147, w = 15, h = 4, col = "moss", a = 0.34 },
    { kind = "rect", x = 133, y = 103, w = 12, h = 4, col = "moss", a = 0.39 },
    { kind = "rect", x = 517, y = 209, w = 12, h = 3, col = "moss", a = 0.43 },
    { kind = "rect", x = 633, y = 133, w = 14, h = 4, col = "moss", a = 0.4 },
    { kind = "rect", x = 179, y = 170, w = 10, h = 2, col = "fern", a = 0.31 },
    { kind = "rect", x = 714, y = 172, w = 16, h = 5, col = "lime", a = 0.31 },
    { kind = "rect", x = 890, y = 127, w = 17, h = 4, col = "fern", a = 0.37 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 13, w = 1008, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 777, y = 26, w = 2, h = 33, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.51, bob = true },
    { kind = "hang", x = 725, y = 26, w = 2, h = 30, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.33, bob = true },
    { kind = "hang", x = 69, y = 26, w = 2, h = 32, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.43, bob = true },
    { kind = "hang", x = 794, y = 26, w = 2, h = 29, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 7, rate = 0.55, bob = true },
    { kind = "hang", x = 444, y = 26, w = 2, h = 41, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.36, bob = true },
    { kind = "hang", x = 858, y = 26, w = 2, h = 40, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.36, bob = true },
    { kind = "hang", x = 824, y = 26, w = 2, h = 55, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.66, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 938, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 160, y = 43, col = { 0.80, 1.00, 0.66 }, r = 90, flicker = 2 },
    { x = 480, y = 43, col = { 0.80, 1.00, 0.66 }, r = 76, flicker = 1.11 },
    { x = 800, y = 43, col = { 0.80, 1.00, 0.66 }, r = 91, flicker = 2.39 },
  },
  mapPos = { x = 6, y = 0, w = 3, h = 1 },
  map = [[
############################################################
############################################################
####################.......#####.......#######.......#######
##...##########............##..........#####..............##
##.......................................................###
##............................................g.........####
##..................................................9.....##
####....................p..........1..........=======.....##
####................=======.....#######...................##
####.....................................................###
AA.......................................................#BB
AA...z....r.....................................r.........BB
##############...#########################...###############
####..............................%.....................####
####..............................%.....................####
###################################EEE######################
###################################EEE######################
]],
  key = {
    ["9"] = "chest:ch_moss_high:scrap:20",
    ["1"] = "chest:chest_moss5:bigshard:4",
    ["z"] = "checkpoint",
    ["p"] = "spitter",
    ["r"] = "rollpede",
    ["g"] = "gnat",
  },
  links = {
    A = { "moss_4", "B" },
    B = { "moss_boss", "A" },
    E = { "moss_grotto", "A" },
  },
}
