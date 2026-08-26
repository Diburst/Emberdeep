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
-- The help card's text, ONE LINE PER LINE. It used to be a single
-- string handed to printf, which is what let it silently grow to
-- 395px on a 270px screen -- printf will happily wrap past the
-- bottom of the canvas and say nothing. Split, it can be counted,
-- scrolled, and swept.
local HELP_LINES = (function()
  local t = {}
  for line in ("MOUSE   left paints the selected tile, right paints the second one.\n" ..
    "        Click any button up top; hover it for what it does.\n" ..
    "TOOLS   B brush   E erase   G fill   I pick   U rect   M select\n" ..
    "TILES   1-9 0 pick a tile   [ ] cycle   X swap the two\n" ..
    "PROPS   , and . step the prop list; N makes it the brush. Cells,\n" ..
    "        anchors, updrafts, checkpoints, SWITCHES, spikes, doors\n" ..
    "        and gates all live here.\n" ..
    "ENEMY   / opens a SEARCH over all the enemies -- type to filter,\n" ..
    "        ENTER picks. J makes the shown one the brush. Drops are\n" ..
    "        per spawn: edit the key line to \"rollpede:energy=0\" and\n" ..
    "        that one pays nothing.\n" ..
    "ATTRS   pick up SEL (M) and CLICK a thing: a gate, a door, a\n" ..
    "        button, a node, an emitter, a panel. The panel that opens\n" ..
    "        is where you change what it DOES -- a gate\'s condition, a\n" ..
    "        node\'s beam count, a button\'s flag. Up/down picks a row,\n" ..
    "        left/right changes it, ENTER on a flag row opens a list of\n" ..
    "        every flag worth naming: this room\'s buttons and nodes,\n" ..
    "        every boss, every module. N in there invents a new one.\n" ..
    "        DRAG with SEL still makes a selection -- only a click\n" ..
    "        inspects.\n" ..
    "LINKS   many-to-many, and it always was: point two gates at one\n" ..
    "        flag and one button opens both; point two buttons at one\n" ..
    "        flag and either opens the gate. The panel lets you PICK an\n" ..
    "        existing flag, which is the only thing that was missing.\n" ..
    "GATES   L and ; still work with a gate as the brush (flag, style),\n" ..
    "        and a gate paints in a run like any other tile -- hold and\n" ..
    "        drag, or use RECT.\n" ..
    "        THE EDITOR PICKS THE MAP CHARACTER, never you: one this\n" ..
    "        room is not using and the engine does not own. That is the\n" ..
    "        shadowed-key bug, made impossible. Paint over the last one\n" ..
    "        of something and its key line goes with it.\n" ..
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
    "        as <room>.<date>-<time>.lua -- nothing is overwritten."):gmatch("([^\n]*)\n?") do
    t[#t + 1] = line
  end
  while #t > 0 and t[#t] == "" do table.remove(t) end
  return t
end)()

local SLACK = 320

-- The top bar's height, named once: the legend and the attributes panel
-- both have to clear it, and both used to do that with a literal.
local CHROME_H = 56
-- How many lines of status are worth covering the room for.
local STATUS_LINES = 3

-- The palette, in the order a level gets built rather than alphabetical.
-- TERRAIN ONLY on the tile row. Spikes, doors and gates moved into the
-- PROPS catalogue below: twelve tile swatches plus ten door and gate
-- letters was twenty-two things competing for the eye, and nineteen of
-- them are not what you are painting right now.
local PALETTE = { ".", "#", "=", "%", "*", "&", "c", "~", "L" }
-- Doors and gates paint like anything else. They are NOT terrain -- a
-- door cell is air with a letter on it and a link in another table -- so
-- moving one is only ever safe within the wall it already belongs to,
-- and the reachability check on every save is what says whether you got
-- it right.
local PNAME = { ["."] = "air", ["#"] = "solid", ["="] = "one-way platform",
  ["%"] = "breakable", ["*"] = "BULWARK block -- only Vess's plated charge",
  ["&"] = "LINK block -- only the LINK blast, so both bots, together",
  ["c"] = "crumbling", ["~"] = "water", ["L"] = "LAVA",
  ["^"] = "spike up", ["v"] = "spike down", ["<"] = "spike left",
  [">"] = "spike right" }

-- ==================================================================
-- PHASE 2: ENTITIES
-- ==================================================================
-- The header above used to say "terrain characters ONLY", because an
-- entity is two edits that are not independently valid -- a character in
-- the grid AND a line in `key` -- and a room with one and not the other
-- does not load at all. RoomIO.setKeyEntries puts both on a single write,
-- which is what made this safe to build.
--
-- THE EDITOR ALLOCATES THE CHARACTER. It is never typed, never chosen for
-- being mnemonic, and never one the engine already owns: the candidate
-- set is derived from World's own published alphabet and filtered against
-- what this room already uses. That is the single most expensive bug in
-- this project -- twelve known instances, `c` for a brazier and `C` for a
-- terminal among them -- and it is now impossible to commit by hand,
-- because there is no hand involved.
--
-- Ordered by what you reach for, not alphabetically. Enemies come from
-- Enemy.TYPES so this list cannot go stale when one is added.
local GATE_STYLES = { "portcullis", "shutter", "piston", "blast", "curtain" }

local PROPS = {
  { spec = "cell",    name = "ENERGY CELL",
    tip = "Lu drains it for half her bar. Refreshes when you leave the ZONE, not the room." },
  { spec = "anchor",  name = "GRAPPLE ANCHOR",
    tip = "Vess only, 110px reach, needs line of sight. His one mobility upgrade." },
  { spec = "updraft:6", name = "UPDRAFT x6",
    tip = "thermal column. Lu rides it with the DRIFT VANES; scenery to Vess. The number is its height in tiles." },
  { spec = "heart",   name = "HEART", tip = "3 hp." },
  { spec = "checkpoint", name = "CHECKPOINT",
    tip = "banks the run and moves the respawn. Gives no health and no energy. NEVER in a room that arms a boss." },
  { spec = "save",    name = "SAVE (retired)",
    tip = "resolves to a checkpoint. checkprops fails any room still using it -- here so you can find and replace one." },
  { spec = "plate",   name = "SWITCH (plate)", switch = true,
    tip = "a pressure plate. Placing one MAKES ITS FLAG for you; select a gate and press L to bind that gate to it." },
  { spec = "linkcore", name = "LINK CORE (lattice)", linkcore = true,
    tip = "armoured lattice. Ordinary fire clinks off it -- ONLY the charged "
       .. "LINK blast shatters it, which needs both bots together. It is not "
       .. "solid: it is the LOCK. Bind a GATE to its flag and that gate is "
       .. "the wall. Placing one MAKES ITS FLAG for you." },
  -- Spikes are terrain, but they belong with the things you place one of
  -- rather than with the things you paint a wall out of.
  { tile = "^", name = "SPIKE UP",    tip = "never stood on, never landed on. Jumping over is fine." },
  { tile = "v", name = "SPIKE DOWN",  tip = "ceiling spikes." },
  { tile = "<", name = "SPIKE LEFT",  tip = "wall spikes, pointing left." },
  { tile = ">", name = "SPIKE RIGHT", tip = "wall spikes, pointing right." },
}

for _, ch in ipairs({ "A", "B", "C", "D", "E", "F" }) do
  PROPS[#PROPS + 1] = { tile = ch, name = "DOOR " .. ch, door = true,
    tip = "a door is AIR with a letter on it; its link lives in links = {}. "
       .. "Move it along the wall it is already on, never onto another." }
end
for _, ch in ipairs({ "G", "H", "I", "J" }) do
  PROPS[#PROPS + 1] = { tile = ch, name = "GATE " .. ch, gate = true,
    tip = "solid until its flag is set. L cycles which flag, ; cycles the "
       .. "style (portcullis / shutter / piston / blast / curtain)." }
end

-- ------------------------------------------------------------------
-- THE BEAM PUZZLE (Crystal Hollows)
-- ------------------------------------------------------------------
-- Five props and one rule: an EMITTER throws a beam, a MIRROR or ROTOR
-- turns it, a PANEL is a mirror that slides on a rail, and a NODE
-- latches a flag once `need` beams land on it. Everything is authored
-- as `kind:part:part`, exactly as the crys_* rooms already do it, and
-- the numeric part of each is cycled with P rather than typed.
--
-- `mirror` is the diagonal's facing: `f` is '/' and `b` is '\\'.
local BEAM = {}
local FACE = { f = "/", b = "\\" }
for _, d in ipairs({ "right", "down", "left", "up" }) do
  BEAM[#BEAM + 1] = { spec = "emitter:" .. d, name = "EMITTER " .. d:upper(),
    tip = "throws a beam " .. d .. ", always on." }
  BEAM[#BEAM + 1] = { spec = "emitter:" .. d .. ":dormant:9",
    name = "EMITTER " .. d:upper() .. " DORMANT", num = { 4, 3, 18 },
    tip = "dark until something wakes it, then runs for the number of "
       .. "seconds on the end. ' cycles that number." }
end
for _, m in ipairs({ "f", "b" }) do
  BEAM[#BEAM + 1] = { spec = "mirror:" .. m, name = "MIRROR " .. FACE[m],
    tip = "a fixed diagonal. Turns a beam 90 degrees and never moves." }
  BEAM[#BEAM + 1] = { spec = "rotor:" .. m, name = "ROTOR " .. FACE[m],
    tip = "a diagonal that SPINS when shot -- it is kind 'enemy' so your "
       .. "shots collide with it. This is the one the player aims at." }
end
for _, rail in ipairs({ "h", "v" }) do
  for _, m in ipairs({ "f", "b" }) do
    BEAM[#BEAM + 1] = { spec = ("panel:%s:%s:4"):format(rail, m),
      name = ("PANEL %s %s"):format(rail == "h" and "SLIDE" or "LIFT", FACE[m]),
      num = { 4, 2, 8 },
      tip = "a mirror on a " .. (rail == "h" and "horizontal" or "vertical")
         .. " rail with N stops. ' cycles N." }
  end
end
BEAM[#BEAM + 1] = { spec = "node", name = "BEAM NODE", node = true,
  num = { 3, 1, 4 },
  tip = "latches a flag once enough beams land on it. Placing one MAKES "
     .. "ITS FLAG; select a gate and press L to bind that gate to it. "
     .. "' cycles how many beams it needs." }
for _, e in ipairs(BEAM) do
  e.beam = true
  PROPS[#PROPS + 1] = e
end

-- The two doors in the game that are allowed to have no link, copied
-- from SPAWN_DOORS in checkdoors.py: camp_awake.A is where a new game
-- starts and test_arena.A is the Test Chamber's way in. Reporting these
-- as dangling would train the eye to ignore the warning.
local SPAWN_DOORS = { ["camp_awake:A"] = true, ["test_arena:A"] = true }

local ENEMIES = {}
for _, n in ipairs(require("src.entities.enemies").TYPES or {}) do
  ENEMIES[#ENEMIES + 1] = { spec = n, name = n:upper(), enemy = true,
    tip = "enemy. Drops are tunable PER SPAWN -- append :energy=6 or "
       .. ":shards=0 to this room's key line." }
end
-- One flat list of forty behind two arrows is a list you STEP THROUGH
-- rather than choose from, which is why the label never seemed to
-- change however long you clicked. Two catalogues, and the long one gets
-- a search.

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
    tip = "CLICK a gate, door, button, node, emitter or panel to open its "
       .. "ATTRIBUTES and change what it does. DRAG instead to select a "
       .. "region, then ctrl+C / ctrl+X and ctrl+V to stamp it." },
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
  { id = "fixmap", label = "FIX MAP", key = "ctrl+M", tip = "re-solve the WORLD ATLAS so every door draws the way it goes. This room is PINNED -- the solver may not move it, and its file is not opened. Use it when a save fails with 'drawn N cells apart'." },
  { id = "newroom", label = "NEW ROOM", key = "ctrl+N", tip = "make a brand new room through a brand new door: pick a wall, and it writes the room file, both halves of the link and the WM.ROOMS entry. Save this room first." },
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
  -- char -> spec for this room, seeded from the file and added to as
  -- entities are placed. The grid is authoritative about which of them
  -- still matter; see S:keyEdits.
  self.entSpec = {}
  self.gateFlag, self.gateStyle = {}, {}
  self.linkTo = {}
  self.doorKind = {}
  local def = World.getRoomDef and World.getRoomDef(self.id)
  for ch, spec in pairs((def and def.key) or {}) do self.entSpec[ch] = spec end
  for ch, f in pairs((def and def.gates) or {}) do self.gateFlag[ch] = f end
  for ch, s in pairs((def and def.gateStyle) or {}) do self.gateStyle[ch] = s end
  for ch, l in pairs((def and def.links) or {}) do
    self.linkTo[ch] = { l[1], l[2], req = l.req }
  end
  for ch, k in pairs((def and def.doorKind) or {}) do self.doorKind[ch] = k end
  self.propIdx, self.enemyIdx = 1, 1
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
  self.hover = nil
  -- AFTER loadFromDisk, not before: the room is what decides entIdx and
  -- the entity catalogue, and laying out first is what froze the label.
  if self:loadFromDisk(false) then self.status = "editing " .. self.id end
  self.widgets = self:layout()
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

-- Is this character the engine's, rather than free for a spawn? Asked of
-- World's published tables, never of a list kept here.
function S:reserved(c)
  return World.CHAR_TILE[c] ~= nil or World.DOOR_CHARS[c] or World.GATE_CHARS[c]
end

-- The character for a spec in THIS room: the one already keyed to it if
-- there is one, otherwise the first candidate the room is not using.
-- Rooms key entities to alphanumerics by convention, so that is the
-- candidate set -- minus everything the engine owns, computed.
local CANDIDATES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

function S:charFor(spec)
  for ch, s in pairs(self.entSpec) do
    if s == spec then return ch end
  end
  local used = {}
  for ch in pairs(self.entSpec) do used[ch] = true end
  for _, row in ipairs(self.rows) do
    for i = 1, #row do used[row:sub(i, i)] = true end
  end
  for i = 1, #CANDIDATES do
    local c = CANDIDATES:sub(i, i)
    if not used[c] and not self:reserved(c) then
      self.entSpec[c] = spec
      return c
    end
  end
  return nil, "this room has no free map characters left"
end

-- What the key table must say once these rows are on disk. Derived from
-- the GRID rather than from a running tally, so it is self-healing: draw
-- over the last rollpede in a room and its key line goes with it.
function S:keyEdits()
  local def = World.getRoomDef and World.getRoomDef(self.id)
  local orig = (def and def.key) or {}
  local present, edits = {}, {}
  for _, row in ipairs(self.rows) do
    for i = 1, #row do
      local c = row:sub(i, i)
      if not self:reserved(c) then present[c] = true end
    end
  end
  for c in pairs(present) do
    local spec = self.entSpec[c] or orig[c]
    if not spec then
      -- Refuse rather than write it: World:load errors on an unmapped
      -- map char, so this would be a room that does not open.
      return nil, ("'%s' is on the map with nothing to spawn"):format(c)
    end
    if spec ~= orig[c] then edits[c] = spec end
  end
  for c in pairs(orig) do
    if not present[c] then edits[c] = false end
  end
  return edits
end

-- WHICH DELETIONS ARE WORTH ASKING ABOUT.
--
-- keyEdits heals from the grid, and it should: paint over the last
-- rollpede and its key line goes with it. But the same rule painted over
-- furn_boss's Crucible during a layout pass -- one cell out of about a
-- hundred and thirty changed in that save -- and took the room's boss
-- with it. The room still loaded. The only symptom anywhere was
-- checkprogress calling four Core rooms unreachable, because the
-- Crucible's reward is what opens the Core door.
--
-- An enemy is scenery; these are not. Each of them is either a flag
-- somebody needs or a service a room provides, and losing one is a
-- decision rather than a side effect of drawing a wall.
local CONSEQUENTIAL = {
  boss = true, chest = true, capsule = true, tank = true, linkcore = true,
  teleporter = true, save = true, checkpoint = true, npc = true,
  reward = true, seat = true, sign = true,
}

function S:gravedigger(edits)
  local def = World.getRoomDef and World.getRoomDef(self.id)
  local orig = (def and def.key) or {}
  local lost = {}
  for c, v in pairs(edits or {}) do
    if v == false then
      local spec = orig[c]
      local head = spec and spec:match("^(%a+)")
      if head and CONSEQUENTIAL[head] then
        lost[#lost + 1] = ("'%s' (%s)"):format(c, spec)
      end
    end
  end
  table.sort(lost)
  return lost
end

-- Same shape as keyEdits, and derived from the GRID for the same reason:
-- paint out the last cell of gate H and its flag goes with it.
function S:gateEdits()
  local def = World.getRoomDef and World.getRoomDef(self.id)
  local og = (def and def.gates) or {}
  local os_ = (def and def.gateStyle) or {}
  local present = {}
  for _, row in ipairs(self.rows) do
    for i = 1, #row do
      local c = row:sub(i, i)
      if World.GATE_CHARS[c] then present[c] = true end
    end
  end
  local ge, se = {}, {}
  for c in pairs(present) do
    local f = (self.gateFlag or {})[c] or og[c]
    if f and f ~= og[c] then ge[c] = f end
    local st = (self.gateStyle or {})[c]
    if st and st ~= os_[c] then se[c] = st end
  end
  for c in pairs(og) do if not present[c] then ge[c] = false end end
  for c in pairs(os_) do if not present[c] then se[c] = false end end
  return ge, se
end

-- Same shape again, and for the same reason: paint a door off the wall
-- and its link goes with it.
--
-- This is the field that was MISSING. A door is a reserved character, so
-- keyEdits skips it by design and nothing else picked it up -- painting
-- a fresh door letter wrote a room whose map had a `C` on it and whose
-- links table did not, which checkdoors reports as NOLINK. The editor
-- could open the wound and not close it.
--
-- Note what it does NOT do: invent a destination. A door with no link
-- yet is left alone rather than pointed somewhere arbitrary, because
-- links are mutual and the other half lives in another file. Making one
-- is S:newRoom or S:linkDoor; this only keeps the table honest about
-- which doors still exist.
function S:linkEdits()
  local def = World.getRoomDef and World.getRoomDef(self.id)
  local ol = (def and def.links) or {}
  local present = {}
  for _, row in ipairs(self.rows) do
    for i = 1, #row do
      local c = row:sub(i, i)
      if World.DOOR_CHARS[c] then present[c] = true end
    end
  end
  local le = {}
  for c in pairs(self.linkTo or {}) do
    if present[c] then le[c] = self.linkTo[c] end
  end
  for c in pairs(ol) do
    if not present[c] then le[c] = false end
  end
  return le
end

-- WHICH DOORS ARE UNLINKED, so the editor can say so before the
-- validator has to. Returns a sorted list of characters.
-- The side a door's POSITION implies, by the engine's own precedence.
-- Shown in the panel as the default, so "derived: left" and "declared:
-- portal" are visibly different things.
function S:derivedSide(ch)
  local d = self:doorCells()[ch]
  if not d then return nil end
  if d.x0 == 0 then return "left" end
  if d.x1 == self:w() - 1 then return "right" end
  if d.y0 == 0 then return "top" end
  if d.y1 == self:h() - 1 then return "bottom" end
  return "portal"
end

-- Same self-healing shape as the rest: a doorKind for a door that is no
-- longer on the map goes with it, and a kind equal to what position
-- already implies is not written at all -- there is no reason to put a
-- line in a file to state the default.
function S:doorKindEdits()
  local def = World.getRoomDef and World.getRoomDef(self.id)
  local od = (def and def.doorKind) or {}
  local present = self:doorCells()
  local out = {}
  for ch in pairs(present) do
    local want = (self.doorKind or {})[ch]
    if want == self:derivedSide(ch) then want = nil end
    if want ~= od[ch] then out[ch] = want or false end
  end
  for ch in pairs(od) do if not present[ch] then out[ch] = false end end
  return out
end

function S:danglingDoors()
  local def = World.getRoomDef and World.getRoomDef(self.id)
  local ol = (def and def.links) or {}
  local out = {}
  for ch in pairs(self:doorCells()) do
    if not ol[ch] and not (self.linkTo or {})[ch]
       and not SPAWN_DOORS[self.id .. ":" .. ch] then
      out[#out + 1] = ch
    end
  end
  table.sort(out)
  return out
end

-- ------------------------------------------------------------------
-- THE WORLD ATLAS
-- ------------------------------------------------------------------
-- A room draws on the map at (ZONE_OFFSETS[zone] + mapPos) * CELL, so
-- two rooms only collide in ABSOLUTE space -- `mapPos = {x=1,y=2}` is
-- free in Mosswood and taken in Skyroot, and a search that works in
-- zone-relative coordinates will happily put a new room on top of one
-- in the zone next door. checkmap fails that; this avoids it.
function S:atlas()
  local WM = require "src.data.worldmap"
  local taken, mine = {}, nil
  for _, id in ipairs(WM.ROOMS) do
    local d = World.getRoomDef and World.getRoomDef(id)
    local mp = d and d.mapPos
    local off = d and WM.ZONE_OFFSETS[d.zone]
    if mp and off then
      local x0, y0 = off.x + mp.x, off.y + mp.y
      for dy = 0, (mp.h or 1) - 1 do
        for dx = 0, (mp.w or 1) - 1 do
          taken[(x0 + dx) .. "," .. (y0 + dy)] = id
        end
      end
      if id == self.id then
        mine = { x0 = x0, y0 = y0, x1 = x0 + (mp.w or 1) - 1,
                 y1 = y0 + (mp.h or 1) - 1, off = off }
      end
    end
  end
  return taken, mine
end

-- A free cell for a room hung off `side` of this one, returned as the
-- ZONE-RELATIVE mapPos the room file wants.
--
-- It starts in the direction the door actually goes -- a right-hand door
-- should draw the new room to the right, which is the whole of
-- checkmap's fault 3 -- and only walks further out if that cell is
-- taken. Walking is along the same axis, so a right door never resolves
-- to a cell above.
local SIDE_STEP = { left = { -1, 0 }, right = { 1, 0 },
                    top = { 0, -1 }, bottom = { 0, 1 } }

function S:freeMapCell(side)
  local taken, mine = self:atlas()
  if not mine then return nil, "this room has no mapPos to hang one off" end
  local step = SIDE_STEP[side]
  if not step then return nil, "unknown side " .. tostring(side) end
  local bx = (step[1] < 0 and mine.x0) or (step[1] > 0 and mine.x1) or mine.x0
  local by = (step[2] < 0 and mine.y0) or (step[2] > 0 and mine.y1) or mine.y0
  for n = 1, 12 do
    local x, y = bx + step[1] * n, by + step[2] * n
    if x >= 0 and y >= 0 and not taken[x .. "," .. y] then
      -- back into the zone's own frame, which is what mapPos means
      return { x = x - mine.off.x, y = y - mine.off.y }, nil, x, y
    end
  end
  return nil, ("no free map cell within 12 to the %s -- the atlas is "
    .. "crowded there, place it by hand"):format(side)
end

-- ------------------------------------------------------------------
-- A NEW ROOM, THROUGH A NEW DOOR
-- ------------------------------------------------------------------
-- Everything is DERIVED except the wall you pick. The id comes from this
-- room's own prefix, the zone and music come from this room's def, the
-- map cell comes from the atlas, and the door letters are the next free
-- ones. Nothing is typed, because every one of those is a string that
-- has to agree with a string in another file, and a typo in any of them
-- is a room that does not load or a door that goes nowhere.

local OPPOSITE = { left = "right", right = "left",
                   top = "bottom", bottom = "top" }

-- The next A-F this room is not already using.
function S:freeDoorChar()
  local used = self:doorCells()
  for _, ch in ipairs({ "A", "B", "C", "D", "E", "F" }) do
    if not used[ch] then return ch end
  end
  return nil, "this room already has all six doors -- DOOR_CHARS is A-F "
    .. "and that is an architectural limit, not a setting"
end

-- `moss_2` -> `moss_9`, skipping every id already on disk.
function S:freeRoomId()
  local prefix = self.id:match("^(%a+)_") or self.id
  for n = 1, 99 do
    local id = ("%s_%d"):format(prefix, n)
    if not RoomIO.roomExists(id) then return id end
  end
  return nil, "no free id under the prefix " .. prefix
end

-- Cut a 2-tall door into `side`, centred on `at`, and hollow three tiles
-- inward so it is not a doorway buried in rock.
--
-- The side is a property of the door's BOUNDING BOX and the precedence
-- is left, right, top, bottom -- so a door placed in a CORNER classifies
-- as left or right whatever wall you meant. It is clamped away from the
-- corners here rather than discovered by checkdoors later.
local function carve(rows, side, ch, at)
  local W, H = #rows[1], #rows
  local function put(x, y, c)          -- 0-based
    if x < 0 or y < 0 or x >= W or y >= H then return end
    local r = rows[y + 1]
    rows[y + 1] = r:sub(1, x) .. c .. r:sub(x + 2)
  end
  if side == "left" or side == "right" then
    local x = (side == "left") and 0 or (W - 1)
    local dir = (side == "left") and 1 or -1
    local y = math.max(1, math.min(H - 3, at))     -- never row 0 or H-1
    put(x, y, ch); put(x, y + 1, ch)
    for d = 1, 3 do
      put(x + dir * d, y, "."); put(x + dir * d, y + 1, ".")
    end
    return y
  else
    local y = (side == "top") and 0 or (H - 1)
    local dir = (side == "top") and 1 or -1
    local x = math.max(1, math.min(W - 3, at))     -- never column 0 or W-1
    put(x, y, ch); put(x + 1, y, ch)
    for d = 1, 3 do
      put(x, y + dir * d, "."); put(x + 1, y + dir * d, ".")
    end
    return x
  end
end

-- The whole transaction. Validate everything first, then write, because
-- the halfway states are all bad: a room file with nothing pointing at
-- it, a link to a room that does not exist, a name in WM.ROOMS with no
-- file behind it. Anything that can be checked is checked before the
-- first byte is written.
function S:newRoom(side)
  if not self.rows then return end
  if self.dirty then
    self.status = "save this room first -- a new door has to be written "
      .. "into a file that is already up to date"
    return
  end

  local myDoor, e1 = self:freeDoorChar()
  if not myDoor then self.status = "NEW ROOM REFUSED: " .. e1 return end
  local newId, e2 = self:freeRoomId()
  if not newId then self.status = "NEW ROOM REFUSED: " .. e2 return end
  local mp, e3 = self:freeMapCell(side)
  if not mp then self.status = "NEW ROOM REFUSED: " .. e3 return end
  local def = World.getRoomDef and World.getRoomDef(self.id)
  if not def or not def.zone then
    self.status = "NEW ROOM REFUSED: this room has no zone to inherit"
    return
  end

  -- carve THIS room's door, next to where you were looking
  local tx, ty = self:cursorTile()
  local mine = {}
  for i, r in ipairs(self.rows) do mine[i] = r end
  local at = (side == "left" or side == "right") and ty or tx
  carve(mine, side, myDoor, at)

  -- ...and the new room's, on the wall that faces it, at the same place
  local NW, NH = 30, 17
  local back = OPPOSITE[side]
  local nrows = {}
  for y = 1, NH do
    local r = {}
    for x = 1, NW do
      r[x] = (y <= 2 or y > NH - 3 or x <= 2 or x > NW - 2) and "#" or "."
    end
    nrows[y] = table.concat(r)
  end
  -- put it on the new room's floor rather than at the same height as a
  -- door that might be twenty rows up a shaft
  local nat = (back == "left" or back == "right") and (NH - 5)
              or math.floor(NW / 2)
  carve(nrows, back, "A", nat)

  -- THREE FILES, AND NO HALF OF THIS IS SURVIVABLE.
  --
  -- A room file nothing points at is litter; a link to a room that does
  -- not exist is a crash on the way through the door; a name in
  -- WM.ROOMS with no file behind it stops the game loading at all. So
  -- every one of the three is DRY RUN first and none is committed until
  -- all three come back clean. What remains after that is disk I/O,
  -- which can still fail and is reported rather than swallowed.
  local spec = { id = newId, zone = def.zone, music = def.music or def.zone,
                 mx = mp.x, my = mp.y, door = "A",
                 backRoom = self.id, backDoor = myDoor, w = NW, h = NH }
  local links = self:linkEdits()
  links[myDoor] = { newId, "A" }

  local dryMine, e4 = RoomIO.writeMap(self.id, mine,
    { dryrun = true, key = self:keyEdits(), links = links })
  if not dryMine then self.status = "NEW ROOM REFUSED: " .. tostring(e4) return end
  local dryNew, e5 = RoomIO.createRoom(spec, nrows, true)
  if not dryNew then self.status = "NEW ROOM REFUSED: " .. tostring(e5) return end
  local dryWM, e6 = RoomIO.registerRoom(newId, true)
  if not dryWM then self.status = "NEW ROOM REFUSED: " .. tostring(e6) return end

  -- ---- committed from here ------------------------------------------
  local ok, err = RoomIO.createRoom(spec, nrows)
  if not ok then self.status = "NEW ROOM FAILED: " .. tostring(err) return end
  local reg, rerr = RoomIO.registerRoom(newId)
  if not reg then
    os.remove(RoomIO.path(newId))            -- put the world back
    self.status = "NEW ROOM FAILED (rolled back): " .. tostring(rerr)
    return
  end
  self.rows = mine
  self.linkTo[myDoor] = { newId, "A" }
  local wrote, werr = RoomIO.writeMap(self.id, mine,
    { key = self:keyEdits(), links = links })
  if not wrote then
    -- the new room is on disk and registered, and this room does not
    -- point at it yet. Say exactly that: it is recoverable by saving.
    self.dirty = true
    self.status = ("%s was created but THIS room did not save (%s) -- "
      .. "press ctrl+S"):format(newId, tostring(werr))
    return
  end

  RoomIO.invalidate(self.id)
  RoomIO.invalidate(newId)
  package.loaded["src.data.worldmap"] = nil
  self.dirty = false
  self:rebuildWorld(0, 0)
  self.widgets = self:layout()
  self.status = ("%s created to the %s -- %s.%s <-> %s.A, registered, "
    .. "both halves written"):format(newId, side, self.id, myDoor, newId)
  self:startChecks(false, false)
end

-- ==================================================================
-- ATTRIBUTES
-- ==================================================================
-- Stepping a catalogue with two arrow keys works for CHOOSING a thing
-- to paint and not at all for CHANGING one you have already painted --
-- the beam node sat 37 presses into a 38-entry list, and the only way
-- to see which entry you were on was a label that the status line was
-- printing over. So: pick up the SEL tool, click the thing, and edit it
-- where it is.
--
-- Every attribute here is a field of a spec string or of the `gates`
-- table. Nothing new is stored -- the panel is a view onto the same two
-- places S:keyEdits and S:gateEdits already read, which is what keeps
-- it self-healing when you paint the object away.

-- The vocabulary a gate can open on. Gathered rather than typed:
-- bosses out of bosses.lua, modules out of core/progress, and this
-- room's own plates and nodes out of the room. A flag you cannot get
-- wrong is a flag you never typed.
local BOSS_FLAGS = {
  "boss_bramblemaw", "boss_rustwarden", "boss_tideengine", "boss_slaggolem",
  "boss_crucible", "boss_prismtyrant", "boss_aeriesentinel",
  "boss_motherengine", "boss_mycelchoir", "boss_archivist", "boss_vessel8",
}
local MODULE_FLAGS = {
  "sparkjump", "grapple", "driftvanes", "hydroseals", "heatplating",
  "telenet", "bulwark", "cinderram", "linkblast",
  "corekey1", "corekey2", "corekey3",
}

-- Every flag this gate could sensibly name, grouped, with the room's own
-- first because that is what a gate usually waits on.
function S:flagChoices()
  local out, seen = {}, {}
  local function add(f, group)
    if f and f ~= "" and not seen[f] then
      seen[f] = true
      out[#out + 1] = { flag = f, group = group }
    end
  end
  for _, f in ipairs(self:roomFlags()) do add(f, "this room") end
  for _, f in ipairs(BOSS_FLAGS) do add(f, "boss down") end
  for _, f in ipairs(MODULE_FLAGS) do add(f, "module") end
  return out
end

-- What is at this cell that has anything to edit?
function S:objectAt(tx, ty)
  local ch = self:get(tx, ty)
  if not ch then return nil end
  if World.GATE_CHARS[ch] then return { kind = "gate", ch = ch } end
  if World.DOOR_CHARS[ch] then return { kind = "door", ch = ch } end
  local spec = self.entSpec and self.entSpec[ch]
  if not spec then return nil end
  local head = spec:match("^(%w+)")
  if head == "node" or head == "plate" or head == "emitter"
     or head == "panel" or head == "rotor" or head == "mirror"
     or head == "updraft" or head == "linkcore" then
    return { kind = head, ch = ch, spec = spec }
  end
  return { kind = "spec", ch = ch, spec = spec }
end

-- A field is { name, get, set } over the spec or the gate tables. Built
-- fresh each time the panel opens so it always describes what is there.
local function specParts(spec)
  local t = {}
  for piece in tostring(spec):gmatch("[^:]+") do t[#t + 1] = piece end
  return t
end

local DIRS = { "right", "down", "left", "up" }
local FACES = { "f", "b" }
local RAILS = { "h", "v" }
local DOOR_KINDS = { "left", "right", "top", "bottom", "portal" }

local function cycleIn(list, cur, d)
  local at = 1
  for i, v in ipairs(list) do if v == cur then at = i end end
  at = at + d
  if at < 1 then at = #list elseif at > #list then at = 1 end
  return list[at]
end

function S:attrFields(obj)
  local F = {}
  local function specField(name, idx, list, tip)
    F[#F + 1] = { name = name, tip = tip,
      get = function() return specParts(self.entSpec[obj.ch])[idx] or "?" end,
      step = function(d)
        local p = specParts(self.entSpec[obj.ch])
        p[idx] = cycleIn(list, p[idx], d)
        self.entSpec[obj.ch] = table.concat(p, ":")
        self.dirty = true
      end }
  end
  -- `hi` is a HARD ceiling and the stepper wraps at it, which is what you
  -- want for a short enumeration (four beams, eight rail stops).
  --
  -- Pass `soft` and it becomes a GUIDELINE instead: the stepper stops on
  -- it once, so a stray press cannot sail past, and a second press goes
  -- on by. Nothing above it is ever clobbered -- a value hand-written in
  -- the room file is carried as it stands and steps from where it is.
  -- Wrapping was the bug there: with a ceiling of 16, a hand-authored 24
  -- became 2 on the first press of '+'.
  local function numField(name, idx, lo, hi, tip, soft)
    F[#F + 1] = { name = name, tip = tip,
      get = function()
        local v = specParts(self.entSpec[obj.ch])[idx] or lo
        local n = tonumber(v)
        -- a '*' marks a value past the guideline. Kept to one character:
        -- the row wraps its value and truncates with "...", so a long
        -- parenthetical would eat the number it was explaining.
        if soft and n and n > hi then return tostring(n) .. "*" end
        return tostring(v)
      end,
      step = function(d)
        local p = specParts(self.entSpec[obj.ch])
        local cur = tonumber(p[idx]) or lo
        local n = cur + d
        if soft then
          if n < lo then n = lo
          elseif n > hi and cur < hi then n = hi end
        else
          if n < lo then n = hi elseif n > hi then n = lo end
        end
        p[idx] = tostring(n)
        self.entSpec[obj.ch] = table.concat(p, ":")
        self.dirty = true
      end }
  end

  if obj.kind == "gate" then
    F[#F + 1] = { name = "OPENS ON", pick = "flag",
      tip = "the flag that opens this gate. Any number of gates may name "
         .. "the SAME flag, and any number of buttons may set it -- that "
         .. "is how one button opens three gates and three buttons open one.",
      get = function()
        local f = (self.gateFlag or {})[obj.ch] or "?"
        return (f:sub(1, 1) == "!") and f:sub(2) or f
      end }
    F[#F + 1] = { name = "WHEN", tip = "GATE is solid until the flag is "
         .. "set. BRIDGE is the inverse -- solid WHILE it is set, which is "
         .. "what a '!' in the room file means.",
      get = function()
        local f = (self.gateFlag or {})[obj.ch] or ""
        return f:sub(1, 1) == "!" and "BRIDGE (solid while set)"
                                  or "GATE (solid until set)"
      end,
      step = function()
        local f = (self.gateFlag or {})[obj.ch] or ""
        if f == "" then return end
        self.gateFlag[obj.ch] = (f:sub(1, 1) == "!") and f:sub(2) or ("!" .. f)
        self.dirty = true
      end }
    F[#F + 1] = { name = "STYLE", tip = "how it moves when it opens.",
      get = function() return (self.gateStyle or {})[obj.ch] or "portcullis" end,
      step = function(d)
        self.gateStyle = self.gateStyle or {}
        self.gateStyle[obj.ch] = cycleIn(GATE_STYLES,
          self.gateStyle[obj.ch] or "portcullis", d)
        self.dirty = true
      end }

  elseif obj.kind == "node" then
    F[#F + 1] = { name = "SETS FLAG", pick = "flag",
      tip = "the flag this node latches once enough beams land on it. "
         .. "Point a gate's OPENS ON at this and the puzzle is wired.",
      get = function() return specParts(self.entSpec[obj.ch])[2] or "?" end }
    numField("BEAMS NEEDED", 3, 1, 4,
      "how many beams have to arrive before it latches.")

  elseif obj.kind == "plate" then
    F[#F + 1] = { name = "SETS FLAG", pick = "flag",
      tip = "the flag this button sets. Pick one another button already "
         .. "uses and the two become alternatives for the same gate.",
      get = function() return specParts(self.entSpec[obj.ch])[2] or "?" end }
    F[#F + 1] = { name = "LATCHING", tip = "LATCH stays set once pressed. "
         .. "MOMENTARY holds only while something is standing on it, and "
         .. "several momentary plates on one flag are OR'd together.",
      get = function()
        return specParts(self.entSpec[obj.ch])[3] == "latch" and "LATCH" or "MOMENTARY"
      end,
      step = function()
        local p = specParts(self.entSpec[obj.ch])
        if p[3] == "latch" then p[3] = nil else p[3] = "latch" end
        self.entSpec[obj.ch] = table.concat(p, ":")
        self.dirty = true
      end }

  elseif obj.kind == "linkcore" then
    F[#F + 1] = { name = "SETS FLAG", pick = "flag",
      tip = "the flag the lattice releases when the LINK blast shatters "
         .. "it. Point a GATE's OPENS ON at this: the core is the lock and "
         .. "the gate is the wall. Nothing else in the game opens it, so "
         .. "the pair have to be together and charged.",
      get = function() return specParts(self.entSpec[obj.ch])[2] or "?" end }

  elseif obj.kind == "emitter" then
    specField("DIRECTION", 2, DIRS, "which way it throws the beam.")
    F[#F + 1] = { name = "STARTS", tip = "DORMANT means Lu has to wake it "
         .. "with her shield, and it runs for the number of seconds below.",
      get = function()
        return specParts(self.entSpec[obj.ch])[3] == "dormant" and "DORMANT" or "LIT"
      end,
      step = function()
        local p = specParts(self.entSpec[obj.ch])
        if p[3] == "dormant" then p[3], p[4] = nil, nil
        else p[3], p[4] = "dormant", p[4] or "9" end
        self.entSpec[obj.ch] = table.concat(p, ":")
        self.dirty = true
      end }
    numField("BURNS FOR", 4, 3, 18, "seconds it stays lit once woken.")

  elseif obj.kind == "panel" then
    specField("RAIL", 2, RAILS, "h slides sideways, v lifts.")
    specField("FACING", 3, FACES, "f is '/', b is '\\'.")
    numField("STOPS", 4, 2, 8, "how many positions along the rail.")

  elseif obj.kind == "rotor" or obj.kind == "mirror" then
    specField("FACING", 2, FACES, "f is '/', b is '\\'.")

  elseif obj.kind == "updraft" then
    numField("HEIGHT", 2, 2, 32, "how many tiles of column. 32 is a "
         .. "guideline, not a rule -- the stepper pauses there, press "
         .. "again to go past, and a taller column written in the room "
         .. "file is kept as it stands. A '*' marks one that is over.",
      true)

  elseif obj.kind == "door" then
    F[#F + 1] = { name = "KIND", tip = "a WALL door is walked into and puts "
         .. "an arriving bot against that wall; a PORTAL is entered with "
         .. "INTERACT and can sit anywhere. Position picks the default. "
         .. "Only a WALL claim is checked -- it has to be on that wall -- "
         .. "so portal and wall doors may link to each other freely.",
      get = function()
        local d = (self.doorKind or {})[obj.ch]
        local der = self:derivedSide(obj.ch)
        if not d or d == der then return (der or "?") .. "  (from position)" end
        return d .. "  (declared)"
      end,
      step = function(dir)
        self.doorKind = self.doorKind or {}
        local cur = self.doorKind[obj.ch] or self:derivedSide(obj.ch) or "portal"
        self.doorKind[obj.ch] = cycleIn(DOOR_KINDS, cur, dir)
        self.dirty = true
      end }
    F[#F + 1] = { name = "GOES TO", tip = "a link is mutual and lives in "
         .. "two files, so it is made with ctrl+N rather than edited here.",
      get = function()
        local l = (self.linkTo or {})[obj.ch]
        return l and (l[1] .. "." .. tostring(l[2])) or "NOT LINKED"
      end }
    F[#F + 1] = { name = "SEALED BY", tip = "a req on this side of the "
         .. "link. Put the SAME req on the partner or the door is shut "
         .. "one way and open the other.",
      get = function()
        local l = (self.linkTo or {})[obj.ch]
        return (l and l.req) or "nothing"
      end }
  end
  return F
end

function S:openAttrs(tx, ty)
  local obj = self:objectAt(tx, ty)
  if not obj then
    self.status = "nothing with attributes there -- SEL-click a gate, a "
      .. "door, a button or a beam prop"
    return
  end
  if obj.kind == "gate" then self:ensureGateFlag(obj.ch) end
  local fields = self:attrFields(obj)
  if #fields == 0 then
    self.status = ("'%s' is %s -- nothing to adjust"):format(obj.ch,
      tostring(obj.spec))
    return
  end
  self.attrs = { obj = obj, fields = fields, sel = 1, rects = {} }
end

function S:closeAttrs()
  self.attrs = nil
  self.widgets = self:layout()
end

-- ENTER on a "pick" field opens the flag chooser, which is the finder in
-- a different hat: type to filter, ENTER to take it.
function S:openFlagPick()
  local a = self.attrs
  if not a then return end
  local f = a.fields[a.sel]
  if not f or f.pick ~= "flag" then return end
  a.pick = { q = "", sel = 1 }
  love.keyboard.setKeyRepeat(true)
end

function S:flagPickHits()
  local a = self.attrs
  local q = ((a and a.pick and a.pick.q) or ""):lower()
  local out = {}
  for _, c in ipairs(self:flagChoices()) do
    if q == "" or c.flag:lower():find(q, 1, true) then out[#out + 1] = c end
  end
  return out
end

function S:applyFlag(flag)
  local a = self.attrs
  if not a then return end
  local obj = a.obj
  if obj.kind == "gate" then
    local cur = (self.gateFlag or {})[obj.ch] or ""
    local inv = cur:sub(1, 1) == "!"
    self.gateFlag[obj.ch] = (inv and "!" or "") .. flag
  else
    local p = specParts(self.entSpec[obj.ch])
    p[2] = flag
    self.entSpec[obj.ch] = table.concat(p, ":")
  end
  self.dirty = true
  a.pick = nil
  love.keyboard.setKeyRepeat(false)
  self.status = ("%s -> %s"):format(a.fields[a.sel].name, flag)
end

function S:attrsKey(k)
  local a = self.attrs
  if not a then return false end
  if a.pick then
    local hits = self:flagPickHits()
    if k == "escape" then a.pick = nil love.keyboard.setKeyRepeat(false)
    elseif k == "backspace" then a.pick.q = a.pick.q:sub(1, -2) a.pick.sel = 1
    elseif k == "down" then a.pick.sel = math.min(math.max(1, #hits), a.pick.sel + 1)
    elseif k == "up" then a.pick.sel = math.max(1, a.pick.sel - 1)
    elseif k == "return" or k == "kpenter" then
      local h = hits[a.pick.sel]
      if h then self:applyFlag(h.flag) end
    elseif k == "n" then
      -- a brand new one, invented the way placing a switch invents one
      self:applyFlag(a.obj.kind == "node" and self:newBeamFlag()
                                          or self:newSwitchFlag())
    end
    return true
  end
  if k == "escape" then self:closeAttrs()
  elseif k == "down" then a.sel = math.min(#a.fields, a.sel + 1)
  elseif k == "up" then a.sel = math.max(1, a.sel - 1)
  elseif k == "left" or k == "right" then
    local f = a.fields[a.sel]
    if f and f.step then f.step(k == "right" and 1 or -1) end
  elseif k == "return" or k == "kpenter" then
    local f = a.fields[a.sel]
    if f and f.pick then self:openFlagPick()
    elseif f and f.step then f.step(1) end
  end
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

-- The generic form of what startChecks does, so anything else that has
-- to shell out gets the same progress panel, the same failure panel and
-- the same "do not run two at once" guard rather than a second copy.
-- `onDone` runs only when every item exited 0.
function S:runJob(items, label, onDone)
  if self.job then self.status = "checks still running -- wait for them" return end
  local prog = love.thread.getChannel("edcheck_progress")
  local res = love.thread.getChannel("edcheck_result")
  while prog:pop() do end
  while res:pop() do end
  local th = love.thread.newThread("src/checkthread.lua")
  th:start(table.concat(items, "\n"))
  self.job = { thread = th, deep = false, t0 = love.timer.getTime(),
               n = #items, done = 0, step = label or "working",
               eta = 45, onDone = onDone, label = label }
  self.status = (label or "working") .. " in the background"
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
    local done = j.onDone
    self.job = nil
    if bad == 0 and done then
      local ok, err = pcall(done)
      if not ok then self.status = "post-step failed: " .. tostring(err) end
    end
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
  local edits, kerr = self:keyEdits()
  if not edits then self.status = "SAVE REFUSED: " .. tostring(kerr) return end
  -- ...and if this save would take something load-bearing off the map,
  -- say what, and make the second press the confirmation. Refusing
  -- outright would be wrong -- deleting a chest is a legitimate edit --
  -- but doing it silently is how a boss goes missing for a day.
  local lost = self:gravedigger(edits)
  if #lost > 0 then
    local sig = table.concat(lost, "|")
    if self.confirmWipe ~= sig then
      self.confirmWipe = sig
      self.status = ("SAVE HELD: this removes %s from the room. Save again "
        .. "to confirm."):format(table.concat(lost, ", "))
      return
    end
  end
  self.confirmWipe = nil
  local gEdits, sEdits = self:gateEdits()
  local ok, err = RoomIO.writeMap(self.id, self.rows,
    { shift = shift, key = edits, gates = gEdits, gateStyle = sEdits,
      links = self:linkEdits(), doorKind = self:doorKindEdits() })
  if not ok then self.status = "SAVE REFUSED: " .. tostring(err) return end
  RoomIO.invalidate(self.id)
  self.pendDX, self.pendDY = 0, 0
  self.dirty = false
  self.failures = nil
  -- Say it here rather than leaving it to checkdoors six seconds later.
  -- A door with no link is the one edit whose consequence is invisible
  -- on screen: the letter is painted, the room looks finished, and the
  -- door goes nowhere.
  local dangling = self:danglingDoors()
  if #dangling > 0 then
    self.status = ("saved -- but door %s has no link. ctrl+N hangs a NEW "
      .. "room off it."):format(table.concat(dangling, ", "))
  end
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

-- Choosing an entity just makes its character the brush. Every tool --
-- brush, rect, fill, the stamp -- then works on it unchanged, which is
-- why there is no "entity mode" anywhere in this file.
-- THE WIDGET LIST IS BUILT ONCE, IN S:enter.
--
-- Which was fine while every label was a constant, and wrong the moment
-- one of them showed a selection: the entity name was baked at enter
-- time -- before loadFromDisk had even set entIdx -- so it read "ENERGY
-- CELL" forever however many times you clicked the arrows. The selection
-- moved, the status line moved, and the one piece of chrome that was
-- supposed to tell you what you were about to place did not.
--
-- Anything that changes what a widget SAYS has to rebuild them.
function S:cat(which)
  return which == "enemy" and ENEMIES or PROPS
end

function S:stepEntity(d, which)
  which = which or "prop"
  local list = self:cat(which)
  local k = which == "enemy" and "enemyIdx" or "propIdx"
  self[k] = (((self[k] or 1) - 1 + d) % #list) + 1
  self.widgets = self:layout()
  self.status = list[self[k]].name .. "   (pick it to paint with it)"
end

-- Choosing anything -- a prop, a spike, a door, a gate, an enemy -- just
-- makes a CHARACTER the brush. Every tool then works on it unchanged,
-- which is why there is no "entity mode" anywhere in this file.
function S:pickEntity(which)
  local list = self:cat(which or "prop")
  local e = list[(which == "enemy" and self.enemyIdx or self.propIdx) or 1]
  if not e then return end

  -- a door, a gate or a spike IS a character; nothing to allocate
  if e.tile then
    self.primary = e.tile
    if e.gate then self:ensureGateFlag(e.tile) end
    self.widgets = self:layout()
    self.status = e.name .. "  ->  '" .. e.tile .. "'"
    return
  end

  -- a SWITCH invents its own flag, so you never type one; a beam NODE
  -- does the same, because it is the other thing in this editor that
  -- OWNS a flag rather than reading one.
  local spec = e.spec
  if e.switch then spec = "plate:" .. self:newSwitchFlag() end
  if e.node then
    spec = ("node:%s:%d"):format(self:newBeamFlag(), (e.num and e.num[1]) or 1)
  end
  if e.linkcore then spec = "linkcore:" .. self:newLinkFlag() end

  local ch, err = self:charFor(spec)
  if not ch then self.status = "CANNOT PLACE: " .. tostring(err) return end
  self.primary = ch
  self.widgets = self:layout()
  self.status = e.name .. "  ->  '" .. ch .. "'"
end

-- ------------------------------------------------------------------
-- SWITCHES AND GATES, WITHOUT TYPING A FLAG NAME
-- ------------------------------------------------------------------
-- A gate opens on a flag and a plate sets one, so linking them is a
-- matter of agreeing on a string -- and a string you TYPE is a string
-- you can typo, in a place where a typo is a gate that never opens and
-- no validator that can tell you why.
--
-- So nothing is typed. Placing a switch invents `sw_<room>_<n>`; F
-- cycles the selected gate through the flags this room actually
-- contains. The link is therefore always to something real.
function S:roomFlags()
  local out, seen = {}, {}
  for _, spec in pairs(self.entSpec or {}) do
    local f = spec:match("^plate:([%w_]+)") or spec:match("^tank:([%w_]+)")
      or spec:match("^capsule:([%w_]+)") or spec:match("^linkcore:([%w_]+)")
      -- a beam NODE latches a flag when enough beams land on it, which
      -- makes it a gate opener exactly like a plate. Without this line
      -- you can place the whole Crystal puzzle and then have nothing to
      -- bind the gate it is supposed to open to.
      or spec:match("^node:([%w_]+)")
    if f and not seen[f] then seen[f] = true out[#out + 1] = f end
  end
  for _, f in pairs(self.gateFlag or {}) do
    if not seen[f] then seen[f] = true out[#out + 1] = f end
  end
  table.sort(out)
  return out
end

function S:newSwitchFlag()
  local n, taken = 1, {}
  for _, f in ipairs(self:roomFlags()) do taken[f] = true end
  while taken[("sw_%s_%d"):format(self.id, n)] do n = n + 1 end
  return ("sw_%s_%d"):format(self.id, n)
end

-- The crys_* rooms name these `crys_bus1`, `crys_bus2`... so the
-- generated form keeps the shape and adds the room, the same way
-- newSwitchFlag does. Anything already in the room counts as taken, so
-- placing a second node beside a hand-authored one cannot collide.
function S:newBeamFlag()
  local n, taken = 1, {}
  for _, f in ipairs(self:roomFlags()) do taken[f] = true end
  while taken[("bus_%s_%d"):format(self.id, n)] do n = n + 1 end
  return ("bus_%s_%d"):format(self.id, n)
end

-- `linkcore_c2` and `linkcore_fc` are how the two existing ones are
-- named, so the generated form keeps the prefix and adds the room.
function S:newLinkFlag()
  local n, taken = 1, {}
  for _, f in ipairs(self:roomFlags()) do taken[f] = true end
  while taken[("linkcore_%s_%d"):format(self.id, n)] do n = n + 1 end
  return ("linkcore_%s_%d"):format(self.id, n)
end

function S:ensureGateFlag(ch)
  self.gateFlag = self.gateFlag or {}
  if self.gateFlag[ch] then return end
  local fl = self:roomFlags()
  self.gateFlag[ch] = fl[1] or self:newSwitchFlag()
  self.dirty = true
end

-- P: cycle the number on the end of the selected prop's spec.
--
-- An emitter's wake time, a panel's stop count and a node's beam count
-- are all "the last number in the spec", and all three are things you
-- want to try three values of while looking at the room. Typing them
-- into a key table is how you get a panel with four stops on a rail
-- three tiles long.
--
-- It edits entSpec for the character that is ALREADY the brush, so the
-- change lands on every cell of that prop in the room at once -- which
-- is right: one character is one spec, and always was.
function S:cycleParam()
  local ch = self.primary
  local spec = self.entSpec and self.entSpec[ch]
  if not spec then
    self.status = "pick a prop that has a number on it first (')"
    return
  end
  local entry
  for _, e in ipairs(PROPS) do
    if e.spec and e.num and spec:find("^" .. e.spec:gsub("%d+$", ""):gsub("%p", "%%%0")) then
      entry = e break
    end
  end
  local head, n = spec:match("^(.-):(%d+)$")
  if not entry or not head then
    self.status = ("'%s' has no number to cycle"):format(spec)
    return
  end
  local lo, hi = entry.num[2], entry.num[3]
  n = tonumber(n) + 1
  if n > hi then n = lo end
  local nu = ("%s:%d"):format(head, n)
  -- charFor keys a spec to a character; rewriting in place keeps that
  -- 1:1 rather than stranding the old spec on a character nothing uses.
  self.entSpec[ch] = nu
  self.dirty = true
  self.widgets = self:layout()
  self.status = ("'%s' -> %s"):format(ch, nu)
end

-- L: bind the gate you are holding to the next flag in the room.
function S:cycleGateFlag()
  local ch = self.primary
  if not World.GATE_CHARS[ch] then
    self.status = "pick a GATE first (it is in the props list)"
    return
  end
  local fl = self:roomFlags()
  if #fl == 0 then
    self.status = "no flags in this room yet -- place a SWITCH first"
    return
  end
  local cur, at = self.gateFlag and self.gateFlag[ch], 0
  for i, f in ipairs(fl) do if f == cur then at = i end end
  self.gateFlag = self.gateFlag or {}
  self.gateFlag[ch] = fl[(at % #fl) + 1]
  self.dirty = true
  self.widgets = self:layout()
  self.status = "gate " .. ch .. "  opens on  " .. self.gateFlag[ch]
end

-- Y: how it looks doing it.
function S:cycleGateStyle()
  local ch = self.primary
  if not World.GATE_CHARS[ch] then
    self.status = "pick a GATE first"
    return
  end
  self.gateStyle = self.gateStyle or {}
  local cur, at = self.gateStyle[ch], 0
  for i, s in ipairs(GATE_STYLES) do if s == cur then at = i end end
  self.gateStyle[ch] = GATE_STYLES[(at % #GATE_STYLES) + 1]
  self.dirty = true
  self.widgets = self:layout()
  self.status = "gate " .. ch .. "  style  " .. self.gateStyle[ch]
end

-- ------------------------------------------------------------------
-- THE FINDER -- a searchable list, because thirty-four is too many
-- ------------------------------------------------------------------
-- Stepping through thirty-four enemies with an arrow is not choosing, it
-- is scrolling. Type two letters instead. love.textinput already reaches
-- the top state (core/state.lua), so this needs no plumbing -- only the
-- discipline to swallow keys while it is open, or the letters you type
-- to search also pick tools and paint tiles.
function S:openFinder()
  self.finder = { q = "", sel = 1 }
  love.keyboard.setKeyRepeat(true)
end

function S:closeFinder()
  self.finder = nil
  love.keyboard.setKeyRepeat(false)
end

-- BOTH catalogues, not just the enemies.
--
-- The beam props took the prop list from eleven entries to thirty-eight,
-- which is past the number you can step through with two arrows -- the
-- exact problem that made the enemy list need a search in the first
-- place. So the finder searches props too, and remembers which list a
-- hit came from so ENTER can set the right index.
--
-- Name as well as spec: "emitter left" finds `emitter:left` and
-- "slide" finds the horizontal panels, neither of which the spec alone
-- would match.
function S:finderHits()
  local q = (self.finder and self.finder.q or ""):lower()
  local out = {}
  local function sweep(list, which)
    for i, e in ipairs(list) do
      local hay = ((e.spec or e.tile or "") .. " " .. (e.name or "")):lower()
      if q == "" or hay:find(q, 1, true) then
        out[#out + 1] = { i = i, e = e, which = which }
      end
    end
  end
  sweep(PROPS, "prop")
  sweep(ENEMIES, "enemy")
  return out
end

function S:textinput(t)
  if self.attrs and self.attrs.pick then
    self.attrs.pick.q = self.attrs.pick.q .. t
    self.attrs.pick.sel = 1
    return
  end
  if not self.finder then return end
  if t == "/" then return end     -- "/" opened it; it is not a search term
  self.finder.q = self.finder.q .. t
  self.finder.sel = 1
end

-- Returns true when it swallowed the key.
function S:finderKey(k)
  if not self.finder then return false end
  local f, hits = self.finder, self:finderHits()
  if k == "escape" then self:closeFinder()
  elseif k == "backspace" then f.q = f.q:sub(1, -2) f.sel = 1
  elseif k == "down" then f.sel = math.min(math.max(1, #hits), f.sel + 1)
  elseif k == "up" then f.sel = math.max(1, f.sel - 1)
  elseif k == "return" or k == "kpenter" then
    local h = hits[f.sel]
    if h then
      if h.which == "prop" then self.propIdx = h.i else self.enemyIdx = h.i end
      self:closeFinder()
      self:pickEntity(h.which)
    end
  end
  return true
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

  -- TWO placeables, because props and enemies are different errands.
  local pr = PROPS[self.propIdx or 1] or PROPS[1]
  add { x = 4, y = 58, w = 12, h = 14, kind = "propstep", val = -1, label = "<",
        tip = "previous prop   ," }
  add { x = 18, y = 58, w = 132, h = 14, kind = "prop", label = pr.name,
        tip = pr.tip .. "   N makes it the brush; , and . step" }
  add { x = 152, y = 58, w = 12, h = 14, kind = "propstep", val = 1, label = ">",
        tip = "next prop   ." }

  local en = ENEMIES[self.enemyIdx or 1] or ENEMIES[1]
  add { x = 170, y = 58, w = 12, h = 14, kind = "enemystep", val = -1, label = "<",
        tip = "previous enemy" }
  add { x = 184, y = 58, w = 108, h = 14, kind = "enemy", label = en and en.name or "-",
        tip = (en and en.tip or "") .. "   J makes it the brush" }
  add { x = 294, y = 58, w = 12, h = 14, kind = "enemystep", val = 1, label = ">",
        tip = "next enemy" }
  add { x = 310, y = 58, w = 42, h = 14, kind = "action", val = "find",
        label = "FIND", tip = "search all " .. (#PROPS + #ENEMIES) ..
        " props and enemies by name or spec; type to filter   /" }

  -- ...and the gate controls, only while a gate is the brush
  if World.GATE_CHARS[self.primary] then
    local ch = self.primary
    add { x = 360, y = 58, w = 96, h = 14, kind = "action", val = "gflag",
          label = "ON " .. ((self.gateFlag or {})[ch] or "?"),
          tip = "which flag opens gate " .. ch ..
                ". Cycles the flags this room actually has -- place a "
                .. "SWITCH to make a new one.   L" }
    add { x = 458, y = 58, w = 84, h = 14, kind = "action", val = "gstyle",
          label = ((self.gateStyle or {})[ch] or "portcullis"):upper(),
          tip = "how gate " .. ch .. " moves when it opens.   ;" }
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
  if g.kind == "propstep" then return self:stepEntity(g.val, "prop") end
  if g.kind == "prop" then return self:pickEntity("prop") end
  if g.kind == "enemystep" then return self:stepEntity(g.val, "enemy") end
  if g.kind == "enemy" then return self:pickEntity("enemy") end
  if g.kind == "size" then
    self:resize(g.val, g.n)
  elseif g.kind == "tile" then
    self.primary = g.val
    self.status = "tile: " .. (PNAME[g.val] or g.val)
  elseif g.kind == "tool" then
    self.tool = g.val
    if g.val == "eraser" then self.primary = "." end
    self.status = "tool: " .. g.val
  elseif g.val == "find" then self:openFinder()
  elseif g.val == "fixmap" then self:askFixMap()
  elseif g.val == "newroom" then self:askNewRoom()
  elseif g.val == "gflag" then self:cycleGateFlag()
  elseif g.val == "gstyle" then self:cycleGateStyle()
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

-- The ONE thing that is not derived. Four options, because a door's side
-- is a property of the wall it is on and nothing else in the room can
-- tell you which wall you meant.
-- ------------------------------------------------------------------
-- THE ATLAS GOES STALE, AND THAT IS NOT A ROOM BUG
-- ------------------------------------------------------------------
-- `mapPos` is hand-typed and has to agree with the door graph, which
-- makes two sources of truth for one fact. Move a door and the atlas
-- does not know: checkmap starts failing with "X -- Y is a floor/ceiling
-- door but they are drawn N cells apart", and the room the message names
-- is fine. There is nothing to fix in it. The fix is somewhere else on
-- the map entirely, and finding it by hand means solving a packing
-- puzzle across 83 rooms.
--
-- maplayout.py already solves that puzzle. What was missing was any way
-- to REACH it from where the failure appears, and a guarantee that it
-- would not rewrite the room you have open -- so it takes `--pin`, and
-- this passes the room you are standing in. The solver may not move it
-- and does not open its file.
function S:askFixMap()
  if self.job then self.status = "checks still running -- wait for them" return end
  if self.dirty then
    self.status = "save this room first (ctrl+S), then ctrl+M -- the solver "
      .. "reads the rooms off disk"
    return
  end
  self:ask(("Re-solve the world atlas? %s stays where it is; other rooms "
    .. "may be moved on the MAP (never in the game)."):format(self.id), {
    { key = "return", label = "SOLVE", fn = function() self:fixMap() end },
    { key = "escape", label = "CANCEL", fn = function() end },
  })
end

function S:fixMap()
  local root = RoomIO.root()
  if root == "" then root = "." end
  local cmd = "cd '" .. root:gsub("'", "'\\''") .. "' && "
    .. "PYTHONPATH=../scripts python3 ../scripts/maplayout.py --solve --write "
    .. "--pin " .. self.id .. " --iters 200000 --restarts 3"
  self:runJob({ "atlas\t" .. cmd,
                "checkmap\tcd '" .. root:gsub("'", "'\\''") .. "' && "
                .. "PYTHONPATH=../scripts python3 ../scripts/checkmap.py" },
              "solving the atlas", function()
    -- every room's def and the zone offsets have all just changed on
    -- disk; anything still cached is a lie
    for _, id in ipairs(require("src.data.worldmap").ROOMS or {}) do
      RoomIO.invalidate(id)
    end
    package.loaded["src.data.worldmap"] = nil
    self:loadFromDisk(true)
  end)
end

function S:askNewRoom()
  if not self.rows then return end
  if self.dirty then
    self.status = "save this room first (ctrl+S), then ctrl+N"
    return
  end
  local id = self:freeRoomId() or "?"
  self:ask(("New room %s through a new door on which wall of %s?")
    :format(id, self.id), {
    { key = "left",   label = "LEFT",   fn = function() self:newRoom("left") end },
    { key = "right",  label = "RIGHT",  fn = function() self:newRoom("right") end },
    { key = "up",     label = "TOP",    fn = function() self:newRoom("top") end },
    { key = "down",   label = "BOTTOM", fn = function() self:newRoom("bottom") end },
    { key = "escape", label = "CANCEL", fn = function() end },
  })
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
          -- the PENDING flag first: the legend is what you read to check
          -- a binding you just made, and reading it off disk showed the
          -- old one until you saved.
          what = "GATE, solid until " ..
                 tostring((self.gateFlag or {})[ch]
                          or (def.gates and def.gates[ch]) or "?")
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
  if self.attrs then
    if btn == 1 then self:attrsClick(ux, uy) end
    return                       -- a modal that lets clicks through is not one
  end
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
    -- SEL is now two gestures on one tool, disambiguated by the mouse
    -- rather than by a mode: DRAG makes a selection, CLICK inspects
    -- whatever is under the cursor. Nothing had to be given up for it --
    -- a zero-tile marquee was never a useful selection.
    if btn == 1 then
      self.sel = { x0 = tx, y0 = ty, x1 = tx, y1 = ty }
      self.dragging = true
      self.selFrom = { tx, ty }
    end
    return
  end
  if self.tool == "rect" and btn == 1 then
    self.rectFrom = { tx, ty }; return
  end
  self:snapshot()
  self.painting = btn
  self:paintAt(btn == 2 and self.secondary or self.primary)
end

-- A field row clicked in the attributes panel.
function S:attrsClick(ux, uy)
  local a = self.attrs
  if a.pick then
    for i, r in ipairs(a.pick.rects or {}) do
      if ux >= r.x and ux < r.x + r.w and uy >= r.y and uy < r.y + r.h then
        local hits = self:flagPickHits()
        if hits[i] then self:applyFlag(hits[i].flag) end
        return
      end
    end
    return
  end
  for i, r in ipairs(a.rects or {}) do
    if ux >= r.x and ux < r.x + r.w and uy >= r.y and uy < r.y + r.h then
      a.sel = i
      local f = a.fields[i]
      -- the two arrow boxes on the right of the row, then the row itself
      if f.pick then self:openFlagPick()
      elseif f.step then f.step(ux > r.x + r.w - 16 and 1 or -1) end
      return
    end
  end
  if a.closeRect then
    local r = a.closeRect
    if ux >= r.x and ux < r.x + r.w and uy >= r.y and uy < r.y + r.h then
      self:closeAttrs()
    end
  end
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
  if self.help then self.helpTop = (self.helpTop or 0) - dy end
end

function S:mousereleased(mx, my, btn)
  if self.tool == "marquee" and btn == 1 and self.selFrom and self.sel then
    local sx, sy = self.selFrom[1], self.selFrom[2]
    self.selFrom = nil
    if self.sel.x0 == self.sel.x1 and self.sel.y0 == self.sel.y1 then
      self.sel = nil
      self.dragging = false
      self:openAttrs(sx, sy)
      return
    end
  end
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
    elseif k == "n" then self:askNewRoom()
    elseif k == "m" then self:askFixMap()
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

  -- the attributes panel and the finder each eat everything while open
  if self.attrs then self:attrsKey(k) return end
  if self.finder then self:finderKey(k) return end

  if love.keyboard.isDown("lalt", "ralt") then
    local edge = ({ left = "left", right = "right", up = "top", down = "bottom" })[k]
    if edge then self:resize(edge, shift and -1 or 1) return end
  end

  -- the help card scrolls, and it eats the keys while it is open so the
  -- arrows do not also drive the map behind it
  if self.help then
    if k == "up" then self.helpTop = (self.helpTop or 0) - 1 return end
    if k == "down" then self.helpTop = (self.helpTop or 0) + 1 return end
    if k == "pageup" then self.helpTop = (self.helpTop or 0) - 8 return end
    if k == "pagedown" then self.helpTop = (self.helpTop or 0) + 8 return end
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
  elseif k == "tab" then self.help = not self.help; self.helpTop = 0
  elseif k == "f" then self:frameRoom()
  elseif k == "k" then self.showLegend = not self.showLegend
  elseif k == "n" then self:pickEntity("prop")
  elseif k == "j" then self:pickEntity("enemy")
  -- L and ';', NOT 'f' and 'y'. The gate-flag branch used to be a second
  -- `k == "f"` BELOW the one that frames the room, so it could never run
  -- -- and both widget tips have been promising L and ';' the whole
  -- time. The tips were right and the bindings were wrong.
  elseif k == "l" then self:cycleGateFlag()
  elseif k == ";" then self:cycleGateStyle()
  -- "'" and not "P": §8 of MAPEDITOR-PLAN reserves P for the room
  -- switcher, which is not built yet, and taking a key a plan has
  -- already spent is how you get two features fighting over one press
  -- six months later. It also puts the three "change a setting on the
  -- thing you are holding" keys side by side: L flag, ; style, ' number.
  elseif k == "'" then self:cycleParam()
  elseif k == "/" then self:openFinder()
  elseif k == "," or k == "." then
    self:stepEntity(k == "." and 1 or -1, "prop")
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

-- IS SOMETHING ON SCREEN HOLDING THE KEYBOARD?
--
-- One list, so the next panel that owns keys is one entry rather than a
-- second place to forget. Everything here routes keypressed to itself
-- and returns; the help card does not, and panning behind it is
-- harmless because you cannot see the map anyway.
function S:modal()
  -- the help card is in the list now: it scrolls with the arrows, so
  -- leaving it out would pan the map behind it exactly the way the
  -- finder used to.
  return (self.finder or self.attrs or self.confirm or self.failures
          or self.help) and true or false
end

function S:update(dt)
  self:pollChecks()
  -- one re-derive per frame, however many tiles were painted into it
  if self.needParse then
    self.needParse = nil
    self:rebuildWorld(0, 0)
  end
  -- PANNING READS HELD KEYS, SO A MODAL HAS TO SWITCH IT OFF.
  --
  -- keypressed routes to whatever is open -- the finder eats the key and
  -- returns -- but this loop never asked, so with the FIND list up the
  -- arrows moved the selection AND scrolled the map underneath it at the
  -- same time. The `not self.stamp` guard below is the same idea, made
  -- once and never extended.
  --
  -- And it is not only the arrows: WASD pans too, so typing a filter
  -- containing w, a, s or d flew the camera across the room while you
  -- searched. "slag" and "wasp" both do it. That half is invisible until
  -- you happen to search for the wrong word, which is why the guard is
  -- on the whole block rather than on the arrow keys.
  local sp = love.keyboard.isDown("lshift", "rshift") and 12 or 5
  local arrows = not self.stamp        -- arrows nudge the stamp instead
  if not self:modal() then
    if love.keyboard.isDown("a") or (arrows and love.keyboard.isDown("left")) then
      Cam.x = Cam.x - sp end
    if love.keyboard.isDown("d") or (arrows and love.keyboard.isDown("right")) then
      Cam.x = Cam.x + sp end
    if love.keyboard.isDown("w") or (arrows and love.keyboard.isDown("up")) then
      Cam.y = Cam.y - sp end
    if love.keyboard.isDown("s") or (arrows and love.keyboard.isDown("down")) then
      Cam.y = Cam.y + sp end
  end
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
  -- THE STATUS GETS ITS OWN BOX, ABOVE THE BOTTOM BAR.
  --
  -- It used to be a right-aligned printf across the SAME ROW as the
  -- brush readout, at full canvas width. Every status longer than a few
  -- words printed straight over "[a] BEAM NODE   BRUSH", and anything
  -- past one line wrapped down onto "matches disk" and the room info as
  -- well -- three strings in the same pixels. The messages this editor
  -- now produces are sentences ("moss_6 created to the right -- ..."),
  -- so that stopped being an edge case.
  --
  -- Boxed, wrapped, right-hand half of the screen, and it grows UPWARD
  -- so the bottom bar keeps its two rows whatever the status says.
  if self.status and self.status ~= "" then
    local sw = math.floor(G.SW * 0.62)
    local sx = G.SW - sw - 4
    local _, sl = G.fonts.main:getWrap(self.status, sw - 10)
    local n = math.min(#sl, STATUS_LINES)
    local sh = n * 10 + 6
    local sy = G.SH - 26 - sh
    box(sx, sy, sw, sh, 0.80)
    g.setColor(P.slate) g.rectangle("line", sx + 0.5, sy + 0.5, sw - 1, sh - 1)
    g.setColor(P.silver)
    for i = 1, n do
      local line = sl[i]
      -- ...and it never runs on: past the cap the last line is elided,
      -- because a status box that can grow to eight lines is a status
      -- box that covers the room you are editing.
      if i == STATUS_LINES and #sl > STATUS_LINES then line = line .. " ..." end
      g.print(line, sx + 5, sy + 3 + (i - 1) * 10)
    end
  end
  g.setColor(P.slate)
  g.printf(("%s  %dx%d  cursor %d,%d   TAB help   F frame"):format(
    self.id, self:w(), self:h(), tx, ty), 0, G.SH - 12, G.SW - 6, "right")

  if self.failures then self:drawFailures() end
  if self.showLegend then
    -- CENTRED VERTICALLY WAS THE BUG. A room with a dozen keyed
    -- characters made the panel tall enough that centring pushed its
    -- title up under the placeable row, so the legend and the widget
    -- labels shared pixels. It lives BETWEEN the chrome and the bottom
    -- bar now, and if it does not fit it says how much it dropped
    -- rather than growing into them.
    local lines = self:legend()
    local top, bottom = CHROME_H + 18, G.SH - 28
    local room = bottom - top
    local shown = math.max(0, math.min(#lines, math.floor((room - 14) / 10)))
    local more = #lines - shown
    local hgt = math.max(24, shown * 10 + 14 + (more > 0 and 10 or 0))
    local y = math.floor(top + (room - hgt) / 2)
    box(40, y, G.SW - 80, hgt, 0.93)
    g.setColor(P.cyan) g.rectangle("line", 40.5, y + 0.5, G.SW - 81, hgt - 1)
    g.setColor(P.ember)
    g.print("WHAT THE LETTERS IN THIS ROOM MEAN            K closes", 48, y + 4)
    g.setColor(P.cream)
    for i = 1, shown do g.print(lines[i], 48, y + 4 + i * 10) end
    if more > 0 then
      g.setColor(P.slate)
      g.print(("...and %d more -- the room is taller than this panel"):format(more),
        48, y + 4 + (shown + 1) * 10)
    end
    if #lines == 0 then
      g.setColor(P.slate) g.print("nothing but terrain in here", 48, y + 14)
    end
  end

  self:drawProgress()
  self:drawTooltip()
  self:drawAttrs()
  self:drawFinder()
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

-- Declared HERE rather than beside the rest of the finder: `box` is a
-- file local and a Lua local does not exist above its own declaration.
-- Calling it earlier compiles perfectly well and then resolves to a nil
-- global at runtime, which luac -p cannot see. load_test has a LATELOCAL
-- lint because this project has already paid for that once.
-- THE ATTRIBUTES PANEL.
--
-- Sized to the canvas, not to the content: 480x270 is not much, so the
-- panel takes a fixed column between the chrome and the bottom bar and
-- every string inside it is wrapped to the box rather than trusted to
-- fit. That is the whole reason the old chrome was unreadable -- long
-- text printed at a fixed spot and whatever was already there lost.
function S:drawAttrs()
  local a = self.attrs
  if not a then return end
  local g = love.graphics
  -- CHROME_H is the top BAR, and the placeable row hangs BELOW it at
  -- y=58..72. Starting the panel at CHROME_H + 6 put its title straight
  -- through "> FIND", which is the same class of bug as the status line.
  local w = 300
  local x = math.floor((G.SW - w) / 2)
  local top = CHROME_H + 20
  local rows = #a.fields
  local h = 26 + rows * 22 + 22
  local y = math.max(top, math.min(top, G.SH - 30 - h))
  box(x, y, w, h, 0.95)
  g.setColor(P.cyan) g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)

  g.setColor(P.ember)
  local title = ("%s  '%s'"):format(a.obj.kind:upper(), a.obj.ch)
  g.print(title, x + 8, y + 6)
  g.setColor(P.slate)
  g.printf("ESC closes", x, y + 6, w - 8, "right")
  a.closeRect = { x = x + w - 66, y = y + 4, w = 60, h = 12 }

  -- ONE MODAL AT A TIME. The flag chooser used to float over the field
  -- rows, so the room's flag names printed through the field names and
  -- the help text. It takes the panel's own body instead.
  if a.pick then
    self:drawFlagPick(x, y, w, h)
    g.setColor(1, 1, 1, 1)
    return
  end

  a.rects = {}
  for i, f in ipairs(a.fields) do
    local ry = y + 22 + (i - 1) * 22
    local on = (i == a.sel)
    a.rects[i] = { x = x + 6, y = ry, w = w - 12, h = 20 }
    if on then
      g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.16)
      g.rectangle("fill", x + 6, ry, w - 12, 20)
    end
    g.setColor(on and P.cream or P.slate)
    g.print(f.name, x + 12, ry + 2)
    g.setColor(on and P.gold or P.silver)
    -- the VALUE is the long one, so it wraps inside the row's own width
    local vw = w - 24
    local _, vl = G.fonts.main:getWrap(tostring(f.get()), vw)
    g.print(vl[1] .. (#vl > 1 and "..." or ""), x + 12, ry + 11)
    if f.step then
      g.setColor(on and P.cyan or P.slate)
      g.print("<", x + w - 30, ry + 6)
      g.print(">", x + w - 16, ry + 6)
    elseif f.pick then
      g.setColor(on and P.cyan or P.slate)
      g.print("PICK", x + w - 36, ry + 6)
    end
  end

  -- one line of help for the selected field, wrapped, at the foot
  local f = a.fields[a.sel]
  if f and f.tip then
    g.setColor(P.slate)
    local _, tl = G.fonts.main:getWrap(f.tip, w - 16)
    for i = 1, math.min(#tl, 2) do
      g.print(tl[i] .. (i == 2 and #tl > 2 and " ..." or ""),
        x + 8, y + h - 20 + (i - 1) * 9)
    end
  end

  g.setColor(1, 1, 1, 1)
end

function S:drawFlagPick(px, py, pw, ph)
  local a = self.attrs
  local g = love.graphics
  local hits = self:flagPickHits()
  -- inside the panel that opened it, so nothing is drawn over anything
  local x, y = px + 6, py + 20
  local w = pw - 12
  local rows = math.max(1, math.min(#hits, math.floor((ph - 46) / 11)))
  local h = 26 + rows * 11
  g.setColor(P.gold) g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  g.setColor(P.ember) g.print("FLAG", x + 6, y + 4)
  g.setColor(P.cream)
  g.print(a.pick.q .. (math.floor(G.time * 2) % 2 == 0 and "_" or ""),
    x + 44, y + 4)
  a.pick.rects = {}
  for i = 1, rows do
    local hit = hits[i]
    local ry = y + 16 + (i - 1) * 11
    a.pick.rects[i] = { x = x + 3, y = ry, w = w - 6, h = 11 }
    if hit then
      if i == a.pick.sel then
        g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.28)
        g.rectangle("fill", x + 3, ry, w - 6, 11)
      end
      g.setColor(i == a.pick.sel and P.cream or P.silver)
      g.print(hit.flag, x + 7, ry + 1)
      g.setColor(P.slate)
      g.printf(hit.group, x, ry + 1, w - 8, "right")
    end
  end
  g.setColor(P.slate)
  g.print(("%d   ENTER takes it, N invents a new one"):format(#hits),
    x + 6, y + h - 11)
  g.setColor(1, 1, 1, 1)
end

function S:drawFinder()
  local f = self.finder
  if not f then return end
  local g = love.graphics
  local hits = self:finderHits()
  local rows = math.max(1, math.min(#hits, 12))
  local w, h = 190, 28 + rows * 10
  local x, y = 150, 74
  box(x, y, w, h, 0.95)
  g.setColor(P.ember)
  g.print("FIND", x + 6, y + 5)
  g.setColor(P.cream)
  g.print(f.q .. (math.floor(G.time * 2) % 2 == 0 and "_" or ""), x + 82, y + 5)
  for i = 1, rows do
    local hit = hits[i]
    if hit then
      if i == f.sel then
        g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.30)
        g.rectangle("fill", x + 3, y + 17 + (i - 1) * 10, w - 6, 10)
      end
      g.setColor(i == f.sel and P.cream or P.slate)
      -- a door or a gate has no spec, only a character
      g.print(hit.e.spec or hit.e.name, x + 8, y + 18 + (i - 1) * 10)
    end
  end
  g.setColor(P.slate)
  g.print(#hits .. "/" .. (#PROPS + #ENEMIES) .. "   ENTER picks, ESC closes",
    x + 6, y + h - 11)
  g.setColor(1, 1, 1, 1)
end

function S:drawHelp()
  -- THE CARD WAS TALLER THAN THE SCREEN.
  --
  -- box(24, 26, ..., 286) on a 270px canvas, holding 395px of wrapped
  -- text -- so it covered the whole screen, ran off the bottom, and its
  -- own "TAB closes this" line was drawn at y=300 where nothing can see
  -- it. The editor opens this by itself on first entry, so that black
  -- rectangle was the first thing the editor ever showed.
  --
  -- It was never swept because the UI harness turned it off in order to
  -- see the screen behind it, so every line added to it this session
  -- went unmeasured. It scrolls now, it is clamped to the canvas, and
  -- editorui_test sweeps it open.
  local g = love.graphics
  local lines = HELP_LINES
  -- FULL SCREEN, edge to edge. Inset, it left a strip of the toolbar
  -- showing down each side -- half a widget label peeking out from
  -- behind a help card, which reads as a rendering fault rather than as
  -- a panel. A modal that does not cover what it sits on is the bug.
  local x, y = 0, 0
  local w, h = G.SW, G.SH
  local rows = math.floor((h - 26) / 9)
  local maxTop = math.max(0, #lines - rows)
  self.helpTop = math.max(0, math.min(self.helpTop or 0, maxTop))
  box(x, y, w, h, 0.94)
  g.setColor(P.cyan) g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  g.setColor(P.ember)
  g.print("ROOM EDITOR", x + 8, y + 5)
  g.setColor(P.cream)
  for i = 1, rows do
    local ln = lines[self.helpTop + i]
    if ln then g.print(ln, x + 8, y + 17 + (i - 1) * 9) end
  end
  g.setColor(P.slate)
  local foot = (maxTop > 0)
    and ("%d-%d of %d   UP/DOWN or wheel scrolls   TAB or ESC closes")
        :format(self.helpTop + 1, math.min(#lines, self.helpTop + rows), #lines)
    or "TAB or ESC closes this"
  g.print(foot, x + 8, y + h - 11)
  g.setColor(1, 1, 1, 1)
end

return S
