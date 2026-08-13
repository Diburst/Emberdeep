#!/usr/bin/env python3
"""Room sanity checkers (built on roommodel.py).

1. Liquid physics: every '~'/'L' tile must be supported below and not
   leak sideways into air below its surface row.

2. Trap + pairwise reachability, HAZARD-AWARE: with full progression
   (all abilities, all gates satisfied) every cell reachable from a door
   must be able to reach a door back, and every door must reach every
   other door. Lava is death, spikes cannot be stood or landed on, and
   arrivals mirror the engine's door placement exactly.
"""
import glob
import sys
import roommodel as RM

def liquid_check(room):
    g, H, W = room.g, room.H, room.W
    bad = []
    for y in range(H):
        for x in range(W):
            ch = g[y][x]
            if ch in RM.LIQ:
                below = g[y + 1][x] if y + 1 < H else "#"
                if below not in "#%c" and below != ch \
                        and below not in RM.DOORS and below not in RM.GATES:
                    bad.append(f"{room.name}: {ch} at ({x},{y}) floats over '{below}'")
                above = g[y - 1][x] if y > 0 else "#"
                if above == ch:  # below the surface
                    for dx in (-1, 1):
                        side = g[y][x + dx] if 0 <= x + dx < W else "#"
                        if side == ".":
                            bad.append(f"{room.name}: {ch} at ({x},{y}) leaks sideways into air")
    return bad

def full_flags(room):
    """All abilities + every gate in this room satisfied (bridges powered)."""
    flags = set(RM.ALL_ABILITIES)
    for ch, flag in room.gates.items():
        flags.add(flag[1:] if flag.startswith("!") else flag)
    return flags

def trap_check(room):
    out = []
    if not room.doors:
        return out
    nav = RM.Nav(room, full_flags(room))
    doors = sorted(room.doors)

    # forward reach from all doors together, then trap detection
    all_start = set()
    for ch in doors:
        all_start |= set(nav.arrivals(ch)) | set(room.doors[ch])
    fwd = nav.reach_from(all_start)
    door_cells = {c for ch in doors for c in room.doors[ch]}
    canexit = set(c for c in door_cells if c in fwd) | (all_start & door_cells)
    changed = True
    while changed:
        changed = False
        for n in list(fwd):
            if n in canexit:
                continue
            for m2 in nav.moves(*n):
                if m2 in canexit:
                    canexit.add(n)
                    changed = True
                    break
    stuck = [n for n in fwd if n not in canexit and nav.standable(*n)]
    if stuck:
        out.append(f"{room.name}: possible trap at tiles "
                   f"{sorted(stuck)[:8]}{'...' if len(stuck) > 8 else ''} "
                   f"({len(stuck)} cells)")

    # pairwise: every door reaches every other door
    for ch in doors:
        reach = nav.reach_from_door(ch)
        for ch2 in doors:
            if ch2 != ch and not any(c in reach for c in room.doors[ch2]):
                out.append(f"{room.name}: door {ch} CANNOT REACH door {ch2}")
    return out

def main():
    liq_bad, trap_bad = [], []
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        room = RM.parse_room(fname)
        liq_bad += liquid_check(room)
        trap_bad += trap_check(room)
    print("== LIQUID ==")
    for b in liq_bad:
        print(" ", b)
    print(f"{len(liq_bad)} liquid issues")
    print("== TRAPS ==")
    for b in trap_bad:
        print(" ", b)
    print(f"{len(trap_bad)} trap reports")
    return 1 if (liq_bad or trap_bad) else 0

if __name__ == "__main__":
    sys.exit(main())
