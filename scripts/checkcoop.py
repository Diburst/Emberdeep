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
import genprogress as GP
import roommodel as RM

VW, VH, T = RM.viewport()  # read out of main.lua, never copied
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


# ======================================================================
# FALL SEPARATION  (COOP-PLAN 12.4 / 13.5) -- REPORT ONLY
# ======================================================================
# The camera audit above measures GATED CROSSINGS: cells Lu can reach
# with the vanes that Vess cannot follow to. A FALL IS NOT A CROSSING,
# so none of it applies to a bot who simply steps off a ledge -- which
# is how the pair actually separate in the twelve tall rooms.
#
# Two different questions, and only the second one is a bug:
#
#   DEEP   the drop exceeds the vertical budget, so the falling bot
#          leaves frame. Under the round-three camera rule (13.1) that
#          is PERMITTED -- vertical abandonment is allowed and the
#          tether pulses. This is reported so we know where it happens,
#          not because it is wrong.
#
#   STRAND the landing has no walking route back to ANY door. Today the
#          co-op warp bails you out. Build-order step 6 removes the warp
#          and makes doors need both bots, at which point this is a soft
#          lock. This is the one that has to be zero before step 6 ships.
#
# REPORT ONLY, deliberately. Existing rooms were authored against a
# world with a warp in it, so promoting this to FAIL today would fail a
# pile of rooms whose design was never wrong under the old rules.
#
# ONE-BODY CAVEAT. This runs the merged model -- one body that hovers
# AND grapples -- so "a route back out" means "a route back out for the
# most capable bot". Build-order step 3 splits the movement kits, and
# only after that can this answer the question 13.5 actually asks:
# a route back out that THAT BOT can walk. Until then a clean result
# here is necessary, not sufficient.


def fall_audit(room):
    """Returns (deep, strand) -- two lists of message strings."""
    deep, strand = [], []
    if not room.doors:
        return deep, strand

    flags = full_flags(room, True)      # most permissive: everything open
    nav = RM.Nav(room, flags)
    start = set()
    for ch in room.doors:
        start |= set(nav.arrivals(ch)) | set(room.doors[ch])
    cells = nav.reach_from(start)
    if not cells:
        return deep, strand

    doorcells = set()
    for cs in room.doors.values():
        doorcells |= set(cs)

    v_scroll = room.H * T > VH

    # Every distinct landing you can fall to, remembering the HIGHEST
    # place you can fall to it from -- that is the worst case, and it is
    # the only one worth printing.
    drops = {}
    for (x, y) in cells:
        cands = []
        for nx in (x - 1, x + 1):
            if 0 <= nx < room.W and nav.passable(nx, y):
                cands.append((nx, y))
        # straight down off a rope, a door lip or an updraft cell
        if y + 1 < room.H and nav.passable(x, y + 1) \
                and not nav.standable(x, y + 1):
            cands.append((x, y + 1))
        for (nx, ny) in cands:
            landed = nav.land(nx, ny)
            if landed is None:
                continue        # lava, spikes or the void: a death, not a split
            drop = landed[1] - y
            if drop <= 0:
                continue
            prev = drops.get(landed)
            if prev is None or drop > prev[1]:
                drops[landed] = ((x, y), drop)

    # Which cells can walk back to a door? Answered ONCE, by reversing
    # the move graph and flooding backwards from the doors -- not by a
    # fresh BFS per landing, which turned a 6-second check into a
    # 45-second one.
    pred = {}
    for c in cells:
        for n in nav.moves(*c):
            if n in cells:
                pred.setdefault(n, []).append(c)
    escapable = set(d for d in doorcells if d in cells)
    queue = list(escapable)
    while queue:
        c = queue.pop()
        for p2 in pred.get(c, ()):
            if p2 not in escapable:
                escapable.add(p2)
                queue.append(p2)

    for landed, (frm, drop) in sorted(drops.items()):
        if landed not in escapable:
            strand.append("%s: a bot falling from %s lands at %s (%d tiles) "
                          "and cannot walk back to ANY door"
                          % (room.name, frm, landed, drop))
        elif v_scroll and drop > V_BUDGET:
            deep.append("%s: %s -> %s is a %d-tile fall (budget %.1f) -- "
                        "the falling bot leaves frame"
                        % (room.name, frm, landed, drop, V_BUDGET))
    return deep, strand


# ======================================================================
# TWO-BODY DOOR REACHABILITY  (COOP-PLAN 7.4) -- REPORT ONLY
# ======================================================================
# checkrooms asks "can A body get from door A to door B". Step 6 makes
# doors need BOTH bots in the mouth, so the question becomes "can EACH of
# them", and those are different questions the moment the two bots stop
# having the same legs -- which, since step 3, they do not.
#
# DO NOT ATTEMPT A JOINT SEARCH. The state would be (Vess cell, Lu cell,
# world bits): about 10^6 position pairs before the bits, which is a
# research project rather than a validator.
#
# Use the monotone fixpoint instead. Every barrier removal in this game is
# PERMANENT -- a broken block stays broken, a latched plate stays latched
# -- so the world only ever gains flags, and it settles in at most one
# round per barrier. Two ordinary single-body runs per round, and Nav is
# reused unchanged.
#
# What the pair START with: every ability the run can hold, plus every
# gate flag this room does not grant itself. Flags earned in OTHER rooms
# are checkprogress's business; the question here is whether the pair can
# work the machinery in front of them and then both get out.
#
# BULWARK BLOCKS are in the fixpoint's shape but not in the game yet
# (build-order step 9). When they land, they enter here as "a block
# adjacent to Rv becomes air" and nothing else about this changes.
#
# REPORT ONLY. Existing rooms were authored against a model where the pair
# shared one body and a warp bailed them out, so promoting this to FAIL
# today would fail rooms whose design was never wrong under the old rules.


def two_body_audit(room):
    """Returns (split, stuck) -- two lists of message strings."""
    split, stuck = [], []
    doors = sorted(room.doors)
    if not doors:
        return split, stuck

    # ---- what this room's own machinery grants, and to whom ----------
    # target_gives is genprogress's on purpose. It is the ONE place that
    # knows what touching an entity is worth, and a second copy here would
    # be correct right up until somebody adds an entity kind -- which is
    # the exact failure this project has three post-mortems about.
    earnable = {}
    for ch, spec in room.key.items():
        cells = room.spawns.get(ch, [])
        if not cells:
            continue
        gives, _ = GP.target_gives(spec)
        both = spec.split(":")[0] == "linkcore"   # only the LINK opens it
        for f in gives:
            e = earnable.setdefault(f, [set(), False])
            e[0].update(cells)
            e[1] = e[1] or both

    world = set(RM.ALL_ABILITIES)
    for ch, flag in room.gates.items():
        f = flag[1:] if flag.startswith("!") else flag
        if f not in earnable:
            world.add(f)

    def bot_reach(bot, w):
        nav = RM.Nav(room, w, bot=bot)
        s = set()
        for ch in room.doors:
            s |= set(nav.arrivals(ch)) | set(room.doors[ch])
        return nav, nav.reach_from(s)

    navv = navl = None
    Rv = Rl = set()
    for _ in range(len(earnable) + 1):
        navv, Rv = bot_reach("vess", world)
        navl, Rl = bot_reach("lu", world)
        fired = False
        for f, (cells, both) in earnable.items():
            if f in world:
                continue
            hv, hl = navv.touches(Rv, cells), navl.touches(Rl, cells)
            if (hv and hl) if both else (hv or hl):
                world.add(f)
                fired = True
        if not fired:
            break

    # ---- machinery the pair cannot work ------------------------------
    for f, (cells, both) in sorted(earnable.items()):
        if f in world:
            continue
        hv, hl = navv.touches(Rv, cells), navl.touches(Rl, cells)
        if both:
            who = ("neither bot" if not (hv or hl) else
                   "only Vess" if hv and not hl else
                   "only Lu" if hl and not hv else "both")
            if who != "both":
                stuck.append("%s: the LINK lattice for '%s' needs both bots "
                             "beside it and %s can get there"
                             % (room.name, f, who))
        elif not (hv or hl):
            stuck.append("%s: '%s' is granted by machinery neither bot can "
                         "reach" % (room.name, f))

    # ---- the door matrix, per bot, under the settled world -----------
    mats = {}
    for bot in RM.BOTS:
        nav = RM.Nav(room, world, bot=bot)
        m = set()
        for ch in doors:
            r = nav.reach_from_door(ch)
            for ch2 in doors:
                if ch2 != ch and any(c in r for c in room.doors[ch2]):
                    m.add((ch, ch2))
        mats[bot] = m

    agreed = mats["vess"] & mats["lu"]
    for (a, b) in sorted((mats["vess"] | mats["lu"]) - agreed):
        who = "Vess" if (a, b) in mats["vess"] else "Lu"
        other = "Lu" if who == "Vess" else "Vess"
        split.append("%s: door %s -> door %s is a trip only %s can make -- "
                     "%s cannot follow" % (room.name, a, b, who, other))
    return split, stuck


def main():
    all_fails, all_notes = [], []
    all_deep, all_strand = [], []
    all_split, all_stuck = [], []
    rooms = 0
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        rooms += 1
        f, n = audit(fname)
        all_fails += f
        all_notes += n
        room = RM.parse_room(fname)
        d, st = fall_audit(room)
        all_deep += d
        all_strand += st
        sp, sk = two_body_audit(room)
        all_split += sp
        all_stuck += sk
    print("== CO-OP CAMERA (%d rooms, budget %.1f tiles horizontal / %.1f vertical) =="
          % (rooms, H_BUDGET, V_BUDGET))
    for n in all_notes:
        print("  NOTE " + n)
    for f in all_fails:
        print("  FAIL " + f)
    print("%d co-op split issues (%d notes on unreachable scenery)"
          % (len(all_fails), len(all_notes)))

    print("== FALL SEPARATION (report only -- fails nothing) ==")
    for m in all_strand:
        print("  STRAND " + m)
    for m in all_deep:
        print("  DEEP   " + m)
    print("  %d stranding fall(s), %d fall(s) past the vertical budget"
          % (len(all_strand), len(all_deep)))
    if all_strand:
        print("  ^ these must be zero BEFORE build-order step 6 removes the "
              "co-op warp; today the warp hides them")

    print("== TWO-BODY DOOR REACHABILITY (report only -- fails nothing) ==")
    for m in all_stuck:
        print("  STUCK " + m)
    for m in all_split:
        print("  SPLIT " + m)
    print("  %d door trip(s) only one bot can make, %d unworkable "
          "mechanism(s)" % (len(all_split), len(all_stuck)))
    if all_split:
        print("  ^ under step 6 a door needs both bots in its mouth, so each "
              "of these is a door the pair cannot use together")

    return 1 if all_fails else 0


if __name__ == "__main__":
    sys.exit(main())
