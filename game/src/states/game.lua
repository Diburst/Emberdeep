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
  self.tetherStrain = 0  -- 0 slack .. 1 severed (COOP-PLAN 12.3)
  self.tetherTaut = 0    -- countdown: the horizontal wall just bit
  self.tetherPulse = 0   -- countdown: LINK pressed while too far apart
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

  -- link meter recharge -- but not through a severed field (12.3). This
  -- is a systemic cost, not a physical one: nothing stops the player
  -- moving, the connection simply is not there to charge through.
  self:tetherUpdate(dt)
  self:updateRecall(dt)
  self:updateStuck(dt)
  if self.linkMeter < 1 and (self.tetherStrain or 0) < S.TETHER_LIMIT then
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
          -- WORLD space, not UI: this clamps a player inside the visible
          -- window in world units, so it follows the camera, not the HUD.
          local minx, maxx = Cam.x + 2, Cam.x + G.VW - 2 - p.w
          -- COOP-PLAN 13.1: the stop is not an invisible wall, it is
          -- the tether going taut and bright at exactly the stop point.
          -- So the clamp reports that it bit, and drawTether says so.
          if p.x < minx then
            local ox = p.x
            p.x = minx
            if PHc.boxBlocked(p.x, p.y, p.w, p.h) then p.x = ox
            else
              if p.vx < 0 then p.vx = 0 end
              self.tetherTaut = 0.2
            end
          end
          if p.x > maxx then
            local ox = p.x
            p.x = maxx
            if PHc.boxBlocked(p.x, p.y, p.w, p.h) then p.x = ox
            else
              if p.vx > 0 then p.vx = 0 end
              self.tetherTaut = 0.2
            end
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

  -- TEST CHAMBER: summon the chosen boss (and again after a wipe) --
  -- UNLESS the room arms it itself. The Archivist is woken by lighting
  -- the fire in the middle of the Threshold, and auto-starting the
  -- fight skipped that: you arrived, the boss began, and you were in a
  -- freezing room with mechanics you had not been given the chance to
  -- set up. If a prop in the room says it arms this boss, the chamber
  -- keeps its hands off and lets the player start it the real way.
  local armedByRoom = false
  for _, e in ipairs(World.entities or {}) do
    if e.armBoss and e.armBoss == self.testBoss then armedByRoom = true break end
  end
  if self.testBoss and G.run.room == self.testBossRoom
    and not armedByRoom
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

-- ------------------------------------------------------------------
-- DEATH REWINDS THE RUN
-- ------------------------------------------------------------------
-- It used to move the bots back to the checkpoint and leave everything
-- else alone: the scrap you picked up on the way to dying, the flags
-- you set, the chest you opened were all still yours. That makes death
-- a walk rather than a loss, and it makes the checkpoint the thing you
-- pass rather than the thing you play toward.
--
-- So it RELOADS THE SLOT. Whatever was banked at the last checkpoint is
-- what you get; everything since is gone.
--
-- If there is no slot on disk yet -- a brand-new run that has not
-- touched a checkpoint -- there is nothing to roll back to, so it falls
-- through to the old behaviour rather than deleting the run.
function S:respawnAtCheckpoint()
  self.respawning = true
  self.fadeDir = 1
  self.fadeCb = function()
    local disk = G.run and G.Save.readSlot(G.run.slot)
    if disk and disk.checkpoint and not G.Save.sealed() then
      local slot, coop = G.run.slot, G.run.coop
      G.run = disk
      G.run.slot, G.run.coop = slot, coop
      -- the player objects carry HP, energy and weapons; rebuild them
      -- from what was banked or the rollback is only half done
      for i, p in ipairs(self.players) do
        local pd = G.run.players and G.run.players[i]
        if pd then
          p.maxhp = pd.maxhp or p.maxhp
          p.weapons = pd.weapons or p.weapons
          p.curWeapon = pd.curWeapon or 1
          p.maxenergy = pd.maxenergy or p.maxenergy
        end
      end
    end
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
-- THE LINK FIELD  (COOP-PLAN 12.3, 13.4)
-- ==================================================================
-- It is NOT a rope, and the game's own geometry refutes a rope twice.
-- The Lane Room puts rock between the two lanes, so a physical line
-- would have to pass through solid tile; and twelve rooms let a bot fall
-- further than any leash could allow without either yanking the partner
-- off a ledge (one player's mistake kills both), stopping a fall dead in
-- mid-air (ropes do not do that), or dragging the anchor (miserable).
--
-- So it is a FIELD, which is what the fiction always said: the LINK blast
-- is a radial nova of energy fired from the midpoint of the pair, and the
-- linkcore lattice is armour only that energy opens. There has never been
-- a rope in this world.
--
--   * it DRAWS THROUGH TERRAIN -- through the Lane Room wall you can see
--     where your partner is, which turns the divider from a problem into
--     something readable
--   * it APPLIES NO FORCE. Ever. Nothing yanks, nothing arrests, and a
--     fall is never interrupted. That was the whole reason to fear a
--     leash and it is answered by construction rather than by tuning
--   * its cost for being stretched is SYSTEMIC: the LINK meter stops
--     charging and Lu's energy regen degrades. Closing the distance
--     restores both, completely and immediately
--
-- It is also the entire edge-indicator UI. No arrow, no marker, no new
-- HUD element: the line already runs between the two bots, so it already
-- points at whichever one is off screen. One line, four states.
-- ONE THRESHOLD, and the same number for every consequence, on purpose:
-- the field becomes VISIBLE at exactly the point it stops WORKING. You
-- never see the tether while it is doing its job, and the moment you can
-- see it, it is telling you why something just stopped.
--
-- It is not ambient, and it deliberately used to be. Drawn all the time
-- it is an eyesore -- a line trailing you through the whole game to
-- report a condition that is almost never interesting. It has exactly
-- three things to say and stays off the screen otherwise:
--
--   * the LINK was pressed and you are too far apart      -- one pulse
--   * you are further apart than 0.75 of a screen         -- fades in
--   * a bot has left the frame entirely                   -- full bright
S.TETHER_LIMIT = 1.0     -- strain == 0.75 of a screen: visible AND severed
S.TETHER_FULL = 1.25     -- ...and fully bright by here, or the instant a
                         -- bot actually leaves the frame, whichever first
S.TETHER_REGEN_MIN = 0.25  -- Lu's regen multiplier once severed

-- Strain is measured against the SAME budget checkcoop.py audits --
-- 0.75 of the viewport on each axis -- so the thing the player feels and
-- the thing the validator measures are one number, not two that drift.
function S:tetherEnds()
  if not self.coop then return nil end
  local v, l = self.players[1], self.players[2]
  if not v or not l then return nil end
  if v.dead or l.dead or v.idle or l.idle then return nil end
  return v, l
end

function S:tetherUpdate(dt)
  self.tetherTaut = math.max(0, (self.tetherTaut or 0) - dt)
  self.tetherPulse = math.max(0, (self.tetherPulse or 0) - dt)
  local v, l = self:tetherEnds()
  if not v then self.tetherStrain = 0 return end
  local dx = math.abs((v.x + v.w / 2) - (l.x + l.w / 2))
  local dy = math.abs((v.y + v.h / 2) - (l.y + l.h / 2))
  self.tetherStrain = math.max(dx / (0.75 * G.VW), dy / (0.75 * G.VH))
end

-- ==================================================================
-- THE RECALL: dragging a downed partner back along the field
-- ==================================================================
-- The hole this fills: §13.5 permits vertical abandonment, step 6 took
-- the warp away, and doors need both bots -- so a bot that goes down in
-- an ability-gated lane the other one cannot enter is a soft lock with
-- no way out but the title screen. The fall-separation audit proves you
-- can always WALK back; it says nothing about a body that cannot walk.
--
-- This is deliberately NOT the warp coming back:
--   * only while a partner is DOWN. Two bots on their feet get nothing.
--   * it costs a channel you must hold, so it is a decision, not a tap.
--   * it moves a BODY. You still have to walk over and revive it.
--   * and it reaches half a screen, so it cannot ferry a corpse across
--     a level to skip the walk -- see RECALL_REACH.
--
-- It also does not break §12.3's "the field applies no force, ever".
-- That rule exists so the game never takes the controls off a PLAYER.
-- A downed bot has no controls to take: it is already a body on the
-- floor being dragged by gravity. Pulling it is not a loss of agency,
-- it is the only agency left in the situation.
S.RECALL_REACH  = 0.5    -- of a screen width. Half of what the tether
                         -- tolerates before it is even drawn, so the
                         -- reach is visibly shorter than the leash.
S.RECALL_CHARGE = 1.1    -- seconds of held button before it takes
S.RECALL_PULL   = 220    -- px/s the body travels along the field

-- The living bot and its downed partner, or nil. Exactly one down: with
-- both down there is nobody to pull, and the run is over anyway.
function S:recallPair()
  if not self.coop then return nil end
  local v, l = self.players[1], self.players[2]
  if not v or not l then return nil end
  if v.dead or l.dead then return nil end
  if v.downed == l.downed then return nil end
  if v.idle or l.idle then return nil end
  if v.downed then return l, v end
  return v, l
end

function S:recallDist()
  local live, dn = self:recallPair()
  if not live then return nil end
  return U.dist(live.x + live.w / 2, live.y + live.h / 2,
                dn.x + dn.w / 2, dn.y + dn.h / 2)
end

function S:updateRecall(dt)
  local live, dn = self:recallPair()
  if not live then self.recall = nil return end

  local slot = live.controlSlot and live:controlSlot()
  local holding = slot and G.Input.down(slot, "warp") or false
  local d = U.dist(live.x + live.w / 2, live.y + live.h / 2,
                   dn.x + dn.w / 2, dn.y + dn.h / 2)
  local reach = S.RECALL_REACH * G.VW

  -- ALREADY PULLING: the body travels whatever the button does now.
  -- Letting go mid-pull would drop it somewhere arbitrary, quite
  -- possibly inside the rock it is passing through.
  if self.recall and self.recall.pulling then
    local tx = live.x + (live.facing or 1) * -10
    local ty = live.y
    local ddx, ddy = tx - dn.x, ty - dn.y
    local dist = math.sqrt(ddx * ddx + ddy * ddy)
    if dist <= 4 then
      dn.x, dn.y = tx, ty
      dn.vx, dn.vy = 0, 0
      World:ensureFree(dn)          -- never leave a body inside terrain
      self.recall = nil
      -- "grapplehit", not "linkhit": there is no linkhit. Audio.sfx
      -- no-ops on a name it does not have, so the arrival would have
      -- been silently silent -- the worst kind of missing sound,
      -- because nothing ever tells you.
      if G.Audio then G.Audio.sfx("grapplehit") end
      self:announce("Recalled. Hold [INTERACT] to revive.", 2)
      return
    end
    local step = math.min(dist, S.RECALL_PULL * dt)
    -- straight along the field, THROUGH geometry: the LINK is not a
    -- rope and the whole reason this rescues a gated lane is that the
    -- wall is not in its way
    dn.x = dn.x + ddx / dist * step
    dn.y = dn.y + ddy / dist * step
    dn.vx, dn.vy = 0, 0
    World:fx("trail", dn.x + dn.w / 2, dn.y + dn.h / 2,
      { color = "cyan", r = 2, t = 0.2 })
    return
  end

  if not holding then self.recall = nil return end

  if d > reach then
    -- say why, once a second, rather than charging something that can
    -- never finish
    self.tetherPulse = 0.45
    self.recallFar = (self.recallFar or 0) - dt
    if self.recallFar <= 0 then
      self.recallFar = 1.0
      self:announce("Too far to recall -- get closer.", 1.2)
      if G.Audio then G.Audio.sfx("deny") end
    end
    self.recall = nil
    return
  end

  self.recall = self.recall or { t = 0, pulling = false, hum = 0 }
  self.recall.t = self.recall.t + dt
  self.recall.hum = (self.recall.hum or 0) - dt
  if self.recall.hum <= 0 then
    self.recall.hum = 0.16
    if G.Audio then
      G.Audio.sfx("emcharge", 0.7 + (self.recall.t / S.RECALL_CHARGE) * 0.8)
    end
  end
  -- fragments spiralling in along the line, faster as it closes
  local prog = math.min(1, self.recall.t / S.RECALL_CHARGE)
  local ang = G.time * 9
  World:fx("spark", dn.x + dn.w / 2 + math.cos(ang) * 14 * (1 - prog),
    dn.y + dn.h / 2 + math.sin(ang) * 14 * (1 - prog),
    { color = "cyan", n = 2 })
  if self.recall.t >= S.RECALL_CHARGE then
    self.recall.pulling = true
    if G.Audio then G.Audio.sfx("grapplelaunch") end
    Cam.shake(1.5, 0.15)
  end
end

-- The one owner of "how much worse does a stretched field make things".
-- player.lua asks this rather than keeping its own copy of the curve.
function S:fieldRegenMult()
  -- Binary, and it used to be a ramp starting at 0.55. The ramp was a
  -- penalty with no signal attached: Lu's regen quietly halved at two
  -- hundred pixels of separation and nothing on screen said so, which is
  -- indistinguishable from a bug. Now the cost and the thing that
  -- announces it are the same threshold, so the line appearing IS the
  -- explanation.
  if (self.tetherStrain or 0) < S.TETHER_LIMIT then return 1 end
  return S.TETHER_REGEN_MIN
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
    -- 13.4: the LINK's own way of saying "not yet, get closer" -- said
    -- through the connection it was about to fire along.
    self.tetherPulse = 0.45
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

-- NOTHING RECOVERS A SEPARATED PAIR ANY MORE, so a room that cannot be
-- crossed by both bots is a soft lock. checkcoop reports fourteen door
-- trips only one of them can make, across eight rooms, and those are
-- level bugs to fix -- but a player meeting one deserves to be told that
-- it is a bug rather than left assuming they have missed something.
--
-- The test is deliberately dumb: both alive, both controlled, neither
-- has moved more than a few pixels in a long time, and they are far
-- apart. Anything cleverer would need a reachability query at runtime.
S.STUCK_T = 25            -- seconds of nobody getting anywhere
S.STUCK_D = 120           -- ...while at least this far apart

function S:updateStuck(dt)
  if not self.coop then self.stuckT = 0 return end
  local v, l = self.players[1], self.players[2]
  if not v or not l or v.dead or l.dead or v.idle or l.idle then
    self.stuckT = 0 return
  end
  local moved = false
  for _, p in ipairs(self.players) do
    local last = p.stuckLast
    if not last or math.abs(p.x - last[1]) > 6 or math.abs(p.y - last[2]) > 6 then
      moved = true
      p.stuckLast = { p.x, p.y }
    end
  end
  local far = math.abs(v.x - l.x) > S.STUCK_D or math.abs(v.y - l.y) > S.STUCK_D
  if moved or not far then self.stuckT = 0 return end
  self.stuckT = (self.stuckT or 0) + dt
  if self.stuckT > S.STUCK_T then
    self.stuckT = 0
    self:announce("Separated with no way back? That is a room bug -- "
      .. "note the room name.", 4)
  end
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

-- THE CO-OP WARP IS GONE.  (COOP-PLAN 1)
--
-- It was a release valve that let a pair ignore separation entirely --
-- every camera rule, every lane, every gated crossing in the design was
-- optional while you could hold a button and be beside your partner. The
-- budget only bites once this is not here.
--
-- Deleting it was cheap: `S:warpToPartner` opened with
-- `if not self.coop then return end`, so it was co-op-only and nothing
-- else called it. `S:recallIdleBot` below is the SOLO mechanism and
-- stays -- it is what makes the both-bots door rule survivable alone.
--
-- The anti-frustration valve already existed and is unchanged: a downed
-- bot is revived by holding INTERACT next to it. So the failure case is
-- "walk to your partner", not "wait for a timer", which is the correct
-- cost.
--
-- IF THE PAIR GET GENUINELY SEPARATED there is no longer anything to
-- rescue them, so S:updateStuck below makes that state LOUD instead of
-- letting a player wonder for five minutes whether the room is broken.

-- second controller drop-in
function S:joystick(what, joy, slot, why)
  if what ~= "added" then return end
  if why == "unmapped" then
    self:announce((joy and joy:getName() or "That controller")
      .. " has no gamepad mapping -- it will not respond", 5)
    return
  end
  if why == "full" then
    self:announce("Both player slots already have a controller", 3)
    return
  end
  if not self.coop and slot == 2 then
    self:announce("Press START on pad 2 to join!", 3)
  elseif not self.coop and slot == 1 then
    -- The pad took player one because nobody was on the keyboard. If a
    -- second person wants in, they can take the keyboard instead of
    -- hunting for a second controller.
    self:announce("Controller = player 1. Player 2: press START, or use the ARROW KEYS", 4)
  end
end

-- F1: test-mode PROGRESS panel (raw key so it needs no binding slot)
function S:raw(ev)
  if ev.kind == "rawkey" and ev.id == "f1"
      and G.settings.testmode and not self.dialogue then
    G.State.push(require "src.states.progress")
  end
  -- F2: the ROOM EDITOR, on the room you are standing in. Pushed, not
  -- switched, so the world underneath keeps drawing and stops updating.
  if ev.kind == "rawkey" and ev.id == "f2"
      and G.settings.testmode and not self.dialogue then
    G.State.push(require "src.states.editor")
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
S.ANNOUNCE_MAX = 8

-- THE QUEUE APPENDS, AND SOMETHING CALLS THIS EVERY FRAME.
--
-- `Emitter:energize` announces "not enough charge" once per frame while
-- Lu's dome is on a dormant emitter she cannot afford. Sixty a second,
-- each queued for 1.5s and drained ONE AT A TIME, so three seconds of
-- standing there banked 179 entries -- four and a half minutes of screen
-- time, and 180 lines in the log. The queue lives on the game state, so
-- it survived the room change and the refill and kept saying a thing
-- that had stopped being true, which is exactly how it was reported.
--
-- Suppressing that one caller would have fixed that one caller. The
-- queue is what is wrong: a message already in it is REFRESHED rather
-- than appended, so a per-frame caller holds its message on screen for
-- as long as the condition lasts and then it goes. Different messages
-- still queue normally, and saying the same thing again after it has
-- cleared shows it again.
function S:announce(text, t)
  local ftext = G.fmtButtons(text)
  t = t or 2
  for _, a in ipairs(self.announceQueue) do
    if a.text == ftext then
      -- max, not assignment: a long message must not be cut short by a
      -- short repeat of itself
      a.t = math.max(a.t, t)
      return
    end
  end
  -- flavor and events go to the log; mechanical chatter does not
  if not (text:find("^%*") or text:find("charging") or text:find("autosaved")
    or text:find("TEST CHAMBER") or text:find("^Not enough ")
    or text:find("Get closer")) then
    require("src.ui.textbox").logLine("", ftext)
  end
  -- AND A CEILING, because de-duplication only covers callers that
  -- repeat themselves VERBATIM. "LINK charging... 43%" is a different
  -- string every percent, so a mashed button could still bank a queue
  -- measured in minutes. Nothing in this game has eight things to say
  -- at once; past that the newest is dropped rather than the oldest,
  -- so whatever is already being read finishes being read.
  if #self.announceQueue >= S.ANNOUNCE_MAX then return end
  self.announceQueue[#self.announceQueue + 1] = { text = ftext, t = t }
end

function S:startDialogue(script, npc)
  local Textbox = require "src.ui.textbox"
  self.dialogue = Textbox.new(script, npc)
end

-- ==================================================================
-- Draw
-- ==================================================================
-- 13.4: ONE LINE, FOUR STATES, and every piece of feedback the system
-- needs. It is drawn in screen space after the world, so it crosses
-- terrain on purpose -- through the Lane Room wall you can still see
-- where your partner is.
--
--   idle              a subtle energy line, barely there
--   LINK while apart  one pulse -- the LINK saying "not yet, get closer"
--   at the wall       taut and bright, at exactly the stop point
--   a bot off screen  pulsing fast along its length, toward the missing
--                     bot. That IS the edge indicator; there is no arrow
--                     and no marker anywhere in this game.
function S:drawTether()
  local v, l = self:tetherEnds()
  if not v then return end
  local g = love.graphics
  local x1, y1 = Cam.toScreen(v.x + v.w / 2, v.y + v.h / 2)
  local x2, y2 = Cam.toScreen(l.x + l.w / 2, l.y + l.h / 2)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 6 then return end

  local strain = self.tetherStrain or 0
  local severed = strain >= S.TETHER_LIMIT
  local taut = (self.tetherTaut or 0) > 0
  local pulsing = (self.tetherPulse or 0) > 0
  local vOff = not Cam.onScreen(v.x + v.w / 2, v.y + v.h / 2, 0)
  local lOff = not Cam.onScreen(l.x + l.w / 2, l.y + l.h / 2, 0)
  local missing = nil
  if vOff ~= lOff then missing = vOff and v or l end

  -- NOTHING ON SCREEN unless the field has something to say. See the
  -- note beside S.TETHER_LIMIT: ambient, this is an eyesore.
  --
  -- A DOWNED PARTNER is the fifth thing it has to say, and the only
  -- one that is an OFFER rather than a warning: the line is how the
  -- player learns the recall exists. An ability nothing draws is an
  -- ability nobody finds.
  local recallLive = self:recallPair()
  if not (pulsing or severed or vOff or lOff or recallLive) then return end

  -- A slack field BOWS and a stretched one straightens, so the one case
  -- where it appears while still connected -- a LINK pressed a little
  -- too far apart -- reads as slack rather than as a warning.
  local sag = (1 - math.min(1, strain)) * math.min(len * 0.14, 22)
  local mx, my = (x1 + x2) / 2, (y1 + y2) / 2 + sag

  -- Brightness ramps from the moment it becomes visible to the moment a
  -- bot is genuinely gone, which is the only reading that has to be
  -- unmistakable across a room you cannot see the other half of.
  local t = 0
  if vOff or lOff then
    t = 1
  elseif severed then
    t = U.clamp((strain - S.TETHER_LIMIT)
      / (S.TETHER_FULL - S.TETHER_LIMIT), 0, 1)
  end
  local col, a, w = (severed and P.slate or P.spark), 0.22 + 0.73 * t, 1
  if pulsing then
    col = P.cyan
    a = math.max(a, 0.35 + 0.55 * (self.tetherPulse / 0.45))
  end
  if taut then col, a, w = P.spark, math.max(a, 0.95), 2 end
  -- CHARGING THE RECALL: the field brightens and thickens as the
  -- channel closes, and goes solid white the instant it takes. The
  -- progress is the line itself, so there is no second widget to
  -- find on a screen that already has a downed bot on it.
  if recallLive then
    local r = self.recall
    if r and r.pulling then
      col, a, w = P.cream, 1, 3
    elseif r then
      local prog = math.min(1, r.t / S.RECALL_CHARGE)
      col = P.cyan
      a = math.max(a, 0.45 + 0.55 * prog)
      w = 1 + prog * 2
    else
      -- idle offer: present, and quiet enough not to shout
      col = P.cyan
      a = math.max(a, 0.30 + 0.10 * math.sin(G.time * 3))
    end
  end

  local N = 16
  local pts = {}
  for i = 0, N do
    local t = i / N
    local it = 1 - t
    pts[#pts + 1] = it * it * x1 + 2 * it * t * mx + t * t * x2
    pts[#pts + 1] = it * it * y1 + 2 * it * t * my + t * t * y2
  end

  g.setLineWidth(w)
  g.setColor(col[1], col[2], col[3], a)
  if severed then
    -- broken into dashes, and fully reversible: walk back toward each
    -- other and it knits itself up again with no penalty owed.
    for i = 1, N, 2 do
      local k = (i - 1) * 2 + 1
      g.line(pts[k], pts[k + 1], pts[k + 2], pts[k + 3])
    end
  else
    g.line(pts)
  end

  if missing then
    local dir = (missing == l) and 1 or -1
    for k = 0, 2 do
      local ph = (G.time * 2.2 + k / 3) % 1
      local t = dir > 0 and ph or (1 - ph)
      local it = 1 - t
      local px = it * it * x1 + 2 * it * t * mx + t * t * x2
      local py = it * it * y1 + 2 * it * t * my + t * t * y2
      g.setColor(P.spark[1], P.spark[2], P.spark[3],
        0.85 * (1 - math.abs(t - 0.5) * 0.6))
      g.circle("fill", px, py, 2.2)
    end
  end
  g.setLineWidth(1)
  g.setColor(1, 1, 1, 1)
end

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
        g.rectangle("fill", 0, d, G.SW, band / 5)
        g.rectangle("fill", 0, G.SH - d - band / 5, G.SW, band / 5)
        g.rectangle("fill", d, 0, band / 5, G.SH)
        g.rectangle("fill", G.SW - d - band / 5, 0, band / 5, G.SH)
      end
      if worst >= Cold.CHILL_MAX then
        g.setColor(0.86, 0.95, 1.0, 0.10 + math.sin(G.time * 9) * 0.06)
        g.rectangle("fill", 0, 0, G.SW, G.SH)
      end
      g.setColor(1, 1, 1, 1)
    end
  end

  self:drawTether()

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
    g.rectangle("fill", (G.SW - w) / 2 - 6, 36, w + 12, 14, 3, 3)
    g.setColor(P.cream[1], P.cream[2], P.cream[3], alpha)
    g.printf(a.text, 0, 39, G.SW, "center")
    g.setColor(1, 1, 1, 1)
  end

  -- link shot flash
  if self.flashT and self.flashT > 0 then
    self.flashT = self.flashT - 1 / 60
    if G.settings.flashes then
      love.graphics.setColor(1, 1, 1, self.flashT * 3)
      love.graphics.rectangle("fill", 0, 0, G.SW, G.SH)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  -- fade
  if self.fade > 0 then
    love.graphics.setColor(0, 0, 0, self.fade)
    love.graphics.rectangle("fill", 0, 0, G.SW, G.SH)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return S
