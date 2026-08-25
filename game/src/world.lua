-- World: room loading, tile queries, entity management, particles,
-- transitions, drawing. The heart of the in-game simulation.
local U = require "src.core.util"
local PH = require "src.physics"
local Cam = require "src.camera"
local Entity = require "src.entities.entity"
-- The palette used to be required eight hundred lines down, next to the
-- first function that happened to need it. A local declared there is not
-- an upvalue for anything ABOVE it, so every function written earlier saw
-- the nil GLOBAL P instead -- which is how drawGrate crashed the Test
-- Chamber the moment it loaded the Crucible's arena. It lives with the
-- other requires now, and tools/load_test.lua fails the build on any
-- function that reads a local declared after it.
local P = require "src.assets.palette"

local T = 16

local World = {
  room = nil,
  w = 0, h = 0,          -- in tiles
  tiles = {},            -- [ty][tx] = code
  entities = {},
  addQueue = {},
  players = {},          -- player entities present
  particles = {},
  doors = {},            -- char -> {x0,y0,x1,y1 (tiles), edge=side or nil}
  crumbles = {},         -- idx -> {state}
  broken = {},           -- idx -> true (breakables destroyed this visit)
  pendingTransition = nil,
  fxTimer = 0,
}

-- tile codes
local AIR, SOLID, ONEWAY, SPIKE_U, SPIKE_D, SPIKE_L, SPIKE_R, WATER, LAVA,
  BREAK, CRUMBLE, GATE = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
World.codes = { AIR = AIR, SOLID = SOLID, ONEWAY = ONEWAY, WATER = WATER,
  LAVA = LAVA, BREAK = BREAK, CRUMBLE = CRUMBLE, GATE = GATE }

-- ICE ('_') PARSES AS SOLID AND IS REMEMBERED SEPARATELY.
--
-- It could have been its own tile code, but SOLID is tested directly in
-- ten places across the renderer and the physics and every one of them
-- would have had to learn about it -- for a tile that collides exactly
-- like rock. So it is rock, plus a set: World.iceSet holds the tiles
-- whose SURFACE is frozen, drawIce glazes them, and the player asks
-- World:isIce what it is standing on. Nothing else changes.
--
-- The character came off checkchars' free list rather than out of the
-- air: '_' is used as a key in no room in the game, so adding it to the
-- alphabet cannot silently turn an existing entity spawn into scenery.
-- That is the bug this project has hit twelve times.
local CHAR_TILE = {
  ["#"] = SOLID, ["_"] = SOLID, ["."] = AIR, ["="] = ONEWAY,
  ["^"] = SPIKE_U, ["v"] = SPIKE_D, ["<"] = SPIKE_L, [">"] = SPIKE_R,
  ["~"] = WATER, ["L"] = LAVA, ["%"] = BREAK, ["c"] = CRUMBLE,
  -- THE BULWARK BLOCK (COOP-PLAN 3): the first VESS gate in the game.
  -- Every mobility gate until now has been Lu's -- spark jump, drift
  -- vanes -- and all three of Vess's modules bolt onto the charge he has
  -- had since room one. A block only a PLATED charge opens is the
  -- missing half of that pair.
  --
  -- It is a BREAK, not a twelfth tile kind, and that is the whole trick.
  -- Eight places in this file ask `== BREAK` for solidity, physics,
  -- edges and drawing; a new kind would have to be taught to all eight
  -- and would go stale in whichever one got missed. Hardness rides
  -- alongside in World.hardSet instead, exactly as ice does, so the only
  -- thing in the engine that learns anything new is breakTile.
  ["*"] = BREAK,
  -- ...and the same trick a second time, for the other half of the
  -- pair. "&" is a BREAK that only the LINK blast opens: the lattice
  -- the pair shot their way out of Ember Camp through. It is a TILE,
  -- not a prop and not a gate -- there is nothing to bind, nothing to
  -- flag and nothing to open. You shoot it together and it is gone.
  ["&"] = BREAK,
}

-- Published for the same reason the alphabet is: roommodel.py has to
-- know that '*' is the gated variant or it will model every bulwark
-- block as free to open, and checkchars fails anyone who writes a second
-- copy of this.
local HARD_CHARS = { ["*"] = "bulwark", ["&"] = "linkblast" }

local DOOR_CHARS = { A = true, B = true, C = true, D = true, E = true, F = true }
local GATE_CHARS = { G = true, H = true, I = true, J = true }

-- THE ROOM ALPHABET, published. A room map is a grid of single
-- characters and these three tables decide which of them are terrain
-- before the room's `key` table is ever consulted -- so an entity keyed
-- to one of them is parsed as scenery and silently never spawns.
--
-- They are exported because four different tools used to keep their own
-- hand-typed copies, and a copy is correct only until this table
-- changes. Anything that needs to know what a character means reads it
-- from here. See scripts/checkchars.py.
-- ==================================================================
-- ANIMATED GATES  (COOP-PLAN 9)
-- ==================================================================
-- An entity cannot be solid in this engine: physics.lua reads TILES and
-- nothing else, and Platform moves its riders itself rather than being a
-- wall you can walk into. A sliding door built as an entity would need a
-- whole entity-collision layer, which touches every moving thing in the
-- game for a feature that does not deserve it.
--
-- So the GATE TILES stay the source of truth and their retraction is
-- animated PER CELL. Collision is already quantised to 16px, so it does
-- not need to be continuous: each cell's visual slides smoothly while
-- only that cell's solidity snaps, and it snaps at the moment its own
-- segment has visually cleared. A five-cell portcullis retracting over
-- half a second flips five times, a tenth of a second apart, each one
-- hidden behind its own animation.
--
-- That is better than a monolithic sliding door rather than a
-- compromise for one: cell-by-cell retraction is what a portcullis, an
-- iris and a shutter all actually do.
--
-- NOTHING IN THE VALIDATORS CHANGES. The character grid is untouched, a
-- gate is still G-J with a flag, so checkprogress still proves the gate
-- gates and roommodel still reads the published alphabet. This is
-- presentation over a model that already works, which is the whole
-- reason to build it this way: it upgrades every gate in all 84 rooms at
-- once, with no room edits and no validator changes.
World.GATE_TIME = 0.5      -- seconds for a whole gate to open or close
World.GATE_SPAN = 0.6      -- the share of that one cell takes
World.GATE_CLEAR = 0.55    -- the phase at which a cell stops being solid

World.CHAR_TILE = CHAR_TILE
World.DOOR_CHARS = DOOR_CHARS
World.GATE_CHARS = GATE_CHARS

function World.preload()
  -- register every entity type
  require "src.entities.projectile"
  require "src.entities.pickup"
  require "src.entities.props"
  require "src.entities.npc"
  require "src.entities.enemies"
  require "src.entities.bosses"
end

local function idx(tx, ty) return ty * 4096 + tx end

-- ------------------------------------------------------------------
-- Queries (physics interface)
-- ------------------------------------------------------------------
function World:tileAt(tx, ty)
  if tx < 0 or ty < 0 or tx >= self.w or ty >= self.h then return SOLID end
  return self.tiles[ty][tx]
end

function World:isIce(tx, ty)
  return self.iceSet ~= nil and self.iceSet[idx(tx, ty)] == true
end

function World:isSolid(tx, ty, ent)
  local c = self:tileAt(tx, ty)
  if c == SOLID then return true end
  if c == BREAK then return not self.broken[idx(tx, ty)] end
  if c == CRUMBLE then
    local st = self.crumbles[idx(tx, ty)]
    return not (st and st.gone)
  end
  if c == GATE then
    local i = idx(tx, ty)
    local flag = self.gateFlags and self.gateFlags[i]
    if not flag or not G.run then return true end
    if flag:sub(1, 1) == "!" then
      -- an energy bridge is a platform APPEARING, not a door retracting,
      -- so it keeps its instant behaviour
      return G.run.flags[flag:sub(2)] and true or false
    end
    -- ...otherwise this cell is solid until its OWN segment has cleared
    return self:gateCellPhase(i) < World.GATE_CLEAR
  end
  return false
end

function World:isOneway(tx, ty)
  return self:tileAt(tx, ty) == ONEWAY
end

function World:isWater(tx, ty)
  if self:tileAt(tx, ty) == WATER then return true end
  -- boss-controlled dynamic water line (Tide Engine)
  if self.waterLine and (ty + 1) * 16 > self.waterLine then
    return self:tileAt(tx, ty) == AIR
  end
  return false
end

function World:isLava(tx, ty)
  return self:tileAt(tx, ty) == LAVA
end

function World:spikeAt(tx, ty)
  local c = self:tileAt(tx, ty)
  return c >= SPIKE_U and c <= SPIKE_R
end

-- ------------------------------------------------------------------
-- WHERE A DROPPED ITEM IS ALLOWED TO LAND
--
-- One rule, shared by everything that puts an object into a room: boss
-- rewards, boss corpses, anything else that has to end up somewhere the
-- player can walk to and take.
--
-- The rule has two halves, and the old code had neither:
--
--   1. FOOTING WITHOUT A HAZARD. The old settleSpot fell until it found
--      a solid or one-way tile below and stopped there, checking only
--      for lava and water. Spikes are not solid, so it fell straight
--      THROUGH a spike bed, landed on the stone underneath, and left the
--      prize sitting inside the spikes. The whole floor of the Mycel
--      Choir's shaft (ug_boss row 30) is a spike bed, so that arena lost
--      its reward every time unless the boss happened to die over one of
--      the six one-way platforms.
--
--   2. REACHABLE. Footing is not enough -- a ledge you cannot climb to
--      is as bad as a spike. Spots are kept only if they are connected
--      to a door mouth, or to where a player is standing right now, by
--      walking, falling, or a jump of 3 rows and 4 tiles (the numbers
--      scripts/roommodel.py is calibrated to).
--
-- If nothing in the room qualifies, the item goes to a player's feet
-- rather than to a "reasonable-looking" spot: standing on someone is by
-- definition reachable and by definition not a spike.
-- ------------------------------------------------------------------
local JUMP_UP = 3        -- rows a jump clears  (roommodel JUMP_H)
local JUMP_ACROSS = 4    -- tiles a jump crosses (roommodel GAP_W)

-- can an object rest on this tile, and can a player stand there to take
-- it? The tile itself and the one above it must be clear of hazards --
-- a prize under a ceiling spike is collected by walking into the spike.
function World:restable(tx, ty)
  if tx < 1 or ty < 1 or tx >= self.w - 1 or ty >= self.h - 1 then return false end
  if self:isSolid(tx, ty) then return false end
  for _, row in ipairs({ ty, ty - 1 }) do
    if self:spikeAt(tx, row) or self:isLava(tx, row) or self:isWater(tx, row) then
      return false
    end
  end
  return self:isSolid(tx, ty + 1) or self:isOneway(tx, ty + 1)
end

-- every tile an object may rest on, reachable from a door or a player.
-- Not cached: it is computed once when a boss dies, and a cache would
-- have to be invalidated by every gate, break and crumble in the room.
function World:dropSpots()
  local rest, out = {}, {}
  local function key(tx, ty) return ty * self.w + tx end
  for ty = 1, self.h - 2 do
    for tx = 1, self.w - 2 do
      if self:restable(tx, ty) then rest[key(tx, ty)] = true end
    end
  end

  local seen, queue = {}, {}
  local function push(tx, ty)
    local k = key(tx, ty)
    if rest[k] and not seen[k] then
      seen[k] = true
      queue[#queue + 1] = { tx, ty }
      out[#out + 1] = { tx, ty }
    end
  end
  -- fall down a column from ty until something holds
  local function drop(tx, ty)
    for y = ty, self.h - 2 do
      if self:isSolid(tx, y) then return end
      if rest[key(tx, y)] then push(tx, y) return end
    end
  end

  -- seeds: the mouth of every door, and the ground under every player
  for _, d in pairs(self.doors or {}) do
    for tx = d.x0 - 1, d.x1 + 1 do
      for ty = d.y0 - 1, d.y1 + 1 do
        push(tx, ty)
        drop(tx, ty)
      end
    end
  end
  for _, p in ipairs(self.players or {}) do
    if not p.dead then
      drop(math.floor((p.x + p.w / 2) / T), math.floor((p.y + p.h) / T))
    end
  end

  local head = 1
  while head <= #queue do
    local tx, ty = queue[head][1], queue[head][2]
    head = head + 1
    -- walk, and step off either edge
    for _, dx in ipairs({ -1, 1 }) do
      push(tx + dx, ty)
      drop(tx + dx, ty)
    end
    -- jump: only if the takeoff has headroom for the whole rise
    for dy = 1, JUMP_UP do
      if self:isSolid(tx, ty - dy) then break end
      for dx = -JUMP_ACROSS, JUMP_ACROSS do
        push(tx + dx, ty - dy)
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------
-- THE FLOOR FLOOD (the Crucible's pouring pots)
--
-- Real LAVA tiles, swapped into the arena's floor row and swapped out
-- again -- not a bespoke damage volume. Everything the game already
-- knows about lava then applies for free: the lava law, inLava physics,
-- the Bulwark plate's surface skim, the renderer, and settleDrop, which
-- will refuse to leave a boss reward on a flooded floor.
--
-- The room says which row floods (`floodRow`); the row below it is the
-- grate the lava sits on and drains back through.
-- ------------------------------------------------------------------
local FLOOD_DRAIN = 1.3
local FLOOD_SPREAD = 0.25    -- seconds per tile; lava is a tide, not a switch

-- Lava does not appear, it ARRIVES. A pour opens two fronts at the spout
-- and each crawls one tile every FLOOD_SPREAD seconds until it runs into
-- ground that is higher than the pool -- which is what makes the raised
-- ends of the Crucible's floor mean something. You can see it coming
-- from twenty tiles away, and the tile you are standing on tells you how
-- long you have.
function World:floodFloor(dur, srcX, x0, x1)
  local row = self.room and self.room.floodRow
  if not row then return false end
  local w = self.w
  srcX = math.max(1, math.min(w - 2, math.floor(srcX or (w / 2))))
  x0 = math.max(1, x0 or 1)
  x1 = math.min(w - 2, x1 or (w - 2))

  local blocked = {}
  for _, d in pairs(self.doors or {}) do
    for tx = d.x0 - 1, d.x1 + 1 do blocked[tx] = true end
  end

  if not self.flood then
    self.flood = { row = row, cells = {}, seen = {}, fronts = {},
                   t = dur or 6, level = 1, state = "grow",
                   growT = FLOOD_SPREAD, blocked = blocked, x0 = x0, x1 = x1 }
  else
    -- a second pot pouring into a pool that is still spreading widens it
    -- rather than being swallowed
    self.flood.state = "grow"
    self.flood.t = math.max(self.flood.t, dur or 6)
    self.flood.x0 = math.min(self.flood.x0, x0)
    self.flood.x1 = math.max(self.flood.x1, x1)
  end
  local f = self.flood
  self:wetTile(srcX)
  f.fronts[#f.fronts + 1] = { x = srcX, dir = -1 }
  f.fronts[#f.fronts + 1] = { x = srcX, dir = 1 }
  if G.Audio then G.Audio.sfx("splash") end
  return true
end

-- one tile becomes lava; returns false if this column is not part of the
-- basin, which is how a front learns it has hit higher ground
function World:wetTile(tx)
  local f = self.flood
  if not f then return false end
  if tx < f.x0 or tx > f.x1 then return false end
  if f.blocked[tx] then return false end
  if self.tiles[f.row][tx] ~= AIR and self.tiles[f.row][tx] ~= LAVA then
    return false                     -- solid: the ground is higher here
  end
  if not f.seen[tx] then
    f.seen[tx] = true
    f.cells[#f.cells + 1] = tx
    self.tiles[f.row][tx] = LAVA
  end
  return true
end

function World:floodActive()
  return self.flood ~= nil and self.flood.state ~= "drain"
end

function World:updateFlood(dt)
  local f = self.flood
  if not f then return end

  if f.state ~= "drain" then
    -- Slag burns. That is the point of letting a pot pour: with a dozen
    -- slaglings on the floor and a crucible filling, the strong play may
    -- be to climb and let it happen, and come back down to a clean
    -- arena. A mechanic that is always correct to prevent is not a
    -- decision, it is a chore.
    local top = f.row * T
    for _, e in ipairs(self.entities) do
      if not e.dead and e.kind == "enemy" and not e.heavy and not e.lavaProof
        and e.y + e.h > top and e.y + e.h < top + T * 1.5 then
        local tx = math.floor((e.x + e.w / 2) / T)
        if f.seen[tx] then
          self:fx("burst", e.x + e.w / 2, e.y + e.h,
            { color = "hotcore", n = 8, speed = 120 })
          e.hp = 0
          if e.onDeath then e:onDeath() end
          e.dead = true
        end
      end
    end
  end

  if f.state == "grow" then
    f.growT = f.growT - dt
    if f.growT <= 0 then
      f.growT = FLOOD_SPREAD
      local moving = false
      for _, fr in ipairs(f.fronts) do
        if not fr.done then
          if self:wetTile(fr.x + fr.dir) then
            fr.x = fr.x + fr.dir
            moving = true
            self:fx("trail", fr.x * T + 8, f.row * T + 12,
              { color = "hotcore", r = 2, t = 0.35, vy = -20 })
          else
            fr.done = true
          end
        end
      end
      if not moving then
        f.state = "on"               -- the pool has found its edges
      end
    end
  elseif f.state == "on" then
    f.t = f.t - dt
    if f.t <= 0 then
      f.state = "drain"
      f.t = FLOOD_DRAIN
      for _, tx in ipairs(f.cells) do
        if self.tiles[f.row][tx] == LAVA then self.tiles[f.row][tx] = AIR end
      end
      if G.Audio then G.Audio.sfx("crumble") end
    end
  else
    f.t = f.t - dt
    f.level = math.max(0, f.t / FLOOD_DRAIN)
    -- it goes out the way it should: down, through the grate
    if math.floor(f.t * 30) % 3 == 0 and #f.cells > 0 then
      local tx = f.cells[love.math.random(1, #f.cells)]
      self:fx("trail", tx * T + love.math.random(2, 14), (f.row + 1) * T + 4,
        { color = "magma", r = 1.5, t = 0.5, vy = 60 })
    end
    if f.t <= 0 then self.flood = nil end
  end
end

-- send an active pool down the grate early. The Crucible's vent blast
-- does this when it slams: the link window is five grounded seconds and
-- it has to be five seconds of FLOOR. Stopping a pot from tipping is not
-- enough on its own now that lava takes twenty seconds to cross the
-- room -- a pour that started legally can still be arriving.
function World:drainFlood()
  local f = self.flood
  if not f or f.state == "drain" then return end
  f.state = "drain"
  f.t = FLOOD_DRAIN
  for _, tx in ipairs(f.cells) do
    if self.tiles[f.row][tx] == LAVA then self.tiles[f.row][tx] = AIR end
  end
end

function World:clearFlood()
  local f = self.flood
  if not f then return end
  for _, tx in ipairs(f.cells) do
    if self.tiles[f.row][tx] == LAVA then self.tiles[f.row][tx] = AIR end
  end
  self.flood = nil
end

-- the receding pool, drawn after the tile pass because by then the tiles
-- are already AIR again
function World:drawFlood(g)
  local f = self.flood
  if not f or f.state ~= "drain" then return end
  local h = T * f.level
  for _, tx in ipairs(f.cells) do
    local px, py = tx * T, (f.row + 1) * T - h
    g.setColor(P.magma[1], P.magma[2], P.magma[3], 0.55 + f.level * 0.45)
    g.rectangle("fill", px, py, T, h)
    if h > 1.5 then
      g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], f.level)
      g.rectangle("fill", px, py, T, 1.5)
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- The grate. It is why the floor can hold lava and then lose it
-- downward, and it is drawn only across the BASIN -- the stretch of the
-- flood row that is open -- so the raised ends read as stone banks
-- rather than as more of the same drain.
-- ------------------------------------------------------------------
-- CURTAIN GATE
--
-- Drawn per tile, but deliberately built so a stacked column reads as
-- ONE unbroken sheet of light rather than a pile of glowing bricks:
-- the scanlines are positioned in WORLD space and scroll continuously,
-- so they run straight through the tile seams, and the edge posts are
-- only drawn on the tiles that actually end the run.
-- ------------------------------------------------------------------
-- THE STYLE VOCABULARY.
--
-- Drawn as geometry rather than as the gate sprite offset, because an
-- offset sprite spills into the neighbouring cell and would need
-- clipping -- and love's scissor is in SCREEN space, which means undoing
-- the camera transform and the render scale for every tile of every
-- gate. Procedural bars cost nothing and stay inside their own cell by
-- construction, which is also how the rest of this game draws.
--
-- `p` is the cell's own phase: 0 shut, 1 gone.
-- A GATE THAT OPENS IS RETRACTED, NOT DELETED.
--
-- Every style used to shrink its moving part to nothing and return, so a
-- fully open gate drew zero pixels and the doorway simply forgot it had
-- ever been a doorway. That loses the thing the animation was for: you
-- come back through a room and there is no sign of what you opened, or
-- of what would shut again if the flag flipped.
--
-- So each style now has a PARKED SIZE it never shrinks below -- the
-- mechanism sitting in its housing -- and the parked geometry is pushed
-- to the edges of the cell so it never covers the passage. A 16px cell
-- keeps at least 12 clear in every style, which is wider than the bots
-- (10px) and read as walkable in play.
local GATE_PARK = {
  portcullis = 3,      -- the bars, stacked up under their head
  shutter    = 2,      -- a jamb down each side
  piston     = 3,      -- the plate, sunk in its recess
  blast      = 2,      -- a lintel top and bottom
}

-- PARKED HARDWARE BELONGS ON THE RUN'S ENDS, NOT ON EVERY CELL.
--
-- The first version drew the housing per cell, so a three-tile
-- portcullis parked as three stacked heads and there was no clear cell
-- anywhere in the column -- a doorway you could see through and not walk
-- through. A run retracts into ONE housing: the head of a portcullis is
-- at the top of the whole run, a shutter's jambs are at its two ends.
-- Middle cells keep only the channel the mechanism travels in.
local function runEnd(seq, which)
  if not seq or seq.n <= 1 then return true end       -- a lone cell is both ends
  if which == "first" then return seq.i == 1 end
  return seq.i == seq.n
end

function World:drawGateStyle(g, style, px, py, p, seq)
  local rust, dark, steel = P.rust, P.dark, P.slate
  local open = p
  if style == "portcullis" then
    -- retracts UPWARD into the head at the top of the run, teeth last
    local head = runEnd(seq, "first")
    local park = head and GATE_PARK.portcullis or 0
    local h = math.max(park, T * (1 - open))
    if h > 0.5 then
      g.setColor(dark[1], dark[2], dark[3], 0.9)
      g.rectangle("fill", px, py, T, h)
      g.setColor(rust)
      for b = 0, 3 do g.rectangle("fill", px + 1 + b * 4, py, 2, h) end
    end
    -- the CHANNEL the bars run in, on every cell: 1px each side, so an
    -- open gate still shows exactly where the bars come down and 14 of
    -- the 16 pixels stay clear
    g.setColor(steel[1], steel[2], steel[3], 0.45)
    g.rectangle("fill", px, py, 1, T)
    g.rectangle("fill", px + T - 1, py, 1, T)
    -- the HEAD, only at the top of the run, and always
    if head then
      g.setColor(steel)
      g.rectangle("fill", px, py, T, 2)
    end
    -- the teeth, on the last cell of the run and only while it is down
    if runEnd(seq, "last") and h > park + 3 then
      g.setColor(rust)
      for b = 0, 3 do
        g.polygon("fill", px + 1 + b * 4, py + h - 3,
          px + 3 + b * 4, py + h, px + 3 + b * 4, py + h - 3)
      end
    end

  elseif style == "shutter" then
    -- parts from the centre outward, into a jamb at each END of the run
    --
    -- ...and for a HORIZONTAL run that means the two OUTER edges, not
    -- both edges of both end cells. Parking a jamb on each side of the
    -- first and last tile left four posts standing in a three-tile
    -- opening -- a fence, not a parted shutter.
    local horiz = seq and seq.n > 1 and not seq.vert
    local first, last = runEnd(seq, "first"), runEnd(seq, "last")
    local parkL = ((horiz and first) or (not horiz and (first or last)))
                  and GATE_PARK.shutter or 0
    local parkR = ((horiz and last) or (not horiz and (first or last)))
                  and GATE_PARK.shutter or 0
    local moving = (T / 2) * (1 - open)
    local wl, wr = math.max(parkL, moving), math.max(parkR, moving)
    g.setColor(dark[1], dark[2], dark[3], 0.9)
    if wl > 0.5 then g.rectangle("fill", px, py, wl, T) end
    if wr > 0.5 then g.rectangle("fill", px + T - wr, py, wr, T) end
    g.setColor(steel)
    if wl > 0.5 then g.rectangle("fill", px + wl - 1, py, 1, T) end
    if wr > 0.5 then g.rectangle("fill", px + T - wr, py, 1, T) end
    -- NO RAIL ACROSS THE MIDDLE CELLS. A shutter usually runs
    -- HORIZONTALLY -- a one-tile-tall hatch -- and a 1px rail on the top
    -- and bottom of every cell seals it: there is then no full-height
    -- column anywhere in the run and nothing can pass through a gate
    -- that is supposed to be open. The jambs at the two ends are the
    -- hardware; the middle is the hole.

  elseif style == "piston" then
    -- slides sideways into a recess it stays visible in
    local home = runEnd(seq, "first")
    local park = home and GATE_PARK.piston or 0
    local w = math.max(park, T * (1 - open))
    if w > 0.5 then
      g.setColor(dark[1], dark[2], dark[3], 0.9)
      g.rectangle("fill", px, py, w, T)
      g.setColor(steel)
      g.rectangle("fill", px + w - 2, py, 2, T)
      g.setColor(rust[1], rust[2], rust[3], 0.7)
      g.rectangle("fill", px, py + T / 2 - 1, w, 2)
    end
    -- same reason as the shutter: the plate parked in its recess at the
    -- head of the run is the cue, and the rest of the run stays clear.
    -- The far end keeps the jamb the plate seals against, so the travel
    -- reads as a distance rather than as a lump on one side.
    if runEnd(seq, "last") then
      g.setColor(steel[1], steel[2], steel[3], 0.5)
      g.rectangle("fill", px + T - 1, py, 1, T)
    end

  elseif style == "blast" then
    -- two halves part vertically, and they SLAM: the last of the travel
    -- happens in the first fifth of the phase, so it stops hard.
    local topEnd, botEnd = runEnd(seq, "first"), runEnd(seq, "last")
    local e = 1 - (1 - open) * (1 - open)
    local moving = (T / 2) * (1 - e)
    local ht = math.max(topEnd and GATE_PARK.blast or 0, moving)
    local hb = math.max(botEnd and GATE_PARK.blast or 0, moving)
    g.setColor(dark[1], dark[2], dark[3], 0.95)
    if ht > 0.5 then g.rectangle("fill", px, py, T, ht) end
    if hb > 0.5 then g.rectangle("fill", px, py + T - hb, T, hb) end
    g.setColor(steel)
    if ht > 0.5 then g.rectangle("fill", px, py + ht - 1, T, 1) end
    if hb > 0.5 then g.rectangle("fill", px, py + T - hb, T, 1) end
    -- hazard stripes on the parked lintels: this is the one that kills
    -- you if it shuts, and it should still say so when it is open
    g.setColor(rust[1], rust[2], rust[3], 0.75)
    for b = 0, 3 do
      if ht > 0.5 then g.rectangle("fill", px + b * 4 + (b % 2), py, 2, 1) end
      if hb > 0.5 then g.rectangle("fill", px + b * 4 + (b % 2), py + T - 1, 2, 1) end
    end
    -- the jamb the halves slide against
    g.setColor(steel[1], steel[2], steel[3], 0.45)
    g.rectangle("fill", px, py, 1, T)
    g.rectangle("fill", px + T - 1, py, 1, T)
  end
  g.setColor(1, 1, 1, 1)
end

function World:drawCurtainTile(g, px, py, tx, ty, open)
  open = open or 0
  local function curtainAt(ax, ay)
    if self:tileAt(ax, ay) ~= GATE then return false end
    return self.gateStyles[idx(ax, ay)] == "curtain"
    -- GEOMETRY, NOT STATE. This used to also require the neighbour's
    -- flag to be unset, so the moment a run opened every cell stopped
    -- seeing its neighbours and a horizontal sheet decided it was
    -- vertical -- the posts jumped to the wrong two ends on the last
    -- frame of the animation.
  end
  local up, down = curtainAt(tx, ty - 1), curtainAt(tx, ty + 1)
  local left, right = curtainAt(tx - 1, ty), curtainAt(tx + 1, ty)
  -- A curtain hangs across whatever it is blocking, so a run laid out
  -- left-to-right has to draw as a sheet lying flat and not as three
  -- unrelated bars standing next to each other. A lone tile is vertical.
  local vert = (up or down) or not (left or right)
  local pulse = (0.55 + math.sin(G.time * 5 + (vert and tx or ty) * 0.7) * 0.15)
                * (1 - open)
  local period, speed = 11, 26
  local phase = (G.time * speed) % period

  g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.20 * pulse)
  if vert then g.rectangle("fill", px + 1, py, T - 2, T)
  else g.rectangle("fill", px, py + 1, T, T - 2) end

  if vert then
    -- the bright core, a narrow column down the middle of the tile
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.55 * pulse)
    g.rectangle("fill", px + T / 2 - 3, py, 6, T)
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.85 * pulse)
    g.rectangle("fill", px + T / 2 - 1, py, 2, T)
    -- scanlines positioned in WORLD space, so they run straight through
    -- the tile seams and a stacked run reads as one unbroken sheet
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.5)
    local first = math.floor((py - phase) / period) * period + phase
    for sy = first, py + T, period do
      if sy >= py and sy < py + T then
        g.rectangle("fill", px + 2, sy, T - 4, 1)
      end
    end
  else
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.55 * pulse)
    g.rectangle("fill", px, py + T / 2 - 3, T, 6)
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.85 * pulse)
    g.rectangle("fill", px, py + T / 2 - 1, T, 2)
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.5)
    local first = math.floor((px - phase) / period) * period + phase
    for sx = first, px + T, period do
      if sx >= px and sx < px + T then
        g.rectangle("fill", sx, py + 2, 1, T - 4)
      end
    end
  end

  -- posts cap the ends of the run, so it reads as hardware and not fog
  g.setColor(P.slate)
  if vert then
    if not up then g.rectangle("fill", px + 2, py - 1, T - 4, 3) end
    if not down then g.rectangle("fill", px + 2, py + T - 2, T - 4, 3) end
  else
    if not left then g.rectangle("fill", px - 1, py + 2, 3, T - 4) end
    if not right then g.rectangle("fill", px + T - 2, py + 2, 3, T - 4) end
  end
  g.setColor(1, 1, 1, 1)
end

function World:drawGrate(g)
  local row = self.room and self.room.floodRow
  if not row then return end
  local gy = (row + 1) * T
  local tx0 = math.max(0, math.floor(Cam.x / T) - 1)
  local tx1 = math.min(self.w - 1, math.floor((Cam.x + G.VW) / T) + 1)
  for tx = tx0, tx1 do
    if self:tileAt(tx, row + 1) == SOLID and self:tileAt(tx, row) ~= SOLID then
      local px = tx * T
      g.setColor(0, 0, 0, 0.55)
      g.rectangle("fill", px, gy + 1, T, 4)
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.85)
      for b = 0, 3 do
        g.rectangle("fill", px + 1 + b * 4, gy + 1, 2, 4)
      end
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      g.rectangle("fill", px, gy, T, 1)
      -- the fire underneath, visible between the bars
      local glow = 0.10 + math.sin(G.time * 2 + tx * 0.7) * 0.05
      if self.flood then glow = glow + 0.35 * (self.flood.level or 1) end
      g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], glow)
      g.rectangle("fill", px, gy + 1, T, 4)
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- BEAMS (the Crystal Hollows' circuits)
--
-- Traced in TILE space, on change rather than every frame: a beam only
-- moves when an emitter wakes, a rotor turns or a panel is shoved, and
-- there is no reason to walk the room sixty times a second to discover
-- that nothing happened. What IS checked every frame is overlap -- the
-- things standing in a beam move even when the beam does not.
--
-- A beam burns players on the same terms as lava (see LAVA_DMG in
-- player.lua) and kills any non-heavy enemy it touches, which is what
-- makes routing one a weapon rather than only a key.
-- ------------------------------------------------------------------
local BDX = { 1, 0, -1, 0 }
local BDY = { 0, 1, 0, -1 }
local MIRROR = {
  f = { 4, 3, 2, 1 },
  b = { 2, 1, 4, 3 },
}
local BEAM_STEPS = 240        -- a hard stop; see the visited-set below

function World:beamTileOf(e)
  return math.floor((e.x + e.w / 2) / T), math.floor((e.y + e.h / 2) / T)
end

function World:traceBeams()
  self.beamSegs = {}
  self.beamDirty = false
  local mirrors, nodes, sources = {}, {}, {}
  local function k(tx, ty) return ty * 4096 + tx end
  for _, e in ipairs(self.entities) do
    if not e.dead then
      if e.beamMirror or e.beamNode then
        local tx, ty = self:beamTileOf(e)
        mirrors[k(tx, ty)] = e
      end
      if e.beamEmit and e.on then sources[#sources + 1] = e end
      if e.beamNode then nodes[#nodes + 1] = e; e.lit = 0 end
    end
  end
  if #sources == 0 then
    for _, n in ipairs(nodes) do n.lit = 0 end
    return
  end

  -- Each segment records the EMITTER that produced it. Without that, a
  -- thing struck by a beam has no way to reach back and switch it off --
  -- which is what the Conductor's shield needs: the beam that shatters
  -- it must be spent doing so, or it stands in the column afterwards and
  -- the players cannot get underneath to use the window they just won.
  for _, src in ipairs(sources) do
    local tx, ty = self:beamTileOf(src)
    local dir = src.dir
    -- A visited (tile, direction) set makes a loop terminate the FIRST
    -- time it closes rather than after 240 wasted steps -- and a loop is
    -- easy to build by accident with two facing mirrors.
    local seen = {}
    local sx, sy = tx, ty
    for _ = 1, BEAM_STEPS do
      local sig = k(tx, ty) * 8 + dir
      if seen[sig] then break end
      seen[sig] = true
      local nx, ny = tx + BDX[dir], ty + BDY[dir]
      if self:isSolid(nx, ny) then
        self.beamSegs[#self.beamSegs + 1] =
          { sx * T + T / 2, sy * T + T / 2, tx * T + T / 2, ty * T + T / 2,
            src = src }
        break
      end
      local hit = mirrors[k(nx, ny)]
      if hit and hit.beamNode then
        hit.lit = (hit.lit or 0) + 1
        self.beamSegs[#self.beamSegs + 1] =
          { sx * T + T / 2, sy * T + T / 2, nx * T + T / 2, ny * T + T / 2,
            src = src }
        break
      elseif hit and hit.beamMirror then
        self.beamSegs[#self.beamSegs + 1] =
          { sx * T + T / 2, sy * T + T / 2, nx * T + T / 2, ny * T + T / 2,
            src = src }
        dir = MIRROR[hit.mirror or "f"][dir]
        tx, ty = nx, ny
        sx, sy = nx, ny
      else
        tx, ty = nx, ny
      end
    end
  end

  for _, n in ipairs(nodes) do
    if not n.latched and (n.lit or 0) >= n.need then n:satisfy() end
  end
end

function World:updateBeams(dt)
  if self.beamDirty then self:traceBeams() end
  local segs = self.beamSegs
  if not segs or #segs == 0 then return end
  self.beamBurnT = (self.beamBurnT or 0) - dt
  local tick = self.beamBurnT <= 0
  if tick then self.beamBurnT = 0.25 end
  for _, s in ipairs(segs) do
    local x0, y0 = math.min(s[1], s[3]) - 3, math.min(s[2], s[4]) - 3
    local bw, bh = math.abs(s[3] - s[1]) + 6, math.abs(s[4] - s[2]) + 6
    for _, e in ipairs(self.entities) do
      if not e.dead and U.aabb(x0, y0, bw, bh, e.x, e.y, e.w, e.h) then
        if e.kind == "enemy" and not e.heavy and not e.harmless then
          self:fx("burst", e.x + e.w / 2, e.y + e.h / 2,
            { color = "cyan", n = 10, speed = 130 })
          e.hp = 0
          if e.onDeath then e:onDeath() end
          e.dead = true
        elseif e.beamStrike then
          -- Heavy things are immune to the outright kill above, which
          -- is correct -- a beam should not delete a boss. But something
          -- heavy may still want to KNOW it is standing in one. The
          -- Conductor's shield is the whole reason this hook exists.
          e:beamStrike(s, dt)
        end
      end
    end
    if tick then
      for _, p in ipairs(self.players) do
        if not p.dead and not p.downed and not p.idle
          and U.aabb(x0, y0, bw, bh, p.x, p.y, p.w, p.h) then
          p.invuln = 0
          p:takeDamage(5, s[1], { pierceDash = true, lava = true })
          self:fx("burst", p.x + p.w / 2, p.y + p.h / 2,
            { color = "cyan", n = 8, speed = 120 })
        end
      end
    end
  end
end

function World:drawBeams(g)
  local segs = self.beamSegs
  if not segs then return end
  for _, s in ipairs(segs) do
    local pulse = 0.75 + math.sin(G.time * 12 + s[1] * 0.05) * 0.25
    g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.35)
    g.setLineWidth(6)
    g.line(s[1], s[2], s[3], s[4])
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.9)
    g.setLineWidth(3)
    g.line(s[1], s[2], s[3], s[4])
    g.setColor(P.white[1], P.white[2], P.white[3], pulse)
    g.setLineWidth(1)
    g.line(s[1], s[2], s[3], s[4])
  end
  g.setLineWidth(1)
  g.setColor(1, 1, 1, 1)
end

-- is an object already sitting somewhere the rule allows? Used to vet
-- spots recorded in an existing save by the old placer.
function World:dropLegal(x, y, w, h)
  local ty = math.floor((y + h - 1) / T)
  for tx = math.floor(x / T), math.floor((x + w - 1) / T) do
    if not self:restable(tx, ty) then return false end
  end
  return true
end

-- place a w x h object as near (x,y) as the rule allows
function World:settleDrop(x, y, w, h)
  local span = math.max(1, math.ceil(w / T))
  local cx, cy = x + w / 2, y + h / 2
  local best, bestD
  for _, s in ipairs(self:dropSpots()) do
    local tx, ty = s[1], s[2]
    -- the whole footprint has to be on good ground, not just its centre
    local wide = true
    for i = 0, span - 1 do
      if not self:restable(tx + i, ty) then wide = false break end
    end
    if wide then
      local sx = tx * T + (span * T - w) / 2
      local sy = (ty + 1) * T - h
      local d = (sx + w / 2 - cx) ^ 2 + (sy + h / 2 - cy) ^ 2
      if not bestD or d < bestD then best, bestD = { sx, sy }, d end
    end
  end
  if best then return best[1], best[2] end
  for _, p in ipairs(self.players or {}) do
    if not p.dead then return p.x + p.w / 2 - w / 2, p.y + p.h - h end
  end
  return self.w * T / 2 - w / 2, self.h * T / 2
end

-- ------------------------------------------------------------------
-- Room loading
-- ------------------------------------------------------------------
-- Published so the editor's save layer can drop a single room after
-- writing it. A local-only cache made RoomIO.invalidate a silent no-op:
-- package.loaded was cleared, this was not, and the saved edit did not
-- come back on the next load.
World.roomCache = {}
local roomCache = World.roomCache
function World.getRoomDef(id)
  if not roomCache[id] then
    roomCache[id] = require("src.data.rooms." .. id)
    roomCache[id].id = id
  end
  return roomCache[id]
end

-- ------------------------------------------------------------------
-- THE GRID PARSER, and everything derived from it.
-- ------------------------------------------------------------------
-- Lifted out of World:load so that there is exactly ONE of it.
--
-- The editor's live resize used to rebuild World.tiles by hand from the
-- character grid, which looked equivalent and was not: the FOUR passes
-- below all read the finished tile array, and skipping them cost water
-- (the settle pass turns the air cell a fish spawns in back into water,
-- so every enemy in a lake left an air bubble behind), the floor and
-- ceiling decor, the water-depth shading, and every door's bounding box
-- and derived side.
--
-- Returns the spawn characters it found, which only World:load cares
-- about -- the editor keeps the entities it already has.
function World:parseGrid(lines, def, roomId)
  self.h = #lines
  self.w = #lines[1]
  self.tiles = {}
  self.doors = {}
  self.gateFlags = {}
  self.gateStyles = {}
  self.gateT = {}          -- flag -> 0..1, how far this mechanism has run
  self.gateSeq = {}        -- cell -> { i = order in its run, n = run length }
  self.iceSet = {}
  self.hardSet = {}
  local spawnsByChar = {}
  for ty = 0, self.h - 1 do
    self.tiles[ty] = {}
    local line = lines[ty + 1]
    if #line ~= self.w then
      error(roomId .. ": row " .. (ty + 1) .. " width " .. #line .. " ~= " .. self.w)
    end
    for tx = 0, self.w - 1 do
      local ch = line:sub(tx + 1, tx + 2 - 1)
      local code = CHAR_TILE[ch]
      if code then
        self.tiles[ty][tx] = code
        if ch == "_" then self.iceSet[idx(tx, ty)] = true end
        -- which FLAG opens this particular breakable, if any
        if HARD_CHARS[ch] then self.hardSet[idx(tx, ty)] = HARD_CHARS[ch] end
      elseif DOOR_CHARS[ch] then
        self.tiles[ty][tx] = AIR
        local d = self.doors[ch]
        if not d then
          d = { x0 = tx, y0 = ty, x1 = tx, y1 = ty }
          self.doors[ch] = d
        else
          d.x0, d.y0 = math.min(d.x0, tx), math.min(d.y0, ty)
          d.x1, d.y1 = math.max(d.x1, tx), math.max(d.y1, ty)
        end
      elseif GATE_CHARS[ch] then
        self.tiles[ty][tx] = GATE
        local flag = def.gates and def.gates[ch]
        self.gateFlags[idx(tx, ty)] = flag or ("gate_" .. roomId .. "_" .. ch)
        -- A CURTAIN is a gate made of light instead of stone. Mechanically
        -- identical -- solid until its flag is set, gone after -- but it
        -- reads as part of the circuit that opens it, which is the whole
        -- point in a zone where the lock, the key and the door are all
        -- the same beam. `gateStyle = { H = "curtain" }` in the room.
        if def.gateStyle and def.gateStyle[ch] then
          self.gateStyles[idx(tx, ty)] = def.gateStyle[ch]
        end
      else
        -- entity spawn char
        self.tiles[ty][tx] = AIR
        spawnsByChar[#spawnsByChar + 1] = { ch = ch, tx = tx, ty = ty }
      end
    end
  end

  -- water/lava settle: entity-spawn cells inside a liquid body become
  -- liquid (no floating air bubbles where a fish or chest was placed)
  for _ = 1, 3 do
    for ty = 0, self.h - 1 do
      for tx = 0, self.w - 1 do
        if self.tiles[ty][tx] == AIR then
          local above = ty > 0 and self.tiles[ty - 1][tx] or SOLID
          local left = tx > 0 and self.tiles[ty][tx - 1] or SOLID
          local right = tx < self.w - 1 and self.tiles[ty][tx + 1] or SOLID
          if above == WATER or (left == WATER and right == WATER) then
            self.tiles[ty][tx] = WATER
          elseif above == LAVA or (left == LAVA and right == LAVA) then
            self.tiles[ty][tx] = LAVA
          end
        end
      end
    end
  end

  -- decorations: seeded per room, drawn behind entities
  local drng = love.math.newRandomGenerator(#roomId * 7349 + (roomId:byte(1) or 65) * 131)
  self.decor = {}
  for ty = 0, self.h - 1 do
    for tx = 0, self.w - 1 do
      if self.tiles[ty][tx] == SOLID then
        local above = self:tileAt(tx, ty - 1)
        if above == AIR and drng:random() < 0.4 then
          self.decor[#self.decor + 1] = {
            kind = "floor", x = tx * 16 + drng:random(1, 9), y = ty * 16,
            v = drng:random(3), ph = drng:random() * 6.28,
            s = 0.7 + drng:random() * 0.7,
          }
        end
        local below = self:tileAt(tx, ty + 1)
        if below == AIR and drng:random() < 0.2 then
          self.decor[#self.decor + 1] = {
            kind = "ceil", x = tx * 16 + drng:random(2, 12), y = (ty + 1) * 16,
            v = drng:random(3), ph = drng:random() * 6.28,
            s = 0.7 + drng:random() * 0.8,
          }
        end
      end
    end
  end

  -- water depth per tile (for depth-shaded rendering)
  self.waterDepth = {}
  for tx = 0, self.w - 1 do
    local depth = 0
    for ty = 0, self.h - 1 do
      if self.tiles[ty][tx] == WATER then
        depth = depth + 1
        self.waterDepth[idx(tx, ty)] = depth
      else
        depth = 0
      end
    end
  end

  -- WHERE EACH CELL SITS IN ITS OWN RUN, so a column retracts in order
  -- rather than all at once. Computed here, once: it is a property of
  -- the geometry and never changes.
  do
    local seen = {}
    for ty = 0, self.h - 1 do
      for tx = 0, self.w - 1 do
        local i = idx(tx, ty)
        if self.tiles[ty][tx] == GATE and not seen[i] then
          local cells = {}
          local vert = self:tileAt(tx, ty - 1) == GATE
            or self:tileAt(tx, ty + 1) == GATE
          if vert then
            local y0 = ty
            while self:tileAt(tx, y0 - 1) == GATE do y0 = y0 - 1 end
            local y = y0
            while self:tileAt(tx, y) == GATE do
              cells[#cells + 1] = idx(tx, y)
              y = y + 1
            end
          else
            local x0 = tx
            while self:tileAt(x0 - 1, ty) == GATE do x0 = x0 - 1 end
            local x = x0
            while self:tileAt(x, ty) == GATE do
              cells[#cells + 1] = idx(x, ty)
              x = x + 1
            end
          end
          for k, ci in ipairs(cells) do
            seen[ci] = true
            self.gateSeq[ci] = { i = k, n = #cells, vert = vert }
          end
        end
      end
    end
  end

  -- SEED THE MECHANISMS TO MATCH THE WORLD AS FOUND.
  --
  -- Lazily seeding this on the first update was wrong in the one case
  -- that matters: a gate whose flag is ALREADY set when you walk in got
  -- initialised to "open" on frame one and never animated. Worse, it
  -- made the animation depend on when the first update happened to run.
  -- A gate you have already opened is open when you come back; a gate
  -- that opens while you are standing there animates. Seeding at parse
  -- is what separates those two.
  self.gateT = {}
  for _, flag in pairs(self.gateFlags) do
    if self.gateT[flag] == nil then
      self.gateT[flag] = self:gateOpenFlag(flag) and 1 or 0
    end
  end

  -- CLASSIFY DOORS. Position derives it; `doorKind` overrides it.
  --
  -- The side used to be derived from the bounding box and nothing else,
  -- with the precedence left > right > top > bottom > portal. That is a
  -- good default and a bad law: it means a door in a corner is silently
  -- a LEFT door however you meant it, and it means an interior door can
  -- never pair with a wall door, because the pairing rule was written
  -- against the derivation rather than against intent.
  --
  -- `doorKind = { B = "portal" }` states it instead. The engine cares
  -- because `edge` decides where an arriving bot is PUT, which way it is
  -- nudged, and whether the door draws a frame or a portal ring -- so a
  -- declared kind that the engine ignored would be a note-to-self, not a
  -- setting. checkdoors enforces the half that has to stay true: a door
  -- calling itself a WALL door has to actually be on that wall.
  for ch, d in pairs(self.doors) do
    if d.x0 == 0 then d.edge = "left"
    elseif d.x1 == self.w - 1 then d.edge = "right"
    elseif d.y0 == 0 then d.edge = "top"
    elseif d.y1 == self.h - 1 then d.edge = "bottom" end
    local declared = def.doorKind and def.doorKind[ch]
    if declared == "portal" then d.edge = nil
    elseif declared then d.edge = declared end
    d.link = def.links and def.links[ch]
    -- A SEALED DOOR: `links = { B = { "room", "D", req = "boss_crucible" } }`.
    -- Used for the boss-room shortcuts, which must not be walkable until
    -- the boss is actually dead -- otherwise you can brush the shortcut on
    -- the way in and skip the fight. Tile gates cannot express this: the
    -- reachability model treats a jump ARC over a door as using it, so a
    -- two-tile pocket is not sealable in the model no matter how it is
    -- built. A requirement on the door itself is exact.
    d.req = d.link and d.link.req
  end

  return spawnsByChar
end

function World:load(roomId, doorChar, keepPlayers)
  local def = World.getRoomDef(roomId)
  self.room = def
  -- ENERGY CELLS ARE ZONE-SCOPED, not room-scoped (see Cell in
  -- pickup.lua). Room-scoped would be a grind -- walk out, walk back,
  -- drain it again -- and run-scoped would make every cell a one-shot
  -- you regret spending. Every path that changes rooms comes through
  -- here (doors, teleport pads, respawn, loading a save), so this is the
  -- only place that has to know the rule.
  if G.run and self.zone ~= def.zone then G.run.usedCells = {} end
  self.zone = def.zone
  self.entities = {}
  self.addQueue = {}
  self.particles = {}
  self.beamSegs = {}
  self.beamDirty = true
  self.crumbles = {}
  self.broken = {}
  self.pendingTransition = nil
  self.bossActive = nil
  self.depthMap = nil          -- rebuilt per room by World:solidDepth

  local lines = {}
  for line in def.map:gmatch("[^\n]+") do
    if #line > 0 then lines[#lines + 1] = line end
  end
  local spawnsByChar = self:parseGrid(lines, def, roomId)

  -- spawn entities
  for _, s in ipairs(spawnsByChar) do
    local spec = def.key and def.key[s.ch]
    if spec then
      self:spawnFromSpec(spec, s.tx, s.ty)
    else
      error(roomId .. ": unmapped map char '" .. s.ch .. "' at " ..
        s.tx .. "," .. s.ty)
    end
  end

  -- Restore movable beam parts to where the players left them. This
  -- runs over the add queue, before the first frame, so the beam is
  -- traced through the restored layout and a solved room looks solved
  -- the instant it draws.
  if G.run then
    require "src.entities.props"
    for _, e in ipairs(self.addQueue) do
      if e.restoreMech then
        local st = Props.mechLoad(e, roomId)
        if st then e:restoreMech(st) end
      end
    end
  end

  -- persistent boss remains: uncollected reward drops + corpses live in
  -- the run, so they survive leaving the zone, saving, and reloading.
  -- A drop written by the old placer may be sitting in a spike bed; that
  -- is recorded in the save, so re-settling it here is the only thing
  -- that gets an existing playthrough its prize back.
  if G.run then
    for _, d in ipairs((G.run.pendingDrops or {})[roomId] or {}) do
      if not self:dropLegal(d.x, d.y, 14, 12) then
        d.x, d.y = self:settleDrop(d.x, d.y, 14, 12)
      end
      local e = Entity.make("reward", d.x, d.y, { "reward", d.spec })
      if e and e ~= true then self.entities[#self.entities + 1] = e end
    end
    for bossId, c in pairs(G.run.bossCorpses or {}) do
      if c.room == roomId then
        if not self:dropLegal(c.x, c.y, 34, 16) then
          c.x, c.y = self:settleDrop(c.x, c.y, 34, 16)
        end
        local e = Entity.make("bosscorpse", c.x, c.y, { "bosscorpse", bossId })
        if e and e ~= true then self.entities[#self.entities + 1] = e end
      end
    end
  end

  Cam.setRoom(self.w * T, self.h * T)
  -- COOP-PLAN 13.3. An arena keeps the PLAIN MIDPOINT. checksight.py
  -- proves every boss visible with camY = clamp(centreY - VH/2, ...),
  -- and favouring the upper bot would let a hovering Lu drag the frame
  -- up and push a grounded boss off the bottom of the screen. This is
  -- the only place Cam.favourTop is written.
  Cam.favourTop = not (self.room and self.room.arena)
  PH.world = self

  -- position players at the entry door
  self.spawnFixed = nil
  if keepPlayers and #self.players > 0 then
    local d = doorChar and self.doors[doorChar]
    for i, p in ipairs(self.players) do
      self.entities[#self.entities + 1] = p
      if d then
        local px = (d.x0 + (d.x1 - d.x0) / 2) * T + T / 2 - p.w / 2
        local py = (d.y1 + 1) * T - p.h - 0.5
        if d.edge == "left" then px = (d.x1 + 1) * T + 2 + (i - 1) * 4
        elseif d.edge == "right" then px = d.x0 * T - p.w - 2 - (i - 1) * 4
        elseif d.edge == "top" then py = (d.y1 + 1) * T + 2
        elseif d.edge == "bottom" then
          -- arriving up out of a floor shaft: climb the shaft to its mouth
          -- and stand on solid ground BESIDE the opening, never hovering
          -- over the hole we came from
          py = d.y0 * T - p.h - 2
          local best, bestRow
          for standRow = d.y0 - 1, math.max(2, d.y0 - 9), -1 do
            for off = 0, 4 do
              for _, dir in ipairs({ -1, 1 }) do
                local tx = (dir < 0 and d.x0 - 1 - off or d.x1 + 1 + off)
                if tx >= 1 and tx < self.w - 1 then
                  -- the walk-back corridor toward the shaft must be open:
                  -- footing on the far side of a wall or closed gate is a
                  -- sealed pocket, not an arrival spot
                  local corridor = true
                  local edge = (dir < 0 and d.x0 - 1 or d.x1 + 1)
                  local step = (dir < 0 and 1 or -1)
                  local cx = tx + step
                  while corridor and ((dir < 0 and cx <= edge)
                      or (dir > 0 and cx >= edge)) do
                    if self:isSolid(cx, standRow) then corridor = false end
                    cx = cx + step
                  end
                  if corridor
                    and self:isSolid(tx, standRow) == false
                    and (self:isSolid(tx, standRow + 1) or self:isOneway(tx, standRow + 1))
                    and not self:isSolid(tx, standRow - 1)
                    and not self:isLava(tx, standRow)
                    and not self:isWater(tx, standRow)
                    and not self:spikeAt(tx, standRow) then
                    best, bestRow = tx, standRow
                    break
                  end
                end
              end
              if best then break end
            end
            if best then break end
          end
          if best then
            px = best * T + (T - p.w) / 2
            py = bestRow * T + T - p.h - 0.5
          end
        end
        p.x = px + (i - 1) * 6
        p.y = py
        p.vx, p.vy = 0, 0
        if d.edge == "top" then p.vy = 40 end
        -- grace: the door we arrived through cannot re-trigger until the
        -- player has fully left its rectangle once
        p.doorGrace = doorChar
      end
      if not d then
        -- doorless load (teleport-style): coordinates from the previous
        -- room may be meaningless here -- clamp into this room first
        -- (the caller is expected to reposition, e.g. onto a telepad)
        p.x = math.max(T + 2, math.min(p.x, self.w * T - T - 2 - p.w))
        p.y = math.max(T + 2, math.min(p.y, self.h * T - T - 2 - p.h))
      end
      -- safety net: never leave a player embedded in solid tiles.
      local PH2 = require "src.physics"
      if PH2.boxBlocked(p.x, p.y, p.w, p.h) then
        local placed = self:ensureFree(p)
        self.spawnFixed = (self.spawnFixed or "") .. (doorChar or "?") .. i
          .. (placed and "" or "!")
      end
      p.roomEnterProtect = 0.3
    end
    local p1 = self.players[1]
    if p1 then Cam.jumpTo(p1.x, p1.y) end
  end

  -- mark visited for map
  if G.run then
    G.run.visited[roomId] = true
    G.run.room = roomId
    -- THE CAMP FREEZES BEHIND YOU. Taking the Ember no longer empties
    -- Ember Camp on the spot -- everyone gathers to watch instead, which
    -- is the whole point of the scene. The freeze lands the moment you
    -- carry it out of the zone, so the keepers are what you find when you
    -- come back rather than what you walk away from.
    if G.run.flags.ember_taken and not G.run.flags.camp_frozen
      and self.zone ~= "camp" then
      G.run.flags.camp_frozen = true
    end
    G.run.door = doorChar
  end

  -- music
  local track = self:musicName(def.music)
  if track and G.Audio then G.Audio.playMusic(track) end

  if def.onEnter then def.onEnter(self) end
end

-- Can a player standing at tile (tx, ty) reach any linked door from
-- there? Tile BFS through non-solid cells (gates honor current flags).
-- Used to refuse respawn/arrival spots inside sealed pockets.
function World:canEscape(tx, ty)
  local doorTiles = {}
  local any = false
  for ch, d in pairs(self.doors) do
    if d.link then
      any = true
      for yy = d.y0, d.y1 do
        for xx = d.x0, d.x1 do
          doorTiles[yy * 1000 + xx] = true
        end
      end
    end
  end
  if not any then return true end
  local seen = { [ty * 1000 + tx] = true }
  local q = { { tx, ty } }
  local head, n = 1, 1
  while head <= n and n < 800 do
    local cx, cy = q[head][1], q[head][2]
    head = head + 1
    if doorTiles[cy * 1000 + cx] then return true end
    for _, dxy in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, ny = cx + dxy[1], cy + dxy[2]
      local key = ny * 1000 + nx
      if nx >= 0 and ny >= 0 and nx < self.w and ny < self.h
          and not seen[key] and not self:isSolid(nx, ny) then
        seen[key] = true
        n = n + 1
        q[n] = { nx, ny }
      end
    end
  end
  return false
end

-- Relocate an entity out of solid terrain: spiral search (favoring up,
-- then sideways) for the nearest free spot. Used by door spawns AND any
-- teleport-style verb (warp-to-partner, recall) so nobody is ever left
-- embedded in a wall. Returns true if the entity ends up in free space.
function World:ensureFree(p)
  local PH2 = require "src.physics"
  if not PH2.boxBlocked(p.x, p.y, p.w, p.h) then return true end
  local candidates = {}
  for r = 1, 8 do
    for dy = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          candidates[#candidates + 1] = { dx = dx, dy = dy,
            score = r * 10 + (dy > 0 and 5 or 0) }
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return a.score < b.score end)
  for _, c in ipairs(candidates) do
    local nx, ny = p.x + c.dx * T, p.y + c.dy * T
    if nx > 0 and ny > 0 and nx + p.w < self.w * T and ny + p.h < self.h * T
      and not PH2.boxBlocked(nx, ny, p.w, p.h) then
      p.x, p.y = nx, ny
      return true
    end
  end
  return false
end

function World:spawnFromSpec(spec, tx, ty)
  local parts = U.split(spec, ":")
  local name = parts[1]
  local x, y = tx * T, ty * T
  local ent, err = Entity.make(name, x, y, parts)
  if not ent then error((self.room and self.room.id or "?") .. ": " .. err) end
  if ent ~= true then
    -- The spawn tile is the only identity a prop has that survives a
    -- reload, so it is what mechanism persistence is keyed on. Set it
    -- for everything; only the parts that implement :restoreMech care.
    ent.mechKey = tx .. "," .. ty
    self:add(ent)
  end
  return ent
end

function World:add(ent)
  self.addQueue[#self.addQueue + 1] = ent
  return ent
end

function World:setPlayers(players)
  self.players = players
end

-- ------------------------------------------------------------------
-- Update
-- ------------------------------------------------------------------
-- WHICH CELL MOVES WHEN. The style decides the order, and the order
-- decides the delay: a portcullis lifts from the top so its teeth are
-- the last thing to leave the floor; a shutter parts from the middle.
local GATE_ORDER = {
  portcullis = function(s) return s.i - 1 end,
  piston     = function(s) return s.i - 1 end,
  shutter    = function(s) return math.abs(s.i - (s.n + 1) / 2) end,
  blast      = function(s) return math.abs(s.i - (s.n + 1) / 2) end,
  curtain    = function() return 0 end,
}

function World:gateOpenFlag(flag)
  if not flag or not G.run then return false end
  if flag:sub(1, 1) == "!" then return false end   -- bridges do not animate
  return G.run.flags[flag] and true or false
end

-- 0 = fully shut, 1 = fully retracted, for ONE cell.
function World:gateCellPhase(i)
  local flag = self.gateFlags and self.gateFlags[i]
  if not flag then return 0 end
  local t = self.gateT and self.gateT[flag]
  if t == nil then t = self:gateOpenFlag(flag) and 1 or 0 end
  local s = self.gateSeq and self.gateSeq[i]
  if not s or s.n <= 1 then return t end
  local style = (self.gateStyles and self.gateStyles[i]) or "portcullis"
  local order = (GATE_ORDER[style] or GATE_ORDER.portcullis)(s)
  local off = (order / (s.n - 1)) * (1 - World.GATE_SPAN)
  return U.clamp((t - off) / World.GATE_SPAN, 0, 1)
end

-- CLOSED -> OPENING -> OPEN -> CLOSING -> CLOSED, with reversal allowed
-- from ANY point. Non-latching plates are reconciled every frame with OR
-- semantics, so a gate really can be told to shut while it is still
-- opening. Running ONE timer toward a target -- rather than playing an
-- animation -- is what makes that free: it resumes from the current
-- phase instead of restarting, and a door never teleports shut on a
-- player standing in it, which is the exact bug a tile-quantised door
-- exists to avoid.
function World:updateGates(dt)
  if not self.gateFlags then return end
  self.gateT = self.gateT or {}
  for _, flag in pairs(self.gateFlags) do
    if self.gateT[flag] == nil then
      self.gateT[flag] = self:gateOpenFlag(flag) and 1 or 0
    end
  end
  local step = dt / World.GATE_TIME
  for flag, t in pairs(self.gateT) do
    local target = self:gateOpenFlag(flag) and 1 or 0
    if t < target then
      self.gateT[flag] = math.min(target, t + step)
    elseif t > target then
      self.gateT[flag] = math.max(target, t - step)
    end
  end
end

function World:update(dt)
  self:updateGates(dt)
  self:updateFlood(dt)
  self:updateBeams(dt)
  -- flush add queue
  for _, e in ipairs(self.addQueue) do
    self.entities[#self.entities + 1] = e
  end
  self.addQueue = {}

  -- crumble timers
  for i, st in pairs(self.crumbles) do
    if st.t then
      st.t = st.t - dt
      if st.t <= 0 and not st.gone then
        st.gone = true
        st.respawn = 4
        local tx, ty = i % 4096, math.floor(i / 4096)
        self:fx("burst", tx * T + 8, ty * T + 8, { color = "slate", n = 6 })
        if G.Audio then G.Audio.sfx("crumble") end
      end
    end
    if st.gone and st.respawn then
      st.respawn = st.respawn - dt
      if st.respawn <= 0 then
        -- only restore if nobody stands there
        local tx, ty = i % 4096, math.floor(i / 4096)
        local blocked = false
        for _, p in ipairs(self.players) do
          if U.aabb(p.x, p.y, p.w, p.h, tx * T, ty * T, T, T) then blocked = true end
        end
        if not blocked then
          st.gone = false
          st.t = nil
          st.respawn = nil
        else
          st.respawn = 0.5
        end
      end
    end
  end

  -- entities
  local n = #self.entities
  local slept = 0
  for i = 1, n do
    local e = self.entities[i]
    if not e.dead then
      -- The damage clocks tick whether or not the body is thinking. An
      -- off-screen enemy can still be reached by a projectile, and a
      -- frozen invuln would swallow the next hit that lands on it.
      if e.invuln and e.invuln > 0 then e.invuln = e.invuln - dt end
      if e.white and e.white > 0 then e.white = e.white - dt end
      if self:asleep(e) then slept = slept + 1 else e:update(dt) end
    end
  end
  self.sleptLast = slept
  -- sweep dead
  for i = #self.entities, 1, -1 do
    if self.entities[i].dead then table.remove(self.entities, i) end
  end

  -- particles
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    p.t = p.t - dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + (p.grav or 0) * dt
    if p.t <= 0 then table.remove(self.particles, i) end
  end

  -- pressure plates OR together per flag
  local plateFlags = {}
  for _, e in ipairs(self.entities) do
    if e.kind == "plate" and not e.latch and not e.dead then
      plateFlags[e.flag] = (plateFlags[e.flag] or false) or (e.pressT > 0)
    end
  end
  for f, v in pairs(plateFlags) do
    G.run.flags[f] = v or nil
  end

  self:ambient(dt)
end

-- ------------------------------------------------------------------
-- ENTITY SLEEP
--
-- Every body in a room used to think every frame. That is free in a 30x17
-- box and it is not free in the rooms this engine is being prepared for,
-- so a body far enough away stops thinking until you come back.
--
-- TWO tests, not one. Off camera is not enough on its own: in co-op the
-- second bot can be off screen and still needs the world to behave around
-- it, so an entity stays awake if it is near ANY living player.
--
-- Sleep is OPT-IN, and only ordinary enemies opt in. That is deliberately
-- the conservative way round. Something that could sleep and does not
-- costs a few microseconds; something that must NOT sleep and does is a
-- boss that stops mid-fight, a door that never opens, or a projectile
-- frozen in the air. Bosses, props, projectiles, pickups and NPCs simply
-- never set the flag -- and Boss extends Entity rather than Enemy, so it
-- cannot inherit it by accident.
--
-- Nothing sleeps at all while a boss is active. A boss that spawns adds
-- has no way to tell them apart from scenery, and an add that freezes off
-- screen is a fight that never ends.
-- ------------------------------------------------------------------
World.SLEEP_R = 640    -- world px from a player; 1.33 viewport widths

function World:asleep(e)
  if not e.canSleep or self.bossActive then return false end
  local cx, cy = e.x + e.w / 2, e.y + e.h / 2
  if Cam.onScreen(cx, cy, 96) then return false end
  local R = World.SLEEP_R
  for _, p in ipairs(self.players) do
    if not p.dead and not p.idle then
      local dx, dy = cx - (p.x + p.w / 2), cy - (p.y + p.h / 2)
      if dx * dx + dy * dy < R * R then return false end
    end
  end
  return true
end

function World:startCrumble(tx, ty)
  local i = idx(tx, ty)
  if self:tileAt(tx, ty) == CRUMBLE then
    local st = self.crumbles[i]
    if not st then
      self.crumbles[i] = { t = 0.45 }
      if G.Audio then G.Audio.sfx("crack") end
    end
  end
end

-- `with` is what is opening it: nil for a shot or a plain dash, or the
-- name of the plate that is doing the work ("bulwark"). A plain '%'
-- takes anything; a bulwark block takes only its own plate and shrugs
-- off everything else with a spark, so the player learns the block is
-- real rather than wondering whether they missed.
function World:breakTile(tx, ty, with)
  local i = idx(tx, ty)
  if self:tileAt(tx, ty) ~= BREAK or self.broken[i] then return false end
  local need = self.hardSet and self.hardSet[i]
  if need and need ~= with then
    -- a refusal has to be VISIBLE or it reads as a dead shot
    if not self.hardT or (G.time - self.hardT) > 0.18 then
      self.hardT = G.time
      self:fx("spark", tx * T + 8, ty * T + 8, { color = "spark", n = 3 })
      if G.Audio then G.Audio.sfx("deny") end
    end
    return false
  end
  self.broken[i] = true
  self:fx("burst", tx * T + 8, ty * T + 8,
    { color = need and "vessred" or "slate", n = need and 14 or 8 })
  if G.Audio then G.Audio.sfx("break") end
  return true
end

-- entities of a class within box
function World:query(x, y, w, h, filter)
  local out = {}
  for _, e in ipairs(self.entities) do
    if not e.dead and (not filter or filter(e)) then
      if U.aabb(x, y, w, h, e.x, e.y, e.w, e.h) then
        out[#out + 1] = e
      end
    end
  end
  return out
end

function World:each(kind, fn)
  for _, e in ipairs(self.entities) do
    if not e.dead and e.kind == kind then fn(e) end
  end
end

-- Is this body inside a thermal column? Uses the body's centre so you have
-- to actually be IN the draft, not clipping its edge.
function World:updraftAt(e)
  local cx = e.x + e.w / 2
  local cy = e.y + e.h / 2
  for _, u in ipairs(self.entities) do
    if u.kind == "updraft" and not u.dead
      and cx >= u.x and cx <= u.x + u.w
      and cy >= u.y and cy <= u.y + u.h then
      return u
    end
  end
  return nil
end

function World:nearestPlayer(x, y)
  local best, bd
  for _, p in ipairs(self.players) do
    if not p.dead and not p.downed and not p.idle then
      local d = U.dist2(x, y, p.x + p.w / 2, p.y + p.h / 2)
      if not bd or d < bd then best, bd = p, d end
    end
  end
  return best, best and math.sqrt(bd) or math.huge
end

function World:alivePlayers()
  local out = {}
  for _, p in ipairs(self.players) do
    if not p.dead and not p.downed then out[#out + 1] = p end
  end
  return out
end

-- ------------------------------------------------------------------
-- Particles / ambient
-- ------------------------------------------------------------------
function World:fx(kind, x, y, opts)
  opts = opts or {}
  if kind == "burst" then
    local col = P[opts.color or "white"]
    for i = 1, opts.n or 8 do
      local a = U.rand(0, math.pi * 2)
      local s = U.rand(30, opts.speed or 90)
      self.particles[#self.particles + 1] = {
        x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s,
        t = U.rand(0.2, 0.5), col = col, r = U.rand(1, 2.5), grav = 200,
      }
    end
  elseif kind == "puff" then
    local col = P[opts.color or "slate"]
    for i = 1, opts.n or 4 do
      self.particles[#self.particles + 1] = {
        x = x + U.rand(-3, 3), y = y + U.rand(-2, 2),
        vx = U.rand(-15, 15), vy = U.rand(-30, -5),
        t = U.rand(0.25, 0.5), col = col, r = U.rand(1.5, 3),
      }
    end
  elseif kind == "spark" then
    local col = P[opts.color or "spark"]
    for i = 1, opts.n or 5 do
      local a = (opts.angle or 0) + U.rand(-0.6, 0.6)
      local s = U.rand(60, 160)
      self.particles[#self.particles + 1] = {
        x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s,
        t = U.rand(0.1, 0.28), col = col, r = U.rand(0.8, 1.6),
      }
    end
  elseif kind == "splash" then
    for i = 1, 10 do
      self.particles[#self.particles + 1] = {
        x = x + U.rand(-6, 6), y = y, vx = U.rand(-40, 40), vy = U.rand(-120, -40),
        t = U.rand(0.3, 0.6), col = P.sky, r = U.rand(1, 2), grav = 400,
      }
    end
  elseif kind == "heal" then
    for i = 1, 8 do
      self.particles[#self.particles + 1] = {
        x = x + U.rand(-8, 8), y = y + U.rand(-4, 8),
        vx = 0, vy = U.rand(-50, -25),
        t = U.rand(0.4, 0.7), col = P.leaf, r = U.rand(1, 2),
      }
    end
  elseif kind == "trail" then
    -- vx/vy default to nothing, which is what every existing caller
    -- wants; the Crucible's drain wants its drips to actually fall
    self.particles[#self.particles + 1] = {
      x = x, y = y, vx = opts.vx or 0, vy = opts.vy or 0, t = opts.t or 0.2,
      col = P[opts.color or "spark"], r = opts.r or 2,
    }
  end
end

function World:ambient(dt)
  self.fxTimer = self.fxTimer - dt
  if self.fxTimer > 0 then return end
  self.fxTimer = 0.12
  local zone = self.zone
  local x = Cam.x + U.rand(0, G.VW)
  local y = Cam.y + U.rand(0, G.VH)
  -- mended zones exhale slow golden motes
  if self:zoneMended() and U.chance(0.25) then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = U.rand(-3, 3),
      vy = U.rand(-8, -3), t = U.rand(1.5, 3), col = P.gold, r = 1 }
  end
  -- the frozen camp snows, gently, forever
  if self:zoneFrozen() then
    self.particles[#self.particles + 1] = { x = x, y = Cam.y - 4,
      vx = U.rand(-6, 6), vy = U.rand(12, 26), t = U.rand(2, 4),
      col = P.ice, r = 1 }
  end
  if zone == "mosswood" then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = U.rand(-6, 6),
      vy = U.rand(4, 12), t = U.rand(1.5, 3), col = P.leaf, r = 1 }
  elseif zone == "furnace" then
    self.particles[#self.particles + 1] = { x = x, y = Cam.y + G.VH + 4,
      vx = U.rand(-8, 8), vy = U.rand(-35, -15), t = U.rand(1, 2.4),
      col = U.chance(0.3) and P.hotcore or P.ember, r = U.rand(0.8, 1.6) }
  elseif zone == "crystal" then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = 0, vy = 0,
      t = U.rand(0.3, 0.9), col = U.chance(0.5) and P.orchid or P.spark, r = 1 }
  elseif zone == "flooded" then
    local tx, ty = math.floor(x / T), math.floor(y / T)
    if self:isWater(tx, ty) then
      self.particles[#self.particles + 1] = { x = x, y = y, vx = 0,
        vy = U.rand(-18, -8), t = U.rand(0.8, 1.6), col = P.ice, r = 1 }
    end
  elseif zone == "skyroot" then
    self.particles[#self.particles + 1] = { x = Cam.x - 4, y = y,
      vx = U.rand(35, 70), vy = U.rand(-4, 4), t = U.rand(1.5, 3),
      col = P.slate, r = 1 }
  elseif zone == "core" then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = 0,
      vy = U.rand(-10, -4), t = U.rand(0.5, 1.2), col = P.cyan, r = 1 }
  end
end

-- ------------------------------------------------------------------
-- Drawing
-- ------------------------------------------------------------------
-- ------------------------------------------------------------------
-- THE DRAW ORDER, in one place.
--
-- This was a single 300-line function. Splitting it into named layers
-- does not change a pixel; it makes the order legible, gives a new layer
-- an obvious place to go, and is what let the FOREGROUND exist at all.
--
-- Two things about the order are load-bearing and neither is obvious
-- from reading a layer on its own:
--
--   * Everything before Cam.apply() is SCREEN space. The sky and the
--     parallax are not in the camera transform -- they scroll by
--     offsetting themselves against Cam.x by hand, which is what makes
--     them parallax rather than scenery.
--
--   * drawDarkness must stay LAST inside the transform. It renders to
--     its own canvas and blits in screen space, so anything drawn after
--     it sits on top of the dark instead of under it -- which is the
--     whole point of a dark room.
-- ------------------------------------------------------------------
function World:draw()
  local g = love.graphics
  local set = G.tiles[self.zone] or G.tiles.camp
  local zc = set.conf

  self:drawSky(g, set, zc)
  self:drawParallax(g, set)

  -- boss arenas carry their own scenery (screen space, room-locked)
  if self.room and self.room.arena then
    self:drawArenaBackdrop(g, self.room.arena, -Cam.x, -Cam.y)
  end

  Cam.apply()

  -- The visible tile window, computed once and handed to every layer
  -- that iterates tiles. It was computed twice before, here and again in
  -- the water pass, with the same four lines written out both times.
  local frozen = self:zoneFrozen()
  local tx0 = math.max(0, math.floor(Cam.x / T) - 1)
  local ty0 = math.max(0, math.floor(Cam.y / T) - 1)
  local tx1 = math.min(self.w - 1, math.floor((Cam.x + G.VW) / T) + 1)
  local ty1 = math.min(self.h - 1, math.floor((Cam.y + G.VH) / T) + 1)

  self:drawBackdrop(g)                    -- room art, BEHIND the rock
  self:drawTerrain(g, set, tx0, ty0, tx1, ty1, frozen)
  self:drawStrata(g, set, tx0, ty0, tx1, ty1)   -- rock, not blocks of dirt
  self:drawEdges(g, set, tx0, ty0, tx1, ty1)    -- and break the 16px outline
  self:drawIce(g, tx0, ty0, tx1, ty1)          -- glaze, AFTER the rock
  self:drawGrate(g)
  self:drawFlood(g)
  -- HOARFROST, over the floor and under everything that stands on it.
  if self.frost then require("src.cold").frostDraw(self) end
  self:drawBeams(g)
  self:drawDoorArt(g, set)
  self:drawDecor(g, tx0, ty0, tx1, ty1)   -- zone decoration, behind bodies
  self:drawScenery(g)                     -- room art, behind bodies
  self:drawEntities(g)
  self:drawWater(g, tx0, ty0, tx1, ty1)
  self:drawParticles(g)
  self:drawOvergrowth(g, set, tx0, ty0, tx1, ty1)  -- cover over the impassable
  self:drawForeground(g)                  -- room art, in front of bodies
  self:drawWashes(g)

  -- DARKNESS. Dark rooms have always been the Undergrove's; a frozen
  -- world is dark everywhere, because every lantern in it has gone out.
  -- This is what makes Lu's lume and the Ember's own aura the way you
  -- see -- the light you are carrying is the only light there is.
  if (self.room and self.room.dark) or self:zoneFrozen() then
    self:drawLight(g)
  end

  Cam.unapply()
end

-- SCREEN SPACE. A vertical wash between the zone's two sky colours.
function World:drawSky(g, set, zc)
  -- background gradient
  local c1, c2 = P[zc.sky1], P[zc.sky2]
  for i = 0, 8 do
    local t = i / 8
    g.setColor(U.lerp(c1[1], c2[1], t), U.lerp(c1[2], c2[2], t), U.lerp(c1[3], c2[3], t), 1)
    g.rectangle("fill", 0, i * (G.VH / 9), G.VW, G.VH / 9 + 1)
  end
end

-- ------------------------------------------------------------------
-- PARALLAX -- N layers, both axes.
--
-- SCREEN SPACE, and that is the whole mechanism: a layer offsets itself
-- against the camera by its OWN factor, so the far ones lag and the near
-- ones keep up. Inside the camera transform they would all move together
-- and there would be no depth at all.
--
-- This was three layers, hardcoded, horizontal only, wrapping at a
-- literal 480 -- which was the image width, said twice, in a place that
-- would not notice if the images ever changed size. It is now a list, of
-- any length, with per-layer factors on both axes, wrapping at whatever
-- the image actually measures.
--
--   fx, fy  scroll factor per axis. 0 is painted on the back wall, 1
--           moves exactly with the world. Anything above ~0.6 starts to
--           read as scenery rather than distance.
--   a       alpha. Distance is mostly haze, not size: fading a far layer
--           does more for depth than moving it slower does.
--
-- fy = 0 everywhere today, which is why this phase changes nothing. A
-- 34-row room is where vertical parallax would earn its keep -- with
-- fy = 0 the sky is welded to the top of the screen, so climbing a shaft
-- reads as the shaft moving past a backdrop rather than as ascent.
-- ------------------------------------------------------------------

-- The three layers the game has always had, written as data. A zone may
-- set its own `parallax` list; this is what it gets if it does not, and
-- the numbers are exactly the ones that were inline before.
local function defaultParallax(set)
  return {
    { img = set.bgGlow,            fx = 0.10, fy = 0.05,  a = 1.00 },
    { img = set.bg and set.bg[1],  fx = 0.25, fy = 0.125, a = 0.55 },
    { img = set.bg and set.bg[2],  fx = 0.50, fy = 0.25,  a = 0.80 },
  }
end

function World:drawParallax(g, set)
  set.parallax = set.parallax or defaultParallax(set)
  for _, layer in ipairs(set.parallax) do
    local img = layer.img
    if img then
      local iw, ih = img:getDimensions()
      local fx, fy = layer.fx or 0, layer.fy or 0
      g.setColor(1, 1, 1, layer.a or 1)
      -- One extra copy on each axis that scrolls, so the seam is always
      -- off screen. An axis that does not scroll draws a single row at
      -- its resting offset -- which is what keeps this identical to the
      -- hand-written version it replaces.
      local ox = -(Cam.x * fx) % iw
      local nx = math.ceil(G.SW / iw) + 1
      -- VERTICAL: offset, never tiled, and ANCHORED AT THE ROOM'S FLOOR.
      --
      -- These layer images are screen-height with a ground line along the
      -- bottom. They tile horizontally because they were drawn to; they
      -- would not tile vertically, and repeating one would put a second
      -- horizon in the sky.
      --
      -- Anchoring at the floor rather than at zero is what makes this
      -- safe to turn on everywhere: at the bottom of any room the offset
      -- is 0 and the frame is exactly what it always was. A room only one
      -- viewport tall has nowhere else to be, so 63 of the 83 rooms are
      -- untouched by construction -- the change lands only where there is
      -- real vertical travel to sell.
      --
      -- Climbing then pushes the backdrop DOWN, uncovering sky above it,
      -- which is the read we want: the shaft is not sliding past a
      -- painted wall, you are going up.
      local oy = 0
      if fy ~= 0 and G.settings.parallaxY and G.settings.parallaxY > 0 then
        local maxCam = math.max(0, self.h * T - G.VH)
        oy = (maxCam - Cam.y) * fy * G.settings.parallaxY
      end
      local ly = (layer.y or 0) + oy
      for i = 0, nx - 1 do
        g.draw(img, ox + (i - 1) * iw, ly)
      end
      -- ...AND FILL WHAT THE SHIFT UNCOVERED.
      --
      -- These images are exactly screen height. Pushing one down by oy
      -- leaves oy pixels above it with nothing in them, and "nothing"
      -- here is drawSky's gradient, which for most zones runs black to
      -- dark. Climbing a 34-row shaft opened 68px of void along the top
      -- of the screen -- the first thing Thomas saw when he went up.
      --
      -- The top row of every one of these layers is sky, so stretching
      -- that single scanline upward fills the gap seamlessly and costs
      -- one draw. Tiling the image instead would hang a second horizon
      -- in the air.
      if ly > 0.5 then
        layer.topq = layer.topq or love.graphics.newQuad(0, 0, iw, 1, iw, ih)
        for i = 0, nx - 1 do
          g.draw(img, layer.topq, ox + (i - 1) * iw, ly, 0, 1, -ly)
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

function World:drawTerrain(g, set, tx0, ty0, tx1, ty1, frozen)
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      local c = self.tiles[ty][tx]
      local px, py = tx * T, ty * T
      if c == SOLID or (c == BREAK and not self.broken[idx(tx, ty)]) then
        if c == SOLID then
          g.draw((tx * 7 + ty * 13) % 3 == 0 and set.solid2 or set.solid, px, py)
        else
          g.draw(set.breakable, px, py)
          -- HARDNESS HAS TO LOOK LIKE SOMETHING.
          --
          -- Every BREAK drew the same sprite, so a bulwark block and an
          -- ordinary breakable were pixel-identical and the only way to
          -- tell them apart was to shoot one and watch it refuse. A block
          -- whose whole point is "not that tool" has to say so BEFORE the
          -- player spends the tool on it.
          local hk = self.hardSet and self.hardSet[idx(tx, ty)]
          if hk then
            local link = hk == "linkblast"
            local col = link and P.violet or P.vessred
            local acc = link and P.orchid or P.rust
            g.setColor(col[1], col[2], col[3], 0.5)
            g.rectangle("fill", px + 1, py + 1, T - 2, T - 2)
            g.setColor(acc[1], acc[2], acc[3], 0.85)
            g.line(px + 3, py + 3, px + T - 3, py + T - 3)
            g.line(px + T - 3, py + 3, px + 3, py + T - 3)
            g.setColor(acc[1], acc[2], acc[3], 0.5)
            g.rectangle("line", px + 1.5, py + 1.5, T - 3, T - 3)
            g.setColor(1, 1, 1, 1)
          end
        end
        -- neighbor-aware shading
        local function hard(t2)
          return t2 == SOLID or t2 == BREAK or t2 == CRUMBLE or t2 == GATE
        end
        local above = self:tileAt(tx, ty - 1)
        local below = self:tileAt(tx, ty + 1)
        local left = self:tileAt(tx - 1, ty)
        local right = self:tileAt(tx + 1, ty)
        local upHard, dnHard = hard(above), hard(below)
        local lHard, rHard = hard(left), hard(right)
        -- BLUE ICE. Once the Ember is gone the ground itself changes: a
        -- cold wash over every solid tile, and a bright rime cap on any
        -- surface with open air above it -- so the world reads as frozen
        -- from the silhouette of the floor, not just from a screen tint.
        if frozen then
          g.setColor(0.42, 0.60, 0.88, 0.30)
          g.rectangle("fill", px, py, T, T)
          if not upHard then
            g.setColor(0.78, 0.90, 1.0, 0.55)
            g.rectangle("fill", px, py, T, 2)
            g.setColor(0.90, 0.97, 1.0, 0.35)
            g.rectangle("fill", px + ((tx * 5) % 6), py + 2, 3, 1)
          end
          g.setColor(1, 1, 1, 1)
        end
        if upHard and dnHard and lHard and rHard then
          -- fully enclosed: fake ambient occlusion
          g.setColor(0, 0, 0, 0.28)
          g.rectangle("fill", px, py, T, T)
          g.setColor(1, 1, 1, 1)
        else
          -- exposed rims
          if not lHard then
            g.setColor(1, 1, 1, 0.10)
            g.rectangle("fill", px, py, 1.5, T)
          end
          if not rHard then
            g.setColor(0, 0, 0, 0.22)
            g.rectangle("fill", px + T - 1.5, py, 1.5, T)
          end
          if not dnHard then
            g.setColor(0, 0, 0, 0.30)
            g.rectangle("fill", px, py + T - 2, T, 2)
          end
          g.setColor(1, 1, 1, 1)
        end
        -- exposed top cap
        if not upHard then
          g.draw(set.cap, px, py)
        end
      elseif c == CRUMBLE then
        local st = self.crumbles[idx(tx, ty)]
        if not (st and st.gone) then
          if st and st.t then
            g.push()
            g.translate(px + love.math.random(-1, 1), py)
            g.draw(set.crumble, 0, 0)
            g.pop()
          else
            g.draw(set.crumble, px, py)
          end
        end
      elseif c == GATE then
        local flag = self.gateFlags[idx(tx, ty)]
        local inverted = flag and flag:sub(1, 1) == "!"
        if inverted then
          if G.run and G.run.flags[flag:sub(2)] then
            -- energy bridge
            local pulse = 0.7 + math.sin(G.time * 6 + tx) * 0.2
            g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], pulse)
            g.rectangle("fill", px, py + 2, T, 4)
            g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse)
            g.rectangle("fill", px, py + 2, T, 1.5)
            g.setColor(1, 1, 1, 1)
          end
        else
          local i = idx(tx, ty)
          local style = self.gateStyles[i]
          local p = self:gateCellPhase(i)
          if style == "curtain" then
            -- light, not stone: the sheet fades rather than retracting,
            -- and the posts stay whatever it does
            self:drawCurtainTile(g, px, py, tx, ty, p)
          elseif style then
            self:drawGateStyle(g, style, px, py, p, self.gateSeq[i])
          else
            -- a gate with no style stated is the plain slab it always
            -- was, and it still animates: it slides up out of the way,
            -- which is the least surprising thing an unlabelled gate can
            -- do and needs no room edits anywhere. Drawn at every phase,
            -- including fully open, so it parks in its head like the
            -- rest rather than disappearing.
            self:drawGateStyle(g, "portcullis", px, py, p, self.gateSeq[i])
          end
        end
      elseif c == ONEWAY then
        g.draw(set.oneway, px, py)
      elseif c == SPIKE_U then
        g.draw(set.spike, px, py)
      elseif c == SPIKE_D then
        g.draw(set.spike, px + T, py + T, math.pi)
      elseif c == SPIKE_L then
        g.draw(set.spike, px, py + T, -math.pi / 2)
      elseif c == SPIKE_R then
        g.draw(set.spike, px + T, py, math.pi / 2)
      elseif c == LAVA then
        local wob = math.sin(G.time * 3 + tx) * 1.5
        local isTop = self:tileAt(tx, ty - 1) ~= LAVA
        g.setColor(P.magma[1], P.magma[2], P.magma[3], 1)
        g.rectangle("fill", px, py + (isTop and (2 + wob) or 0), T, T - (isTop and (2 + wob) or 0))
        if isTop then
          g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 1)
          g.rectangle("fill", px, py + 1 + wob, T, 2)
        end
        g.setColor(1, 1, 1, 1)
      end
    end
  end
end

-- Edge chevrons, sealed bars and portal frames: everything that tells
-- you where a door is and whether it will open.
-- ------------------------------------------------------------------
-- ROCK, instead of blocks of dirt.
--
-- A solid tile draws one 16x16 image, so a large mass of them reads as a
-- grid of identical stamps. The fix is not a better tile -- it is
-- FEATURES BIGGER THAN A TILE, so the eye stops finding the seam.
--
-- Three of them, and all three only on ENCLOSED tiles. The exposed rim,
-- the cap, and anything a bot can stand on are left completely alone:
-- those are what the player reads to know where the floor is, and they
-- have to stay crisp. Texture goes where nobody can walk.
--
--   DEPTH   how far inside the mass a tile sits, breadth-first out from
--           open air, computed once per room and cached. Rock darkening
--           inward is the strongest single cue that it is a solid BODY
--           rather than a wall of stamps.
--   STRATA  horizontal bands keyed on the tile ROW ALONE, so one band
--           runs unbroken across every tile in that row and crosses the
--           entire mass. This is what actually kills the grid.
--   GRAIN   a few flecks per tile in the zone's own cap colour, so the
--           mineral belongs to the zone it is in.
--
-- The hash is sin-based rather than bitwise on purpose: LOVE 11 runs
-- LuaJIT, which is 5.1, and 5.3's `~` and `>>` would not survive there.
-- ------------------------------------------------------------------
local function h01(a, b, s)
  local n = math.sin(a * 12.9898 + b * 78.233 + (s or 0) * 3.71) * 43758.5453
  return n - math.floor(n)
end

local NEIGH = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function hardKind(c)
  return c == SOLID or c == BREAK or c == CRUMBLE or c == GATE
end

-- Distance from open air, breadth-first, capped -- once per room.
function World:solidDepth()
  if self.depthMap then return self.depthMap end
  local d, q, qn = {}, {}, 0
  for ty = 0, self.h - 1 do
    for tx = 0, self.w - 1 do
      if not hardKind(self.tiles[ty][tx]) then
        local i = idx(tx, ty)
        d[i] = 0; qn = qn + 1; q[qn] = i
      end
    end
  end
  local head = 1
  while head <= qn do
    local i = q[head]; head = head + 1
    local nd = d[i] + 1
    if nd <= 6 then
      local tx, ty = i % 4096, math.floor(i / 4096)
      for k = 1, 4 do
        local nx, ny = tx + NEIGH[k][1], ty + NEIGH[k][2]
        if nx >= 0 and ny >= 0 and nx < self.w and ny < self.h then
          local j = idx(nx, ny)
          if d[j] == nil then d[j] = nd; qn = qn + 1; q[qn] = j end
        end
      end
    end
  end
  self.depthMap = d
  return d
end

function World:drawStrata(g, set, tx0, ty0, tx1, ty1)
  local amt = G.settings.strata or 1
  local zc = set.conf
  -- A zone may dial its own banding down. Ice is smooth: the Coldstore
  -- at the Scrapyard's strength read as sediment rather than as a frozen
  -- face. The global setting still scales it, so EMBERDEEP_STRATA=0
  -- turns everything off exactly as before.
  amt = amt * (zc and zc.strata or 1)
  if amt <= 0 then return end
  local dk = P[zc.dark] or P.black
  local cap = P[zc.cap] or P.gray
  local d = self:solidDepth()
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      local c = self.tiles[ty][tx]
      if c == SOLID or c == BREAK then
        local dep = d[idx(tx, ty)] or 0
        -- dep 1 is the rim: left clean so the silhouette stays readable
        if dep >= 2 then
          local px, py = tx * T, ty * T
          g.setColor(dk[1], dk[2], dk[3], math.min(0.52, (dep - 1) * 0.135) * amt)
          g.rectangle("fill", px, py, T, T)
          local sh = h01(0, ty, 3)
          if sh < 0.34 then
            local yy = py + math.floor(sh * 8.8) * 4 + 3
            g.setColor(dk[1], dk[2], dk[3], 0.32 * amt)
            g.rectangle("fill", px, yy, T, 2)
            g.setColor(cap[1], cap[2], cap[3], 0.06 * amt)
            g.rectangle("fill", px, yy + 2, T, 1)
          end
          for k = 1, 3 do
            local hx = h01(tx, ty, k)
            if hx > 0.63 then
              local hy = h01(ty, tx, k + 7)
              g.setColor(cap[1], cap[2], cap[3], 0.11 * amt)
              g.rectangle("fill", px + math.floor(hx * 13), py + math.floor(hy * 13), 2, 2)
            end
          end
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- THE EDGES -- where "square" actually lives.
--
-- drawStrata textures the INSIDE of a mass, and in a room like moss_3
-- that turns out to be almost nothing: the platforms are one or two
-- tiles thick, so every tile in them is depth-1 rim and the strata pass
-- skips the lot. What the player is looking at is not the inside of the
-- rock. It is the OUTLINE, and the outline is a 16px staircase of
-- perfect right angles.
--
-- So this pass works on exactly the tiles strata refuses: the rim. Four
-- treatments, each aimed at one straight line:
--
--   DRIP     under a ceiling or a platform's belly -- the flat bottom
--            edge is the single most "brick" line on screen
--   CREST    over an exposed top, spilling PAST the lip left and right,
--            so the platform's ends stop being vertical cuts
--   RAGGED   on exposed vertical faces, a few pixels of broken profile
--   CHAMFER  a soft 2px cut across convex corners, in the zone's own
--            backdrop colour, so a 90 degree corner reads as worn
--
-- All of it is ADDITIVE and hashed off world position: stable frame to
-- frame, never tiling, and it cannot move a collision boundary because
-- it does not touch the tile map. What a bot can stand on is exactly
-- what it could stand on before -- this only changes where the eye
-- thinks the edge is.
-- ------------------------------------------------------------------
-- Growth spilling DOWN an exposed vertical face. Split out of drawEdges
-- so the two sides share one body without allocating a table per tile to
-- iterate over.
-- ------------------------------------------------------------------
-- THE WALL PROBLEM.
--
-- Per-tile noise cannot fix a thirty-tile column. Whatever you scatter
-- along it repeats on a 16px beat, and the eye reads the beat, so the
-- column stays a ruled line with fringe on it -- which is exactly what
-- the first two passes produced.
--
-- What a rock face actually has is a profile that wanders over METRES,
-- not centimetres. So the bulge is a function of world Y alone, summing
-- two slow sines with periods of about nine and twenty-three tiles. It
-- is continuous across tile boundaries by construction, because it never
-- knew where the boundaries were.
--
-- Drawn in four bands per tile rather than per pixel: four rectangles a
-- tile is affordable inside the draw loop, and at 4px the steps read as
-- strata rather than as stairs.
-- ------------------------------------------------------------------
local function faceBulge(wy, seed)
  local a = math.sin(wy * 0.045 + seed)
  local b = math.sin(wy * 0.017 + seed * 2.3)
  return (a * 0.5 + b * 0.5 + 1) * 0.5      -- 0..1
end

function World:faceCreep(g, sx, py, tx, ty, dir, up, amt, dk, cap)
  -- the wandering profile first, so the strands hang off the new edge
  local base = P[(G.tiles[self.zone] or G.tiles.camp).conf.base] or P.gray
  local seed = (dir > 0 and 3.1 or 7.9)
  local out = 6 * amt
  for b = 0, 3 do
    local wy = py + b * 4
    local d = faceBulge(wy, seed) * out
    if d > 0.7 then
      local bx = dir > 0 and sx or (sx + 3 - d)
      g.setColor(base[1], base[2], base[3], 0.95)
      g.rectangle("fill", bx, wy, d, 4)
      g.setColor(dk[1], dk[2], dk[3], 0.8)
      g.rectangle("fill", dir > 0 and (bx + d - 1) or bx, wy, 1, 4)
    end
  end
  for k = 0, 3 do
    local hh = h01(tx * 3 + dir, ty, k + 97)
    if hh > 0.45 then
      local dy = math.floor(h01(ty, tx + dir, k + 101) * 12)
      local ln = (2 + hh * 9) * amt
      g.setColor(dk[1], dk[2], dk[3], 0.9)
      g.rectangle("fill", sx, py + dy, 3, ln)
      if not up and dy < 4 then
        g.setColor(cap[1], cap[2], cap[3], 0.7)
        g.rectangle("fill", sx, py + dy, 3, math.min(ln, 4))
      end
    end
  end
end

-- BLUE ICE, drawn over the finished rock.
--
-- Slipperiness the player cannot see is a trap, not a mechanic, so this
-- has to be unmistakable: a cold wash over the whole tile, a bright lip
-- along any face with air above it, and a slow specular travelling
-- across that lip so the surface reads as WET as well as blue. The lip
-- is the part that matters -- it is the exact edge you will slide along.
function World:drawIce(g, tx0, ty0, tx1, ty1)
  if not self.iceSet then return end
  local P_ = P
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      if self.iceSet[idx(tx, ty)] then
        local px, py = tx * T, ty * T
        g.setColor(P_.ice[1], P_.ice[2], P_.ice[3], 0.30)
        g.rectangle("fill", px, py, T, T)
        g.setColor(P_.navy[1], P_.navy[2], P_.navy[3], 0.22)
        g.rectangle("fill", px, py + T - 5, T, 5)
        -- the walking surface
        if self:tileAt(tx, ty - 1) == AIR then
          g.setColor(0.82, 0.94, 1.00, 0.85)
          g.rectangle("fill", px, py, T, 2)
          local ph = (G.time * 26 + tx * 11 + ty * 7) % 220
          if ph < T then
            g.setColor(1, 1, 1, 0.75)
            g.rectangle("fill", px + ph, py, math.min(6, T - ph), 2)
          end
          g.setColor(1, 1, 1, 0.18)
          g.rectangle("fill", px, py + 2, T, 1)
        end
      end
    end
  end
end

function World:drawEdges(g, set, tx0, ty0, tx1, ty1)
  local amt = G.settings.edges or 1
  if amt <= 0 then return end
  local zc = set.conf
  local dk = P[zc.dark] or P.black
  local cap = P[zc.cap] or P.gray
  local acc = P[zc.accent] or P.gray
  local base = P[zc.base] or P.gray
  local sky = P[zc.sky2] or P.black

  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      local c = self.tiles[ty][tx]
      local solid = c == SOLID or (c == BREAK and not self.broken[idx(tx, ty)])
      if solid then
        local px, py = tx * T, ty * T
        local up = hardKind(self:tileAt(tx, ty - 1))
        local dn = hardKind(self:tileAt(tx, ty + 1))
        local lf = hardKind(self:tileAt(tx - 1, ty))
        local rt = hardKind(self:tileAt(tx + 1, ty))

        -- DRIP. Wildly varied length is the point: a fringe of equal
        -- stubs is just a second straight line a few pixels lower.
        if not dn then
          for k = 0, 4 do
            local hx = h01(tx, ty, k + 11)
            if hx > 0.30 then
              local dx = math.floor(hx * 14)
              local r2 = h01(ty, tx, k + 19)
              local len = (1 + r2 * r2 * 18) * amt      -- squared: mostly short, occasionally long
              local wdt = r2 > 0.7 and 3 or 2
              g.setColor(dk[1], dk[2], dk[3], 0.92)
              g.rectangle("fill", px + dx, py + T, wdt, len)
              if r2 > 0.55 then
                g.setColor(base[1], base[2], base[3], 0.5)
                g.rectangle("fill", px + dx, py + T, wdt, len * 0.4)
              end
              if h01(tx, ty, k + 31) > 0.75 then
                g.setColor(acc[1], acc[2], acc[3], 0.45)
                g.rectangle("fill", px + dx, py + T + len - 2, wdt, 2)
              end
            end
          end
        end

        -- CREST over the lip
        if not up then
          for k = 0, 3 do
            local hx = h01(tx, ty, k + 41)
            if hx > 0.38 then
              local dx = math.floor(hx * 13)
              local hh = 1 + math.floor(h01(ty, tx, k + 47) * 4 * amt)
              g.setColor(cap[1], cap[2], cap[3], 0.9)
              g.rectangle("fill", px + dx, py - hh, 3, hh)
            end
          end
        end

        -- FACE CREEP. Growth spilling DOWN an exposed vertical face from
        -- the lip above it. This is the one that stops a wall reading as
        -- a ruled line -- a straight edge with things hanging over it
        -- stops being a straight edge.
        -- Unrolled rather than looping a { {lf,-1}, {rt,1} } table: that
        -- allocates three tables per solid tile PER FRAME, which is
        -- roughly fifteen hundred a frame across a full screen, and this
        -- runs inside the draw loop where the garbage is not free.
        if not lf then self:faceCreep(g, px - 3, py, tx, ty, -1, up, amt, dk, cap) end
        if not rt then self:faceCreep(g, px + T, py, tx, ty, 1, up, amt, dk, cap) end

        -- ROUND THE CORNER. A stepped 3px bite in the backdrop colour --
        -- the only way to take a 90 degree corner off something already
        -- drawn is to paint the background back over it.
        local ca = 0.88 * math.min(1, amt)
        local function bite(cx, cy, sx2, sy2)
          g.setColor(sky[1], sky[2], sky[3], ca)
          g.rectangle("fill", cx, cy, 3 * sx2, 1 * sy2)
          g.rectangle("fill", cx, cy + 1 * sy2, 2 * sx2, 1 * sy2)
          g.rectangle("fill", cx, cy + 2 * sy2, 1 * sx2, 1 * sy2)
        end
        if not up and not lf then bite(px, py, 1, 1) end
        if not up and not rt then bite(px + T - 1, py, -1, 1) end
        if not dn and not lf then bite(px, py + T - 1, 1, -1) end
        if not dn and not rt then bite(px + T - 1, py + T - 1, -1, -1) end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end
-- ------------------------------------------------------------------
-- OVERGROWTH -- foreground cover over the impassable.
--
-- Drawn in the FOREGROUND slot, so it passes in front of the bots, but
-- hung only off rock the player can never occupy. That is the trick
-- that makes heavy foreground safe here: occluding a wall costs nothing,
-- occluding the floor you are trying to land on costs everything.
--
-- Long strands, low density, swaying on per-strand phase. Nearer than
-- the world (py < 0) so they slide past as you move.
-- ------------------------------------------------------------------
function World:drawOvergrowth(g, set, tx0, ty0, tx1, ty1)
  local amt = G.settings.edges or 1
  if amt <= 0 then return end
  local zc = set.conf
  local dk = P[zc.dark] or P.black
  local acc = P[zc.accent] or P.gray
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      local c = self.tiles[ty][tx]
      if (c == SOLID or c == BREAK) and not hardKind(self:tileAt(tx, ty + 1)) then
        local hx = h01(tx, ty, 83)
        if hx > 0.52 then
          local px, py = tx * T, ty * T + T
          local len = (10 + h01(ty, tx, 89) * 26) * amt
          local sway = math.sin(G.time * 0.6 + tx * 0.7) * 3
          local segs = 5
          local ox2, oy2 = px + math.floor(hx * 12), py
          g.setLineWidth(2)
          for i = 1, segs do
            local t = i / segs
            local nx = px + math.floor(hx * 12) + sway * t * t
            local ny = py + len * t
            -- fade along the strand: dark where it leaves the rock,
            -- picking up the zone accent at the tip, so it reads against
            -- a dark background instead of vanishing into it
            g.setColor(dk[1] + (acc[1] - dk[1]) * t * 0.6,
                       dk[2] + (acc[2] - dk[2]) * t * 0.6,
                       dk[3] + (acc[3] - dk[3]) * t * 0.6, 0.85)
            g.line(ox2, oy2, nx, ny)
            ox2, oy2 = nx, ny
          end
          g.setLineWidth(1)
          g.setColor(acc[1], acc[2], acc[3], 0.5)
          g.rectangle("fill", ox2 - 1, oy2 - 2, 3, 3)
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

function World:drawDoorArt(g, set)
  -- edge-door markers: a soft pulsing chevron pointing out of the room,
  -- so exits read at a glance
  for ch, d in pairs(self.doors) do
    if d.edge and d.link and not self:doorSealed(d) then
      local cx = (d.x0 + (d.x1 - d.x0 + 1) / 2) * T
      local cy = (d.y0 + (d.y1 - d.y0 + 1) / 2) * T
      local acc = P[set.conf.accent]
      local pulse = 0.45 + math.sin(G.time * 3 + d.x0) * 0.2
      local o = math.sin(G.time * 3 + d.x0) * 1.5
      g.setColor(acc[1], acc[2], acc[3], pulse)
      if d.edge == "left" then
        g.polygon("fill", cx + 4 - o, cy - 5, cx + 4 - o, cy + 5, cx - 1 - o, cy)
      elseif d.edge == "right" then
        g.polygon("fill", cx - 4 + o, cy - 5, cx - 4 + o, cy + 5, cx + 1 + o, cy)
      elseif d.edge == "top" then
        g.polygon("fill", cx - 5, cy + 4 - o, cx + 5, cy + 4 - o, cx, cy - 1 - o)
      else
        g.polygon("fill", cx - 5, cy - 4 + o, cx + 5, cy - 4 + o, cx, cy + 1 + o)
      end
      g.setColor(1, 1, 1, 1)
    end
  end

  -- sealed doors: barred, and visibly so
  for _, d in pairs(self.doors) do
    if d.link and self:doorSealed(d) then
      local px, py = d.x0 * T, d.y0 * T
      local w = (d.x1 - d.x0 + 1) * T
      local h = (d.y1 - d.y0 + 1) * T
      g.setColor(P.black[1], P.black[2], P.black[3], 0.82)
      g.rectangle("fill", px, py, w, h)
      g.setColor(P.gray)
      for i = 0, 3 do
        g.rectangle("fill", px + 1, py + 2 + i * (h - 5) / 3, w - 2, 2)
      end
      g.setColor(P.slate)
      g.rectangle("line", px, py, w, h)
      g.setColor(1, 1, 1, 1)
    end
  end

  -- portal door frames (edge doors are just openings)
  for ch, d in pairs(self.doors) do
    if not d.edge and d.link and not self:doorSealed(d) then
      local px = d.x0 * T
      local py = d.y0 * T
      local w = (d.x1 - d.x0 + 1) * T
      local h = (d.y1 - d.y0 + 1) * T
      local acc = P[set.conf.accent]
      g.setColor(P.black[1], P.black[2], P.black[3], 0.75)
      g.rectangle("fill", px + 2, py, w - 4, h)
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 1)
      g.rectangle("fill", px + 4, py + 3, w - 8, h - 3)
      g.setColor(acc[1], acc[2], acc[3], 0.9)
      g.rectangle("line", px + 2.5, py + 0.5, w - 5, h - 0.5)
      g.setColor(acc[1], acc[2], acc[3], 0.4 + math.sin(G.time * 3) * 0.2)
      g.rectangle("fill", px + w / 2 - 2, py + 2, 4, 2)
      g.setColor(1, 1, 1, 1)
    end
  end
end

function World:drawEntities(g)
  -- entities by layer
  table.sort(self.entities, function(a, b) return (a.layer or 0) < (b.layer or 0) end)
  for _, e in ipairs(self.entities) do
    -- the BOX, not the corner: see Cam.boxOnScreen
    if not e.dead and Cam.boxOnScreen(e.x, e.y, e.w, e.h, 64) then e:draw() end
  end
end

function World:drawWater(g, tx0, ty0, tx1, ty1)
  -- dynamic water line overlay
  if self.waterLine then
    local wy = self.waterLine
    if wy < Cam.y + G.VH then
      g.setColor(P.water[1], P.water[2], P.water[3], 0.42)
      g.rectangle("fill", Cam.x, wy, G.VW, Cam.y + G.VH - wy)
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.8)
      for sx = 0, G.VW, 8 do
        local wob = math.sin(G.time * 2.5 + sx * 0.15) * 1.5
        g.rectangle("fill", Cam.x + sx, wy + wob, 8, 1.5)
      end
    end
  end

  -- water overlay (drawn over entities, darker with depth)
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      if self.tiles[ty][tx] == WATER then
        local px, py = tx * T, ty * T
        local isTop = self:tileAt(tx, ty - 1) ~= WATER
        local depth = self.waterDepth[idx(tx, ty)] or 1
        local a = math.min(0.62, 0.34 + depth * 0.035)
        g.setColor(P.water[1] * 0.9, P.water[2] * 0.9, P.water[3], a)
        if isTop then
          local wob = math.sin(G.time * 2.2 + tx * 0.8) * 1.5
          g.rectangle("fill", px, py + 3 + wob, T, T - 3 - wob)
          g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.8)
          g.rectangle("fill", px, py + 2 + wob, T, 1.5)
          -- surface sparkle
          if (tx * 31 + math.floor(G.time * 3)) % 7 == 0 then
            g.setColor(1, 1, 1, 0.5)
            g.rectangle("fill", px + (tx * 13 + math.floor(G.time * 8)) % 12, py + 2 + wob, 2, 1)
          end
        else
          g.rectangle("fill", px, py, T, T)
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

function World:drawParticles(g)
  -- particles
  for _, p in ipairs(self.particles) do
    local a = math.min(1, p.t * 4)
    g.setColor(p.col[1], p.col[2], p.col[3], a)
    g.rectangle("fill", p.x - p.r / 2, p.y - p.r / 2, p.r, p.r)
  end
  g.setColor(1, 1, 1, 1)
end

-- Full-screen tints that say something about the state of the world:
-- warmth where a guardian has fallen, cold once the Ember is gone.
function World:drawWashes(g)
  -- healed-zone warmth: once a zone's guardian falls, its air warms
  if self:zoneMended() then
    local warm = 0.05 + math.sin(G.time * 0.8) * 0.015
    g.setColor(1, 0.72, 0.4, warm)
    g.rectangle("fill", Cam.x, Cam.y, G.VW, G.VH)
    g.setColor(1, 1, 1, 1)
  end

  -- after the Ember leaves, the cold owns everywhere
  if self:zoneFrozen() then
    g.setColor(0.55, 0.7, 0.95, 0.16)
    g.rectangle("fill", Cam.ox, Cam.oy, G.VW, G.VH)
    g.setColor(1, 1, 1, 1)
  end
end

-- A zone counts as "mended" once its guardian -- the Mender's mad
-- repair -- has been put down. Subtle, but the deep should feel it.
local MENDED_FLAG = {
  mosswood = "boss_bramblemaw", flooded = "boss_tideengine",
  furnace = "boss_crucible", crystal = "boss_prismtyrant",
  skyroot = "boss_aeriesentinel", undergrove = "boss_mycelchoir",
}
function World:zoneMended()
  local mf = MENDED_FLAG[self.zone]
  return mf and G.run and G.run.flags and G.run.flags[mf]
    and not self.bossActive
end

-- THE WHOLE DEEP FREEZES, not just the camp.
--
-- This used to be scoped to `zone == "camp"`, because the only frozen
-- place was the one you stole from. But the Ember was the city's heat --
-- every district was warm because of it -- so once it leaves the camp
-- zone in your hands, everything it was keeping alive goes out at once.
-- camp_frozen is set by World:load the moment you carry it into a
-- non-camp room, which makes it exactly the right trigger: it fires on
-- the first step you take away.
-- MUSIC. Every zone keeps its own theme right up until the Ember comes
-- loose, and then there is only one piece of music left in the world --
-- the zones do not get to sound like themselves any more. Everything
-- that starts zone music asks this, so a boss dying cannot quietly put
-- the old theme back on over a frozen world.
function World:musicName(want)
  if G.run and G.run.flags and G.run.flags.camp_frozen then
    return "untending"
  end
  return want
end

function World:zoneFrozen()
  return G.run and G.run.flags and G.run.flags.camp_frozen or false
end

-- ==================================================================
-- ROOM ART -- decoupled from the collision grid
-- ==================================================================
-- Everything a room looks like used to be a consequence of what it is
-- made of: a `#` is a solid tile and it draws the zone's solid tile,
-- full stop. That is a tight, honest system and it is also why every
-- room in this game is built out of the same sixteen-pixel vocabulary.
--
-- These two layers take art off the grid. An entry sits at arbitrary
-- WORLD pixels, at any size, at any alpha, and owes nothing to what the
-- tile underneath it is:
--
--   room.scenery     drawn BEHIND bodies -- the far wall of a hall, a
--                    shaft of light, a machine too big to be a tile
--   room.foreground  drawn IN FRONT of bodies -- a pillar you pass
--                    behind, a hanging root, the near lip of a ledge
--
-- The foreground is most of what separates a room that reads as a SPACE
-- from a flat wall with things standing on it. Both sit inside the
-- camera transform, so they are hidden by an unlit room and tinted by a
-- frozen one exactly like the geometry they are pretending to belong to.
--
-- THE GATE IS THE DATA. A room with neither table draws nothing, which
-- is every room today. Deliberately not a settings toggle: a switch a
-- player can flip to turn off level geometry is not a graphics option.
--
--   { kind = "rect",   x, y, w, h, col = "shadow", a = 0.8 }
--   { kind = "sprite", name = "prop_pillar", x, y, sx, sy, a }
--   { kind = "band",   x, y, w, h, col, a, a2 }   -- vertical fade
--
-- Any entry may carry `px` / `py`: a scroll factor that shifts it
-- against the camera. px = 0.15 on a scenery entry makes a far wall
-- drift behind the room as you walk, which is the whole point of taking
-- art off the grid -- a tile can only ever be exactly where it is.
-- ==================================================================
function World:drawArtLayer(g, list)
  if not list then return end
  for _, o in ipairs(list) do
    local a = o.a or 1
    -- Parallax INSIDE the camera transform: the offset is added back, so
    -- a factor of 0 is welded to the world and 1 is welded to the screen.
    -- Above 1 the thing is NEARER than the world, which is what sells a
    -- foreground -- it should overtake you as you walk.
    local x = o.x + (o.px and Cam.x * o.px or 0)
    local y = o.y + (o.py and Cam.y * o.py or 0)
    local c = P[o.col or "shadow"] or P.shadow
    local w, h = o.w or T, o.h or T

    if o.kind == "sprite" then
      G.drawSprite(o.name, o.frame or 1, x, y,
        { sx = o.sx, sy = o.sy, alpha = a, flip = o.flip })

    elseif o.kind == "band" then
      -- A vertical fade from `a` to `a2`. The cheapest depth cue there
      -- is: haze is what distance actually looks like.
      local steps = math.max(1, math.min(24, math.floor(h / 4)))
      for i = 0, steps - 1 do
        local t = i / steps
        g.setColor(c[1], c[2], c[3], a + ((o.a2 or 0) - a) * t)
        g.rectangle("fill", x, y + h * t, w, h / steps + 1)
      end

    elseif o.kind == "girder" then
      -- Horizontal truss: two chords and a zig-zag web between them.
      -- Reads as structure at any size, which is what a machine city
      -- that never stopped running is made of.
      local d = o.step or 24
      g.setColor(c[1], c[2], c[3], a)
      g.rectangle("fill", x, y, w, 3)
      g.rectangle("fill", x, y + h - 3, w, 3)
      g.setLineWidth(o.lw or 2)
      local n = math.max(1, math.floor(w / d))
      for i = 0, n - 1 do
        local x0 = x + i * d
        g.line(x0, y + h - 3, x0 + d / 2, y + 3)
        g.line(x0 + d / 2, y + 3, x0 + d, y + h - 3)
      end
      g.setLineWidth(1)

    elseif o.kind == "column" then
      -- Vertical pillar with a cap, a foot and rivet rows.
      g.setColor(c[1], c[2], c[3], a)
      g.rectangle("fill", x, y, w, h)
      g.rectangle("fill", x - 3, y, w + 6, 5)
      g.rectangle("fill", x - 3, y + h - 5, w + 6, 5)
      local acc = P[o.acc or "gray"] or P.gray
      g.setColor(acc[1], acc[2], acc[3], a * 0.7)
      for ry = y + 12, y + h - 12, o.step or 18 do
        g.rectangle("fill", x + 2, ry, 2, 2)
        g.rectangle("fill", x + w - 4, ry, 2, 2)
      end

    elseif o.kind == "rail" then
      -- Handrail: top bar, mid bar, posts. An industrial stairwell is
      -- mostly this.
      g.setColor(c[1], c[2], c[3], a)
      g.rectangle("fill", x, y, w, 2)
      g.rectangle("fill", x, y + h * 0.45, w, 2)
      for px2 = x, x + w, o.step or 20 do
        g.rectangle("fill", px2, y, 2, h)
      end

    elseif o.kind == "shaft" then
      -- A slab of light falling through a gap. Skewed, so it reads as a
      -- beam rather than a rectangle, and it breathes.
      local sk = o.skew or 18
      local br = a * (0.75 + math.sin(G.time * 0.5 + (o.ph or 0)) * 0.25)
      local steps = 14
      for i = 0, steps - 1 do
        local t = i / steps
        g.setColor(c[1], c[2], c[3], br * (1 - t) * 0.5)
        g.rectangle("fill", x + sk * t, y + h * t, w * (1 - t * 0.25), h / steps + 1)
      end

    elseif o.kind == "hang" then
      -- Something hanging and swaying: chain, cable, root, vine. Phase
      -- from its own x so a row of them never moves in unison.
      local sway = math.sin(G.time * (o.rate or 0.8) + (o.ph or x * 0.05)) * (o.sway or 4)
      g.setColor(c[1], c[2], c[3], a)
      local segs = math.max(2, math.floor(h / 8))
      local px2, py2 = x, y
      for i = 1, segs do
        local t = i / segs
        local nx = x + sway * t * t
        local ny = y + h * t
        g.setLineWidth(o.lw or 2)
        g.line(px2, py2, nx, ny)
        px2, py2 = nx, ny
      end
      g.setLineWidth(1)
      if o.bob then
        g.rectangle("fill", px2 - 3, py2, 6, 5)
      end

    elseif o.kind == "stack" then
      -- A ridge of layered silhouettes: the far wall of a big room, a
      -- heap of dead machines, a treeline. Seeded so it is stable.
      local rng = love.math.newRandomGenerator(o.seed or 7)
      g.setColor(c[1], c[2], c[3], a)
      local step = o.step or 22
      local i = 0
      for sx = x, x + w, step do
        local hh = h * (0.45 + rng:random() * 0.55)
        local ww = step * (0.7 + rng:random() * 0.6)
        g.rectangle("fill", sx, y + h - hh, ww, hh)
        i = i + 1
      end

    else
      g.setColor(c[1], c[2], c[3], a)
      g.rectangle("fill", x, y, w, h)
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- THREE layers, and the difference between them is only WHERE IN THE
-- DRAW ORDER they sit -- which is the whole of it:
--
--   backdrop    behind the rock      the far wall, a distant machine
--   scenery     over rock, behind bodies   haze, glow, things ON the rock
--   foreground  in front of bodies   what you pass behind
--
-- Getting this wrong is silent and looks like a bug in the art: a
-- "background" in the scenery layer paints straight over the terrain,
-- which is exactly what the first pass at the deep stairs did.
function World:drawBackdrop(g)
  self:drawArtLayer(g, self.room and self.room.backdrop)
end

function World:drawScenery(g)
  self:drawArtLayer(g, self.room and self.room.scenery)
end

function World:drawForeground(g)
  self:drawArtLayer(g, self.room and self.room.foreground)
end

function World:drawArenaBackdrop(g, arena, ox, oy)
  local W, H = self.w * T, self.h * T
  local floorY = H - 5 * T
  local function X(wx) return wx + ox end
  local function Y(wy) return wy + oy end

  if arena == "bramblemaw" then
    -- root columns and hanging growth: the untended orchard
    for i = 0, 5 do
      local rx = 60 + i * 150 + (i % 2) * 40
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.5)
      g.rectangle("fill", X(rx), Y(0), 10 + (i % 3) * 4, floorY + T)
      g.setColor(P.pine[1], P.pine[2], P.pine[3], 0.45)
      for v = 0, 3 do
        local vy = 20 + v * 34 + math.sin(G.time * 0.6 + i + v) * 3
        g.rectangle("fill", X(rx - 6 + v * 5), Y(vy), 2, 26)
      end
    end
  elseif arena == "rustwarden" then
    -- THE PUMP HALL: a wall of machinery the Warden never left.
    -- Back layer: three great pump bodies, pistons still breathing.
    for i = 0, 2 do
      local px = 90 + i * 260
      local stroke = math.sin(G.time * 0.7 + i * 2.1) * 9
      -- pump housing
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.55)
      g.rectangle("fill", X(px), Y(floorY - 118), 66, 118)
      g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.7)
      g.rectangle("fill", X(px + 6), Y(floorY - 112), 54, 44)
      -- piston cylinder + rod (the slow breath of the hall)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      g.rectangle("fill", X(px + 24), Y(floorY - 150), 18, 38)
      g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.55)
      g.rectangle("fill", X(px + 30), Y(floorY - 134 + stroke), 6, 26)
      -- flywheel, turning at a century's patience
      local wa = G.time * 0.5 + i
      g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.65)
      g.circle("line", X(px + 33), Y(floorY - 58), 22)
      g.circle("line", X(px + 33), Y(floorY - 58), 21)
      for s = 0, 2 do
        local a = wa + s * math.pi / 1.5
        g.line(X(px + 33 - math.cos(a) * 20), Y(floorY - 58 - math.sin(a) * 20),
          X(px + 33 + math.cos(a) * 20), Y(floorY - 58 + math.sin(a) * 20))
      end
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.8)
      g.circle("fill", X(px + 33), Y(floorY - 58), 4)
    end
    -- Mid layer: the mains. Three horizontal runs with flanges/elbows.
    for i = 0, 2 do
      local py = 30 + i * 34
      g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.75)
      g.rectangle("fill", X(0), Y(py), W, 9)
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.8)
      g.rectangle("fill", X(0), Y(py + 7), W, 2)
      for f = 0, 8 do
        local fx = 30 + f * 110 + i * 24
        g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.8)
        g.rectangle("fill", X(fx), Y(py - 2), 5, 13)
      end
    end
    -- risers dropping from the mains to the pumps
    g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.65)
    for i = 0, 4 do
      local rx = 60 + i * 190
      g.rectangle("fill", X(rx), Y(36), 7, floorY - 60)
    end
    -- Valve wheels: one still turns; the rest froze mid-turn.
    for i = 0, 3 do
      local vx2, vy2 = 63 + i * 190, 96 + (i % 2) * 44
      local spin = (i == 1) and G.time * 0.9 or (i * 1.3)
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.9)
      g.circle("line", X(vx2), Y(vy2), 9)
      for s = 0, 2 do
        local a = spin + s * math.pi / 1.5
        g.line(X(vx2 - math.cos(a) * 8), Y(vy2 - math.sin(a) * 8),
          X(vx2 + math.cos(a) * 8), Y(vy2 + math.sin(a) * 8))
      end
      g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.9)
      g.circle("fill", X(vx2), Y(vy2), 2.5)
    end
    -- Dial gauges: a bank of dead needles, and one that still twitches.
    for i = 0, 5 do
      local gx = 50 + i * 150
      local gy = 62 + (i % 3) * 10
      g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
      g.circle("fill", X(gx), Y(gy), 11)
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.9)
      g.circle("fill", X(gx), Y(gy), 9)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      for tick = -2, 2 do
        local a = math.pi * 0.75 + tick * 0.35
        g.line(X(gx + math.cos(a) * 7), Y(gy + math.sin(a) * 7),
          X(gx + math.cos(a) * 9), Y(gy + math.sin(a) * 9))
      end
      local na = math.pi * 0.75 + 1.4   -- dead: pinned at zero
      if i == 2 then                    -- one gauge still believes
        na = math.pi * 0.75 + 0.7 + math.sin(G.time * 6) * 0.12
        g.setColor(P.teal[1], P.teal[2], P.teal[3], 0.9)
      else
        g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.9)
      end
      g.line(X(gx), Y(gy), X(gx + math.cos(na) * 7), Y(gy + math.sin(na) * 7))
      g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.8)
      g.circle("fill", X(gx), Y(gy), 1.5)
    end
    -- a slow drip from a failed joint
    local dripY = (G.time * 40) % 120
    g.setColor(P.sky[1], P.sky[2], P.sky[3], 0.6)
    g.rectangle("fill", X(214), Y(64 + dripY), 2, 4)
  elseif arena == "tideengine" then
    -- drowned terraces: planter rows with green still trying
    for i = 0, 4 do
      local ty = 40 + i * 42
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.5)
      g.rectangle("fill", X(30 + (i % 2) * 60), Y(ty), W - 120, 6)
      g.setColor(P.fern[1], P.fern[2], P.fern[3], 0.4)
      for px = 0, 8 do
        local wx = 50 + (i % 2) * 60 + px * 80
        g.rectangle("fill", X(wx), Y(ty - 6 + math.sin(G.time + px + i) * 1.5), 3, 6)
      end
    end
  elseif arena == "slaggolem" then
    -- THE CASTING FORGE: where the Golem remade itself, over and over.
    -- magma seams glowing through the back wall
    for i = 0, 4 do
      local sx2 = 30 + i * 130 + (i % 2) * 40
      local glow = 0.3 + math.sin(G.time * 1.6 + i * 1.7) * 0.12
      g.setColor(P.magma[1], P.magma[2], P.magma[3], glow)
      g.rectangle("fill", X(sx2), Y(20 + (i % 3) * 24), 3, floorY - 40)
      g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], glow * 0.6)
      g.rectangle("fill", X(sx2 + 1), Y(30 + (i % 3) * 24), 1, floorY - 60)
    end
    -- the stamp press: a great ram that still falls on schedule
    local px = W / 2 - 30
    local cycle = (G.time * 0.5) % 1
    local ram = cycle < 0.12 and (cycle / 0.12) or
      (cycle < 0.2 and 1 or math.max(0, 1 - (cycle - 0.2) / 0.5))
    g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.8)
    g.rectangle("fill", X(px), Y(0), 12, 40)
    g.rectangle("fill", X(px + 48), Y(0), 12, 40)
    g.rectangle("fill", X(px - 4), Y(0), 68, 10)
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.8)
    g.rectangle("fill", X(px + 14), Y(10 + ram * 52), 32, 26)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.8)
    g.rectangle("fill", X(px + 22), Y(10), 16, ram * 52 + 2)
    -- the anvil block beneath it, and a fresh glowing cast
    g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.85)
    g.rectangle("fill", X(px + 10), Y(floorY - 22), 40, 22)
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3],
      0.5 + (ram > 0.9 and 0.4 or 0))
    g.rectangle("fill", X(px + 20), Y(floorY - 26), 20, 5)
    -- casting molds: rows of ingot trays, some still glowing
    for i = 0, 5 do
      local mx = 40 + i * 90
      if mx < px - 50 or mx > px + 110 then
        g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.8)
        g.rectangle("fill", X(mx), Y(floorY - 10), 34, 10)
        for c2 = 0, 2 do
          local hot = (i + c2) % 3 == 0
          if hot then
            g.setColor(P.magma[1], P.magma[2], P.magma[3],
              0.5 + math.sin(G.time * 3 + i + c2) * 0.2)
          else
            g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.7)
          end
          g.rectangle("fill", X(mx + 3 + c2 * 10), Y(floorY - 8), 7, 5)
        end
      end
    end
    -- racks of metal stock: uprights with leaning billets
    for i = 0, 2 do
      local rx = 46 + i * 300
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.75)
      g.rectangle("fill", X(rx), Y(floorY - 74), 4, 74)
      g.rectangle("fill", X(rx + 40), Y(floorY - 74), 4, 74)
      g.rectangle("fill", X(rx - 2), Y(floorY - 74), 48, 4)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      for b2 = 0, 4 do
        g.rectangle("fill", X(rx + 5 + b2 * 7), Y(floorY - 66 + b2 * 2), 3,
          64 - b2 * 2)
      end
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.7)
      g.rectangle("fill", X(rx + 8), Y(floorY - 40), 30, 3)
    end
  elseif arena == "crucible" then
    -- the foundry heights: chimneys, chains, and part hoppers
    for i = 0, 3 do
      local cx2 = 70 + i * 150
      g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.5)
      g.rectangle("fill", X(cx2), Y(0), 22, 90 + (i % 2) * 30)
      g.setColor(P.magma[1], P.magma[2], P.magma[3],
        0.25 + math.sin(G.time * 2 + i) * 0.1)
      g.rectangle("fill", X(cx2 + 7), Y(84 + (i % 2) * 30), 8, 5)
    end
    g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.7)
    for i = 0, 5 do
      g.rectangle("fill", X(40 + i * 100), Y(0), 2, 46 + (i % 3) * 16)
      g.rectangle("fill", X(36 + i * 100), Y(44 + (i % 3) * 16), 10, 8)
    end
  elseif arena == "prismtyrant" then
    -- the crystal organ: a rank of singing shards
    for i = 0, 9 do
      local px = 40 + i * 88
      local ph = 60 + (i * 37) % 70
      local hum = math.sin(G.time * 1.5 + i) * 0.08
      g.setColor(P.plum[1], P.plum[2], P.plum[3], 0.5)
      g.polygon("fill", X(px), Y(floorY), X(px + 10), Y(floorY),
        X(px + 5), Y(floorY - ph))
      g.setColor(P.orchid[1], P.orchid[2], P.orchid[3], 0.3 + hum)
      g.polygon("line", X(px), Y(floorY), X(px + 10), Y(floorY),
        X(px + 5), Y(floorY - ph))
    end
  elseif arena == "aeriesentinel" then
    -- the sky door and the watch-perches
    g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.25)
    g.circle("line", X(W / 2), Y(30), 46)
    g.circle("line", X(W / 2), Y(30), 38)
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.5)
    for i = 0, 2 do
      g.rectangle("fill", X(80 + i * 260), Y(70 + i * 20), 60, 4)
      g.rectangle("fill", X(106 + i * 260), Y(74 + i * 20), 6, 30)
    end
  elseif arena == "mycelchoir" then
    -- fungal columns, listening
    for i = 0, 4 do
      local fx = 60 + i * 100
      g.setColor(P.plum[1], P.plum[2], P.plum[3], 0.45)
      g.rectangle("fill", X(fx), Y(floorY - 90 - (i % 2) * 30), 12, 90 + (i % 2) * 30 + T)
      g.setColor(P.violet[1], P.violet[2], P.violet[3], 0.4)
      g.ellipse("fill", X(fx + 6), Y(floorY - 92 - (i % 2) * 30), 16, 6)
    end
  elseif arena == "archivist" then
    -- the deep stacks, shelved to the dark
    for i = 0, 6 do
      local sx2 = 30 + i * 130
      g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.5)
      g.rectangle("fill", X(sx2), Y(20), 36, floorY - 14)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.4)
      for s = 0, 5 do
        g.rectangle("fill", X(sx2 + 3), Y(34 + s * 34), 30, 3)
      end
    end
  elseif arena == "motherengine" then
    -- the heart-wall: cable falls into the dark
    for i = 0, 8 do
      local cx2 = 40 + i * 88
      local sway = math.sin(G.time * 0.8 + i) * 3
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.75)
      g.rectangle("fill", X(cx2 + sway), Y(0), 4, floorY - 20 - (i % 3) * 30)
      g.setColor(P.cyan[1], P.cyan[2], P.cyan[3],
        0.2 + math.sin(G.time * 1.4 + i * 2) * 0.1)
      g.circle("fill", X(cx2 + 2 + sway), Y(floorY - 18 - (i % 3) * 30), 2.5)
    end

  -- ================================================================
  -- THE SCRAPYARD
  -- ================================================================
  -- Sorting Yard 7. Three parallax ranks of dead caretaker frames, stacked
  -- and leaning and hung from chains -- every one of them the same
  -- silhouette as the bot the player is standing in. A few still have an
  -- eye lit; some of those go out as you pass. Deliberately NOT a light-
  -- radius mechanic: this zone must never depend on a Lu module.
  elseif arena == "scrapyard" or arena == "vessel8" then
    local ranks = {
      { n = 7, a = 0.30, sc = 0.55, y = floorY - 6, step = 96, seed = 3 },
      { n = 9, a = 0.44, sc = 0.80, y = floorY + 2, step = 74, seed = 11 },
      { n = 6, a = 0.62, sc = 1.05, y = floorY + 8, step = 118, seed = 23 },
    }
    -- hanging chains, behind everything
    g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.8)
    for i = 0, 9 do
      local hx = 30 + i * 92 + (i % 3) * 13
      g.rectangle("fill", X(hx), Y(0), 2, 40 + (i * 37) % 90)
    end
    for r, rk in ipairs(ranks) do
      for i = 0, rk.n - 1 do
        local k = i * rk.seed
        local fx = 24 + i * rk.step + (k % 37)
        local lean = ((k % 7) - 3) * 0.09
        local bw, bh = 13 * rk.sc, 26 * rk.sc
        local fy = rk.y - (k % 3) * 5
        g.push()
        g.translate(X(fx), Y(fy))
        g.rotate(lean)
        -- torso
        g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], rk.a)
        g.rectangle("fill", -bw / 2, -bh, bw, bh)
        -- head, on the ones that still have one
        if k % 4 ~= 0 then
          g.setColor(P.gray[1], P.gray[2], P.gray[3], rk.a * 0.9)
          g.rectangle("fill", -bw / 2 + 1, -bh - 8 * rk.sc, bw - 2, 8 * rk.sc)
        end
        -- legs, on the ones that still have those
        if k % 5 ~= 0 then
          g.setColor(P.dark[1], P.dark[2], P.dark[3], rk.a)
          g.rectangle("fill", -bw / 2 + 1, 0, 3 * rk.sc, 9 * rk.sc)
          g.rectangle("fill", bw / 2 - 3 * rk.sc - 1, 0, 3 * rk.sc, 9 * rk.sc)
        end
        -- one eye, still lit. It flickers, and some of them give up.
        if k % 6 == 1 then
          local life = 0.5 + 0.5 * math.sin(G.time * (0.7 + (k % 5) * 0.3) + k)
          local giveUp = math.sin(G.time * 0.13 + k * 1.7)
          if giveUp > -0.2 then
            g.setColor(P.blood[1], P.blood[2], P.blood[3], rk.a * life * 1.4)
            g.circle("fill", 1.5 * rk.sc, -bh - 4 * rk.sc, 1.3 * rk.sc)
          end
        end
        g.pop()
      end
    end
    -- drifting ash, not embers. Nothing here is burning any more.
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.22)
    for i = 0, 25 do
      local ax = (i * 71 + G.time * (5 + (i % 4) * 3)) % (W + 40) - 20
      local ay = (i * 53 + G.time * (11 + (i % 3) * 5)) % (H + 20) - 10
      g.circle("fill", X(ax), Y(ay), 0.8 + (i % 3) * 0.35)
    end
    if arena == "vessel8" then
      -- EIGHT's room: the frames here are intact, sorted, and racked. It
      -- did the filing itself.
      g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.45)
      for i = 0, 3 do
        g.rectangle("fill", X(40 + i * 150), Y(floorY - 74), 92, 3)
        g.rectangle("fill", X(40 + i * 150), Y(floorY - 38), 92, 3)
      end
      -- and one rack left empty, at head height, waiting
      g.setColor(P.blood[1], P.blood[2], P.blood[3],
        0.16 + 0.06 * math.sin(G.time * 0.9))
      g.rectangle("fill", X(W / 2 - 14), Y(floorY - 72), 28, 32)
    end

  -- ================================================================
  -- EMBER CAMP
  -- ================================================================
  elseif arena == "campshop" then
    -- JUN'S MAINTENANCE SHOP: a century of half-finished work. Pegboards,
    -- benches, cable runs, and a lathe he has not switched off in years.
    local base = H - 4 * T
    -- cable runs sagging along the back wall
    for i = 0, 3 do
      local yy = 40 + i * 22
      g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], 0.7)
      for seg = 0, 11 do
        local sx = 30 + seg * 50
        local sag = math.sin(seg * 0.9 + i) * 5 + 6
        g.line(X(sx), Y(yy), X(sx + 25), Y(yy + sag))
        g.line(X(sx + 25), Y(yy + sag), X(sx + 50), Y(yy))
      end
    end
    -- pegboards with tools hung in rows
    for b = 0, 2 do
      local bx = 70 + b * 190
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.55)
      g.rectangle("fill", X(bx), Y(52), 84, 54)
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.6)
      g.rectangle("line", X(bx), Y(52), 84, 54)
      for t = 0, 5 do
        local tx = bx + 8 + t * 13
        local hang = 10 + (t % 3) * 9
        g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.75)
        g.rectangle("fill", X(tx), Y(58), 2, hang)
        g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
        if t % 3 == 0 then
          g.rectangle("fill", X(tx - 3), Y(58 + hang), 8, 4)     -- hammer head
        elseif t % 3 == 1 then
          g.circle("line", X(tx + 1), Y(58 + hang + 3), 4)       -- wrench eye
        else
          g.polygon("fill", X(tx - 2), Y(58 + hang), X(tx + 4), Y(58 + hang),
            X(tx + 1), Y(58 + hang + 6))                          -- pliers
        end
      end
    end
    -- benches, crates and a parts bin along the floor
    for b = 0, 4 do
      local bx = 40 + b * 130
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.8)
      g.rectangle("fill", X(bx), Y(base - 26), 96, 8)
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.85)
      g.rectangle("fill", X(bx + 6), Y(base - 18), 7, 18)
      g.rectangle("fill", X(bx + 83), Y(base - 18), 7, 18)
      -- clutter on top: jars, coils, a stub of pipe
      g.setColor(P.teal[1], P.teal[2], P.teal[3], 0.6)
      g.rectangle("fill", X(bx + 20), Y(base - 34), 8, 8)
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.7)
      g.circle("line", X(bx + 46), Y(base - 31), 6)
      g.circle("line", X(bx + 46), Y(base - 31), 3)
      g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.7)
      g.rectangle("fill", X(bx + 62), Y(base - 32), 18, 5)
    end
    -- the lathe, still turning
    local lx = 300
    g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], 0.9)
    g.rectangle("fill", X(lx), Y(base - 44), 70, 44)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.8)
    g.rectangle("fill", X(lx + 6), Y(base - 38), 58, 10)
    local spin = G.time * 3
    g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.75)
    g.circle("line", X(lx + 14), Y(base - 33), 7)
    g.line(X(lx + 14 - math.cos(spin) * 6), Y(base - 33 - math.sin(spin) * 6),
      X(lx + 14 + math.cos(spin) * 6), Y(base - 33 + math.sin(spin) * 6))
    -- a work lamp over the bench, the only warm thing in here
    g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.5 + math.sin(G.time * 2) * 0.06)
    g.circle("fill", X(230), Y(70), 5)
    World.glow(X(230), Y(70), 54, P.gold, 0.16)

  elseif arena == "embercamp" then
    -- EMBER CAMP: a settlement, not a cave. Huts, crates, hammocks,
    -- drying lines and small lanterns -- all of it deliberately dimmer
    -- and smaller than the Ember burning at the middle of the room.
    local base = H - 5 * T
    local emberX = 37 * T
    -- back wall of the cavern, warmed unevenly by the great fire
    for i = 0, 9 do
      local px = 20 + i * 96
      local d = math.abs(px - emberX) / (W * 0.6)
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.30 - d * 0.16)
      g.rectangle("fill", X(px), Y(30), 70, base - 30)
    end
    -- huts: a big one on the left (the one you can enter), then smaller
    local huts = { { 150, 120, 78 }, { 330, 78, 52 }, { 620, 92, 58 },
                   { 760, 70, 46 }, { 890, 84, 54 } }
    for i, hut in ipairs(huts) do
      local hx, hw, hh = hut[1], hut[2], hut[3]
      local hy = base - hh
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.9)
      g.rectangle("fill", X(hx), Y(hy), hw, hh)
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.95)
      g.polygon("fill", X(hx - 8), Y(hy), X(hx + hw + 8), Y(hy),
        X(hx + hw / 2), Y(hy - 22))
      g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], 0.8)
      for pl = 0, 3 do
        g.line(X(hx + 6 + pl * (hw / 4)), Y(hy), X(hx + 6 + pl * (hw / 4)), Y(hy + hh))
      end
      -- a lit window each, small and yellow
      g.setColor(P.gold[1], P.gold[2], P.gold[3],
        0.35 + math.sin(G.time * 1.3 + i * 2) * 0.07)
      g.rectangle("fill", X(hx + hw - 22), Y(hy + 14), 12, 10)
    end
    -- hammocks slung between the huts
    for i = 0, 2 do
      local ax = 250 + i * 230
      local sag = math.sin(G.time * 0.7 + i) * 2
      g.setColor(P.cream[1], P.cream[2], P.cream[3], 0.35)
      for seg = 0, 8 do
        local t1, t2 = seg / 8, (seg + 1) / 8
        local function hy(t) return base - 54 + math.sin(t * math.pi) * (14 + sag) end
        g.line(X(ax + t1 * 90), Y(hy(t1)), X(ax + t2 * 90), Y(hy(t2)))
      end
    end
    -- drying lines with cloth
    for i = 0, 1 do
      local ax = 420 + i * 300
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.5)
      g.line(X(ax), Y(base - 96), X(ax + 140), Y(base - 92))
      for c = 0, 4 do
        local cxx = ax + 14 + c * 26
        local flap = math.sin(G.time * 1.6 + c) * 2
        g.setColor(c % 2 == 0 and P.fern or P.maroon)
        g.rectangle("fill", X(cxx + flap), Y(base - 94 + c), 10, 16)
      end
    end
    -- crates, barrels and stacked equipment
    for i = 0, 11 do
      local bx = 60 + i * 78 + (i % 3) * 11
      local bh = 12 + (i % 3) * 7
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.85)
      g.rectangle("fill", X(bx), Y(base - bh), 20, bh)
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.9)
      g.rectangle("line", X(bx), Y(base - bh), 20, bh)
      if i % 4 == 0 then
        g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.8)
        g.rectangle("fill", X(bx + 24), Y(base - 16), 12, 16, 3, 3)
      end
    end
    -- the small lanterns: deliberately modest next to the Ember
    for i = 0, 6 do
      local lx = 90 + i * 128
      if math.abs(lx - emberX) > 90 then
        local flick = 0.30 + math.sin(G.time * 2.4 + i * 1.7) * 0.06
        g.setColor(P.shadow)
        g.rectangle("fill", X(lx), Y(base - 60), 2, 26)
        g.setColor(P.ember[1], P.ember[2], P.ember[3], flick)
        g.circle("fill", X(lx + 1), Y(base - 62), 3)
        World.glow(X(lx + 1), Y(base - 62), 30, P.ember, 0.10)
      end
    end

  elseif arena == "camphut" then
    -- INSIDE THE LONG HUT: bunks, a stove, and everything the camp
    -- could not fit outdoors.
    local base = H - 5 * T
    g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.55)
    g.rectangle("fill", X(0), Y(0), W, base)
    g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.8)
    for i = 0, 14 do
      g.rectangle("fill", X(i * 34), Y(0), 5, base)     -- wall timbers
    end
    -- bunks along the back
    for i = 0, 3 do
      local bx = 40 + i * 100
      for tier = 0, 1 do
        local by = base - 34 - tier * 30
        g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.95)
        g.rectangle("fill", X(bx), Y(by), 74, 6)
        g.setColor(P.cream[1], P.cream[2], P.cream[3], 0.30)
        g.rectangle("fill", X(bx + 6), Y(by - 7), 62, 7)
        g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.55)
        g.rectangle("fill", X(bx + 44), Y(by - 9), 22, 9)
      end
    end
    -- the stove, small and warm
    local sx = W / 2 - 14
    g.setColor(P.shadow)
    g.rectangle("fill", X(sx), Y(base - 40), 28, 40, 3, 3)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.9)
    g.rectangle("fill", X(sx + 11), Y(base - 76), 6, 36)
    local flick = 0.5 + math.sin(G.time * 3.1) * 0.14
    g.setColor(P.ember[1], P.ember[2], P.ember[3], flick)
    g.rectangle("fill", X(sx + 7), Y(base - 26), 14, 10, 2, 2)
    World.glow(X(sx + 14), Y(base - 21), 52, P.ember, 0.16)
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- Darkness: dark rooms are wrapped in shadow; light radiates from Lu
-- (wider with the Lume Core / dome), from Vess faintly, and from any
-- entity that carries a lightR (glowmites, struck sporebulbs, the
-- singing choir throat, waypoint props).
-- ------------------------------------------------------------------
-- ==================================================================
-- LIGHT
-- ==================================================================
-- Two models, one list of lights.
--
-- The MASK (shipped) is a black rectangle with soft holes punched in it,
-- three concentric circles per light. It is SUBTRACTIVE: it can take
-- darkness away and that is all it can do. It cannot tint, two lamps
-- overlapping are no brighter than one, and at RS=4 its three fixed
-- alpha steps read as three visible rings.
--
-- The BUFFER accumulates coloured light additively into its own canvas
-- and MULTIPLIES the scene by it. Unlit is a floor rather than a void,
-- overlapping lamps add up, and Lu's lume can be cold while the Ember is
-- warm -- which is most of what makes a dark room read as a place with
-- things burning in it rather than a screen with holes cut in it.
--
-- This is a LOOK, not a quality setting. It changes the character of
-- Undergrove, Coldstore and the Cradle, so it ships OFF.

local PROP_GLOW = { save = 26, checkpoint = 24, teleporter = 30 }

-- Light TINTS -- what a source throws, not what it is painted. Kept
-- apart from the palette deliberately: a brazier is orange and throws
-- orange, but Lu is white and throws cold.
local LIGHT_VESS = { 1.00, 0.72, 0.42 }
local LIGHT_LU   = { 0.62, 0.86, 1.00 }
local LIGHT_SHOT = { 0.85, 0.95, 1.00 }
local LIGHT_PROP = { 1.00, 0.82, 0.55 }
local LIGHT_WARM = { 1.00, 0.78, 0.50 }

-- ONE OWNER for what emits light, how far, and what colour.
--
-- Both models read this. Letting each keep its own list is precisely how
-- a prop ends up glowing under one model and invisible under the other,
-- and nobody would find out until they switched.
--
-- The mask ignores `col`; it is the entire point of the buffer.
function World:eachLight(fn)
  -- Lights the ROOM asks for, in world pixels.
  --
  -- Art in scenery/foreground does NOT emit. A lamp you can see and a
  -- lamp that lights the floor around it are two different things, and a
  -- room that wants one almost always wants both -- so the art goes in
  -- room.scenery and the light goes here, at the same coordinates.
  --
  --   room.lights = { { x, y, r = 60, col = {1,.8,.5}, flicker = 7 } }
  --
  -- `flicker` is a rate: a lamp that breathes a little reads as fire
  -- rather than as a bulb, and a corridor of them never pulses in step
  -- because each is phased off its own x.
  local rl = self.room and self.room.lights
  if rl then
    for _, L in ipairs(rl) do
      local r = L.r or 40
      if L.flicker then
        r = r * (1 + math.sin(G.time * L.flicker + (L.ph or L.x * 0.07)) * 0.07)
      end
      fn(L.x, L.y, r, L.col or LIGHT_WARM)
    end
  end
  for _, pl in ipairs(self.players) do
    if not pl.dead and not pl.idle then
      local r, col
      if pl.isVess then
        r, col = 34, LIGHT_VESS
      else
        r = G.run.flags.lumecore and 105 or 68
        if pl.domeActive then r = r + 22 end
        col = LIGHT_LU
      end
      fn(pl.x + pl.w / 2, pl.y + pl.h / 2, r, col)
    end
  end
  for _, e in ipairs(self.entities) do
    if not e.dead then
      if e.lightR then
        fn(e.x + e.w / 2, e.y + e.h / 2, e.lightR, e.lightCol or LIGHT_WARM)
      elseif e.kind == "proj" and e.side == "player" then
        fn(e.x + e.w / 2, e.y + e.h / 2, 15, LIGHT_SHOT)
      elseif PROP_GLOW[e.kind] then
        fn(e.x + e.w / 2, e.y + e.h / 2, PROP_GLOW[e.kind], LIGHT_PROP)
      elseif e.interactable then
        fn(e.x + e.w / 2, e.y + e.h / 2, 16, LIGHT_PROP)
      end
    end
  end
end

-- One soft radial falloff, generated once and scaled per light. Squared,
-- so there is a bright core, a long tail, and no step anywhere -- the
-- mask's three fixed alphas are exactly what produce the rings that
-- become obvious once the canvas is dense enough to show them.
local lightTex
local function getLightTex()
  if lightTex then return lightTex end
  local S = 128
  local d = love.image.newImageData(S, S)
  local c = (S - 1) / 2
  d:mapPixel(function(x, y)
    local dx, dy = (x - c) / c, (y - c) / c
    local f = math.max(0, 1 - math.sqrt(dx * dx + dy * dy))
    return 1, 1, 1, f * f
  end)
  lightTex = love.graphics.newImage(d)
  lightTex:setFilter("linear", "linear")
  return lightTex
end

function World:drawLight(g)
  if G.settings.lighting == "buffer" then
    self:drawLightBuffer(g)
  else
    self:drawDarkness(g)
  end
end

function World:drawLightBuffer(g)
  local RS = G.RS or 1
  if not self.lightCanvas or self.lightRS ~= RS then
    self.lightCanvas = love.graphics.newCanvas(G.VW * RS, G.VH * RS)
    self.lightRS = RS
  end
  local tex = getLightTex()
  local tw = tex:getWidth()
  local dark = math.min(0.96, self.room.dark or 0.85)
  -- AMBIENT: what an unlit pixel keeps. The mask takes `dark` away as
  -- flat black; here the same number becomes a floor that light is added
  -- on top of. Tinted cold on purpose -- unlit rock at the bottom of the
  -- world is not grey, and a neutral ambient makes an unlit room read as
  -- "turned down" rather than "deep".
  local amb = 1 - dark
  -- The offset the camera REALLY used, shake included. Reading Cam.x
  -- here instead slides the light off the world on every explosion.
  local cx0, cy0 = Cam.ox, Cam.oy
  local prev = g.getCanvas()

  g.push()
  g.setCanvas(self.lightCanvas)
  g.origin()
  g.scale(RS)
  g.clear(amb * 0.80, amb * 0.88, amb * 1.18, 1)
  g.setBlendMode("add")
  self:eachLight(function(wx, wy, r, col)
    if r <= 0 then return end
    local sx, sy = wx - cx0, wy - cy0
    if sx < -r or sy < -r or sx > G.VW + r or sy > G.VH + r then return end
    local s = (r * 2) / tw
    g.setColor(col[1], col[2], col[3], 1)
    g.draw(tex, sx, sy, 0, s, s, tw / 2, tw / 2)
  end)
  g.setBlendMode("alpha")
  g.setCanvas(prev)
  g.pop()

  g.push()
  g.origin()
  -- MULTIPLY the scene by the light map. LOVE requires "premultiplied"
  -- for multiply; this buffer is cleared at alpha 1 and only ever added
  -- to, so every pixel is opaque and it is a straight RGB multiply.
  g.setColor(1, 1, 1, 1)
  g.setBlendMode("multiply", "premultiplied")
  g.draw(self.lightCanvas, 0, 0)
  g.setBlendMode("alpha")
  -- ...then a little of the same buffer ADDED back. A real bloom wants a
  -- downsample and a blur pass; this gets most of the read for one more
  -- draw, and what it buys is a lamp bleeding past the edge of what it
  -- lights instead of stopping dead at it.
  local glow = G.settings.glow or 0
  if glow > 0 then
    g.setBlendMode("add")
    g.setColor(1, 1, 1, glow)
    g.draw(self.lightCanvas, 0, 0)
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
  end
  g.pop()
end

function World:drawDarkness(g)
  local RS = G.RS or 1
  if not self.darkCanvas or self.darkRS ~= RS then
    self.darkCanvas = love.graphics.newCanvas(G.VW * RS, G.VH * RS)
    self.darkRS = RS
  end
  local dark = math.min(0.96, self.room.dark or 0.85)
  local prev = g.getCanvas()
  -- PUSH BEFORE origin(). This function wiped the transform and never put
  -- it back. It worked only because it is the LAST thing drawn inside
  -- Cam.apply()/unapply(), so that pop() happened to clean up after it --
  -- anything added below this call would have drawn at the origin. Once
  -- love.draw carries a scale(G.RS), the wipe takes the render scale with
  -- it too, and the overlay covers a quarter of the screen.
  g.push()
  g.setCanvas(self.darkCanvas)
  g.origin()
  g.scale(RS)                       -- the holes stay in logical units
  g.clear(0, 0, 0, dark)
  g.setBlendMode("replace")
  -- Project through the offset the camera REALLY used. Using Cam.x here
  -- ignored screen shake, so every explosion slid the dark frame and the
  -- light spheres away from the world for as long as it lasted.
  local cx0, cy0 = Cam.ox, Cam.oy
  local function hole(wx, wy, r)
    if r <= 0 then return end
    local sx, sy = wx - cx0, wy - cy0
    if sx < -r or sy < -r or sx > G.VW + r or sy > G.VH + r then return end
    g.setColor(0, 0, 0, dark * 0.55)
    g.circle("fill", sx, sy, r)
    g.setColor(0, 0, 0, dark * 0.22)
    g.circle("fill", sx, sy, r * 0.72)
    g.setColor(0, 0, 0, 0)
    g.circle("fill", sx, sy, r * 0.45)
  end
  -- Same lights, same order, same radii as before -- read from the one
  -- list both models share, rather than from a second copy kept here.
  self:eachLight(function(wx, wy, r) hole(wx, wy, r) end)
  g.setBlendMode("alpha")
  g.setCanvas(prev)
  g.pop()
  g.setColor(1, 1, 1, 1)
  -- g.origin() above cleared the camera translate for the rest of this
  -- function, so this draw is in SCREEN space. It used to be drawn at
  -- (Cam.x, Cam.y), which pushed the whole overlay off by exactly the
  -- scroll distance -- fine in a single-screen room, badly wrong anywhere
  -- the camera moves. The canvas is already screen-sized and screen-aligned.
  g.push()
  g.origin()
  g.draw(self.darkCanvas, 0, 0)
  g.pop()
end

-- ------------------------------------------------------------------
-- Zone decorations (code-drawn, seeded per room)
-- ------------------------------------------------------------------
function World.glow(x, y, r, col, a)
  local g = love.graphics
  g.setColor(col[1], col[2], col[3], a * 0.25)
  g.circle("fill", x, y, r)
  g.setColor(col[1], col[2], col[3], a * 0.35)
  g.circle("fill", x, y, r * 0.6)
  g.setColor(col[1], col[2], col[3], a * 0.5)
  g.circle("fill", x, y, r * 0.3)
  g.setColor(1, 1, 1, 1)
end

function World:drawDecor(g, tx0, ty0, tx1, ty1)
  if not self.decor then return end
  local zone = self.zone
  local x0, y0 = tx0 * T - 16, ty0 * T - 16
  local x1, y1 = tx1 * T + 32, ty1 * T + 32
  for _, d in ipairs(self.decor) do
    if d.x > x0 and d.x < x1 and d.y > y0 and d.y < y1 then
      local sway = math.sin(G.time * 1.6 + d.ph) * 1.2
      if d.kind == "floor" then
        if zone == "mosswood" or zone == "camp" then
          if d.v == 1 then -- grass tuft
            g.setColor(P.leaf)
            g.line(d.x, d.y, d.x - 1 + sway, d.y - 4 * d.s)
            g.line(d.x + 2, d.y, d.x + 2 + sway, d.y - 5 * d.s)
            g.setColor(P.fern)
            g.line(d.x + 4, d.y, d.x + 4 + sway, d.y - 3 * d.s)
          elseif d.v == 2 then -- little mushroom
            g.setColor(P.cream)
            g.rectangle("fill", d.x + 1, d.y - 3, 2, 3)
            g.setColor(zone == "camp" and P.ember or P.pink)
            g.rectangle("fill", d.x - 1, d.y - 5, 6, 3, 1, 1)
          else -- pebbles
            g.setColor(P.gray)
            g.rectangle("fill", d.x, d.y - 2, 3, 2)
            g.setColor(P.slate)
            g.rectangle("fill", d.x + 4, d.y - 1, 2, 1)
          end
        elseif zone == "flooded" then
          if d.v == 1 then -- kelp
            g.setColor(P.teal)
            g.line(d.x, d.y, d.x + sway, d.y - 6 * d.s, d.x - sway, d.y - 11 * d.s)
          elseif d.v == 2 then -- barnacles
            g.setColor(P.ice)
            g.circle("fill", d.x, d.y - 1, 1.4)
            g.circle("fill", d.x + 4, d.y - 1, 1.1)
          else
            g.setColor(P.deepsea)
            g.rectangle("fill", d.x, d.y - 3, 2, 3)
            g.rectangle("fill", d.x + 3, d.y - 2, 2, 2)
          end
        elseif zone == "furnace" then
          if d.v == 1 then -- glowing vent
            g.setColor(P.dark)
            g.rectangle("fill", d.x - 1, d.y - 2, 6, 2)
            local pulse = 0.4 + math.sin(G.time * 3 + d.ph) * 0.3
            g.setColor(P.magma[1], P.magma[2], P.magma[3], pulse)
            g.rectangle("fill", d.x, d.y - 1, 4, 1)
          elseif d.v == 2 then -- slag lump
            g.setColor(P.maroon)
            g.circle("fill", d.x + 1, d.y - 1, 2)
            g.setColor(P.rust)
            g.circle("fill", d.x + 3, d.y - 1, 1.3)
          else
            g.setColor(P.soil)
            g.rectangle("fill", d.x, d.y - 2, 4, 2)
          end
        elseif zone == "crystal" then
          if d.v <= 2 then -- crystal cluster
            local c1 = d.v == 1 and P.orchid or P.violet
            g.setColor(c1)
            g.polygon("fill", d.x, d.y, d.x + 2, d.y - 6 * d.s, d.x + 4, d.y)
            g.setColor(P.spark[1], P.spark[2], P.spark[3],
              0.5 + math.sin(G.time * 2 + d.ph) * 0.3)
            g.polygon("fill", d.x + 3, d.y, d.x + 4.5, d.y - 4 * d.s, d.x + 6, d.y)
          else
            g.setColor(P.gloom)
            g.rectangle("fill", d.x, d.y - 2, 3, 2)
          end
        elseif zone == "skyroot" then
          if d.v == 1 then -- root curl
            g.setColor(P.brown)
            g.line(d.x, d.y, d.x + 2 + sway, d.y - 5 * d.s, d.x + 5 + sway, d.y - 4 * d.s)
          elseif d.v == 2 then
            g.setColor(P.leaf)
            g.line(d.x, d.y, d.x + sway, d.y - 4 * d.s)
            g.line(d.x + 3, d.y, d.x + 3 + sway, d.y - 6 * d.s)
          else
            g.setColor(P.umber)
            g.rectangle("fill", d.x, d.y - 2, 4, 2)
          end
        elseif zone == "core" then
          if d.v == 1 then -- terminal with blinking light
            g.setColor(P.dark)
            g.rectangle("fill", d.x - 1, d.y - 4, 6, 4)
            local on = math.floor(G.time * 2 + d.ph) % 2 == 0
            g.setColor(on and P.cyan or P.teal)
            g.rectangle("fill", d.x + 1, d.y - 3, 2, 1)
          elseif d.v == 2 then -- cable stub
            g.setColor(P.shadow)
            g.line(d.x, d.y, d.x + 3, d.y - 3, d.x + 7, d.y - 2)
            g.setColor(P.cyan)
            g.circle("fill", d.x + 7, d.y - 2, 1)
          else
            g.setColor(P.gray)
            g.rectangle("fill", d.x, d.y - 1, 3, 1)
          end
        end
      else -- ceiling decor
        if zone == "mosswood" or zone == "camp" or zone == "skyroot" then
          g.setColor(P.fern)
          g.line(d.x, d.y, d.x + sway * 0.5, d.y + 5 * d.s, d.x + sway, d.y + 9 * d.s)
          g.setColor(P.leaf)
          g.circle("fill", d.x + sway, d.y + 9 * d.s, 1)
        elseif zone == "flooded" then
          g.setColor(P.teal)
          g.line(d.x, d.y, d.x, d.y + 3 * d.s)
          -- drip
          local dripT = (G.time * 0.7 + d.ph) % 2
          if dripT < 1 then
            g.setColor(P.sky[1], P.sky[2], P.sky[3], 0.8)
            g.rectangle("fill", d.x - 0.5, d.y + 3 + dripT * 22, 1, 2)
          end
        elseif zone == "furnace" then
          g.setColor(P.shadow)
          g.line(d.x, d.y, d.x, d.y + 6 * d.s)
          g.setColor(P.gray)
          g.circle("fill", d.x, d.y + 6 * d.s, 1)
        elseif zone == "crystal" then
          g.setColor(P.violet)
          g.polygon("fill", d.x - 2, d.y, d.x + 2, d.y, d.x, d.y + 6 * d.s)
        elseif zone == "core" then
          g.setColor(P.shadow)
          g.line(d.x, d.y, d.x + sway, d.y + 7 * d.s)
          g.setColor(P.blood[1], P.blood[2], P.blood[3],
            0.4 + math.sin(G.time * 4 + d.ph) * 0.3)
          g.circle("fill", d.x + sway, d.y + 7 * d.s, 1)
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- Transitions
-- ------------------------------------------------------------------
-- Called by player logic when standing at a portal door pressing up,
-- or automatically when overlapping an edge door.
function World:doorSealed(d)
  return d and d.req and not G.run.flags[d.req]
end

-- IS EVERY BOT IN THIS DOOR'S MOUTH?  (COOP-PLAN 7.1)
--
-- A door is a shared decision now: it does not fire until both bodies
-- are in it. Readable, and it makes every transition something the pair
-- agree to rather than something one of them does to the other.
--
-- SOLO COUNTS THE PARKED BOT AS PRESENT, or solo play stops at the first
-- door in the game. `S:recallIdleBot` already teleports the idle bot to
-- you, so the solo loop is: walk to the door, recall, step through --
-- which is the right amount of friction. The test is on `idle`, not on
-- position, precisely so that loop keeps working.
--
-- A DOWNED bot also counts. A rescue that has to happen before you can
-- leave the room is a death sentence rather than a mechanic, and the
-- revive is already a thing you choose to do.
function World:doorHasEveryone(d)
  local n, inside = 0, 0
  for _, p in ipairs(self.players or {}) do
    if not p.dead then
      n = n + 1
      if p.idle or p.downed
        or U.aabb(p.x, p.y, p.w, p.h, d.x0 * T, d.y0 * T,
                  (d.x1 - d.x0 + 1) * T, (d.y1 - d.y0 + 1) * T) then
        inside = inside + 1
      end
    end
  end
  return n == 0 or inside >= n
end

function World:requestTransition(doorChar)
  local d = self.doors[doorChar]
  if not d or not d.link then return end
  if not self:doorHasEveryone(d) then
    -- Say so, but not every frame: standing in a door with your partner
    -- across the room is a state you can be in for a while.
    if not self.bothNagT or G.time - self.bothNagT > 2.5 then
      self.bothNagT = G.time
      if G.game then
        G.game:announce("This door needs BOTH bots.", 1.6)
      end
    end
    return
  end
  if self:doorSealed(d) then
    if not self.sealNagT or G.time - self.sealNagT > 2 then
      self.sealNagT = G.time
      if G.game then G.game:announce("Sealed. Something in this room is not finished.", 2) end
      if G.Audio then G.Audio.sfx("deny") end
    end
    return
  end
  if not self.pendingTransition then
    self.pendingTransition = { room = d.link[1], door = d.link[2] }
  end
end

function World:doorAt(x, y, w, h)
  for ch, d in pairs(self.doors) do
    if d.link and U.aabb(x, y, w, h,
      d.x0 * T, d.y0 * T, (d.x1 - d.x0 + 1) * T, (d.y1 - d.y0 + 1) * T) then
      return ch, d
    end
  end
  return nil
end

return World
