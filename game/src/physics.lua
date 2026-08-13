-- Tile-based AABB platformer physics.
-- Entities: x, y (top-left), w, h, vx, vy plus flags set here:
--   onGround, hitWall, hitCeil, inWater, onOneway, groundTile
local U = require "src.core.util"

local PH = {}
local T = 16

-- Tile solidity queries are answered by the world module via these callbacks,
-- set on PH.world at room load.
PH.world = nil

local function solidAt(tx, ty, ent)
  return PH.world:isSolid(tx, ty, ent)
end

local function onewayAt(tx, ty)
  return PH.world:isOneway(tx, ty)
end

-- Move entity by (dx, dy) with collision resolution. Returns collided sides.
function PH.move(ent, dx, dy)
  local world = PH.world
  ent.hitWall = false
  ent.hitCeil = false
  local wasOnGround = ent.onGround
  ent.onGround = false
  ent.onOneway = false

  -- X axis ------------------------------------------------------------
  local nx = ent.x + dx
  if dx ~= 0 then
    local dir = dx > 0 and 1 or -1
    local edge = dir > 0 and (nx + ent.w) or nx
    local tx = math.floor(edge / T)
    local ty0 = math.floor(ent.y / T)
    local ty1 = math.floor((ent.y + ent.h - 0.001) / T)
    local blocked = false
    for ty = ty0, ty1 do
      if solidAt(tx, ty, ent) then blocked = true break end
    end
    if blocked then
      if dir > 0 then nx = tx * T - ent.w - 0.001 else nx = (tx + 1) * T + 0.001 end
      ent.hitWall = dir
      ent.vx = 0
    end
  end
  ent.x = nx

  -- Y axis ------------------------------------------------------------
  local ny = ent.y + dy
  if dy ~= 0 then
    local dir = dy > 0 and 1 or -1
    local edge = dir > 0 and (ny + ent.h) or ny
    local ty = math.floor(edge / T)
    local tx0 = math.floor(ent.x / T)
    local tx1 = math.floor((ent.x + ent.w - 0.001) / T)
    local blocked = false
    local onewayLanding = false
    for tx = tx0, tx1 do
      if solidAt(tx, ty, ent) then
        blocked = true
        break
      end
    end
    -- one-way platforms: only when moving down, feet were above the top
    if not blocked and dir > 0 and not ent.dropThrough then
      local platTop = ty * T
      if ent.y + ent.h <= platTop + 0.5 then
        for tx = tx0, tx1 do
          if onewayAt(tx, ty) then
            blocked = true
            onewayLanding = true
            break
          end
        end
      end
    end
    if blocked then
      if dir > 0 then
        ny = ty * T - ent.h - 0.001
        ent.onGround = true
        ent.onOneway = onewayLanding
        ent.groundTX, ent.groundTY = math.floor((ent.x + ent.w / 2) / T), ty
      else
        ny = (ty + 1) * T + 0.001
        ent.hitCeil = true
      end
      ent.vy = 0
    end
  end
  ent.y = ny

  -- environment flags --------------------------------------------------
  local cx = math.floor((ent.x + ent.w / 2) / T)
  local cy = math.floor((ent.y + ent.h / 2) / T)
  ent.inWater = world:isWater(cx, cy)
  ent.inLava = world:isLava(cx, math.floor((ent.y + ent.h - 2) / T))
    or world:isLava(cx, cy)

  ent.justLanded = ent.onGround and not wasOnGround
  return ent
end

-- Standing-on-ground check without moving (for coyote frames after walking off)
function PH.groundBelow(ent)
  local ty = math.floor((ent.y + ent.h + 1) / T)
  local tx0 = math.floor(ent.x / T)
  local tx1 = math.floor((ent.x + ent.w - 0.001) / T)
  for tx = tx0, tx1 do
    if solidAt(tx, ty, ent) then return true end
    if onewayAt(tx, ty) and (ent.y + ent.h) <= ty * T + 0.5 then return true end
  end
  return false
end

-- Simple raycast through tiles (for line of sight); returns true if clear.
function PH.lineOfSight(x1, y1, x2, y2)
  local steps = math.ceil(U.dist(x1, y1, x2, y2) / (T / 2))
  if steps == 0 then return true end
  for i = 0, steps do
    local t = i / steps
    local x = U.lerp(x1, x2, t)
    local y = U.lerp(y1, y2, t)
    if PH.world:isSolid(math.floor(x / T), math.floor(y / T)) then
      return false
    end
  end
  return true
end

-- Does an AABB overlap any solid tile?
function PH.boxBlocked(x, y, w, h)
  local tx0, tx1 = math.floor(x / T), math.floor((x + w - 0.001) / T)
  local ty0, ty1 = math.floor(y / T), math.floor((y + h - 0.001) / T)
  for ty = ty0, ty1 do
    for tx = tx0, tx1 do
      if PH.world:isSolid(tx, ty) then return true end
    end
  end
  return false
end

return PH
