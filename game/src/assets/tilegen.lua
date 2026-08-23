-- Procedural tile + background generator, tinted per zone.
local P = require "src.assets.palette"

local TG = {}
local T = 16

local ZONES = {
  camp     = { base = "umber", dark = "soil", accent = "ember", cap = "brown",
               bg1 = "dark", bg2 = "shadow", sky1 = "black", sky2 = "dark" },
  mosswood = { base = "pine", dark = "soil", accent = "leaf", cap = "moss",
               bg1 = "dark", bg2 = "pine", sky1 = "black", sky2 = "dark" },
  flooded  = { base = "deepsea", dark = "navy", accent = "sky", cap = "teal",
               bg1 = "navy", bg2 = "deepsea", sky1 = "black", sky2 = "navy" },
  furnace  = { base = "maroon", dark = "soil", accent = "magma", cap = "rust",
               bg1 = "dark", bg2 = "maroon", sky1 = "black", sky2 = "maroon" },
  crystal  = { base = "gloom", dark = "dark", accent = "orchid", cap = "violet",
               bg1 = "dark", bg2 = "plum", sky1 = "black", sky2 = "gloom" },
  skyroot  = { base = "shadow", dark = "dark", accent = "sky", cap = "slate",
               bg1 = "navy", bg2 = "shadow", sky1 = "dark", sky2 = "navy" },
  core     = { base = "shadow", dark = "black", accent = "cyan", cap = "teal",
               bg1 = "black", bg2 = "dark", sky1 = "black", sky2 = "dark" },
  undergrove = { base = "soil", dark = "black", accent = "violet", cap = "plum",
               bg1 = "black", bg2 = "dark", sky1 = "black", sky2 = "black" },
  -- `strata` scales World:drawStrata for this zone only. The Coldstore
  -- reads as ICE, and ice is smooth: banding every deep tile the way the
  -- Scrapyard wants it made the walls look like sediment instead of a
  -- frozen face. It is a per-zone property because "how layered is the
  -- rock" is a fact about the rock, not a global preference.
  coldstore = { base = "slate", dark = "navy", accent = "ice", cap = "silver",
               bg1 = "navy", bg2 = "shadow", sky1 = "black", sky2 = "navy",
               strata = 0.35 },
  cradle   = { base = "gloom", dark = "black", accent = "ice", cap = "slate",
               bg1 = "black", bg2 = "dark", sky1 = "black", sky2 = "black" },
  scrapyard = { base = "shadow", dark = "black", accent = "slate", cap = "gray",
               bg1 = "black", bg2 = "dark", sky1 = "black", sky2 = "black" },
}
TG.ZONES = ZONES

local function mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t,
           a[3] + (b[3] - a[3]) * t, 1 }
end

local function solidTile(rng, zc)
  local d = love.image.newImageData(T, T)
  local base, dark = P[zc.base], P[zc.dark]
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      local c = base
      local n = rng:random()
      if n < 0.16 then c = mix(base, dark, 0.6)
      elseif n < 0.26 then c = mix(base, dark, 0.3)
      elseif n > 0.94 then c = mix(base, P[zc.cap], 0.25) end
      -- subtle brick seams
      if (y % 8 == 7 and rng:random() < 0.5) or (x % 8 == (y >= 8 and 3 or 7) and rng:random() < 0.3) then
        c = mix(c, dark, 0.5)
      end
      d:setPixel(x, y, c[1], c[2], c[3], 1)
    end
  end
  return d
end

local function capTile(rng, zc)
  -- exposed-top strip (moss/teal/etc), 16x4 drawn over solid tops
  local d = love.image.newImageData(T, 4)
  local cap = P[zc.cap]
  local acc = P[zc.accent]
  for x = 0, T - 1 do
    local h = 2 + (rng:random() < 0.4 and 1 or 0)
    for y = 0, 3 do
      if y < h then
        local c = (y == 0 and rng:random() < 0.5) and acc or cap
        d:setPixel(x, y, c[1], c[2], c[3], 1)
      else
        d:setPixel(x, y, 0, 0, 0, 0)
      end
    end
  end
  return d
end

local function onewayTile(zc)
  local d = love.image.newImageData(T, 6)
  local base, cap = P[zc.base], P[zc.cap]
  local dark = P[zc.dark]
  for x = 0, T - 1 do
    for y = 0, 5 do
      local c
      if y == 0 then c = cap
      elseif y <= 2 then c = base
      elseif y <= 3 and x % 4 ~= 0 then c = dark
      else c = nil end
      if c then d:setPixel(x, y, c[1], c[2], c[3], 1)
      else d:setPixel(x, y, 0, 0, 0, 0) end
    end
  end
  return d
end

local function spikeTile(zc)
  local d = love.image.newImageData(T, T)
  local base = P.silver
  local dark = P.gray
  for i = 0, 1 do
    local cx = i * 8
    for y = 0, 15 do
      for x = 0, 7 do
        local half = 8 - math.floor(y / 2)
        local lo = math.floor(y / 2) / 2
        local on = x >= math.floor((8 - (16 - y) / 2) / 2) -- fallback
        d:setPixel(cx + x, y, 0, 0, 0, 0)
      end
    end
  end
  -- simpler: two triangles, apex at top
  for y = 0, 15 do
    for x = 0, 15 do
      local lx = x % 8
      local spread = math.floor(y / 2.2)
      local on = lx >= 3 - math.floor(spread / 2) and lx <= 4 + math.floor(spread / 2)
      if on then
        local c = (lx <= 3) and base or dark
        d:setPixel(x, y, c[1], c[2], c[3], 1)
      end
    end
  end
  return d
end

local function breakableTile(rng, zc)
  local d = solidTile(rng, zc)
  local acc = P[zc.accent]
  -- cracked cross pattern
  for i = 0, 15 do
    local x1 = math.max(0, math.min(15, 8 + math.floor(math.sin(i * 1.7) * 3)))
    d:setPixel(x1, i, acc[1] * 0.6, acc[2] * 0.6, acc[3] * 0.6, 1)
    d:setPixel(i, math.max(0, math.min(15, 8 + math.floor(math.cos(i * 2.1) * 3))),
      acc[1] * 0.5, acc[2] * 0.5, acc[3] * 0.5, 1)
  end
  return d
end

local function crumbleTile(rng, zc)
  local d = solidTile(rng, zc)
  -- dotted look: punch holes
  for y = 0, 15 do
    for x = 0, 15 do
      if (x + y * 3) % 7 == 0 and rng:random() < 0.8 then
        d:setPixel(x, y, 0, 0, 0, 0)
      end
    end
  end
  return d
end

local function gateTile(zc)
  local d = love.image.newImageData(T, T)
  local a, b = P.slate, P.gray
  local acc = P[zc.accent]
  for y = 0, 15 do
    for x = 0, 15 do
      local c = ((math.floor(x / 4) + math.floor(y / 4)) % 2 == 0) and a or b
      if x == 0 or x == 15 or y == 0 or y == 15 then c = P.dark end
      if (x == 7 or x == 8) and (y == 7 or y == 8) then c = acc end
      d:setPixel(x, y, c[1], c[2], c[3], 1)
    end
  end
  return d
end

local function makeBgGlow(zone, zc)
  -- soft distant light spots, tileable (drawn with slowest parallax)
  local rng = love.math.newRandomGenerator(zone:byte(1) * 5477 + #zone * 13)
  local c = love.graphics.newCanvas(480, 270)
  love.graphics.setCanvas(c)
  love.graphics.clear(0, 0, 0, 0)
  local acc = P[zc.accent]
  for i = 1, 6 do
    local bx = rng:random(0, 480)
    local by = rng:random(30, 240)
    local r = rng:random(30, 70)
    for off = -480, 480, 480 do
      for k = 3, 1, -1 do
        love.graphics.setColor(acc[1], acc[2], acc[3], 0.022 * (4 - k))
        love.graphics.circle("fill", bx + off, by, r * k / 3)
      end
    end
  end
  love.graphics.setCanvas()
  love.graphics.setColor(1, 1, 1, 1)
  return c
end

local function makeBg(zone, zc)
  -- two parallax silhouette strips, tileable horizontally (480 wide)
  local rng = love.math.newRandomGenerator(zone:byte(1) * 7919 + #zone)
  local layers = {}
  for li = 1, 2 do
    local c = love.graphics.newCanvas(480, 270)
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    local col = P[li == 1 and zc.bg2 or zc.bg1]
    love.graphics.setColor(col[1], col[2], col[3], 1)
    local n = li == 1 and 7 or 10
    for i = 1, n do
      local bx = rng:random(0, 480)
      local bw = rng:random(40, 130)
      local bh = rng:random(60, 200)
      -- stalagmite from bottom and stalactite from top, drawn tileable
      for off = -480, 480, 480 do
        if rng:random() < 0.5 or li == 1 then
          love.graphics.polygon("fill", bx + off, 270, bx + bw + off, 270,
            bx + bw * 0.7 + off, 270 - bh, bx + bw * 0.3 + off, 270 - bh * 0.85)
        else
          love.graphics.polygon("fill", bx + off, 0, bx + bw + off, 0,
            bx + bw * 0.65 + off, bh * 0.8, bx + bw * 0.35 + off, bh)
        end
      end
    end
    love.graphics.setCanvas()
    layers[li] = c
  end
  love.graphics.setColor(1, 1, 1, 1)
  return layers
end

function TG.buildAll()
  G.tiles = {}
  -- soft vignette overlay (half-res, scaled up with linear filter)
  do
    local vw, vh = 240, 135
    local d = love.image.newImageData(vw, vh)
    for y = 0, vh - 1 do
      for x = 0, vw - 1 do
        local nx = (x / vw - 0.5) * 2
        local ny = (y / vh - 0.5) * 2
        local dist = math.sqrt(nx * nx + ny * ny)
        local a = math.max(0, (dist - 0.75)) * 0.55
        d:setPixel(x, y, 0, 0, 0, math.min(0.5, a))
      end
    end
    G.vignette = love.graphics.newImage(d)
    G.vignette:setFilter("linear", "linear")
  end
  for zone, zc in pairs(ZONES) do
    local rng = love.math.newRandomGenerator(#zone * 1013 + zone:byte(1))
    local set = {}
    set.solid = love.graphics.newImage(solidTile(rng, zc))
    set.solid2 = love.graphics.newImage(solidTile(rng, zc))
    set.cap = love.graphics.newImage(capTile(rng, zc))
    set.oneway = love.graphics.newImage(onewayTile(zc))
    set.spike = love.graphics.newImage(spikeTile(zc))
    set.breakable = love.graphics.newImage(breakableTile(rng, zc))
    set.crumble = love.graphics.newImage(crumbleTile(rng, zc))
    set.gate = love.graphics.newImage(gateTile(zc))
    set.bg = makeBg(zone, zc)
    set.bgGlow = makeBgGlow(zone, zc)
    set.conf = zc
    for _, img in pairs(set) do
      if type(img) == "userdata" and img.setFilter then img:setFilter("nearest", "nearest") end
    end
    G.tiles[zone] = set
  end
end

return TG
