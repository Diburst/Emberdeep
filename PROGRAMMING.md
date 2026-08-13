# EMBERDEEP — Programmer's Guide

How the code is organized, how to change it safely, and how to prove you
didn't break anything. Companions: `game/BUILDING.md` (quick reference),
`TESTING.md` (the full QA stack), `NARRATIVE-PLAN.md` (story canon),
`EXPANSION-PLAN.md` (roadmap). Everything below assumes you are in
`emberdeep/game/` unless a path says otherwise.

---

## 1. The big picture

Emberdeep is plain Lua on **LÖVE 11.5**. There is no compile step and no
external asset: every sprite, tile, song, and sound effect is *generated
from source at load time*. The renderer draws to a **480×270 virtual
canvas**, integer-scaled to the window. Simulation runs on a **fixed 60Hz
timestep** (`main.lua` owns the accumulator). Physics is **tile AABB** on a
16px grid — deliberately static tiles only, because the entire validation
stack (Section 7) is built on that contract. Do not add moving solid
terrain.

Global state lives on `G`:

| field | what it is |
|---|---|
| `G.run` | the current playthrough: flags, scrap, forge tiers, checkpoint, log, pendingDrops, bossCorpses. **Everything in it is saved verbatim** (`src/save.lua`, atomic writes, `Save.migrate` for old schemas). |
| `G.run.flags` | THE progression mechanism. One flat table of booleans: `boss_crucible`, `heatplating`, `quest_tikka_done`, `cradle_truth`... Doors, gates, dialogue, NPC spawns, and endings all key off it. |
| `G.game` | the in-game state instance (`src/states/game.lua`) while playing; `nil` in menus. `G.game:announce(text)` is the toast line; `G.game:startDialogue(script)` opens the textbox. |
| `G.State` | the state stack (`src/core/state.lua`). `switch` replaces, `push`/`pop` overlay (pause, forge, map, log). |
| `G.settings` | options + input bindings (saved separately from runs). |
| `G.Audio`, `G.Input`, `G.Save` | the singletons. |

The rendering flow for a frame: `World:draw()` = background gradient →
parallax silhouettes → **arena backdrop** (boss rooms, `drawArenaBackdrop`)
→ `Cam.apply()` → tiles → decor → entities by layer → particles → mended
warmth / frozen-camp overlays → darkness overlay (dark rooms) →
`Cam.unapply()` → HUD/textbox on top.

## 2. File roles

    game/main.lua              bootstrap: canvas, fixed timestep, input wiring,
                               G.drawSprite / G.fmtButtons / G.btn helpers
    game/conf.lua              window + save-directory identity
    game/src/core/             class.lua (OO), util.lua (clamp/approach/rand),
                               ser.lua (save serializer), state.lua (stack),
                               invariants.lua (per-frame assertions in tests),
                               progress.lua (in-game completability solver, F1)
    game/src/physics.lua       AABB move/collide; sets onGround/hitWall/inWater
    game/src/world.lua         room parsing, tile queries, entity lifecycle,
                               doors/gates, arrival placement, drawing, darkness,
                               arena backdrops, persistent drops/corpses respawn
    game/src/camera.lua        co-op midpoint camera, lookahead, shake
    game/src/input.lua         2 players, pad + keyboard, live rebinding
    game/src/save.lua          settings + 3 slots + schema migration
    game/src/items.lua         Items.grant("module:X" | "weapon:Y" | "scrap:N"),
                               MODULES name/desc table (pickup announcements)
    game/src/weapons.lua       weapon defs + forge tier table
    game/src/entities/         entity.lua (registry), player.lua (both bots),
                               enemies.lua (all regular enemies), bosses.lua
                               (all bosses + spawn/liveness law + corpse lore),
                               props.lua (signs, chests, plates, teleporters,
                               lanterns, the Seat, reward drops, corpses...),
                               projectile.lua, pickup.lua, npc.lua
    game/src/states/           title, saveselect, intro, game, pause, log,
                               mapscreen, teleport, forge, options, controls,
                               progress (F1), testchamber, ending, coldending
    game/src/ui/               menu.lua, hud.lua, textbox.lua (dialogue + log
                               recorder + NAMES/PORT_COLOR)
    game/src/audio/            sfx.lua (synthesized), music.lua (tracker songs
                               as note strings), audio.lua (front-end)
    game/src/assets/           palette.lua (named colors), font.lua,
                               spritegen.lua (ASCII→atlas compiler),
                               sprites/*.lua (the art), tilegen.lua (per-zone
                               tiles + parallax backgrounds)
    game/src/data/rooms/*.lua  one file per room (ASCII map + key + links)
    game/src/data/dialogue.lua every line of text in the game, flag-gated
    game/src/data/worldmap.lua room registry, minimap layout, telepads
    game/src/data/progress_graph.lua   GENERATED — never hand-edit
    game/src/test_scenarios.lua        the headless test suite
    scripts/                   Python dev tools: genrooms/gen_coldstore
                               (room generators), fixrooms, checkrooms,
                               checkdoors, genprogress, checkprogress,
                               roommodel (the shared movement model)

## 3. Adding assets

### 3.1 A sprite

Sprites are ASCII pixel art compiled at load by `spritegen.lua`. Each entry:
`pal` maps single characters to palette color names (`src/assets/palette.lua`),
`frames` is a list of frames, each a list of equal-width row strings; `.` is
transparent. Add entries to the right file under `src/assets/sprites/`
(`enemies1/2`, `props`, `npcs`, `bosses`, `chars`) — all are auto-loaded.

```lua
-- in src/assets/sprites/enemies2.lua
out.en_dripper = {
  pal = { k = "black", s = "sky", w = "white" },
  frames = {
    { ".ss.",
      "swws",
      ".ss.",
      "..s." },
    { ".ss.",
      "swws",
      ".ss.",
      ".s.." },
  },
}
```

Draw it anywhere with `G.drawSprite("en_dripper", frame, cx, bottomY, opts)`
— `opts` supports `flip`, `sx/sy` (scale), `tint = {r,g,b,a}`, `white`
(hit-flash). **Rules learned the hard way:** every row in a frame must be
the same width (generate programmatically with asserts if the sprite is
big — see the generator note at the top of `sprites/bosses.lua`), and the
`m(half)` mirror helper is ONLY for genuine half-designs; mirroring a
complete drawing produces a two-headed monster.

### 3.2 A sound effect or song

SFX are synthesized in `src/audio/sfx.lua` — copy an existing def (they are
envelope + waveform recipes) and give it a name; play with
`G.Audio.sfx("name")`. Songs live in `src/audio/music.lua` as `SONGS.<id>`
tracker tables: four channels (`lead`, `harm`, `bass`, `drums`), each with
patterns of 16 note tokens (`"C4"`, `"F#3"`, `"--"`; drums use `k-`/`s-`/`h-`)
and an `order` list. Reference the song id from a room def (`music = "<id>"`)
or `G.Audio.playMusic("<id>")`.

### 3.3 A zone palette

`src/assets/tilegen.lua` `ZONES` table: base/dark/accent/cap colors plus
background gradient names. Add a zone entry and every room with
`zone = "<id>"` gets generated tiles and parallax art.

## 4. Modifying behaviors (where the dials are)

- **Player feel:** `src/entities/player.lua` `BASE` table (runSpeed, accel,
  jumpVel, gravity, friction...). If you touch ANY of these, run the
  `calibrate` scenario and update `scripts/roommodel.py` constants to the
  measured values — the validators must model the real engine.
- **Weapons:** `src/weapons.lua` defs — `dmg`/`rate`/`pierce` per tier.
  Special fire paths (`radial`, `mortar`, charge) live in the fire section
  of `player.lua`.
- **Link shot:** recharge rate + damage in `src/states/game.lua`
  (`linkMeter` recharge, `fireLinkShot`).
- **Enemy stats:** each `reg("name", {hp=, touchDmg=, ...})` def in
  `enemies.lua`. Difficulty multipliers: HP in `enemies.lua`/`bosses.lua`
  init, damage taken in `player.lua takeDamage`.
- **Boss fights:** each boss is a small state machine in `bosses.lua`
  (`self.state` / `self.stateT`, `setState`). Damage-window law belongs in
  the boss's `hurt()` override (see the Crucible or the Archivist).
- **Economy:** forge costs at the top of `src/states/forge.lua`; drops per
  enemy in their `drops` table; boss drops via `reward = "module:x"`.

## 5. Adding an enemy (worked example)

One entry in `enemies.lua` + one sprite. The `reg` helper wires the class,
registry, HP scaling, and drops:

```lua
-- src/entities/enemies.lua (in the zone section of your choice)
reg("dripper", { hp = 3, touchDmg = 2, sprite = "en_dripper", w = 10, h = 10,
  drops = { shards = 2 }, deathColor = "sky", animRate = 6 },
  function(self, dt)
    -- hangs from the ceiling; drops on approach, then hops home
    self.vy = math.min((self.vy or 0) + 830 * dt, 300)
    local p = playerNear(self, 60)
    if p and not self.falling then self.falling = true end
    if not self.falling then self.vy = 0 end   -- cling until triggered
    PH.move(self, 0, self.vy * dt)
  end)
```

Update callbacks get `self` (an Entity: `x,y,w,h,vx,vy,facing,onGround,
hitWall`) and use `PH.move` for collision, `playerNear(self, range)` for
aggro, `Proj.spawn(World, x, y, cfg)` for shots (cfg: `dmg`, `vx/vy`,
`gravity`, `chill`, `life`...). Spawn it in a room by adding a key entry
(`["d"] = "dripper"`) and placing `d` on the map. Behavior conventions:
nothing should idle motionless when a player is visible (v4.1 feedback),
and velocity formulas must be **bounded** — put oscillation terms inside
the `U.approach` target, never added outside it (the depthmine leaky-
integrator lesson).

## 6. Adding a room (worked example)

A room is a Lua table: metadata, an ASCII `map`, a `key` mapping spawn
characters to entity specs, and `links` pairing doors.

```lua
-- src/data/rooms/moss_nook.lua
return {
  zone = "mosswood", music = "mosswood",
  mapPos = { x = 12, y = 1, w = 1, h = 1 },   -- minimap cell (zone-local)
  map = [[
##############################
##############################
##..........................##
##...........g..............##
##.......====......====.....##
##..........................##
##..1................3......##
AA..........................##
AA..........................##
##############################
##############################
]],
  key = {
    ["1"] = "sign:sign_nook",
    ["3"] = "chest:ch_nook:scrap:20",
    ["g"] = "gnat",
  },
  links = {
    A = { "moss_2", "B" },   -- and moss_2's links must name us back
  },
}
```

**Tile characters** (global, everything else is a spawn char): `#` solid,
`.` air, `=` one-way, `~` water, `L` lava, `%` breakable, `c` crumble,
`^v<>` spikes, `A`–`F` doors, `G`–`J` gates (`gates = { G = "someflag" }`;
`"!flag"` = energy bridge, solid only while powered). **Never reuse a tile
character as a spawn char** — a linkcore once parsed as lava.

Door geometry: side doors are 2×2 blocks on the left/right edge (right
edges pair with left edges), top/bottom doors are 3-wide (or 2-wide)
blocks in the wall rows. Register the room in `worldmap.lua` `WM.ROOMS`,
and add the reverse link in the neighbor.

**Authoring rules that the validators WILL enforce:**

- Gate columns must run floor-to-ceiling *inclusive of the standing row*,
  or an enclosed pocket — anything else is flagged as hoppable/bypassable.
- Climb routes: a jump reaches 3 rows (Vess) / 4 (Lu spark); zigzag rungs
  must alternate columns **≤5 apart** or the bottom becomes a trap.
- Never put a one-way rung on the row directly under a top door's tiles.
- Generate big rooms programmatically with width asserts (see
  `scripts/gen_coldstore.py` for the pattern) — hand-counted rows always
  drift, and `fixrooms.py`'s padding can create liquid leaks.
- Every reward should sit at the end of *its own* detour, not on the
  walk-through path; plates/buttons belong off the golden path.

## 7. Validation — run this after EVERY change

The suite is the product. From `game/`:

```sh
python3 ../scripts/fixrooms.py                          # after hand map edits
python3 ../scripts/checkrooms.py                        # traps, liquids, door↔door
python3 ../scripts/checkdoors.py                        # 1:1 mutual door topology
PYTHONPATH=../scripts python3 ../scripts/genprogress.py # regen progress_graph.lua
PYTHONPATH=../scripts python3 ../scripts/checkprogress.py  # completability proof
```

All three checkers must print **0 issues**. `checkprogress` proves, from a
fresh save, that the ending and every item are obtainable and no gate can
be bypassed — if you add a flag source (chest, plate, boss reward, NPC
gift), teach `scripts/genprogress.py` about it (`BOSS_REWARDS`,
`NPC_GIVES`, `target_gives`) or the proof fails.

Then the engine scenarios (see `TESTING.md` for the full table and the
one-liner that runs all of them):

```sh
rm -rf ~/.local/share/love/emberdeep         # clean save dir between runs
EMBERDEEP_TEST=sweep xvfb-run -a love .      # exit 0 = pass
```

Minimum after a map edit: `sweep shaftdoors rungprobe doorjump progress`.
After enemy/boss work: `bossflow bossspawn bossdrops`. After player
physics: `calibrate` (then update roommodel). Add a scenario for every new
mechanic — `test_scenarios.lua` is full of copyable patterns. Scenario
gotchas: `error()` on failure (log lines alone don't fail the run), give
the paused world ~15 frames to flush spawns after dialogue, and never
navigate menus by hardcoded index if you can avoid it (the pause menu
grew a row once and broke a scenario).

The in-game **Test Chamber** (title menu) fights any boss in any arena
with any loadout, and **F1** in-game shows the live completability panel.

## 8. Building the executables

Always start from a clean `.love` (it is just a zip with `main.lua` at the
root) and smoke-test THAT exact artifact before packaging:

```sh
cd game
zip -9 -r emberdeep.love main.lua conf.lua src
mkdir /tmp/smoke && cd /tmp/smoke && unzip -q /path/to/emberdeep.love
EMBERDEEP_TEST=links xvfb-run -a love .      # must exit 0
```

**Windows** (with the LÖVE 11.5 win64 release unzipped):

```sh
cat love.exe emberdeep.love > Emberdeep.exe
# ship Emberdeep.exe next to ALL the DLLs + license.txt from the LÖVE zip
zip -9 -r Emberdeep-vX.Y-win64.zip Emberdeep.exe *.dll license.txt
```

**macOS** (with the LÖVE 11.5 macOS release — love.app is universal):

```sh
cp emberdeep.love love.app/Contents/Resources/
python3 - <<'EOF'
import plistlib
p = plistlib.load(open("love.app/Contents/Info.plist","rb"))
p["CFBundleName"] = "Emberdeep"
p["CFBundleIdentifier"] = "com.emberdeep.game"   # keep this STABLE across versions
p["CFBundleShortVersionString"] = "X.Y"
p.pop("CFBundleDocumentTypes", None)
p.pop("UTExportedTypeDeclarations", None)
plistlib.dump(p, open("love.app/Contents/Info.plist","wb"))
plistlib.load(open("love.app/Contents/Info.plist","rb"))  # round-trip verify!
EOF
mv love.app Emberdeep.app
zip -9 -qry Emberdeep-vX.Y-macos.zip Emberdeep.app   # -y KEEPS SYMLINKS
```

Three macOS rules, each learned from a broken build: **patch the plist
with plistlib, never regex** (a partial match once left mismatched XML
tags and macOS reported the app as unplayable); **keep the bundle
identifier identical across versions** so Gatekeeper's one-time
right-click→Open approval carries over; **zip with `-y`** and verify the
archive still contains 39 symlink entries
(`python3 -c "import zipfile; z=zipfile.ZipFile('...zip'); print(sum(1 for i in z.infolist() if (i.external_attr>>16)&0o170000==0o120000))"`).
The app stays unsigned — first launch is right-click → Open.

## 9. Adding bigger things — checklists

**A boss:** class in `bosses.lua` (init def with `id`, `name`, `hp`,
`reward`) + state-machine `update` + `hurt` law + `draw` (bespoke sprite
in `sprites/bosses.lua`) → `PLACE[id]` spawn position → `EPITAPH[id]` →
`CORPSE_LORE[id]` in props.lua → `boss:<id>` trigger char in the arena
room (+ `arena = "<id>"` backdrop tag, scene in `World:drawArenaBackdrop`)
→ testchamber `BOSSES`/`ARENAS` lists → `BOSS_REWARDS` in genprogress →
extend `bossflow`, and `bossspawn`/`bossreenter` pick it up from their
lists. The engine enforces spawn-unembedding and the tripwire trigger for
free; `bossspawn` also fails any boss that neither moves nor attacks
within six seconds.

**An NPC with a quest:** sprite (`sprites/npcs.lua`, use the `npc()`
template) → `SPRITES` in `entities/npc.lua` → `NAMES`/`PORT_COLOR` in
`ui/textbox.lua` → dialogue entries in `data/dialogue.lua` (first matching
entry wins — order them most-specific first; `set`/`give`/`fn`/`choice`
entries do the work; `once = "flag"` + `notflag` for one-shot beats) →
place with `npc:<id>[:need:<flag>][:until:<flag>]...` (conditions chain) →
if the NPC *gives* progression flags, add an `NPC_GIVES` stage in
genprogress so completability stays provable.

**A module/ability gate:** grant via chest (`chest:<flag>:module:<id>`) or
boss reward → `Items.MODULES` entry (name + desc are the pickup toast) →
gate rooms with `gates = { G = "<id>" }` → if it changes traversal
(new jump, light, endurance), teach `roommodel.py`/`genprogress.py` the
semantics — copy how `lumecore`, `cryocoils`, or `heatplating` are done.

## 10. The gotcha list

- `G.run` is saved wholesale: anything you put there must serialize
  (numbers/strings/bools/plain tables) and must be lazily-defaulted for
  old saves (`G.run.log = G.run.log or {}`).
- Boss/quest flags are forever: display names can change freely, ids
  (`prismtyrant`) must not — renames are display-layer only.
- Autosave is refused during the endgame lockout (`ember_taken`,
  `reckoning`) and for slotless Test Chamber runs — never call
  `Save.writeSlot` directly from gameplay code.
- Dialogue pauses the world: entities added during a dialogue (boss
  drops!) appear only after it closes.
- A `sign:<id>` with a `once` flag still needs a fallback entry below it,
  or the sign goes silent after the first read.
- Positions you assign directly (bypassing `PH.move`) need a
  `boxBlocked` guard or `World:ensureFree` — sway animations and spawns
  have both embedded things in walls before.
- Water: `World.waterLine` (Tide Engine) makes AIR below the line count
  as water; clear it when the fight ends (`Boss.onDeath` does).
- New anchors need `["n"] = "anchor"` in the room key; new entity spawn
  chars must avoid ALL tile chars (`L` is lava!) and `A`–`J`.
- After any map/flag change, the generated `progress_graph.lua` must be
  regenerated and committed — the F1 panel and checkprogress read it.
