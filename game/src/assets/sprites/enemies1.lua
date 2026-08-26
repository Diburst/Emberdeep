-- Enemy sprites: Mosswood + Flooded Works.
-- m(half) mirrors a left half into a symmetric full row.
local function m(half)
  return half .. half:reverse()
end

local out = {}

out.en_gnat = {
  pal = { k = "black", g = "leaf", w = "ice", e = "blood" },
  frames = {
    {
      m(".w..."), -- wings up
      m(".ww.."),
      m("..kkk"),
      m(".kgeg"),
      m(".kggg"),
      m("..kkk"),
      m("...k."),
      m("....."),
    },
    {
      m("....."),
      m(".w..."),
      m(".wkkk"),
      m(".kgeg"),
      m(".kggg"),
      m("..kkk"),
      m("...k."),
      m("....."),
    },
  },
}

out.en_hopper = {
  pal = { k = "black", l = "leaf", d = "fern", e = "black", w = "white" },
  frames = {
    {
      m("......"),
      m("..kkkk"),
      m(".kllll"),
      m("klwkll"),
      m("klllll"),
      m("kldlll"),
      m("klddll"),
      m(".kkkkk"),
      m("..k.kk"),
      m("......"),
    },
    {
      m("......"),
      m("......"),
      m("..kkkk"),
      m(".klwkl"),
      m("klllll"),
      m("kldlll"),
      m("kllddl"),
      m(".kkkkk"),
      m(".k..kk"),
      m("......"),
    },
  },
}

out.en_spitter = {
  pal = { k = "black", l = "leaf", f = "fern", p = "pink", d = "soil", o = "gold" },
  frames = {
    {
      m("..kpp."),
      m(".kppop"),
      m("kpoppp"),
      m("kppppp"),
      m(".kppkk"),
      m("..kfk."),
      m("..kfk."),
      m(".kffk."),
      m("..kfk."),
      m("..kfk."),
      m(".kfffk"),
      m("kfffff"),
      m("kddddd"),
      m(".kkkkk"),
    },
    {
      m(".kpp.."),
      m("kppop."),
      m("kpoppp"),
      m("kppppp"),
      m(".kppkk"),
      m("..kfk."),
      m(".kffk."),
      m("..kfk."),
      m("..kfk."),
      m(".kffk."),
      m(".kfffk"),
      m("kfffff"),
      m("kddddd"),
      m(".kkkkk"),
    },
  },
}

out.en_rollpede = {
  pal = { k = "black", g = "moss", d = "pine", s = "silver", e = "blood" },
  frames = {
    {
      m("......."),
      m("..kkkkk"),
      m(".kggggg"),
      m("kgsggsg"),
      m("kgggggg"),
      m("kgsggsg"),
      m(".kggggg"),
      m("..kkkkk"),
      m(".k..k.."),
      m("......."),
    },
    {
      m("......."),
      m("..kkkkk"),
      m(".kgsggs"),
      m("kgggggg"),
      m("kgsggsg"),
      m("kgggggg"),
      m(".kgsggs"),
      m("..kkkkk"),
      m("..k..k."),
      m("......."),
    },
  },
}

out.en_finfish = {
  pal = { k = "black", b = "sky", d = "deepsea", w = "white", e = "black" },
  frames = {
    {
      "..............",
      "......kkkk....",
      "..k..kbbbbk...",
      ".kbkkbbwebbk..",
      "kbbbbbbbbbbbk.",
      ".kbkkbbbbbk...",
      "..k..kkkkk....",
      "..............",
    },
    {
      "..............",
      "......kkkk....",
      ".....kbbbbk...",
      "..kkkbbwebbk..",
      ".kbbbbbbbbbbk.",
      "..kkkbbbbbk...",
      ".....kkkkk....",
      "..............",
    },
  },
}

out.en_bubbler = {
  pal = { k = "black", j = "sky", i = "ice", d = "deepsea", e = "black" },
  frames = {
    {
      m("..kkkk"),
      m(".kiiii"),
      m("kiijji"),
      m("kijjjj"),
      m("kijejj"),
      m("kijjjj"),
      m(".kijjj"),
      m("..kkkk"),
      m(".j..j."),
      m("..j..j"),
      m(".j..j."),
      m("......"),
    },
    {
      m("..kkkk"),
      m(".kiiii"),
      m("kiijji"),
      m("kijejj"),
      m("kijjjj"),
      m("kijjjj"),
      m(".kijjj"),
      m("..kkkk"),
      m("..j..j"),
      m(".j..j."),
      m("..j..j"),
      m("......"),
    },
  },
}

out.en_crab = {
  pal = { k = "black", r = "rust", o = "ember", s = "silver", e = "black", w = "white" },
  frames = {
    {
      m("kk......"),
      m("kok....."),
      m(".kok.kkk"),
      m("..kkroor"),
      m(".krrrrrr"),
      m("krrwerrr"),
      m("krrrrrrr"),
      m(".krrrrrr"),
      m("..kkkkkk"),
      m(".kr.kr.."),
      m("kr...kr."),
      m("........"),
    },
    {
      m("kk......"),
      m(".kok...."),
      m("..kok.kk"),
      m("..kkroor"),
      m(".krrrrrr"),
      m("krrwerrr"),
      m("krrrrrrr"),
      m(".krrrrrr"),
      m("..kkkkkk"),
      m("..kr.kr."),
      m(".kr...kr"),
      m("........"),
    },
  },
}

out.en_depthmine = {
  pal = { k = "black", s = "gray", d = "shadow", r = "blood", o = "ember" },
  frames = {
    {
      m("...k.."),
      m("..ksk."),
      m(".kssss"),
      m("kssrss"),
      m("ksssss"),
      m("kssrss"),
      m(".kssss"),
      m("..ksk."),
      m("...k.."),
      m("......"),
      m("......"),
      m("......"),
    },
    {
      m("...k.."),
      m("..ksk."),
      m(".kssss"),
      m("kssoss"),
      m("ksssss"),
      m("kssoss"),
      m(".kssss"),
      m("..ksk."),
      m("...k.."),
      m("......"),
      m("......"),
      m("......"),
    },
  },
}

out.en_spineshell = {
  -- The shell is the enemy: navy plate, water-blue dome, ice spines, and
  -- a pale belly that is drawn because it is the answer. Everything but
  -- that strip of `l` stops a round (enemies.lua, shellBlocked).
  pal = { k = "black", b = "navy", w = "deepsea", s = "water",
          i = "ice", l = "vesslite", r = "rust" },
  frames = {
    {
      "......k.k.k.....",
      ".....kikikik....",
      "....kkkkkkkkkk..",
      "...kbbbbbbbbbbk.",
      "..kbwwwwwwwwwwbk",
      "..kbwswswswswbkr",
      ".kbbwwwwwwwwwbkr",
      ".kbbbbbbbbbbbbk.",
      "..kkkkkkkkkkkk..",
      "..klllllllllk...",
      "..kk......kk....",
      ".kk........kk...",
      "................",
    },
    {
      "......k.k.k.....",
      ".....kikikik....",
      "....kkkkkkkkkk..",
      "...kbbbbbbbbbbk.",
      "..kbwwwwwwwwwwbk",
      "..kbwswswswswbkr",
      ".kbbwwwwwwwwwbkr",
      ".kbbbbbbbbbbbbk.",
      "..kkkkkkkkkkkk..",
      "..klllllllllk...",
      "...kk......kk...",
      "..kk........kk..",
      "................",
    },
  },
}

return out
