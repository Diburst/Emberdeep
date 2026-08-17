#!/usr/bin/env python3
"""Co-op camera auditor.

The camera has no zoom. Cam.update follows the plain midpoint of both bots
and clamps to the room bounds, so a bot leaves frame once the pair separate
by more than the viewport. Viewport is 480x270 px = 30.0 x 16.9 tiles.

Rule (Thomas, Aug 2026): both players must remain on screen at all times,
and no gated crossing may demand more than 0.75 of a screen. That gives:

    horizontal  0.75 * 480 = 360 px = 22.5 tiles
    vertical    0.75 * 270 = 202 px = 12.7 tiles

Only rooms big enough to SCROLL can split the pair at all -- a 30x17 room
is exactly one screen, so the camera never moves and separation is
impossible. Those rooms pass for free.

What this checks: every cell a body can only reach WITH the drift vanes is
somewhere Lu can go and Vess cannot follow on foot. For each such cell we
measure how far it is from the nearest cell reachable WITHOUT the vanes --
that is where Vess has to stand while she crosses. If that exceeds the
budget on an axis the room actually scrolls on, the pair get split.

FAIL is reserved for hover-only cells that hold something (an entity or a
door): those are gated sections the player is expected to reach. Bare
decorative ledges are reported as NOTE and do not fail the build -- nobody
is required to stand on them.
"""
import glob
import sys
import roommodel as RM

VW, VH, T = 480, 270, 16
BUDGET = 0.75
H_BUDGET = BUDGET * VW / T          # 22.5 tiles
V_BUDGET = BUDGET * VH / T          # 12.66 tiles


def reach(room, flags):
    nav = RM.Nav(room, flags)
    if not room.doors:
        return set()
    start = set()
    for ch in room.doors:
        start |= set(nav.arrivals(ch)) | set(room.doors[ch])
    return nav.reach_from(start)


def full_flags(room, with_vanes):
    flags = set(RM.ALL_ABILITIES)
    if not with_vanes:
        flags.discard("driftvanes")
    for ch, flag in room.gates.items():
        f = flag[1:] if flag.startswith("!") else flag
        # a gate keyed to the vanes themselves is only open once you have
        # them, so it must not be force-opened in the no-vanes pass
        if not with_vanes and f == "driftvanes":
            continue
        flags.add(f)
    return flags


def audit(fname):
    room = RM.parse_room(fname)
    fails, notes = [], []
    if not room.doors:
        return fails, notes

    without = reach(room, full_flags(room, False))
    withv = reach(room, full_flags(room, True))
    gated = withv - without
    if not gated:
        return fails, notes

    # does this room scroll at all?
    h_scroll = room.W * T > VW
    v_scroll = room.H * T > VH
    if not h_scroll and not v_scroll:
        return fails, notes          # single screen: cannot split the pair

    # what is worth reaching? entity spawns and doors
    payload = {}
    for ch, cells in (room.spawns or {}).items():
        spec = room.key.get(ch)
        if not spec:
            continue
        for c in cells:
            payload[c] = spec
    for ch, cells in room.doors.items():
        for c in cells:
            payload[c] = "door:" + ch

    if not without:
        return fails, notes

    worst_h, worst_v, worst_cell = 0, 0, None
    for (cx, cy) in gated:
        # where does Vess have to stand? the nearest place he can get to
        dh, dv, best = None, None, None
        for (ax, ay) in without:
            h, v = abs(cx - ax), abs(cy - ay)
            if best is None or (h + v) < best:
                best, dh, dv = h + v, h, v
        if dh is None:
            continue
        over_h = h_scroll and dh > H_BUDGET
        over_v = v_scroll and dv > V_BUDGET
        if dh > worst_h or dv > worst_v:
            worst_h, worst_v, worst_cell = max(dh, worst_h), max(dv, worst_v), (cx, cy)
        if over_h or over_v:
            what = payload.get((cx, cy)) or payload.get((cx, cy + 1))
            msg = ("%s: hover-only cell %s is %.0fh/%.0fv tiles from anywhere "
                   "Vess can stand (budget %.1fh/%.1fv)"
                   % (room.name, (cx, cy), dh, dv, H_BUDGET, V_BUDGET))
            if what:
                fails.append(msg + "  -- and it holds '%s'" % what)
            else:
                notes.append(msg)

    return fails, notes


def main():
    all_fails, all_notes = [], []
    rooms = 0
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        rooms += 1
        f, n = audit(fname)
        all_fails += f
        all_notes += n
    print("== CO-OP CAMERA (%d rooms, budget %.1f tiles horizontal / %.1f vertical) =="
          % (rooms, H_BUDGET, V_BUDGET))
    for n in all_notes:
        print("  NOTE " + n)
    for f in all_fails:
        print("  FAIL " + f)
    print("%d co-op split issues (%d notes on unreachable scenery)"
          % (len(all_fails), len(all_notes)))
    return 1 if all_fails else 0


if __name__ == "__main__":
    sys.exit(main())
