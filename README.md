# Hollowmark Tactics

An isometric tactics RPG for phones, built on the systems of Final Fantasy Tactics Advance with original names, maps and story. Vanilla JS, no build step, no image assets (all art is drawn on canvas).

Open `index.html` through any static server (`python3 -m http.server`) and play in a phone-sized window.

## Systems

| System | How it works here |
| --- | --- |
| Turn order | Speed-based CT. Acting costs 100 CT when you move and act, 80 for one of them, 60 for neither, so skipping makes your next turn come sooner. Haste/Slow/Stop change it. |
| Battlefield | Isometric grid with height. Jump limits climbing, melee reach is limited by height difference, bows and guns arc over it. 4-way camera rotation, pinch/drag/zoom. |
| Facing | Side attacks halve the target's evade, back attacks cut it to a fifth. You pick a facing when you end a turn. |
| Races and jobs | 5 races (Human, Saurian, Sylph, Mossling, Nuwa), 23 jobs. Advanced jobs unlock by mastering abilities of other jobs (e.g. Knight needs 2 Squire abilities). Stat growth on level-up depends on the current job. |
| Learning through gear | Every weapon, armor piece and accessory teaches abilities. While equipped, the current job can use them. Winning battles gives AP to each one; at full AP the ability is mastered for good. |
| Ability slots | Primary job actions (mastered or gear-taught), a Secondary job (mastered actions only), one Reaction and one Support (mastered only). 92 actions, 8 reactions, 8 supports. |
| Equipment rules | Each job has its own weapon, body and head types; only some jobs can hold shields (Shieldbearer lifts that). Changing job unequips what the new job can't use. |
| Weapon unlocks | Shop stock expands after each story mission. Loot from battles is combined at the Bazaar into gear the shop doesn't sell; once crafted it joins the shop's stock. Rogues can steal weapons and armor from enemy clans (enemy rogues can steal yours). |
| Laws and Judges | Each day has a banned and a favored action. First offense is a yellow card, the second sends the unit to jail for 2 battles (bail costs gil). KOs and favored actions earn JP; 3 JP buys a Combo that grows with each ally next to the target. KO'd units recover after battle. |
| Statuses | Poison, Regen, Sleep, Silence, Blind, Slow, Haste, Stop, Protect, Shell, Immobilize, Disable, Doom, Boost, plus stat breaks. |
| Campaign | World map with travel (1 day per trip, laws change daily), 3 story missions, repeatable skirmishes, a pub with errands (send a unit away for a few battles), recruits who ask to join after wins, a 16-unit clan. Autosaves to localStorage. |

## The first three maps

1. **Briar Ford**: a river crossing with a bridge and shallows. Grimkin and a Wolfhound. Banned: Items.
2. **Cinder Quarry**: terraced cliffs up to height 7 around a lava pit, against the Ashfang clan (5 jobbed units with gear you can steal). Banned: Fire.
3. **Mirewood Hollow**: bog, deep water and trees, against the Mire Hag, Oozes (half physical damage, weak to fire) and a Sandmaw. Banned: Water.

## Code

- `js/data.js`: races, jobs, abilities, items, monsters, laws, maps, missions.
- `js/engine.js`: rules (stats, CT, movement, ranges, damage, statuses, reactions, laws, AI). No DOM, so it runs in Node.
- `js/game.js`: campaign state (save, shop, bazaar, missions, rewards, errands, recruits).
- `js/render.js`: isometric canvas renderer and procedural sprites.
- `js/ui.js`: screens and the battle controller.

## Tests

```
node tests/engine.test.js                       # data integrity, systems, AI-vs-AI battles on all 3 maps
python3 -m http.server 8765 &                   # then:
NODE_PATH=$(npm root -g) node tests/smoke.js    # Playwright: screens, shop, equip, a full story battle, save/reload
```

The Playwright test runs headless at 390x800. Balance has only been checked with AI-vs-AI runs, not by hand on a real phone.
