-- THE JUNCTION. The zone's exam, and the one circuit that needs both
-- of them.
--
-- The node wants TWO beams. One falls straight down the shaft from the
-- emitter above it. The other falls at col 14, six slots away from
-- where the reflector panel is parked -- and only Vess's charge moves a
-- panel. Set the panel first, then wake both emitters.
--
-- The last span before the arena is a vane lock: the Hollows are built
-- upward and the city expected its caretakers to be able to hold a
-- glide. Take the Spire first.
--
-- Note what is NOT required: nothing has to happen at the same instant.
-- The panel stays where it is shoved, so one bot can do all of this by
-- swapping, slowly. Co-op just means nobody has to walk back.
return {
  zone = "crystal", music = "crystal",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "plum", a = 0.34, a2 = 0.08, py = 0.05 },
    { kind = "column", x = -14, y = 116, w = 11, h = 156, col = "black", a = 0.4, py = 0.24, step = 36, acc = "orchid" },
    { kind = "column", x = 16, y = 102, w = 11, h = 170, col = "black", a = 0.4, py = 0.24, step = 23, acc = "orchid" },
    { kind = "column", x = 70, y = 95, w = 11, h = 177, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 118, y = 124, w = 11, h = 148, col = "black", a = 0.4, py = 0.24, step = 25, acc = "orchid" },
    { kind = "column", x = 170, y = 173, w = 11, h = 99, col = "black", a = 0.4, py = 0.24, step = 37, acc = "orchid" },
    { kind = "column", x = 217, y = 163, w = 11, h = 109, col = "black", a = 0.4, py = 0.24, step = 32, acc = "orchid" },
    { kind = "column", x = 261, y = 64, w = 11, h = 208, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 313, y = 122, w = 11, h = 150, col = "black", a = 0.4, py = 0.24, step = 27, acc = "orchid" },
    { kind = "column", x = 348, y = 100, w = 11, h = 172, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 377, y = 41, w = 11, h = 231, col = "black", a = 0.4, py = 0.24, step = 36, acc = "orchid" },
    { kind = "column", x = 404, y = 160, w = 11, h = 112, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 433, y = 161, w = 11, h = 111, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 463, y = 128, w = 11, h = 144, col = "black", a = 0.4, py = 0.24, step = 28, acc = "orchid" },
    { kind = "column", x = 516, y = 114, w = 11, h = 158, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 568, y = 98, w = 11, h = 174, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 599, y = 74, w = 11, h = 198, col = "black", a = 0.4, py = 0.24, step = 40, acc = "orchid" },
    { kind = "column", x = 633, y = 150, w = 11, h = 122, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 663, y = 59, w = 11, h = 213, col = "black", a = 0.4, py = 0.24, step = 29, acc = "orchid" },
    { kind = "column", x = 699, y = 118, w = 11, h = 154, col = "black", a = 0.4, py = 0.24, step = 37, acc = "orchid" },
    { kind = "column", x = 749, y = 88, w = 11, h = 184, col = "black", a = 0.4, py = 0.24, step = 22, acc = "orchid" },
    { kind = "column", x = 792, y = 141, w = 11, h = 131, col = "black", a = 0.4, py = 0.24, step = 34, acc = "orchid" },
    { kind = "column", x = 838, y = 108, w = 11, h = 164, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 884, y = 129, w = 11, h = 143, col = "black", a = 0.4, py = 0.24, step = 38, acc = "orchid" },
    { kind = "column", x = 915, y = 44, w = 11, h = 228, col = "black", a = 0.4, py = 0.24, step = 31, acc = "orchid" },
    { kind = "column", x = 942, y = 87, w = 11, h = 185, col = "black", a = 0.4, py = 0.24, step = 33, acc = "orchid" },
    { kind = "column", x = 7, y = 117, w = 17, h = 155, col = "black", a = 0.24, py = 0.13, step = 26, acc = "orchid" },
    { kind = "column", x = 49, y = 98, w = 17, h = 174, col = "black", a = 0.24, py = 0.13, step = 23, acc = "orchid" },
    { kind = "column", x = 108, y = 94, w = 17, h = 178, col = "black", a = 0.24, py = 0.13, step = 38, acc = "orchid" },
    { kind = "column", x = 153, y = 79, w = 17, h = 193, col = "black", a = 0.24, py = 0.13, step = 35, acc = "orchid" },
    { kind = "column", x = 204, y = 82, w = 17, h = 190, col = "black", a = 0.24, py = 0.13, step = 32, acc = "orchid" },
    { kind = "column", x = 252, y = 93, w = 17, h = 179, col = "black", a = 0.24, py = 0.13, step = 37, acc = "orchid" },
    { kind = "column", x = 304, y = 148, w = 17, h = 124, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 365, y = 94, w = 17, h = 178, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 420, y = 62, w = 17, h = 210, col = "black", a = 0.24, py = 0.13, step = 29, acc = "orchid" },
    { kind = "column", x = 455, y = 117, w = 17, h = 155, col = "black", a = 0.24, py = 0.13, step = 33, acc = "orchid" },
    { kind = "column", x = 489, y = 82, w = 17, h = 190, col = "black", a = 0.24, py = 0.13, step = 37, acc = "orchid" },
    { kind = "column", x = 526, y = 130, w = 17, h = 142, col = "black", a = 0.24, py = 0.13, step = 22, acc = "orchid" },
    { kind = "column", x = 573, y = 163, w = 17, h = 109, col = "black", a = 0.24, py = 0.13, step = 39, acc = "orchid" },
    { kind = "column", x = 614, y = 42, w = 17, h = 230, col = "black", a = 0.24, py = 0.13, step = 23, acc = "orchid" },
    { kind = "column", x = 665, y = 135, w = 17, h = 137, col = "black", a = 0.24, py = 0.13, step = 38, acc = "orchid" },
    { kind = "column", x = 723, y = 120, w = 17, h = 152, col = "black", a = 0.24, py = 0.13, step = 33, acc = "orchid" },
    { kind = "column", x = 757, y = 50, w = 17, h = 222, col = "black", a = 0.24, py = 0.13, step = 24, acc = "orchid" },
    { kind = "column", x = 810, y = 125, w = 17, h = 147, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "column", x = 851, y = 82, w = 17, h = 190, col = "black", a = 0.24, py = 0.13, step = 36, acc = "orchid" },
    { kind = "column", x = 901, y = 88, w = 17, h = 184, col = "black", a = 0.24, py = 0.13, step = 23, acc = "orchid" },
    { kind = "column", x = 954, y = 42, w = 17, h = 230, col = "black", a = 0.24, py = 0.13, step = 27, acc = "orchid" },
    { kind = "shaft", x = 790, y = 0, w = 48, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = 28, ph = 4.12 },
    { kind = "shaft", x = 530, y = 0, w = 34, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = -32, ph = 1.06 },
    { kind = "shaft", x = 860, y = 0, w = 45, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = -17, ph = 5.61 },
    { kind = "shaft", x = 500, y = 0, w = 32, h = 244, col = "orchid", a = 0.16, py = 0.2, skew = -7, ph = 4.89 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "rect", x = 574, y = 185, w = 3, h = 14, col = "plum", a = 0.53 },
    { kind = "rect", x = 576, y = 185, w = 4, h = 12, col = "orchid", a = 0.41 },
    { kind = "rect", x = 711, y = 95, w = 4, h = 7, col = "orchid", a = 0.45 },
    { kind = "rect", x = 715, y = 95, w = 3, h = 7, col = "violet", a = 0.66 },
    { kind = "rect", x = 106, y = 224, w = 2, h = 15, col = "orchid", a = 0.72 },
    { kind = "rect", x = 111, y = 224, w = 2, h = 14, col = "orchid", a = 0.39 },
    { kind = "rect", x = 146, y = 137, w = 3, h = 17, col = "orchid", a = 0.47 },
    { kind = "rect", x = 148, y = 137, w = 2, h = 9, col = "plum", a = 0.47 },
    { kind = "rect", x = 425, y = 34, w = 4, h = 12, col = "orchid", a = 0.52 },
    { kind = "rect", x = 427, y = 34, w = 3, h = 10, col = "violet", a = 0.37 },
    { kind = "rect", x = 433, y = 34, w = 3, h = 8, col = "orchid", a = 0.58 },
    { kind = "rect", x = 639, y = 211, w = 2, h = 7, col = "plum", a = 0.69 },
    { kind = "rect", x = 641, y = 211, w = 2, h = 7, col = "orchid", a = 0.67 },
    { kind = "rect", x = 647, y = 211, w = 2, h = 13, col = "plum", a = 0.49 },
    { kind = "rect", x = 99, y = 31, w = 4, h = 8, col = "orchid", a = 0.58 },
    { kind = "rect", x = 102, y = 31, w = 3, h = 13, col = "orchid", a = 0.41 },
    { kind = "rect", x = 103, y = 31, w = 3, h = 14, col = "orchid", a = 0.72 },
    { kind = "rect", x = 108, y = 31, w = 3, h = 13, col = "violet", a = 0.62 },
    { kind = "rect", x = 219, y = 198, w = 4, h = 15, col = "plum", a = 0.64 },
    { kind = "rect", x = 224, y = 198, w = 4, h = 11, col = "plum", a = 0.69 },
    { kind = "rect", x = 227, y = 198, w = 3, h = 17, col = "violet", a = 0.71 },
    { kind = "rect", x = 225, y = 198, w = 2, h = 13, col = "plum", a = 0.5 },
    { kind = "rect", x = 314, y = 97, w = 3, h = 19, col = "violet", a = 0.6 },
    { kind = "rect", x = 319, y = 97, w = 3, h = 18, col = "orchid", a = 0.66 },
    { kind = "rect", x = 874, y = 212, w = 4, h = 20, col = "plum", a = 0.64 },
    { kind = "rect", x = 879, y = 212, w = 3, h = 16, col = "plum", a = 0.45 },
    { kind = "rect", x = 634, y = 65, w = 3, h = 6, col = "violet", a = 0.6 },
    { kind = "rect", x = 638, y = 65, w = 3, h = 19, col = "plum", a = 0.64 },
    { kind = "rect", x = 638, y = 65, w = 4, h = 14, col = "orchid", a = 0.48 },
    { kind = "rect", x = 673, y = 185, w = 2, h = 11, col = "orchid", a = 0.71 },
    { kind = "rect", x = 675, y = 185, w = 3, h = 13, col = "orchid", a = 0.58 },
    { kind = "rect", x = 681, y = 185, w = 3, h = 13, col = "plum", a = 0.57 },
    { kind = "rect", x = 688, y = 185, w = 4, h = 19, col = "violet", a = 0.67 },
    { kind = "rect", x = 295, y = 206, w = 2, h = 11, col = "orchid", a = 0.55 },
    { kind = "rect", x = 299, y = 206, w = 3, h = 15, col = "violet", a = 0.73 },
    { kind = "rect", x = 303, y = 206, w = 2, h = 18, col = "orchid", a = 0.58 },
    { kind = "rect", x = 304, y = 206, w = 3, h = 12, col = "violet", a = 0.5 },
    { kind = "rect", x = 949, y = 120, w = 4, h = 15, col = "plum", a = 0.36 },
    { kind = "rect", x = 954, y = 120, w = 2, h = 17, col = "plum", a = 0.73 },
    { kind = "rect", x = 957, y = 120, w = 2, h = 14, col = "violet", a = 0.61 },
    { kind = "rect", x = 83, y = 58, w = 4, h = 7, col = "violet", a = 0.39 },
    { kind = "rect", x = 87, y = 58, w = 4, h = 10, col = "orchid", a = 0.69 },
    { kind = "rect", x = 919, y = 102, w = 4, h = 13, col = "violet", a = 0.55 },
    { kind = "rect", x = 922, y = 102, w = 4, h = 16, col = "plum", a = 0.42 },
    { kind = "rect", x = 923, y = 102, w = 2, h = 14, col = "plum", a = 0.71 },
    { kind = "rect", x = 737, y = 39, w = 3, h = 11, col = "orchid", a = 0.65 },
    { kind = "rect", x = 740, y = 39, w = 4, h = 16, col = "orchid", a = 0.56 },
    { kind = "rect", x = 747, y = 39, w = 4, h = 17, col = "orchid", a = 0.54 },
    { kind = "rect", x = 743, y = 39, w = 3, h = 19, col = "plum", a = 0.52 },
    { kind = "rect", x = 368, y = 211, w = 3, h = 9, col = "orchid", a = 0.61 },
    { kind = "rect", x = 373, y = 211, w = 2, h = 13, col = "plum", a = 0.55 },
    { kind = "rect", x = 374, y = 211, w = 4, h = 19, col = "plum", a = 0.64 },
    { kind = "rect", x = 383, y = 211, w = 3, h = 14, col = "orchid", a = 0.48 },
    { kind = "rect", x = 229, y = 191, w = 4, h = 20, col = "plum", a = 0.46 },
    { kind = "rect", x = 234, y = 191, w = 4, h = 18, col = "violet", a = 0.46 },
    { kind = "rect", x = 233, y = 191, w = 2, h = 16, col = "plum", a = 0.4 },
    { kind = "rect", x = 557, y = 111, w = 2, h = 20, col = "violet", a = 0.71 },
    { kind = "rect", x = 560, y = 111, w = 2, h = 13, col = "plum", a = 0.59 },
    { kind = "rect", x = 563, y = 111, w = 3, h = 13, col = "violet", a = 0.72 },
    { kind = "rect", x = 566, y = 111, w = 3, h = 14, col = "orchid", a = 0.64 },
    { kind = "rect", x = 483, y = 180, w = 2, h = 16, col = "plum", a = 0.46 },
    { kind = "rect", x = 488, y = 180, w = 4, h = 14, col = "violet", a = 0.74 },
    { kind = "rect", x = 7, y = 139, w = 3, h = 9, col = "orchid", a = 0.59 },
    { kind = "rect", x = 10, y = 139, w = 3, h = 11, col = "violet", a = 0.72 },
    { kind = "rect", x = 17, y = 139, w = 4, h = 14, col = "violet", a = 0.41 },
    { kind = "rect", x = 831, y = 77, w = 4, h = 19, col = "plum", a = 0.37 },
    { kind = "rect", x = 836, y = 77, w = 3, h = 8, col = "violet", a = 0.47 },
    { kind = "rect", x = 837, y = 77, w = 4, h = 20, col = "plum", a = 0.49 },
    { kind = "rect", x = 846, y = 77, w = 4, h = 6, col = "orchid", a = 0.71 },
    { kind = "rect", x = 338, y = 52, w = 2, h = 8, col = "orchid", a = 0.73 },
    { kind = "rect", x = 342, y = 52, w = 4, h = 18, col = "orchid", a = 0.64 },
    { kind = "rect", x = 344, y = 52, w = 3, h = 10, col = "violet", a = 0.66 },
    { kind = "rect", x = 353, y = 52, w = 4, h = 8, col = "violet", a = 0.67 },
    { kind = "rect", x = 39, y = 77, w = 6, h = 5, col = "cream", a = 0.56 },
    { kind = "rect", x = 454, y = 27, w = 3, h = 3, col = "cream", a = 0.31 },
    { kind = "rect", x = 490, y = 45, w = 4, h = 4, col = "cream", a = 0.38 },
    { kind = "rect", x = 48, y = 123, w = 3, h = 3, col = "cream", a = 0.33 },
    { kind = "rect", x = 866, y = 89, w = 4, h = 3, col = "cream", a = 0.47 },
    { kind = "rect", x = 139, y = 143, w = 6, h = 3, col = "cream", a = 0.53 },
    { kind = "rect", x = 914, y = 90, w = 6, h = 3, col = "cream", a = 0.31 },
    { kind = "rect", x = 415, y = 61, w = 4, h = 4, col = "cream", a = 0.57 },
    { kind = "rect", x = 603, y = 177, w = 4, h = 5, col = "cream", a = 0.36 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "column", x = 443, y = 0, w = 10, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 73, y = 0, w = 11, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 470, y = 0, w = 15, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "column", x = 578, y = 0, w = 17, h = 272, col = "black", a = 0.8, py = -0.15, step = 30, acc = "violet" },
    { kind = "band", x = 0, y = 0, w = 24, h = 272, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
    { kind = "band", x = 936, y = 0, w = 24, h = 272, col = "plum", a = 0.45, a2 = 0.45, py = -0.06 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 120, y = 111, col = { 0.78, 0.48, 1.00 }, r = 83, flicker = 3.44 },
    { x = 360, y = 80, col = { 0.78, 0.48, 1.00 }, r = 63, flicker = 3.7 },
    { x = 600, y = 102, col = { 0.78, 0.48, 1.00 }, r = 59, flicker = 3.53 },
    { x = 840, y = 136, col = { 0.78, 0.48, 1.00 }, r = 76, flicker = 2.22 },
  },
  mapPos = { x = 9, y = 0, w = 3, h = 1 },
  map = [[
############################################################
############################################################
##...............................H..................I.....##
##......5........................H..................I.....##
##.n....%%.......................H..................I.....##
##....#######.............w....w.H..................I.....##
##.............w.........w..u....H..........u.......I.....##
##..........w.e...............f..H..................I.....##
##........=======.......=======..H......=======.....I.....##
##...............................H..................I.....##
##...............................H..................I.....BB
##.........pd..d....1......d.do..H..w...............I.a...BB
######...#################################%#################
######...###############################.....###############
######...###############################..8..###############
######AAA###################################################
######AAA###################################################
]],
  gates = { H = "crys_bus5", I = "driftvanes" },
  gateStyle = { H = "curtain" },
  key = {
    ["a"] = "cell",
    ["8"] = "chest:chest_crys5b:scrap:25",

    ["n"] = "anchor",
    ["d"] = "shardling",
    ["u"] = "cryoturret",
    ["w"] = "prismwisp",
    ["5"] = "capsule:cap_crys",
    ["e"] = "emitter:down:dormant:9",
    ["f"] = "emitter:down:dormant:9",
    ["p"] = "panel:h:b:3",
    ["o"] = "node:crys_bus5:2",
    ["1"] = "sign:sign_resonance",
  },
  links = {
    A = { "crys_4", "B" },
    B = { "crys_boss", "A" },
  },
}
