-- LOG: a scrollable history of everything anyone has said to you --
-- dialogue, signs, terminal records, and the deep's own announcements.
-- Opened from the pause menu.
local P = require "src.assets.palette"
local Textbox = require "src.ui.textbox"

local S = { name = "log", translucent = true }

local WRAP = 66      -- characters per wrapped line
local ROWH = 9
local TOP, BOT = 34, 20

function S:enter()
  -- flatten the log into colored display lines
  local L = {}
  local function add(t, c) L[#L + 1] = { t, c or P.silver } end
  local log = (G.run and G.run.log) or {}
  if #log == 0 then
    add("Nothing yet. Talk to somebody.", P.slate)
  end
  for _, e in ipairs(log) do
    local who = e.who or ""
    local name = who ~= "" and who ~= "sys" and (Textbox.NAMES[who] or who) or nil
    local col = name and P[Textbox.PORT_COLOR[who] or "slate"] or P.slate
    if name then
      add(name .. ":", col)
    end
    -- wrap the body
    local body = e.text or ""
    local line = ""
    for word in body:gmatch("%S+") do
      local cand = line == "" and word or (line .. " " .. word)
      if #cand > WRAP then
        add("  " .. line, name and P.light or P.silver)
        line = word
      else
        line = cand
      end
    end
    if line ~= "" then add("  " .. line, name and P.light or P.silver) end
  end
  self.lines = L
  -- open at the bottom: the freshest words
  self.scroll = math.max(0, #L - self:visibleRows())
end

function S:visibleRows()
  return math.floor((G.SH - TOP - BOT) / ROWH)
end

function S:menu(action)
  if action == "cancel" or action == "start" or action == "confirm" then
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

function S:update(dt)
  for slot = 1, 2 do
    if G.Input.pressed(slot, "map") or G.Input.pressed(slot, "pause") then
      G.State.pop()
      return
    end
    -- fast scroll with left/right
    if G.Input.down(slot, "left") then
      self.scroll = math.max(0, self.scroll - 1)
    elseif G.Input.down(slot, "right") then
      local maxScroll = math.max(0, #self.lines - self:visibleRows())
      self.scroll = math.min(maxScroll, self.scroll + 1)
    end
  end
end

function S:draw()
  local g = love.graphics
  g.setColor(P.black[1], P.black[2], P.black[3], 0.9)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  g.setFont(G.fonts.main)
  g.setColor(P.gold)
  g.printf("LOG", 0, 12, G.SW, "center")
  g.setColor(P.slate)
  g.printf(G.fmtButtons("[MOVE] scroll    [CANCEL] close"),
    0, G.SH - 14, G.SW, "center")
  local vis = self:visibleRows()
  for i = 1, vis do
    local ln = self.lines[i + self.scroll]
    if ln then
      g.setColor(ln[2])
      g.print(ln[1], 24, TOP + (i - 1) * ROWH)
    end
  end
  -- scrollbar
  if #self.lines > vis then
    local h = G.SH - TOP - BOT
    local barH = math.max(8, h * vis / #self.lines)
    local barY = TOP + (h - barH) * (self.scroll / math.max(1, #self.lines - vis))
    g.setColor(P.gray)
    g.rectangle("fill", G.SW - 8, TOP, 2, h)
    g.setColor(P.silver)
    g.rectangle("fill", G.SW - 8, barY, 2, barH)
  end
  g.setColor(1, 1, 1, 1)
end

return S
