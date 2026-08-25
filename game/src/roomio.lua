-- ==================================================================
-- ROOM FILE SURGERY
-- ==================================================================
-- The save layer under the room editor, and deliberately the first thing
-- built, because every part of the editor is a UI on top of it and this
-- is where the risk actually lives.
--
-- THE RULE: writes are SURGICAL. This module replaces exactly the bytes
-- it means to and leaves every other byte in the file alone.
--
-- It would be far easier to parse a room into a table and serialise it
-- back. It would also destroy every comment in the file, and the comments
-- in this project are load-bearing -- they carry the reasons, and the
-- reasons are the part that keeps getting relearned expensively.
--
-- Surgery has a second payoff that matters more over time: it does not
-- care where a file came from. A room typed by hand and a room emitted by
-- genscrap.py go through exactly the same path, which is the whole
-- premise of "generate, then refine".
--
-- PURE LUA. No love.* anywhere in this file, on purpose: it runs headless
-- under plain lua5.3 for the round-trip test as happily as it runs inside
-- the game.
-- ==================================================================
local RoomIO = {}

RoomIO.DIR = "src/data/rooms/"
RoomIO.BACKUP = "../_backups/"

-- ------------------------------------------------------------------
-- WHERE THE FILES ARE
-- ------------------------------------------------------------------
-- io.open resolves against the PROCESS working directory, which is
-- wherever `love` happened to be invoked from -- not the game folder.
-- Every path here used to be relative, so the whole save layer worked
-- only when the game was started with `love .` from game/ and failed
-- with "no such room" from anywhere else. The editor then reported
-- "NO ROOM LOADED", which is true and says nothing about why.
--
-- love.filesystem.getSource() is the game directory whatever the cwd is.
-- Guarded so this file stays plain Lua with no love.* dependency: the
-- roomio scenario and the identity sweep both run it outside LOVE.
RoomIO.ROOT = nil

function RoomIO.root()
  if RoomIO.ROOT then return RoomIO.ROOT end
  local ok, src = pcall(function()
    return love and love.filesystem and love.filesystem.getSource
       and love.filesystem.getSource()
  end)
  if ok and type(src) == "string" and src ~= "" and not src:match("%.love$") then
    RoomIO.ROOT = src .. "/"
  else
    RoomIO.ROOT = ""            -- no LOVE, or a fused archive: use the cwd
  end
  return RoomIO.ROOT
end

function RoomIO.path(id) return RoomIO.root() .. RoomIO.DIR .. id .. ".lua" end

function RoomIO.readRaw(id)
  local path = RoomIO.path(id)
  local f = io.open(path, "r")
  if f then
    local s = f:read("*a")
    f:close()
    return s
  end
  -- Belt and braces: love.filesystem is mounted at the game source
  -- whatever io.open thinks the working directory is. Reading has to
  -- work for the editor to open at all, so it gets the second chance.
  -- Writing deliberately does not -- love.filesystem writes land in the
  -- save directory, which is emphatically not the room file.
  local ok, s = pcall(function()
    return love and love.filesystem and love.filesystem.read
       and love.filesystem.read(RoomIO.DIR .. id .. ".lua")
  end)
  if ok and type(s) == "string" and #s > 0 then return s end
  return nil, "cannot open " .. path
end

-- Byte span of the GRID TEXT inside `map = [[ ... ]]`, exclusive of the
-- delimiters. Returned as an inclusive (first, last) pair so that
--     src:sub(1, first - 1) .. body .. src:sub(last + 1)
-- reassembles the file exactly.
function RoomIO.mapSpan(src)
  local _, afterOpen = src:find("map%s*=%s*%[%[\n")
  if not afterOpen then return nil, "no map block" end
  local close = src:find("%]%]", afterOpen + 1)
  if not close then return nil, "unterminated map block" end
  return afterOpen + 1, close - 1
end

-- Grid text <-> rows.
--
-- TWO CONVENTIONS EXIST IN THE WILD and the identity test found the
-- second one on its first full run: 82 of 83 rooms end their map block
-- with a newline before `]]`, and camp_hut ends `...####]]` with none.
--
-- The first version of this required a trailing newline on every row, so
-- camp_hut's last row simply vanished -- thirty bytes, which is exactly
-- its width. A room silently one row shorter is about the worst thing a
-- save layer can do, and no validator would have caught it: the result
-- is still a rectangle, still parses, still loads.
--
-- So the terminator is PRESERVED, not normalised. An editor that quietly
-- reformats files is an editor whose diffs nobody can read, and "make
-- them all consistent" is a decision for fixrooms.py to offer and for
-- Thomas to take -- not something a save should do behind his back.
function RoomIO.gridToRows(body)
  local rows = {}
  -- append a sentinel newline so a final row without one is still seen,
  -- then drop the empty row it creates when the body already had one
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do rows[#rows + 1] = line end
  if body:sub(-1) == "\n" then rows[#rows] = nil end
  return rows
end

function RoomIO.rowsToGrid(rows, trailingNewline)
  local s = table.concat(rows, "\n")
  if trailingNewline then s = s .. "\n" end
  return s
end

function RoomIO.readRows(id)
  local src, err = RoomIO.readRaw(id)
  if not src then return nil, err end
  local a, b = RoomIO.mapSpan(src)
  if not a then return nil, b end
  return RoomIO.gridToRows(src:sub(a, b)), src
end

-- Every row the same width, always. A one-character drift produces a
-- room that still parses and is nonsense, and it is invisible in a diff
-- unless you are looking for it.
function RoomIO.checkRect(rows)
  if #rows == 0 then return nil, "empty grid" end
  local w = #rows[1]
  for i = 2, #rows do
    if #rows[i] ~= w then
      return nil, ("row %d is %d wide, row 1 is %d"):format(i, #rows[i], w)
    end
  end
  return w, #rows
end

function RoomIO.backup(id, src)
  local dir = RoomIO.root() .. RoomIO.BACKUP
  os.execute('mkdir -p "' .. dir .. '"')
  local stamp = os.date("%Y%m%d-%H%M%S")
  local p = dir .. id .. "." .. stamp .. ".lua"
  local f = io.open(p, "w")
  if not f then return nil, "cannot write backup " .. p end
  f:write(src)
  f:close()
  return p
end

-- ------------------------------------------------------------------
-- SHIFTING A ROOM'S ORIGIN
-- ------------------------------------------------------------------
-- Growing a room on its RIGHT or BOTTOM edge costs nothing: every
-- coordinate in the file keeps meaning what it meant. Growing on the
-- LEFT or TOP moves the origin, and everything in the file that is
-- written in absolute world pixels -- the backdrop, scenery and
-- foreground art layers, and the light positions -- stays where it was
-- while the terrain slides out from under it.
--
-- Ten rooms have those layers and they are the most heavily commented
-- files in the tree, so this bumps the NUMBERS IN PLACE rather than
-- parsing the tables and writing them back out. A save that silently
-- reformats a file is a save whose diff nobody can read.

-- The `{ ... }` byte span of a top-level field, brace-matched with the
-- string and comment rules Lua actually has -- `col = "black"` and a
-- prose comment must not be able to close a table.
function RoomIO.fieldSpan(src, name)
  local a = src:find("\n%s*" .. name .. "%s*=%s*{")
  if not a then return nil end
  a = src:find("{", a)
  local depth, i, n = 0, a, #src
  local quote = nil
  while i <= n do
    local c = src:sub(i, i)
    if quote then
      if c == "\\" then i = i + 1
      elseif c == quote then quote = nil end
    elseif c == '"' or c == "'" then
      quote = c
    elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
      local nl = src:find("\n", i) or (n + 1)
      i = nl - 1
    elseif c == "{" then depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then return a, i end
    end
    i = i + 1
  end
  return nil, "unbalanced braces in " .. name
end

local function num(v)
  if v == math.floor(v) then return ("%d"):format(v) end
  return (("%.4f"):format(v):gsub("0+$", ""):gsub("%.$", ""))
end

-- One line of a table body, with its comment held aside so a sentence
-- that happens to contain "x = 4" cannot be edited.
local function shiftLine(line, dx, dy)
  local quote, cut = nil, nil
  for i = 1, #line do
    local c = line:sub(i, i)
    if quote then
      if c == "\\" then
      elseif c == quote then quote = nil end
    elseif c == '"' or c == "'" then quote = c
    elseif c == "-" and line:sub(i + 1, i + 1) == "-" then cut = i break
    end
  end
  local code = cut and line:sub(1, cut - 1) or line
  local rest = cut and line:sub(cut) or ""
  local function bump(d)
    return function(pre, v)
      return pre .. num(tonumber(v) + d)
    end
  end
  code = code:gsub("([%s{,]x%s*=%s*)(%-?%d+%.?%d*)", bump(dx))
  code = code:gsub("([%s{,]y%s*=%s*)(%-?%d+%.?%d*)", bump(dy))
  return code .. rest
end

RoomIO.SHIFTABLE = { "backdrop", "scenery", "foreground", "lights" }

-- Returns the new source, and how many fields it touched.
function RoomIO.shiftArt(src, dx, dy)
  if dx == 0 and dy == 0 then return src, 0 end
  local hits = 0
  for _, name in ipairs(RoomIO.SHIFTABLE) do
    local a, b = RoomIO.fieldSpan(src, name)
    if a and type(b) == "number" then
      local body = src:sub(a, b)
      local out = {}
      for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = shiftLine(line, dx, dy)
      end
      -- gmatch with the sentinel newline yields one extra empty row
      if out[#out] == "" then table.remove(out) end
      src = src:sub(1, a - 1) .. table.concat(out, "\n") .. src:sub(b + 1)
      hits = hits + 1
    end
  end
  return src, hits
end

-- ------------------------------------------------------------------
-- THE KEY TABLE
-- ------------------------------------------------------------------
-- Placing an entity is TWO edits -- a character in the grid and a line in
-- `key` -- and they are not independently valid. World:load errors out on
-- "unmapped map char" the instant it meets a character with no entry, so
-- a file that has one and not the other does not load at all. They ride
-- on one write for exactly the reason the origin shift does: two writes
-- mean two backups and a window in which the room on disk is broken.
--
-- Surgical, like everything else here. It rewrites the lines it means to
-- and leaves the rest of the table -- including its comments, and three
-- rooms have them -- exactly as it found them.
--
-- entries: { ["a"] = "cell" }  sets or replaces
--          { ["a"] = false }   removes
-- `key`, `gates` and `gateStyle` are the same shape -- a table of
-- one-character string keys mapping to strings -- and therefore the same
-- surgery. Writing it three times would be three chances to fix a bug
-- twice.
--
--   key       ["x"] = "plate:sw_moss_1"     what a map char spawns
--   gates     G = "sw_moss_1"               which flag opens a gate
--   gateStyle G = "portcullis"              how it looks doing it
--
-- The gates tables are written `G = "flag"` rather than `["G"] = "flag"`,
-- so both forms are read and each key is rewritten in the form the file
-- already used. An editor that reformats a table nobody asked it to
-- touch is an editor whose diffs stop being readable.
-- AN ENTRY'S VALUE, RENDERED.
--
-- `key`, `gates` and `gateStyle` all map a character to a STRING, and
-- this module was written on that assumption -- `type(want) == "string"`
-- guarded every branch, so a table value was silently treated as "leave
-- this entry alone". `links` maps a character to a TABLE, which is why
-- a door painted in the editor went to disk with no destination and
-- checkdoors caught it as NOLINK.
local function entryValue(v)
  if type(v) == "string" then return ('"%s"'):format(v) end
  -- a link: { "room", "B" }, optionally with a req that seals it
  local parts = {}
  for i = 1, #v do parts[#parts + 1] = ('"%s"'):format(tostring(v[i])) end
  -- `req` LAST, which is where every hand-written one already sits
  if v.req then parts[#parts + 1] = ('req = "%s"'):format(v.req) end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Is this something to write, as opposed to `false` (delete) or nil?
local function isValue(v)
  return type(v) == "string" or type(v) == "table"
end

function RoomIO.setKeyEntries(src, entries)
  return RoomIO.setTableEntries(src, "key", entries)
end

function RoomIO.setTableEntries(src, field, entries)
  if not entries or not next(entries) then return src end
  local a, b = RoomIO.fieldSpan(src, field)
  if not a then
    -- THE TABLE MAY NOT EXIST YET. Most rooms have no `gateStyle` at
    -- all, and "this room has never had one" is not a reason to refuse
    -- to give it one -- it was the reason four rooms out of five came
    -- back as WRITE REFUSED the first time the editor tried to set a
    -- gate's style.
    --
    -- Nothing to add means nothing to do; a removal on a table that is
    -- not there is already true.
    local add = {}
    for ch, spec in pairs(entries) do
      if isValue(spec) then add[#add + 1] = ch end
    end
    if #add == 0 then return src end
    table.sort(add)
    local parts = {}
    for _, ch in ipairs(add) do
      parts[#parts + 1] = (field == "key")
        and ('["%s"] = %s'):format(ch, entryValue(entries[ch]))
        or  ('%s = %s'):format(ch, entryValue(entries[ch]))
    end
    -- in front of the map block, which every room has
    local at = src:find("\n%s*map%s*=%s*%[%[")
    if not at then return nil, "no map block to put " .. field .. " before" end
    local line
    if field == "links" or field == "key" then
      -- stacked, because that is how all 83 rooms write both
      line = ("\n  %s = {\n    %s,\n  },"):format(field, table.concat(parts, ",\n    "))
    else
      line = ("\n  %s = { %s },"):format(field, table.concat(parts, ", "))
    end
    return src:sub(1, at - 1) .. line .. src:sub(at)
  end
  if type(b) ~= "number" then return nil, tostring(b) end

  local origInner = src:sub(a + 1, b - 1)

  -- SPLIT INTO ENTRIES, NOT LINES.
  --
  -- `key` is written one entry per line; `gates` is written on ONE line,
  -- sometimes with two entries on it -- `gates = { G = "x", H = "y" }`.
  -- A line-based pass reads that as a single line, matches the first
  -- entry and silently drops the second. The round-trip caught it on
  -- crys_2 as a file that no longer parsed, which is the good version of
  -- that bug; the bad version is a gate quietly disappearing.
  --
  -- So: walk the interior, cut it at commas that are not inside a string
  -- or a nested table, and treat each piece as one entry.
  local pieces, depth, quote, from = {}, 0, nil, 1
  local i, n = 1, #origInner
  while i <= n do
    local c = origInner:sub(i, i)
    if quote then
      if c == "\\" then i = i + 1 elseif c == quote then quote = nil end
    elseif c == '"' or c == "'" then quote = c
    elseif c == "-" and origInner:sub(i + 1, i + 1) == "-" then
      i = (origInner:find("\n", i) or (n + 1)) - 1
    elseif c == "{" then depth = depth + 1
    elseif c == "}" then depth = depth - 1
    elseif c == "," and depth == 0 then
      pieces[#pieces + 1] = origInner:sub(from, i - 1)
      from = i + 1
    end
    i = i + 1
  end
  pieces[#pieces + 1] = origInner:sub(from)

  -- Was it written across lines, and with what indent?
  local multi = origInner:find("\n") ~= nil
  local indent = origInner:match("\n(%s*)%S") or "    "
  local tail = origInner:match("\n(%s*)$") or "  "

  local seen, out, hadEntries, bare = {}, {}, false, false
  for _, piece in ipairs(pieces) do
    -- A COMMENT ABOVE AN ENTRY BELONGS TO THAT ENTRY'S PIECE.
    --
    -- The split is on top-level commas, so everything written above an
    -- entry -- blank separator lines AND comment lines -- arrives at the
    -- head of its piece. The first version only peeled BLANKS, then
    -- tested the whole piece for an entry pattern anchored at its start,
    -- found none because the piece began with `--`, and emitted the
    -- comment and the entry together as unterminated text. That drops
    -- the comma after the entry, and the file no longer parses.
    --
    -- `stair_junction`, `ug_secret` and `sky_boss` are all written that
    -- way, and none of them was caught, because setTableEntries returns
    -- early on an empty edit -- so the identity sweep that ran over
    -- every room never entered this loop at all. The sweep now rewrites
    -- every entry to its own current value, which does.
    --
    -- The first newline is the one that ENDED the previous entry, not a
    -- blank line, so it comes off before anything is counted.
    local body = (piece:gsub("^\n", "", 1))
    local pre = {}
    while true do
      local first, rest = body:match("^([^\n]*)\n(.*)$")
      if not first then break end
      local t = first:match("^%s*(.-)%s*$")
      if t == "" or t:sub(1, 2) == "--" then
        pre[#pre + 1] = t
        body = rest
      else
        break
      end
    end
    -- ["G"] = "..."   or   G = "..."   -- ANCHORED, so a comment that
    -- happens to contain `["x"] =` cannot be mistaken for an entry
    local ch = body:match('^%s*%["(.)"%]%s*=')
    local plain = false
    if not ch then
      ch = body:match("^%s*(%w)%s*=")
      plain = ch ~= nil
    end
    if ch then
      for _, t in ipairs(pre) do out[#out + 1] = { entry = false, text = t } end
      hadEntries = true
      if plain then bare = true end
      local want = entries[ch]
      if want == false then
        seen[ch] = true                              -- drop it
      elseif isValue(want) then
        seen[ch] = true
        out[#out + 1] = { entry = true, text = plain
          and ('%s = %s'):format(ch, entryValue(want))
          or  ('["%s"] = %s'):format(ch, entryValue(want)) }
      else
        out[#out + 1] = { entry = true, text = body:match("^%s*(.-)%s*$") }
      end
    else
      for _, t in ipairs(pre) do out[#out + 1] = { entry = false, text = t } end
      -- A comment or a blank separator line. Kept, and kept WITHOUT a
      -- comma -- three rooms space their key table out with a blank line
      -- and the first version of this ate it, which the round-trip
      -- caught as the only difference in the whole file.
      for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local t = line:match("^%s*(.-)%s*$")
        if t ~= "" or #out > 0 then
          out[#out + 1] = { entry = false, text = t }
        end
      end
      while #out > 0 and not out[#out].entry and out[#out].text == "" do
        table.remove(out)                     -- no trailing blank run
      end
    end
  end

  local add = {}
  for ch, spec in pairs(entries) do
    if isValue(spec) and not seen[ch] then add[#add + 1] = ch end
  end
  table.sort(add)
  local barestyle = bare or (field ~= "key" and not hadEntries)
  for _, ch in ipairs(add) do
    out[#out + 1] = { entry = true, text = barestyle
      and ('%s = %s'):format(ch, entryValue(entries[ch]))
      or  ('["%s"] = %s'):format(ch, entryValue(entries[ch])) }
  end

  local nEntries = 0
  for _, o in ipairs(out) do if o.entry then nEntries = nEntries + 1 end end

  local inner
  if #out == 0 and not hadEntries then
    inner = origInner            -- it was `{}` and it still is
  elseif #out == 0 then
    inner = ""                   -- emptied: collapse to `{}`
  elseif (field == "gates" or field == "gateStyle") and #out == nEntries then
    -- NAMED, not "anything that is not key": `links` is stacked in all
    -- 83 rooms, and collapsing a three-door room onto one line is a
    -- reformat of a file the editor was only asked to add a door to.
    --
    -- `gates` and `gateStyle` are written on ONE line in all 29 rooms
    -- that have them, and there are at most four of either. So they go
    -- back on one line, as long as nothing but entries is in there.
    -- Without this, adding a gate and then removing it left the table
    -- permanently expanded -- a file changed by an edit that was undone,
    -- which is the one thing this module must never do.
    local t = {}
    for _, o in ipairs(out) do t[#t + 1] = o.text end
    inner = " " .. table.concat(t, ", ") .. " "
  elseif multi or nEntries > 1 then
    -- A single-line table that GAINS a second entry becomes multi-line.
    -- That is a reformat, and it is the one this module allows: the file
    -- is being changed anyway, and `{ G = "a", H = "b", I = "c" }` past
    -- two entries reads worse than the stacked form every `key` uses.
    local parts = {}
    for _, o in ipairs(out) do
      parts[#parts + 1] = (o.text == "" and "")
        or (indent .. o.text .. (o.entry and "," or ""))
    end
    inner = "\n" .. table.concat(parts, "\n") .. "\n" .. tail
  else
    inner = " " .. out[1].text .. " "
  end
  return src:sub(1, a) .. inner .. src:sub(b)
end

-- Replace the map block and NOTHING else.
--
-- `opts.dryrun` returns the bytes that WOULD be written instead of
-- writing them. That is what makes the identity round-trip cheap enough
-- to run over every room in the game on every test run: it proves the
-- surgery is exact without touching a single file.
--
-- `opts.nobackup` skips the backup for the same reason.
function RoomIO.writeMap(id, rows, opts)
  opts = opts or {}
  local src, err = RoomIO.readRaw(id)
  if not src then return nil, err end
  local a, b = RoomIO.mapSpan(src)
  if not a then return nil, b end
  local ok, err2 = RoomIO.checkRect(rows)
  if not ok then return nil, "refusing to write a ragged map: " .. err2 end

  -- reproduce THIS file's own terminator, whichever it uses
  local trailing = src:sub(b, b) == "\n"
  local out = src:sub(1, a - 1) .. RoomIO.rowsToGrid(rows, trailing) .. src:sub(b + 1)

  -- The origin shift rides along on the SAME write. Two writes would
  -- mean two backups and a window in which the file on disk has the new
  -- grid and the old art -- exactly the state nothing can recover from.
  -- It runs on the already-substituted string and re-finds its own
  -- spans, so it does not care whether the art tables sit before or
  -- after the map block.
  if opts.shift and (opts.shift.dx ~= 0 or opts.shift.dy ~= 0) then
    out = RoomIO.shiftArt(out, opts.shift.dx, opts.shift.dy)
  end

  -- ...and so does the key table, for the same reason. A grid with a new
  -- character in it and no entry to match is a room that will not load.
  for _, field in ipairs({ "key", "gates", "gateStyle", "doorKind", "links" }) do
    if opts[field] then
      local done, ferr = RoomIO.setTableEntries(out, field, opts[field])
      if not done then return nil, ferr end
      out = done
    end
  end

  -- The file must still be loadable Lua afterwards. Cheap, and it turns a
  -- corrupted room into a refused write rather than a crash on next load.
  local chunk, lerr = load(out, "roomio:" .. id)
  if not chunk then return nil, "result would not parse: " .. tostring(lerr) end

  if opts.dryrun then return out end

  if not opts.nobackup then
    local bp, berr = RoomIO.backup(id, src)
    if not bp then return nil, berr end
  end

  local f = io.open(RoomIO.path(id), "w")
  if not f then
    return nil, "cannot write " .. RoomIO.path(id) ..
      " -- start the game from its own folder, or check permissions"
  end
  f:write(out)
  f:close()
  return true
end

-- ------------------------------------------------------------------
-- MAKING A ROOM THAT DID NOT EXIST
-- ------------------------------------------------------------------
-- Two files, and the room is not real until BOTH are written: the room
-- file itself, and its name in WM.ROOMS. A room absent from that list
-- does not exist however good its file is -- which is stated in
-- room-format.md and is exactly the kind of thing an editor is for.
--
-- Everything here REFUSES rather than overwrites. Creating is the one
-- operation with no undo: writeMap backs a file up before touching it,
-- and there is nothing to back up when the file is new.

RoomIO.WORLDMAP = "src/data/worldmap.lua"

function RoomIO.roomExists(id)
  local f = io.open(RoomIO.path(id), "r")
  if f then f:close() return true end
  return false
end

-- The body of a new room. Deliberately plain: walls, a floor, and the
-- one door that connects it to where you came from. Everything else --
-- backdrop, props, enemies, geometry -- is what the editor is for, and
-- a template that guesses at them just makes more to delete.
function RoomIO.roomTemplate(o)
  -- solid, then carved: two tiles of wall all round and a floor three
  -- rows up from the bottom, which is genrooms.py's own convention and
  -- puts the stand row at h-4.
  local rows = {}
  for y = 1, o.h do rows[y] = string.rep("#", o.w) end
  for y = 3, o.h - 3 do
    local r = {}
    for x = 1, o.w do
      r[x] = (x <= 2 or x > o.w - 2) and "#" or "."
    end
    rows[y] = table.concat(r)
  end
  return ("-- %s -- created in the editor.\nreturn {\n"
    .. "  zone = %q, music = %q,\n"
    .. "  mapPos = { x = %d, y = %d, w = 1, h = 1 },\n"
    .. "  map = [[\n%s\n]],\n"
    .. "  key = {},\n"
    .. "  links = {\n    %s = { %q, %q },\n  },\n}\n")
    :format(o.id, o.zone, o.music, o.mx, o.my,
            table.concat(rows, "\n"), o.door, o.backRoom, o.backDoor)
end

-- Write a brand-new room file. `rows` overrides the template's grid,
-- which is how the caller gets its door carved into the wall.
function RoomIO.createRoom(o, rows, dryrun)
  if RoomIO.roomExists(o.id) then
    return nil, ("%s already exists -- refusing to overwrite it"):format(o.id)
  end
  local text = RoomIO.roomTemplate(o)
  if rows then
    local ok, err = RoomIO.checkRect(rows)
    if not ok then return nil, "refusing to write a ragged map: " .. err end
    local a, b = RoomIO.mapSpan(text)
    if not a then return nil, "the template has no map block" end
    text = text:sub(1, a - 1) .. RoomIO.rowsToGrid(rows, true) .. text:sub(b + 1)
  end
  local chunk, lerr = load(text, "roomio:new:" .. o.id)
  if not chunk then return nil, "the new room would not parse: " .. tostring(lerr) end
  if dryrun then return text end
  local f = io.open(RoomIO.path(o.id), "w")
  if not f then return nil, "cannot write " .. RoomIO.path(o.id) end
  f:write(text)
  f:close()
  return true
end

-- Append an id to WM.ROOMS, next to the rooms it belongs with.
--
-- The list is grouped by zone and wrapped by hand, so the insertion goes
-- after the LAST room sharing this one's prefix -- `moss_9` lands after
-- `moss_secret` rather than at the bottom of the file, and the grouping
-- survives. Failing that it goes on its own line before the closing
-- brace, which is ugly and correct.
function RoomIO.registerRoom(id, dryrun)
  local path = RoomIO.root() .. RoomIO.WORLDMAP
  local fh = io.open(path, "r")
  if not fh then return nil, "cannot read " .. path end
  local src = fh:read("*a")
  fh:close()

  -- "WM%.ROOMS", not "ROOMS": fieldSpan anchors on `\n%s*<name>%s*=`,
  -- and the table is declared `WM.ROOMS = {`, so a bare name matches
  -- nothing. It is a Lua pattern, hence the escaped dot.
  local a, b = RoomIO.fieldSpan(src, "WM%.ROOMS")
  if not a then return nil, "no WM.ROOMS table in worldmap.lua" end
  if type(b) ~= "number" then return nil, tostring(b) end
  local inner = src:sub(a + 1, b - 1)
  if inner:find('"' .. id .. '"', 1, true) then
    return nil, id .. " is already in WM.ROOMS"
  end

  local prefix = id:match("^(%a+)_") or id
  -- the end of the last quoted name that shares the prefix
  local at, last = nil, nil
  for from, name, to in inner:gmatch('()"([%w_]+)"()') do
    if (name:match("^(%a+)_") or name) == prefix then at, last = to, name end
  end
  local out
  if at then
    out = src:sub(1, a) .. inner:sub(1, at - 1) .. ', "' .. id .. '"'
        .. inner:sub(at) .. src:sub(b)
  else
    local tail = inner:match("\n(%s*)$") or "  "
    out = src:sub(1, a) .. inner:gsub("%s*$", "")
        .. ',\n  "' .. id .. '",\n' .. tail .. src:sub(b)
  end

  local chunk, lerr = load(out, "roomio:worldmap")
  if not chunk then return nil, "worldmap would not parse: " .. tostring(lerr) end
  if dryrun then return out end

  local bak = io.open(path .. ".bak", "w")
  if bak then bak:write(src) bak:close() end
  local f = io.open(path, "w")
  if not f then return nil, "cannot write " .. path end
  f:write(out)
  f:close()
  return true
end

-- BOTH caches, always.
--
-- World keeps its own roomCache AND require() keeps package.loaded.
-- Clearing only the first makes a saved edit look like it did not save,
-- and the next half hour goes into debugging the save layer, which is
-- fine.
function RoomIO.invalidate(id)
  local key = "src.data.rooms." .. id
  package.loaded[key] = nil
  local W = package.loaded["src.world"]
  if W and W.roomCache then W.roomCache[id] = nil end
end

return RoomIO
