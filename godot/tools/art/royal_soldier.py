#!/usr/bin/env python3
"""The royal soldier (sheet `royal_soldier`, Nov 2026): 128x128 frames in the King's layout, four directions.
Idle 1 frame, walk 6, attack / hit / cast / ko 8 each, a painted portrait. The cut sheets in
art_src/characters/royal_soldier/ (one row per direction s, e, n, w; 128 px cells) are the source: this slices
them into assets/characters/royal_soldier/ and writes the "royal_soldier" entry of meta.json (nothing else in the file
is touched). Then: godot --headless --import and tools/build_resources.gd -- only=royal_soldier.
He is drawn with the flat ORIGINAL look: under Alaric's HYBRID lighting his pale helmet burned out to white.
"""
import json, re, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art_src/characters/royal_soldier"
OUT = ROOT / "assets/characters/royal_soldier"
NAME, DIRS = "royal_soldier", "senw"
# kind: (frames, fps, loop)
KINDS = {"idle": (1, 4, True), "walk": (6, 8, True), "attack": (8, 14, False), "hit": (8, 10, False),
         "cast": (8, 10, False), "ko": (8, 10, False)}
STRIKE = {"attack": {"s": 3, "e": 3, "n": 4, "w": 3}, "cast": dict.fromkeys("senw", 5)}  # the back swing lands a frame later

files = {}
for kind, (n, _, _) in KINDS.items():
    sheet = Image.open(SRC / f"{kind}_sheet.png").convert("RGBA")
    assert sheet.size == (128 * n, 512), (kind, sheet.size)
    (OUT / "animations" / kind).mkdir(parents=True, exist_ok=True)
    for r, d in enumerate(DIRS):
        files[kind, d] = []
        for i in range(n):
            rel = f"animations/{kind}/{kind}_{d}_{i}.png"
            sheet.crop((i * 128, r * 128, i * 128 + 128, r * 128 + 128)).save(OUT / rel)
            files[kind, d].append(rel)
(OUT / "portraits").mkdir(parents=True, exist_ok=True)
shutil.copyfile(SRC / "portrait.png", OUT / "portraits/portrait_01.png")

anims = {}


def add(name, kind, d, fps=None, loop=None):
    n, f, lp = KINDS[kind]
    a = {"dir": d, "fps": f if fps is None else fps, "loop": lp if loop is None else loop,
         "frames": files[kind, d], "native": "none"}
    if kind in ("attack", "cast", "hit", "ko"):
        a["strike"] = STRIKE.get(kind, {}).get(d, -1)
    anims[name] = a


for d in DIRS:
    for kind in KINDS:
        add(f"{kind}_{d}", kind, d)
    add(f"run_{d}", "walk", d, fps=12)
    add(f"dash_{d}", "walk", d, fps=14)
    add(f"heavy_{d}", "attack", d)
for kind in ("attack", "cast", "hit", "ko"):
    add(kind, kind, "s")
add("heavy", "attack", "s")
add("victory", "idle", "s")
for alias, d in (("f", "s"), ("b", "n")):
    for kind in ("idle", "walk", "hit"):
        add(f"{kind}_{alias}", kind, d)
    add(f"ready_{alias}", "idle", d)

meta_path = ROOT / "assets/characters/meta.json"
text = meta_path.read_text(encoding="utf-8")
base = json.loads(text)["hooded_cutthroat"]
entry = {"size": [128, 128], "anchor": [64, 112], "scale": 1.15, "eight_dir": True, "slash_in_frames": False,
         "portrait": "portraits/portrait_01.png", "portraits": ["portraits/portrait_01.png"], "anims": anims}
for k in ("effects", "effects_from"):
    if k in base:
        entry[k] = base[k]
block = json.dumps({NAME: entry}, indent=2)[1:-1].strip("\n")
start = text.find(f'\n  "{NAME}": {{')
if start >= 0:  # replace the old block, up to the next top-level entry (or the end of the file)
    nxt = text.find('\n  "', start + 1)
    if nxt >= 0:
        text = text[:start + 1] + block + ",\n" + text[nxt + 1:]
    else:
        text = text[:start].rstrip().rstrip(",") + ",\n" + block + "\n}\n"
else:
    text = text.rstrip()
    assert text.endswith("}")
    text = text[:-1].rstrip() + ",\n" + block + "\n}\n"
json.loads(text)
meta_path.write_text(text, encoding="utf-8", newline="\n")
print("wired", NAME, len(anims), "animations")
