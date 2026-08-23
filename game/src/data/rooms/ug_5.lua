-- The spore descent. Every ledge glows faintly with sleeping bulbs.
return {
  zone = "undergrove", music = "undergrove",
  -- ------------------------------------------------------------------
  -- DEEPER IN -- the fungus is the only thing still working.
  --
  -- Three layers, and the only difference between them is where in the
  -- draw order they sit: backdrop is BEHIND the rock, scenery is over
  -- the rock but behind the bots, foreground is in front of everything.
  -- py < 0 is nearer than the world; py > 0 is further away.
  -- ------------------------------------------------------------------
  backdrop = {
    -- Almost nothing back here, and that is the point: in a dark room
    -- the backdrop is whatever the fungus reaches, and no further.
    { kind = "stack", x = -30, y = 290, w = 540, h = 237, col = "black", a = 0.7, py = 0.3, step = 40, seed = 21 },
  },
  scenery = {
    -- Bioluminescent clusters. The ART is here and the LIGHT is in
    -- room.lights at the same coordinates -- a thing you can see and
    -- a thing that lights the floor are not the same thing.
    { kind = "rect", x = 112, y = 218, w = 16, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 119, y = 212, w = 3, h = 8, col = "violet", a = 0.6 },
    { kind = "rect", x = 333, y = 338, w = 14, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 339, y = 333, w = 3, h = 7, col = "violet", a = 0.6 },
    { kind = "rect", x = 235, y = 108, w = 10, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 239, y = 105, w = 3, h = 5, col = "violet", a = 0.6 },
    { kind = "rect", x = 394, y = 468, w = 12, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 399, y = 464, w = 3, h = 6, col = "violet", a = 0.6 },
    { kind = "band", x = 0, y = 0, w = 480, h = 528, col = "black", a = 0.1, a2 = 0.34 },
  },
  foreground = {
    -- root curtains: you walk behind these
    { kind = "hang", x = 80, y = 0, w = 3, h = 140, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 260, y = 0, w = 3, h = 100, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 400, y = 0, w = 3, h = 120, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "band", x = 0, y = 0, w = 30, h = 528, col = "black", a = 0.8, a2 = 0.8, py = -0.07 },
    { kind = "band", x = 450, y = 0, w = 30, h = 528, col = "black", a = 0.8, a2 = 0.8, py = -0.07 },
  },
  lights = {
    { x = 120, y = 220, r = 50, col = { 0.50, 0.90, 0.95 }, flicker = 2.0 },
    { x = 340, y = 340, r = 47, col = { 0.72, 0.50, 1.00 }, flicker = 2.4 },
    { x = 240, y = 110, r = 41, col = { 0.72, 0.50, 1.00 }, flicker = 2.8 },
    { x = 400, y = 470, r = 44, col = { 0.50, 0.90, 0.95 }, flicker = 3.2 },
  },
  mapPos = { x = 6, y = 0, w = 1, h = 2 },
  dark = 0.85,
  map = [[
##############################
##############################
##..........................##
##..........................##
##..........................##
##..........................##
##......f...................##
##..........................##
##..........................##
##..........................##
AA................f.........##
AA..........................##
##..........................##
###########.................##
###########...b.............##
##..........=====...........##
##..........................##
##...................b......##
##.................=====....##
##..........................##
##............b.............##
##..........=====...........##
##..........................##
##...................b......##
##.................=====....##
##..........................##
##..........................##
##..........=====...........##
##.......................m..##
##..........................##
######################...#####
######################BBB#####
######################BBB#####
]],
  key = {
    ["b"] = "sporebulb",
    ["f"] = "sporefly",
    ["m"] = "myceling",
  },
  links = {
    A = { "ug_4", "B" },
    B = { "ug_6", "A" },
  },
}
