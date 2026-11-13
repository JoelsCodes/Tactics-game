# Hollowmark Tactics — Blender Environment Bible (v1)

## Core art direction
**The Last Benediction**: small 11×11 tactical diorama of a war-torn ruined gothic cathedral overtaken by violet-blue crystal growth. A surviving ancient Crystal Vessel altar is the emotional focal point. Cold desaturated limestone, fractured slate, ash, restrained violet emission, and selective warm memorial accents. Combat readability outranks decorative clutter.

## Lessons from Blender procedural-modeling research and Colab prototypes
1. **Layout first**: establish tile topology, elevation, lanes, objective, and spawn cells before scenery.
2. **Make modular, plausible architecture**: reproducible gothic pointed arches, columns, capitals, buttresses, tracery, windows and nave walls. Damage should follow structural logic, not random fragmentation.
3. **Separate gameplay and world art**: the 11×11 grid defines gameplay; scenery outside its bounds is non-playable, non-pathable, and has no automatic collision. Blender's `NONPLAY | World beyond battlefield` collection groups outer scenery.
4. **Keep the focal hierarchy**: brightest altar, readable battlefield, subdued surrounding environment. Crystal clusters should not all glow equally.
5. **Deterministic content**: fixed random seeds, named collections, repeatable mesh generation, explicit nav JSON, Godot GLB export, and orthographic preview renders.
6. **Godot readiness requires validation**: glTF import, material fidelity, draw calls, tile visibility, collision/navigation, elevation transitions, and real battle camera; a Blender render alone is not proof.
7. **Performance**: instance and batch repeated architectural elements/rubble as the prototype matures. Keep visual and collision meshes separate.

## V3: World Beyond the Tiles
Extend the **visual world only** with a devastated rear apse, collapsed transept wings, flying buttresses, ruined bell towers, shattered rose-window tracery, roof debris, war memorial stones, ash, and low-emission crystal blight. Maintain low foreground scenery to avoid occluding the combat view. The 11×11 tile JSON remains unchanged in scope; exterior meshes are exported as visual GLB geometry.

## Reference research
- https://github.com/dottyboy/BlenderLevelArchitect
- https://github.com/DLR-RM/BlenderProc
- https://github.com/KhronosGroup/glTF-Blender-IO
- https://docs.blender.org/api/current/

## Next steps
Run the V3 Colab notebook, inspect render and GLB, check 121 tile positions, review sightlines, then iterate on materials, architectural silhouette, geometry batching, and Godot integration.
