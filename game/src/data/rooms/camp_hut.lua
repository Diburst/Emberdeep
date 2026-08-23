-- The long hut: the biggest shelter in Ember Camp, and the only one you
-- can walk into. Bunks, a stove, drying lines. Most of the keepers live
-- their indoor life here, which is why the camp outside is not a crowd.
return {
  zone = "camp", music = "camp",
  arena = "camphut",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 480, h = 272, col = "umber", a = 0.34, a2 = 0.1, py = 0.06 },
    { kind = "column", x = -12, y = 48, w = 18, h = 223, col = "brown", a = 0.34, py = 0.22, step = 43, acc = "ember" },
    { kind = "column", x = 89, y = 48, w = 15, h = 223, col = "brown", a = 0.34, py = 0.22, step = 37, acc = "ember" },
    { kind = "column", x = 222, y = 48, w = 18, h = 223, col = "brown", a = 0.34, py = 0.22, step = 41, acc = "ember" },
    { kind = "column", x = 321, y = 48, w = 11, h = 223, col = "brown", a = 0.34, py = 0.22, step = 32, acc = "ember" },
    { kind = "column", x = 410, y = 48, w = 12, h = 223, col = "brown", a = 0.34, py = 0.22, step = 36, acc = "ember" },
    { kind = "rail", x = -12, y = 59, w = 504, h = 4, col = "brown", a = 0.34, py = 0.24 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 90, y = 59, w = 1, h = 8, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 88, y = 67, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 240, y = 59, w = 1, h = 16, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 238, y = 75, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 390, y = 59, w = 1, h = 7, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 388, y = 66, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "rect", x = 152, y = 199, w = 10, h = 3, col = "brown", a = 0.43 },
    { kind = "rect", x = 388, y = 152, w = 13, h = 3, col = "brown", a = 0.52 },
    { kind = "rect", x = 51, y = 161, w = 13, h = 6, col = "brown", a = 0.32 },
    { kind = "rect", x = 389, y = 112, w = 11, h = 6, col = "brown", a = 0.34 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 18, h = 272, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
    { kind = "band", x = 462, y = 0, w = 18, h = 272, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 90, y = 70, col = { 1.00, 0.74, 0.42 }, r = 78, flicker = 4.6 },
    { x = 240, y = 78, col = { 1.00, 0.74, 0.42 }, r = 62, flicker = 4.54 },
    { x = 390, y = 69, col = { 1.00, 0.74, 0.42 }, r = 66, flicker = 4.95 },
    { x = 240, y = 233, col = { 1.00, 0.60, 0.28 }, r = 80, flicker = 4.28 },
  },
  mapPos = { x = 3, y = 3, w = 1, h = 1 },
  map = [[
##############################
##############################
##############################
##############################
##..........................##
##..........................##
##..........................##
##.....====.........====....##
##..........................##
##..........................##
##.............AA...........##
##.w.O.t.P.r.Q.AA..x.R......##
##############################
##############################
##############################
##############################
##############################]],
  key = {
    ["w"] = "npc:tikka:until:camp_witness",
    ["O"] = "frozenkeeper:tikka",
    ["t"] = "npc:root:until:camp_witness",
    ["P"] = "frozenkeeper:root",
    ["r"] = "npc:inks:until:camp_witness",
    ["Q"] = "frozenkeeper:inks",
    ["x"] = "npc:vill:until:camp_witness",
    ["R"] = "frozenkeeper:vill",
  },
  links = {
    A = { "camp_main", "E" },
  },
}
