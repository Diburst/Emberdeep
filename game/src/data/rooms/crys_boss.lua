-- THE SCHEDULER'S FLOOR.
--
-- The Conductor is SHIELDED by default and the beam circuit is the only
-- thing that opens it. Everything in this room exists to serve one
-- sequence: work out which of the three images is real, park the
-- reflector beneath it, get Lu to that station's emitter, and hold the
-- channel.
--
-- THREE INDEPENDENT RUNS. A mirror turns a beam ninety degrees, so it
-- can never send one back up the column it came down: the final leg
-- into the boss has to be vertical and upward, which means the beam has
-- to be travelling along the FLOOR before it gets there. Hence a
-- reflector beneath each station. One shared floor beam would not work
-- -- the panel nearest the emitter would always intercept it and the
-- other two stations could never be reached -- so each station has its
-- own emitter (row 4), its own fixed corner mirror (row 16), and its
-- own panel.
--
--   emitter   col 5 (updraft)    col 24 (climb)    col 54 (updraft)
--   mirror    col 5   b          col 24   b        col 54   f
--   panel     cols 9-15  f       cols 27-33  f     cols 45-51  b
--   station   col 12 +/-3T       col 30 +/-3T      col 48 +/-3T
--
-- THE TRACK AND THE JITTER ARE THE SAME WINDOW. Each station re-rolls
-- its exact column by up to three tiles every cycle, and each panel's
-- rail is exactly six slots wide. The jitter is not decoration: it is
-- the entire reason the rail exists. Fixed stations would mean solving
-- the aim once and never thinking about it again.
--
-- THE OUTER TWO PERCHES ARE VANE-ONLY. Thermal columns at cols 3 and 56
-- are the only way up to the left and right emitters. The centre one is
-- plain climbing -- row 13, row 11, row 9, row 7, row 5 -- so a third of
-- the time the answer is easy, and that is where the shape gets taught.
--
-- THE FLOOR LEG IS HOT. Every beam here is a real beam: it burns players
-- standing in it and it kills the wisps outright. The stretch of floor
-- between a mirror and its panel is genuinely dangerous ground, and a
-- badly aimed beam is a hazard you built yourself.
return {
  zone = "crystal", music = "crystal",
  arena = "prismtyrant",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 992, h = 352, col = "plum", a = 0.34, a2 = 0.08, py = 0.05 },
    { kind = "column", x = -14, y = 227, w = 11, h = 125, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 19, y = 113, w = 11, h = 239, col = "black", a = 0.4, py = 0.24, step = 25, acc = "orchid" },
    { kind = "column", x = 60, y = 154, w = 11, h = 198, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 112, y = 209, w = 11, h = 143, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 164, y = 138, w = 11, h = 214, col = "black", a = 0.4, py = 0.24, step = 26, acc = "orchid" },
    { kind = "column", x = 217, y = 128, w = 11, h = 224, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 251, y = 166, w = 11, h = 186, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 278, y = 217, w = 11, h = 135, col = "black", a = 0.4, py = 0.24, step = 24, acc = "orchid" },
    { kind = "column", x = 308, y = 220, w = 11, h = 132, col = "black", a = 0.4, py = 0.24, step = 24, acc = "orchid" },
    { kind = "column", x = 347, y = 203, w = 11, h = 149, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 390, y = 71, w = 11, h = 281, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 427, y = 81, w = 11, h = 271, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 453, y = 143, w = 11, h = 209, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 504, y = 196, w = 11, h = 156, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 529, y = 142, w = 11, h = 210, col = "black", a = 0.4, py = 0.24, step = 36, acc = "orchid" },
    { kind = "column", x = 559, y = 138, w = 11, h = 214, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 610, y = 162, w = 11, h = 190, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 661, y = 156, w = 11, h = 196, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 692, y = 110, w = 11, h = 242, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 722, y = 183, w = 11, h = 169, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 747, y = 132, w = 11, h = 220, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 774, y = 84, w = 11, h = 268, col = "black", a = 0.4, py = 0.24, step = 26, acc = "orchid" },
    { kind = "column", x = 812, y = 136, w = 11, h = 216, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 837, y = 213, w = 11, h = 139, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 879, y = 90, w = 11, h = 262, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 912, y = 214, w = 11, h = 138, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 957, y = 123, w = 11, h = 229, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 7, y = 186, w = 17, h = 166, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 44, y = 88, w = 17, h = 264, col = "black", a = 0.24, py = 0.13, step = 35, acc = "orchid" },
    { kind = "column", x = 79, y = 166, w = 17, h = 186, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 122, y = 210, w = 17, h = 142, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 171, y = 195, w = 17, h = 157, col = "black", a = 0.24, py = 0.13, step = 34, acc = "orchid" },
    { kind = "column", x = 203, y = 148, w = 17, h = 204, col = "black", a = 0.24, py = 0.13, step = 40, acc = "orchid" },
    { kind = "column", x = 239, y = 169, w = 17, h = 183, col = "black", a = 0.24, py = 0.13, step = 24, acc = "orchid" },
    { kind = "column", x = 276, y = 129, w = 17, h = 223, col = "black", a = 0.24, py = 0.13, step = 40, acc = "orchid" },
    { kind = "column", x = 328, y = 210, w = 17, h = 142, col = "black", a = 0.24, py = 0.13, step = 24, acc = "orchid" },
    { kind = "column", x = 371, y = 84, w = 17, h = 268, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 427, y = 73, w = 17, h = 279, col = "black", a = 0.24, py = 0.13, step = 28, acc = "orchid" },
    { kind = "column", x = 469, y = 71, w = 17, h = 281, col = "black", a = 0.24, py = 0.13, step = 30, acc = "orchid" },
    { kind = "column", x = 522, y = 64, w = 17, h = 288, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 554, y = 166, w = 17, h = 186, col = "black", a = 0.24, py = 0.13, step = 24, acc = "orchid" },
    { kind = "column", x = 602, y = 111, w = 17, h = 241, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 663, y = 97, w = 17, h = 255, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 695, y = 91, w = 17, h = 261, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 738, y = 212, w = 17, h = 140, col = "black", a = 0.24, py = 0.13, step = 34, acc = "orchid" },
    { kind = "column", x = 784, y = 214, w = 17, h = 138, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 841, y = 154, w = 17, h = 198, col = "black", a = 0.24, py = 0.13, step = 34, acc = "orchid" },
    { kind = "column", x = 895, y = 172, w = 17, h = 180, col = "black", a = 0.24, py = 0.13, step = 38, acc = "orchid" },
    { kind = "column", x = 935, y = 228, w = 17, h = 124, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 981, y = 130, w = 17, h = 222, col = "black", a = 0.24, py = 0.13, step = 35, acc = "orchid" },
    { kind = "shaft", x = 745, y = 0, w = 38, h = 316, col = "orchid", a = 0.16, py = 0.2, skew = -15, ph = 4.62 },
    { kind = "shaft", x = 177, y = 0, w = 33, h = 316, col = "orchid", a = 0.16, py = 0.2, skew = 31, ph = 4.26 },
    { kind = "shaft", x = 10, y = 0, w = 37, h = 316, col = "orchid", a = 0.16, py = 0.2, skew = -18, ph = 0.85 },
    { kind = "shaft", x = 786, y = 0, w = 57, h = 316, col = "orchid", a = 0.16, py = 0.2, skew = 0, ph = 0.7 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 218, y = 183, w = 3, h = 8, col = "violet", a = 0.56 },
    { kind = "rect", x = 221, y = 183, w = 2, h = 20, col = "orchid", a = 0.62 },
    { kind = "rect", x = 222, y = 183, w = 3, h = 12, col = "violet", a = 0.64 },
    { kind = "rect", x = 227, y = 183, w = 3, h = 17, col = "orchid", a = 0.65 },
    { kind = "rect", x = 694, y = 279, w = 3, h = 15, col = "violet", a = 0.71 },
    { kind = "rect", x = 697, y = 279, w = 4, h = 19, col = "violet", a = 0.43 },
    { kind = "rect", x = 704, y = 279, w = 3, h = 8, col = "plum", a = 0.47 },
    { kind = "rect", x = 9, y = 72, w = 4, h = 7, col = "plum", a = 0.75 },
    { kind = "rect", x = 11, y = 72, w = 2, h = 12, col = "violet", a = 0.6 },
    { kind = "rect", x = 19, y = 72, w = 2, h = 20, col = "violet", a = 0.37 },
    { kind = "rect", x = 18, y = 72, w = 3, h = 14, col = "orchid", a = 0.41 },
    { kind = "rect", x = 50, y = 29, w = 3, h = 18, col = "orchid", a = 0.61 },
    { kind = "rect", x = 53, y = 29, w = 3, h = 14, col = "orchid", a = 0.49 },
    { kind = "rect", x = 54, y = 29, w = 2, h = 19, col = "orchid", a = 0.36 },
    { kind = "rect", x = 510, y = 95, w = 3, h = 13, col = "violet", a = 0.52 },
    { kind = "rect", x = 512, y = 95, w = 4, h = 15, col = "violet", a = 0.44 },
    { kind = "rect", x = 516, y = 95, w = 2, h = 9, col = "plum", a = 0.55 },
    { kind = "rect", x = 522, y = 95, w = 2, h = 9, col = "violet", a = 0.72 },
    { kind = "rect", x = 283, y = 214, w = 2, h = 10, col = "plum", a = 0.44 },
    { kind = "rect", x = 285, y = 214, w = 4, h = 16, col = "orchid", a = 0.6 },
    { kind = "rect", x = 162, y = 201, w = 4, h = 14, col = "plum", a = 0.47 },
    { kind = "rect", x = 167, y = 201, w = 4, h = 7, col = "plum", a = 0.5 },
    { kind = "rect", x = 272, y = 212, w = 4, h = 7, col = "orchid", a = 0.53 },
    { kind = "rect", x = 275, y = 212, w = 4, h = 9, col = "orchid", a = 0.59 },
    { kind = "rect", x = 948, y = 203, w = 2, h = 19, col = "violet", a = 0.58 },
    { kind = "rect", x = 953, y = 203, w = 3, h = 19, col = "orchid", a = 0.53 },
    { kind = "rect", x = 958, y = 203, w = 2, h = 19, col = "violet", a = 0.59 },
    { kind = "rect", x = 297, y = 143, w = 2, h = 12, col = "violet", a = 0.74 },
    { kind = "rect", x = 299, y = 143, w = 4, h = 18, col = "plum", a = 0.63 },
    { kind = "rect", x = 305, y = 143, w = 2, h = 20, col = "violet", a = 0.44 },
    { kind = "rect", x = 453, y = 215, w = 3, h = 17, col = "violet", a = 0.53 },
    { kind = "rect", x = 458, y = 215, w = 3, h = 14, col = "orchid", a = 0.46 },
    { kind = "rect", x = 817, y = 271, w = 2, h = 20, col = "plum", a = 0.7 },
    { kind = "rect", x = 820, y = 271, w = 4, h = 16, col = "plum", a = 0.71 },
    { kind = "rect", x = 269, y = 209, w = 2, h = 19, col = "orchid", a = 0.51 },
    { kind = "rect", x = 272, y = 209, w = 3, h = 7, col = "violet", a = 0.57 },
    { kind = "rect", x = 279, y = 209, w = 2, h = 18, col = "plum", a = 0.46 },
    { kind = "rect", x = 574, y = 146, w = 2, h = 16, col = "violet", a = 0.67 },
    { kind = "rect", x = 576, y = 146, w = 4, h = 13, col = "violet", a = 0.75 },
    { kind = "rect", x = 103, y = 262, w = 4, h = 14, col = "orchid", a = 0.58 },
    { kind = "rect", x = 107, y = 262, w = 2, h = 13, col = "violet", a = 0.41 },
    { kind = "rect", x = 109, y = 262, w = 4, h = 20, col = "orchid", a = 0.74 },
    { kind = "rect", x = 639, y = 234, w = 4, h = 20, col = "violet", a = 0.66 },
    { kind = "rect", x = 641, y = 234, w = 4, h = 16, col = "orchid", a = 0.56 },
    { kind = "rect", x = 647, y = 234, w = 2, h = 17, col = "plum", a = 0.46 },
    { kind = "rect", x = 654, y = 234, w = 4, h = 17, col = "violet", a = 0.73 },
    { kind = "rect", x = 474, y = 132, w = 3, h = 17, col = "plum", a = 0.4 },
    { kind = "rect", x = 479, y = 132, w = 4, h = 12, col = "plum", a = 0.69 },
    { kind = "rect", x = 482, y = 132, w = 2, h = 10, col = "violet", a = 0.74 },
    { kind = "rect", x = 480, y = 132, w = 3, h = 19, col = "orchid", a = 0.6 },
    { kind = "rect", x = 43, y = 125, w = 4, h = 8, col = "orchid", a = 0.5 },
    { kind = "rect", x = 47, y = 125, w = 4, h = 8, col = "plum", a = 0.57 },
    { kind = "rect", x = 51, y = 125, w = 3, h = 11, col = "plum", a = 0.59 },
    { kind = "rect", x = 49, y = 125, w = 4, h = 14, col = "violet", a = 0.74 },
    { kind = "rect", x = 409, y = 89, w = 3, h = 18, col = "plum", a = 0.38 },
    { kind = "rect", x = 411, y = 89, w = 3, h = 13, col = "violet", a = 0.38 },
    { kind = "rect", x = 417, y = 89, w = 2, h = 6, col = "plum", a = 0.43 },
    { kind = "rect", x = 278, y = 38, w = 2, h = 10, col = "plum", a = 0.7 },
    { kind = "rect", x = 281, y = 38, w = 4, h = 9, col = "violet", a = 0.36 },
    { kind = "rect", x = 288, y = 38, w = 2, h = 7, col = "plum", a = 0.54 },
    { kind = "rect", x = 723, y = 251, w = 2, h = 7, col = "violet", a = 0.36 },
    { kind = "rect", x = 727, y = 251, w = 4, h = 6, col = "orchid", a = 0.74 },
    { kind = "rect", x = 659, y = 281, w = 3, h = 13, col = "plum", a = 0.38 },
    { kind = "rect", x = 663, y = 281, w = 4, h = 19, col = "orchid", a = 0.59 },
    { kind = "rect", x = 669, y = 281, w = 4, h = 18, col = "violet", a = 0.59 },
    { kind = "rect", x = 674, y = 281, w = 2, h = 13, col = "orchid", a = 0.48 },
    { kind = "rect", x = 652, y = 81, w = 2, h = 16, col = "orchid", a = 0.42 },
    { kind = "rect", x = 656, y = 81, w = 2, h = 18, col = "orchid", a = 0.7 },
    { kind = "rect", x = 658, y = 81, w = 3, h = 16, col = "plum", a = 0.61 },
    { kind = "rect", x = 667, y = 81, w = 4, h = 8, col = "violet", a = 0.72 },
    { kind = "rect", x = 619, y = 115, w = 4, h = 12, col = "violet", a = 0.6 },
    { kind = "rect", x = 624, y = 115, w = 2, h = 7, col = "orchid", a = 0.65 },
    { kind = "rect", x = 213, y = 203, w = 5, h = 4, col = "cream", a = 0.59 },
    { kind = "rect", x = 485, y = 183, w = 4, h = 5, col = "cream", a = 0.43 },
    { kind = "rect", x = 926, y = 139, w = 5, h = 4, col = "cream", a = 0.58 },
    { kind = "rect", x = 251, y = 145, w = 3, h = 3, col = "cream", a = 0.33 },
    { kind = "rect", x = 333, y = 57, w = 3, h = 5, col = "cream", a = 0.53 },
    { kind = "rect", x = 791, y = 229, w = 4, h = 3, col = "cream", a = 0.37 },
    { kind = "rect", x = 300, y = 221, w = 4, h = 5, col = "cream", a = 0.59 },
    { kind = "rect", x = 896, y = 42, w = 6, h = 4, col = "cream", a = 0.4 },
    { kind = "rect", x = 418, y = 231, w = 3, h = 6, col = "cream", a = 0.31 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "column", x = 168, y = 0, w = 13, h = 352, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 482, y = 0, w = 12, h = 352, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 92, y = 0, w = 11, h = 352, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 295, y = 0, w = 17, h = 352, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "band", x = 0, y = 0, w = 24, h = 352, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
    { kind = "band", x = 968, y = 0, w = 24, h = 352, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 124, y = 93, col = { 0.78, 0.48, 1.00 }, r = 77, flicker = 4.19 },
    { x = 372, y = 99, col = { 0.78, 0.48, 1.00 }, r = 74, flicker = 2.87 },
    { x = 620, y = 170, col = { 0.78, 0.48, 1.00 }, r = 52, flicker = 4.29 },
    { x = 868, y = 236, col = { 0.78, 0.48, 1.00 }, r = 62, flicker = 2.53 },
  },
  mapPos = { x = 12, y = 0, w = 3, h = 1 },
  map = [[
##############################################################
##############################################################
##..........................................................##
##..........................................................##
##...e..................e.............................e.....##
##===...............====...............................===..##
##..........................................................##
##..................===.....................................##
##..........................................................##
##.......................==========.........................##
##..........................................................##
##....................=====.................................##
##..........................................................##
##..........=========..................=========............##
##..........................................................##
AA.........................................................B.#
AA.U.m...p..............m..p..t..............q........k.U..B.#
##############################################################
##############################################################
##############################################################
##############################################################
##############################################################
]],
  key = {
    ["t"] = "boss:prismtyrant",
    ["e"] = "emitter:down:dormant:1",
    ["m"] = "mirror:b",
    ["k"] = "mirror:f",
    ["p"] = "panel:h:f:6",
    ["q"] = "panel:h:b:6",
    ["U"] = "updraft:12",
  },
  links = {
    B = { "deep_stair_1", "F", req = "boss_prismtyrant" },
    A = { "crys_5", "B" },
  },
}
