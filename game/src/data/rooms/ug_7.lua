-- The approach. The walls hum. Something down here still sings.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 736, h = 272, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 27, h = 272, col = "black", a = 0.44, py = 0.28, step = 27, acc = "violet" },
    { kind = "column", x = 70, y = 0, w = 34, h = 272, col = "black", a = 0.44, py = 0.21, step = 29, acc = "violet" },
    { kind = "column", x = 138, y = 0, w = 34, h = 272, col = "black", a = 0.44, py = 0.29, step = 38, acc = "violet" },
    { kind = "column", x = 246, y = 0, w = 29, h = 272, col = "black", a = 0.44, py = 0.18, step = 26, acc = "violet" },
    { kind = "column", x = 341, y = 0, w = 23, h = 272, col = "black", a = 0.44, py = 0.27, step = 40, acc = "violet" },
    { kind = "column", x = 430, y = 0, w = 31, h = 272, col = "black", a = 0.44, py = 0.24, step = 28, acc = "violet" },
    { kind = "column", x = 527, y = 0, w = 27, h = 272, col = "black", a = 0.44, py = 0.23, step = 24, acc = "violet" },
    { kind = "column", x = 640, y = 0, w = 26, h = 272, col = "black", a = 0.44, py = 0.25, step = 43, acc = "violet" },
    { kind = "column", x = 720, y = 0, w = 19, h = 272, col = "black", a = 0.44, py = 0.29, step = 39, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 155, y = 161, w = 4, h = 5, col = "orchid", a = 0.57 },
    { kind = "rect", x = 90, y = 101, w = 4, h = 4, col = "violet", a = 0.72 },
    { kind = "rect", x = 62, y = 236, w = 2, h = 4, col = "lime", a = 0.61 },
    { kind = "rect", x = 539, y = 186, w = 4, h = 4, col = "lime", a = 0.43 },
    { kind = "rect", x = 374, y = 74, w = 4, h = 3, col = "lime", a = 0.66 },
    { kind = "rect", x = 463, y = 134, w = 4, h = 2, col = "lime", a = 0.73 },
    { kind = "rect", x = 494, y = 174, w = 5, h = 3, col = "orchid", a = 0.56 },
    { kind = "rect", x = 132, y = 133, w = 3, h = 5, col = "orchid", a = 0.46 },
    { kind = "rect", x = 244, y = 175, w = 5, h = 5, col = "lime", a = 0.48 },
    { kind = "rect", x = 127, y = 150, w = 3, h = 5, col = "violet", a = 0.57 },
    { kind = "rect", x = 259, y = 130, w = 2, h = 4, col = "lime", a = 0.61 },
    { kind = "rect", x = 618, y = 80, w = 3, h = 2, col = "violet", a = 0.75 },
    { kind = "rect", x = 584, y = 121, w = 4, h = 3, col = "orchid", a = 0.81 },
    { kind = "rect", x = 335, y = 197, w = 2, h = 5, col = "lime", a = 0.51 },
    { kind = "rect", x = 151, y = 114, w = 4, h = 3, col = "violet", a = 0.65 },
    { kind = "rect", x = 221, y = 99, w = 5, h = 2, col = "violet", a = 0.65 },
    { kind = "rect", x = 220, y = 127, w = 2, h = 3, col = "violet", a = 0.84 },
    { kind = "rect", x = 604, y = 146, w = 3, h = 5, col = "orchid", a = 0.78 },
    { kind = "hang", x = 152, y = 74, w = 2, h = 19, col = "plum", a = 0.44, lw = 2, sway = 5, rate = 0.46, bob = true },
    { kind = "hang", x = 662, y = 0, w = 2, h = 24, col = "plum", a = 0.53, lw = 2, sway = 5, rate = 0.39, bob = true },
    { kind = "hang", x = 13, y = 103, w = 2, h = 20, col = "plum", a = 0.46, lw = 2, sway = 2, rate = 0.36, bob = true },
    { kind = "hang", x = 18, y = 69, w = 2, h = 14, col = "plum", a = 0.44, lw = 2, sway = 4, rate = 0.27, bob = true },
    { kind = "hang", x = 470, y = 20, w = 2, h = 14, col = "plum", a = 0.45, lw = 2, sway = 3, rate = 0.23, bob = true },
    { kind = "hang", x = 125, y = 112, w = 2, h = 14, col = "plum", a = 0.56, lw = 2, sway = 2, rate = 0.49, bob = true },
    { kind = "hang", x = 573, y = 112, w = 2, h = 14, col = "plum", a = 0.56, lw = 2, sway = 5, rate = 0.32, bob = true },
    { kind = "hang", x = 108, y = 65, w = 2, h = 18, col = "plum", a = 0.53, lw = 2, sway = 2, rate = 0.21, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 706, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 408, y = 0, w = 10, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 19, y = 0, w = 12, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 655, y = 0, w = 10, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 463, y = 145, col = { 0.70, 0.45, 1.00 }, r = 48, flicker = 2.9 },
    { x = 208, y = 93, col = { 0.70, 0.45, 1.00 }, r = 41, flicker = 4.04 },
    { x = 88, y = 105, col = { 0.70, 0.45, 1.00 }, r = 40, flicker = 4.57 },
  },
  mapPos = { x = 8, y = 2, w = 2, h = 1 },
  dark = 0.85,
  map = [[
##############################################
##############################################
##..........................................##
##..........................................##
##................................f.........##
##....................7.....................##
##..................======..................##
##..........................................##
##..........................................##
##............======........................##
AA..........................................BB
AA..........................................BB
##....z.b...m.................m......b..1a..##
##############################################
##############################################
##############################################
##############################################
]],
  key = {
    ["a"] = "cell",
    ["z"] = "checkpoint",
    ["1"] = "sign:sign_choir",
    ["7"] = "chest:chest_ferrocoil:module:ferrocoil",
    ["m"] = "myceling",
    ["f"] = "sporefly",
    ["b"] = "sporebulb",
  },
  links = {
    A = { "ug_6", "B" },
    B = { "ug_boss", "A" },
  },
}
