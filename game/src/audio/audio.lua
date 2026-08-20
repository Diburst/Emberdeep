-- Audio manager: synthesized SFX and looped music on two volume buses.
--
-- THREE THINGS THIS MODULE USED TO GET WRONG. None of them mattered while
-- every room was one screen wide. All of them matter now.
--
--   * A NEW SOURCE PER CALL. love.audio.newSource ran on every single sfx
--     invocation and the object was then dropped on the floor. At a few
--     sounds a second nobody notices; a large room with a dozen vents,
--     braziers and beams in earshot is a different proposition. Sources
--     are pooled per name and reused once they stop.
--
--   * VOLUME BAKED IN AT CREATION. setVolume was called once, when the
--     Source was made, so moving the SFX slider did nothing to anything
--     already playing -- and on a long sound, nothing audible at all. The
--     buses are now applied every frame to every live source.
--
--   * NO POSITIONAL MODEL. Every sound played at full volume, dead centre.
--     That is exactly right when the whole room fits on screen and
--     increasingly wrong as rooms stop fitting.
--
-- Coordinates are OPTIONAL and every existing call site keeps working
-- untouched: with no x, y a sound is non-diegetic and plays centred at
-- full volume, which is what a menu blip or a pickup chime wants anyway.
-- Pass x, y for something that happens at a PLACE.
local Audio = {}
G.Audio = Audio

Audio.sfxData = {}     -- name -> SoundData
Audio.musicData = {}   -- name -> SoundData (looped)
Audio.currentMusic = nil
Audio.currentMusicName = nil
Audio.fadingOut = nil
Audio.enabled = true

-- Tuning. Distances are world px, so they are directly comparable to the
-- 480x270 viewport: NEAR is a little under half a screen, FAR is close to
-- two screens, and a sound beyond FAR is not played at all rather than
-- played at zero.
Audio.NEAR = 200
Audio.FAR = 900
Audio.POOL_MAX = 6     -- sources per sound name

Audio.pool = {}        -- name -> { Source, ... }
Audio.live = {}        -- Source -> its positional gain, for bus updates

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi else return v end
end

function Audio.init()
  -- if the audio device failed (headless), disable gracefully
  local ok = pcall(function() return love.audio.getVolume() end)
  Audio.enabled = ok
end

function Audio.sfxBus()
  return (G.settings.volSfx or 1) * (G.settings.volMaster or 1)
end

function Audio.musicBus()
  return (G.settings.volMusic or 1) * (G.settings.volMaster or 1)
end

-- Hand back a free Source for this sound, allocating only when the pool
-- has nothing idle and is not yet full.
local function take(name, data)
  local p = Audio.pool[name]
  if not p then p = {}; Audio.pool[name] = p end
  for i = 1, #p do
    if not p[i]:isPlaying() then return p[i] end
  end
  if #p >= Audio.POOL_MAX then
    -- Everything is busy. Steal the oldest rather than allocate without a
    -- ceiling: a sound clipping another copy of ITSELF is a far smaller
    -- problem than a room that allocates a Source every frame.
    local s = table.remove(p, 1)
    s:stop()
    p[#p + 1] = s
    return s
  end
  local ok, src = pcall(love.audio.newSource, data, "static")
  if not ok then return nil end
  p[#p + 1] = src
  return src
end

-- x, y are optional WORLD coordinates.
function Audio.sfx(name, pitch, x, y)
  if not Audio.enabled then return end
  local data = Audio.sfxData[name]
  if not data then return end

  local gain, pan = 1, 0
  if x then
    local Cam = require "src.camera"
    local lx, ly = Cam.x + G.VW / 2, Cam.y + G.VH / 2
    local dx, dy = x - lx, (y or ly) - ly
    local d = math.sqrt(dx * dx + dy * dy)
    -- Inaudible: return BEFORE taking a source, so a far-off room full of
    -- machinery cannot exhaust the pool with sounds nobody can hear.
    if d >= Audio.FAR then return end
    gain = clamp(1 - (d - Audio.NEAR) / (Audio.FAR - Audio.NEAR), 0, 1)
    pan = clamp(dx / (G.VW * 0.5), -1, 1)
  end

  local src = take(name, data)
  if not src then return end
  -- Always set pitch, never conditionally: a pooled source still carries
  -- whatever the previous caller asked for.
  src:setPitch(pitch or 1)
  -- The synth writes MONO SoundData (newSoundData(n, RATE, 16, 1)), which
  -- is the only reason panning is possible at all -- LOVE silently ignores
  -- setPosition on a stereo source. Rolloff is zeroed because distance is
  -- modelled in `gain` above; leaving OpenAL's own attenuation on would
  -- apply it twice.
  src:setRelative(true)
  src:setRolloff(0)
  src:setPosition(pan, 0, 0)
  src:setVolume(gain * Audio.sfxBus())
  Audio.live[src] = gain
  src:play()
end

function Audio.playMusic(name)
  if not Audio.enabled then return end
  if Audio.currentMusicName == name then return end
  local data = Audio.musicData[name]
  Audio.currentMusicName = name
  if Audio.currentMusic then
    -- STOP whatever is already fading before taking its place.
    --
    -- This slot holds exactly one source and used to be overwritten
    -- without stopping, so any track change that arrived inside the 1.5s
    -- fade orphaned a LOOPING source with nothing left referencing it --
    -- it then played until the process died. Boss death alone does it:
    -- Boss:onDeath switches back to the zone track while the boss track
    -- is still fading, and a run that fights several bosses stacks one
    -- track per fight on top of the last.
    if Audio.fadingOut then Audio.fadingOut:stop() end
    Audio.fadingOut = Audio.currentMusic
    Audio.currentMusic = nil
  end
  if not data then return end
  local ok, src = pcall(love.audio.newSource, data, "static")
  if not ok then return end
  src:setLooping(true)
  src:setVolume(0)
  src:play()
  Audio.currentMusic = src
  Audio.fadeIn = 0
end

function Audio.stopMusic()
  if Audio.currentMusic then
    if Audio.fadingOut then Audio.fadingOut:stop() end
    Audio.fadingOut = Audio.currentMusic
    Audio.currentMusic = nil
    Audio.currentMusicName = nil
  end
end

function Audio.update(dt)
  if not Audio.enabled then return end

  -- SFX bus, applied to everything still sounding. This is the fix for
  -- "turning the slider down does nothing until the next sound".
  local sbus = Audio.sfxBus()
  for src, gain in pairs(Audio.live) do
    if src:isPlaying() then
      src:setVolume(gain * sbus)
    else
      Audio.live[src] = nil          -- legal to clear during pairs()
    end
  end

  local target = Audio.musicBus()
  if Audio.fadingOut then
    local v = Audio.fadingOut:getVolume() - dt * 1.5
    if v <= 0 then
      Audio.fadingOut:stop()
      Audio.fadingOut = nil
    else
      Audio.fadingOut:setVolume(v)
    end
  end
  if Audio.currentMusic then
    local v = Audio.currentMusic:getVolume()
    if v < target then
      Audio.currentMusic:setVolume(math.min(target, v + dt * 0.8))
    elseif v > target then
      Audio.currentMusic:setVolume(target)
    end
  end
end

return Audio
