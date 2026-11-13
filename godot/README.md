# Hollowmark Tactics (Godot): fresh start

Everything from the first build was deleted on purpose (battle system, rules, classes, maps, menus, campaign, web version). They are still in git history (commit `202b479` and before) if anything is ever wanted back.

What is kept:
- **The art**: source sheets in `art_src/`, the built tiles, characters, props and effects in `assets/`.
- **The pipeline** that cuts them: `tools/art/` and `tools/build_resources.gd`.
- **How they are placed and made to look right**: `scripts/terrain.gd` (isometric terrain), `scripts/character.gd` (one sprite standing on it), the shaders (`unit`, `water`, `lava`), and the notes below.
- A **viewer** (`scenes/viewer.tscn`) that shows a sample map with every character on it. The two maps in `samples/` are terrain test patches, not game maps.
- The Claude Bridge editor plugin (`addons/claude_bridge`, `tools/godot-mcp/`): tooling for driving the Godot editor, not game code.

Open `godot/project.godot` in **Godot 4.3+** and press Play: the game starts with the forest intro (`scenes/intro.tscn`), which fades into the hallway scene and the first battle; the barracks is `scenes/barracks.tscn`. In the terrain viewer (`scenes/viewer.tscn`, F6): drag to pan, pinch or wheel to zoom, Q/E to rotate, Tab for the next sample.

## Files

| Path | What it is |
|---|---|
| `scripts/terrain.gd` | `Terrain`: builds a height map as textured `Polygon2D` blocks in a Y-sorted `field`. Map format, rotation (4 views), `iso`/`ground`/`stand_point`/`terrain_h`, slopes, water/lava shaders, trees, tufts, clouds, pedestal props. |
| `scripts/character.gd` | `Character`: `AnimatedSprite2D` with feet on the origin, shadow, unit shader; front/back frames and mirroring by each animation's `native` direction; waterline. |
| `scripts/viewer.gd`, `scenes/viewer.tscn` | The viewer. |
| `samples/*.json` | Sample maps: `rows` of `<terrain><height>` codes (`g0 g1 W0`), plus optional `smooth`, `hub`, `shadows`, `tufts`, `props`. |
| `shaders/` | `unit` (tint, hue shift, hit flash, KO gray, waterline), `water`, `lava`. |
| `assets/characters/*.tres` | SpriteFrames per character, built from `meta.json`. |
| `tests/check.tscn` | Headless check: samples build in all rotations, every terrain has its textures, every character has all 12 animations. |
| `tests/shot.tscn` | One screenshot of the viewer. |

Terrain codes (`Terrain.LOOK`): `g` grass, `t` grass with a tree, `d` dirt, `s` stone, `r` crag, `c` cinder, `l` lava, `a` sand, `m` mud, `n` snow, `w` shallow water, `W` deep water, `b` bridge, `M` marble, `k` island grass, `v` open sky (cloud puffs).

## Data layer (`scripts/core/`)

Step 1 of the new game: Resources and math only, no UI or combat.

| Class | What it is |
|---|---|
| `TacticalMath` | Levels 0-99, multiplier `1 + 0.02 x level`, proficiency ranks S, A, B, C, D, F and the 100-point level bar, stat modifier math, chess geometry rays (Rook, Bishop, Knight, Queen, King). |
| `StatModifier` | One flat and/or percent change to one stat; stat caps (`LIMITS`: HP 300, SP 30). |
| `SkillData` | An active skill as data (SP cost, power, proficiency). |
| `ItemResource` | Base item; `WeaponItem` (bound to the unit, smithing level and tiers), `WeaponStyle` (geometry, stance, reach), `RelicItem` (skill conduit, accessory passive, negative trade-off with per-turn drains). No separate accessories: relics are the accessories. Inventory relics are permanent equipment and never become field props. |
| `CharacterStats` | Classless stats and a fixed rank (S-F) per proficiency. Max HP = base x level multiplier; Max SP = (5 + Will/2 + Magic/4) x level multiplier, capped at 30, not regenerating. |
| `EquipmentLoadout` | Main Weapon (immutable, smithing-upgraded), Weapon Style, Relic Slot 1, Relic Slot 2 (set in menus from the permanent inventory), and Temp-Relic (vessels only, filled only by tethering in battle). |

Checked by `tests/core_check.tscn`.

## Board layer (`scripts/board/`)

Step 2: grid rules, movement and targeting geometry. No drawing or UI; units plug in later.

| Class | What it is |
|---|---|
| `IsoProjection` | Grid <-> screen math (tile size, height step, 4 view rotations, draw depth, picking the tile under a point, top or cliff side). `Terrain` uses it, so drawing and picking agree. |
| `TacticalGrid` | Cells, heights, terrain, obstacles, occupancy and teams. Walking search (Move, terrain cost; every unit climbs at most 1 level, nothing 2 or more levels higher is walkable, the JUMP stat is how far it can step down; through allies and knocked-out bodies of any team, not standing foes; never ending on anyone) returning a `MovementRange` with costs and paths. Built from the same map format as `Terrain`: heights in half levels, ramps, flags (`!` no walk, `~` pass only, `*` out of play) and decks (`b4=W0`), see `Terrain.parse_token`. What the ground does to units is `TerrainRules`. |
| `GeometryPattern` | A footprint: rays from `TacticalMath.geometry_rays` (Rook, Bishop, Knight, Queen, King, Pawn), plus jumps, pierce, splash and vertical reach. |
| `GeometryResolver` | Walks a pattern over a grid: targetable tiles, the `TargetArea` (tiles and occupants) of an aimed attack, occupants in reach, chess-style move tiles. |
| `StanceRules`, `StyleResolver` | The weapon styles and stances (owner's rules, Nov 2026; one table in the `StanceRules` header). Every style has Impact and Pierce; only the Pawn also has Axe. Rook and Bishop face forward (Rook: the line ahead; Bishop: the two forward diagonals), the whole map: Impact hits the first unit on the line, Pierce every unit; 33% for 1-3 tiles, then 1/D. Knight: one of 8 L-jumps, Impact 100% on the end tile, Pierce 50% there and 25% on the two tiles passed. Queen: 8 directions, Impact the first unit within 2 tiles for 50%, Pierce like the Rook. King: the 8 tiles around, Impact one chosen tile 100%, Pierce all 8 at 33%. Pawn (faces): Impact the front tile 100%, Pierce one of three front tiles 50%, Axe all three 33%. Higher ground than the attacker blocks (the Knight lands up to 2 higher). Everything hits ally and foe. Facing = placed facing, then the direction of the last step; attacking does not turn a unit. `StyleResolver.targetable/affected` give the aim tiles and a `TargetArea` with per-tile `percents`. |

Line rules: a ray ends at the board edge, open sky, an obstacle, a tile more than `vertical_reach` (3) above the unit, or the first unit on it (which can be hit). Knights jump over everything. Terrain: deep water, lava, trees and sky cannot be stood on; trees and placed obstacles block lines; shallow water and mud cost 2 to walk.

Checked by `tests/board_check.tscn`.

## Units layer (`scripts/units/`)

Step 3: who fights, deployment limits and vessel decay. No drawing or UI.

| Class | What it is |
|---|---|
| `UnitData` | Lasting unit definition (stats, loadout). Subclasses: `KingData` (the Commander; `vessel_roster`), `CoCaptainData` (permanent human, signature skills, no decay), `VesselData` (summoned onto relics; `fade_turns` 5, and the permanent lifetime stats `tether_count` (+1 per summon) and `sever_count` (+1 per untether)). |
| `BattleUnit` | A unit in one battle: HP, SP, cell, and for vessels the Fade Clock, its King and `temp_relic()`. It is the occupant on the `TacticalGrid`. |
| `FadeClock` | The in-battle countdown: -1 every time the vessel ends its turn (paused while knocked out); at 0 the vessel is untethered. |
| `DeploymentManager` | Node enforcing 1 King (required, on every mission), at most 1 Co-Captain, and a per-battle summon limit for vessels (the map's `max_summons`, default 6; every summon counts, they can all be on the field at once), and running the relic cycle below. |
| `RelicProp` | A relic lying on a tile (Node2D, no drawing yet). Does not block the tile. |

The relic cycle:
1. Field relics lie on tiles as props (`place_relic`; which relics and where will come from each map's options). No unit can pick them up.
2. The King summons a vessel from his roster onto a prop (`summon_vessel(vessel, cell)`). The vessel is tethered: it stands in the prop's place and the relic goes into its Temp-Relic slot (its skill, passives and drawbacks apply). The tile must be within 30% of the map's longer side of the King (straight-line) and free, and the King must be standing.
3. The vessel's Fade Clock starts at 5 and goes down by 1 each time it ends its turn (`end_turn`), paused while it is knocked out. At 0 it is untethered automatically, the only way a vessel is untethered: its permanent Sever Count goes up by 1 and it cannot be summoned again this battle.
4. On untether: 25% the relic goes home to the permanent inventory; otherwise it reappears as a prop on the vessel's tile, ready for another vessel.
5. End of battle (`end_battle`): each vessel still on the field takes its Temp-Relic home 10% of the time, otherwise the relic is lost; props left on the field are lost. Inventory relics in Relic Slots 1 and 2 stay equipped.

Checked by `tests/units_check.tscn`.

## Proficiencies, mentorship and the barracks (Step 4)

- **Six proficiencies** (`Proficiency`): Physical, Elemental, Healing, Tactical, Status, Void. Every skill has one (`SkillData.category`). A character has a fixed rank in each, S, A, B, C, D or F (`CharacterStats.rank_of`); ranks never level up. Physical skills follow the style and stance; the other five ignore them.
- **Skill levels 0-99** (`SkillMastery`): level 0 while studying (usable already, not kept), 1 when learned and kept for good. Every level, 0 to 1 included, comes from use: each use fills a 100-point bar by the character's rank gain in that skill's proficiency (S 20, A 16, B 13, C 10, D 7, F 4, times efficiency), minus a roll of 0-3 per use, at least 1 (S 17-20, F 1-4; `SkillTree.use_skill`). At C a level takes 10-15 uses. Skill power scales with its level (`1 + 0.02 x level`).
- **Five equipment slots** (`EquipmentLoadout`): Main Weapon, Weapon Style, Relic Slot 1, Relic Slot 2, Temp-Relic (vessels only).
- **Skill mastery** (`SkillMastery`, `SkillTree` on each human's `UnitData.skill_tree`): starting a study puts the skill at level 0; filling its 100-point bar takes it to level 1, which is learning it. Nothing else is required.
- **Mentorship** (`Mentorship`): a human (King or Co-Captain) picks a vessel from the party (`PartyRoster`) and one of the skills on its relics as the active study. The human can use it at once; using it takes it from level 0 to 1, when it is kept for good (`SkillTree.use_skill`, to be called by combat). Switching studies keeps progress, but a paused study cannot be used.
- **Barracks** (`scenes/barracks.tscn`, the main scene; `BarracksScreen`, `MentorshipMenu`): lists Commanders and Vessels; each Commander has a Mentorship button that opens the sub-menu (proficiency ranks, current study, vessels, their relic skills, details, Study button, learned skills). Uses `SampleParty` until there is a save system. Plain default controls until there is a menu art reference.

Checked by `tests/mentorship_check.tscn` (rules and driving the menus). Screenshot: `xvfb-run -a godot --path godot res://tests/ui_shot.tscn -- out=/home/user/x.png mentor=0`.

## Combat loop (Step 5, `scripts/battle/`)

**Damage** (`scripts/battle/damage_formula.gd`):
- *Basic attack* (no skill, costs no SP): `weapon power + Attack - Defense`, then the style's percent for that tile (`TargetArea.percents`: 33% / 1/D for the lines, 100 / 50 / 25 for the Knight, and so on), rounded, at least 1.
- *Physical skill*: `weapon power + (rank multiplier x Attack) x (1 + 0.02 x skill level) - Defense` (the skill's own full number, at least 1), then the style's percent for that tile replaces the 100%. The rank multiplier is rolled inside the rank's band on every use (`SkillData.roll`, `BattleController.perform`), and a preview shows the band's middle. Bands: E 1.00-1.20, D 1.25-1.50, C 1.55-1.85, B 1.90-2.25, A 2.30-2.80, S exactly 3.0. Each skill has its own `rank` (saved). A physical skill's `base_power` is no longer used.
- **Skill animation and effects**: each skill's `animation` is `attack` (melee combo), `heavy` or `cast`; empty = by type (physical: heavy, other: cast). Its `effect` is played at the aimed tile on the strike frame and replaces the default effect. Effects are the ones on the user's own sheet (`meta.json` `effects`; folders in `assets/characters/<sheet>/effects/`). The list in the sheets: `slash`, `streak`, `circle`, `burst`, `eruption`, `smoke`, `rend`, `swirl`, `shard`. Which sheets have which: `python3 -c` over `assets/characters/meta.json` (each character's `effects` keys), or see the table below.
- **Skill database**: `data/skills/<proficiency>.json` (one entry per skill: name, rank, sp, description, shape, effect_implemented), loaded by `SkillLibrary`. Statuses (`BattleUnit.statuses`, each ticks down at the end of its unit's own turn): `marked` (Feinting Lunge: physical hits on it miss 5%, not 25%) and `mild_blind` (Dirty Sand Kick: its own attacks miss 35%, not 25%; 1 to 3 turns, rolled per hit). `atk_down` (Grip Loosen: its physical damage is 15% less, `DamageFormula.ATK_DOWN_PERCENT`). Physical skills so far: Quick Jab, Shield Prod, Hamstring Cut, Step-Aside Strike, Feinting Lunge, Dirty Sand Kick and Grip Loosen, Crescent Strike, Pity Pity and Hop (`hop`: an action that moves the user 1 tile forward onto a tile up to 3 levels higher (drops are free), not 4 or more; not chosen by the enemy AI) (`push`: an adjacent target that survives is moved 1 tile straight back, unless the tile behind cannot be stood on). Rank E skills cost 3 SP unless the owner says otherwise. Skills with `allows_move_after` (Quick Jab) reopen the unit's walk after they are used, with only the move points the first walk left over: move, jab, move on what is left. Without the flag, a unit walks once per turn whether before or after its action, and a basic attack never reopens the walk.
- Elemental, Void, Healing (the other damage categories) keep their formulas; Tactical and Status do no HP damage yet.

No drawing or input yet; a battle scene will call these.

| Class | What it is |
|---|---|
| `BattleController` | Node running a battle: `start`, `next_turn`, `move_range`/`move`, `actions`/`highlights`/`preview`/`perform`, `summon_vessel` (free during the King's turn), `end_turn`, `finish` (returns a `BattleSummary`). Every damaging hit on a target has a 25% chance to miss (heals never miss) (`MISS_CHANCE`, rolled per target in `perform`): no damage or heal, and no push, slow or other effect; the SP is still spent. Win when every enemy is down; lose when every player unit on the field is down (a downed King only stops summoning). |
| `TurnManager` | Charge time: each tick a standing unit gains its Speed; at 100 it acts. Ending a turn costs 100 CT (moved and acted), 80 (one) or 60 (neither). Ties: leaders, then vessels, then enemies, then Speed. Knocked-out units are skipped. `upcoming(n)` for a turn-order display. |
| `EnemyAI` | Enemy turns. Tries every reachable tile, every affordable action and every aim, scores the previewed hits and takes the best; with nothing worth doing in reach it walks toward the foe it most wants. Values damage, knockouts, wounded targets, vessels on the field (above the King), the King, healing wounded allies; avoids friendly fire, needless SP and needless walking. Weights in `WEIGHTS`. A plain enemy can use the owner's rank E physical skills (`SkillLibrary.enemy_pool()`) as well as its own `EnemyData.skills`; an enemy with `skills_only` uses only its own list (Riverford's do, all rank E). After a skill with `allows_move_after` (Quick Jab) it walks again on the move points left, as the player does. Acts only through `BattleController`, so it follows the same rules as the player. |
| `BattleAction` | A basic attack (free, Physical) or a skill (fixed SP cost). |
| `DamageFormula` | Basic attack: weapon power + Attack - Defense, times the stance percent per tile. Physical skill: weapon power + (rank multiplier x Attack) x skill level term - Defense, times the style's percent (see Combat loop). Elemental: skill power + Magic - Resistance. Void: skill power + Magic. Healing: skill power + Magic / 2. Tactical and Status: no HP change yet. At least 1 damage. |
| `BattleSummary` | Filled in during the battle, completed by `finish(roster)`: outcome, turns, per unit damage dealt/taken, healing, KOs, SP spent, skill uses and levels gained (skills learned), vessel tethers/severs this battle, relics secured (into the roster's inventory) and lost. Skills only level by use; there is no end-of-battle experience. |
| `ActionResult` | What an action did or would do: area, SP spent, hits (amount, heal, knocked out), skill levels gained. |
| `EnemyData` (`scripts/units/`) | Minimal opposing unit: stats, loadout, skills. |

- SP works like MP: skills spend a fixed cost from the 15-30 pool, which does not refill in battle; relic SP drains apply at turn start. Styles and stances change footprint, tile selection and Physical damage only.
- Weapon styles and stances are set in the loadout menus before battle and are fixed during it: a `BattleUnit` copies its style's stance when it enters the battle (`stance()`), and nothing changes it after that.
- **Enemy styles (Nov 2026):** every enemy rolls a random style (Rook, Bishop, Knight or Pawn; never King or Queen) and an allowed stance at the start of every battle (`EnemyStyles`, called from `BattleSetup.populate`); the tutorial fights keep their fixed styles (`BattleSetup.fixed_styles`: the first battle and the chamber).
- **Sword drops (Nov 2026):** when an enemy goes down its body leaves the tile and a slightly transparent sword (`assets/props/sword_drop.png`, cut from the owner's sheet by `tools/art/sword_drop.py`; drawn `BattleStage.SWORD_HEIGHT` 1.1 world units tall, inside the tile rule) lies there with its style and stance (`BattleController.swords`, `sword_dropped`). Only a player-side unit that **ends its turn on the tile** takes it (walking over it does not): it rises quickly above the unit, fading, and the style and stance are **that unit's** (`UnitData.known_styles`, `learn_style`; `BattleController._collect_sword_at` in `end_turn`; the battle's `summary.styles_found`, added to each unit in `finish`; saved with each unit by `SaveCodec`). Other units do not get it. Swords left behind are lost. In the barracks Loadout menu the Weapon Style slot lists the styles that unit has found (what it held stays in its collection). Rook with Impact is Alaric's first style. Checked by `tests/sword_check.tscn`; frames: `tests/battle_shot.tscn -- step=sword|sword_rise setup=riverford1`.
- Highlights come from the unit's Weapon Style geometry (Rook, Bishop, Knight, Queen, King, Pawn) with the stance applied to attacks and Physical skills; hits resolve against every unit in the `TargetArea` (allies too).
- Using a studied or learned skill levels it (`SkillTree.use_skill`).
- Vessels: summoning is free during the King's turn (no move or action used), raises `tether_count` and adds the vessel to the turn order; at the end of each of its turns its Fade Clock goes down by 1 (paused while knocked out); at 0 it is untethered (`sever_count` +1, relic home 25% or dropped on its tile) and leaves the turn order.

Checked by `tests/battle_check.tscn` (turn order, SP, footprints and damage per stance, vessels, and a scripted battle to the end). `tests/ai_check.tscn` checks the AI's choices and plays whole battles with it on both sides.

## Roster, saves and the barracks (Step 7, `scripts/units/` and `scripts/ui/`)

| Class | What it is |
|---|---|
| `SaveGame` | Everything saved: the `PartyRoster` and the `CampaignState`. `SaveGame.new_game()` starts with the placeholder `SampleParty`. |
| `SaveCodec` | `SaveGame` <-> plain data for JSON. Versioned (`VERSION`, `migrate` hook); enums stored by name; numbers clamped to their legal ranges; missing or wrong-typed fields fall back to defaults; skills and relics written once in tables and referenced by key, so sharing (a skill on a relic and in a skill tree; one relic in two slots) survives a reload. Damage and inconsistencies come back as warnings. |
| `SaveSystem` | Files: one JSON per slot in `user://saves`. Safe writes (temp file, previous save kept as `.bak`), automatic fallback to the backup, slot-name checks, `slots()` / `newest_slot()`. |
| `SaveLoadResult` | Load outcome: the game, or the error, plus warnings and whether the backup was used. |
| `CampaignState` | Lifetime counters (battles fought/won/lost, vessels tethered/severed in total, relics secured/lost, skills learned) and completed missions. |
| `CampaignFlow` | `deploy_leaders` (the King and the chosen Co-Captain), `prepare_deployment` (any vessel the King owns can be summoned, up to the map's limit), `finish_battle` (relics into the inventory, campaign updated, autosave). |
| `RosterManager` | Rules for organizing the party: equip a spare relic into a relic slot (the replaced one returns to the inventory; a relic is never in two places), choose which Co-Captain goes on missions with the King (`set_active_co_captain`). |
| `PartyRoster` | Also holds `active_co_captain` (`deployed_co_captain()`), `all_units()` and `audit()`. |
| `BarracksScreen`, `LoadoutMenu` | The hub: Commanders (Mentorship, Loadout), vessels (Loadout, tether and sever counts), spare relics, Save and Load, Battle (straight onto the mission map: there is no pre-battle screen). The King is fixed on every mission; each Co-Captain has a "Send on missions" button. Continues from the newest save on start. |

What a save holds: each unit's stats and level , the six proficiency ranks, all five loadout slots (Main Weapon with its smithing level, Weapon Style, Relic Slots 1-2, Temp-Relic), each human's skill tree (skill levels, study progress, the active study, mentor), vessels' `tether_count` and `sever_count`, the relic inventory, the chosen Co-Captain and the campaign counters. Battle-only state (HP, SP, positions, Fade Clocks) is not saved. Skill levels and each vessel's tether and sever counts change on the roster's own resources during a battle, so saving afterwards keeps them.

Checked by `tests/save_check.tscn`. Screenshot of the equipment menu: `xvfb-run -a godot --path godot res://tests/ui_shot.tscn -- out=/home/user/x.png loadout=0`.

## Experience and levels

- **Character data** (`CharacterStats`, read through `UnitData.level / exp / exp_to_next_level / total_exp`): `level` 1-99, `exp` toward the next level, `total_exp` lifetime XP. Skills, weapons and relics keep their own 0-99 levels.
- **The curve** (`ExperienceCurve`): 100 XP to leave level 1, then 10 more per level (level 10 -> 11 costs 190, 50 -> 51 costs 590, 98 -> 99 costs 1070; 57,330 in all). Level 99 is the cap.
- **During a battle nobody gains XP.** Each defeated enemy adds its `EnemyData.exp_reward` (default 30) to the battle's pool (`BattleSummary.exp_pool`).
- **At victory** (`BattleController.finish`, via `ExperienceSystem`): the pool is divided evenly, `pool / participants` in whole numbers (a remainder is dropped), among the player-side units that started at least one turn: the King, the Co-Captain and vessels, including vessels that have since faded. A unit that never got a turn does not take part. A loss or an unfinished battle gives nothing.
- **Level-ups** (`CharacterStats.add_exp`): leftover XP carries into the next level, several levels can come at once, and XP is dropped at 99 (`total_exp` still counts it). HP and SP pools grow with the level through the existing `1 + 0.02 x level` multiplier, still capped at 300 HP and 30 SP; Attack, Defense, Magic, Resistance, Speed, Will, Move and Jump do not change. Each level gained is a `LevelUp` record (levels, HP and SP before and after) and the summary lists them per unit.
- **Saves** keep level, `exp` and `total_exp` for every unit. The save format is now version 2; version 1 saves still load (XP starts at 0, level 0 becomes 1).

Checked by `tests/exp_check.tscn`.

## Missions and summoning

- **Out-of-battle menus** (barracks, Loadout, Mentorship) manage everything: weapon, weapon style and stance, and relics. Each unit has Main Weapon, Weapon Style, Relic Slot 1, Relic Slot 2 and (vessels, in battle) the Temp-Relic. The Main Weapon is bound to its unit. Nothing can be changed during a battle.
- **No pre-battle screen.** The barracks' Battle button starts the mission map straight away.
- **Leaders:** the King goes on every mission. The player chooses the Co-Captain in the barracks (`PartyRoster.active_co_captain`; the first one until chosen).
- **Vessels are not picked beforehand.** In battle the King can summon any vessel he owns onto a field relic, free (no move or action), within 30% of the map's longer side of him. A map allows a fixed number of summons for the whole battle (`max_summons` in the map file, default 6): every summon counts, they can all be on the field at once, and a vessel that fades is not summoned again, nor does it give its summon back. A summoned vessel's Fade Clock starts at once and runs until victory or until it fades, when its relic drops on its tile.

## Story scenes and the first battle

Story scenes extend `Cutscene3D` (`scripts/stage/cutscene_3d.gd`): the map on the battle's 3D board and static camera, units standing on tiles, a fade, and the dialogue box (`say(text, sheet)`), plus `walk`, `jump` (a quick hop that keeps the facing) and `slide` (knocked back). No input, no rules.
- `scenes/intro.tscn` (`IntroCutscene`): **the game starts here.** Two lines of narration over black (the village burned, his family dead; drafted by Claude), then the forest: Alaric runs along the path toward the ruins but he is hurt and weak. His wound gives out, he stumbles and slumps (a held frame of the hurt animation, `UnitView3D.hold`, with a red pulse), then limps on; two Ashen Squires run in behind him, he looks back, runs for the entrance and goes in. One squire calls "I smell a hurt rat, I think he went in there!" and the scene fades slowly to black (`FADE_OUT`) into the hallway scene. Checked by `tests/intro_check.tscn`.
- `scenes/hallway.tscn` (`HallwayCutscene`): the abandoned castle's hallway (`samples/intro_ruins.json`). Alaric limps in from the entrance; halfway down an Ashen Squire appears at the entrance and calls "Here by the hallway!", then lunges; Alaric hops back out of reach, leaps forward and slashes, driving the squire 3 tiles back to the entrance. Then it starts the **first battle** with both on the cells they stand on.
- **The first battle** (`FirstBattle.setup`): Alaric alone at level 1 with the **Rook weapon style** (no Co-Captain, no vessels: no summon stones, a summon limit of 0) against one Ashen Squire that only moves and uses the basic attack (`EnemyData.basic_attack_only`). A story scene starts a battle by setting `BattleStage.pending_game` and `BattleStage.pending_setup` (a `BattleSetup`: map, Alaric's cell, enemies, summon stones, summon limit, `on_win`, `tutorial`); a win at the result panel's **Continue** hands the game on (`Cutscene3D.carried_game`) to the scene `on_win` names; a lost story battle restarts (**Try again**).
- `scenes/hallway_return.tscn` (`HallwayReturnCutscene`): after the first battle: Alaric stands slumped where the fight left him; iron boots sound (narration, drafted by Claude): more squires are coming. He looks back, straightens and limps to the doors at the far end of the hall; the scene fades out into the chamber.
- `scenes/chamber.tscn` (`ChamberCutscene`, map `samples/ruins_chamber.json`, a 12x9 room with a dais and the carved altar block at the far wall): Alaric limps in down the empty room (nowhere to go), slumps by the altar and waits for the end. His bleeding hand falls on the altar (the `cast` frames and a magic circle), a white flash, and Bram and Lyra step out of the light (the vessel tint, `UnitLook.VESSEL_TINT`). Iron boots echo; the owner's dialogue (Lyra, Bram, Alaric, Lyra, word for word, with the speaker's name in the box). Then the two spirits dissolve, two squires walk in, and the **chamber battle** starts.
- **The chamber battle** (`FirstBattle.chamber_setup`): Alaric (level 1, Rook) and two Ashen Squires, with two summon stones (Altar Shards) on the far wall where Bram and Lyra stood and a summon limit of 2. The vessels are `FirstBattle.bram()` / `lyra()` (placeholder skills and numbers), added to Alaric's roster by `FirstBattle.chamber_game`. `BattleSetup.tutorial` turns on `BattleTutorial`: a hint panel under the objectives (`BattleHud.show_tip`) that follows the player through opening SUMMON, picking a vessel, clicking a crystal, the second summon and the Fade Clock. It only reads the stage's state, never blocks input. A win leads to the base scene.
- `scenes/base.tscn` (`BaseCutscene`): after the chamber battle, Alaric, Bram and Lyra talk about making the chamber their base (a first draft by Claude, in their voices: the owner can reword it), then it fades out into the barracks. Checked by `tests/chamber_check.tscn`.
- **Chapter two, Riverford (Nov 2026, the owner's story "The Price of Embers")**: `Riverford` (`scripts/units/riverford.gd`) builds the five battles from `samples/riverford_1..5.json` (made by `tools/make_riverford_maps.py`, which also writes the market square `riverford_market.json`; every map is 16 deep and 20 to 24 wide, with its own tiles and several levels of height: 1 The Back Alleys, mud lanes and a raised fish market; 2 The Tangled Paths, canals, bridges and a walled garden; 3 The Interception, a street that steps down in terraces to a walled yard; 4 The Final Stand, a dusk-lit flagstone lane (Alaric starts on the right); 5 Vesper's Wrath, the courtyard with a high barrier, a dais and the drain). Enemies are `Riverford.KINDS` (each kind its own stats and a short list of **rank E skills only**; the sprites are the owner's beginner sheets: Rot-Hound = Forest Wolf, Sewer Slime = Moss Slime, Town Watchman and Watch Sergeant = Riverband Brute, Watch Scout = Hooded Cutthroat, Royal Guard = Ironhollow Sentinel, Battle-Mage = Hollowmark Assassin). The scenes are data (`RiverfordStory.SCENES`) played by `StoryScene` (`scenes/story_scene.tscn`): fades, letterbox bars, chapter and narration cards, a dialogue box, units that walk, run, jump, act and fade, speech bubbles, colour washes, flashes and shakes. `WorldData.SCENES` says which scene plays before ("pre", straight into the battle) or after ("post") a map the first time it is played as a story mission; `CampaignState.scenes_seen` makes each play once; replays never play scenes. In scene `rf_awakening` Merc dies and rises (`Riverford.add_merc`). Map 5 has two waves (`BattleSetup.waves`, `BattleStage._arrivals`) and Vesper flees at 40% HP (`BattleSetup.flee`, `BattleController.fleeing`, `unit_fled`: a fleeing unit is never knocked out; its exit plays in `BattleStage._play_flees`). Checked by `tests/riverford_check.tscn` and `tests/story_check.tscn`; fairness by the balance simulator (`bash godot/tools/balance/run.sh`, `tests/balance_sim.gd`); frames: `bash godot/tools/shots.sh riverford:1..5` and `tests/intro_shot.tscn -- scene=story_scene key=rf_market`.
- **Skills, ranks E to S (Nov 2026)**: `data/skills/{physical,elemental,healing,tactical,status,void}.json`. The owner's ten rank E physical and seven healing skills are untouched; `tools/skills/build_skills.py` appends the rest (anything with `"gen": true`; run it again to rebuild them) and writes each description from the numbers. Rules live in `SkillFx` (the `fx` object of a skill): damage modifiers (scale, hits, execute, pct_hp, vs_status, desperate, chaos), `blast` radius, `self_only`, drain, statuses (burn, regen, ward, exposed, silence, root, with poison, mild blind, atk down, marked), stat mods (`mods`), SP drain/steal/give, heal_pct, cleanse, guard, pull, swap, delay/rush and `self` effects. Tactical skills never miss; elemental and void damage ignore the stance. SP costs: E 3, D 4, C 5, B 6, A 8, S 10. Checked by `tests/skills_check.tscn`, which casts every skill.
- **Villagers** (`NpcLook`: man, girl, kid, mechanic): idle/walk-only sprites for cutscenes, the base and towns (`tools/art/npc_idle_walk.py`).
- **World map** (`scenes/world_map.tscn`, `WorldMapScreen`, art in `WorldMapArt`, data in `WorldData`): see `godot/HANDOFF.md`. **Base** (`scenes/base_area.tscn`, `BaseArea`, `samples/base.json`): a free-roam 30x30 area (the camera follows Alaric there; `tools/make_base_map.py` rebuilds the map). Checked by `tests/world_check.tscn` and `tests/base_check.tscn`; frames with `bash godot/tools/shots.sh world` / `base` (`base:x,y`).
- `Cutscene3D` also has `narrate(text)` (a card in the middle of the screen), `flash()` (white), `pulse_red()` and `say(text, who, name)` (the speaker's name above the line).
- `samples/abandoned_hallway.json`: the hallway saved as a replayable map for later (the owner will say what it is for).
- Screenshots: `bash godot/tools/shots.sh hallway` / `return` / `chamber` / `base` (every step; `chamber:<b>,<b>` for some), `first` / `second` (each battle as it starts; `second` is the chamber battle).

## Battle screen (Step 8, `scenes/battle.tscn`)

**Screen:** made for a 16:9 desktop display. Layouts are built at 1920x1080 and scale with the window (`project.godot`: `canvas_items` stretch, `expand` aspect; the window opens at 1600x900). The barracks is three columns (Commanders, Vessels, Spare relics); Mentorship and Loadout are three side-by-side panels.

The barracks' **Battle** button opens a test fight (`SampleBattle` on `samples/demo_battlefield.json`) with the current party. At the end the result panel leads back to the barracks (XP, relics and an autosave go through `CampaignFlow.finish_battle`).

| Path | What it is |
|---|---|
| `scripts/stage/battle_stage.gd` | `BattleStage` (`Node3D`): the screen. Builds the 3D board (`Board3D`), draws units as upright billboards (`UnitView3D`), relics as floating crystals with a cyan light, damage numbers as `Label3D`, turns clicks into `BattleController` calls (`Board3D.pick` casts the mouse ray at tile tops and walls), runs the camera (static: one lens, angle and distance, `Board3D.CAMERA_FOV` / `CAMERA_DISTANCE`, the whole battlefield centred between the HUD bands, `BattleStage.lock_camera`, which the story scenes use too; it never zooms; a long map scrolls along its long side and Z / C turn the view a quarter-turn, `turn_view`, checked by `tests/camera_turn_check`). Enemy turns are played by `EnemyAI`: they walk, the area they are about to hit glows, then they strike. |
| `scripts/stage/board_3d.gd` | `Board3D`: the 3D diorama board, lighting, sky, fog and camera (see "3D board" below). |
| `scripts/stage/unit_view_3d.gd`, `tree_view_3d.gd` | Upright character billboards (front/back frames and mirroring as in 2D, tints, KO gray and wading through `modulate` and height, a shadow-only capsule) and trees. |
| `scripts/stage/tile_highlights.gd`, `shaders/tile_highlight_3d.gdshader` | Neon-blue floor highlights, one mesh per kind lying just above the tile tops: walkable tiles (blue wash, cyan border), an attack or skill footprint (deeper blue, stripes), the area it would hit (pulsing), the aimed tile (corner brackets), relics the King can summon onto. Regions glow only along their outer border (edge flags in grid space). |
| `scripts/stage/unit_look.gd` | Which sheet and tint a unit uses (the owner's full sheets by unit id, `CharacterLook.BY_ID`; any other unit and every enemy is the Ashen Squire; vessels a faint blue, enemies a faint red), and portrait crops. |
| `scripts/ui/hud/` | `BattleHud` for a 16:9 screen: **TurnOrderBar** top center (portraits with names in initiative order from `TurnManager.upcoming`; gold frame on the unit acting now; gold King/Co-Captain, cyan vessels with their Fade Clock, red enemies), **CommandPalette** bottom center (Abilities opens one column per group: Weapon, each proficiency, Summon; Wait / End Turn), two **UnitStatusCard**s in the bottom corners (right: the acting unit; left: a clicked or targeted unit; name, level, role, HP, SP, XP; for vessels the Fade Clock, Sever and Tether counts), a message line and the result panel. `HudStyle` is the look (navy glass, hairline borders, one gold accent) and is shared by the barracks and its menus. |

**Battle HUD look** (modeled on the owner's reference image): sleek smoky dark-brown glass panels with a bronze edge, a gold hairline and corner diamonds (`slim_panel.png`, `HudStyle.hud_theme()`), title plaques with diamond caps (`HudStyle.plaque`). Top left: an arrow-shaped TURN banner (`BattleStage.round`: goes up when a unit that already acted this round acts again) and an Objectives strip fading to the right. Top center: the turn queue as compact cards (portrait, name, thin HP line colored by side) between gold arrow caps; the acting unit's card has a cyan edge, a breathing glow and a scale pop. **Command palette** (bottom center, plaque: unit and SP): a large gold-framed ATTACK, ABILITIES (an icon slot that opens a list above the bar: skills by proficiency with SP cost at the right), ITEMS (greyed out: no consumables yet), DEFEND (the King has SUMMON here instead: it opens the list of vessels he can summon) (guard: `DamageFormula.GUARD_PERCENT` = 50% damage until the unit's next turn, ends the turn, a cyan shield shows over the unit; `BattleController.defend`), WAIT / END TURN and MOVE (shows the walk range again with Cancel). **Status cards** (plaque: Acting / Target): name in capitals and LVL, a large portrait in a side-tinted ring, role and stance, exact HP and SP on thin lines, XP, status chips (Fade countdown, Guarding, Knocked out, Low SP). All art comes from `tools/art/build_ui.py`. **Own icons:** PNGs in `assets/ui/icons/` (`attack`, `abilities`, `items`, `defend`, `summon`, `wait`, `move`) replace the generated ones and keep their own colors (`HudStyle.icon`); see the README in that folder.

A turn: the walkable tiles glow; click one to walk. **Abilities** lists the unit's skills grouped by proficiency with their fixed SP cost (greyed out when SP is short); for the King it also lists Summon for every vessel he owns that is not already out (the column shows how many summons are left). Pick one, its footprint glows; click a tile to aim (the hit area glows, the target shows on the left card and the damage over each unit), click it again to confirm. **Wait / End Turn** ends the turn. Weapon styles and loadouts are fixed in battle, so there is no command for them. The game is classless, so the card shows the unit's role (King, Co-Captain, Vessel, Enemy) where a class would go.

Units and relics stand on their tile's top (`Board3D.top_point`); the depth buffer sorts them with the blocks. The 2D `Terrain`, `Character` and the 2D lighting below are still used by the viewer (`scenes/viewer.tscn`) and the art checks.

**Magenta sheets:** `python3 tools/art/magenta_key.py sheet.png out.png` (or `out_dir --cols C --rows R` to cut frames) turns a #FF00FF background into transparency with soft, de-tinted edges. Checked by `python3 tools/art/test_magenta_key.py`. Which rows are which animation is set per sheet when the art arrives (`tools/art/eight_dir.py`, `idle_walk_sheet.py`).

Checked by `tests/stage_check.tscn`. Screenshots: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/battle_shot.tscn -- out=/home/user/x.png step=` with `abilities`, `confirm`, `summon`, `enemy` or `result` (needs Vulkan; see Setup).

## Tests

```sh
godot --headless --path godot --import                    # once, to build the import cache
godot --headless --path godot res://tests/check.tscn
godot --headless --path godot res://tests/core_check.tscn
godot --headless --path godot res://tests/board_check.tscn
godot --headless --path godot res://tests/units_check.tscn
godot --headless --path godot res://tests/mentorship_check.tscn
godot --headless --path godot res://tests/battle_check.tscn
godot --headless --path godot res://tests/save_check.tscn
godot --headless --path godot res://tests/exp_check.tscn
godot --headless --path godot res://tests/stage_check.tscn
godot --headless --path godot res://tests/ai_check.tscn
python3 godot/tools/art/test_magenta_key.py
xvfb-run -a godot --path godot res://tests/shot.tscn -- out=/home/user/x.png sample=0 zoom=.8 rot=0
```

## Art pipeline

Everything visual comes from the source images in `art_src/` (see `art_src/README.md` for the labeled list). `python3 tools/art/build_art.py` turns them into game assets (needs Python with Pillow, numpy and scipy, about 20 s):

- **Characters** are built separately: `bash tools/art/build_characters.sh` (the owner's full sheets and idle/walk sheets; see the King and "The other full sheets" below). The seven older sheets (hero, knight, cardmage, gunman, dino, brute, wolf) and their cutter were removed at the owner's request.
- **Terrain** (`tools/art/tiles.py`): fourteen biome sheets. A "block" (center, size and depth of one isometric slab on a sheet) gives the 96x96 top textures from its interior tiles, and its lit and shaded side faces as strips. `TILESHEETS` lists what each sheet contains, and `BLOCKS`, `TOPS`, `SIDES` and `FLAT_TOPS` record the measured regions. Dirt, sand and crag are recolors. Water and lava are textures plus shaders.
- **Props and effects** (`tools/art/build_art.py`): the tree is the canopy from the village sheet, the bridge deck is cut from the bridges sheet, and the shadow, light dot and cloud puffs are generated.

Rebuild after changing the art:

```sh
python3 godot/tools/art/build_art.py
godot --headless --path godot --import
godot --headless --path godot --script res://tools/build_resources.gd   # SpriteFrames
```

## The King (eight-direction sheet)

The owner's King sheet (`art_src/characters/king_sheet.webp`, a generated reference atlas on magenta,
not a uniform grid) is cut by `tools/art/eight_dir.py` into the character `king`:
- **Reading it:** rows from the thin dark-magenta divider lines; frames in movement rows as runs of sprite columns (dust merges into its frame), in action rows by divider lines (sword trails bridge neighbours; neighbouring slivers from effect spikes join up). Magenta keyed with soft edges, then `defringe` neutralizes the magenta cast lossy compression left on opaque outline pixels (violet magic stays).
- **Alignment:** feet = bottom of the dark body pixels, centred on the lowest rows (effects do not move it); every frame on one 134x71 canvas with the feet on one anchor (`test_eight_dir.py`: 0 px offset, no magenta left). Frames stay at source resolution; `meta.scale` (2.23) scales them in the game with nearest filtering.
- **Animations:** `idle/walk/run/dash_<dir>` for `s se e ne n nw w sw` at 4/8/12/14 fps; `attack` (melee combo, 12 fps, strike frame 3), `heavy` (10 fps, strike 6), `cast` (8 fps, strike 9), `hit` (8 fps), `ko` (6 fps, holds). The sheet's UP-RIGHT / UP-LEFT blocks show the face (a generation error), so `ne` / `nw` use the true back view (UP) for now (`dir_use` in `SHEETS`; `manifest.json` says `same_as`). The last two heavy cells are only the ground eruption, so they are left out and played as an effect on the target.
- **Effects:** `fx_*` from the particle row: swirl, slash (4), rend, eruption (5), circle, burst, smoke (4). Heavy attacks raise an eruption on the aimed tile, casts a magic circle and a burst, the melee combo a slash, all on the strike frame.
- **Manifest:** `assets/characters/king/manifest.json`: every frame's source rectangle and feet, fps, loop, direction, strike frame. The painted portrait (`portrait.png`, first of the sheet's portraits) is used by the HUD.
- Rebuild: `python3 godot/tools/art/eight_dir.py`, import, `godot --headless --path godot --script res://tools/build_resources.gd`.
- Not used yet: dash (no game action for it).

**The sheet's bottom section** is cut by `tools/art/king_extras.py` (run after `eight_dir.py`; it also reads `art_src/characters/king_sheet.webp`, which is never modified). Layout under `assets/characters/king/`:
```
animations/{idle,walk,run,dash,attack,magic,hurt,death}/   frames (attack holds melee and heavy, magic the cast)
effects/{slashes,eruptions,magic_circles,bursts,smoke}/     one transparent image per frame
portraits/portrait_01..05.png                               the five painted portraits, at their own size
equipment/sword.png (+ sword_panel.png as drawn)            artwork/full_portrait.png     manifest.json
```
- **Effects** are keyed by flood-filling the magenta from each cell's edge only, so violet glows inside an effect survive; `anim_check` counts magenta-looking pixels in each (none). In battle: melee strike = slash at the target, heavy = eruption plus dust on the aimed tile, cast = magic circle and burst, a run starts with a dust puff (`UnitView3D.spawn_fx`).
- **No colour variations:** the sheets' colour looks are not used (the owner removed them, with the barracks' Appearance screen and the saved look). The extras scripts do not cut or bake them; every unit is drawn from its own sheet.

### The other full sheets (Vesper, Lyra, Ashen Squire, Hollow Choir, Lunar; Vesper is an enemy)

Five more owner sheets (`art_src/characters/<name>_sheet.webp`) are cut the same way into `assets/characters/{vesper,mira,squire,choir,wraith}/` with the same folder layout as the King:
- **Animations** (`eight_dir.py`, `sheet_8dir`): the blocks are found from the magenta panels; movement frames from body pixels only (a staff's orb or a trail does not join neighbours; overwide runs are split), dash frames keep their dust; the action rows have no reliable dividers, so they are cut into equal cells (`cols`), and strike frames are found where the effect peaks (`auto_strike`). Cells that are only an eruption or a magic circle are dropped (played as effects). The hurt / death block is split by shape: lying frames are the knockout. Up-right / up-left use the back view, as for the King.
- **Lyra** has a four-direction sheet (down, up, left, right), and her actions are drawn facing left.
- **Extras** (`char_extras.py`, `LAYOUT`): effects (slashes, streaks, eruptions, bursts, smoke; a magic circle where the sheet has one), five portraits, the weapon (sword, or the mage's staff) and the illustration.
- **Who wears them** (`CharacterLook.BY_ID`): Lyra (a vessel), Ashen Squire, Hollow Choir (the mage), Lunar (the wolf; renamed from the Lantern Wraith, sheet id `wraith`), and the placeholder vessels. Any other unit, and every enemy, is drawn with the Ashen Squire sheet.
- `tests/lineup_shot.tscn` renders all six characters walking and on their heavy strike; `tools/art/contact.py <name> out.png [0|1]` makes a contact sheet of a character's frames.
- Known limits: some action cells keep a sliver of the neighbouring cell's effect, since the grid is not exact.

### Robin (enemy)

`art_src/characters/robin_sheet.webp` (the King's eight-direction layout: `SHEETS['robin']` in `eight_dir.py`, extras in `char_extras.py`) and his four-direction idle and walk, `robin_idle_walk_sheet.png` (`tools/art/robin_idle_walk.py`, drawn as tall as the King). He is an enemy: `UnitLook.ENEMY_CHARACTERS` draws an enemy named Robin with his sheet (the demo battle has one); other enemies are Ashen Squires. His sheet's colour palettes are not used. Known: five of his effect images keep a few magenta pixels.

- **Diorama edge (Nov 2026):** the cutaway rim no longer ends in a hard block. `shaders/diorama_edge.gdshader` (`Board3D._rim_surface`) sinks the rim texture into a dark void colour with depth and scissors the bottom into a ragged line; `shaders/rim_mist.gdshader` (two `RimMist` sheets under the board, densest at the rim, depth-faded) veils the drop; `Board3D._build_overhangs` hangs roots, ivy and rock spikes on the rim faces (hash-placed, scenery only, no shadows). Under the static camera most of the front rim sits behind the HUD, so the effect shows at the board's lower corners and as the mist halo. Not checked on a real display. **Cliff profile (Nov 2026, second pass):** the rim walls are now a grid (`Board3D._rim_wall`) whose points go through `_rim_warp` (pinned at the ground line, the board tapers in by `RIM_TAPER` at the bottom and noise pushes the points about, so corners and neighbours still meet); `diorama_edge.gdshader` adds strata, crevices and moss and dissolves the lowest part into the mist (alpha, ragged line); `_build_overhangs` also adds a grass (or rubble) lip over the top edge and protruding boulders, and everything hung on the rim follows the warp (`_rim_follow`). Check a new map with `tests/diorama_shot.tscn -- map=<name> units=0 pitch=-25 yaw=-60`.

### The Eater (enemy slime)

`eater_sheet.webp` (the owner's sheet in Vesper's layout, saved lossless; `SHEETS['eater']` in `eight_dir.py`, extras in `char_extras.py` with no weapon). It has no separate idle/walk sheet: its idle and walk come from the main sheet's four direction blocks (the sheet's diagonals are read for the scale only). Its frame counts differ per direction (down 5, up 6, right 4, left 4-5). The heavy block's last two cells (spike eruptions) and the magic block's burst cells (3 and 7) are dropped as effect-only; the slime sheet's hit/hurt/death block has only wide cells, so `hd_pick` chooses them (hit = cells 1 and 2, ko = 2, 6, 3, 7: it melts into a puddle). it follows the owner's **tile rule** (Nov 2026), not the King's height: `target_body` 53.7, meta scale 1.45, so its idle and walk frames fit one tile (about 89 px wide in the tile units below, about 55 px tall). `anim_check` `tile_fit` checks it. An enemy named Eater is drawn with it (`UnitLook.ENEMY_CHARACTERS`). Colour palettes not used. Its four-direction attack (`eater_attack_sheet.png`, `tools/art/eater_attack.py` through `attack_sheet.py`, run right after `eight_dir.py`) gives `attack_s/e/n/w`, four frames, strike on the splash frame, `slash_in_frames` set.

### The damage prediction view (Nov 2026, the owner's request)

When a tile is aimed with the attack or a skill (`BattleStage._aim_at`), a **Forecast** panel slides out from the left edge of the battle HUD, just above the Target card (`ForecastPanel`, `scripts/ui/hud/forecast_panel.gd`, built by `BattleHud`; `show_forecast` / `hide_forecast`). It hides when the aim ends (`_set_mode` leaves CONFIRM: cancel, perform, a new turn). It shows, for the unit on the aimed tile: the action's name and SP cost on the plaque, the target's name and HP before and after with a forecast bar (green stays, red is lost for certain, amber might be lost; a heal shows the gain), the chance to hit, the damage or healing in large numbers (a range when it rolls: a physical skill's rank band, Heal's 27 to 33), a Knockout / May KO chip, chips for other effects (a status, slow, push, never KOs, uses all SP), and one line for each other unit the action hits. The numbers come from `DamageForecast` (`scripts/battle/damage_forecast.gd`), which only reads the battle (`preview`, `miss_chance_for`) and changes nothing; the healing skills without a number say what they do instead (Pray 50%, HP Roulette 50 / 50, Poison Spit 50% poison, Chance! +10%, Venom Removal). Checked by `tests/forecast_check.tscn`; frames: `bash godot/tools/shots.sh battle:forecast battle:forecast_heal`. Only one hit chance is shown (the game has one miss chance, not separate physical and magic ones).

### The healing proficiency (rank E, Nov 2026)

Seven skills in `data/skills/healing.json`, loaded by `SkillLibrary.healing()`, all rank E and 3 SP. Their rules are in `scripts/battle/support_rules.gd` (`SupportRules`), keyed by each skill's `support` field; `allies_only` / `enemies_only` set who they may target (`SupportRules.may_target`, checked in `BattleController.preview`). Rolls happen in `SupportRules.roll` (from `perform`), so the aim preview shows nominal amounts.

- **Pray:** 50% to cure every ailment of one ally (marked, mild blind, attack down, poison).
- **Heal:** 30 HP, plus or minus 10% (27 to 33), rolled each use.
- **HP Roulette:** teammates only. 50%: full heal; otherwise half its current HP is taken away, never below 1.
- **Poison Spit:** enemies only. 50% per hit to poison: 5% of max HP lost at the end of each of the poisoned unit's turns, for 3 to 5 of its turns (`BattleUnit.POISON`, `SupportRules.poison_tick`, called in `BattleController.end_turn`). Poison never takes the last point of HP.
- **Venom Removal:** teammates only; cures poison.
- **Chance!:** a random teammate in the area gets a random stat (attack, defense, magic, resistance, speed, will) up 10% for 5 of its turns or until the battle ends (`BattleUnit.buffs`, read by `BattleUnit.stat`); the stat is named on screen.
- **SP Finisher:** enemies only. Spends ALL the user's SP. Damage is physical-style at 110% of Attack, plus 5% for every 10% of its total SP still left (160% at full, 110% at none), through `DamageFormula.skill_finisher` (guard and Atk Down apply).

My readings (change if wrong): Pray's "status ailments" are the four statuses in the game (marked, mild blind, atk down, poison); the poison and the buff numbers are the ones written; Poison Spit deals no damage (only the poison); the SP Finisher is an enemy-only attack although it sits in the healing list (its category stays healing, so it levels with healing); HP Roulette's "take away half" never KOs. Players reach these only through skill trees and relics; nothing drops them yet (the summon stone pool is still the physical E skills). Checked by `tests/healing_check.tscn`.

### The Boar (enemy) and Merc (vessel): grid sheets

One four-direction sheet each (`boar_sheet.png`, `merc_sheet.png`: blocks IDLE, WALK, ATTACK, HURT, MAGIC, DEATH, each four frames across and a row per direction DOWN, UP, LEFT, RIGHT, plus the illustration; palettes not used) cut whole by `tools/art/boar_sheet.py` / `merc_sheet.py` through the shared `grid_sheet.py` (a config of block boxes; a block drawn only facing the viewer, like Merc's HURT, MAGIC and DEATH, has one row and gives the plain `hit`, `cast` and `ko`, which the game mirrors). Merc is a vessel (`CharacterLook.BY_ID`, id `merc`; not in the sample party yet). For the Boar, which writes the character's entire `meta.json` entry (no `eight_dir.py` sheet). Every animation is directional (`attack_s`... `cast_`, `hit_` (frames 1 and 2 of HURT), `ko_`); heavy reuses the attack, run and dash the walk. The attack arc and the magic aura are in the frames (`slash_in_frames`). One pixel size (0.9) and per-direction feet; the canvas fits every frame. Drawn at the 120 px standard. An enemy named Boar is drawn with it (`UnitLook.ENEMY_CHARACTERS`). It has no effect sprites and one portrait (the illustration).

### The Red Wolf (enemy)

Same process as Robin: `redwolf_sheet.webp` (`SHEETS['redwolf']`, extras with no weapon: he fights with claws) and `redwolf_idle_walk_sheet.png` (`tools/art/redwolf_idle_walk.py`; his walking side views touch on the sheet, so `split` separates them). An enemy named Red Wolf is drawn with his sheet (`UnitLook.ENEMY_CHARACTERS`; the demo battle's second enemy). Colour palettes not used.

### Placeholder vessels (owner's sheets, no names yet)

`sorc` (8 directions), `warden`, `shade`, `lancer`, `blade` (4 directions, `sheet_4dir`) are five more vessels in the sample party (working names Sorceress, Bram, Shade, Lancer, Blade; Bram was called Warden and keeps the sheet id `warden`). **Bram's idle (4 frames), walk, run and attack (6 each), hurt (2) and knock-out (4), in four directions, come from the owner's six sheets** (`art_src/characters/bram_{idle,walk,run,attack,hit,ko}_sheet.png`: a row per direction DOWN, RIGHT, UP, LEFT) cut by `tools/art/bram_anims.py`, after `eight_dir.py`: idle and walk are scaled by figure height, run and attack by head width against the walk (the sheets were not drawn at one scale; the idle's figure is about 8% stockier), all on his 190x97 canvas. `attack_<dir>` is a six-frame one-shot with the strike on frame 3 and no drawn arc (`slash_in_frames` stays off, so the game adds its own slash). `hit_<dir>` and `ko_<dir>` are one-shots (the animator picks them for his facing; the knock-out holds its last frame); the hurt is scaled by head width against the idle, the knock-out against the hurt's matching wince; frames land in `animations/hurt` and `animations/death`. Checked by `anim_check` (`bram_anims`). His cast and dash still come from the older `warden_sheet.webp`, and the older one-direction `attack`, `hit` and `ko` stay as fallbacks. **Lyra (sheet id `mira`) has them too, plus a cast** (`tools/art/lyra_anims.py`; both characters go through the shared `tools/art/sheet_set.py`, which has per-sheet scale rules, an optional soft-edge cut and a grid-sheet source). Her walk still comes from a magenta sheet (`lyra_walk_sheet.png`); her **idle (8 frames), run (6), attack (8, strike on frame 5: two ready, two raised, two slash, two recovery; the sword is drawn but no arc, so `slash_in_frames` is off and the game adds its slash), cast (8, release on frame 5), hurt (8) and knock-out (8)** come from six transparent sheets in Alaric's layout (`lyra_v2_{idle,run,attack,cast,hurt,ko}_sheet.png`, 1254x1254; the attack and cast have eight direction rows and rows 0, 2, 4 and 6 are used; the attack and cast sheets are drawn at half the idle's size, so the attack takes the cast's scale; the run takes the idle's), cut through `alaric_v2.row_cells` after dropping the halo of faint red noise (alpha under 128). Her knock-out sheet squeezes the fall into 156 px cells, so the lying frames are drawn about 40% smaller than the standing one; `area_norm` rescales each frame by its figure's area (capped at 1.6x) so she stays one size on the floor, and `grounded` puts them on the feet row. The older idle, hurt and knock-out sheets stay in `art_src`. The magenta sheets are scaled so each one's resting frames are as tall as her idle (her hair makes head width unreliable), her attack is cut with soft edges so the swing's translucent arc stays (frame 3, `slash_in_frames` on, strike on frame 3), and everything lands on her 118x94 canvas (a thrust's far tip could be clipped; the script lists clipped frames, none now). Her older cast, dash and the one-direction fallbacks stay. They have animations, effects and portraits only: no weapon or illustration yet. Known: some cut cells carry a sliver of a neighbour; the lancer's effects keep a few magenta pixels.

**Idle** is one still frame per direction (the most upright frame of the sheet's idle row, `eight_dir.py`) with a slight breathing motion in the game (`UnitView3D._process`, about 1% from the feet): the sheets' idle rows step and lean. The sheets' side (left / right) idle and walk poses are crouched like their runs; that needs new art (the owner may regenerate those rows).

**Animation controller** (`scripts/stage/sprite_animator.gd`, used by `UnitView3D`, reusable for any character): MOVE (idle/walk/run/dash per direction, never restarted when asked again), ACTION (one-shots with a `struck` signal on the strike frame; hurt interrupts, other actions do not), POSE (victory), DEAD (ko holds its last frame). Eight-direction sheets pick the drawn direction from the screen direction (nearest of 8); (front/back-only sheets would mirror; none are left). In battle a unit runs on paths of 4+ tiles (0.17 s per tile, walk 0.3 s), faces each step's screen direction, and damage numbers, hurt and knockouts wait for the attacker's strike frame. Checked by `tests/anim_check.tscn`; `tests/king_shot.tscn` renders all eight directions and the actions.

## Characters

- Only the owner's sheets are in the game (`art_src/characters/`, see below); every frame sits on its character's shared canvas with the feet at `meta.json` `anchor`. `Character` sets `sprite.offset` so the anchor sits on the node's origin, then places the node at `Terrain.stand_point(x, y)`.
- Drawn at half size (`SPRITE_SCALE` .5). The game draws four directions only (down, right, up, left): `SpriteAnimator.dir_of` snaps every facing to the larger screen axis, so there is no diagonal art: the data names only `_s`, `_e`, `_n` and `_w` (the diagonal names and frames were removed). **One standard size for every fighter (the owner's rule): as tall as the King.** A character with the new four-direction idle and walk is drawn with its idle figure `STANDARD_FIGURE` (120 px: frame px x `meta.json` scale) tall; its idle/walk script sets the scale (`idle_walk_sheet.standard_scale`), so all its animations grow or shrink together. The King, Lyra, the Ashen Squire, the Sorceress, Bram, Robin and the Red Wolf follow it (`anim_check` checks them); new characters do by going through `idle_walk_sheet.build`. Older full sheets without the new idle and walk are scaled to `BODY_TARGET` by `tools/art/eight_dir.py` and still stand a little taller (Vesper, Choir, Wraith, the placeholder vessels: about 135-148 px). Do not tune a character's size by hand. **The camera is static (the owner's rule):** intro and battle keep one lens (28 degrees, the 3D look), one angle (pitch -50) and one distance (`Board3D.CAMERA_DISTANCE`, 36, which fits the whole battlefield between the HUD bands), and it never zooms (it turns in quarter-turns with Z / C in battle, and scrolls along a long map); closer or farther and the upright sprites look paper thin. A map has to fit in that view. `stage_check` and `intro_check` check it. 
- Standing in shallow water: the shader's `cut` hides the feet below the waterline and the shadow is hidden.
- Add characters to `terrain.field` (Y-sorted) so they overlap blocks correctly.

## Terrain: how it is made to look right

- Each tile is a block: a top face and the two visible side faces, `TW` 32 / `TH` 16 half-size, `HS` 14 per height level, sides always reaching `BASE` below level 0.
- Every flat-top terrain is **one baked seamless texture** mapped by position (no per-tile pictures, no grid lines, tops 1.5% larger so neighbours overlap). Side strips are 4 tiles wide and wrap seamlessly, so cliff faces run on without joins. Water, lava and bridges stay level and use per-tile textures (water and lava through shaders, lava adds a point light).
- Any new biome should follow this standard.

### Grass

Grass (`g`) has no per-tile pictures: `bake_ground` in `tools/art/build_art.py` blends the 64 block tops (from `art_src/tiles/grass_blocks.jpg`, cut by `build_grass_blocks`) into one seamless 1024px texture, `ground_grass.png`, with smooth noise choosing lawn, tufted or mossy areas and small flower and stone patches. `terrain.gd` maps that texture by position (rotated grid coordinates, repeat on), so the ground has no tile borders; grass tiles also have no grid line and are drawn 1.5% larger so neighbours overlap. The dirt sides (`side_blockgrass_l/r.png`) are eight plain block faces cropped inside their outlines and feathered into each other so the cliff runs on without joins; `v0` in `LOOK` skips the grass lip so the dirt shows. The texture repeats about every 10.7 tiles. `blocktop_NN.png` are the intermediate cuts.

### Smooth hills

Maps are smooth by default (`smooth: false` turns it off). A smooth map draws terrain as slopes instead of cliff steps: each tile corner takes the mean height of the tiles around it (`_vh`, `_corner_heights` in `terrain.gd`), so neighbouring tops share edges, and the top is shaded by its slope (`SLOPE_SHADE`, light from behind). The sides always reach the same base level, so only the map border shows earth. Characters stand on the slopes (`terrain_h`, bilinear over the corners; `stand_point`).

### Lighting and finish (HD-2D look)

All 2D, no 3D nodes: a `WorldEnvironment` (SSAO, glow, color correction) only acts on 3D scenes and the compatibility renderer has no 2D glow, so each effect is done by hand.
- **Baked light, `terrain.gd`**: every face is vertex-shaded. The left face gets warm light, the right face is darker and cooler (`LEFT_LIGHT`, `RIGHT_LIGHT`), both fade darker toward the ground. Tops get warm overhead light plus **ambient occlusion** per corner (`corner_shade`: corners whose surroundings stand higher than the tile are darkened, `AO_PER_LEVEL`) and a soft **cast shadow** from a taller tile on the lit side (light from the front-left, shadows fall up-right).
- **`shaders/terrain_face.gdshader`** (tops and sides, not water/lava): local-contrast boost so stone and grain read deeper, a slow world-space tint drift so large areas are not uniform, then multiplies the baked vertex light.
- **`shaders/tile_highlight.gdshader`**: the neon-blue floor highlight (premultiplied blend so it stays blue on bright grass): bright core line along the region border with a soft inner falloff, faint tile grid, diamond inlay rings, and a light sweep running across the region in world space.

### UI art

`tools/art/build_ui.py` (Pillow, numpy, scipy) draws every UI texture into `assets/ui/` with no source images: stone and walnut nine-slice panels (bronze rim, gold inner trim, corner studs and brackets, translucent glass center), button states, bar track and fill, a divider and the menu backdrop. `HudStyle` (`scripts/ui/hud/hud_style.gd`) wraps them as `StyleBoxTexture` (`panel()`, `button_box()`, `bar()`, `divider()`, `backdrop()`) and takes its fonts from `Typography` (`scripts/ui/typography.gd`): Cinzel Bold for headings, Inter (Regular, Medium, SemiBold, Bold) for every gameplay text (`assets/fonts/`, SIL OFL 1.1, see `LICENSE.txt` and `OFL.txt` there). After changing the script run `godot --headless --path godot --import`.

### 3D board (`scripts/stage/board_3d.gd`, the battle screen)

The battlefield is a true 3D board built from the map and the tile art: every tile is a column of real geometry (top quad plus wall quads down to the lower neighbour, outer walls to `BASE` below zero), a warm `DirectionalLight3D` sun with soft real-time shadows (`light_angular_distance` gives PCSS softening; from the screen's front-left, so shadows fall up-right) and two soft omni fills, `WorldEnvironment` with a `ProceduralSkyMaterial` backdrop (deep blue to a dusky horizon; the camera looks down, so the visible part is the sky's ground half) that also lights the shadows, light depth and height fog so the board's base fades into the air, SSAO, glow, filmic tonemap and grading, and a perspective `Camera3D` (default pitch -50 degrees, 28 degree lens, orbit with `rotate_view`) with depth-of-field blur for the miniature look. Units are upright `AnimatedSprite3D` billboards (`BILLBOARD_FIXED_Y`, nearest filtering with no mipmaps, size `UNIT_SCALE`) standing on the tops. An upright quad seen from 50 degrees above is squashed to cos(pitch) = 0.64 of its height and reads like a flat card, so `_fit_unit` stretches it by 1/cos(pitch) on Y: on screen the sprite has its drawn proportions while it stays vertical. Units are unshaded with a warm modulate (a camera-facing quad lit from the side reads as a dark cutout); an invisible capsule per unit casts their shadow, because a flat billboard only casts a hairline.
- **Backdrop:** a screen-space radial gradient (`shaders/backdrop_radial.gdshader`): warm twilight amber behind the board through dusky rose and slate to midnight at the corners. The stops are picked in sRGB and converted in the shader; the center stays under the glow threshold. With it the scene uses a flat ambient color. Maps may set `"backdrop": "sky"` for the procedural sky instead, and `"god_rays": true` for light shafts (`shaders/light_shaft.gdshader`, off by default: the owner did not like them).
- **Props:** a map may list `"props"`: `{"id", "x", "y", "h", "flip"}` from the prop catalogue (`assets/props/catalogue.json`; `h` is the height in world units, the King is about 1.9). Each stands on its tile as an upright billboard (`PropView3D`). The catalogue is cut from the owner's prop sheets in `art_src/props/` by `tools/art/props.py` (names and categories in its `NAMES` / `MANUAL`; `--boxes` numbers a new sheet's pieces): doors, ruins, landmarks (the sword in the stone, statues, fountain, portal, shrine, stalls), banners, weapons, containers, furniture (throne, rugs, tables), lights, plants.
- **Abandoned castle** (`tools/art/castle_tiles.py`, from the owner's three cube sheets `art_src/tiles/abandoned_castle_{walls,ruins,props}.jpg`): terrains `f` flagstone floor, `h` overgrown flagstones, `e` carved medallion slab and `o` slab with a carved border (both on brick sides, for a dais), `q` sandstone brick wall. Each tile shows one whole slab (256 px tops, not blended into a seamless ground like grass: a flagstone grid would smear). Cubes are placed by their top corner and width in `CUBES` (the sheets are not on a grid); the brick side strip is the lit face of a corner wall made seamless; raised floor shows the slabs' stone lip over the dirt cliff. The sheets' arches, stairs, statues, throne and sword dais are not used: on the 3D board they would be flat cut-outs. Tinted down a little, the light sandstone takes the warm sun strongly. Used by `samples/intro_ruins.json`.
- **Props:** a map may list `"props"`: `{"id", "x", "y", "h", "flip"}` from the prop catalogue (`assets/props/catalogue.json`, cut from `art_src/props/` by `tools/art/props.py`); each stands on its tile as an upright billboard (`PropView3D`). The owner found them too flat ("fake") in the ruin, so no map uses them yet.
- **Backdrop:** a map may set `"backdrop"`: `radial` (default, twilight amber), `radial_black` (a lighter black behind the board to a darker black at the corners; the ruins) or `sky`.
- **Per-map look:** a map may set `"grade"` (`natural` default: true colors, dramatic contrast; `golden`: warm highlights only; `sepia`: the strong golden-hour curve) and `"haze"` (`light` default: faint mist, thin haze, few motes; `heavy`: thick smoky mist and dust). `Board3D.set_grade` / `set_haze`; screenshots take `grade=`.
- **Atmosphere pass:** heavy SSAO (deep contact shadows between blocks), a golden-hour grade (`golden_hour_lut()`: a per-channel 1D color-correction curve, warm mids and gold highlights with saturation won back), soft-light glow on three levels, thin warm volumetric fog that the sun lights (`light_volumetric_fog_energy`), floating dust motes (`GPUParticles3D` "Dust") and a low mist sheet over the floor (`shaders/floor_mist.gdshader`, drifting noise that fades into the ground and blocks by depth).
- **Floor grid:** `tile_highlight_3d.gdshader` draws cyan grid lines on every tile edge, a breathing pulse and rolling scanlines (strongest on walk and attack ranges) on top of the border glow.
- **HUD glass:** textured panels over the battle use `shaders/ui_glass.gdshader` (`HudStyle.frost_panels`): the game shows blurred through their translucent glass center. Turn-order portraits use the gold ring `portrait_frame.png`, tinted per side.
- The project runs on **Forward+** (Vulkan): SSAO, DoF and soft shadows do not exist in the Compatibility renderer. A computer without Vulkan support cannot run the game.
- Picking (`pick`) casts the camera ray at every tile top and exposed wall and takes the nearest hit; framing (`frame_rect`) keeps the fixed camera distance and only centres the view in the screen space between the HUD bands, with its own projection (works before the first frame). The camera is the board's child and the board sits at the origin.
- Bare-board screenshot: `xvfb-run -a godot --path godot res://tests/diorama_shot.tscn -- out=/tmp/d.png [pitch=-45] [fov=30] [yaw=45] [ssao=0] [shadow=0]`.
- Lessons: the 2D right-hand side strips are pre-darkened, so the prototype uses the lit strip on every wall and lets the sun shade it; wall quads must be wound so the normal faces out (`_quad`), or Godot lights them from behind and they render black.
- Not done yet: smooth slopes (tops are flat steps), animated water and lava, pedestal props and clouds from the 2D `Terrain`, floating-island maps.

### Block sheets

New tile art comes as isometric block sheets (an n x n grid of blocks on a dark background). `BLOCK_TERRAINS` in `tools/art/build_art.py` says, per terrain, which sheet and which cells give its tops and which give its side strip; `build_block_terrains` cuts the middle of each top face (`block_top`) and blends the faces into one wrapping strip (`block_side_strip`), then the terrain is baked seamless like grass. In use now: grass (`grass_blocks`), cinder and lava (`volcanic_new`; lava tops come from the molten faces), dirt and stone (`castle_ruins`: dark soil, flagstones), crag (`mountain_rock`), snow (`snow_blocks`, terrain `n`), marble (`town_marble`). `cut_block` only removes background connected to the cell edge, so dark soil and cracks inside a block stay. Still on the old art: sand, mud, water, bridges, Skyhold's rock sides, clouds. Saved for later biomes: `dungeon` (10x10), `sky_cubes`, `village_cobble`, `sky_islands`, `cosmic_ruins`.

### Floating islands (`hub: true`)

The rim tiles `k` are floating-island grass (`isle`, tops from `sky_islands`), every cliff under the islands, marble and bridges uses the islands' rocky undersides (`side_island`, built by `rect_side_strip` because island bottoms are not cube faces), marble tops come from `town_marble`, and the portal obelisk and crystal markers are pedestals cut whole from `cosmic_ruins` (`SHEET_SPRITES` -> `props/sky_obelisk.png`, `props/sky_crystal.png`). The sky-cube clouds kept their cube outline, so the drawn cloud puffs stay.

## Lessons from the first build

1. Check which game and repo before building anything.
2. Get the art or a style reference before writing rendering code.
3. Measure images with rulers (draw a coordinate grid over the sheet), not by eye.
4. Make small edits, not whole-file rewrites.
5. Look at few, small screenshots; use the headless check for the rest.
6. Keep sessions short, one milestone each.

## Setup in a fresh container

- Godot 4.3: download `Godot_v4.3-stable_linux.x86_64.zip` from the godotengine GitHub releases and put the binary at `/usr/local/bin/godot`.
- The art pipeline needs Python with Pillow, numpy and scipy.
- **Quick screenshots:** `bash godot/tools/shots.sh [intro|intro:all|intro:<beat>,<beat>|battle|battle:<step>|nearfar|all]` (default `intro`: the King walking and standing still). Runs at 1920x1080 on xvfb, scenes sped up 4x (`SHOTS_SPEED`), several shots in parallel; frames go to `/tmp/hollowmark_shots` (`SHOTS_OUT`). The intro pair takes about 15 s, `all` about 40 s.
- Screenshots of the battle need Vulkan. With no GPU: `apt-get install -y mesa-vulkan-drivers xvfb` (software Vulkan, lavapipe; a frame takes seconds and a screenshot about a minute). Headless tests (`--headless`) need nothing extra.
- Claude Bridge (optional, with the editor open on your computer): `claude mcp add godot -- node /path/to/repo/godot/tools/godot-mcp/server.js`. It only listens on 127.0.0.1:6550.


### Chapter three, the Crucible, ailments and the AI (Nov 2026)
See `HANDOFF.md` ("Status ailments, the enemy AI and chapter three") and `CLAUDE.md`: `Crucible` and `CrucibleStory` (three big scrolling maps from `tools/make_crucible_maps.py`; scenes `cr_*`), the classic ailments in `BattleUnit`, the AI weights in `EnemyAI.WEIGHTS`, `PartyRoster.stand_down` (Lyra: Co-Captain or vessel). Tests: `tests/crucible_check.tscn`, `tests/ailments_check.tscn`; frames: `bash godot/tools/shots.sh crucible:1..3` and `tests/intro_shot.tscn -- scene=story_scene key=cr_breaking`.

## Camera research: Triangle Strategy-style movement (proposal, Nov 2026)
Read [`docs/TRIANGLE_STRATEGY_CAMERA_RESEARCH.md`](docs/TRIANGLE_STRATEGY_CAMERA_RESEARCH.md) for the GitHub references, an audit of existing sprite perspective correction and directional sprites, and an optional staged experiment for 90° rotation, battlefield panning and bounded zoom. **Research only:** current fixed-camera rules in root `CLAUDE.md` remain in force unless the owner explicitly authorizes an experiment or change. No new camera gameplay behavior is implemented by this note.

## SpriteKiln preview generator (Nov 2026)
The [`docs/SPRITEKILN_WORKFLOW.md`](docs/SPRITEKILN_WORKFLOW.md) guide explains how to run the **manual** [SpriteKiln GitHub Actions preview](https://github.com/JoelsCodes/Tactics-game/actions/workflows/spritekiln-preview.yml) from ChatGPT-authored character specs. This produces isolated downloadable preview artifacts, **not** modifications to approved Hollowmark art. First completed rendering test is still pending.
