#!/usr/bin/env python3
"""Room key/gate integrity.

The room format has three tables that must agree with the map:

  key    char -> entity spec     every char must APPEAR in the map
  gates  char -> flag            every gate char must appear too
  map    the grid                every non-tile char must HAVE a key entry

Nothing checked this, and two faults lived in the tree for months as a
result: flood_2 declared a checkpoint it never placed (so that room had no
checkpoint at all, despite claiming one), and sky_boss kept an `anchor`
entry after its anchors were deleted from the map.

The nastier direction is a key char shadowed by a TILE char -- `v` is
SPIKE_D, `c` is crumble, `L` is lava. A chest keyed to one of those is
parsed as terrain and silently never spawns. That is how eleven enemies
once sat unspawnable across seven rooms, and how the DRIFT VANES chest
went missing the day it was written.

Run from game/ with PYTHONPATH=../scripts.
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roommodel as RM                                    # noqa: E402

# READ FROM THE ENGINE, never typed here. This file used to hold its own
# copy of the tile alphabet, which is fine until world.lua gains a
# character and this stops guarding it -- see checkchars.py.
TILE = RM.TILES
DOORS = RM.DOORS
GATES = RM.GATES


def audit(fname):
    name = fname.split("/")[-1][:-4]
    src = open(fname).read()
    m = re.search(r"map = \[\[\n(.*?)\]\]", src, re.S)
    if not m:
        return ["%s: no map block" % name]
    rows = [r for r in m.group(1).split("\n") if r.strip()]
    bad = []

    w = len(rows[0])
    for i, r in enumerate(rows):
        if len(r) != w:
            bad.append("%s: row %d is %d chars, expected %d" % (name, i, len(r), w))

    km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
    key = dict(re.findall(r'\["(.)"\]\s*=\s*"([^"]+)"', km.group(1))) if km else {}
    gm = re.search(r"gates = \{([^}]*)\}", src)
    gates = dict(re.findall(r'([A-J])\s*=\s*"([^"]+)"', gm.group(1))) if gm else {}

    present = set()
    for r in rows:
        for ch in r:
            if ch not in TILE and ch not in DOORS and ch not in GATES:
                present.add(ch)

    for ch, spec in sorted(key.items()):
        if ch in TILE:
            bad.append("%s: key '%s' (%s) is SHADOWED BY A TILE CHAR -- it will "
                       "never spawn" % (name, ch, spec))
        elif ch not in present:
            bad.append("%s: key '%s' (%s) never appears in the map"
                       % (name, ch, spec))
    for ch in sorted(present):
        if ch not in key:
            bad.append("%s: map char '%s' has no key entry -- the engine will "
                       "error on load" % (name, ch))
    joined = "".join(rows)
    for ch in sorted(gates):
        if ch not in joined:
            bad.append("%s: gate '%s' (%s) is not in the map"
                       % (name, ch, gates[ch]))
    return bad


def main():
    bad = []
    n = 0
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        n += 1
        bad += audit(fname)
    for b in bad:
        print("  " + b)
    print("%d key/gate issues across %d rooms" % (len(bad), n))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
