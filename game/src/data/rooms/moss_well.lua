-- The deep mossy well. Tikka dropped her music box down here -- but the
-- well drains into the Undergrove (door D, to ug_1), and the water took
-- it with it. What is at the bottom now is the carving that says so.
return {
  zone = "mosswood", music = "mosswood",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 512, col = "pine", a = 0.3, a2 = 0.07, py = 0.05 },
    { kind = "column", x = -16, y = 0, w = 34, h = 512, col = "black", a = 0.38, py = 0.23, step = 46, acc = "moss" },
    { kind = "column", x = 78, y = 0, w = 28, h = 512, col = "black", a = 0.24, py = 0.23, step = 33, acc = "moss" },
    { kind = "column", x = 157, y = 0, w = 21, h = 512, col = "black", a = 0.35, py = 0.15, step = 40, acc = "moss" },
    { kind = "column", x = 218, y = 0, w = 29, h = 512, col = "black", a = 0.24, py = 0.28, step = 41, acc = "moss" },
    { kind = "column", x = 293, y = 0, w = 20, h = 512, col = "black", a = 0.36, py = 0.26, step = 38, acc = "moss" },
    { kind = "column", x = 359, y = 0, w = 38, h = 512, col = "black", a = 0.27, py = 0.26, step = 42, acc = "moss" },
    { kind = "column", x = 449, y = 0, w = 24, h = 512, col = "black", a = 0.32, py = 0.27, step = 35, acc = "moss" },
    { kind = "shaft", x = 114, y = 0, w = 62, h = 435, col = "lime", a = 0.15, py = 0.18, skew = 7, ph = 4.92 },
    { kind = "shaft", x = 60, y = 0, w = 40, h = 435, col = "lime", a = 0.15, py = 0.18, skew = -11, ph = 3.66 },
    { kind = "shaft", x = 158, y = 0, w = 58, h = 435, col = "lime", a = 0.15, py = 0.18, skew = -3, ph = 1.61 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 85, y = 201, w = 2, h = 26, col = "moss", a = 0.5, lw = 2, sway = 4, rate = 0.48, bob = true },
    { kind = "hang", x = 322, y = 65, w = 2, h = 39, col = "moss", a = 0.54, lw = 2, sway = 5, rate = 0.3, bob = true },
    { kind = "hang", x = 444, y = 185, w = 2, h = 27, col = "moss", a = 0.71, lw = 2, sway = 3, rate = 0.35, bob = true },
    { kind = "hang", x = 457, y = 211, w = 2, h = 11, col = "moss", a = 0.62, lw = 2, sway = 6, rate = 0.48, bob = true },
    { kind = "hang", x = 223, y = 214, w = 2, h = 12, col = "moss", a = 0.48, lw = 2, sway = 3, rate = 0.3, bob = true },
    { kind = "hang", x = 323, y = 2, w = 2, h = 29, col = "moss", a = 0.53, lw = 2, sway = 2, rate = 0.25, bob = true },
    { kind = "hang", x = 407, y = 115, w = 2, h = 22, col = "moss", a = 0.47, lw = 2, sway = 5, rate = 0.42, bob = true },
    { kind = "hang", x = 133, y = 147, w = 2, h = 38, col = "moss", a = 0.6, lw = 2, sway = 6, rate = 0.49, bob = true },
    { kind = "hang", x = 425, y = 90, w = 2, h = 28, col = "moss", a = 0.42, lw = 2, sway = 3, rate = 0.35, bob = true },
    { kind = "hang", x = 318, y = 225, w = 2, h = 14, col = "moss", a = 0.54, lw = 2, sway = 5, rate = 0.21, bob = true },
    { kind = "rect", x = 261, y = 165, w = 9, h = 2, col = "fern", a = 0.36 },
    { kind = "rect", x = 323, y = 432, w = 16, h = 5, col = "lime", a = 0.31 },
    { kind = "rect", x = 260, y = 109, w = 14, h = 3, col = "lime", a = 0.38 },
    { kind = "rect", x = 389, y = 179, w = 15, h = 5, col = "moss", a = 0.42 },
    { kind = "rect", x = 43, y = 198, w = 9, h = 4, col = "moss", a = 0.44 },
    { kind = "rect", x = 328, y = 202, w = 9, h = 5, col = "lime", a = 0.36 },
    { kind = "rect", x = 53, y = 408, w = 13, h = 2, col = "fern", a = 0.34 },
    { kind = "rect", x = 318, y = 192, w = 14, h = 4, col = "moss", a = 0.23 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "girder", x = -24, y = 25, w = 528, h = 13, col = "black", a = 0.82, py = -0.12, step = 44 },
    { kind = "hang", x = 289, y = 38, w = 2, h = 24, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 5, rate = 0.32, bob = true },
    { kind = "hang", x = 111, y = 38, w = 2, h = 39, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 7, rate = 0.64, bob = true },
    { kind = "hang", x = 34, y = 38, w = 2, h = 60, col = "black", a = 0.78, py = -0.12, lw = 3, sway = 6, rate = 0.31, bob = true },
    { kind = "band", x = 0, y = 0, w = 22, h = 512, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
    { kind = "band", x = 458, y = 0, w = 22, h = 512, col = "black", a = 0.4, a2 = 0.4, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 240, y = 81, col = { 0.80, 1.00, 0.66 }, r = 93, flicker = 2.08 },
  },
  mapPos = { x = 0, y = 1, w = 1, h = 2 },
  map = [[
##############################
########.AA.................##
########.AA.................##
##.......AA.................##
##..########==..............##
##..........................##
##..........................##
##..........==########......##
##..........................##
##......g...................##
##..########==..............##
##..........................##
##..........................##
##..........==########......##
##..........................##
##................g.........##
##..########==..............##
##..........................##
##..........................##
##..........==########......##
####...5..................####
#########.................####
####~~~~~##~~~~~~~~~~~~~~~####
####~~~~~~~~~~~~~~~~~~~~~~####
####~~~~~~~~~~~~~~~~~~~~~~####
####~~~~~~~~~~~~~~~~~~~~~~####
####~~~~~~~~~~~~~~~~~~~~~~####
####~~~~~~~~~~~~~~~~~~~~~~####
##############~~~#############
##############~~~#############
##############DDD#############
##############DDD#############
]],
  key = {
    ["5"] = "sign:sign_wellbottom",
    ["g"] = "gnat",
  },
  links = {
    A = { "moss_2", "D" },
    D = { "ug_1", "A" },
  },
}
