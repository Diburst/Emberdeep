#!/usr/bin/env python3
"""One-shot world repair pass:
- carve shafts through floors above every bottom-edge door
- add exit doors to the two top-entry boss arenas (furn_boss, core_boss)
- seal / flood water pockets so no liquid floats or leaks
- add escape steps to spike chasms and the moss_5 basement
"""
import re

def edit(path, fn):
    src = open(path).read()
    m = re.search(r"map = \[\[\n(.*?)\]\]", src, re.S)
    rows = [list(r) for r in m.group(1).strip("\n").split("\n")]
    fn(rows)
    body = "\n".join("".join(r) for r in rows)
    src = src[:m.start(1)] + body + "\n" + src[m.end(1):]
    open(path, "w").write(src)
    print("fixed", path)

def setlinks(path, repl_from, repl_to):
    src = open(path).read()
    assert repl_from in src, (path, repl_from)
    src = src.replace(repl_from, repl_to)
    open(path, "w").write(src)

R = "src/data/rooms/"

def carve(rows, x0, x1, y0, y1, ch="."):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            rows[y][x] = ch

# ---- bottom-door shafts --------------------------------------------
edit(R + "furn_1.lua", lambda r: carve(r, 14, 16, 28, 29))     # lava -> air over exit
edit(R + "furn_6.lua", lambda r: carve(r, 14, 16, 28, 29))
edit(R + "core_4.lua", lambda r: carve(r, 14, 16, 28, 29))
edit(R + "sky_1.lua", lambda r: carve(r, 14, 16, 30, 31))
edit(R + "flood_hub.lua", lambda r: carve(r, 14, 16, 12, 14))
edit(R + "crys_5.lua", lambda r: carve(r, 6, 8, 12, 14))
edit(R + "sky_2.lua", lambda r: carve(r, 6, 8, 12, 14))
edit(R + "sky_boss.lua", lambda r: carve(r, 6, 8, 17, 19))
edit(R + "flood_deep1.lua", lambda r: carve(r, 50, 52, 21, 23))

# ---- boss arena exits ----------------------------------------------
def furnboss(rows):
    for y in (15, 16):
        rows[y][58] = "B"
        rows[y][59] = "B"
edit(R + "furn_boss.lua", furnboss)
setlinks(R + "furn_boss.lua",
    '    A = { "furn_6", "B" },',
    '    A = { "furn_6", "B" },\n    B = { "furn_3", "D" },')

def furn3(rows):
    # interior portal DD near the save statue (standing level rows 10-11)
    for y in (10, 11):
        rows[y][26] = "D"
        rows[y][27] = "D"
edit(R + "furn_3.lua", furn3)
setlinks(R + "furn_3.lua",
    '    C = { "furn_3", "A" },',
    '    C = { "furn_3", "A" },\n    D = { "furn_boss", "B" },')

def coreboss(rows):
    for y in (15, 16):
        rows[y][78] = "B"
        rows[y][79] = "B"
edit(R + "core_boss.lua", coreboss)
setlinks(R + "core_boss.lua",
    '    A = { "core_4", "B" },',
    '    A = { "core_4", "B" },\n    B = { "core_2", "D" },')

def core2(rows):
    for y in (10, 11):
        rows[y][52] = "D"
        rows[y][53] = "D"
edit(R + "core_2.lua", core2)
setlinks(R + "core_2.lua",
    '    C = { "core_2", "A" },',
    '    C = { "core_2", "A" },\n    D = { "core_boss", "B" },')

# ---- crys_1: seal the water basin from the air shaft ----------------
def crys1(rows):
    for y in range(3, 14):
        rows[y][31] = "#"
    # air shaft now cols 32-34; make sure it's open down to the ledge
    carve(rows, 32, 34, 4, 12)
edit(R + "crys_1.lua", crys1)

# ---- flood_4: seal + flood the grapple vault pocket -----------------
def flood4(rows):
    for y in (17, 18, 19):
        rows[y][43] = "#"
        rows[y][53] = "#"
    carve(rows, 44, 52, 17, 19, "~")
    rows[19][47] = "3"  # chest back in (now underwater)
edit(R + "flood_4.lua", flood4)

# ---- moss_well: honest water basin, chest underwater ----------------
def mosswell(rows):
    H = len(rows)
    W = len(rows[0])
    # rebuild rows 20..H-1 as a clean basin
    for y in range(20, H):
        for x in range(W):
            rows[y][x] = "#"
    # basin interior cols 4-25, water rows 22-27, air above
    carve(rows, 4, 25, 20, 21, ".")
    carve(rows, 4, 25, 22, 27, "~")
    # ledge with checkpoint above waterline
    for x in range(4, 9):
        rows[21][x] = "#"
    rows[20][5] = "4"        # checkpoint on the dry ledge
    # chest at the bottom of the basin
    rows[27][20] = "1"
edit(R + "moss_well.lua", mosswell)

# ---- moss_5: escape steps out of the basement -----------------------
def moss5(rows):
    # steps under each floor gap so a 2-tile jumper can climb out
    # gaps at ~cols 4-5, 26-31, 52-55 (floor row 12, basement floor 15/16)
    for (x, y) in ((6, 14), (25, 14), (32, 14), (51, 14), (56, 14)):
        if rows[y][x] == ".":
            rows[y][x] = "#"
edit(R + "moss_5.lua", moss5)

# ---- crys_3 + sky_3: climbable chasm ends ---------------------------
def chasm_steps(rows, x0, x1, floor_y):
    # staircase at both ends: replace spikes with solid + add step blocks
    for x in (x0, x0 + 1, x1 - 1, x1):
        rows[floor_y][x] = "#"
    rows[floor_y - 1][x0] = "#"
    rows[floor_y - 1][x1] = "#"
edit(R + "crys_3.lua", lambda r: chasm_steps(r, 14, 45, 15))
edit(R + "sky_3.lua", lambda r: chasm_steps(r, 12, 47, 15))

print("world repair complete")
