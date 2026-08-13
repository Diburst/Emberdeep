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

function NPC:update(dt)
  local World = require "src.world"
  self.vy = math.min((self.vy or 0) + 830 * dt, 300)
  PH.move(self, 0, self.vy * dt)
  -- face nearest player occasionally
  self.faceT = self.faceT - dt
  if self.faceT <= 0 then
    self.faceT = 0.5
    local p = World:nearestPlayer(self.x, self.y)
    if p and U.dist(self.x, self.y, p.x, p.y) < 60 then
      self.facing = p.x > self.x and 1 or -1
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
  G.drawSprite(name, frame, self.x + self.w / 2, self.y + self.h + 0.5,
    { flip = self.facing < 0 })
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
