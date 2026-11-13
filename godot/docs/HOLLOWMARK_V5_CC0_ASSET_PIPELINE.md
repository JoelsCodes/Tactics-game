# Hollowmark — The Last Benediction V5: Covenant of Ash

## Build status (2026-11-13)
A **complete Google Colab notebook**, a Blender Python V5 generator, and an official-API CC0 downloader have been created and syntax-checked in ChatGPT. The downloader was tested against simulated API responses, including 15 PBR map conversions, dependency downloads, and unsafe-path rejection. **The full Blender render, actual asset API downloads, and Godot import have not yet been executed/tested.** The notebook and source package are delivered as conversation download artifacts; this GitHub commit documents the configuration rather than claiming to contain the entire notebook.

## Production target
War-torn gothic cathedral, violet-blue Crystal Vessel altar, richly detailed and emotionally grounded environment inspired by the user's HD-2D tactics screenshot. Preserve the existing **11×11 movement grid**, spawns (4,1), (6,1), objective (5,9), and visual-only NONPLAY geometry outside it.

## Verified CC0 assets (Poly Haven)
License: https://polyhaven.com/license
API terms and User-Agent/visible credit: https://github.com/Poly-Haven/Public-API/blob/master/ToS.md

- [Monastery Stone Floor](https://polyhaven.com/a/monastery_stone_floor) — gameplay flagstone
- [Old Stone Wall 02](https://polyhaven.com/a/old_stone_wall_02) — damaged limestone masonry
- [Stone Tile Wall](https://polyhaven.com/a/stone_tile_wall) — cut/carved masonry
- [Cobblestone Floor 001](https://polyhaven.com/a/cobblestone_floor_001) — damaged dark paving
- [Wood Peeling Paint Weathered](https://polyhaven.com/a/wood_peeling_paint_weathered) — roof/pew timber
- [Gothic Statue](https://polyhaven.com/a/gothic_statue) — exterior visual-only memorial model; optional if the download fails

The Colab downloader obtains official URL + MD5 from `https://api.polyhaven.com/files/{asset_id}`, downloads source maps, verifies MD5 where provided, saves modified image maps, and outputs original URL/MD5 and SHA-256 provenance. No third-party marketplace models, questionable licenses, or game-extracted assets are used.

## Pipeline changes from V4
- Real photo-scanned albedo, roughness, OpenGL normal maps feed Blender Principled BSDF in a glTF-friendly pattern.
- Retain the authored gothic kit but enrich nonplay architecture with coping stones, carved facade details, ivy, siege memorials, contained embers, and warmer light pools.
- Reduce excessive crystal emission and maintain one high-value focal altar.
- Export .blend / .glb / .png / 121-cell grid JSON / license manifest in a downloadable archive.

## Required validations
1. Run the V5 notebook in Google Colab (Run all).
2. Verify all 5 material sets download and all 15 color/roughness/normal maps are sourced.
3. Verify the model import result in V5 material manifest (do not assume it succeeded).
4. Inspect the render for gameplay occlusion, UV stretching and stone scale.
5. Import GLB in Godot 4 and inspect material normals, size, readability and FPS.
6. Commit the generated output or notebook source to a dedicated assets branch after visual approval.

Never call a syntax-checked notebook a completed/verified 3D render.
