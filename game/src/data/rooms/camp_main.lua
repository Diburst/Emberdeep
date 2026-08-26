-- Ember Camp: the hub. Lantern light, NPCs, save statue.
return {
  zone = "camp", music = "camp",
  arena = "embercamp",
  -- BEHIND the rock: stacked wrecks, gantries, haze
  backdrop = {
    { kind = "band", x = 0, y = 0, w = 1280, h = 272, col = "umber", a = 0.34, a2 = 0.1, py = 0.06 },
    { kind = "column", x = -12, y = 48, w = 15, h = 223, col = "brown", a = 0.34, py = 0.22, step = 50, acc = "ember" },
    { kind = "column", x = 67, y = 48, w = 11, h = 223, col = "brown", a = 0.34, py = 0.22, step = 34, acc = "ember" },
    { kind = "column", x = 150, y = 48, w = 14, h = 223, col = "brown", a = 0.34, py = 0.22, step = 37, acc = "ember" },
    { kind = "column", x = 280, y = 48, w = 10, h = 223, col = "brown", a = 0.34, py = 0.22, step = 40, acc = "ember" },
    { kind = "column", x = 403, y = 48, w = 13, h = 223, col = "brown", a = 0.34, py = 0.22, step = 32, acc = "ember" },
    { kind = "column", x = 485, y = 48, w = 12, h = 223, col = "brown", a = 0.34, py = 0.22, step = 49, acc = "ember" },
    { kind = "column", x = 574, y = 48, w = 10, h = 223, col = "brown", a = 0.34, py = 0.22, step = 31, acc = "ember" },
    { kind = "column", x = 709, y = 48, w = 12, h = 223, col = "brown", a = 0.34, py = 0.22, step = 30, acc = "ember" },
    { kind = "column", x = 845, y = 48, w = 15, h = 223, col = "brown", a = 0.34, py = 0.22, step = 48, acc = "ember" },
    { kind = "column", x = 944, y = 48, w = 11, h = 223, col = "brown", a = 0.34, py = 0.22, step = 40, acc = "ember" },
    { kind = "column", x = 1064, y = 48, w = 18, h = 223, col = "brown", a = 0.34, py = 0.22, step = 49, acc = "ember" },
    { kind = "column", x = 1146, y = 48, w = 18, h = 223, col = "brown", a = 0.34, py = 0.22, step = 44, acc = "ember" },
    { kind = "column", x = 1240, y = 48, w = 13, h = 223, col = "brown", a = 0.34, py = 0.22, step = 44, acc = "ember" },
    { kind = "rail", x = -12, y = 59, w = 1304, h = 4, col = "brown", a = 0.34, py = 0.24 },
  },
  -- welded to the world: rust runs and lamps
  scenery = {
    { kind = "hang", x = 93, y = 59, w = 1, h = 16, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 91, y = 75, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 249, y = 59, w = 1, h = 8, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 247, y = 67, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 405, y = 59, w = 1, h = 7, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 403, y = 66, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 561, y = 59, w = 1, h = 10, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 559, y = 69, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 718, y = 59, w = 1, h = 12, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 716, y = 71, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 874, y = 59, w = 1, h = 15, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 872, y = 74, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 1030, y = 59, w = 1, h = 6, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 1028, y = 65, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "hang", x = 1186, y = 59, w = 1, h = 8, col = "brown", a = 0.7, lw = 1, sway = 2, rate = 0.3, bob = true },
    { kind = "rect", x = 1184, y = 67, w = 5, h = 6, col = "ember", a = 0.95 },
    { kind = "rect", x = 402, y = 150, w = 13, h = 4, col = "brown", a = 0.39 },
    { kind = "rect", x = 1153, y = 224, w = 20, h = 3, col = "brown", a = 0.39 },
    { kind = "rect", x = 1033, y = 196, w = 10, h = 5, col = "brown", a = 0.34 },
    { kind = "rect", x = 927, y = 168, w = 17, h = 5, col = "brown", a = 0.54 },
    { kind = "rect", x = 317, y = 122, w = 10, h = 3, col = "brown", a = 0.44 },
    { kind = "rect", x = 63, y = 189, w = 9, h = 5, col = "brown", a = 0.36 },
    { kind = "rect", x = 504, y = 183, w = 10, h = 5, col = "brown", a = 0.43 },
    { kind = "rect", x = 111, y = 116, w = 16, h = 3, col = "brown", a = 0.38 },
    { kind = "rect", x = 238, y = 192, w = 9, h = 4, col = "brown", a = 0.38 },
    { kind = "rect", x = 528, y = 200, w = 14, h = 4, col = "brown", a = 0.37 },
  },
  -- NEARER than the world -- it overtakes you
  foreground = {
    { kind = "band", x = 0, y = 0, w = 18, h = 272, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
    { kind = "band", x = 1262, y = 0, w = 18, h = 272, col = "black", a = 0.34, a2 = 0.34, py = -0.05 },
  },
  -- additive; the lamps and one welding arc
  lights = {
    { x = 93, y = 78, col = { 1.00, 0.74, 0.42 }, r = 58, flicker = 4 },
    { x = 249, y = 70, col = { 1.00, 0.74, 0.42 }, r = 75, flicker = 3.07 },
    { x = 405, y = 69, col = { 1.00, 0.74, 0.42 }, r = 69, flicker = 4.71 },
    { x = 561, y = 72, col = { 1.00, 0.74, 0.42 }, r = 77, flicker = 3.23 },
    { x = 718, y = 74, col = { 1.00, 0.74, 0.42 }, r = 64, flicker = 4.09 },
    { x = 874, y = 77, col = { 1.00, 0.74, 0.42 }, r = 73, flicker = 3.04 },
    { x = 1030, y = 68, col = { 1.00, 0.74, 0.42 }, r = 77, flicker = 2.98 },
    { x = 1186, y = 70, col = { 1.00, 0.74, 0.42 }, r = 61, flicker = 3.95 },
    { x = 640, y = 233, col = { 1.00, 0.60, 0.28 }, r = 107, flicker = 4.73 },
  },
  mapPos = { x = 2, y = 2, w = 4, h = 1 },
  gates = {},
  onEnter = function(World)
    local f = G.run.flags
    if f.corekey1 and f.corekey2 and f.corekey3 and not f.coredoor then
      f.coredoor = true
      G.game:announce("The great hatch to the Core rumbles open below the camp!", 4)
      if G.Audio then G.Audio.sfx("quake") end
    end
  end,
  map = [[
################################################################################
################################################################################
###............................................................................#
##.............................................................................#
##.............................................................................#
##....................######...................................................#
##............................................====....===......................#
##..............................3.....................................######..&#
##.....................====..=====........................=====..............&&#
##..........................................................................&&&#
....DD..........E................................................##........&&&&B
....DD1......dM.E........bN.2.OtPoQp.Y..eKRqSu..Vf...iU...5..4...##........&&&&B
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
]],
  key = {
    ["Y"] = "emberlantern",
    ["K"] = "frozenkeeper:elder",
    ["M"] = "frozenkeeper:sol",
    ["N"] = "frozenkeeper:brassa",
    ["U"] = "frozenkeeper:vill2",
    ["1"] = "sign:sign_camp_west",
    ["2"] = "sign:sign_camp_east",
    ["3"] = "capsule:cap_camp",
    ["4"] = "sign:sign_core",
    ["5"] = "checkpoint",
    ["e"] = "npc:elder:until:reckoning:until:camp_frozen",
    ["d"] = "npc:sol:until:camp_frozen",
    ["b"] = "npc:brassa:until:reckoning:until:camp_frozen",
    ["i"] = "npc:vill2:until:camp_frozen",
    ["f"] = "npc:ferro:need:ferro_rescued:until:reckoning:until:camp_frozen",
    -- THE WITNESSES. Everyone who lives in the side rooms comes here the
    -- moment the Ember comes loose, and stands in the dark watching it
    -- until the camp finally freezes. Their home-room copies switch off
    -- on the same flag, so nobody is ever in two places.
    ["t"] = "npc:tikka:need:camp_witness:until:camp_frozen",
    ["o"] = "npc:root:need:camp_witness:until:camp_frozen",
    ["p"] = "npc:inks:need:camp_witness:until:camp_frozen",
    ["q"] = "npc:vill:need:camp_witness:until:camp_frozen",
    ["u"] = "npc:jun:need:camp_witness:until:camp_frozen",
    -- ...and what is left of them afterwards. Every witness gets a body:
    -- without these five the visitors simply blinked out when the camp
    -- froze, which reads as a despawn bug rather than as an ending.
    ["O"] = "frozenkeeper:tikka",
    ["P"] = "frozenkeeper:root",
    ["Q"] = "frozenkeeper:inks",
    ["R"] = "frozenkeeper:vill",
    ["S"] = "frozenkeeper:jun",
    -- FROZEN_LINES has carried a line for Ferro since it was written and
    -- no room ever placed him. It is the best line in the set.
    ["V"] = "frozenkeeper:ferro",
  },
  links = {
    E = { "camp_hut", "A" },
    D = { "camp_awake", "B" },
    B = { "stair_junction", "A" },
  },
}
