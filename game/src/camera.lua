-- Camera: follows the players' midpoint, clamped to room bounds,
-- with lookahead, smoothing and screen shake.
local U = require "src.core.util"

local Cam = {}
Cam.x, Cam.y = 0, 0
-- The integer offset apply() last translated by, shake included. Anything
-- that has to line up with the world while drawing OUTSIDE the camera
-- transform (the darkness canvas) must use these, not Cam.x/Cam.y --
-- otherwise it drifts by the shake every time something explodes.
Cam.ox, Cam.oy = 0, 0
Cam.shakeT, Cam.shakeMag = 0, 0
Cam.roomW, Cam.roomH = 480, 270

function Cam.setRoom(wpx, hpx)
  Cam.roomW, Cam.roomH = wpx, hpx
end

function Cam.jumpTo(x, y)
  Cam.x = x - G.VW / 2
  Cam.y = y - G.VH / 2
  Cam.clamp()
end

function Cam.clamp()
  Cam.x = U.clamp(Cam.x, 0, math.max(0, Cam.roomW - G.VW))
  Cam.y = U.clamp(Cam.y, 0, math.max(0, Cam.roomH - G.VH))
  if Cam.roomW < G.VW then Cam.x = (Cam.roomW - G.VW) / 2 end
  if Cam.roomH < G.VH then Cam.y = (Cam.roomH - G.VH) / 2 end
end

function Cam.update(dt, targets)
  local tx, ty, n = 0, 0, 0
  for _, p in ipairs(targets) do
    tx = tx + p.x + p.w / 2 + (p.lookahead or 0)
    ty = ty + p.y + p.h / 2
    n = n + 1
  end
  if n == 0 then return end
  tx, ty = tx / n - G.VW / 2, ty / n - G.VH / 2

  local k = 1 - math.exp(-dt * 8)
  Cam.x = U.lerp(Cam.x, tx, k)
  Cam.y = U.lerp(Cam.y, ty, k)
  Cam.clamp()

  if Cam.shakeT > 0 then
    Cam.shakeT = Cam.shakeT - dt
  end
end

function Cam.shake(mag, dur)
  if not G.settings.shake then return end
  Cam.shakeMag = math.max(Cam.shakeMag * (Cam.shakeT > 0 and 1 or 0), mag)
  Cam.shakeT = math.max(Cam.shakeT, dur)
end

function Cam.apply()
  local sx, sy = 0, 0
  if Cam.shakeT > 0 then
    sx = love.math.random(-Cam.shakeMag, Cam.shakeMag)
    sy = love.math.random(-Cam.shakeMag, Cam.shakeMag)
  end
  Cam.ox = math.floor(Cam.x + sx)
  Cam.oy = math.floor(Cam.y + sy)
  love.graphics.push()
  love.graphics.translate(-Cam.ox, -Cam.oy)
end

function Cam.unapply()
  love.graphics.pop()
end

-- world -> screen
function Cam.toScreen(x, y)
  return x - Cam.x, y - Cam.y
end

function Cam.onScreen(x, y, margin)
  margin = margin or 32
  return x > Cam.x - margin and x < Cam.x + G.VW + margin
    and y > Cam.y - margin and y < Cam.y + G.VH + margin
end

return Cam
