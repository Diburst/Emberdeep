-- ==================================================================
-- THE COLDSTORE'S VERB: heat you carry
-- ==================================================================
-- Every number the zone runs on lives here, for the same reason every
-- upgrade cost lives in src/upgrades.lua: the moment a constant is
-- written in two places, one of them is wrong and nobody finds out for
-- a month.
--
-- It also has to be readable from OUTSIDE Lua. tools/checkheat.py walks
-- the brazier chain at the real carry speed against the real spark
-- timer and fails if two consecutive braziers are further apart than a
-- spark survives -- and it reads these values straight out of this file
-- rather than keeping its own copy. A validator with its own copy of
-- the number it is validating is a validator that passes forever.
--
-- THE TWO LAWS, and why they do not overlap:
--   ICE  is broken by a heavy blow  -- the ram, the charged lance, the
--        mortar. That is the thawplate rule and it is unchanged.
--   FIRE is spread only by carrying it. Nothing else lights anything.
--        Not the Cinder Ram, not a charge, not a lance. The chain
--        starts at the one hearth that never went out and you extend
--        it outward, one crossing at a time.
--
-- The second law is the whole zone. If a charge could light a brazier
-- the spark would be decoration and the Coldstore would be a corridor
-- with a status effect in it.
-- ==================================================================
local Cold = {}

-- ------------------------------------------------------------------
-- CHILL. A 0..1 meter per bot. It is not a debuff; it is a countdown.
-- ------------------------------------------------------------------
-- Unprotected: FILL_BARE takes the meter from empty to full, and then
-- the bite starts. Full-to-down is BITE_TICK * (1 / BITE_FRAC) seconds,
-- and because the bite is a FRACTION of max HP rather than a flat
-- number, the countdown is the same length for a bot on base 12 HP and
-- for a maxed one. "About four seconds" stays about four seconds
-- instead of quietly becoming instant for an unupgraded run.
Cold.CHILL_MAX   = 1.0
Cold.FILL_BARE   = 1 / 2.2     -- meter/sec with no Cryo Coils
Cold.FILL_COILED = 1 / 11.0    -- ...with them: crossable, never comfortable
Cold.DRAIN       = 1 / 1.2     -- meter/sec inside a heat radius
-- MEASURED, not chosen: takeDamage grants 1.2s of i-frames, so a tick
-- faster than that is a number that lies about itself. It was 0.5, and
-- the harness showed the bites landing 1.2s apart regardless.
Cold.BITE_TICK   = 1.2         -- seconds between bites once the meter is full
Cold.BITE_FRAC   = 0.30        -- of max HP per bite
Cold.BITE_MIN    = 2           -- ...never less than this

-- The tell before the teeth. Above SLOW_AT the bot stiffens up, so the
-- meter is legible in the movement and not only in the bar.
Cold.SLOW_AT     = 0.55
Cold.SLOW_MIN    = 0.72        -- of top speed at a full meter

-- ------------------------------------------------------------------
-- HEAT. A lit brazier is an island; the hearth is the mainland.
-- ------------------------------------------------------------------
Cold.BRAZIER_R   = 48          -- px. Chill drains inside this.
Cold.HEARTH_R    = 76
Cold.BRAZIER_LIGHT = 90        -- lightR, for the dark
Cold.HEARTH_LIGHT  = 150

-- ------------------------------------------------------------------
-- THE SPARK. The zone's clock.
-- ------------------------------------------------------------------
-- You take fire out of a lit brazier and you have SPARK_BURN seconds of
-- it. Carrying costs you your gun, your dome and your charge -- the
-- same trade the Ember makes, one size down -- so whoever holds it is
-- being escorted, not fighting.
--
-- While it burns it holds your own chill off. That is not generosity:
-- it is what makes the ESCORT the one racing the meter, and it is why
-- losing the spark halfway is a walk home rather than a death.
Cold.SPARK_BURN  = 10.0
Cold.CARRY_SLOW  = 0.85        -- of top speed
Cold.SPARK_LIGHT = 64
Cold.SPARK_R     = 20          -- px reach to light a brazier by walking into it

-- Warn the carrier with sound and shrinking flame for the last stretch.
Cold.SPARK_LOW   = 3.0

-- ------------------------------------------------------------------
-- Is (x, y) inside anything burning?  Returns the strongest source, or
-- nil. Anything with a `heatR` counts, so a brazier, the hearth and
-- whatever Phase 2 adds all answer the same question.
-- ------------------------------------------------------------------
function Cold.heatAt(World, x, y)
  local best, bestSlack = nil, -1
  for _, e in ipairs(World.entities or {}) do
    local r = e.heatR
    if r and r > 0 and not e.dead then
      local ex = e.x + (e.w or 0) / 2
      local ey = e.y + (e.h or 0) / 2
      local dx, dy = x - ex, y - ey
      local slack = r - math.sqrt(dx * dx + dy * dy)
      if slack > bestSlack then best, bestSlack = e, slack end
    end
  end
  if bestSlack >= 0 then return best end
  return nil
end

-- ------------------------------------------------------------------
-- Brazier state lives in the RUN, not on the prop, so a lit brazier is
-- still lit when you walk back into the room -- and still lit after a
-- save, a bot swap and a reload. Lighting one is permanent progress,
-- exactly like opening a shortcut.
-- ------------------------------------------------------------------
function Cold.flagFor(id) return "brazier_" .. tostring(id) end

function Cold.isLit(id)
  if not (G.run and G.run.flags) then return false end
  return G.run.flags[Cold.flagFor(id)] and true or false
end

function Cold.light(id)
  if not (G.run and G.run.flags) then return end
  G.run.flags[Cold.flagFor(id)] = true
end

-- ------------------------------------------------------------------
-- A GATE THAT ANSWERS TO THE ZONE'S OWN WORK
-- ------------------------------------------------------------------
-- The way to the Threshold used to be opened by carrying four catalog
-- plates in from four other zones and handing them to a man standing in
-- a doorway. That is the least mysterious structure available, and it
-- put the Coldstore's climax behind errands run somewhere else.
--
-- It answers to heat now. A room can declare:
--
--     braziergate = { flag = "cradle_found", need = { "c5a", "c5b" } }
--
-- and the gate opens the moment every brazier named there is burning --
-- which is to say, the moment somebody has carried fire that far in.
-- The door is the proof of the journey rather than a receipt for one.
--
-- Gates resolve per-tile against G.run.flags every frame, so the wall
-- goes the instant the last brazier catches, with the player standing
-- there watching it.
function Cold.checkGates(World)
  local def = World and World.room and World.room.braziergate
  if not def or not (G.run and G.run.flags) then return false end
  if G.run.flags[def.flag] then return false end
  for _, id in ipairs(def.need or {}) do
    if not Cold.isLit(id) then return false end
  end
  G.run.flags[def.flag] = true
  return true
end

return Cold
