-- ==================================================================
-- THE VALIDATOR SUITE, OFF THE MAIN THREAD.
-- ==================================================================
-- io.popen blocks until the child exits. The deep suite is a MINUTE of
-- Python -- checkbeams 17s, checkprogress 19s, genprogress 16s -- and
-- running it inline froze the window solid for that whole minute with
-- no cursor, no repaint and no way to tell it apart from a hang.
--
-- So it runs here instead. The editor stays live and paints a progress
-- bar; this pushes one line per validator as it starts, then the tally.
--
-- Protocol:
--   in   one string, "label\tshell command" per line
--   out  "edcheck_progress"  <- "3/12 checksight" as each one begins
--        "edcheck_result"    <- failure count, then the failure text
-- ==================================================================
require "love.thread"

local list = ...
local prog = love.thread.getChannel("edcheck_progress")
local res  = love.thread.getChannel("edcheck_result")

local items = {}
for line in list:gmatch("[^\n]+") do items[#items + 1] = line end

local bad, detail = 0, {}

for i, it in ipairs(items) do
  local label, cmd = it:match("^([^\t]+)\t(.+)$")
  if label then
    prog:push(("%d/%d  %s"):format(i, #items, label))
    -- THE EXIT STATUS IS THE VERDICT, not the word "FAIL".
    --
    -- io.popen in 5.1 cannot report the child's status, so the first
    -- version scanned the output for "FAIL" -- and checkrooms does not
    -- print that word. It exits 1 and prints "3 liquid issues", so the
    -- editor cheerfully reported "all clean" while the room was broken.
    -- Echoing $? out of a subshell gets the real answer back.
    local pipe = io.popen("( " .. cmd .. " ) 2>&1; echo \"__EXIT:$?\"")
    local out = ""
    if pipe then
      out = pipe:read("*a") or ""
      pipe:close()
    else
      out = "could not run " .. cmd .. "\n__EXIT:127"
    end
    local status = tonumber(out:match("__EXIT:(%d+)%s*$") or "") or 0
    if status ~= 0 then
      bad = bad + 1
      detail[#detail + 1] = "-- " .. label .. " (exit " .. status .. ")"
      -- keep the validator's own words: they name the room and the tile
      for l in out:gmatch("[^\n]+") do
        if not l:find("__EXIT:", 1, true) and l:match("%S") then
          if #detail < 200 then detail[#detail + 1] = "   " .. l end
        end
      end
    end
  end
end

prog:push("done")
res:push(bad)
res:push(table.concat(detail, "\n"))
