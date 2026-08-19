-- The in-game state: owns the world, players, co-op logic, transitions,
-- respawns, link shot, announcements, autosave.
local U = require "src.core.util"
local P = require "src.assets.palette"
local Cam = require "src.camera"
local World = require "src.world"
local Player = require "src.entities.player"
local Proj = require "src.entities.projectile"

local S = { name = "game" }

-- mode: { coop = bool, testBoss = id?, testBossRoom = room? }
function S:enter(prev, mode)
  G.game = self
  self.coop = mode and mode.coop or false
  self.testBoss = mode and mode.testBoss or nil
  self.testBossRoom = mode and mode.testBossRoom or nil
  self.testBossT = nil
  self.activeBot = 1
  self.fade = 1          -- 1 = black, fading in
  self.fadeDir = -1
  self.fadeCb = nil
  self.announceQueue = {}
  self.linkMeter = 1
  self.linkState = nil   -- {t} charging
  self.partnerHoldT = 0
  self.pendingSwap = false
  self.respawning = false
  self.dialogue = nil
  self.cutscene = nil
  self.playtimeAcc = 0

  -- build player entities
  local p1 = Player.new(1, 0, 0)
  local p2 = Player.new(2, 0, 0)
  self.players = { p1, p2 }
  if not self.coop then
    p2.idle = true
  end
  World:setPlayers(self.players)
  World.entities = {}
  for _, p in ipairs(self.players) do World:add(p) end
  World:load(G.run.room, G.run.door, true)
  Cam.jumpTo(p1.x + p1.w / 2, p1.y + p1.h / 2)
end

function S:leave()
  if G.game == self then G.game = nil end
end

function S:activePlayers()
  local out = {}
  for _, p in ipairs(self.players) do
    if not p.dead and not p.idle then out[#out + 1] = p end
  end
  return out
end

function S:activeBotEntity()
  return self.players[self.activeBot]
end

-- ==================================================================
-- Update
-- ==================================================================
function S:update(dt)
  -- playtime
  G.run.playtime = G.run.playtime + dt

  -- fade
  if self.fadeDir ~= 0 then
    self.fade = U.clamp(self.fade + self.fadeDir * dt * 3.5, 0, 1)
    if self.fade == 1 and self.fadeDir > 0 then
      self.fadeDir = -1
      if self.fadeCb then
        local cb = self.fadeCb
        self.fadeCb = nil
        cb()
      end
    elseif self.fade == 0 and self.fadeDir < 0 then
      self.fadeDir = 0
    end
  end

  if self:pollMeta() then return end

  -- dialogue pauses the world
  if self.dialogue then
    self.dialogue:update(dt)
    if self.dialogue.done then self.dialogue = nil end
    return
  end
  if self.cutscene then
    self.cutscene:update(dt)
    if self.cutscene.done then self.cutscene = nil end
  end

  if self.fade > 0.95 then return end -- hold sim during full black

  -- link meter recharge
  if self.linkMeter < 1 then
    self.linkMeter = math.min(1, self.linkMeter + dt / 16.5)
  end

  -- link shot channel
  if self.linkState then
    self.linkState.t = self.linkState.t - dt
    local v, l = self.players[1], self.players[2]
    v.vx, l.vx = 0, 0
    World:fx("trail", U.lerp(v.x, l.x, math.random()) + 5,
      U.lerp(v.y, l.y, math.random()) + 7, { color = "spark", r = 2, t = 0.2 })
    if self.linkState.t <= 0 then
      self.linkState = nil
      self.linkMeter = 0
      self:fireLinkShot()
    end
  end

  -- solo: partner button hold detection (tap = swap, hold = recall)
  if not self.coop and self.pendingSwap then
    if G.Input.down(1, "partner") then
      self.partnerHoldT = self.partnerHoldT + dt
      if self.partnerHoldT > 0.35 then
        self.pendingSwap = false
        self:recallIdleBot()
      end
    else
      self.pendingSwap = false
      if self.partnerHoldT <= 0.35 then self:swapBots() end
    end
  end

  World:update(dt)

  -- co-op screen edge constraint (collision-aware: never shove a player
  -- through terrain -- if the clamped spot is solid, leave them be and
  -- let the camera midpoint drift instead)
  if self.coop then
    local PHc = require "src.physics"
    local alive = self:activePlayers()
    if #alive == 2 then
      for _, p in ipairs(alive) do
        if not p.downed then
          local minx, maxx = Cam.x + 2, Cam.x + G.VW - 2 - p.w
          if p.x < minx then
            local ox = p.x
            p.x = minx
            if PHc.boxBlocked(p.x, p.y, p.w, p.h) then p.x = ox
            elseif p.vx < 0 then p.vx = 0 end
          end
          if p.x > maxx then
            local ox = p.x
            p.x = maxx
            if PHc.boxBlocked(p.x, p.y, p.w, p.h) then p.x = ox
            elseif p.vx > 0 then p.vx = 0 end
          end
        end
      end
    end
  end

  -- camera follows controlled players (and idle bot loosely ignored)
  local targets = {}
  for _, p in ipairs(self.players) do
    if not p.dead and not p.idle and not p.downed then
      p.lookahead = p.facing * 14
      targets[#targets + 1] = p
    end
  end
  if #targets == 0 then
    for _, p in ipairs(self.players) do
      if not p.dead and not p.idle then targets[#targets + 1] = p end
    end
  end
  if #targets > 0 then Cam.update(dt, targets) end

  -- announcements
  if self.announceQueue[1] then
    local a = self.announceQueue[1]
    a.t = a.t - dt
    if a.t <= 0 then table.remove(self.announceQueue, 1) end
  end

  -- test chamber: leaving the arena terminates the test
  if G.run.testChamber and self.testBossRoom
    and G.run.room ~= self.testBossRoom then
    if G.Audio then G.Audio.stopMusic() end
    G.State.switch(require "src.states.title")
    return
  end

  -- test chamber: summon the chosen boss (and again after a wipe)
  if self.testBoss and G.run.room == self.testBossRoom
    and not World.bossActive and not self.respawning
    and not G.run.flags["boss_" .. self.testBoss] then
    self.testBossT = (self.testBossT or 1.2) - dt
    if self.testBossT <= 0 then
      self.testBossT = nil
      local Bosses = require "src.entities.bosses"
      Bosses.start(self.testBoss, World)
      self:announce("TEST CHAMBER: FIGHT!", 1.6)
    end
  elseif self.testBossT then
    self.testBossT = nil
  end

  -- ending trigger (set when the Mender falls)
  if G.run.flags.ending and not G.run.flags.ending_done then
    G.State.switch(require "src.states.ending")
    return
  end

  -- Brassa's forge opens once her dialogue closes
  if self.forgeQueued and not self.dialogue then
    self.forgeQueued = nil
    G.State.push(require "src.states.forge")
  end

  -- room transition. The arena seals during a boss fight: door touches
  -- must be DROPPED, not queued -- a stale request must never yank the
  -- players somewhere the moment the boss dies.
  if World.pendingTransition and World.bossActive then
    World.pendingTransition = nil
  end
  if World.pendingTransition and self.fadeDir == 0 and not World.bossActive then
    local tr = World.pendingTransition
    World.pendingTransition = nil
    self:transitionTo(tr.room, tr.door)
  end

  -- all players down check
  if not self.respawning then
    local anyUp = false
    for _, p in ipairs(self.players) do
      if not p.dead and not p.downed and not p.idle then anyUp = true end
    end
    if not anyUp then
      if G.Save.sealed() then
        -- no checkpoints past the point of no return
        self:reloadLastSave()
      else
        self:respawnAtCheckpoint()
      end
    end
  end
end

-- ==================================================================
-- Transitions / respawn / saving
-- ==================================================================
function S:transitionTo(room, door)
  local oldZone = World.zone
  self.fadeDir = 1
  self.fadeCb = function()
    World:load(room, door, true)
    -- zone change => checkpoint + autosave
    if World.zone ~= oldZone then
      self:setCheckpoint(room, door)
      self:autosave()
    end
  end
  if G.Audio then G.Audio.sfx("door") end
end

function S:setCheckpoint(room, door)
  -- Sealed runs do not move their checkpoint. Zone changes, teleport pads
  -- and the warp menu all come through here, and every one of them used
  -- to keep quietly advancing the respawn point after the theft.
  if G.Save.sealed() then return end
  G.run.checkpoint = { room = room, door = door }
end

function S:autosave()
  -- the Ember lockout: from the moment the Reckoning starts until an
  -- ending is written, NOTHING touches the save files. The theft can
  -- never be committed to disk half-done.
  if G.Save.sealed() then return end
  self:syncRun()
  if not G.run.slot then return end   -- test chamber runs are ephemeral
  G.Save.writeSlot(G.run.slot, G.run)
  self:announce("* autosaved *", 1.4)
end

function S:reloadLastSave()
  -- the deep refuses this timeline: back to the last saved moment
  local slot, coop = G.run.slot, self.coop
  local data = slot and G.Save.readSlot(slot)
  if data then
    G.run = data
    G.run.slot = slot
    G.State.switch(require "src.states.game", { coop = coop })
  else
    G.State.switch(require "src.states.title")
  end
end

function S:syncRun()
  for i, p in ipairs(self.players) do
    local pd = G.run.players[i]
    pd.hp = p.hp
    pd.maxhp = p.maxhp
    pd.curWeapon = p.curWeapon
    pd.maxenergy = p.maxenergy
  end
  G.run.coop = self.coop
end

function S:respawnAtCheckpoint()
  self.respawning = true
  self.fadeDir = 1
  self.fadeCb = function()
    local cp = G.run.checkpoint
    for _, p in ipairs(self.players) do
      p.downed = false
      p.dead = false
      p.hp = p.maxhp
      p.invuln = 1.5
      p.domeActive = false
      p.energy = p.maxenergy
    end
    World:load(cp.room, cp.door, true)
    -- lantern checkpoints store exact coordinates: place the bots there
    -- (never trust positions carried over from another room). RESCUE
    -- GUARD: if the stored spot cannot reach any door (a sealed pocket,
    -- e.g. behind a gate that closed), keep the door placement instead
    -- of looping the players into a trap forever.
    if cp.x and cp.y
        and World:canEscape(math.floor(cp.x / 16), math.floor(cp.y / 16)) then
      local PH = require "src.physics"
      for i, p in ipairs(self.players) do
        p.x = cp.x + (i - 1) * 14
        p.y = cp.y
        p.vx, p.vy = 0, 0
        if PH.boxBlocked(p.x, p.y, p.w, p.h) then
          p.x, p.y = cp.x, cp.y - 16
        end
      end
      Cam.jumpTo(cp.x, cp.y)
    end
    self.respawning = false
    self.linkMeter = 1
  end
  if G.Audio then G.Audio.sfx("respawn") end
end

function S:onPlayerDown(p)
  local anyUp = false
  for _, q in ipairs(self.players) do
    if not q.dead and not q.downed and not q.idle then anyUp = true end
  end
  if anyUp then
    if not self.coop then
      -- solo: force-switch control to the other bot if it's deployed
      self:announce("Bot down! Walk the other bot over and hold [INTERACT] to revive!", 3)
    else
      self:announce(p.isVess and "Vess is down! Revive them!" or "Lu is down! Revive them!", 3)
    end
  end
  -- solo where idle bot exists: auto-swap so player keeps control
  if not self.coop then
    local other = p:partner()
    if other and other.idle and not other.dead then
      self:swapBots(true)
    end
  end
end

function S:onPlayerBledOut(p)
  -- bleed-out expired: full wipe -> checkpoint
  self:respawnAtCheckpoint()
end

-- ==================================================================
-- Co-op verbs
-- ==================================================================
function S:partnerPressed(p)
  if self.coop then
    self:tryLinkShot()
  else
    -- tap vs hold resolved in update
    self.pendingSwap = true
    self.partnerHoldT = 0
  end
end

function S:tryLinkShot()
  if self.linkState then return end
  -- Maro switches this on in Ember Camp. Before that the pair simply do
  -- not know they can do it, so there is nothing to charge or explain.
  if not G.run.flags.linkblast then
    if G.Audio then G.Audio.sfx("deny") end
    return
  end
  if self.linkMeter < 1 then
    if G.Audio then G.Audio.sfx("deny") end
    self:announce("LINK charging... " .. math.floor(self.linkMeter * 100) .. "%", 1)
    return
  end
  local v, l = self.players[1], self.players[2]
  if v.dead or l.dead or v.downed or l.downed then return end
  if self.coop and (v.idle or l.idle) then return end
  local d = U.dist(v.x, v.y, l.x, l.y)
  if d > 48 then
    self:announce(self.coop and "Get closer to LINK!"
      or "Recall your partner first (hold [PARTNER]), then LINK ([WARP])!", 1.6)
    if G.Audio then G.Audio.sfx("deny") end
    return
  end
  self.linkState = { t = 0.9 }
  if G.Audio then G.Audio.sfx("linkcharge") end
end

function S:fireLinkShot()
  local v, l = self.players[1], self.players[2]
  local dir = v.facing
  local cx = (v.x + v.w / 2 + l.x + l.w / 2) / 2
  local cy = (v.y + v.h / 2 + l.y + l.h / 2) / 2
  Cam.shake(4, 0.4)
  G.Input.rumble(1, 1, 0.5)
  G.Input.rumble(2, 1, 0.5)
  if G.Audio then G.Audio.sfx("linkshot") end
  -- radial nova: hits everything around the pair
  for i = 0, 11 do
    local a = i * math.pi / 6
    Proj.spawn(World, cx, cy, {
      side = "player", dmg = 12, owner = v, link = true,
      vx = math.cos(a) * 420, vy = math.sin(a) * 420,
      kind = "lance", size = 9, pierce = 99, life = 1.0,
    })
  end
  -- heavier forward lance in Vess's facing direction
  for i = 0, 2 do
    Proj.spawn(World, cx + dir * i * 6, cy + (i - 1) * 3, {
      side = "player", dmg = 12, owner = v, link = true,
      vx = dir * 560, vy = 0,
      kind = "lance", size = 11, pierce = 99, life = 1.2,
    })
  end
  World:fx("burst", cx, cy, { color = "spark", n = 22, speed = 170 })
  self.flashT = 0.15
end

function S:swapBots(force)
  local cur = self.players[self.activeBot]
  local nxt = self.players[self.activeBot == 1 and 2 or 1]
  if nxt.dead or nxt.downed and not force then
    if nxt.downed then
      -- allow swapping to downed? no
      if G.Audio then G.Audio.sfx("deny") end
      return
    end
  end
  cur.idle = true
  cur.charging = false
  nxt.idle = false
  nxt.invuln = math.max(nxt.invuln, 0.3)
  self.activeBot = nxt.idx
  if G.Audio then G.Audio.sfx("swap") end
  World:fx("spark", nxt.x + nxt.w / 2, nxt.y + nxt.h / 2, { color = "spark", n = 6 })
end

function S:recallIdleBot()
  local active = self.players[self.activeBot]
  local idle = active:partner()
  if not idle or not idle.idle or idle.dead then return end
  idle.x = active.x + (active.facing > 0 and -12 or 12)
  idle.y = active.y
  idle.vx, idle.vy = 0, 0
  World:ensureFree(idle)  -- never recall a bot into a wall
  World:fx("burst", idle.x + idle.w / 2, idle.y + idle.h / 2, { color = "spark", n = 8 })
  if G.Audio then G.Audio.sfx("warp") end
end

function S:warpToPartner(p)
  local other = p:partner()
  if not other or other.dead then return end
  if not self.coop then return end
  p.x = other.x + (other.facing > 0 and -12 or 12)
  p.y = other.y
  p.vx, p.vy = 0, 0
  World:ensureFree(p)  -- never warp into a wall
  p.roomEnterProtect = 0.4
  World:fx("burst", p.x + p.w / 2, p.y + p.h / 2, { color = "spark", n = 8 })
  if G.Audio then G.Audio.sfx("warp") end
end

-- second controller drop-in
function S:joystick(what, joy, slot)
  if what == "added" and not self.coop and slot == 2 then
    self:announce("Press START on pad 2 to join!", 3)
  end
end

-- F1: test-mode PROGRESS panel (raw key so it needs no binding slot)
function S:raw(ev)
  if ev.kind == "rawkey" and ev.id == "f1"
      and G.settings.testmode and not self.dialogue then
    G.State.push(require "src.states.progress")
  end
end

-- pause / map / drop-in are polled in update() so they work identically
-- for pads, keyboard, and any rebinding.
function S:pollMeta()
  for slot = 1, 2 do
    if G.Input.pressed(slot, "pause") then
      if self.dialogue then return end
      if slot == 2 and not self.coop then
        self:dropIn()
      else
        G.State.push(require "src.states.pause")
      end
      return true
    end
    if G.Input.pressed(slot, "map") and not self.dialogue then
      G.State.push(require "src.states.mapscreen")
      return true
    end
  end
end

function S:dropIn()
  self.coop = true
  local lu = self.players[2]
  local vess = self.players[1]
  lu.idle = false
  vess.idle = false
  self.activeBot = 1
  if lu.dead then lu.dead = false lu.hp = math.floor(lu.maxhp / 2) end
  lu.x, lu.y = vess.x, vess.y
  lu.vx, lu.vy = 0, -60
  World:fx("burst", lu.x + 5, lu.y + 8, { color = "cyan", n = 12 })
  self:announce("Lu joined! Two-bot mode.", 2.5)
  if G.Audio then G.Audio.sfx("join") end
end

function S:dropOut()
  self.coop = false
  self.activeBot = 1
  local lu = self.players[2]
  lu.idle = true
  self.players[1].idle = false
  self:announce("Back to one-player mode ([PARTNER] taps swap bots).", 3)
end

-- ==================================================================
-- Dialogue / announcements
-- ==================================================================
function S:announce(text, t)
  local ftext = G.fmtButtons(text)
  -- flavor and events go to the log; mechanical chatter does not
  if not (text:find("^%*") or text:find("charging") or text:find("autosaved")
    or text:find("TEST CHAMBER") or text:find("Not enough scrap")
    or text:find("Get closer")) then
    require("src.ui.textbox").logLine("", ftext)
  end
  self.announceQueue[#self.announceQueue + 1] = { text = ftext, t = t or 2 }
end

function S:startDialogue(script, npc)
  local Textbox = require "src.ui.textbox"
  self.dialogue = Textbox.new(script, npc)
end

-- ==================================================================
-- Draw
-- ==================================================================
function S:draw()
  World:draw()

  -- atmosphere vignette
  if G.vignette then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(G.vignette, 0, 0, 0, 2, 2)
  end

  -- THE COLD, at the edges of the screen.
  -- The Coldstore's gate is the air, not a door, and this is how the air
  -- says so: you walk in without Cryo Coils and the frame starts closing
  -- in white. Driven by the WORST of the two bots, because either of
  -- them going down is your problem.
  do
    local Cold = require "src.cold"
    local worst = 0
    for _, p in ipairs(self.players or {}) do
      if not p.dead and (p.chill or 0) > worst then worst = p.chill end
    end
    if worst > 0.05 then
      local g = love.graphics
      local a = (worst / Cold.CHILL_MAX) ^ 1.6
      local band = 10 + 46 * a
      -- four soft edges rather than one flat wash: a full-screen tint
      -- would grey the room out, and you still have to be able to see
      -- the floor you are running for.
      for i = 0, 5 do
        local t = i / 5
        g.setColor(0.86, 0.95, 1.0, 0.16 * a * (1 - t))
        local d = band * t
        g.rectangle("fill", 0, d, G.VW, band / 5)
        g.rectangle("fill", 0, G.VH - d - band / 5, G.VW, band / 5)
        g.rectangle("fill", d, 0, band / 5, G.VH)
        g.rectangle("fill", G.VW - d - band / 5, 0, band / 5, G.VH)
      end
      if worst >= Cold.CHILL_MAX then
        g.setColor(0.86, 0.95, 1.0, 0.10 + math.sin(G.time * 9) * 0.06)
        g.rectangle("fill", 0, 0, G.VW, G.VH)
      end
      g.setColor(1, 1, 1, 1)
    end
  end

  -- link charge beam warning
  if self.linkState then
    local v, l = self.players[1], self.players[2]
    local g = love.graphics
    g.setColor(P.spark[1], P.spark[2], P.spark[3], 0.8)
    local x1, y1 = Cam.toScreen(v.x + v.w / 2, v.y + v.h / 2)
    local x2, y2 = Cam.toScreen(l.x + l.w / 2, l.y + l.h / 2)
    g.line(x1, y1, x2, y2)
    g.setColor(1, 1, 1, 1)
  end

  local Hud = require "src.ui.hud"
  Hud.draw(self)

  if self.dialogue then self.dialogue:draw() end

  -- announcements
  if self.announceQueue[1] then
    local a = self.announceQueue[1]
    local g = love.graphics
    local alpha = math.min(1, a.t * 3)
    g.setFont(G.fonts.main)
    local w = G.fonts.main:getWidth(a.text)
    g.setColor(0, 0, 0, 0.6 * alpha)
    g.rectangle("fill", (G.VW - w) / 2 - 6, 36, w + 12, 14, 3, 3)
    g.setColor(P.cream[1], P.cream[2], P.cream[3], alpha)
    g.printf(a.text, 0, 39, G.VW, "center")
    g.setColor(1, 1, 1, 1)
  end

  -- link shot flash
  if self.flashT and self.flashT > 0 then
    self.flashT = self.flashT - 1 / 60
    if G.settings.flashes then
      love.graphics.setColor(1, 1, 1, self.flashT * 3)
      love.graphics.rectangle("fill", 0, 0, G.VW, G.VH)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  -- fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, G.VW, G.VH)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return S
