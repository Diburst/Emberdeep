-- Test scenarios (loaded by src/test.lua).
return function(Test, scenarios)
  local wait, press, hold, release, menuNav =
    Test.wait, Test.press, Test.hold, Test.release, Test.menuNav

  local function startRun(opts)
    opts = opts or {}
    G.run = G.Save.newRun(1, opts.difficulty or 2, opts.coop)
    if opts.room then
      G.run.room = opts.room
      G.run.door = opts.door or "A"
      G.run.checkpoint = { room = opts.room, door = opts.door or "A" }
    end
    for k, v in pairs(opts.flags or {}) do G.run.flags[k] = v end
    G.State.switch(require "src.states.game", { coop = opts.coop })
  end

  local function pos(i)
    local p = G.game.players[i]
    return math.floor(p.x) .. "," .. math.floor(p.y)
  end

  -- ----------------------------------------------------------------
  -- link graph validation (no simulation)
  -- ----------------------------------------------------------------
  scenarios.links = function()
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local fails = 0
    local defs = {}
    for _, id in ipairs(WM.ROOMS) do
      local ok, def = pcall(World.getRoomDef, id)
      if not ok then
        Test.log("FAILROOM " .. id .. ": " .. tostring(def))
        fails = fails + 1
      else
        defs[id] = def
      end
    end
    for id, def in pairs(defs) do
      for ch, link in pairs(def.links or {}) do
        local target, tdoor = link[1], link[2]
        local tdef = defs[target]
        if not tdef then
          Test.log("BADLINK " .. id .. ":" .. ch .. " -> missing room " .. tostring(target))
          fails = fails + 1
        else
          -- target door must exist in target's map
          local found = tdef.map:find(tdoor, 1, true)
          if not found then
            Test.log("BADDOOR " .. id .. ":" .. ch .. " -> " .. target .. ":" .. tdoor .. " (no such door char)")
            fails = fails + 1
          end
          -- reciprocity: target should have some link back to id
          local back = false
          for _, l2 in pairs(tdef.links or {}) do
            if l2[1] == id then back = true end
          end
          if not back then
            Test.log("NOBACK " .. id .. ":" .. ch .. " -> " .. target .. " has no return link")
          end
        end
      end
    end
    Test.log(fails == 0 and "OK links" or ("FAIL links " .. fails))
  end

  -- ----------------------------------------------------------------
  -- full room sweep with simulation
  -- ----------------------------------------------------------------
  scenarios.sweep = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local sweepFails = 0
    for _, id in ipairs(WM.ROOMS) do
      Test.log("ROOM " .. id)
      local def = World.getRoomDef(id)
      -- find first door char present in this room's parsed map
      local ok, err = pcall(function()
        World:load(id, nil, true)
      end)
      if not ok then
        Test.log("FAILLOAD " .. id .. ": " .. tostring(err))
        sweepFails = sweepFails + 1
      else
        -- position players at each door and simulate
        local doorChars = {}
        for ch in pairs(World.doors) do doorChars[#doorChars + 1] = ch end
        table.sort(doorChars)
        for _, ch in ipairs(doorChars) do
          local ok2, err2 = pcall(function()
            World:load(id, ch, true)
          end)
          if not ok2 then
            Test.log("FAILDOOR " .. id .. ":" .. ch .. " " .. tostring(err2))
            sweepFails = sweepFails + 1
          else
            if World.spawnFixed then
              Test.log("EMBED " .. id .. ":" .. ch .. " (" .. World.spawnFixed .. ")")
            end
            World.pendingTransition = nil
            wait(20)
            World.pendingTransition = nil
          end
        end
      end
    end
    if sweepFails == 0 then Test.log("OK sweep")
    else Test.log("FAIL sweep: " .. sweepFails) end
  end

  -- ----------------------------------------------------------------
  -- shaft/edge door arrivals: entering through any linked door must
  -- settle the players on ground (or in water) inside the room, and
  -- must NOT bounce straight back through the arrival door
  -- ----------------------------------------------------------------
  scenarios.shaftdoors = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local fails = 0
    for _, id in ipairs(WM.ROOMS) do
      local ok = pcall(function() World:load(id, nil, true) end)
      if ok then
        local doorChars = {}
        for ch, d in pairs(World.doors) do
          if d.link then doorChars[#doorChars + 1] = ch end
        end
        table.sort(doorChars)
        for _, ch in ipairs(doorChars) do
          local ok2 = pcall(function() World:load(id, ch, true) end)
          if ok2 then
            -- geometry test, not combat: keep bosses/enemies from killing
            -- the players during the settle window
            for _, p in ipairs(World.players) do
              p.hp = 9999
              p.downed = false
            end
            wait(150)  -- 2.5s of settling; transitions process normally
            if G.run.room ~= id then
              Test.log("BOUNCE " .. id .. ":" .. ch .. " -> " .. tostring(G.run.room))
              fails = fails + 1
              World:load(id, nil, true)  -- recover for next door
            else
              -- settle check over a window: knockback from a nearby enemy
              -- can leave a player airborne on any single frame
              local pend = {}
              for i in ipairs(World.players) do pend[i] = true end
              for _ = 1, 90 do
                local any = false
                for i, p in ipairs(World.players) do
                  if pend[i] then
                    local tx = math.floor((p.x + p.w / 2) / 16)
                    local ty = math.floor((p.y + p.h / 2) / 16)
                    if p.onGround or World:isWater(tx, ty)
                        or World:isWater(tx, ty + 1) then
                      pend[i] = false
                    else
                      any = true
                    end
                  end
                end
                if not any then break end
                wait(1)
              end
              for i, p in ipairs(World.players) do
                local tx = math.floor((p.x + p.w / 2) / 16)
                local ty = math.floor((p.y + p.h / 2) / 16)
                if World:isLava(tx, ty) then
                  Test.log("LAVA " .. id .. ":" .. ch .. " p" .. i)
                  fails = fails + 1
                elseif pend[i] then
                  Test.log("AFLOAT " .. id .. ":" .. ch .. " p" .. i
                    .. " at " .. tx .. "," .. ty)
                  fails = fails + 1
                elseif not World:canEscape(tx, ty) then
                  Test.log("BOXED " .. id .. ":" .. ch .. " p" .. i
                    .. " sealed in at " .. tx .. "," .. ty)
                  fails = fails + 1
                end
              end
            end
          end
        end
      end
    end
    if fails == 0 then Test.log("OK shaftdoors")
    else Test.log("FAIL shaftdoors: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- co-op mechanics scenario
  -- ----------------------------------------------------------------
  scenarios.play = function()
    startRun { coop = true, room = "test_arena", door = "A" }
    wait(30)
    Test.log("spawn p1=" .. pos(1) .. " p2=" .. pos(2))
    Test.shot("play_spawn")
    hold(1, "right")
    wait(40)
    hold(1, "jump")
    wait(10)
    release(1, "jump")
    wait(30)
    release(1, "right")
    Test.log("after run p1=" .. pos(1))
    Test.shot("play_move")
    hold(1, "fire")
    wait(20)
    release(1, "fire")
    Test.shot("play_fire")
    hold(2, "right")
    wait(30)
    release(2, "right")
    press(2, "special")
    wait(10)
    Test.shot("play_dome")
    Test.log("dome=" .. tostring(G.game.players[2].domeActive))
    press(2, "special")
    hold(2, "right")
    wait(20)
    release(2, "right")
    press(2, "partner")
    wait(70)
    Test.shot("play_link")
    Test.log("linkMeter=" .. G.game.linkMeter)
    press(1, "special")
    wait(15)
    Test.log("after dash p1=" .. pos(1))
    Test.log("OK play")
  end

  -- ----------------------------------------------------------------
  -- integration: boss death path, shields, revive, save/load
  -- ----------------------------------------------------------------
  local function findBoss()
    local World = require "src.world"
    return World.bossActive
  end

  scenarios.bossflow = function()
    local World = require "src.world"
    startRun { coop = true, room = "moss_boss", door = "A" }
    wait(15)
    -- walk right to trip the trigger
    hold(1, "right") hold(2, "right")
    wait(160)
    release(1, "right") release(2, "right")
    local boss = findBoss()
    Test.log("boss=" .. tostring(boss and boss.bossName))
    Test.shot("boss_bramble")
    if boss then
      -- closed-mouth damage should be reduced but nonzero
      local hpBefore = boss.hp
      boss:hurt(6, boss.x - 10, boss.y)
      Test.log("armored dmg taken=" .. (hpBefore - boss.hp))
      while not boss.dead do
        boss:hurt(10, boss.x - 10, boss.y)
        wait(2)
      end
      wait(30)
      Test.log("bramble dead flag=" .. tostring(G.run.flags.boss_bramblemaw)
        .. " bossActive=" .. tostring(World.bossActive))
      Test.shot("boss_dead")
    end

    -- crucible shield logic
    World:load("furn_boss", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    hold(1, "right") hold(2, "right")
    wait(170)
    release(1, "right") release(2, "right")
    local cru = findBoss()
    Test.log("boss2=" .. tostring(cru and cru.bossName))
    if cru then
      local before = cru.hp
      cru:hurt(3, cru.x, cru.y)
      Test.log("shielded small hit dmg=" .. (before - cru.hp) .. " (want 0)")
      cru:hurt(12, cru.x, cru.y)
      Test.log("shielded BIG small-arms hit dmg=" .. (before - cru.hp) .. " (want 0)")
      cru.ventsOpen = false
      cru:hurt(8, cru.x, cru.y, { link = true })
      Test.log("link with vents CLOSED shielded=" .. tostring(cru.shielded)
        .. " dmg=" .. (before - cru.hp) .. " (want true/0)")
      cru.ventsOpen = true
      cru:hurt(8, cru.x, cru.y, { link = true })
      Test.log("link with vents OPEN shielded=" .. tostring(cru.shielded)
        .. " dmg=" .. (before - cru.hp) .. " (want false/8)")
      wait(200)
      local adds = 0
      for _, e in ipairs(World.entities) do
        if e.kind == "enemy" and not e.isBoss and not e.dead then adds = adds + 1 end
      end
      Test.log("adds while shattered=" .. adds .. " (want >=1) shatterT=" ..
        string.format("%.1f", cru.shatterT or -1))
      while not cru.dead do
        cru.shielded = false
        cru.shatterT = 10
        cru:hurt(12, cru.x, cru.y)
        wait(1)
      end
      wait(30)
      Test.log("corekey1=" .. tostring(G.run.flags.corekey1))
    end

    -- rusted warden shield law: impenetrable front, open back, dome stun
    World:load("flood_warden", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    hold(1, "right") hold(2, "right")
    wait(110)
    release(1, "right") release(2, "right")
    local war = findBoss()
    Test.log("boss3=" .. tostring(war and war.bossName))
    if war then
      war.state = "stalk"
      war.facing = -1
      local hb = war.hp
      local frontOwner = { x = war.x - 46, w = 12 }
      war:hurt(6, war.x - 30, war.y + 10, { owner = frontOwner })
      Test.log("warden front hit dmg=" .. (hb - war.hp) .. " (want 0)")
      -- fast projectile that tunneled past the midline before connecting:
      -- srcx reads as behind, but the SHOOTER is in front -> still blocked
      war:hurt(6, war.x + war.w + 4, war.y + 10, { owner = frontOwner })
      Test.log("warden tunneled front hit dmg=" .. (hb - war.hp) .. " (want 0)")
      war:hurt(6, war.x + war.w + 20, war.y + 10,
        { owner = { x = war.x + war.w + 20, w = 12 } })
      Test.log("warden back hit dmg=" .. (hb - war.hp) .. " (want 6)")
      -- recover after a charge keeps the front shield up, back open
      war:setState("recover", 3)
      hb = war.hp
      war:hurt(6, war.x - 30, war.y + 10, { owner = frontOwner })
      Test.log("warden recover front dmg=" .. (hb - war.hp) .. " (want 0)")
      war:hurt(6, war.x + war.w + 20, war.y + 10,
        { owner = { x = war.x + war.w + 20, w = 12 } })
      Test.log("warden recover back dmg=" .. (hb - war.hp) .. " (want 6)")
      -- Lu's dome interrupts the charge and stuns
      local lu = G.game.players[2]
      lu.x = war.x - 50
      lu.y = war.y
      lu.vx, lu.vy = 0, 0
      lu.energy = math.max(lu.energy or 0, 8)
      lu.domeActive = true
      war.facing = -1
      war:setState("charge", 1.4)
      for _ = 1, 60 do
        wait(1)
        if war.state ~= "charge" then break end
      end
      Test.log("warden after dome: state=" .. war.state .. " (want stunned)")
      hb = war.hp
      war:hurt(5, war.x - 30, war.y + 10, { owner = frontOwner })
      Test.log("warden stunned front dmg=" .. (hb - war.hp) .. " (want 5)")
      lu.domeActive = false
    end

    -- mycel choir: only the singing throat forwards damage
    G.run.flags.lumecore = true
    World:load("ug_boss", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    hold(1, "right") hold(2, "right")
    wait(160)
    release(1, "right") release(2, "right")
    local cho = findBoss()
    Test.log("boss4=" .. tostring(cho and cho.bossName))
    if cho then
      wait(120)  -- let the intro finish and the first verse start
      local hb = cho.hp
      cho:hurt(9, cho.x, cho.y)
      Test.log("choir heart direct hit dmg=" .. (hb - cho.hp) .. " (want 0)")
      local nodes = {}
      for _, e in ipairs(World.entities) do
        if e.idx and e.boss == cho then nodes[e.idx] = e end
      end
      Test.log("choir nodes=" .. #nodes .. " (want 3)")
      cho.singing = 1
      nodes[2]:hurt(6, nodes[2].x, nodes[2].y)
      Test.log("silent throat hit dmg=" .. (hb - cho.hp) .. " (want 0)")
      nodes[1]:hurt(6, nodes[1].x, nodes[1].y)
      Test.log("singing throat hit dmg=" .. (hb - cho.hp) .. " (want 6)")
      while not cho.dead do
        cho.singing = 1
        nodes[1]:hurt(12, nodes[1].x, nodes[1].y)
        wait(1)
      end
      wait(30)
      Test.log("choir dead flag=" .. tostring(G.run.flags.boss_mycelchoir)
        .. " pulsebloom=" .. tostring(G.run.flags.weapon_pulsebloom))
      local luW = false
      for _, w in ipairs(G.game.players[2].weapons) do
        if w.id == "pulsebloom" then luW = true end
      end
      Test.log("lu owns pulsebloom=" .. tostring(luW) .. " (want true)")
    end
    Test.log("OK bossflow")
  end

  scenarios.revive = function()
    startRun { coop = true, room = "test_arena", door = "A" }
    wait(15)
    local p1, p2 = G.game.players[1], G.game.players[2]
    p1.roomEnterProtect = 0
    p2.roomEnterProtect = 0
    p1.hp = 2
    p1.invuln = 0
    p1:takeDamage(5, p1.x + 20)
    wait(5)
    Test.log("p1 downed=" .. tostring(p1.downed) .. " bleedout=" .. math.floor(p1.bleedout))
    -- p2 walks to p1 and holds interact
    p2.x = p1.x + 14
    p2.y = p1.y
    hold(2, "interact")
    wait(120)
    release(2, "interact")
    Test.log("p1 revived=" .. tostring(not p1.downed) .. " hp=" .. p1.hp)
    Test.shot("revive_done")

    -- both down -> respawn at checkpoint with full hp
    p1.invuln = 0 p2.invuln = 0
    p1.roomEnterProtect = 0 p2.roomEnterProtect = 0
    p1:takeDamage(99, nil)
    p2:takeDamage(99, nil)
    wait(90)
    Test.log("after wipe: room=" .. G.run.room .. " p1hp=" .. p1.hp .. "/" .. p1.maxhp
      .. " downed=" .. tostring(p1.downed))
    Test.log("OK revive")
  end

  scenarios.saveload = function()
    startRun { coop = true, room = "test_arena", door = "A" }
    wait(10)
    G.run.scrap = 42
    G.run.flags.testflag = true
    G.run.players[1].weapons[1].xp = 17
    G.game:syncRun()
    local ok = G.Save.writeSlot(2, G.run)
    Test.log("write ok=" .. tostring(ok))
    local back = G.Save.readSlot(2)
    Test.log("scrap=" .. tostring(back.scrap) .. " flag=" .. tostring(back.flags.testflag)
      .. " xp=" .. tostring(back.players[1].weapons[1].xp)
      .. " room=" .. tostring(back.room))
    G.Save.deleteSlot(2)
    Test.log("deleted=" .. tostring(G.Save.readSlot(2) == nil))
    -- settings roundtrip
    G.settings.volMusic = 0.35
    G.Save.saveSettings()
    local s2 = G.Save.loadSettings()
    Test.log("settings vol=" .. tostring(s2.volMusic))
    Test.log("OK saveload")
  end

  scenarios.mender = function()
    local World = require "src.world"
    startRun { coop = true, room = "core_boss", door = "A",
      flags = { coredoor = true } }
    wait(15)
    hold(1, "right") hold(2, "right")
    wait(200)
    release(1, "right") release(2, "right")
    local mo = findBoss()
    Test.log("phase1=" .. tostring(mo and mo.bossName))
    if mo then
      while not mo.dead do
        mo:hurt(15, mo.x, mo.y)
        wait(1)
      end
      -- dialogue plays; advance it
      for i = 1, 12 do
        if G.game.dialogue then G.game.dialogue:advance() end
        wait(4)
      end
      wait(10)
      local m2 = findBoss()
      Test.log("phase2=" .. tostring(m2 and m2.bossName))
      Test.shot("mender_fight")
      if m2 then
        while not m2.dead do
          m2:hurt(15, m2.x, m2.y)
          wait(1)
        end
        wait(40)
        -- the Mender yields: advance the safe-mode speech
        for i = 1, 12 do
          if G.game.dialogue then G.game.dialogue:advance() end
          wait(4)
        end
        Test.log("mender_yield=" .. tostring(G.run.flags.mender_yield)
          .. " (want true)")
        if not G.run.flags.mender_yield then error("mender did not yield") end
        -- the Seat appears; take it (BECOME)
        local seat
        for _, e in ipairs(World.entities) do
          if e.hint == "the Seat" then seat = e break end
        end
        Test.log("seat=" .. tostring(seat ~= nil) .. " (want true)")
        if not seat then error("the Seat did not appear") end
        seat:interact(G.game.players[1])
        wait(2)
        -- choice: first option (Become) is preselected
        for i = 1, 8 do
          if G.game and G.game.dialogue then G.game.dialogue:advance() end
          wait(3)
        end
        wait(40)
        Test.log("ending flag=" .. tostring(G.run.flags.ending)
          .. " become=" .. tostring(G.run.flags.ending_become)
          .. " state=" .. tostring(G.State.top().name))
        if not G.run.flags.ending then error("BECOME did not trigger the ending") end
        Test.shot("ending_state")
        -- run the ending cards (8 cards incl. the sting)
        for i = 1, 10 do menuNav("confirm") wait(10) end
        Test.shot("credits")
      end
    end
    Test.log("OK mender")
  end

  -- ----------------------------------------------------------------
  -- solo playability proofs
  -- ----------------------------------------------------------------
  scenarios.sololink = function()
    startRun { coop = false, room = "furn_boss", door = "A" }
    wait(20)
    Test.log("labels: jump=" .. G.btn(1, "jump") .. " partner=" .. G.btn(1, "partner")
      .. " anyPad=" .. tostring(G.anyPad()))
    hold(1, "right")
    wait(200)
    release(1, "right")
    local World = require "src.world"
    local cru = World.bossActive
    Test.log("boss=" .. tostring(cru and cru.bossName))
    if cru then
      -- recall idle bot to active's side
      hold(1, "partner")
      wait(30)
      release(1, "partner")
      wait(5)
      local p1, p2 = G.game.players[1], G.game.players[2]
      Test.log("dist=" .. math.floor(require("src.core.util").dist(p1.x, p1.y, p2.x, p2.y)))
      -- solo link shot via warp button
      press(1, "warp")
      Test.log("linkState=" .. tostring(G.game.linkState ~= nil))
      wait(75)
      wait(20)
      Test.log("shielded after solo link=" .. tostring(cru.shielded) .. " (want false)")
      Test.shot("solo_link")
    end
    Test.log("OK sololink")
  end

  scenarios.solobridge = function()
    startRun { coop = false, room = "crys_3", door = "A" }
    wait(20)
    local World = require "src.world"
    local p1, p2 = G.game.players[1], G.game.players[2]
    -- walk onto the plate at x=8
    hold(1, "right")
    while p1.x < 8 * 16 - 2 do wait(1) end
    release(1, "right")
    wait(10)
    Test.log("bridge flag=" .. tostring(G.run.flags.bridge_c3))
    Test.log("bridge solid=" .. tostring(World:isSolid(20, 12)) .. " (want true)")
    -- recall partner onto the plate, then swap and cross
    hold(1, "partner")
    wait(30)
    release(1, "partner")
    wait(5)
    press(1, "partner")  -- tap: swap to Lu
    wait(25)
    Test.log("activeBot=" .. G.game.activeBot)
    hold(1, "right")
    local steps = 0
    while steps < 600 and p2.x < 47 * 16 do wait(1) steps = steps + 1 end
    release(1, "right")
    Test.log("lu x=" .. math.floor(p2.x / 16) .. " y=" .. math.floor(p2.y / 16)
      .. " downed=" .. tostring(p2.downed))
    Test.log((p2.x >= 47 * 16 and not p2.downed) and "OK solobridge" or "FAIL solobridge")
    Test.shot("solo_bridge")
  end

  scenarios.soloenergize = function()
    startRun { coop = false, room = "furn_4", door = "A" }
    wait(20)
    local World = require "src.world"
    local p1, p2 = G.game.players[1], G.game.players[2]
    press(1, "partner")  -- swap to Lu
    wait(20)
    -- march Lu to the machine at x=30
    hold(1, "right")
    local steps = 0
    while steps < 800 and p2.x < 29 * 16 do wait(1) steps = steps + 1 end
    release(1, "right")
    wait(5)
    press(1, "interact")
    wait(10)
    Test.log("furnvault flag=" .. tostring(G.run.flags.furnvault) .. " (want true)")
    Test.log("gate open=" .. tostring(not World:isSolid(36, 9)) .. " (want true)")
    Test.log("OK soloenergize")
  end

  -- ----------------------------------------------------------------
  -- hotkey audit: every open/close pairing must toggle cleanly
  -- ----------------------------------------------------------------
  scenarios.hotkeys = function()
    startRun { coop = true, room = "test_arena", door = "A" }
    wait(20)
    local function state() return G.State.top().name end
    local function tap(slot, action)
      press(slot, action)
      wait(6)
    end
    -- map: open with MAP, close with MAP
    tap(1, "map");  Test.log("map open -> " .. state())
    tap(1, "map");  Test.log("map close(map) -> " .. state())
    -- map: close with PAUSE
    tap(1, "map");  tap(1, "pause"); Test.log("map close(pause) -> " .. state())
    -- map: close with menu-cancel (pad B / Esc path)
    tap(1, "map");  menuNav("cancel"); wait(6)
    Test.log("map close(cancel) -> " .. state())
    -- map: close with menu backbtn (pad BACK / Tab menu path)
    tap(1, "map");  menuNav("backbtn"); wait(6)
    Test.log("map close(backbtn) -> " .. state())
    -- pause: open/close with PAUSE
    tap(1, "pause"); Test.log("pause open -> " .. state())
    tap(1, "pause"); Test.log("pause close(pause) -> " .. state())
    -- pause: close with menu start
    tap(1, "pause"); menuNav("start"); wait(6)
    Test.log("pause close(start) -> " .. state())
    -- pause: close with menu cancel
    tap(1, "pause"); menuNav("cancel"); wait(6)
    Test.log("pause close(cancel) -> " .. state())
    -- P2 map key
    tap(2, "map"); Test.log("p2 map open -> " .. state())
    tap(2, "map"); Test.log("p2 map close -> " .. state())
    -- map opened by P1, closed by P2
    tap(1, "map"); tap(2, "map"); Test.log("cross-player close -> " .. state())
    -- F1 progress panel (test mode): open F1, close F1 / cancel / map
    local function f1()
      G.Input.queue[#G.Input.queue + 1] = { kind = "rawkey", id = "f1" }
      wait(6)
    end
    G.settings.testmode = true
    f1(); Test.log("progress open -> " .. state())
    if state() ~= "progress" then Test.log("FAIL f1 did not open progress") end
    f1(); Test.log("progress close(f1) -> " .. state())
    if state() ~= "game" then Test.log("FAIL f1 did not close progress") end
    f1(); menuNav("cancel"); wait(6)
    Test.log("progress close(cancel) -> " .. state())
    if state() ~= "game" then Test.log("FAIL cancel did not close progress") end
    f1(); tap(1, "map")
    Test.log("progress close(map) -> " .. state())
    if state() ~= "game" then Test.log("FAIL map did not close progress") end
    -- testmode OFF: F1 must do nothing
    G.settings.testmode = false
    f1()
    if state() ~= "game" then Test.log("FAIL f1 opened progress with testmode off") end
    G.settings.testmode = true
    Test.log("progress hotkey verified")
    Test.log("OK hotkeys")
  end

  -- ----------------------------------------------------------------
  -- CHAOS: input-fuzz monkey. Seeded random gameplay inputs in every
  -- room with the frame-level invariants armed. Finds tunneling, weird
  -- ability overlaps, physics blowups. Tunables:
  --   EMBERDEEP_FUZZ_STEPS  steps per room (default 600)
  --   EMBERDEEP_FUZZ_SEED   RNG seed (default 1)
  --   EMBERDEEP_ROOMS       comma-separated room filter
  -- ----------------------------------------------------------------
  scenarios.fuzz = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local steps = tonumber(os.getenv("EMBERDEEP_FUZZ_STEPS")) or 600
    local seed = tonumber(os.getenv("EMBERDEEP_FUZZ_SEED")) or 1
    local only = os.getenv("EMBERDEEP_ROOMS")
    local rng = love.math.newRandomGenerator(seed)
    local ACTIONS = { "left", "right", "up", "down", "jump", "fire",
      "special", "interact", "util", "partner", "warp" }
    local fuzzed = 0
    for _, id in ipairs(WM.ROOMS) do
      if not only or only:find(id, 1, true) then
        local ok = pcall(function() World:load(id, nil, true) end)
        if ok then
          local dchars = {}
          for ch, d in pairs(World.doors) do
            if d.link then dchars[#dchars + 1] = ch end
          end
          if #dchars > 0 then
            table.sort(dchars)
            pcall(function()
              World:load(id, dchars[rng:random(#dchars)], true)
            end)
          end
          fuzzed = fuzzed + 1
          for _, p in ipairs(World.players) do
            p.hp = 9999 p.dead = false p.downed = false
          end
          for i = 1, steps do
            for slot = 1, 2 do
              local a = ACTIONS[rng:random(#ACTIONS)]
              if rng:random() < 0.5 then
                G.Input.virtual[slot][a] = true
              else
                G.Input.virtual[slot][a] = nil
              end
            end
            wait(1)
            if i % 60 == 0 then
              -- keep the fuzz inside this room and alive
              if G.run.room ~= id then
                World.pendingTransition = nil
                pcall(function() World:load(id, nil, true) end)
              end
              for _, p in ipairs(World.players) do
                p.hp = 9999 p.dead = false p.downed = false
              end
              if G.State.top().name ~= "game" then
                menuNav("cancel")
              end
            end
          end
          for slot = 1, 2 do
            for _, a in ipairs(ACTIONS) do G.Input.virtual[slot][a] = nil end
          end
        end
      end
    end
    Test.log("fuzzed " .. fuzzed .. " rooms x " .. steps
      .. " steps, seed " .. seed)
    Test.log("OK fuzz")  -- invariant violations fail the run at DONE
  end

  -- ----------------------------------------------------------------
  -- CHAOS: UI liveness. Storm random menu/hotkey inputs, then prove a
  -- short cancel-spam always returns to gameplay (generalizes the v1.2
  -- Tab bug). Save+Quit landing on the title is recovered, not failed.
  --   EMBERDEEP_UI_STEPS  input rounds (default 1500)
  --   EMBERDEEP_FUZZ_SEED RNG seed (default 1)
  -- ----------------------------------------------------------------
  scenarios.uilive = function()
    startRun { coop = true, room = "camp_main", door = "A" }
    wait(30)
    local steps = tonumber(os.getenv("EMBERDEEP_UI_STEPS")) or 1500
    local seed = tonumber(os.getenv("EMBERDEEP_FUZZ_SEED")) or 1
    local rng = love.math.newRandomGenerator(seed)
    local fails = 0
    G.settings.testmode = true
    local MENU = { "up", "down", "left", "right", "confirm", "cancel",
      "start", "backbtn" }
    local META = { "pause", "map", "interact" }
    local function escape()
      for _ = 1, 30 do
        local top = G.State.top().name
        if top == "title" or top == "slots" then
          startRun { coop = true, room = "camp_main", door = "A" }
          wait(30)
        elseif top == "game" and not (G.game and G.game.dialogue) then
          return true
        elseif G.game and G.game.dialogue then
          press(rng:random() < 0.5 and 1 or 2, "confirm")
          wait(4)
        else
          menuNav("cancel")
          wait(4)
        end
      end
      return false
    end
    for i = 1, steps do
      local r = rng:random()
      if r < 0.45 then
        menuNav(MENU[rng:random(#MENU)])
      elseif r < 0.8 then
        press(rng:random(2), META[rng:random(#META)], 2)
      elseif r < 0.9 then
        G.Input.queue[#G.Input.queue + 1] = { kind = "rawkey", id = "f1" }
        wait(2)
      else
        G.Input.queue[#G.Input.queue + 1] = { kind = "rawkey", id = "tab" }
        wait(2)
      end
      if i % 100 == 0 then
        if not escape() then
          fails = fails + 1
          Test.log("FAIL UILOCK at round " .. i .. " top="
            .. tostring(G.State.top().name))
          -- hard recovery so the storm can continue
          while #G.State.stack > 1 do G.State.pop() end
        end
      end
    end
    if not escape() then
      fails = fails + 1
      Test.log("FAIL UILOCK at end top=" .. tostring(G.State.top().name))
    end
    Test.log("ui storm: " .. steps .. " rounds, seed " .. seed)
    if fails == 0 then Test.log("OK uilive")
    else Test.log("FAIL uilive: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- CHAOS: soak. Hours of simulated play cycling every room with
  -- combat alive, watching Lua memory and entity counts for leaks.
  --   EMBERDEEP_SOAK_MINUTES sim-minutes (default 8)
  --   also set EMBERDEEP_MAX_MINUTES >= soak+2 (harness time cap)
  -- ----------------------------------------------------------------
  scenarios.soak = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local minutes = tonumber(os.getenv("EMBERDEEP_SOAK_MINUTES")) or 8
    local total = minutes * 3600
    local rng = love.math.newRandomGenerator(7)
    local ACTIONS = { "left", "right", "jump", "fire", "special" }
    local samples = {}
    local step, roomIx = 0, 1
    collectgarbage("collect")
    local baseMem = collectgarbage("count")
    while step < total do
      local id = WM.ROOMS[(roomIx - 1) % #WM.ROOMS + 1]
      roomIx = roomIx + 1
      local ok = pcall(function() World:load(id, nil, true) end)
      if ok then
        local dchars = {}
        for ch, d in pairs(World.doors) do
          if d.link then dchars[#dchars + 1] = ch end
        end
        if #dchars > 0 then
          table.sort(dchars)
          pcall(function()
            World:load(id, dchars[rng:random(#dchars)], true)
          end)
        end
        for _, p in ipairs(World.players) do
          p.hp = 9999 p.dead = false p.downed = false
        end
        for _ = 1, 240 do
          for slot = 1, 2 do
            local a = ACTIONS[rng:random(#ACTIONS)]
            G.Input.virtual[slot][a] = (rng:random() < 0.5) and true or nil
          end
          wait(1)
          step = step + 1
        end
        for slot = 1, 2 do
          for _, a in ipairs(ACTIONS) do G.Input.virtual[slot][a] = nil end
        end
        World.pendingTransition = nil
        if G.State.top().name ~= "game" then menuNav("cancel") end
        if step % 3600 < 240 then
          collectgarbage("collect")
          local mem = collectgarbage("count")
          samples[#samples + 1] = { step = step, mem = mem,
            ents = #World.entities }
          Test.log(string.format("soak %dmin mem=%.0fkB ents=%d",
            math.floor(step / 3600), mem, #World.entities))
        end
      end
    end
    collectgarbage("collect")
    local endMem = collectgarbage("count")
    Test.log(string.format("soak done: mem %.0f -> %.0f kB over %d sim-min",
      baseMem, endMem, minutes))
    if endMem > baseMem * 3 + 20000 then
      Test.log("FAIL soak: memory growth suggests a leak")
    else
      Test.log("OK soak")
    end
  end

  -- ----------------------------------------------------------------
  -- boss re-entry: die to a boss, respawn, come back -- the arena must
  -- fully reset (no stale bossActive/door-lock, no leftover body, a
  -- fresh trigger, full boss hp, no half-set flags)
  -- ----------------------------------------------------------------
  scenarios.bossreenter = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true, cryocoils = true,
    } }
    wait(12)
    local World = require "src.world"
    local fails = 0
    local ROOMS = { "moss_boss", "flood_warden", "flood_boss", "furn_golem",
      "furn_boss", "crys_boss", "sky_boss", "core_boss", "ug_boss",
      "cold_boss" }
    for _, id in ipairs(ROOMS) do
      G.run.checkpoint = { room = "camp_main", door = "B" }
      World:load(id, "A", true)
      wait(20)
      local function findTrigger()
        for _, e in ipairs(World.entities) do
          if e.bossId and e.kind ~= "enemy" and not e.dead then return e end
        end
      end
      local trig = findTrigger()
      if not trig then
        Test.log("FAIL NOTRIGGER " .. id) fails = fails + 1
      else
        local function summon()
          for _, p in ipairs(World.players) do
            p.x, p.y = trig.x, trig.y - 4
            p.vx, p.vy = 0, 0
            p.hp = p.maxhp
            p.dead, p.downed = false, false
          end
          for i = 1, 300 do
            wait(1)
            if World.bossActive then return true end
          end
          return false
        end
        if not summon() then
          Test.log("FAIL NOSPAWN " .. id) fails = fails + 1
        else
          local maxhp = World.bossActive.maxhp
          World.bossActive.hp = World.bossActive.hp - 5
          wait(30)
          -- a door touched mid-fight must be DROPPED, not queued: kill
          -- the boss with a request pending and prove nobody teleports
          World:requestTransition("A")
          wait(5)
          if World.pendingTransition then
            Test.log("FAIL QUEUED " .. id
              .. " transition request survived the boss lock")
            fails = fails + 1
          end
          World:requestTransition("A")
          local b = World.bossActive
          if b then b.hp = 0 end
          for _ = 1, 120 do
            wait(1)
            if not World.bossActive then break end
          end
          wait(30)
          if G.run.room ~= id then
            Test.log("FAIL YANKED " .. id .. " -> " .. tostring(G.run.room)
              .. " (stale transition fired on boss death)")
            fails = fails + 1
            G.run.flags["boss_" .. trig.bossId] = nil
          else
            G.run.flags["boss_" .. trig.bossId] = nil
            World:load(id, "A", true)
            wait(20)
            trig = findTrigger()
          end
          if not trig then
            Test.log("FAIL RETRIGGER-AFTER-KILL " .. id) fails = fails + 1
            goto nextboss
          end
          if not summon() then
            Test.log("FAIL RESUMMON-AFTER-KILL " .. id) fails = fails + 1
            goto nextboss
          end
          World.bossActive.hp = World.bossActive.hp - 5
          wait(10)
          -- wipe and respawn (transitions are locked during the fight,
          -- so death is the one way out mid-fight)
          G.game:respawnAtCheckpoint()
          for i = 1, 200 do
            wait(1)
            if G.run.room == "camp_main" then break end
          end
          if G.run.room ~= "camp_main" then
            Test.log("FAIL NORESPAWN " .. id .. " (room=" ..
              tostring(G.run.room) .. ")") fails = fails + 1
          end
          if G.run.flags["boss_" .. trig.bossId] then
            Test.log("FAIL FLAGLEAK " .. id .. " boss flag set without a kill")
            fails = fails + 1
          end
          -- re-enter
          World:load(id, "A", true)
          wait(20)
          if World.bossActive then
            Test.log("FAIL STALEBOSS " .. id) fails = fails + 1
          end
          local bodies = 0
          for _, e in ipairs(World.entities) do
            if e.bossId and e.kind == "enemy" and not e.dead then
              bodies = bodies + 1
            end
          end
          if bodies > 0 then
            Test.log("FAIL LEFTOVER " .. id .. " boss bodies=" .. bodies)
            fails = fails + 1
          end
          trig = findTrigger()
          if not trig then
            Test.log("FAIL NORETRIGGER " .. id) fails = fails + 1
          elseif not summon() then
            Test.log("FAIL NORESPAWN2 " .. id) fails = fails + 1
          elseif World.bossActive.hp ~= maxhp then
            Test.log("FAIL NOTRESET " .. id .. " hp=" ..
              World.bossActive.hp .. "/" .. maxhp) fails = fails + 1
          end
          G.game:respawnAtCheckpoint()
          wait(100)
          ::nextboss::
        end
      end
    end
    if fails == 0 then Test.log("OK bossreenter")
    else Test.log("FAIL bossreenter: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- persistence: collected things stay collected across room reloads
  -- and save/load; nothing is double-collectable
  -- ----------------------------------------------------------------
  scenarios.persistence = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local fails, chests, caps = 0, 0, 0
    for _, id in ipairs(WM.ROOMS) do
      local ok = pcall(function() World:load(id, nil, true) end)
      if ok then
        wait(2)
        local found = {}
        for _, e in ipairs(World.entities) do
          if (e.kind == "chest" or e.kind == "capsule") and e.flag
              and not G.run.flags[e.flag] then
            found[#found + 1] = { kind = e.kind, flag = e.flag }
            G.run.flags[e.flag] = true  -- "collect" it
          end
        end
        if #found > 0 then
          World:load(id, nil, true)
          wait(2)
          for _, f in ipairs(found) do
            local present, openState
            for _, e in ipairs(World.entities) do
              if e.flag == f.flag and not e.dead then
                present = e
                openState = e.open
              end
            end
            if f.kind == "chest" then
              chests = chests + 1
              if not present then
                Test.log("FAIL CHESTGONE " .. id .. " " .. f.flag)
                fails = fails + 1
              elseif not openState or present.interactable then
                Test.log("FAIL RELOOT " .. id .. " " .. f.flag
                  .. " respawned closed") fails = fails + 1
              end
            else
              caps = caps + 1
              if present then
                Test.log("FAIL DOUBLECOLLECT " .. id .. " " .. f.flag
                  .. " capsule/tank respawned after collection")
                fails = fails + 1
              end
            end
          end
        end
      end
    end
    -- save/load roundtrip keeps the flags
    G.game:syncRun()
    G.Save.writeSlot(3, G.run)
    local back = G.Save.readSlot(3)
    if not back then
      Test.log("FAIL SAVELOAD roundtrip") fails = fails + 1
    else
      for _, f in ipairs({ "chest_sparkjump", "cap_camp", "chest_moss5" }) do
        if G.run.flags[f] and not back.flags[f] then
          Test.log("FAIL FLAGDROP " .. f) fails = fails + 1
        end
      end
    end
    Test.log("persistence: " .. chests .. " chests, " .. caps
      .. " capsules/tanks checked")
    if fails == 0 then Test.log("OK persistence")
    else Test.log("FAIL persistence: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- save compatibility: hand-written saves in the layouts of released
  -- versions must boot into a sane, grounded game
  -- ----------------------------------------------------------------
  scenarios.savecompat = function()
    local GOLDEN = {
      { name = "v1.0-fresh", data = {
        slot = 2, difficulty = 2, coop = true,
        playtime = 12, scrap = 0,
        flags = {}, visited = { camp_awake = true },
        room = "camp_awake", door = "A",
        checkpoint = { room = "camp_awake", door = "A" },
        players = {
          { maxhp = 12, hp = 12, weapons = { { id = "boltdriver", xp = 0 } }, curWeapon = 1 },
          { maxhp = 12, hp = 12, weapons = { { id = "sparkshot", xp = 0 } }, curWeapon = 1,
            maxenergy = 100 },
        },
        -- note: no 'capsules' field (added in a later version)
      } },
      { name = "v1.2-midgame", data = {
        slot = 2, difficulty = 1, coop = false,
        playtime = 4000, scrap = 55, capsules = 3,
        flags = { sparkjump = true, grapple = true, hydroseals = true,
          boss_bramblemaw = true, boss_rustwarden = true,
          chest_sparkjump = true, chest_grapple = true },
        visited = { camp_awake = true, camp_main = true, moss_1 = true,
          flood_1 = true, flood_2 = true },
        room = "flood_hub", door = "A",
        checkpoint = { room = "flood_hub", door = "A" },
        players = {
          { maxhp = 24, hp = 20, weapons = { { id = "boltdriver", xp = 40 },
            { id = "scatterhex", xp = 10 } }, curWeapon = 2 },
          { maxhp = 24, hp = 24, weapons = { { id = "sparkshot", xp = 25 } },
            curWeapon = 1, maxenergy = 120 },
        },
      } },
    }
    -- Write these the way the OLD builds wrote them: straight to disk at
    -- their real version. Routing them through writeSlot would stamp the
    -- CURRENT version and silently skip the migration this test exists to
    -- prove.
    local Ser = require "src.core.ser"
    local UU = require "src.core.util"
    local function writeGolden(i, data, version)
      local d = UU.copy(data)
      d.version = version
      d.savedAt = os.time()
      return love.filesystem.write("slot" .. i .. ".sav", Ser.pack(d))
    end

    local fails = 0
    for _, g in ipairs(GOLDEN) do
      local wrote = writeGolden(2, g.data, g.version or 1)
      if not wrote then
        Test.log("FAIL WRITE " .. g.name) fails = fails + 1
      else
        local run = G.Save.readSlot(2)
        if not run then
          Test.log("FAIL READ " .. g.name) fails = fails + 1
        else
          local ok, err = pcall(function()
            G.run = run
            G.State.switch(require "src.states.game", { coop = run.coop })
          end)
          if not ok then
            Test.log("FAIL BOOT " .. g.name .. ": " .. tostring(err))
            fails = fails + 1
          else
            wait(90)
            if G.run.room ~= g.data.room then
              Test.log("FAIL ROOM " .. g.name .. " -> " .. tostring(G.run.room))
              fails = fails + 1
            end
            local World = require "src.world"
            local settled = false
            for _ = 1, 150 do
              wait(1)
              local p = World.players[1]
              local tx = math.floor((p.x + p.w / 2) / 16)
              local ty = math.floor((p.y + p.h / 2) / 16)
              if p.onGround or World:isWater(tx, ty) then settled = true break end
            end
            if not settled then
              Test.log("FAIL AFLOAT " .. g.name) fails = fails + 1
            end
            -- v2 migration: shard-XP and stat grants become forge tiers
            if not G.run.forge then
              Test.log("FAIL MIGRATE " .. g.name .. " no forge table")
              fails = fails + 1
            elseif g.name == "v1.2-midgame" then
              local fo = G.run.forge
              if fo.boltdriver ~= 3 or fo.sparkshot ~= 2 or fo.scatterhex ~= 1 then
                Test.log("FAIL MIGRATE weapon tiers: bolt=" .. tostring(fo.boltdriver)
                  .. " spark=" .. tostring(fo.sparkshot)
                  .. " scatter=" .. tostring(fo.scatterhex))
                fails = fails + 1
              end
              if fo.hpTier ~= 3 or fo.energyTier ~= 1 then
                Test.log("FAIL MIGRATE stat tiers: hp=" .. tostring(fo.hpTier)
                  .. " en=" .. tostring(fo.energyTier))
                fails = fails + 1
              end
            end
            Test.log("loaded " .. g.name .. " ok: room=" .. G.run.room)
          end
        end
      end
    end
    -- REGRESSION: a save written by the CURRENT build must land on disk
    -- already stamped Save.VERSION. If writeSlot stamps anything older,
    -- every load silently re-runs the migration chain -- harmless while
    -- the steps are idempotent, save-eating the moment one isn't.
    local fresh = G.Save.newRun(2, 2, false)
    if not G.Save.writeSlot(2, fresh) then
      Test.log("FAIL WRITE fresh") fails = fails + 1
    else
      local raw = love.filesystem.read("slot2.sav")
      local onDisk = raw and Ser.unpack(raw)
      if not onDisk then
        Test.log("FAIL READ fresh") fails = fails + 1
      elseif onDisk.version ~= G.Save.VERSION then
        Test.log("FAIL VERSION fresh: on disk v" .. tostring(onDisk.version)
          .. ", current is v" .. tostring(G.Save.VERSION))
        fails = fails + 1
      else
        Test.log("fresh save stamped v" .. tostring(onDisk.version) .. " ok")
      end
    end

    G.Save.deleteSlot(2)
    if fails == 0 then Test.log("OK savecompat")
    else Test.log("FAIL savecompat: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- checkpoints: respawning at every save statue / lantern in the game
  -- must put the players in the right room, on the ground
  -- ----------------------------------------------------------------
  scenarios.checkpoints = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local fails, count = 0, 0
    for _, id in ipairs(WM.ROOMS) do
      local def = World.getRoomDef(id)
      local spots = {}
      if def.key then
        local rows = {}
        for line in def.map:gmatch("[^\n]+") do rows[#rows + 1] = line end
        for ch, spec in pairs(def.key) do
          if spec == "save" or spec == "checkpoint" then
            for ty, line in ipairs(rows) do
              local tx = line:find(ch, 1, true)
              while tx do
                spots[#spots + 1] = { tx = tx - 1, ty = ty - 1 }
                tx = line:find(ch, tx + 1, true)
              end
            end
          end
        end
      end
      for _, sp in ipairs(spots) do
        count = count + 1
        G.run.checkpoint = { room = id, x = sp.tx * 16 + 2, y = sp.ty * 16 }
        G.game:respawnAtCheckpoint()
        for _ = 1, 150 do
          wait(1)
          if G.run.room == id and G.game.fadeDir == 0 then break end
        end
        if G.run.room ~= id then
          Test.log("FAIL CPROOM " .. id .. " -> " .. tostring(G.run.room))
          fails = fails + 1
        else
          local settled = false
          for _ = 1, 150 do
            wait(1)
            local p = World.players[1]
            local tx2 = math.floor((p.x + p.w / 2) / 16)
            local ty2 = math.floor((p.y + p.h / 2) / 16)
            if p.onGround or World:isWater(tx2, ty2) then settled = true break end
          end
          if not settled then
            Test.log("FAIL CPFLOAT " .. id .. " at " .. sp.tx .. "," .. sp.ty)
            fails = fails + 1
          end
        end
        for _, p in ipairs(World.players) do p.hp = 9999 end
      end
    end
    Test.log("checkpoints tested: " .. count)
    if fails == 0 then Test.log("OK checkpoints")
    else Test.log("FAIL checkpoints: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- co-op transitions: doors while a partner is downed or parked must
  -- carry everyone along in a sane state
  -- ----------------------------------------------------------------
  scenarios.cooptransition = function()
    startRun { coop = true, room = "camp_main", door = "A" }
    wait(30)
    local World = require "src.world"
    local fails = 0
    local P1, P2 = G.game.players[1], G.game.players[2]
    -- move both bots to the right side first (the co-op screen tether
    -- stops anyone straying a full screen from a downed partner -- that
    -- is by design), then down P2 next to the door
    P1.x, P1.y = 74 * 16, 10 * 16
    P2.x, P2.y = 75 * 16, 10 * 16
    P1.vx, P1.vy, P2.vx, P2.vy = 0, 0, 0, 0
    require("src.camera").jumpTo(P1.x, P1.y)  -- teleports must snap the cam
    wait(10)
    -- down P2 with a real bleed-out timer, as the damage path would set
    P2.hp = 0
    P2.downed = true
    P2.bleedout = 30
    wait(10)
    -- P1 walks out the right edge door (B -> moss_1)
    hold(1, "right")
    for _ = 1, 150 do
      wait(1)
      if G.run.room == "moss_1" then break end
    end
    release(1, "right")
    wait(30)
    if G.run.room ~= "moss_1" then
      Test.log("FAIL no transition with downed partner") fails = fails + 1
    else
      if P2.dead then
        Test.log("FAIL downed partner died in transit") fails = fails + 1
      end
      if not P2.downed then
        Test.log("FAIL downed state lost in transit") fails = fails + 1
      end
      local dx = math.abs(P1.x - P2.x)
      if dx > 220 then
        Test.log("FAIL partner left behind (" .. math.floor(dx) .. "px)")
        fails = fails + 1
      end
    end
    -- revive on the other side
    P2.x, P2.y = P1.x + 8, P1.y
    hold(1, "interact")
    local revived = false
    for _ = 1, 400 do
      wait(1)
      if not P2.downed then revived = true break end
    end
    release(1, "interact")
    if not revived then
      Test.log("FAIL cannot revive after transition") fails = fails + 1
    end
    -- solo: parked bot must ride along too
    startRun { coop = false, room = "camp_main", door = "A" }
    wait(30)
    P1, P2 = G.game.players[1], G.game.players[2]
    P1.x, P1.y = 77 * 16, 10 * 16
    P1.vx, P1.vy = 0, 0
    hold(1, "right")
    for _ = 1, 120 do
      wait(1)
      if G.run.room == "moss_1" then break end
    end
    release(1, "right")
    wait(30)
    if G.run.room ~= "moss_1" then
      Test.log("FAIL solo transition") fails = fails + 1
    else
      local dx = math.abs(P1.x - P2.x)
      if dx > 220 then
        Test.log("FAIL parked bot left behind (" .. math.floor(dx) .. "px)")
        fails = fails + 1
      end
    end
    if fails == 0 then Test.log("OK cooptransition")
    else Test.log("FAIL cooptransition: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- physics calibration: the validators' movement model (scripts/
  -- roommodel.py JUMP_H=3, JUMP_H_SPARK=4, GAP_W=4, rope 110px) must
  -- match the real engine. If this fails, re-measure and update BOTH.
  -- ----------------------------------------------------------------
  scenarios.calibrate = function()
    startRun { coop = true, room = "test_arena", door = "A" }
    wait(30)
    local World = require "src.world"
    local P1, P2 = G.game.players[1], G.game.players[2]
    local fails = 0
    local function place(p, tx, ty)
      p.x, p.y = tx * 16 + 2, (ty + 1) * 16 - p.h - 0.5
      p.vx, p.vy = 0, 0
    end
    local function apex(slot, p, holdSteps)
      local startY = p.y
      local minY = p.y
      hold(slot, "jump")
      for i = 1, 50 do
        wait(1)
        if p.y < minY then minY = p.y end
        if i == holdSteps then release(slot, "jump") end
      end
      release(slot, "jump")
      wait(20)
      return (startY - minY) / 16
    end
    place(P2, 28, 13)
    -- 1) Vess jump apex vs JUMP_H = 3
    place(P1, 8, 13) wait(10)
    local j = apex(1, P1, 22)
    Test.log(string.format("vess jump apex: %.2f tiles (model JUMP_H=3)", j))
    if j < 3.15 or j >= 4 then
      Test.log("FAIL JUMP_H drift: engine " .. j
        .. " (need 3.15-3.99: real margin over 3-tile ledges)")
      fails = fails + 1
    end
    -- 2) Lu spark jump vs JUMP_H_SPARK = 4
    G.run.flags.sparkjump = true
    place(P2, 14, 13) wait(10)
    local js = apex(2, P2, 24)
    Test.log(string.format("lu spark jump apex: %.2f tiles (model 4)", js))
    if js < 4.15 or js >= 5 then
      Test.log("FAIL JUMP_H_SPARK drift: engine " .. js
        .. " (need 4.15-4.99: real margin over 4-tile ledges)")
      fails = fails + 1
    end
    -- 3b) DRIFT VANES hover gap vs roommodel's GAP_W_HOVER = 10.
    -- Measured headless at 12.25 tiles (tools/vanes_test.lua); the model
    -- carries two tiles of margin. If airAccel or the hover clamp is ever
    -- retuned, this fails before a player falls in a hole.
    G.run.flags.driftvanes = true
    place(P2, 16, 13) wait(10)
    hold(2, "right")
    wait(30)
    local hx
    hold(2, "jump")
    for _ = 1, 20 do wait(1) if not P2.onGround then hx = P2.x break end end
    local lipY = P2.y
    local hoverBest = 0
    for _ = 1, 160 do
      wait(1)
      if P2.y <= lipY + 1 then hoverBest = P2.x - (hx or P2.x) end
      if P2.onGround then break end
    end
    release(2, "jump") release(2, "right")
    Test.log(string.format("lu hover gap: %.2f tiles (model GAP_W_HOVER=10)",
      hoverBest / 16))
    if hoverBest / 16 < 10 or hoverBest / 16 >= 14 then
      Test.log("FAIL GAP_W_HOVER drift: engine " .. (hoverBest / 16)
        .. " (need 10-13.99)")
      fails = fails + 1
    end
    G.run.flags.driftvanes = nil
    wait(5)

    -- 3) running jump distance vs GAP_W = 4 (open-sky runway: cols 16+)
    place(P1, 16, 13) wait(10)
    hold(1, "right")
    wait(30)
    local takeoffX
    hold(1, "jump")
    for _ = 1, 20 do wait(1) if not P1.onGround then takeoffX = P1.x break end end
    for _ = 1, 90 do wait(1) if P1.onGround then break end end
    release(1, "jump") release(1, "right")
    local gap = takeoffX and (P1.x - takeoffX) / 16 or -1
    Test.log(string.format("running jump distance: %.2f tiles (model GAP_W=4)", gap))
    if math.floor(gap) < 4 then
      Test.log("FAIL GAP_W drift: engine " .. gap) fails = fails + 1
    end
    -- 4) water exit: model lets a surface hop land 2 tiles above water.
    -- Swim at the surface (center in water, head clear), jump.
    local surfaceY = 14 * 16
    place(P1, 34, 13)
    P1.y = surfaceY - P1.h + 9   -- center just below the waterline
    P1.vx, P1.vy = 0, 0
    wait(3)
    local minY = P1.y
    hold(1, "jump")
    for _ = 1, 45 do wait(1) if P1.y < minY then minY = P1.y end end
    release(1, "jump")
    local rise = (surfaceY - (minY + P1.h)) / 16
    Test.log(string.format("water breach: feet %.2f tiles above surface (model needs 2)", rise))
    if rise < 1.9 then
      Test.log("FAIL water hop drift: engine " .. rise) fails = fails + 1
    end
    -- 5) grapple rope: 5 tiles across / 3 up connects (93px), 8 across
    -- does not (>110px). Grapple engages while SPECIAL is held in air.
    G.run.flags.grapple = true
    local function ropeTest(dtiles)
      place(P1, 6, 13) P1.facing = 1 wait(5)
      local a = World:spawnFromSpec("anchor", 6 + dtiles, 10)
      wait(3)
      hold(1, "jump") wait(6) release(1, "jump")
      hold(1, "special")
      local got = false
      for _ = 1, 40 do wait(1) if P1.grappling then got = true break end end
      release(1, "special")
      wait(30)
      a.dead = true
      P1.grappling = nil P1.vx, P1.vy = 0, 0
      wait(5)
      return got
    end
    local near = ropeTest(5)
    local far = ropeTest(8)
    Test.log("rope: 5 tiles=" .. tostring(near) .. " 8 tiles=" .. tostring(far)
      .. " (model: euclidean 110px)")
    if not near then Test.log("FAIL rope shorter than model") fails = fails + 1 end
    if far then Test.log("FAIL rope longer than model") fails = fails + 1 end
    if fails == 0 then Test.log("OK calibrate")
    else Test.log("FAIL calibrate: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- rung prober: every oneway platform the static model claims is
  -- jump-reachable from below must actually be reachable in-engine
  -- ----------------------------------------------------------------
  scenarios.rungprobe = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
      boss_bramblemaw = true, boss_rustwarden = true, boss_tideengine = true,
      boss_slaggolem = true, boss_crucible = true, boss_prismtyrant = true,
      boss_aeriesentinel = true, boss_motherengine = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local fails, probed, skipped = 0, 0, 0
    local only = os.getenv("EMBERDEEP_ROOMS")  -- comma-separated filter
    for _, id in ipairs(WM.ROOMS) do
      if only and not only:find(id, 1, true) then goto nextroom end
      local ok = pcall(function() World:load(id, nil, true) end)
      if ok then
        -- combat-free probing
        for _, e in ipairs(World.entities) do
          if e.kind == "enemy" then e.dead = true end
        end
        G.game.players[2].idle = true
        -- collect jump-target segments: oneway platforms AND solid ledge
        -- tops (the moss_4 vault roof taught us solid 4-tile targets can
        -- sit on the critical path)
        local segs = {}
        for ty = 1, World.h - 2 do
          local x0
          for tx = 1, World.w - 1 do
            if World:isOneway(tx, ty) then
              x0 = x0 or tx
            elseif x0 then
              segs[#segs + 1] = { x0 = x0, x1 = tx - 1, y = ty, kind = "oneway" }
              x0 = nil
            end
          end
          if x0 then
            segs[#segs + 1] = { x0 = x0, x1 = World.w - 2, y = ty, kind = "oneway" }
          end
        end
        local maprows = {}
        for line in World.room.map:gmatch("[^\n]+") do
          maprows[#maprows + 1] = line
        end
        local function mapch(tx, ty)
          local row = maprows[ty + 1]
          return row and row:sub(tx + 1, tx + 1) or "#"
        end
        for ty = 2, World.h - 2 do
          local x0
          for tx = 1, World.w - 1 do
            local ch = mapch(tx, ty)
            local ledge = World:isSolid(tx, ty)
              and ch ~= "c" and ch ~= "%"  -- transient platforms crumble
              and not World:isSolid(tx, ty - 1) and not World:isSolid(tx, ty - 2)
              and not World:isLava(tx, ty - 1) and not World:spikeAt(tx, ty - 1)
            if ledge then
              x0 = x0 or tx
            elseif x0 then
              segs[#segs + 1] = { x0 = x0, x1 = tx - 1, y = ty, kind = "solid" }
              x0 = nil
            end
          end
          if x0 then
            segs[#segs + 1] = { x0 = x0, x1 = World.w - 2, y = ty, kind = "solid" }
          end
        end
        for _, s in ipairs(segs) do
          local sy = s.y - 1  -- stand row on top of the segment
          -- candidate launches the model would accept:
          -- dy 1..3 = plain jump (Vess pilots), dy 4 = spark jump (Lu)
          local cands = {}
          local maxdy = 0
          for tx = s.x0, s.x1 do
            for dy = 1, 4 do
              for dx = -3, 3 do
                local lx, ly = tx + dx, sy + dy
                if lx >= 1 and lx < World.w - 1 and ly < World.h - 1
                    and not World:isSolid(lx, ly)
                    and (World:isSolid(lx, ly + 1) or World:isOneway(lx, ly + 1))
                    and not World:isLava(lx, ly) and not World:spikeAt(lx, ly)
                    and not World:isWater(lx, ly) then
                  -- two arc shapes: rise in the target column (through a
                  -- oneway), or rise BESIDE a solid ledge and drift over
                  -- its lip at the top
                  local clearT = true
                  for k = sy, ly - 1 do
                    if World:isSolid(tx, k) then clearT = false break end
                  end
                  local clearL = dx ~= 0
                  if clearL then
                    for k = sy, ly - 1 do
                      if World:isSolid(lx, k) then clearL = false break end
                    end
                  end
                  if clearL then
                    local sdir = (tx > lx) and 1 or -1
                    for xx = lx + sdir, tx, sdir do
                      if World:isSolid(xx, sy) then clearL = false break end
                    end
                  end
                  if clearT or clearL then
                    cands[#cands + 1] = { lx = lx, ly = ly, tx = tx, dy = dy,
                      score = dy * 10 + math.abs(dx) }
                    if dy > maxdy then maxdy = dy end
                  end
                end
              end
            end
          end
          table.sort(cands, function(a, b) return a.score < b.score end)
          -- solid ledges only matter when a jump is genuinely needed
          -- (skip dy-1 stair steps to keep the run fast)
          local trivialSolid = s.kind == "solid"
            and (#cands == 0 or cands[1].dy <= 1)
          if #cands == 0 or trivialSolid then
            skipped = skipped + 1
          else
            probed = probed + 1
            local okJump = false
            for ci = 1, math.min(3, #cands) do
              local c = cands[ci]
              -- spark-tier jumps are Lu's; everything else probes as Vess
              local slot = (c.dy >= 4) and 2 or 1
              local PL = G.game.players[slot]
              G.game.players[1].idle = (slot == 2)
              G.game.players[2].idle = (slot == 1)
              local jumpHold = (c.dy >= 4) and 30 or 24
              -- a previous probe may have died, or clipped an edge door
              -- and transitioned out (rungs under top doors!): recover
              PL.dead = false PL.downed = false PL.hp = 9999
              if G.run.room ~= id then
                World.pendingTransition = nil
                pcall(function() World:load(id, nil, true) end)
                for _, e in ipairs(World.entities) do
                  if e.kind == "enemy" then e.dead = true end
                end
                G.game.players[1].idle = (slot == 2)
                G.game.players[2].idle = (slot == 1)
              end
              -- run-up: start up to 2 tiles behind the launch cell --
              -- but NOT for near-vertical jumps beside a solid lip, where
              -- the human technique is a stand-jump at the wall base
              local dir = (c.tx >= c.lx) and 1 or -1
              local standJump = math.abs(c.tx - c.lx) <= 1
              local startLx = c.lx
              if standJump then goto placed end
              for back = 1, 2 do
                local bx = c.lx - dir * back
                if bx >= 1 and bx < World.w - 1
                    and not World:isSolid(bx, c.ly)
                    and (World:isSolid(bx, c.ly + 1) or World:isOneway(bx, c.ly + 1))
                    and not World:isSolid(bx, c.ly - 1) then
                  startLx = bx
                else
                  break
                end
              end
              ::placed::
              PL.x, PL.y = startLx * 16 + 2, (c.ly + 1) * 16 - PL.h - 0.5
              PL.vx, PL.vy = 0, 0
              wait(3)
              local launchX = c.lx * 16 + 8
              local targetX = c.tx * 16 + 8
              if startLx ~= c.lx then
                hold(slot, dir > 0 and "right" or "left")
                for _ = 1, 40 do
                  wait(1)
                  if (dir > 0 and PL.x + PL.w / 2 >= launchX - 2)
                      or (dir < 0 and PL.x + PL.w / 2 <= launchX + 2) then
                    break
                  end
                end
              end
              hold(slot, "jump")
              for step = 1, 80 do
                local dx = targetX - (PL.x + PL.w / 2)
                release(slot, "left") release(slot, "right")
                if dx > 3 then hold(slot, "right")
                elseif dx < -3 then hold(slot, "left") end
                if step == jumpHold then release(slot, "jump") end
                wait(1)
                if PL.onGround then
                  local footRow = math.floor((PL.y + PL.h + 1) / 16)
                  local ptx = math.floor((PL.x + PL.w / 2) / 16)
                  if footRow == s.y and ptx >= s.x0 - 1 and ptx <= s.x1 + 1 then
                    okJump = true break
                  end
                  if step > jumpHold + 4 then break end
                end
              end
              release(slot, "jump") release(slot, "left") release(slot, "right")
              if os.getenv("EMBERDEEP_PROBE_DEBUG") then
                Test.log("  probe " .. id .. " " .. s.kind .. "(" .. s.x0
                  .. "-" .. s.x1 .. "," .. s.y .. ") launch(" .. c.lx .. ","
                  .. c.ly .. ")dy" .. c.dy .. "->tx" .. c.tx
                  .. " pilot=" .. slot
                  .. " end=" .. math.floor(PL.x / 16) .. ","
                  .. math.floor((PL.y + PL.h) / 16)
                  .. " ok=" .. tostring(okJump)
                  .. " room=" .. tostring(G.run.room))
              end
              if okJump then break end
            end
            if not okJump then
              fails = fails + 1
              Test.log("FAILRUNG " .. id .. " " .. s.kind .. " (" .. s.x0
                .. "-" .. s.x1 .. "," .. s.y
                .. ") static-reachable but engine failed")
            end
          end
        end
        G.game.players[1].idle = false
        G.game.players[2].idle = true
      end
      ::nextroom::
    end
    Test.log("rungs probed=" .. probed .. " skipped=" .. skipped
      .. " failed=" .. fails)
    if fails == 0 then Test.log("OK rungprobe")
    else Test.log("FAIL rungprobe: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- every ceiling door must be enterable: stand beneath it, jump,
  -- prove the transition fires (sky_4's boss door taught us the model
  -- can claim entries the engine's ceiling refuses)
  -- ----------------------------------------------------------------
  scenarios.doorjump = function()
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, telenet = true,
      boss_bramblemaw = true, boss_rustwarden = true, boss_tideengine = true,
      boss_slaggolem = true, boss_crucible = true, boss_prismtyrant = true,
      boss_aeriesentinel = true, boss_motherengine = true,
      coredoor = true, linkcore_c2 = true,
    } }
    wait(12)
    local WM = require "src.data.worldmap"
    local World = require "src.world"
    local fails, probed = 0, 0
    for _, id in ipairs(WM.ROOMS) do
      local ok = pcall(function() World:load(id, nil, true) end)
      if not ok then goto nextroom end
      local tops = {}
      for ch, d in pairs(World.doors) do
        if d.link and d.edge == "top" then
          tops[#tops + 1] = { ch = ch, d = d, link = d.link }
        end
      end
      for _, t in ipairs(tops) do
        pcall(function() World:load(id, nil, true) end)
        for _, e in ipairs(World.entities) do
          if e.kind == "enemy" then e.dead = true end
        end
        local P1 = G.game.players[1]
        G.game.players[2].idle = true
        -- best footing under ANY door column (nearest wins); alcove
        -- doors whose bottom row sits on solid are walk-in instead
        local standRow, standCol
        for cx = t.d.x0, t.d.x1 do
          for ty = t.d.y1 + 1, math.min(World.h - 2, t.d.y1 + 7) do
            if World:isSolid(cx, ty) then break end
            if World:isSolid(cx, ty + 1) or World:isOneway(cx, ty + 1) then
              if not standRow or ty < standRow then
                standRow, standCol = ty, cx
              end
              break
            end
          end
        end
        local walkCol, walkDir
        if not standRow then
          for _, side in ipairs({ { t.d.x0 - 1, 1 }, { t.d.x1 + 1, -1 } }) do
            local sx = side[1]
            if sx >= 1 and sx < World.w - 1
                and not World:isSolid(sx, t.d.y1)
                and (World:isSolid(sx, t.d.y1 + 1)
                     or World:isOneway(sx, t.d.y1 + 1)) then
              walkCol, walkDir = sx, side[2]
              break
            end
          end
        end
        if not standRow and not walkCol then
          Test.log("FAIL NOSTAND " .. id .. ":" .. t.ch
            .. " no footing under or beside the ceiling door") fails = fails + 1
        else
          probed = probed + 1
          local entered = false
          if standRow then
            P1.x = standCol * 16 + 3
            P1.y = (standRow + 1) * 16 - P1.h - 0.5
            P1.vx, P1.vy = 0, 0
            P1.doorGrace = nil
            require("src.camera").jumpTo(P1.x, P1.y)
            wait(5)
            hold(1, "jump")
            for _ = 1, 90 do
              wait(1)
              if G.run.room ~= id then entered = true break end
            end
            release(1, "jump")
          else
            P1.x = walkCol * 16 + 3
            P1.y = (t.d.y1 + 1) * 16 - P1.h - 0.5
            P1.vx, P1.vy = 0, 0
            P1.doorGrace = nil
            require("src.camera").jumpTo(P1.x, P1.y)
            wait(5)
            hold(1, walkDir > 0 and "right" or "left")
            for _ = 1, 90 do
              wait(1)
              if G.run.room ~= id then entered = true break end
            end
            release(1, walkDir > 0 and "right" or "left")
          end
          wait(30)
          if not entered then
            Test.log("FAILDOORJUMP " .. id .. ":" .. t.ch
              .. " cannot enter the ceiling door") fails = fails + 1
          end
        end
      end
      ::nextroom::
    end
    Test.log("ceiling doors probed=" .. probed)
    if fails == 0 then Test.log("OK doorjump")
    else Test.log("FAIL doorjump: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- new co-op mechanics: link-cores (charged blast only) and ember
  -- vents (Lu's dome eats the barrage)
  -- ----------------------------------------------------------------
  scenarios.testchamber = function()
    local World = require "src.world"
    local TC = require "src.states.testchamber"

    -- 1. real UI path: title menu -> TEST CHAMBER opens
    wait(30)
    menuNav("confirm")            -- dismiss PRESS START
    wait(5)
    menuNav("down") menuNav("down")   -- START -> OPTIONS -> TEST CHAMBER
    menuNav("confirm")
    wait(5)
    Test.log("state after menu=" .. G.State.top().name .. " (want testchamber)")
    if G.State.top().name ~= "testchamber" then
      Test.log("FAIL test chamber did not open from title")
    end
    Test.shot("testchamber_menu")

    -- 2. configure: solo, Veteran, Rusted Warden in the Crucible arena,
    -- full kit, and launch
    TC.cfg.coop = false
    TC.cfg.difficulty = 3
    TC.cfg.boss = 2                -- Rusted Warden
    TC.cfg.arena = 6               -- furn_boss (cross-arena fight)
    TC.cfg.scatterhex = true
    TC.cfg.arclance = true
    TC.cfg.pulsebloom = true
    TC.cfg.weaponTier = 3
    TC.cfg.domeTier = 3
    TC.cfg.hpTier = 4
    TC.cfg.energyTier = 2
    TC.cfg.abilities = 3
    TC:launch()
    wait(30)
    Test.log("room=" .. G.run.room .. " (want furn_boss) slot=" .. tostring(G.run.slot)
      .. " (want nil) diff=" .. G.run.difficulty)
    if G.run.room ~= "furn_boss" or G.run.slot ~= nil then
      Test.log("FAIL chamber run setup wrong")
    end
    local v, l = G.game.players[1], G.game.players[2]
    Test.log("vess weapons=" .. #v.weapons .. " (want 3) lu weapons=" .. #l.weapons
      .. " (want 2) maxhp=" .. v.maxhp .. " (want 28) maxen=" .. (l.maxenergy or 0)
      .. " (want 140)")
    if #v.weapons ~= 3 or #l.weapons ~= 2 or v.maxhp ~= 28 then
      Test.log("FAIL loadout not applied")
    end
    local Weapons = require "src.weapons"
    Test.log("forge arclance tier=" .. Weapons.forge().arclance .. " (want 3)"
      .. " sparkjump=" .. tostring(G.run.flags.sparkjump))

    -- 3. the chosen boss spawns in the chosen (non-native) arena
    for _ = 1, 200 do
      wait(1)
      if World.bossActive then break end
    end
    Test.log("summoned=" .. tostring(World.bossActive and World.bossActive.bossName)
      .. " (want RUSTED WARDEN in furn_boss)")
    if not World.bossActive or World.bossActive.bossId ~= "rustwarden" then
      Test.log("FAIL wrong or missing boss")
    end
    Test.shot("testchamber_fight")

    -- 4. wipe: respawn back at the arena door, boss re-summons fresh
    local p1 = G.game.players[1]
    p1.invuln = 0 p1.roomEnterProtect = 0
    p1:takeDamage(999, nil)
    local p2 = G.game.players[2]
    p2.invuln = 0 p2.roomEnterProtect = 0
    p2:takeDamage(999, nil)
    wait(120)
    Test.log("after wipe room=" .. G.run.room .. " bossActive="
      .. tostring(World.bossActive ~= nil))
    local resummoned = false
    for _ = 1, 240 do
      wait(1)
      if World.bossActive then resummoned = true break end
    end
    Test.log("boss re-summoned after wipe=" .. tostring(resummoned) .. " (want true)")
    if not resummoned then Test.log("FAIL no re-summon after wipe") end

    -- 5. kill it: reward flows, run stays slotless (no autosave crash)
    local b = World.bossActive
    while not b.dead do
      b:hurt(50, b.x + b.w + 20, b.y + 10,
        { owner = { x = b.x + b.w + 20, w = 12 } })
      b.state = "stunned"
      wait(1)
    end
    wait(40)
    Test.log("kill flag=" .. tostring(G.run.flags.boss_rustwarden)
      .. " slot still=" .. tostring(G.run.slot) .. " (want true/nil)")

    -- 6. leaving the arena terminates the test -> back to the title screen
    World:requestTransition("A")
    for _ = 1, 180 do
      wait(1)
      if G.State.top().name == "title" then break end
    end
    Test.log("after leaving arena state=" .. G.State.top().name .. " (want title)")
    if G.State.top().name ~= "title" then
      Test.log("FAIL leaving the arena did not end the test")
    end

    -- 7. pause menu offers EXIT TEST (no save+quit crash path in chamber runs)
    TC.cfg.boss = 10               -- NONE (roam): no boss lock on the doors
    TC:launch()
    wait(40)
    press(1, "pause")
    wait(5)
    Test.log("paused state=" .. G.State.top().name)
    for _ = 1, 6 do menuNav("down") end
    menuNav("confirm")
    wait(30)
    Test.log("after EXIT TEST state=" .. G.State.top().name .. " (want title)")
    if G.State.top().name ~= "title" then
      Test.log("FAIL pause EXIT TEST did not return to title")
    end
    Test.log("OK testchamber")
  end

  scenarios.darkroom = function()
    local World = require "src.world"
    -- 1. dark rooms flag + overlay renders without crashing
    startRun { coop = true, room = "ug_2", door = "A" }
    wait(30)
    Test.log("ug_2 dark=" .. tostring(World.room.dark))
    if not World.room.dark then Test.log("FAIL ug_2 not dark") end
    Test.shot("dark_ug2")

    -- 2. sporebulb: a hit lights it up
    local bulb
    for _, e in ipairs(World.entities) do
      if e.litT ~= nil and not e.dead then bulb = e break end
    end
    if bulb then
      bulb:hurt(1, bulb.x - 10, bulb.y)
      wait(2)
      Test.log("bulb lit lightR=" .. tostring(bulb.lightR) .. " (want 52)")
      if (bulb.lightR or 0) < 50 then Test.log("FAIL bulb did not light") end
    else
      Test.log("FAIL no sporebulb found in ug_2")
    end

    -- 3. mitehusk: breaking frees the mite and sets its flag
    local husk
    for _, e in ipairs(World.entities) do
      if e.flag == "glowmite1" and not e.dead then husk = e break end
    end
    if husk then
      while not husk.dead do husk:hurt(3, husk.x - 8, husk.y) wait(1) end
      wait(3)
      Test.log("glowmite1=" .. tostring(G.run.flags.glowmite1) .. " (want true)")
    else
      Test.log("FAIL no mitehusk in ug_2")
    end

    -- 4. lumecore gate: solid without the flag, open with it
    World:load("ug_3", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local gtx, gty = 25, 12
    local solidNo = World:isSolid(gtx, gty, G.game.players[1])
    G.run.flags.lumecore = true
    World:load("ug_3", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local solidYes = World:isSolid(gtx, gty, G.game.players[1])
    Test.log("gate solid without=" .. tostring(solidNo)
      .. " with=" .. tostring(solidYes) .. " (want true/false)")
    if not solidNo or solidYes then Test.log("FAIL lumecore gate broken") end

    -- 5. conditional NPCs: Ferro waits in the rescue pocket, then moves camp
    G.run.flags.ferro_rescued = nil
    World:load("ug_rescue", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local function findNpc(id)
      for _, e in ipairs(World.entities) do
        if e.kind == "npc" and e.id == id and not e.dead then return e end
      end
    end
    local before = findNpc("ferro") ~= nil
    G.run.flags.ferro_rescued = true
    World:load("ug_rescue", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local after = findNpc("ferro") ~= nil
    World:load("camp_main", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local camp = findNpc("ferro") ~= nil
    Test.log("ferro rescue-room before/after=" .. tostring(before) .. "/" .. tostring(after)
      .. " camp=" .. tostring(camp) .. " (want true/false/true)")
    if not before or after or not camp then Test.log("FAIL ferro conditional spawn") end

    -- 6. Pulse Bloom: radial ring fires (works for Lu)
    local Items = require "src.items"
    Items.grant("weapon:pulsebloom")
    local lu = G.game.players[2]
    lu.curWeapon = #lu.weapons
    hold(2, "fire")
    wait(4)
    release(2, "fire")
    local shots = 0
    for _, e in ipairs(World.entities) do
      if e.kind == "proj" and e.side == "player" and not e.dead then shots = shots + 1 end
    end
    Test.log("pulsebloom ring shots=" .. shots .. " (want >=8)")
    if shots < 8 then Test.log("FAIL pulsebloom did not fire a ring") end
    Test.log("OK darkroom")
  end

  -- ----------------------------------------------------------------
  -- COLDSTORE: cold gating, ice friction, thawplate, the Archivist,
  -- Curator Lock's reveal, and the Cradle record.
  -- ----------------------------------------------------------------
  scenarios.coldstore = function()
    local fails = 0
    local function fail(msg) fails = fails + 1 Test.log("FAIL " .. msg) end
    local World = require "src.world"

    -- 1. cold air is lethal without the coils.
    -- NOTE the sense of `chill` inverted with the refit: it used to be a
    -- countdown from 12 seconds of warmth, so `chill = 0.6` here meant
    -- "about to freeze". It is a 0..1 meter that FILLS now, so this sets
    -- it to empty and lets the room do the work.
    startRun { coop = true, room = "cold_2", door = "A" }
    wait(30)
    local Cold = require "src.cold"
    local p1 = G.game.players[1]
    p1.chill = 0
    local hp0 = p1.hp
    wait(60 * 4)
    Test.log(string.format("no coils, 4s: chill %.2f, hp %d -> %d (want lower)",
      p1.chill, hp0, p1.hp))
    if p1.hp >= hp0 then fail("cold air did not bite without cryocoils") end

    -- 2. the coils are NOT immunity. They are a longer breath, and the
    -- distinction matters: the old chill made a coiled bot untouchable in
    -- the Coldstore, which meant the zone's own verb stopped applying to
    -- anyone equipped to be there.
    G.run.flags.cryocoils = true
    p1.hp = p1.maxhp
    p1.chill = 0
    local hp1 = p1.hp
    wait(60 * 4)
    Test.log(string.format("coils, 4s: chill %.2f, hp %d -> %d (want equal, "
      .. "meter still rising)", p1.chill, hp1, p1.hp))
    if p1.hp < hp1 then fail("cryocoils did not buy time") end
    if p1.chill <= 0 then
      fail("cryocoils froze the meter -- that is immunity, not protection")
    end

    -- 2b. THE VERB. Fire is spread by carrying it and by nothing else, so
    -- drive the real prop: walk a spark into cold_2's first brazier and
    -- watch it take, stay lit, and drain the meter.
    local brz
    for _, e in ipairs(World.entities) do
      if e.id == "c2a" then brz = e break end
    end
    if not brz then fail("no brazier c2a in cold_2") else
      if brz:lit() then fail("c2a starts lit -- nothing has carried fire yet") end
      p1.x, p1.y = brz.x - 60, brz.y + 8
      p1.vx, p1.vy = 0, 0
      p1.chill = 0.9
      p1:takeSpark()
      wait(10)
      if not p1:hasSpark() then fail("could not take a spark") end
      -- walk into it
      for _ = 1, 90 do
        p1.x = p1.x + 1
        wait(1)
        if brz:lit() then break end
      end
      Test.log("brazier c2a lit: " .. tostring(brz:lit())
        .. ", flag " .. tostring(G.run.flags[Cold.flagFor("c2a")]))
      if not brz:lit() then fail("carrying a spark into a brazier did not light it") end
      if p1:hasSpark() then fail("lighting it did not consume the spark") end
      local c0 = p1.chill
      wait(45)
      Test.log(string.format("standing in it: chill %.2f -> %.2f", c0, p1.chill))
      if p1.chill >= c0 then fail("a lit brazier did not drain the meter") end
    end

    -- 3. icy floors: momentum survives with no input
    Test.log("room.ice=" .. tostring(World.room.ice))
    if not World.room.ice then fail("cold_2 not icy") end
    p1.x, p1.vx, p1.vy = 8 * 16, 0, 0
    wait(20)
    p1.vx = 150
    wait(18)  -- 0.3s, no input held
    Test.log("ice slide vx=" .. math.floor(p1.vx) .. " (want > 40)")
    if math.abs(p1.vx) <= 40 then fail("ice not slick") end

    -- 4. cryocoils gate in cold_1: solid without, open with
    G.run.flags.cryocoils = nil
    World:load("cold_1", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local solidNo = World:isSolid(30, 11, p1)
    G.run.flags.cryocoils = true
    World:load("cold_1", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local solidYes = World:isSolid(30, 11, p1)
    Test.log("cryo gate solid without/with=" .. tostring(solidNo) .. "/"
      .. tostring(solidYes) .. " (want true/false)")
    if not solidNo or solidYes then fail("cryocoils gate broken") end

    -- 5. thawplate: light fire bounces off, a heavy hit melts, stand latches
    World:load("cold_3", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local plate
    for _, e in ipairs(World.entities) do
      if e.flag == "thaw_cold3" and e.frozen ~= nil then plate = e break end
    end
    if not plate then
      fail("no thawplate in cold_3")
    else
      plate:hurt(3, plate.x - 8, plate.y)
      Test.log("light hit frozen=" .. tostring(plate.frozen) .. " (want true)")
      if not plate.frozen then fail("thawplate melted too easily") end
      plate:hurt(8, plate.x - 8, plate.y)
      Test.log("heavy hit frozen=" .. tostring(plate.frozen) .. " (want false)")
      if plate.frozen then fail("thawplate did not melt") end
      p1.x, p1.y = plate.x, plate.y - 20
      p1.vy = 0
      wait(40)
      Test.log("thaw_cold3=" .. tostring(G.run.flags.thaw_cold3) .. " (want true)")
      if not G.run.flags.thaw_cold3 then fail("thawplate did not latch") end
    end

    -- 6. the Archivist: only the re-shelve window wounds it; kill grants
    World:load("cold_boss", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(20)
    local trig
    for _, e in ipairs(World.entities) do
      if e.bossId == "archivist" and e.kind ~= "enemy" then trig = e break end
    end
    -- walk in to trip the trigger
    for _, p in ipairs(World.players) do p.x = World.w * 16 / 2 p.y = 15 * 16 end
    wait(40)
    local boss = World.bossActive
    Test.log("archivist summoned=" .. tostring(boss and boss.bossId))
    if not boss then
      fail("archivist did not start")
    else
      boss:setState("ride", 2)
      local closedHp = boss.hp
      boss:hurt(10, boss.x - 10, boss.y)
      Test.log("closed-drawer dmg: " .. closedHp .. " -> " .. boss.hp .. " (want equal)")
      if boss.hp < closedHp then fail("archivist hurt outside reshelve") end
      boss:setState("reshelve", 999)
      local guard = 0
      while not boss.dead and guard < 200 do
        boss:hurt(12, boss.x - 10, boss.y)
        wait(2)
        guard = guard + 1
      end
      wait(30)
      -- dying speech
      local dguard = 0
      while G.game.dialogue and dguard < 200 do
        G.game.dialogue:advance() wait(1) dguard = dguard + 1
      end
      wait(15)  -- let the paused world flush the spawn queue
      -- the prize is a physical drop now: walk over and take it
      local drop
      for _, e in ipairs(World.entities) do
        if e.give == "weapon:magnetmortar" and not e.dead then drop = e break end
      end
      if not drop then
        fail("archivist dropped no physical reward")
      else
        p1.x, p1.y = drop.x, drop.baseY - 4
        p1.vx, p1.vy = 0, 0
        wait(20)
      end
      Test.log("boss_archivist=" .. tostring(G.run.flags.boss_archivist)
        .. " weapon_magnetmortar=" .. tostring(G.run.flags.weapon_magnetmortar)
        .. " (want true/true)")
      if not G.run.flags.boss_archivist or not G.run.flags.weapon_magnetmortar then
        fail("archivist kill rewards missing")
      end
    end

    -- 7. Curator Lock hands over the Cradle location once the plates are home
    G.run.flags.arcplate1 = true G.run.flags.arcplate2 = true
    G.run.flags.arcplate3 = true G.run.flags.arcplate4 = true
    World:load("cold_4", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    local lock
    for _, e in ipairs(World.entities) do
      if e.kind == "npc" and e.id == "lock" then lock = e break end
    end
    if not lock then
      fail("no Curator Lock in cold_4")
    else
      lock:interact(p1)
      local g2 = 0
      while G.game.dialogue and g2 < 200 do
        G.game.dialogue:advance() wait(1) g2 = g2 + 1
      end
      Test.log("cradle_found=" .. tostring(G.run.flags.cradle_found) .. " (want true)")
      if not G.run.flags.cradle_found then fail("lock did not reveal the Cradle") end
    end

    -- 8. the Cradle: dark, pods lit, and the record sets the truth
    World:load("cradle_1", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    Test.log("cradle dark=" .. tostring(World.room.dark))
    if not World.room.dark then fail("cradle_1 not dark") end
    local pods, record = 0, nil
    for _, e in ipairs(World.entities) do
      if e.kind == "prop" and e.lightR == 20 then pods = pods + 1 end
      if e.kind == "sign" and e.dlgId == "cradle_record" then record = e end
    end
    Test.log("pods=" .. pods .. " (want >= 12)")
    if pods < 12 then fail("cradle pods missing") end
    if record then
      record:interact(p1)
    else
      -- fall back: trigger the record dialogue directly
      local Dialogue = require "src.data.dialogue"
      G.game:startDialogue(Dialogue.get("cradle_record", p1))
    end
    local g3 = 0
    while G.game.dialogue and g3 < 300 do
      G.game.dialogue:advance() wait(1) g3 = g3 + 1
    end
    Test.log("cradle_truth=" .. tostring(G.run.flags.cradle_truth) .. " (want true)")
    if not G.run.flags.cradle_truth then fail("the record did not land") end
    Test.shot("cradle")
    if fails > 0 then error(fails .. " coldstore failure(s)") end
    Test.log("OK coldstore")
  end

  -- ----------------------------------------------------------------
  -- BOSSSPAWN: every boss spawns free of terrain and its trigger fires
  -- from ANY height (the Bramble Maw used to be jumpable-over, and more
  -- than one boss has spawned inside the floor).
  -- ----------------------------------------------------------------
  scenarios.bossspawn = function()
    local World = require "src.world"
    local PH = require "src.physics"
    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, cryocoils = true, lumecore = true,
    } }
    wait(12)
    local LIST = {
      { "bramblemaw", "moss_boss" }, { "rustwarden", "flood_warden" },
      { "tideengine", "flood_boss" }, { "slaggolem", "furn_golem" },
      { "crucible", "furn_boss" }, { "prismtyrant", "crys_boss" },
      { "aeriesentinel", "sky_boss" }, { "mycelchoir", "ug_boss" },
      { "archivist", "cold_boss" }, { "motherengine", "core_boss" },
      { "vessel8", "scrap_boss" },
    }
    local fails = 0
    for _, e in ipairs(LIST) do
      local id, room = e[1], e[2]
      World:load(room, "A", true)
      G.game.fade = 0 G.game.fadeDir = 0
      wait(10)
      -- find the tripwire and cross it HIGH (the jump-over route)
      -- Not every boss is armed by a tripwire, and the exception is a
      -- design decision rather than an oversight: the Archivist is woken
      -- from the kept brazier's dialogue ("Wake it" / "Take a spark"),
      -- on a thing you can see and choose. So look for BOTH mechanisms
      -- and read which one this arena uses off the room, instead of
      -- keeping a list here that goes stale the next time one changes.
      local trig, armer
      for _, t in ipairs(World.entities) do
        if t.bossId == id and t.kind == "bosstrigger" then trig = t end
        if t.armBoss == id then armer = t end
      end
      if not trig and armer then
        -- exactly what the dialogue's "Wake it" branch does
        require("src.entities.bosses").start(id, World)
        wait(10)
      end
      if not trig and not armer then
        Test.log("FAIL NOARM " .. id
          .. " -- no bosstrigger and nothing with armBoss in " .. room)
        fails = fails + 1
      else
        -- Only the tripwire route needs the players moved. Guarding this
        -- on `trig` rather than on the branch: the armed-by-choice bosses
        -- reach the else with trig still nil, and the previous version
        -- indexed it anyway.
        for _, p in ipairs(World.players) do
          if trig then
            p.x = trig.x
            p.y = 40
            p.vx, p.vy = 0, 0
          end
          p.invuln = 99
        end
        wait(10)
        local b = World.bossActive
        if not b then
          Test.log("FAIL NOSPAWN " .. id .. " (high crossing missed)")
          fails = fails + 1
        else
          if PH.boxBlocked(b.x, b.y, b.w, b.h) then
            Test.log("FAIL EMBEDDED-AT-SPAWN " .. id) fails = fails + 1
          end
          -- liveness: within six seconds it must MOVE or ATTACK
          local bx0, by0 = b.x, b.y
          local maxDisp, acted = 0, false
          for _ = 1, 360 do
            wait(1)
            if b.dead then break end
            local d = math.abs(b.x - bx0) + math.abs(b.y - by0)
            if d > maxDisp then maxDisp = d end
            if not acted then
              for _, pe in ipairs(World.entities) do
                if (pe.kind == "proj" and pe.side == "enemy")
                  or (pe.kind == "enemy" and pe ~= b and not pe.dead
                      and not pe.boss and pe.maxhp and pe.maxhp < 900) then
                  acted = true break
                end
              end
            end
            if maxDisp > 6 and acted then break end
          end
          if not b.dead and PH.boxBlocked(b.x, b.y, b.w, b.h) then
            Test.log("FAIL EMBEDDED-LATER " .. id .. " at "
              .. math.floor(b.x) .. "," .. math.floor(b.y))
            fails = fails + 1
          end
          Test.log(string.format("%s disp=%.1f acted=%s", id, maxDisp,
            tostring(acted)))
          if maxDisp <= 6 and not acted then
            Test.log("FAIL LIFELESS " .. id .. " (no movement, no attacks)")
            fails = fails + 1
          end
          Test.log("OK spawn " .. id)
        end
      end
      -- mark killed so the next load is quiet
      G.run.flags["boss_" .. id] = true
      World.bossActive = nil
    end
    if fails > 0 then error(fails .. " boss spawn failure(s)") end
    Test.log("OK bossspawn")
  end

  -- ----------------------------------------------------------------
  -- BOSSADDS: nothing a boss summons outlives it.
  --
  -- Static analysis can prove every spawn site is tagged. It cannot
  -- prove the sweep actually reaches them at runtime -- through the add
  -- queue, through bosses that summon on a timer, through the one that
  -- summons an ALLY. So this fights every boss in the game to death and
  -- counts what is left standing.
  -- ----------------------------------------------------------------
  scenarios.bossadds = function()
    local World = require "src.world"
    local Bosses = require "src.entities.bosses"
    local TC = require "src.states.testchamber"

    -- ----------------------------------------------------------------
    -- WHAT EVERY BOSS ACTUALLY DOES.
    --
    -- Read out of bosses.lua, not guessed. Line numbers are where to go
    -- and re-check a claim when one of these stops being true.
    --
    --   arm     -- "trip" a bosstrigger column, "choice" a brazier
    --              dialogue (the Archivist is woken deliberately)
    --   gate    -- what hurt() demands before damage lands at all
    --   summons -- "always" it tags adds the moment it wakes
    --              "hurt"   only below a health threshold
    --              "random" on a dice roll during some state
    --              false    it never calls addSpawn, anywhere
    --
    -- This table exists because the old loop said it would kill each
    -- boss "however this particular boss insists on being killed" and
    -- then knew about exactly one of the gates. THREE bosses were
    -- unkillable by it -- the Tide Engine (hurt() returns false until
    -- both valves are blown), the Mycel Choir (needs opts.fromNode) and
    -- the Crucible (needs link AND open vents) -- so each burned its
    -- 4000-frame guard and logged SKIP, and the add-sweep this scenario
    -- exists to prove was never tested on any of them.
    -- ----------------------------------------------------------------
    local FACTS = {
      bramblemaw    = { gate = "none",   summons = "random",
                        note = "gnat on chance(0.5) per volley (285)" },
      rustwarden    = { gate = "link",   summons = false,
                        note = "deflects() yields to opts.link (656); no addSpawn" },
      tideengine    = { gate = "valves", summons = "always",
                        note = "hurt() false until both valves blown (1023); valves spawned on the first update (913)" },
      slaggolem     = { gate = "none",   summons = "hurt",
                        note = "slagblobs only below 70% hp (1156)" },
      crucible      = { gate = "vents",  summons = "random",
                        note = "shield needs link AND ventsOpen (1546); slaglings via spewSlag (1538)" },
      prismtyrant   = { gate = "beam",   summons = "random",
                        note = "shield needs opts.beam (2029); wisps on every recharge (1894)" },
      aeriesentinel = { gate = "none",   summons = false,
                        note = "no addSpawn anywhere in its class" },
      mycelchoir    = { gate = "node",   summons = "always",
                        note = "hurt() needs opts.fromNode (3153); three nodes at start (3074)" },
      archivist     = { gate = "none",   summons = false,
                        note = "a closed shield only multiplies damage, never blocks (3356)" },
      motherengine  = { gate = "none",   summons = "random",
                        note = "sentinel + screamer in state 'adds' (2824)" },
      vessel8       = { gate = "link",   summons = false,
                        note = "deflects() yields to opts.link (4214); no addSpawn" },
    }

    -- Every key any boss's hurt() looks for. The ones that do not care
    -- about a given key ignore it, so a single table serves all eleven.
    local HURT = { link = true, beam = true, refracted = true, fromNode = true }

    -- Fifteen seconds of open fight. The Bramble Maw rolls its gnat at
    -- chance(0.5) once per volley and a volley cycle is about five
    -- seconds (244, 290), so a five-second window saw one roll and
    -- reported VACUOUS half the time it ran.
    local SUMMON_FRAMES = 900

    -- Open whatever this boss is holding shut. Reaching into valves and
    -- vents is DRIVING, not asserting: the subject here is the sweep in
    -- Boss:onDeath, and a fair fight is not required to reach it.
    local function openGate(b)
      for _, v in ipairs(b.valves or {}) do          -- Tide Engine
        if not v.regenT then v.regenT, v.regenMax = 15, 15 end
      end
      if b.shielded then
        b.ventsOpen = true                            -- Crucible
        if b.beamStrike then                          -- Conductor
          b:beamStrike({ b.x, b.y, b.x, b.y + 40 }, 1 / 60)
        end
      end
      b.invuln = 0    -- 1.2s per landed hit would swallow two in three
    end

    local bad, vacuous, checked = 0, 0, 0
    for _, bd in ipairs(TC.BOSSES) do
      if bd.id then
        local fact = FACTS[bd.id] or { gate = "?", summons = "random" }
        startRun { coop = true, room = bd.arena, door = "A" }
        G.run.flags.bulwark = true
        G.run.flags.driftvanes = true
        G.run.flags.linkblast = true
        wait(20)

        -- Arm it the way this arena arms it: a tripwire column, or the
        -- brazier dialogue that wakes the Archivist.
        local trig, armer
        for _, e in ipairs(World.entities) do
          if e.kind == "bosstrigger" and e.bossId == bd.id then trig = e end
          if e.armBoss == bd.id then armer = e end
        end
        if trig then
          for _, p in ipairs(World.players) do
            p.x, p.y = trig.x, 40
            p.vx, p.vy = 0, 0
          end
        elseif armer then
          Bosses.start(bd.id, World)
        else
          error(bd.id .. ": nothing arms it in " .. bd.arena)
        end
        wait(10)

        local b = World.bossActive
        if not b then error(bd.id .. " did not spawn") end
        for _, p in ipairs(World.players) do p.invuln = 999 end
        local guard = 0
        while b.state == "intro" and guard < 300 do wait(1) guard = guard + 1 end

        -- SOFTEN IT FIRST. The old version waited four seconds at FULL
        -- health, which is a window in which two of these bosses cannot
        -- summon by definition: the Slag Golem calls blobs only below
        -- 70% and Maro calls Brassa only below 60%.
        local floorHp = math.max(1, math.floor((b.maxhp or 100) * 0.5))
        guard = 0
        while not b.dead and b.hp > floorHp and guard < 900 do
          openGate(b)
          b:hurt(8, b.x - 10, b.y, HURT)
          wait(1)
          guard = guard + 1
        end
        if b.hp > floorHp and not b.dead then
          Test.log(("WARN %-14s could not be softened (hp %d/%d) -- %s")
            :format(bd.id, b.hp, b.maxhp, fact.note or ""))
        end

        -- WATCH IT FIGHT -- and do not touch it while watching.
        --
        -- openGate() forces ventsOpen every frame, and for the Crucible
        -- that is not neutral: a link hit through open vents SHATTERS the
        -- shield and stuns it for five seconds (1546), so holding the
        -- vents open kept stunning it before it could reach the slam that
        -- spews the slaglings (1488). The gate-forcing was suppressing
        -- the very summons being counted.
        --
        -- And sample every frame, keeping the PEAK. A single reading at
        -- the end cannot see an add that spawned and died inside the
        -- window, which is precisely the case this scenario cares about.
        local spawned = 0
        for _ = 1, SUMMON_FRAMES do
          local n = 0
          for _, e in ipairs(World.entities) do
            if e.bossAdd and not e.dead then n = n + 1 end
          end
          if n > spawned then spawned = n end
          wait(1)
        end

        guard = 0
        while not b.dead and guard < 1200 do
          openGate(b)
          b:hurt(20, b.x - 10, b.y, HURT)
          wait(1)
          guard = guard + 1
        end
        if not b.dead then
          Test.log(("SKIP %-14s could not be killed -- gate=%s %s")
            :format(bd.id, fact.gate, fact.note or ""))
        else
          wait(10)
          local left = 0
          for _, e in ipairs(World.entities) do
            if e.bossAdd and not e.dead then left = left + 1 end
          end
          checked = checked + 1
          Test.log(string.format("%-14s summoned %d, %d left after death",
            bd.id, spawned, left))
          if left > 0 then bad = bad + 1 end

          -- A boss that summoned nothing proves nothing about a sweep.
          -- Which of them SHOULD have is a per-boss fact, not a global
          -- one: five of the eleven never call addSpawn at all, and
          -- failing them for it would be failing them for their design.
          if fact.summons == "always" and spawned == 0 then
            error(bd.id .. " summoned nothing but always should -- " .. fact.note)
          elseif fact.summons and spawned == 0 then
            Test.log(("VACUOUS %-14s -- expected %s summons, saw none (%s)")
              :format(bd.id, tostring(fact.summons), fact.note or ""))
            vacuous = vacuous + 1
          end

          local prize, corpse = false, false
          for _, e in ipairs(World.entities) do
            if e.give and not e.dead then prize = true end
            if e.bossId and e.hint == "inspect" then corpse = true end
          end
          -- GONE and COLLECTED are different facts and only the first
          -- implicates the sweep: Reward:update auto-grants on TOUCH and
          -- both bots are parked where the prize lands.
          if b.reward then
            local mod = b.reward:match("^module:(.+)$")
            local wpn = b.reward:match("^weapon:(.+)$")
            local held = (mod and G.run.flags[mod])
              or (wpn and G.run.flags["weapon_" .. wpn])
            if not prize and not held then
              error(bd.id .. ": the reward is gone and nobody has it ("
                .. b.reward .. ")")
            end
          end
          if not corpse and bd.id ~= "motherengine" then
            error(bd.id .. ": the sweep ate the corpse")
          end
        end
        G.run.flags["boss_" .. bd.id] = true
        World.bossActive = nil
      end
    end
    if bad > 0 then error(bad .. " boss(es) left adds alive after dying") end
    Test.log(string.format("%d bosses killed and swept, %d vacuous", checked, vacuous))
    Test.log("OK bossadds")
  end

  -- ----------------------------------------------------------------
  -- CONDUCTOR: the shield is the default and only a beam opens it.
  --
  -- The whole point of the refit is that the fight cannot be won by
  -- ignoring it, so the first thing this does is TRY to win by ignoring
  -- it: five hundred points of gunfire into a shielded Conductor, and
  -- its HP must not move. Then it drives a real solve and checks the
  -- window opens, the chip lands, and the shield comes back.
  -- ----------------------------------------------------------------
  scenarios.conductor = function()
    local World = require "src.world"
    startRun { coop = true, room = "crys_boss", door = "A" }
    G.run.flags.bulwark = true
    G.run.flags.driftvanes = true
    wait(20)
    local b = World.bossActive
    if not b then error("the Conductor did not spawn") end
    for _, p in ipairs(World.players) do p.invuln = 999 end
    -- let it leave the intro and take a station
    while b.state == "intro" do wait(1) end
    wait(10)
    if not b.shielded then error("it did not start shielded") end
    if not b.images then error("it never took a station") end

    -- 1. GUNFIRE ALONE MUST DO NOTHING
    local before = b.hp
    for _ = 1, 100 do
      b:hurt(5, b.x - 20, b.y)
      wait(1)
    end
    Test.log("hp after 500 damage of gunfire = " .. b.hp .. " (want " .. before .. ")")
    if b.hp ~= before then
      error("a shielded Conductor took " .. (before - b.hp) .. " from plain shots")
    end

    -- 2. THE STATIONS ARE SPREAD AND JITTERED
    local xs = {}
    for _, im in ipairs(b.images) do xs[#xs + 1] = im.x end
    table.sort(xs)
    local minGap = 1e9
    for i = 2, #xs do minGap = math.min(minGap, xs[i] - xs[i - 1]) end
    Test.log(string.format("station spread: min gap %.0fpx", minGap))
    if minGap < 8 * 16 then
      error("stations are bunched: min gap " .. minGap .. "px")
    end
    -- re-roll a few times; the columns must actually move. A swap is a
    -- WARP now, so it has to be driven to completion rather than treated
    -- as instant -- and the boss must come back, not get stuck scattered.
    local seen = {}
    for r = 1, 12 do
      b:swapStations()
      if not b.warpPhase then error("swapStations did not start a warp") end
      local guard = 0
      while b.warpPhase and guard < 200 do wait(1) guard = guard + 1 end
      if b.warpPhase then error("the warp never finished (round " .. r .. ")") end
      seen[math.floor(b.images[1].x)] = true
    end
    local distinct = 0
    for _ in pairs(seen) do distinct = distinct + 1 end
    Test.log("station 1 took " .. distinct .. " distinct columns over 12 rolls")
    if distinct < 3 then error("stations are not jittering") end

    -- 3. A BEAM STRIKE OPENS IT, AND THE CHIP LANDS -- AND THE BEAM DIES
    -- The beam runs floor-to-station, so if it survives its own strike
    -- the players cannot stand under the boss to use the window. Drive a
    -- REAL emitter here rather than a synthetic segment, so the whole
    -- chain is exercised: trace -> overlap -> strike -> expend -> retrace.
    local em
    for _, e in ipairs(World.entities) do
      if e.beamEmit and e.dormant then em = e break end
    end
    if not em then error("the arena has no dormant emitter") end
    em.on = true
    em.wakeT = em.wakeFor
    World.beamDirty = true
    wait(1)
    local segsLit = #World.beamSegs
    Test.log("beam segments while lit = " .. segsLit)
    if segsLit == 0 then error("waking an arena emitter produced no beam") end

    local hp0 = b.hp
    b:beamStrike({ b.x, b.y, b.x, b.y + 40, src = em }, 1 / 60)
    wait(2)
    Test.log("emitter on after strike = " .. tostring(em.on) .. " (want false)")
    if em.on then error("the beam stayed lit after breaking the shield") end
    if #World.beamSegs ~= 0 then
      error("the beam column did not clear: " .. #World.beamSegs .. " segments left")
    end
    Test.log("beam column cleared -- the window is usable")
    Test.log("after beam: shielded=" .. tostring(b.shielded)
      .. " hp " .. hp0 .. " -> " .. b.hp)
    if b.shielded then error("a beam strike did not open the shield") end
    local chip = hp0 - b.hp
    local want = math.floor(b.maxhp * 0.10)
    if chip < want then
      error("beam chip was " .. chip .. ", wanted at least " .. want)
    end

    -- 4. GUNFIRE WORKS IN THE WINDOW
    local hp1 = b.hp
    b:hurt(6, b.x - 20, b.y)
    wait(1)
    if b.hp >= hp1 then error("guns did nothing during the open window") end

    -- 5. THE WINDOW CLOSES AND THE SHIELD COMES BACK
    local guard = 0
    while not b.shielded and guard < 600 do wait(1) guard = guard + 1 end
    if not b.shielded then error("the shield never came back") end
    Test.log("shield restored after the window")
    -- a recharge brings a swarm
    local wisps = 0
    for _, e in ipairs(World.entities) do
      if e.kind == "enemy" and not e.isBoss and not e.dead then wisps = wisps + 1 end
    end
    Test.log("wisps after recharge = " .. wisps)
    if wisps < 1 then error("no swarm spawned on recharge") end

    -- 6. AND IT IS STILL KILLABLE, THE INTENDED WAY
    guard = 0
    while not b.dead and guard < 3000 do
      if b.shielded then
        b:beamStrike({ b.x, b.y, b.x, b.y + 40 }, 1 / 60)
      else
        b:hurt(8, b.x - 20, b.y)
      end
      wait(1)
      guard = guard + 1
    end
    if not b.dead then error("could not kill it even playing correctly") end
    Test.log("OK conductor")
  end

  -- ----------------------------------------------------------------
  -- BEAMPERSIST: a solved circuit stays solved, and waking an emitter
  -- is a two-second channel that costs half of Lu's bar.
  --
  -- Everything here is measured on the live world rather than asserted
  -- from the room file: the panel is shoved through the real
  -- Panel:shove, the room is genuinely left and re-entered, and the
  -- energy is read off the player before and after.
  -- ----------------------------------------------------------------
  scenarios.beampersist = function()
    local World = require "src.world"
    startRun { coop = true, room = "crys_3", door = "A" }
    G.run.flags.bulwark = true
    wait(20)
    local function findPanel()
      for _, e in ipairs(World.entities) do
        if e.kind == "panel" then return e end
      end
    end
    local pan = findPanel()
    if not pan then error("crys_3 has no reflector panel") end
    if pan.slot ~= 0 then error("panel did not start at slot 0") end
    for _ = 1, 3 do pan:shove(1) wait(2) end
    if pan.slot ~= 3 then
      error("shoved 3 times, panel is at slot " .. pan.slot)
    end
    local wantX = pan.x
    -- leave and come back: the panel must be exactly where we left it
    World:load("crys_2", "B", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    World:load("crys_3", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    local pan2 = findPanel()
    if not pan2 then error("panel gone after re-entry") end
    Test.log("panel slot after re-entry = " .. pan2.slot .. " (want 3)")
    if pan2.slot ~= 3 or pan2.x ~= wantX then
      error("panel reset on re-entry: slot " .. pan2.slot .. " x " .. pan2.x)
    end

    -- now the channel, in crys_2 where the emitter is dormant
    World:load("crys_2", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    local em
    for _, e in ipairs(World.entities) do
      if e.beamEmit and e.dormant then em = e end
    end
    if not em then error("crys_2 has no dormant emitter") end
    local lu
    for _, p in ipairs(World.players) do if not p.isVess then lu = p end end
    if not lu then error("no Lu in the run") end
    lu.x, lu.y = em.x + 14, em.y - 4
    lu.vx, lu.vy = 0, 0
    lu.energy = lu.maxenergy
    lu.invuln = 999
    local before = lu.energy
    local Props = require "src.entities.props"
    local Emitter_CHANNEL = 2.0
    -- drive the channel by hand for the full window
    local frames = math.ceil(Emitter_CHANNEL * 60) + 8
    for _ = 1, frames do
      lu.domeActive = true
      lu.vx, lu.vy = 0, 0
      lu.x, lu.y = em.x + 14, em.y - 4
      if not em.on then em:energize(lu, 1 / 60) end
      wait(1)
    end
    Test.log("emitter on = " .. tostring(em.on))
    if not em.on then error("a held dome never woke the emitter") end
    local spent = before - lu.energy
    Test.log(string.format("channel spent %.1f of %d energy (want >= 50)",
      spent, lu.maxenergy))
    if spent < lu.maxenergy / 2 - 2 then
      error(string.format("channel cost only %.1f -- less than half a bar", spent))
    end
    Test.log("OK beampersist")
  end

  -- ----------------------------------------------------------------
  -- BOSSDROPS: rewards are physical drops that persist until picked
  -- up, and corpses stay where the machine fell.
  -- ----------------------------------------------------------------
  scenarios.bossdrops = function()
    local World = require "src.world"
    startRun { coop = true, room = "crys_boss", door = "A" }
    wait(20)
    for _, p in ipairs(World.players) do p.x = World.w * 8 p.invuln = 999 end
    wait(30)
    local b = World.bossActive
    if not b then error("conductor did not start") end
    -- The Conductor is shielded by default now, so plain damage in a
    -- loop would spin here forever. Kill it the way the fight intends:
    -- open it with a beam strike, then shoot the window.
    local guard = 0
    while not b.dead and guard < 4000 do
      if b.shielded then
        b:beamStrike({ b.x, b.y, b.x, b.y + 40 }, 1 / 60)
      else
        b:hurt(14, b.x - 10, b.y)
      end
      wait(1)
      guard = guard + 1
    end
    if not b.dead then error("conductor would not die") end
    wait(30)
    local function findDrop()
      for _, e in ipairs(World.entities) do
        if e.give == "module:corekey2" and not e.dead then return e end
      end
    end
    local function findCorpse()
      for _, e in ipairs(World.entities) do
        if e.bossId == "prismtyrant" and e.hint == "inspect" then return e end
      end
    end
    if not findDrop() then error("no physical reward drop") end
    if not findCorpse() then error("no corpse where it fell") end
    if G.run.flags.corekey2 then error("reward granted without pickup") end
    -- leave, come back: both persist
    World:load("crys_5", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(5)
    World:load("crys_boss", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    local drop = findDrop()
    if not drop then error("drop vanished after leaving the room") end
    if not findCorpse() then error("corpse vanished after leaving the room") end
    -- collect it
    local p1 = G.game.players[1]
    p1.x, p1.y = drop.x, drop.baseY - 4
    p1.vx, p1.vy = 0, 0
    wait(20)
    Test.log("corekey2=" .. tostring(G.run.flags.corekey2) .. " (want true)")
    if not G.run.flags.corekey2 then error("pickup did not grant") end
    local left = (G.run.pendingDrops or {})["crys_boss"]
    if left and #left > 0 then error("pendingDrops not consumed") end
    Test.log("OK bossdrops")
  end

  -- ----------------------------------------------------------------
  -- V41MISC: lava law + the pause LOG.
  -- ----------------------------------------------------------------
  scenarios.v41misc = function()
    local World = require "src.world"
    -- 1. lava: instant down, wreck thrown back to the last safe ground
    startRun { coop = true, room = "furn_5", door = "A",
      flags = { heatplating = true } }
    wait(30)
    local p1 = G.game.players[1]
    local safeX = p1.x
    wait(10)
    p1.x = 20 * 16   -- over the lava channel
    p1.y = 12 * 16 + 4
    p1.invuln = 0
    wait(12)
    local tx = math.floor((p1.x + p1.w / 2) / 16)
    local ty = math.floor((p1.y + p1.h + 2) / 16)
    Test.log("lava: downed=" .. tostring(p1.downed)
      .. " inLava=" .. tostring(World:isLava(tx, ty)))
    if not p1.downed then error("lava did not put the bot down") end
    if World:isLava(tx, ty) then error("wreck rests in lava, not on land") end
    -- 2. the LOG: dialogue + announces are recorded and the panel opens
    G.game:announce("The deep takes note of this test.", 1)
    G.game:startDialogue({ { who = "elder", text = "Testing, little sparks." } })
    wait(2)
    while G.game.dialogue do G.game.dialogue:advance() wait(2) end
    local n = #(G.run.log or {})
    Test.log("log entries=" .. n .. " (want >= 2)")
    if n < 2 then error("log did not record") end
    G.State.push(require "src.states.log")
    wait(5)
    if G.State.top().name ~= "log" then error("log panel did not open") end
    Test.shot("log_panel")
    G.State.top():menu("cancel")
    wait(5)
    if G.State.top().name == "log" then error("log panel did not close") end
    Test.log("OK v41misc")
  end

  -- ----------------------------------------------------------------
  -- EMBERTHEFT: the Cold Accounting easter egg. Take the Ember early,
  -- everyone freezes, the bad ending runs, the game reloads the last
  -- save -- and NOTHING was ever written to disk.
  
  -- ----------------------------------------------------------------
  scenarios.embertheft = function()
    local World = require "src.world"
    startRun { coop = true, room = "camp_main", door = "A" }
    wait(30)
    local p1 = G.game.players[1]
    G.game:autosave()          -- baseline save: scrap 0
    wait(5)
    G.run.scrap = 77           -- in-memory progress that must NOT survive
    local lantern
    for _, e in ipairs(World.entities) do
      if e.hint == "lantern" then lantern = e break end
    end
    if not lantern then error("no ember lantern in camp_main") end
    lantern:interact(p1)
    -- advance through both confirmations (Yes is preselected) and the
    -- freeze text until the Cold Accounting takes the screen
    local guard = 0
    while G.State.top().name ~= "coldending" and guard < 300 do
      if G.game and G.game.dialogue then G.game.dialogue:advance() end
      wait(3)
      guard = guard + 1
    end
    Test.log("state=" .. G.State.top().name .. " (want coldending)")
    if G.State.top().name ~= "coldending" then error("Cold Accounting did not trigger") end
    Test.shot("cold_accounting")
    -- run the cards; the state reloads the last save at the end
    local guard2 = 0
    while G.State.top().name == "coldending" and guard2 < 40 do
      wait(60)
      G.State.top():menu("confirm")
      guard2 = guard2 + 1
    end
    wait(30)
    Test.log("state=" .. G.State.top().name .. " scrap=" .. tostring(G.run.scrap)
      .. " ember_taken=" .. tostring(G.run.flags.ember_taken))
    if G.State.top().name ~= "game" then error("did not reload into the game") end
    if G.run.scrap == 77 then error("theft timeline survived the reload") end
    if G.run.flags.ember_taken or G.run.flags.camp_frozen then
      error("ember flags leaked into the reloaded run")
    end
    local disk = G.Save.readSlot(1)
    if disk and (disk.flags.ember_taken or disk.flags.camp_frozen) then
      error("ember flags were written to disk")
    end
    Test.log("OK embertheft")
  end

  -- ----------------------------------------------------------------
  -- RECKONING: the full RECLAIM route. Maro fights, the camp freezes,
  -- Tikka hands over the music box, the Seat takes the Ember back.
  -- ----------------------------------------------------------------
  scenarios.reckoning = function()
    local World = require "src.world"
    startRun { coop = true, room = "camp_main", door = "A", flags = {
      mender_yield = true, cradle_truth = true, quest_tikka_done = true,
      met_elder = true,
    } }
    wait(30)
    local p1 = G.game.players[1]
    G.game:autosave()
    wait(5)
    local function findLantern()
      for _, e in ipairs(World.entities) do
        if e.hint == "lantern" then return e end
      end
    end
    local lantern = findLantern()
    if not lantern then error("no ember lantern") end
    lantern:interact(p1)
    -- through both confirmations and Maro's speech, into the fight
    local guard = 0
    while not World.bossActive and guard < 300 do
      if G.game.dialogue then G.game.dialogue:advance() end
      wait(3)
      guard = guard + 1
    end
    local maro = World.bossActive
    Test.log("boss=" .. tostring(maro and maro.bossName) .. " (want EMBERKEEPER MARO)")
    if not maro or maro.bossId ~= "maro" then error("Maro did not take the field") end
    Test.shot("reckoning_fight")
    -- autosave must refuse during the Reckoning
    local before = G.Save.readSlot(1)
    G.game:autosave()
    local after = G.Save.readSlot(1)
    if after and after.flags.reckoning then error("reckoning was written to disk") end
    -- the fight (Brassa joins at 60%)
    local sawBrassa = false
    while not maro.dead do
      maro:hurt(10, maro.x - 10, maro.y)
      for _, e in ipairs(World.entities) do
        if e.kind == "enemy" and not e.dead and e.sprite == "npc_brassa" then
          sawBrassa = true
        end
      end
      wait(2)
    end
    Test.log("brassa joined=" .. tostring(sawBrassa) .. " (want true)")
    if not sawBrassa then error("Brassa never took the field") end
    wait(20)
    for i = 1, 10 do
      if G.game.dialogue then G.game.dialogue:advance() end
      wait(3)
    end
    Test.log("boss_maro=" .. tostring(G.run.flags.boss_maro) .. " (want true)")
    if not G.run.flags.boss_maro then error("Maro's fall did not register") end
    -- take the Ember: confirmation, the freeze, Tikka's music box
    lantern = findLantern()
    lantern:interact(p1)
    local guard3 = 0
    while not G.run.flags.ember_taken and guard3 < 200 do
      if G.game.dialogue then G.game.dialogue:advance() end
      wait(3)
      guard3 = guard3 + 1
    end
    for i = 1, 14 do
      if G.game.dialogue then G.game.dialogue:advance() end
      wait(3)
    end
    Test.log("ember_taken=" .. tostring(G.run.flags.ember_taken)
      .. " camp_frozen=" .. tostring(G.run.flags.camp_frozen)
      .. " tikka_gift=" .. tostring(G.run.flags.tikka_gift)
      .. " (want true/true/true)")
    if not (G.run.flags.ember_taken and G.run.flags.camp_frozen
        and G.run.flags.tikka_gift) then
      error("the taking of the Ember did not resolve")
    end
    Test.shot("frozen_moment")
    -- the frozen camp is a permanent, walkable tableau
    World:load("camp_main", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    local liveNpcs, frozen = 0, 0
    for _, e in ipairs(World.entities) do
      if e.kind == "npc" and not e.dead then liveNpcs = liveNpcs + 1 end
      if e.hint == "look" then frozen = frozen + 1 end
    end
    Test.log("live npcs=" .. liveNpcs .. " frozen=" .. frozen
      .. " (want 0 / >= 8)")
    if liveNpcs > 0 or frozen < 8 then error("frozen camp tableau wrong") end
    Test.shot("frozen_camp")
    -- carry it to the Seat
    World:load("core_boss", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    local seat
    for _, e in ipairs(World.entities) do
      if e.hint == "the Seat" then seat = e break end
    end
    if not seat then error("the Seat is missing from core_boss") end
    seat:interact(p1)
    local guard4 = 0
    while not G.run.flags.ending and guard4 < 200 do
      if G.game.dialogue then G.game.dialogue:advance() end
      wait(3)
      guard4 = guard4 + 1
    end
    wait(40)
    Test.log("ending_reclaim=" .. tostring(G.run.flags.ending_reclaim)
      .. " state=" .. G.State.top().name .. " (want true / ending)")
    if not G.run.flags.ending_reclaim or G.State.top().name ~= "ending" then
      error("RECLAIM did not reach the ending")
    end
    -- run the cards + credits; ending_done + camp_frozen must persist
    for i = 1, 12 do G.State.top():menu("confirm") wait(12) end
    local disk = G.Save.readSlot(1)
    Test.log("disk ending_done=" .. tostring(disk and disk.flags.ending_done)
      .. " camp_frozen=" .. tostring(disk and disk.flags.camp_frozen)
      .. " (want true/true)")
    if not (disk and disk.flags.ending_done and disk.flags.camp_frozen) then
      error("RECLAIM ending did not persist")
    end
    Test.shot("reclaim_credits")
    Test.log("OK reckoning")
  end

  scenarios.linkvent = function()
    startRun { coop = true, flags = { coredoor = true } }
    wait(12)
    local World = require "src.world"
    local fails = 0
    -- 1) link-core seal in core_2
    World:load("core_2", "A", true)
    wait(10)
    local P1, P2 = G.game.players[1], G.game.players[2]
    if not World:isSolid(51, 11) then
      Test.log("FAIL core_2 seal not solid before blast") fails = fails + 1
    end
    local core
    for _, e in ipairs(World.entities) do
      if e.linkcore then core = e end
    end
    if not core then
      Test.log("FAIL no linkcore entity") fails = fails + 1
    else
      -- ordinary fire must clink off
      P1.x, P1.y = core.x - 40, 11 * 16 + 1
      P1.facing = 1 P1.vx, P1.vy = 0, 0
      require("src.camera").jumpTo(P1.x, P1.y)
      hold(1, "fire") wait(60) release(1, "fire")
      if G.run.flags.linkcore_c2 then
        Test.log("FAIL small arms broke the linkcore") fails = fails + 1
      end
      -- the LINK blast must shatter it
      P2.x, P2.y = P1.x + 10, P1.y
      P2.vx, P2.vy = 0, 0
      G.game:fireLinkShot()
      wait(40)
      if not G.run.flags.linkcore_c2 then
        Test.log("FAIL link blast did not break the core") fails = fails + 1
      end
      if World:isSolid(51, 11) then
        Test.log("FAIL seal still solid after core shattered") fails = fails + 1
      end
    end
    -- 2) ember vents in core_1: Lu's dome eats the barrage
    World:load("core_1", "A", true)
    wait(10)
    for _, e in ipairs(World.entities) do
      if e.kind == "enemy" then e.dead = true end
    end
    P1, P2 = G.game.players[1], G.game.players[2]
    -- park the pair under the col-22 vent, dome up
    P2.x, P2.y = 22 * 16 + 2, 11 * 16 + 1
    P1.x, P1.y = P2.x - 8, P2.y
    P1.vx, P1.vy, P2.vx, P2.vy = 0, 0, 0, 0
    require("src.camera").jumpTo(P2.x, P2.y)
    P2.domeActive = true
    P2.energy = P2.maxenergy
    local hp1, hp2 = P1.hp, P2.hp
    for _ = 1, 300 do
      wait(1)
      P1.x, P1.y = P2.x - 8, P2.y  -- stay huddled
      P1.vx, P1.vy = 0, 0
      P2.vx, P2.vy = 0, 0
      P2.domeActive = true
    end
    if P1.hp < hp1 or P2.hp < hp2 then
      Test.log("FAIL dome did not protect from vent embers ("
        .. P1.hp .. "/" .. hp1 .. ", " .. P2.hp .. "/" .. hp2 .. ")")
      fails = fails + 1
    end
    if P2.energy >= P2.maxenergy then
      Test.log("FAIL vent embers never hit the dome (no energy drain)")
      fails = fails + 1
    end
    -- without the dome, embers hurt
    P2.domeActive = false
    local hurtT = false
    for _ = 1, 400 do
      wait(1)
      P1.x, P1.y = 22 * 16 + 3, 11 * 16 + 1  -- squarely in the ember column
      P1.vx, P1.vy = 0, 0
      if P1.hp < hp1 then hurtT = true break end
    end
    if not hurtT then
      Test.log("FAIL vents never damaged an unshielded player") fails = fails + 1
    end
    P1.hp = P1.maxhp P2.hp = P2.maxhp
    if fails == 0 then Test.log("OK linkvent")
    else Test.log("FAIL linkvent: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- Brassa's forge: scrap-driven upgrades with capsule/tank gating
  -- ----------------------------------------------------------------
  scenarios.forge = function()
    startRun { coop = true, room = "camp_main", door = "A" }
    wait(20)
    local Weapons = require "src.weapons"
    local fails = 0
    local f = Weapons.forge()
    G.run.scrap = 200
    G.State.push(require "src.states.forge")
    wait(5)
    local st = G.State.top()
    -- buy bolt driver tier 2 (first row)
    menuNav("confirm") wait(5)
    if f.boltdriver ~= 2 then Test.log("FAIL weapon tier not bought: " .. tostring(f.boltdriver)) fails = fails + 1 end
    if G.run.scrap ~= 175 then Test.log("FAIL scrap not charged: " .. G.run.scrap) fails = fails + 1 end
    if Weapons.levelOf({ id = "boltdriver" }) ~= 2 then
      Test.log("FAIL levelOf does not track forge tier") fails = fails + 1
    end
    -- hp tier without a capsule core must be refused
    local hpRow = 0
    -- navigate: weapons (2 owned) + dome, then MAX HEALTH row
    menuNav("down") menuNav("down") menuNav("down") wait(2)
    local beforeHp = G.run.players[1].maxhp
    menuNav("confirm") wait(5)
    if f.hpTier ~= 0 or G.run.players[1].maxhp ~= beforeHp then
      Test.log("FAIL hp tier bought without a capsule core") fails = fails + 1
    end
    -- with a core it must work
    G.run.capsules = 1
    menuNav("confirm") wait(5)
    if f.hpTier ~= 1 then Test.log("FAIL hp tier not bought with core") fails = fails + 1 end
    if G.run.players[1].maxhp ~= beforeHp + 4 then
      Test.log("FAIL maxhp not applied: " .. G.run.players[1].maxhp) fails = fails + 1
    end
    if G.game.players[1].maxhp ~= beforeHp + 4 then
      Test.log("FAIL live player maxhp not applied") fails = fails + 1
    end
    -- second hp tier gated again (only 1 core)
    menuNav("confirm") wait(5)
    if f.hpTier ~= 1 then Test.log("FAIL hp tier gating failed on tier 2") fails = fails + 1 end
    -- energy tier gated by tanks
    menuNav("down") wait(2)
    menuNav("confirm") wait(5)
    if f.energyTier ~= 0 then Test.log("FAIL energy tier without tank") fails = fails + 1 end
    G.run.tanks = 1
    menuNav("confirm") wait(5)
    if f.energyTier ~= 1 then Test.log("FAIL energy tier not bought") fails = fails + 1 end
    if G.run.players[2].maxenergy ~= 120 then
      Test.log("FAIL maxenergy not applied: " .. tostring(G.run.players[2].maxenergy)) fails = fails + 1
    end
    -- dome tier makes absorb cheaper
    menuNav("up") menuNav("up") wait(2)  -- back to dome row
    local beforeScrap = G.run.scrap
    menuNav("confirm") wait(5)
    if f.dome ~= 2 then Test.log("FAIL dome tier not bought: " .. tostring(f.dome)) fails = fails + 1 end
    local lu = G.game.players[2]
    lu.energy = 100
    lu:domeAbsorb(10)
    if math.abs(lu.energy - (100 - 16)) > 0.01 then
      Test.log("FAIL dome tier 2 drain wrong: " .. lu.energy) fails = fails + 1
    end
    -- leave via cancel
    menuNav("cancel") wait(5)
    if G.State.top().name ~= "game" then Test.log("FAIL forge did not close") fails = fails + 1 end
    -- save roundtrip keeps forge tiers
    G.game:syncRun()
    G.Save.writeSlot(3, G.run)
    local back = G.Save.readSlot(3)
    if not back or not back.forge or back.forge.boltdriver ~= 2
        or back.forge.hpTier ~= 1 or back.forge.dome ~= 2 then
      Test.log("FAIL forge tiers lost in save roundtrip") fails = fails + 1
    end
    G.Save.deleteSlot(3)
    if fails == 0 then Test.log("OK forge")
    else Test.log("FAIL forge: " .. fails) end
  end

  -- ----------------------------------------------------------------
  -- progress solver sanity: fresh run must be completable; mid-game
  -- run must be completable; panel renders
  -- ----------------------------------------------------------------
  scenarios.progress = function()
    startRun { coop = true }
    wait(20)
    local Prog = require "src.core.progress"
    local r1 = Prog.report()
    Test.log("fresh: completable=" .. tostring(r1.completable)
      .. " roomsNow=" .. r1.roomsReachableNow
      .. " itemsNow=" .. #r1.itemsNow .. " locked=" .. #r1.itemsLocked)
    if not r1.completable then Test.log("FAIL fresh run not completable") end
    if #r1.itemsLocked > 0 then Test.log("FAIL items locked at fresh start") end
    -- a fresh start should NOT already reach everything
    if r1.roomsReachableNow >= r1.roomsTotal then
      Test.log("FAIL zero-flag run reaches every room (gates not gating)")
    end
    -- mid-game state
    for _, f in ipairs({ "sparkjump", "grapple", "hydroseals",
        "boss_bramblemaw", "boss_rustwarden" }) do
      G.run.flags[f] = true
    end
    G.run.room = "flood_hub"
    local r2 = Prog.report()
    Test.log("midgame: completable=" .. tostring(r2.completable)
      .. " roomsNow=" .. r2.roomsReachableNow
      .. " blocked=" .. #r2.itemsBlocked .. " locked=" .. #r2.itemsLocked)
    if not r2.completable then Test.log("FAIL midgame not completable") end
    if #r2.itemsLocked > 0 then Test.log("FAIL items locked midgame") end
    G.run.room = "camp_awake"
    G.settings.testmode = true
    G.Input.queue[#G.Input.queue + 1] = { kind = "rawkey", id = "f1" }
    wait(10)
    Test.shot("progress_panel")
    if G.State.top().name ~= "progress" then
      Test.log("FAIL panel did not open")
    end
    Test.log("OK progress")
  end


  -- ----------------------------------------------------------------
  -- THE BULWARK LINE. The headless harnesses in tools/ prove the maths;
  -- this proves it in the real engine, with real rooms and real bodies.
  -- ----------------------------------------------------------------
  scenarios.bulwark = function()
    local World = require "src.world"
    local Entity = require "src.entities.entity"
    local fails = 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end

    startRun { coop = true, room = "scrap_boss", door = "A",
      flags = { sparkjump = true, grapple = true, heatplating = true,
                hydroseals = true, bulwark = true } }
    wait(20)
    local v = G.game.players[1]

    -- 1. ZERO PASS-THROUGH. Park a body ahead of Vess and charge it.
    local e = Entity.make("plateframe", v.x + 46, v.y - 2)
    World:add(e)
    wait(4)
    v.facing = 1
    v.dashT = 0.2 v.dashCd = 0 v.dashHits = {} v.bulwarkT = 0.32
    local crossed = false
    for i = 1, 30 do
      wait(1)
      if v.x > e.x + e.w then crossed = true end
    end
    if crossed then fail("bulwark: a charge carried Vess THROUGH a body") end
    if v.dashT > 0 then fail("bulwark: the charge did not end on contact") end
    Test.log("bulwark: contact stopped the charge, no pass-through")
    e.dead = true

    -- 2. CONCUSSION on something light, and none on a boss-mass body
    local h = Entity.make("scraphusk", v.x + 44, v.y)
    World:add(h)
    wait(4)
    v.facing = 1
    v.dashT = 0.2 v.dashCd = 0 v.dashHits = {} v.bulwarkT = 0.32
    wait(24)
    if (h.stunT or 0) <= 0 then fail("bulwark: a light body was not concussed") end
    Test.log("bulwark: husk concussed for " .. string.format("%.2f", h.stunT or 0) .. "s")
    h.dead = true

    -- 3. the front/back rule, through the real takeDamage
    v.invuln = 0 v.dashT = 0.2 v.bulwarkT = 0.32
    local hp0 = v.hp
    v:takeDamage(3, v.x + v.w / 2 + 24, { pierceDash = true })
    if v.hp ~= hp0 then fail("bulwark: a FRONTAL pierceDash hit got through") end
    v.invuln = 0 v.dashT = 0.2 v.bulwarkT = 0.32
    v:takeDamage(3, v.x + v.w / 2 - 24, { pierceDash = true })
    if v.hp >= hp0 then fail("bulwark: a hit in the BACK was wrongly blocked") end
    Test.log("bulwark: front blocked, back open")

    -- 4. the CINDER RAM shatters a raised guard rather than damaging it
    G.run.flags.cinderram = true
    local pf = Entity.make("plateframe", v.x + 46, v.y - 2)
    World:add(pf)
    wait(4)
    pf.facing = -1              -- plate pointed AT Vess
    local phc = pf.hp
    v.facing = 1
    v.dashT = 0.2 v.dashCd = 0 v.dashHits = {} v.bulwarkT = 0.32
    wait(24)
    if (pf.guardT or 0) <= 0 then fail("cinderram: the guard did not shatter") end
    if pf.hp ~= phc then fail("cinderram: a guard-break should not also damage") end
    Test.log("cinderram: guard shattered for " .. string.format("%.1f", pf.guardT or 0) .. "s")
    pf.dead = true

    -- 5. EIGHT never leaves its room
    World:load("scrap_boss", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(10)
    local Bosses = require "src.entities.bosses"
    local b = Bosses.start("vessel8", World)
    local lo = 2 * 16
    local hi = World.w * 16 - 2 * 16 - b.w
    local escaped = 0
    for i = 1, 900 do
      wait(1)
      if b.dead then break end
      if b.x < lo - 1 or b.x > hi + 1 then escaped = escaped + 1 end
      if i % 30 == 0 and b.hp > 1 then b.hp = b.hp - 2 end
    end
    if escaped > 0 then fail("EIGHT left the room on " .. escaped .. " frames") end
    Test.log("EIGHT held its post (" .. escaped .. " frames out of bounds)")

    Test.log((fails == 0 and "OK" or "FAILED ") .. " bulwark")
  end


  -- ----------------------------------------------------------------
  -- THE DRIFT VANES. tools/vanes_test.lua proves the physics; this proves
  -- the gate, the column and the co-op camera in the real engine.
  -- ----------------------------------------------------------------
  scenarios.vanes = function()
    local World = require "src.world"
    local Cam = require "src.camera"
    local fails = 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end

    -- 1. THE GATE. sky_2's pocket is sealed until she has the vanes.
    startRun { coop = true, room = "sky_2", door = "A",
      flags = { sparkjump = true, grapple = true } }
    wait(20)
    local lu = G.game.players[2]
    if G.run.flags.driftvanes then fail("vanes: a new run starts with them") end
    lu.onGround = false lu.y = lu.y - 40 lu.vy = 120
    wait(4)
    Test.log("no vanes: hovering=" .. tostring(lu.hovering))
    if lu.hovering then fail("vanes: Lu hovered without the module") end

    G.run.flags.driftvanes = true
    wait(20)
    local p = G.game.players[2]
    p.x, p.y = 300, 60 p.vy = 120 p.onGround = false
    wait(4)
    if not p.hovering then fail("vanes: Lu will not hover WITH the module") end
    Test.log("with vanes: hovering=" .. tostring(p.hovering)
      .. " vy=" .. string.format("%.0f", p.vy))

    -- 2. THE NEST holds the module, and the chest is real
    World:load("sky_nest", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(12)
    local found = false
    for _, e in ipairs(World.entities) do
      if e.kind == "chest" then found = true end
    end
    if not found then fail("sky_nest: no chest -- the vanes never spawned") end
    Test.log("sky_nest chest present: " .. tostring(found))

    -- 3. THE COLUMN lifts her, and only her
    World:load("gal_2", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(12)
    local col
    for _, e in ipairs(World.entities) do
      if e.kind == "updraft" then col = col or e end
    end
    if not col then
      fail("gal_2: no updraft entity spawned")
    else
      Test.log("gal_2 column: " .. col.tiles .. " tiles at y=" .. math.floor(col.y))
      local v, l = G.game.players[1], G.game.players[2]
      for _, who in ipairs({ v, l }) do
        who.x = col.x + 3
        who.y = col.y + col.h - who.h - 2
        who.vx, who.vy = 0, 0
        who.onGround = true
      end
      local ly0, vy0 = l.y, v.y
      hold(2, "jump")
      hold(1, "jump")
      wait(90)
      release(2, "jump")
      release(1, "jump")
      local lrise, vrise = ly0 - l.y, vy0 - v.y
      Test.log(string.format("column: Lu rose %.0f px, Vess rose %.0f px", lrise, vrise))
      if lrise < 8 * 16 then fail("column did not lift Lu") end
      if vrise > 5 * 16 then fail("column lifted VESS -- it must be scenery to him") end

      -- 4. THE CO-OP CAMERA: with Lu at the top and Vess at the bottom,
      -- both must still be on screen.
      Cam.update(1, { v, l })
      for _ = 1, 30 do Cam.update(1 / 60, { v, l }) end
      local sep = math.abs(l.y - v.y)
      local lOn = Cam.onScreen(l.x, l.y, 0)
      local vOn = Cam.onScreen(v.x, v.y, 0)
      Test.log(string.format("separation %.0f px (budget %.0f), Lu on=%s Vess on=%s",
        sep, 0.75 * G.VH, tostring(lOn), tostring(vOn)))
      if not (lOn and vOn) then
        fail("co-op: a bot left the frame at " .. math.floor(sep) .. " px of separation")
      end
    end

    Test.log((fails == 0 and "OK" or "FAILED ") .. " vanes")
  end


  -- ----------------------------------------------------------------
  -- SEALED BOSS SHORTCUTS. The Deep Stair shortcut in each arena must be
  -- unusable until that boss is dead -- otherwise you can brush it on the
  -- way in and walk straight past the fight.
  -- ----------------------------------------------------------------
  scenarios.sealed = function()
    local World = require "src.world"
    local fails = 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end

    startRun { coop = true, flags = {
      sparkjump = true, grapple = true, hydroseals = true,
      heatplating = true, cryocoils = true, driftvanes = true,
    } }
    wait(12)

    local LIST = {
      { "furn_boss", "B", "boss_crucible" },
      { "crys_boss", "B", "boss_prismtyrant" },
      { "flood_boss", "F", "boss_tideengine" },
      { "cold_boss", "C", "boss_archivist" },
    }
    for _, e in ipairs(LIST) do
      local room, ch, flag = e[1], e[2], e[3]
      G.run.flags[flag] = nil
      World:load(room, "A", true)
      G.game.fade = 0 G.game.fadeDir = 0
      wait(8)
      local d = World.doors[ch]
      if not d then
        fail(room .. ": no door " .. ch)
      else
        if not World:doorSealed(d) then
          fail(room .. ":" .. ch .. " is NOT sealed before the boss dies")
        end
        -- stand in the doorway and try to leave
        World.pendingTransition = nil
        for _, pl in ipairs(World.players) do
          pl.x = d.x0 * 16 + 1
          pl.y = d.y0 * 16
          pl.vx, pl.vy = 0, 0
        end
        World:requestTransition(ch)
        if World.pendingTransition then
          fail(room .. ":" .. ch .. " LET US THROUGH before the boss was dead")
          World.pendingTransition = nil
        end
        Test.log(room .. ":" .. ch .. " sealed, transition refused")

        -- now kill the boss and try again
        G.run.flags[flag] = true
        if World:doorSealed(d) then
          fail(room .. ":" .. ch .. " still sealed AFTER the boss died")
        end
        World:requestTransition(ch)
        if not World.pendingTransition then
          fail(room .. ":" .. ch .. " will not open after the boss died")
        end
        Test.log(room .. ":" .. ch .. " opens once " .. flag .. " is held")
        World.pendingTransition = nil
      end
    end

    -- and an ordinary door is untouched
    World:load("moss_2", "A", true)
    G.game.fade = 0 G.game.fadeDir = 0
    wait(8)
    for ch2, d2 in pairs(World.doors) do
      if d2.link and World:doorSealed(d2) then
        fail("moss_2:" .. ch2 .. " is sealed and should not be")
      end
    end
    Test.log("ordinary doors unaffected")

    Test.log((fails == 0 and "OK" or "FAILED ") .. " sealed")
  end

  scenarios.solo = function()
    startRun { coop = false, room = "test_arena", door = "A" }
    wait(20)
    Test.log("solo spawn p1=" .. pos(1) .. " idle2=" .. tostring(G.game.players[2].idle))
    press(1, "partner")
    wait(20)
    Test.log("activeBot=" .. G.game.activeBot .. " idle1=" .. tostring(G.game.players[1].idle))
    hold(1, "right")
    wait(40)
    release(1, "right")
    hold(1, "partner")
    wait(50)
    release(1, "partner")
    wait(5)
    Test.log("after recall p1=" .. pos(1) .. " p2=" .. pos(2))
    Test.log("OK solo")
  end

  -- ----------------------------------------------------------------
  -- ENTITY SLEEP (Phase 2.5)
  --
  -- Driven with PROBES rather than real enemies: a probe counts the
  -- frames it was allowed to think in, so the assertion is on the
  -- behaviour ("did this body update?") and not on some enemy's internal
  -- state, which would break the moment that enemy is retuned.
  -- ----------------------------------------------------------------
  scenarios.sleep = function()
    startRun { coop = true, room = "test_arena", door = "A" }
    wait(10)
    local World = require "src.world"
    local fails = 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end

    local function probe(x, y, canSleep)
      local e = { x = x, y = y, w = 12, h = 12, ticks = 0, dead = false,
                  invuln = 0, white = 0, canSleep = canSleep, kind = "probe",
                  update = function(self) self.ticks = self.ticks + 1 end,
                  draw = function() end }
      World:add(e)
      return e
    end

    local p1 = G.game.players[1]
    local far    = probe(6000, 6000, true)
    local near   = probe(p1.x + 40, p1.y, true)
    local optOut = probe(6000, 6000, nil)
    wait(30)
    Test.log(("ticks after 30: far=%d near=%d optOut=%d slept=%s")
      :format(far.ticks, near.ticks, optOut.ticks, tostring(World.sleptLast)))
    if far.ticks ~= 0 then fail("a body 6000px away kept thinking") end
    if near.ticks == 0 then fail("a body beside the player stopped thinking") end
    if optOut.ticks == 0 then fail("a body that never opted in was put to sleep") end
    if not World.sleptLast or World.sleptLast < 1 then
      fail("World.sleptLast did not report the sleeping body")
    end

    -- it must WAKE when you come back, or this is a soft-lock generator
    far.x, far.y = p1.x + 40, p1.y
    local was = far.ticks
    wait(20)
    if far.ticks <= was then fail("a sleeper next to the player never woke") end

    -- ...and nothing sleeps during a boss fight, however far it wanders:
    -- a boss add frozen off screen is a fight that never ends.
    --
    -- Asserted by calling the predicate with a controlled `self`, NOT by
    -- standing a fake boss up in the live World. World.bossActive is
    -- contractually a boss ENTITY -- hud.lua reads b.hp / b.maxhp off it
    -- every single frame -- so a `{ fake = true }` there does not test the
    -- sleep guard, it crashes the draw path by breaking a different
    -- invariant. That is exactly what the first version of this did.
    far.x, far.y = 6000, 6000
    if World:asleep(far) ~= true then
      fail("a body 6000px away was not asleep to begin with")
    end
    local fighting = { bossActive = true, players = World.players,
                       asleep = World.asleep }
    if fighting:asleep(far) ~= false then
      fail("bossActive did not keep a distant body awake")
    end

    far.dead, near.dead, optOut.dead = true, true, true
    wait(2)
    Test.log((fails == 0 and "OK" or "FAILED ") .. " sleep")
  end

  -- ----------------------------------------------------------------
  -- ROOMIO: the room editor's save layer, proven before any UI exists.
  --
  -- The load-bearing assertion is IDENTITY: read a room's grid and write
  -- it back unchanged, and the file must come out BYTE-IDENTICAL. One
  -- assertion, run over every room in the game, catches comment loss,
  -- whitespace drift, a mangled trailing newline and quoting bugs all at
  -- once -- and it is the entire reason the save layer does surgery
  -- instead of parse-and-reserialise.
  --
  -- Dry-run, so proving it costs nothing and touches no files.
  -- ----------------------------------------------------------------
  scenarios.roomio = function()
    local R = require "src.roomio"
    local WM = require "src.data.worldmap"
    local fails, checked, widest = 0, 0, 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end

    for _, id in ipairs(WM.ROOMS) do
      local src = R.readRaw(id)
      if not src then fail("cannot read " .. id)
      else
        local rows, err = R.readRows(id)
        if not rows then fail(id .. ": " .. tostring(err))
        else
          local w, h = R.checkRect(rows)
          if not w then fail(id .. " is ragged: " .. tostring(h))
          else
            if w > widest then widest = w end
            local out, werr = R.writeMap(id, rows, { dryrun = true })
            if not out then fail(id .. " write: " .. tostring(werr))
            elseif out ~= src then
              fail(id .. " NOT IDENTITY (" .. #src .. " -> " .. #out .. " bytes)")
            else
              checked = checked + 1
            end
          end
        end
      end
    end
    Test.log(("identity: %d/%d rooms byte-identical, widest %d"):format(checked, #WM.ROOMS, widest))

    -- EDIT AND REVERT. An edit must land, and undoing it must return the
    -- file to exactly what it was -- which is the property the editor's
    -- undo stack is going to lean on all day.
    local id = "test_arena"
    local src0 = R.readRaw(id)
    if src0 then
      local rows = R.readRows(id)
      local orig = rows[2]
      rows[2] = string.rep("#", #orig)
      local edited = R.writeMap(id, rows, { dryrun = true })
      if not edited then fail("edit did not produce output")
      elseif edited == src0 then fail("edit produced no change")
      else
        rows[2] = orig
        local back = R.writeMap(id, rows, { dryrun = true })
        if back ~= src0 then fail("revert did not restore the original bytes")
        else Test.log("edit-and-revert restores the original exactly") end
      end

      -- A ragged map must be REFUSED, not written. This is the check that
      -- stops a one-character drift becoming a room that parses and is
      -- nonsense.
      local bad = R.readRows(id)
      bad[3] = bad[3] .. "#"
      local out, werr = R.writeMap(id, bad, { dryrun = true })
      if out then fail("a ragged map was accepted")
      else Test.log("ragged map refused: " .. tostring(werr)) end
    end

    -- BOTH TERMINATOR CONVENTIONS, synthesised.
    --
    -- 82 of 83 rooms end their map block with a newline before `]]`;
    -- camp_hut ends `...####]]` with none, and that single room is the
    -- only reason the first version of gridToRows was caught dropping a
    -- final row. If camp_hut is ever normalised, the sweep above stops
    -- covering the variant and nothing notices -- so the variant is
    -- constructed here rather than relied upon in the content.
    for _, tc in ipairs({
      { name = "trailing newline", body = "###\n#.#\n###\n" },
      { name = "no terminator",    body = "###\n#.#\n###"   },
    }) do
      local rows = R.gridToRows(tc.body)
      local back = R.rowsToGrid(rows, tc.body:sub(-1) == "\n")
      if #rows ~= 3 then
        fail(("%s: got %d rows, expected 3"):format(tc.name, #rows))
      elseif back ~= tc.body then
        fail(("%s: round-trip changed the bytes (%q -> %q)"):format(tc.name, tc.body, back))
      else
        Test.log(("both conventions: %-17s %d rows, byte-identical"):format(tc.name, #rows))
      end
    end

    Test.log((fails == 0 and "OK" or "FAILED ") .. " roomio")
  end

  -- ----------------------------------------------------------------
  -- EDITOR -- the parts that have no pixels in them.
  --
  -- The editor is a mouse tool, so almost none of it is testable and
  -- the parts that ARE are exactly the parts that break silently: the
  -- mouse-to-tile arithmetic (off by one tile and you paint the wrong
  -- cell forever), the widget hit test, the undo snapshot, and the
  -- check THREAD, which either round-trips or hangs the editor.
  -- ----------------------------------------------------------------
  scenarios.editor = function()
    local World = require "src.world"
    local Cam = require "src.camera"
    local Ed = require "src.states.editor"
    local fails = 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end
    local function eq(got, want, what)
      if got ~= want then fail(("%s: got %s want %s"):format(what, tostring(got), tostring(want))) end
    end

    World:load("moss_1", nil, true)
    Ed:enter()
    if not Ed.rows then fail("no rows for moss_1") return end
    eq(Ed.id, "moss_1", "room id")

    -- geometry agrees with the engine's own parse
    eq(Ed:w(), World.w, "width")
    eq(Ed:h(), World.h, "height")

    -- paint -> text AND live tiles, then undo restores both
    local tx, ty = 2, 2
    local before = Ed:get(tx, ty)
    local target = (before == "#") and "." or "#"
    Ed:snapshot()
    Ed:set(tx, ty, target)
    eq(Ed:get(tx, ty), target, "text after set")
    eq(World.tiles[ty][tx], World.CHAR_TILE[target], "live tile after set")
    if not Ed.dirty then fail("set did not mark dirty") end
    Ed:doUndo()
    eq(Ed:get(tx, ty), before, "text after undo")
    eq(World.tiles[ty][tx], World.CHAR_TILE[before], "live tile after undo")

    -- rows must still be rectangular after all that
    local RoomIO = require "src.roomio"
    local w = RoomIO.checkRect(Ed.rows)
    if not w then fail("rows went ragged") end

    -- mouse -> tile. Pin the blit and the camera and check the corners
    -- rather than trusting the algebra.
    G.blitOX, G.blitOY, G.blitScale = 100, 50, 2
    local oldRS = G.RS; G.RS = 1
    Cam.x, Cam.y, Cam.ox, Cam.oy = 32, 16, 32, 16
    local realGet = love.mouse.getPosition
    local function at(mx, my)
      love.mouse.getPosition = function() return mx, my end
      return Ed:cursorTile()
    end
    -- screen 100,50 is logical 0,0 which is world 32,16 -> tile 2,1
    local cx, cy = at(100, 50); eq(cx, 2, "cursorTile x at origin") eq(cy, 1, "cursorTile y at origin")
    -- +32 screen px at scale 2 is +16 logical = one whole tile right
    cx, cy = at(132, 50); eq(cx, 3, "cursorTile x +1 tile")
    -- and the widget hit test, in the SAME logical space
    local hitTool = Ed:hit(6, 26)
    if not hitTool or hitTool.kind ~= "tool" then fail("tool row does not hit at 6,26") end
    local hitTile = Ed:hit(6, 8)
    if not hitTile or hitTile.kind ~= "tile" then fail("tile row does not hit at 6,8") end
    if Ed:hit(6, 200) then fail("hit test claims a widget in the play area") end
    -- every widget must carry a tooltip, or hovering it teaches nothing
    for _, g in ipairs(Ed.widgets) do
      if not g.tip or #g.tip < 8 then fail("widget " .. tostring(g.label) .. " has no tooltip") end
    end
    love.mouse.getPosition = realGet
    G.RS = oldRS

    -- THE THREAD. One fast validator, real io.popen, real channels.
    -- If this hangs, the editor hangs, and that is the whole reason
    -- the thread exists.
    Ed.job = nil
    local FASTONE = "checkdoors\tPYTHONPATH=../scripts python3 ../scripts/checkdoors.py"
    local prog = love.thread.getChannel("edcheck_progress")
    local res = love.thread.getChannel("edcheck_result")
    while prog:pop() do end
    while res:pop() do end
    local th = love.thread.newThread("src/checkthread.lua")
    th:start(FASTONE)
    local t0 = love.timer.getTime()
    local bad
    while love.timer.getTime() - t0 < 30 do
      bad = res:pop()
      if bad then break end
      local err = th:getError()
      if err then fail("check thread error: " .. tostring(err)) break end
      love.timer.sleep(0.02)
    end
    if bad == nil then
      fail("check thread never returned within 30s")
    else
      eq(bad, 0, "checkdoors failure count via thread")
      Test.log(("thread round-trip in %.2fs"):format(love.timer.getTime() - t0))
    end
    local sawProgress = false
    while true do
      local p = prog:pop()
      if not p then break end
      if p:find("checkdoors", 1, true) then sawProgress = true end
    end
    if not sawProgress then fail("thread published no progress line") end

    -- REVERT MUST PUT THE LIVE TILES BACK, not just the text. The first
    -- version reassigned self.rows only, so the screen kept every
    -- discarded edit and the status line read "saved" -- a revert
    -- indistinguishable from a save.
    local rx, ry = 3, 3
    local orig = Ed:get(rx, ry)
    local other = (orig == "#") and "." or "#"
    Ed:snapshot()
    Ed:set(rx, ry, other)
    Ed:loadFromDisk(true)
    eq(Ed:get(rx, ry), orig, "text after revert")
    eq(World.tiles[ry][rx], World.CHAR_TILE[orig], "LIVE TILE after revert")
    if Ed.dirty then fail("revert left the room marked dirty") end
    -- and the revert is itself undoable
    Ed:doUndo()
    eq(Ed:get(rx, ry), other, "undo brings the discarded edit back")
    Ed:loadFromDisk(true)

    -- F2 must live on the RAW channel. In keypressed it popped the
    -- editor and then handed the same keypress to the game underneath,
    -- which pushed it straight back -- F2 did nothing, twice per press.
    if Ed.keypressed == nil then fail("no keypressed") end
    if type(Ed.raw) ~= "function" then fail("editor has no raw() -- F2 will not exit") end
    Ed.confirm = nil
    Ed.dirty = false
    local popped = false
    local realPop = G.State.pop
    G.State.pop = function() popped = true end
    Ed:raw({ kind = "rawkey", id = "f2" })
    if not popped then fail("F2 on a clean room did not exit") end
    -- ...and with edits pending it must ASK instead of leaving
    popped = false
    Ed.dirty = true
    Ed:raw({ kind = "rawkey", id = "f2" })
    if popped then fail("F2 discarded unsaved edits without asking") end
    if not Ed.confirm then fail("F2 with unsaved edits raised no confirm") end
    if #Ed.confirm.opts < 3 then fail("exit confirm needs save / discard / cancel") end
    -- ESC takes the LAST option, which must therefore be the safe one
    local last = Ed.confirm.opts[#Ed.confirm.opts]
    if last.fn then fail("the escape-hatch option must do nothing, not act") end
    Ed:answer(last)
    if Ed.confirm then fail("answering left the modal up") end
    if popped then fail("cancel exited anyway") end
    G.State.pop = realPop
    Ed.dirty = false

    -- ctrl+R must ask too, and every option must be reachable by key
    Ed:set(rx, ry, other)
    Ed:askRevert()
    if not Ed.confirm then fail("ctrl+R raised no confirm") end
    for _, o in ipairs(Ed.confirm.opts) do
      if not o.key or #o.key ~= 1 then fail("confirm option without a single-key binding") end
    end
    Ed:answer(Ed.confirm.opts[1])          -- DISCARD
    eq(Ed:get(rx, ry), orig, "confirmed revert restored the tile")

    -- leaving must put the camera back inside the room
    Cam.x, Cam.y = -300, -300
    Ed:leave()
    if Cam.x < 0 or Cam.y < 0 then fail("leave() left the camera outside the room") end

    Test.log((fails == 0 and "OK" or "FAILED ") .. " editor")
  end

  -- ----------------------------------------------------------------
  -- RESIZE -- growing a room outward.
  --
  -- Every assertion here is for something that fails SILENTLY. A door
  -- that stopped being an edge door still loads. Art that no longer
  -- lines up with its terrain still draws. A room one column wider than
  -- its neighbours' expectations still parses. None of it crashes and
  -- none of it looks wrong until you are standing in it.
  -- ----------------------------------------------------------------
  scenarios.resize = function()
    local World = require "src.world"
    local RoomIO = require "src.roomio"
    local Ed = require "src.states.editor"
    local fails = 0
    local function fail(m) Test.log("FAIL " .. m) fails = fails + 1 end
    local function eq(got, want, what)
      if got ~= want then fail(("%s: got %s want %s"):format(what, tostring(got), tostring(want))) end
    end

    -- ---------------------------------------------------------------
    -- THE DOORS THAT MUST RIDE THE EDGE
    --
    -- A door's side is derived from where it sits, so growing an edge
    -- under one silently turns it into an interior portal and the room
    -- still loads. One fixture per edge, because the four directions
    -- are four different code paths -- and each fixture ASSERTS IT HAS
    -- A DOOR ON THAT EDGE before testing anything, so that re-hanging a
    -- door in one of these rooms fails this test loudly instead of
    -- quietly making it prove nothing.
    -- ---------------------------------------------------------------
    local FIXTURES = {
      { "moss_1", "right" },       -- TWO doors on the one edge (B and E)
      { "moss_1", "left" },
      { "flood_4", "top" },
      { "deep_stair_1", "bottom" },-- two again (B and D), and an ART room
    }

    local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

    for _, fx in ipairs(FIXTURES) do
      local room, edge = fx[1], fx[2]
      local tag = room .. "/" .. edge
      World:load(room, nil, true)
      Ed:enter()
      if not Ed.rows then fail(tag .. ": no rows") break end
      local w0, h0 = Ed:w(), Ed:h()
      local doors = Ed:doorsOnEdge(edge)
      local before, sideBefore = Ed:doorCells(), {}
      for ch, d in pairs(before) do sideBefore[ch] = Ed:doorSide(d) end
      if count(doors) == 0 then
        fail(tag .. " has no door on that edge -- this fixture proves nothing")
      else
        local horiz = (edge == "left" or edge == "right")
        local dx = (edge == "left") and 2 or 0
        local dy = (edge == "top") and 2 or 0

        Ed:resize(edge, 2)
        eq(Ed:w(), horiz and w0 + 2 or w0, tag .. " width")
        eq(Ed:h(), horiz and h0 or h0 + 2, tag .. " height")
        if not RoomIO.checkRect(Ed.rows) then fail(tag .. ": grid went ragged") end
        eq(World.w, Ed:w(), tag .. ": World.w followed")
        eq(World.h, Ed:h(), tag .. ": World.h followed")

        -- new space is ROCK. Growing into air punches the same hole
        -- through a wall that "reverting" with '.' used to.
        local probeX = (edge == "left") and 0 or (edge == "right") and (Ed:w() - 1) or 1
        local probeY = (edge == "top") and 0 or (edge == "bottom") and (Ed:h() - 1) or 1
        local pc = Ed:get(probeX, probeY)
        if pc ~= "#" and not World.DOOR_CHARS[pc] then
          fail(tag .. ": new space is '" .. tostring(pc) .. "', not solid")
        end

        -- every door that was on the edge is still on it, same size...
        local after = Ed:doorsOnEdge(edge)
        local afterAll = Ed:doorCells()
        for ch, cells in pairs(doors) do
          if not after[ch] then
            fail(tag .. ": door " .. ch .. " did not ride the edge out")
          elseif #after[ch] ~= #cells then
            fail(tag .. ": door " .. ch .. " changed size riding out")
          end
          -- ...and the cells it vacated were filled in, not left as a
          -- second copy of the door floating inside the room
          for _, c in ipairs(cells) do
            local ox, oy = c[1] + dx, c[2] + dy
            local old = Ed:get(ox, oy)
            if World.DOOR_CHARS[old] and after[ch] then
              local still = false
              for _, n in ipairs(after[ch]) do
                if n[1] == ox and n[2] == oy then still = true end
              end
              if not still then
                fail(tag .. ": door " .. ch .. " left a copy behind at " ..
                     ox .. "," .. oy)
              end
            end
          end
        end
        -- ...and nothing became an edge door that was not one
        for ch in pairs(after) do
          if not doors[ch] then
            fail(tag .. ": " .. ch .. " became an edge door out of nowhere")
          end
        end

        -- THE ONE THAT SHIPPED BROKEN: every door on any OTHER wall
        -- must be exactly where it was, shifted only by the origin.
        -- The first version asked which door CELLS touched the growing
        -- edge, so a left door reaching the bottom row was dragged down
        -- the wall and buried in the new rock -- and it kept x == 0, so
        -- checkdoors saw a valid left door and said nothing.
        for ch, d in pairs(before) do
          if Ed:doorSide(d) ~= edge then
            local nd = afterAll[ch]
            if not nd then
              fail(tag .. ": door " .. ch .. " vanished from another wall")
            else
              eq(#nd.cells, #d.cells, tag .. ": door " .. ch ..
                 " changed size while another wall grew")
              eq(nd.x0, d.x0 + dx, tag .. ": door " .. ch .. " moved in x")
              eq(nd.y0, d.y0 + dy, tag .. ": door " .. ch .. " moved in y")
              eq(Ed:doorSide(nd), sideBefore[ch], tag .. ": door " .. ch ..
                 " changed WALL from " .. tostring(sideBefore[ch]))
            end
          end
        end
        -- and no door may be torn in half: its cells must stay contiguous
        for ch, nd in pairs(afterAll) do
          local span = (nd.x1 - nd.x0 + 1) * (nd.y1 - nd.y0 + 1)
          if span ~= #nd.cells then
            fail(tag .. ": door " .. ch .. " is in " .. #nd.cells ..
                 " cells spread over a " .. span .. "-cell box -- it was torn")
          end
        end

        -- the origin moves for left and top ONLY
        eq(Ed.pendDX or 0, dx, tag .. ": pendDX")
        eq(Ed.pendDY or 0, dy, tag .. ": pendDY")

        -- the edge now carries doors, so a shrink into it must refuse
        local ww, hh = Ed:w(), Ed:h()
        Ed:resize(edge, -1)
        eq(Ed:w(), ww, tag .. ": shrink ate a wall with a door on it (w)")
        eq(Ed:h(), hh, tag .. ": shrink ate a wall with a door on it (h)")
        if not (Ed.status or ""):find("in the way", 1, true) then
          fail(tag .. ": shrink refused without naming what was in the way")
        end

        -- undo restores the shape, World, and the pending shift
        Ed:doUndo()
        eq(Ed:w(), w0, tag .. ": width after undo")
        eq(Ed:h(), h0, tag .. ": height after undo")
        eq(World.w, w0, tag .. ": World.w after undo")
        eq(#Ed.rows[1], w0, tag .. ": row text after undo")
        eq(Ed.pendDX or 0, 0, tag .. ": undo left a stale origin shift")
        eq(Ed.pendDY or 0, 0, tag .. ": undo left a stale origin shift (y)")
      end
    end

    -- ---------------------------------------------------------------
    -- THE DERIVED TABLES
    --
    -- The live rebuild used to walk CHAR_TILE by hand, which skipped the
    -- four passes world.lua runs over the finished tile array. The one
    -- that showed: the settle pass turns the AIR cell an entity spawns
    -- in back into WATER, so every enemy standing in a lake left an air
    -- bubble behind the moment the room was resized.
    -- ---------------------------------------------------------------
    do
      local wet = nil
      for _, room in ipairs({ "flood_2", "flood_3", "flood_4", "flood_5" }) do
        World:load(room, nil, true)
        Ed:enter()
        -- a cell that is WATER in the world but is NOT a water character
        -- in the text: that is exactly what the settle pass produced
        for ty = 0, Ed:h() - 1 do
          for tx = 0, Ed:w() - 1 do
            if World.tiles[ty][tx] == World.codes.WATER
               and Ed:get(tx, ty) ~= "~" then
              wet = { room, tx, ty, Ed:get(tx, ty) }
              break
            end
          end
          if wet then break end
        end
        if wet then break end
      end
      if not wet then
        fail("no room has a settled-water cell -- this test proves nothing")
      else
        local room, tx, ty, ch = wet[1], wet[2], wet[3], wet[4]
        Test.log(("settled water fixture: %s (%d,%d) is '%s' in the text")
                 :format(room, tx, ty, ch))
        World:load(room, nil, true)
        Ed:enter()
        Ed:resize("bottom", 1)
        eq(World.tiles[ty][tx], World.codes.WATER,
           room .. ": settled water at " .. tx .. "," .. ty ..
           " turned to air across a resize")
        -- the other derived tables must come back too
        if not World.waterDepth then fail(room .. ": waterDepth was dropped") end
        if not World.decor then fail(room .. ": decor was dropped") end
        local d = Ed:doorCells()
        for ch2 in pairs(d) do
          if not World.doors[ch2] then
            fail(room .. ": door " .. ch2 .. " missing from World.doors after resize")
          end
        end
        Ed:doUndo()
      end
    end

    -- back to a known room for the rest
    World:load("moss_1", nil, true)
    Ed:enter()

    -- ---------------------------------------------------------------
    -- THE ART SHIFT. Ten rooms carry absolute world-pixel coordinates;
    -- a left/top grow slides the terrain out from under them.
    -- ---------------------------------------------------------------
    local src = RoomIO.readRaw("deep_stair_1")
    if not src then fail("cannot read deep_stair_1") else
      local a, b = RoomIO.fieldSpan(src, "lights")
      if not a or type(b) ~= "number" then fail("fieldSpan missed lights") else
        local out = RoomIO.shiftArt(src, 48, 0)
        if #out < #src - 40 then fail("shiftArt mangled the file") end
        -- the first light was at x = 46; +48 makes it 94, y untouched
        local nb = select(2, RoomIO.fieldSpan(out, "lights"))
        local body = out:sub(select(1, RoomIO.fieldSpan(out, "lights")), nb)
        if not body:find("x = 94", 1, true) then
          fail("shiftArt did not move the first light to x = 94")
        end
        if not body:find("y = 68", 1, true) then
          fail("shiftArt moved a y it was told to leave alone")
        end
        -- and it must still be Lua
        if not load(out, "shifted") then fail("shifted file no longer parses") end
        -- a zero shift is EXACTLY the identity, or every save rewrites
        -- ten heavily-commented files for nothing
        local same = RoomIO.shiftArt(src, 0, 0)
        if same ~= src then fail("a zero shift is not the identity") end
        -- comments must survive: this file is mostly commentary
        local cbefore = select(2, src:gsub("\n%s*%-%-", ""))
        local cafter = select(2, out:gsub("\n%s*%-%-", ""))
        eq(cafter, cbefore, "comment lines lost to the shift")
      end
    end

    -- The awkward cases, synthesised rather than hoped for: a COMMENT
    -- that contains "x = 10", a negative coordinate, a float, a nested
    -- colour table, and neighbouring fields (w, h, lw, a2) that share a
    -- line with the two that move.
    do
      local probe = table.concat({
        "return {",
        "  zone = \"t\",",
        "  backdrop = {",
        "    -- moved this from x = 10, y = 20 back when it was wrong",
        "    { kind = \"rect\", x = 10, y = 20, w = 4, h = 4, col = \"black\" },",
        "    { kind = \"band\", x = -6, y = 0, w = 480, h = 544, a2 = 0.5 },",
        "    { kind = \"hang\", x = 12.5, y = 7, lw = 2, sway = 5 },",
        "  },",
        "  lights = { { x = 3, y = 4, r = 9, col = { 1, 0.5, 0.25 } } },",
        "}",
      }, "\n")
      local got = RoomIO.shiftArt(probe, 100, 1000)
      local want = {
        { "-- moved this from x = 10, y = 20", "a comment was rewritten" },
        { "x = 110, y = 1020, w = 4, h = 4", "plain coords, or w/h moved too" },
        { "x = 94, y = 1000, w = 480, h = 544", "a negative x" },
        { "x = 112.5, y = 1007, lw = 2", "a float, or lw moved" },
        { "x = 103, y = 1004, r = 9", "a one-line lights table" },
        { "col = { 1, 0.5, 0.25 }", "a nested colour table was touched" },
      }
      for _, wcase in ipairs(want) do
        if not got:find(wcase[1], 1, true) then
          fail("shiftArt got " .. wcase[2] .. " wrong")
        end
      end
      if not load(got, "probe") then fail("shifted probe does not parse") end
    end

    -- nothing above may have written to disk
    local now = RoomIO.readRaw("deep_stair_1")
    if now ~= src then fail("the scenario wrote to deep_stair_1") end

    Ed.pendDX, Ed.pendDY = 0, 0
    Test.log((fails == 0 and "OK" or "FAILED ") .. " resize")
  end
end
