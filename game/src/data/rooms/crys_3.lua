-- THE SPAN. The light bridge stays exactly as it was -- two plates, one
-- of you stays behind -- and above it the zone teaches its second verb.
--
-- A curtain falls from the emitter at col 53, straight down across the
-- corridor, and the floor is the only way east. The REFLECTOR PANEL
-- answers to one thing in this game and one thing only: Vess's CHARGE.
-- Its rail runs along the CATWALK at head height, cols 49 to 53, and
-- the catwalk is why the puzzle works: a panel parked on the floor can
-- only ever catch the beam at the bottom of its fall, which moves the
-- hazard rather than clearing it. Caught at row 8 instead, the beam is
-- turned east along the catwalk into the node at col 56 -- and the
-- whole corridor below is clean.
--
-- Four slots, not three. The panel starts at col 49 and the beam falls
-- at col 53; a three-slot rail stops one tile short of it, and a
-- circuit that cannot be closed is indistinguishable from one the
-- player has not solved yet. tools/checkbeams.py traces every emitter
-- through every legal panel position now, so that cannot recur.
return {
  zone = "crystal", music = "crystal",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 992, h = 288, col = "plum", a = 0.34, a2 = 0.08, py = 0.05 },
    { kind = "column", x = -14, y = 131, w = 11, h = 157, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 31, y = 108, w = 11, h = 180, col = "black", a = 0.4, py = 0.24, step = 35, acc = "orchid" },
    { kind = "column", x = 86, y = 99, w = 11, h = 189, col = "black", a = 0.4, py = 0.24, step = 26, acc = "orchid" },
    { kind = "column", x = 140, y = 71, w = 11, h = 217, col = "black", a = 0.4, py = 0.24, step = 24, acc = "orchid" },
    { kind = "column", x = 170, y = 87, w = 11, h = 201, col = "black", a = 0.4, py = 0.24, step = 35, acc = "orchid" },
    { kind = "column", x = 199, y = 54, w = 11, h = 234, col = "black", a = 0.4, py = 0.24, step = 39, acc = "orchid" },
    { kind = "column", x = 245, y = 121, w = 11, h = 167, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 300, y = 156, w = 11, h = 132, col = "black", a = 0.4, py = 0.24, step = 40, acc = "orchid" },
    { kind = "column", x = 339, y = 58, w = 11, h = 230, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 384, y = 140, w = 11, h = 148, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 428, y = 89, w = 11, h = 199, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 459, y = 106, w = 11, h = 182, col = "black", a = 0.4, py = 0.24, step = 24, acc = "orchid" },
    { kind = "column", x = 508, y = 93, w = 11, h = 195, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 537, y = 84, w = 11, h = 204, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 584, y = 55, w = 11, h = 233, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 635, y = 114, w = 11, h = 174, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 668, y = 148, w = 11, h = 140, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 719, y = 58, w = 11, h = 230, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 753, y = 158, w = 11, h = 130, col = "black", a = 0.4, py = 0.24, step = 26, acc = "orchid" },
    { kind = "column", x = 800, y = 46, w = 11, h = 242, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 846, y = 54, w = 11, h = 234, col = "black", a = 0.4, py = 0.24, step = 39, acc = "orchid" },
    { kind = "column", x = 878, y = 103, w = 11, h = 185, col = "black", a = 0.4, py = 0.24, step = 39, acc = "orchid" },
    { kind = "column", x = 911, y = 61, w = 11, h = 227, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 942, y = 135, w = 11, h = 153, col = "black", a = 0.4, py = 0.24, step = 25, acc = "orchid" },
    { kind = "column", x = 990, y = 47, w = 11, h = 241, col = "black", a = 0.4, py = 0.24, step = 30, acc = "orchid" },
    { kind = "column", x = 7, y = 167, w = 17, h = 121, col = "black", a = 0.24, py = 0.13, step = 38, acc = "orchid" },
    { kind = "column", x = 49, y = 175, w = 17, h = 113, col = "black", a = 0.24, py = 0.13, step = 26, acc = "orchid" },
    { kind = "column", x = 84, y = 171, w = 17, h = 117, col = "black", a = 0.24, py = 0.13, step = 24, acc = "orchid" },
    { kind = "column", x = 144, y = 48, w = 17, h = 240, col = "black", a = 0.24, py = 0.13, step = 37, acc = "orchid" },
    { kind = "column", x = 187, y = 143, w = 17, h = 145, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 234, y = 115, w = 17, h = 173, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 270, y = 153, w = 17, h = 135, col = "black", a = 0.24, py = 0.13, step = 26, acc = "orchid" },
    { kind = "column", x = 327, y = 86, w = 17, h = 202, col = "black", a = 0.24, py = 0.13, step = 40, acc = "orchid" },
    { kind = "column", x = 366, y = 182, w = 17, h = 106, col = "black", a = 0.24, py = 0.13, step = 33, acc = "orchid" },
    { kind = "column", x = 400, y = 155, w = 17, h = 133, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 440, y = 50, w = 17, h = 238, col = "black", a = 0.24, py = 0.13, step = 40, acc = "orchid" },
    { kind = "column", x = 471, y = 180, w = 17, h = 108, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 518, y = 143, w = 17, h = 145, col = "black", a = 0.24, py = 0.13, step = 37, acc = "orchid" },
    { kind = "column", x = 566, y = 69, w = 17, h = 219, col = "black", a = 0.24, py = 0.13, step = 38, acc = "orchid" },
    { kind = "column", x = 625, y = 134, w = 17, h = 154, col = "black", a = 0.24, py = 0.13, step = 31, acc = "orchid" },
    { kind = "column", x = 674, y = 81, w = 17, h = 207, col = "black", a = 0.24, py = 0.13, step = 25, acc = "orchid" },
    { kind = "column", x = 730, y = 123, w = 17, h = 165, col = "black", a = 0.24, py = 0.13, step = 29, acc = "orchid" },
    { kind = "column", x = 765, y = 178, w = 17, h = 110, col = "black", a = 0.24, py = 0.13, step = 33, acc = "orchid" },
    { kind = "column", x = 823, y = 126, w = 17, h = 162, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 874, y = 121, w = 17, h = 167, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 922, y = 155, w = 17, h = 133, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 981, y = 163, w = 17, h = 125, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "shaft", x = 164, y = 0, w = 53, h = 259, col = "orchid", a = 0.16, py = 0.2, skew = 32, ph = 0.47 },
    { kind = "shaft", x = 333, y = 0, w = 37, h = 259, col = "orchid", a = 0.16, py = 0.2, skew = -7, ph = 4.75 },
    { kind = "shaft", x = 674, y = 0, w = 33, h = 259, col = "orchid", a = 0.16, py = 0.2, skew = 22, ph = 3.99 },
    { kind = "shaft", x = 187, y = 0, w = 42, h = 259, col = "orchid", a = 0.16, py = 0.2, skew = 21, ph = 1.67 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 449, y = 221, w = 2, h = 7, col = "violet", a = 0.56 },
    { kind = "rect", x = 453, y = 221, w = 3, h = 8, col = "orchid", a = 0.74 },
    { kind = "rect", x = 453, y = 221, w = 3, h = 18, col = "orchid", a = 0.72 },
    { kind = "rect", x = 438, y = 169, w = 2, h = 7, col = "orchid", a = 0.58 },
    { kind = "rect", x = 441, y = 169, w = 2, h = 17, col = "violet", a = 0.54 },
    { kind = "rect", x = 448, y = 169, w = 3, h = 9, col = "orchid", a = 0.46 },
    { kind = "rect", x = 450, y = 169, w = 3, h = 6, col = "plum", a = 0.56 },
    { kind = "rect", x = 554, y = 120, w = 4, h = 12, col = "violet", a = 0.38 },
    { kind = "rect", x = 559, y = 120, w = 4, h = 6, col = "orchid", a = 0.73 },
    { kind = "rect", x = 558, y = 120, w = 2, h = 13, col = "violet", a = 0.35 },
    { kind = "rect", x = 305, y = 74, w = 4, h = 10, col = "plum", a = 0.68 },
    { kind = "rect", x = 309, y = 74, w = 2, h = 9, col = "orchid", a = 0.51 },
    { kind = "rect", x = 313, y = 74, w = 2, h = 18, col = "orchid", a = 0.61 },
    { kind = "rect", x = 317, y = 74, w = 3, h = 11, col = "orchid", a = 0.62 },
    { kind = "rect", x = 936, y = 107, w = 2, h = 14, col = "plum", a = 0.49 },
    { kind = "rect", x = 939, y = 107, w = 2, h = 8, col = "plum", a = 0.58 },
    { kind = "rect", x = 940, y = 107, w = 4, h = 13, col = "orchid", a = 0.73 },
    { kind = "rect", x = 942, y = 107, w = 4, h = 15, col = "plum", a = 0.39 },
    { kind = "rect", x = 358, y = 218, w = 2, h = 18, col = "orchid", a = 0.57 },
    { kind = "rect", x = 362, y = 218, w = 3, h = 16, col = "orchid", a = 0.65 },
    { kind = "rect", x = 366, y = 218, w = 3, h = 13, col = "orchid", a = 0.67 },
    { kind = "rect", x = 449, y = 205, w = 2, h = 7, col = "orchid", a = 0.66 },
    { kind = "rect", x = 453, y = 205, w = 4, h = 14, col = "plum", a = 0.54 },
    { kind = "rect", x = 604, y = 103, w = 3, h = 10, col = "orchid", a = 0.49 },
    { kind = "rect", x = 606, y = 103, w = 3, h = 10, col = "orchid", a = 0.7 },
    { kind = "rect", x = 614, y = 103, w = 3, h = 13, col = "orchid", a = 0.63 },
    { kind = "rect", x = 794, y = 64, w = 4, h = 8, col = "orchid", a = 0.56 },
    { kind = "rect", x = 798, y = 64, w = 2, h = 9, col = "plum", a = 0.45 },
    { kind = "rect", x = 798, y = 64, w = 2, h = 16, col = "plum", a = 0.59 },
    { kind = "rect", x = 800, y = 64, w = 3, h = 10, col = "plum", a = 0.7 },
    { kind = "rect", x = 853, y = 226, w = 2, h = 7, col = "orchid", a = 0.36 },
    { kind = "rect", x = 858, y = 226, w = 2, h = 8, col = "plum", a = 0.38 },
    { kind = "rect", x = 850, y = 63, w = 3, h = 18, col = "violet", a = 0.72 },
    { kind = "rect", x = 853, y = 63, w = 3, h = 10, col = "orchid", a = 0.65 },
    { kind = "rect", x = 856, y = 63, w = 4, h = 11, col = "orchid", a = 0.38 },
    { kind = "rect", x = 859, y = 63, w = 3, h = 11, col = "violet", a = 0.37 },
    { kind = "rect", x = 366, y = 111, w = 3, h = 19, col = "orchid", a = 0.56 },
    { kind = "rect", x = 368, y = 111, w = 2, h = 17, col = "violet", a = 0.61 },
    { kind = "rect", x = 370, y = 111, w = 3, h = 16, col = "orchid", a = 0.6 },
    { kind = "rect", x = 381, y = 111, w = 2, h = 18, col = "plum", a = 0.74 },
    { kind = "rect", x = 478, y = 233, w = 3, h = 12, col = "orchid", a = 0.46 },
    { kind = "rect", x = 481, y = 233, w = 3, h = 20, col = "plum", a = 0.54 },
    { kind = "rect", x = 482, y = 233, w = 3, h = 8, col = "orchid", a = 0.73 },
    { kind = "rect", x = 490, y = 233, w = 2, h = 9, col = "violet", a = 0.4 },
    { kind = "rect", x = 792, y = 33, w = 4, h = 10, col = "plum", a = 0.58 },
    { kind = "rect", x = 794, y = 33, w = 4, h = 15, col = "violet", a = 0.74 },
    { kind = "rect", x = 726, y = 64, w = 2, h = 13, col = "orchid", a = 0.59 },
    { kind = "rect", x = 729, y = 64, w = 4, h = 15, col = "violet", a = 0.42 },
    { kind = "rect", x = 730, y = 64, w = 4, h = 14, col = "violet", a = 0.4 },
    { kind = "rect", x = 732, y = 64, w = 2, h = 16, col = "plum", a = 0.62 },
    { kind = "rect", x = 523, y = 164, w = 4, h = 19, col = "orchid", a = 0.68 },
    { kind = "rect", x = 525, y = 164, w = 2, h = 12, col = "violet", a = 0.35 },
    { kind = "rect", x = 533, y = 164, w = 2, h = 19, col = "orchid", a = 0.64 },
    { kind = "rect", x = 538, y = 164, w = 3, h = 19, col = "plum", a = 0.59 },
    { kind = "rect", x = 955, y = 132, w = 3, h = 17, col = "orchid", a = 0.61 },
    { kind = "rect", x = 957, y = 132, w = 3, h = 12, col = "plum", a = 0.72 },
    { kind = "rect", x = 982, y = 241, w = 4, h = 8, col = "plum", a = 0.68 },
    { kind = "rect", x = 985, y = 241, w = 3, h = 18, col = "violet", a = 0.51 },
    { kind = "rect", x = 986, y = 241, w = 2, h = 10, col = "plum", a = 0.74 },
    { kind = "rect", x = 862, y = 202, w = 4, h = 11, col = "violet", a = 0.56 },
    { kind = "rect", x = 865, y = 202, w = 2, h = 16, col = "violet", a = 0.4 },
    { kind = "rect", x = 271, y = 120, w = 2, h = 6, col = "plum", a = 0.5 },
    { kind = "rect", x = 276, y = 120, w = 4, h = 11, col = "orchid", a = 0.71 },
    { kind = "rect", x = 279, y = 120, w = 4, h = 15, col = "violet", a = 0.72 },
    { kind = "rect", x = 280, y = 120, w = 4, h = 10, col = "plum", a = 0.48 },
    { kind = "rect", x = 640, y = 140, w = 3, h = 13, col = "plum", a = 0.65 },
    { kind = "rect", x = 643, y = 140, w = 3, h = 9, col = "violet", a = 0.44 },
    { kind = "rect", x = 646, y = 140, w = 4, h = 7, col = "violet", a = 0.36 },
    { kind = "rect", x = 652, y = 140, w = 4, h = 7, col = "plum", a = 0.64 },
    { kind = "rect", x = 761, y = 56, w = 4, h = 12, col = "orchid", a = 0.4 },
    { kind = "rect", x = 763, y = 56, w = 4, h = 6, col = "violet", a = 0.46 },
    { kind = "rect", x = 769, y = 56, w = 4, h = 17, col = "plum", a = 0.49 },
    { kind = "rect", x = 767, y = 56, w = 3, h = 17, col = "orchid", a = 0.45 },
    { kind = "rect", x = 377, y = 144, w = 2, h = 8, col = "orchid", a = 0.4 },
    { kind = "rect", x = 382, y = 144, w = 4, h = 11, col = "violet", a = 0.72 },
    { kind = "rect", x = 413, y = 162, w = 2, h = 13, col = "violet", a = 0.38 },
    { kind = "rect", x = 417, y = 162, w = 2, h = 11, col = "orchid", a = 0.58 },
    { kind = "rect", x = 419, y = 162, w = 2, h = 16, col = "plum", a = 0.69 },
    { kind = "rect", x = 348, y = 149, w = 5, h = 4, col = "cream", a = 0.37 },
    { kind = "rect", x = 756, y = 84, w = 3, h = 4, col = "cream", a = 0.36 },
    { kind = "rect", x = 380, y = 174, w = 4, h = 5, col = "cream", a = 0.52 },
    { kind = "rect", x = 562, y = 200, w = 5, h = 4, col = "cream", a = 0.4 },
    { kind = "rect", x = 871, y = 85, w = 4, h = 4, col = "cream", a = 0.38 },
    { kind = "rect", x = 895, y = 108, w = 6, h = 6, col = "cream", a = 0.48 },
    { kind = "rect", x = 698, y = 74, w = 3, h = 3, col = "cream", a = 0.42 },
    { kind = "rect", x = 593, y = 214, w = 6, h = 5, col = "cream", a = 0.56 },
    { kind = "rect", x = 224, y = 160, w = 6, h = 3, col = "cream", a = 0.46 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "column", x = 247, y = 0, w = 14, h = 288, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 506, y = 0, w = 10, h = 288, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 935, y = 0, w = 11, h = 288, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 200, y = 0, w = 14, h = 288, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "band", x = 0, y = 0, w = 24, h = 288, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
    { kind = "band", x = 968, y = 0, w = 24, h = 288, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 124, y = 159, col = { 0.78, 0.48, 1.00 }, r = 57, flicker = 4.12 },
    { x = 372, y = 65, col = { 0.78, 0.48, 1.00 }, r = 78, flicker = 4.34 },
    { x = 620, y = 76, col = { 0.78, 0.48, 1.00 }, r = 74, flicker = 3.5 },
    { x = 868, y = 72, col = { 0.78, 0.48, 1.00 }, r = 62, flicker = 3.18 },
  },
  mapPos = { x = 6, y = 1, w = 3, h = 1 },
  gates = { G = "!bridge_c3", H = "crys_bus3" },
  gateStyle = { H = "curtain" },
  map = [[
##############################################################
##############################################################
#####.......................................#######........H##
###..........w................................##...........H##
##.........................................................H##
##....w.....................................w..............H##
##......................w...........w............#...e.....H##
##.........................................................H##
##..........w.....................w..........2...p......o..H##
##.........................................===============.H##
AA.........................................................HBB
AA..1.......x.................x..........4.....y...........HBB
##############GGGGGGGGGGGGGGG##GGGGGGGGGGGGGGG################
##############...............##...............################
##############...............##...............################
###############..............##..............#################
###############^^^^^^^^^^^^^^##^^^^^^^^^^^^^^#################
##############################################################
]],
  key = {
    ["x"] = "plate:bridge_c3",
    ["y"] = "plate:bridge_c3",
    ["1"] = "sign:sign_bridge",
    ["w"] = "prismwisp",
    ["4"] = "tank:tank_crys",
    ["e"] = "emitter:down",
    ["p"] = "panel:h:b:4",
    ["o"] = "node:crys_bus3",
    ["2"] = "sign:sign_panel",
  },
  links = {
    A = { "crys_2", "B" },
    B = { "crys_4", "A" },
  },
}
