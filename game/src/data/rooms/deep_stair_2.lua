-- THE DEEP STAIR, lower landing. The Core waits at the bottom of it.
return {
  zone = "camp", music = "camp",
  arena = "deepstair",
  -- ------------------------------------------------------------------
  -- THE LOWER SHAFT -- the light gave up before you did.
  --
  -- A service stairwell, not a cave. The city built this to move people
  -- between districts and it has moved nobody for a hundred years, so
  -- the art has to read as STRUCTURE that outlived its purpose rather
  -- than as rock.
  --
  -- px is useless in this room and py is everything: the shaft is 30
  -- tiles = exactly one viewport wide, so Cam.x never moves, and there
  -- are 274px of vertical travel to play with.
  --     py > 0  lags the camera  -> further away
  --     py < 0  outruns it       -> nearer than the world
  -- ------------------------------------------------------------------
  dark = 0.66,
  backdrop = {
    -- The shaft is DEEPER than the column you stand in: a second
    -- flight on the half-beat, lagging the camera, so the eye reads
    -- two stairwells instead of one painted wall.
    { kind = "girder", x = 24, y = 104, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 152, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 200, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 248, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 296, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 344, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 392, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 440, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    { kind = "girder", x = 24, y = 488, w = 432, h = 13, col = "black", a = 0.5, py = 0.3, step = 30 },
    -- side columns, further back again
    { kind = "column", x = 26, y = 24, w = 14, h = 496, col = "black", a = 0.45, py = 0.42, step = 26, acc = "gray" },
    { kind = "column", x = 430, y = 24, w = 14, h = 496, col = "black", a = 0.45, py = 0.42, step = 26, acc = "gray" },
    -- light falling in from the district above, dying out below
    { kind = "shaft", x = 90, y = 34, w = 44, h = 120, col = "cream", a = 0.08, py = 0.18, skew = 26, ph = 0 },
    -- DEPTH HAZE. Distance is mostly haze, and down is distance
    -- here: the bottom of the shaft should be losing itself.
  },
  scenery = {
    { kind = "band", x = 0, y = 0, w = 480, h = 544, col = "black", a = 0.1, a2 = 0.86, py = 0 },
    { kind = "rect", x = 43, y = 112, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 45, y = 114, w = 3, h = 5, col = "gold", a = 1 },
    { kind = "rect", x = 431, y = 304, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 433, y = 306, w = 3, h = 5, col = "gold", a = 1 },
  },
  foreground = {
    -- Crossbeams NEARER than the world (py < 0): they overtake you
    -- on the way down, which is the whole trick of a foreground.
    { kind = "girder", x = -20, y = 54, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    { kind = "girder", x = -20, y = 214, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    { kind = "girder", x = -20, y = 374, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    { kind = "girder", x = -20, y = 502, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    -- chains off the beams, each swaying on its own phase
    { kind = "hang", x = 140, y = 70, w = 2, h = 66, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 320, y = 70, w = 2, h = 52, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 190, y = 230, w = 2, h = 74, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 410, y = 230, w = 2, h = 50, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 110, y = 390, w = 2, h = 70, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 300, y = 390, w = 2, h = 58, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 420, y = 390, w = 2, h = 44, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    -- the near lip of the shaft, hard left and right
    { kind = "band", x = 0, y = 0, w = 34, h = 544, col = "black", a = 0.85, a2 = 0.85, py = -0.06 },
    { kind = "band", x = 446, y = 0, w = 34, h = 544, col = "black", a = 0.85, a2 = 0.85, py = -0.06 },
  },
  lights = {
    { x = 46, y = 116, r = 44, col = { 0.72, 0.80, 0.95 }, flicker = 4.2 },
    { x = 434, y = 308, r = 34, col = { 0.72, 0.80, 0.95 }, flicker = 3.1 },
  },
  mapPos = { x = 22, y = 4, w = 1, h = 2 },
  gates = { G = "boss_tideengine", H = "boss_archivist" },
  map = [[
#######A######################
#######A######################
##..........................##
##.....==...................##
##..........................##
##==============............##
##..........................##
##..........................##
##............==============##
##..........................##
##..........................##
##==============.....###....##
##...................GD#....##
##...................GD#....##
##............=======###====##
##..........................##
##..........................##
##==============............##
##..........................##
##.........................==#
##............==============##
##..........................##
##..........................##
##====###=======............##
##....#EH...................##
##....#EH...................##
##....###=....==============##
##..........................##
##..........................##
##==========#===............##
##.........#C...............##
##.........#C...............##
##############################
##############################
]],
  key = {},
  links = {
    A = { "deep_stair_1", "B" },
    C = { "core_1", "A" },
    D = { "flood_boss", "F", req = "boss_tideengine" },
    E = { "cold_boss", "C", req = "boss_archivist" },
  },
}
