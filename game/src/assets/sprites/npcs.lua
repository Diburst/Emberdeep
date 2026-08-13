-- NPC body sprites (12x16, 2 frames: eyes open / closed) built from a
-- shared template with per-character palettes.
local function body(eyesOpen, hatRows)
  local face = eyesOpen and "..kfeffefk.." or "..kffffffk.."
  local rows = {}
  local hat = hatRows or { "...hhhhhh...", "..hhhhhhhh.." }
  for _, r in ipairs(hat) do rows[#rows + 1] = r end
  local rest = {
    "..kffffffk..",
    face,
    "..kffffffk..",
    "...kffffk...",
    "..bbbbbbbb..",
    ".bbbbbbbbbb.",
    ".bbsbbbbsbb.",
    ".bbbbbbbbbb.",
    ".bbbbbbbbbb.",
    "..bbbbbbbb..",
    "..bbb..bbb..",
    "..bbb..bbb..",
    "..kkk..kkk..",
    "............",
  }
  for _, r in ipairs(rest) do rows[#rows + 1] = r end
  return rows
end

local function npc(hair, robe, sec, hatRows)
  return {
    pal = { k = "black", h = hair, f = "skin", e = "black", b = robe, s = sec },
    frames = { body(true, hatRows), body(false, hatRows) },
  }
end

return {
  npc_elder = npc("silver", "plum", "violet",
    { "..hhhhhhhh..", "..hhhhhhhh.." }),
  npc_brassa = npc("rust", "ember", "gold",
    { "...ssssss...", "..hhhhhhhh.." }),
  npc_tikka = npc("moss", "leaf", "lime"),
  npc_ferro = npc("rust", "brown", "gold",
    { "...hhhhhh...", "..hhhhhhhh.." }),
  npc_mote = npc("spark", "sky", "cyan"),
  npc_jun = npc("teal", "cyan", "spark"),
  npc_sol = npc("light", "white", "silver"),
  npc_inks = npc("navy", "sky", "ice"),
  npc_root = npc("umber", "brown", "gold",
    { "..ssssssss..", "...hhhhhh..." }),
  npc_vill = npc("gray", "slate", "silver"),
  npc_vill2 = npc("umber", "teal", "ice"),
  npc_lock = npc("silver", "navy", "ice",
    { "...ssssss...", "..shhhhhhs.." }),
}
