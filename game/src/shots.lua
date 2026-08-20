-- Screenshot regression harness.  `EMBERDEEP_SHOTS=<tag> love .`
--
-- Loads a fixed list of rooms, draws each exactly once, and writes the
-- world canvas to emberdeep/_shots/<tag>/<room>.png.  Compare two tags
-- with ../scripts/shotdiff.py.
--
-- The output lives INSIDE the project rather than in /tmp so that the
-- shots are reachable from the device bridge -- a harness whose output
-- only the person running it can see is half a harness.  _shots/ is
-- gitignored.  Override the location with EMBERDEEP_SHOTDIR.
--
-- WHY THIS EXISTS.  Every phase of the foundation refit is a rendering
-- change, and the scenario suite asserts on STATE, not pixels -- so it is
-- structurally blind to exactly the regressions this work can cause.  A
-- pixel-identical diff is the only proof that a "pure plumbing" patch was
-- actually pure.
--
-- DETERMINISM IS THE WHOLE POINT.  Four rules, every one of them
-- load-bearing, and every one of them learned by reading the code rather
-- than by assuming:
--
--   * THE WORLD IS NEVER UPDATED.  Ambient particles are spawned from
--     World:ambient, which is called from World:update.  One update tick
--     and every run differs.  So this harness replaces State.update
--     entirely rather than calling it with dt = 0.
--
--   * THE GAME STATE FADES IN.  game.lua's enter() sets fade = 1 -- a
--     fully black screen -- and walks it down from update().  A harness
--     that never updates captures a black frame for every room and the
--     diff passes forever.  Forced to 0 after each load.
--
--   * G.time IS PINNED.  A dozen draw sites read it: water surface wobble,
--     the sparkle on top of a water tile, the mended-zone warmth pulse,
--     terminal blink, the crystal rail shimmer.  Left running, the diff is
--     pure noise.
--
--   * BOTH RNGs ARE RESEEDED before each draw.  Room decor already uses
--     its own seeded generator (world.lua:812), and the one raw
--     love.math.random in the draw path (the crumble-tile jitter at
--     world.lua:1491) only fires on an actively-crumbling tile, which
--     cannot happen without an update.  Both facts are true today and
--     neither is guaranteed to stay true, so this reseeds anyway -- it
--     costs nothing and it stops a future draw-time RNG call from
--     producing a mystery diff.
--
-- The canvas is captured DIRECTLY (G.canvas:newImageData) rather than via
-- love.graphics.captureScreenshot, which grabs the window -- including the
-- letterbox bars, which vary with window size and would pollute the diff.

local Shots = {}

local SEED = 20260820
local PINNED_TIME = 100.0

-- Coverage, deliberately chosen rather than "every room": every zone, both
-- room shapes (single-viewport 30x17 and the tall/wide ones), every boss
-- arena, and the dark rooms -- because the darkness mask is a whole
-- rendering path that no other shot exercises.
Shots.ROOMS = {
  -- camp
  "camp_main", "camp_hut", "camp_awake",
  -- mosswood: wide, tall, arena, grotto
  "moss_1", "moss_3", "moss_grotto", "moss_boss",
  -- flooded: water rendering is its own path
  "flood_2", "flood_warden", "flood_boss",
  -- furnace
  "furn_1", "furn_golem", "furn_boss",
  -- crystal: beams
  "crys_1", "crys_boss",
  -- skyroot: the tall ones
  "sky_1", "sky_boss",
  -- undergrove: DARK.  ug_boss is dark AND an arena.
  "ug_1", "ug_5", "ug_boss",
  -- coldstore
  "cold_1", "cold_boss",
  -- core
  "core_1", "core_4", "core_boss",
  -- scrapyard
  "scrap_2", "scrap_boss",
  -- cradle: dark, and its own zone
  "cradle_1",
  -- connective tissue: the 34-row stair, the gallery, the test arena
  "deep_stair_1", "gal_2", "test_arena",
}

-- Ability flags only.  Deliberately NO boss_* flags: those switch whole
-- zones into their "mended" render path (World:zoneMended adds a warmth
-- overlay) and the point of a baseline is the ordinary state of the world.
-- lumecore IS set, because it doubles Lu's light radius and the dark rooms
-- are half of what this harness is for.
local FLAGS = {
  sparkjump = true, grapple = true, hydroseals = true,
  heatplating = true, telenet = true, cryocoils = true,
  driftvanes = true, lumecore = true,
}

-- Relative to the LOVE process cwd, which is game/ when run as `love .`
-- from there. Absolute paths work too, via EMBERDEEP_SHOTDIR.
local SHOTDIR = os.getenv("EMBERDEEP_SHOTDIR") or "../_shots"

local tag, dir, idx, phase = nil, nil, 0, "load"
local log

local function out(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
  local line = table.concat(parts, " ")
  print(line)
  if log then log:write(line, "\n") log:flush() end
end

local function reseed()
  love.math.setRandomSeed(SEED)
  math.randomseed(SEED)
  G.time = PINNED_TIME
end

function Shots.init(t)
  tag = t
  dir = SHOTDIR .. "/" .. tag
  os.execute("mkdir -p '" .. dir .. "'")
  log = io.open(SHOTDIR .. "/shots.log", "a")
  -- Stamp the set with what produced it. A tag is just a folder name, so
  -- two runs at different render scales will happily overwrite each other
  -- and leave no trace of which one won -- which is exactly what happened
  -- the first time RS=4 was run. The canvas dimensions in each PNG are the
  -- authority (shotdiff derives the scale from them), but a human reading
  -- the folder should not have to open an image to find out.
  local mf = io.open(dir .. "/meta.txt", "w")
  if mf then
    mf:write(string.format(
      "rs=%d\nrooms=%d\ncanvas=%dx%d\nworld=%dx%d\nscreen=%dx%d\n",
      G.RS or 1, #Shots.ROOMS, (G.SW or 0) * (G.RS or 1), (G.SH or 0) * (G.RS or 1),
      G.VW or 0, G.VH or 0, G.SW or 0, G.SH or 0))
    mf:close()
  end
  out(string.format("=== SHOTS %s (%d rooms, RS=%d, canvas %dx%d) ===",
    tag, #Shots.ROOMS, G.RS or 1, (G.SW or 0) * (G.RS or 1), (G.SH or 0) * (G.RS or 1)))

  reseed()
  G.run = G.Save.newRun(1, 2, true)
  for k, v in pairs(FLAGS) do G.run.flags[k] = v end
  G.run.room = Shots.ROOMS[1]
  G.run.door = nil
  G.State.switch(require "src.states.game", { coop = true })
  idx, phase = 1, "draw"
  Shots.settle()
  -- Last, not first: this is the switch main.lua reads to stop calling
  -- State.update. Setting it before the state is stood up would strand the
  -- loading state half-built.
  G.shotsActive = true
end

-- Everything that game.lua's update() would have established before the
-- first frame is visible, done explicitly.
function Shots.settle()
  local g = G.game
  if not g then return end
  g.fade, g.fadeDir, g.fadeCb = 0, 0, nil
  g.announceQueue = {}
  g.dialogue, g.cutscene = nil, nil
  g.respawning = false
  g.linkMeter, g.linkState = 1, nil
end

-- Called INSTEAD OF State.update.  The world is never stepped.
function Shots.update()
  if phase ~= "load" then return end
  idx = idx + 1
  if idx > #Shots.ROOMS then
    out("=== DONE " .. tag .. " ===")
    love.event.quit(0)
    return
  end
  local id = Shots.ROOMS[idx]
  reseed()
  local ok, err = pcall(function()
    require("src.world"):load(id, nil, true)
  end)
  if not ok then
    out("FAILLOAD " .. id .. ": " .. tostring(err))
    love.event.quit(1)
    return
  end
  Shots.settle()
  phase = "draw"
end

function Shots.preDraw()
  reseed()
end

function Shots.postDraw()
  if phase ~= "draw" then return end
  local id = Shots.ROOMS[idx]
  local ok, err = pcall(function()
    local data = G.canvas:newImageData()
    local fd = data:encode("png")
    local f = io.open(dir .. "/" .. string.format("%02d_", idx) .. id .. ".png", "wb")
    if not f then error("cannot open output file") end
    f:write(fd:getString())
    f:close()
  end)
  if not ok then
    out("FAILSHOT " .. id .. ": " .. tostring(err))
    love.event.quit(1)
    return
  end
  out("SHOT " .. string.format("%02d", idx) .. " " .. id)
  phase = "load"
end

return Shots
