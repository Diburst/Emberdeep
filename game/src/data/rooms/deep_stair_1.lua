-- THE DEEP STAIR, upper landing. Every road below Mosswood begins here.
return {
  zone = "camp", music = "camp",
  arena = "deepstair",
  -- ------------------------------------------------------------------
  -- THE UPPER SHAFT -- you can still tell it was built.
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
  dark = 0.40,
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
    -- SIDE COLUMNS, FURTHER BACK AGAIN -- and only one of them was ever
    -- seen. The left column sits at x=26, behind the two solid tiles of
    -- the left wall, so its `black` at 0.45 is completely occluded and
    -- nobody ever noticed how heavy that was. The right one at x=430 is
    -- tile 27, which is OPEN SPACE for the whole lower half of the room
    -- and right beside door C -- so the same value drew a hard black bar
    -- down the right-hand lane, darker than the rock in front of it.
    --
    -- A thing that is FURTHER AWAY loses contrast toward the haze; it
    -- does not become the darkest object on screen. So the exposed one
    -- is haze-coloured and faint, and now reads as a pillar standing
    -- behind the shaft rather than as a hole punched in it. Rendered and
    -- compared at black/0.45, black/0.18, gray/0.14, gray/0.20 and
    -- slate/0.12 before picking.
    --
    -- The left one is left as it was on purpose: it is invisible either
    -- way, and its value is a fossil worth keeping legible next to the
    -- one that had to change.
    { kind = "column", x = 26, y = 24, w = 14, h = 496, col = "black", a = 0.45, py = 0.42, step = 26, acc = "gray" },
    { kind = "column", x = 430, y = 24, w = 14, h = 496, col = "gray", a = 0.20, py = 0.42, step = 26, acc = "slate" },
    -- light falling in from the district above, dying out below
    { kind = "shaft", x = 70, y = 34, w = 66, h = 240, col = "cream", a = 0.22, py = 0.18, skew = 26, ph = 0 },
    { kind = "shaft", x = 250, y = 34, w = 54, h = 190, col = "cream", a = 0.16, py = 0.18, skew = 26, ph = 1.7 },
    -- DEPTH HAZE. Distance is mostly haze, and down is distance
    -- here: the bottom of the shaft should be losing itself.
  },
  scenery = {
    { kind = "band", x = 0, y = 0, w = 480, h = 544, col = "black", a = 0.1, a2 = 0.62, py = 0 },
    { kind = "rect", x = 43, y = 64, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 45, y = 66, w = 3, h = 5, col = "gold", a = 1 },
    { kind = "rect", x = 431, y = 112, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 433, y = 114, w = 3, h = 5, col = "gold", a = 1 },
    { kind = "rect", x = 43, y = 256, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 45, y = 258, w = 3, h = 5, col = "gold", a = 1 },
    { kind = "rect", x = 431, y = 304, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 433, y = 306, w = 3, h = 5, col = "gold", a = 1 },
    { kind = "rect", x = 43, y = 448, w = 7, h = 9, col = "rust", a = 0.9 },
    { kind = "rect", x = 45, y = 450, w = 3, h = 5, col = "gold", a = 1 },
  },
  foreground = {
    -- Crossbeams NEARER than the world (py < 0): they overtake you
    -- on the way down, which is the whole trick of a foreground.
    { kind = "girder", x = -20, y = 54, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    { kind = "girder", x = -20, y = 214, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    { kind = "girder", x = -20, y = 374, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    { kind = "girder", x = -20, y = 502, w = 520, h = 16, col = "black", a = 0.92, py = -0.12, step = 34 },
    -- chains off the beams, each swaying on its own phase
    { kind = "hang", x = 120, y = 70, w = 2, h = 54, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 300, y = 70, w = 2, h = 38, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 210, y = 230, w = 2, h = 62, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 390, y = 230, w = 2, h = 44, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 96, y = 390, w = 2, h = 58, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    { kind = "hang", x = 340, y = 390, w = 2, h = 40, col = "black", a = 0.85, py = -0.12, lw = 2, sway = 5, rate = 0.55, bob = true },
    -- the near lip of the shaft, hard left and right
    { kind = "band", x = 0, y = 0, w = 34, h = 544, col = "black", a = 0.85, a2 = 0.85, py = -0.06 },
    { kind = "band", x = 446, y = 0, w = 34, h = 544, col = "black", a = 0.85, a2 = 0.85, py = -0.06 },
  },
  lights = {
    { x = 46, y = 68, r = 58, col = { 1.00, 0.74, 0.40 }, flicker = 7.5 },
    { x = 434, y = 116, r = 54, col = { 1.00, 0.74, 0.40 }, flicker = 6.2 },
    { x = 46, y = 260, r = 52, col = { 1.00, 0.74, 0.40 }, flicker = 8.1 },
    { x = 434, y = 308, r = 48, col = { 1.00, 0.74, 0.40 }, flicker = 5.6 },
    { x = 46, y = 452, r = 44, col = { 1.00, 0.74, 0.40 }, flicker = 7.0 },
  },
  mapPos = { x = 22, y = 2, w = 1, h = 2 },
  gates = { H = "boss_crucible", I = "boss_prismtyrant", J = "bus_deep_stair_1_1" },
  gateStyle = { J = "shutter" },
  map = [[
###############################
###############################
##..........................###
##....A.....................###
##....A.....................###
##==============............###
##..........................###
##..........................###
##............==============###
##...................###....###
##...................HE#....###
##==============.....HE#....###
##..................=###....###
##..........................###
##............==============###
##..........................###
##............................C
##==============..............C
##.........................===#
##..........................###
##............==============###
##....###...................###
##....#FI...................###
##====#FI======.............###
##....###=....................#
##............................#
##............=========.......#
##...................b.......f#
##............................#
##==============..............#
##............................#
##.d..........................#
########......######JJJ.......#
#########....########.#g.e....#
##########BB#########D#########
##########BB#########D#########
]],
  key = {
    ["f"] = "mirror:b",
    ["g"] = "node:bus_deep_stair_1_1:1",
    ["b"] = "emitter:right:dormant:9",
    ["d"] = "cell",
    ["e"] = "panel:h:f:4",
  },
  links = {
    A = { "stair_junction", "C", req = "boss_bramblemaw" },
    B = { "deep_stair_2", "A" },
    C = { "furn_1", "A" },
    D = { "crys_1", "A" },
    E = { "furn_boss", "B", req = "boss_crucible" },
    F = { "crys_boss", "B", req = "boss_prismtyrant" },
  },
}
