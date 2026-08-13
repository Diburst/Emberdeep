-- Procedural SFX synthesizer. Everything rendered at load into SoundData.
local SFX = {}
local RATE = 22050

-- helpers ------------------------------------------------------------
local function env(t, a, d)
  if t < a then return t / a end
  local x = 1 - (t - a) / d
  return x > 0 and x or 0
end

local sq = function(ph, duty)
  return (ph % 1) < (duty or 0.5) and 1 or -1
end
local tri = function(ph)
  local p = ph % 1
  return p < 0.5 and (p * 4 - 1) or (3 - p * 4)
end
local sin = function(ph) return math.sin(ph * math.pi * 2) end

local nseed = 1
local function noise()
  nseed = (nseed * 1103515245 + 12345) % 2147483648
  return (nseed / 2147483648) * 2 - 1
end

local function render(dur, fn)
  local n = math.floor(dur * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local ph = 0
  for i = 0, n - 1 do
    local t = i / RATE
    local s = fn(t, dur)
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    sd:setSample(i, s)
  end
  return sd
end

-- generic recipes ----------------------------------------------------
local function blip(f1, f2, dur, duty, vol)
  local ph = 0
  return render(dur, function(t, d)
    local f = f1 + (f2 - f1) * (t / d)
    ph = ph + f / RATE
    return sq(ph, duty) * env(t, 0.005, d) * (vol or 0.5)
  end)
end

local function sweepTri(f1, f2, dur, vol)
  local ph = 0
  return render(dur, function(t, d)
    local f = f1 + (f2 - f1) * (t / d)
    ph = ph + f / RATE
    return tri(ph) * env(t, 0.005, d) * (vol or 0.5)
  end)
end

local function noiseBurst(dur, vol, lp)
  local last = 0
  return render(dur, function(t, d)
    local n = noise()
    last = last + (n - last) * (lp or 1)
    return last * env(t, 0.002, d) * (vol or 0.5)
  end)
end

local function chirpArp(freqs, stepDur, duty, vol)
  local ph = 0
  local total = stepDur * #freqs
  return render(total, function(t)
    local i = math.min(#freqs, math.floor(t / stepDur) + 1)
    ph = ph + freqs[i] / RATE
    local lt = t - (i - 1) * stepDur
    return sq(ph, duty) * env(lt, 0.004, stepDur) * (vol or 0.45)
  end)
end

-- build all -----------------------------------------------------------
function SFX.buildAll()
  local Audio = require "src.audio.audio"
  Audio.init()
  local S = Audio.sfxData

  S.jump = blip(280, 520, 0.14, 0.5, 0.35)
  S.land = noiseBurst(0.08, 0.3, 0.25)
  S.shoot1 = blip(900, 300, 0.09, 0.25, 0.35)          -- bolt driver
  S.shoot2 = (function()                               -- scatter: noise+low blip
    local ph = 0
    return render(0.14, function(t, d)
      ph = ph + (400 - t * 1800) / RATE
      return (sq(ph, 0.3) * 0.5 + noise() * 0.5) * env(t, 0.003, d) * 0.4
    end)
  end)()
  S.shoot3 = (function()                               -- arc lance release
    local ph, ph2 = 0, 0
    return render(0.25, function(t, d)
      ph = ph + (1400 - t * 3000) / RATE
      ph2 = ph2 + 220 / RATE
      return (sq(ph, 0.5) * 0.5 + tri(ph2) * 0.4) * env(t, 0.004, d) * 0.5
    end)
  end)()
  S.shoot4 = blip(1200, 700, 0.06, 0.25, 0.25)         -- spark shot
  S.hitenemy = noiseBurst(0.06, 0.35, 0.5)
  S.hurt = (function()
    local ph = 0
    return render(0.3, function(t, d)
      ph = ph + (220 - t * 350) / RATE
      return (sq(ph, 0.5) * 0.6 + noise() * 0.3) * env(t, 0.004, d) * 0.55
    end)
  end)()
  S.enemydie = (function()
    local ph = 0
    return render(0.35, function(t, d)
      ph = ph + (500 - t * 1100) / RATE
      return (sq(ph, 0.4) * 0.4 + noise() * 0.5) * env(t, 0.003, d) * 0.5
    end)
  end)()
  S.shard = blip(1100, 1500, 0.06, 0.5, 0.2)
  S.bigshard = chirpArp({ 900, 1200, 1600 }, 0.05, 0.5, 0.3)
  S.heart = chirpArp({ 600, 900 }, 0.07, 0.5, 0.35)
  S.scrap = blip(500, 700, 0.08, 0.3, 0.3)
  S.capsule = chirpArp({ 523, 659, 784, 1047, 1319 }, 0.09, 0.5, 0.45)
  S.levelup = chirpArp({ 784, 988, 1175 }, 0.06, 0.25, 0.4)
  S.wswap = blip(400, 650, 0.07, 0.25, 0.3)
  S.dash = (function()
    local last = 0
    return render(0.16, function(t, d)
      local n = noise()
      last = last + (n - last) * 0.15
      return last * env(t, 0.01, d) * 0.45
    end)
  end)()
  S.grapple = blip(300, 900, 0.12, 0.25, 0.35)
  S.domeon = sweepTri(300, 700, 0.18, 0.4)
  S.domeoff = sweepTri(700, 250, 0.15, 0.35)
  S.domehit = blip(800, 500, 0.07, 0.5, 0.3)
  S.repair = chirpArp({ 700, 900, 1100, 900 }, 0.06, 0.5, 0.35)
  S.deny = blip(220, 180, 0.12, 0.5, 0.35)
  S.door = sweepTri(200, 90, 0.2, 0.4)
  S.save = chirpArp({ 659, 784, 988, 1319 }, 0.08, 0.5, 0.4)
  S.checkpoint = chirpArp({ 523, 784 }, 0.09, 0.5, 0.35)
  S.revive = chirpArp({ 440, 554, 659, 880 }, 0.08, 0.5, 0.45)
  S.down = (function()
    local ph = 0
    return render(0.5, function(t, d)
      ph = ph + (330 - t * 400) / RATE
      return sq(ph, 0.5) * env(t, 0.01, d) * 0.5
    end)
  end)()
  S.respawn = chirpArp({ 330, 440, 554, 659 }, 0.08, 0.5, 0.4)
  S.linkcharge = (function()
    local ph = 0
    return render(0.85, function(t, d)
      ph = ph + (200 + t * 900) / RATE
      return sq(ph, 0.5) * (0.25 + t * 0.3) * env(t, 0.05, d)
    end)
  end)()
  S.linkshot = (function()
    local ph = 0
    return render(0.6, function(t, d)
      ph = ph + (1600 - t * 2200) / RATE
      return (sq(ph, 0.5) * 0.5 + noise() * 0.45) * env(t, 0.004, d) * 0.6
    end)
  end)()
  S.swap = blip(600, 900, 0.08, 0.25, 0.3)
  S.warp = sweepTri(900, 300, 0.2, 0.4)
  S.join = chirpArp({ 523, 659, 784 }, 0.07, 0.5, 0.4)
  S.splash = noiseBurst(0.25, 0.35, 0.12)
  -- Tide Engine tidal surge: a long rising inhale, then the wall lands.
  S.surgecharge = (function()
    local ph, ph2, last = 0, 0, 0
    return render(1.9, function(t, d)
      local k = t / d
      ph = ph + (70 + k * k * 620) / RATE            -- whine climbing
      ph2 = ph2 + (44 + math.sin(t * 5) * 6) / RATE  -- pump rumble
      last = last + (noise() - last) * 0.05          -- water dragged in
      local e = (t < 0.1) and (t / 0.1)
        or (t > d - 0.07 and math.max(0, (d - t) / 0.07) or 1)
      return (tri(ph) * 0.34 * k + sq(ph2, 0.5) * 0.2 + last * (0.25 + k * 0.55))
        * e * 0.8
    end)
  end)()
  S.surgeblast = (function()
    local ph, last, body = 0, 0, 0
    return render(1.1, function(t, d)
      ph = ph + (300 - t * 230) / RATE               -- collapsing pitch
      last = last + (noise() - last) * 0.35          -- broadband crash
      body = body + (last - body) * 0.07             -- low, heavy body
      local e = (t < 0.012) and (t / 0.012)
        or math.max(0, 1 - (t - 0.012) / (d - 0.012))
      return (last * 0.4 + body * 1.3 + tri(ph) * 0.3) * e * 0.9
    end)
  end)()
  S.crack = noiseBurst(0.1, 0.3, 0.6)
  S.crumble = noiseBurst(0.3, 0.4, 0.3)
  S.break_ = noiseBurst(0.2, 0.45, 0.5)
  S["break"] = S.break_
  S.talk = blip(700, 750, 0.03, 0.3, 0.18)
  S.menumove = blip(500, 550, 0.04, 0.5, 0.2)
  S.menusel = chirpArp({ 600, 900 }, 0.05, 0.5, 0.3)
  S.menuback = blip(500, 350, 0.07, 0.5, 0.25)
  S.roar = (function()
    local ph = 0
    return render(0.7, function(t, d)
      ph = ph + (90 + math.sin(t * 30) * 25) / RATE
      return (sq(ph, 0.5) * 0.5 + noise() * 0.4) * env(t, 0.03, d) * 0.6
    end)
  end)()
  S.explode = (function()
    local last = 0
    return render(0.6, function(t, d)
      local n = noise()
      last = last + (n - last) * 0.2
      return last * env(t, 0.005, d) * 0.7
    end)
  end)()
  S.quake = noiseBurst(0.8, 0.4, 0.06)
  S.teleport = chirpArp({ 800, 600, 900, 700, 1000 }, 0.05, 0.25, 0.35)
  S.chest = chirpArp({ 440, 554, 659, 880, 1109 }, 0.07, 0.5, 0.4)
  S.energize = (function()
    local ph = 0
    return render(0.5, function(t, d)
      ph = ph + (150 + t * 700) / RATE
      return tri(ph) * env(t, 0.03, d) * 0.5
    end)
  end)()
  S.switch = blip(350, 500, 0.09, 0.5, 0.35)
  S.bosswarn = (function()
    local ph = 0
    return render(0.8, function(t, d)
      local f = (math.floor(t * 4) % 2 == 0) and 440 or 330
      ph = ph + f / RATE
      return sq(ph, 0.5) * env(t, 0.01, d) * 0.4
    end)
  end)()
end

return SFX
