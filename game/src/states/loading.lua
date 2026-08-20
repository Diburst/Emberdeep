-- Boot loader: builds all procedural assets across frames with a progress bar.
local P = require "src.assets.palette"

local S = { name = "loading" }

function S:enter()
  self.steps = {}
  self.labels = {}
  local function add(label, fn)
    self.steps[#self.steps + 1] = fn
    self.labels[#self.labels + 1] = label
  end

  add("stoking the forge", function()
    require("src.assets.font").build()
  end)
  add("etching sprites", function()
    local ok, mod = pcall(require, "src.assets.spritegen")
    if ok then mod.buildAll() end
  end)
  add("cutting tiles", function()
    local ok, mod = pcall(require, "src.assets.tilegen")
    if ok then mod.buildAll() end
  end)
  add("tuning bells", function()
    local ok, mod = pcall(require, "src.audio.sfx")
    if ok then mod.buildAll() end
  end)
  -- music: one step per song so the bar moves
  local okm, Music = pcall(require, "src.audio.music")
  if okm then
    for _, song in ipairs(Music.songList()) do
      add("composing: " .. song, function() Music.render(song) end)
    end
  end
  add("waking the bots", function()
    local ok, world = pcall(require, "src.world")
    if ok and world.preload then world.preload() end
  end)

  self.i = 0
  self.total = #self.steps
  self.err = nil
end

function S:update(dt)
  if self.err then return end
  local start = love.timer.getTime()
  -- run steps until we've spent ~12ms this frame
  while self.i < self.total and love.timer.getTime() - start < 0.012 do
    self.i = self.i + 1
    local ok, err = pcall(self.steps[self.i])
    if not ok then
      self.err = "load step '" .. self.labels[self.i] .. "': " .. tostring(err)
      error(self.err)
    end
    if self.i >= self.total then break end
  end
  if self.i >= self.total and not self.launched then
    self.launched = true
    -- Shot mode takes over here rather than at boot, because it needs the
    -- procedural sprites, tiles and fonts that these steps build. It must
    -- also return BEFORE the switch to title -- the switch would tear down
    -- the game state it just stood up.
    if G.shots then
      require("src.shots").init(G.shots)
      return
    end
    if G.test then
      require("src.test").run(G.test)
    end
    G.State.switch(require "src.states.title")
  end
end

function S:draw()
  local g = love.graphics
  g.clear(P.black)
  if G.fonts then
    g.setFont(G.fonts.main)
    g.setColor(P.ember)
    g.printf("E M B E R D E E P", 0, 110, G.SW, "center")
    g.setColor(P.slate)
    local label = self.labels[math.min(self.i + 1, self.total)] or ""
    g.printf(label, 0, 150, G.SW, "center")
  end
  -- progress bar
  local w, h = 180, 6
  local x, y = (G.SW - w) / 2, 136
  love.graphics.setColor(P.shadow)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(P.ember)
  local frac = self.total > 0 and (self.i / self.total) or 1
  love.graphics.rectangle("fill", x + 1, y + 1, (w - 2) * frac, h - 2)
end

return S
