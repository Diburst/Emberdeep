-- THE READING ROOM -- save, teleport pad, and the zone's third verb
-- taught where nothing can go wrong, and then required once.
--
-- The emitter on the shelf is DORMANT: dark, inert, and a century past
-- its last work order. Lu climbs the two steps, stands next to it and
-- holds a dome on it for two seconds; half her bar goes into the
-- machine and the machine wakes up. It fires the length of the hall,
-- well over the walking row, into the NODE at col 47.
--
-- That circuit is the curtain at col 48 -- floor to ceiling, the only
-- way out of this room. So the zone's third verb is not a demonstration
-- you can walk past: you learn it standing next to a save point, with a
-- sign at your feet and nothing in the room that can hurt you, and then
-- you use it. The crawl to the cache is behind the curtain too.
--
-- The two shelves are load-bearing in the literal sense: without the
-- step at row 9 the emitter shelf is five rows off the floor, and a
-- two-second channel cannot be held from the top of a jump.
return {
  zone = "crystal", music = "crystal",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "plum", a = 0.34, a2 = 0.08, py = 0.05 },
    { kind = "column", x = -14, y = 108, w = 11, h = 164, col = "black", a = 0.4, py = 0.24, step = 36, acc = "orchid" },
    { kind = "column", x = 21, y = 165, w = 11, h = 107, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 54, y = 116, w = 11, h = 156, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 92, y = 78, w = 11, h = 194, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 125, y = 65, w = 11, h = 207, col = "black", a = 0.4, py = 0.24, step = 40, acc = "orchid" },
    { kind = "column", x = 152, y = 117, w = 11, h = 155, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 191, y = 57, w = 11, h = 215, col = "black", a = 0.4, py = 0.24, step = 36, acc = "orchid" },
    { kind = "column", x = 231, y = 135, w = 11, h = 137, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 273, y = 104, w = 11, h = 168, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 301, y = 129, w = 11, h = 143, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 347, y = 65, w = 11, h = 207, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 378, y = 84, w = 11, h = 188, col = "black", a = 0.4, py = 0.24, step = 37, acc = "orchid" },
    { kind = "column", x = 432, y = 49, w = 11, h = 223, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 464, y = 107, w = 11, h = 165, col = "black", a = 0.4, py = 0.24, step = 30, acc = "orchid" },
    { kind = "column", x = 495, y = 129, w = 11, h = 143, col = "black", a = 0.4, py = 0.24, step = 30, acc = "orchid" },
    { kind = "column", x = 543, y = 92, w = 11, h = 180, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 572, y = 116, w = 11, h = 156, col = "black", a = 0.4, py = 0.24, step = 34, acc = "orchid" },
    { kind = "column", x = 603, y = 151, w = 11, h = 121, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 635, y = 58, w = 11, h = 214, col = "black", a = 0.4, py = 0.24, step = 34, acc = "orchid" },
    { kind = "column", x = 665, y = 105, w = 11, h = 167, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 701, y = 112, w = 11, h = 160, col = "black", a = 0.4, py = 0.24, step = 37, acc = "orchid" },
    { kind = "column", x = 756, y = 94, w = 11, h = 178, col = "black", a = 0.4, py = 0.24, step = 26, acc = "orchid" },
    { kind = "column", x = 803, y = 94, w = 11, h = 178, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 828, y = 87, w = 11, h = 185, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 869, y = 70, w = 11, h = 202, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 917, y = 173, w = 11, h = 99, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 943, y = 161, w = 11, h = 111, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 7, y = 49, w = 17, h = 223, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 44, y = 43, w = 17, h = 229, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 104, y = 58, w = 17, h = 214, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 142, y = 55, w = 17, h = 217, col = "black", a = 0.24, py = 0.13, step = 28, acc = "orchid" },
    { kind = "column", x = 201, y = 108, w = 17, h = 164, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 242, y = 44, w = 17, h = 228, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 295, y = 155, w = 17, h = 117, col = "black", a = 0.24, py = 0.13, step = 40, acc = "orchid" },
    { kind = "column", x = 348, y = 64, w = 17, h = 208, col = "black", a = 0.24, py = 0.13, step = 23, acc = "orchid" },
    { kind = "column", x = 380, y = 136, w = 17, h = 136, col = "black", a = 0.24, py = 0.13, step = 37, acc = "orchid" },
    { kind = "column", x = 422, y = 85, w = 17, h = 187, col = "black", a = 0.24, py = 0.13, step = 31, acc = "orchid" },
    { kind = "column", x = 453, y = 112, w = 17, h = 160, col = "black", a = 0.24, py = 0.13, step = 26, acc = "orchid" },
    { kind = "column", x = 510, y = 123, w = 17, h = 149, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 544, y = 145, w = 17, h = 127, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 581, y = 164, w = 17, h = 108, col = "black", a = 0.24, py = 0.13, step = 34, acc = "orchid" },
    { kind = "column", x = 635, y = 60, w = 17, h = 212, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 683, y = 96, w = 17, h = 176, col = "black", a = 0.24, py = 0.13, step = 23, acc = "orchid" },
    { kind = "column", x = 732, y = 158, w = 17, h = 114, col = "black", a = 0.24, py = 0.13, step = 30, acc = "orchid" },
    { kind = "column", x = 771, y = 90, w = 17, h = 182, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 812, y = 76, w = 17, h = 196, col = "black", a = 0.24, py = 0.13, step = 30, acc = "orchid" },
    { kind = "column", x = 855, y = 145, w = 17, h = 127, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 909, y = 105, w = 17, h = 167, col = "black", a = 0.24, py = 0.13, step = 29, acc = "orchid" },
    { kind = "shaft", x = 229, y = 0, w = 47, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = -32, ph = 4.85 },
    { kind = "shaft", x = 82, y = 0, w = 56, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = -18, ph = 4.53 },
    { kind = "shaft", x = 386, y = 0, w = 38, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = 2, ph = 5.77 },
    { kind = "shaft", x = 211, y = 0, w = 40, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = -21, ph = 0.63 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 6, y = 216, w = 3, h = 9, col = "violet", a = 0.74 },
    { kind = "rect", x = 9, y = 216, w = 3, h = 15, col = "orchid", a = 0.45 },
    { kind = "rect", x = 194, y = 132, w = 3, h = 9, col = "plum", a = 0.72 },
    { kind = "rect", x = 196, y = 132, w = 4, h = 11, col = "orchid", a = 0.47 },
    { kind = "rect", x = 200, y = 132, w = 3, h = 10, col = "violet", a = 0.37 },
    { kind = "rect", x = 541, y = 157, w = 3, h = 10, col = "violet", a = 0.46 },
    { kind = "rect", x = 543, y = 157, w = 4, h = 11, col = "violet", a = 0.66 },
    { kind = "rect", x = 551, y = 157, w = 3, h = 17, col = "orchid", a = 0.47 },
    { kind = "rect", x = 751, y = 98, w = 3, h = 15, col = "plum", a = 0.54 },
    { kind = "rect", x = 754, y = 98, w = 3, h = 17, col = "orchid", a = 0.52 },
    { kind = "rect", x = 757, y = 98, w = 3, h = 18, col = "orchid", a = 0.53 },
    { kind = "rect", x = 406, y = 56, w = 2, h = 9, col = "orchid", a = 0.69 },
    { kind = "rect", x = 411, y = 56, w = 4, h = 19, col = "plum", a = 0.64 },
    { kind = "rect", x = 414, y = 56, w = 3, h = 16, col = "orchid", a = 0.51 },
    { kind = "rect", x = 421, y = 56, w = 2, h = 7, col = "orchid", a = 0.61 },
    { kind = "rect", x = 294, y = 54, w = 3, h = 9, col = "plum", a = 0.73 },
    { kind = "rect", x = 296, y = 54, w = 3, h = 19, col = "violet", a = 0.65 },
    { kind = "rect", x = 300, y = 54, w = 3, h = 20, col = "orchid", a = 0.43 },
    { kind = "rect", x = 309, y = 54, w = 2, h = 8, col = "plum", a = 0.45 },
    { kind = "rect", x = 344, y = 83, w = 4, h = 20, col = "plum", a = 0.38 },
    { kind = "rect", x = 349, y = 83, w = 2, h = 18, col = "violet", a = 0.41 },
    { kind = "rect", x = 348, y = 83, w = 4, h = 7, col = "violet", a = 0.38 },
    { kind = "rect", x = 367, y = 88, w = 3, h = 14, col = "plum", a = 0.46 },
    { kind = "rect", x = 372, y = 88, w = 4, h = 16, col = "violet", a = 0.55 },
    { kind = "rect", x = 630, y = 134, w = 3, h = 6, col = "orchid", a = 0.38 },
    { kind = "rect", x = 634, y = 134, w = 2, h = 12, col = "violet", a = 0.68 },
    { kind = "rect", x = 30, y = 121, w = 2, h = 10, col = "violet", a = 0.4 },
    { kind = "rect", x = 35, y = 121, w = 4, h = 20, col = "plum", a = 0.59 },
    { kind = "rect", x = 36, y = 121, w = 4, h = 14, col = "plum", a = 0.67 },
    { kind = "rect", x = 310, y = 58, w = 3, h = 14, col = "plum", a = 0.38 },
    { kind = "rect", x = 314, y = 58, w = 3, h = 16, col = "orchid", a = 0.38 },
    { kind = "rect", x = 314, y = 58, w = 4, h = 12, col = "violet", a = 0.6 },
    { kind = "rect", x = 319, y = 58, w = 3, h = 10, col = "plum", a = 0.45 },
    { kind = "rect", x = 200, y = 41, w = 3, h = 18, col = "orchid", a = 0.45 },
    { kind = "rect", x = 204, y = 41, w = 2, h = 12, col = "violet", a = 0.41 },
    { kind = "rect", x = 210, y = 41, w = 4, h = 7, col = "orchid", a = 0.37 },
    { kind = "rect", x = 865, y = 65, w = 3, h = 19, col = "violet", a = 0.58 },
    { kind = "rect", x = 867, y = 65, w = 2, h = 12, col = "plum", a = 0.53 },
    { kind = "rect", x = 156, y = 99, w = 3, h = 17, col = "plum", a = 0.72 },
    { kind = "rect", x = 158, y = 99, w = 2, h = 8, col = "plum", a = 0.62 },
    { kind = "rect", x = 758, y = 214, w = 2, h = 12, col = "plum", a = 0.58 },
    { kind = "rect", x = 761, y = 214, w = 3, h = 7, col = "violet", a = 0.67 },
    { kind = "rect", x = 768, y = 214, w = 4, h = 9, col = "violet", a = 0.61 },
    { kind = "rect", x = 770, y = 214, w = 4, h = 10, col = "orchid", a = 0.46 },
    { kind = "rect", x = 904, y = 169, w = 2, h = 11, col = "plum", a = 0.7 },
    { kind = "rect", x = 908, y = 169, w = 2, h = 20, col = "violet", a = 0.36 },
    { kind = "rect", x = 875, y = 108, w = 4, h = 17, col = "orchid", a = 0.44 },
    { kind = "rect", x = 879, y = 108, w = 4, h = 14, col = "violet", a = 0.7 },
    { kind = "rect", x = 708, y = 88, w = 3, h = 11, col = "plum", a = 0.66 },
    { kind = "rect", x = 711, y = 88, w = 3, h = 20, col = "violet", a = 0.38 },
    { kind = "rect", x = 467, y = 219, w = 3, h = 11, col = "orchid", a = 0.71 },
    { kind = "rect", x = 470, y = 219, w = 3, h = 10, col = "plum", a = 0.37 },
    { kind = "rect", x = 554, y = 139, w = 4, h = 10, col = "violet", a = 0.61 },
    { kind = "rect", x = 559, y = 139, w = 2, h = 10, col = "plum", a = 0.56 },
    { kind = "rect", x = 558, y = 139, w = 3, h = 7, col = "violet", a = 0.37 },
    { kind = "rect", x = 469, y = 160, w = 4, h = 20, col = "orchid", a = 0.53 },
    { kind = "rect", x = 471, y = 160, w = 2, h = 12, col = "plum", a = 0.38 },
    { kind = "rect", x = 473, y = 160, w = 3, h = 16, col = "orchid", a = 0.58 },
    { kind = "rect", x = 891, y = 161, w = 2, h = 14, col = "orchid", a = 0.56 },
    { kind = "rect", x = 895, y = 161, w = 2, h = 17, col = "orchid", a = 0.35 },
    { kind = "rect", x = 901, y = 161, w = 2, h = 13, col = "plum", a = 0.62 },
    { kind = "rect", x = 776, y = 75, w = 3, h = 19, col = "violet", a = 0.54 },
    { kind = "rect", x = 781, y = 75, w = 2, h = 14, col = "orchid", a = 0.37 },
    { kind = "rect", x = 784, y = 75, w = 4, h = 7, col = "plum", a = 0.63 },
    { kind = "rect", x = 782, y = 75, w = 2, h = 19, col = "plum", a = 0.47 },
    { kind = "rect", x = 424, y = 112, w = 3, h = 12, col = "violet", a = 0.41 },
    { kind = "rect", x = 429, y = 112, w = 3, h = 13, col = "plum", a = 0.39 },
    { kind = "rect", x = 596, y = 48, w = 3, h = 6, col = "cream", a = 0.47 },
    { kind = "rect", x = 370, y = 168, w = 5, h = 4, col = "cream", a = 0.44 },
    { kind = "rect", x = 522, y = 99, w = 5, h = 6, col = "cream", a = 0.31 },
    { kind = "rect", x = 765, y = 149, w = 4, h = 6, col = "cream", a = 0.51 },
    { kind = "rect", x = 902, y = 47, w = 4, h = 6, col = "cream", a = 0.49 },
    { kind = "rect", x = 676, y = 194, w = 5, h = 4, col = "cream", a = 0.51 },
    { kind = "rect", x = 76, y = 113, w = 5, h = 3, col = "cream", a = 0.56 },
    { kind = "rect", x = 351, y = 56, w = 4, h = 3, col = "cream", a = 0.53 },
    { kind = "rect", x = 869, y = 196, w = 3, h = 5, col = "cream", a = 0.54 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "column", x = 273, y = 0, w = 11, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 139, y = 0, w = 15, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 789, y = 0, w = 15, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 403, y = 0, w = 14, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "band", x = 0, y = 0, w = 24, h = 272, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
    { kind = "band", x = 936, y = 0, w = 24, h = 272, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 120, y = 151, col = { 0.78, 0.48, 1.00 }, r = 79, flicker = 2.98 },
    { x = 360, y = 60, col = { 0.78, 0.48, 1.00 }, r = 62, flicker = 2.17 },
    { x = 600, y = 131, col = { 0.78, 0.48, 1.00 }, r = 65, flicker = 4 },
    { x = 840, y = 73, col = { 0.78, 0.48, 1.00 }, r = 65, flicker = 2.12 },
  },
  mapPos = { x = 3, y = 1, w = 3, h = 1 },
  hasTeleporter = true,
  gates = { H = "crys_bus2" },
  gateStyle = { H = "curtain" },
  map = [[
############################################################
############################################################
##..............................................H.........##
##...............................f........g.....H........###
##..............................................H.....a..###
##..............................................H.....######
##.............w........e.w......f........g....oH......#####
##....................======.....=........=..===H........###
##................................a.............H.........##
##................====..........................H...%.....##
AA..............................................H...%EE...BB
AA......s.....t.....1.........w.............u...H...%EE...BB
############################################################
############################################################
############################################################
############################################################
############################################################
]],
  key = {
    ["s"] = "checkpoint",
    ["t"] = "teleporter:crystal",
    ["w"] = "prismwisp",
    ["u"] = "cryoturret",
    ["e"] = "emitter:right:dormant:14",
    ["o"] = "node:crys_bus2",
    ["1"] = "sign:sign_dormant",
    ["a"] = "cell",
    ["f"] = "mirror:f",
    ["g"] = "mirror:b",
  },
  links = {
    A = { "crys_1", "B" },
    B = { "crys_3", "A" },
    E = { "crys_secret", "A" },
  },
}
