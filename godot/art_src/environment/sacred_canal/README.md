# Sacred Canal Bridge (owner's Blender export, Nov 2026)
- `sacred_canal_bridge.glb`: the visual mesh (143 meshes, 70 MB). Loaded at battle start by `SacredCanalScenery`.
- `../../data/environment/sacred_canal_nav.json`: the owner's navigation file (160 cells: bridge 6x20, gate landing 10x4). Nav coordinates: x = bridge width, y = toward the gate; world = (x-2.5, y+0.5, 3.5) in Blender (Z up), which is glTF (x-2.5, 3.5, -(y+0.5)).
- `ASSET_LICENSES.json`, `VALIDATION.json`: from the owner's package (Poly Haven / ambientCG CC0 sources, original authored geometry).
- The `.blend` master (50 MB) and the generator scripts stay in the owner's package folder (`Sacred_Canal_Structural_Final.zip`), not in the repo.
- `owner_standalone_review.png`: the owner's own standalone Godot render (not a Hollowmark render).
