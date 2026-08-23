-- Mosswood shaft: climbs toward the Skyroot high above.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 512, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 38, h = 512, col = "black", a = 0.37, py = 0.19, step = 26, acc = "moss" },
    { kind = "column", x = 48, y = 0, w = 20, h = 512, col = "black", a = 0.26, py = 0.16, step = 38, acc = "moss" },
    { kind = "column", x = 125, y = 0, w = 26, h = 512, col = "black", a = 0.37, py = 0.2, step = 33, acc = "moss" },
    { kind = "column", x = 214, y = 0, w = 23, h = 512, col = "black", a = 0.3, py = 0.23, step = 45, acc = "moss" },
    { kind = "column", x = 271, y = 0, w = 28, h = 512, col = "black", a = 0.36, py = 0.14, step = 46, acc = "moss" },
    { kind = "column", x = 367, y = 0, w = 39, h = 512, col = "black", a = 0.32, py = 0.23, step = 34, acc = "moss" },
    { kind = "column", x = 461, y = 0, w = 26, h = 512, col = "black", a = 0.33, py = 0.16, step = 31, acc = "moss" },
    { kind = "shaft", x = 122, y = 0, w = 61, h = 435, col = "lime", a = 0.15, py = 0.18, skew = 2, ph = 2.58 },
    { kind = "shaft", x = 397, y = 0, w = 64, h = 435, col = "lime", a = 0.15, py = 0.18, skew = -6, ph = 5.03 },
    { kind = "shaft", x = 240, y = 0, w = 60, h = 435, col = "lime", a = 0.15, py = 0.18, skew = -7, ph = 2.6 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 33, y = 196, w = 2, h = 16, col = "moss", a = 0.54, lw = 2, sway = 6, rate = 0.28, bob = true },
    { kind = "hang", x = 287, y = 11, w = 2, h = 34, col = "moss", a = 0.43, lw = 2, sway = 6, rate = 0.39, bob = true },
    { kind = "hang", x = 99, y = 60, w = 2, h = 20, col = "moss", a = 0.7, lw = 2, sway = 5, rate = 0.28, bob = true },
    { kind = "hang", x = 361, y = 203, w = 2, h = 16, col = "moss", a = 0.7, lw = 2, sway = 2, rate = 0.29, bob = true },
    { kind = "hang", x = 320, y = 129, w = 2, h = 25, col = "moss", a = 0.41, lw = 2, sway = 3, rate = 0.44, bob = true },
    { kind = "hang", x = 71, y = 118, w = 2, h = 34, col = "moss", a = 0.41, lw = 2, sway = 5, rate = 0.36, bob = true },
    { kind = "hang", x = 302, y = 58, w = 2, h = 40, col = "moss", a = 0.57, lw = 2, sway = 3, rate = 0.34, bob = true },
    { kind = "hang", x = 15, y = 164, w = 2, h = 29, col = "moss", a = 0.53, lw = 2, sway = 3, rate = 0.39, bob = true },
    { kind = "hang", x = 99, y = 222, w = 2, h = 28, col = "moss", a = 0.6, lw = 2, sway = 3, rate = 0.2, bob = true },
    { kind = "hang", x = 163, y = 32, w = 2, h = 11, col = "moss", a = 0.44, lw = 2, sway = 5, rate = 0.49, bob = true },
    { kind = "rect", x = 249, y = 436, w = 12, h = 2, col = "fern", a = 0.25 },
    { kind = "rect", x = 357, y = 196, w = 8, h = 3, col = "moss", a = 0.38 },
    { kind = "rect", x = 119, y = 394, w = 16, h = 3, col = "lime", a = 0.39 },
    { kind = "rect", x = 376, y = 231, w = 7, h = 4, col = "lime", a = 0.23 },
    { kind = "rect", x = 434, y = 369, w = 16, h = 2, col = "moss", a = 0.32 },
    { kind = "rect", x = 50, y = 310, w = 8, h = 2, col = "lime", a = 0.3 },
    { kind = "rect", x = 63, y = 383, w = 13, h = 2, col = "fern", a = 0.37 },
    { kind = "rect", x = 347, y = 103, w = 14, h = 2, col = "fern", a = 0.3 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 25, w = 528, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 165, y = 38, w = 2, h = 64, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 7, rate = 0.33, bob = true },
    { kind = "hang", x = 450, y = 38, w = 2, h = 50, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.68, bob = true },
    { kind = "hang", x = 462, y = 38, w = 2, h = 35, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 6, rate = 0.53, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 512, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 458, y = 0, w = 22, h = 512, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 240, y = 81, col = { 0.80, 1.00, 0.66 }, r = 70, flicker = 1.45 },
  },
  mapPos = { x = 3, y = 0, w = 1, h = 2 },
  map = [[
#############CC###############
#############CC###############
##..........................##
##..........1...............##
##..........====............##
##..........................##
##....................####..##
##.........g..g.............##
################............##
#############........g......##
#######..............====...##
####........................##
##..g........................#
##....................####...#
##.......####................#
##...........................#
##..####.....................#
##..........####......########
##.......................#####
##.............====........###
##..........................AA
##..........................AA
##.................###########
BB...........====...........##
BB.....h....................##
###########.................##
##.............g............##
##...........####...........##
##..................z.......##
##############################
##############################
##############################
]],
  key = {
    ["1"] = "sign:sign_sky_gate",
    ["z"] = "checkpoint",
    ["g"] = "gnat",
    ["h"] = "hopper",
  },
  links = {
    A = { "moss_4", "A" },
    B = { "moss_2", "B" },
    C = { "sky_1", "A" },
  },
}
