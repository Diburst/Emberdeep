-- In-game HUD: per-bot health/weapon panels, Lu energy, link meter, boss bar.
local P = require "src.assets.palette"
local U = require "src.core.util"
local Weapons = require "src.weapons"

local Hud = {}

local function drawBar(x, y, w, h, frac, colFill, colBack)
  local g = love.graphics
  g.setColor(colBack or P.shadow)
  g.rectangle("fill", x, y, w, h)
  g.setColor(colFill)
  g.rectangle("fill", x + 1, y + 1, math.max(0, (w - 2) * U.clamp(frac, 0, 1)), h - 2)
end

local function drawPlayerPanel(game, p, x, y, rightAlign)
  local g = love.graphics
  local font = G.fonts.main
  g.setFont(font)

  local name = p.isVess and "VESS" or "LU"
  local nameCol = p.isVess and P.vessred or P.lublue

  g.setColor(0, 0, 0, 0.45)
  g.rectangle("fill", x - 3, y - 3, 120, 38, 3, 3)

  -- portrait
  local portrait = p.isVess and "port_vess" or "port_lu"
  if G.spriteExists(portrait) then
    g.setColor(P.dark)
    g.rectangle("fill", x - 1, y - 1, 22, 22, 2, 2)
    G.drawSprite(portrait, 1, x + 10, y + 20, {})
    g.setColor(p.downed and P.blood or nameCol)
    g.rectangle("line", x - 1, y - 1, 22, 22, 2, 2)
    if p.downed then
      g.setColor(0, 0, 0, 0.55)
      g.rectangle("fill", x - 1, y - 1, 22, 22, 2, 2)
    end
  end
  x = x + 24

  g.setColor(nameCol)
  g.print(name, x, y)

  -- HP
  local hpx = x + 28
  drawBar(hpx, y + 1, 60, 6, p.hp / p.maxhp,
    p.hp <= p.maxhp * 0.25 and P.blood or P.leaf)
  g.setColor(P.light)
  g.print(math.max(0, math.ceil(p.hp)) .. "/" .. p.maxhp, hpx + 62 - 60, y + 8)

  -- weapon
  local ws = p:curWeaponState()
  if ws then
    local def = Weapons.get(ws.id)
    local lvl = Weapons.levelOf(ws)
    local wy = y + 16
    g.setColor(P.gold)
    g.print(def.name:sub(1, 1), x, wy)
    g.setColor(P.silver)
    g.print("Lv" .. lvl, x + 8, wy)
    -- forge tier pips (upgrades bought from Brassa with scrap)
    for t = 1, 3 do
      g.setColor(t <= lvl and P.gold or P.gray)
      g.rectangle("fill", x + 28 + (t - 1) * 9, wy + 2, 7, 4)
    end
    if lvl >= 3 then
      g.setColor(P.ember)
      g.print("MAX", x + 58, wy)
    end
  end

  -- Vess charge: a cooldown wedge plus what the charge currently IS.
  -- Grey wedge = mobility, lit wedge = a shield, chevron = an attack.
  if p.isVess and G.run.flags.bulwark then
    local cy2 = y + 25
    local ready = (p.dashCd or 0) <= 0
    local live = (p.bulwarkT or 0) > 0
    g.push() g.translate(x + 4, cy2 + 3)
    g.setColor(live and P.vesslite or (ready and P.vessred or P.gray))
    g.polygon("fill", -3, -4, 3, -2.5, 3, 2.5, -3, 4)
    g.pop()
    if G.run.flags.cinderram then
      g.setColor(ready and P.magma or P.gray)
      g.setLineWidth(1.5)
      g.line(x + 10, cy2 - 1, x + 13, cy2 + 3, x + 10, cy2 + 7)
      g.setLineWidth(1)
    end
    -- cooldown drains left to right, so it reads at a glance
    if not ready then
      drawBar(x + 18, cy2 + 1, 34, 3, 1 - (p.dashCd or 0) / 0.65, P.vessdark)
    end
  end

  -- Lu energy
  if not p.isVess then
    local ey = y + 24
    g.setColor(P.cyan)
    g.print("E", x, ey)
    drawBar(x + 28, ey + 1, 60, 5, p.energy / p.maxenergy,
      p.domeActive and P.spark or P.cyan)
  end

  -- downed indicator
  if p.downed then
    g.setColor(P.blood)
    g.print("DOWN " .. math.ceil(p.bleedout), x + 28, y + 8)
  end
  if p.idle then
    g.setColor(P.slate)
    g.print("standby", x + 44, y)
  end
  g.setColor(1, 1, 1, 1)
end

function Hud.draw(game)
  local g = love.graphics
  drawPlayerPanel(game, game.players[1], 8, 8)
  drawPlayerPanel(game, game.players[2], G.VW - 125, 8)

  -- link meter (center top) -- hidden until Maro switches the LINK on
  if G.run.flags.linkblast then
    local lm = game.linkMeter
    local x, w = G.VW / 2 - 30, 60
    g.setColor(0, 0, 0, 0.45)
    g.rectangle("fill", x - 2, 6, w + 4, 10, 2, 2)
    drawBar(x, 8, w, 6, lm, lm >= 1 and P.spark or P.teal)
    g.setFont(G.fonts.main)
    if lm >= 1 then
      if math.floor(G.time * 2) % 2 == 0 then
        g.setColor(P.spark)
        g.print("LINK READY", x + 6, 16)
      end
    end
  end

  -- scrap counter
  g.setColor(0, 0, 0, 0.45)
  g.rectangle("fill", G.VW / 2 - 24, G.VH - 16, 48, 12, 2, 2)
  g.setColor(P.silver)
  g.print("o " .. (G.run.scrap or 0), G.VW / 2 - 18, G.VH - 14)

  -- boss bar
  local World = require "src.world"
  if World.bossActive and not World.bossActive.dead then
    local b = World.bossActive
    local bw = 200
    local bx = (G.VW - bw) / 2
    g.setColor(0, 0, 0, 0.55)
    g.rectangle("fill", bx - 4, G.VH - 34, bw + 8, 22, 3, 3)
    g.setColor(P.blood)
    g.print(b.bossName or "???", bx, G.VH - 32)
    drawBar(bx, G.VH - 22, bw, 7, b.hp / b.maxhp, P.blood)
  end

  g.setColor(1, 1, 1, 1)
end

return Hud
