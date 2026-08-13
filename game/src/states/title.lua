-- Title screen.
local P = require "src.assets.palette"
local Menu = require "src.ui.menu"

local S = { name = "title" }

function S:enter()
  self.t = 0
  self.started = false
  self.list = Menu.new({
    { label = "START", onConfirm = function()
      G.State.switch(require "src.states.saveselect")
    end },
    { label = "OPTIONS", onConfirm = function()
      G.State.push(require "src.states.options")
    end },
    { label = "TEST CHAMBER", onConfirm = function()
      G.State.push(require "src.states.testchamber")
    end },
    { label = "QUIT", onConfirm = function() love.event.quit() end },
  }, { y = 172, spacing = 15 })
  if G.Audio then G.Audio.playMusic("title") end
  -- decorative embers
  self.embers = {}
  for i = 1, 26 do
    self.embers[i] = { x = love.math.random(0, G.VW), y = love.math.random(0, G.VH),
      s = love.math.random() * 0.7 + 0.3 }
  end
end

function S:update(dt)
  self.t = self.t + dt
  for _, e in ipairs(self.embers) do
    e.y = e.y - dt * 14 * e.s
    e.x = e.x + math.sin(self.t * 1.2 + e.s * 9) * 0.3
    if e.y < -4 then
      e.y = G.VH + 4
      e.x = love.math.random(0, G.VW)
    end
  end
end

function S:menu(action)
  if not self.started then
    if action == "confirm" or action == "start" then
      self.started = true
      if G.Audio then G.Audio.sfx("menusel") end
    end
    return
  end
  if action == "cancel" then
    self.started = false
    return
  end
  self.list:menuEvent(action)
end

function S:draw()
  local g = love.graphics
  g.clear(P.black)

  -- distant cavern silhouettes
  if G.tiles and G.tiles.camp then
    g.setColor(1, 1, 1, 0.5)
    g.draw(G.tiles.camp.bg[1], 0, 0)
    g.setColor(1, 1, 1, 0.75)
    g.draw(G.tiles.camp.bg[2], 0, 0)
  end

  -- floating embers
  for _, e in ipairs(self.embers) do
    g.setColor(P.ember[1], P.ember[2], P.ember[3], 0.3 + e.s * 0.4)
    g.rectangle("fill", e.x, e.y, e.s > 0.7 and 2 or 1, e.s > 0.7 and 2 or 1)
  end

  -- the two bots by a lantern
  if G.sprites then
    G.drawSprite("prop_lantern", 2, G.VW / 2, 158)
    G.drawSprite("vess_idle", math.floor(self.t * 2) % 2 + 1, G.VW / 2 - 24, 158)
    G.drawSprite("lu_idle", math.floor(self.t * 2 + 1) % 2 + 1, G.VW / 2 + 24, 158,
      { flip = true })
  end

  g.setFont(G.fonts.main)
  g.setColor(P.dark)
  g.printf("E M B E R D E E P", 2, 62, math.floor(G.VW / 2), "center", 0, 2, 2)
  g.setColor(P.ember)
  g.printf("E M B E R D E E P", 0, 60, math.floor(G.VW / 2), "center", 0, 2, 2)
  g.setColor(P.slate)
  g.printf("a co-op cavern story", 0, 92, G.VW, "center")

  if not self.started then
    if math.floor(self.t * 2) % 2 == 0 then
      g.setColor(P.light)
      g.printf(G.anyPad() and "PRESS START" or "PRESS ENTER", 0, 190, G.VW, "center")
    end
  else
    self.list:draw()
  end

  g.setColor(P.gray)
  g.printf("v4.1", 0, G.VH - 12, G.VW - 6, "right")
  g.setColor(1, 1, 1, 1)
end

return S
