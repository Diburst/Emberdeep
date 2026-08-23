-- The mycel gallery. Things regrow here if you do not finish them.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 736, h = 272, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 24, h = 272, col = "black", a = 0.44, py = 0.29, step = 30, acc = "violet" },
    { kind = "column", x = 55, y = 0, w = 28, h = 272, col = "black", a = 0.44, py = 0.26, step = 30, acc = "violet" },
    { kind = "column", x = 166, y = 0, w = 27, h = 272, col = "black", a = 0.44, py = 0.19, step = 27, acc = "violet" },
    { kind = "column", x = 237, y = 0, w = 37, h = 272, col = "black", a = 0.44, py = 0.29, step = 24, acc = "violet" },
    { kind = "column", x = 343, y = 0, w = 34, h = 272, col = "black", a = 0.44, py = 0.24, step = 31, acc = "violet" },
    { kind = "column", x = 447, y = 0, w = 30, h = 272, col = "black", a = 0.44, py = 0.2, step = 44, acc = "violet" },
    { kind = "column", x = 533, y = 0, w = 26, h = 272, col = "black", a = 0.44, py = 0.26, step = 33, acc = "violet" },
    { kind = "column", x = 643, y = 0, w = 19, h = 272, col = "black", a = 0.44, py = 0.25, step = 37, acc = "violet" },
    { kind = "column", x = 701, y = 0, w = 26, h = 272, col = "black", a = 0.44, py = 0.17, step = 38, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 432, y = 198, w = 4, h = 2, col = "violet", a = 0.82 },
    { kind = "rect", x = 182, y = 218, w = 4, h = 3, col = "lime", a = 0.59 },
    { kind = "rect", x = 612, y = 184, w = 2, h = 4, col = "violet", a = 0.71 },
    { kind = "rect", x = 706, y = 101, w = 3, h = 4, col = "violet", a = 0.47 },
    { kind = "rect", x = 365, y = 80, w = 2, h = 4, col = "lime", a = 0.71 },
    { kind = "rect", x = 600, y = 123, w = 3, h = 5, col = "orchid", a = 0.57 },
    { kind = "rect", x = 143, y = 189, w = 3, h = 2, col = "lime", a = 0.47 },
    { kind = "rect", x = 432, y = 209, w = 5, h = 4, col = "orchid", a = 0.62 },
    { kind = "rect", x = 68, y = 87, w = 3, h = 3, col = "violet", a = 0.43 },
    { kind = "rect", x = 674, y = 44, w = 4, h = 5, col = "lime", a = 0.56 },
    { kind = "rect", x = 681, y = 240, w = 3, h = 4, col = "violet", a = 0.58 },
    { kind = "rect", x = 691, y = 140, w = 5, h = 3, col = "orchid", a = 0.78 },
    { kind = "rect", x = 133, y = 37, w = 3, h = 5, col = "violet", a = 0.66 },
    { kind = "rect", x = 19, y = 32, w = 3, h = 2, col = "orchid", a = 0.6 },
    { kind = "rect", x = 38, y = 152, w = 4, h = 4, col = "orchid", a = 0.77 },
    { kind = "rect", x = 316, y = 225, w = 2, h = 3, col = "orchid", a = 0.84 },
    { kind = "rect", x = 254, y = 85, w = 3, h = 4, col = "lime", a = 0.46 },
    { kind = "rect", x = 278, y = 75, w = 3, h = 2, col = "violet", a = 0.47 },
    { kind = "hang", x = 407, y = 64, w = 2, h = 22, col = "plum", a = 0.37, lw = 2, sway = 2, rate = 0.32, bob = true },
    { kind = "hang", x = 508, y = 18, w = 2, h = 36, col = "plum", a = 0.48, lw = 2, sway = 3, rate = 0.22, bob = true },
    { kind = "hang", x = 247, y = 135, w = 2, h = 38, col = "plum", a = 0.48, lw = 2, sway = 5, rate = 0.23, bob = true },
    { kind = "hang", x = 463, y = 22, w = 2, h = 29, col = "plum", a = 0.3, lw = 2, sway = 2, rate = 0.32, bob = true },
    { kind = "hang", x = 26, y = 24, w = 2, h = 40, col = "plum", a = 0.35, lw = 2, sway = 2, rate = 0.48, bob = true },
    { kind = "hang", x = 717, y = 136, w = 2, h = 35, col = "plum", a = 0.48, lw = 2, sway = 4, rate = 0.36, bob = true },
    { kind = "hang", x = 66, y = 42, w = 2, h = 36, col = "plum", a = 0.54, lw = 2, sway = 2, rate = 0.42, bob = true },
    { kind = "hang", x = 36, y = 112, w = 2, h = 13, col = "plum", a = 0.3, lw = 2, sway = 4, rate = 0.22, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 706, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 377, y = 0, w = 14, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 380, y = 0, w = 12, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 223, y = 0, w = 16, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 461, y = 211, col = { 0.70, 0.45, 1.00 }, r = 48, flicker = 2.52 },
    { x = 128, y = 115, col = { 0.70, 0.45, 1.00 }, r = 55, flicker = 2.5 },
    { x = 579, y = 91, col = { 0.70, 0.45, 1.00 }, r = 58, flicker = 4.04 },
  },
  mapPos = { x = 4, y = 0, w = 2, h = 1 },
  dark = 0.85,
  map = [[
##############################################
##############################################
##..........................................##
##..........................................##
##..........................f...............##
##................k.........................##
##..............======......................##
##.............w............................##
##..........................................##
##......======..........======..............##
AA..........................................BB
AA....b.............m.....b.........m...b...BB
##..........................................##
##############################################
##############################################
##############################################
##############################################
]],
  key = {
    ["k"] = "mitehusk:glowmite2",
    ["m"] = "myceling",
    ["f"] = "sporefly",
    ["b"] = "sporebulb",
    ["w"] = "glowmite",
  },
  links = {
    A = { "ug_3", "B" },
    B = { "ug_5", "A" },
  },
}
