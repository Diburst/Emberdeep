-- The Bramble Maw's clearing.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 36, h = 272, col = "black", a = 0.28, py = 0.26, step = 34, acc = "moss" },
    { kind = "column", x = 72, y = 0, w = 34, h = 272, col = "black", a = 0.39, py = 0.26, step = 37, acc = "moss" },
    { kind = "column", x = 148, y = 0, w = 37, h = 272, col = "black", a = 0.37, py = 0.18, step = 26, acc = "moss" },
    { kind = "column", x = 254, y = 0, w = 30, h = 272, col = "black", a = 0.25, py = 0.15, step = 41, acc = "moss" },
    { kind = "column", x = 346, y = 0, w = 36, h = 272, col = "black", a = 0.28, py = 0.22, step = 45, acc = "moss" },
    { kind = "column", x = 412, y = 0, w = 33, h = 272, col = "black", a = 0.29, py = 0.15, step = 29, acc = "moss" },
    { kind = "column", x = 474, y = 0, w = 28, h = 272, col = "black", a = 0.3, py = 0.14, step = 46, acc = "moss" },
    { kind = "column", x = 565, y = 0, w = 21, h = 272, col = "black", a = 0.38, py = 0.18, step = 44, acc = "moss" },
    { kind = "column", x = 619, y = 0, w = 23, h = 272, col = "black", a = 0.25, py = 0.18, step = 37, acc = "moss" },
    { kind = "column", x = 701, y = 0, w = 38, h = 272, col = "black", a = 0.35, py = 0.23, step = 33, acc = "moss" },
    { kind = "column", x = 786, y = 0, w = 22, h = 272, col = "black", a = 0.39, py = 0.15, step = 43, acc = "moss" },
    { kind = "column", x = 847, y = 0, w = 28, h = 272, col = "black", a = 0.26, py = 0.24, step = 36, acc = "moss" },
    { kind = "column", x = 925, y = 0, w = 32, h = 272, col = "black", a = 0.25, py = 0.21, step = 27, acc = "moss" },
    { kind = "shaft", x = 429, y = 0, w = 62, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 11, ph = 4.02 },
    { kind = "shaft", x = 583, y = 0, w = 42, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -16, ph = 0.9 },
    { kind = "shaft", x = 717, y = 0, w = 58, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 4, ph = 4.04 },
    { kind = "shaft", x = 698, y = 0, w = 46, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -19, ph = 2.9 },
    { kind = "shaft", x = 824, y = 0, w = 40, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -2, ph = 2.59 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 190, y = 24, w = 2, h = 11, col = "moss", a = 0.67, lw = 2, sway = 6, rate = 0.33, bob = true },
    { kind = "hang", x = 257, y = 0, w = 2, h = 19, col = "moss", a = 0.72, lw = 2, sway = 2, rate = 0.22, bob = true },
    { kind = "hang", x = 483, y = 8, w = 2, h = 34, col = "moss", a = 0.49, lw = 2, sway = 6, rate = 0.26, bob = true },
    { kind = "hang", x = 227, y = 108, w = 2, h = 11, col = "moss", a = 0.53, lw = 2, sway = 3, rate = 0.37, bob = true },
    { kind = "hang", x = 181, y = 96, w = 2, h = 40, col = "moss", a = 0.43, lw = 2, sway = 2, rate = 0.34, bob = true },
    { kind = "hang", x = 300, y = 70, w = 2, h = 29, col = "moss", a = 0.45, lw = 2, sway = 5, rate = 0.45, bob = true },
    { kind = "hang", x = 648, y = 76, w = 2, h = 23, col = "moss", a = 0.73, lw = 2, sway = 3, rate = 0.35, bob = true },
    { kind = "hang", x = 664, y = 31, w = 2, h = 30, col = "moss", a = 0.47, lw = 2, sway = 2, rate = 0.31, bob = true },
    { kind = "hang", x = 633, y = 15, w = 2, h = 37, col = "moss", a = 0.54, lw = 2, sway = 2, rate = 0.34, bob = true },
    { kind = "hang", x = 423, y = 43, w = 2, h = 35, col = "moss", a = 0.43, lw = 2, sway = 4, rate = 0.21, bob = true },
    { kind = "hang", x = 366, y = 25, w = 2, h = 17, col = "moss", a = 0.59, lw = 2, sway = 2, rate = 0.37, bob = true },
    { kind = "hang", x = 714, y = 70, w = 2, h = 26, col = "moss", a = 0.6, lw = 2, sway = 2, rate = 0.21, bob = true },
    { kind = "hang", x = 20, y = 30, w = 2, h = 12, col = "moss", a = 0.45, lw = 2, sway = 4, rate = 0.47, bob = true },
    { kind = "hang", x = 607, y = 104, w = 2, h = 11, col = "moss", a = 0.72, lw = 2, sway = 4, rate = 0.37, bob = true },
    { kind = "hang", x = 614, y = 99, w = 2, h = 20, col = "moss", a = 0.51, lw = 2, sway = 2, rate = 0.23, bob = true },
    { kind = "hang", x = 209, y = 75, w = 2, h = 11, col = "moss", a = 0.67, lw = 2, sway = 4, rate = 0.44, bob = true },
    { kind = "hang", x = 414, y = 119, w = 2, h = 16, col = "moss", a = 0.52, lw = 2, sway = 4, rate = 0.32, bob = true },
    { kind = "hang", x = 588, y = 73, w = 2, h = 18, col = "moss", a = 0.57, lw = 2, sway = 5, rate = 0.22, bob = true },
    { kind = "hang", x = 589, y = 104, w = 2, h = 39, col = "moss", a = 0.45, lw = 2, sway = 6, rate = 0.26, bob = true },
    { kind = "hang", x = 358, y = 27, w = 2, h = 11, col = "moss", a = 0.53, lw = 2, sway = 5, rate = 0.39, bob = true },
    { kind = "hang", x = 567, y = 106, w = 2, h = 35, col = "moss", a = 0.63, lw = 2, sway = 3, rate = 0.27, bob = true },
    { kind = "rect", x = 553, y = 173, w = 12, h = 2, col = "lime", a = 0.25 },
    { kind = "rect", x = 764, y = 65, w = 13, h = 3, col = "lime", a = 0.23 },
    { kind = "rect", x = 431, y = 136, w = 17, h = 3, col = "lime", a = 0.38 },
    { kind = "rect", x = 946, y = 45, w = 9, h = 3, col = "moss", a = 0.39 },
    { kind = "rect", x = 720, y = 130, w = 10, h = 4, col = "moss", a = 0.25 },
    { kind = "rect", x = 145, y = 163, w = 17, h = 3, col = "lime", a = 0.2 },
    { kind = "rect", x = 407, y = 155, w = 14, h = 3, col = "fern", a = 0.31 },
    { kind = "rect", x = 770, y = 116, w = 15, h = 3, col = "moss", a = 0.3 },
    { kind = "rect", x = 645, y = 138, w = 17, h = 2, col = "fern", a = 0.3 },
    { kind = "rect", x = 946, y = 189, w = 8, h = 3, col = "lime", a = 0.38 },
    { kind = "rect", x = 770, y = 233, w = 10, h = 4, col = "lime", a = 0.2 },
    { kind = "rect", x = 691, y = 111, w = 14, h = 3, col = "fern", a = 0.26 },
    { kind = "rect", x = 279, y = 136, w = 13, h = 4, col = "moss", a = 0.37 },
    { kind = "rect", x = 781, y = 120, w = 8, h = 4, col = "fern", a = 0.24 },
    { kind = "rect", x = 432, y = 66, w = 6, h = 3, col = "fern", a = 0.42 },
    { kind = "rect", x = 151, y = 64, w = 16, h = 2, col = "moss", a = 0.21 },
    { kind = "rect", x = 537, y = 167, w = 6, h = 5, col = "lime", a = 0.36 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 13, w = 1008, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 948, y = 26, w = 2, h = 61, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.41, bob = true },
    { kind = "hang", x = 525, y = 26, w = 2, h = 52, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.51, bob = true },
    { kind = "hang", x = 116, y = 26, w = 2, h = 59, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.33, bob = true },
    { kind = "hang", x = 591, y = 26, w = 2, h = 61, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 920, y = 26, w = 2, h = 50, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.54, bob = true },
    { kind = "hang", x = 794, y = 26, w = 2, h = 52, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 9, rate = 0.45, bob = true },
    { kind = "hang", x = 870, y = 26, w = 2, h = 35, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.43, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 938, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 160, y = 43, col = { 0.80, 1.00, 0.66 }, r = 96, flicker = 1.08 },
    { x = 480, y = 43, col = { 0.80, 1.00, 0.66 }, r = 80, flicker = 1.17 },
    { x = 800, y = 43, col = { 0.80, 1.00, 0.66 }, r = 68, flicker = 1.68 },
  },
  mapPos = { x = 9, y = 0, w = 3, h = 1 },
  arena = "bramblemaw",
  map = [[
############################################################
############################################################
##........................................................##
##........................................................##
##........................................................##
##........................................................##
##........................................................##
##..........====..........................................##
##........................................................##
##...====.................====............................##
##........................................................##
A.........................................................BB
A.....1..........t........................................BB
############################################################
############################################################
############################################################
############################################################
]],
  key = {
    ["1"] = "sign:sign_moss_gate",
    ["t"] = "boss:bramblemaw",
  },
  links = {
    A = { "moss_5", "B" },
    B = { "flood_1", "A" },
  },
}
