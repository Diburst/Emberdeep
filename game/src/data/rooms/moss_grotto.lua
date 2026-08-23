-- generated (v4.1)
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 496, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 35, h = 496, col = "black", a = 0.25, py = 0.28, step = 38, acc = "moss" },
    { kind = "column", x = 52, y = 0, w = 40, h = 496, col = "black", a = 0.3, py = 0.16, step = 33, acc = "moss" },
    { kind = "column", x = 142, y = 0, w = 23, h = 496, col = "black", a = 0.31, py = 0.19, step = 40, acc = "moss" },
    { kind = "column", x = 233, y = 0, w = 39, h = 496, col = "black", a = 0.32, py = 0.16, step = 33, acc = "moss" },
    { kind = "column", x = 315, y = 0, w = 30, h = 496, col = "black", a = 0.27, py = 0.24, step = 34, acc = "moss" },
    { kind = "column", x = 398, y = 0, w = 30, h = 496, col = "black", a = 0.32, py = 0.19, step = 39, acc = "moss" },
    { kind = "shaft", x = 36, y = 0, w = 71, h = 421, col = "lime", a = 0.15, py = 0.18, skew = -7, ph = 4.22 },
    { kind = "shaft", x = 61, y = 0, w = 50, h = 421, col = "lime", a = 0.15, py = 0.18, skew = -18, ph = 0.13 },
    { kind = "shaft", x = 178, y = 0, w = 73, h = 421, col = "lime", a = 0.15, py = 0.18, skew = -4, ph = 4.61 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 474, y = 201, w = 2, h = 13, col = "moss", a = 0.69, lw = 2, sway = 2, rate = 0.43, bob = true },
    { kind = "hang", x = 371, y = 9, w = 2, h = 26, col = "moss", a = 0.71, lw = 2, sway = 5, rate = 0.24, bob = true },
    { kind = "hang", x = 240, y = 3, w = 2, h = 11, col = "moss", a = 0.72, lw = 2, sway = 3, rate = 0.25, bob = true },
    { kind = "hang", x = 249, y = 122, w = 2, h = 38, col = "moss", a = 0.74, lw = 2, sway = 6, rate = 0.39, bob = true },
    { kind = "hang", x = 420, y = 88, w = 2, h = 26, col = "moss", a = 0.45, lw = 2, sway = 4, rate = 0.21, bob = true },
    { kind = "hang", x = 401, y = 17, w = 2, h = 27, col = "moss", a = 0.7, lw = 2, sway = 6, rate = 0.34, bob = true },
    { kind = "hang", x = 265, y = 140, w = 2, h = 20, col = "moss", a = 0.7, lw = 2, sway = 6, rate = 0.46, bob = true },
    { kind = "hang", x = 415, y = 151, w = 2, h = 20, col = "moss", a = 0.52, lw = 2, sway = 3, rate = 0.24, bob = true },
    { kind = "hang", x = 166, y = 90, w = 2, h = 17, col = "moss", a = 0.73, lw = 2, sway = 2, rate = 0.36, bob = true },
    { kind = "hang", x = 125, y = 3, w = 2, h = 10, col = "moss", a = 0.59, lw = 2, sway = 3, rate = 0.32, bob = true },
    { kind = "rect", x = 323, y = 283, w = 8, h = 4, col = "moss", a = 0.3 },
    { kind = "rect", x = 22, y = 335, w = 10, h = 4, col = "fern", a = 0.37 },
    { kind = "rect", x = 379, y = 403, w = 15, h = 5, col = "lime", a = 0.29 },
    { kind = "rect", x = 92, y = 85, w = 13, h = 2, col = "fern", a = 0.37 },
    { kind = "rect", x = 23, y = 304, w = 9, h = 3, col = "moss", a = 0.23 },
    { kind = "rect", x = 446, y = 169, w = 16, h = 4, col = "fern", a = 0.42 },
    { kind = "rect", x = 394, y = 104, w = 11, h = 4, col = "lime", a = 0.38 },
    { kind = "rect", x = 27, y = 325, w = 11, h = 2, col = "moss", a = 0.4 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 24, w = 528, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 428, y = 37, w = 2, h = 62, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 6, rate = 0.33, bob = true },
    { kind = "hang", x = 255, y = 37, w = 2, h = 44, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.54, bob = true },
    { kind = "hang", x = 302, y = 37, w = 2, h = 45, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 7, rate = 0.43, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 496, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 458, y = 0, w = 22, h = 496, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 240, y = 79, col = { 0.80, 1.00, 0.66 }, r = 89, flicker = 2.29 },
  },
  mapPos = { x = 8, y = 1, w = 1, h = 2 },
  map = [[
#############AAA##############
#############AAA##############
##..........................##
##..........................##
##..........................##
##.............====.........##
##..........................##
##..........................##
##........====........g.....##
##..........................##
##..........................##
##.............====.........##
##..........................##
##..........................##
##........====..............##
##....g.....................##
##..........................##
##.............====.........##
##..........................##
##..........................##
##........====........h.....##
##..........................##
##..........................##
##.............====.........##
##..........................##
##..........................##
##.....1..=p==.3......2.....##
##############################
##############################
##############################
##############################
]],
  key = {
    ["1"] = "chest:chest_grotto:bigshard:4",
    ["2"] = "chest:chest_moldcap:module:moldcap",
    ["3"] = "sign:sign_grotto",
    ["g"] = "gnat",
    ["h"] = "hopper",
    ["p"] = "spitter",
  },
  links = {
    A = { "moss_5", "E" },
  },
}
