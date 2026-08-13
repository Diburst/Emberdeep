-- Frame-level invariant checks, active under EMBERDEEP_TEST.
-- Every sim step, every scenario: things that must NEVER be true, no
-- matter which test is running. A violation logs an INVARIANT line and
-- fails the run at the end (see src/test.lua).
local M = { count = 0 }

local reported = {}   -- dedupe key -> true
local embedFrames = {} -- player idx -> consecutive embedded frames

local function report(key, msg)
  if reported[key] then return end
  reported[key] = true
  M.count = M.count + 1
  local Test = require "src.test"
  Test.log("INVARIANT " .. msg)
end

-- allow scenarios to reset between rooms if they want a clean slate
function M.reset()
  reported = {}
  embedFrames = {}
end

local function embedded(World, p)
  -- sample the body interior (2px inset): any point inside a solid tile
  -- means the player is stuck in terrain
  local pts = {
    { p.x + 2, p.y + 2 }, { p.x + p.w - 2, p.y + 2 },
    { p.x + 2, p.y + p.h - 2 }, { p.x + p.w - 2, p.y + p.h - 2 },
    { p.x + p.w / 2, p.y + p.h / 2 },
  }
  for _, pt in ipairs(pts) do
    if World:isSolid(math.floor(pt[1] / 16), math.floor(pt[2] / 16), p) then
      return true
    end
  end
  return false
end

function M.check()
  local ok, err = pcall(M.checkInner)
  if not ok then
    report("harness", "harness error: " .. tostring(err))
  end
end

function M.checkInner()
  -- state stack sanity (always applicable)
  local State = G.State
  if State and State.stack and #State.stack > 8 then
    report("stack", "state stack depth " .. #State.stack)
  end

  if not (G.game and G.run) then return end
  local World = require "src.world"
  if not World.room or not World.players then return end
  if World.loading then return end

  -- entity population sanity
  if World.entities and #World.entities > 1500 then
    report("entities:" .. tostring(G.run.room),
      "entity count " .. #World.entities .. " in " .. tostring(G.run.room))
  end

  local roomW = (World.w or 0) * 16
  local roomH = (World.h or 0) * 16

  for i, p in ipairs(World.players) do
    if not p.dead and not p.idle then
      -- embedded in terrain (3+ consecutive frames = real, not transient)
      if embedded(World, p) then
        embedFrames[i] = (embedFrames[i] or 0) + 1
        if embedFrames[i] >= 3 then
          report("embed:" .. tostring(G.run.room) .. ":" .. i,
            "p" .. i .. " embedded in terrain at "
            .. math.floor(p.x / 16) .. "," .. math.floor(p.y / 16)
            .. " in " .. tostring(G.run.room))
        end
      else
        embedFrames[i] = 0
      end
      -- out of room bounds
      if roomW > 0 and (p.x < -24 or p.x > roomW + 24
          or p.y < -48 or p.y > roomH + 24) then
        report("oob:" .. tostring(G.run.room) .. ":" .. i,
          "p" .. i .. " out of bounds " .. math.floor(p.x) .. ","
          .. math.floor(p.y) .. " in " .. tostring(G.run.room)
          .. " vy=" .. math.floor(p.vy or 0)
          .. " downed=" .. tostring(p.downed)
          .. " dash=" .. tostring((p.dashT or 0) > 0)
          .. " grap=" .. tostring(p.grappling ~= nil)
          .. " Wh=" .. tostring(World.h))
      end
      -- hp sanity (scenarios may deliberately overheal to 9999)
      if p.hp and (p.hp < -1 or p.hp > math.max(p.maxhp or 12, 9999)) then
        report("hp:" .. i, "p" .. i .. " hp " .. tostring(p.hp)
          .. "/" .. tostring(p.maxhp))
      end
    end
  end

  -- camera clamped to the room
  local Cam = require "src.camera"
  if roomW >= G.VW and Cam.x and (Cam.x < -2 or Cam.x > roomW - G.VW + 2) then
    report("camx:" .. tostring(G.run.room),
      "camera x " .. math.floor(Cam.x) .. " outside room "
      .. tostring(G.run.room))
  end
  if roomH >= G.VH and Cam.y and (Cam.y < -2 or Cam.y > roomH - G.VH + 2) then
    report("camy:" .. tostring(G.run.room),
      "camera y " .. math.floor(Cam.y) .. " outside room "
      .. tostring(G.run.room))
  end
end

return M
