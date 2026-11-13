# Hollowmark Tactics — V4 Ash & Amethyst

## Status
Complete source and Google Colab notebook generated in ChatGPT on 2026-11-13. Python scripts compile; procedural PBR textures were generated and visually inspected. **Blender render and Godot import are pending user-run Colab validation.** The source package and notebook are conversation artifacts; the full generator has not been committed to GitHub in this change.

## Creative direction
The Last Benediction: war-torn cathedral overtaken by violet-blue crystal ruins. 11×11 tactical grid remains unchanged (121 cells); ancient Vessel altar at (5,9), spawns (4,1),(6,1). Non-playable environment extends world silhouette but is excluded from navigation/collision metadata.

## New V4 pipeline
1. Procedurally generate 512×512 raster PBR basecolor, roughness, and tangent-space normal maps in Python for **limestone, flagstone, sootstone, timber, and rubble**. No external downloads or licensing dependencies. The maps are synthetic, not photogrammetry.
2. Import maps into Blender via Principled BSDF image nodes and Normal Map node; UV-scale box meshes to physical dimensions for more consistent texel density. Pack images into .blend and export mapped GLB.
3. Enhance modular gothic architecture: courses of ashlar masonry, tower surface detail, pointed lancet windows, tracery and remnants of stained glass.
4. Add war narrative: smashed stone, funeral banners, damaged pews, siege gate debris, memorial marks and shattered roof silhouettes.
5. Keep exterior crystal blight darker and less emissive than the altar to maintain focal hierarchy. Use cooler lighting and a stronger 2048×1536 orthographic preview.
6. Export .blend, .glb, PNG preview, 11×11 navigation JSON, material manifest and texture atlas ZIP.

## Production checklist after Colab render
- Confirm all 121 unique grid coordinates and blocked cells.
- Compare silhouette and readable lanes to V3; fix occlusion and z-fighting.
- Import GLB into Godot 4 and verify texture/normal maps, transparent material behavior, shadows and scale.
- Add dedicated collision for playable surfaces only; no collision for NONPLAY scenery.
- Profile object count/draw calls and eventually batch repeated meshes or use instances.
- Use authored CC0 real PBR assets where appropriate; validate license and scale.

See the standing [environment bible](HOLLOWMARK_BLENDER_ENVIRONMENT_BIBLE.md) for broad art direction and architecture research.
