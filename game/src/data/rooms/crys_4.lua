-- THE STACK. A climbing shaft, and the room where the beam stops being
-- a lock and becomes a weapon -- and then goes on being a lock anyway.
--
-- The emitter on the shelf is dormant and points along its own ledge,
-- straight through the cryoturret that owns that shelf and into a NODE
-- at the far end. So one two-second channel does both jobs at once:
-- the turret is gone, and the circuit that drops the curtain over the
-- way out is closed. Nothing here is decoration.
--
-- Deliberately no panel and no rotor: a hostile beam laid across a
-- vertical shaft has no fair answer, because a ROTOR can only ever
-- shorten a beam from the mirror onward -- it cannot protect anything
-- standing between the emitter and itself. Aiming is the rotor's job;
-- making a room safe is the panel's, and a panel wants a floor to run
-- along. This shaft has neither. The beam here is short, level, and
-- entirely on its own shelf, which is why it is allowed to exist.
return {
  zone = "crystal", music = "crystal",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 512, col = "plum", a = 0.34, a2 = 0.08, py = 0.05 },
    { kind = "column", x = -14, y = 172, w = 11, h = 340, col = "black", a = 0.4, py = 0.24, step = 34, acc = "orchid" },
    { kind = "column", x = 15, y = 320, w = 11, h = 192, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 40, y = 271, w = 11, h = 241, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 69, y = 191, w = 11, h = 321, col = "black", a = 0.4, py = 0.24, step = 34, acc = "orchid" },
    { kind = "column", x = 110, y = 235, w = 11, h = 277, col = "black", a = 0.4, py = 0.24, step = 36, acc = "orchid" },
    { kind = "column", x = 148, y = 215, w = 11, h = 297, col = "black", a = 0.4, py = 0.24, step = 25, acc = "orchid" },
    { kind = "column", x = 185, y = 172, w = 11, h = 340, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 231, y = 194, w = 11, h = 318, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 263, y = 82, w = 11, h = 430, col = "black", a = 0.4, py = 0.24, step = 25, acc = "orchid" },
    { kind = "column", x = 313, y = 191, w = 11, h = 321, col = "black", a = 0.4, py = 0.24, step = 37, acc = "orchid" },
    { kind = "column", x = 367, y = 224, w = 11, h = 288, col = "black", a = 0.4, py = 0.24, step = 39, acc = "orchid" },
    { kind = "column", x = 405, y = 254, w = 11, h = 258, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 446, y = 221, w = 11, h = 291, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 7, y = 121, w = 17, h = 391, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 62, y = 136, w = 17, h = 376, col = "black", a = 0.24, py = 0.13, step = 30, acc = "orchid" },
    { kind = "column", x = 118, y = 103, w = 17, h = 409, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 171, y = 210, w = 17, h = 302, col = "black", a = 0.24, py = 0.13, step = 35, acc = "orchid" },
    { kind = "column", x = 219, y = 304, w = 17, h = 208, col = "black", a = 0.24, py = 0.13, step = 28, acc = "orchid" },
    { kind = "column", x = 262, y = 189, w = 17, h = 323, col = "black", a = 0.24, py = 0.13, step = 35, acc = "orchid" },
    { kind = "column", x = 310, y = 311, w = 17, h = 201, col = "black", a = 0.24, py = 0.13, step = 24, acc = "orchid" },
    { kind = "column", x = 352, y = 173, w = 17, h = 339, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 390, y = 160, w = 17, h = 352, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 429, y = 314, w = 17, h = 198, col = "black", a = 0.24, py = 0.13, step = 28, acc = "orchid" },
    { kind = "shaft", x = 281, y = 0, w = 51, h = 460, col = "orchid", a = 0.16, py = 0.2, skew = -31, ph = 1.83 },
    { kind = "shaft", x = 326, y = 0, w = 46, h = 460, col = "orchid", a = 0.16, py = 0.2, skew = 26, ph = 0.23 },
    { kind = "shaft", x = 135, y = 0, w = 55, h = 460, col = "orchid", a = 0.16, py = 0.2, skew = -22, ph = 0.82 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 391, y = 61, w = 4, h = 9, col = "plum", a = 0.44 },
    { kind = "rect", x = 396, y = 61, w = 2, h = 9, col = "violet", a = 0.55 },
    { kind = "rect", x = 395, y = 61, w = 4, h = 15, col = "violet", a = 0.55 },
    { kind = "rect", x = 350, y = 424, w = 2, h = 19, col = "plum", a = 0.58 },
    { kind = "rect", x = 353, y = 424, w = 2, h = 7, col = "violet", a = 0.72 },
    { kind = "rect", x = 20, y = 93, w = 4, h = 13, col = "plum", a = 0.51 },
    { kind = "rect", x = 24, y = 93, w = 2, h = 11, col = "plum", a = 0.72 },
    { kind = "rect", x = 28, y = 93, w = 2, h = 15, col = "plum", a = 0.41 },
    { kind = "rect", x = 371, y = 110, w = 4, h = 18, col = "plum", a = 0.48 },
    { kind = "rect", x = 375, y = 110, w = 4, h = 8, col = "violet", a = 0.69 },
    { kind = "rect", x = 335, y = 82, w = 3, h = 7, col = "violet", a = 0.73 },
    { kind = "rect", x = 337, y = 82, w = 4, h = 12, col = "orchid", a = 0.6 },
    { kind = "rect", x = 308, y = 347, w = 3, h = 17, col = "plum", a = 0.62 },
    { kind = "rect", x = 310, y = 347, w = 3, h = 12, col = "plum", a = 0.72 },
    { kind = "rect", x = 318, y = 347, w = 2, h = 9, col = "violet", a = 0.42 },
    { kind = "rect", x = 317, y = 347, w = 2, h = 10, col = "plum", a = 0.56 },
    { kind = "rect", x = 169, y = 125, w = 4, h = 15, col = "violet", a = 0.39 },
    { kind = "rect", x = 171, y = 125, w = 4, h = 6, col = "plum", a = 0.35 },
    { kind = "rect", x = 335, y = 244, w = 3, h = 15, col = "orchid", a = 0.73 },
    { kind = "rect", x = 339, y = 244, w = 3, h = 10, col = "orchid", a = 0.67 },
    { kind = "rect", x = 341, y = 244, w = 3, h = 18, col = "violet", a = 0.74 },
    { kind = "rect", x = 49, y = 357, w = 3, h = 6, col = "plum", a = 0.4 },
    { kind = "rect", x = 52, y = 357, w = 4, h = 8, col = "orchid", a = 0.7 },
    { kind = "rect", x = 53, y = 357, w = 2, h = 17, col = "violet", a = 0.73 },
    { kind = "rect", x = 61, y = 357, w = 3, h = 6, col = "orchid", a = 0.54 },
    { kind = "rect", x = 242, y = 317, w = 4, h = 12, col = "orchid", a = 0.49 },
    { kind = "rect", x = 246, y = 317, w = 2, h = 16, col = "violet", a = 0.61 },
    { kind = "rect", x = 121, y = 207, w = 3, h = 13, col = "orchid", a = 0.54 },
    { kind = "rect", x = 124, y = 207, w = 4, h = 15, col = "orchid", a = 0.48 },
    { kind = "rect", x = 299, y = 393, w = 3, h = 10, col = "violet", a = 0.72 },
    { kind = "rect", x = 301, y = 393, w = 4, h = 8, col = "plum", a = 0.52 },
    { kind = "rect", x = 309, y = 393, w = 2, h = 13, col = "violet", a = 0.74 },
    { kind = "rect", x = 82, y = 178, w = 5, h = 5, col = "cream", a = 0.59 },
    { kind = "rect", x = 260, y = 211, w = 3, h = 6, col = "cream", a = 0.56 },
    { kind = "rect", x = 363, y = 344, w = 3, h = 3, col = "cream", a = 0.48 },
    { kind = "rect", x = 450, y = 138, w = 3, h = 5, col = "cream", a = 0.42 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "column", x = 259, y = 0, w = 18, h = 512, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 159, y = 0, w = 15, h = 512, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "band", x = 0, y = 0, w = 24, h = 512, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
    { kind = "band", x = 456, y = 0, w = 24, h = 512, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 120, y = 130, col = { 0.78, 0.48, 1.00 }, r = 55, flicker = 4.37 },
    { x = 360, y = 259, col = { 0.78, 0.48, 1.00 }, r = 78, flicker = 2.59 },
  },
  mapPos = { x = 9, y = 1, w = 1, h = 2 },
  map = [[
##############BBB#############
##############BBB#############
##############HHH#############
##..............9...........##
##............#######.......##
##.........===..............##
##..........................##
##...ou...e.................##
##..#######.................##
##..........................##
##..................n.......##
##............===...........##
##..........................##
##....................w.....##
##................#######...##
##..........................##
##........n.................##
##.............====.........##
##..........................##
##..........d...............##
##......#######.............##
##.............===..........##
##..........................##
##......................z...##
##..................#######.##
##..............===.........##
AA..........................##
AA..........................##
##############################
##############################
##############################
##############################
]],
  gates = { H = "crys_bus4" },
  gateStyle = { H = "curtain" },
  key = {
    ["9"] = "chest:chest_lance:weapon:arclance",
    ["n"] = "anchor",
    ["u"] = "cryoturret",
    ["w"] = "prismwisp",
    ["d"] = "shardling",
    ["z"] = "checkpoint",
    ["o"] = "node:crys_bus4",
    ["e"] = "emitter:left:dormant:14",
  },
  links = {
    A = { "crys_3", "B" },
    B = { "crys_5", "A" },
  },
}
