-- Flooded roots. The water tables of the old well pool here in the dark.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 736, h = 352, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 28, h = 352, col = "black", a = 0.44, py = 0.29, step = 42, acc = "violet" },
    { kind = "column", x = 85, y = 0, w = 34, h = 352, col = "black", a = 0.44, py = 0.3, step = 33, acc = "violet" },
    { kind = "column", x = 200, y = 0, w = 22, h = 352, col = "black", a = 0.44, py = 0.16, step = 24, acc = "violet" },
    { kind = "column", x = 281, y = 0, w = 37, h = 352, col = "black", a = 0.44, py = 0.27, step = 28, acc = "violet" },
    { kind = "column", x = 364, y = 0, w = 24, h = 352, col = "black", a = 0.44, py = 0.18, step = 44, acc = "violet" },
    { kind = "column", x = 466, y = 0, w = 27, h = 352, col = "black", a = 0.44, py = 0.23, step = 36, acc = "violet" },
    { kind = "column", x = 552, y = 0, w = 20, h = 352, col = "black", a = 0.44, py = 0.26, step = 26, acc = "violet" },
    { kind = "column", x = 615, y = 0, w = 35, h = 352, col = "black", a = 0.44, py = 0.24, step = 35, acc = "violet" },
    { kind = "column", x = 693, y = 0, w = 27, h = 352, col = "black", a = 0.44, py = 0.2, step = 41, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 284, y = 43, w = 3, h = 3, col = "lime", a = 0.7 },
    { kind = "rect", x = 343, y = 43, w = 2, h = 3, col = "lime", a = 0.83 },
    { kind = "rect", x = 286, y = 117, w = 3, h = 4, col = "lime", a = 0.47 },
    { kind = "rect", x = 40, y = 276, w = 3, h = 4, col = "violet", a = 0.72 },
    { kind = "rect", x = 399, y = 37, w = 3, h = 3, col = "orchid", a = 0.83 },
    { kind = "rect", x = 133, y = 264, w = 5, h = 4, col = "orchid", a = 0.44 },
    { kind = "rect", x = 520, y = 61, w = 3, h = 5, col = "orchid", a = 0.75 },
    { kind = "rect", x = 567, y = 239, w = 5, h = 2, col = "lime", a = 0.64 },
    { kind = "rect", x = 252, y = 311, w = 3, h = 5, col = "lime", a = 0.48 },
    { kind = "rect", x = 79, y = 65, w = 5, h = 3, col = "lime", a = 0.79 },
    { kind = "rect", x = 614, y = 59, w = 5, h = 2, col = "lime", a = 0.54 },
    { kind = "rect", x = 142, y = 260, w = 3, h = 2, col = "lime", a = 0.54 },
    { kind = "rect", x = 109, y = 273, w = 5, h = 3, col = "orchid", a = 0.45 },
    { kind = "rect", x = 592, y = 293, w = 2, h = 4, col = "violet", a = 0.56 },
    { kind = "rect", x = 228, y = 202, w = 3, h = 2, col = "lime", a = 0.66 },
    { kind = "rect", x = 106, y = 254, w = 2, h = 2, col = "orchid", a = 0.75 },
    { kind = "rect", x = 579, y = 71, w = 2, h = 4, col = "orchid", a = 0.57 },
    { kind = "rect", x = 168, y = 299, w = 3, h = 2, col = "violet", a = 0.5 },
    { kind = "hang", x = 713, y = 1, w = 2, h = 30, col = "plum", a = 0.35, lw = 2, sway = 4, rate = 0.22, bob = true },
    { kind = "hang", x = 225, y = 96, w = 2, h = 21, col = "plum", a = 0.36, lw = 2, sway = 5, rate = 0.43, bob = true },
    { kind = "hang", x = 599, y = 39, w = 2, h = 12, col = "plum", a = 0.45, lw = 2, sway = 3, rate = 0.37, bob = true },
    { kind = "hang", x = 251, y = 19, w = 2, h = 34, col = "plum", a = 0.46, lw = 2, sway = 3, rate = 0.27, bob = true },
    { kind = "hang", x = 92, y = 114, w = 2, h = 27, col = "plum", a = 0.56, lw = 2, sway = 2, rate = 0.29, bob = true },
    { kind = "hang", x = 181, y = 91, w = 2, h = 25, col = "plum", a = 0.46, lw = 2, sway = 2, rate = 0.49, bob = true },
    { kind = "hang", x = 448, y = 61, w = 2, h = 18, col = "plum", a = 0.38, lw = 2, sway = 5, rate = 0.25, bob = true },
    { kind = "hang", x = 465, y = 142, w = 2, h = 32, col = "plum", a = 0.5, lw = 2, sway = 3, rate = 0.21, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 352, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 706, y = 0, w = 30, h = 352, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 175, y = 0, w = 10, h = 352, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 551, y = 0, w = 16, h = 352, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 64, y = 0, w = 12, h = 352, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 479, y = 245, col = { 0.70, 0.45, 1.00 }, r = 56, flicker = 4 },
    { x = 71, y = 241, col = { 0.70, 0.45, 1.00 }, r = 52, flicker = 3.17 },
    { x = 481, y = 136, col = { 0.70, 0.45, 1.00 }, r = 60, flicker = 4.53 },
  },
  mapPos = { x = 6, y = 2, w = 2, h = 1 },
  dark = 0.8,
  map = [[
######AAA#####################################
######AAA#####################################
##..........................................##
##..======..................................##
##..........................................##
##########..................................##
#########...................................##
######.......=======........................##
###.........................................##
##.........==..f............................##
##.....................................w....##
##..======..................................##
##..........................................BB
##....................b......m..b...........BB
######...............###...#######........####
######~~~~~~~~~~~~~~~###...#######~~~~~~~~####
######~~~~~~~~~~~~~~~###...#######~~~k~~~~####
######~~~~~~4~~~~~~~~###...#######~~~~~~~~####
######~~~~~~~~~~~~~~~###...#######~~~~~~~~####
########################...###################
########################DDD###################
########################DDD###################
]],
  key = {
    ["4"] = "tank:tank_ug",
    ["k"] = "mitehusk:glowmite3",
    ["m"] = "myceling",
    ["b"] = "sporebulb",
    ["f"] = "sporefly",
    ["w"] = "glowmite",
  },
  links = {
    A = { "ug_5", "B" },
    B = { "ug_7", "A" },
    D = { "ug_secret", "A" },
  },
}
