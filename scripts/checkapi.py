#!/usr/bin/env python3
"""Every method that is CALLED is actually DEFINED.

Run from game/:  python3 ../scripts/checkapi.py

WHY THIS EXISTS. A structural edit to world.lua replaced a slice that
reached further than intended and deleted World:zoneMended,
World:musicName and World:zoneFrozen along with the block it meant to
replace. Deleting a function is perfectly good Lua, so:

  * luac -p passed -- the file parses
  * all ten validators passed -- they are Python, they never load the game
  * the scenario suite would have caught it, but it is not run per-edit

and the first thing that noticed was the game crashing on a nil call,
several steps later, in front of Thomas.

Nothing in the toolchain asked the one question that matters after a
structural edit: is everything that gets called still there? This does,
statically, in about a second.

WHAT IT CHECKS
  * `World:foo(` anywhere in src/ resolves to a `function World:foo` or a
    `World.foo =` in world.lua
  * `self:foo(` INSIDE world.lua resolves the same way -- inside world.lua
    `self` is a World, which is what makes this checkable at all. Other
    files' `self:` belongs to their own class and is left alone.

It is deliberately not clever. A name that is only ever built at runtime
would be a false positive; there are none today, and one would be worth
knowing about anyway.
"""
import os
import re
import sys

WORLD = "src/world.lua"


def strip_comments(s):
    # Prose describing a call looks exactly like a call to a regex, and
    # this project has been bitten by that three times.
    return re.sub(r"--[^\n]*", "", s)



# ------------------------------------------------------------------
# A FILE LOCAL CALLED ABOVE ITS OWN DECLARATION
# ------------------------------------------------------------------
# `local function f` does not exist above the line it is written on. A
# call to it earlier in the file compiles perfectly -- it becomes a
# GLOBAL lookup -- and then resolves to nil the first time that path
# runs. luac -p cannot see it, because there is nothing malformed about
# calling an undeclared name.
#
# This cost a working join screen: Input.profileForKey was written above
# bindingMatchesKey and died with "attempt to call global
# 'bindingMatchesKey' (a nil value)" only when the scenario ran it.
LOCALFN = re.compile(r"^local function ([A-Za-z_]\w*)\s*\(", re.M)


def check_local_order(paths):
    bad = []
    for path in paths:
        src = open(path).read()
        code = strip_comments(src)
        decl = {}
        for m in LOCALFN.finditer(code):
            decl.setdefault(m.group(1), m.start())
        for name, at in decl.items():
            for m in re.finditer(r"(?<![\w.:])%s\s*\(" % re.escape(name), code):
                if m.start() < at:
                    line = code[:m.start()].count("\n") + 1
                    dline = code[:at].count("\n") + 1
                    bad.append("%s:%d calls local '%s' declared at line %d "
                               "-- it is nil there"
                               % (path.split("/")[-1], line, name, dline))
                    break
    return bad


def main():
    if not os.path.isfile(WORLD):
        sys.exit("run from game/ -- no %s here" % WORLD)
    wsrc = strip_comments(open(WORLD).read())

    defined = set(re.findall(r"^function World[:.](\w+)", wsrc, re.M))
    defined |= set(re.findall(r"^World\.(\w+)\s*=", wsrc, re.M))
    # fields assigned on self in load/init are not methods but are often
    # called as one (self.frost, self.room); only method CALLS are checked,
    # so this stays honest without needing to know about fields.

    calls = {}          # name -> [(file, line)]
    luafiles = ["main.lua"] if os.path.isfile("main.lua") else []
    for root, _dirs, files in os.walk("src"):
        if "rooms" in root:
            continue
        for f in sorted(files):
            if not f.endswith(".lua"):
                continue
            p = os.path.join(root, f)
            luafiles.append(p)
            for i, raw in enumerate(open(p), 1):
                line = strip_comments(raw)
                names = re.findall(r"\bWorld:(\w+)\s*\(", line)
                if p == WORLD:
                    names += re.findall(r"\bself:(\w+)\s*\(", line)
                for n in names:
                    calls.setdefault(n, []).append((p, i))

    missing = sorted(n for n in calls if n not in defined)
    print("== WORLD API ==")
    print("  %d methods defined, %d distinct methods called"
          % (len(defined), len(calls)))
    for n in missing:
        where = calls[n]
        print("  FAIL World:%s is called %d time(s) but never defined -- %s"
              % (n, len(where),
                 ", ".join("%s:%d" % w for w in where[:4])))
    unused = sorted(defined - set(calls))
    for n in unused:
        print("  NOTE World:%s is defined but never called in src/" % n)
    print("%d missing method(s), %d unused" % (len(missing), len(unused)))

    badorder = check_local_order(luafiles)
    print("== LOCAL ORDER ==")
    for msg in badorder:
        print("  FAIL %s" % msg)
    print("  %d file(s) scanned, %d bad call(s)"
          % (len(luafiles), len(badorder)))

    return 1 if (missing or badorder) else 0


if __name__ == "__main__":
    sys.exit(main())
