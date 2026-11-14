# Hollowmark Tactics — New Map Production & Release Checklist

**Use for every new map and every meaningful visual update.** Copy this checklist into the map's task/PR/issue and mark [x] only when checked. An untested claim is not a pass.

**Required reading before starting**
- `CLAUDE.md` — owner's existing game rules (do not undo)
- `AGENTS.md` — shared collaboration, tests, commits
- `godot/HANDOFF.md` and `godot/README.md`
- `godot/docs/HOLLOWMARK_MAP_PRODUCTION_STANDARD.md`
- `godot/docs/HOLLOWMARK_INVISIBLE_GRID_STANDARD.md`
- Map-specific brief, actual grid source and relevant story canon

## 1. Map brief, game data and boundaries
- [ ] Confirm map name, location, atmosphere, gameplay objective and current user reference.
- [ ] Read actual grid file/schema and existing Godot scenes; record this map's unique width, length, elevation and mechanics.
- [ ] Preserve square-grid movement, targeting, attack footprints, collision, objectives, spawns and existing rules.
- [ ] Verify reachable paths, blocked cells and elevation constraints before visual work.
- [ ] Identify the non-playable visual background and keep it separate from valid tactical cells.

## 2. Invisible square-grid contract
- [ ] **No tile checkerboard or obvious square-by-square segmentation in normal gameplay.**
- [ ] Visual surfaces flow across logical cells as continuous roads, masonry, grass, floor or terrain.
- [ ] Buildings, trees, rivers, terrain boundaries and props follow natural forms; not arbitrarily tile-shaped.
- [ ] Game logic remains a hidden square grid, independent of rendered meshes.
- [ ] No unit selected: zero visible grid, debug markers or permanent ranges.
- [ ] Unit selected/aiming: only temporary, accurate and readable move/target/selected-cell overlays.
- [ ] Walkable areas *look* walkable; impassable areas have physical visual justification.
- [ ] Elevation communicates via stairs, ledges, retaining walls, cliff faces and appropriate shading.
- [ ] Visual exterior/non-playable surroundings cannot be selected as movement destinations.
- [ ] Check visual readability, overlays and character occlusion across all supported quarter-turn camera angles; **no battle-camera zoom**.

## 3. Environment quality
- [ ] Composition: readable tactical lanes and intentional focal point(s), not random decoration.
- [ ] Architecture: coherent scale, realistic structural support, strong silhouettes and appropriate details.
- [ ] Terrain: natural intersections and edges; no bare floating board unless intentionally approved.
- [ ] Materials: world-scale UVs, rich but consistent PBR maps; no obvious stretching or repetitive seams.
- [ ] Lighting: mood and contrast support legibility, with restrained emissions.
- [ ] Environmental storytelling: meaningful props, believable wear, appropriate vegetation/debris.
- [ ] Non-playable background: supports depth/continuity without obstructing units and objectives.
- [ ] Object detail is purposeful, not simply increased polycount or clutter.

## 4. Asset rights and provenance
- [ ] Source each external model/texture/HDRI from a verified commercial-use license (prefer CC0).
- [ ] No game-ripped, 'personal use', non-commercial or uncertain assets.
- [ ] Keep per-map `ASSET_LICENSES.json` with source URL, asset name, license/license URL, filenames, and attribution if needed.
- [ ] Record checksums/download metadata when possible; use the owner's screenshots as inspiration, not copied assets.

## 5. Blender technical checks
- [ ] Re-open saved `.blend` and confirm textures are packed or all relative paths resolve.
- [ ] Material Preview and actual camera render show intended textures, colors and lights.
- [ ] Review tactical camera views for pillars/roofs blocking units; configure fades/hides where necessary.
- [ ] GLB exported with supported PBR textures, correct scale and transforms.
- [ ] Keep nonplayable scenery collection and gameplay reference collection clearly named and separated.

## 6. Godot technical checks
- [ ] Import `.glb` into the actual Godot project; inspect materials, normals, texture paths and scale.
- [ ] Verify authoritative navigation data rather than inventing a replacement JSON schema.
- [ ] Test a unit moving, attacking, aiming, targeting and traversing different elevations.
- [ ] Verify selection overlays appear only when appropriate and track the real world-space cells.
- [ ] Validate collision/cover on gameplay objects; non-playable scenery does not create walkable cells.
- [ ] Test the existing camera rotations/scrolling, sprite orientation, unit visibility, and no zoom.
- [ ] Measure performance or clearly label it unmeasured.

## 7. Deliverables and honest completion
- [ ] Deliver editable source project `.blend` and any generator scripts.
- [ ] Deliver `.glb`, plus actual gameplay/navigation metadata if relevant.
- [ ] Deliver *actual* preview screenshots/renders (not merely conceptual references).
- [ ] Deliver license manifest and concise README detailing dependencies, scale and known issues.
- [ ] Compare resulting render against the owner's high-quality tactical RPG reference and improve obvious failures.
- [ ] Update `godot/HANDOFF.md` and use a focused Git commit; avoid overriding other agents' work.
- [ ] In final response, say what was built, what passed validation, what remains untested, and the smallest next action if necessary.

## Final gates
**ART:** looks like a handcrafted, believable place without visible grid tiles.  
**TACTICS:** square-grid logic and readability work under the art.  
**ENGINE:** scene loads with correct assets/lighting/collision and acceptable measured performance.  
**RIGHTS:** all third-party content is legally usable and documented.  
**DELIVERY:** reproducible editable project and verified render/export, with known limitations listed.

If any gate cannot be tested, mark **NOT TESTED**, not complete.
