# Story canon (SPOILERS: the owner's long-term plot; do not reveal ahead of the owner's chapters)

Read this before writing or editing any story scene, dialogue or enemy placement. Chapter five ends with the FIRST clue only. `tests/bellwether_check.gd` (`story_canon`) fails if chapter five names Reave, Elowen or a princess.

## What is true (known to the owner and to the future story, NOT to Alaric or the player yet)
1. The King did not destroy Alaric's village, did not know Alaric before the attack, and did not order it.
2. The King was a capable, compassionate ruler; the death of his daughter left him consumed by grief. He has withdrawn from his duties and searches for someone who can contact the dead. He has heard of Alaric's summoning and wants to find him, hoping Alaric can bring back his daughter.
3. Princess Elowen died years ago and is ALIVE again, through a rare phenomenon like Lyra's. She is a living human with summoning powers like Alaric's. Her father believes she is dead; she has not returned to him.
4. Elowen and Reave are genuinely in love (not controlled, not manipulated: a "Bonnie and Clyde" pair) and willingly conspire to overthrow the King. Reave is a living, intelligent, charismatic, dangerous human.
5. Reave planned the burning of Alaric's village to make the King look cruel and provoke rebellion. Alaric was never the target; his survival and summoner's gift were a surprise.
6. The attackers were vessels: Elowen summoned long-dead soldiers of a genuine royal regiment (historical armor, weapons and crest: a crowned falcon over two crossed blades). The King has no missing soldiers or stolen banners because they died generations ago. She dematerialized them afterward.
7. Later: when Alaric defeats the King, the King asks him to visit Elowen's grave and summon her spirit; Alaric finds none (she is alive); both conclude her soul has moved on.

## Rules for every agent
- Do NOT replace Reave with an ancient entity, demon, chancellor or royal adviser. Do NOT make Elowen mind-controlled. Do NOT make the King secretly responsible. Do NOT make Alaric a chosen target.
- Do not give other vessels Lyra's independence; do not add exceptions to the vessel rules (a summoner spends energy to materialize and sustain vessels; materialized vessels have free will and act within his range; when he is too hurt or tired they return to the Vessel World).
- Alaric keeps his revenge and his belief that the King did it until the owner's chapters change that, gradually.

## What chapter five shows (the only hints so far)
- A merchant: the roads are neglected, not cruel ("Neglect, perhaps... there's a difference"); an elder remembers the King feeding the town through a famine and that he was never the same after losing his little girl; some townsfolk grumble about taxes, others praise the crown.
- A veteran of the old army: the crest Alaric describes (a crowned falcon, two crossed blades) is a regiment that fought for the crown generations ago and "hasn't been carried in a very long time". Nobody explains it. Alaric dismisses the doubt.
- The village attack's look in the existing art and dialogue carries no crest detail (checked: the repo's earlier scenes only show armored squires), so the crest above is the first one named; later chapters and any art of the attack must use it.

## Chapters six and seven (what they show; nothing more)
- Chapter six (the Ashen Expanse, Cassian Vale): Cassian remembers the King as compassionate (he walked through a plague town against his advisers) and as changed after his daughter's death; he has no proof and says so. The academy archive shows the crest's regiment (disbanded after the Northern Campaign, long before Alaric was born): "either someone revived a forgotten regiment, or someone wanted you to recognize it." He gives Alaric a copy of the record and says "Find out who gave the order." The player (not Alaric) sees the King alone: "They say he can call the dead. Do they remember?... Then find him. Please." Cassian does NOT join (he may in a later chapter): there is deliberately no `Expanse.recruit`.
- Chapter seven (Vespera): the second clue, a burial record whose officer is the soldier Alaric saw, dead 112 years: "Someone brought him back." (Alaric and the player may now suspect vessels, but not who, and not that someone else summons.) The King, shown to the player only, sends an invitation, not soldiers: "I only wish to speak with him." Malrec is an independent villain (his own philosophy about keeping the dead); do not tie him to the plot. Seraphine joins as an ordinary vessel.
- `tests/late_check.gd` (`canon`) fails if either chapter says Reave, Elowen, princess or conspiracy, or settles who gave the order.

## Chapter eight (the capital): what it shows, and what it must not
- Shows: the King has ordered Alaric brought in ALIVE (soldiers say so; the invitations never arrived and nobody says why: do not blame Reave or anyone); the capital's soldiers are honorable (Captain Aldren, the palace commander) and are spared or left to retreat; frightened citizens know Alaric only by rumor (a quiet echo of his own certainty about the King); the King, shown to the player only, is exhausted and sorrowful ("Withdraw the remaining soldiers from the streets. I will speak with him myself... But I have to try."). The commander's warning at the palace: "he is not the man you think." Lyra to Alaric: "Remember that when you get them [answers]" (this line matters in chapter nine).
- Must not: show or mention the grave, name Reave or Elowen, give the King's reason, or show the throne room. Chapter eight ends with the doors opening and a white flash ("CHAPTER EIGHT COMPLETE"). Chapter nine, "The Last King", then begins at once (Alaric fights the final defenders and the King; afterwards the King asks him to summon Elowen at her grave and he finds no spirit). `tests/crown_check.gd` guards chapter eight's text.
