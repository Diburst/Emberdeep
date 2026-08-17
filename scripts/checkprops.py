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

ITEMS are audited by a different rule. A capsule or a chest is a static
hovering object with no physics, so one parked three tiles up a shaft is
deliberate, not broken -- you jump for it. What is never acceptable is an
item you have to stand in a hazard to take. Rewards dropped at RUNTIME
are placed by World:settleDrop and covered by tools/drop_test.lua; these
are the hand-placed ones, held to the same standard.

Run from game/ with PYTHONPATH=../scripts.
"""
import glob
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


def main():
    rows, n = [], 0
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        n += 1
        rows += audit(fname)
    order = {"FAIL": 0, "WARN": 1, "NOTE": 2}
    rows.sort(key=lambda r: order[r[0]])
    for sev, msg in rows:
        print("  %-4s %s" % (sev, msg))
    fails = sum(1 for s, _ in rows if s == "FAIL")
    warns = sum(1 for s, _ in rows if s == "WARN")
    print("%d grounding failures, %d warnings across %d rooms" % (fails, warns, n))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
