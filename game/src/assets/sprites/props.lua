-- Prop sprites + character portraits.
local out = {}

-- Save statue: a little lantern shrine
out.prop_save = {
  pal = { k = "black", s = "slate", g = "gray", e = "ember", o = "gold",
    c = "cream", d = "dark" },
  frames = { {
    "......eo......",
    ".....kcck.....",
    ".....kcek.....",
    "......kk......",
    "....kssssk....",
    "...ksggggsk...",
    "...ksgeegsk...",
    "...ksgeegsk...",
    "...ksggggsk...",
    "....kssssk....",
    ".....ksk......",
    ".....ksk......",
    "....kssgk.....",
    "...ksggssk....",
    "..ksggggssk...",
    ".kssssssssk...",
  } },
}

-- Checkpoint lantern (unlit / lit)
local lantern = function(litTop, flame)
  return {
    "....kk......",
    "...k" .. litTop .. litTop .. "k.....",
    "..k" .. flame .. flame .. flame .. flame .. "k....",
    "..k" .. flame .. flame .. flame .. flame .. "k....",
    "...kkkk.....",
    "....ss......",
    "....ss......",
    "....ss......",
    "....ss......",
    "....ss......",
    "....ss......",
    "....ss......",
    "...ssss.....",
    "..ssssss....",
    ".kssssssk...",
    ".kkkkkkkk...",
  }
end
out.prop_lantern = {
  pal = { k = "black", s = "gray", d = "shadow", e = "ember", o = "gold" },
  frames = { lantern("d", "d"), lantern("o", "e") },
}

-- Teleporter pad
out.prop_teleporter = {
  pal = { k = "black", s = "slate", g = "gray", c = "cyan", t = "teal", d = "dark" },
  frames = { {
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    ".kt......................tk.",
    "kssk....................kssk",
    "kssssssssssssssssssssssssssk",
    "ksccccccccccccccccccccccccsk",
    "kssssssssssssssssssssssssssk",
    ".kddddddddddddddddddddddddk.",
    ".kkkkkkkkkkkkkkkkkkkkkkkkkk.",
  } },
}

-- Chest (closed / open)
out.prop_chest = {
  pal = { k = "black", b = "brown", u = "umber", o = "gold", d = "dark", c = "cream" },
  frames = {
    {
      "..kkkkkkkkkk..",
      ".kbbbbbbbbbbk.",
      "kbbbbbbbbbbbbk",
      "kubbbbobbbbbuk",
      "kkkkkkokkkkkkk",
      "kubbbbobbbbbuk",
      "kubbbkookbbbuk",
      "kubbbkookbbbuk",
      "kubbbbbbbbbbuk",
      "kuubbbbbbbbuuk",
      "kkkkkkkkkkkkkk",
      "..............",
    },
    {
      "kbbbbbbbbbbbbk",
      "kbddddddddddbk",
      "kbddddddddddbk",
      "kkkkkkkkkkkkkk",
      "kubbbbbbbbbbuk",
      "kubbbkookbbbuk",
      "kubbbkookbbbuk",
      "kubbbbbbbbbbuk",
      "kubbbbbbbbbbuk",
      "kuubbbbbbbbuuk",
      "kkkkkkkkkkkkkk",
      "..............",
    },
  },
}

-- Sign
out.prop_sign = {
  pal = { k = "black", b = "brown", u = "umber", c = "cream" },
  frames = { {
    "kkkkkkkkkkkk",
    "kbbbbbbbbbbk",
    "kbccbccbccbk",
    "kbbbbbbbbbbk",
    "kbccbccbbbbk",
    "kbbbbbbbbbbk",
    "kkkkkkkkkkkk",
    "....kuu.....",
    "....kuu.....",
    "....kuu.....",
    "....kuu.....",
    "...kkuuk....",
  } },
}

-- Energize machine console (dark / lit). 'Z' = screen, 'W' = lights,
-- substituted per frame.
local machineTemplate = {
  "....kkkkkkkk....",
  "...kssssssssk...",
  "...kssZZZZssk...",
  "...ksZZZZZZsk...",
  "...ksZZZZZZsk...",
  "...kssZZZZssk...",
  "...kssssssssk...",
  "..kssggggggssk..",
  "..ksgWggggWgsk..",
  "..ksggggggggsk..",
  "..ksgWWWWWWgsk..",
  "..ksggggggggsk..",
  "..ksggggggggsk..",
  ".kssggggggggssk.",
  ".kssssssssssssk.",
  ".kkkkkkkkkkkkkk.",
  "..kgg......ggk..",
  "..kgg......ggk..",
  ".kkggk....kggkk.",
  ".kkkkk....kkkkk.",
  "................",
  "................",
  "................",
  "................",
}
local function machineFrame(screen, light)
  local rows = {}
  for i, r in ipairs(machineTemplate) do
    rows[i] = r:gsub("Z", screen):gsub("W", light)
  end
  return rows
end
out.prop_machine = {
  pal = { k = "black", s = "slate", g = "gray", d = "shadow", c = "cyan", p = "spark" },
  frames = { machineFrame("d", "d"), machineFrame("c", "p") },
}

-- ==================================================================
-- Portraits (20x20)
-- ==================================================================
out.port_vess = {
  pal = { k = "black", r = "vessred", R = "vessdark", s = "spark", e = "ember", d = "dark" },
  frames = { {
    "....kkkkkkkkkkkk....",
    "..kkrrrrrrrrrrrrkk..",
    ".krrrrrrrrrrrrrrrrk.",
    ".krrrrrrrrrrrrrrrrk.",
    "krrrrrrrrrrrrrrrrrrk",
    "krrkkkkkkkkkkkkkkrrk",
    "krksssssssssssssskrk",
    "krksskksssssskkssskk",
    "krksskksssssskkssskk",
    "krksssssssssssssskrk",
    "krrkkkkkkkkkkkkkkrrk",
    "krrrrrrrrrrrrrrrrrrk",
    "krrrRRRRRRRRRRRrrrrk",
    "krrrRkkkkkkkkkRrrrrk",
    ".krrRRRRRRRRRRRrrrk.",
    ".krrrrrrrrrrrrrrrrk.",
    "..krrrrreerrrrrrrk..",
    "..kkrrrreerrrrrkk...",
    "....kkkkkkkkkkk.....",
    "....................",
  } },
}

out.port_lu = {
  pal = { k = "black", b = "lublue", B = "ludark", s = "spark", c = "cyan", d = "dark" },
  frames = { {
    ".........cc.........",
    ".........kk.........",
    "....kkkkkkkkkkkk....",
    "..kkbbbbbbbbbbbbkk..",
    ".kbbbbbbbbbbbbbbbbk.",
    "kbbbbbbbbbbbbbbbbbbk",
    "kbbkkkkkkkkkkkkkkbbk",
    "kbksssssssssssssskbk",
    "kbkskksssssssskksskk",
    "kbkskksssssssskksskk",
    "kbksssssssssssssskbk",
    "kbbkkkkkkkkkkkkkkbbk",
    "kbbbbbbbbbbbbbbbbbbk",
    "kbbbBBBBBBBBBBBbbbbk",
    ".kbbBkkkkkkkkkBbbbk.",
    ".kbbBBBBBBBBBBBbbbk.",
    "..kbbbbccbbbbbbbk...",
    "...kkbbccbbbbkk.....",
    ".....kkkkkkkk.......",
    "....................",
  } },
}

-- Human portrait template with palette swaps
local function humanPortrait(hatRow)
  return {
    hatRow or "....hhhhhhhhhhhh....",
    "..hhhhhhhhhhhhhhhh..",
    "..hhhhhhhhhhhhhhhh..",
    ".khffffffffffffffhk.",
    ".kffffffffffffffffk.",
    ".kffffffffffffffffk.",
    ".kffeeffffffffeeffk.",
    ".kffeeffffffffeeffk.",
    ".kffffffffffffffffk.",
    ".kffffffffffffffffk.",
    ".kfffffffssfffffffk.",
    ".kffffffffffffffffk.",
    ".kfffffmmmmmmffffgk.",
    ".kffffffffffffffffk.",
    "..kffffffffffffffk..",
    "...kkffffffffffkk...",
    ".....kkkkkkkkkk.....",
    "....bbbbbbbbbbbb....",
    "...bbbbbbbbbbbbbb...",
    "....................",
  }
end

local function port(hair, skin, robe, mouth, hatRow)
  return {
    pal = { k = "black", h = hair, f = skin, e = "black", s = "gray",
      m = mouth or "rust", b = robe, g = skin },
    frames = { humanPortrait(hatRow) },
  }
end

out.port_elder = port("silver", "skin", "plum")
out.port_brassa = port("rust", "skin", "ember")
out.port_tikka = port("moss", "skin", "leaf")
out.port_jun = port("teal", "skin", "cyan")
out.port_sol = port("light", "skin", "white")
out.port_inks = port("navy", "skin", "sky")
out.port_root = port("umber", "skin", "brown")
out.port_vill = port("gray", "skin", "slate")
out.port_mender = {
  pal = { k = "black", r = "blood", d = "dark", s = "spark", c = "maroon" },
  frames = { {
    "....................",
    "..kkkkkkkkkkkkkkkk..",
    ".kddddddddddddddddk.",
    "kddddddddddddddddddk",
    "kddkkkkkkkkkkkkkkddk",
    "kdkrrrrrrrrrrrrrrkdk",
    "kdkrrkkrrrrrrkkrrkdk",
    "kdkrrkkrrrrrrkkrrkdk",
    "kdkrrrrrrrrrrrrrrkdk",
    "kddkkkkkkkkkkkkkkddk",
    "kddddddddddddddddddk",
    "kddccccccccccccccddk",
    "kddckkkkkkkkkkkkcddk",
    "kddccccccccccccccddk",
    ".kddddddddddddddddk.",
    ".kddddddddddddddddk.",
    "..kddddddrrddddddk..",
    "...kkddddrrddddkk...",
    ".....kkkkkkkkkk.....",
    "....................",
  } },
}

return out
