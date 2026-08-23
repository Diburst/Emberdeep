#!/usr/bin/env python3
"""Replace a room's map block from stdin, and nothing else.

    python3 ../scripts/setmap.py scrap_1 < newgrid.txt
    python3 ../scripts/setmap.py scrap_1 --check < newgrid.txt   # no write

The Lua editor has RoomIO.writeMap for this. This is its authoring twin,
for rewriting a room's geometry wholesale from a script rather than a
mouse -- and it uses the same rule: byte-for-byte identical outside the
grid, the file's own terminator preserved, a ragged grid refused.

--key adds entries to the room's key table at the same time, because a
new enemy character and the grid it appears in are one edit. A character
already present is left alone rather than silently redefined.
"""

import argparse
import re
import sys
import os

DIR = "src/data/rooms"
SPAN = re.compile(r"(map = \[\[\n)(.*?)(\]\])", re.S)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("room")
    ap.add_argument("--check", action="store_true", help="report, do not write")
    ap.add_argument("--key", action="append", default=[],
                    help='CHAR=spec, e.g. --key "w=welder"')
    a = ap.parse_args()

    path = os.path.join(DIR, a.room + ".lua")
    if not os.path.exists(path):
        sys.exit("FAIL no such room: %s" % path)
    src = open(path).read()
    m = SPAN.search(src)
    if not m:
        sys.exit("FAIL %s has no map block" % a.room)

    old = [r for r in m.group(2).split("\n") if r]
    new = [r for r in sys.stdin.read().split("\n") if r.strip("\n")]
    if not new:
        sys.exit("FAIL empty grid on stdin")

    w = len(new[0])
    bad = [i for i, r in enumerate(new) if len(r) != w]
    if bad:
        for i in bad[:6]:
            print("  row %d is %d wide, row 0 is %d" % (i, len(new[i]), w))
        sys.exit("FAIL refusing a ragged grid (%d bad rows)" % len(bad))

    # Reproduce THIS file's terminator: 82 rooms end the block with a
    # newline before ]] and camp_hut does not.
    trailing = m.group(2).endswith("\n")
    body = "\n".join(new) + ("\n" if trailing else "")
    out = src[:m.start(2)] + body + src[m.end(2):]

    for spec in a.key:
        ch, _, val = spec.partition("=")
        if not val:
            sys.exit("FAIL --key wants CHAR=spec, got %r" % spec)
        if re.search(r'\["%s"\]' % re.escape(ch), out):
            print("  key '%s' already defined, left alone" % ch)
            continue
        km = re.search(r"(key = \{\n)", out)
        if km:
            out = out[:km.end(1)] + '    ["%s"] = "%s",\n' % (ch, val) + out[km.end(1):]
        else:
            # no key table yet: put one directly before links
            lm = re.search(r"(\n  links = \{)", out)
            if not lm:
                sys.exit("FAIL %s has neither a key nor a links table" % a.room)
            out = (out[:lm.start(1)] + '\n  key = {\n    ["%s"] = "%s",\n  },'
                   % (ch, val) + out[lm.start(1):])

    print("  %-14s %dx%d -> %dx%d   %+d bytes"
          % (a.room, len(old[0]), len(old), w, len(new), len(out) - len(src)))
    if a.check:
        print("  (--check: nothing written)")
        return 0
    open(path, "w").write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
