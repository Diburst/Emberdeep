-- The Undergrove: drowned throat of the old well. Dark begins here.
return {
  zone = "undergrove", music = "undergrove",
  -- ------------------------------------------------------------------
  -- THE UNDERGROVE -- the dark has structure if you bring a light.
  --
  -- Three layers, and the only difference between them is where in the
  -- draw order they sit: backdrop is BEHIND the rock, scenery is over
  -- the rock but behind the bots, foreground is in front of everything.
  -- py < 0 is nearer than the world; py > 0 is further away.
  -- ------------------------------------------------------------------
  backdrop = {
    -- Almost nothing back here, and that is the point: in a dark room
    -- the backdrop is whatever the fungus reaches, and no further.
    { kind = "stack", x = -30, y = 290, w = 556, h = 237, col = "black", a = 0.7, py = 0.3, step = 40, seed = 21 },
  },
  scenery = {
    -- Bioluminescent clusters. The ART is here and the LIGHT is in
    -- room.lights at the same coordinates -- a thing you can see and
    -- a thing that lights the floor are not the same thing.
    { kind = "rect", x = 83, y = 298, w = 14, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 89, y = 293, w = 3, h = 7, col = "violet", a = 0.6 },
    { kind = "rect", x = 354, y = 178, w = 12, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 359, y = 174, w = 3, h = 6, col = "violet", a = 0.6 },
    { kind = "rect", x = 212, y = 428, w = 16, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 219, y = 422, w = 3, h = 8, col = "violet", a = 0.6 },
    { kind = "rect", x = 425, y = 378, w = 10, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 429, y = 375, w = 3, h = 5, col = "violet", a = 0.6 },
    { kind = "rect", x = 135, y = 118, w = 10, h = 3, col = "orchid", a = 0.75 },
    { kind = "rect", x = 139, y = 115, w = 3, h = 5, col = "violet", a = 0.6 },
    { kind = "band", x = 0, y = 0, w = 496, h = 528, col = "black", a = 0.1, a2 = 0.34 },
  },
  foreground = {
    -- root curtains: you walk behind these
    { kind = "hang", x = 120, y = 0, w = 3, h = 120, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 300, y = 0, w = 3, h = 90, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 420, y = 0, w = 3, h = 140, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "hang", x = 60, y = 250, w = 3, h = 80, col = "black", a = 0.88, py = -0.13, lw = 3, sway = 6, rate = 0.35 },
    { kind = "band", x = 0, y = 0, w = 30, h = 528, col = "black", a = 0.8, a2 = 0.8, py = -0.07 },
    { kind = "band", x = 466, y = 0, w = 30, h = 528, col = "black", a = 0.8, a2 = 0.8, py = -0.07 },
  },
  lights = {
    { x = 90, y = 300, r = 47, col = { 0.50, 0.90, 0.95 }, flicker = 2.0 },
    { x = 360, y = 180, r = 44, col = { 0.72, 0.50, 1.00 }, flicker = 2.4 },
    { x = 220, y = 430, r = 50, col = { 0.72, 0.50, 1.00 }, flicker = 2.8 },
    { x = 430, y = 380, r = 41, col = { 0.50, 0.90, 0.95 }, flicker = 3.2 },
    { x = 140, y = 120, r = 41, col = { 0.72, 0.50, 1.00 }, flicker = 3.6 },
  },
  mapPos = { x = 0, y = 0, w = 1, h = 2 },
  dark = 0.5,
  map = [[
####AAA########################
####AAA########################
##~~~~~~~~#####################
##~~~~~~~~##................###
##~~~~~~~~##..........b.....BBB
##~~f~f~~~##.......1.=====..BBB
##~~~~~~~~##......===.......###
##~~~~f~~~##................###
##~~~~~~~~##..=====.........###
##~~f~~~~~##................###
##~~~~~~~~##................###
##~~~~~~~~##.........=====..###
##~~~~~~~~##................###
##~~~~~~~~##................###
##~~~f~~~~##..=====.........###
##~~~~~~f~##................###
##~~~f~~~~##................###
##~~~~~~~~##.........=====..###
##~~~~~~~~##................###
##~~~~~~~~##................###
##~~~~~~~~##..=====.........###
##~~~~~~~~~~~~~~~~~~~~~~~~~~###
##~~~~~~~~~~~~~~~~~~~~~~~~~~###
##~~~~~~~~~~~~~~~~~~~~~~~~~~###
##~~~~~~~~##~~~~~~~~~~~~~~~~###
##~~~~~~~~##~~~~~~~~~~~~~~~~###
##~~~~~~~~##~~~~~~~~~~~~~~~~###
############~~~~~~~~~~~~~~~~###
############~~~~~~~~~~~~~~~~###
###############################
###############################
###############################
###############################
]],
  key = {
    ["1"] = "sign:sign_undergrove",
    ["f"] = "finfish",
    ["b"] = "sporebulb",
  },
  links = {
    A = { "moss_well", "D" },
    B = { "ug_2", "A" },
  },
}
