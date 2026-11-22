# Overhaul: no vessels, no summoning, no mentorship (plan, Nov 2026)

Owner's decisions (Nov 2026): remove the vessel system, remove the summon stones/artifacts on every map, remove Mentorship.
Answers to the design questions: a chosen party fights beside Alaric; skills are learned from defeated enemies, with one shrine per world-map place filling the gaps; the vessel storyline is cut (Bram and Lyra join as ordinary party members from their first appearance); the work is staged, tests green after each stage, saves migrated.

Nothing below is built yet. This file is the work order. Update it as each stage lands.

## What goes, what stays

**Goes**
- `VesselData`, the King's `vessel_roster`, `Role.VESSEL`, tether / untether, `FadeClock`, `BattleUnit.anchor`, the Temp-Relic slot, `PartyRoster.stand_down`, `BattleSetup.temp_vessels`, `force_co_captain` (re-think).
- Summon stones and altar shards on maps: `RelicProp` stones, `AltarShardView`, `StonePlacement`, `SummonStone`, `StoneInfoPanel`, `SummonPicker`, `SummonRanking`, the King's Summon command (and auto-summon, undo/summon test), `max_summons`, `BattleSetup.relics`, the summon tutorial.
- `Mentorship`, Mentor Bonds, `SkillCollection` (stone swaps), the Skill Journal, the vessel mastery teaching offers.
- Tests that only cover those: `mentorship_check`, `collect_check`, `summon_picker_check`, `undo_summon_check` (its Esc-cancel half moves to a new test), `altar_shard_check`, `stones_check`, `chamber_check` (summon part), part of `growth_check`, `life_check`.

**Stays**
- Sword drops (they are not summon stones): the `RelicProp`-like prop used for swords must be split from the stone before deleting.
- Permanent relics in the inventory, equipment slots 1 and 2, weapon styles and stances, status marks, skills data (`data/skills`), `SkillTree` (rewritten, see stage 4), the Co-Captain data type (renamed in stage 3).

## The new party model

- One roster: the King plus **party members** (today's Co-Captains and former vessels, converted to one `PartyMemberData`; the old `CoCaptainData` becomes it).
- A battle fields the King plus up to **PARTY_SIZE = 3** members, chosen in the barracks (no pre-battle screen, owner rule). Default: the last chosen three; new recruits are added automatically while there is room.
- Members are placed at the start of the battle on cells next to the King's (the map's `party` cells when it lists them, else the nearest free tiles). First-turn spacing (`tests/spacing_check`) must still hold: maps whose spawn leaves no room will list cells.
- Story battles that need a particular member (chapter five battle 4: only Alaric and Lyra) set `BattleSetup.party_only` (replaces `force_co_captain`).
- Vessel-only rules go away: "learns by use", `vessels_only` skills, `fade_drain` skills (re-purposed or removed in the skill data), Lyra's soul immunity (becomes a flag on her data), the King falling no longer cuts anyone loose.

## Owner's decisions on the party picker and the main menu (Nov 2026, after the mockups)

- **Layout A (company on the left, battle party slots on the right) is the Formation screen, and it is a pop-up that opens before every battle**, leading straight into the fight (a Fight button, and Back to the world map). This replaces the old rule "no pre-battle screen" (`CLAUDE.md` design rules; update it when stage 1 lands).
- **The last pick is remembered and saved** (in the save file, per party: the ordered member ids; unknown or missing ids are dropped, new recruits fill free slots).
- **The main menu has no party picking.** Its Formation section goes. The Company page becomes the Roster page (below).
- **Roster page layout, from the owner's reference:** tabs along the top (Roster, Equipment, Abilities, Campaign, Records, System); the company list on the left (portrait, name, level, HP and SP bars); the centre shows the selected member's **vertical portrait strip** (a tall crop of the painted portrait, not a full-body figure), name, role, level, HP / SP / XP and the eight attributes; the right shows Equipment (Main weapon, Weapon style, Relic 1, Relic 2) and Abilities and skills. Same steel look as the rest of the menus.
- **Skill reach on the tactical grid** (the reference shows it) **belongs in the skill menu itself**, not on the Roster page.
- Mockups: `docs/mockups/menus/roster_page.png` and `formation_popup.png` (made by `tests/menu_mockup_shot.tscn`, sample data); the three first options are in `docs/mockups/party_picker/`.

## Stages

0. **Survey and design** (this document). Done.
   Stage 1 (below) is done too, including the Roster page (1b): see `HANDOFF.md`.
   Stage 2 (stones, altar shards, stone placement, the summon UI, the tutorial) is done: see `HANDOFF.md`.
1. **Chosen party replaces summoning.** `PartyRoster.party` (saved) and the Formation pop-up before every battle (mockup approved, layout A), `CampaignFlow.deploy_party`, `BattleSetup.populate` places the party, summon command and picker removed from the HUD. Vessels are still the data type (placed at the start, no fade clock) so the game keeps working. Update every `captain_cell` user (22 places) to the `party` cells.
2. **Stones and altars off every map.** Remove stone placement, props for stones, shard views, the stone window, tutorial, and the world-map stone counts. Keep sword drops.
3. **Vessel types out.** Convert `VesselData` to the party member type, migrate saves (`save_codec.gd`, version bump), rewrite the story scenes and flags that mention vessels (the owner's lines word for word wherever possible; every change marked DRAFT and listed in `HANDOFF.md`), remove `Role.VESSEL` and its battle rules, and fix the AI and turn manager.
4. **Skills.** Remove Mentorship and the collection; add learning from defeated enemies (a unit that defeats an enemy, or is hit by its skill, can learn it, by the enemy's rank) and one shrine per world-map place. A mockup of the learn prompt and the shrine first.
5. **Cleanup.** Docs (`CLAUDE.md`, `README.md`, `HANDOFF.md`), balance simulator, full test suite.

## Risks to watch
- The owner's chamber and altar scenes use the summon tutorial and Bram's and Lyra's "vessels" dialogue word for word; cutting the storyline changes the owner's text, so list every changed line.
- Chapter three's Lyra merge (`Crucible.merge_lyra`, `give_lyra`) and chapter four's temporary Gideon and Kaelen (`temp_vessels`) exist only because of vessels; both simplify, but their tests (`crucible_check`, `mountain_check`) read the old behaviour.
- Saves: old saves hold `vessel_roster`, tether counts, mastery progress and the journal. Migrate, do not drop: vessels become party members with their level and skills kept.
- The balance numbers (`tools/balance`) assumed summons; re-run after stage 3.
