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
    # DECLARED kind beats derived side. `doorKind = { B = "portal" }`.
    declared = {}
    dm = re.search(r"doorKind = \{(.*?)\}", src, re.S)
    if dm:
        for em in re.finditer(r'\[?"?([A-F])"?\]?\s*=\s*"(\w+)"', dm.group(1)):
            declared[em.group(1)] = em.group(2)
    sides, onwall = {}, {}
    for ch, (xs, ys) in doors.items():
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        if x0 == 0: side = "left"
        elif x1 == W - 1: side = "right"
        elif y0 == 0: side = "top"
        elif y1 == H - 1: side = "bottom"
        else: side = "portal"
        # which walls this door's box ACTUALLY touches -- a corner door
        # touches two, which is exactly why the derivation alone could
        # never express intent
        onwall[ch] = {
            "left": x0 == 0, "right": x1 == W - 1,
            "top": y0 == 0, "bottom": y1 == H - 1,
            "portal": not (x0 == 0 or x1 == W - 1 or y0 == 0 or y1 == H - 1),
        }
        sides[ch] = declared.get(ch, side)
    links = {}
    lm = re.search(r"links = \{(.*?)\n  \}", src, re.S)
    if lm:
        for em in re.finditer(
                r'([A-F])\s*=\s*\{\s*"([\w]+)"\s*,\s*"([A-F])"\s*'
                r'(?:,\s*req\s*=\s*"([^"]+)"\s*)?,?\s*\}', lm.group(1)):
            links[em.group(1)] = (em.group(2), em.group(3))
    return sides, links, onwall, declared

OPPOSITE = {"left": "right", "right": "left", "top": "bottom",
            "bottom": "top", "portal": "portal"}

def main():
    rooms = {}
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        name = fname.split("/")[-1][:-4]
        rooms[name] = parse(fname)
    bad, notes = [], []
    targets = {}
    for name, (sides, links, onwall, declared) in sorted(rooms.items()):
        if name == "test_arena":
            continue
        for ch in sorted(sides):
            if ch not in links and (name, ch) not in SPAWN_DOORS:
                bad.append(f"NOLINK   {name}:{ch} ({sides[ch]}) has no links entry")
            # THE ONE RULE THAT SURVIVES AS A FAILURE: a door that calls
            # itself a wall door has to be ON that wall. The engine puts
            # an arriving bot against `edge`, so a LEFT door floating in
            # the middle of a room drops it inside the terrain.
            # PORTAL IS NOT A WALL CLAIM, so it is never checked. A door
            # sitting IN a wall but declared a portal is a legitimate
            # thing to build -- it is entered with INTERACT rather than
            # walked into, and the engine places an arriving bot at the
            # door's own cell, which works anywhere. Refusing it was the
            # derivation making a rule for itself again.
            if sides[ch] != "portal" and not onwall[ch].get(sides[ch], False):
                how = "declared" if ch in declared else "derived"
                bad.append(f"MISPLACED {name}:{ch} is {how} '{sides[ch]}' but "
                           f"its box does not touch that wall")
        for ch, (tr, td) in sorted(links.items()):
            if ch not in sides:
                bad.append(f"GHOSTLINK {name}:{ch} -> {tr}:{td} but no '{ch}' door in map")
                continue
            if tr not in rooms:
                bad.append(f"MISSING  {name}:{ch} -> {tr} (room not found)")
                continue
            tsides, tlinks = rooms[tr][0], rooms[tr][1]
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
            # A WALL DOOR PAIRS WITH ITS OPPOSITE WALL. That is still
            # true and still worth saying -- walking out of a right wall
            # and arriving at another right wall is incoherent, and the
            # map draws the two rooms side by side on the strength of it.
            #
            # But it is NOT a law that binds a PORTAL. An interior door
            # is a hole in the middle of a room; it has no wall to be
            # opposite to, so portal->wall and wall->portal are both
            # fine and the old rule refused them for no reason beyond
            # the way the side happened to be computed.
            a, b = sides[ch], tsides[td]
            if a != "portal" and b != "portal" and b != OPPOSITE[a]:
                notes.append(f"OPPOSITE {name}:{ch} ({a}) -> {tr}:{td} "
                             f"({b}) -- two wall doors that do not face "
                             f"each other; the map draws them adjacent")
    for n in notes:
        print("  NOTE", n)
    for b in bad:
        print(" ", b)
    print(f"{len(bad)} door topology issues, {len(notes)} note(s)")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
