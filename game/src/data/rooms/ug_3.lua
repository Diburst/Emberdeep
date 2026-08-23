-- Root Hollow: the Undergrove waystation. The deep doors are sealed to the lightless.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 272, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 33, h = 272, col = "black", a = 0.44, py = 0.29, step = 38, acc = "violet" },
    { kind = "column", x = 75, y = 0, w = 29, h = 272, col = "black", a = 0.44, py = 0.19, step = 28, acc = "violet" },
    { kind = "column", x = 143, y = 0, w = 24, h = 272, col = "black", a = 0.44, py = 0.24, step = 35, acc = "violet" },
    { kind = "column", x = 242, y = 0, w = 26, h = 272, col = "black", a = 0.44, py = 0.16, step = 38, acc = "violet" },
    { kind = "column", x = 313, y = 0, w = 33, h = 272, col = "black", a = 0.44, py = 0.2, step = 44, acc = "violet" },
    { kind = "column", x = 416, y = 0, w = 21, h = 272, col = "black", a = 0.44, py = 0.26, step = 31, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 242, y = 72, w = 5, h = 5, col = "violet", a = 0.6 },
    { kind = "rect", x = 184, y = 85, w = 4, h = 3, col = "violet", a = 0.68 },
    { kind = "rect", x = 247, y = 83, w = 5, h = 5, col = "violet", a = 0.59 },
    { kind = "rect", x = 56, y = 64, w = 5, h = 3, col = "orchid", a = 0.57 },
    { kind = "rect", x = 61, y = 137, w = 3, h = 2, col = "lime", a = 0.58 },
    { kind = "rect", x = 470, y = 237, w = 2, h = 2, col = "lime", a = 0.51 },
    { kind = "rect", x = 98, y = 56, w = 2, h = 3, col = "lime", a = 0.77 },
    { kind = "rect", x = 99, y = 122, w = 2, h = 2, col = "orchid", a = 0.43 },
    { kind = "rect", x = 316, y = 197, w = 5, h = 4, col = "lime", a = 0.75 },
    { kind = "rect", x = 224, y = 98, w = 4, h = 4, col = "violet", a = 0.48 },
    { kind = "rect", x = 217, y = 195, w = 2, h = 5, col = "lime", a = 0.45 },
    { kind = "rect", x = 176, y = 34, w = 5, h = 3, col = "lime", a = 0.61 },
    { kind = "hang", x = 199, y = 44, w = 2, h = 31, col = "plum", a = 0.58, lw = 2, sway = 3, rate = 0.23, bob = true },
    { kind = "hang", x = 126, y = 11, w = 2, h = 19, col = "plum", a = 0.58, lw = 2, sway = 3, rate = 0.44, bob = true },
    { kind = "hang", x = 450, y = 17, w = 2, h = 18, col = "plum", a = 0.37, lw = 2, sway = 4, rate = 0.41, bob = true },
    { kind = "hang", x = 347, y = 125, w = 2, h = 33, col = "plum", a = 0.45, lw = 2, sway = 2, rate = 0.23, bob = true },
    { kind = "hang", x = 385, y = 26, w = 2, h = 25, col = "plum", a = 0.51, lw = 2, sway = 3, rate = 0.42, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 450, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 161, y = 0, w = 15, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 341, y = 0, w = 11, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 194, y = 134, col = { 0.70, 0.45, 1.00 }, r = 47, flicker = 4.88 },
    { x = 115, y = 149, col = { 0.70, 0.45, 1.00 }, r = 53, flicker = 3 },
  },
  mapPos = { x = 3, y = 0, w = 1, h = 1 },
  dark = 0.7,
  hasTeleporter = true,
  gates = { H = "lumecore" },
  map = [[
##############################
##############################
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
AA.......................H..BB
AA..................1....H..BB
##...t..s...........#....H..##
##############...#############
##############...#############
##############DDD#############
##############DDD#############
]],
  key = {
    ["t"] = "teleporter:undergrove",
    ["s"] = "checkpoint",
    ["1"] = "sign:sign_roothollow",
  },
  links = {
    A = { "ug_2", "B" },
    B = { "ug_4", "A" },
    D = { "ug_rescue", "A" },
  },
}
