# FFT-like skill animation research for Hollowmark Tactics
Research date: 2026-11-12. Reference material for Claude and ChatGPT, **not** an implementation request or permission to override existing owner rules.

## Status (reviewed by Claude, 2026-11-12, against the code as it stands)
This note was written before part of it was built. **Read this section first; the rest is the original research.**

**Already built (do not rebuild):**
- The authoritative boundary exists: `BattleController` decides every outcome; `BattleStage` and `HitFeedback` only show it, on the attacker's strike frame (or when a projectile arrives). The audit in "Implementation order" step 1 is done.
- **Feedback** is `HitFeedback` (`scripts/stage/hit_feedback.gd`), driven by `data/hit_profiles.json`: hit-stop (capped by `MAX_HITSTOP`, 0.14 s), white flash, recoil, lunge, particles, impact sound hooks, camera shake. Give a skill its own feel with an `overrides` entry (e.g. Quick Jab uses the dagger profile). `tests/feedback_check.tscn`.
- **Projectile, burst, ring, aura, beam** are `EffectLibrary` / `FxSprite` (`scripts/stage/`), in four looks (fire, ice, spark, holy) from the owner's effect sheet; `SkillLook.of(skill)` gives every non-physical skill a look; a spell from 2+ tiles flies as a projectile, an area skill flies one projectile and opens a ring. `tests/effects_check`, `skill_look_check`.
- **Facing:** sprites show each unit's world facing as seen from the current view, through `Board3D.screen_dir` (Alaric has eight directions, the rest four). Any new skill animation that plays a direction must use it, never assume a fixed view.

**Camera rule, updated:** no zoom, ever (owner, Nov 2026). The view may turn in quarter-turns (Z / C) and a long map scrolls; the lens, angle and distance stay fixed. Where this note says "do not rotate", read "do not zoom, and do not move the camera for an effect". The shake we have stays inside that rule.

**Built after this review (Nov 2026, owner "do 1-3"):** status marks on units (`StatusFx`), afterimages (`UnitView3D.afterimages` / `dash`) and a skill timeline in `hit_profiles.json` (`HitFeedback.run_timeline`, events ring / aura / burst / dash / afterimages / shake / sfx; `tests/skill_fx_check`). See `godot/HANDOFF.md`.

**Was still open at the review (the first three are now built):** a skill timeline (timed events per skill, so a heavy and a light skill with the same pose feel different); afterimages (none in the code); on-unit ailment visuals (sleep, stun, haste show only as icons); per-outcome branches (a skill's own miss / crit / block / kill version; crit and block are handled by profile data only); earth, wind, water, poison and void looks. The proposed pieces map onto what exists: `Feedback` = `HitFeedback`, `ProjectilePresenter` = `HitFeedback` + `EffectLibrary`. A timeline would extend `hit_profiles.json` and `HitFeedback`, not add a second system. The event names below are an illustration, not a schema.

**Not verified:** the GitHub file paths and details quoted below (for example the 0.4 s sword timing) were not opened again; `action-director` needs Godot 4.7, so it is a design reference only (our project is 4.3).

## Goal
Build a scalable, high-quality, original skill-animation pipeline for the existing Godot 4.3+ isometric tactical RPG, covering melee, ranged, magic, buffs, healing, summons, and multi-hit skills. The intended result is precise hit feedback and reusable animation building blocks without drawing a complete bespoke spritesheet for every skill.

## Evidence from public GitHub source
1. [godotlabsio/godot-tactical-rpg-lite](https://github.com/godotlabsio/godot-tactical-rpg-lite):
   - `scenes/weapons/sword.tscn` contains a 0.4-second `AnimationPlayer` attack with sprite-frame keys at 0, 0.1, 0.2, 0.3 seconds and method-track callbacks at 0.1s (`deal_damage`) and 0.4s (`animation_finished`). `sword.gd` delegates to the combat callback rather than calculating damage in the visual.
   - `scenes/weapons/bow.gd` triggers an arrow from a named shoot point during animation; `projectile.gd` travels toward a world target, spawns an impact effect on arrival, fires callbacks, and frees itself.
   - `scenes/actions/action_execution.gd` carries actor, target grid/world position, and affected cells; this cleanly separates action context from the effect visualization.
   - Takeaway: animation events and projectile arrival should trigger the *presentation of a validated action*, not duplicate battle rules.
2. [Project-Tactics/Project-Tactics](https://github.com/Project-Tactics/Project-Tactics):
   - `src/Libs/Ecs/System/SpriteSystem.cpp` advances animation time using a fixed delta, selects frames from animation descriptors, and updates rendered sprite UVs.
   - `src/Apps/Samples/Component/CharacterFacing.cpp` adapts facings to battle-camera orientation; some directions use flipped sprites.
   - Takeaway: keep facing selection and sprite playback independent from gameplay; prefer genuine owner-supplied eight-direction poses when available rather than forcing mirrored approximations.
3. [juda8020/action-director](https://github.com/juda8020/action-director):
   - README describes an alpha timeline authoring/playback tool with separate animation, motion, VFX, camera, sound, hitbox and event tracks; deterministic 60-tick ActionSpec, frame stepping, A/B takes, and a Godot runtime addon.
   - It states **Godot 4.7** is required for its app; this is a *design reference*, not a drop-in dependency for Hollowmark's Godot 4.3+ project. Its alpha has documented limitations.
   - Takeaway: a small custom skill-event editor or inspector is a sensible later milestone, after reliable runtime sequences are proven.
4. [Psychronic-Games/RPGReactor](https://github.com/Psychronic-Games/RPGReactor): research lead for reusable action sequences and editor patterns; validate individual source paths before incorporating features.
5. [gdquest-demos/godot-2d-tactical-rpg-movement](https://github.com/gdquest-demos/godot-2d-tactical-rpg-movement) and [TylerMooney/Godot-4-Tactical-RPG-Tutorials](https://github.com/TylerMooney/Godot-4-Tactical-RPG-Tutorials): optional references for tactics movement and project structure; not verified as sophisticated skill-animation engines.

## Hollowmark integration constraints — MUST respect
- Read root `CLAUDE.md`, `AGENTS.md`, `godot/HANDOFF.md`, and `godot/README.md` before any work. Current systems include `SkillFx`, skills under `godot/data/skills/*.json`, skill generation in `godot/tools/skills/build_skills.py`, `BattleStage`, `Board3D`, `UnitView3D`, and the owner's character-sprite metadata and art tools. Inspect actual current files before designing interfaces; don't invent function names or replace working combat logic.
- **DO NOT zoom, change the lens, or change the camera distance during battle (updated: the view may turn in quarter-turns with Z / C, see Status).** The owner requires a fixed battle camera angle/FOV/distance; the only movement is the quarter-turn and map scrolling. Replace generic cinematic camera suggestions with screen-space/board-local lighting, subtle screen-space shake ONLY if compatible with camera invariants and owner-approved, impact flashes, sprite afterimages, squash/recoil, hit-stop, and VFX layering. Do not change base/map scrolling behavior.
- Preserve current sprite direction standards, `meta.json` mappings, tile size constraints, owner's art, slash-in-frame flags, hit reaction behavior, and documented Alaric `alaric_v2` overrides. Some attack sheets already include slashes; do not double-render them. Do not add assets/designs without approved owner art or references.
- Physical skill reach/shape/affected cells come from existing weapon style, stance and `StyleResolver`; animations must follow resolved targets, not change targeting. Multi-target and friendly-fire behavior must stay aligned with actual combat resolution.
- Skill animations must not mutate battle position unless the underlying verified gameplay action has legitimate displacement. A visual lunge or teleport is presentation only, with restoration to the original anchored pose at completion; handle elevation and occlusion on 3D board.
- Never let a display-only hit event apply gameplay damage twice. Make a clear authoritative resolution boundary; preserve interruption, skip, speed-up, miss, block, critical, kill, and multi-target semantics.

## Proposed architecture (evaluate; do not blindly replace existing systems)
- `SkillDefinition`: existing validated costs, rank, targets, footprint, damage/status rules.
- `SkillSequence`: authorable *visual event data*, preferably stable IDs and timings (seconds or fixed ticks), independent of numerical game rules.
- `SkillDirector`: schedules visual presentation, coordinates a single action-context object, emits completion/cancel signals, and cleans up on aborted actions.
- `Sprite/UnitPoseAdapter`: chooses 8-direction clips where available and supports preexisting attack, cast, hit and idle behavior with the approved character sheets.
- `VFXSpawner/Pool`: handles particle and sprite effects, directional slash arcs, ground decals, persistent areas, shader flashes and cleanup.
- `ProjectilePresenter`: starts from a named unit anchor, travels to actual resolved world/tile target and triggers a purely visual impact cue (or intentionally resolves gameplay once, if the current combat architecture specifically requires this).
- `Feedback`: hit-stop (initial experimental range ~40-100ms, tune), impact audio, local sprite recoil, afterimages and optional approved non-camera-shifting shake.
- `CombatResolver adapter`: is the **only authoritative gameplay outcome**; sequencing should not reimplement status effects, line-of-sight, area-of-effect, or enemy logic.

## Authorable event vocabulary
`play_pose`, `face_target`, `visual_lunge`, `visual_return`, `spawn_vfx`, `spawn_projectile`, `audio_cue`, `screen_flash`, `hit_stop`, `target_react`, `show_result`, `wait`, `cleanup`. Reserve conditional branches for `miss`, `crit`, `block`, `kill`, and resolved hit counts. Use simple serial/parallel grouping later if justified.

Illustrative sequence (NOT a verified Hollowmark schema):
```json
{
  "id": "sample_phantom_sever_visual",
  "duration": 1.1,
  "events": [
    {"at": 0.00, "type": "play_pose", "clip": "cast"},
    {"at": 0.12, "type": "spawn_vfx", "effect": "charge"},
    {"at": 0.30, "type": "visual_lunge", "towards": "first_target"},
    {"at": 0.34, "type": "spawn_vfx", "effect": "afterimage"},
    {"at": 0.45, "type": "play_pose", "clip": "attack"},
    {"at": 0.52, "type": "show_result", "resolved_hit": 0},
    {"at": 0.67, "type": "target_react", "resolved_hit": 0},
    {"at": 0.80, "type": "visual_return"},
    {"at": 0.95, "type": "play_pose", "clip": "idle"},
    {"at": 1.10, "type": "cleanup"}
  ]
}
```
Only author new effect names after their art is approved and provided; placeholders may reuse current existing `SkillFx` assets.

## Implementation order
1. Audit the current skill execution pipeline and `SkillFx` thoroughly; document call order and single authoritative damage application point. Inventory available clips, owner-approved art, direction metadata, and test coverage. Do not start by replacing architecture.
2. Build the smallest safe timeline/event runner or extend existing `SkillFx` if it already solves the problem. Start with one melee, one projectile, one spell, using existing visuals.
3. Add deterministic ordering, cleanup/cancellation, hit-stop, impact response, visual motion offset and afterimage support as separate small features. Keep board positions authoritative and preserve the fixed camera.
4. Add coverage for 8D/4D fallbacks, elevation, occlusion, misses, crits, multiple targets, rapid consecutive skills, save/load or scene transitions, skip/fast playback, and simultaneous VFX lifetimes.
5. Only once working, consider a visual authoring/preview timeline. Prioritize asset reusability over hundreds of unique hand-drawn skill sheets.

## Tests and acceptance
- Perform Godot headless import and GDScript parse checks, then run existing animation, skill, battle, hit, feedback and board test scenes per root CLAUDE.md and AGENTS.md, plus targeted new tests.
- Confirm each outcome applies **once**, animation completion always fires, visual offsets reset on interruption, projectiles clean up, orientation/pivots match tile positions, and no camera rule changes occurred.
- For visual changes capture an approved 1920x1080 screenshot; distinguish tested rendering from untested aesthetic expectations.
- This document is research/planning only. No effects have been newly implemented or tested by adding these notes.
