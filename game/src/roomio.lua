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
