#!/usr/bin/env python3
"""Furniture placement audit: is it standing on anything?

Save lanterns and checkpoints are both authored so their FEET sit on the
bottom edge of the tile they are placed in:

    SavePoint  Entity.init(self, x, y - 8)   16x24  -> bottom = y + 16
    Checkpoint Entity.init(self, x + 2, y)   12x16  -> bottom = y + 16

So the tile directly BELOW the placed cell has to hold them up. If it does
not, the lantern hangs in the air -- and a checkpoint is worse than
cosmetic when it floats, because it writes its own tile coordinates as the
respawn point:

    G.run.checkpoint = { room = ..., x = self.x - 2, y = self.y }

You then respawn in mid-air and fall, and whatever is under the checkpoint
is what catches you. If that is lava or spikes, the checkpoint kills you on
arrival, forever.

Severity:
  FAIL  nothing underneath at all, or the fall lands in lava / on spikes
  WARN  supported only by a breakable ('%') or crumbling ('c') tile --
        support that can be removed, under the one thing you rely on
  NOTE  supported by a one-way ('='), which holds but reads as a shelf

Also checks that each one can actually be reached from a door.

NOTHING THAT SAVES OR RESPAWNS BELONGS IN A BOSS ROOM. A checkpoint
inside an arena writes its own tile as the respawn point, so dying to the
boss puts you back on its floor with the fight re-armed and whatever
state the arena was in still set -- and a save lantern lets you bank a
run mid-fight. The retry loop for a boss is the room BEFORE it. This is
a hard rule; `cold_boss` shipped with a checkpoint six tiles from the
door because the room was generated before it was an arena.

ITEMS are audited by a different rule. A capsule or a chest is a static
hovering object with no physics, so one parked three tiles up a shaft is
deliberate, not broken -- you jump for it. What is never acceptable is an
item you have to stand in a hazard to take. Rewards dropped at RUNTIME
are placed by World:settleDrop and covered by tools/drop_test.lua; these
are the hand-placed ones, held to the same standard.

Run from game/ with PYTHONPATH=../scripts.
"""
import glob
import os
import re
import sys
import roommodel as RM

# must be held up by something: they are furniture, and a floating
# checkpoint respawns you in mid-air
FURNITURE = ("save", "checkpoint", "teleporter")

# may hover, but must be reachable and must not be taken from inside a
# hazard
ITEMS = ("chest", "capsule", "tank", "plate", "thawplate", "linkcore")

HAZARD = "^v<>L"


def audit(fname):
    room = RM.parse_room(fname)
    out = []
    flags = set(RM.ALL_ABILITIES)
    for ch, f in room.gates.items():
        flags.add(f[1:] if f.startswith("!") else f)
    nav = RM.Nav(room, flags)
    reach = set()
    if room.doors:
        start = set()
        for ch in room.doors:
            start |= set(nav.arrivals(ch)) | set(room.doors[ch])
        reach = nav.reach_from(start)

    for ch, cells in sorted((room.spawns or {}).items()):
        spec = room.key.get(ch)
        if not spec:
            continue
        kind = spec.split(":")[0]
        if kind in ITEMS:
            for (x, y) in cells:
                here = "%s %-11s at (%d,%d)" % (room.name, kind, x, y)
                # The cell the item occupies is its own spawn char, so it
                # is air by construction -- the cell that matters is the
                # one you stand in to take it, and the one your head is
                # in while you do.
                for (hy, what) in ((y + 1, "is taken from"), (y - 1, "is reached under")):
                    if 0 <= hy < room.H and room.g[hy][x] in HAZARD:
                        out.append(("FAIL", "%s %s a '%s'" % (
                            here, what, room.g[hy][x])))
                if reach and not nav.touches(reach, [(x, y)]):
                    out.append(("FAIL", "%s cannot be reached from any door" % here))
            continue
        if kind not in FURNITURE:
            continue
        for (x, y) in cells:
            below = room.g[y + 1][x] if y + 1 < room.H else "#"
            here = "%s %-11s at (%d,%d)" % (room.name, kind, x, y)
            if below in "%c":
                out.append(("WARN", "%s rests on '%s' -- support that can be "
                            "shot out or crumble away" % (here, below)))
            elif below == "=":
                out.append(("NOTE", "%s rests on a one-way shelf" % here))
            elif room.g[y][x] == "~":
                # a lantern in a flooded chamber is not floating, it is
                # submerged -- and you respawn swimming, which is fine in a
                # room you needed hydro seals to enter in the first place
                out.append(("NOTE", "%s is submerged (flooded chamber)" % here))
            elif below == "~":
                out.append(("WARN", "%s hangs over open water -- you respawn "
                            "and drop straight in" % here))
            elif not nav.support(x, y + 1):
                land = nav.land(x, y)
                if land is None:
                    out.append(("FAIL", "%s is FLOATING and a fall from it "
                                "ends in lava or on spikes" % here))
                elif land == (x, y):
                    out.append(("FAIL", "%s is FLOATING over nothing" % here))
                else:
                    lx, ly = land
                    out.append(("FAIL", "%s is FLOATING -- %d tiles of air, "
                                "lands at (%d,%d)" % (here, ly - y, lx, ly)))
            if reach and not nav.touches(reach, [(x, y)]):
                out.append(("FAIL", "%s cannot be reached from any door" % here))
    return out


def arenas():
    """Rooms that arm a boss -- by a tripwire column, or by a prop that
    wakes one (the Threshold's kept brazier)."""
    import os
    import re
    out = set()
    for fname in glob.glob("src/data/rooms/*.lua"):
        src = open(fname).read()
        if re.search(r'"boss:\w+', src) or re.search(r'"brazier:\w+:kept:\w+"', src):
            out.add(os.path.basename(fname)[:-4])
    return out


def audit_boss_present(fname, boss_rooms):
    """A room named for a boss must contain one.

    checkprops finds arenas by looking for a `boss:` spec in the source,
    so a room that LOSES its boss silently stops being an arena and every
    check about arenas stops applying to it. That is exactly what
    happened to furn_boss: the spawn tile got painted over during a
    layout pass, the editor's key table healed itself to match the grid,
    and the only symptom anywhere in the suite was checkprogress calling
    four Core rooms unreachable -- four steps downstream, in a different
    zone, with no mention of the Crucible.

    The name is the intent. If a room is called <something>_boss and has
    no boss in it, say so in those words.
    """
    name = os.path.basename(fname)[:-4]
    if not name.endswith("_boss"):
        return []
    # ASK arenas(), do not re-answer it. A room can arm its boss without a
    # `boss:` spawn -- cold_boss wakes the Archivist off a kept brazier --
    # and a second hand-written copy of "what counts as arming a boss" is
    # the exact failure this project has three of. It flagged cold_boss
    # the moment it was written.
    if name in boss_rooms:
        return []
    return [("FAIL", "%s is a boss arena with nothing that arms a boss -- "
             "no reward, so everything gated behind it is unreachable"
             % name)]


def audit_arena(fname, boss_rooms):
    """No boss room may hold anything that saves or respawns."""
    import os
    import re
    name = os.path.basename(fname)[:-4]
    if name not in boss_rooms:
        return []
    src = open(fname).read()
    out = []
    km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
    if km:
        for ch, spec in re.findall(r'\["(.)"\]\s*=\s*"([^"]+)"', km.group(1)):
            kind = spec.split(":")[0]
            if kind in ("save", "checkpoint"):
                out.append(("FAIL",
                    "%s is a BOSS ROOM and holds a %s ('%s'). Dying to the "
                    "boss would respawn you on its floor with the fight "
                    "re-armed, and a lantern would let the run be banked "
                    "mid-fight. Put it in the room before the arena."
                    % (name, kind, ch)))
    if "hasSave = true" in src:
        out.append(("FAIL",
            "%s is a BOSS ROOM and declares hasSave" % name))
    return out


def audit_checkpoints():
    """ONE checkpoint per room, THREE per zone, and no `save` spec left.

    A save lantern and a checkpoint were the same thing in two costumes:
    both wrote the slot, both moved the respawn. The lantern also
    refilled HP, which quietly made every fight after it easier than it
    was designed to be. There is one of them now.

    THE CAPS ARE A GUIDELINE, NOT A GATE. They used to FAIL, which put
    a pacing opinion on the same footing as a room that will not load --
    and the editor runs this on every save, so a deliberate second
    checkpoint in a long room blocked the save until you argued with the
    validator. Pacing is the designer's call and the tool does not get a
    veto over it.

    They are still worth SAYING, because both are usually accidents:
    two checkpoints in one room normally means one was left behind, and
    a fourth in a zone normally means dying there has stopped costing
    anything. Said once, in the notes, where they can be read and
    ignored.

    What stays a FAIL is correctness, not taste: the retired `save`
    spec, a leftover `hasSave`, and anything that respawns you inside a
    boss arena. Those are not opinions about pacing -- they are rooms
    that behave wrongly."""
    import os
    import re
    out = []
    per_zone = {}
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        name = os.path.basename(fname)[:-4]
        src = open(fname).read()
        zm = re.search(r'zone = "(\w+)"', src)
        zone = zm.group(1) if zm else "?"
        km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
        saves, cps = [], []
        if km:
            for ch, spec in re.findall(r'\["(.)"\]\s*=\s*"([^"]+)"',
                                       km.group(1)):
                k = spec.split(":")[0]
                if k == "save":
                    saves.append(ch)
                elif k == "checkpoint":
                    cps.append(ch)
        for ch in saves:
            out.append(("FAIL", "%s still uses the retired `save` spec "
                        "('%s'). Save points are checkpoints now -- one "
                        "thing, no HP refill, no [INTERACT]." % (name, ch)))
        if "hasSave = true" in src:
            out.append(("FAIL", "%s still declares hasSave" % name))
        if len(cps) > 1:
            out.append(("NOTE", "%s has %d checkpoints. One per room is the "
                        "guideline -- two is usually one left behind, but "
                        "if you meant it, mean it." % (name, len(cps))))
        if cps:
            per_zone.setdefault(zone, []).append(name)
    for zone, names in sorted(per_zone.items()):
        if len(names) > 3:
            out.append(("NOTE", "zone %r has %d checkpoints (%s). Three is "
                        "the guideline -- past that, dying costs little "
                        "anywhere in the zone. Your call."
                        % (zone, len(names), ", ".join(names))))
    return out


def audit_pickup_flags():
    """A PICKUP IS ITS FLAG, so two of them cannot share one.

    Entity.register("tank") and ("capsule") both open with

        if G.run and G.run.flags[flag] then return true end

    -- "already taken, do not spawn". That is right, and it is why a
    duplicated flag deletes an item rather than duplicating it: taking
    either one makes the other stop existing, in a room that still shows
    it on the map. Reported exactly that way -- "I'm in flood_5 and
    there's no tank_flood, even though it's on the map."

    It is not cosmetic. The forge gates energy tier N behind N+1 tanks
    (states/forge.lua), so a swallowed tank is one tier the player can
    never buy, for the rest of the run, with nothing on screen to say
    so. checkprogress cannot see it either: two rooms granting the same
    flag look to it like two routes to one thing, which is a shape the
    game legitimately uses elsewhere.

    Chests are held to the same rule for the same reason.

    flood_2 and flood_5 both said `tank:tank_flood`. They were the only
    pair in the game -- seven tank flags, ten capsule flags, one
    collision -- which is exactly the kind of thing that survives for
    months because everything around it looks fine."""
    seen = {}
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        name = os.path.basename(fname)[:-4]
        src = open(fname).read()
        km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
        if not km:
            continue
        for ch, spec in re.findall(r'\["(.)"\]\s*=\s*"([^"]+)"', km.group(1)):
            parts = spec.split(":")
            kind = parts[0]
            if kind not in ("tank", "capsule", "chest"):
                continue
            # `tank:<flag>`, `capsule:<flag>`, `chest:<flag>:<loot>...`
            flag = parts[1] if len(parts) > 1 else ""
            if not flag:
                # an unnamed one derives its flag from its coordinates,
                # so it cannot collide with anything but itself
                continue
            seen.setdefault((kind, flag), []).append("%s '%s'" % (name, ch))
    out = []
    for (kind, flag), where in sorted(seen.items()):
        if len(where) > 1:
            out.append(("FAIL", "%d %ss share the flag %r (%s). Taking one "
                        "deletes the others -- a pickup IS its flag. Give "
                        "each its own." % (len(where), kind, flag,
                                           ", ".join(where))))
    return out


def main():
    rows, n = [], 0
    boss_rooms = arenas()
    rows += audit_checkpoints()
    rows += audit_pickup_flags()
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        n += 1
        rows += audit(fname)
        rows += audit_arena(fname, boss_rooms)
        rows += audit_boss_present(fname, boss_rooms)
    order = {"FAIL": 0, "WARN": 1, "NOTE": 2}
    rows.sort(key=lambda r: order[r[0]])
    for sev, msg in rows:
        print("  %-4s %s" % (sev, msg))
    fails = sum(1 for s, _ in rows if s == "FAIL")
    warns = sum(1 for s, _ in rows if s == "WARN")
    notes = sum(1 for s, _ in rows if s == "NOTE")
    print("%d failures, %d warnings, %d notes across %d rooms (%d boss rooms "
          "checked for saves)" % (fails, warns, notes, n, len(boss_rooms)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
