-- Mosswood entry: gentle combat introduction.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 960, h = 272, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 28, h = 272, col = "black", a = 0.31, py = 0.15, step = 31, acc = "moss" },
    { kind = "column", x = 53, y = 0, w = 27, h = 272, col = "black", a = 0.27, py = 0.19, step = 34, acc = "moss" },
    { kind = "column", x = 132, y = 0, w = 40, h = 272, col = "black", a = 0.4, py = 0.22, step = 33, acc = "moss" },
    { kind = "column", x = 207, y = 0, w = 34, h = 272, col = "black", a = 0.39, py = 0.23, step = 40, acc = "moss" },
    { kind = "column", x = 296, y = 0, w = 25, h = 272, col = "black", a = 0.38, py = 0.22, step = 35, acc = "moss" },
    { kind = "column", x = 367, y = 0, w = 23, h = 272, col = "black", a = 0.35, py = 0.14, step = 40, acc = "moss" },
    { kind = "column", x = 447, y = 0, w = 26, h = 272, col = "black", a = 0.38, py = 0.19, step = 41, acc = "moss" },
    { kind = "column", x = 539, y = 0, w = 36, h = 272, col = "black", a = 0.34, py = 0.19, step = 34, acc = "moss" },
    { kind = "column", x = 638, y = 0, w = 28, h = 272, col = "black", a = 0.27, py = 0.27, step = 34, acc = "moss" },
    { kind = "column", x = 731, y = 0, w = 30, h = 272, col = "black", a = 0.32, py = 0.23, step = 38, acc = "moss" },
    { kind = "column", x = 797, y = 0, w = 37, h = 272, col = "black", a = 0.26, py = 0.17, step = 38, acc = "moss" },
    { kind = "column", x = 868, y = 0, w = 40, h = 272, col = "black", a = 0.29, py = 0.16, step = 34, acc = "moss" },
    { kind = "shaft", x = 343, y = 0, w = 48, h = 231, col = "lime", a = 0.15, py = 0.18, skew = 22, ph = 3.38 },
    { kind = "shaft", x = 345, y = 0, w = 42, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -22, ph = 2.2 },
    { kind = "shaft", x = 544, y = 0, w = 66, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -1, ph = 4.49 },
    { kind = "shaft", x = 252, y = 0, w = 43, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -18, ph = 0.26 },
    { kind = "shaft", x = 524, y = 0, w = 69, h = 231, col = "lime", a = 0.15, py = 0.18, skew = -9, ph = 4.34 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 540, y = 105, w = 2, h = 13, col = "moss", a = 0.73, lw = 2, sway = 5, rate = 0.34, bob = true },
    { kind = "hang", x = 494, y = 24, w = 2, h = 38, col = "moss", a = 0.7, lw = 2, sway = 4, rate = 0.44, bob = true },
    { kind = "hang", x = 328, y = 71, w = 2, h = 26, col = "moss", a = 0.7, lw = 2, sway = 2, rate = 0.38, bob = true },
    { kind = "hang", x = 948, y = 56, w = 2, h = 11, col = "moss", a = 0.42, lw = 2, sway = 5, rate = 0.31, bob = true },
    { kind = "hang", x = 842, y = 46, w = 2, h = 19, col = "moss", a = 0.4, lw = 2, sway = 3, rate = 0.44, bob = true },
    { kind = "hang", x = 223, y = 100, w = 2, h = 10, col = "moss", a = 0.43, lw = 2, sway = 6, rate = 0.26, bob = true },
    { kind = "hang", x = 827, y = 122, w = 2, h = 11, col = "moss", a = 0.54, lw = 2, sway = 5, rate = 0.49, bob = true },
    { kind = "hang", x = 557, y = 84, w = 2, h = 31, col = "moss", a = 0.71, lw = 2, sway = 4, rate = 0.21, bob = true },
    { kind = "hang", x = 692, y = 9, w = 2, h = 18, col = "moss", a = 0.49, lw = 2, sway = 4, rate = 0.41, bob = true },
    { kind = "hang", x = 341, y = 50, w = 2, h = 29, col = "moss", a = 0.69, lw = 2, sway = 4, rate = 0.32, bob = true },
    { kind = "hang", x = 811, y = 20, w = 2, h = 33, col = "moss", a = 0.7, lw = 2, sway = 4, rate = 0.27, bob = true },
    { kind = "hang", x = 223, y = 71, w = 2, h = 10, col = "moss", a = 0.67, lw = 2, sway = 2, rate = 0.45, bob = true },
    { kind = "hang", x = 752, y = 108, w = 2, h = 21, col = "moss", a = 0.49, lw = 2, sway = 4, rate = 0.48, bob = true },
    { kind = "hang", x = 205, y = 42, w = 2, h = 13, col = "moss", a = 0.44, lw = 2, sway = 2, rate = 0.43, bob = true },
    { kind = "hang", x = 496, y = 47, w = 2, h = 16, col = "moss", a = 0.55, lw = 2, sway = 3, rate = 0.32, bob = true },
    { kind = "hang", x = 85, y = 33, w = 2, h = 10, col = "moss", a = 0.47, lw = 2, sway = 4, rate = 0.25, bob = true },
    { kind = "hang", x = 925, y = 53, w = 2, h = 17, col = "moss", a = 0.65, lw = 2, sway = 3, rate = 0.22, bob = true },
    { kind = "hang", x = 372, y = 11, w = 2, h = 19, col = "moss", a = 0.44, lw = 2, sway = 5, rate = 0.29, bob = true },
    { kind = "hang", x = 53, y = 69, w = 2, h = 26, col = "moss", a = 0.59, lw = 2, sway = 3, rate = 0.31, bob = true },
    { kind = "hang", x = 350, y = 35, w = 2, h = 14, col = "moss", a = 0.43, lw = 2, sway = 4, rate = 0.32, bob = true },
    { kind = "hang", x = 503, y = 56, w = 2, h = 25, col = "moss", a = 0.66, lw = 2, sway = 4, rate = 0.36, bob = true },
    { kind = "rect", x = 751, y = 109, w = 18, h = 5, col = "moss", a = 0.44 },
    { kind = "rect", x = 360, y = 176, w = 18, h = 5, col = "lime", a = 0.34 },
    { kind = "rect", x = 914, y = 136, w = 17, h = 2, col = "fern", a = 0.44 },
    { kind = "rect", x = 282, y = 59, w = 13, h = 5, col = "fern", a = 0.44 },
    { kind = "rect", x = 700, y = 32, w = 7, h = 3, col = "moss", a = 0.41 },
    { kind = "rect", x = 505, y = 176, w = 17, h = 4, col = "fern", a = 0.37 },
    { kind = "rect", x = 409, y = 132, w = 18, h = 5, col = "moss", a = 0.23 },
    { kind = "rect", x = 679, y = 104, w = 8, h = 3, col = "fern", a = 0.25 },
    { kind = "rect", x = 644, y = 66, w = 16, h = 2, col = "fern", a = 0.4 },
    { kind = "rect", x = 277, y = 222, w = 9, h = 5, col = "moss", a = 0.25 },
    { kind = "rect", x = 508, y = 35, w = 8, h = 4, col = "lime", a = 0.28 },
    { kind = "rect", x = 427, y = 177, w = 7, h = 2, col = "lime", a = 0.41 },
    { kind = "rect", x = 855, y = 203, w = 16, h = 5, col = "moss", a = 0.39 },
    { kind = "rect", x = 164, y = 97, w = 14, h = 2, col = "lime", a = 0.23 },
    { kind = "rect", x = 882, y = 137, w = 7, h = 4, col = "fern", a = 0.21 },
    { kind = "rect", x = 309, y = 160, w = 16, h = 4, col = "fern", a = 0.44 },
    { kind = "rect", x = 684, y = 150, w = 13, h = 5, col = "moss", a = 0.43 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 13, w = 1008, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 107, y = 26, w = 2, h = 55, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.32, bob = true },
    { kind = "hang", x = 864, y = 26, w = 2, h = 46, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.47, bob = true },
    { kind = "hang", x = 861, y = 26, w = 2, h = 35, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 4, rate = 0.46, bob = true },
    { kind = "hang", x = 689, y = 26, w = 2, h = 41, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.4, bob = true },
    { kind = "hang", x = 128, y = 26, w = 2, h = 53, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 8, rate = 0.67, bob = true },
    { kind = "hang", x = 610, y = 26, w = 2, h = 45, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.59, bob = true },
    { kind = "hang", x = 622, y = 26, w = 2, h = 43, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.59, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 938, y = 0, w = 22, h = 272, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 160, y = 43, col = { 0.80, 1.00, 0.66 }, r = 96, flicker = 1.25 },
    { x = 480, y = 43, col = { 0.80, 1.00, 0.66 }, r = 75, flicker = 1.73 },
    { x = 800, y = 43, col = { 0.80, 1.00, 0.66 }, r = 68, flicker = 2.14 },
  },
  mapPos = { x = 5, y = 3, w = 3, h = 1 },
  map = [[
############################################################
############################################################
######.........######...............####.........#.#########
###.....................................................####
####.........................................####........###
####............................====....................##.#
####.......====..........................................#.#
##.....................1..........................%......#.#
##....................###.........................%......#EE
###...............................................%.......EE
A.##........g..............====...........h.....############
A.##....................................................####
A................h......................g...===...........BB
##.......#####........cccc..#####.........................BB
###...z................^^........g................h.......##
############################################################
############################################################
]],
  key = {
    ["1"] = "sign:sign_link",
    ["z"] = "checkpoint",
    ["g"] = "gnat",
    ["h"] = "hopper",
  },
  links = {
    A = { "stair_junction", "B" },
    B = { "moss_2", "A" },
    E = { "moss_secret", "A" },
  },
}
