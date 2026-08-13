-- Audio manager: plays synthesized SFX and looped music with volume control.
local Audio = {}
G.Audio = Audio

Audio.sfxData = {}     -- name -> SoundData
Audio.musicData = {}   -- name -> SoundData (looped)
Audio.currentMusic = nil
Audio.currentMusicName = nil
Audio.fadingOut = nil
Audio.enabled = true

function Audio.init()
  -- if the audio device failed (headless), disable gracefully
  local ok = pcall(function() return love.audio.getVolume() end)
  Audio.enabled = ok
end

function Audio.sfx(name, pitch)
  if not Audio.enabled then return end
  local data = Audio.sfxData[name]
  if not data then return end
  local ok, src = pcall(love.audio.newSource, data)
  if not ok then return end
  src:setVolume(G.settings.volSfx * G.settings.volMaster)
  if pitch then src:setPitch(pitch) end
  src:play()
end

function Audio.playMusic(name)
  if not Audio.enabled then return end
  if Audio.currentMusicName == name then return end
  local data = Audio.musicData[name]
  Audio.currentMusicName = name
  if Audio.currentMusic then
    Audio.fadingOut = Audio.currentMusic
    Audio.currentMusic = nil
  end
  if not data then return end
  local ok, src = pcall(love.audio.newSource, data)
  if not ok then return end
  src:setLooping(true)
  src:setVolume(0)
  src:play()
  Audio.currentMusic = src
  Audio.fadeIn = 0
end

function Audio.stopMusic()
  if Audio.currentMusic then
    Audio.fadingOut = Audio.currentMusic
    Audio.currentMusic = nil
    Audio.currentMusicName = nil
  end
end

function Audio.update(dt)
  if not Audio.enabled then return end
  local target = G.settings.volMusic * G.settings.volMaster
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
