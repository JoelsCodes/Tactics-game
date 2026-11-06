class_name RiverfordStory
extends RefCounted
## Chapter two, "The Price of Embers": the scenes StoryScene plays (see its header for the step language). The narration cards and the spoken
## lines that are the owner's are used word for word (the market, the squire captain's aide, Merc's last stand and rise, the ledger). The owner's
## stage directions are played, not shown. Lines marked DRAFT are Claude's first drafts, for the owner to keep or rewrite (listed in HANDOFF.md).
## Where each scene plays: WorldData.SCENES (a map's "pre" scene runs first, then the battle; "post" runs after the first win).
##   rf_market        before 1 The Back Alleys     the market square: Merc faces Vesper, the squires chase him
##   rf_paths         before 2 The Tangled Paths   the Watch closes the canal district
##   rf_interception  before 3 The Interception    the squires have Merc cornered; the party arrives; Merc escapes
##   rf_lane          before 4 The Final Stand     dusk, the squires hold the lane to the courtyard
##   rf_awakening     before 5 Vesper's Wrath      Merc's death, his rise as a vessel, Vesper's reinforcements
##   rf_escape        after 5                      the dust settles; the end of the chapter

const MAP_1 := "res://samples/riverford_1.json"
const MAP_2 := "res://samples/riverford_2.json"
const MAP_3 := "res://samples/riverford_3.json"
const MAP_4 := "res://samples/riverford_4.json"
const MAP_5 := "res://samples/riverford_5.json"

# ---- the owner's lines
const MERC_1 := "It was a farming settlement! Families, children, people who couldn't swing a rusted butter knife! I hauled grain and iron out there myself just last season. You didn't clear out rebels, Captain. You slaughtered a pantry."
const VESPER_1 := "A pantry that harbored treasonous tongues, little merchant. The King's fire cleanses what it touches. You have a very generous heart, Merc... but generous men often forget where their loyalties lie. Or worse, who is watching them."
const MERC_2 := "No, no, you're—you're completely right, Captain! My mistake! Bad memory, must have been someone else's village. I'll just... close up shop. Good day!"
const VESPER_2 := "Such a shame. A man who talks too much about the dead usually ends up joining them. Run him down. Make it look like a street robbery gone wrong. Quietly."
const AIDE_1 := "Ambush! Guard the flank—!"
const MERC_3 := "P-Please—I'm just a merchant! I don't want any trouble! I'll give you my gold, my shop, everything—!"
const VESPER_3 := "I know. But peace of mind is priceless."
const MERC_4 := "You can burn the villages. You can cut down everyone who speaks. But you'll never stop the rot in your own throat, Vesper. I died a coward... but I won't leave this world with my mouth shut."
const VESPER_4 := "Then keep it shut in the dirt."
const MERC_5 := "I spent my whole life hiding behind crates and counting coins because I was too terrified to fight. I watched them burn my friends, and I stayed silent. I hated myself for it more than I feared their blades."
const MERC_6 := "I died with a coward's breath in my lungs. I refuse to stay dead with a coward's soul."
const MERC_7 := "Use me, Alaric. Point me at the bastards who wear crowns. Let me be the wall I was too weak to be in life. Help me avenge everything I was never brave enough to face."
const ALARIC_1 := "Rise. Your ledger is clear."

# ---- DRAFT lines (Claude's)
const LYRA_1 := "He said it out loud. In the middle of the market."  # DRAFT
const BRAM_1 := "And the captain heard every word."  # DRAFT
const LYRA_2 := "They'll kill him for it."  # DRAFT
const WATCH_1 := "Halt! By order of the Watch, this quarter is closed. Nobody passes."  # DRAFT
const BRAM_2 := "Stand aside, friend. We have no quarrel with the Watch."  # DRAFT
const WATCH_2 := "Then you have no business running through my streets."  # DRAFT
const LYRA_3 := "Every minute we spend here, that man's chances shrink."  # DRAFT
const VESPER_5 := "Deal with them. I will see to our friend myself."  # DRAFT
const AIDE_2 := "Hold the lane! The captain wants nobody near that courtyard."  # DRAFT
const BRAM_3 := "The captain wants. Of course."  # DRAFT
const LYRA_4 := "They would not guard it if Merc were already dead."  # DRAFT
const VESPER_6 := "What... what are you? Guards! GUARDS! Cut them down, every one of them!"  # DRAFT
const MERC_8 := "He ran. A man who burns villages ran from a dead merchant."  # DRAFT
const BRAM_4 := "The rot goes deeper than one captain."  # DRAFT
const LYRA_5 := "Three of us now."  # DRAFT
const FLEE := "You are no ghost... fine. The drains will keep me. Come and find me in the dark!"  # DRAFT, said by Vesper as Vesper flees

## What is said as battle `n` begins: [sheet, name, text] (a bark under the turn bar). DRAFT lines.
static func opening(n: int) -> Array:
	return [[], ["mira", "Lyra", "Hounds! The market scent drew them. Hold the lane!"], ["warden", "Bram", "Hold the bridges. They can only cross one at a time."],
		["mira", "Lyra", "The squires are between us and Merc. Break through them!"], ["warden", "Bram", "Mind the broken walls. One lane at a time."],
		["merc", "Merc", "Let me through. I have a few debts to collect."]][n]


## What Vesper says as Vesper leaves the fight (BattleSetup.flee_line): [sheet, name, text].
static func flee_line() -> Array:
	return ["vesper", "Vesper", FLEE]


## Any scene of chapters two and three by key.
static func scene(key: String) -> Dictionary:
	if CrucibleStory.SCENES.has(key):
		return CrucibleStory.SCENES[key]
	if MountainStory.SCENES.has(key):
		return MountainStory.SCENES[key]
	if BellwetherStory.SCENES.has(key):
		return BellwetherStory.SCENES[key]
	if ExpanseStory.SCENES.has(key):
		return ExpanseStory.SCENES[key]
	if VesperaStory.SCENES.has(key):
		return VesperaStory.SCENES[key]
	if CrownStory.SCENES.has(key):
		return CrownStory.SCENES[key]
	if FinaleStory.SCENES.has(key):
		return FinaleStory.SCENES[key]
	return SCENES.get(key, {"id": "", "map": MAP_1, "steps": []})


const SCENES := {
	# ---------------------------------------------------------------------------------------------- 1: the market
	"rf_market": {
		"id": "rf_market", "map": "res://samples/riverford_market.json", "stage": [6, 3, 7, 16],
		"folk": [["villager_man", [5, 2]], ["villager_girl", [13, 6]], ["villager_kid", [3, 10]], ["villager_kid", [15, 12]], ["villager_man", [13, 16]], ["mechanic", [2, 14]]],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#9fc4ff", 0.10, 0.1], ["wait", 0.6],
			["title", "CHAPTER TWO", "The Price of Embers", 2.2],
			["fade", 0.0, 1.8], ["beat", "start"],
			["spawn", "alaric", "king", [9, 0], "E"], ["spawn", "bram", "warden", [10, 0], "E"], ["spawn", "lyra", "mira", [8, 0], "E"],
			["walk", "bram", [10, 4], {"par": true, "t": 0.95}], ["walk", "lyra", [8, 4], {"par": true, "t": 0.95}], ["walk", "alaric", [9, 5], {"par": true, "t": 0.95}],
			["narrate", "The stone of the borderland trade town of Oakhaven's shadow is slick with early morning frost.", 3.0],
			["narrate", "Alaric, Bram, and Lyra keep their hoods low, slipping through the crowded market stalls in search of provisions. The air smells of salted fish and wet wool, but the conversation cutting through the market hum is entirely about ash.", 5.0],
			["join"], ["beat", "market"],
			["spawn", "merc", "merc", [9, 12], "E"],
			["spawn", "vesper", "vesper", [9, 18], "W"], ["spawn", "sq1", "squire", [8, 18], "W"], ["spawn", "sq2", "squire", [10, 18], "W"],
			["walk", "vesper", [9, 14], {"par": true, "t": 0.8}], ["walk", "sq1", [8, 15], {"par": true, "t": 0.8}], ["walk", "sq2", [10, 15], {"par": true, "t": 0.8}],
			["bubble", "alaric", "..."], ["join"], ["look", "alaric", "E"], ["look", "bram", "E"], ["look", "lyra", "E"], ["beat", "face"],
			["say", "merc", "MERC", MERC_1],
			["walk", "vesper", [9, 13], {"t": 0.7}], ["beat", "closer"],
			["say", "vesper", "VESPER", VESPER_1],
			["bubble", "merc", "!"], ["shake", 0.012, 0.5], ["wait", 0.5],
			["walk", "merc", [9, 11], {"t": 0.45}], ["look", "merc", "E"],
			["say", "merc", "MERC", MERC_2],
			["walk", "merc", [[6, 11], [0, 10]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["wait", 0.5], ["look", "vesper", "E"],
			["say", "vesper", "VESPER", VESPER_2],
			["walk", "sq1", [[8, 11], [5, 11], [0, 10]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["walk", "sq2", [[10, 11], [6, 11], [0, 10]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["wait", 0.8],
			["say", "lyra", "LYRA", LYRA_1], ["say", "bram", "BRAM", BRAM_1], ["say", "lyra", "LYRA", LYRA_2],
			["bubble", "alaric", "!"], ["wait", 0.5],
			["walk", "alaric", [[9, 8], [6, 9], [0, 9]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["walk", "bram", [[10, 8], [6, 8], [0, 8]], {"anim": "run", "t": 0.22, "hide": true, "par": true}],
			["walk", "lyra", [[8, 8], [6, 10], [0, 10]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["fade", 1.0, 1.4], ["join"], ["bars", false],
			["narrate", "Merc sprints through the winding, muddy back-alleys, his breath tearing in his throat. He's terrified—tripping over crates, shoving past fishmongers, every instinct screaming at him to curl into a ball. Yet, raw adrenaline keeps his legs moving.", 5.5],
			["narrate", "Behind him, heavy armored boots pound the cobblestones. The squires are gaining.", 3.2],
			["narrate", "Cut to Alaric, Bram, and Lyra cutting across an intersection to intercept, only to be ambushed by a sudden pack of Rot-Hounds drawn by the market scent and town chaos.", 5.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- 2: the Watch
	"rf_paths": {
		"id": "rf_paths", "map": MAP_2, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [6, 2], "E"], ["spawn", "lyra", "mira", [8, 1], "E"],
			["spawn", "w1", "riverband_brute", "@enemy0", "W", {"tint": "enemy"}],
			["spawn", "s1", "hooded_cutthroat", "@enemy1", "W", {"tint": "enemy"}], ["spawn", "s2", "hooded_cutthroat", "@enemy2", "W", {"tint": "enemy"}],
			["spawn", "w3", "riverband_brute", "@enemy3", "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "The party carves through the hound pack, but the delay costs them. As they push forward to track Merc, they are intercepted by a patrol of Town Watchmen sent to secure the perimeter.", 5.0],
			["look", "w1", "W"], ["bubble", "w1", "!"], ["beat", "watch"],
			["say", "w1", "TOWN WATCHMAN", WATCH_1],
			["say", "bram", "BRAM", BRAM_2],
			["say", "w1", "TOWN WATCHMAN", WATCH_2],
			["say", "lyra", "LYRA", LYRA_3],
			["narrate", "It's a messy, frantic skirmish—Alaric commanding through absolute silence, Bram acting as a living wall, and Lyra dropping precision spells to manage the crowd. They are burning precious time.", 5.0],
			["act", "alaric", "attack"], ["wait", 0.6],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- 3: the interception
	"rf_interception": {
		"id": "rf_interception", "map": MAP_3, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true],
			["spawn", "merc", "merc", [7, 18], "W"],
			["spawn", "sq1", "squire", "@enemy0", "E"], ["spawn", "sq2", "squire", "@enemy1", "E"], ["spawn", "sq3", "squire", "@enemy2", "E"],
			["spawn", "aide", "squire", "@enemy3", "E"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "The party breaks through the street corner just in time to see Vesper's squires cornering Merc against a dead-end brick wall. Merc is backed into a corner, weaponless, trembling so hard he can barely stand.", 5.0],
			["bubble", "merc", "..."], ["act", "sq1", "attack"], ["act", "sq2", "attack"], ["wait", 0.4],
			["narrate", "As the squires raise their blades, Alaric and his party spill into the courtyard.", 3.0],
			["spawn", "alaric", "king", [7, 0], "E"], ["spawn", "bram", "warden", [8, 0], "E"], ["spawn", "lyra", "mira", [6, 0], "E"],
			["walk", "alaric", "@king", {"anim": "run", "t": 0.2, "par": true}], ["walk", "bram", [8, 2], {"anim": "run", "t": 0.2, "par": true}], ["walk", "lyra", [10, 1], {"anim": "run", "t": 0.2, "par": true}],
			["join"], ["beat", "arrive"],
			["narrate", "The sudden arrival—the towering, battered silhouette of Bram, Lyra's floating tomes, and Alaric's cold, piercing stare—creates just enough of a chaotic distraction.", 4.0],
			["look", "aide", "W"], ["look", "sq1", "W"], ["look", "sq2", "W"],
			["say", "aide", "SQUIRE CAPTAIN'S AIDE", AIDE_1],
			["slide", "merc", [7, 16]], ["bubble", "merc", "!"],
			["jump", "merc", [7, 13]],
			["walk", "merc", [[3, 13], [3, 16], [2, 16]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["spawn", "vesper", "vesper", [13, 15], "W", {"alpha": 0.0}],
			["fadein", "vesper", 0.8], ["beat", "vesper"],
			["walk", "vesper", [[10, 16]], {"t": 0.6}], ["look", "vesper", "W"],
			["say", "vesper", "VESPER", VESPER_5],
			["walk", "vesper", [[10, 12], [3, 13], [3, 16], [2, 16]], {"anim": "run", "t": 0.2, "hide": true, "par": true}],
			["look", "sq1", "W"], ["look", "sq2", "W"], ["look", "sq3", "W"], ["wait", 1.4], ["join"],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- 4: the lane at dusk
	"rf_lane": {
		"id": "rf_lane", "map": MAP_4, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#0a1030", 0.18, 0.1],
			["spawn", "alaric", "king", "@king", "W"], ["spawn", "bram", "warden", "@captain", "W"], ["spawn", "lyra", "mira", [7, 19], "W"],
			["spawn", "sq1", "squire", "@enemy0", "E", {"tint": "enemy"}], ["spawn", "sq2", "squire", "@enemy1", "E", {"tint": "enemy"}],
			["spawn", "sq3", "hooded_cutthroat", "@enemy2", "E", {"tint": "enemy"}], ["spawn", "aide", "squire", "@enemy3", "E", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "Alaric and the party quickly cut down the remaining squires, but the trail leads them into a desolate, stone-walled courtyard bathed in deep evening shadows.", 5.0],
			["say", "aide", "SQUIRE CAPTAIN'S AIDE", AIDE_2],
			["say", "bram", "BRAM", BRAM_3],
			["say", "lyra", "LYRA", LYRA_4],
			["act", "alaric", "attack"], ["wait", 0.5],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- 5: Merc's death and rise
	"rf_awakening": {
		"id": "rf_awakening", "map": MAP_5, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#0a1030", 0.16, 0.1],
			["spawn", "alaric", "king", [4, 4], "E"], ["spawn", "bram", "warden", [5, 3], "E"], ["spawn", "lyra", "mira", [3, 3], "E"],
			["spawn", "merc", "merc", [7, 15], "E"], ["spawn", "vesper", "vesper", [7, 17], "W"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [[4, 9], [4, 11]], {"t": 0.5, "par": true}], ["walk", "bram", [[5, 9], [5, 11]], {"t": 0.5, "par": true}], ["walk", "lyra", [[3, 9], [3, 11]], {"t": 0.5, "par": true}],
			["narrate", "At the far end, Captain Vesper has cornered Merc against a high stone barrier. Merc has nowhere left to run. He drops to his knees, his entire body shaking, his hands raised in surrender.", 4.5],
			["join"], ["hold", "merc", "hit", 1], ["beat", "kneel"],
			["narrate", "Vesper stands over him, drawing a long, obsidian-etched executioner's blade that catches the pale moonlight.", 3.2],
			["say", "merc", "MERC", MERC_3],
			["say", "vesper", "VESPER", VESPER_3],
			["narrate", "Vesper pauses, looking at Merc's trembling, pathetic posture. For a fraction of a second, something shifts in Merc. The trembling stops. The cowardice doesn't vanish—it wraps around a core of absolute, terrifying clarity. He looks up at the blade, then straight into Vesper's eyes, finding a sudden, bizarre reservoir of spine.", 6.5],
			["say", "merc", "MERC", MERC_4],
			["say", "vesper", "VESPER", VESPER_4],
			["act", "vesper", "attack"], ["wait", 0.45], ["flash"], ["shake", 0.05, 0.6], ["play", "merc", "ko"], ["beat", "death"],
			["narrate", "The blade flashes downward. A sickening crunch echoes off the stone. Merc collapses, lifeless. Vesper turns away, sheathing his sword, entirely unaware of what happens next.", 4.5],
			["look", "vesper", "E"],
			["walk", "vesper", [[7, 21]], {"t": 0.8, "par": true}],
			["title", "THE SPECTRAL RISE", "", 1.6],
			["tint", "#1030a0", 0.34, 2.0],
			["narrate", "The map plunges into a deep, supernatural dusk. The air grows ice-cold. Vesper is already walking away, back toward the main road, oblivious.", 4.0],
			["spawn", "ghost", "merc", [7, 15], "W", {"tint": "vessel", "alpha": 0.0}],
			["fx", "alaric", "circle", 1.6],
			["narrate", "But down on the blood-stained stones, a heavy, suffocating blue light begins to pulse.", 3.2],
			["fadein", "ghost", 1.6], ["fx", "alaric", "burst", 1.4], ["flash"], ["beat", "ghost"],
			["narrate", "A spectral version of Merc sits up. He looks down at his glowing, phantom hands. There is no trembling left in them—only iron weight.", 4.2],
			["look", "alaric", "E"], ["play", "ghost", "idle"],
			["narrate", "He turns his head and locks eyes with Alaric. There is an instant, unspoken recognition. He doesn't explain how he knows Alaric; he simply stands up, his footsteps striking the stone with the heavy, resonant sound of a marching legion.", 5.5],
			["walk", "ghost", [[7, 13]], {"t": 0.8}], ["shake", 0.02, 0.35],
			["walk", "ghost", [[5, 12]], {"t": 0.8}], ["shake", 0.02, 0.35],
			["walk", "ghost", [[5, 11]], {"t": 0.8}], ["shake", 0.02, 0.35], ["look", "ghost", "W"],
			["narrate", "As he approaches Alaric, Merc speaks, his voice echoing with a chilling, quiet fury.", 3.2],
			["say", "ghost", "MERC", MERC_5],
			["narrate", "He stops right in front of Alaric, looking down at his own phantom chest where the blade struck, then locking his blazing blue eyes onto Alaric.", 4.0],
			["say", "ghost", "MERC", MERC_6],
			["hold", "ghost", "hit", 1], ["wait", 0.5],
			["say", "ghost", "MERC", MERC_7],
			["narrate", "Alaric looks down at him, his face a mask of solemn granite. He extends a hand.", 3.6],
			["say", "alaric", "ALARIC", ALARIC_1],
			["play", "ghost", "idle"], ["flash"], ["give_merc"], ["beat", "vessel"],
			["narrate", "Merc is bound to Alaric as their newest vessel—bringing a strange, tactical cunning and hidden grit to the party.", 4.0],
			["look", "vesper", "W"], ["bubble", "vesper", "!"], ["shake", 0.03, 0.6], ["beat", "wrath"],
			["narrate", "Vesper spins around, realizing the magic behind him. Enraged and unnerved by the impossible sight, Vesper calls in a reinforcement wave of elite royal guards and battle-mages.", 5.0],
			["say", "vesper", "VESPER", VESPER_6],
			["spawn", "g1", "ironhollow_sentinel", [6, 23], "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "g2", "ironhollow_sentinel", [9, 23], "W", {"tint": "enemy", "alpha": 0.0}],
			["spawn", "m1", "hollowmark_assassin", [7, 23], "W", {"tint": "enemy", "alpha": 0.0}],
			["fadein", "g1", 0.6], ["fadein", "g2", 0.6], ["fadein", "m1", 0.6],
			["walk", "g1", [[6, 17]], {"anim": "run", "t": 0.2, "par": true}], ["walk", "g2", [[9, 17]], {"anim": "run", "t": 0.2, "par": true}], ["walk", "m1", [[7, 16]], {"anim": "run", "t": 0.2, "par": true}],
			["join"], ["wait", 0.6],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- after 5: the dust settles
	"rf_escape": {
		"id": "rf_escape", "map": MAP_5, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#0a1030", 0.2, 0.1],
			["spawn", "alaric", "king", [5, 7], "E"], ["spawn", "bram", "warden", [4, 6], "E"], ["spawn", "lyra", "mira", [6, 6], "E"], ["spawn", "merc", "merc", [5, 5], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "Vesper realizes the tide has turned. Battered and furious, he triggers a smoke-bomb rune, shattering the courtyard's stonework and escaping into the subterranean drainage tunnels before Alaric can deliver a killing blow.", 6.0],
			["say", "merc", "MERC", MERC_8],
			["say", "bram", "BRAM", BRAM_4],
			["say", "lyra", "LYRA", LYRA_5],
			["look", "alaric", "W"],
			["narrate", "The dust settles. The rebellion has its third soul, and the enemy knows they are no longer hunting ghosts—they are hunting an army.", 5.5],
			["tint", "#000000", 0.5, 1.5],
			["title", "END OF CHAPTER TWO", "The Price of Embers", 2.6],
			["fade", 1.0, 1.0],
		],
	},
}
