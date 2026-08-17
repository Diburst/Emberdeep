-- Enemy sprites: Furnace, Crystal, Skyroot, Core.
local function m(half)
  return half .. half:reverse()
end

local out = {}

out.en_cinderbat = {
  pal = { k = "black", b = "maroon", o = "magma", y = "hotcore", e = "hotcore" },
  frames = {
    {
      m("k....."),
      m("kk...."),
      m("kbk.kk"),
      m("kbbkbe"),
      m(".kbbbo"),
      m("..kbbb"),
      m("...kkk"),
      m("......"),
      m("......"),
      m("......"),
    },
    {
      m("......"),
      m("......"),
      m("..k.kk"),
      m(".kbkbe"),
      m("kbbbbo"),
      m("kkkbbb"),
      m("...kkk"),
      m("......"),
      m("......"),
      m("......"),
    },
  },
}

out.en_slagblob = {
  pal = { k = "black", o = "magma", y = "hotcore", d = "maroon", e = "black" },
  frames = {
    {
      m("......."),
      m("..kkkkk"),
      m(".koyoyo"),
      m("koyeooo"),
      m("kooooyo"),
      m("kdooood"),
      m("kdddddd"),
      m(".kkkkkk"),
      m("......."),
      m("......."),
      m("......."),
      m("......."),
    },
    {
      m("......."),
      m("......."),
      m("..kkkkk"),
      m(".kyoyoo"),
      m("koeoooy"),
      m("kooyooo"),
      m("kdddddd"),
      m(".kkkkkk"),
      m("......."),
      m("......."),
      m("......."),
      m("......."),
    },
  },
}

out.en_welder = {
  pal = { k = "black", s = "slate", g = "gray", o = "ember", c = "spark", e = "blood" },
  frames = {
    {
      m("..kck."),
      m("..kkk."),
      m(".kssss"),
      m("ksgegs"),
      m("ksgggs"),
      m(".kssss"),
      m("..kkkk"),
      m(".ko.ok"),
      m("..o..o"),
      m("......"),
      m("......"),
      m("......"),
    },
    {
      m("..k.kc"),
      m("..kkk."),
      m(".kssss"),
      m("ksgegs"),
      m("ksgggs"),
      m(".kssss"),
      m("..kkkk"),
      m("..ko.o"),
      m(".o..o."),
      m("......"),
      m("......"),
      m("......"),
    },
  },
}

out.en_shieldbug = {
  pal = { k = "black", g = "gold", d = "rust", s = "cream", e = "black" },
  frames = {
    {
      m("......."),
      m("..kkkkk"),
      m(".kggggg"),
      m("kgsgsgs"),
      m("kgggggg"),
      m("kgsgsgs"),
      m(".kddddd"),
      m("..kkkkk"),
      m(".kd.kd."),
      m("......."),
    },
    {
      m("......."),
      m("..kkkkk"),
      m(".kgsgsg"),
      m("kgggggg"),
      m("kgsgsgs"),
      m("kgggggg"),
      m(".kddddd"),
      m("..kkkkk"),
      m("..kd.kd"),
      m("......."),
    },
  },
}

out.en_shardling = {
  pal = { k = "black", v = "violet", o = "orchid", s = "spark", d = "plum", e = "spark" },
  frames = {
    {
      m("...k.."),
      m("..kok."),
      m(".kovok"),
      m("kovvvo"),
      m("kvvevv"),
      m("kvvvvv"),
      m("kdvvvd"),
      m("kdvvvd"),
      m(".kdvdk"),
      m(".kdkdk"),
      m("kdk.kd"),
      m("kk...k"),
      m("......"),
      m("......"),
    },
    {
      m("...k.."),
      m("..kok."),
      m(".kovok"),
      m("kovvvo"),
      m("kvvevv"),
      m("kvvvvv"),
      m("kdvvvd"),
      m("kdvvvd"),
      m(".kdvdk"),
      m(".kdkdk"),
      m(".kd.kd"),
      m(".k...k"),
      m("......"),
      m("......"),
    },
  },
}

out.en_prismwisp = {
  pal = { k = "black", s = "spark", o = "orchid", w = "white" },
  frames = {
    {
      m("..ko."),
      m(".koso"),
      m("kosws"),
      m("kosss"),
      m(".koso"),
      m("..ko."),
      m("...k."),
      m("....."),
      m("....."),
      m("....."),
    },
    {
      m("...k."),
      m("..kos"),
      m(".kosw"),
      m("kosss"),
      m(".koss"),
      m("..kos"),
      m("...k."),
      m("....."),
      m("....."),
      m("....."),
    },
  },
}

out.en_cryoturret = {
  pal = { k = "black", v = "violet", o = "orchid", s = "spark", d = "gloom" },
  frames = {
    {
      m("...ks."),
      m("..kok."),
      m(".kvvok"),
      m("kvsvvo"),
      m("kvvvvv"),
      m(".kvvvk"),
      m("..kkk."),
      m(".kdddk"),
      m("kddddd"),
      m("kkkkkk"),
      m("......"),
      m("......"),
    },
    {
      m("...k.."),
      m("..kok."),
      m(".kvvok"),
      m("kvsvvo"),
      m("kvvvvv"),
      m(".kvvvk"),
      m("..kkk."),
      m(".kdddk"),
      m("kddddd"),
      m("kkkkkk"),
      m("......"),
      m("......"),
    },
  },
}

out.en_windray = {
  pal = { k = "black", b = "sky", i = "ice", d = "slate", e = "black" },
  frames = {
    {
      m("k......."),
      m("kk......"),
      m("kbk..kkk"),
      m("kbbkkbeb"),
      m(".kbbbbbb"),
      m("..kkbbbb"),
      m("....kkkk"),
      m("........"),
    },
    {
      m("........"),
      m("....kkkk"),
      m("..kkbbeb"),
      m("kkbbbbbb"),
      m("kbbbbbbb"),
      m("kkkkbbbb"),
      m("....kkkk"),
      m("........"),
    },
  },
}

out.en_sporeballoon = {
  pal = { k = "black", l = "leaf", p = "pink", d = "fern", o = "lime" },
  frames = {
    {
      m("..kkkk"),
      m(".kppop"),
      m("kpopop"),
      m("kppppp"),
      m("kpppop"),
      m(".kpppp"),
      m("..kkkk"),
      m("...kd."),
      m("..kd.."),
      m("..kdd."),
      m(".kdddk"),
      m("..kkk."),
      m("......"),
      m("......"),
    },
    {
      m("..kkkk"),
      m(".kpopo"),
      m("kppopp"),
      m("kppppp"),
      m("kpopop"),
      m(".kpppp"),
      m("..kkkk"),
      m("..kd.."),
      m("...kd."),
      m("..kdd."),
      m(".kdddk"),
      m("..kkk."),
      m("......"),
      m("......"),
    },
  },
}

out.en_skylancer = {
  pal = { k = "black", i = "ice", b = "sky", s = "silver", e = "black" },
  frames = {
    {
      "..............",
      "kk....kkk.....",
      "kskkkkibbkk...",
      "kssssibebbkkk.",
      "kskkkkibbbbbk.",
      "kk....kkkkkk..",
      "..............",
      "..............",
    },
    {
      "..............",
      ".k....kkk.....",
      "kskkkkibbkk...",
      "kssssibebbkkk.",
      "kskkkkibbbbbk.",
      ".k....kkkkkk..",
      "..............",
      "..............",
    },
  },
}

-- SKYSPIRE: the ion pair.
-- Stormvane -- a charging coil on a vane; the core lights as it winds up.
out.en_stormvane = {
  pal = { k = "black", s = "slate", i = "ice", b = "sky", c = "cyan", w = "white" },
  frames = {
    {
      m("...kkk"),
      m("..kssk"),
      m(".ksiik"),
      m("ksibbk"),
      m("ksibck"),
      m("ksibck"),
      m(".ksibk"),
      m("..ksik"),
      m("...kkk"),
      m("....kk"),
      m("....ks"),
      m("....ks"),
      m("....kk"),
      m("......"),
    },
    {
      m("...kkk"),
      m("..kssk"),
      m(".ksiik"),
      m("ksibck"),
      m("ksicwk"),
      m("ksicwk"),
      m(".ksibk"),
      m("..ksik"),
      m("...kkk"),
      m("....kk"),
      m("....ks"),
      m("....ks"),
      m("....kk"),
      m("......"),
    },
  },
}

-- Roostfang -- the Skyspire bat. 1-2 fly, 3 is the bite.
out.en_roostfang = {
  pal = { k = "black", b = "slate", i = "sky", e = "cyan", w = "ice" },
  frames = {
    {
      m("k....."),
      m("kk...."),
      m("kbk.kk"),
      m("kbbkbe"),
      m(".kbbbi"),
      m("..kbbb"),
      m("...kkk"),
      m("......"),
      m("......"),
      m("......"),
    },
    {
      m("......"),
      m("......"),
      m("..k.kk"),
      m(".kbkbe"),
      m("kbbbbi"),
      m("kkkbbb"),
      m("...kkk"),
      m("......"),
      m("......"),
      m("......"),
    },
    {
      m("......"),
      m("..kk.."),
      m(".kbbkk"),
      m("kbbbbe"),
      m("kbbbbi"),
      m(".kbwwb"),
      m("..kwkw"),
      m("...kwk"),
      m("......"),
      m("......"),
    },
  },
}

out.en_sentinel = {
  pal = { k = "black", s = "slate", c = "cyan", w = "spark", d = "dark", e = "blood" },
  frames = {
    {
      m("..kkkkk"),
      m(".ksssss"),
      m("kssccss"),
      m("kscwwcs"),
      m("kscwecs"):gsub("e", "w"),
      m("kscwwcs"),
      m("kssccss"),
      m(".ksssss"),
      m("..kkkkk"),
      m(".c.c.c."),
      m("......."),
      m("......."),
      m("......."),
      m("......."),
    },
    {
      m("..kkkkk"),
      m(".ksssss"),
      m("kssccss"),
      m("kscwwcs"),
      m("kscwwcs"),
      m("kscwwcs"),
      m("kssccss"),
      m(".ksssss"),
      m("..kkkkk"),
      m("..c.c.c"),
      m("......."),
      m("......."),
      m("......."),
      m("......."),
    },
  },
}

out.en_screamer = {
  pal = { k = "black", p = "pink", w = "white", d = "plum", e = "black" },
  frames = {
    {
      m("..kkkk"),
      m(".kpppp"),
      m("kppepp"),
      m("kppppp"),
      m(".kpwwp"),
      m(".kpwwp"),
      m("kppppp"),
      m(".kpppp"),
      m("..kkkk"),
      m("......"),
      m("......"),
      m("......"),
    },
    {
      m("..kkkk"),
      m(".kpppp"),
      m("kppepp"),
      m("kppppp"),
      m(".kwwwp"),
      m(".kwwwp"),
      m("kpwwpp"),
      m(".kpppp"),
      m("..kkkk"),
      m("......"),
      m("......"),
      m("......"),
    },
  },
}

out.en_eliteguard = {
  pal = { k = "black", s = "slate", d = "dark", c = "cyan", g = "gray", e = "cyan" },
  frames = {
    {
      m("..kkkkk"),
      m(".ksssss"),
      m(".ksekes"):gsub("k", "s"),
      m(".ksssss"),
      m("..kkkkk"),
      m(".kgggg g"):gsub(" ", "g"):sub(1, 14),
      m("kggcgg g"):gsub(" ", "g"):sub(1, 14),
      m("kgggggg"),
      m("kggggg g"):gsub(" ", "g"):sub(1, 14),
      m(".kgggg g"):gsub(" ", "g"):sub(1, 14),
      m("..kkkkk"),
      m(".kd.kd."),
      m(".kd.kd."),
      m(".kk.kk."),
      m("......."),
      m("......."),
    },
    {
      m("..kkkkk"),
      m(".ksssss"),
      m(".ksekes"):gsub("k", "s"),
      m(".ksssss"),
      m("..kkkkk"),
      m(".kggggg"),
      m("kggcggg"),
      m("kgggggg"),
      m("kggggg g"):gsub(" ", "g"):sub(1, 14),
      m(".kggggg"),
      m("..kkkkk"),
      m("..kd.kd"),
      m("..kd.kd"),
      m("..kk.kk"),
      m("......."),
      m("......."),
    },
  },
}

-- clean up the gsub hacks: rebuild eliteguard rows deterministically
local eg = out.en_eliteguard
for f = 1, 2 do
  eg.frames[f][6] = m(".kggggg")
  eg.frames[f][7] = m("kggcggg")
  eg.frames[f][9] = m("kgggggg")
  eg.frames[f][10] = m(".kggggg")
end

-- Undergrove ------------------------------------------------------
out.en_myceling = {
  pal = { k = "black", c = "plum", d = "violet", s = "cream", e = "spark" },
  frames = {
    {
      m("..ccc "),
      m(".ccccc"),
      m("cccddd"),
      m(".sdddd"),
      m("..ksks"),
      m(".k.k.k"),
    },
    {
      m("..ccc "),
      m(".ccccc"),
      m("cccddd"),
      m(".sdddd"),
      m("..sksk"),
      m("k.k.k."),
    },
  },
}

out.en_glowmite = {
  pal = { k = "black", g = "spark", w = "ice", c = "cyan" },
  frames = {
    { m(".w.."), m("wgc."), m("gccg"), m(".gg.") },
    { m("..w."), m(".gcw"), m("gccg"), m(".gg.") },
  },
}

out.en_sporefly = {
  pal = { k = "black", v = "violet", o = "orchid", w = "ice" },
  frames = {
    { m(".w..."), m("ww.o."), m(".ovvo"), m("..vv."), m("...v.") },
    { m("....."), m(".w.o."), m("wwovv"), m("..vv."), m("...v.") },
  },
}

out.en_slagling = {
  pal = { k = "black", o = "magma", y = "hotcore", d = "maroon" },
  frames = {
    {
      m("...."),
      m(".oo."),
      m("oyyo"),
      m("odyo"),
      m("kook"),
    },
    {
      m(".oo."),
      m("oyyo"),
      m("oyyo"),
      m("odok"),
      m("k..k"),
    },
  },
}

-- Coldstore: frozen archive vaults
out.en_frostwisp = {
  pal = { k = "black", i = "ice", w = "white", s = "sky" },
  frames = {
    {
      m("..i..."),
      m(".iwi.."),
      m("iwswi."),
      m("iwwsi."),
      m(".iwi.i"),
      m("..i..."),
      m(".i...."),
      m("......"),
    },
    {
      m("......"),
      m("..i..."),
      m(".iwi.i"),
      m("iwswi."),
      m("iwwsi."),
      m(".iwi.."),
      m("..i..i"),
      m("......"),
    },
  },
}

out.en_shelverbot = {
  pal = { k = "black", s = "slate", g = "gray", i = "ice", b = "brown", e = "cyan" },
  frames = {
    {
      m(".sssss."),
      m("sggggs."),
      m("sgeges."),
      m("sggggs."),
      m("sbbbbs."),
      m("sbbbbs."),
      m(".sggs.."),
      m(".k..k.."),
      m(".k..k.."),
      m("kk..kk."),
    },
    {
      m(".sssss."),
      m("sggggs."),
      m("sgeges."),
      m("sggggs."),
      m("sbbbbs."),
      m("sbbbbs."),
      m(".sggs.."),
      m("..kk..."),
      m(".k..k.."),
      m("kk..kk."),
    },
  },
}

out.en_icemaw = {
  pal = { k = "black", i = "ice", w = "white", t = "silver" },
  frames = {
    {
      m("......."),
      m("..ii..."),
      m(".iwwi.."),
      m("iwtwti."),
      m("iwwwwi."),
      m("kiiiik."),
      m(".kkkk.."),
    },
    {
      m("..ii..."),
      m(".iwwi.."),
      m("iwtwti."),
      m("iwtwti."),
      m("iwwwwi."),
      m("kiiiik."),
      m(".kkkk.."),
    },
  },
}

-- ------------------------------------------------------------------
-- THE SCRAPYARD
-- ------------------------------------------------------------------
out.en_scraphusk = {
  pal = { k = "black", g = "gray", d = "slate", s = "shadow", r = "blood",
    w = "silver" },
  frames = {
    {
      "..............",
      "....kkkkkk....",
      "...kdssssdk...",
      "...ksskrsdk...",
      "..kkdssssdkk..",
      ".kdddsssssdk..",
      "kwkddddddsdk..",
      "kkkkddddddkk..",
      "...kk...kk....",
      "..............",
    },
    {
      "..............",
      "..............",
      "....kkkkkk....",
      "...kdssssdk...",
      "...kssrksdk...",
      "..kkdssssdkk..",
      "kwkdddsssssdk.",
      "kkkkdddddddkk.",
      "....kk..kk....",
      "..............",
    },
  },
}

out.en_plateframe = {
  pal = { k = "black", g = "gray", d = "slate", s = "shadow", r = "blood",
    w = "silver", e = "maroon" },
  frames = {
    {
      "....kkkkkk....",
      "...kdddddddk..",
      "...ksssssssk..",
      "...kkkkkkkkk..",
      "...kskrrksdk..",
      "...kkkkkkkkk..",
      "..kkeeeeeekk..",
      "..kdssssssdkw.",
      "..kdsssssssdw.",
      "..kdssssssdkw.",
      "..kddssssddk..",
      "...kdddddddk..",
      "...kddkkkddk..",
      "...kdk...kdk..",
      "...kdk...kdk..",
      "..kkdkk.kkdkk.",
      "..kkkkk.kkkkk.",
    },
    {
      "....kkkkkk....",
      "...kdddddddk..",
      "...ksssssssk..",
      "...kkkkkkkkk..",
      "...kskrrksdk..",
      "...kkkkkkkkk..",
      "..kkeeeeeekk..",
      "..kdssssssdkw.",
      "..kdssssssdkw.",
      "..kdsssssssdw.",
      "..kddssssddk..",
      "...kdddddddk..",
      "...kddkkkddk..",
      "...kdk...kdk..",
      "...kdk...kdk..",
      "..kkdkk.kkdkk.",
      "..kkkkk.kkkkk.",
    },
  },
}

out.en_rammer = {
  pal = { k = "black", g = "gray", d = "slate", s = "shadow", r = "blood",
    e = "vessdark", w = "silver" },
  frames = {
    {
      "...kkkkkk.....",
      "..kddddddk....",
      "..ksssssdk....",
      "..kkkkkkkk....",
      "..kskrrsdk....",
      "..kkkkkkkk....",
      ".kkeeeeeekk...",
      ".kdsssssssdk..",
      ".kdssssssssdw.",
      ".kdsssssssdkw.",
      ".kddsssssddk..",
      "..kdddddddk...",
      "..kddk.kddk...",
      "..kdsk.kdsk...",
      ".kkddkkkddkk..",
      ".kkkkk.kkkkk..",
    },
    {
      "...kkkkkk.....",
      "..kddddddk....",
      "..ksssssdk....",
      "..kkkkkkkk....",
      "..kskrrsdk....",
      "..kkkkkkkk....",
      ".kkeeeeeekk...",
      ".kdsssssssdk..",
      ".kdssssssssdw.",
      ".kdsssssssdkw.",
      ".kddsssssddk..",
      "..kdddddddk...",
      "..kddk.kddk...",
      "..kddk.kdsk...",
      ".kkdskkkddkk..",
      ".kkkkk.kkkkk..",
    },
  },
}

return out
