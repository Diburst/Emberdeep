-- Chiptune tracker: pattern data rendered to looping SoundData at load.
-- Channels: lead/harm (square), bass (triangle), drums (noise kit).
-- Pattern = 16 tokens (16th notes). "--" rest, "==" sustain.
local Music = {}
local RATE = 22050

-- note parsing -------------------------------------------------------
local SEMI = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
local function nfreq(tok)
  local letter, sharp, oct = tok:match("^([A-G])(#?)(%d)$")
  if not letter then return nil end
  local s = SEMI[letter] + (sharp == "#" and 1 or 0)
  local midi = 12 * (tonumber(oct) + 1) + s
  return 440 * 2 ^ ((midi - 69) / 12)
end

local function tokens(str)
  local out = {}
  for tok in str:gmatch("%S+") do out[#out + 1] = tok end
  return out
end

-- synth --------------------------------------------------------------
local function sq(ph, duty) return (ph % 1) < duty and 1 or -1 end
local function tri(ph)
  local p = ph % 1
  return p < 0.5 and (p * 4 - 1) or (3 - p * 4)
end

local nseed = 7
local function noise()
  nseed = (nseed * 1103515245 + 12345) % 2147483648
  return (nseed / 2147483648) * 2 - 1
end

-- ==================================================================
-- Song data
-- ==================================================================
local SONGS = {}

SONGS.title = {
  bpm = 92, echo = 0.32,
  lead = { duty = 0.25, vol = 0.20, order = { 1, 1, 2, 3 }, patterns = {
    "A4 -- -- -- C5 -- -- -- E5 -- -- -- C5 -- -- --",
    "B4 -- -- -- E5 -- -- -- D5 -- -- -- B4 -- -- --",
    "A4 -- -- -- E4 -- -- -- A4 -- == == -- -- -- --",
  } },
  harm = { duty = 0.5, vol = 0.10, order = { 1, 2, 1, 2 }, patterns = {
    "E3 == == == == == == == C3 == == == == == == ==",
    "D3 == == == == == == == E3 == == == == == == ==",
  } },
  bass = { vol = 0.30, order = { 1, 2, 1, 3 }, patterns = {
    "A2 -- -- -- -- -- -- -- A2 -- -- -- -- -- -- --",
    "F2 -- -- -- -- -- -- -- G2 -- -- -- -- -- -- --",
    "A2 -- -- -- -- -- -- -- E2 -- -- -- -- -- -- --",
  } },
}

SONGS.camp = {
  bpm = 100, echo = 0.2,
  lead = { duty = 0.25, vol = 0.20, order = { 1, 2, 1, 3 }, patterns = {
    "E4 -- G4 -- C5 -- == == B4 -- G4 -- A4 -- == ==",
    "A4 -- G4 -- E4 -- == == D4 -- E4 -- G4 -- == ==",
    "E4 -- D4 -- C4 -- == == == == -- -- G4 -- E4 --",
  } },
  harm = { duty = 0.5, vol = 0.09, order = { 1, 2, 1, 2 }, patterns = {
    "C4 == == == == == == == G3 == == == == == == ==",
    "A3 == == == == == == == F3 == == == == == == ==",
  } },
  bass = { vol = 0.32, order = { 1, 2, 1, 2 }, patterns = {
    "C2 -- -- C2 -- -- C2 -- G2 -- -- G2 -- -- G2 --",
    "A2 -- -- A2 -- -- A2 -- F2 -- -- F2 -- -- F2 --",
  } },
  drums = { vol = 0.20, order = { 1, 1, 1, 1 }, patterns = {
    "k- -- h- -- s- -- h- -- k- -- h- -- s- -- h- h-",
  } },
}

SONGS.mosswood = {
  bpm = 122, echo = 0.22,
  lead = { duty = 0.25, vol = 0.20, order = { 1, 2, 1, 3, 1, 2, 4, 4 }, patterns = {
    "D4 -- F4 -- G4 -- A4 -- -- -- A4 -- G4 -- F4 --",
    "D4 -- F4 -- G4 -- C5 -- -- -- A4 -- == == -- --",
    "F4 -- G4 -- A4 -- C5 -- D5 -- C5 -- A4 -- G4 --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  harm = { duty = 0.5, vol = 0.10, order = { 4, 4, 4, 4, 1, 2, 1, 3 }, patterns = {
    "D4 -- F4 -- G4 -- A4 -- -- -- A4 -- G4 -- F4 --",
    "D4 -- F4 -- G4 -- C5 -- -- -- A4 -- == == -- --",
    "F4 -- G4 -- A4 -- C5 -- D5 -- C5 -- A4 -- G4 --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  bass = { vol = 0.33, order = { 1, 1, 2, 1, 1, 1, 2, 3 }, patterns = {
    "D2 -- D3 -- D2 -- D3 -- D2 -- D3 -- C3 -- D3 --",
    "A2 -- A3 -- A2 -- A3 -- G2 -- G3 -- G2 -- A2 --",
    "F2 -- F3 -- F2 -- F3 -- G2 -- G3 -- A2 -- A3 --",
  } },
  drums = { vol = 0.22, order = { 1, 1, 1, 2 }, patterns = {
    "k- -- h- -- s- -- h- k- k- -- h- -- s- -- h- --",
    "k- -- h- -- s- -- k- k- s- -- h- h- s- s- h- --",
  } },
}

SONGS.flooded = {
  bpm = 86, echo = 0.4,
  lead = { duty = 0.25, vol = 0.17, order = { 1, 2, 1, 3 }, patterns = {
    "E4 -- G4 -- B4 -- G4 -- E4 -- G4 -- B4 -- D5 --",
    "C4 -- E4 -- G4 -- E4 -- D4 -- F#4 -- A4 -- F#4 --",
    "B3 -- D4 -- G4 -- D4 -- E4 -- == == == == -- --",
  } },
  harm = { duty = 0.5, vol = 0.08, order = { 1, 2, 1, 3 }, patterns = {
    "B3 == == == == == == == E3 == == == == == == ==",
    "G3 == == == == == == == A3 == == == == == == ==",
    "G3 == == == == == == == E3 == == == == == == ==",
  } },
  bass = { vol = 0.3, order = { 1, 2, 1, 3 }, patterns = {
    "E2 -- -- -- -- -- B2 -- E2 -- -- -- -- -- -- --",
    "C2 -- -- -- -- -- G2 -- D2 -- -- -- -- -- A2 --",
    "G2 -- -- -- -- -- D2 -- E2 -- -- -- -- -- -- --",
  } },
  drums = { vol = 0.13, order = { 1, 1, 1, 1 }, patterns = {
    "k- -- -- -- h- -- -- -- s- -- -- -- h- -- h- --",
  } },
}

SONGS.furnace = {
  bpm = 142, echo = 0.15,
  lead = { duty = 0.25, vol = 0.20, order = { 5, 5, 1, 2, 1, 3, 4, 4 }, patterns = {
    "C4 -- -- C4 D#4 -- C4 -- G4 -- F4 -- D#4 -- D4 --",
    "C4 -- -- C4 D#4 -- C4 -- G#4 -- G4 -- F4 -- D#4 --",
    "C5 -- A#4 -- G#4 -- G4 -- F4 -- D#4 -- D4 -- C4 --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
    "C4 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  harm = { duty = 0.5, vol = 0.1, order = { 4, 4, 4, 4, 4, 4, 1, 1 }, patterns = {
    "C3 -- -- C3 D#3 -- C3 -- G3 -- F3 -- D#3 -- D3 --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  bass = { vol = 0.36, order = { 1, 1, 1, 2, 1, 1, 1, 2 }, patterns = {
    "C2 C2 C3 C2 C2 C3 C2 C3 C2 C2 C3 C2 A#1 A#2 A#1 A#2",
    "G#1 G#1 G#2 G#1 G#1 G#2 G#1 G#2 G1 G1 G2 G1 G1 G2 G1 G2",
  } },
  drums = { vol = 0.26, order = { 1, 1, 1, 2 }, patterns = {
    "k- -- h- k- s- -- h- k- k- k- h- -- s- -- h- h-",
    "k- -- h- k- s- -- k- k- s- -- s- -- s- s- s- s-",
  } },
}

SONGS.crystal = {
  bpm = 128, echo = 0.38,
  lead = { duty = 0.25, vol = 0.16, order = { 1, 2, 1, 3 }, patterns = {
    "A4 -- E5 -- C5 -- E5 -- A4 -- E5 -- C5 -- E5 --",
    "G4 -- D5 -- B4 -- D5 -- G4 -- D5 -- B4 -- D5 --",
    "F4 -- C5 -- A4 -- C5 -- E4 -- B4 -- G#4 -- B4 --",
  } },
  harm = { duty = 0.25, vol = 0.1, order = { 1, 2, 1, 3 }, patterns = {
    "-- -- A5 -- -- -- E5 -- -- -- C6 -- -- -- E5 --",
    "-- -- G5 -- -- -- D5 -- -- -- B5 -- -- -- D5 --",
    "-- -- F5 -- -- -- C5 -- -- -- E5 -- -- -- B4 --",
  } },
  bass = { vol = 0.3, order = { 1, 2, 1, 3 }, patterns = {
    "A2 -- -- -- -- -- -- -- E2 -- -- -- -- -- -- --",
    "G2 -- -- -- -- -- -- -- D2 -- -- -- -- -- -- --",
    "F2 -- -- -- -- -- -- -- E2 -- -- -- -- -- -- --",
  } },
  drums = { vol = 0.12, order = { 1, 1, 1, 1 }, patterns = {
    "-- -- h- -- -- -- h- -- -- -- h- -- -- -- h- h-",
  } },
}

SONGS.skyroot = {
  bpm = 104, echo = 0.3,
  lead = { duty = 0.25, vol = 0.19, order = { 1, 2, 1, 3 }, patterns = {
    "G4 -- B4 -- D5 -- == == E5 -- D5 -- B4 -- G4 --",
    "A4 -- C5 -- E5 -- == == D5 -- C5 -- A4 -- E4 --",
    "G4 -- B4 -- D5 -- G5 -- == == D5 -- B4 -- == ==",
  } },
  harm = { duty = 0.5, vol = 0.09, order = { 1, 2, 1, 3 }, patterns = {
    "D4 == == == == == == == E4 == == == == == == ==",
    "E4 == == == == == == == C4 == == == == == == ==",
    "D4 == == == == == == == G4 == == == == == == ==",
  } },
  bass = { vol = 0.3, order = { 1, 2, 1, 2 }, patterns = {
    "G2 -- -- G2 -- -- D2 -- E2 -- -- E2 -- -- B2 --",
    "A2 -- -- A2 -- -- E2 -- C2 -- -- C2 -- -- G2 --",
  } },
  drums = { vol = 0.15, order = { 1, 1, 1, 1 }, patterns = {
    "k- -- -- h- -- -- s- -- -- h- -- k- s- -- h- --",
  } },
}

SONGS.core = {
  bpm = 132, echo = 0.22,
  lead = { duty = 0.25, vol = 0.18, order = { 4, 1, 4, 2, 4, 1, 4, 3 }, patterns = {
    "C5 -- B4 -- C5 -- -- -- F#4 -- -- -- G4 -- -- --",
    "D#5 -- D5 -- D#5 -- -- -- C5 -- -- -- B4 -- -- --",
    "G4 -- F#4 -- G4 -- G#4 -- A4 -- -- -- -- -- -- --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  harm = { duty = 0.5, vol = 0.11, order = { 1, 1, 1, 1, 1, 1, 1, 1 }, patterns = {
    "C4 -- -- C4 -- -- C4 -- F#3 -- -- F#3 -- -- G3 --",
  } },
  bass = { vol = 0.35, order = { 1, 1, 1, 1, 1, 1, 1, 2 }, patterns = {
    "C2 -- C2 -- C2 -- C2 -- F#1 -- F#1 -- G1 -- G1 --",
    "C2 -- C2 -- D#2 -- D#2 -- F#2 -- F#2 -- G2 -- G#2 --",
  } },
  drums = { vol = 0.22, order = { 1, 1, 1, 2 }, patterns = {
    "k- -- h- -- s- -- h- -- k- -- h- -- s- -- h- --",
    "k- k- h- -- s- -- k- -- s- -- s- s- s- -- h- --",
  } },
}

SONGS.undergrove = {
  bpm = 92, echo = 0.34,
  lead = { duty = 0.25, vol = 0.14, order = { 1, 4, 2, 4, 1, 4, 3, 4 }, patterns = {
    "D4 -- -- -- F4 -- -- -- E4 -- -- -- -- -- -- --",
    "A3 -- -- -- D4 -- -- -- C4 -- -- -- A3 -- -- --",
    "F4 -- -- -- E4 -- -- -- D4 -- -- -- -- -- C4 --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  harm = { duty = 0.5, vol = 0.07, order = { 1, 1, 2, 2, 1, 1, 2, 2 }, patterns = {
    "D3 -- -- -- -- -- -- -- A2 -- -- -- -- -- -- --",
    "F3 -- -- -- -- -- -- -- E3 -- -- -- -- -- -- --",
  } },
  bass = { vol = 0.30, order = { 1, 1, 1, 2 }, patterns = {
    "D2 -- -- -- -- -- D2 -- -- -- D2 -- -- -- -- --",
    "A1 -- -- -- -- -- A1 -- -- -- C2 -- -- -- -- --",
  } },
  drums = { vol = 0.12, order = { 1, 1, 1, 2 }, patterns = {
    "k- -- -- -- h- -- -- -- -- -- -- -- h- -- -- --",
    "k- -- -- -- h- -- -- -- k- -- -- -- s- -- -- --",
  } },
}

SONGS.coldstore = {
  bpm = 84, echo = 0.42,
  lead = { duty = 0.25, vol = 0.12, order = { 1, 2, 1, 3, 4, 4, 1, 3 }, patterns = {
    "E4 -- -- -- -- -- B3 -- -- -- -- -- G4 -- -- --",
    "F#4 -- -- -- -- -- E4 -- -- -- B3 -- -- -- -- --",
    "G4 -- -- -- F#4 -- -- -- E4 -- -- -- -- -- -- --",
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
  harm = { duty = 0.5, vol = 0.06, order = { 1, 1, 2, 2 }, patterns = {
    "E3 -- -- -- -- -- -- -- B2 -- -- -- -- -- -- --",
    "G3 -- -- -- -- -- -- -- F#3 -- -- -- -- -- -- --",
  } },
  bass = { vol = 0.26, order = { 1, 1, 2, 1 }, patterns = {
    "E2 -- -- -- -- -- -- -- -- -- E2 -- -- -- -- --",
    "G1 -- -- -- -- -- -- -- -- -- B1 -- -- -- -- --",
  } },
  drums = { vol = 0.08, order = { 1, 1, 1, 2 }, patterns = {
    "h- -- -- -- -- -- -- -- h- -- -- -- -- -- -- --",
    "h- -- -- -- k- -- -- -- h- -- -- -- -- -- -- --",
  } },
}

SONGS.cradle = {
  bpm = 66, echo = 0.5,
  lead = { duty = 0.125, vol = 0.11, order = { 1, 2, 1, 3 }, patterns = {
    "C5 -- -- -- G4 -- -- -- E4 -- -- -- G4 -- -- --",
    "A4 -- -- -- E4 -- -- -- C4 -- -- -- E4 -- -- --",
    "F4 -- -- -- G4 -- -- -- C5 -- -- -- -- -- -- --",
  } },
  harm = { duty = 0.25, vol = 0.05, order = { 1, 1, 2, 1 }, patterns = {
    "C3 -- -- -- -- -- -- -- G2 -- -- -- -- -- -- --",
    "F3 -- -- -- -- -- -- -- G3 -- -- -- -- -- -- --",
  } },
  bass = { vol = 0.2, order = { 1, 1, 2, 1 }, patterns = {
    "C2 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
    "F1 -- -- -- -- -- -- -- G1 -- -- -- -- -- -- --",
  } },
  drums = { vol = 0.0, order = { 1 }, patterns = {
    "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
  } },
}

SONGS.boss = {
  bpm = 160, echo = 0.18,
  lead = { duty = 0.25, vol = 0.21, order = { 1, 1, 2, 3 }, patterns = {
    "A4 -- A4 -- C5 -- A4 -- E5 -- D5 -- C5 -- B4 --",
    "A4 -- A4 -- C5 -- A4 -- F5 -- E5 -- D5 -- C5 --",
    "E5 -- -- -- D5 -- -- -- C5 -- B4 -- A4 -- G#4 --",
  } },
  harm = { duty = 0.5, vol = 0.12, order = { 1, 1, 1, 2 }, patterns = {
    "A3 -- -- A3 -- -- A3 -- A3 -- -- A3 -- -- G3 --",
    "F3 -- -- F3 -- -- E3 -- E3 -- -- E3 -- -- E3 --",
  } },
  bass = { vol = 0.36, order = { 1, 1, 2, 2 }, patterns = {
    "A1 A2 A1 A2 A1 A2 A1 A2 A1 A2 A1 A2 G1 G2 G1 G2",
    "F1 F2 F1 F2 F1 F2 F1 F2 E1 E2 E1 E2 E1 E2 E1 E2",
  } },
  drums = { vol = 0.26, order = { 1, 1, 1, 2 }, patterns = {
    "k- -- s- -- k- k- s- -- k- -- s- -- k- k- s- h-",
    "k- -- s- -- k- k- s- -- s- s- s- s- k- k- k- k-",
  } },
}

SONGS.finalboss = {
  bpm = 168, echo = 0.2,
  lead = { duty = 0.25, vol = 0.21, order = { 1, 2, 1, 3, 4, 4, 1, 3 }, patterns = {
    "D5 -- -- D5 C5 -- D5 -- F5 -- E5 -- D5 -- C5 --",
    "D5 -- -- D5 C5 -- D5 -- G5 -- F5 -- E5 -- D5 --",
    "A5 -- G5 -- F5 -- E5 -- D5 -- C#5 -- D5 -- == ==",
    "D5 -- A#4 -- A4 -- G4 -- F4 -- E4 -- D4 -- -- --",
  } },
  harm = { duty = 0.25, vol = 0.12, order = { 1, 1, 1, 1, 2, 2, 1, 1 }, patterns = {
    "D4 -- -- D4 -- -- D4 -- A#3 -- -- A#3 -- -- A3 --",
    "D4 -- D4 -- F4 -- F4 -- G4 -- G4 -- A4 -- A4 --",
  } },
  bass = { vol = 0.37, order = { 1, 1, 1, 2, 1, 1, 1, 2 }, patterns = {
    "D2 D2 D3 D2 D2 D3 D2 D3 A#1 A#1 A#2 A#1 A1 A1 A2 A1",
    "G1 G1 G2 G1 G#1 G#1 G#2 G#1 A1 A1 A2 A1 A1 A2 A1 A2",
  } },
  drums = { vol = 0.27, order = { 1, 1, 1, 2 }, patterns = {
    "k- -- s- -- k- k- s- -- k- -- s- -- k- k- s- s-",
    "k- k- s- s- k- k- s- s- s- s- s- s- s- s- s- s-",
  } },
}

SONGS.victory = {
  bpm = 120, echo = 0.25,
  lead = { duty = 0.25, vol = 0.22, order = { 1, 2 }, patterns = {
    "C5 -- C5 -- C5 -- E5 -- G5 -- == == E5 -- G5 --",
    "A5 -- G5 -- E5 -- C5 -- D5 -- == == C5 -- == ==",
  } },
  harm = { duty = 0.5, vol = 0.11, order = { 1, 2 }, patterns = {
    "E4 == == == == == == == C4 == == == == == == ==",
    "F4 == == == == == == == E4 == == == == == == ==",
  } },
  bass = { vol = 0.32, order = { 1, 2 }, patterns = {
    "C2 -- -- C2 -- -- G2 -- C2 -- -- C2 -- -- G2 --",
    "F2 -- -- F2 -- -- G2 -- C2 -- -- C2 -- -- C2 --",
  } },
  drums = { vol = 0.18, order = { 1, 1 }, patterns = {
    "k- -- h- -- s- -- h- -- k- -- h- -- s- -- s- s-",
  } },
}

SONGS.gameover = {
  bpm = 70, echo = 0.3,
  lead = { duty = 0.25, vol = 0.18, order = { 1 }, patterns = {
    "A4 -- -- -- G4 -- -- -- F4 -- -- -- E4 == == ==",
  } },
  bass = { vol = 0.28, order = { 1 }, patterns = {
    "A2 -- -- -- -- -- -- -- F2 -- -- -- E2 -- -- --",
  } },
}

-- ==================================================================
-- Renderer
-- ==================================================================
function Music.songList()
  local names = {}
  for name in pairs(SONGS) do names[#names + 1] = name end
  table.sort(names)
  return names
end

local function channelEvents(ch, totalRows)
  -- returns list {row0, row1, freq}
  local evs = {}
  local cur = nil
  local row = 0
  for _, pi in ipairs(ch.order) do
    local toks = tokens(ch.patterns[pi])
    for i = 1, 16 do
      local tok = toks[i] or "--"
      if tok == "==" then
        if cur then cur.row1 = row + 1 end
      elseif tok == "--" then
        cur = nil
      else
        local f = nfreq(tok)
        if f then
          cur = { row0 = row, row1 = row + 1, freq = f }
          evs[#evs + 1] = cur
        end
      end
      row = row + 1
    end
  end
  return evs
end

local function drumEvents(ch)
  local evs = {}
  local row = 0
  for _, pi in ipairs(ch.order) do
    local toks = tokens(ch.patterns[pi])
    for i = 1, 16 do
      local tok = toks[i] or "--"
      local t = tok:sub(1, 1)
      if t == "k" or t == "s" or t == "h" then
        evs[#evs + 1] = { row = row, type = t }
      end
      row = row + 1
    end
  end
  return evs
end

function Music.render(name)
  local Audio = require "src.audio.audio"
  if Audio.musicData[name] then return end
  local song = SONGS[name]
  if not song then return end

  local spr = math.floor(RATE * 60 / song.bpm / 4) -- samples per row
  local totalRows = 0
  for _, chName in ipairs({ "lead", "harm", "bass", "drums" }) do
    local ch = song[chName]
    if ch then totalRows = math.max(totalRows, #ch.order * 16) end
  end
  local n = totalRows * spr
  local buf = {}
  for i = 0, n - 1 do buf[i] = 0 end

  -- tonal channels
  for _, chName in ipairs({ "lead", "harm", "bass" }) do
    local ch = song[chName]
    if ch then
      local evs = channelEvents(ch, totalRows)
      local isBass = chName == "bass"
      for _, ev in ipairs(evs) do
        local s0 = ev.row0 * spr
        local s1 = math.min(n, ev.row1 * spr)
        local len = s1 - s0
        local ph = 0
        for i = 0, len - 1 do
          local t = i / RATE
          -- vibrato on held notes
          local f = ev.freq
          if t > 0.15 and not isBass then
            f = f * (1 + math.sin(t * 5.5 * math.pi * 2) * 0.006)
          end
          ph = ph + f / RATE
          local a = 1
          local atk = 0.004
          if t < atk then a = t / atk end
          local rel = (len - i) / RATE
          if rel < 0.012 then a = a * rel / 0.012 end
          -- gentle decay over the note
          a = a * (1 - 0.3 * math.min(1, t / 0.6))
          local s
          if isBass then s = tri(ph) else s = sq(ph, ch.duty or 0.5) end
          local idx = s0 + i
          buf[idx] = buf[idx] + s * a * ch.vol
        end
      end
    end
  end

  -- drums
  if song.drums then
    local ch = song.drums
    for _, ev in ipairs(drumEvents(ch)) do
      local s0 = ev.row * spr
      if ev.type == "k" then
        local ph = 0
        for i = 0, math.min(n - s0, math.floor(0.09 * RATE)) - 1 do
          local t = i / RATE
          ph = ph + (120 - t * 800) / RATE
          local a = 1 - t / 0.09
          buf[s0 + i] = buf[s0 + i] + tri(ph) * a * ch.vol * 1.4
        end
      elseif ev.type == "s" then
        local last = 0
        for i = 0, math.min(n - s0, math.floor(0.1 * RATE)) - 1 do
          local t = i / RATE
          local nz = noise()
          last = last + (nz - last) * 0.5
          local a = 1 - t / 0.1
          buf[s0 + i] = buf[s0 + i] + last * a * ch.vol
        end
      elseif ev.type == "h" then
        for i = 0, math.min(n - s0, math.floor(0.03 * RATE)) - 1 do
          local t = i / RATE
          local a = 1 - t / 0.03
          buf[s0 + i] = buf[s0 + i] + noise() * a * ch.vol * 0.5
        end
      end
    end
  end

  -- echo (wraps around the loop for seamlessness)
  local echoAmt = song.echo or 0.25
  local delay = spr * 3
  if echoAmt > 0 then
    local out = {}
    for i = 0, n - 1 do
      local src = buf[(i - delay) % n]
      out[i] = buf[i] + src * echoAmt
    end
    buf = out
  end

  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  for i = 0, n - 1 do
    local s = buf[i]
    -- soft clip
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    sd:setSample(i, s * 0.85)
  end
  Audio.musicData[name] = sd
end

return Music
