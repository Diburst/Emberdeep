-- ==================================================================
-- THE COLDSTORE'S VERB: heat you carry
-- ==================================================================
-- Every number the zone runs on lives here, for the same reason every
-- upgrade cost lives in src/upgrades.lua: the moment a constant is
-- written in two places, one of them is wrong and nobody finds out for
-- a month.
--
-- It also has to be readable from OUTSIDE Lua. tools/checkheat.py walks
-- the brazier chain at the real carry speed against the real spark
-- timer and fails if two consecutive braziers are further apart than a
-- spark survives -- and it reads these values straight out of this file
-- rather than keeping its own copy. A validator with its own copy of
-- the number it is validating is a validator that passes forever.
--
-- THE TWO LAWS, and why they do not overlap:
--   ICE  is broken by a heavy blow  -- the ram, the charged lance, the
--        mortar. That is the thawplate rule and it is unchanged.
--   FIRE is spread only by carrying it. Nothing else lights anything.
--        Not the Cinder Ram, not a charge, not a lance. The chain
--        starts at the one hearth that never went out and you extend
--        it outward, one crossing at a time.
--
-- The second law is the whole zone. If a charge could light a brazier
-- the spark would be decoration and the Coldstore would be a corridor
-- with a status effect in it.
-- ==================================================================
local Cold = {}

-- ------------------------------------------------------------------
-- CHILL. A 0..1 meter per bot. It is not a debuff; it is a countdown.
-- ------------------------------------------------------------------
-- Unprotected: FILL_BARE takes the meter from empty to full, and then
-- the bite starts. Full-to-down is BITE_TICK * (1 / BITE_FRAC) seconds,
-- and because the bite is a FRACTION of max HP rather than a flat
-- number, the countdown is the same length for a bot on base 12 HP and
-- for a maxed one. "About four seconds" stays about four seconds
-- instead of quietly becoming instant for an unupgraded run.
Cold.CHILL_MAX   = 1.0
Cold.FILL_BARE   = 1 / 2.2     -- meter/sec with no Cryo Coils
Cold.FILL_COILED = 1 / 11.0    -- ...with them: crossable, never comfortable
Cold.DRAIN       = 1 / 1.2     -- meter/sec inside a heat radius
-- MEASURED, not chosen: takeDamage grants 1.2s of i-frames, so a tick
-- faster than that is a number that lies about itself. It was 0.5, and
-- the harness showed the bites landing 1.2s apart regardless.
Cold.BITE_TICK   = 1.2         -- seconds between bites once the meter is full
Cold.BITE_FRAC   = 0.30        -- of max HP per bite
Cold.BITE_MIN    = 2           -- ...never less than this

-- The tell before the teeth. Above SLOW_AT the bot stiffens up, so the
-- meter is legible in the movement and not only in the bar.
Cold.SLOW_AT     = 0.55
Cold.SLOW_MIN    = 0.72        -- of top speed at a full meter

-- ------------------------------------------------------------------
-- HEAT. A lit brazier is an island; the hearth is the mainland.
-- ------------------------------------------------------------------
Cold.BRAZIER_R   = 48          -- px. Chill drains inside this.
Cold.HEARTH_R    = 76
Cold.BRAZIER_LIGHT = 90        -- lightR, for the dark
Cold.HEARTH_LIGHT  = 150

-- ------------------------------------------------------------------
-- THE SPARK. The zone's clock.
-- ------------------------------------------------------------------
-- You take fire out of a lit brazier and you have SPARK_BURN seconds of
-- it. Carrying costs you your gun, your dome and your charge -- the
-- same trade the Ember makes, one size down -- so whoever holds it is
-- being escorted, not fighting.
--
-- While it burns it holds your own chill off. That is not generosity:
-- it is what makes the ESCORT the one racing the meter, and it is why
-- losing the spark halfway is a walk home rather than a death.
Cold.SPARK_BURN  = 10.0
Cold.CARRY_SLOW  = 0.85        -- of top speed
Cold.SPARK_LIGHT = 64
Cold.SPARK_R     = 20          -- px reach to light a brazier by walking into it
-- FIRE IN YOUR HANDS MELTS WHAT YOU WALK OVER. A carrier crossing a
-- frozen floor leaves a thawed line behind them, which is the point of
-- carrying it: the spark is not just a key for braziers, it is heat.
Cold.SPARK_MELT  = 1           -- tiles either side of the carrier
Cold.SPARK_MELT_T = 0.15       -- seconds between melts

-- Warn the carrier with sound and shrinking flame for the last stretch.
Cold.SPARK_LOW   = 3.0

-- ------------------------------------------------------------------
-- Is (x, y) inside anything burning?  Returns the strongest source, or
-- nil. Anything with a `heatR` counts, so a brazier, the hearth and
-- whatever Phase 2 adds all answer the same question.
-- ------------------------------------------------------------------
function Cold.heatAt(World, x, y)
  local best, bestSlack = nil, -1
  for _, e in ipairs(World.entities or {}) do
    local r = e.heatR
    if r and r > 0 and not e.dead then
      local ex = e.x + (e.w or 0) / 2
      local ey = e.y + (e.h or 0) / 2
      local dx, dy = x - ex, y - ey
      local slack = r - math.sqrt(dx * dx + dy * dy)
      if slack > bestSlack then best, bestSlack = e, slack end
    end
  end
  if bestSlack >= 0 then return best end
  return nil
end

-- ------------------------------------------------------------------
-- Brazier state lives in the RUN, not on the prop, so a lit brazier is
-- still lit when you walk back into the room -- and still lit after a
-- save, a bot swap and a reload. Lighting one is permanent progress,
-- exactly like opening a shortcut.
-- ------------------------------------------------------------------
function Cold.flagFor(id) return "brazier_" .. tostring(id) end

function Cold.isLit(id)
  if not (G.run and G.run.flags) then return false end
  return G.run.flags[Cold.flagFor(id)] and true or false
end

function Cold.light(id)
  if not (G.run and G.run.flags) then return end
  G.run.flags[Cold.flagFor(id)] = true
end

-- ------------------------------------------------------------------
-- A GATE THAT ANSWERS TO THE ZONE'S OWN WORK
-- ------------------------------------------------------------------
-- The way to the Threshold used to be opened by carrying four catalog
-- plates in from four other zones and handing them to a man standing in
-- a doorway. That is the least mysterious structure available, and it
-- put the Coldstore's climax behind errands run somewhere else.
--
-- It answers to heat now. A room can declare:
--
--     braziergate = { flag = "cradle_found", need = { "c5a", "c5b" } }
--
-- and the gate opens the moment every brazier named there is burning --
-- which is to say, the moment somebody has carried fire that far in.
-- The door is the proof of the journey rather than a receipt for one.
--
-- Gates resolve per-tile against G.run.flags every frame, so the wall
-- goes the instant the last brazier catches, with the player standing
-- there watching it.
function Cold.checkGates(World)
  local def = World and World.room and World.room.braziergate
  if not def or not (G.run and G.run.flags) then return false end
  if G.run.flags[def.flag] then return false end
  for _, id in ipairs(def.need or {}) do
    if not Cold.isLit(id) then return false end
  end
  G.run.flags[def.flag] = true
  return true
end

-- ==================================================================
-- HOARFROST
-- ==================================================================
-- Creeping ice that eats a floor a tile at a time. It is the Archivist's
-- weapon and the Coldstore's exam: the arena does not fill with enemies,
-- it gets SMALLER, and the only things that push it back are the two
-- answers the zone has already taught you --
--
--   a LIT BRAZIER, which frost will not grow inside (strategic: it is
--   permanent, and the Archivist snuffing one is what costs you), and
--   the CINDER RAM, which burns a chevron through it (tactical, and
--   optional -- a player who took another route must still be able to
--   win, so braziers alone are sufficient).
--
-- Standing on frost is not instant death. It fills your chill at the
-- BARE rate whatever you are wearing, so the Cryo Coils stop mattering
-- the moment you are standing on the stuff -- which is the zone saying,
-- in its own language, that this is worse than its air.
-- ==================================================================
Cold.FROST_TICK      = 3.2     -- seconds per tile of growth, per front
Cold.FROST_TICK_SOLO = 5.4     -- ...with only one bot live. A solo player
                               -- does sequentially what two do at once.
Cold.FROST_FILL      = 1 / 1.8 -- chill/sec standing on it, coils or not
-- 1.5 tiles. It was 2.5, which held so much floor that three braziers
-- made most of the arena permanently safe and left the Archivist very
-- little ground it could work with.
Cold.FROST_BURN_R    = 24      -- px: frost will not grow this near a fire
Cold.RAM_BURN        = 2       -- tiles either side of a charge

function Cold.frostInit(World, row)
  World.frost = { row = row, cells = {}, t0 = 0, t1 = 0 }
end

function Cold.frostAt(World, tx, ty)
  local f = World.frost
  if not f or ty ~= f.row then return false end
  return f.cells[tx] and true or false
end

-- Is this tile inside the reach of something burning?
local function nearFire(World, tx, row)
  local px, py = tx * 16 + 8, row * 16 + 8
  for _, e in ipairs(World.entities or {}) do
    if e.heatR and e.heatR > 0 and not e.dead then
      local ex = e.x + (e.w or 0) / 2
      local ey = e.y + (e.h or 0) / 2
      local dx, dy = px - ex, py - ey
      if dx * dx + dy * dy < (Cold.FROST_BURN_R) ^ 2 then return true end
    end
  end
  return false
end

function Cold.frostSet(World, tx, on)
  local f = World.frost
  if not f then return end
  if tx < 1 or tx > World.w - 2 then return end
  f.cells[tx] = on or nil
end

-- Ice a span outright -- the Archivist planting rime under itself.
function Cold.frostSeed(World, x0, x1)
  local f = World.frost
  if not f then return 0 end
  local n = 0
  for tx = math.floor(x0), math.floor(x1) do
    if not f.cells[tx] and not nearFire(World, tx, f.row) then
      Cold.frostSet(World, tx, true)
      n = n + 1
    end
  end
  return n
end

-- Burn it back. Returns how many tiles actually went.
function Cold.frostBurn(World, tx, radius)
  local f = World.frost
  if not f then return 0 end
  local n = 0
  for x = tx - radius, tx + radius do
    if f.cells[x] then f.cells[x] = nil n = n + 1 end
  end
  return n
end

function Cold.frostCount(World)
  local f = World.frost
  if not f then return 0 end
  local n = 0
  for _ in pairs(f.cells) do n = n + 1 end
  return n
end

-- Two fronts, one per wall, walking inward. A front stalls at a fire
-- rather than dying: put the brazier out and it starts moving again,
-- from where it stopped.
function Cold.frostUpdate(World, dt)
  local f = World.frost
  if not f then return end
  local live = 0
  for _, p in ipairs(World.players or {}) do
    if not p.dead and not p.downed and not p.idle then live = live + 1 end
  end
  local tick = live <= 1 and Cold.FROST_TICK_SOLO or Cold.FROST_TICK

  -- A front SKIPS a protected tile rather than stalling on it. Stopping
  -- dead at the first brazier looked right and was badly wrong: the
  -- fronts parked outside the outer fires and the whole middle of the
  -- arena never froze at all, so putting a brazier out changed nothing
  -- and the Archivist's entire escalation was inert. A fire keeps its
  -- own patch; it does not hold the room behind it.
  local function advance(from, to, step)
    for tx = from, to, step do
      if not f.cells[tx] and not nearFire(World, tx, f.row) then
        Cold.frostSet(World, tx, true)
        return true
      end
    end
    return false
  end

  f.t0 = f.t0 + dt
  if f.t0 >= tick then
    f.t0 = 0
    advance(1, World.w - 2, 1)
  end
  f.t1 = f.t1 + dt
  if f.t1 >= tick then
    f.t1 = 0
    advance(World.w - 2, 1, -1)
  end

  -- a fire lit AFTER the ice arrived clears what it can reach
  for tx in pairs(f.cells) do
    if nearFire(World, tx, f.row) then f.cells[tx] = nil end
  end
end

-- Is this bot standing on it?
function Cold.onFrost(World, p)
  local f = World.frost
  if not f then return false end
  local tx = math.floor((p.x + p.w / 2) / 16)
  local ty = math.floor((p.y + p.h + 2) / 16)
  return ty == f.row + 1 and f.cells[tx] and true or false
end

function Cold.frostDraw(World)
  local f = World.frost
  if not f then return end
  local g = love.graphics
  local y = f.row * 16
  for tx in pairs(f.cells) do
    local x = tx * 16
    g.setColor(0.72, 0.88, 0.98, 0.55)
    g.rectangle("fill", x, y + 10, 16, 6)
    g.setColor(0.92, 0.98, 1.0, 0.75)
    for k = 0, 2 do
      local h = 2 + ((tx * 7 + k * 5) % 5)
      g.rectangle("fill", x + 2 + k * 5, y + 10 - h, 1, h)
    end
  end
  g.setColor(1, 1, 1, 1)
end

return Cold
