-- A collapsed pocket. Ferro is stranded; Mote will not leave her glowmites.
return {
  zone = "undergrove", music = "undergrove",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 272, col = "black", a = 0.5, a2 = 0.16, py = 0.05 },
    { kind = "column", x = -14, y = 0, w = 28, h = 272, col = "black", a = 0.44, py = 0.28, step = 41, acc = "violet" },
    { kind = "column", x = 53, y = 0, w = 28, h = 272, col = "black", a = 0.44, py = 0.25, step = 38, acc = "violet" },
    { kind = "column", x = 164, y = 0, w = 35, h = 272, col = "black", a = 0.44, py = 0.24, step = 38, acc = "violet" },
    { kind = "column", x = 246, y = 0, w = 38, h = 272, col = "black", a = 0.44, py = 0.24, step = 43, acc = "violet" },
    { kind = "column", x = 331, y = 0, w = 19, h = 272, col = "black", a = 0.44, py = 0.28, step = 27, acc = "violet" },
    { kind = "column", x = 426, y = 0, w = 31, h = 272, col = "black", a = 0.44, py = 0.3, step = 41, acc = "violet" },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 19, y = 77, w = 3, h = 3, col = "lime", a = 0.69 },
    { kind = "rect", x = 29, y = 204, w = 2, h = 3, col = "lime", a = 0.46 },
    { kind = "rect", x = 215, y = 234, w = 4, h = 3, col = "lime", a = 0.55 },
    { kind = "rect", x = 14, y = 38, w = 4, h = 4, col = "violet", a = 0.62 },
    { kind = "rect", x = 271, y = 72, w = 4, h = 3, col = "violet", a = 0.58 },
    { kind = "rect", x = 274, y = 120, w = 5, h = 3, col = "violet", a = 0.46 },
    { kind = "rect", x = 300, y = 138, w = 5, h = 2, col = "violet", a = 0.51 },
    { kind = "rect", x = 321, y = 138, w = 3, h = 5, col = "violet", a = 0.62 },
    { kind = "rect", x = 47, y = 66, w = 5, h = 2, col = "lime", a = 0.46 },
    { kind = "rect", x = 179, y = 78, w = 3, h = 5, col = "violet", a = 0.6 },
    { kind = "rect", x = 35, y = 69, w = 3, h = 3, col = "violet", a = 0.59 },
    { kind = "rect", x = 336, y = 113, w = 3, h = 3, col = "orchid", a = 0.51 },
    { kind = "hang", x = 299, y = 58, w = 2, h = 19, col = "plum", a = 0.4, lw = 2, sway = 2, rate = 0.31, bob = true },
    { kind = "hang", x = 342, y = 83, w = 2, h = 27, col = "plum", a = 0.56, lw = 2, sway = 4, rate = 0.41, bob = true },
    { kind = "hang", x = 236, y = 49, w = 2, h = 13, col = "plum", a = 0.38, lw = 2, sway = 5, rate = 0.23, bob = true },
    { kind = "hang", x = 206, y = 37, w = 2, h = 23, col = "plum", a = 0.56, lw = 2, sway = 3, rate = 0.34, bob = true },
    { kind = "hang", x = 45, y = 33, w = 2, h = 33, col = "plum", a = 0.57, lw = 2, sway = 5, rate = 0.31, bob = true },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "band", x = 450, y = 0, w = 30, h = 272, col = "black", a = 0.66, a2 = 0.66, py = -0.05 },
    { kind = "column", x = 464, y = 0, w = 12, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
    { kind = "column", x = 205, y = 0, w = 10, h = 272, col = "black", a = 0.8, py = -0.14, step = 28, acc = "plum" },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 271, y = 203, col = { 0.70, 0.45, 1.00 }, r = 43, flicker = 2.71 },
    { x = 80, y = 137, col = { 0.70, 0.45, 1.00 }, r = 51, flicker = 2.63 },
  },
  mapPos = { x = 3, y = 1, w = 1, h = 1 },
  dark = 0.55,
  gates = { I = "mote_done" },
  map = [[
##############AAA#############
##############AAA#############
##..................I.......##
##..........======..I.......##
##..................I.......##
##..................I.......##
##.............=====I.......##
##..................I.......##
##..................I.......##
##........======....I.......##
##===...............I.w..w..##
##...e..o...........I..5....##
##..................I.......##
##############################
##############################
##############################
##############################
]],
  key = {
    ["e"] = "npc:ferro:until:ferro_rescued",
    ["o"] = "npc:mote",
    ["5"] = "capsule:cap_ug",
    ["w"] = "glowmite",
  },
  links = {
    A = { "ug_3", "D" },
  },
}
