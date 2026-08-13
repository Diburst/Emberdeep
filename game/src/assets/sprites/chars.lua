-- Vess (P1 gunner, red) and Lu (P2 operator, blue) — detailed second-pass
-- sprites: 3-tone shading, visor glints, richer silhouettes.
local vpal = { k = "black", r = "vessred", R = "vessdark", q = "vesslite",
  e = "ember", o = "gold", s = "spark", w = "white", g = "slate",
  d = "gray", x = "flame" }
local lpal = { k = "black", b = "lublue", B = "ludark", q = "lulite",
  c = "cyan", s = "spark", w = "white", g = "slate", d = "gray",
  x = "flame", e = "ember" }

local function rows(w, list)
  for i, r in ipairs(list) do
    assert(#r == w, "row " .. i .. " len " .. #r .. ": " .. r)
  end
  return list
end

-- ==================================================================
-- VESS 16x20 — stocky gunner. Body rows 0..14 shared, legs 15..19 vary.
-- ==================================================================
local function vessBody(antenna, visorRow, chest)
  return {
    antenna, --                                              r0 antenna
    "........k.......",                                   -- r1 stalk
    "....kkkkkkkk....",                                   -- r2 helm top
    "...kqqqqqqqqk...",                                   -- r3 crown light
    "..kqqrrrrrrrrk..",                                   -- r4
    "..krrrrrrrrrrk..",                                   -- r5
    "..kkkkkkkkkkkk..",                                   -- r6 visor top
    visorRow,                                             -- r7 visor
    "..kssssssssssk..",                                   -- r8 visor
    "..kkkkkkkkkkkk..",                                   -- r9 visor bot
    "...kqrrrrrrRk...",                                   -- r10 chin
    "..kkRRRRRRRRkk..",                                   -- r11 shoulders
    ".krrrrrrrrrrrrk.",                                   -- r12 torso
    chest,                                                -- r13 chest+gun
    ".krrrrrrrrrkggd.",                                   -- r14 gun barrel
  }
end

local VA1 = "........e......."
local VA2 = "........s......."
local VVIS1 = "..kswssssssssk.."
local VVIS2 = "..kssssswssssk.."
local VCHEST1 = ".krqeeorrrrkggd."
local VCHEST2 = ".krqeeqrrrrkggd."

local VLEG_idle = {
  "..krRRRRRRRrk...",
  "..kRRk..kRRk....",
  "..kRqk..kRqk....",
  "..kRRk..kRRk....",
  ".kkkkk..kkkkk...",
}
local VLEG_run1 = {
  "..krRRRRRRRrk...",
  ".kRRk....kRRk...",
  ".kRqk....kRqk...",
  ".kRRk....kRRk...",
  "kkkkk....kkkkk..",
}
local VLEG_run2 = {
  "..krRRRRRRRrk...",
  "...kRRkkRRk.....",
  "...kRqk.kRqk....",
  "...kRRk.kRRk....",
  "..kkkk...kkkk...",
}
local VLEG_run3 = {
  "..krRRRRRRRrk...",
  "..kRRk....kRRk..",
  "..kRqk....kRqk..",
  "..kRRk....kRRk..",
  ".kkkkk...kkkkk..",
}
local VLEG_jump = {
  "..krRRRRRRRrk...",
  "..kRRRk.kRRRk...",
  "..kRqRk.kRqRk...",
  "...kkk...kkk....",
  "................",
}
local VLEG_fall = {
  "..krRRRRRRRrk...",
  ".kRRk.....kRRk..",
  ".kRqk.....kRqk..",
  ".kkkk.....kkkk..",
  "................",
}

local function vess(antenna, visor, chest, legs)
  local out = {}
  for _, r in ipairs(vessBody(antenna, visor, chest)) do out[#out + 1] = r end
  for _, r in ipairs(legs) do out[#out + 1] = r end
  return rows(16, out)
end

-- hurt body: cracked visor
local VVIS_HURT = "..ksxxsxxsxxsk.."

-- ==================================================================
-- LU 14x19 — slim operator. Body rows 0..13, legs 14..18 vary.
-- ==================================================================
local function luBody(tip, visorRow, core)
  return {
    tip,                                                -- r0 antenna glow
    "......k.......",                                   -- r1 stalk
    ".....kkkk.....",                                   -- r2 crown
    "...kkqqqqkk...",                                   -- r3
    "..kqqbbbbbbk..",                                   -- r4
    "..kbbbbbbbbk..",                                   -- r5
    "..kkkkkkkkkk..",                                   -- r6 visor top
    visorRow,                                           -- r7 visor
    "..kkkkkkkkkk..",                                   -- r8 visor bot
    "...kqbbbbBk...",                                   -- r9 chin
    "..kkBBBBBBkk..",                                   -- r10 shoulders
    core,                                               -- r11 torso + core
    ".kbbccbbbbkgk.",                                   -- r12 core + hand
    ".kbbbbbbbbbk..",                                   -- r13
  }
end

local LA1 = "......c......."
local LA2 = "......s......."
local LVIS1 = "..kswsssssk..."
local LVIS2 = "..kssswsssk..."
local LCORE1 = ".kqbccbbbbbk.."
local LCORE2 = ".kqbssbbbbbk.."
local LVIS_HURT = "..kxsxxsxxk..."

local LLEG_idle = {
  "..kbBBBBBbk...",
  "..kBBk.kBBk...",
  "..kBqk.kBqk...",
  "..kBBk.kBBk...",
  ".kkkk...kkkk..",
}
local LLEG_run1 = {
  "..kbBBBBBbk...",
  ".kBBk...kBBk..",
  ".kBqk...kBqk..",
  ".kBBk...kBBk..",
  "kkkk.....kkkk.",
}
local LLEG_run2 = {
  "..kbBBBBBbk...",
  "...kBBkBBk....",
  "...kBqkBqk....",
  "...kBBk.kBk...",
  "..kkkk..kkk...",
}
local LLEG_run3 = {
  "..kbBBBBBbk...",
  "..kBBk..kBBk..",
  "..kBqk..kBqk..",
  "..kBBk..kBBk..",
  ".kkkk....kkkk.",
}
local LLEG_jump = {
  "..kbBBBBBbk...",
  "..kBBBkBBBk...",
  "..kBqBkBqBk...",
  "...kkk..kkk...",
  "..............",
}
local LLEG_fall = {
  "..kbBBBBBbk...",
  ".kBBk....kBBk.",
  ".kBqk....kBqk.",
  ".kkkk....kkkk.",
  "..............",
}

local function lu(tip, visor, core, legs)
  local out = {}
  for _, r in ipairs(luBody(tip, visor, core)) do out[#out + 1] = r end
  for _, r in ipairs(legs) do out[#out + 1] = r end
  return rows(14, out)
end

return {
  vess_idle = { pal = vpal, frames = {
    vess(VA1, VVIS1, VCHEST1, VLEG_idle),
    vess(VA2, VVIS2, VCHEST2, VLEG_idle),
  } },
  vess_run = { pal = vpal, frames = {
    vess(VA1, VVIS1, VCHEST1, VLEG_run1),
    vess(VA1, VVIS1, VCHEST1, VLEG_run2),
    vess(VA1, VVIS1, VCHEST1, VLEG_run3),
    vess(VA2, VVIS2, VCHEST2, VLEG_run2),
  } },
  vess_jump = { pal = vpal, frames = { vess(VA1, VVIS1, VCHEST1, VLEG_jump) } },
  vess_fall = { pal = vpal, frames = { vess(VA1, VVIS1, VCHEST1, VLEG_fall) } },
  vess_hurt = { pal = vpal, frames = { vess(VA2, VVIS_HURT, VCHEST1, VLEG_fall) } },

  lu_idle = { pal = lpal, frames = {
    lu(LA1, LVIS1, LCORE1, LLEG_idle),
    lu(LA2, LVIS2, LCORE2, LLEG_idle),
  } },
  lu_run = { pal = lpal, frames = {
    lu(LA1, LVIS1, LCORE1, LLEG_run1),
    lu(LA1, LVIS1, LCORE1, LLEG_run2),
    lu(LA1, LVIS1, LCORE1, LLEG_run3),
    lu(LA2, LVIS2, LCORE2, LLEG_run2),
  } },
  lu_jump = { pal = lpal, frames = { lu(LA1, LVIS1, LCORE1, LLEG_jump) } },
  lu_fall = { pal = lpal, frames = { lu(LA1, LVIS1, LCORE1, LLEG_fall) } },
  lu_hurt = { pal = lpal, frames = { lu(LA2, LVIS_HURT, LCORE1, LLEG_fall) } },
}
