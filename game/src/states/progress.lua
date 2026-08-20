-- PROGRESS panel (test mode): live world-progression report.
-- Opened with F1 (or the pause menu entry) while testmode is on.
local P = require "src.assets.palette"

local S = { name = "progress", translucent = true }

function S:enter()
  self.scroll = 0
  self:rebuild()
end

function S:rebuild()
  local ok, rep = pcall(function()
    return require("src.core.progress").report()
  end)
  self.rep = ok and rep or nil
  self.err = ok and nil or tostring(rep)

  -- flatten into display lines: { text, color }
  local L = {}
  local function add(t, c) L[#L + 1] = { t, c or P.silver } end
  if not self.rep then
    add("progress solver error:", P.blood)
    add(tostring(self.err), P.blood)
    self.lines = L
    return
  end
  local r = self.rep
  add(r.completable and "RUN IS COMPLETABLE FROM HERE"
    or "!! RUN CANNOT BE COMPLETED -- REPORT THIS !!",
    r.completable and P.leaf or P.blood)
  add(string.format("rooms: %d/%d visited, %d reachable now",
    r.roomsVisited, r.roomsTotal, r.roomsReachableNow))
  add(string.format("items: %d/%d collected", r.itemsCollected, r.itemsTotal))
  add("")
  if #r.itemsNow > 0 then
    add("REACHABLE NOW:", P.gold)
    for _, it in ipairs(r.itemsNow) do
      add("  " .. it.label .. "  -  " .. it.room, P.silver)
    end
    add("")
  end
  if #r.itemsBlocked > 0 then
    add("BLOCKED (need more progress):", P.rust)
    for _, it in ipairs(r.itemsBlocked) do
      local m = (it.missing and #it.missing > 0)
        and ("  [needs " .. table.concat(it.missing, ", ") .. "]") or ""
      add("  " .. it.label .. "  -  " .. it.room .. m, P.slate)
    end
    add("")
  end
  if #r.itemsLocked > 0 then
    add("!! UNREACHABLE (map bug -- report this):", P.blood)
    for _, it in ipairs(r.itemsLocked) do
      add("  " .. it.label .. "  -  " .. it.room, P.blood)
    end
    add("")
  end
  if #r.unvisitedNow > 0 then
    add("UNEXPLORED ROOMS YOU CAN REACH:", P.cyan)
    local line = "  "
    for i, rm in ipairs(r.unvisitedNow) do
      line = line .. rm .. (i < #r.unvisitedNow and ", " or "")
      if #line > 46 then add(line, P.slate) line = "  " end
    end
    if line ~= "  " then add(line, P.slate) end
  end
  self.lines = L
end

local ROWH = 9
local TOP, BOT = 34, 20

function S:visibleRows()
  return math.floor((G.SH - TOP - BOT) / ROWH)
end

function S:menu(action)
  if action == "cancel" or action == "start" then
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  local maxScroll = math.max(0, #self.lines - self:visibleRows())
  if action == "up" then
    self.scroll = math.max(0, self.scroll - 1)
  elseif action == "down" then
    self.scroll = math.min(maxScroll, self.scroll + 1)
  end
end

function S:raw(ev)
  if ev.kind == "rawkey" and (ev.id == "f1" or ev.id == "tab") then
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
  end
end

function S:update(dt)
  for slot = 1, 2 do
    if G.Input.pressed(slot, "map") or G.Input.pressed(slot, "pause") then
      G.State.pop()
      return
    end
  end
end

function S:draw()
  local g = love.graphics
  g.setColor(P.black[1], P.black[2], P.black[3], 0.88)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  g.setFont(G.fonts.main)
  g.setColor(P.cyan)
  g.printf("PROGRESS  (test mode)", 0, 12, G.SW, "center")
  g.setColor(P.slate)
  g.printf(G.fmtButtons("F1 / [CANCEL] close    [MOVE] scroll"),
    0, G.SH - 14, G.SW, "center")
  local vis = self:visibleRows()
  for i = 1, vis do
    local ln = self.lines[i + self.scroll]
    if not ln then break end
    g.setColor(ln[2])
    g.print(ln[1], 14, TOP + (i - 1) * ROWH)
  end
  if self.scroll > 0 then
    g.setColor(P.gold)
    g.print("^", G.SW - 16, TOP)
  end
  if #self.lines - self.scroll > vis then
    g.setColor(P.gold)
    g.print("v", G.SW - 16, G.SH - BOT - 8)
  end
  g.setColor(1, 1, 1, 1)
end

return S
