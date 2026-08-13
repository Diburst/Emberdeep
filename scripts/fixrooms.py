#!/usr/bin/env python3
"""Normalize room map blocks: make every row the same width.

Short rows: pad with '.' inserted before the final char (or '#' if the row
is a solid wall). Long rows: trim chars before the final char.
Reports every change so nothing drifts silently.
"""
import re
import sys
import glob

def fix_map(text, fname):
    m = re.search(r"map = \[\[\n(.*?)\]\]", text, re.S)
    if not m:
        return text, []
    body = m.group(1)
    rows = [r for r in body.split("\n") if r.strip() != ""]
    width = max(len(r) for r in rows)
    changes = []
    fixed = []
    for i, r in enumerate(rows):
        orig = r
        if len(r) < width:
            need = width - len(r)
            if set(r) == {"#"}:
                r = r + "#" * need
            else:
                # insert dots before the trailing run of identical chars
                # (protects borders like "##" and door runs like "BB")
                tail = 1
                while tail < len(r) and r[-tail - 1] == r[-1]:
                    tail += 1
                r = r[: len(r) - tail] + "." * need + r[len(r) - tail:]
            changes.append(f"{fname}: row {i+1} padded {len(orig)}->{width}")
        elif len(r) > width:
            excess = len(r) - width
            r = r[: width - 1] + r[-1]
            changes.append(f"{fname}: row {i+1} trimmed {len(orig)}->{width}")
        fixed.append(r)
    new_body = "\n".join(fixed) + "\n"
    new_text = text[: m.start(1)] + new_body + text[m.end(1):]
    return new_text, changes

def main():
    total = 0
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        with open(fname) as f:
            text = f.read()
        new_text, changes = fix_map(text, fname)
        for c in changes:
            print(c)
            total += 1
        if new_text != text:
            with open(fname, "w") as f:
                f.write(new_text)
    print(f"{total} rows fixed")

if __name__ == "__main__":
    main()
