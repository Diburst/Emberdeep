#!/usr/bin/env python3
"""Door topology auditor.

Rules enforced across all rooms:
  1. Every door char (A-F) present in a map must have a links entry (NOLINK)
     and every links entry must have a door in the map (GHOSTLINK).
  2. A link must point at an existing room (MISSING) and an existing door
     char in that room (PHANTOM).
  3. Links are 1:1 and mutual: if roomX:D1 -> roomY:D2 then roomY:D2 ->
     roomX:D1 (NOTMUTUAL), and no two doors may share a target (SHARED).
  4. Geometric continuity: a right-edge door must link to a left-edge door,
     left to right, top to bottom, bottom to top; interior (portal) doors
     link to portals (GEOMETRY).
"""
import re
import glob
import sys

DOORS = set("ABCDEF")

# Linkless doors that are intentional: engine treats a door without a links
# entry as inert (no portal frame, no transition). camp_awake:A is the
# new-game spawn marker (see save.lua defaults).
SPAWN_DOORS = {("camp_awake", "A")}

def parse(fname):
    src = open(fname).read()
    m = re.search(r"map = \[\[\n(.*?)\]\]", src, re.S)
    rows = [r for r in m.group(1).split("\n") if r.strip()]
    H, W = len(rows), len(rows[0])
    doors = {}
    for y in range(H):
        for x in range(W):
            ch = rows[y][x]
            if ch in DOORS:
                xs, ys = doors.setdefault(ch, ([], []))
                xs.append(x); ys.append(y)
    sides = {}
    for ch, (xs, ys) in doors.items():
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        if x0 == 0: side = "left"
        elif x1 == W - 1: side = "right"
        elif y0 == 0: side = "top"
        elif y1 == H - 1: side = "bottom"
        else: side = "portal"
        sides[ch] = side
    links = {}
    lm = re.search(r"links = \{(.*?)\n  \}", src, re.S)
    if lm:
        for em in re.finditer(
                r'([A-F])\s*=\s*\{\s*"([\w]+)"\s*,\s*"([A-F])"\s*\}', lm.group(1)):
            links[em.group(1)] = (em.group(2), em.group(3))
    return sides, links

OPPOSITE = {"left": "right", "right": "left", "top": "bottom",
            "bottom": "top", "portal": "portal"}

def main():
    rooms = {}
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        name = fname.split("/")[-1][:-4]
        rooms[name] = parse(fname)
    bad = []
    targets = {}
    for name, (sides, links) in sorted(rooms.items()):
        if name == "test_arena":
            continue
        for ch in sorted(sides):
            if ch not in links and (name, ch) not in SPAWN_DOORS:
                bad.append(f"NOLINK   {name}:{ch} ({sides[ch]}) has no links entry")
        for ch, (tr, td) in sorted(links.items()):
            if ch not in sides:
                bad.append(f"GHOSTLINK {name}:{ch} -> {tr}:{td} but no '{ch}' door in map")
                continue
            if tr not in rooms:
                bad.append(f"MISSING  {name}:{ch} -> {tr} (room not found)")
                continue
            tsides, tlinks = rooms[tr]
            if td not in tsides:
                bad.append(f"PHANTOM  {name}:{ch} -> {tr}:{td} (no such door there)")
                continue
            back = tlinks.get(td)
            if back != (name, ch):
                bad.append(f"NOTMUTUAL {name}:{ch} -> {tr}:{td} but {tr}:{td} -> {back}")
            key = (tr, td)
            if key in targets:
                bad.append(f"SHARED   {name}:{ch} and {targets[key]} both -> {tr}:{td}")
            targets[key] = f"{name}:{ch}"
            want = OPPOSITE[sides[ch]]
            if tsides[td] != want:
                bad.append(f"GEOMETRY {name}:{ch} ({sides[ch]}) -> {tr}:{td} "
                           f"({tsides[td]}, expected {want})")
    for b in bad:
        print(" ", b)
    print(f"{len(bad)} door topology issues")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
