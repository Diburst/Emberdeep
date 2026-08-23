-- generated (v4.1)
return {
  zone = "furnace", music = "furnace",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 272, col = "maroon", a = 0.1, a2 = 0.42, py = 0.05 },
    { kind = "rect", x = -18, y = 181, w = 55, h = 91, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 83, y = 142, w = 41, h = 130, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 151, y = 170, w = 52, h = 102, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 230, y = 93, w = 32, h = 179, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 306, y = 185, w = 37, h = 87, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 376, y = 162, w = 32, h = 110, col = "black", a = 0.4, py = 0.22 },
    { kind = "rect", x = 448, y = 174, w = 53, h = 98, col = "black", a = 0.4, py = 0.22 },
    { kind = "girder", x = -16, y = 43, w = 512, h = 14, col = "black", a = 0.42, py = 0.28, step = 27 },
    { kind = "girder", x = -16, y = 108, w = 512, h = 14, col = "black", a = 0.42, py = 0.28, step = 30 },
    { kind = "shaft", x = 257, y = 95, w = 41, h = 163, col = "magma", a = 0.2, py = 0.14, skew = 10, ph = 2.98 },
    { kind = "shaft", x = 414, y = 95, w = 44, h = 163, col = "magma", a = 0.2, py = 0.14, skew = 13, ph = 4.51 },
    { kind = "shaft", x = 355, y = 95, w = 36, h = 163, col = "magma", a = 0.2, py = 0.14, skew = 6, ph = 2.89 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 14, y = 66, w = 6, h = 29, col = "rust", a = 0.35 },
    { kind = "rect", x = 68, y = 58, w = 3, h = 26, col = "rust", a = 0.33 },
    { kind = "rect", x = 212, y = 185, w = 7, h = 14, col = "rust", a = 0.3 },
    { kind = "rect", x = 150, y = 177, w = 3, h = 13, col = "rust", a = 0.33 },
    { kind = "rect", x = 83, y = 225, w = 4, h = 22, col = "rust", a = 0.26 },
    { kind = "rect", x = 217, y = 118, w = 3, h = 26, col = "rust", a = 0.36 },
    { kind = "rect", x = 47, y = 91, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 49, y = 93, w = 4, h = 6, col = "magma", a = 1 },
    { kind = "rect", x = 298, y = 135, w = 8, h = 10, col = "rust", a = 0.9 },
    { kind = "rect", x = 300, y = 137, w = 4, h = 6, col = "magma", a = 1 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 13, w = 528, h = 16, col = "black", a = 0.9, py = -0.13, step = 32 },
    { kind = "hang", x = 321, y = 29, w = 2, h = 42, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 352, y = 29, w = 2, h = 29, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 265, y = 29, w = 2, h = 32, col = "black", a = 0.85, py = -0.13, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "band", x = 0, y = 0, w = 24, h = 272, col = "black", a = 0.5, a2 = 0.5, py = -0.06 },
    { kind = "band", x = 456, y = 0, w = 24, h = 272, col = "black", a = 0.5, a2 = 0.5, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 51, y = 96, col = { 1.00, 0.52, 0.20 }, r = 58, flicker = 5.74 },
    { x = 302, y = 140, col = { 1.00, 0.52, 0.20 }, r = 59, flicker = 5.48 },
    { x = 132, y = 239, col = { 1.00, 0.40, 0.14 }, r = 105, flicker = 2.82 },
  },
  mapPos = { x = 3, y = 1, w = 1, h = 1 },
  gates = { G = "linkcore_fc" },
  map = [[
##############################
##############################
##............G.............##
##............G.............##
##............G.............##
##............G.............##
##............G.............##
##............G.............##
##............G.............##
##............G.............##
AA............G.............##
AA........k...G.....3...4...##
##############################
##############################
##############################
##############################
##############################
]],
  key = {
    ["k"] = "linkcore:linkcore_fc",
    ["3"] = "chest:ch_fc1:bigshard:5",
    ["4"] = "chest:ch_fc2:scrap:25",
  },
  links = {
    A = { "furn_2", "C" },
  },
}
