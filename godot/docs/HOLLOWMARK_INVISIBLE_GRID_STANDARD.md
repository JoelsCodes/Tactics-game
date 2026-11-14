# Hollowmark Tactics — Invisible Square-Grid Standard
**Status:** Owner-approved default for every new and revised Hollowmark tactical map (2026-11-13).  
**Applies to:** Blender authoring, Godot maps, imported scenes, previews, runtime presentation, and tactical overlays.  
**Exceptions:** Only when the owner explicitly chooses a different grid presentation or movement system.

## Core rule
> **Hollowmark uses invisible square grids: square-based gameplay underneath, handcrafted environment art on top.** The player should see a believable place, not a visible tile board.

**This is a visual presentation rule, not permission to redesign combat.** Keep the square-based movement, targeting, attack footprints, tile ranges, existing elevation rules, game rules and current map data. Do not switch to hex grids, navmesh-based free movement, or freeform targeting.

## A. Hidden gameplay layer
Maintain accurate per-cell data as the project actually defines it: grid coordinates, world-space mapping, elevation/height, walkable or blocked states, cover, terrain effects, spawn locations, objectives, interactions, and any encounter-specific rules. **Inspect the existing Godot map schema and code before adding fields**; illustrative field names are not a schema change.

- The movement data and authoritative collision/occupancy rules are independent of aesthetic meshes.
- Navigation is constrained to playable cells; non-playable outer scenery never gains valid cells merely because it has visible floor or geometry.
- The grid may be displayed through developer debugging tools, but remains hidden during normal play.
- Keep the authored dimensions for **each** map; the cathedral's 11×11 layout is specific to The Last Benediction.

## B. Continuous visual-world layer
Construct terrain, stone flooring, architecture, steps, roads, dirt tracks, grass, bridges, ruins, cliffs, rivers, trees, roofs and background as natural **continuous surfaces and structures**, not one visually separate square mesh per gameplay cell.

- Favor continuous meshes, irregular stone patterns, UVs at consistent world scale, blended materials, geometry detail, scattered props and natural edges.
- Grid-aligned data **must not** force all buildings, pathways, cracks, rivers or props to have square silhouettes.
- Avoid repeating uniform square tile seams, checkerboards, raised cube floors, and bare flat rectangles as finished art.
- Surround the battlefield with a convincingly continuous **non-playable** world, visually distinct only where natural boundaries explain gameplay.
- High-quality authoring uses modular assets and documented commercial-use rights, as required by `HOLLOWMARK_MAP_PRODUCTION_STANDARD.md`.

## C. Runtime display / overlay states
**No unit selected:** show no persistent visible tile grid, cell outlines, numbered cubes, debug markers or range overlays.

**Unit selected / movement or action being aimed:** show only relevant, temporary tactical aids—selected cell, legal destination cells, movement reach, targetable cells, affected attack footprint, and height information when actually needed. Return to seamless world presentation on deselection or action completion.

Overlays should:
- Be subtle but readable against diverse terrain, without permanently obscuring materials and characters.
- Accurately follow the true logical cells and surface height, including stair landings and elevated areas.
- Distinguish legal versus blocked/out-of-range cells with accessible visual design (not color only if possible).
- Never claim a destination is reachable when navigation says otherwise.
- Respect existing camera rules; **do not introduce battle-camera zoom** just to make overlays legible.

## D. Environmental truth and tactical readability
**The art must not lie.** Walkable surfaces should look usable; impassable terrain should have a readable physical or magical explanation; height must be apparent even when overlay is hidden.

- Walkable: open courtyard, stable bridge surface, broad steps/landing, flat stone, road or dirt path.
- Blocked: broken masonry, deep water, steep cliffs, dense impassable growth, collapsed beams, major furniture obstruction.
- Elevation: physical steps, terrace edges, retaining walls, cliff faces, appropriate railings, readable shadows and material transitions.
- Decorative clutter must never hide unit silhouettes, selection indicators or key paths in the supported tactical camera angles.
- When natural-looking irregular geometry meets a square logical boundary, resolve discrepancy with deliberate in-world visual cues or on-demand overlays, not always-on checkerboards.
- Test rotation and scrolling in every supported camera orientation; preserve authored 8-direction sprite facing and pixel presentation.

## E. Blender → Godot separation
Maintain distinct Blender scene collections/naming where possible:
- `VISUAL_PLAYABLE`: visible traversable terrain, architecture and gameplay-relevant props.
- `VISUAL_NONPLAY`: exterior/background world, atmosphere and inaccessible scenery.
- `GAMEPLAY_REFERENCE`: optional hidden/disabled visual guides used to align coordinates.
- `RENDER_HELPERS`: cameras, staging and auxiliary lights.

Export visual geometry/materials via glTF/GLB and gameplay/navigation grid data separately as supported by the current project. Do **not** assume the `.glb` carries the full tactical JSON schema, or that all Blender shaders/physics transfer to Godot unchanged. Set imported collision based on gameplay needs; exterior scenery should not unexpectedly block or create unit movement.

## F. Acceptance test (must be checked for each new map)
1. **Unselected screenshot:** no checkerboard, tiles, debug grid, floating squares or permanent range indicators; landscape feels continuous.
2. **Selected screenshot:** legal moves/attacks overlay the correct hidden cells without overpowering the environment.
3. **Path test:** unit walks/attacks according to the original square-grid combat logic, including blocked tiles, range and cover.
4. **Height test:** logical elevations and terrain steps match visually.
5. **Visual honesty test:** no apparent walkable path that is secretly blocked without clear cues; no unmarked deep gaps.
6. **Camera test:** readability, unit visibility and overlays hold across supported quarter-turn rotations and scrolling without zoom.
7. **Boundary test:** rich non-playable surroundings exist but do not create extra navigable cells.
8. **Build/export test:** source Blender scene, game data, materials, GLB and Godot import have actual checks, with clear 'not tested' labels where appropriate.

## Collaboration behavior
When building a new map, follow this standard automatically. Preserve the user's map-specific setting and grid size. Do the work when tools allow, use the checklist `godot/docs/HOLLOWMARK_MAP_RELEASE_CHECKLIST.md`, and report objective visual/gameplay verification rather than describing a blockout as complete.
