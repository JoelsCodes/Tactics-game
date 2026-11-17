"""samples/sluice_vault.json (the Drowned Reliquary, Proving Grounds 7) from the original gameplay file data/environment/sluice_vault_nav.json, which stays
byte for byte as built. The original's rows are rows[y][x] with y toward the throne; the board shows a map's row index left to right and its token index
up the screen, so the game copy is transposed (board x = original y, board y = original x) to put the throne at the back of the default view. Ramps
rise toward the throne: 'v' (+y in the original) becomes '>' (+x on the board). Spawns [x, y] become [y, x]. HollowmarkScenery places the GLB to match.
Run: python godot/tools/make_sluice_vault_map.py"""
import json
from pathlib import Path
G = Path(__file__).resolve().parent.parent
src = json.loads((G / "data/environment/sluice_vault_nav.json").read_text())
grid = [r.split() for r in src["rows"]]
turn = {"v": ">", "^": "<", ">": "v", "<": "^"}
def t(tok):
    for k, v in turn.items():
        if k in tok[1:] and not tok.startswith("v"): return tok.replace(k, v)
    return tok
rows = [" ".join(t(grid[y][x]) for y in range(len(grid))) for x in range(len(grid[0]))]
sp = src["spawns"]
sw = lambda c: [c[1], c[0]]
out = {"name": "Proving Grounds 7: The Drowned Reliquary. A flooded vault under the city: a round arena on an arcaded drum ringed by jade water, three arched bridges, raised ledges and a throne under two sluice gates.",
       "rows": rows, "spawns": {"king": sw(sp["king"]), "captain": sw(sp["captain"]), "stones": [sw(s) for s in sp["stones"]], "enemies": [{"kind": e["kind"], "at": sw(e["at"])} for e in sp["enemies"]]},
       "scenery": "sluice_vault", "level_height": src["level_height"], "floor_base": src["floor_base"], "shadows": True, "prelit": True}
(G / "samples/sluice_vault.json").write_text(json.dumps(out, indent=1) + "\n")
print("rows", len(rows), "x", len(rows[0].split()))
