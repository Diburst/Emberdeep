-- A hoard pocket under the roots. Somebody cached supplies here long ago,
-- and the well water has been adding to the pile ever since -- Tikka's
-- music box among the rest.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 272, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 34, h = 272, col = "black", a = 0.44, py = 0.18, step = 30, acc = "violet" },
    { kind = "column", x = 73, y = 0, w = 35, h = 272, col = "black", a = 0.44, py = 0.29, step = 34, acc = "violet" },
    { kind = "column", x = 170, y = 0, w = 26, h = 272, col = "black", a = 0.44, py = 0.22, step = 30, acc = "violet" },
    { kind = "column", x = 258, y = 0, w = 28, h = 272, col = "black", a = 0.44, py = 0.29, step = 41, acc = "violet" },
    { kind = "column", x = 359, y = 0, w = 28, h = 272, col = "black", a = 0.44, py = 0.22, step = 43, acc = "violet" },
    { kind = "column", x = 466, y = 0, w = 30, h = 272, col = "black", a = 0.44, py = 0.27, step = 34, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 190, y = 212, w = 2, h = 2, col = "orchid", a = 0.49 },
    { kind = "rect", x = 340, y = 68, w = 5, h = 2, col = "violet", a = 0.83 },
    { kind = "rect", x = 342, y = 29, w = 3, h = 5, col = "violet", a = 0.8 },
    { kind = "rect", x = 383, y = 51, w = 4, h = 2, col = "orchid", a = 0.49 },
    { kind = "rect", x = 299, y = 31, w = 5, h = 4, col = "violet", a = 0.48 },
    { kind = "rect", x = 12, y = 178, w = 3, h = 3, col = "orchid", a = 0.71 },
    { kind = "rect", x = 190, y = 44, w = 3, h = 5, col = "lime", a = 0.61 },
    { kind = "rect", x = 104, y = 78, w = 4, h = 5, col = "violet", a = 0.65 },
    { kind = "rect", x = 239, y = 164, w = 5, h = 5, col = "lime", a = 0.67 },
    { kind = "rect", x = 21, y = 134, w = 3, h = 4, col = "orchid", a = 0.77 },
    { kind = "rect", x = 43, y = 198, w = 2, h = 5, col = "orchid", a = 0.59 },
    { kind = "rect", x = 418, y = 151, w = 3, h = 2, col = "lime", a = 0.68 },
    { kind = "hang", x = 257, y = 134, w = 2, h = 36, col = "plum", a = 0.49, lw = 2, sway = 3, rate = 0.27, bob = true },
    { kind = "hang", x = 270, y = 62, w = 2, h = 33, col = "plum", a = 0.45, lw = 2, sway = 2, rate = 0.42, bob = true },
    { kind = "hang", x = 45, y = 63, w = 2, h = 32, col = "plum", a = 0.48, lw = 2, sway = 5, rate = 0.23, bob = true },
    { kind = "hang", x = 397, y = 53, w = 2, h = 14, col = "plum", a = 0.33, lw = 2, sway = 2, rate = 0.22, bob = true },
    { kind = "hang", x = 268, y = 15, w = 2, h = 20, col = "plum", a = 0.56, lw = 2, sway = 4, rate = 0.26, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 450, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 152, y = 0, w = 15, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 119, y = 0, w = 14, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 324, y = 171, col = { 0.70, 0.45, 1.00 }, r = 41, flicker = 3.57 },
    { x = 50, y = 158, col = { 0.70, 0.45, 1.00 }, r = 60, flicker = 4.03 },
  },
  mapPos = { x = 7, y = 3, w = 1, h = 1 },
  dark = 0.75,
  map = [[
##############AAA#############
##############AAA#############
##...####..................###
##..........................##
##..........................##
##...........=====.........###
###........................###
####......................####
##.........=====..........####
####........................##
####...............1........##
###..............=====......##
##........................%%BB
##.b.8..b...........x...9.%%BB
##############################
##############################
##############################
]],
  key = {
    ["x"] = "frostpatch:6",
    ["1"] = "chest:musicbox_chest:module:musicbox",
    ["8"] = "chest:chest_ugsec:scrap:40",
    ["9"] = "chest:chest_ugsec2:bigshard:6",
    ["b"] = "sporebulb",
  },
  links = {
    A = { "ug_6", "D" },
    -- THE WAY INTO THE COLDSTORE. Behind two courses of shootable wall,
    -- with rime spilling out from under them onto floor that has no
    -- business being cold. ug_secret is already a room you only stand in
    -- if you went looking, so a player who gets this far has proved they
    -- explore -- which is exactly who the archive is written for.
    B = { "cold_1", "A" },
  },
}
