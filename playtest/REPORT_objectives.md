# Objective maps with their real rules (Nov 2026)

`campaign_sim -- snap=playtest/run5.json retries=5 grind=3`: each objective map played with its real `ScenarioRules` (run on a stand-in stage, `tests/sim_stage.gd`), telegraphs landing, and the party AI going for the objective (`EnemyAI.party_objective`). The party starts at the levels run 5 had just before it first fought each map, with the same recruits. Skills learned up to then are not in run 5's log, so the party starts with none (a little weaker than run 5). Raw: `objectives_run1.json` / `.log`. Headless, AI party, not checked by a person.

| Map | Result | How it ended | Party at start |
|---|---|---|---|
| Ch3 phalanx (lantern bearers) | LOST x6 | a spirit carried off by round 6 | Alaric L4 |
| Ch3 pincer (soul-binders, clock) | LOST x6 | 4 spirits consumed (round 12) | L5 |
| Ch3 breaking (Warden withdraws) | won, 2nd try | | L8 |
| Ch3 ritual (apparatus drain) | LOST x6 | King down by round 11 | L10 |
| Ch3 judgment (Warden's telegraph) | won, 1st try | | L12 |
| Ch4 msiege (war standards) | LOST x6 | stalemate (700 turns) | L14 |
| Ch4 mlast (protect the memorial) | won, 1st try | | L20 |
| Ch4 mheart (Hollow Heart) | LOST x6 | stalemate (700 turns) | L26 |
| Ch5 bwhollow (Alaric weakened, Lyra only) | won, 1st try | | L27 |
| Ch9 pking (the King's second phase) | won, 3rd try | | L45 |
| Ch15 a15_5 (Elowen summons) | won, 4th try | | L79 |

## Why the five losses happen
1. **Phalanx is a race the party cannot win.** The nearest bearer starts 11 tiles from the exit and moves 3 a turn (out in about 4 turns); Alaric starts 16+ tiles away and a summoned vessel is only 1 tile a turn faster than a bearer. `allowed` is 0, so one escape loses. Fix ideas: `allowed` 1, bearers Move 2, or start them farther from the exit.
2. **Pincer's clock is too fast for the walk.** A spirit every 3 rounds, 4 lose: round 12. The soul-binders (40 HP, Defense 7) sit across a big scrolling map. Fix ideas: every 4 rounds, or 5-6 spirits, or binders with less HP.
3. **Ritual's drain plus the guards.** 6% of Alaric's HP a round, Lyra captured, the apparatus has 100 HP; Alaric falls by round 11. Fix ideas: 4%, or the apparatus at 70 HP.
4. **Msiege never ends.** Each standard calls a soldier every 3 rounds and the party (4 units) cannot clear the soldiers and reach the standards; stalemate at 700 turns. Fix ideas: every 4-5 rounds, or a cap on calls per standard.
5. **Mheart never ends.** The Hollow Heart (210 HP, Resistance 12) calls 2 echoes every few rounds with no limit (`boss_summon` has no `max` here, unlike Elowen's). Fix idea: give it a `max` (e.g. 6), like Elowen.
