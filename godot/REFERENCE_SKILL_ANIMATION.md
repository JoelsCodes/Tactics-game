# How eight open-source RPGs animate skills (Nov 2026)

Searched GitHub (topics rpg, jrpg, turn-based-rpg, action-rpg, roguelike, tactical-rpg, rpg-engine ... all over 1000 stars) and read the skill and ability code of the ones that have any. Star counts are from the search on 11 Nov 2026. **Nothing was run, nothing was copied into the repo.** Read only, shallow clones outside the project.

| Stars | Repo | Licence | Language | What it teaches about skill animation |
|---|---|---|---|---|
| 7.7k | veloren/veloren | GPL-3 | Rust | Abilities are timed **stages**; the client turns state into visuals |
| 7.0k | wesnoth/wesnoth | GPL-2 | C++ | Every animation hangs off the **moment of impact** (covered in `REFERENCE_TACTICS_GAMES.md`) |
| 6.8k | 00-Evan/shattered-pixel-dungeon | GPL-3 | Java | The cleanest **bolt + particle emitter** vocabulary; the effect fires on a callback |
| 3.1k | gdquest-demos/godot-open-rpg | MIT | GDScript | A Godot turn-based combat skeleton; **almost no skill animation** (see below) |
| 2.4k | m969/EGamePlay | MIT | C# | A skill is a **timeline of typed clips** |
| 1.3k | flareteam/flare-engine | GPL-3 | C++ | A power is a **text record**; the caster has "active frames"; additive blending |
| 1.3k | EasyRPG/Player | GPL-3 | C++ | RPG Maker battle animations: **cells + a timing track** (sound, flash, shake) |
| 1.0k | AnyRPG/AnyRPGCore | MIT | C# | Effects are attached to **ability stages**; cast time can come from the clip |

Skipped: server emulators and MMO frameworks (TrinityCore, azerothcore, rathena, forgottenserver, OpenMU: no client animation), engines for other people's assets (OpenMW, OpenGothic, xoreos, ScummVM, sdlpal), and games already studied (Ancient Beast, Zemeroth).

## What each one does

### Veloren: stages, and visuals that read state
- An ability is a RON file of **durations per stage**: `buildup_duration`, `charge_duration`, `swing_duration`, `recover_duration` (`assets/common/abilities/spear/dash.ron`). The state machine (`common/src/states/basic_melee.rs`) moves `StageSection::Buildup -> Action -> Recover` on a timer. `hit_timing` is a fraction of the swing at which the blow lands.
- The animation code never decides damage. The client reads `(stage_section, progress)` and poses the skeleton from them (`voxygen/anim/src/character/*.rs`).
- Special visuals are a small **enum on the ability** (`FrontendSpecifier::FlameTornado`, `FireGigasWhirlwind`...), and the particle code switches on it **and on the stage section** (`voxygen/src/scene/particle.rs`: the flame tornado only spawns particles during `Action`). The server knows nothing about them.
- Takeaway: wind-up, release, and recovery as named, timed stages; effect names as data on the skill; the effect knows which stage it belongs to.

### Shattered Pixel Dungeon: bolt, particles, then the effect
- `CharSprite.zap(cell, callback)` turns the caster, plays its `zap` animation, and calls back when it ends. Only then does the wand spawn `MagicMissile`, an **emitter that travels** from caster to target at a fixed `SPEED` (200 px/s, `time = distance / SPEED`) and calls back on arrival; the callback applies the game effect (`Wand.fx`, `MagicMissile.java`).
- Visual **types are constants**: `FROST`, `FIRE`, `CORROSION`, `FOLIAGE`, `FORCE`, `SHADOW`, `EARTH`, `WARD`, `POISON`, `LIGHT_MISSILE`, and `*_CONE` variants for cone skills. One class, many looks.
- Particles come from **factories** (`Emitter.Factory`: `emit(emitter, index, x, y)`), with `burst(factory, n)` for a one-shot and `pour(factory, interval)` for a stream. Particles are **recycled** from a pool, and `lightMode()` marks a factory as additive.
- Status icons over a unit (`SpellSprite`) fade in 0.2 s, hold 0.8 s, fade out 0.4 s.
- Takeaway: one projectile that carries an element, a factory per look, additive blending for magic, and "apply the effect on arrival".

### EGamePlay: a skill is a timeline of clips
- A skill execution is a list of **clips** with `StartTime` and `EndTime` (`ExecuteClipData.cs`). Clip types: `Animation` (caster clip), `Audio`, `ParticleEffect` (a prefab), `ItemExecute` (spawns a projectile or area that carries effects), and `ActionEvent` (fire at start, on collision, at the end, or on multiple collisions; either assign an effect or start a **new execution**).
- Gameplay and visuals sit on the **same timeline**, authored in an editor window (`ExecutionLinkEditor`). Sample skills (a fireball, an explosion, a laser) each have one.
- Takeaway: the only repo that treats the effect timeline as the single source for sound, particles, projectile and damage. The "start a new execution" clip is how a skill chains (a fireball that explodes).

### Flare: a power as data, with active frames
- A power is a text record: `animation` (the effect sprite sheet), `directional` (8 rows, one per direction), `visual_option` and `visual_random` (pick which direction row for non-directional art), `lifespan`, `floor` (drawn under units), `soundfx`, `soundfx_hit`, `new_state` (the caster's attack animation name, or `instant`), `post_effect` (a status with magnitude, duration and chance) (`src/PowerManager.cpp`).
- Animation sets define `frames`, `duration`, `type` (`play_once`, `looped`, `back_forth`), and **`active_frame`**: the frames of the caster's animation on which the power fires (`src/AnimationSet.cpp`). Also `blend_mode` (`normal` or `add`), `alpha_mod`, `color_mod`.
- Status effects carry their own `animation` shown while the status lasts.
- Takeaway: the caster's attack sheet marks its own release frame (we have `strike`), and effect sheets declare their blend mode. Tint and alpha are data, so one sheet serves several elements.

### EasyRPG Player: cells and a timing track
- An RPG Maker battle animation is a sheet of **5-column cells** (96 px, or 128 px for large) plus, per animation frame, a list of **cells**: `cell_id`, `x`, `y`, `zoom`, `transparency`, and tone (r, g, b, gray) (`src/battle_animation.cpp`). It plays at 2 real frames per animation frame.
- Alongside it, a **timing track**: for animation frame N, play a sound, **flash** the target or the screen with a colour and power (a flash decays over about 10 frames), and **shake** the target or the screen (offset about 3 to 6 px for 16 animation frames).
- Takeaway: a compact way to make many effects from a few drawn cells by moving, scaling and fading them, plus a per-frame track for sound, flash and shake.

### AnyRPGCore: effects hang off stages
- `AbilityProperties` has four effect lists, one per `AbilityStage { CastChannel, CastEnd, ActionHit, ActionEnd }`: effects on every tick while casting, when casting completes, on a **hit event inside the action animation**, and when the action ends. Cast time can simply be the **length of the cast clip** (`useAnimationCastTime`).
- Prefabs attach to the caster (`holdableObjectList`) and are destroyed after a delay (`prefabDestroyDelay`, `despawnPrefabsOnCastEnd`). Animations come from named profiles.
- Takeaway: "ActionHit" is an event inside the animation, which is what our `strike` frame already is. The extra stage worth having is a **channel tick** for sustained effects.

### Godot Open RPG: not much
- The best Godot-native code in the list, and the most disappointing for skills. Battlers only have `hurt` and `die` clips; **attack animations are placeholder tweens and timers** (`src/combat/actions/battler_action_attack.gd`: move to the target, wait 0.1 s, apply damage). Its own comments say "Normally we would wait for an attack animation's 'triggered' signal".
- Worth keeping in mind: `BattlerAction` is a `Resource` with `execute()` written as a coroutine, and `BattlerAnim` has an `action_triggered` signal that an `AnimationPlayer` track emits at the impact frame. That is the pattern we already use (`struck`).

### Wesnoth (recap)
Every animation is anchored to the impact: `start_time` is negative for the wind-up, frames are `image:duration`, and a unit's attack has a before, during and after pose. See `REFERENCE_TACTICS_GAMES.md`.

## What they agree on
1. **Gameplay resolves on an event, not at the end.** Impact frame (Wesnoth, Flare `active_frame`), callback on arrival (SPD), `ActionHit` stage (AnyRPG), clip time (EGamePlay). We already do this with `strike`.
2. **Stages have names and durations**: buildup, action, recover (Veloren, AnyRPG, Wesnoth's before/during/after).
3. **The look is data on the skill**: an element or specifier name, not code per skill (SPD missile types, Veloren specifiers, Flare power records).
4. **Magic is additive**: Flare `blend_mode=add`, SPD `lightMode`, RPG Maker tone. Our soft-dot and cloud sprites already point that way.
5. **One projectile, one burst, one aura** cover most skills when tinted by element.
6. **Flash, shake and sound are keyed to frames**, not to the whole skill (EasyRPG's timing track).

## What we have, and the gaps
Today: a skill names an `animation` (the caster's pose) and an `effect` (one of a few effect sheets embedded in the character's `meta.json`), `HitFeedback` handles the impact (hitstop, recoil, flash, particles, shake) from `data/hit_profiles.json` with per-skill `overrides`, and the strike frame decides when the blow lands.

Gaps these games fill:
- **No stage times on a skill.** The wind-up and recovery are the character sheet's, so a heavy skill and a light one with the same pose feel the same.
- **No reusable effect library.** Effects live inside character sheets (`effects_from`), so a new element means new frames per character. There is no shared projectile, burst, ring or aura that a skill picks by element and tints.
- **No travel time for projectiles in the rules of presentation beyond `projectile_speed`**; no beam, cone or area shapes with their own look.
- **No sustained effect.** Channels, auras, and "status while it lasts" (we have ailments with no on-unit animation).
- **No per-frame timing track** for flash and shake inside one effect.

## Ideas ranked by how well they fit us
1. **A small shared effect library, selected by skill element and tinted** (SPD's missile types and factories; Veloren specifiers). Five or six pieces cover most skills: projectile, burst, ground ring, aura, beam, cone. Data in `data/` next to `hit_profiles.json`; additive material; a skill chooses a piece and a colour. Biggest win per hour.
2. **Optional stage times and a timeline on a skill**, defaulting to the sheet's own (Veloren stages, EGamePlay clips, AnyRPG stages). For example `"timeline": [{"t": -0.25, "do": "aura"}, {"t": 0, "do": "projectile"}, {"t": "impact", "do": "burst"}]`. A skill with none behaves as it does now. This is where heavy and light skills start to feel different.
3. **Status animations on the unit while an ailment lasts**, with SPD's 0.2 / 0.8 / 0.4 s fade-in, hold, fade-out for the icon, and Flare's per-effect animation. Our ailments (sleep, stun, haste...) are invisible except for icons.
4. **A frame timing track inside an effect** for flash, shake and sound (EasyRPG), so a big skill can flash at its peak frame, not at the start.
5. **A "cells" player** (EasyRPG): compose an effect from a few drawn cells with per-frame position, zoom and opacity. Only worth it if we get effect art in that form.
6. **A channel tick** (AnyRPG `CastChannel`) for skills that hold a turn-long effect. No skill needs it yet.

## Licences
Veloren, Wesnoth, Shattered Pixel Dungeon, Flare and EasyRPG are **GPL**: ideas and structures only, nothing copied, no art or sounds. Godot Open RPG, EGamePlay and AnyRPGCore are **MIT**, but their useful parts are small, and EGamePlay and AnyRPGCore ship third-party Unity assets (Unity-chan, character animation packs) under their own licences: take nothing from their asset folders. As with the earlier rounds, any art lead needs the owner's decision before it enters the repo.

## Limits of this look
- Read the combat and effect code of each, a few files each. Veloren's skeletal animation, Flare's full animation sets and SPD's whole `Speck` catalogue were not read in depth.
- Nothing was run. Behaviour is taken from the code, not observed in play.
- The ranking is a judgement about what fits a Godot 3D battle with 2D sprites; the owner has not seen any of it.
