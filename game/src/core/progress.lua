-- World-progression solver (test mode).
-- Runs the same flag-inventory fixpoint as scripts/checkprogress.py over
-- the generated src/data/progress_graph.lua, from the CURRENT run state.
-- Used by the in-game Progress menu; pure data in, report out.
local Graph = require "src.data.progress_graph"

local M = {}

local function satisfied(reqs, flags)
  for _, alt in ipairs(reqs) do
    local ok = true
    for _, f in ipairs(alt) do
      if not flags[f] then ok = false break end
    end
    if ok then return true end
  end
  return false
end

local function missingOf(reqs, flags)
  -- smallest set of missing flags across the alternatives
  local best
  for _, alt in ipairs(reqs) do
    local miss = {}
    for _, f in ipairs(alt) do
      if not flags[f] then miss[#miss + 1] = f end
    end
    if not best or #miss < #best then best = miss end
  end
  return best or {}
end

-- One fixpoint pass. collect=false: what can I touch RIGHT NOW with the
-- flags I hold. collect=true: what is EVENTUALLY obtainable if I pick
-- everything up along the way (completability).
local function solve(startRoom, flags, collect)
  local have = {}
  for k, v in pairs(flags) do if v then have[k] = true end end
  local doorSeen = {}   -- "room:door" = true
  local roomSeen = {}
  local targetSeen = {} -- "room|tkey" = true

  local function seedRoom(rm)
    roomSeen[rm] = true
    local info = Graph.rooms[rm]
    if not info then return end
    for dch in pairs(info.doors) do
      doorSeen[rm .. ":" .. dch] = true
    end
  end
  seedRoom(startRoom)

  local changed = true
  while changed do
    changed = false
    for flag, d in pairs(Graph.derived) do
      if collect and not have[flag] and roomSeen[d.room]
          and satisfied({ d.req }, have) then
        have[flag] = true
        changed = true
      end
    end
    for rm in pairs(roomSeen) do
      local info = Graph.rooms[rm]
      if info then
        for _, e in ipairs(info.edges) do
          local fromDoor = e.from:sub(6)
          if doorSeen[rm .. ":" .. fromDoor] and satisfied(e.reqs, have) then
            if e.to:sub(1, 5) == "door:" then
              local td = e.to:sub(6)
              if not doorSeen[rm .. ":" .. td] then
                doorSeen[rm .. ":" .. td] = true
                changed = true
              end
              local link = info.doors[td]
              if link and link[1] and Graph.rooms[link[1]] then
                if not doorSeen[link[1] .. ":" .. link[2]] then
                  if not roomSeen[link[1]] then roomSeen[link[1]] = true end
                  doorSeen[link[1] .. ":" .. link[2]] = true
                  changed = true
                end
              end
            else
              local key = rm .. "|" .. e.to
              if not targetSeen[key] then
                targetSeen[key] = true
                changed = true
              end
              local give = info.gives[e.to]
              if collect and give and satisfied({ give.req }, have) then
                for _, f in ipairs(give.flags) do
                  if not have[f] then
                    have[f] = true
                    changed = true
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return { flags = have, doors = doorSeen, rooms = roomSeen,
           targets = targetSeen }
end

-- Human label for an entity target from the flags it grants.
local PRETTY = {
  sparkjump = "SPARK JUMP module", grapple = "MAGNE-GRAPPLE module",
  hydroseals = "HYDRO SEALS module", heatplating = "HEAT PLATING module",
  telenet = "TELE-NET master key",
  -- named for their zone, not numbered: see items.lua
  corekey1 = "Core key: Furnace", corekey2 = "Core key: Hollows",
  corekey3 = "Core key: Spire",
  moldcap = "Root's moldcap", musicbox = "Tikka's music box",
}
local function labelFor(give)
  for _, f in ipairs(give.flags) do
    if PRETTY[f] then return PRETTY[f] end
  end
  for _, f in ipairs(give.flags) do
    if f:sub(1, 4) == "cap_" then return "Life Capsule" end
    if f:sub(1, 5) == "tank_" then return "Energy Tank" end
    if f:sub(1, 7) == "weapon_" then return "Weapon: " .. f:sub(8) end
    if f:sub(1, 5) == "boss_" then return "Boss: " .. f:sub(6) end
  end
  if give.kind == "chest" then return "Chest (" .. (give.flags[1] or "?") .. ")" end
  return give.flags[1] or "?"
end

local function zoneOf(rm)
  local WM = require "src.data.worldmap"
  local def = require("src.world").getRoomDef(rm)
  return (def and WM.ZONE_NAMES[def.zone]) or rm
end

-- Build the full report for the Progress menu.
function M.report()
  local run = G.run
  local here = (run and run.room) or Graph.start.room
  if not Graph.rooms[here] then here = Graph.start.room end
  local flags = (run and run.flags) or {}

  local now = solve(here, flags, false)
  local ever = solve(here, flags, true)

  local rep = {
    completable = ever.flags.ending and true or false,
    room = here,
  }

  -- rooms
  local total, visited, reachNow = 0, 0, 0
  rep.unvisitedNow = {}
  for rm in pairs(Graph.rooms) do
    total = total + 1
    local v = run and run.visited and run.visited[rm]
    if v then visited = visited + 1 end
    if now.rooms[rm] then
      reachNow = reachNow + 1
      if not v then rep.unvisitedNow[#rep.unvisitedNow + 1] = rm end
    end
  end
  table.sort(rep.unvisitedNow)
  rep.roomsTotal, rep.roomsVisited, rep.roomsReachableNow =
    total, visited, reachNow

  -- items: collectables + bosses only (plates/machines/teleporters are
  -- steps, not goals -- they still drive the solver, just aren't listed)
  local LISTED = { chest = true, capsule = true, tank = true, boss = true,
                   npc = true }
  rep.itemsNow, rep.itemsBlocked, rep.itemsLocked = {}, {}, {}
  local collected, itemTotal = 0, 0
  for rm, info in pairs(Graph.rooms) do
    for tkey, give in pairs(info.gives) do
      repeat
      if not LISTED[give.kind] then break end
      itemTotal = itemTotal + 1
      local doneAll = true
      for _, f in ipairs(give.flags) do
        if not flags[f] then doneAll = false break end
      end
      if doneAll then
        collected = collected + 1
      else
        local entry = { room = rm, zone = zoneOf(rm), label = labelFor(give) }
        if now.targets[rm .. "|" .. tkey]
            and satisfied({ give.req }, now.flags) then
          rep.itemsNow[#rep.itemsNow + 1] = entry
        elseif ever.targets[rm .. "|" .. tkey] then
          -- find what is missing: smallest missing set over edges into it
          local missBest
          for _, e in ipairs(info.edges) do
            if e.to == tkey then
              local miss = missingOf(e.reqs, flags)
              if not missBest or #miss < #missBest then missBest = miss end
            end
          end
          for _, f in ipairs(give.req) do
            if not flags[f] then
              missBest = missBest or {}
              missBest[#missBest + 1] = f
            end
          end
          entry.missing = missBest or {}
          rep.itemsBlocked[#rep.itemsBlocked + 1] = entry
        else
          rep.itemsLocked[#rep.itemsLocked + 1] = entry
        end
      end
      until true
    end
  end
  local function byRoom(a, b) return a.room < b.room end
  table.sort(rep.itemsNow, byRoom)
  table.sort(rep.itemsBlocked, byRoom)
  table.sort(rep.itemsLocked, byRoom)
  rep.itemsCollected, rep.itemsTotal = collected, itemTotal
  return rep
end

M.zoneOf = zoneOf
return M
