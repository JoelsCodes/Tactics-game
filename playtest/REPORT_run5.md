# Playtest run 5: level-up growth, smarter party, humans study from vessels (Nov 2026)

`godot --headless --path godot res://tests/campaign_sim.tscn -- retries=5 grind=3` (35 minutes). Raw: `run5.json`, `run5.log`. Headless only, not checked on a real display.
Limits: the AI plays the party (worse than a person); the special rules of chapters three and four (lanterns, spirit clock, drain, standards, memorial) are NOT simulated, those battles are played as defeat-all-enemies.

## Result: 64 of 72 story battles won, the campaign is finishable
- Riverford (ch2) and the opening: easy, all first try. Chapter 3 map 1: 3 tries.
- **Lost even after 6 tries and 15 replays:** ch3 phalanx, pincer, breaking, ritual; ch4 msiege, mlast; ch8 cwgates; ch11 ftower.
- From chapter five to fifteen almost everything falls on the first try; a few need 2-4 (pances, pking, aapproach, asentinels, alast, a12_3, a12_4, a14_5).
- Levels: Alaric L13 entering ch4, L26 after ch4's grinding, L45 at ch9, L79 at the end. Enemies are L46-62 in the final arc, so the party ends **15-17 levels above** them: the grinding forced by chapters three and four carries the party through the rest.

## Where to adjust
1. **Chapter three (maps 2-5) is the wall**, at enemy level 6-9 with a party of 5-12. In the simulator it is the only stretch where grinding does not help (Alaric gained 7 levels there and still lost). Suggest: chapter three `TUNE` atk -1 or -2 on maps 2-5, or fewer enemies in phalanx/pincer. (Its special rules are not simulated, so check by hand first.)
2. **Chapter four maps 3-4 (msiege, mlast)** lost after Alaric went L14 -> L26. Standards call reinforcements in the real game, which the sim leaves out, so these may be harder still. Suggest lighter waves there.
3. **Chapters five to seven are too easy** after that grinding (one try each). Enemies could rise 2-3 levels there, or chapters three/four could be softened so the party arrives at a lower level.
4. Single spikes: cwgates (ch8 finale) and ftower (ch11 map 3) were the only late losses; both are boss maps. Fine as walls; soften by 1 atk if they feel unfair.
5. Enemy skills: enemies already use every proficiency within their chapter rank; nothing here points at a single over-strong skill. The losses come with the King down, i.e. focus fire on Alaric (enemy AI weight `king` 10, `vessel` 15). Lowering `king` would make the early chapters gentler without touching skills.

## Skills learned by the end: 31
- By rank: E 4, D 7, C 5, B 7, A 6, S 2 (the stones' new ranks reach the party).
- By proficiency: Elemental 9, Void 6, Tactical 5, Status 4, Healing 4, Physical 3.
- By unit: Merc 7, Seraphine 6, Bram 4, Gideon 4, Kaelen 4, Lyra 4, Alaric 2.
- **Humans learn very few:** Alaric 2 and Lyra 4 over the whole campaign. A human studies one skill at a time and only fills its bar by using it, and the AI only uses it when it is the best move. A player who uses the study skill every turn would learn more, but the pace is slow: worth a faster study rate for humans (e.g. 2x `proficiency_efficiency` while studying).

## Bonus
- Growth works: party HP/attack keep pace (see `tests/growth_check`).
- Cassian joins at L75 (one below Alaric) as intended.
- Lyra merged into the Co-Captain: one Lyra in the roster from chapter three on.
