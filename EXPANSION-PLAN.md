# EMBERDEEP — v3.0 "The Deep Wings" Expansion Plan

**STATUS: APPROVED (Aug 11, 2026).** All four phases; new zones stay optional side
wings; themes as proposed; the Proving Floor scales with the difficulty setting
(Story players can clear it) rather than brutal-only.
**Phase 1 (The Undergrove): SHIPPED** — see the v3.0 entry in the design notes.

Originally a proposal — Everything below is designed to fit the existing engine
(LÖVE 11.5, ASCII rooms, prop/flag system, forge economy) and to be provable by the
existing QA stack (checkrooms / checkdoors / checkprogress + the 24-scenario suite).
Current game: 47 rooms, 6 zones, 8 bosses, 4 weapons, 5 modules, 8 camp NPCs, 3 side quests.

Proposed totals after expansion: **~71 rooms, 8 zones, 11 bosses, 7 weapons, 7 modules,
13 NPCs, 9 side quests, a quest journal, and a boss-rush gauntlet.**

---

## 1. Two new zones (~24 rooms)

Both are **optional side wings** off the existing critical path. The ending still needs
exactly the 3 core keys, so the completability proof stays intact — the new zones gate
*rewards* (weapons, capsules, tanks, quests), not the finale. Each zone gets its own
tile palette (`tilegen.lua`), tracker song (`music.lua`), 2–3 new enemies, and one new prop.

### A. THE UNDERGROVE — dark fungal caverns (mid-game)
- **Where:** below Mosswood, entered through the bottom of **moss_well** (the well
  finally goes somewhere). ~11 rooms: 8 main + boss arena + secret + a rescue chamber.
- **Gate / new module: LUME CORE** (Lu-only light emitter). The Undergrove is dark —
  rendered as a shadow overlay with a light radius around Lu (bigger when her dome is up).
  Deep doors use a gate tile keyed to the `lumecore` flag, so `checkprogress` models it
  exactly like heatplating/hydroseals. The Lume Core itself is found in a new alcove in
  the Flooded Works deep (post-Rusted Warden), pointing players back across the world.
- **New prop: `sporebulb`** — glowing pods that burst into drifting spore clouds
  (dome-blocked, like vents). Shooting a bulb lights the room briefly — a resource for
  players who arrive before they have the Lume Core (taste of the zone, hard gate deeper in).
- **New enemies:** `myceling` (crawler that re-grows once from its husk), `glowmite`
  (harmless light-carrier that panics and flees — kill it and the room darkens),
  `sporefly` swarms.
- **Boss: THE MYCEL CHOIR** — three fungal node-heads sharing one health pool, rooted at
  different heights of a vertical arena. Only the one currently "singing" (lit, mouth open)
  takes damage; the song rotates. In the dark phases the arena lights come only from Lu.
  Reward: **Pulse Bloom** (Lu's second weapon, below) + a Life Capsule in the zone.

### B. THE COLDSTORE — frozen archive vaults (late-game)
- **Where:** north of Crystal Hollows (crys_4 has a natural attach point). ~11 rooms.
- **Gate / new module: CRYO COILS** — both bots endure the deep-freeze rooms (mirrors
  heatplating; same validator semantics). Found behind a Slag Golem–guarded cache in the
  Furnace (heat and cold bookend each other), so the zone opens after Furnace Depths.
- **Mechanic: ice floors** — a per-tile friction modifier (small, contained physics change;
  `calibrate` gets an ice-slide measurement so `roommodel.py` stays honest). Ice is never
  required for a critical jump — it spices combat/traversal, the validators keep it honest.
- **New prop: `thawplate`** — a pressure plate encased in ice; a charged Arc Lance shot or
  Link Shot melts it free. Teaches charge-shot utility outside combat.
- **New enemies:** `frostwisp` (freezing shot slows your fire rate briefly), `shelverbot`
  (archive drone that throws book-crates in arcs), `icemaw` (floor ambusher).
- **Boss: THE ARCHIVIST** — a giant catalog engine on a rail across the arena ceiling.
  Cycles indexing sweeps (beam telegraphs), crate barrages, and a vault-slam that shatters
  the ice floor into pits. Vulnerable only when it stops to "re-shelve" — its drawer opens.
  Reward: **Magnet Mortar** (Vess weapon) + energy tank.

---

## 2. Three new bosses total

The two zone bosses above, plus:

- **WARDEN PRIME (gauntlet finale)** — a boss-rush wing, **THE PROVING FLOOR**, opened in
  the Core antechamber once all three original core keys are held. Refights of remixed
  bosses (2 at a time in the final round), capped by Warden Prime: a perfected Rusted
  Warden with the tower shield on BOTH sides — only stunned by baiting its charge into
  the arena's four breakable pillars (or Lu's dome). Pure optional postgame-style content,
  pre-ending. Reward: **forge tier 4** unlock (below) + a unique HUD trinket flag.

---

## 3. Three new weapons

All use projectile features the engine already supports (gravity, bounces, homing, pierce):

- **MAGNET MORTAR** (Vess, Coldstore) — lobbed arcing shells (gravity arcs, like the
  Warden's new throw, but yours). Big damage, slow rate, shots roll a moment before
  detonating. Forge tiers raise blast size / add a cluster split.
- **RIVET RICOCHET** (Vess, sold by the new merchant after his quest chain) — fast shots
  with 2 wall bounces (the `bounces` cfg already exists). Rewards clever angles in the
  tight new caverns. Tiers add bounce count + damage.
- **PULSE BLOOM** (Lu, Mycel Choir) — a short-range radial burst centered on Lu; fires
  even while the dome is up (small energy cost). Finally gives Lu a defensive-offense
  identity in co-op and makes solo-Lu segments viable. Tiers widen the ring.

Forge additions: the 3 new weapons get tier tracks, plus a **tier-4 "PRIME" track**
unlocked by the Proving Floor (one final upgrade per weapon; big scrap sink for the
expanded economy). Save schema bumps to v3 with a `Save.migrate` step — old saves get
the new forge keys at tier 1 (covered by `savecompat`).

## 4. New abilities (modules)

- **LUME CORE** — Lu's light (Undergrove gate). Also: dark rooms elsewhere get subtle
  bonus alcoves you can now see.
- **CRYO COILS** — cold endurance (Coldstore gate).
- Both slot into the existing flag/gate system, so `genprogress.py` and the Progress
  panel handle them with zero new validator concepts.

(Considered and deliberately skipped: moving platforms and magnet-boot ceiling walking —
both would breach the static-tile physics contract that the entire verification stack is
built on. The two chosen gates reuse proven semantics.)

## 5. NPCs & side quests

Five new NPCs, and the camp physically grows as you rescue/recruit them:

- **FERRO** — a wandering scrap-merchant found stranded in the Undergrove rescue chamber.
  Rescue him → he sets up a stall in Ember Camp. Quest chain: three trade fetches
  (zone-specific salvage items) → stocks rare goods → final trade gifts **Rivet Ricochet**.
- **MOTE** — a glowmite-keeper child bot in the Undergrove who won't leave without her
  swarm. Quest: guide 3 glowmites (escort-lite: they follow Lu's light) back to her.
  Reward: capsule + she moves to camp, hangs around Tikka.
- **CURATOR LOCK** — the Coldstore's mad archivist-bot. Quest: recover 4 mis-shelved
  **archive plates** (one per original zone — a reason to revisit with new abilities).
  Reward: energy tank + lore dialogues that flesh out the pre-collapse world.
- **PATROL-7 ("Sev")** — a broken scout found after the Archivist falls. Repaired by Lu →
  joins camp; opens **Sol's Lost Patrol** quest: find 3 wrecked patrol bots across the old
  zones, each marked on the map when Sol briefs you. Reward: scrap cache + Sev sells
  one-use "beacon" items (set a custom teleport point — consumable, so no progression risk).
- **HUM** — a silent monk-bot by the Proving Floor door. No quest; pure vibes and hints.

Existing NPCs get quest extensions: **Tikka's Duet** (play the music box at 3 resonance
stones — one per new zone + one in Skyroot — for a capsule) and **Inks' Grand Survey**
(touch survey markers in the two new zones; reward: auto-map reveals secrets as dots).

**Quest journal:** a TASKS tab on the pause/Progress panel (the flag plumbing already
exists — this is UI). Lists active/complete side quests with one-line hints. `genprogress`
treats every quest reward as an obtainable item, so the validators *prove every quest is
completable from a fresh save*.

## 6. Build & verification plan (4 phases, each shippable)

Each phase lands as its own session-sized chunk, ending fully green before the next starts
(fixrooms → 3 validators → genprogress → sweep/shaftdoors/rungprobe/doorjump → extended
bossflow → targeted fuzz on new rooms → savecompat):

1. **Phase 1 — The Undergrove** (zone, darkness rendering, Lume Core, sporebulb, 3 enemies,
   Mycel Choir, Pulse Bloom, Ferro + Mote quests). Biggest phase; proves the new-zone pipeline.
2. **Phase 2 — The Coldstore** (zone, ice friction + calibrate update, Cryo Coils, thawplate,
   3 enemies, The Archivist, Magnet Mortar, Curator Lock + Sev quests).
3. **Phase 3 — Camp & quest pass** (quest journal UI, camp growth rooms/dialogue, Tikka's
   Duet, Inks' Survey, Ferro chain → Rivet Ricochet, forge UI for new weapons, save v3).
4. **Phase 4 — The Proving Floor** (boss-rush wing, remixed refights, Warden Prime,
   tier-4 forge, new test scenarios: `gauntlet`, `questflow`, `darkroom`).

New test scenarios added along the way: `darkroom` (light-gating honest), `questflow`
(every quest completable in-engine, not just in the model), `gauntlet`, plus extensions
to `bossflow` for all three new bosses.

---

### Open questions for you
1. Scope: all four phases, or a subset first?
2. Should the new zones stay **optional side wings** (recommended — keeps the ending
   proof clean) or do you want one of them wired into the critical path?
3. Any theme veto/steer on the zones (dark-fungal + frozen-archive), boss concepts, or names?
4. Difficulty target for the Proving Floor: brutal-optional, or tuned for everyone?
