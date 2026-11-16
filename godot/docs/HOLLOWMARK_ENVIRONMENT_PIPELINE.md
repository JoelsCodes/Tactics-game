# Hollowmark Blender Environment Pipeline

Use this workflow for every new or revised environment. Read the map production standard, invisible grid standard and release checklist first. Keep the actual map data and existing battle behavior authoritative.

## Library installation

Install the versioned [Hollowmark Environment Library v0.1.0](https://chatgpt.com/library?file_id=libfile_97b909f8c87081918934a77c89090947&account_id=personal) under `Documents/Hollowmark/Environment_Library`. On a new machine or Work workspace, extract it and register the folder using [the tool README](../tools/environment/README.md). The archive holds the native Blender assets, texture sources, license evidence and actual review exports. Git holds the source tools and [the matching asset manifest](../tools/environment/asset_manifest.json).

## Each environment session

1. Read the supplied reference and authoritative map data. Record the largest relationships that matter to silhouette, structure, terrain, materials and camera readability.
2. Search the asset manifest. Pick REUSE when an approved asset matches the brief and dimensions. Pick ADAPT when an existing asset is a sound starting point. Pick CREATE when a new design can meet the reference more convincingly. Make adaptations as new versioned assets, with clean origins, metre-scale dimensions, packed image maps, previews and evidence.
3. Keep visible surfaces continuous, with separate playable art, exterior art, hidden guides and camera helpers. Keep the original geometry alignment, gameplay JSON and camera rules. Keep collisions and effects tied to their actual engine integration.
4. Render from the tactical camera, review the three largest visible issues against the reference and fix the underlying design. Save the review and paths to its images. Require actual import and runtime review with the checklist. Validate terrain alignment, depth and overlays across the supported camera views and measure performance on the intended hardware.
5. Publish a production map only after its art, tactics, engine, rights and delivery evidence pass. Update the manifest only when an actual visual review and Godot checks justify the new status. Update the versioned bundle and Git manifest together. Keep large binaries outside Git.

## Pilot evidence

The kit includes wall, gateway, staircase, escarpment, limestone and court candidates. All six reopen as marked native assets with thumbnails. The Gate Terrace asset-review GLB and isolated gateway/staircase GLBs imported in the Hollowmark checkout with Godot 4.6.3. The main scene passed three surface probes and had a windowed same-camera capture. The asset review remains below the art target, and the fixture has no playable encounter. All six candidates retain **Needs Improvement**. Untested gates include battle wiring, runtime effects, supported camera rotations and target hardware performance. See the library's review and reports for detail.

## Refinement 02

The existing bundle link now points to the refinement of the same six candidates. The updated kit and archive contain fixed-camera comparisons, detailed module renders, neutral and grazing limestone tests, and the corresponding GLB validation. The in-project review passed four isolated asset imports, nine stair tread probes, six showcase surface probes, and the 749 existing board assertions. The six candidates remain **Needs Improvement**. Repeated bay caps, angular cliff contacts and tonal uniformity remain visible against the supplied reference.
