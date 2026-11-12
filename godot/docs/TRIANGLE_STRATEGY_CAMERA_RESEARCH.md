# Triangle Strategy-style camera research — Hollowmark Tactics
Research recorded 2026-11-12. **Exploratory design proposal, not authorization to implement or change the owner's existing fixed-camera rules.** Claude and ChatGPT: read root `CLAUDE.md`, `AGENTS.md`, `godot/HANDOFF.md`, and `godot/README.md` before touching the game.

> **Owner decision (Nov 2026): no zoom.** Step 6 of the design and milestone 4 below are dropped; the camera distance and lens stay fixed in every experiment. Note for whoever builds the rest: quarter-turns (`Board3D.rotate_view`) and camera-relative sprite facing (`Board3D.screen_dir`) already exist in the code; the open problems are keys (Q / E turn the unit), wide scrolling maps, the left-to-right battle rule and occlusion from the back.

## Goal
Explore a Triangle Strategy-like camera for Hollowmark's 3D diorama board with pixel-art characters: turn the view around the map, move across large maps, and possibly zoom without flattening, stretching, leaning, clipping, or changing sprite-facing direction incorrectly. Preserve original pixel crispness, feet alignment, size consistency and art approval. Start as an isolated opt-in prototype that can revert to the current framing.

## GitHub references and source inspection
- Official Godot 3D sprite demos: https://github.com/godotengine/godot-demo-projects/tree/master/3d/sprites . Refer to Sprite3D/AnimatedSprite3D billboard rendering and fixed-Y vs camera-facing behavior; verify Godot version.
- Project Tactics: https://github.com/Project-Tactics/Project-Tactics — `src/Apps/Samples/Component/CharacterFacing.cpp` maps a camera quarter-turn into the sprite's facing (some directions mirrored); use as an architectural example, **not** as a reason to mirror Hollowmark's owner-drawn eight-way sprites.
- Iso & Orbit Godot: https://github.com/Maxwell-M1/iso_and_orbit_godot — research lead for orbit-camera controls and easing; inspect version and code before adopting (not assumed Godot 4.3 compatible).
- NoClip Billboard Sprite3D: https://github.com/dougVanny/NoClipBillboardSprite3D — optional research lead on ground intersection/clipping; verify consequences for proper occlusion, shadows, depth ordering, and the current rendering pipeline.
- Triangle Strategy is a visual/design reference for quarter-turn rotation and adjustable zoom; no proprietary implementation was inspected or copied.

## What our repo already has — confirmed by reading current scripts
- `godot/scripts/stage/board_3d.gd` uses `Camera3D.PROJECTION_PERSPECTIVE`, `CAMERA_FOV = 28.0`, `CAMERA_DISTANCE = 36.0`, default pitch `-50.0`, default yaw `-90.0`. Variables `yaw` and `rot` already exist, and a comment mentions quarter-turn orbit, but live battle is constrained to fixed orientation. Do not assume exposed player rotation is currently functional.
- `Board3D._place_camera()`, `_transform_for()`, `frame_rect()`, `follow()`, `scroll_range()`, `scroll_to()` set/reframe camera. `stretch_at()` compensates perspective foreshortening based on elevation from each upright's world position; `unit_size_at()` compensates perspective size; `on_screen_lean()` and `upright_orient()` counter edge-of-screen tilt, capped by `LEAN_CAP = 15` degrees. `_refit_uprights()` recalculates upright fitting when camera transform or viewport changes.
- `godot/scripts/stage/unit_view_3d.gd`: `AnimatedSprite3D` is nearest-filtered, anchored at the feet, initially fixed-Y billboard, switched to explicit basis with `set_orient()`, and uses `fit(k,m)` for screen-proportion corrections. Visual lunge/knockback are kept separate from actual unit grid positions.
- `godot/scripts/stage/sprite_animator.gd`: `SpriteAnimator.face(screen_dir)` takes SCREEN-space directions, chooses 8 directions when `meta.dirs8` exists (e.g. Alaric) and 4-direction/front-back fallback on older characters. Its current facing must be kept distinct from **world-space gameplay facing** when the camera rotates. Only change displayed clip, not unit facing or stance.
- `godot/scripts/stage/battle_stage.gd`: `lock_camera()` and `frame_board()` preserve static framing between HUD bands. Oversize maps already scroll along their long dimension via `scroll_range`, `focus_cell`, `_goal_z`, and `scroll_to`, eased using `SCROLL_EASE`. Small maps presently don't pan.

## Important existing rules / explicit owner decision required
Root `CLAUDE.md` currently says the camera uses one fixed lens, pitch and distance; battle rotation is prohibited, and allowed camera movement is limited to scrolling over oversize maps and following the player in the base. This research **does not override those rules**. The user wants to investigate a more mobile Triangle Strategy-like system; obtain an explicit go-ahead before altering live battle controls or any owner rule. Avoid editing skill animation systems merely because this document discusses cameras.

## Recommended experimental design (unimplemented)
1. Add an **opt-in debug/test camera mode** behind a flag or a separate test scene. Preserve the current camera as the default and record baseline 1920×1080 screenshots. No gameplay or HUD rewrites.
2. Start with **four discrete 90° yaw positions**, at unchanged pitch (-50°), FOV (28°), distance (36). Orbit around a stable board target; keep transforms stable and camera target/pivot coherent. Verify HUD free-rect framing in every view, including long rectangular and elevated maps.
3. Convert each unit's **persistent world-facing vector** into camera-screen-space via projection of its foot position and an offset along the world-facing vector (prefer actual camera projection instead of hardcoded yaw lookup). Feed resulting direction into SpriteAnimator's 8D or 4D selection **without modifying gameplay facing**. Test both left/right and front/back as the camera circles. Preserve walk phase continuity and attack impact timings.
4. Continue using current billboard correction (upright orientation and `stretch_at`/`unit_size_at`) but validate at all yaw positions and viewport edges, for different map elevations and camera targets. Screen-height and width drift must be measured, not assumed fixed; nearest texture filtering/pixel clarity and feet pivots should remain intact.
5. Extend **pan** independently from rotation (bounded by map extents and usable HUD rectangle). Existing one-axis long-map scrolling can inform implementation; rotating maps may require a camera-relative 2D pan with safe clamping and selection-to-screen picking that honors current orientation.
6. Only after passing quarter-turn tests, explore **bounded zoom**, preferably first as constrained camera distance with fixed FOV/pitch. Monitor pixel sampling, sprite scaling, depth clipping, shadow alignment, camera frustum and HUD obstruction. Do not implement free pitch or unrestricted zoom by default.
7. Optional transition easing (camera yaw interpolation) should preserve correct sprite facing throughout the transition. Decide whether to quantize selected directions or blend only camera motion. Check behind-the-unit sprite frames and animations for character continuity. Camera roll, arbitrary tilt, and ground-level cinematic shots are high risk; defer.
8. Rotated viewpoints change **terrain occlusion**. Investigate targeted wall/prop fade or cutaway without violating correct depth tests or globally x-raying sprites. Keep board/gameplay cell coordinates, collision, highlights, targeting, tiles, minimap, cursor picking and UI consistent.

## Candidate components (planning names only)
- `TacticalCameraController`: optional orbit/pan/zoom input, yaw transitions, bounded target.
- `DirectionalSpriteFacingAdapter`: world direction -> camera-relative 8D/4D sprite frame without changing unit-facing logic.
- Existing `Board3D` projection and upright fitting should be reused, measured, and changed only where necessary.
- `CameraOcclusionHandler`: optional controlled fade/cutaway for foreground props after determining an actual visibility issue.

## Proposed validation matrix
- **Views:** 0°, 90°, 180°, 270°; transitions between them if enabled.
- **Characters:** Alaric's true eight-direction `alaric_v2` and at least two older 4D characters; idle, walking, attack, hurt, KO.
- **Positions:** map center, near/far corners, outer screen edges, low/high elevation, long map, small map.
- **Visual invariants:** no apparent sprite flattening; consistent projected size and screen-vertical orientation; feet aligned to tile; no unintended mirroring; correct sprite-facing relative to true gameplay facing; pixel-perfect/nearest filtering; no clipping or occlusion bugs.
- **Gameplay invariants:** no change to facing/stance reach, unit world coordinates, pathfinding, aiming, collision, cursor picking, skill effects, save/load or turn processing.
- **Testing:** add focused projection/facing and camera-view tests; run Godot 4.3+ import and parse checks, relevant `anim_check`, `scroll_check`, `board_check`, `battle_check`, `hit_check`, and HUD/shot workflows outlined in `CLAUDE.md`. Compare screenshots at 1920×1080; do not claim tested without running the tests.

## Suggested phased milestones
1. Research + baseline screenshots and measurements; confirm precise acceptance criteria and current behavior.
2. Isolated four-angle rotation proof of concept, with 8D world-facing conversion and 4D fallback.
3. Two-axis bounded pan while maintaining battlefield selection visibility and HUD framing.
4. Safe zoom experiment within measured sprite-quality thresholds.
5. Occlusion/transition polish and user controls, only after owner approval.

**Current status:** Research documented only. No new camera controls, code, shaders, assets, or tests have been implemented by writing this file.
