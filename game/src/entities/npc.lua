-- NPCs: townsfolk with dialogue. Spec: npc:<id>
local Entity = require "src.entities.entity"
local U = require "src.core.util"
local P = require "src.assets.palette"
local PH = require "src.physics"

local NPC = Entity.extend()

local SPRITES = {
  elder = "npc_elder", brassa = "npc_brassa", tikka = "npc_tikka",
  jun = "npc_jun", sol = "npc_sol", inks = "npc_inks", root = "npc_root",
  vill = "npc_vill", vill2 = "npc_vill2",
  ferro = "npc_ferro", mote = "npc_mote", lock = "npc_lock",
}

function NPC:init(x, y, parts)
  Entity.init(self, x + 2, y + 1)
  self.kind = "npc"
  self.id = parts[2] or "vill"
  self.w, self.h = 12, 15
  self.interactable = true
  self.hint = "talk"
  self.interactRange = 24
  self.layer = 1
  self.bob = U.rand(0, 6)
  self.faceT = 0
end

-- ------------------------------------------------------------------
-- WITNESSING THE EMBER
--
-- The moment it comes loose, everyone in camp walks toward it. Two of
-- them are going to do something about it -- Maro and Brassa -- and the
-- rest are going to stand there and shake: first because they are
-- frightened, and then, as the lanterns go out one by one, because they
-- are cold. The two are different shakes on purpose.
--
-- The point is staging. Everyone ends up in one room, near the thing
-- that is about to happen, so their dialogue is something you can walk
-- along and read rather than something you have to go hunting for after.
-- ------------------------------------------------------------------
NPC.FIGHTERS = { elder = true, brassa = true }
NPC.FEAR_T = 14           -- seconds of fright before the cold takes over
local WITNESS_SPEED = 34  -- they hurry, but they are not young
local WITNESS_GAP = 26    -- how close they crowd

function NPC:witnessing()
  return G.run and G.run.flags and G.run.flags.camp_witness
    and not G.run.flags.camp_frozen
end

-- what they are all looking at: whoever is holding it, or the plinth
function NPC:emberFocus(World)
  for _, pl in ipairs(World.players or {}) do
    if pl.hasEmber and pl:hasEmber() then return pl.x + pl.w / 2, pl.y end
  end
  for _, e in ipairs(World.entities) do
    if e.lightR and e.hint == "the Ember" then return e.x + e.w / 2, e.y end
  end
  return nil
end

function NPC:update(dt)
  local World = require "src.world"
  self.vy = math.min((self.vy or 0) + 830 * dt, 300)

  if self:witnessing() then
    self.witnessT = (self.witnessT or 0) + dt
    local fx = self:emberFocus(World)
    if fx then
      local dx = fx - (self.x + self.w / 2)
      if math.abs(dx) > WITNESS_GAP then
        -- crowd in. PH.move keeps them off each other's heads and out of
        -- the walls; nobody is pathfinding, they are just drawn to it.
        local step = (dx > 0 and 1 or -1) * WITNESS_SPEED * dt
        PH.move(self, step, 0)
        self.facing = dx > 0 and 1 or -1
        self.walking = true
      else
        self.walking = false
        self.facing = dx > 0 and 1 or -1
      end
    end
    -- the shake. Fear is fast and small; cold is slow and big, and it
    -- gets worse the longer the lanterns have been out.
    if not NPC.FIGHTERS[self.id] then
      local t = (G.run.emberT or 0)
      if t < NPC.FEAR_T then
        self.shiver = math.sin(G.time * 34 + self.bob * 7) * 0.7
        self.shiverKind = "fear"
      else
        local deep = math.min(1, (t - NPC.FEAR_T) / 40)
        self.shiver = math.sin(G.time * (9 + deep * 5) + self.bob * 7)
          * (0.9 + deep * 1.4)
        self.shiverKind = "cold"
      end
    else
      self.shiver, self.shiverKind = nil, nil
    end
  else
    self.shiver, self.shiverKind = nil, nil
  end

  PH.move(self, 0, self.vy * dt)
  -- face nearest player occasionally
  self.faceT = self.faceT - dt
  if self.faceT <= 0 then
    self.faceT = 0.5
    if not self:witnessing() then
      local p = World:nearestPlayer(self.x, self.y)
      if p and U.dist(self.x, self.y, p.x, p.y) < 60 then
        self.facing = p.x > self.x and 1 or -1
      end
    end
  end
end

function NPC:interact(player)
  local Dialogue = require "src.data.dialogue"
  local script = Dialogue.get(self.id, player)
  if script then
    self.facing = player.x > self.x and 1 or -1
    G.game:startDialogue(script)
  end
end

function NPC:draw()
  local name = SPRITES[self.id] or "npc_vill"
  local frame = math.floor(G.time * 2 + self.bob) % 2 + 1
  local ox = self.shiver or 0
  G.drawSprite(name, frame, self.x + self.w / 2 + ox, self.y + self.h + 0.5,
    { flip = self.facing < 0 })
  -- breath, once they are cold rather than frightened
  if self.shiverKind == "cold" then
    local g = love.graphics
    local p = (G.time * 0.6 + self.bob) % 1
    if p < 0.45 then
      g.setColor(P.ice[1], P.ice[2], P.ice[3], (0.45 - p) * 0.7)
      g.circle("fill", self.x + self.w / 2 + self.facing * 6 + p * self.facing * 7,
        self.y + 4 - p * 3, 1 + p * 2.5)
      g.setColor(1, 1, 1, 1)
    end
  end
end

-- Spec: npc:<id>[:need:<flag>][:until:<flag>]... -- conditional presence,
-- any number of condition pairs. "need" spawns only once the flag is set;
-- "until" despawns once it is.
Entity.register("npc", function(x, y, parts)
  for i = 3, #parts - 1, 2 do
    local cond, flag = parts[i], parts[i + 1]
    if cond == "need" and not (G.run and G.run.flags[flag]) then return true end
    if cond == "until" and (G.run and G.run.flags[flag]) then return true end
  end
  return NPC.new(x, y, parts)
end)
return NPC
