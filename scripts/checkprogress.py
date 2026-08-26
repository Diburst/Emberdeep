#!/usr/bin/env python3
"""World-progression validator.

Runs a flag-inventory fixpoint over the progress graph from a fresh
start (camp_awake spawn, zero flags) and asserts:

  1. COMPLETABLE: the 'ending' flag is obtainable.
  2. ALL ITEMS: every flag-granting entity in the world is obtainable
     (no chest/capsule/tank/ability is locked out forever).
  3. ALL ROOMS: every room becomes reachable.
  4. NO SELF-LOCK: report the obtain order, proving no flag requires
     itself (a cycle would simply never resolve and shows up as 1-3).
  5. GATE-ARRIVAL SAFETY: at the moment a door first becomes reachable
     (with the flags held then), at least one exit from that room is
     usable -- you can never walk into a room you cannot leave.

The same fixpoint runs in-game in src/core/progress.lua (test-mode
Progress menu); this is the offline, fail-the-build version.
"""
import sys
from collections import deque

import genprogress as GP


def satisfied(reqs, flags):
    return any(r <= flags for r in reqs)


def fixpoint(graph, start_flags=frozenset()):
    """-> (flags, first_reach {(room,door): frozenset flags at first reach},
    obtain_order [(flag, room)])"""
    flags = set(start_flags)
    first_reach = {}
    obtain_order = []
    start_room, start_door = GP.SPAWN_DOOR
    first_reach[(start_room, start_door)] = frozenset(flags)

    changed = True
    while changed:
        changed = False
        # derived flags on visiting their room
        for flag, d in GP.DERIVED.items():
            if flag not in flags and set(d["req"]) <= flags \
                    and any(rm == d["room"] for (rm, _dch) in first_reach):
                flags.add(flag)
                obtain_order.append((flag, d["room"]))
                changed = True
        for (rm, dch) in list(first_reach):
            info = graph[rm]
            for (fkey, tkey), reqs in info["edges"].items():
                if fkey != "door:" + dch or not satisfied(reqs, flags):
                    continue
                if tkey.startswith("door:"):
                    tdch = tkey[5:]
                    if (rm, tdch) not in first_reach:
                        first_reach[(rm, tdch)] = frozenset(flags)
                        changed = True
                    link = info["room"].links.get(tdch)
                    if link and link[0] in graph:
                        dest = (link[0], link[1])
                        if dest not in first_reach:
                            first_reach[dest] = frozenset(flags)
                            changed = True
                else:
                    cells, gives, extra, _kind = info["targets"][tkey]
                    if set(extra) <= flags:
                        new = [f for f in gives if f not in flags]
                        if new:
                            for f in new:
                                flags.add(f)
                                obtain_order.append((f, rm))
                            changed = True
    return flags, first_reach, obtain_order


def main():
    graph = GP.build_graph()
    flags, first_reach, order = fixpoint(graph)
    bad = []

    # 1. completable
    if "ending" not in flags:
        bad.append("NOT COMPLETABLE: 'ending' is unobtainable from a fresh start")

    # 2. every item obtainable
    for rm, info in sorted(graph.items()):
        for tkey, target in info["targets"].items():
            gives = target[1]
            for f in gives:  # noqa: E501 -- flat check per granted flag
                if f not in flags:
                    bad.append(f"ITEM LOCKED: {rm} {tkey} grants '{f}' but it is never obtainable")

    # 3. every room reachable
    reached_rooms = {rm for (rm, _d) in first_reach}
    for rm in sorted(graph):
        if rm not in reached_rooms:
            bad.append(f"ROOM UNREACHABLE: {rm}")

    # 5. gate-arrival safety: with the flags held at first arrival, the
    # traversal model must actually reach a linked door's tiles from the
    # arrival spot. NO shortcuts: "you can walk back into the door you
    # came through" must be PROVEN, not assumed -- an arrival spot inside
    # a sealed pocket (furn_6's tank alcove taught us) reaches nothing.
    import roommodel as _RM
    for (rm, dch), F in sorted(first_reach.items()):
        info = graph[rm]
        room = info["room"]
        nav = _RM.Nav(room, set(F))
        reach = nav.reach_from_door(dch)
        ok = False
        for ch2, link in room.links.items():
            if link and ch2 in room.doors \
                    and any(c in reach for c in room.doors[ch2]):
                ok = True
                break
        if not ok:
            bad.append(f"ARRIVAL TRAP: {rm}:{dch} first reached with "
                       f"{sorted(F)} has no usable exit")

    # 6. gate integrity: each gate flag must matter in SOME context --
    # there must exist a combination of the room's other gate flags under
    # which adding this flag changes what is reachable. A gate that never
    # changes anything is decorative, missing its tiles, or hoppable.
    import itertools
    import roommodel as RM
    for rm, info in sorted(graph.items()):
        room = info["room"]

        # WHO the gate matters to is part of the question.
        #
        # This used to ask the merged model only -- one body holding every
        # module in the game -- and a gate that body can bypass looked
        # decorative. That is structurally blind to the best kind of gate
        # this game has: furn_3's G is a CO-OP gate, and Thomas built it
        # on purpose. Vess grapples over it and opens it from the far
        # side; Lu cannot follow and walks through once he has. Merged,
        # the gate changes nothing (107 cells either way). For Lu it is
        # the difference between 24 cells and 101.
        #
        # So the signature is taken per body as well as merged, and a
        # gate is a bypass only if it changes nothing for ANY of them.
        # A gate that matters to one bot is a gate.
        BODIES = (None,) + RM.BOTS

        def sig(fl):
            out = set()
            for bot in BODIES:
                nav = RM.Nav(room, fl, bot=bot)
                for dch in sorted(room.doors):
                    reach = nav.reach_from_door(dch)
                    for tkey, target in info["targets"].items():
                        if nav.touches(reach, target[0]):
                            out.add((bot, dch, tkey))
            return out

        gate_flags = sorted({f[1:] if f.startswith("!") else f
                             for f in room.gates.values()})
        for gch, gflag in sorted(room.gates.items()):
            base = gflag[1:] if gflag.startswith("!") else gflag
            others = [f for f in gate_flags if f != base]
            meaningful = False
            for r in range(len(others) + 1):
                for ctx in itertools.combinations(others, r):
                    # baseline must not already contain the gate's flag
                    # (ability gates like 'grapple' are in ALL_ABILITIES)
                    fl = (set(RM.ALL_ABILITIES) - {base}) | set(ctx)
                    if sig(fl) != sig(fl | {base}):
                        meaningful = True
                        break
                if meaningful:
                    break
            if not meaningful:
                bad.append(f"GATE BYPASS: {rm} gate {gch} ({gflag}) does not "
                           f"gate anything (missing tiles or hoppable)")

    print("== PROGRESSION ==")
    print(f"flags obtained ({len(order)}):")
    for f, rm in order:
        print(f"   {f:<24} ({rm})")
    print(f"rooms reached: {len(reached_rooms)}/{len(graph)}")
    for b in bad:
        print(" ", b)
    print(f"{len(bad)} progression issues")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
