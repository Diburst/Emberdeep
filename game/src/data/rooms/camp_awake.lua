-- Jun's maintenance shop: where Vess and Lu boot up. Cluttered with
-- benches, tools and cable runs (see drawArenaBackdrop 'campshop').
-- Jun teaches the basics here in person -- there is no signage any more.
return {
  zone = "camp", music = "camp",
  arena = "campshop",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 640, h = 272, col = "umber", a = 0.34, a2 = 0.1, py = 0.06 },
    { kind = "column", x = -12, y = 48, w = 10, h = 223, col = "brown", a = 0.34, py = 0.22, step = 30, acc = "ember" },
    { kind = "column", x = 96, y = 48, w = 17, h = 223, col = "brown", a = 0.34, py = 0.22, step = 40, acc = "ember" },
    { kind = "column", x = 229, y = 48, w = 14, h = 223, col = "brown", a = 0.34, py = 0.22, step = 31, acc = "ember" },
    { kind = "column", x = 316, y = 48, w = 16, h = 223, col = "brown", a = 0.34, py = 0.22, step = 35, acc = "ember" },
    { kind = "column", x = 421, y = 48, w = 12, h = 223, col = "brown", a = 0.34, py = 0.22, step = 33, acc = "ember" },
    { kind = "column", x = 550, y = 48, w = 11, h = 223, col = "brown", a = 0.34, py = 0.22, step = 37, acc = "ember" },
    { kind = "rail", x = -12, y = 59, w = 664, h = 4, col = "brown", a = 0.34, py = 0.24 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 91, y = 59, w = 1, h = 11, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 89, y = 70, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 243, y = 59, w = 1, h = 14, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 241, y = 73, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 396, y = 59, w = 1, h = 8, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 394, y = 67, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 548, y = 59, w = 1, h = 8, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 546, y = 67, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "rect", x = 33, y = 113, w = 13, h = 4, col = "brown", a = 0.43 },
    { kind = "rect", x = 512, y = 143, w = 11, h = 6, col = "brown", a = 0.44 },
    { kind = "rect", x = 519, y = 102, w = 14, h = 5, col = "brown", a = 0.34 },
    { kind = "rect", x = 588, y = 128, w = 10, h = 6, col = "brown", a = 0.42 },
    { kind = "rect", x = 106, y = 181, w = 14, h = 3, col = "brown", a = 0.44 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 18, h = 272, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
    { kind = "band", x = 622, y = 0, w = 18, h = 272, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 91, y = 73, col = { 1.00, 0.74, 0.42 }, r = 65, flicker = 2.65 },
    { x = 243, y = 76, col = { 1.00, 0.74, 0.42 }, r = 83, flicker = 2.51 },
    { x = 396, y = 70, col = { 1.00, 0.74, 0.42 }, r = 81, flicker = 4.96 },
    { x = 548, y = 70, col = { 1.00, 0.74, 0.42 }, r = 63, flicker = 4.45 },
    { x = 320, y = 233, col = { 1.00, 0.60, 0.28 }, r = 94, flicker = 4.13 },
  },
  mapPos = { x = 4, y = 3, w = 2, h = 1 },
  map = [[
########################################
########################################
#####################................###
#########......####..................###
##....##.............................###
####...........................####...##
###.....................9...........####
###..................====.............##
##....................................##
###......======.......................##
###.....A.....................====....##
###.....A.........................BB..##
####........j..W....t...1...2.....BB.z##
########################################
####..................................##
##..................................####
########################################
]],
  hasTeleporter = true,
  key = {
    -- THE EMBERCAMP PAD, moved out of the old hub room and into the
    -- shop you wake up in. A room whose only job was holding a
    -- teleporter was a room you walked through, never to.
    ["t"] = "teleporter:camp",
    ["1"] = "sign:sign_camp_west",
    ["2"] = "chest:chest_camptele:scrap:6",
    ["9"] = "chest:ch_shelf:scrap:15",
    ["j"] = "npc:jun:until:camp_witness",
    ["W"] = "frozenkeeper:jun",
    ["z"] = "checkpoint",
  },
  links = {
    B = { "camp_main", "D" },
  },
}
