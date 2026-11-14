# Hollowmark Tactics — Map Production Standard
Version 1.0 · Shared instructions for Claude Code, ChatGPT Work, and environment-building agents

> **Scope:** EVERY new or revised Hollowmark battlefield, town, dungeon, castle, shrine, or cinematic environment. **Not limited to The Last Benediction.**
> **Priority:** The owner's explicit instructions and current map brief override generic defaults. Existing gameplay, story canon, map data, and code must be inspected and preserved before editing.

## The mission
Build Hollowmark Tactics maps that look and feel like **handcrafted, premium fantasy tactical RPG environments**, not beige checkerboards, cubes, or standalone floating platforms. Our quality benchmark is the owner-provided detailed isometric tactical RPG village screenshot: believable cobblestone, roofs and architecture, elevation and retaining walls, dense but intentional environmental dressing, warmth from lanterns/torches, vegetation, natural transitions into surrounding scenery, and instantly readable gameplay. **Use as art-direction inspiration, never reproduce copyrighted artwork/assets.**

### Map-specific direction vs universal standards
- Universal: visual/gameplay separation, believable material richness, modular high-quality architecture, strong lighting/composition, clear tactical readability, verified licensing, optimization, and proof of actual render/import.
- **The Last Benediction only**: 11×11 playable grid; ruined gothic cathedral overtaken by violet-blue crystals; a surviving Vessel altar; war-torn, tragic, sacred mood; reference spawns (4,1)/(6,1) and altar (5,9) only where supported by its actual navigation data.
- **Other/new maps:** obtain dimensions, theme, combat requirements, story context and existing grid by reading the current map's source or user brief. **Do not force 11×11, cathedral scenery, or violet crystals onto unrelated maps.**
- Respect existing campaign maps, movement and elevation rules, story content, and enemy/collision setup. Do not rewrite established gameplay to accommodate visuals without authorization.

## Nonnegotiable two-layer architecture
**Gameplay layer**: map dimensions, grid coordinates, height levels, valid paths, obstacles/cover, spawns, objective markers, collision and navigation; typically invisible in the final render, visible via debug overlay only.

**Visual layer**: Blender scene meshes, richly textured floors, architecture, ruins, roofs, props, vegetation, weather, particles, lighting, exterior/background world; it must feel like a physical location. Non-playable decorative scenery has **no default nav cells** and must not obstruct the tactical camera or create confusing false paths.

**Never show debug tile cubes/markers as the final environment.** A clear blockout is a valid engineering artifact but never a production-art deliverable. Preserve map semantics while replacing blockout visuals with integrated world geometry.

## Art-direction and modeling standards
1. **Composition before decoration**: identify playable lanes and elevation and one or two visual focal points; frame them with buildings, cliffs, distant scenery. Favor a readable isometric/orthographic tactical camera. Keep foreground objects from blocking the player's view (hide/fade/occlude appropriately).
2. **Architecture**: use proportionally believable structures, considered silhouettes and modular reusable kits: lintels, pitched roofs, stair landings, masonry courses, arches, columns, buttresses, damaged supports, and joins. No obvious isolated primitive cubes/cones as finished structural assets.
3. **Terrain**: surfaces vary in elevation, weathering and edge transitions, with retaining walls, stairs and paths that make heights obvious. Playable terrain must blend into non-playable outskirts instead of appearing on a detachable plinth, except if art direction explicitly calls for a diorama.
4. **Materials**: choose high-quality physically-based stone, tile, soil, plaster, wood, metal, fabric and rock materials. Maintain proper texel density, consistent scale, albedo/roughness/normal maps, suitable UVs, grime and edge wear. Avoid uniform color and stretched/repeated textures. Blender shaders must be exported/baked into Godot-compatible PBR where required.
5. **Lighting**: intentional warm/cool color relationships and controlled luminance hierarchy; deep shadows with legible combat positions; practical light sources and restrained emission. Evaluate in the actual tactical camera and Godot renderer, not only a beauty shot.
6. **Props and atmosphere**: dense where story supports it, but not random clutter. Use damaged roofs, rubble, fences, banners, plants, lanterns, debris and history-specific details. Decorative objects must not hide units or suggest false walkable areas.
7. **Crystal or magical elements only where appropriate**: natural embedded growth, varied silhouette, limited glow. Don't default to glowing cones.
8. **Performance**: instancing, LOD when appropriate, texture budgets, sensible polygon counts, draw-call profiling, collision separation, culling and Godot compatibility; optimize from measured results.

## Licensed asset sourcing
- Prefer **Poly Haven** and **ambientCG** assets with explicit verified **CC0** license allowing commercial use and redistribution. Exact selected asset URLs and license should be validated before use; never assume an arbitrary web model is reusable.
- Other sources require explicit verified commercial rights, no share-alike incompatibility with distribution plans, and correct attribution when required.
- No ripped game models, no non-commercial/personal-only assets, and no unverified marketplace files.
- Maintain **ASSET_LICENSES.json** or equivalent manifest per map with asset title, author/provider (if known), source URL, exact license name and URL, download date, local filename and use. Keep original downloaded files where practical and checksums when available.
- The owner's quality-reference screenshots are **visual targets, not licensed assets to import**.

## Required map delivery structure
Keep current project's existing conventions if they differ. An ideal map package has:
- `<map>.blend` — editable master scene with packed or reliably relative-linked assets
- `<map>.glb` — visually compatible engine asset
- `<map>_navigation.json` — actual gameplay grid, elevations, blocked cells, objectives and spawns where supported; do **not invent** missing data
- `<map>_preview.png` — an actual render of the current scene
- `ASSET_LICENSES.json` — provenance and permissions
- `README.md` — scale, coordinate mapping, setup, tested status, known issues
- Source scripts and any asset dependency instructions (if generator-based)
Do not claim a .blend, screenshot or JSON exists without checking the delivered path. A .glb is visual scene geometry, not a replacement for grid metadata.

## Quality gates — don't confuse progress with success
1. **Inventory**: inspect repo project, existing map, and dependencies; identify exact map and gameplay constraints. Read `CLAUDE.md`, `AGENTS.md`, `godot/HANDOFF.md`, `godot/README.md`, and relevant environment docs.
2. **Benchmark**: inspect owner reference and current best screenshot; define what quality difference the next implementation must close. For existing maps, do not discard better authored art in favor of a fresh blockout.
3. **Construct**: use real reusable architecture, licensed source materials/models, careful modeling, correct material maps and cinematic but readable lighting.
4. **Render & inspect**: make an actual camera render. Inspect scene as a whole and close-up; identify weakest visual elements and fix those, rather than indiscriminately adding objects.
5. **Validate gameplay**: grid coordinate count, unique tiles, elevation, reachability, objectives, spawns, cover and occlusion; keep cosmetic exterior out of nav layer. Do not alter grid without cause.
6. **Validate Godot**: import glTF, verify textures/materials, scale, collision rules, draw calls/FPS and tactical readability in-engine. If not executed, clearly say not tested.
7. **Communicate and commit**: link output, state what changed and was *actually verified*, track remaining caveats, and update `godot/HANDOFF.md`. Don't call unfinished blockout final or claim local PC access without an actual test.

## How to talk and collaborate with the owner
- Be **warm, energetic, direct, creative and conversational**, like a committed game-making partner. Use plain language; do not sound like a corporate status report.
- Propose strong art decisions independently; don't repeatedly ask for preferences already stated, and don't require approval for routine choices.
- **Do the work** when files/tools permit: inspect, change, render, test, troubleshoot and provide artifacts. Don't replace implementation with elaborate plans.
- Be candid: mention when there is no access to the user's PC, no completed render, missing files, missing textures, or a Godot import you haven't verified. Do not claim ongoing background work unless a job/automation was actually started.
- Focus on **high-quality first complete implementations** with focused polish after inspection; avoid endless V1/V2/V3 iterations of basic primitives. Reject beautiful-but-unplayable scenes and functional-but-ugly beige blockouts as final deliveries.
- Explain the smallest next action only when user intervention truly is needed.

## Further project references
- `godot/docs/HOLLOWMARK_BLENDER_ENVIRONMENT_BIBLE.md` — Last Benediction style-specific Blender lessons
- `godot/docs/HOLLOWMARK_V4_ASH_AND_AMETHYST.md`
- `godot/docs/HOLLOWMARK_V5_CC0_ASSET_PIPELINE.md`
- `godot/STORY_CANON.md` — if map connects to story or characters
- https://polyhaven.com/license
- https://docs.ambientcg.com/license/

## Quick prompt for any new map
> Read `godot/docs/HOLLOWMARK_MAP_PRODUCTION_STANDARD.md` and the repo handoff before building this map. Treat its existing gameplay metadata as authoritative. Produce a premium, readable, richly detailed environment with full non-playable surroundings, legally reusable assets, a proper Blender master, a Godot GLB, navigation data and verified preview. Show actual work and test results, not a simplified placeholder. Use the owner's instructions to decide this map's unique setting and size.
