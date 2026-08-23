-- THE UPPER STAIR. The half of the service column that goes up.
--
-- The Deep Stairs run from the Junction down through every zone the
-- city buried. This is the other direction: one shaft from the Junction
-- to the Skyroot arena at the top, and the way home from the Aerie
-- Sentinel.
--
-- It is a THERMAL COLUMN the whole way. Coming DOWN needs nothing --
-- you fall, and the landings catch you -- which is what makes it a
-- shortcut the moment the Sentinel is dead. Going UP needs the Drift
-- Vanes, and by the time you have them you have already been to the top
-- the long way. The shaft is the reward for that trip, not the route.
return {
  zone = "camp", music = "camp",
  arena = "deepstair",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 448, col = "umber", a = 0.34, a2 = 0.1, py = 0.06 },
    { kind = "column", x = -12, y = 80, w = 17, h = 367, col = "brown", a = 0.34, py = 0.22, step = 37, acc = "ember" },
    { kind = "column", x = 83, y = 80, w = 17, h = 367, col = "brown", a = 0.34, py = 0.22, step = 46, acc = "ember" },
    { kind = "column", x = 221, y = 80, w = 10, h = 367, col = "brown", a = 0.34, py = 0.22, step = 49, acc = "ember" },
    { kind = "column", x = 326, y = 80, w = 18, h = 367, col = "brown", a = 0.34, py = 0.22, step = 35, acc = "ember" },
    { kind = "column", x = 405, y = 80, w = 15, h = 367, col = "brown", a = 0.34, py = 0.22, step = 37, acc = "ember" },
    { kind = "rail", x = -12, y = 98, w = 504, h = 4, col = "brown", a = 0.34, py = 0.24 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 90, y = 98, w = 1, h = 7, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 88, y = 105, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 240, y = 98, w = 1, h = 9, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 238, y = 107, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 390, y = 98, w = 1, h = 10, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 388, y = 108, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "rect", x = 299, y = 328, w = 16, h = 4, col = "brown", a = 0.42 },
    { kind = "rect", x = 278, y = 353, w = 12, h = 4, col = "brown", a = 0.42 },
    { kind = "rect", x = 241, y = 238, w = 14, h = 4, col = "brown", a = 0.47 },
    { kind = "rect", x = 34, y = 307, w = 9, h = 6, col = "brown", a = 0.37 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 18, h = 448, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
    { kind = "band", x = 462, y = 0, w = 18, h = 448, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 90, y = 108, col = { 1.00, 0.74, 0.42 }, r = 59, flicker = 2.67 },
    { x = 240, y = 110, col = { 1.00, 0.74, 0.42 }, r = 59, flicker = 4.28 },
    { x = 390, y = 111, col = { 1.00, 0.74, 0.42 }, r = 57, flicker = 4.74 },
    { x = 240, y = 385, col = { 1.00, 0.60, 0.28 }, r = 110, flicker = 4.54 },
  },
  mapPos = { x = 7, y = 0, w = 1, h = 2 },
  map = [[
#############AAA##############
#############AAA##############
##..........................##
##..........................##
##..........................##
##...=======................##
##..........................##
##..........................##
##................========..##
##..........................##
##..........................##
##.======...................##
##..........................##
##..........................##
##...............=======....##
##..........................##
##..........................##
##..=======.................##
##..........................##
##..........................##
##................=======...##
##..........................##
##..........................##
##..======..................##
##..........................##
##....n.......U.............##
#############BBB##############
#############BBB##############
]],
  key = {
    ["U"] = "updraft:24",
    ["n"] = "anchor",
  },
  links = {
    A = { "sky_boss", "B", req = "boss_aeriesentinel" },
    B = { "stair_junction", "D" },
  },
}
