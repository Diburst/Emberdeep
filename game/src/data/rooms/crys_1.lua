-- CRYSTAL HOLLOWS, first floor of the compute cluster.
--
-- The zone's opening lesson, and it teaches three things with one shot:
-- a live BEAM is dangerous, a ROTOR turns it when hit by anything at
-- all, and a NODE it reaches closes a circuit. The rotor starts turned
-- the wrong way, so the beam runs into the floor and the bus gate stays
-- shut; flip it and the beam swings up the shaft into the node.
--
-- Note the shardlings on the beam's row -- the first thing most players
-- see the beam do is kill something for them.
return {
  zone = "crystal", music = "crystal",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 416, col = "plum", a = 0.34, a2 = 0.08, py = 0.05 },
    { kind = "column", x = -14, y = 222, w = 11, h = 194, col = "black", a = 0.4, py = 0.24, step = 24, acc = "orchid" },
    { kind = "column", x = 22, y = 177, w = 11, h = 239, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 63, y = 140, w = 11, h = 276, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 88, y = 181, w = 11, h = 235, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 135, y = 78, w = 11, h = 338, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 183, y = 137, w = 11, h = 279, col = "black", a = 0.4, py = 0.24, step = 39, acc = "orchid" },
    { kind = "column", x = 238, y = 146, w = 11, h = 270, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 286, y = 262, w = 11, h = 154, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 318, y = 86, w = 11, h = 330, col = "black", a = 0.4, py = 0.24, step = 40, acc = "orchid" },
    { kind = "column", x = 362, y = 243, w = 11, h = 173, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 391, y = 97, w = 11, h = 319, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 436, y = 112, w = 11, h = 304, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 474, y = 70, w = 11, h = 346, col = "black", a = 0.4, py = 0.24, step = 30, acc = "orchid" },
    { kind = "column", x = 503, y = 127, w = 11, h = 289, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 551, y = 230, w = 11, h = 186, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 589, y = 192, w = 11, h = 224, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 618, y = 103, w = 11, h = 313, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 653, y = 211, w = 11, h = 205, col = "black", a = 0.4, py = 0.24, step = 39, acc = "orchid" },
    { kind = "column", x = 695, y = 185, w = 11, h = 231, col = "black", a = 0.4, py = 0.24, step = 30, acc = "orchid" },
    { kind = "column", x = 733, y = 268, w = 11, h = 148, col = "black", a = 0.4, py = 0.24, step = 30, acc = "orchid" },
    { kind = "column", x = 777, y = 103, w = 11, h = 313, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 816, y = 192, w = 11, h = 224, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 871, y = 103, w = 11, h = 313, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 921, y = 199, w = 11, h = 217, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 7, y = 163, w = 17, h = 253, col = "black", a = 0.24, py = 0.13, step = 31, acc = "orchid" },
    { kind = "column", x = 60, y = 130, w = 17, h = 286, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 105, y = 165, w = 17, h = 251, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 145, y = 139, w = 17, h = 277, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 187, y = 125, w = 17, h = 291, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 236, y = 108, w = 17, h = 308, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 279, y = 196, w = 17, h = 220, col = "black", a = 0.24, py = 0.13, step = 28, acc = "orchid" },
    { kind = "column", x = 318, y = 195, w = 17, h = 221, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 366, y = 234, w = 17, h = 182, col = "black", a = 0.24, py = 0.13, step = 40, acc = "orchid" },
    { kind = "column", x = 424, y = 165, w = 17, h = 251, col = "black", a = 0.24, py = 0.13, step = 37, acc = "orchid" },
    { kind = "column", x = 475, y = 202, w = 17, h = 214, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 517, y = 156, w = 17, h = 260, col = "black", a = 0.24, py = 0.13, step = 34, acc = "orchid" },
    { kind = "column", x = 572, y = 141, w = 17, h = 275, col = "black", a = 0.24, py = 0.13, step = 33, acc = "orchid" },
    { kind = "column", x = 619, y = 65, w = 17, h = 351, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 675, y = 231, w = 17, h = 185, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 715, y = 72, w = 17, h = 344, col = "black", a = 0.24, py = 0.13, step = 35, acc = "orchid" },
    { kind = "column", x = 766, y = 262, w = 17, h = 154, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 801, y = 125, w = 17, h = 291, col = "black", a = 0.24, py = 0.13, step = 30, acc = "orchid" },
    { kind = "column", x = 854, y = 192, w = 17, h = 224, col = "black", a = 0.24, py = 0.13, step = 29, acc = "orchid" },
    { kind = "column", x = 896, y = 185, w = 17, h = 231, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 943, y = 106, w = 17, h = 310, col = "black", a = 0.24, py = 0.13, step = 34, acc = "orchid" },
    { kind = "shaft", x = 815, y = 0, w = 35, h = 374, col = "orchid", a = 0.16, py = 0.2, skew = -13, ph = 2.02 },
    { kind = "shaft", x = 487, y = 0, w = 32, h = 374, col = "orchid", a = 0.16, py = 0.2, skew = 17, ph = 1.31 },
    { kind = "shaft", x = 399, y = 0, w = 50, h = 374, col = "orchid", a = 0.16, py = 0.2, skew = 17, ph = 1.08 },
    { kind = "shaft", x = 222, y = 0, w = 52, h = 374, col = "orchid", a = 0.16, py = 0.2, skew = 4, ph = 5.09 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 526, y = 207, w = 3, h = 11, col = "violet", a = 0.63 },
    { kind = "rect", x = 529, y = 207, w = 4, h = 17, col = "orchid", a = 0.42 },
    { kind = "rect", x = 534, y = 207, w = 2, h = 19, col = "violet", a = 0.65 },
    { kind = "rect", x = 538, y = 207, w = 4, h = 6, col = "plum", a = 0.51 },
    { kind = "rect", x = 243, y = 68, w = 2, h = 17, col = "orchid", a = 0.58 },
    { kind = "rect", x = 245, y = 68, w = 4, h = 6, col = "violet", a = 0.49 },
    { kind = "rect", x = 249, y = 68, w = 4, h = 10, col = "plum", a = 0.64 },
    { kind = "rect", x = 747, y = 42, w = 2, h = 14, col = "orchid", a = 0.54 },
    { kind = "rect", x = 752, y = 42, w = 3, h = 10, col = "violet", a = 0.45 },
    { kind = "rect", x = 757, y = 42, w = 2, h = 6, col = "violet", a = 0.41 },
    { kind = "rect", x = 22, y = 329, w = 2, h = 8, col = "violet", a = 0.43 },
    { kind = "rect", x = 25, y = 329, w = 4, h = 10, col = "violet", a = 0.58 },
    { kind = "rect", x = 32, y = 329, w = 3, h = 8, col = "orchid", a = 0.37 },
    { kind = "rect", x = 34, y = 329, w = 3, h = 10, col = "plum", a = 0.46 },
    { kind = "rect", x = 711, y = 144, w = 3, h = 15, col = "orchid", a = 0.41 },
    { kind = "rect", x = 713, y = 144, w = 3, h = 9, col = "violet", a = 0.46 },
    { kind = "rect", x = 719, y = 144, w = 2, h = 9, col = "violet", a = 0.68 },
    { kind = "rect", x = 723, y = 144, w = 4, h = 11, col = "plum", a = 0.4 },
    { kind = "rect", x = 91, y = 300, w = 4, h = 11, col = "violet", a = 0.61 },
    { kind = "rect", x = 94, y = 300, w = 2, h = 14, col = "orchid", a = 0.55 },
    { kind = "rect", x = 95, y = 300, w = 3, h = 8, col = "orchid", a = 0.72 },
    { kind = "rect", x = 97, y = 300, w = 2, h = 15, col = "plum", a = 0.58 },
    { kind = "rect", x = 159, y = 108, w = 4, h = 13, col = "violet", a = 0.43 },
    { kind = "rect", x = 164, y = 108, w = 4, h = 9, col = "orchid", a = 0.41 },
    { kind = "rect", x = 366, y = 44, w = 3, h = 19, col = "violet", a = 0.42 },
    { kind = "rect", x = 370, y = 44, w = 2, h = 16, col = "orchid", a = 0.75 },
    { kind = "rect", x = 900, y = 166, w = 4, h = 16, col = "plum", a = 0.62 },
    { kind = "rect", x = 904, y = 166, w = 2, h = 12, col = "orchid", a = 0.73 },
    { kind = "rect", x = 25, y = 118, w = 2, h = 19, col = "plum", a = 0.57 },
    { kind = "rect", x = 29, y = 118, w = 3, h = 15, col = "orchid", a = 0.56 },
    { kind = "rect", x = 103, y = 128, w = 3, h = 9, col = "orchid", a = 0.61 },
    { kind = "rect", x = 107, y = 128, w = 3, h = 9, col = "plum", a = 0.48 },
    { kind = "rect", x = 109, y = 128, w = 4, h = 19, col = "violet", a = 0.55 },
    { kind = "rect", x = 599, y = 134, w = 2, h = 9, col = "orchid", a = 0.75 },
    { kind = "rect", x = 604, y = 134, w = 4, h = 15, col = "orchid", a = 0.35 },
    { kind = "rect", x = 605, y = 134, w = 3, h = 8, col = "orchid", a = 0.41 },
    { kind = "rect", x = 820, y = 39, w = 2, h = 10, col = "violet", a = 0.48 },
    { kind = "rect", x = 825, y = 39, w = 3, h = 9, col = "violet", a = 0.35 },
    { kind = "rect", x = 925, y = 178, w = 2, h = 14, col = "violet", a = 0.43 },
    { kind = "rect", x = 929, y = 178, w = 3, h = 6, col = "plum", a = 0.54 },
    { kind = "rect", x = 929, y = 178, w = 2, h = 7, col = "plum", a = 0.59 },
    { kind = "rect", x = 929, y = 288, w = 3, h = 7, col = "orchid", a = 0.7 },
    { kind = "rect", x = 932, y = 288, w = 2, h = 7, col = "plum", a = 0.55 },
    { kind = "rect", x = 933, y = 288, w = 3, h = 10, col = "violet", a = 0.69 },
    { kind = "rect", x = 569, y = 330, w = 3, h = 11, col = "orchid", a = 0.7 },
    { kind = "rect", x = 572, y = 330, w = 4, h = 17, col = "orchid", a = 0.4 },
    { kind = "rect", x = 573, y = 330, w = 4, h = 18, col = "plum", a = 0.57 },
    { kind = "rect", x = 341, y = 90, w = 3, h = 9, col = "violet", a = 0.42 },
    { kind = "rect", x = 343, y = 90, w = 3, h = 10, col = "orchid", a = 0.41 },
    { kind = "rect", x = 831, y = 319, w = 4, h = 8, col = "orchid", a = 0.68 },
    { kind = "rect", x = 835, y = 319, w = 3, h = 7, col = "violet", a = 0.71 },
    { kind = "rect", x = 837, y = 319, w = 3, h = 11, col = "plum", a = 0.6 },
    { kind = "rect", x = 144, y = 209, w = 2, h = 6, col = "plum", a = 0.42 },
    { kind = "rect", x = 147, y = 209, w = 2, h = 6, col = "violet", a = 0.65 },
    { kind = "rect", x = 154, y = 209, w = 3, h = 20, col = "violet", a = 0.52 },
    { kind = "rect", x = 655, y = 108, w = 4, h = 16, col = "violet", a = 0.39 },
    { kind = "rect", x = 658, y = 108, w = 3, h = 15, col = "violet", a = 0.59 },
    { kind = "rect", x = 442, y = 119, w = 4, h = 17, col = "plum", a = 0.63 },
    { kind = "rect", x = 446, y = 119, w = 2, h = 18, col = "plum", a = 0.38 },
    { kind = "rect", x = 448, y = 119, w = 4, h = 15, col = "orchid", a = 0.44 },
    { kind = "rect", x = 451, y = 119, w = 2, h = 20, col = "orchid", a = 0.7 },
    { kind = "rect", x = 431, y = 277, w = 4, h = 6, col = "orchid", a = 0.61 },
    { kind = "rect", x = 435, y = 277, w = 3, h = 13, col = "orchid", a = 0.75 },
    { kind = "rect", x = 474, y = 198, w = 4, h = 19, col = "violet", a = 0.62 },
    { kind = "rect", x = 476, y = 198, w = 2, h = 6, col = "plum", a = 0.67 },
    { kind = "rect", x = 484, y = 198, w = 3, h = 14, col = "plum", a = 0.69 },
    { kind = "rect", x = 169, y = 215, w = 4, h = 8, col = "orchid", a = 0.49 },
    { kind = "rect", x = 172, y = 215, w = 2, h = 16, col = "plum", a = 0.74 },
    { kind = "rect", x = 173, y = 215, w = 4, h = 15, col = "violet", a = 0.55 },
    { kind = "rect", x = 175, y = 215, w = 4, h = 18, col = "plum", a = 0.62 },
    { kind = "rect", x = 343, y = 69, w = 4, h = 5, col = "cream", a = 0.49 },
    { kind = "rect", x = 846, y = 317, w = 5, h = 6, col = "cream", a = 0.59 },
    { kind = "rect", x = 174, y = 153, w = 6, h = 6, col = "cream", a = 0.57 },
    { kind = "rect", x = 819, y = 202, w = 3, h = 6, col = "cream", a = 0.4 },
    { kind = "rect", x = 427, y = 294, w = 5, h = 5, col = "cream", a = 0.56 },
    { kind = "rect", x = 381, y = 159, w = 6, h = 6, col = "cream", a = 0.51 },
    { kind = "rect", x = 610, y = 313, w = 4, h = 3, col = "cream", a = 0.48 },
    { kind = "rect", x = 57, y = 281, w = 6, h = 6, col = "cream", a = 0.55 },
    { kind = "rect", x = 279, y = 234, w = 4, h = 6, col = "cream", a = 0.37 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "column", x = 547, y = 0, w = 10, h = 416, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 392, y = 0, w = 11, h = 416, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 537, y = 0, w = 12, h = 416, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 471, y = 0, w = 10, h = 416, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "band", x = 0, y = 0, w = 24, h = 416, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
    { kind = "band", x = 936, y = 0, w = 24, h = 416, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 120, y = 285, col = { 0.78, 0.48, 1.00 }, r = 58, flicker = 2.3 },
    { x = 360, y = 261, col = { 0.78, 0.48, 1.00 }, r = 74, flicker = 4.18 },
    { x = 600, y = 240, col = { 0.78, 0.48, 1.00 }, r = 62, flicker = 3.17 },
    { x = 840, y = 281, col = { 0.78, 0.48, 1.00 }, r = 55, flicker = 2.69 },
  },
  mapPos = { x = 0, y = 0, w = 3, h = 2 },
  gates = { G = "boss_tideengine", H = "crys_bus1" },
  gateStyle = { H = "curtain" },
  map = [[
########AAA#################################################
########AAA#################################################
##.....G...G........................................H.....##
##.....G...G...................#....................H.....##
##~~~######~~~~~~~~~~~~~~~~~~~~#....................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#.n..................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#....................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#....................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#....................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#....................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#.n..................H.....##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#....................H.....##
##~~~~~~~~f~~~~~~~~~~~m~~~~~~~~#....................H.....##
###################################.................H.....##
##............................o.....................H.....##
##..................................=======.........H.....##
##..................................................H.....##
##...........................................4......H.....##
##..........................................====....H.....##
##................d.................................H.....BB
##........e...................r.....z...1...........H.....BB
############################################################
############################################################
############################################################
############################################################
############################################################
]],
  key = {
    ["4"] = "chest:ch_ap4:module:arcplate4",
    ["n"] = "anchor",
    ["f"] = "finfish",
    ["m"] = "depthmine",
    ["z"] = "checkpoint",
    ["d"] = "shardling",
    ["1"] = "sign:sign_crystal",
    ["e"] = "emitter:right",
    ["r"] = "rotor:b",
    ["o"] = "node:crys_bus1",
  },
  links = {
    A = { "deep_stair_1", "D" },
    B = { "crys_2", "A" },
  },
}
