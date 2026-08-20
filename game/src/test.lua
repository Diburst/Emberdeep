-- Headless test harness. Activated when EMBERDEEP_TEST is set; the value
-- names a scenario. Scenarios drive virtual input frame-by-frame, take
-- screenshots and a log into emberdeep/_testlogs/, then quit.
--
-- Output used to go to /tmp, which is fine for the person running LOVE
-- and useless to anyone else -- every failure became "paste me what it
-- said", and a run whose tail was pasted hid the FAIL lines above it.
-- _testlogs/ is inside the project and gitignored. Override with
-- EMBERDEEP_TESTDIR.
local Test = {}

local OUTDIR = os.getenv("EMBERDEEP_TESTDIR") or "../_testlogs"

local log
local frame = 0
local scenario
local co

local function out(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
  local line = table.concat(parts, " ")
  print(line)
  if log then log:write(line, "\n") log:flush() end
  if Test.alllog then Test.alllog:write(line, "\n") Test.alllog:flush() end
end
Test.log = out

function Test.shot(name)
  love.graphics.captureScreenshot(function(img)
    local fd = img:encode("png")
    local f = io.open(OUTDIR .. "/shots/" .. name .. ".png", "wb")
    if f then
      f:write(fd:getString())
      f:close()
      out("SHOT " .. name)
    end
  end)
end

-- coroutine helpers -------------------------------------------------
local function wait(frames)
  for _ = 1, frames do coroutine.yield() end
end

local function press(player, action, frames)
  G.Input.virtual[player][action] = true
  wait(frames or 2)
  G.Input.virtual[player][action] = nil
  wait(1)
end

local function hold(player, action)
  G.Input.virtual[player][action] = true
end

local function release(player, action)
  G.Input.virtual[player][action] = nil
end

local function menuNav(action)
  -- inject a menu event directly
  G.Input.menuQueue[#G.Input.menuQueue + 1] = { action = action, slot = 1 }
  wait(2)
end

Test.wait, Test.press, Test.hold, Test.release, Test.menuNav =
  wait, press, hold, release, menuNav

-- scenarios ---------------------------------------------------------
local scenarios = {}

function scenarios.boot()
  wait(30)
  Test.shot("boot_title")
  out("STATE " .. tostring(G.State.top().name))
  out("OK boot")
end

-- registered by other modules (sweep etc.) via Test.addScenario
function Test.addScenario(name, fn) scenarios[name] = fn end

-- load extra scenario packs if present
pcall(function() require("src.test_scenarios")(Test, scenarios) end)

function Test.run(name)
  os.execute("mkdir -p '" .. OUTDIR .. "/shots'")
  -- One file per scenario, so a failure can be read on its own, PLUS an
  -- append-only combined log for the order things ran in.
  log = io.open(OUTDIR .. "/" .. name .. ".log", "w")
  Test.alllog = io.open(OUTDIR .. "/all.log", "a")
  out("=== TEST " .. name .. " ===")
  scenario = scenarios[name]
  if not scenario then
    out("FAIL unknown scenario: " .. tostring(name))
    love.event.quit(1)
    return
  end
  co = coroutine.create(function()
    local ok, err = pcall(scenario)
    -- frame-level invariants (src/core/invariants.lua) fail any scenario
    local inv = package.loaded["src.core.invariants"]
    local invCount = inv and inv.count or 0
    if ok and invCount > 0 then
      out("FAIL " .. invCount .. " invariant violation(s) -- see INVARIANT lines")
      ok = false
    elseif ok then
      out("INVARIANTS clean")
      out("=== DONE " .. name .. " ===")
    else
      out("FAIL " .. tostring(err))
    end
    wait(5)
    love.event.quit(ok and 0 or 1)
  end)
  -- resume the scenario once per SIMULATION STEP so wait(n) means n steps
  local maxMinutes = tonumber(os.getenv("EMBERDEEP_MAX_MINUTES")) or 10
  G.testStep = function()
    frame = frame + 1
    if frame > 60 * 60 * maxMinutes then -- sim-minutes hard cap
      out("FAIL timeout")
      love.event.quit(1)
    end
    if co and coroutine.status(co) ~= "dead" then
      local ok, err = coroutine.resume(co)
      if not ok then
        out("FAIL coroutine: " .. tostring(err))
        love.event.quit(1)
      end
    end
  end
  -- (state stack updates run through the fixed-step accumulator for
  -- menus and gameplay alike, so the step hook alone is sufficient)
end

return Test
