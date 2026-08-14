-- World: room loading, tile queries, entity management, particles,
-- transitions, drawing. The heart of the in-game simulation.
local U = require "src.core.util"
local PH = require "src.physics"
local Cam = require "src.camera"
local Entity = require "src.entities.entity"

local T = 16

local World = {
  room = nil,
  w = 0, h = 0,          -- in tiles
  tiles = {},            -- [ty][tx] = code
  entities = {},
  addQueue = {},
  players = {},          -- player entities present
  particles = {},
  doors = {},            -- char -> {x0,y0,x1,y1 (tiles), edge=side or nil}
  crumbles = {},         -- idx -> {state}
  broken = {},           -- idx -> true (breakables destroyed this visit)
  pendingTransition = nil,
  fxTimer = 0,
}

-- tile codes
local AIR, SOLID, ONEWAY, SPIKE_U, SPIKE_D, SPIKE_L, SPIKE_R, WATER, LAVA,
  BREAK, CRUMBLE, GATE = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
World.codes = { AIR = AIR, SOLID = SOLID, ONEWAY = ONEWAY, WATER = WATER,
  LAVA = LAVA, BREAK = BREAK, CRUMBLE = CRUMBLE, GATE = GATE }

local CHAR_TILE = {
  ["#"] = SOLID, ["."] = AIR, ["="] = ONEWAY,
  ["^"] = SPIKE_U, ["v"] = SPIKE_D, ["<"] = SPIKE_L, [">"] = SPIKE_R,
  ["~"] = WATER, ["L"] = LAVA, ["%"] = BREAK, ["c"] = CRUMBLE,
}

local DOOR_CHARS = { A = true, B = true, C = true, D = true, E = true, F = true }
local GATE_CHARS = { G = true, H = true, I = true, J = true }

function World.preload()
  -- register every entity type
  require "src.entities.projectile"
  require "src.entities.pickup"
  require "src.entities.props"
  require "src.entities.npc"
  require "src.entities.enemies"
  require "src.entities.bosses"
end

local function idx(tx, ty) return ty * 4096 + tx end

-- ------------------------------------------------------------------
-- Queries (physics interface)
-- ------------------------------------------------------------------
function World:tileAt(tx, ty)
  if tx < 0 or ty < 0 or tx >= self.w or ty >= self.h then return SOLID end
  return self.tiles[ty][tx]
end

function World:isSolid(tx, ty, ent)
  local c = self:tileAt(tx, ty)
  if c == SOLID then return true end
  if c == BREAK then return not self.broken[idx(tx, ty)] end
  if c == CRUMBLE then
    local st = self.crumbles[idx(tx, ty)]
    return not (st and st.gone)
  end
  if c == GATE then
    local flag = self.gateFlags and self.gateFlags[idx(tx, ty)]
    if not flag or not G.run then return true end
    local inverted = flag:sub(1, 1) == "!"
    local set = G.run.flags[inverted and flag:sub(2) or flag]
    if inverted then
      return set and true or false -- energy bridge: solid only while powered
    end
    return not set
  end
  return false
end

function World:isOneway(tx, ty)
  return self:tileAt(tx, ty) == ONEWAY
end

function World:isWater(tx, ty)
  if self:tileAt(tx, ty) == WATER then return true end
  -- boss-controlled dynamic water line (Tide Engine)
  if self.waterLine and (ty + 1) * 16 > self.waterLine then
    return self:tileAt(tx, ty) == AIR
  end
  return false
end

function World:isLava(tx, ty)
  return self:tileAt(tx, ty) == LAVA
end

function World:spikeAt(tx, ty)
  local c = self:tileAt(tx, ty)
  return c >= SPIKE_U and c <= SPIKE_R
end

-- ------------------------------------------------------------------
-- Room loading
-- ------------------------------------------------------------------
local roomCache = {}
function World.getRoomDef(id)
  if not roomCache[id] then
    roomCache[id] = require("src.data.rooms." .. id)
    roomCache[id].id = id
  end
  return roomCache[id]
end

function World:load(roomId, doorChar, keepPlayers)
  local def = World.getRoomDef(roomId)
  self.room = def
  self.zone = def.zone
  self.entities = {}
  self.addQueue = {}
  self.particles = {}
  self.doors = {}
  self.crumbles = {}
  self.broken = {}
  self.gateFlags = {}
  self.pendingTransition = nil
  self.bossActive = nil

  -- parse grid
  local lines = {}
  for line in def.map:gmatch("[^\n]+") do
    if #line > 0 then lines[#lines + 1] = line end
  end
  self.h = #lines
  self.w = #lines[1]
  self.tiles = {}
  local spawnsByChar = {}
  for ty = 0, self.h - 1 do
    self.tiles[ty] = {}
    local line = lines[ty + 1]
    if #line ~= self.w then
      error(roomId .. ": row " .. (ty + 1) .. " width " .. #line .. " ~= " .. self.w)
    end
    for tx = 0, self.w - 1 do
      local ch = line:sub(tx + 1, tx + 2 - 1)
      local code = CHAR_TILE[ch]
      if code then
        self.tiles[ty][tx] = code
      elseif DOOR_CHARS[ch] then
        self.tiles[ty][tx] = AIR
        local d = self.doors[ch]
        if not d then
          d = { x0 = tx, y0 = ty, x1 = tx, y1 = ty }
          self.doors[ch] = d
        else
          d.x0, d.y0 = math.min(d.x0, tx), math.min(d.y0, ty)
          d.x1, d.y1 = math.max(d.x1, tx), math.max(d.y1, ty)
        end
      elseif GATE_CHARS[ch] then
        self.tiles[ty][tx] = GATE
        local flag = def.gates and def.gates[ch]
        self.gateFlags[idx(tx, ty)] = flag or ("gate_" .. roomId .. "_" .. ch)
      else
        -- entity spawn char
        self.tiles[ty][tx] = AIR
        spawnsByChar[#spawnsByChar + 1] = { ch = ch, tx = tx, ty = ty }
      end
    end
  end

  -- water/lava settle: entity-spawn cells inside a liquid body become
  -- liquid (no floating air bubbles where a fish or chest was placed)
  for _ = 1, 3 do
    for ty = 0, self.h - 1 do
      for tx = 0, self.w - 1 do
        if self.tiles[ty][tx] == AIR then
          local above = ty > 0 and self.tiles[ty - 1][tx] or SOLID
          local left = tx > 0 and self.tiles[ty][tx - 1] or SOLID
          local right = tx < self.w - 1 and self.tiles[ty][tx + 1] or SOLID
          if above == WATER or (left == WATER and right == WATER) then
            self.tiles[ty][tx] = WATER
          elseif above == LAVA or (left == LAVA and right == LAVA) then
            self.tiles[ty][tx] = LAVA
          end
        end
      end
    end
  end

  -- decorations: seeded per room, drawn behind entities
  local drng = love.math.newRandomGenerator(#roomId * 7349 + (roomId:byte(1) or 65) * 131)
  self.decor = {}
  for ty = 0, self.h - 1 do
    for tx = 0, self.w - 1 do
      if self.tiles[ty][tx] == SOLID then
        local above = self:tileAt(tx, ty - 1)
        if above == AIR and drng:random() < 0.4 then
          self.decor[#self.decor + 1] = {
            kind = "floor", x = tx * 16 + drng:random(1, 9), y = ty * 16,
            v = drng:random(3), ph = drng:random() * 6.28,
            s = 0.7 + drng:random() * 0.7,
          }
        end
        local below = self:tileAt(tx, ty + 1)
        if below == AIR and drng:random() < 0.2 then
          self.decor[#self.decor + 1] = {
            kind = "ceil", x = tx * 16 + drng:random(2, 12), y = (ty + 1) * 16,
            v = drng:random(3), ph = drng:random() * 6.28,
            s = 0.7 + drng:random() * 0.8,
          }
        end
      end
    end
  end

  -- water depth per tile (for depth-shaded rendering)
  self.waterDepth = {}
  for tx = 0, self.w - 1 do
    local depth = 0
    for ty = 0, self.h - 1 do
      if self.tiles[ty][tx] == WATER then
        depth = depth + 1
        self.waterDepth[idx(tx, ty)] = depth
      else
        depth = 0
      end
    end
  end

  -- classify doors (edge if touching boundary)
  for ch, d in pairs(self.doors) do
    if d.x0 == 0 then d.edge = "left"
    elseif d.x1 == self.w - 1 then d.edge = "right"
    elseif d.y0 == 0 then d.edge = "top"
    elseif d.y1 == self.h - 1 then d.edge = "bottom" end
    d.link = def.links and def.links[ch]
  end

  -- spawn entities
  for _, s in ipairs(spawnsByChar) do
    local spec = def.key and def.key[s.ch]
    if spec then
      self:spawnFromSpec(spec, s.tx, s.ty)
    else
      error(roomId .. ": unmapped map char '" .. s.ch .. "' at " ..
        s.tx .. "," .. s.ty)
    end
  end

  -- persistent boss remains: uncollected reward drops + corpses live in
  -- the run, so they survive leaving the zone, saving, and reloading
  if G.run then
    for _, d in ipairs((G.run.pendingDrops or {})[roomId] or {}) do
      local e = Entity.make("reward", d.x, d.y, { "reward", d.spec })
      if e and e ~= true then self.entities[#self.entities + 1] = e end
    end
    for bossId, c in pairs(G.run.bossCorpses or {}) do
      if c.room == roomId then
        local e = Entity.make("bosscorpse", c.x, c.y, { "bosscorpse", bossId })
        if e and e ~= true then self.entities[#self.entities + 1] = e end
      end
    end
  end

  Cam.setRoom(self.w * T, self.h * T)
  PH.world = self

  -- position players at the entry door
  self.spawnFixed = nil
  if keepPlayers and #self.players > 0 then
    local d = doorChar and self.doors[doorChar]
    for i, p in ipairs(self.players) do
      self.entities[#self.entities + 1] = p
      if d then
        local px = (d.x0 + (d.x1 - d.x0) / 2) * T + T / 2 - p.w / 2
        local py = (d.y1 + 1) * T - p.h - 0.5
        if d.edge == "left" then px = (d.x1 + 1) * T + 2 + (i - 1) * 4
        elseif d.edge == "right" then px = d.x0 * T - p.w - 2 - (i - 1) * 4
        elseif d.edge == "top" then py = (d.y1 + 1) * T + 2
        elseif d.edge == "bottom" then
          -- arriving up out of a floor shaft: climb the shaft to its mouth
          -- and stand on solid ground BESIDE the opening, never hovering
          -- over the hole we came from
          py = d.y0 * T - p.h - 2
          local best, bestRow
          for standRow = d.y0 - 1, math.max(2, d.y0 - 9), -1 do
            for off = 0, 4 do
              for _, dir in ipairs({ -1, 1 }) do
                local tx = (dir < 0 and d.x0 - 1 - off or d.x1 + 1 + off)
                if tx >= 1 and tx < self.w - 1 then
                  -- the walk-back corridor toward the shaft must be open:
                  -- footing on the far side of a wall or closed gate is a
                  -- sealed pocket, not an arrival spot
                  local corridor = true
                  local edge = (dir < 0 and d.x0 - 1 or d.x1 + 1)
                  local step = (dir < 0 and 1 or -1)
                  local cx = tx + step
                  while corridor and ((dir < 0 and cx <= edge)
                      or (dir > 0 and cx >= edge)) do
                    if self:isSolid(cx, standRow) then corridor = false end
                    cx = cx + step
                  end
                  if corridor
                    and self:isSolid(tx, standRow) == false
                    and (self:isSolid(tx, standRow + 1) or self:isOneway(tx, standRow + 1))
                    and not self:isSolid(tx, standRow - 1)
                    and not self:isLava(tx, standRow)
                    and not self:isWater(tx, standRow)
                    and not self:spikeAt(tx, standRow) then
                    best, bestRow = tx, standRow
                    break
                  end
                end
              end
              if best then break end
            end
            if best then break end
          end
          if best then
            px = best * T + (T - p.w) / 2
            py = bestRow * T + T - p.h - 0.5
          end
        end
        p.x = px + (i - 1) * 6
        p.y = py
        p.vx, p.vy = 0, 0
        if d.edge == "top" then p.vy = 40 end
        -- grace: the door we arrived through cannot re-trigger until the
        -- player has fully left its rectangle once
        p.doorGrace = doorChar
      end
      if not d then
        -- doorless load (teleport-style): coordinates from the previous
        -- room may be meaningless here -- clamp into this room first
        -- (the caller is expected to reposition, e.g. onto a telepad)
        p.x = math.max(T + 2, math.min(p.x, self.w * T - T - 2 - p.w))
        p.y = math.max(T + 2, math.min(p.y, self.h * T - T - 2 - p.h))
      end
      -- safety net: never leave a player embedded in solid tiles.
      local PH2 = require "src.physics"
      if PH2.boxBlocked(p.x, p.y, p.w, p.h) then
        local placed = self:ensureFree(p)
        self.spawnFixed = (self.spawnFixed or "") .. (doorChar or "?") .. i
          .. (placed and "" or "!")
      end
      p.roomEnterProtect = 0.3
    end
    local p1 = self.players[1]
    if p1 then Cam.jumpTo(p1.x, p1.y) end
  end

  -- mark visited for map
  if G.run then
    G.run.visited[roomId] = true
    G.run.room = roomId
    G.run.door = doorChar
  end

  -- music
  if def.music and G.Audio then G.Audio.playMusic(def.music) end

  if def.onEnter then def.onEnter(self) end
end

-- Can a player standing at tile (tx, ty) reach any linked door from
-- there? Tile BFS through non-solid cells (gates honor current flags).
-- Used to refuse respawn/arrival spots inside sealed pockets.
function World:canEscape(tx, ty)
  local doorTiles = {}
  local any = false
  for ch, d in pairs(self.doors) do
    if d.link then
      any = true
      for yy = d.y0, d.y1 do
        for xx = d.x0, d.x1 do
          doorTiles[yy * 1000 + xx] = true
        end
      end
    end
  end
  if not any then return true end
  local seen = { [ty * 1000 + tx] = true }
  local q = { { tx, ty } }
  local head, n = 1, 1
  while head <= n and n < 800 do
    local cx, cy = q[head][1], q[head][2]
    head = head + 1
    if doorTiles[cy * 1000 + cx] then return true end
    for _, dxy in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, ny = cx + dxy[1], cy + dxy[2]
      local key = ny * 1000 + nx
      if nx >= 0 and ny >= 0 and nx < self.w and ny < self.h
          and not seen[key] and not self:isSolid(nx, ny) then
        seen[key] = true
        n = n + 1
        q[n] = { nx, ny }
      end
    end
  end
  return false
end

-- Relocate an entity out of solid terrain: spiral search (favoring up,
-- then sideways) for the nearest free spot. Used by door spawns AND any
-- teleport-style verb (warp-to-partner, recall) so nobody is ever left
-- embedded in a wall. Returns true if the entity ends up in free space.
function World:ensureFree(p)
  local PH2 = require "src.physics"
  if not PH2.boxBlocked(p.x, p.y, p.w, p.h) then return true end
  local candidates = {}
  for r = 1, 8 do
    for dy = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          candidates[#candidates + 1] = { dx = dx, dy = dy,
            score = r * 10 + (dy > 0 and 5 or 0) }
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return a.score < b.score end)
  for _, c in ipairs(candidates) do
    local nx, ny = p.x + c.dx * T, p.y + c.dy * T
    if nx > 0 and ny > 0 and nx + p.w < self.w * T and ny + p.h < self.h * T
      and not PH2.boxBlocked(nx, ny, p.w, p.h) then
      p.x, p.y = nx, ny
      return true
    end
  end
  return false
end

function World:spawnFromSpec(spec, tx, ty)
  local parts = U.split(spec, ":")
  local name = parts[1]
  local x, y = tx * T, ty * T
  local ent, err = Entity.make(name, x, y, parts)
  if not ent then error((self.room and self.room.id or "?") .. ": " .. err) end
  if ent ~= true then self:add(ent) end
  return ent
end

function World:add(ent)
  self.addQueue[#self.addQueue + 1] = ent
  return ent
end

function World:setPlayers(players)
  self.players = players
end

-- ------------------------------------------------------------------
-- Update
-- ------------------------------------------------------------------
function World:update(dt)
  -- flush add queue
  for _, e in ipairs(self.addQueue) do
    self.entities[#self.entities + 1] = e
  end
  self.addQueue = {}

  -- crumble timers
  for i, st in pairs(self.crumbles) do
    if st.t then
      st.t = st.t - dt
      if st.t <= 0 and not st.gone then
        st.gone = true
        st.respawn = 4
        local tx, ty = i % 4096, math.floor(i / 4096)
        self:fx("burst", tx * T + 8, ty * T + 8, { color = "slate", n = 6 })
        if G.Audio then G.Audio.sfx("crumble") end
      end
    end
    if st.gone and st.respawn then
      st.respawn = st.respawn - dt
      if st.respawn <= 0 then
        -- only restore if nobody stands there
        local tx, ty = i % 4096, math.floor(i / 4096)
        local blocked = false
        for _, p in ipairs(self.players) do
          if U.aabb(p.x, p.y, p.w, p.h, tx * T, ty * T, T, T) then blocked = true end
        end
        if not blocked then
          st.gone = false
          st.t = nil
          st.respawn = nil
        else
          st.respawn = 0.5
        end
      end
    end
  end

  -- entities
  local n = #self.entities
  for i = 1, n do
    local e = self.entities[i]
    if not e.dead then
      if e.invuln and e.invuln > 0 then e.invuln = e.invuln - dt end
      if e.white and e.white > 0 then e.white = e.white - dt end
      e:update(dt)
    end
  end
  -- sweep dead
  for i = #self.entities, 1, -1 do
    if self.entities[i].dead then table.remove(self.entities, i) end
  end

  -- particles
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    p.t = p.t - dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + (p.grav or 0) * dt
    if p.t <= 0 then table.remove(self.particles, i) end
  end

  -- pressure plates OR together per flag
  local plateFlags = {}
  for _, e in ipairs(self.entities) do
    if e.kind == "plate" and not e.latch and not e.dead then
      plateFlags[e.flag] = (plateFlags[e.flag] or false) or (e.pressT > 0)
    end
  end
  for f, v in pairs(plateFlags) do
    G.run.flags[f] = v or nil
  end

  self:ambient(dt)
end

function World:startCrumble(tx, ty)
  local i = idx(tx, ty)
  if self:tileAt(tx, ty) == CRUMBLE then
    local st = self.crumbles[i]
    if not st then
      self.crumbles[i] = { t = 0.45 }
      if G.Audio then G.Audio.sfx("crack") end
    end
  end
end

function World:breakTile(tx, ty)
  if self:tileAt(tx, ty) == BREAK and not self.broken[idx(tx, ty)] then
    self.broken[idx(tx, ty)] = true
    self:fx("burst", tx * T + 8, ty * T + 8, { color = "slate", n = 8 })
    if G.Audio then G.Audio.sfx("break") end
    return true
  end
  return false
end

-- entities of a class within box
function World:query(x, y, w, h, filter)
  local out = {}
  for _, e in ipairs(self.entities) do
    if not e.dead and (not filter or filter(e)) then
      if U.aabb(x, y, w, h, e.x, e.y, e.w, e.h) then
        out[#out + 1] = e
      end
    end
  end
  return out
end

function World:each(kind, fn)
  for _, e in ipairs(self.entities) do
    if not e.dead and e.kind == kind then fn(e) end
  end
end

function World:nearestPlayer(x, y)
  local best, bd
  for _, p in ipairs(self.players) do
    if not p.dead and not p.downed and not p.idle then
      local d = U.dist2(x, y, p.x + p.w / 2, p.y + p.h / 2)
      if not bd or d < bd then best, bd = p, d end
    end
  end
  return best, best and math.sqrt(bd) or math.huge
end

function World:alivePlayers()
  local out = {}
  for _, p in ipairs(self.players) do
    if not p.dead and not p.downed then out[#out + 1] = p end
  end
  return out
end

-- ------------------------------------------------------------------
-- Particles / ambient
-- ------------------------------------------------------------------
local P = require "src.assets.palette"

function World:fx(kind, x, y, opts)
  opts = opts or {}
  if kind == "burst" then
    local col = P[opts.color or "white"]
    for i = 1, opts.n or 8 do
      local a = U.rand(0, math.pi * 2)
      local s = U.rand(30, opts.speed or 90)
      self.particles[#self.particles + 1] = {
        x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s,
        t = U.rand(0.2, 0.5), col = col, r = U.rand(1, 2.5), grav = 200,
      }
    end
  elseif kind == "puff" then
    local col = P[opts.color or "slate"]
    for i = 1, opts.n or 4 do
      self.particles[#self.particles + 1] = {
        x = x + U.rand(-3, 3), y = y + U.rand(-2, 2),
        vx = U.rand(-15, 15), vy = U.rand(-30, -5),
        t = U.rand(0.25, 0.5), col = col, r = U.rand(1.5, 3),
      }
    end
  elseif kind == "spark" then
    local col = P[opts.color or "spark"]
    for i = 1, opts.n or 5 do
      local a = (opts.angle or 0) + U.rand(-0.6, 0.6)
      local s = U.rand(60, 160)
      self.particles[#self.particles + 1] = {
        x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s,
        t = U.rand(0.1, 0.28), col = col, r = U.rand(0.8, 1.6),
      }
    end
  elseif kind == "splash" then
    for i = 1, 10 do
      self.particles[#self.particles + 1] = {
        x = x + U.rand(-6, 6), y = y, vx = U.rand(-40, 40), vy = U.rand(-120, -40),
        t = U.rand(0.3, 0.6), col = P.sky, r = U.rand(1, 2), grav = 400,
      }
    end
  elseif kind == "heal" then
    for i = 1, 8 do
      self.particles[#self.particles + 1] = {
        x = x + U.rand(-8, 8), y = y + U.rand(-4, 8),
        vx = 0, vy = U.rand(-50, -25),
        t = U.rand(0.4, 0.7), col = P.leaf, r = U.rand(1, 2),
      }
    end
  elseif kind == "trail" then
    self.particles[#self.particles + 1] = {
      x = x, y = y, vx = 0, vy = 0, t = opts.t or 0.2,
      col = P[opts.color or "spark"], r = opts.r or 2,
    }
  end
end

function World:ambient(dt)
  self.fxTimer = self.fxTimer - dt
  if self.fxTimer > 0 then return end
  self.fxTimer = 0.12
  local zone = self.zone
  local x = Cam.x + U.rand(0, G.VW)
  local y = Cam.y + U.rand(0, G.VH)
  -- mended zones exhale slow golden motes
  if self:zoneMended() and U.chance(0.25) then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = U.rand(-3, 3),
      vy = U.rand(-8, -3), t = U.rand(1.5, 3), col = P.gold, r = 1 }
  end
  -- the frozen camp snows, gently, forever
  if self:zoneFrozen() then
    self.particles[#self.particles + 1] = { x = x, y = Cam.y - 4,
      vx = U.rand(-6, 6), vy = U.rand(12, 26), t = U.rand(2, 4),
      col = P.ice, r = 1 }
  end
  if zone == "mosswood" then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = U.rand(-6, 6),
      vy = U.rand(4, 12), t = U.rand(1.5, 3), col = P.leaf, r = 1 }
  elseif zone == "furnace" then
    self.particles[#self.particles + 1] = { x = x, y = Cam.y + G.VH + 4,
      vx = U.rand(-8, 8), vy = U.rand(-35, -15), t = U.rand(1, 2.4),
      col = U.chance(0.3) and P.hotcore or P.ember, r = U.rand(0.8, 1.6) }
  elseif zone == "crystal" then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = 0, vy = 0,
      t = U.rand(0.3, 0.9), col = U.chance(0.5) and P.orchid or P.spark, r = 1 }
  elseif zone == "flooded" then
    local tx, ty = math.floor(x / T), math.floor(y / T)
    if self:isWater(tx, ty) then
      self.particles[#self.particles + 1] = { x = x, y = y, vx = 0,
        vy = U.rand(-18, -8), t = U.rand(0.8, 1.6), col = P.ice, r = 1 }
    end
  elseif zone == "skyroot" then
    self.particles[#self.particles + 1] = { x = Cam.x - 4, y = y,
      vx = U.rand(35, 70), vy = U.rand(-4, 4), t = U.rand(1.5, 3),
      col = P.slate, r = 1 }
  elseif zone == "core" then
    self.particles[#self.particles + 1] = { x = x, y = y, vx = 0,
      vy = U.rand(-10, -4), t = U.rand(0.5, 1.2), col = P.cyan, r = 1 }
  end
end

-- ------------------------------------------------------------------
-- Drawing
-- ------------------------------------------------------------------
function World:draw()
  local g = love.graphics
  local set = G.tiles[self.zone] or G.tiles.camp
  local zc = set.conf

  -- background gradient
  local c1, c2 = P[zc.sky1], P[zc.sky2]
  for i = 0, 8 do
    local t = i / 8
    g.setColor(U.lerp(c1[1], c2[1], t), U.lerp(c1[2], c2[2], t), U.lerp(c1[3], c2[3], t), 1)
    g.rectangle("fill", 0, i * (G.VH / 9), G.VW, G.VH / 9 + 1)
  end
  -- distant glow spots
  if set.bgGlow then
    g.setColor(1, 1, 1, 1)
    local off0 = -(Cam.x * 0.1) % 480
    g.draw(set.bgGlow, off0 - 480, 0)
    g.draw(set.bgGlow, off0, 0)
  end
  -- parallax silhouettes
  g.setColor(1, 1, 1, 0.55)
  local off1 = -(Cam.x * 0.25) % 480
  g.draw(set.bg[1], off1 - 480, 0)
  g.draw(set.bg[1], off1, 0)
  g.setColor(1, 1, 1, 0.8)
  local off2 = -(Cam.x * 0.5) % 480
  g.draw(set.bg[2], off2 - 480, 0)
  g.draw(set.bg[2], off2, 0)
  g.setColor(1, 1, 1, 1)

  -- boss arenas carry their own scenery (screen space, room-locked)
  if self.room and self.room.arena then
    self:drawArenaBackdrop(g, self.room.arena, -Cam.x, -Cam.y)
  end

  Cam.apply()

  -- tiles
  local tx0 = math.max(0, math.floor(Cam.x / T) - 1)
  local ty0 = math.max(0, math.floor(Cam.y / T) - 1)
  local tx1 = math.min(self.w - 1, math.floor((Cam.x + G.VW) / T) + 1)
  local ty1 = math.min(self.h - 1, math.floor((Cam.y + G.VH) / T) + 1)
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      local c = self.tiles[ty][tx]
      local px, py = tx * T, ty * T
      if c == SOLID or (c == BREAK and not self.broken[idx(tx, ty)]) then
        if c == SOLID then
          g.draw((tx * 7 + ty * 13) % 3 == 0 and set.solid2 or set.solid, px, py)
        else
          g.draw(set.breakable, px, py)
        end
        -- neighbor-aware shading
        local function hard(t2)
          return t2 == SOLID or t2 == BREAK or t2 == CRUMBLE or t2 == GATE
        end
        local above = self:tileAt(tx, ty - 1)
        local below = self:tileAt(tx, ty + 1)
        local left = self:tileAt(tx - 1, ty)
        local right = self:tileAt(tx + 1, ty)
        local upHard, dnHard = hard(above), hard(below)
        local lHard, rHard = hard(left), hard(right)
        if upHard and dnHard and lHard and rHard then
          -- fully enclosed: fake ambient occlusion
          g.setColor(0, 0, 0, 0.28)
          g.rectangle("fill", px, py, T, T)
          g.setColor(1, 1, 1, 1)
        else
          -- exposed rims
          if not lHard then
            g.setColor(1, 1, 1, 0.10)
            g.rectangle("fill", px, py, 1.5, T)
          end
          if not rHard then
            g.setColor(0, 0, 0, 0.22)
            g.rectangle("fill", px + T - 1.5, py, 1.5, T)
          end
          if not dnHard then
            g.setColor(0, 0, 0, 0.30)
            g.rectangle("fill", px, py + T - 2, T, 2)
          end
          g.setColor(1, 1, 1, 1)
        end
        -- exposed top cap
        if not upHard then
          g.draw(set.cap, px, py)
        end
      elseif c == CRUMBLE then
        local st = self.crumbles[idx(tx, ty)]
        if not (st and st.gone) then
          if st and st.t then
            g.push()
            g.translate(px + love.math.random(-1, 1), py)
            g.draw(set.crumble, 0, 0)
            g.pop()
          else
            g.draw(set.crumble, px, py)
          end
        end
      elseif c == GATE then
        local flag = self.gateFlags[idx(tx, ty)]
        local inverted = flag and flag:sub(1, 1) == "!"
        if inverted then
          if G.run and G.run.flags[flag:sub(2)] then
            -- energy bridge
            local pulse = 0.7 + math.sin(G.time * 6 + tx) * 0.2
            g.setColor(P.cyan[1], P.cyan[2], P.cyan[3], pulse)
            g.rectangle("fill", px, py + 2, T, 4)
            g.setColor(P.spark[1], P.spark[2], P.spark[3], pulse)
            g.rectangle("fill", px, py + 2, T, 1.5)
            g.setColor(1, 1, 1, 1)
          end
        elseif not (flag and G.run and G.run.flags[flag]) then
          g.draw(set.gate, px, py)
        end
      elseif c == ONEWAY then
        g.draw(set.oneway, px, py)
      elseif c == SPIKE_U then
        g.draw(set.spike, px, py)
      elseif c == SPIKE_D then
        g.draw(set.spike, px + T, py + T, math.pi)
      elseif c == SPIKE_L then
        g.draw(set.spike, px, py + T, -math.pi / 2)
      elseif c == SPIKE_R then
        g.draw(set.spike, px + T, py, math.pi / 2)
      elseif c == LAVA then
        local wob = math.sin(G.time * 3 + tx) * 1.5
        local isTop = self:tileAt(tx, ty - 1) ~= LAVA
        g.setColor(P.magma[1], P.magma[2], P.magma[3], 1)
        g.rectangle("fill", px, py + (isTop and (2 + wob) or 0), T, T - (isTop and (2 + wob) or 0))
        if isTop then
          g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], 1)
          g.rectangle("fill", px, py + 1 + wob, T, 2)
        end
        g.setColor(1, 1, 1, 1)
      end
    end
  end

  -- edge-door markers: a soft pulsing chevron pointing out of the room,
  -- so exits read at a glance
  for ch, d in pairs(self.doors) do
    if d.edge and d.link then
      local cx = (d.x0 + (d.x1 - d.x0 + 1) / 2) * T
      local cy = (d.y0 + (d.y1 - d.y0 + 1) / 2) * T
      local acc = P[set.conf.accent]
      local pulse = 0.45 + math.sin(G.time * 3 + d.x0) * 0.2
      local o = math.sin(G.time * 3 + d.x0) * 1.5
      g.setColor(acc[1], acc[2], acc[3], pulse)
      if d.edge == "left" then
        g.polygon("fill", cx + 4 - o, cy - 5, cx + 4 - o, cy + 5, cx - 1 - o, cy)
      elseif d.edge == "right" then
        g.polygon("fill", cx - 4 + o, cy - 5, cx - 4 + o, cy + 5, cx + 1 + o, cy)
      elseif d.edge == "top" then
        g.polygon("fill", cx - 5, cy + 4 - o, cx + 5, cy + 4 - o, cx, cy - 1 - o)
      else
        g.polygon("fill", cx - 5, cy - 4 + o, cx + 5, cy - 4 + o, cx, cy + 1 + o)
      end
      g.setColor(1, 1, 1, 1)
    end
  end

  -- portal door frames (edge doors are just openings)
  for ch, d in pairs(self.doors) do
    if not d.edge and d.link then
      local px = d.x0 * T
      local py = d.y0 * T
      local w = (d.x1 - d.x0 + 1) * T
      local h = (d.y1 - d.y0 + 1) * T
      local acc = P[set.conf.accent]
      g.setColor(P.black[1], P.black[2], P.black[3], 0.75)
      g.rectangle("fill", px + 2, py, w - 4, h)
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 1)
      g.rectangle("fill", px + 4, py + 3, w - 8, h - 3)
      g.setColor(acc[1], acc[2], acc[3], 0.9)
      g.rectangle("line", px + 2.5, py + 0.5, w - 5, h - 0.5)
      g.setColor(acc[1], acc[2], acc[3], 0.4 + math.sin(G.time * 3) * 0.2)
      g.rectangle("fill", px + w / 2 - 2, py + 2, 4, 2)
      g.setColor(1, 1, 1, 1)
    end
  end

  -- zone decorations (behind entities)
  self:drawDecor(g, tx0, ty0, tx1, ty1)

  -- entities by layer
  table.sort(self.entities, function(a, b) return (a.layer or 0) < (b.layer or 0) end)
  for _, e in ipairs(self.entities) do
    if not e.dead and Cam.onScreen(e.x, e.y, 64) then e:draw() end
  end

  -- dynamic water line overlay
  if self.waterLine then
    local wy = self.waterLine
    if wy < Cam.y + G.VH then
      g.setColor(P.water[1], P.water[2], P.water[3], 0.42)
      g.rectangle("fill", Cam.x, wy, G.VW, Cam.y + G.VH - wy)
      g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.8)
      for sx = 0, G.VW, 8 do
        local wob = math.sin(G.time * 2.5 + sx * 0.15) * 1.5
        g.rectangle("fill", Cam.x + sx, wy + wob, 8, 1.5)
      end
    end
  end

  -- water overlay (drawn over entities, darker with depth)
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      if self.tiles[ty][tx] == WATER then
        local px, py = tx * T, ty * T
        local isTop = self:tileAt(tx, ty - 1) ~= WATER
        local depth = self.waterDepth[idx(tx, ty)] or 1
        local a = math.min(0.62, 0.34 + depth * 0.035)
        g.setColor(P.water[1] * 0.9, P.water[2] * 0.9, P.water[3], a)
        if isTop then
          local wob = math.sin(G.time * 2.2 + tx * 0.8) * 1.5
          g.rectangle("fill", px, py + 3 + wob, T, T - 3 - wob)
          g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.8)
          g.rectangle("fill", px, py + 2 + wob, T, 1.5)
          -- surface sparkle
          if (tx * 31 + math.floor(G.time * 3)) % 7 == 0 then
            g.setColor(1, 1, 1, 0.5)
            g.rectangle("fill", px + (tx * 13 + math.floor(G.time * 8)) % 12, py + 2 + wob, 2, 1)
          end
        else
          g.rectangle("fill", px, py, T, T)
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)

  -- particles
  for _, p in ipairs(self.particles) do
    local a = math.min(1, p.t * 4)
    g.setColor(p.col[1], p.col[2], p.col[3], a)
    g.rectangle("fill", p.x - p.r / 2, p.y - p.r / 2, p.r, p.r)
  end
  g.setColor(1, 1, 1, 1)

  -- healed-zone warmth: once a zone's guardian falls, its air warms
  if self:zoneMended() then
    local warm = 0.05 + math.sin(G.time * 0.8) * 0.015
    g.setColor(1, 0.72, 0.4, warm)
    g.rectangle("fill", Cam.x, Cam.y, G.VW, G.VH)
    g.setColor(1, 1, 1, 1)
  end

  -- the frozen camp: after the Ember leaves, the cold owns this place
  if self:zoneFrozen() then
    g.setColor(0.55, 0.7, 0.95, 0.16)
    g.rectangle("fill", Cam.x, Cam.y, G.VW, G.VH)
    g.setColor(1, 1, 1, 1)
  end

  -- darkness overlay (dark rooms: the Undergrove)
  if self.room and self.room.dark then
    self:drawDarkness(g)
  end

  Cam.unapply()
end

-- A zone counts as "mended" once its guardian -- the Mender's mad
-- repair -- has been put down. Subtle, but the deep should feel it.
local MENDED_FLAG = {
  mosswood = "boss_bramblemaw", flooded = "boss_tideengine",
  furnace = "boss_crucible", crystal = "boss_prismtyrant",
  skyroot = "boss_aeriesentinel", undergrove = "boss_mycelchoir",
}
function World:zoneMended()
  local mf = MENDED_FLAG[self.zone]
  return mf and G.run and G.run.flags and G.run.flags[mf]
    and not self.bossActive
end

function World:zoneFrozen()
  return self.zone == "camp" and G.run and G.run.flags
    and (G.run.flags.ember_taken or G.run.flags.camp_frozen)
end

-- ------------------------------------------------------------------
-- Arena scenery: each boss room tells its owner's story behind the
-- fight. Drawn between the parallax layers and the tiles.
-- ------------------------------------------------------------------
function World:drawArenaBackdrop(g, arena, ox, oy)
  local W, H = self.w * T, self.h * T
  local floorY = H - 5 * T
  local function X(wx) return wx + ox end
  local function Y(wy) return wy + oy end

  if arena == "bramblemaw" then
    -- root columns and hanging growth: the untended orchard
    for i = 0, 5 do
      local rx = 60 + i * 150 + (i % 2) * 40
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.5)
      g.rectangle("fill", X(rx), Y(0), 10 + (i % 3) * 4, floorY + T)
      g.setColor(P.pine[1], P.pine[2], P.pine[3], 0.45)
      for v = 0, 3 do
        local vy = 20 + v * 34 + math.sin(G.time * 0.6 + i + v) * 3
        g.rectangle("fill", X(rx - 6 + v * 5), Y(vy), 2, 26)
      end
    end
  elseif arena == "rustwarden" then
    -- THE PUMP HALL: a wall of machinery the Warden never left.
    -- Back layer: three great pump bodies, pistons still breathing.
    for i = 0, 2 do
      local px = 90 + i * 260
      local stroke = math.sin(G.time * 0.7 + i * 2.1) * 9
      -- pump housing
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.55)
      g.rectangle("fill", X(px), Y(floorY - 118), 66, 118)
      g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.7)
      g.rectangle("fill", X(px + 6), Y(floorY - 112), 54, 44)
      -- piston cylinder + rod (the slow breath of the hall)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      g.rectangle("fill", X(px + 24), Y(floorY - 150), 18, 38)
      g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.55)
      g.rectangle("fill", X(px + 30), Y(floorY - 134 + stroke), 6, 26)
      -- flywheel, turning at a century's patience
      local wa = G.time * 0.5 + i
      g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.65)
      g.circle("line", X(px + 33), Y(floorY - 58), 22)
      g.circle("line", X(px + 33), Y(floorY - 58), 21)
      for s = 0, 2 do
        local a = wa + s * math.pi / 1.5
        g.line(X(px + 33 - math.cos(a) * 20), Y(floorY - 58 - math.sin(a) * 20),
          X(px + 33 + math.cos(a) * 20), Y(floorY - 58 + math.sin(a) * 20))
      end
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.8)
      g.circle("fill", X(px + 33), Y(floorY - 58), 4)
    end
    -- Mid layer: the mains. Three horizontal runs with flanges/elbows.
    for i = 0, 2 do
      local py = 30 + i * 34
      g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.75)
      g.rectangle("fill", X(0), Y(py), W, 9)
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.8)
      g.rectangle("fill", X(0), Y(py + 7), W, 2)
      for f = 0, 8 do
        local fx = 30 + f * 110 + i * 24
        g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.8)
        g.rectangle("fill", X(fx), Y(py - 2), 5, 13)
      end
    end
    -- risers dropping from the mains to the pumps
    g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.65)
    for i = 0, 4 do
      local rx = 60 + i * 190
      g.rectangle("fill", X(rx), Y(36), 7, floorY - 60)
    end
    -- Valve wheels: one still turns; the rest froze mid-turn.
    for i = 0, 3 do
      local vx2, vy2 = 63 + i * 190, 96 + (i % 2) * 44
      local spin = (i == 1) and G.time * 0.9 or (i * 1.3)
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.9)
      g.circle("line", X(vx2), Y(vy2), 9)
      for s = 0, 2 do
        local a = spin + s * math.pi / 1.5
        g.line(X(vx2 - math.cos(a) * 8), Y(vy2 - math.sin(a) * 8),
          X(vx2 + math.cos(a) * 8), Y(vy2 + math.sin(a) * 8))
      end
      g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.9)
      g.circle("fill", X(vx2), Y(vy2), 2.5)
    end
    -- Dial gauges: a bank of dead needles, and one that still twitches.
    for i = 0, 5 do
      local gx = 50 + i * 150
      local gy = 62 + (i % 3) * 10
      g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
      g.circle("fill", X(gx), Y(gy), 11)
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.9)
      g.circle("fill", X(gx), Y(gy), 9)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      for tick = -2, 2 do
        local a = math.pi * 0.75 + tick * 0.35
        g.line(X(gx + math.cos(a) * 7), Y(gy + math.sin(a) * 7),
          X(gx + math.cos(a) * 9), Y(gy + math.sin(a) * 9))
      end
      local na = math.pi * 0.75 + 1.4   -- dead: pinned at zero
      if i == 2 then                    -- one gauge still believes
        na = math.pi * 0.75 + 0.7 + math.sin(G.time * 6) * 0.12
        g.setColor(P.teal[1], P.teal[2], P.teal[3], 0.9)
      else
        g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.9)
      end
      g.line(X(gx), Y(gy), X(gx + math.cos(na) * 7), Y(gy + math.sin(na) * 7))
      g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.8)
      g.circle("fill", X(gx), Y(gy), 1.5)
    end
    -- a slow drip from a failed joint
    local dripY = (G.time * 40) % 120
    g.setColor(P.sky[1], P.sky[2], P.sky[3], 0.6)
    g.rectangle("fill", X(214), Y(64 + dripY), 2, 4)
  elseif arena == "tideengine" then
    -- drowned terraces: planter rows with green still trying
    for i = 0, 4 do
      local ty = 40 + i * 42
      g.setColor(P.deepsea[1], P.deepsea[2], P.deepsea[3], 0.5)
      g.rectangle("fill", X(30 + (i % 2) * 60), Y(ty), W - 120, 6)
      g.setColor(P.fern[1], P.fern[2], P.fern[3], 0.4)
      for px = 0, 8 do
        local wx = 50 + (i % 2) * 60 + px * 80
        g.rectangle("fill", X(wx), Y(ty - 6 + math.sin(G.time + px + i) * 1.5), 3, 6)
      end
    end
  elseif arena == "slaggolem" then
    -- THE CASTING FORGE: where the Golem remade itself, over and over.
    -- magma seams glowing through the back wall
    for i = 0, 4 do
      local sx2 = 30 + i * 130 + (i % 2) * 40
      local glow = 0.3 + math.sin(G.time * 1.6 + i * 1.7) * 0.12
      g.setColor(P.magma[1], P.magma[2], P.magma[3], glow)
      g.rectangle("fill", X(sx2), Y(20 + (i % 3) * 24), 3, floorY - 40)
      g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3], glow * 0.6)
      g.rectangle("fill", X(sx2 + 1), Y(30 + (i % 3) * 24), 1, floorY - 60)
    end
    -- the stamp press: a great ram that still falls on schedule
    local px = W / 2 - 30
    local cycle = (G.time * 0.5) % 1
    local ram = cycle < 0.12 and (cycle / 0.12) or
      (cycle < 0.2 and 1 or math.max(0, 1 - (cycle - 0.2) / 0.5))
    g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.8)
    g.rectangle("fill", X(px), Y(0), 12, 40)
    g.rectangle("fill", X(px + 48), Y(0), 12, 40)
    g.rectangle("fill", X(px - 4), Y(0), 68, 10)
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.8)
    g.rectangle("fill", X(px + 14), Y(10 + ram * 52), 32, 26)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.8)
    g.rectangle("fill", X(px + 22), Y(10), 16, ram * 52 + 2)
    -- the anvil block beneath it, and a fresh glowing cast
    g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.85)
    g.rectangle("fill", X(px + 10), Y(floorY - 22), 40, 22)
    g.setColor(P.hotcore[1], P.hotcore[2], P.hotcore[3],
      0.5 + (ram > 0.9 and 0.4 or 0))
    g.rectangle("fill", X(px + 20), Y(floorY - 26), 20, 5)
    -- casting molds: rows of ingot trays, some still glowing
    for i = 0, 5 do
      local mx = 40 + i * 90
      if mx < px - 50 or mx > px + 110 then
        g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.8)
        g.rectangle("fill", X(mx), Y(floorY - 10), 34, 10)
        for c2 = 0, 2 do
          local hot = (i + c2) % 3 == 0
          if hot then
            g.setColor(P.magma[1], P.magma[2], P.magma[3],
              0.5 + math.sin(G.time * 3 + i + c2) * 0.2)
          else
            g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.7)
          end
          g.rectangle("fill", X(mx + 3 + c2 * 10), Y(floorY - 8), 7, 5)
        end
      end
    end
    -- racks of metal stock: uprights with leaning billets
    for i = 0, 2 do
      local rx = 46 + i * 300
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.75)
      g.rectangle("fill", X(rx), Y(floorY - 74), 4, 74)
      g.rectangle("fill", X(rx + 40), Y(floorY - 74), 4, 74)
      g.rectangle("fill", X(rx - 2), Y(floorY - 74), 48, 4)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.7)
      for b2 = 0, 4 do
        g.rectangle("fill", X(rx + 5 + b2 * 7), Y(floorY - 66 + b2 * 2), 3,
          64 - b2 * 2)
      end
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.7)
      g.rectangle("fill", X(rx + 8), Y(floorY - 40), 30, 3)
    end
  elseif arena == "crucible" then
    -- the foundry heights: chimneys, chains, and part hoppers
    for i = 0, 3 do
      local cx2 = 70 + i * 150
      g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.5)
      g.rectangle("fill", X(cx2), Y(0), 22, 90 + (i % 2) * 30)
      g.setColor(P.magma[1], P.magma[2], P.magma[3],
        0.25 + math.sin(G.time * 2 + i) * 0.1)
      g.rectangle("fill", X(cx2 + 7), Y(84 + (i % 2) * 30), 8, 5)
    end
    g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.7)
    for i = 0, 5 do
      g.rectangle("fill", X(40 + i * 100), Y(0), 2, 46 + (i % 3) * 16)
      g.rectangle("fill", X(36 + i * 100), Y(44 + (i % 3) * 16), 10, 8)
    end
  elseif arena == "prismtyrant" then
    -- the crystal organ: a rank of singing shards
    for i = 0, 9 do
      local px = 40 + i * 88
      local ph = 60 + (i * 37) % 70
      local hum = math.sin(G.time * 1.5 + i) * 0.08
      g.setColor(P.plum[1], P.plum[2], P.plum[3], 0.5)
      g.polygon("fill", X(px), Y(floorY), X(px + 10), Y(floorY),
        X(px + 5), Y(floorY - ph))
      g.setColor(P.orchid[1], P.orchid[2], P.orchid[3], 0.3 + hum)
      g.polygon("line", X(px), Y(floorY), X(px + 10), Y(floorY),
        X(px + 5), Y(floorY - ph))
    end
  elseif arena == "aeriesentinel" then
    -- the sky door and the watch-perches
    g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.25)
    g.circle("line", X(W / 2), Y(30), 46)
    g.circle("line", X(W / 2), Y(30), 38)
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.5)
    for i = 0, 2 do
      g.rectangle("fill", X(80 + i * 260), Y(70 + i * 20), 60, 4)
      g.rectangle("fill", X(106 + i * 260), Y(74 + i * 20), 6, 30)
    end
  elseif arena == "mycelchoir" then
    -- fungal columns, listening
    for i = 0, 4 do
      local fx = 60 + i * 100
      g.setColor(P.plum[1], P.plum[2], P.plum[3], 0.45)
      g.rectangle("fill", X(fx), Y(floorY - 90 - (i % 2) * 30), 12, 90 + (i % 2) * 30 + T)
      g.setColor(P.violet[1], P.violet[2], P.violet[3], 0.4)
      g.ellipse("fill", X(fx + 6), Y(floorY - 92 - (i % 2) * 30), 16, 6)
    end
  elseif arena == "archivist" then
    -- the deep stacks, shelved to the dark
    for i = 0, 6 do
      local sx2 = 30 + i * 130
      g.setColor(P.navy[1], P.navy[2], P.navy[3], 0.5)
      g.rectangle("fill", X(sx2), Y(20), 36, floorY - 14)
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.4)
      for s = 0, 5 do
        g.rectangle("fill", X(sx2 + 3), Y(34 + s * 34), 30, 3)
      end
    end
  elseif arena == "motherengine" then
    -- the heart-wall: cable falls into the dark
    for i = 0, 8 do
      local cx2 = 40 + i * 88
      local sway = math.sin(G.time * 0.8 + i) * 3
      g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.75)
      g.rectangle("fill", X(cx2 + sway), Y(0), 4, floorY - 20 - (i % 3) * 30)
      g.setColor(P.cyan[1], P.cyan[2], P.cyan[3],
        0.2 + math.sin(G.time * 1.4 + i * 2) * 0.1)
      g.circle("fill", X(cx2 + 2 + sway), Y(floorY - 18 - (i % 3) * 30), 2.5)
    end

  -- ================================================================
  -- EMBER CAMP
  -- ================================================================
  elseif arena == "campshop" then
    -- JUN'S MAINTENANCE SHOP: a century of half-finished work. Pegboards,
    -- benches, cable runs, and a lathe he has not switched off in years.
    local base = H - 4 * T
    -- cable runs sagging along the back wall
    for i = 0, 3 do
      local yy = 40 + i * 22
      g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], 0.7)
      for seg = 0, 11 do
        local sx = 30 + seg * 50
        local sag = math.sin(seg * 0.9 + i) * 5 + 6
        g.line(X(sx), Y(yy), X(sx + 25), Y(yy + sag))
        g.line(X(sx + 25), Y(yy + sag), X(sx + 50), Y(yy))
      end
    end
    -- pegboards with tools hung in rows
    for b = 0, 2 do
      local bx = 70 + b * 190
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.55)
      g.rectangle("fill", X(bx), Y(52), 84, 54)
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.6)
      g.rectangle("line", X(bx), Y(52), 84, 54)
      for t = 0, 5 do
        local tx = bx + 8 + t * 13
        local hang = 10 + (t % 3) * 9
        g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.75)
        g.rectangle("fill", X(tx), Y(58), 2, hang)
        g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.7)
        if t % 3 == 0 then
          g.rectangle("fill", X(tx - 3), Y(58 + hang), 8, 4)     -- hammer head
        elseif t % 3 == 1 then
          g.circle("line", X(tx + 1), Y(58 + hang + 3), 4)       -- wrench eye
        else
          g.polygon("fill", X(tx - 2), Y(58 + hang), X(tx + 4), Y(58 + hang),
            X(tx + 1), Y(58 + hang + 6))                          -- pliers
        end
      end
    end
    -- benches, crates and a parts bin along the floor
    for b = 0, 4 do
      local bx = 40 + b * 130
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.8)
      g.rectangle("fill", X(bx), Y(base - 26), 96, 8)
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.85)
      g.rectangle("fill", X(bx + 6), Y(base - 18), 7, 18)
      g.rectangle("fill", X(bx + 83), Y(base - 18), 7, 18)
      -- clutter on top: jars, coils, a stub of pipe
      g.setColor(P.teal[1], P.teal[2], P.teal[3], 0.6)
      g.rectangle("fill", X(bx + 20), Y(base - 34), 8, 8)
      g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.7)
      g.circle("line", X(bx + 46), Y(base - 31), 6)
      g.circle("line", X(bx + 46), Y(base - 31), 3)
      g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.7)
      g.rectangle("fill", X(bx + 62), Y(base - 32), 18, 5)
    end
    -- the lathe, still turning
    local lx = 300
    g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], 0.9)
    g.rectangle("fill", X(lx), Y(base - 44), 70, 44)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.8)
    g.rectangle("fill", X(lx + 6), Y(base - 38), 58, 10)
    local spin = G.time * 3
    g.setColor(P.silver[1], P.silver[2], P.silver[3], 0.75)
    g.circle("line", X(lx + 14), Y(base - 33), 7)
    g.line(X(lx + 14 - math.cos(spin) * 6), Y(base - 33 - math.sin(spin) * 6),
      X(lx + 14 + math.cos(spin) * 6), Y(base - 33 + math.sin(spin) * 6))
    -- a work lamp over the bench, the only warm thing in here
    g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.5 + math.sin(G.time * 2) * 0.06)
    g.circle("fill", X(230), Y(70), 5)
    World.glow(X(230), Y(70), 54, P.gold, 0.16)

  elseif arena == "embercamp" then
    -- EMBER CAMP: a settlement, not a cave. Huts, crates, hammocks,
    -- drying lines and small lanterns -- all of it deliberately dimmer
    -- and smaller than the Ember burning at the middle of the room.
    local base = H - 5 * T
    local emberX = 37 * T
    -- back wall of the cavern, warmed unevenly by the great fire
    for i = 0, 9 do
      local px = 20 + i * 96
      local d = math.abs(px - emberX) / (W * 0.6)
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.30 - d * 0.16)
      g.rectangle("fill", X(px), Y(30), 70, base - 30)
    end
    -- huts: a big one on the left (the one you can enter), then smaller
    local huts = { { 150, 120, 78 }, { 330, 78, 52 }, { 620, 92, 58 },
                   { 760, 70, 46 }, { 890, 84, 54 } }
    for i, hut in ipairs(huts) do
      local hx, hw, hh = hut[1], hut[2], hut[3]
      local hy = base - hh
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.9)
      g.rectangle("fill", X(hx), Y(hy), hw, hh)
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.95)
      g.polygon("fill", X(hx - 8), Y(hy), X(hx + hw + 8), Y(hy),
        X(hx + hw / 2), Y(hy - 22))
      g.setColor(P.shadow[1], P.shadow[2], P.shadow[3], 0.8)
      for pl = 0, 3 do
        g.line(X(hx + 6 + pl * (hw / 4)), Y(hy), X(hx + 6 + pl * (hw / 4)), Y(hy + hh))
      end
      -- a lit window each, small and yellow
      g.setColor(P.gold[1], P.gold[2], P.gold[3],
        0.35 + math.sin(G.time * 1.3 + i * 2) * 0.07)
      g.rectangle("fill", X(hx + hw - 22), Y(hy + 14), 12, 10)
    end
    -- hammocks slung between the huts
    for i = 0, 2 do
      local ax = 250 + i * 230
      local sag = math.sin(G.time * 0.7 + i) * 2
      g.setColor(P.cream[1], P.cream[2], P.cream[3], 0.35)
      for seg = 0, 8 do
        local t1, t2 = seg / 8, (seg + 1) / 8
        local function hy(t) return base - 54 + math.sin(t * math.pi) * (14 + sag) end
        g.line(X(ax + t1 * 90), Y(hy(t1)), X(ax + t2 * 90), Y(hy(t2)))
      end
    end
    -- drying lines with cloth
    for i = 0, 1 do
      local ax = 420 + i * 300
      g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.5)
      g.line(X(ax), Y(base - 96), X(ax + 140), Y(base - 92))
      for c = 0, 4 do
        local cxx = ax + 14 + c * 26
        local flap = math.sin(G.time * 1.6 + c) * 2
        g.setColor(c % 2 == 0 and P.fern or P.maroon)
        g.rectangle("fill", X(cxx + flap), Y(base - 94 + c), 10, 16)
      end
    end
    -- crates, barrels and stacked equipment
    for i = 0, 11 do
      local bx = 60 + i * 78 + (i % 3) * 11
      local bh = 12 + (i % 3) * 7
      g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.85)
      g.rectangle("fill", X(bx), Y(base - bh), 20, bh)
      g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.9)
      g.rectangle("line", X(bx), Y(base - bh), 20, bh)
      if i % 4 == 0 then
        g.setColor(P.rust[1], P.rust[2], P.rust[3], 0.8)
        g.rectangle("fill", X(bx + 24), Y(base - 16), 12, 16, 3, 3)
      end
    end
    -- the small lanterns: deliberately modest next to the Ember
    for i = 0, 6 do
      local lx = 90 + i * 128
      if math.abs(lx - emberX) > 90 then
        local flick = 0.30 + math.sin(G.time * 2.4 + i * 1.7) * 0.06
        g.setColor(P.shadow)
        g.rectangle("fill", X(lx), Y(base - 60), 2, 26)
        g.setColor(P.ember[1], P.ember[2], P.ember[3], flick)
        g.circle("fill", X(lx + 1), Y(base - 62), 3)
        World.glow(X(lx + 1), Y(base - 62), 30, P.ember, 0.10)
      end
    end

  elseif arena == "camphut" then
    -- INSIDE THE LONG HUT: bunks, a stove, and everything the camp
    -- could not fit outdoors.
    local base = H - 5 * T
    g.setColor(P.soil[1], P.soil[2], P.soil[3], 0.55)
    g.rectangle("fill", X(0), Y(0), W, base)
    g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.8)
    for i = 0, 14 do
      g.rectangle("fill", X(i * 34), Y(0), 5, base)     -- wall timbers
    end
    -- bunks along the back
    for i = 0, 3 do
      local bx = 40 + i * 100
      for tier = 0, 1 do
        local by = base - 34 - tier * 30
        g.setColor(P.umber[1], P.umber[2], P.umber[3], 0.95)
        g.rectangle("fill", X(bx), Y(by), 74, 6)
        g.setColor(P.cream[1], P.cream[2], P.cream[3], 0.30)
        g.rectangle("fill", X(bx + 6), Y(by - 7), 62, 7)
        g.setColor(P.maroon[1], P.maroon[2], P.maroon[3], 0.55)
        g.rectangle("fill", X(bx + 44), Y(by - 9), 22, 9)
      end
    end
    -- the stove, small and warm
    local sx = W / 2 - 14
    g.setColor(P.shadow)
    g.rectangle("fill", X(sx), Y(base - 40), 28, 40, 3, 3)
    g.setColor(P.gray[1], P.gray[2], P.gray[3], 0.9)
    g.rectangle("fill", X(sx + 11), Y(base - 76), 6, 36)
    local flick = 0.5 + math.sin(G.time * 3.1) * 0.14
    g.setColor(P.ember[1], P.ember[2], P.ember[3], flick)
    g.rectangle("fill", X(sx + 7), Y(base - 26), 14, 10, 2, 2)
    World.glow(X(sx + 14), Y(base - 21), 52, P.ember, 0.16)
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- Darkness: dark rooms are wrapped in shadow; light radiates from Lu
-- (wider with the Lume Core / dome), from Vess faintly, and from any
-- entity that carries a lightR (glowmites, struck sporebulbs, the
-- singing choir throat, waypoint props).
-- ------------------------------------------------------------------
function World:drawDarkness(g)
  if not self.darkCanvas then
    self.darkCanvas = love.graphics.newCanvas(G.VW, G.VH)
  end
  local dark = math.min(0.96, self.room.dark or 0.85)
  local prev = g.getCanvas()
  g.setCanvas(self.darkCanvas)
  g.origin()
  g.clear(0, 0, 0, dark)
  g.setBlendMode("replace")
  local cx0, cy0 = math.floor(Cam.x), math.floor(Cam.y)
  local function hole(wx, wy, r)
    if r <= 0 then return end
    local sx, sy = wx - cx0, wy - cy0
    if sx < -r or sy < -r or sx > G.VW + r or sy > G.VH + r then return end
    g.setColor(0, 0, 0, dark * 0.55)
    g.circle("fill", sx, sy, r)
    g.setColor(0, 0, 0, dark * 0.22)
    g.circle("fill", sx, sy, r * 0.72)
    g.setColor(0, 0, 0, 0)
    g.circle("fill", sx, sy, r * 0.45)
  end
  for _, pl in ipairs(self.players) do
    if not pl.dead and not pl.idle then
      local r
      if pl.isVess then
        r = 34
      else
        r = G.run.flags.lumecore and 105 or 68
        if pl.domeActive then r = r + 22 end
      end
      hole(pl.x + pl.w / 2, pl.y + pl.h / 2, r)
    end
  end
  local PROP_GLOW = { save = 26, checkpoint = 24, teleporter = 30 }
  for _, e in ipairs(self.entities) do
    if not e.dead then
      if e.lightR then
        hole(e.x + e.w / 2, e.y + e.h / 2, e.lightR)
      elseif e.kind == "proj" and e.side == "player" then
        hole(e.x + e.w / 2, e.y + e.h / 2, 15)
      elseif PROP_GLOW[e.kind] then
        hole(e.x + e.w / 2, e.y + e.h / 2, PROP_GLOW[e.kind])
      elseif e.interactable then
        hole(e.x + e.w / 2, e.y + e.h / 2, 16)
      end
    end
  end
  g.setBlendMode("alpha")
  g.setCanvas(prev)
  g.setColor(1, 1, 1, 1)
  g.draw(self.darkCanvas, cx0, cy0)
end

-- ------------------------------------------------------------------
-- Zone decorations (code-drawn, seeded per room)
-- ------------------------------------------------------------------
function World.glow(x, y, r, col, a)
  local g = love.graphics
  g.setColor(col[1], col[2], col[3], a * 0.25)
  g.circle("fill", x, y, r)
  g.setColor(col[1], col[2], col[3], a * 0.35)
  g.circle("fill", x, y, r * 0.6)
  g.setColor(col[1], col[2], col[3], a * 0.5)
  g.circle("fill", x, y, r * 0.3)
  g.setColor(1, 1, 1, 1)
end

function World:drawDecor(g, tx0, ty0, tx1, ty1)
  if not self.decor then return end
  local zone = self.zone
  local x0, y0 = tx0 * T - 16, ty0 * T - 16
  local x1, y1 = tx1 * T + 32, ty1 * T + 32
  for _, d in ipairs(self.decor) do
    if d.x > x0 and d.x < x1 and d.y > y0 and d.y < y1 then
      local sway = math.sin(G.time * 1.6 + d.ph) * 1.2
      if d.kind == "floor" then
        if zone == "mosswood" or zone == "camp" then
          if d.v == 1 then -- grass tuft
            g.setColor(P.leaf)
            g.line(d.x, d.y, d.x - 1 + sway, d.y - 4 * d.s)
            g.line(d.x + 2, d.y, d.x + 2 + sway, d.y - 5 * d.s)
            g.setColor(P.fern)
            g.line(d.x + 4, d.y, d.x + 4 + sway, d.y - 3 * d.s)
          elseif d.v == 2 then -- little mushroom
            g.setColor(P.cream)
            g.rectangle("fill", d.x + 1, d.y - 3, 2, 3)
            g.setColor(zone == "camp" and P.ember or P.pink)
            g.rectangle("fill", d.x - 1, d.y - 5, 6, 3, 1, 1)
          else -- pebbles
            g.setColor(P.gray)
            g.rectangle("fill", d.x, d.y - 2, 3, 2)
            g.setColor(P.slate)
            g.rectangle("fill", d.x + 4, d.y - 1, 2, 1)
          end
        elseif zone == "flooded" then
          if d.v == 1 then -- kelp
            g.setColor(P.teal)
            g.line(d.x, d.y, d.x + sway, d.y - 6 * d.s, d.x - sway, d.y - 11 * d.s)
          elseif d.v == 2 then -- barnacles
            g.setColor(P.ice)
            g.circle("fill", d.x, d.y - 1, 1.4)
            g.circle("fill", d.x + 4, d.y - 1, 1.1)
          else
            g.setColor(P.deepsea)
            g.rectangle("fill", d.x, d.y - 3, 2, 3)
            g.rectangle("fill", d.x + 3, d.y - 2, 2, 2)
          end
        elseif zone == "furnace" then
          if d.v == 1 then -- glowing vent
            g.setColor(P.dark)
            g.rectangle("fill", d.x - 1, d.y - 2, 6, 2)
            local pulse = 0.4 + math.sin(G.time * 3 + d.ph) * 0.3
            g.setColor(P.magma[1], P.magma[2], P.magma[3], pulse)
            g.rectangle("fill", d.x, d.y - 1, 4, 1)
          elseif d.v == 2 then -- slag lump
            g.setColor(P.maroon)
            g.circle("fill", d.x + 1, d.y - 1, 2)
            g.setColor(P.rust)
            g.circle("fill", d.x + 3, d.y - 1, 1.3)
          else
            g.setColor(P.soil)
            g.rectangle("fill", d.x, d.y - 2, 4, 2)
          end
        elseif zone == "crystal" then
          if d.v <= 2 then -- crystal cluster
            local c1 = d.v == 1 and P.orchid or P.violet
            g.setColor(c1)
            g.polygon("fill", d.x, d.y, d.x + 2, d.y - 6 * d.s, d.x + 4, d.y)
            g.setColor(P.spark[1], P.spark[2], P.spark[3],
              0.5 + math.sin(G.time * 2 + d.ph) * 0.3)
            g.polygon("fill", d.x + 3, d.y, d.x + 4.5, d.y - 4 * d.s, d.x + 6, d.y)
          else
            g.setColor(P.gloom)
            g.rectangle("fill", d.x, d.y - 2, 3, 2)
          end
        elseif zone == "skyroot" then
          if d.v == 1 then -- root curl
            g.setColor(P.brown)
            g.line(d.x, d.y, d.x + 2 + sway, d.y - 5 * d.s, d.x + 5 + sway, d.y - 4 * d.s)
          elseif d.v == 2 then
            g.setColor(P.leaf)
            g.line(d.x, d.y, d.x + sway, d.y - 4 * d.s)
            g.line(d.x + 3, d.y, d.x + 3 + sway, d.y - 6 * d.s)
          else
            g.setColor(P.umber)
            g.rectangle("fill", d.x, d.y - 2, 4, 2)
          end
        elseif zone == "core" then
          if d.v == 1 then -- terminal with blinking light
            g.setColor(P.dark)
            g.rectangle("fill", d.x - 1, d.y - 4, 6, 4)
            local on = math.floor(G.time * 2 + d.ph) % 2 == 0
            g.setColor(on and P.cyan or P.teal)
            g.rectangle("fill", d.x + 1, d.y - 3, 2, 1)
          elseif d.v == 2 then -- cable stub
            g.setColor(P.shadow)
            g.line(d.x, d.y, d.x + 3, d.y - 3, d.x + 7, d.y - 2)
            g.setColor(P.cyan)
            g.circle("fill", d.x + 7, d.y - 2, 1)
          else
            g.setColor(P.gray)
            g.rectangle("fill", d.x, d.y - 1, 3, 1)
          end
        end
      else -- ceiling decor
        if zone == "mosswood" or zone == "camp" or zone == "skyroot" then
          g.setColor(P.fern)
          g.line(d.x, d.y, d.x + sway * 0.5, d.y + 5 * d.s, d.x + sway, d.y + 9 * d.s)
          g.setColor(P.leaf)
          g.circle("fill", d.x + sway, d.y + 9 * d.s, 1)
        elseif zone == "flooded" then
          g.setColor(P.teal)
          g.line(d.x, d.y, d.x, d.y + 3 * d.s)
          -- drip
          local dripT = (G.time * 0.7 + d.ph) % 2
          if dripT < 1 then
            g.setColor(P.sky[1], P.sky[2], P.sky[3], 0.8)
            g.rectangle("fill", d.x - 0.5, d.y + 3 + dripT * 22, 1, 2)
          end
        elseif zone == "furnace" then
          g.setColor(P.shadow)
          g.line(d.x, d.y, d.x, d.y + 6 * d.s)
          g.setColor(P.gray)
          g.circle("fill", d.x, d.y + 6 * d.s, 1)
        elseif zone == "crystal" then
          g.setColor(P.violet)
          g.polygon("fill", d.x - 2, d.y, d.x + 2, d.y, d.x, d.y + 6 * d.s)
        elseif zone == "core" then
          g.setColor(P.shadow)
          g.line(d.x, d.y, d.x + sway, d.y + 7 * d.s)
          g.setColor(P.blood[1], P.blood[2], P.blood[3],
            0.4 + math.sin(G.time * 4 + d.ph) * 0.3)
          g.circle("fill", d.x + sway, d.y + 7 * d.s, 1)
        end
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- ------------------------------------------------------------------
-- Transitions
-- ------------------------------------------------------------------
-- Called by player logic when standing at a portal door pressing up,
-- or automatically when overlapping an edge door.
function World:requestTransition(doorChar)
  local d = self.doors[doorChar]
  if not d or not d.link then return end
  if not self.pendingTransition then
    self.pendingTransition = { room = d.link[1], door = d.link[2] }
  end
end

function World:doorAt(x, y, w, h)
  for ch, d in pairs(self.doors) do
    if d.link and U.aabb(x, y, w, h,
      d.x0 * T, d.y0 * T, (d.x1 - d.x0 + 1) * T, (d.y1 - d.y0 + 1) * T) then
      return ch, d
    end
  end
  return nil
end

return World
