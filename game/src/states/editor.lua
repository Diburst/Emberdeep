-- ==================================================================
-- THE ROOM EDITOR -- Phase 1: tiles.
-- ==================================================================
-- Pushed on top of the game state, so the world underneath keeps
-- DRAWING and stops UPDATING -- State.update only runs the top of the
-- stack. That is the whole pause mechanism; there is nothing else to it.
--
-- WYSIWYG is not approximated here: painting pokes World.tiles directly,
-- so every edit goes through the real terrain renderer, the real strata
-- and edge passes and the real light buffer on the very next frame.
-- `self.rows` is the authoritative text that gets written to disk; the
-- poke is what makes it visible instantly.
--
-- Terrain characters ONLY in this phase. Doors, gates and entity keys
-- are Phase 2/3 precisely because they are not a tile poke -- they touch
-- other tables, other files and the generated graph.
-- ==================================================================
local RoomIO = require "src.roomio"
local World = require "src.world"
local Cam = require "src.camera"
local P = require "src.assets.palette"

local S = { name = "editor", translucent = true }
local T = 16

-- How far outside the room you may pan, in world units. The editor is
-- the one place that WANTS to see past the edge: you cannot build
-- outwards from a boundary you can never bring into the middle of the
-- screen. Cam.clamp is the play-mode rule and is deliberately not used.
local SLACK = 320

-- The palette, in the order a level gets built rather than alphabetical.
local PALETTE = { ".", "#", "=", "%", "c", "~", "L", "^", "v", "<", ">" }
-- Doors and gates paint like anything else. They are NOT terrain -- a
-- door cell is air with a letter on it and a link in another table -- so
-- moving one is only ever safe within the wall it already belongs to,
-- and the reachability check on every save is what says whether you got
-- it right.
local SPECIAL = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" }
local PNAME = { ["."] = "air", ["#"] = "solid", ["="] = "one-way platform",
  ["%"] = "breakable", ["c"] = "crumbling", ["~"] = "water", ["L"] = "LAVA",
  ["^"] = "spike up", ["v"] = "spike down", ["<"] = "spike left",
  [">"] = "spike right" }

local TOOLS = {
  { id = "brush",   short = "BRUSH", key = "B",
    tip = "paint the selected tile; drag to draw. Right-drag paints the second tile." },
  { id = "eraser",  short = "ERASE", key = "E",
    tip = "brush, but forced to air. Same thing as picking '.' first." },
  { id = "fill",    short = "FILL",  key = "G",
    tip = "flood-fill the connected region under the cursor." },
  { id = "pick",    short = "PICK",  key = "I",
    tip = "eyedropper: click a tile to make it the selected tile." },
  { id = "rect",    short = "RECT",  key = "U",
    tip = "press, drag, release: fills the rectangle you dragged." },
  { id = "marquee", short = "SEL",   key = "M",
    tip = "drag a selection, then ctrl+C / ctrl+X, then ctrl+V to stamp it." },
}

-- Everything a mouse can press that is not a tool or a tile.
local ACTIONS = {
  { id = "undo",   label = "UNDO",  key = "ctrl+Z", tip = "step back one edit (200 deep)." },
  { id = "redo",   label = "REDO",  key = "ctrl+Y", tip = "step forward again." },
  { id = "copy",   label = "COPY",  key = "ctrl+C", tip = "copy the marquee selection." },
  { id = "paste",  label = "PASTE", key = "ctrl+V", tip = "start a floating stamp; click or ENTER to drop it." },
  { id = "grid",   label = "GRID",  key = "H",      tip = "show or hide the tile grid." },
  { id = "help",   label = "HELP",  key = "TAB",    tip = "the full hotkey card." },
  { id = "save",   label = "SAVE",  key = "ctrl+S", tip = "write the room, then run the fast checks (~6s), including the reachability check that catches a walled-in door." },
  { id = "deep",   label = "DEEP",  key = "^S",     tip = "write, run EVERY check and regenerate the progress graph (~60s, runs in the background)." },
  { id = "revert", label = "REVERT",key = "ctrl+R", tip = "discard unsaved edits and reload from disk. Asks first, and the revert is itself undoable." },
  { id = "exit",   label = "EXIT",  key = "F2",     tip = "back to the game. With unsaved edits it offers save, discard or cancel." },
}

-- The suites, split by how long they take. Measured, not guessed:
-- the fast seven total 2.3s and the deep five add 57s on top.
-- checkrooms is in the FAST tier despite costing 3.7s of the ~6, because
-- it is the ONLY check that notices a door walled in behind rock. Proven
-- rather than assumed: sealing moss_1's right door behind one column of
-- '#' leaves checkdoors and checkcoop perfectly happy -- the door still
-- pairs, it just cannot be reached -- and checkrooms says "door A CANNOT
-- REACH door B". Resize can produce that state, so the check that finds
-- it has to run on every save and not only on the deep one.
local FAST = { "checkdoors", "checkchars", "checkkeys", "checkmap",
               "checksight", "checkprops", "checkheat", "checkapi",
               "checkrooms", "checkreach" }
local DEEP_EXTRA = { "checkcoop", "checkbeams", "checkprogress" }

local shownHelp = false     -- module-level: nag once per launch, not per entry

-- ---------------------------------------------------------------- life
--
-- REVERT HAS TO PUT THE TILES BACK TOO.
--
-- The first version reassigned self.rows and stopped. The text was
-- correct, the disk was correct, and World.tiles still held every
-- discarded edit -- so the screen did not change and the only visible
-- effect was the dirty flag going out, which reads on the status bar as
-- the word "saved". A revert that looks exactly like a save is worse
-- than no revert at all. It goes through S:restore, which is the one
-- function that owns writing BOTH.
function S:loadFromDisk(keepHistory)
  self.id = World.room and World.room.id
  local rows, err
  if self.id then rows, err = RoomIO.readRows(self.id) end
  self.sel, self.stamp = nil, nil
  if not rows then
    self.rows = nil
    -- Say WHICH of the two things failed, and what it tried.
    -- "NO ROOM LOADED" was true, useless, and identical for a world that
    -- has not loaded a room and for a save layer that cannot find the
    -- disk -- which is the state you land in the moment the game is
    -- started from anywhere but game/.
    if not self.id then
      self.status = "NO ROOM LOADED -- World.room is nil; open the editor from inside a room"
    else
      self.status = "CANNOT READ " .. RoomIO.path(self.id) .. "  (" .. tostring(err) .. ")"
    end
    return false
  end
  if keepHistory and self.rows then
    self:snapshot()             -- a revert is itself undoable
  else
    self.undo, self.redo = {}, {}
  end
  self:restore(rows)            -- text AND live tiles
  self.dirty = false
  return true
end

function S:enter()
  self.undo, self.redo, self.clip = {}, {}, nil
  self.rows, self.confirm, self.failures = nil, nil, nil
  self.tool, self.primary, self.secondary = "brush", "#", "."
  self.deepStale = false
  self.grid = true
  self.widgets = self:layout()
  self.hover = nil
  if self:loadFromDisk(false) then self.status = "editing " .. self.id end
  if not shownHelp then self.help = true; shownHelp = true end
end

function S:leave()
  -- The camera is almost certainly outside the room by now. Put it back
  -- before the game state resumes, or the first frame of play lerps in
  -- from wherever the editor left it.
  Cam.clamp()
end

-- ---------------------------------------------------------------- grid
function S:w() return #self.rows[1] end
function S:h() return #self.rows end

function S:get(tx, ty)
  if tx < 0 or ty < 0 or ty >= self:h() or tx >= self:w() then return nil end
  return self.rows[ty + 1]:sub(tx + 1, tx + 1)
end

-- The single write path. The text is authoritative; the world is
-- re-derived from it once per frame.
--
-- This used to poke World.tiles[ty][tx] directly, which is correct for
-- exactly the characters whose meaning is one cell deep -- and wrong for
-- every other kind. Painting water next to air must run the settle pass;
-- painting a door changes a bounding box; painting a spawn char changes
-- what the settle pass sees. Flagging the frame and letting the engine's
-- own parser run once is both simpler and cheaper than the old poke,
-- because a fill of four hundred tiles now re-derives once instead of
-- four hundred times.
function S:set(tx, ty, ch)
  if self:get(tx, ty) == nil or self:get(tx, ty) == ch then return false end
  local r = self.rows[ty + 1]
  self.rows[ty + 1] = r:sub(1, tx) .. ch .. r:sub(tx + 2)
  self.needParse = true
  self.dirty, self.deepStale = true, true
  return true
end

function S:snapshot()
  local c = {}
  for i, r in ipairs(self.rows) do c[i] = r end
  -- The pending origin shift is part of the state, not a side effect:
  -- undo a left-grow without it and the next save shifts the art by a
  -- column that is no longer there.
  c.pendDX, c.pendDY = self.pendDX or 0, self.pendDY or 0
  self.undo[#self.undo + 1] = c
  if #self.undo > 200 then table.remove(self.undo, 1) end
  self.redo = {}
end

function S:restore(rows)
  self.rows = rows
  self.pendDX, self.pendDY = rows.pendDX or 0, rows.pendDY or 0
  self:rebuildWorld(0, 0)
  self.dirty = true
end

function S:doUndo()
  local c = table.remove(self.undo)
  if not c then self.status = "nothing to undo" return end
  local cur = {} for i, r in ipairs(self.rows) do cur[i] = r end
  cur.pendDX, cur.pendDY = self.pendDX or 0, self.pendDY or 0
  self.redo[#self.redo + 1] = cur
  self:restore(c)
  self.status = "undo"
end

function S:doRedo()
  local c = table.remove(self.redo)
  if not c then self.status = "nothing to redo" return end
  self:snapshot()
  self:restore(c)
  self.status = "redo"
end

-- ---------------------------------------------------------------- tools
function S:fill(tx, ty, ch)
  local from = self:get(tx, ty)
  if not from or from == ch then return end
  local q, n = { { tx, ty } }, 1
  while n > 0 do
    local p = table.remove(q); n = n - 1
    local x, y = p[1], p[2]
    if self:get(x, y) == from then
      self:set(x, y, ch)
      q[#q + 1] = { x + 1, y }; q[#q + 1] = { x - 1, y }
      q[#q + 1] = { x, y + 1 }; q[#q + 1] = { x, y - 1 }
      n = n + 4
    end
  end
end

function S:rectFill(x0, y0, x1, y1, ch)
  for y = math.min(y0, y1), math.max(y0, y1) do
    for x = math.min(x0, x1), math.max(x0, x1) do self:set(x, y, ch) end
  end
end

function S:copySel(cut)
  if not self.sel then self.status = "no selection -- press M and drag one" return end
  local s = self.sel
  local x0, x1 = math.min(s.x0, s.x1), math.max(s.x0, s.x1)
  local y0, y1 = math.min(s.y0, s.y1), math.max(s.y0, s.y1)
  local c = {}
  for y = y0, y1 do
    local row = {}
    for x = x0, x1 do row[#row + 1] = self:get(x, y) or "." end
    c[#c + 1] = table.concat(row)
  end
  self.clip = c
  if cut then
    self:snapshot()
    self:rectFill(x0, y0, x1, y1, self.secondary)
  end
  self.status = (cut and "cut " or "copied ") .. #c[1] .. "x" .. #c
end

function S:paste()
  if not self.clip then self.status = "clipboard empty" return end
  local tx, ty = self:cursorTile()
  self.stamp = { rows = self.clip, x = tx, y = ty }
  self.status = "stamp: click or ENTER to drop, arrows nudge, shift+H/V flip, ESC cancel"
end

function S:flipStamp(vertical)
  if not self.stamp then return end
  local r = self.stamp.rows
  local out = {}
  if vertical then
    for i = #r, 1, -1 do out[#out + 1] = r[i] end
  else
    for i = 1, #r do out[i] = r[i]:reverse() end
  end
  self.stamp.rows = out
end

function S:commitStamp()
  if not self.stamp then return end
  self:snapshot()
  local st = self.stamp
  for j, row in ipairs(st.rows) do
    for i = 1, #row do
      self:set(st.x + i - 1, st.y + j - 1, row:sub(i, i))
    end
  end
  self.stamp = nil
  self.status = "stamped"
end

-- ---------------------------------------------------------------- size
--
-- EXTENDING A ROOM OUTWARD.
--
-- New space is SOLID, never air. The room-format notes have a hard rule
-- about this: you carve rooms out of rock, and a batch of edits that
-- "reverted" by writing "." punched holes through walls that nothing
-- noticed for weeks. Growing into air would make the same hole, just
-- outward.
--
-- Three things follow the edge and are not optional:
--
--  1. DOORS. A door's side is derived from where it sits -- x1 == W-1
--     is a right door, anything interior is a PORTAL -- so growing an
--     edge under a door silently reclassifies it and checkdoors fails on
--     the geometry pairing. Doors on a growing edge slide out with it.
--  2. THE ORIGIN, on a left or top grow. Art layers and lights are
--     absolute world pixels; the pending shift is banked here and
--     applied to the file by RoomIO on the next save.
--  3. THE MAP CELL. A room past 33 tiles wide or 26 tall needs a second
--     map cell, which may land on a neighbour. That is fixmappos.py's
--     job at save time, not something to guess at here.
local FILL = "#"

local EDGES = { left = true, right = true, top = true, bottom = true }

-- Every door in the room: its cells and its bounding box.
function S:doorCells()
  local out = {}
  for ty = 0, self:h() - 1 do
    for tx = 0, self:w() - 1 do
      local ch = self:get(tx, ty)
      if World.DOOR_CHARS[ch] then
        local d = out[ch]
        if not d then
          d = { cells = {}, x0 = tx, y0 = ty, x1 = tx, y1 = ty }
          out[ch] = d
        end
        d.cells[#d.cells + 1] = { tx, ty }
        d.x0, d.y0 = math.min(d.x0, tx), math.min(d.y0, ty)
        d.x1, d.y1 = math.max(d.x1, tx), math.max(d.y1, ty)
      end
    end
  end
  return out
end

-- A DOOR'S SIDE IS A PROPERTY OF THE WHOLE DOOR, NOT OF ITS CELLS.
--
-- world.lua derives it from the BOUNDING BOX, first match wins:
--   x0 == 0 -> left, x1 == w-1 -> right, y0 == 0 -> top,
--   y1 == h-1 -> bottom, otherwise portal.
-- The precedence is the point. A door in a corner is left or right,
-- never top or bottom.
--
-- The first resize asked "which door CELLS touch this edge", which is a
-- different question with the same answer most of the time. A left door
-- reaching the bottom row has a cell on the bottom edge, so growing the
-- bottom dragged it down the wall and walled it into the new rock -- and
-- because it kept x == 0 it still classified as `left`, so checkdoors
-- saw a perfectly good left door and said nothing. Worse on a top grow:
-- only the ONE cell on row 0 moved, so the door was torn in half and
-- left in two disconnected places.
function S:doorSide(d)
  if d.x0 == 0 then return "left" end
  if d.x1 == self:w() - 1 then return "right" end
  if d.y0 == 0 then return "top" end
  if d.y1 == self:h() - 1 then return "bottom" end
  return "portal"
end

-- Only the doors this edge actually owns, with ALL of their cells.
function S:doorsOnEdge(edge)
  local out = {}
  for ch, d in pairs(self:doorCells()) do
    if self:doorSide(d) == edge then out[ch] = d.cells end
  end
  return out
end

-- Everything in the strip a shrink would delete.
function S:stripContents(edge, n)
  local w, h = self:w(), self:h()
  local found = {}
  local function look(tx, ty)
    local ch = self:get(tx, ty)
    if ch and ch ~= FILL and ch ~= "." then found[ch] = (found[ch] or 0) + 1 end
  end
  for i = 0, n - 1 do
    if edge == "left" then for ty = 0, h - 1 do look(i, ty) end
    elseif edge == "right" then for ty = 0, h - 1 do look(w - 1 - i, ty) end
    elseif edge == "top" then for tx = 0, w - 1 do look(tx, i) end
    else for tx = 0, w - 1 do look(tx, h - 1 - i) end end
  end
  return found
end

function S:resize(edge, n)
  if not self.rows or not EDGES[edge] or n == 0 then return end
  local w, h = self:w(), self:h()

  if n < 0 then
    local k = -n
    local along = (edge == "left" or edge == "right") and w or h
    if along - k < 4 then self.status = "refusing to shrink below 4" return end
    -- A shrink that eats a door, a gate or an entity spawn is not a
    -- resize, it is a deletion wearing one. Name what is in the way.
    local found = self:stripContents(edge, k)
    local blockers = {}
    for ch in pairs(found) do
      if World.DOOR_CHARS[ch] or World.GATE_CHARS[ch]
         or not World.CHAR_TILE[ch] then
        blockers[#blockers + 1] = ch
      end
    end
    if #blockers > 0 then
      table.sort(blockers)
      self.status = "cannot shrink " .. edge .. ": '" ..
        table.concat(blockers, "' '") .. "' is in the way"
      return
    end
  end

  local moving = self:doorsOnEdge(edge)
  self:snapshot()

  local rows = self.rows
  if edge == "right" then
    if n > 0 then
      for i = 1, #rows do rows[i] = rows[i] .. FILL:rep(n) end
    else
      for i = 1, #rows do rows[i] = rows[i]:sub(1, w + n) end
    end
  elseif edge == "left" then
    if n > 0 then
      for i = 1, #rows do rows[i] = FILL:rep(n) .. rows[i] end
    else
      for i = 1, #rows do rows[i] = rows[i]:sub(1 - n) end
    end
  elseif edge == "bottom" then
    if n > 0 then
      for _ = 1, n do rows[#rows + 1] = FILL:rep(w) end
    else
      for _ = 1, -n do table.remove(rows) end
    end
  else -- top
    if n > 0 then
      for _ = 1, n do table.insert(rows, 1, FILL:rep(w)) end
    else
      for _ = 1, -n do table.remove(rows, 1) end
    end
  end

  -- the origin only moves when the edge that grew was the one it sits on
  local dx = (edge == "left") and n or 0
  local dy = (edge == "top") and n or 0
  self.pendDX = (self.pendDX or 0) + dx
  self.pendDY = (self.pendDY or 0) + dy

  -- slide the doors out to the new edge (only on a GROW; a shrink that
  -- reached a door was already refused)
  if n > 0 then
    local nw, nh = self:w(), self:h()
    for ch, cells in pairs(moving) do
      for _, c in ipairs(cells) do
        local ox, oy = c[1] + dx, c[2] + dy
        self:rawset(ox, oy, FILL)
      end
      for _, c in ipairs(cells) do
        local ox, oy = c[1] + dx, c[2] + dy
        if edge == "left" then ox = 0
        elseif edge == "right" then ox = nw - 1
        elseif edge == "top" then oy = 0
        else oy = nh - 1 end
        self:rawset(ox, oy, ch)
      end
    end
  end

  self.dirty, self.deepStale = true, true
  self:rebuildWorld(dx, dy)
  self.status = ("%s %s by %d -- now %dx%d"):format(
    n > 0 and "grew" or "shrank", edge, math.abs(n), self:w(), self:h())
end

-- set() pokes the live world, which is the wrong shape mid-resize.
function S:rawset(tx, ty, ch)
  local r = self.rows[ty + 1]
  if not r or tx < 0 or tx >= #r then return end
  self.rows[ty + 1] = r:sub(1, tx) .. ch .. r:sub(tx + 2)
end

-- Rebuild World from the row text after the grid CHANGES SHAPE.
--
-- This hands the rows to the ENGINE'S OWN PARSER rather than walking
-- CHAR_TILE by hand. The hand-rolled version looked equivalent and was
-- not: four passes in world.lua read the finished tile array, and
-- skipping them silently dropped the water-settle pass (every enemy
-- standing in a lake left an air bubble where its spawn character was),
-- the decor, the water-depth shading, and every door's bounding box.
--
-- Entities are deliberately NOT respawned -- the editor keeps the ones
-- it has, and only slides them when the origin moves.
function S:rebuildWorld(dxTiles, dyTiles)
  World:parseGrid(self.rows, World.room or {}, self.id or "editor")
  World.depthMap = nil
  Cam.setRoom(World.w * T, World.h * T)

  if (dxTiles or 0) ~= 0 or (dyTiles or 0) ~= 0 then
    local px, py = (dxTiles or 0) * T, (dyTiles or 0) * T
    for _, e in ipairs(World.entities or {}) do
      if e.x then e.x = e.x + px end
      if e.y then e.y = e.y + py end
    end
    for _, pl in ipairs(World.players or {}) do
      if pl.x then pl.x = pl.x + px end
      if pl.y then pl.y = pl.y + py end
    end
    Cam.x, Cam.y = Cam.x + px, Cam.y + py
  end
end

-- ---------------------------------------------------------------- save
--
-- The checks run on a THREAD. Inline io.popen froze the window for the
-- whole minute the deep suite takes, which is indistinguishable from a
-- crash. See src/checkthread.lua.
function S:startChecks(deep, exitAfter)
  if self.job then self.status = "checks already running" return end
  local items = {}
  -- The validators are all written to be run FROM game/ ("../scripts",
  -- "src/data/rooms"). The check thread inherits the process working
  -- directory, which is wherever love was launched from -- so every
  -- command is anchored explicitly rather than hoping.
  local root = RoomIO.root()
  if root == "" then root = "." end
  local function add(v, cmd)
    items[#items + 1] = v .. "\t" ..
      "cd '" .. root:gsub("'", "'\\''") .. "' && " .. cmd
  end
  -- FIRST, because it can WRITE. A resize past 33 tiles wide or 26 tall
  -- needs another map cell, and checkmap validates the result -- so the
  -- repair has to have happened before checkmap looks. It is silent and
  -- writes nothing when the cells are already right, which is almost
  -- always.
  add("fixmappos", "PYTHONPATH=../scripts python3 ../scripts/fixmappos.py " ..
      "--write " .. self.id)
  for _, v in ipairs(FAST) do
    add(v, "PYTHONPATH=../scripts python3 ../scripts/" .. v .. ".py")
  end
  if deep then
    for _, v in ipairs(DEEP_EXTRA) do
      add(v, "PYTHONPATH=../scripts python3 ../scripts/" .. v .. ".py")
    end
    add("genprogress", "PYTHONPATH=../scripts python3 ../scripts/genprogress.py " ..
        "src/data/progress_graph.lua")
  end

  local prog = love.thread.getChannel("edcheck_progress")
  local res = love.thread.getChannel("edcheck_result")
  while prog:pop() do end          -- a cancelled run can leave crumbs
  while res:pop() do end

  local th = love.thread.newThread("src/checkthread.lua")
  th:start(table.concat(items, "\n"))
  self.job = { thread = th, deep = deep, t0 = love.timer.getTime(),
               n = #items, done = 0, step = "starting", eta = deep and 60 or 6,
               exitAfter = exitAfter }
  self.status = deep and "deep checks running in the background"
                     or "checks running"
end

function S:pollChecks()
  local j = self.job
  if not j then return end
  local prog = love.thread.getChannel("edcheck_progress")
  local p = prog:pop()
  while p do
    j.step = p
    local d = p:match("^(%d+)/")
    if d then j.done = tonumber(d) - 1 end
    if p == "done" then j.done = j.n end
    p = prog:pop()
  end

  local res = love.thread.getChannel("edcheck_result")
  local bad = res:pop()
  if bad then
    local detail = res:pop() or ""
    local el = love.timer.getTime() - j.t0
    if j.deep and bad == 0 then self.deepStale = false end
    self.status = ("%s %s in %ds"):format(j.deep and "DEEP:" or "checks:",
      bad == 0 and "all clean" or (bad .. " FAILURE(S)"), math.floor(el + 0.5))
    if bad > 0 then
      self.failures = {}
      for line in (detail .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("%S") then self.failures[#self.failures + 1] = line end
      end
      self.failScroll = 0
    else
      self.failures = nil
    end
    self.job = nil
    -- SAVE & EXIT waits for the verdict rather than racing it. Popping
    -- the moment the write lands would abandon the channel the results
    -- come back on, and you would leave the editor never knowing you
    -- had just broken a room.
    if j.exitAfter then
      if bad == 0 then G.State.pop()
      else self.status = self.status .. " -- staying in the editor" end
    end
    return
  end

  local err = j.thread:getError()
  if err then
    self.status = "check thread died: " .. tostring(err)
    self.job = nil
  end
end

function S:save(deep, exitAfter)
  if not self.rows then return end
  if self.job then self.status = "checks still running -- wait for them" return end
  local shift = { dx = (self.pendDX or 0) * T, dy = (self.pendDY or 0) * T }
  local ok, err = RoomIO.writeMap(self.id, self.rows, { shift = shift })
  if not ok then self.status = "SAVE REFUSED: " .. tostring(err) return end
  RoomIO.invalidate(self.id)
  self.pendDX, self.pendDY = 0, 0
  self.dirty = false
  self.failures = nil
  self:startChecks(deep, exitAfter)
end

-- ---------------------------------------------------------------- input
-- Mouse in LOGICAL screen units: undo the letterbox blit, then the
-- render scale. main.lua publishes what it actually drew with.
function S:uiPos()
  local mx, my = love.mouse.getPosition()
  local sc = (G.blitScale or 1) * (G.RS or 1)
  return (mx - (G.blitOX or 0)) / sc, (my - (G.blitOY or 0)) / sc
end

function S:cursorTile()
  local ux, uy = self:uiPos()
  return math.floor((ux + (Cam.ox or Cam.x)) / T),
         math.floor((uy + (Cam.oy or Cam.y)) / T)
end

-- ---------------------------------------------------------------- chrome
function S:layout()
  local w = {}
  local function add(t) w[#w + 1] = t end

  for i, c in ipairs(PALETTE) do
    local k = (i < 10) and tostring(i) or (i == 10 and "0" or "[ ]")
    add { x = 4 + (i - 1) * 20, y = 4, w = 18, h = 14, kind = "tile", val = c,
          label = c, tip = PNAME[c] .. "   key " .. k }
  end
  for i, c in ipairs(SPECIAL) do
    local door = World.DOOR_CHARS[c]
    add { x = 250 + (i - 1) * 20, y = 4, w = 18, h = 14, kind = "tile", val = c,
          label = c,
          tip = (door and "DOOR " or "GATE ") .. c .. " -- " ..
                (door and ("its link and its partner live in links = {}; move it "
                        .. "along the wall it is on, never onto another wall")
                       or "solid until its flag is set; gates = {} names the flag")
                .. ".   K for the legend" }
  end

  local x = 4
  for _, t in ipairs(TOOLS) do
    add { x = x, y = 22, w = 36, h = 14, kind = "tool", val = t.id,
          label = t.short, tip = t.tip .. "   key " .. t.key }
    x = x + 38
  end
  -- the size bar, shown only in size mode so the chrome stays out of
  -- the way the other 95% of the time
  x = 250
  for _, e in ipairs({ "left", "right", "top", "bottom" }) do
    for _, n in ipairs({ 1, -1 }) do
      add { x = x, y = 22, w = 26, h = 14, kind = "size", val = e, n = n,
            only = "size", label = e:sub(1, 1):upper() .. (n > 0 and "+" or "-"),
            tip = (n > 0 and "grow" or "shrink") .. " the " .. e ..
                  " edge by one tile. New space is SOLID, doors on that " ..
                  "edge slide with it.   alt" ..
                  (n > 0 and "" or "+shift") .. "+arrow" }
      x = x + 28
    end
  end

  x = 4
  for _, a in ipairs(ACTIONS) do
    local bw = (#a.label * 6) + 8
    add { x = x, y = 40, w = bw, h = 14, kind = "action", val = a.id,
          label = a.label, tip = a.tip .. "   " .. a.key }
    x = x + bw + 2
  end
  return w
end

function S:hit(ux, uy)
  for _, g in ipairs(self.widgets) do
    if (not g.only or (g.only == "size" and self.sizemode))
       and ux >= g.x and ux < g.x + g.w and uy >= g.y and uy < g.y + g.h then
      return g
    end
  end
end

function S:activate(g)
  if g.kind == "size" then
    self:resize(g.val, g.n)
  elseif g.kind == "tile" then
    self.primary = g.val
    self.status = "tile: " .. (PNAME[g.val] or g.val)
  elseif g.kind == "tool" then
    self.tool = g.val
    if g.val == "eraser" then self.primary = "." end
    self.status = "tool: " .. g.val
  elseif g.val == "undo" then self:doUndo()
  elseif g.val == "redo" then self:doRedo()
  elseif g.val == "copy" then self:copySel(false)
  elseif g.val == "paste" then self:paste()
  elseif g.val == "grid" then self.grid = not self.grid
  elseif g.val == "help" then self.help = not self.help
  elseif g.val == "save" then self:save(false)
  elseif g.val == "deep" then self:save(true)
  elseif g.val == "revert" then self:askRevert()
  elseif g.val == "exit" then self:tryExit()
  end
end

-- ---------------------------------------------------------------- ask
--
-- Anything that can destroy work asks first. Both of the destructive
-- paths here are one keystroke away from a path that is not: ctrl+R
-- sits next to nothing in particular, but F2 is the key you press when
-- you are done, which is exactly when you have the most to lose.
function S:ask(text, opts)
  self.confirm = { text = text, opts = opts, rects = {} }
end

function S:answer(o)
  self.confirm = nil
  if o and o.fn then o.fn(self) end
end

function S:doRevert()
  self:loadFromDisk(true)
  self.status = "reverted to disk (ctrl+Z brings it back)"
end

function S:askRevert()
  if not self.rows then return end
  if not self.dirty then self.status = "nothing to revert" return end
  self:ask("Discard every unsaved edit in " .. self.id .. "\nand reload it from disk?", {
    { key = "y", label = "DISCARD", fn = S.doRevert },
    { key = "n", label = "KEEP EDITING" },
  })
end

-- WHAT IS 'C'?
--
-- Every non-terrain character in a room means something written down in
-- another table, and until now the editor showed you a letter and left
-- you to guess. "C is in the way" is a true and useless thing to say.
function S:legend()
  local out, seen = {}, {}
  local def = World.room or {}
  for ty = 0, self:h() - 1 do
    for tx = 0, self:w() - 1 do
      local ch = self:get(tx, ty)
      if ch and not World.CHAR_TILE[ch] and not seen[ch] then
        seen[ch] = true
        local what
        if World.DOOR_CHARS[ch] then
          local d = self:doorCells()[ch]
          local link = def.links and def.links[ch]
          what = ("DOOR, %s wall -> %s"):format(
            d and self:doorSide(d) or "?",
            link and (link[1] .. "." .. tostring(link[2])) or "NOT LINKED")
          if link and link.req then what = what .. "  (needs " .. link.req .. ")" end
        elseif World.GATE_CHARS[ch] then
          what = "GATE, solid until " ..
                 tostring(def.gates and def.gates[ch] or "?")
        else
          what = tostring(def.key and def.key[ch] or "UNMAPPED -- the room will not load")
        end
        out[#out + 1] = ch .. "   " .. what
      end
    end
  end
  table.sort(out)
  return out
end

function S:tryExit()
  if not self.dirty then G.State.pop() return end
  self:ask("You have unsaved edits in " .. self.id .. ".", {
    { key = "s", label = "SAVE & EXIT", fn = function(self)
        self:save(false, true)      -- pops once the checks come back clean
      end },
    { key = "d", label = "DISCARD & EXIT", fn = function(self)
        self:loadFromDisk(true)
        G.State.pop()
      end },
    { key = "c", label = "CANCEL" },
  })
end

-- ---------------------------------------------------------------- mouse
function S:paintAt(ch)
  local tx, ty = self:cursorTile()
  if self.tool == "fill" then self:fill(tx, ty, ch)
  elseif self.tool == "pick" then
    local g = self:get(tx, ty)
    if g then self.primary = g; self.status = "picked " .. (PNAME[g] or g) end
  else
    self:set(tx, ty, ch)
  end
end

function S:mousepressed(mx, my, btn)
  local ux, uy = self:uiPos()
  if self.confirm then
    if btn == 1 then
      for i, r in ipairs(self.confirm.rects) do
        if ux >= r.x and ux < r.x + r.w and uy >= r.y and uy < r.y + r.h then
          self:answer(self.confirm.opts[i]); return
        end
      end
    end
    return                       -- a modal that lets clicks through is not one
  end
  local g = self:hit(ux, uy)
  if g then
    if btn == 1 then self:activate(g)
    elseif btn == 2 and g.kind == "tile" then self.secondary = g.val end
    return
  end
  if not self.rows then return end

  local tx, ty = self:cursorTile()
  if self.stamp then
    if btn == 1 then self.stamp.x, self.stamp.y = tx, ty; self:commitStamp() end
    return
  end
  if self.tool == "marquee" then
    if btn == 1 then self.sel = { x0 = tx, y0 = ty, x1 = tx, y1 = ty }; self.dragging = true end
    return
  end
  if self.tool == "rect" and btn == 1 then
    self.rectFrom = { tx, ty }; return
  end
  self:snapshot()
  self.painting = btn
  self:paintAt(btn == 2 and self.secondary or self.primary)
end

function S:mousemoved()
  local ux, uy = self:uiPos()
  self.hover = self:hit(ux, uy)
  if not self.rows then return end
  local tx, ty = self:cursorTile()
  if self.dragging and self.sel then self.sel.x1, self.sel.y1 = tx, ty end
  if self.painting and self.tool ~= "fill" and self.tool ~= "pick" then
    self:paintAt(self.painting == 2 and self.secondary or self.primary)
  end
end

function S:wheelmoved(dx, dy)
  if self.failures then self:scrollFailures(-dy) end
end

function S:mousereleased(mx, my, btn)
  if self.rectFrom and btn == 1 then
    local tx, ty = self:cursorTile()
    self:snapshot()
    self:rectFill(self.rectFrom[1], self.rectFrom[2], tx, ty, self.primary)
    self.rectFrom = nil
  end
  self.painting, self.dragging = nil, false
end

-- ---------------------------------------------------------------- keys
local TOOLKEY = { b = "brush", e = "eraser", g = "fill", i = "pick",
                  u = "rect", m = "marquee" }

function S:keypressed(k)
  local ctrl = love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui")
  local shift = love.keyboard.isDown("lshift", "rshift")

  -- The failure panel is modal-ish: it is in the way on purpose, and
  -- ANY key gets rid of it so you can go and fix the thing it names.
  if self.failures then
    if k == "up" then self:scrollFailures(-1) return end
    if k == "down" then self:scrollFailures(1) return end
    if k == "pageup" then self:scrollFailures(-8) return end
    if k == "pagedown" then self:scrollFailures(8) return end
    self.failures = nil
    self.status = "checks cleared -- the room is still as it was"
    return
  end

  if self.confirm then
    for _, o in ipairs(self.confirm.opts) do
      if k == o.key then self:answer(o) return end
    end
    if k == "escape" then self:answer(self.confirm.opts[#self.confirm.opts]) end
    return
  end

  if ctrl then
    if k == "s" then self:save(shift)
    elseif k == "z" then if shift then self:doRedo() else self:doUndo() end
    elseif k == "y" then self:doRedo()
    elseif k == "c" then self:copySel(false)
    elseif k == "x" then self:copySel(true)
    elseif k == "v" then self:paste()
    elseif k == "a" then self.sel = { x0 = 0, y0 = 0, x1 = self:w() - 1, y1 = self:h() - 1 }
    elseif k == "r" then self:askRevert()
    end
    return
  end

  if self.stamp then
    local d = shift and 8 or 1
    if k == "left" then self.stamp.x = self.stamp.x - d
    elseif k == "right" then self.stamp.x = self.stamp.x + d
    elseif k == "up" then self.stamp.y = self.stamp.y - d
    elseif k == "down" then self.stamp.y = self.stamp.y + d
    elseif k == "h" and shift then self:flipStamp(false)
    elseif k == "v" and shift then self:flipStamp(true)
    elseif k == "return" then self:commitStamp()
    elseif k == "escape" then self.stamp = nil; self.status = "stamp cancelled"
    end
    return
  end

  if love.keyboard.isDown("lalt", "ralt") then
    local edge = ({ left = "left", right = "right", up = "top", down = "bottom" })[k]
    if edge then self:resize(edge, shift and -1 or 1) return end
  end

  if k == "r" then
    self.sizemode = not self.sizemode
    self.status = self.sizemode
      and "SIZE MODE -- alt+arrow grows an edge, alt+shift+arrow shrinks it"
      or "size mode off"
  elseif TOOLKEY[k] then
    self.tool = TOOLKEY[k]
    if k == "e" then self.primary = "." end
    self.status = "tool: " .. self.tool
  elseif k == "x" then self.primary, self.secondary = self.secondary, self.primary
  elseif k == "h" then self.grid = not self.grid
  elseif k == "escape" then
    if self.help then self.help = false else self.sel = nil end
  elseif k == "tab" then self.help = not self.help
  elseif k == "f" then self:frameRoom()
  elseif k == "k" then self.showLegend = not self.showLegend
  elseif tonumber(k) then
    local i = tonumber(k); if i == 0 then i = 10 end
    if PALETTE[i] then self.primary = PALETTE[i] end
  elseif k == "[" or k == "]" then
    local at = 1
    for i, c in ipairs(PALETTE) do if c == self.primary then at = i end end
    at = at + (k == "]" and 1 or -1)
    if at < 1 then at = #PALETTE elseif at > #PALETTE then at = 1 end
    self.primary = PALETTE[at]
  end
end

-- F2 MUST BE HANDLED HERE AND NOT IN keypressed.
--
-- love.keypressed fires during the event pump; game.lua's F2 fires from
-- Input.drain inside love.update, a whole phase later. Popping from
-- keypressed therefore popped the editor and then handed the SAME
-- keypress to the game underneath, which pushed it straight back --
-- so F2 did nothing at all, twice per press. One event, one handler:
-- both halves now live on the raw channel.
function S:raw(ev)
  if ev.kind == "rawkey" and ev.id == "f2" then self:tryExit() end
end

-- Snap the camera back over the room. The price of free panning is
-- being able to lose the room entirely; this is the way back.
function S:frameRoom()
  Cam.x = math.max(0, (Cam.roomW - G.VW) / 2)
  Cam.y = math.max(0, (Cam.roomH - G.VH) / 2)
  self.status = "framed"
end

-- ---------------------------------------------------------------- tick
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

function S:update(dt)
  self:pollChecks()
  -- one re-derive per frame, however many tiles were painted into it
  if self.needParse then
    self.needParse = nil
    self:rebuildWorld(0, 0)
  end
  local sp = love.keyboard.isDown("lshift", "rshift") and 12 or 5
  local arrows = not self.stamp        -- arrows nudge the stamp instead
  if love.keyboard.isDown("a") or (arrows and love.keyboard.isDown("left")) then
    Cam.x = Cam.x - sp end
  if love.keyboard.isDown("d") or (arrows and love.keyboard.isDown("right")) then
    Cam.x = Cam.x + sp end
  if love.keyboard.isDown("w") or (arrows and love.keyboard.isDown("up")) then
    Cam.y = Cam.y - sp end
  if love.keyboard.isDown("s") or (arrows and love.keyboard.isDown("down")) then
    Cam.y = Cam.y + sp end
  -- The loose clamp. Not Cam.clamp: see SLACK.
  Cam.x = clamp(Cam.x, -SLACK, math.max(0, Cam.roomW - G.VW) + SLACK)
  Cam.y = clamp(Cam.y, -SLACK, math.max(0, Cam.roomH - G.VH) + SLACK)
end

-- ---------------------------------------------------------------- draw
local function box(x, y, w, h, a)
  love.graphics.setColor(0, 0, 0, a or 0.72)
  love.graphics.rectangle("fill", x, y, w, h)
end

function S:draw()
  local g = love.graphics
  if G.fonts and G.fonts.main then g.setFont(G.fonts.main) end
  if not self.rows then
    g.setColor(P.blood) g.printf(self.status, 0, 120, G.SW, "center") return
  end

  local W, H = self:w() * T, self:h() * T
  Cam.apply()

  -- Outside the room: dim it and draw a hard boundary, so panning past
  -- the edge reads as "past the edge" rather than as a rendering bug.
  g.setColor(0, 0, 0, 0.55)
  g.rectangle("fill", -4000, -4000, 8000, 4000 + 0)          -- above
  g.rectangle("fill", -4000, H, 8000, 4000)                  -- below
  g.rectangle("fill", -4000, 0, 4000, H)                     -- left
  g.rectangle("fill", W, 0, 4000, H)                         -- right

  if self.grid then
    g.setColor(1, 1, 1, 0.08)
    for x = 0, self:w() do g.rectangle("fill", x * T, 0, 1, H) end
    for y = 0, self:h() do g.rectangle("fill", 0, y * T, W, 1) end
  end

  g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.55)
  g.rectangle("line", 0.5, 0.5, W - 1, H - 1)

  -- EVERY NON-TERRAIN CHARACTER, LABELLED IN PLACE.
  -- A door cell is air with a letter on it; without this the editor
  -- draws it as a hole in the wall and you find out what it was when a
  -- shrink refuses because "C is in the way".
  do
    local shown = {}
    for gy = 0, self:h() - 1 do
      for gx = 0, self:w() - 1 do
        local ch = self:get(gx, gy)
        if ch and not World.CHAR_TILE[ch] then
          local col = World.DOOR_CHARS[ch] and P.cyan
                   or World.GATE_CHARS[ch] and P.gold or P.moss or P.silver
          g.setColor(col[1], col[2], col[3], 0.22)
          g.rectangle("fill", gx * T, gy * T, T, T)
          g.setColor(col[1], col[2], col[3], 0.95)
          g.rectangle("line", gx * T + 0.5, gy * T + 0.5, T - 1, T - 1)
          if not shown[ch] then
            shown[ch] = true
            g.print(ch, gx * T + 5, gy * T + 4)
          end
        end
      end
    end
  end

  local tx, ty = self:cursorTile()
  if self.sel then
    local s = self.sel
    local x0, x1 = math.min(s.x0, s.x1), math.max(s.x0, s.x1)
    local y0, y1 = math.min(s.y0, s.y1), math.max(s.y0, s.y1)
    g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.25)
    g.rectangle("fill", x0 * T, y0 * T, (x1 - x0 + 1) * T, (y1 - y0 + 1) * T)
  end
  if self.stamp then
    g.setColor(0.4, 0.9, 1, 0.45)
    for j, row in ipairs(self.stamp.rows) do
      for i = 1, #row do
        if row:sub(i, i) ~= "." then
          g.rectangle("fill", (self.stamp.x + i - 1) * T, (self.stamp.y + j - 1) * T, T, T)
        end
      end
    end
  elseif not self.hover then
    g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.7)
    g.rectangle("line", tx * T + 0.5, ty * T + 0.5, T - 1, T - 1)
  end
  Cam.unapply()

  self:drawChrome(tx, ty)
end

function S:drawChrome(tx, ty)
  local g = love.graphics

  -- top bar backing, tall enough for all three widget rows
  box(0, 0, G.SW, 56, 0.62)

  for _, wg in ipairs(self.widgets) do
   if not wg.only or (wg.only == "size" and self.sizemode) then
    local on = (wg.kind == "tile" and wg.val == self.primary)
             or (wg.kind == "tool" and wg.val == self.tool)
             or (wg.kind == "action" and wg.val == "grid" and self.grid)
    local hot = (self.hover == wg)
    g.setColor(0, 0, 0, hot and 0.85 or 0.6)
    g.rectangle("fill", wg.x, wg.y, wg.w, wg.h)
    g.setColor(on and P.ember or (hot and P.cream or P.slate))
    g.rectangle("line", wg.x + 0.5, wg.y + 0.5, wg.w - 1, wg.h - 1)
    g.setColor(on and P.gold or (hot and P.cream or P.silver))
    g.print(wg.label, wg.x + 4, wg.y + 3)
   end
  end
  -- the second (right-button) tile, marked on its own swatch
  for _, wg in ipairs(self.widgets) do
    if wg.kind == "tile" and wg.val == self.secondary then
      g.setColor(P.cyan) g.rectangle("line", wg.x + 2.5, wg.y + 2.5, wg.w - 5, wg.h - 5)
    end
  end

  -- bottom status
  box(0, G.SH - 26, G.SW, 26)
  g.setColor(P.ember)
  g.print("[" .. self.primary .. "] " .. (PNAME[self.primary] or "?")
    .. "   " .. self.tool:upper(), 4, G.SH - 22)
  g.setColor(self.dirty and P.gold or P.slate)
  g.print(self.dirty and "UNSAVED EDITS" or "matches disk", 4, G.SH - 12)
  if self.deepStale then
    g.setColor(P.blood) g.print("DEEP CHECKS STALE", 62, G.SH - 12)
  end
  g.setColor(P.silver)
  g.printf(self.status, 0, G.SH - 22, G.SW - 6, "right")
  g.setColor(P.slate)
  g.printf(("%s  %dx%d  cursor %d,%d   TAB help   F frame"):format(
    self.id, self:w(), self:h(), tx, ty), 0, G.SH - 12, G.SW - 6, "right")

  if self.failures then self:drawFailures() end
  if self.showLegend then
    local lines = self:legend()
    local hgt = math.max(24, #lines * 10 + 14)
    local y = math.floor((G.SH - hgt) / 2)
    box(40, y, G.SW - 80, hgt, 0.93)
    g.setColor(P.cyan) g.rectangle("line", 40.5, y + 0.5, G.SW - 81, hgt - 1)
    g.setColor(P.ember)
    g.print("WHAT THE LETTERS IN THIS ROOM MEAN            K closes", 48, y + 4)
    g.setColor(P.cream)
    for i, l in ipairs(lines) do g.print(l, 48, y + 4 + i * 10) end
    if #lines == 0 then
      g.setColor(P.slate) g.print("nothing but terrain in here", 48, y + 14)
    end
  end

  self:drawProgress()
  self:drawTooltip()
  if self.help then self:drawHelp() end
  if self.confirm then self:drawConfirm() end
end

function S:drawConfirm()
  local g = love.graphics
  local c = self.confirm
  local w, h = 320, 74
  local x, y = math.floor((G.SW - w) / 2), 92
  g.setColor(0, 0, 0, 0.55)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  box(x, y, w, h, 0.95)
  g.setColor(P.gold)
  g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  g.setColor(P.cream)
  g.printf(c.text, x + 10, y + 9, w - 20)

  local bw, gap = 96, 6
  local total = #c.opts * bw + (#c.opts - 1) * gap
  local bx = x + math.floor((w - total) / 2)
  local by = y + h - 22
  c.rects = {}
  for i, o in ipairs(c.opts) do
    local r = { x = bx, y = by, w = bw, h = 16 }
    c.rects[i] = r
    g.setColor(0, 0, 0, 0.8) g.rectangle("fill", r.x, r.y, r.w, r.h)
    g.setColor(i == 1 and P.ember or P.slate)
    g.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    g.setColor(i == 1 and P.gold or P.silver)
    g.printf(o.label .. "  [" .. o.key:upper() .. "]", r.x, r.y + 4, r.w, "center")
    bx = bx + bw + gap
  end
end

-- The whole reason the thread exists: a minute of Python has to LOOK
-- like a minute of Python.
function S:drawProgress()
  local j = self.job
  if not j then return end
  local g = love.graphics
  local el = love.timer.getTime() - j.t0
  local x, y, w, h = 60, G.SH - 62, G.SW - 120, 28
  box(x, y, w, h, 0.9)
  g.setColor(P.slate)
  g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)

  local frac = math.min(1, j.done / math.max(1, j.n))
  g.setColor(P.ember)
  g.rectangle("fill", x + 4, y + 18, (w - 8) * frac, 4)
  g.setColor(P.shadow or P.slate)
  g.rectangle("line", x + 4, y + 18, w - 8, 4)

  local dots = ("."):rep(1 + math.floor(el * 3) % 3)
  g.setColor(P.cream)
  g.print((j.deep and "DEEP CHECKS" or "CHECKS") .. " " .. dots, x + 6, y + 5)
  g.setColor(P.silver)
  g.printf(("%s   %ds / ~%ds"):format(j.step, math.floor(el), j.eta),
    0, y + 5, x + w - 6, "right")
end

-- THE FAILURE PANEL.
--
-- The first one printed the whole report into a fixed 100px box with no
-- bound and no way out: it covered the room, overflowed its own frame,
-- and said "clears on the next save" -- so the only way to see what you
-- were fixing was to save the broken thing again.
--
-- Bounded, scrolled, and dismissed by any key. The text is drawn at 3/4
-- scale where there are pixels to spare for it; at RS = 1 the canvas is
-- literal pixel art and a fractional scale would just smear, so there it
-- stays full size and simply shows fewer lines.
local FAILBOX = { x = 16, y = 58, h = 150 }

function S:failMetrics()
  local sc = (G.RS or 1) > 1 and 0.75 or 1
  local lh = 10 * sc
  local rows = math.floor((FAILBOX.h - 24) / lh)
  return sc, lh, math.max(1, rows)
end

function S:scrollFailures(d)
  if not self.failures then return false end
  local _, _, rows = self:failMetrics()
  local maxs = math.max(0, #self.failures - rows)
  self.failScroll = math.max(0, math.min(maxs, (self.failScroll or 0) + d))
  return true
end

function S:drawFailures()
  local g = love.graphics
  local sc, lh, rows = self:failMetrics()
  local w = G.SW - FAILBOX.x * 2
  local x, y = FAILBOX.x, FAILBOX.y
  box(x, y, w, FAILBOX.h, 0.93)
  g.setColor(P.blood)
  g.rectangle("line", x + 0.5, y + 0.5, w - 1, FAILBOX.h - 1)

  local top = self.failScroll or 0
  local more = #self.failures - rows
  g.setColor(P.blood)
  g.print(("%d line(s) from the checks"):format(#self.failures), x + 6, y + 5)
  g.setColor(P.slate)
  g.printf(more > 0 and "UP/DOWN or wheel scrolls -- any other key clears"
                    or "any key clears", 0, y + 5, x + w - 6, "right")

  g.push()
  g.translate(x + 6, y + 18)
  g.scale(sc)
  for i = 1, rows do
    local line = self.failures[top + i]
    if not line then break end
    g.setColor(line:sub(1, 2) == "--" and P.ember or P.cream)
    -- hard-truncate rather than wrap: a wrapped 200-char python line
    -- eats the whole panel and buries the nine after it
    local maxch = math.floor((w - 14) / (6 * sc))
    if #line > maxch then line = line:sub(1, maxch - 1) .. ">" end
    g.print(line, 0, (i - 1) * 10)
  end
  g.pop()

  if more > 0 then
    local frac = top / more
    g.setColor(P.slate)
    g.rectangle("fill", x + w - 4, y + 18 + frac * (FAILBOX.h - 30), 2, 12)
  end
end

function S:drawTooltip()
  local wg = self.hover
  if not wg or self.help then return end
  local g = love.graphics
  local tw = math.min(300, G.SW - 20)
  local x = math.min(wg.x, G.SW - tw - 6)
  local y = wg.y + wg.h + 4
  local _, lines = G.fonts.main:getWrap(wg.tip, tw - 10)
  local hgt = #lines * 10 + 8
  box(x, y, tw, hgt, 0.92)
  g.setColor(P.slate) g.rectangle("line", x + 0.5, y + 0.5, tw - 1, hgt - 1)
  g.setColor(P.cream)
  g.printf(wg.tip, x + 5, y + 4, tw - 10)
end

function S:drawHelp()
  local g = love.graphics
  box(24, 26, G.SW - 48, 240, 0.92)
  g.setColor(P.ember)
  g.print("ROOM EDITOR", 32, 32)
  g.setColor(P.cream)
  g.printf(
    "MOUSE   left paints the selected tile, right paints the second one.\n" ..
    "        Click any button up top; hover it for what it does.\n" ..
    "TOOLS   B brush   E erase   G fill   I pick   U rect   M select\n" ..
    "TILES   1-9 0 pick a tile   [ ] cycle   X swap the two\n" ..
    "PAN     WASD or arrows, SHIFT for fast. You CAN pan off the edge --\n" ..
    "        that is deliberate, so you can build outwards. F re-frames.\n" ..
    "LEGEND  K -- what every letter in THIS room means. Doors and gates\n" ..
    "        are drawn labelled in place, and paint from the right-hand\n" ..
    "        swatches. Move a door ALONG its own wall, never onto\n" ..
    "        another one; the save proves it can still be reached.\n" ..
    "SIZE    R toggles the size bar. alt+arrow grows that edge by a tile,\n" ..
    "        alt+shift+arrow shrinks it. New space is SOLID; doors on the\n" ..
    "        edge slide out with it; a shrink refuses to eat a door, a\n" ..
    "        gate or a spawn. Saving fixes the map cell if it changed.\n" ..
    "EDIT    ctrl+Z undo   ctrl+Y redo   ctrl+A select all   H grid\n" ..
    "        ctrl+C copy  ctrl+X cut  ctrl+V stamp (arrows nudge,\n" ..
    "        shift+H / shift+V flip, ENTER drops it, ESC cancels)\n" ..
    "SAVE    ctrl+S writes the room and runs the fast checks (~3s).\n" ..
    "        ctrl+shift+S also runs every slow check and rebuilds the\n" ..
    "        progress graph -- about a MINUTE, in the background.\n" ..
    "        ctrl+R discards unsaved edits -- it asks first, and the\n" ..
    "        revert itself is undoable with ctrl+Z.\n" ..
    "LEAVE   F2. With unsaved edits it offers save, discard or cancel.\n" ..
    "        Every save backs the old file up to emberdeep/_backups/\n" ..
    "        as <room>.<date>-<time>.lua -- nothing is overwritten.",
    32, 44, G.SW - 64)
  g.setColor(P.slate)
  g.print("TAB or ESC closes this", 32, 254)
end

return S
