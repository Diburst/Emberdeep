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
    { kind = "rect", x = 88, y = 90, w = 150, h = 90, col = "maroon", a = 0.85, py = 0.28 },
    { kind = "band", x = 91, y = 93, w = 144, h = 84, col = "magma", a = 0.5, a2 = 0.12, py = 0.28 },
    { kind = "rect", x = 608, y = 110, w = 140, h = 80, col = "maroon", a = 0.85, py = 0.28 },
    { kind = "band", x = 611, y = 113, w = 134, h = 74, col = "magma", a = 0.5, a2 = 0.12, py = 0.28 },
    -- gantry behind everything
    { kind = "girder", x = -52, y = 60, w = 1000, h = 15, col = "black", a = 0.55, py = 0.34, step = 32 },
    { kind = "girder", x = -52, y = 210, w = 1000, h = 15, col = "black", a = 0.55, py = 0.34, step = 32 },
    { kind = "column", x = 179, y = 20, w = 13, h = 312, col = "black", a = 0.5, py = 0.4, acc = "rust" },
    { kind = "column", x = 678, y = 20, w = 13, h = 312, col = "black", a = 0.5, py = 0.4, acc = "rust" },
  },
  scenery = {
    -- heat haze rising off the floor
    { kind = "band", x = -32, y = 202, w = 960, h = 150, col = "magma", a = 0, a2 = 0.13 },
  },
  foreground = {
    -- chains and a near gantry: the works, passing in front
    { kind = "girder", x = -52, y = 26, w = 1000, h = 18, col = "black", a = 0.94, py = -0.14, step = 36 },
    { kind = "hang", x = 268, y = 44, w = 2, h = 80, col = "black", a = 0.9, py = -0.14, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 568, y = 44, w = 2, h = 66, col = "black", a = 0.9, py = -0.14, lw = 2, sway = 4, rate = 0.45, bob = true },
    { kind = "hang", x = 798, y = 44, w = 2, h = 52, col = "black", a = 0.9, py = -0.14, lw = 2, sway = 4, rate = 0.45, bob = true },
  },
  lights = {
    { x = 128, y = 300, r = 70, col = { 1.00, 0.55, 0.22 }, flicker = 5.5 },
    { x = 728, y = 300, r = 66, col = { 1.00, 0.55, 0.22 }, flicker = 6.8 },
    { x = 428, y = 140, r = 50, col = { 1.00, 0.55, 0.22 }, flicker = 7.9 },
  },
  arena = "crucible",
  mapPos = { x = 14, y = 3, w = 3, h = 1 },
  floodRow = 17,
  gates = { G = "boss_crucible" },
  map = [[
############AAA#########################################
############AAA#########################################
###########................................#############
#########.....................................##########
########..#===...................................#######
########.##......................................#######
#######..##.......................................######
#######..##.......p..............q.................#####
######..###........................................#####
######..###..........................................###
#####..###............................................##
#####..###............................................##
######..##........#####..........#####...a............##
######...G............................................##
#######..G............................................##
#######..G.........................................B..##
########.G.1.b..............t......................B..##
###############................................#########
########################################################
########################################################
########################################################
########################################################
]],
  key = {
    -- THE TRIPWIRE, on the arena's midline.
    --
    -- `t` is a full-height column, not a body: crossing col 28 at ANY
    -- height starts the fight, which is why a boss cannot be jumped
    -- over into. It is at col 28 because that is the middle -- the same
    -- middle the engine uses, World.w * T / 2 -- so the line you cross
    -- is directly under where the Crucible hovers in. Its ROW is
    -- cosmetic (the detection box is the whole column); 16 is where
    -- every other 22-row arena in the game puts it.
    --
    -- It went missing in an editor save on 22 Aug and took the boss with
    -- it: furn_boss was an arena with nothing in it that arms a boss,
    -- and the first symptom was core_2/3/4/boss reported unreachable
    -- four steps downstream. Two guards came out of that -- the editor
    -- now holds a save that would delete a boss until you confirm it,
    -- and checkprops fails an arena with nothing to arm.
    ["t"] = "boss:crucible",
    ["1"] = "sign:sign_link2",
    ["p"] = "cruciblepot:left",
    ["q"] = "cruciblepot:right",
    ["a"] = "anchor",
    ["b"] = "updraft:18",
  },
  links = {
    B = { "deep_stair_1", "E", req = "boss_crucible" },
    A = { "furn_6", "B" },
  },
}
