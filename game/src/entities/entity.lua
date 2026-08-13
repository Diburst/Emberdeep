-- Entity base class + registry.
local class = require "src.core.class"
local U = require "src.core.util"

local Entity = class()

function Entity:init(x, y)
  self.x, self.y = x, y
  self.w, self.h = 14, 14
  self.vx, self.vy = 0, 0
  self.hp = 1
  self.maxhp = 1
  self.dead = false
  self.gravity = 800
  self.maxFall = 300
  self.facing = 1
  self.invuln = 0
  self.white = 0
  self.layer = 0 -- draw order within entities
end

function Entity:center()
  return self.x + self.w / 2, self.y + self.h / 2
end

function Entity:update(dt) end
function Entity:draw() end

function Entity:hurt(dmg, srcx, srcy, opts)
  if self.dead or self.invuln > 0 then return false end
  self.hp = self.hp - dmg
  self.white = 0.15
  if self.onHurt then self:onHurt(dmg, srcx, srcy, opts) end
  if self.hp <= 0 then
    self:die(opts)
  end
  return true
end

function Entity:die(opts)
  if self.dead then return end
  self.dead = true
  if self.onDeath then self:onDeath(opts) end
end

-- registry ----------------------------------------------------------
Entity.registry = {}

function Entity.register(name, ctor)
  Entity.registry[name] = ctor
end

function Entity.make(name, x, y, spec)
  local ctor = Entity.registry[name]
  if not ctor then return nil, "unknown entity: " .. tostring(name) end
  return ctor(x, y, spec)
end

return Entity
