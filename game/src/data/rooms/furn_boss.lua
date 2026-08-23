-- THE CRUCIBLE's foundry floor.
--
-- floodRow = 17 is the BASIN: row 17 is open only between cols 10 and 48,
-- and solid either side, so the middle of the floor sits a tile lower
-- than its two ends. A pour opens two fronts at the spout that crawl one
-- tile every half second until they hit that higher ground -- which is
-- what makes the raised ends worth running to. Row 18 under the basin is
-- the GRATE the pool drains back down through.
--
-- The two pots (p, q) hang directly over the two big shelves on purpose:
-- players can only aim straight up, so "climb to the safe place and
-- shoot the thing above you" is one motion.
--
-- The three tiles at row 14 cols 29-31 are the centre perch -- the only
-- refuge under the boss, level with the two existing stubs so a plain
-- 3-row jump reaches it with no modules, and small enough that two bots
-- and a slagling tide cannot all share it. It is also the only refuge you
-- can shoot the boss from, so a flood is pressure rather than downtime.
return {
  zone = "furnace", music = "furnace",
  -- ------------------------------------------------------------------
  -- THE CRUCIBLE -- ten thousand perfect parts, no orders.
  --
  -- Three layers, and the only difference between them is where in the
  -- draw order they sit: backdrop is BEHIND the rock, scenery is over
  -- the rock but behind the bots, foreground is in front of everything.
  -- py < 0 is nearer than the world; py > 0 is further away.
  -- ------------------------------------------------------------------
  backdrop = {
    -- Furnace mouths still burning behind the wall, on a slow cycle.
    -- The Crucible made ten thousand perfect parts and the line never
    -- got the message; the light back there is the line still running.
    { kind = "rect", x = 120, y = 90, w = 150, h = 90, col = "maroon", a = 0.85, py = 0.28 },
    { kind = "band", x = 123, y = 93, w = 144, h = 84, col = "magma", a = 0.5, a2 = 0.12, py = 0.28 },
    { kind = "rect", x = 640, y = 110, w = 140, h = 80, col = "maroon", a = 0.85, py = 0.28 },
    { kind = "band", x = 643, y = 113, w = 134, h = 74, col = "magma", a = 0.5, a2 = 0.12, py = 0.28 },
    -- gantry behind everything
    { kind = "girder", x = -20, y = 60, w = 1000, h = 15, col = "black", a = 0.55, py = 0.34, step = 32 },
    { kind = "girder", x = -20, y = 210, w = 1000, h = 15, col = "black", a = 0.55, py = 0.34, step = 32 },
    { kind = "column", x = 211, y = 20, w = 13, h = 312, col = "black", a = 0.5, py = 0.4, acc = "rust" },
    { kind = "column", x = 710, y = 20, w = 13, h = 312, col = "black", a = 0.5, py = 0.4, acc = "rust" },
  },
  scenery = {
    -- heat haze rising off the floor
    { kind = "band", x = 0, y = 202, w = 960, h = 150, col = "magma", a = 0, a2 = 0.13 },
  },
  foreground = {
    -- chains and a near gantry: the works, passing in front
    { kind = "girder", x = -20, y = 26, w = 1000, h = 18, col = "black", a = 0.94, py = -0.14, step = 36 },
    { kind = "hang", x = 300, y = 44, w = 2, h = 80, col = "black", a = 0.9, py = -0.14, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 600, y = 44, w = 2, h = 66, col = "black", a = 0.9, py = -0.14, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 830, y = 44, w = 2, h = 52, col = "black", a = 0.9, py = -0.14, lw = 2, sway = 4, rate = 0.45, bob = true },
  },
  lights = {
    { x = 160, y = 300, r = 70, col = { 1.00, 0.55, 0.22 }, flicker = 5.5 },
    { x = 760, y = 300, r = 66, col = { 1.00, 0.55, 0.22 }, flicker = 6.8 },
    { x = 460, y = 140, r = 50, col = { 1.00, 0.55, 0.22 }, flicker = 7.9 },
  },
  arena = "crucible",
  mapPos = { x = 14, y = 3, w = 3, h = 1 },
  floodRow = 17,
  map = [[
######AAA###################################################
######AAA###################################################
##........................................................##
##.......p...................................q............##
##........................................................##
##..=====.................................................##
##........................................................##
##........................................................##
##..=====.................................................##
##........................................................##
##........................................................##
##..=====.................................................##
##............t...........................................##
##....==========............................==========....##
##........................................................##
##...............===.........===.........===.........B....##
##....1..............................................B....##
##########.......................................###########
############################################################
############################################################
############################################################
############################################################
]],
  key = {
    ["t"] = "boss:crucible",
    ["1"] = "sign:sign_link2",
    ["p"] = "cruciblepot:left",
    ["q"] = "cruciblepot:right",
  },
  links = {
    B = { "deep_stair_1", "E", req = "boss_crucible" },
    A = { "furn_6", "B" },
  },
}
