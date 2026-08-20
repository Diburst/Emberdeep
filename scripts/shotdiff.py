#!/usr/bin/env python3
"""Compare two runs of the screenshot-regression harness.

    EMBERDEEP_SHOTS=before love .        # in game/
    ...make the change...
    EMBERDEEP_SHOTS=after love .
    python3 ../scripts/shotdiff.py before after

Shot sets live in emberdeep/_shots/<tag>/ (gitignored), located relative to
this script rather than to the caller's cwd, so it runs from anywhere.
Override with EMBERDEEP_SHOTDIR.

Exit status is 0 when every room is pixel-identical and 1 otherwise, so a
phase that claims to be pure plumbing can be gated on it.

WHY A DEDICATED TOOL.  The scenario suite asserts on state, not pixels.
Every phase of the foundation refit is a rendering change, so the suite is
structurally blind to exactly the regressions this work can cause.  This is
the only thing that can see them.

THE SCALE IS DERIVED, NOT DECLARED.  A shot set rendered at RS=4 is
1920x1080; the RS=1 baseline is 480x270.  Comparing them means box-
downsampling the larger by 4 first.  That factor is read off the IMAGE
DIMENSIONS, because a tag is just a folder name and carries no promise
about what produced it -- the first RS=4 run in this project was written
into the tag `phase2`, straight over the RS=1 set already there, and a
tool that trusted the name would have compared two unrelated things.
Pixels cannot lie about their own size.  `--scale` remains, as an
assertion: pass it and the run fails if the derived factor disagrees.

READING THE OUTPUT.  `px` is the count of pixels that differ at all -- the
number that must be zero for a phase claiming to be a no-op.  `maxch` is
the largest single-channel delta, which separates "a sprite moved" (255)
from "a blend rounded differently" (1).  `mean` is over differing pixels
only, not over the frame, because a two-pixel change averaged across
480x270 rounds to zero and reads as success.
"""

import os
import sys
import argparse

try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("shotdiff needs pillow and numpy: pip3 install --user pillow numpy")

SHOTDIR = os.environ.get(
    "EMBERDEEP_SHOTDIR",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "_shots"))


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)


def box_downsample(a, factor):
    """Average factor x factor blocks. Exact inverse of integer upscaling."""
    h, w = a.shape[0] // factor, a.shape[1] // factor
    a = a[: h * factor, : w * factor]
    return a.reshape(h, factor, w, factor, a.shape[2]).mean(axis=(1, 3))


def derive_factor(a, b):
    """How many times bigger is b than a? +n = b is n x larger, -n = a is,
    1 = same, None = not an integer multiple in both axes."""
    (ha, wa), (hb, wb) = a.shape[:2], b.shape[:2]
    if (ha, wa) == (hb, wb):
        return 1
    big, small, sign = ((hb, wb), (ha, wa), 1) if hb >= ha else ((ha, wa), (hb, wb), -1)
    if small[0] == 0 or small[1] == 0:
        return None
    fh, fw = big[0] / small[0], big[1] / small[1]
    if fh != fw or fh != int(fh) or int(fh) < 1:
        return None
    return sign * int(fh)


def read_meta(d):
    p = os.path.join(d, "meta.txt")
    if not os.path.isfile(p):
        return {}
    out = {}
    for line in open(p):
        if "=" in line:
            k, v = line.strip().split("=", 1)
            out[k] = v
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--scale", type=int, default=None,
                    help="ASSERT the after-set is this many times larger; "
                         "fails if the images disagree")
    ap.add_argument("--tolerance", type=int, default=0,
                    help="per-channel delta to ignore; >0 only when comparing "
                         "across scales")
    ap.add_argument("--write-diffs", metavar="DIR",
                    help="write an amplified difference image per failing room")
    args = ap.parse_args()

    da = os.path.join(SHOTDIR, args.before)
    db = os.path.join(SHOTDIR, args.after)
    for d in (da, db):
        if not os.path.isdir(d):
            sys.exit("no such shot set: %s" % d)

    for tag, d in ((args.before, da), (args.after, db)):
        m = read_meta(d)
        if m:
            print("%-10s RS=%s  canvas %s  (%s rooms)"
                  % (tag, m.get("rs", "?"), m.get("canvas", "?"), m.get("rooms", "?")))
        else:
            print("%-10s no meta.txt -- predates the stamp; scale comes from "
                  "the images" % tag)
    print()

    fa = sorted(f for f in os.listdir(da) if f.endswith(".png"))
    fb = sorted(f for f in os.listdir(db) if f.endswith(".png"))

    # A missing room is a failure, not a skip. A run that silently compared
    # 12 of 31 rooms would pass just as loudly as one that compared all 31.
    problems = 0
    for f in sorted(set(fa) - set(fb)):
        print("MISSING in %-10s %s" % (args.after, f)); problems += 1
    for f in sorted(set(fb) - set(fa)):
        print("MISSING in %-10s %s" % (args.before, f)); problems += 1

    if args.write_diffs:
        os.makedirs(args.write_diffs, exist_ok=True)

    shared = sorted(set(fa) & set(fb))
    if not shared:
        sys.exit("no rooms in common between %s and %s" % (args.before, args.after))

    failed = 0
    factors = set()
    for f in shared:
        a, b = load(os.path.join(da, f)), load(os.path.join(db, f))
        fac = derive_factor(a, b)
        if fac is None:
            print("SIZE     %-28s %s vs %s -- not an integer multiple"
                  % (f, a.shape[:2], b.shape[:2]))
            failed += 1
            continue
        factors.add(fac)
        if fac > 1:
            a, b = a.astype(np.float64), box_downsample(b, fac)
        elif fac < 0:
            a, b = box_downsample(a, -fac), b.astype(np.float64)

        chmax = np.abs(a - b).max(axis=2)
        mask = chmax > args.tolerance
        n = int(mask.sum())
        if n == 0:
            print("ok       %-28s" % f)
            continue
        failed += 1
        print("DIFF     %-28s %8d px of %d  maxch %3d  mean %5.1f"
              % (f, n, mask.size, int(chmax.max()), float(chmax[mask].mean())))
        if args.write_diffs:
            amp = np.clip(chmax * 8, 0, 255).astype(np.uint8)
            out = np.zeros(amp.shape + (3,), dtype=np.uint8)
            out[..., 0] = amp
            out[..., 1] = amp // 4
            Image.fromarray(out).save(os.path.join(args.write_diffs, f))

    print()
    if len(factors) > 1:
        print("WARNING: rooms in this set were rendered at DIFFERENT scales "
              "(%s) -- the set is mixed and its result means nothing"
              % sorted(factors))
        problems += 1
    fac = factors.pop() if len(factors) == 1 else None
    if fac == 1:
        print("compared at 1:1")
    elif fac is not None:
        who = args.after if fac > 0 else args.before
        print("compared at 1:%d -- %s box-downsampled to match (tolerance %d)"
              % (abs(fac), who, args.tolerance))

    if args.scale is not None:
        want = args.scale
        got = abs(fac) if fac else None
        if got != want:
            print("ASSERTION FAILED: --scale %d, but the images say %s"
                  % (want, got))
            problems += 1
        else:
            print("--scale %d confirmed by the images" % want)

    print("%d room(s) compared, %d differing, %d problem(s)"
          % (len(shared), failed, problems))
    sys.exit(1 if (failed or problems) else 0)


if __name__ == "__main__":
    main()
