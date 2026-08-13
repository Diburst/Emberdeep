-- Sprite compiler: ASCII pixel-art definitions -> packed atlas + quads.
-- A sprite def:
--   { pal = { r = "vessred", ... },  -- char -> palette color name
--     frames = { {"..rr..", ...}, ... },
--     ox, oy }  -- draw origin (default: bottom-center)
local P = require "src.assets.palette"

local SG = {}

local SOURCES = {
  "src.assets.sprites.chars",
  "src.assets.sprites.props",
  "src.assets.sprites.enemies1",
  "src.assets.sprites.enemies2",
  "src.assets.sprites.bosses",
  "src.assets.sprites.npcs",
}

local whiteShader

function SG.buildAll()
  local defs = {}
  for _, path in ipairs(SOURCES) do
    local ok, mod = pcall(require, path)
    if ok and type(mod) == "table" then
      for name, def in pairs(mod) do
        if defs[name] then error("duplicate sprite: " .. name) end
        defs[name] = def
      end
    end
  end

  -- measure
  local entries = {}
  for name, def in pairs(defs) do
    local fh = #def.frames[1]
    local fw = #def.frames[1][1]
    for fi, fr in ipairs(def.frames) do
      if #fr ~= fh then error(name .. " frame " .. fi .. " height mismatch") end
      for _, row in ipairs(fr) do
        if #row ~= fw then
          error(name .. " frame " .. fi .. " row width mismatch (" .. #row .. " vs " .. fw .. ")")
        end
      end
    end
    entries[#entries + 1] = { name = name, def = def, w = fw, h = fh, n = #def.frames }
  end
  table.sort(entries, function(a, b)
    if a.h ~= b.h then return a.h > b.h end
    return a.name < b.name
  end)

  -- shelf pack
  local ATLAS_W = 1024
  local x, y, shelfH = 0, 0, 0
  local places = {}
  for _, e in ipairs(entries) do
    local totalW = (e.w + 1) * e.n
    if x + totalW > ATLAS_W and x > 0 then
      x = 0
      y = y + shelfH + 1
      shelfH = 0
    end
    places[e.name] = { x = x, y = y }
    x = x + totalW
    shelfH = math.max(shelfH, e.h)
  end
  local ATLAS_H = y + shelfH + 1

  local data = love.image.newImageData(ATLAS_W, ATLAS_H)
  local sprites = {}
  for _, e in ipairs(entries) do
    local def, place = e.def, places[e.name]
    -- resolve palette
    local pal = {}
    for ch, cname in pairs(def.pal or {}) do
      local c = P[cname]
      if not c then error("sprite " .. e.name .. ": unknown palette color " .. tostring(cname)) end
      pal[ch] = c
    end
    local quads = {}
    for fi, fr in ipairs(def.frames) do
      local fx = place.x + (fi - 1) * (e.w + 1)
      for ry = 1, e.h do
        local row = fr[ry]
        for rx = 1, e.w do
          local ch = row:sub(rx, rx)
          if ch ~= "." and ch ~= " " then
            local c = pal[ch]
            if not c then error("sprite " .. e.name .. ": unmapped char '" .. ch .. "'") end
            data:setPixel(fx + rx - 1, place.y + ry - 1, c[1], c[2], c[3], 1)
          end
        end
      end
      quads[fi] = { fx, place.y, e.w, e.h }
    end
    sprites[e.name] = {
      w = e.w, h = e.h, n = e.n,
      ox = def.ox or math.floor(e.w / 2),
      oy = def.oy or e.h,
      quads = quads,
    }
  end

  local img = love.graphics.newImage(data)
  img:setFilter("nearest", "nearest")
  local quadObjs = {}
  for name, s in pairs(sprites) do
    s.img = img
    for i, q in ipairs(s.quads) do
      s.quads[i] = love.graphics.newQuad(q[1], q[2], q[3], q[4], ATLAS_W, ATLAS_H)
    end
  end

  whiteShader = love.graphics.newShader([[
    uniform float whiteAmount;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
      vec4 px = Texel(tex, tc);
      px.rgb = mix(px.rgb, vec3(1.0), whiteAmount);
      return px * color;
    }
  ]])

  G.sprites = sprites
  G.spriteAtlas = img

  -- Draw with origin at bottom-center by default.
  -- opts: flip, rot, sx, sy, tint {r,g,b,a}, white (0..1), oy/ox override
  function G.drawSprite(name, frame, dx, dy, opts)
    local s = sprites[name]
    if not s then
      love.graphics.setColor(1, 0, 1, 1)
      love.graphics.rectangle("fill", dx - 4, dy - 8, 8, 8)
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    opts = opts or {}
    frame = ((frame - 1) % s.n) + 1
    local sx = (opts.sx or 1) * (opts.flip and -1 or 1)
    local sy = opts.sy or 1
    local t = opts.tint
    if t then love.graphics.setColor(t[1], t[2], t[3], t[4] or 1)
    else love.graphics.setColor(1, 1, 1, opts.alpha or 1) end
    if opts.white and opts.white > 0 then
      love.graphics.setShader(whiteShader)
      whiteShader:send("whiteAmount", math.min(1, opts.white))
    end
    love.graphics.draw(s.img, s.quads[frame],
      math.floor(dx), math.floor(dy), opts.rot or 0, sx, sy,
      opts.ox or s.ox, opts.oy or s.oy)
    if opts.white and opts.white > 0 then love.graphics.setShader() end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function G.spriteExists(name) return sprites[name] ~= nil end
end

return SG
