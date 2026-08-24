-- Hidden grotto off the Mosswood entry.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 256, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 39, h = 256, col = "black", a = 0.28, py = 0.19, step = 31, acc = "moss" },
    { kind = "column", x = 59, y = 0, w = 25, h = 256, col = "black", a = 0.3, py = 0.2, step = 33, acc = "moss" },
    { kind = "column", x = 149, y = 0, w = 32, h = 256, col = "black", a = 0.25, py = 0.22, step = 41, acc = "moss" },
    { kind = "column", x = 223, y = 0, w = 26, h = 256, col = "black", a = 0.38, py = 0.26, step = 36, acc = "moss" },
    { kind = "column", x = 312, y = 0, w = 34, h = 256, col = "black", a = 0.28, py = 0.27, step = 26, acc = "moss" },
    { kind = "column", x = 406, y = 0, w = 20, h = 256, col = "black", a = 0.27, py = 0.18, step = 34, acc = "moss" },
    { kind = "shaft", x = 392, y = 0, w = 60, h = 217, col = "lime", a = 0.15, py = 0.18, skew = -6, ph = 0.4 },
    { kind = "shaft", x = 399, y = 0, w = 55, h = 217, col = "lime", a = 0.15, py = 0.18, skew = 9, ph = 1.49 },
    { kind = "shaft", x = 171, y = 0, w = 49, h = 217, col = "lime", a = 0.15, py = 0.18, skew = -7, ph = 5.74 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 307, y = 97, w = 2, h = 39, col = "moss", a = 0.54, lw = 2, sway = 5, rate = 0.43, bob = true },
    { kind = "hang", x = 117, y = 70, w = 2, h = 34, col = "moss", a = 0.49, lw = 2, sway = 4, rate = 0.41, bob = true },
    { kind = "hang", x = 365, y = 115, w = 2, h = 39, col = "moss", a = 0.71, lw = 2, sway = 5, rate = 0.33, bob = true },
    { kind = "hang", x = 24, y = 86, w = 2, h = 40, col = "moss", a = 0.5, lw = 2, sway = 6, rate = 0.46, bob = true },
    { kind = "hang", x = 146, y = 76, w = 2, h = 39, col = "moss", a = 0.6, lw = 2, sway = 2, rate = 0.45, bob = true },
    { kind = "hang", x = 453, y = 86, w = 2, h = 37, col = "moss", a = 0.48, lw = 2, sway = 3, rate = 0.24, bob = true },
    { kind = "hang", x = 418, y = 2, w = 2, h = 31, col = "moss", a = 0.51, lw = 2, sway = 4, rate = 0.38, bob = true },
    { kind = "hang", x = 289, y = 0, w = 2, h = 16, col = "moss", a = 0.51, lw = 2, sway = 4, rate = 0.22, bob = true },
    { kind = "hang", x = 219, y = 59, w = 2, h = 20, col = "moss", a = 0.72, lw = 2, sway = 6, rate = 0.21, bob = true },
    { kind = "hang", x = 440, y = 14, w = 2, h = 25, col = "moss", a = 0.44, lw = 2, sway = 5, rate = 0.45, bob = true },
    { kind = "rect", x = 118, y = 85, w = 7, h = 3, col = "moss", a = 0.34 },
    { kind = "rect", x = 116, y = 59, w = 7, h = 3, col = "fern", a = 0.4 },
    { kind = "rect", x = 352, y = 211, w = 18, h = 4, col = "fern", a = 0.42 },
    { kind = "rect", x = 439, y = 154, w = 6, h = 3, col = "lime", a = 0.26 },
    { kind = "rect", x = 13, y = 90, w = 17, h = 3, col = "moss", a = 0.26 },
    { kind = "rect", x = 303, y = 139, w = 8, h = 5, col = "fern", a = 0.24 },
    { kind = "rect", x = 386, y = 67, w = 13, h = 4, col = "moss", a = 0.43 },
    { kind = "rect", x = 185, y = 134, w = 16, h = 4, col = "fern", a = 0.37 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 12, w = 528, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 63, y = 25, w = 2, h = 34, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.64, bob = true },
    { kind = "hang", x = 119, y = 25, w = 2, h = 39, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.33, bob = true },
    { kind = "hang", x = 419, y = 25, w = 2, h = 63, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.39, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 256, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 458, y = 0, w = 22, h = 256, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 240, y = 40, col = { 0.80, 1.00, 0.66 }, r = 89, flicker = 1.13 },
  },
  mapPos = { x = 7, y = 2, w = 1, h = 1 },
  map = [[
##############################
##############################
###############.##############
############..............####
########..................####
###.........................##
##.............1............##
###........................###
A.#........................###
A..........................###
A.........######...........###
####.......................###
####......................####
###.......................####
##############################
##############################
]],
  key = {
    ["1"] = "capsule:cap_moss",
  },
  links = {
    A = { "moss_1", "E" },
  },
}
