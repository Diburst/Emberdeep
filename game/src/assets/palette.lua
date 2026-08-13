-- The Emberdeep palette. Curated ~40 colors, Cave Story-adjacent:
-- deep cool darks, warm lantern accents, zone-tinted mid tones.
local function hex(h)
  local r = tonumber(h:sub(1, 2), 16) / 255
  local g = tonumber(h:sub(3, 4), 16) / 255
  local b = tonumber(h:sub(5, 6), 16) / 255
  return { r, g, b, 1 }
end

local P = {
  -- neutrals
  black    = hex "0d0b14",
  dark     = hex "1a1826",
  shadow   = hex "2b2838",
  gray     = hex "4e4a5e",
  slate    = hex "6e6a80",
  silver   = hex "a5a2b8",
  light    = hex "d6d4e0",
  white    = hex "f4f2f8",
  -- warm / lantern
  ember    = hex "ff9a3c",
  flame    = hex "ff6427",
  rust     = hex "b8471f",
  maroon   = hex "6e2318",
  gold     = hex "ffd23e",
  cream    = hex "ffedb5",
  brown    = hex "8a5a2e",
  umber    = hex "5c3a20",
  soil     = hex "3a2818",
  -- greens (Mosswood)
  moss     = hex "5cb84a",
  leaf     = hex "8ede56",
  fern     = hex "2f7a38",
  pine     = hex "1c4a2c",
  lime     = hex "cfff70",
  -- blues (Flooded Works)
  sky      = hex "6ec8f0",
  water    = hex "3a7ad4",
  deepsea  = hex "24448c",
  navy     = hex "162a54",
  ice      = hex "bfeef8",
  -- reds / furnace
  blood    = hex "d42b2b",
  magma    = hex "ff4514",
  hotcore  = hex "ffd214",
  -- purples / crystal
  violet   = hex "9b5de5",
  orchid   = hex "c77dff",
  plum     = hex "5a2e8a",
  gloom    = hex "34205c",
  pink     = hex "ff7eb6",
  -- cyans / tech
  cyan     = hex "3ce8d4",
  teal     = hex "1f9e9e",
  spark    = hex "9cf8ff",
  -- character tones
  vessred  = hex "e04848",
  vessdark = hex "8c2430",
  vesslite = hex "ff8c7a",
  lublue   = hex "58a8f0",
  ludark   = hex "2c5aa8",
  lulite   = hex "9ed6ff",
  skin     = hex "f0c8a0",
}

-- Zone tint accents used by tile generator and map screen.
P.zoneAccent = {
  camp    = P.ember,
  mosswood = P.moss,
  flooded = P.water,
  furnace = P.magma,
  crystal = P.violet,
  skyroot = P.sky,
  core    = P.cyan,
}

return P
