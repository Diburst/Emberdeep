-- In-game map: visited rooms as boxes, zone-coloured, with the DOOR
-- CONNECTIONS drawn between them.
--
-- Rewritten because the old one could not answer "what is furn_1 attached
-- to?". It drew boxes at a fixed scale with no links, no way to pan, and no
-- way to zoom -- so a world 45 cells wide ran off a 480px screen and the
-- only thing you could do about it was squint.
--
-- Rewritten AGAIN because the answer was still unreadable. Two reasons:
--
--   Every link was a centre-to-centre line. Rooms that are neighbours got
--   a line as long and as loud as rooms at opposite ends of the world, so
--   the map was a cat's cradle. Now the layout solver (scripts/maplayout.py)
--   places doored rooms touching, and a touching pair draws a small notch
--   at the shared wall instead of a line. Only the links that are NOT
--   neighbours -- shafts and boss lifts -- are lines, they are dashed, and
--   the long ones are drawn only for the room you are on or the room under
--   the crosshair. Everything else gets a stub at its own wall: "there is a
--   way out here, going that way."
--
--   Zone names were printed at the zone's ORIGIN cell whether or not any
--   room was there, so labels for neighbouring zones landed on top of each
--   other and on top of the boxes. Now each label sits over the bounding
--   box of the rooms of that zone you have actually seen, and a label that
--   would collide with one already placed moves below its zone or is
--   dropped rather than overprinted.
local P = require "src.assets.palette"

local S = { name = "mapscreen", translucent = true }

local ZOOMS = { 4, 6, 8, 12, 18 }
local PAN_SPEED = 150          -- px/sec at zoom 1; scaled by cell size
-- The framed map area. Its HEIGHT is set by what the footer needs, not
-- the other way round: four lines of 8px plus their gaps is 37px, and the
-- old 214 left only 33 -- so the exits line printed over the legend, and
-- a room box near the bottom edge printed over the room name under it.
local FOOT_LINES = 4
local VIEW = { x = 6, y = 20, w = 468, h = 202 }

-- ------------------------------------------------------------------
-- build the atlas once per open
-- ------------------------------------------------------------------
function S:enter()
  local WM = require "src.data.worldmap"
  local World = require "src.world"
  self.WM = WM
  self.rooms = {}
  self.order = {}
  for _, id in ipairs(WM.ROOMS) do
    local ok, def = pcall(World.getRoomDef, id)
    local off = ok and def and WM.ZONE_OFFSETS[def.zone]
    if ok and def and def.mapPos and off then
      local mp = def.mapPos
      self.rooms[id] = {
        id = id, def = def, zone = def.zone,
        x = off.x + mp.x, y = off.y + mp.y,
        w = mp.w or 1, h = mp.h or 1,
        seen = G.run.visited[id] or G.DEBUG,
      }
      self.order[#self.order + 1] = id
    end
  end

  self:buildConns()
  self:buildZoneBoxes()

  self.cur = World.room and World.room.id
  self.zoom = 3
  self:fit()
  -- open centred on where you are, because that is the question you
  -- actually came here with
  local me = self.cur and self.rooms[self.cur]
  if me then
    self.cx = (me.x + me.w / 2)
    self.cy = (me.y + me.h / 2)
  end
end

-- one entry per door pair, not one per door, so a link is not drawn
-- twice (and drawn twice at different alphas, which is how the old one
-- got its slightly smeared look)
function S:buildConns()
  self.conns = {}
  self.byRoom = {}
  local seen = {}
  for _, id in ipairs(self.order) do
    local r = self.rooms[id]
    for ch, link in pairs(r.def.links or {}) do
      local o = link[1]
      local a, b, ka, kb = id, o, ch, link[2] or "?"
      if b < a then a, b, ka, kb = o, id, kb, ka end
      local key = a .. ka .. b .. kb
      if not seen[key] then
        seen[key] = true
        local cn = { a = a, b = b, req = link.req }
        self.conns[#self.conns + 1] = cn
        self.byRoom[a] = self.byRoom[a] or {}
        self.byRoom[b] = self.byRoom[b] or {}
        table.insert(self.byRoom[a], cn)
        table.insert(self.byRoom[b], cn)
      end
    end
  end
end

-- A zone's label belongs over the rooms of it you have SEEN, not over
-- the cell its offset happens to name. And not over the zone's whole
-- bounding box either: EMBER CAMP is four huts at one end of the world
-- and the Deep Stair at the other, twenty-five cells apart, because the
-- route between them runs through Mosswood. Labelling the bounding box
-- of that puts "EMBER CAMP" in the middle of Mosswood. So the label goes
-- over the largest cluster of touching rooms the zone has.
function S:buildZoneBoxes()
  local byZone = {}
  for _, id in ipairs(self.order) do
    local r = self.rooms[id]
    if r.seen then
      byZone[r.zone] = byZone[r.zone] or {}
      table.insert(byZone[r.zone], r)
    end
  end
  self.zbox = {}
  for zone, list in pairs(byZone) do
    local group = {}
    for i, r in ipairs(list) do group[i] = i end
    local function find(i)
      while group[i] ~= i do group[i] = group[group[i]]; i = group[i] end
      return i
    end
    for i = 1, #list do
      for j = i + 1, #list do
        local a, b = list[i], list[j]
        local touchX = a.x < b.x + b.w + 1 and b.x < a.x + a.w + 1
        local touchY = a.y < b.y + b.h + 1 and b.y < a.y + a.h + 1
        if touchX and touchY then group[find(i)] = find(j) end
      end
    end
    local boxes, count = {}, {}
    for i, r in ipairs(list) do
      local k = find(i)
      local b = boxes[k]
      if not b then
        boxes[k] = { x0 = r.x, y0 = r.y, x1 = r.x + r.w, y1 = r.y + r.h }
        count[k] = 1
      else
        b.x0 = math.min(b.x0, r.x); b.y0 = math.min(b.y0, r.y)
        b.x1 = math.max(b.x1, r.x + r.w); b.y1 = math.max(b.y1, r.y + r.h)
        count[k] = count[k] + 1
      end
    end
    local bestK, bestN = nil, -1
    for k, n in pairs(count) do
      if n > bestN then bestK, bestN = k, n end
    end
    self.zbox[zone] = boxes[bestK]
  end
end

-- pick the largest zoom at which everything you have seen fits
function S:fit()
  local x0, y0, x1, y1
  for _, id in ipairs(self.order) do
    local r = self.rooms[id]
    if r.seen then
      x0 = math.min(x0 or r.x, r.x); y0 = math.min(y0 or r.y, r.y)
      x1 = math.max(x1 or r.x + r.w, r.x + r.w)
      y1 = math.max(y1 or r.y + r.h, r.y + r.h)
    end
  end
  if not x0 then x0, y0, x1, y1 = 0, 0, 1, 1 end
  self.bounds = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  self.cx, self.cy = (x0 + x1) / 2, (y0 + y1) / 2
  for i = #ZOOMS, 1, -1 do
    if (x1 - x0) * ZOOMS[i] <= VIEW.w and (y1 - y0) * ZOOMS[i] <= VIEW.h then
      self.zoom = i
      return
    end
  end
  self.zoom = 1
end

function S:cell() return ZOOMS[self.zoom] end

-- world cell -> screen pixel
function S:toScreen(cx, cy)
  local c = self:cell()
  return VIEW.x + VIEW.w / 2 + (cx - self.cx) * c,
         VIEW.y + VIEW.h / 2 + (cy - self.cy) * c
end

function S:clampView()
  local b = self.bounds
  local c = self:cell()
  local halfW, halfH = VIEW.w / (2 * c), VIEW.h / (2 * c)
  local pad = 2
  local lo, hi = b.x0 - pad + halfW, b.x1 + pad - halfW
  if lo > hi then self.cx = (b.x0 + b.x1) / 2 else self.cx = math.max(lo, math.min(hi, self.cx)) end
  lo, hi = b.y0 - pad + halfH, b.y1 + pad - halfH
  if lo > hi then self.cy = (b.y0 + b.y1) / 2 else self.cy = math.max(lo, math.min(hi, self.cy)) end
end

-- which room is under the crosshair?
function S:underCursor()
  for _, id in ipairs(self.order) do
    local r = self.rooms[id]
    if r.seen and self.cx >= r.x and self.cx < r.x + r.w
      and self.cy >= r.y and self.cy < r.y + r.h then
      return r
    end
  end
  return nil
end

-- ------------------------------------------------------------------
-- input
-- ------------------------------------------------------------------
function S:menu(action)
  if action == "cancel" or action == "backbtn" or action == "start" then
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
  end
end

function S:update(dt)
  local c = self:cell()
  local dx, dy = 0, 0
  for slot = 1, 2 do
    if G.Input.pressed(slot, "map") or G.Input.pressed(slot, "pause") then
      G.State.pop()
      if G.Audio then G.Audio.sfx("menuback") end
      return
    end
    if G.Input.pressed(slot, "jump") then self:setZoom(self.zoom + 1) end
    if G.Input.pressed(slot, "fire") then self:setZoom(self.zoom - 1) end
    if G.Input.pressed(slot, "util") then
      self:fit()
      if G.Audio then G.Audio.sfx("menumove") end
    end
    if G.Input.down(slot, "left") then dx = dx - 1 end
    if G.Input.down(slot, "right") then dx = dx + 1 end
    if G.Input.down(slot, "up") then dy = dy - 1 end
    if G.Input.down(slot, "down") then dy = dy + 1 end
  end
  if dx ~= 0 or dy ~= 0 then
    local sp = PAN_SPEED / c * dt
    self.cx = self.cx + dx * sp
    self.cy = self.cy + dy * sp
    self:clampView()
  end
end

function S:setZoom(z)
  z = math.max(1, math.min(#ZOOMS, z))
  if z == self.zoom then return end
  self.zoom = z
  self:clampView()
  if G.Audio then G.Audio.sfx("menumove") end
end

-- ------------------------------------------------------------------
-- draw
-- ------------------------------------------------------------------
local function edgePoint(r, tx, ty)
  -- where a line toward (tx,ty) leaves room r's rect, in cell space
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  local dx, dy = tx - cx, ty - cy
  if dx == 0 and dy == 0 then return cx, cy end
  local sx = dx ~= 0 and (r.w / 2) / math.abs(dx) or math.huge
  local sy = dy ~= 0 and (r.h / 2) / math.abs(dy) or math.huge
  local s = math.min(sx, sy)
  return cx + dx * s, cy + dy * s
end

-- do these two boxes share a wall? returns "H"/"V" and the point on the
-- shared wall, in cell space
local function sharedWall(a, b)
  local ov = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
  if ov > 0 then
    local my = (math.max(a.y, b.y) + math.min(a.y + a.h, b.y + b.h)) / 2
    if b.x == a.x + a.w then return "H", a.x + a.w, my, ov end
    if a.x == b.x + b.w then return "H", b.x + b.w, my, ov end
  end
  local ox = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
  if ox > 0 then
    local mx = (math.max(a.x, b.x) + math.min(a.x + a.w, b.x + b.w)) / 2
    if b.y == a.y + a.h then return "V", mx, a.y + a.h, ox end
    if a.y == b.y + b.h then return "V", mx, b.y + b.h, ox end
  end
  return nil
end

local function dashed(g, x1, y1, x2, y2, on, off)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.01 then return end
  local ux, uy = dx / len, dy / len
  local t = 0
  while t < len do
    local e = math.min(t + on, len)
    g.line(x1 + ux * t, y1 + uy * t, x1 + ux * e, y1 + uy * e)
    t = e + off
  end
end

function S:drawLinks(g)
  local c = self:cell()
  local sel = self.sel
  for _, cn in ipairs(self.conns) do
    local ra, rb = self.rooms[cn.a], self.rooms[cn.b]
    if ra and rb and ra.seen then
      local sealed = cn.req and not G.run.flags[cn.req]
      local hot = (cn.a == self.cur or cn.b == self.cur)
        or (sel and (cn.a == sel.id or cn.b == sel.id))
      if rb.seen then
        local kind, wx, wy, ov = sharedWall(ra, rb)
        if kind then
          -- neighbours: a notch in the shared wall, not a line
          local sx, sy = self:toScreen(wx, wy)
          local t = math.max(3, math.min(ov * c * 0.5, c * 0.6))
          if sealed then
            g.setColor(P.blood[1], P.blood[2], P.blood[3], 0.95)
          elseif hot then
            g.setColor(P.gold[1], P.gold[2], P.gold[3], 1)
          else
            g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
          end
          if kind == "H" then
            g.rectangle("fill", sx - 1.5, sy - t / 2, 3, t)
          else
            g.rectangle("fill", sx - t / 2, sy - 1.5, t, 3)
          end
        elseif hot or c >= 12 then
          -- a shaft or a boss lift. Drawn full-length only when it is
          -- one of YOURS -- drawing all seventeen at once is what made
          -- the old map look like a wiring diagram.
          local ax, ay = edgePoint(ra, rb.x + rb.w / 2, rb.y + rb.h / 2)
          local bx, by = edgePoint(rb, ra.x + ra.w / 2, ra.y + ra.h / 2)
          local sx, sy = self:toScreen(ax, ay)
          local ex, ey = self:toScreen(bx, by)
          if sealed then
            g.setColor(P.blood[1], P.blood[2], P.blood[3], hot and 0.9 or 0.35)
          elseif hot then
            g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.9)
          else
            g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.3)
          end
          dashed(g, sx, sy, ex, ey, 3, 3)
          if sealed then
            local mx, my = (sx + ex) / 2, (sy + ey) / 2
            g.setColor(P.blood)
            g.rectangle("fill", mx - 2, my - 2, 4, 4)
          end
        else
          self:stub(g, ra, rb, sealed and P.blood or P.silver, 0.55)
        end
      else
        -- an exit to somewhere you have not been: a stub, so the map
        -- says "there is more that way" instead of saying nothing
        self:stub(g, ra, rb, P.slate, 0.8)
      end
    end
  end
end

-- a short spur off a room's own wall, pointing at a partner it is not
-- touching. Says "a way out, that way" without crossing the whole atlas.
function S:stub(g, r, o, col, alpha)
  local c = self:cell()
  local ax, ay = edgePoint(r, o.x + o.w / 2, o.y + o.h / 2)
  local dx = (o.x + o.w / 2) - (r.x + r.w / 2)
  local dy = (o.y + o.h / 2) - (r.y + r.h / 2)
  local d = math.max(0.001, math.sqrt(dx * dx + dy * dy))
  local sx, sy = self:toScreen(ax, ay)
  local ex, ey = self:toScreen(ax + dx / d * 0.7, ay + dy / d * 0.7)
  g.setColor(col[1], col[2], col[3], alpha)
  g.line(sx, sy, ex, ey)
  g.circle("fill", ex, ey, math.max(1, c / 10))
end

-- one label per zone, over the rooms of it you have seen, and never on
-- top of a label already placed
function S:drawZoneLabels(g)
  local c = self:cell()
  if c < 6 then return end
  local names = {}
  for zone in pairs(self.zbox) do names[#names + 1] = zone end
  table.sort(names)
  local placed = {}
  -- a label must clear the other labels AND the room boxes; the old one
  -- checked neither, which is how ZONE names ended up printed across
  -- somebody else's rooms
  local boxes = {}
  for _, id in ipairs(self.order) do
    local r = self.rooms[id]
    if r.seen then
      local sx, sy = self:toScreen(r.x, r.y)
      if sx < VIEW.x + VIEW.w and sx + r.w * c > VIEW.x
        and sy < VIEW.y + VIEW.h and sy + r.h * c > VIEW.y then
        boxes[#boxes + 1] = { x = sx, y = sy, w = r.w * c, h = r.h * c }
      end
    end
  end
  local function fits(x, y, w)
    if y < VIEW.y - 2 or y + 8 > VIEW.y + VIEW.h then return false end
    for _, p in ipairs(placed) do
      if x < p.x + p.w + 2 and x + w + 2 > p.x
        and y < p.y + 8 and y + 8 > p.y then return false end
    end
    for _, b in ipairs(boxes) do
      if x < b.x + b.w and x + w > b.x
        and y < b.y + b.h and y + 8 > b.y then return false end
    end
    return true
  end
  for _, zone in ipairs(names) do
    local b = self.zbox[zone]
    local label = self.WM.ZONE_NAMES[zone] or zone
    local tw = G.fonts.main:getWidth(label)
    local mx = self:toScreen((b.x0 + b.x1) / 2, 0)
    local left = self:toScreen(b.x0, 0)
    local right = self:toScreen(b.x1, 0)
    local _, above = self:toScreen(0, b.y0)
    local _, below = self:toScreen(0, b.y1)
    above, below = math.floor(above) - 10, math.floor(below) + 2
    local lx, ly
    -- centred over the zone first, then shouldered off to either side,
    -- then under it. A dropped label is a zone with no name on the map,
    -- so it is worth trying six places before giving up on one.
    for _, cand in ipairs({
      { math.floor(mx - tw / 2), above },
      { math.floor(left), above },
      { math.floor(right - tw), above },
      { math.floor(mx - tw / 2), below },
      { math.floor(left), below },
      { math.floor(right - tw), below },
    }) do
      if not ly and fits(cand[1], cand[2], tw) then lx, ly = cand[1], cand[2] end
    end
    if ly then
      placed[#placed + 1] = { x = lx, y = ly, w = tw }
      local accent = P.zoneAccent[zone] or P.slate
      g.setColor(accent[1], accent[2], accent[3], 0.7)
      g.print(label, lx, ly)
    end
  end
end

function S:draw()
  local g = love.graphics
  local c = self:cell()
  self.sel = self:underCursor()
  g.setColor(P.black[1], P.black[2], P.black[3], 0.93)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  g.setFont(G.fonts.main)
  g.setColor(P.ember)
  g.printf("MAP OF THE DEEP", 0, 6, G.SW, "center")

  g.setScissor(VIEW.x, VIEW.y, VIEW.w, VIEW.h)

  self:drawLinks(g)

  for _, id in ipairs(self.order) do
    local r = self.rooms[id]
    if r.seen then
      local sx, sy = self:toScreen(r.x, r.y)
      local w, h = r.w * c - 1, r.h * c - 1
      local accent = P.zoneAccent[r.zone] or P.slate
      g.setColor(accent[1] * 0.35, accent[2] * 0.35, accent[3] * 0.35, 1)
      g.rectangle("fill", sx, sy, w, h)
      g.setColor(accent[1], accent[2], accent[3], 0.9)
      g.rectangle("line", sx + 0.5, sy + 0.5, w - 1, h - 1)
      if r.def.hasSave then
        g.setColor(P.gold)
        g.rectangle("fill", sx + 2, sy + 2, 2, 2)
      end
      if r.def.hasTeleporter and G.run.flags.telenet then
        g.setColor(P.cyan)
        g.rectangle("fill", sx + w - 4, sy + 2, 2, 2)
      end
      if r.def.arena then
        g.setColor(P.blood[1], P.blood[2], P.blood[3], 0.9)
        g.rectangle("fill", sx + w / 2 - 1, sy + h - 4, 2, 2)
      end
      -- the id only when it actually fits inside the box; printing it
      -- regardless is what had "deep_stair_1" lying across three rooms
      if c >= 12 then
        local short = id:match("_(.+)$") or id
        local tw = G.fonts.main:getWidth(short)
        if tw + 4 <= w then
          g.setColor(P.light[1], P.light[2], P.light[3], 0.7)
          g.print(short, sx + (w - tw) / 2, sy + h / 2 - 4)
        end
      end
      if self.sel == r then
        g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.9)
        g.rectangle("line", sx - 0.5, sy - 0.5, w + 1, h + 1)
      end
      if id == self.cur and math.floor(G.time * 3) % 2 == 0 then
        g.setColor(P.white)
        g.rectangle("fill", sx + w / 2 - 2, sy + h / 2 - 2, 4, 4)
      end
    end
  end

  self:drawZoneLabels(g)

  -- the crosshair: whatever sits under it is what the footer describes
  local hx, hy = VIEW.x + VIEW.w / 2, VIEW.y + VIEW.h / 2
  g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.85)
  g.line(hx - 5, hy, hx - 1, hy) g.line(hx + 1, hy, hx + 5, hy)
  g.line(hx, hy - 5, hx, hy - 1) g.line(hx, hy + 1, hx, hy + 5)
  g.setScissor()

  g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.6)
  g.rectangle("line", VIEW.x - 0.5, VIEW.y - 0.5, VIEW.w + 1, VIEW.h + 1)

  self:drawFooter(g)
  g.setColor(1, 1, 1, 1)
end

-- Cut a string to what will actually fit on one line. printf WRAPS, and
-- a wrapped exits list grows downward into the legend -- which is what it
-- was doing for any room with more than about four doors.
local function elide(g, text, maxW)
  local font = G.fonts.main
  if font:getWidth(text) <= maxW then return text end
  local lo, hi = 1, #text
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if font:getWidth(text:sub(1, mid) .. "..") <= maxW then lo = mid else hi = mid - 1 end
  end
  return text:sub(1, lo) .. ".."
end

function S:drawFooter(g)
  local sel = self.sel
  local WM = self.WM
  local y = VIEW.y + VIEW.h + 3
  if sel then
    local accent = P.zoneAccent[sel.zone] or P.slate
    g.setColor(accent)
    g.print(sel.id, 8, y)
    g.setColor(P.slate)
    -- MEASURED, not a fixed 74px column. Room ids run to fourteen
    -- characters -- "stair_junction" is one -- and at 6px a glyph that is
    -- 84px, so the zone name was printing straight through the tail of
    -- the longest names on the map.
    g.print(WM.ZONE_NAMES[sel.zone] or sel.zone,
      8 + G.fonts.main:getWidth(sel.id) + 10, y)
    -- what is it attached to? the question the old map could not answer.
    local parts = {}
    for ch, link in pairs(sel.def.links or {}) do
      local o = self.rooms[link[1]]
      local shown = (o and o.seen) and link[1] or "?"
      local mark = ""
      if link.req and not G.run.flags[link.req] then mark = " (sealed)" end
      parts[#parts + 1] = ch .. ":" .. shown .. mark
    end
    table.sort(parts)
    g.setColor(P.silver)
    g.print(elide(g, "exits  "
      .. (#parts > 0 and table.concat(parts, "   ") or "none"), G.SW - 16),
      8, y + 9)
  else
    g.setColor(P.slate)
    g.print("move the crosshair over a room to see its exits", 8, y)
  end
  g.setColor(P.gray)
  g.print(elide(g,
    "gold: save   cyan: teleporter   red: boss   notch: door   dashed: shaft",
    G.SW - 16), 8, y + 19)
  g.setColor(P.slate)
  g.print(elide(g, G.fmtButtons(
    "ARROWS/D-PAD pan   [JUMP] in   [FIRE] out   [UTIL] fit   [MAP] close"),
    G.SW - 16), 8, y + 28)
end

return S
