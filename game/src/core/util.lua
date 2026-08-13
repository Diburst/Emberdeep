-- Shared utility functions.
local U = {}

function U.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function U.lerp(a, b, t) return a + (b - a) * t end

function U.sign(v)
  if v > 0 then return 1 elseif v < 0 then return -1 end
  return 0
end

-- Move v toward target by at most amount.
function U.approach(v, target, amount)
  if v < target then return math.min(v + amount, target) end
  if v > target then return math.max(v - amount, target) end
  return v
end

function U.round(v) return math.floor(v + 0.5) end

function U.dist(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function U.dist2(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return dx * dx + dy * dy
end

function U.aabb(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

function U.copy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local r = {}
  seen[t] = r
  for k, v in pairs(t) do r[U.copy(k, seen)] = U.copy(v, seen) end
  return r
end

function U.merge(dst, src)
  for k, v in pairs(src) do dst[k] = v end
  return dst
end

function U.choose(list) return list[love.math.random(#list)] end

function U.rand(lo, hi) return lo + love.math.random() * (hi - lo) end

function U.chance(p) return love.math.random() < p end

function U.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function U.indexOf(list, v)
  for i = 1, #list do if list[i] == v then return i end end
  return nil
end

function U.removeValue(list, v)
  local i = U.indexOf(list, v)
  if i then table.remove(list, i) end
end

function U.split(s, sep)
  local out = {}
  for piece in string.gmatch(s, "([^" .. sep .. "]+)") do
    out[#out + 1] = piece
  end
  return out
end

function U.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Shortest-arc angle difference.
function U.angleDiff(a, b)
  local d = (b - a) % (math.pi * 2)
  if d > math.pi then d = d - math.pi * 2 end
  return d
end

function U.formatTime(seconds)
  seconds = math.floor(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = seconds % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

return U
