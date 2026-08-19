#!/usr/bin/env python3
"""checkchars -- the room alphabet, and who owns it.

WHY THIS EXISTS.

    A room map is a grid of single characters, and the engine reads some
    of them as TERRAIN before it ever looks at the room's `key` table:

        ["c"] = "brazier:c2b"

    is not a brazier. `c` is the crumble tile. The engine parses that
    cell as terrain, the brazier never spawns, and the room file looks
    completely correct. The same trap has now been walked into with
    `c` (crumble), `C` (a door letter) and `L` (lava) -- three times,
    on three different props, and each time the symptom was something
    else entirely: a validator reporting the wrong count, a puzzle that
    could not be finished, a prop that was simply not there.

    checkkeys has caught this since the eleven-unspawnable-enemies
    incident. But it caught it with its OWN hand-typed copy of the tile
    alphabet:

        TILE = set("#.=^v<>~L%c")        # checkkeys.py
        tile = set("#.%c=~L") | SPIKES   # roommodel.py
        local TILE = "#.=^v<>~L%%c"      # load_test.lua
        CHAR_TILE = { ... }              # world.lua -- the real one

    Four copies of one fact. Add a tile char to the engine and three of
    them go stale, and the guard stops guarding the newest character
    without saying a word. THAT is the bug class, not the typo.

SO THIS TOOL DOES TWO THINGS.

    1. It reads the alphabet out of `src/world.lua` -- CHAR_TILE,
       DOOR_CHARS, GATE_CHARS, the tables the engine actually parses
       with -- and checks every key char in every room against it,
       naming what reserves the character and printing what is free.

    2. It refuses to let the copies come back. Any hand-written tile
       alphabet elsewhere in scripts/ or tools/ is a failure, because
       the next one to drift will be silent again.

Run from game/:  python3 ../scripts/checkchars.py
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roommodel as RM                                    # noqa: E402

WORLD = "src/world.lua"


# ------------------------------------------------------------------
# The alphabet, from the engine
# ------------------------------------------------------------------
def read_alphabet(path=WORLD):
    src = open(path).read()

    m = re.search(r"local CHAR_TILE = \{(.*?)\n\}", src, re.S)
    if not m:
        sys.exit("checkchars: could not find CHAR_TILE in %s -- if the "
                 "engine's tile table moved, THIS is the line to fix, "
                 "and nothing else." % path)
    tiles = {}
    for ch, name in re.findall(r'\["(.)"\]\s*=\s*(\w+)', m.group(1)):
        tiles[ch] = name

    def charset(var):
        mm = re.search(r"local %s = \{(.*?)\}" % var, src, re.S)
        if not mm:
            sys.exit("checkchars: could not find %s in %s" % (var, path))
        return set(re.findall(r"(\w)\s*=\s*true", mm.group(1)))

    doors = charset("DOOR_CHARS")
    gates = charset("GATE_CHARS")
    return tiles, doors, gates


TILES, DOORS, GATES = read_alphabet()

RESERVED = {}
for ch, name in TILES.items():
    RESERVED[ch] = "the %s tile" % name.lower().replace("_", " ")
for ch in sorted(DOORS):
    RESERVED[ch] = "a door letter"
for ch in sorted(GATES):
    RESERVED[ch] = "a gate letter"

# every printable char a room file can hold that is NOT spoken for
ALPHABET = ("abcdefghijklmnopqrstuvwxyz"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "0123456789")
FREE = [c for c in ALPHABET if c not in RESERVED]

fails = []

print("== the alphabet, read from %s ==" % WORLD)
print("   terrain : %s" % " ".join(
    "%s=%s" % (c, TILES[c]) for c in sorted(TILES)))
print("   doors   : %s" % " ".join(sorted(DOORS)))
print("   gates   : %s" % " ".join(sorted(GATES)))
print("   free    : %s" % "".join(FREE))

# ------------------------------------------------------------------
# 1. No room may key an entity to a reserved character
# ------------------------------------------------------------------
print("")
print("== no room keys an entity to a character the engine already owns ==")
rooms = 0
collisions = 0
used_by_room = {}
for fname in sorted(glob.glob("src/data/rooms/*.lua")):
    if fname.endswith("test_arena.lua"):
        continue
    rooms += 1
    name = os.path.basename(fname)[:-4]
    src = open(fname).read()
    km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
    if not km:
        continue
    entries = re.findall(r'\["(.)"\]\s*=\s*"([^"]+)"', km.group(1))
    used_by_room[name] = set(ch for ch, _ in entries)
    for ch, spec in entries:
        why = RESERVED.get(ch)
        if why:
            collisions += 1
            # name a replacement that is actually free IN THIS ROOM, so
            # the fix is a character rather than another search
            taken = used_by_room[name]
            spare = [c for c in FREE if c not in taken][:6]
            fails.append(
                "%s: key '%s' (%s) is %s. The engine parses that cell as "
                "terrain before it ever reads the key table, so this "
                "entity SILENTLY never spawns. Free in this room: %s"
                % (name, ch, spec, why, " ".join(spare)))
if collisions == 0:
    print("   %d rooms, 0 collisions" % rooms)

# ------------------------------------------------------------------
# 2. Nobody keeps their own copy of the alphabet
# ------------------------------------------------------------------
# A hand-typed tile set is the actual defect. It is invisible while it
# agrees with the engine and silent when it stops.
print("")
print("== nobody keeps a second copy of it ==")
OWNERS = {
    # the engine itself, and the one parser allowed to read it
    "src/world.lua",
    "scripts/checkchars.py",
    "scripts/roommodel.py",
}
# A COPY, precisely: a string literal of six or more characters drawn
# ENTIRELY from the terrain alphabet. That is what an alphabet copy looks
# like -- set("#.=^v<>~L%c"), "#.%c=~L", "#.=^v<>~L%%c" -- and it is
# narrow enough not to fire on a legitimate SUBSET with a meaning of its
# own, like checkprops' HAZARD = "^v<>L" (things that hurt) or a two-char
# `ch in "%c"` test. Subsets are reasoning; a full copy is a second
# source of truth.
# ...and it counts DISTINCT characters, not length. A map fragment like
# "=======" or "########" in a room generator is made of terrain chars
# too, and it is content rather than a definition. Six distinct terrain
# characters in one literal is an alphabet; one repeated is a ledge.
_ALPHA = "".join(re.escape(c) for c in sorted(TILES))
_LITERAL = re.compile(r"""['"]([%s]{6,})['"]""" % (_ALPHA + re.escape("%")))


def is_copy(line):
    for lit in _LITERAL.findall(line):
        if len(set(lit.replace("%%", "%"))) >= 6:
            return lit
    return None
copies = 0
for fname in (sorted(glob.glob("../scripts/*.py"))
              + sorted(glob.glob("../tools/*.lua"))):
    rel = os.path.normpath(fname).replace("../", "")
    if rel in OWNERS or os.path.basename(fname) in (
            "checkchars.py", "roommodel.py"):
        continue
    src = open(fname).read()
    for lineno, line in enumerate(src.split("\n"), 1):
        if line.lstrip().startswith(("#", "--")):
            continue          # a comment quoting the alphabet is fine
        if is_copy(line):
            copies += 1
            fails.append(
                "%s:%d keeps its own copy of the tile alphabet: %s\n"
                "        Read it from world.lua instead (roommodel.RESERVED "
                "in Python, World's CHAR_TILE in Lua). A second copy is "
                "correct until the engine changes and silent afterwards."
                % (rel, lineno, line.strip()))
if copies == 0:
    print("   the engine is the only place the alphabet is written down")

# ------------------------------------------------------------------
# 3. Every spec a room uses is a thing the engine can build
# ------------------------------------------------------------------
print("")
print("== every key spec names a registered entity ==")
registered = set()
for fname in glob.glob("src/entities/*.lua"):
    src = open(fname).read()
    registered |= set(re.findall(r'Entity\.register\("([%\w]+)"', src))
    # `local Roostfang = reg("roostfang", {...})` -- the assignment form
    # is the common one, so anchoring at the line start missed every
    # enemy in the game and reported them all as unregistered.
    registered |= set(re.findall(r'\breg\("([\w]+)"', src))
unknown = {}
for fname in sorted(glob.glob("src/data/rooms/*.lua")):
    if fname.endswith("test_arena.lua"):
        continue
    name = os.path.basename(fname)[:-4]
    src = open(fname).read()
    km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
    if not km:
        continue
    for ch, spec in re.findall(r'\["(.)"\]\s*=\s*"([^"]+)"', km.group(1)):
        kind = spec.split(":")[0]
        if kind not in registered:
            unknown.setdefault(kind, []).append(name)
if unknown:
    for kind, where in sorted(unknown.items()):
        fails.append("no entity type %r is registered, but %d room(s) spawn "
                     "one: %s" % (kind, len(where), ", ".join(sorted(set(where))[:4])))
else:
    print("   %d registered types cover every spec in every room"
          % len(registered))

# ------------------------------------------------------------------
print("")
if fails:
    for f in fails:
        print("  FAIL " + f)
    print("%d problem(s)" % len(fails))
    sys.exit(1)
print("OK  the alphabet has one owner and no room argues with it")
