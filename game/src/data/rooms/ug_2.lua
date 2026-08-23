-- First caverns under the well. The dark thickens; spores glow when struck.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 736, h = 272, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 18, h = 272, col = "black", a = 0.44, py = 0.25, step = 41, acc = "violet" },
    { kind = "column", x = 75, y = 0, w = 27, h = 272, col = "black", a = 0.44, py = 0.3, step = 29, acc = "violet" },
    { kind = "column", x = 136, y = 0, w = 28, h = 272, col = "black", a = 0.44, py = 0.26, step = 27, acc = "violet" },
    { kind = "column", x = 225, y = 0, w = 25, h = 272, col = "black", a = 0.44, py = 0.27, step = 27, acc = "violet" },
    { kind = "column", x = 315, y = 0, w = 33, h = 272, col = "black", a = 0.44, py = 0.23, step = 44, acc = "violet" },
    { kind = "column", x = 384, y = 0, w = 32, h = 272, col = "black", a = 0.44, py = 0.22, step = 42, acc = "violet" },
    { kind = "column", x = 465, y = 0, w = 27, h = 272, col = "black", a = 0.44, py = 0.21, step = 33, acc = "violet" },
    { kind = "column", x = 577, y = 0, w = 23, h = 272, col = "black", a = 0.44, py = 0.23, step = 32, acc = "violet" },
    { kind = "column", x = 690, y = 0, w = 33, h = 272, col = "black", a = 0.44, py = 0.2, step = 44, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 504, y = 156, w = 3, h = 5, col = "violet", a = 0.56 },
    { kind = "rect", x = 150, y = 200, w = 4, h = 4, col = "orchid", a = 0.85 },
    { kind = "rect", x = 512, y = 56, w = 4, h = 3, col = "lime", a = 0.73 },
    { kind = "rect", x = 604, y = 88, w = 5, h = 3, col = "lime", a = 0.52 },
    { kind = "rect", x = 477, y = 129, w = 5, h = 3, col = "violet", a = 0.74 },
    { kind = "rect", x = 330, y = 107, w = 4, h = 5, col = "lime", a = 0.52 },
    { kind = "rect", x = 432, y = 36, w = 3, h = 4, col = "violet", a = 0.53 },
    { kind = "rect", x = 598, y = 191, w = 3, h = 3, col = "orchid", a = 0.71 },
    { kind = "rect", x = 78, y = 37, w = 5, h = 2, col = "lime", a = 0.68 },
    { kind = "rect", x = 329, y = 111, w = 2, h = 4, col = "violet", a = 0.8 },
    { kind = "rect", x = 581, y = 92, w = 2, h = 2, col = "lime", a = 0.54 },
    { kind = "rect", x = 261, y = 193, w = 2, h = 4, col = "violet", a = 0.68 },
    { kind = "rect", x = 524, y = 180, w = 3, h = 4, col = "lime", a = 0.44 },
    { kind = "rect", x = 227, y = 74, w = 5, h = 2, col = "orchid", a = 0.76 },
    { kind = "rect", x = 121, y = 83, w = 2, h = 5, col = "violet", a = 0.8 },
    { kind = "rect", x = 525, y = 172, w = 5, h = 5, col = "orchid", a = 0.64 },
    { kind = "rect", x = 264, y = 125, w = 5, h = 5, col = "lime", a = 0.48 },
    { kind = "rect", x = 71, y = 190, w = 4, h = 5, col = "violet", a = 0.67 },
    { kind = "hang", x = 414, y = 17, w = 2, h = 15, col = "plum", a = 0.59, lw = 2, sway = 5, rate = 0.32, bob = true },
    { kind = "hang", x = 621, y = 61, w = 2, h = 18, col = "plum", a = 0.31, lw = 2, sway = 5, rate = 0.3, bob = true },
    { kind = "hang", x = 708, y = 78, w = 2, h = 31, col = "plum", a = 0.58, lw = 2, sway = 3, rate = 0.31, bob = true },
    { kind = "hang", x = 392, y = 121, w = 2, h = 23, col = "plum", a = 0.32, lw = 2, sway = 3, rate = 0.29, bob = true },
    { kind = "hang", x = 483, y = 70, w = 2, h = 15, col = "plum", a = 0.46, lw = 2, sway = 4, rate = 0.23, bob = true },
    { kind = "hang", x = 655, y = 47, w = 2, h = 18, col = "plum", a = 0.5, lw = 2, sway = 3, rate = 0.34, bob = true },
    { kind = "hang", x = 646, y = 112, w = 2, h = 25, col = "plum", a = 0.6, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 297, y = 133, w = 2, h = 35, col = "plum", a = 0.39, lw = 2, sway = 4, rate = 0.45, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 706, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 519, y = 0, w = 10, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 391, y = 0, w = 12, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 625, y = 0, w = 14, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 661, y = 92, col = { 0.70, 0.45, 1.00 }, r = 44, flicker = 3.12 },
    { x = 548, y = 104, col = { 0.70, 0.45, 1.00 }, r = 38, flicker = 2.85 },
    { x = 237, y = 154, col = { 0.70, 0.45, 1.00 }, r = 60, flicker = 2.75 },
  },
  mapPos = { x = 1, y = 0, w = 2, h = 1 },
  dark = 0.8,
  map = [[
##############################################
##############################################
AA..........................................##
AA..........................................##
##=====.............f.......................##
##......................k...................##
##..======.............=====................##
##=.........................................##
##.........w..........==....................##
##..======....................======........##
##............======........................BB
##=.........1...b........b.......m....b.....BB
##..........................................##
##############################################
##############################################
##############################################
##############################################
]],
  key = {
    ["1"] = "sign:sign_dark",
    ["b"] = "sporebulb",
    ["k"] = "mitehusk:glowmite1",
    ["m"] = "myceling",
    ["f"] = "sporefly",
    ["w"] = "glowmite",
  },
  links = {
    A = { "ug_1", "B" },
    B = { "ug_3", "A" },
  },
}
