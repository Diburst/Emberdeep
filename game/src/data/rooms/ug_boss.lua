-- The choir loft. Three throats, one hunger, singing in the dark.
return {
  zone = "undergrove", music = "undergrove",
  -- ------------------------------------------------------------------
  -- THE CHOIR -- the deep learned to sing what the city forgot.
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
    { kind = "rect", x = 91, y = 148, w = 18, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 99, y = 141, w = 3, h = 9, col = "violet", a = 0.6 },
    { kind = "rect", x = 372, y = 198, w = 16, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 379, y = 192, w = 3, h = 8, col = "violet", a = 0.6 },
    { kind = "rect", x = 233, y = 418, w = 14, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 239, y = 413, w = 3, h = 7, col = "violet", a = 0.6 },
    { kind = "rect", x = 145, y = 468, w = 10, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 149, y = 465, w = 3, h = 5, col = "violet", a = 0.6 },
    { kind = "rect", x = 414, y = 428, w = 12, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 419, y = 424, w = 3, h = 6, col = "violet", a = 0.6 },
    { kind = "band", x = 0, y = 0, w = 480, h = 528, col = "black", a = 0.1, a2 = 0.34 },
  },
  foreground = {
    -- root curtains: you walk behind these
    { kind = "hang", x = 70, y = 0, w = 3, h = 110, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 200, y = 0, w = 3, h = 80, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 330, y = 0, w = 3, h = 130, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 440, y = 0, w = 3, h = 95, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "band", x = 0, y = 0, w = 30, h = 528, col = "black", a = 0.8, a2 = 0.8, py = -0.07 },
    { kind = "band", x = 450, y = 0, w = 30, h = 528, col = "black", a = 0.8, a2 = 0.8, py = -0.07 },
  },
  lights = {
    { x = 100, y = 150, r = 53, col = { 0.50, 0.90, 0.95 }, flicker = 2.0 },
    { x = 380, y = 200, r = 50, col = { 0.72, 0.50, 1.00 }, flicker = 2.4 },
    { x = 240, y = 420, r = 47, col = { 0.72, 0.50, 1.00 }, flicker = 2.8 },
    { x = 150, y = 470, r = 41, col = { 0.50, 0.90, 0.95 }, flicker = 3.2 },
    { x = 420, y = 430, r = 44, col = { 0.72, 0.50, 1.00 }, flicker = 3.6 },
  },
  arena = "mycelchoir",
  mapPos = { x = 10, y = 1, w = 1, h = 2 },
  dark = 0.9,
  map = [[
##############################
##############################
##..........................##
##..........................##
##..........................##
##..........................##
##..........................##
##..........................##
##..........................##
##..........................##
##..........................##
##...................======.##
##..........................##
##..........................##
##............======........##
##..........................##
##..........................##
##...======.................##
##..........................##
##..........................##
##............======........##
##..........................##
##..........................##
##...................======.##
##..........................##
##..........................##
AA............======........##
AA.......t..................##
##========..................##
##..........................##
##^^^^^^^^^^^^^^^^^^^^^^^^^^##
##############################
##############################
]],
  key = {
    ["t"] = "boss:mycelchoir",
  },
  links = {
    A = { "ug_7", "B" },
  },
}
