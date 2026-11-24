# Universal enemy sheet (levels 1-99)

Thirty enemy archetypes any map can pull from at any level: `EnemySheet.make("mage", 40, &"id", "Royal Mage")` gives a Battle-Mage built for level 40. Source: `scripts/units/enemy_sheet.gd`; every level of every archetype is in `docs/enemy_sheet.csv` (written by `tools/export_enemy_sheet.gd`, which also writes this page). Checked by `tests/enemy_sheet_check.tscn`.

## How it works (after Final Fantasy Tactics)

- **Enemies are built like the party.** In FFT an enemy is a unit with a job and a level near the party's, made by the same rules as your own units. Here each archetype is a job: a multiplier per stat (FFT's job multipliers: a Knight's high PA, a Wizard's high MA) and a growth grade per stat.
- **Growth is FFT's law.** FFT adds raw / (C + level) to a hidden raw stat at each level-up (C is the job's growth constant: lower grows faster). From level 1 to L that multiplies the stat by (C + L) / (C + 1), a straight line in the level. Our party already grows exactly this way: +5% of the starting value a level is C = 19. Grades: **S** 13, **A** 16, **B** 19 (the party's rate), **C** 24, **D** 32; Speed: **f** 45, **n** 66 (the party's), **s** 95.
- **Stat at level L** = base x multiplier x (C + L) / (C + 1). Base at level 1 (multiplier 1.0): Attack 5, Defense 6, Magic 7.5, Resistance 5, Speed 6, Will 8 (the chapters' early enemies, after their tuning). Move and Jump are fixed per archetype, as per FFT job.
- **HP is fitted to this game's pace.** Damage here is scaled up and HP down, so two pure peers would down each other in about one blow. The aim is three to five good blows, so a soldier's HP at level L is four of the King's basic blows at level L (the King as he grows, weapon power 8); each archetype's HP is that times its HP multiplier, shaped by its HP grade. HP is the number shown in battle; sheet enemies skip the chapters' enemy HP cap and curve and their attack ramp (those are for hand-written enemies that do not grow).
- **SP** comes from Will and Magic as for everyone; **EXP** is the archetype's multiplier x (20 + 5 x level).
- **Pace it gives:** the King downs a soldier of his own level in about 4 blows at every level. A soldier downs the King in about 1.2 blows at level 1, 2 at 20, 3 at 55 and 4 at 99 (the early levels are deadly, as the chapters' first enemies are; a map can soften it with `tune`, e.g. `{"atk": -2}`).

## The archetypes

| key | name | family | role | HP | Atk | Def | Mag | Res | Spd | Will | growth (HP Atk Def Mag Res Spd Will) | Move | Jump | EXP x | skills |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `soldier` | Soldier | people | - | x1.0 | x1.0 | x1.0 | x0.4 | x0.8 | x1.0 | x0.9 | B B B D C n C | 4 | 2 | 1.0 | Quick Jab, Crescent Strike, Shield Prod |
| `knight` | Knight | people | guardian | x1.3 | x1.15 | x1.6 | x0.3 | x0.9 | x0.6 | x0.9 | A B A D C s C | 3 | 1 | 1.25 | Shield Prod, Shoulder Barge, Grip Loosen |
| `archer` | Archer | people | skirmisher | x0.85 | x1.05 | x0.7 | x0.4 | x0.8 | x1.15 | x1.0 | B A C D C f B | 4 | 3 | 1.0 | Pin Down, Hamstring Cut, Dirty Sand Kick |
| `brawler` | Brawler | people | brute | x1.25 | x1.2 | x0.9 | x0.3 | x0.8 | x1.05 | x1.0 | S A B D C n B | 4 | 3 | 1.1 | Quick Jab, Twin Strike, Stunning Blow |
| `thief` | Thief | people | skirmisher | x0.8 | x0.95 | x0.7 | x0.4 | x0.8 | x1.35 | x1.0 | C B C D C f B | 5 | 4 | 1.0 | Feinting Lunge, Step-Aside Strike, Dirty Sand Kick |
| `mage` | Battle-Mage | people | caster | x0.7 | x0.4 | x0.6 | x1.5 | x1.15 | x1.0 | x1.6 | C D C S A n A | 4 | 2 | 1.1 | Ember Flick, Frost Prick, Static Snap, Fireball |
| `healer` | Healer | people | support | x0.8 | x0.45 | x0.75 | x1.25 | x1.3 | x0.95 | x1.8 | B D C A S n S | 4 | 2 | 1.1 | Bandage Hat, Hum a Tune, Soak |
| `hexer` | Hexer | people | support | x0.75 | x0.4 | x0.65 | x1.3 | x1.25 | x1.05 | x1.7 | C D C A A n A | 4 | 2 | 1.1 | Hush, Lullaby, Slow Spell, Itch Powder |
| `summoner` | Summoner | people | caster | x0.7 | x0.35 | x0.6 | x1.6 | x1.2 | x0.8 | x1.8 | C D C A A s A | 3 | 2 | 1.3 | Fireball, Chain Spark, Frost Lance |
| `lancer` | Lancer | people | - | x1.1 | x1.15 | x1.15 | x0.3 | x0.8 | x0.95 | x0.9 | B A B D C n C | 4 | 4 | 1.15 | Hamstring Cut, Rending Cut, Pin Down |
| `duelist` | Duelist | people | skirmisher | x1.0 | x1.2 | x0.9 | x0.7 | x1.0 | x1.05 | x1.1 | B A B C B n B | 4 | 3 | 1.2 | Feinting Lunge, Twin Strike, Rending Cut |
| `assassin` | Assassin | people | skirmisher | x0.8 | x1.15 | x0.65 | x0.4 | x0.75 | x1.45 | x1.0 | C A D D C f B | 5 | 4 | 1.2 | Twin Strike, Hamstring Cut, Step-Aside Strike |
| `spellblade` | Spellblade | people | - | x1.0 | x1.0 | x0.95 | x1.0 | x1.0 | x1.0 | x1.1 | B B B B B n B | 4 | 3 | 1.15 | Crescent Strike, Static Snap, Frost Lance |
| `commander` | Commander | people | support | x1.0 | x0.9 | x0.9 | x0.8 | x1.0 | x0.95 | x1.5 | B B B C B n A | 4 | 2 | 1.3 | Feinting Lunge, Shield Prod, Bonk |
| `chanter` | Chanter | people | support | x0.75 | x0.5 | x0.6 | x1.1 | x1.1 | x1.0 | x1.7 | C D C B A n S | 4 | 2 | 1.1 | Hum a Tune, Lullaby, Hush |
| `berserker` | Berserker | people | brute | x1.4 | x1.4 | x0.7 | x0.2 | x0.6 | x0.95 | x0.7 | S S C D D n D | 4 | 2 | 1.2 | Wild Swing, Rending Cut, Shoulder Barge |
| `crossbow` | Crossbowman | people | skirmisher | x0.85 | x1.2 | x0.75 | x0.3 | x0.8 | x0.9 | x0.9 | B A C D C n C | 3 | 2 | 1.05 | Pin Down, Cripple, Hamstring Cut |
| `alchemist` | Alchemist | people | support | x0.85 | x0.7 | x0.75 | x0.9 | x1.0 | x1.05 | x1.3 | B C C B B n B | 4 | 2 | 1.0 | Bandage Hat, Poison Spit, Itch Powder |
| `darkknight` | Dark Knight | people | brute | x1.2 | x1.2 | x1.2 | x1.1 | x0.9 | x0.9 | x1.2 | A A B B C n B | 4 | 2 | 1.4 | Hollow Touch, Rending Cut, Null Pulse |
| `beast` | Beast | monster | skirmisher | x0.95 | x1.1 | x0.6 | x0.2 | x0.6 | x1.3 | x0.8 | B A C D D f C | 5 | 3 | 0.9 | Hamstring Cut, Crescent Strike |
| `flyer` | Flyer | monster | skirmisher | x0.75 | x0.95 | x0.55 | x0.5 | x0.8 | x1.4 | x0.9 | C B D C C f C | 6 | 5 | 0.95 | Step-Aside Strike, Hamstring Cut, Dirty Sand Kick |
| `drake` | Drake | monster | brute | x1.5 | x1.3 | x1.2 | x1.0 | x1.0 | x0.95 | x1.0 | S A A B B n B | 4 | 3 | 1.6 | Wild Swing, Fireball, Rending Cut |
| `construct` | Construct | monster | guardian | x1.6 | x1.2 | x1.7 | x0.2 | x0.6 | x0.5 | x0.6 | A B S D D s D | 3 | 1 | 1.3 | Shoulder Barge, Stunning Blow, Grip Loosen |
| `ooze` | Ooze | monster | - | x1.3 | x0.7 | x1.2 | x0.6 | x0.5 | x0.5 | x0.8 | A C A C D s C | 3 | 1 | 0.8 | Grip Loosen, Poison Spit |
| `undead` | Undead | monster | brute | x1.15 | x1.05 | x0.9 | x0.4 | x0.6 | x0.7 | x0.6 | A B B D D s D | 3 | 2 | 0.9 | Rending Cut, Cripple, Grip Loosen |
| `wraith` | Wraith | monster | caster | x0.7 | x0.4 | x0.5 | x1.35 | x1.4 | x1.1 | x1.4 | C D D A S n A | 5 | 4 | 1.15 | Hollow Touch, Dim Light, Null Pulse |
| `fungus` | Fungus | monster | caster | x1.0 | x0.6 | x0.9 | x0.9 | x0.9 | x0.5 | x1.0 | B C B B B s B | 3 | 1 | 0.85 | Spark Sneeze, Itch Powder, Poison Spit |
| `shellback` | Shellback | monster | guardian | x1.0 | x1.0 | x1.4 | x0.2 | x0.7 | x0.75 | x0.7 | B B A D C s C | 3 | 2 | 0.9 | Shield Prod, Cripple, Grip Loosen |
| `fiend` | Fiend | monster | caster | x1.2 | x1.0 | x0.9 | x1.45 | x1.2 | x1.1 | x1.4 | A B B S A n A | 4 | 3 | 1.6 | Fireball, Chain Spark, Hollow Touch |
| `tyrant` | Tyrant | boss | - | x3.0 | x1.3 | x1.25 | x1.3 | x1.25 | x1.05 | x1.5 | A A A A A n A | 4 | 3 | 4.0 | Feinting Lunge, Twin Strike, Rending Cut, Fireball, Pin Down |

## At a glance (HP / Atk / Def / Mag / Res / Spd)

| archetype | Lv 1 | Lv 10 | Lv 20 | Lv 35 | Lv 55 | Lv 75 | Lv 99 |
|---|---|---|---|---|---|---|---|
| Soldier | 99 / 5 / 6 / 3 / 4 / 6 | 109 / 7 / 9 / 4 / 5 / 7 | 118 / 10 / 12 / 5 / 7 / 8 | 129 / 14 / 16 / 6 / 9 / 9 | 141 / 19 / 22 / 8 / 13 / 11 | 150 / 24 / 28 / 10 / 16 / 13 | 158 / 30 / 35 / 12 / 20 / 15 |
| Knight | 129 / 6 / 10 / 2 / 5 / 4 | 146 / 8 / 15 / 3 / 6 / 4 | 160 / 11 / 20 / 4 / 8 / 4 | 177 / 16 / 29 / 5 / 11 / 5 | 194 / 21 / 40 / 6 / 14 / 6 | 208 / 27 / 51 / 7 / 18 / 6 | 220 / 34 / 65 / 9 / 22 / 7 |
| Archer | 84 / 5 / 4 / 3 / 4 / 7 | 93 / 8 / 6 / 4 / 5 / 8 | 100 / 11 / 7 / 5 / 7 / 10 | 110 / 16 / 10 / 6 / 9 / 12 | 120 / 22 / 13 / 8 / 13 / 15 | 127 / 28 / 17 / 10 / 16 / 18 | 134 / 36 / 21 / 12 / 20 / 22 |
| Brawler | 124 / 6 / 5 / 2 / 4 / 6 | 145 / 9 / 8 / 3 / 5 / 7 | 162 / 13 / 11 / 4 / 7 / 8 | 182 / 18 / 15 / 5 / 9 / 9 | 202 / 25 / 20 / 6 / 13 / 11 | 216 / 32 / 25 / 7 / 16 / 13 | 230 / 41 / 32 / 9 / 20 / 16 |
| Thief | 79 / 5 / 4 / 3 / 4 / 8 | 84 / 7 / 6 / 4 / 5 / 10 | 90 / 9 / 7 / 5 / 7 / 11 | 97 / 13 / 10 / 6 / 9 / 14 | 104 / 18 / 13 / 8 / 13 / 18 | 110 / 22 / 17 / 10 / 16 / 21 | 115 / 28 / 21 / 12 / 20 / 25 |
| Battle-Mage | 70 / 2 / 4 / 11 / 6 / 6 | 74 / 3 / 5 / 18 / 9 / 7 | 79 / 3 / 6 / 27 / 12 / 8 | 85 / 4 / 8 / 39 / 17 / 9 | 91 / 5 / 11 / 55 / 24 / 11 | 96 / 6 / 14 / 71 / 31 / 13 | 101 / 8 / 18 / 90 / 39 / 15 |
| Healer | 79 / 2 / 5 / 9 / 7 / 6 | 87 / 3 / 6 / 14 / 11 / 6 | 94 / 4 / 8 / 20 / 15 / 7 | 103 / 5 / 11 / 28 / 22 / 9 | 113 / 6 / 14 / 39 / 32 / 10 | 120 / 7 / 18 / 50 / 41 / 12 | 126 / 9 / 22 / 63 / 52 / 14 |
| Hexer | 75 / 2 / 4 / 10 / 6 / 6 | 79 / 3 / 5 / 15 / 10 / 7 | 84 / 3 / 7 / 21 / 13 / 8 | 91 / 4 / 9 / 29 / 19 / 9 | 98 / 5 / 12 / 41 / 26 / 11 | 103 / 6 / 15 / 52 / 33 / 13 | 108 / 8 / 19 / 66 / 42 / 16 |
| Summoner | 70 / 2 / 4 / 12 / 6 / 5 | 74 / 2 / 5 / 18 / 9 / 5 | 79 / 3 / 6 / 25 / 13 / 6 | 85 / 4 / 8 / 36 / 18 / 7 | 91 / 5 / 11 / 50 / 25 / 8 | 96 / 6 / 14 / 64 / 32 / 9 | 101 / 7 / 18 / 81 / 41 / 10 |
| Lancer | 109 / 6 / 7 / 2 / 4 / 6 | 120 / 9 / 10 / 3 / 5 / 6 | 130 / 12 / 13 / 4 / 7 / 7 | 142 / 17 / 19 / 5 / 9 / 9 | 155 / 24 / 26 / 6 / 13 / 10 | 165 / 31 / 32 / 7 / 16 / 12 | 174 / 39 / 41 / 9 / 20 / 14 |
| Duelist | 99 / 6 / 5 / 5 / 5 / 6 | 109 / 9 / 8 / 7 / 7 / 7 | 118 / 13 / 11 / 9 / 10 / 8 | 129 / 18 / 15 / 12 / 14 / 9 | 141 / 25 / 20 / 17 / 19 / 11 | 150 / 32 / 25 / 21 / 24 / 13 | 158 / 41 / 32 / 26 / 30 / 16 |
| Assassin | 79 / 6 / 4 / 3 / 4 / 9 | 84 / 9 / 5 / 4 / 5 / 10 | 90 / 12 / 6 / 5 / 7 / 12 | 97 / 17 / 8 / 6 / 9 / 15 | 104 / 24 / 10 / 8 / 12 / 19 | 110 / 31 / 13 / 10 / 15 / 23 | 115 / 39 / 15 / 12 / 18 / 27 |
| Spellblade | 99 / 5 / 6 / 8 / 5 / 6 | 109 / 7 / 8 / 11 / 7 / 7 | 118 / 10 / 11 / 15 / 10 / 8 | 129 / 14 / 15 / 20 / 14 / 9 | 141 / 19 / 21 / 28 / 19 / 11 | 150 / 24 / 27 / 35 / 24 / 13 | 158 / 30 / 34 / 44 / 30 / 15 |
| Commander | 99 / 5 / 5 / 6 / 5 / 6 | 109 / 7 / 8 / 8 / 7 / 6 | 118 / 9 / 11 / 11 / 10 / 7 | 129 / 12 / 15 / 14 / 14 / 9 | 141 / 17 / 20 / 19 / 19 / 10 | 150 / 21 / 25 / 24 / 24 / 12 | 158 / 27 / 32 / 30 / 30 / 14 |
| Chanter | 75 / 3 / 4 / 8 / 6 / 6 | 79 / 3 / 5 / 12 / 8 / 7 | 84 / 4 / 6 / 16 / 12 / 8 | 91 / 5 / 8 / 22 / 17 / 9 | 98 / 7 / 11 / 31 / 23 / 11 | 103 / 8 / 14 / 39 / 29 / 13 | 108 / 10 / 18 / 49 / 37 / 15 |
| Berserker | 139 / 7 / 4 / 2 / 3 / 6 | 162 / 12 / 6 / 2 / 4 / 6 | 182 / 17 / 7 / 2 / 5 / 7 | 204 / 24 / 10 / 3 / 6 / 9 | 226 / 34 / 13 / 4 / 8 / 10 | 242 / 44 / 17 / 5 / 10 / 12 | 258 / 56 / 21 / 6 / 12 / 14 |
| Crossbowman | 84 / 6 / 5 / 2 / 4 / 5 | 93 / 9 / 6 / 3 / 5 / 6 | 100 / 13 / 8 / 4 / 7 / 7 | 110 / 18 / 11 / 5 / 9 / 8 | 120 / 25 / 14 / 6 / 13 / 10 | 127 / 32 / 18 / 7 / 16 / 11 | 134 / 41 / 22 / 9 / 20 / 13 |
| Alchemist | 84 / 4 / 5 / 7 / 5 / 6 | 93 / 5 / 6 / 10 / 7 / 7 | 100 / 6 / 8 / 13 / 10 / 8 | 110 / 8 / 11 / 18 / 14 / 9 | 120 / 11 / 14 / 25 / 19 / 11 | 127 / 14 / 18 / 32 / 24 / 13 | 134 / 17 / 22 / 40 / 30 / 16 |
| Dark Knight | 119 / 6 / 7 / 8 / 5 / 5 | 134 / 9 / 10 / 12 / 6 / 6 | 148 / 13 / 14 / 16 / 8 / 7 | 163 / 18 / 19 / 22 / 11 / 8 | 179 / 25 / 27 / 31 / 14 / 10 | 192 / 32 / 34 / 39 / 18 / 11 | 203 / 41 / 42 / 49 / 22 / 13 |
| Beast | 94 / 6 / 4 / 2 / 3 / 8 | 104 / 8 / 5 / 2 / 4 / 9 | 112 / 12 / 6 / 2 / 5 / 11 | 123 / 17 / 8 / 3 / 6 / 14 | 134 / 23 / 11 / 4 / 8 / 17 | 142 / 29 / 14 / 5 / 10 / 20 | 150 / 37 / 18 / 6 / 12 / 24 |
| Flyer | 75 / 5 / 3 / 4 / 4 / 8 | 79 / 7 / 4 / 5 / 5 / 10 | 84 / 9 / 5 / 7 / 7 / 12 | 91 / 13 / 7 / 9 / 9 / 15 | 98 / 18 / 9 / 12 / 13 / 18 | 103 / 22 / 11 / 15 / 16 / 22 | 108 / 28 / 13 / 18 / 20 / 26 |
| Drake | 149 / 7 / 7 / 8 / 5 / 6 | 174 / 10 / 11 / 11 / 7 / 6 | 195 / 14 / 15 / 15 / 10 / 7 | 218 / 20 / 22 / 20 / 14 / 9 | 242 / 27 / 30 / 28 / 19 / 10 | 260 / 35 / 39 / 35 / 24 / 12 | 276 / 44 / 49 / 44 / 30 / 14 |
| Construct | 159 / 6 / 10 / 2 / 3 / 3 | 179 / 9 / 17 / 2 / 4 / 3 | 197 / 12 / 24 / 2 / 5 / 4 | 218 / 16 / 35 / 3 / 6 / 4 | 239 / 22 / 50 / 4 / 8 / 5 | 256 / 28 / 64 / 5 / 10 / 5 | 271 / 35 / 82 / 6 / 12 / 6 |
| Ooze | 129 / 4 / 7 / 5 / 3 / 3 | 146 / 5 / 11 / 6 / 3 / 3 | 160 / 6 / 15 / 8 / 4 / 4 | 177 / 8 / 22 / 11 / 5 / 4 | 194 / 11 / 30 / 14 / 7 / 5 | 208 / 14 / 39 / 18 / 8 / 5 | 220 / 17 / 49 / 22 / 10 / 6 |
| Undead | 114 / 5 / 5 / 3 / 3 / 4 | 129 / 8 / 8 / 4 / 4 / 5 | 142 / 10 / 11 / 5 / 5 / 5 | 157 / 14 / 15 / 6 / 6 / 6 | 172 / 19 / 20 / 8 / 8 / 7 | 184 / 25 / 25 / 10 / 10 / 7 | 195 / 31 / 32 / 12 / 12 / 8 |
| Wraith | 70 / 2 / 3 / 10 / 7 / 7 | 74 / 3 / 4 / 15 / 12 / 7 | 79 / 3 / 5 / 21 / 17 / 8 | 85 / 4 / 6 / 30 / 24 / 10 | 91 / 5 / 8 / 42 / 34 / 12 | 96 / 6 / 10 / 54 / 44 / 14 | 101 / 8 / 12 / 68 / 56 / 16 |
| Fungus | 99 / 3 / 5 / 7 / 5 / 3 | 109 / 4 / 8 / 10 / 7 / 3 | 118 / 5 / 11 / 13 / 9 / 4 | 129 / 7 / 15 / 18 / 12 / 4 | 141 / 9 / 20 / 25 / 17 / 5 | 150 / 12 / 25 / 32 / 21 / 5 | 158 / 15 / 32 / 40 / 27 / 6 |
| Shellback | 99 / 5 / 8 / 2 / 4 / 5 | 109 / 7 / 13 / 2 / 5 / 5 | 118 / 10 / 18 / 2 / 6 / 5 | 129 / 14 / 25 / 3 / 8 / 6 | 141 / 19 / 35 / 4 / 11 / 7 | 150 / 24 / 45 / 5 / 14 / 8 | 158 / 30 / 57 / 6 / 17 / 9 |
| Fiend | 119 / 5 / 5 / 11 / 6 / 7 | 134 / 7 / 8 / 18 / 9 / 7 | 148 / 10 / 11 / 26 / 13 / 8 | 163 / 14 / 15 / 37 / 18 / 10 | 179 / 19 / 20 / 53 / 25 / 12 | 192 / 24 / 25 / 68 / 32 / 14 | 203 / 30 / 32 / 87 / 41 / 16 |
| Tyrant | 298 / 7 / 8 / 10 / 6 / 6 | 336 / 10 / 11 / 15 / 10 / 7 | 369 / 14 / 16 / 21 / 13 / 8 | 409 / 20 / 23 / 29 / 19 / 9 | 449 / 27 / 31 / 41 / 26 / 11 | 479 / 35 / 40 / 52 / 33 / 13 | 508 / 44 / 51 / 66 / 42 / 16 |

## Using it

```gdscript
# a level-40 mage under a map's own name, with the archetype's skills
var e := EnemySheet.make("mage", 40, &"crown_3_mage_1", "Royal Mage")
# other skills, and a map's tuning (HP x0.8, Attack -2)
var k := EnemySheet.make("knight", 40, &"crown_3_knight_1", "Crown Knight", ["Shield Prod", "Pin Down"], {"hp": 0.8, "atk": -2})
# just the numbers
var r := EnemySheet.row("thief", 25)  # {hp, atk, def, mag, res, spd, will, sp, move, jump, exp}
```

Nothing in the game uses the sheet yet: the chapters and the Proving Grounds still build their enemies from their own KINDS. Moving a map over is a one-line change per enemy.
