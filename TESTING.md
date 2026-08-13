# EMBERDEEP — testing guide

Two layers of automated QA: **offline validators** (Python, no game
needed) and **headless scenarios** (the real engine driven by a bot,
via LÖVE + xvfb). Run everything from the repo:

```sh
cd game
```

## Offline validators (seconds)

```sh
python3 ../scripts/checkrooms.py     # liquids, traps, door↔door reachability
python3 ../scripts/checkdoors.py     # door topology: 1:1 mutual links + geometry
PYTHONPATH=../scripts python3 ../scripts/checkprogress.py   # world completability
PYTHONPATH=../scripts python3 ../scripts/genprogress.py     # regen progress_graph.lua
python3 ../scripts/fixrooms.py       # run after hand-editing any room map
```

`checkrooms` proves every door reaches every other door in each room under
full progression, hazard-aware (lava kills, spikes can't be stood on, the
grapple rope is a real 110px). `checkdoors` proves right exits meet left
entrances (etc.) with exactly one partner each. `checkprogress` runs a
flag-inventory fixpoint from a fresh save and proves: the ending is
reachable, every item/ability is obtainable, no room is orphaned, no gate
is hoppable or decorative, and no door ever strands you on arrival.

**All three must print `0 issues` before shipping.** They share one
movement model (`scripts/roommodel.py`) whose constants are verified
against the real engine by the `calibrate` scenario below — if you touch
player physics, run `calibrate` and update the model to match.

## Headless scenarios (engine truth)

```sh
rm -rf ~/.local/share/love/emberdeep   # clean save dir between scenarios
EMBERDEEP_TEST=<name> xvfb-run -a love .
```

Logs append to `/tmp/emberdeep_test.log`, screenshots land in
`/tmp/shots/`. Exit code 0 = pass. Every scenario also runs the
**frame-level invariant harness** (`src/core/invariants.lua`): any frame
with an embedded / out-of-bounds player, insane hp, runaway entity
count, or unclamped camera fails the run with an `INVARIANT` line.

Correctness suite (run all before shipping):

| scenario       | proves |
|----------------|--------|
| `links`        | every door link resolves to a real room + door |
| `hotkeys`      | every open/close hotkey pairing incl. F1 progress panel |
| `sweep`        | every room loads via every door, no spawn embeds |
| `shaftdoors`   | every arrival lands on ground; no bounce-back, lava, or floating |
| `calibrate`    | engine physics == validator model (jump, gap, water, rope) |
| `rungprobe`    | every jump-reachable platform is physically jumpable |
| `progress`     | in-game progression solver: fresh + midgame completable |
| `doorjump`     | every ceiling door physically enterable (jump or walk-in) |
| `forge`        | Brassa's crafting: costs, tier gating, live stats, saves |
| `linkvent`     | link-cores need the blast; Lu's dome blocks vent embers |
| `darkroom`     | Undergrove darkness, lume gate, husks, bulbs, Pulse Bloom |
| `coldstore`    | cold gating, ice friction, thawplate, the Archivist, the Cradle |
| `embertheft`   | Cold Accounting easter egg: freeze, bad ending, clean reload |
| `reckoning`    | full RECLAIM route: Maro, the freeze, Tikka's box, the Seat |
| `bossspawn`    | every boss spawns terrain-free; triggers fire at any height |
| `bossdrops`    | rewards are physical, persistent drops; corpses persist |
| `v41misc`      | lava law (instant down, wreck to safe ground) + pause LOG |
| `testchamber`  | title-menu Test Chamber: loadout, cross-arena boss, wipe re-summon, slotless |
| `play` `solo` `revive` `saveload` `bossflow` `mender` | core loops |
| `sololink` `solobridge` `soloenergize` | solo-mode co-op verb coverage |
| `bossreenter`  | boss arenas fully reset after death + re-entry |
| `persistence`  | collected stays collected; nothing double-collectable |
| `savecompat`   | old-version save layouts boot clean |
| `checkpoints`  | every statue/lantern respawn is sane |
| `cooptransition` | doors with downed/parked partners carry everyone |

One-liner for the full suite:

```sh
for s in links hotkeys sweep shaftdoors calibrate rungprobe doorjump \
         progress forge linkvent darkroom coldstore embertheft reckoning bossspawn \
         bossdrops v41misc testchamber play solo revive saveload bossflow \
         mender sololink solobridge soloenergize bossreenter persistence \
         savecompat checkpoints cooptransition; do
  rm -rf ~/.local/share/love/emberdeep
  EMBERDEEP_TEST=$s xvfb-run -a love . || echo "FAILED: $s"
done
```

## Chaos suite (run as long as you like)

**Fuzz** — seeded random gameplay input in every room, invariants armed.
Catches tunneling, ability-combo weirdness, physics blowups.

```sh
EMBERDEEP_TEST=fuzz EMBERDEEP_FUZZ_STEPS=2000 EMBERDEEP_FUZZ_SEED=42 \
  EMBERDEEP_MAX_MINUTES=60 xvfb-run -a love .
# reproduce a finding exactly: same seed + steps; narrow with
# EMBERDEEP_ROOMS=moss_3,flood_2
```

**UI liveness** — random menu/hotkey storm; every 100 rounds proves a
short cancel-spam returns to gameplay (the generalized Tab bug).

```sh
EMBERDEEP_TEST=uilive EMBERDEEP_UI_STEPS=5000 EMBERDEEP_FUZZ_SEED=7 \
  EMBERDEEP_MAX_MINUTES=60 xvfb-run -a love .
```

**Soak** — cycles every room with combat alive for N sim-minutes,
sampling Lua memory + entity counts every minute; fails on leak-shaped
growth (final > 3x baseline + 20MB).

```sh
EMBERDEEP_TEST=soak EMBERDEEP_SOAK_MINUTES=60 EMBERDEEP_MAX_MINUTES=65 \
  xvfb-run -a love .
```

Notes: headless runs are real-time (vsync), so 60 sim-minutes ≈ 60 wall
minutes. `EMBERDEEP_MAX_MINUTES` is the harness watchdog — set it a
couple of minutes above the expected run length. Seeds make chaos runs
reproducible; when fuzz finds something, save the seed.

## In-game test mode

Settings → TEST MODE (default ON) enables play-testing tools:
**F1** (or Pause → PROGRESS) opens the Progress panel — live
completability check, what's reachable right now, what's blocked and on
which flags, unexplored-but-reachable rooms. If it ever shows
"RUN CANNOT BE COMPLETED" or an UNREACHABLE item on a real save, that's
a bug — the offline validators should have caught it.
