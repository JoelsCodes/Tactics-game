# Hollowmark Environment Library

The library root is `Documents/Hollowmark/Environment_Library`. The desktop install contains six native assets, the scanned and packed maps, previews, the asset manifest and a test scene. Git tracks the tools, manifest and instructions. Keep large Blender files and texture images in the versioned library bundle.

## Install and index

Extract the library archive under `Documents/Hollowmark`. Register the extracted root in Blender 4.x from the repository root. On Windows, pass the full path to `blender.exe` if it is outside PATH.

```text
blender -b --python-exit-code 3 -P godot/tools/environment/kit.py -- "<library>" --register-only
python godot/tools/environment/envlib.py search "<library>" arch --tag gateway
python godot/tools/environment/envlib.py search "<library>" stairs --fits 5 4 2.2
```

Asset Browser displays **Hollowmark Environment Library** after Blender reloads its preferences. Architecture and terrain are collection assets. Position these in metres at their documented origin. The limestone is an image-backed Principled material. Categories reserve room for Nature, Water, Map_Templates and Scripts. A fresh build of the same kit uses the included baked maps and `kit.py`; keep existing asset revisions and their evidence together. `previews.py` embeds an actual Cycles preview per asset.

Search returns REUSE, ADAPT or CREATE. Match the reference, required tags, dimensions and footprint. Existing map-wide objects can inform an adaptation. Use `Production Ready` for assets with visual evidence, an actual Godot import, and documented rights. Asset review can load `Needs Improvement` assets. A playable build requires `Production Ready` for every new library placement and rejects prototypes in either mode.

## Map brief and build

Use `showcase.json` as a placement example. Put the supplied reference beside the brief or update the paths. Record the composition and construction relationships in `reference_read`. The tool hashes those inputs and records placement decisions. It does not design combat, infer coordinates from an image, or make art decisions on behalf of the reviewer.

For a real map use `mode: battle_map` and point `navigation` to the original Hollowmark JSON with `rows`. Preserve the data byte for byte. Existing map-specific navigation adapters stay in their own integration code. Set `existing_blend` and `export_collections` for a revision. The tool opens the original master and saves a separate copy with the existing camera and lights. Set placements by asset ID, layer, XYZ location and optional yaw. New scenes use the camera brief. Set map-authored `godot_probes` at gameplay locations in engine coordinates. Blender (X,Y,Z) maps to Godot (X,Z,-Y).

```text
blender -b --python-exit-code 3 -P godot/tools/environment/assemble.py -- "<library>" "<brief.json>" "<new-output>"
godot --headless --path godot --script res://tools/environment/check_import.gd -- "<new-output>"
godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x840 --script res://tools/environment/check_import.gd -- "<new-output>"
```

Open the Blender and Godot previews side by side. The visual collections are separate from authoritative gameplay. GLB exports selected visual meshes at metre scale with evaluated modifiers, tangents, embedded albedo, roughness and normal maps. The checker measures bounds and looks at imported materials, surface UVs, tangents, and supplied collision probes. The windowed run writes a same-camera capture and a frame-time sample for that machine. The harness uses temporary collision and lighting for inspection. Game collision, local to world offsets, camera behavior and special effects remain map integration responsibilities.

## Review and release

Use the official release checklist. Save the three highest-impact visual faults, the revision that addressed them, and the final visual verdict against the reference in the map's review JSON. Retain preview hashes in that record. Capture unselected and selected gameplay, test paths/elevation/spawns/objectives/overlays, and verify supported camera turns and target hardware performance inside the deployed battle. Water, emissive effects, alpha, particles and baked lighting need visual review in Godot when present.

`review.template.json` starts each gate open. Copy the `files` object from the accepted `build.json`, set evidence paths or links, then run:

```text
python godot/tools/environment/envlib.py package "<new-output>" "<review.json>" "<new-release.zip>"
```

Packaging checks the five gates, the current GLB, the actual Godot frame and build hashes. Archive only a signed-off battlefield. There is no battlefield release for the current asset-review showcase.

## Library installation status

The library is installed and registered on the Work host. On another machine extract and register it using the command above. The showcase uses five geometry modules and honed limestone. It is an art and import review, with no scripted encounter or fabricated navigation. See `asset_manifest.json` and the library showcase validation for exactly what qualified. Use the stable bundle link in the repository production instructions for restored sessions.

## Existing map adapters

For The Last Benediction, retain both the in-game rows and the original `data/environment/last_benediction_nav.json`. Run the repository's existing `check_nav.py` against its own GLB when reviewing that map. `inspect_glb.gd`, `inspect_materials.gd` and `inspect_scenery.gd` remain useful diagnostics for legacy imports. The general checker complements them with pinned build hashes, the same-camera render and explicit probes.

## Reviewing a kit revision

`previews.py -- "<library>" --details "<output>"` renders the same fixed views of each module. It evaluates the limestone on a one-to-one scale sample under neutral and grazing lights. Run it on both revisions when comparing the kit. The optional `limestone_maps.py` uses Pillow and NumPy outside Blender to regenerate the packed JPEGs from the original Rock 01 scan shipped under `Materials/Textures/Rock01_Source`.

```text
python godot/tools/environment/limestone_maps.py "<library>/Materials/Textures/Rock01_Source" "<library>/Materials/Textures/Limestone"
blender -b --python-exit-code 3 -P godot/tools/environment/previews.py -- "<library>" --details "<review-output>"
```

An exterior cliff placement can use `terrain_fit` to fit one connected foundation beneath multiple terraces. Set `span_scale` for width and length, `rear_flare` for the fractional widening of the upper shelf, and `rise_m` for its height change. Set `rise_limits_m` to the two local Y positions after length scaling. The fit recalculates UVs in metres. Check a fitted shelf against actual walking surfaces before approving it.

## Cut-stone terrace kit release

Revision 04 qualifies the six native assets for reuse in straight cut-stone terraces and fitted rock foundations. The unchanged asset IDs now return REUSE. Bake the weathered bedrock grade alongside the limestone by adding `--bedrock "<library>/Materials/Textures/Rock051"` to the material command. In an exterior wall placement, `wall_span_m` permits a 2.55–4 m bay with metre-scaled UVs. Set `compact_module_surfaces` for new built scenes to combine compatible surfaces in each placement during GLB export. The Blender source retains its independently editable parts.
