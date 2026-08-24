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

-- ==================================================================
-- THE VERTICAL RULE  (COOP-PLAN 13.1-13.3)
-- ==================================================================
-- Horizontal separation is WALLED -- game.lua clamps the leading bot to
-- the frame, collision-aware, and the tether goes taut and bright at
-- exactly that point so the rule explains itself the first time you meet
-- it. Vertical separation is PERMITTED: a bot may be abandoned downward,
-- and twelve rooms let that happen just by falling down them.
--
-- Which is the problem this solves. Once the pair are further apart than
-- the frame is tall, the plain midpoint shows NEITHER of them -- it puts
-- the middle of the empty gap on screen. So when the upper bot runs out
-- of screen to climb into, the camera stops averaging and follows them.
--
-- THE TRIGGER IS POSITION, NOT GAP. A gap threshold flips every time the
-- two bots cross, which in normal play is constantly, and the frame
-- would jerk on every jump. "Pushing the top two tiles" cannot engage
-- until the upper bot is physically against the top edge, and it is
-- one-sided -- it only ever pulls the camera UP -- so it settles instead
-- of fighting the midpoint.
--
-- The arithmetic falls out rather than being tuned: with a midpoint
-- camera the constraint first bites at a separation of
-- 2 * (VH/2 - TOP_BAND) = 206px, which is 0.75 of the viewport -- the
-- co-op vertical budget checkcoop.py already audits, arrived at from the
-- other direction. Change TOP_BAND and you are changing that budget.
Cam.TOP_BAND = 32          -- two tiles of headroom above the upper bot

-- Boss arenas keep the plain midpoint (13.3). Favouring the top bot is
-- RIGHT for the four tower fights you climb toward -- Aerie Sentinel,
-- Mother Engine, Mycel Choir, the Conductor -- and WRONG for every
-- grounded boss: a hovering Lu would drag the frame upward and push the
-- Bramble Maw off the bottom of it. checksight.py proves boss visibility
-- against camY = clamp(centreY - VH/2, 0, roomH - VH), so this flag is
-- what keeps that proof true. world.lua clears it for any room with an
-- arena; do not set it anywhere else.
Cam.favourTop = true

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
  local topY = math.huge
  for _, p in ipairs(targets) do
    tx = tx + p.x + p.w / 2 + (p.lookahead or 0)
    ty = ty + p.y + p.h / 2
    n = n + 1
    local cy = p.y + p.h / 2
    if cy < topY then topY = cy end
  end
  if n == 0 then return end
  tx, ty = tx / n - G.VW / 2, ty / n - G.VH / 2

  -- 13.2: keep the upper bot TOP_BAND below the top edge, and never
  -- push the camera down to do it. See the note beside Cam.TOP_BAND.
  if Cam.favourTop and n > 1 then
    local lim = topY - Cam.TOP_BAND
    if ty > lim then ty = lim end
  end

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
    -- FLOAT shake. This used love.math.random(a, b)'s INTEGER overload,
    -- so the gentlest tremor the game could express was a whole world
    -- unit -- four screen pixels at RS=4, which is not a tremor.
    sx = (love.math.random() * 2 - 1) * Cam.shakeMag
    sy = (love.math.random() * 2 - 1) * Cam.shakeMag
  end
  -- Snap to the RENDER grid, not the world grid. Flooring to whole world
  -- units is what keeps pixel art crisp at RS=1, and is exactly what
  -- quantises every camera movement into RS-pixel jumps above it.
  local RS = G.RS or 1
  Cam.ox = math.floor((Cam.x + sx) * RS) / RS
  Cam.oy = math.floor((Cam.y + sy) * RS) / RS
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

-- A POINT test is wrong for anything bigger than a point, and the entity
-- draw loop was using one on the top-left corner. An updraft's origin is
-- the TOP of its column -- twelve tiles up, 192px -- so standing at the
-- bottom of one put its corner far outside the margin and the whole
-- column vanished. It came back the moment a jump nudged the camera up,
-- which is exactly what a corner test looks like from the chair.
--
-- Anything tall or wide had the same bug latent in it: a boss, a long
-- platform, a beam. Test the box.
function Cam.boxOnScreen(x, y, w, h, margin)
  margin = margin or 32
  return x + (w or 0) > Cam.x - margin and x < Cam.x + G.VW + margin
    and y + (h or 0) > Cam.y - margin and y < Cam.y + G.VH + margin
end

return Cam
