-- THE JUNCTION. The middle landing of the city's service stairwell, and
-- from here on the hub of the whole map.
--
-- The Deep Stairs used to be entered from moss_5, four rooms into
-- Mosswood, which meant the vertical column that reaches almost every
-- zone was hidden behind the first zone. It is one room from Embercamp
-- now, and the road to Mosswood runs straight through it -- so the
-- stairwell is a place you know about long before you can use most of
-- it.
--
-- Four ways out:
--   A  west   Embercamp
--   B  east   Mosswood
--   C  down   the Deep Stairs, and through them the rest of the city
--   D  up     the Upper Stair, and the Skyroot arena at the top of it
--
-- D is a THERMAL COLUMN and nothing else. Without the Drift Vanes the
-- ceiling is simply a ceiling; with them the shaft above opens up, which
-- is why the way home from the Aerie Sentinel lands here.
return {
  zone = "camp", music = "camp",
  arena = "deepstair",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 640, h = 368, col = "umber", a = 0.34, a2 = 0.1, py = 0.06 },
    { kind = "column", x = -12, y = 66, w = 18, h = 301, col = "brown", a = 0.34, py = 0.22, step = 39, acc = "ember" },
    { kind = "column", x = 116, y = 66, w = 17, h = 301, col = "brown", a = 0.34, py = 0.22, step = 45, acc = "ember" },
    { kind = "column", x = 205, y = 66, w = 11, h = 301, col = "brown", a = 0.34, py = 0.22, step = 38, acc = "ember" },
    { kind = "column", x = 288, y = 66, w = 13, h = 301, col = "brown", a = 0.34, py = 0.22, step = 33, acc = "ember" },
    { kind = "column", x = 376, y = 66, w = 16, h = 301, col = "brown", a = 0.34, py = 0.22, step = 49, acc = "ember" },
    { kind = "column", x = 489, y = 66, w = 18, h = 301, col = "brown", a = 0.34, py = 0.22, step = 41, acc = "ember" },
    { kind = "column", x = 632, y = 66, w = 10, h = 301, col = "brown", a = 0.34, py = 0.22, step = 48, acc = "ember" },
    { kind = "rail", x = -12, y = 80, w = 664, h = 4, col = "brown", a = 0.34, py = 0.24 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 91, y = 80, w = 1, h = 8, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 89, y = 88, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 243, y = 80, w = 1, h = 12, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 241, y = 92, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 396, y = 80, w = 1, h = 9, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 394, y = 89, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 548, y = 80, w = 1, h = 12, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 546, y = 92, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "rect", x = 542, y = 295, w = 8, h = 3, col = "brown", a = 0.44 },
    { kind = "rect", x = 252, y = 225, w = 14, h = 3, col = "brown", a = 0.4 },
    { kind = "rect", x = 415, y = 133, w = 20, h = 6, col = "brown", a = 0.52 },
    { kind = "rect", x = 160, y = 175, w = 13, h = 6, col = "brown", a = 0.34 },
    { kind = "rect", x = 176, y = 266, w = 14, h = 3, col = "brown", a = 0.46 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 18, h = 368, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
    { kind = "band", x = 622, y = 0, w = 18, h = 368, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 91, y = 91, col = { 1.00, 0.74, 0.42 }, r = 80, flicker = 4.33 },
    { x = 243, y = 95, col = { 1.00, 0.74, 0.42 }, r = 66, flicker = 3.22 },
    { x = 396, y = 92, col = { 1.00, 0.74, 0.42 }, r = 68, flicker = 4.44 },
    { x = 548, y = 95, col = { 1.00, 0.74, 0.42 }, r = 58, flicker = 2.78 },
    { x = 320, y = 316, col = { 1.00, 0.60, 0.28 }, r = 99, flicker = 5.03 },
  },
  mapPos = { x = 6, y = 2, w = 2, h = 1 },
  map = [[
#####################DDD################
#####################DDD################
##....................................##
##....................................##
##..................=====.............##
##....................................##
##....................................##
##............=====...................##
##....................................##
###...................................##
####....................======........##
###...................................##
##....................................##
##............=====...................##
##....................................##
##....................................##
##......................======........##
A......................................B
A......1..............U..........z.....B
##########.........#####################
###########...C...######################
#############.C.########################
########################################
]],
  key = {
    ["U"] = "updraft:17",
    ["z"] = "checkpoint",
    ["1"] = "sign:sign_junction",
  },
  links = {
    A = { "camp_main", "B" },
    B = { "moss_1", "A" },
    -- SEALED UNTIL THE MAW IS DOWN. Without this the Junction hands the
    -- whole city over on the first walk out of camp: the reachability
    -- model goes camp -> Junction -> Deep Stairs -> furn_1 and kills the
    -- CRUCIBLE before it has picked up the Spark Jump. Moving the
    -- stairwell next to camp was the point; opening it there was not.
    -- One line, and the intended order is back.
    C = { "deep_stair_1", "A", req = "boss_bramblemaw" },
    D = { "upper_stair", "B" },
  },
}
