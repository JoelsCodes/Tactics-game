# Playtest run 3: whole campaign, AI party (Nov 2026)

Command: `godot --headless --path godot res://tests/campaign_sim.tscn -- retries=6 grind=4`.
Raw results: `run3.json` (every battle, levels, every skill learned) and `run3.log`. Headless only, not checked on a real display.

## Result
- Won: hallway, chamber, all five Riverford maps (map 4 took 2 tries, map 5 took 6 with 20 grinding replays), and a few later maps
  (mscout, mheart, bwroad, bwquarry, exgate, exprice, vsstreets, cwouter, cwgates). Lost most battles from chapter three on, even after 7 tries.
- Levels: grinding pushed Alaric to L65 by the end. Every vessel ends at L60-65; Lyra as Co-Captain stays at L13 (she only gains XP as a vessel).
- Skills learned by the end: **33** (rank E 17, D 8, C 8; none B/A/S). Bram 10, Merc 7, Gideon 6, Kaelen 4, Seraphine 4, Lyra 2. Every proficiency shows up.

## Why the losses do NOT measure difficulty
A debug run of Crown map 1 with the whole party set to L53 (enemies are L22) still lost: **Alaric dealt 4 damage in 35 rounds**, Bram 3, Merc 2,
Seraphine 0; only Kaelen (99) fought. Chapter three at L8 looks the same (Alaric 11 dealt, 74 taken). The AI party walks into range and hardly attacks,
and vessels are summoned only once enemies are close, so the King falls first. Enemies at L22 beat an L53 party, so the simulated party is the bottleneck, not enemy skills.
(Enemy level also adds almost nothing to enemy stats: an enemy's stats come from its kind and the chapter `TUNE`, so level gaps matter far less than in most RPGs.)

## What it still tells us
- Chapters 1-2 (where the party AI does fight) are tuned about right: the first maps are easy, and Riverford 5 is a real wall that needs grinding.
- Learning by use works but is slow: 33 skills over ~800 simulated battles, and no B/A/S skill was learned, because vessels only learn what their stones and relics give them.
- Lyra as Co-Captain falls far behind (L13 vs L60+). Worth deciding whether a Co-Captain should share the battle XP.
- Rank E skills dominate what is learned; if the owner wants rank B+ learned before the finale, stones from chapter 7 on need a higher B+ chance, or relics should carry ranked skills.

## Next step needed before trusting balance numbers
Fix the party AI in `campaign_sim`/`balance_sim` (it should attack when it can and summon earlier), then rerun. `campaign_sim` now has `debug=1`
(per-unit damage lines) and `boost=N` (start the party at level N) to check single battles.
