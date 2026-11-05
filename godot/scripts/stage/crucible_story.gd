class_name CrucibleStory
extends RefCounted
## Chapter three, "The Crucible and the Crown": the scenes StoryScene plays (the step language is in story_scene.gd). The narration and every spoken line
## in the owner's script are used word for word; the owner's stage directions are played, not shown. Lines marked DRAFT are Claude's (listed in HANDOFF.md).
##   cr_table      before 1 The Phalanx      the Sunken Bastion's war table: "The Weight of Three"; chains into cr_gate
##   cr_gate       (chained)                 the ambush at the Iron Gate: the gates slam, Vesper and his phalanx
##   cr_pincer     before 2 The Pincer       Vesper triggers the battle-mages' runes
##   cr_breaking   before 3 The Breaking Point   Alaric falls, Lyra becomes flesh, Gideon and Kaelen arrive (Lyra: Co-Captain; two vessels join)
##   cr_end        after 3                   Vesper's escape, the Co-Captain system, the end of the chapter

const MAP_1 := "res://samples/crucible_1.json"
const MAP_2 := "res://samples/crucible_2.json"
const MAP_3 := "res://samples/crucible_3.json"

const MERC_1 := "Vesper didn't run back to the capital after our little courtyard reunion. He's reinforced every garrison between here and the Iron Spire. He knows we're hunting him."
const BRAM_1 := "Good. Let him gather his dogs in one place. Makes the slaughter cleaner."
const LYRA_1 := "It's not a slaughter, Bram. It's a trap. Vesper is using himself as bait to draw Alaric out into the open. And every time Alaric pulls more ether through that anchor of his... the strain on his lifeline multiplies. You're burning yourself alive, Alaric."
const VESPER_1 := "Look at you. A handful of ghosts and a disgraced peasant playing at being a king. It ends here, Alaric."
const ALARIC_1 := "It hasn't even started."
const LYRA_2 := "You missed, Captain."
const LYRA_3 := "You carry the war, Alaric. Let me carry the line."
const GIDEON_1 := "Someone woke the mountain. Let's clear the yard!"
const KAELEN_1 := "Keep your focus on the King's lapdogs! We've got a kingdom to reclaim!"

## DRAFT: Vesper's last word as Vesper flees, and what is said as each battle opens.
const FLEE := "That is impossible... she was a ghost! This is not over. Not while the crown still has a head to wear it!"


static func flee_line() -> Array:
	return ["vesper", "Vesper", FLEE]


static func opening(n: int) -> Array:
	return [[], ["warden", "Bram", "Shields up. Nothing gets past the line."], ["merc", "Merc", "Mages on both flanks. I'll find a way up there."], ["mira", "Lyra", "Alaric, stay behind me. Please."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


const SCENES := {
	# ---------------------------------------------------------------------------------------------- the war table
	"cr_table": {
		"id": "cr_table", "map": "res://samples/crucible_bastion.json", "stage": [0, 0, 0, 0], "next": "cr_gate",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.12, 0.1], ["wait", 0.6],
			["title", "CHAPTER THREE", "The Crucible and the Crown", 2.4],
			["fade", 0.0, 1.8], ["beat", "start"],
			["spawn", "alaric", "king", [11, 8], "S"], ["spawn", "bram", "warden", [8, 11], "W", {"tint": "vessel"}], ["spawn", "merc", "merc", [8, 4], "E", {"tint": "vessel"}],
			["spawn", "lyra", "mira", [5, 13], "W", {"tint": "vessel"}],
			["narrate", "The Sunken Bastion's war table is no longer just a slab of cold stone; it is the beating heart of an escalating ghost-war. Alaric stands at the head of the table, flanked by Bram, Merc, and Lyra. The quiet, hunted outcast of Oakhaven is drawing eyes—and targets.", 6.0],
			["beat", "table"],
			["say", "merc", "MERC", MERC_1],
			["say", "bram", "BRAM", BRAM_1],
			["look", "lyra", "S"], ["beat", "lyra"],
			["say", "lyra", "LYRA", LYRA_1],
			["narrate", "Alaric doesn't answer immediately. He meets Lyra's intense, worried gaze with that same absolute, unblinking silence. He knows the risk. But the crown is still on the King's head, and the fire still echoes in his blood.", 5.5],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the ambush at the Iron Gate
	"cr_gate": {
		"id": "cr_gate", "map": MAP_1, "stage": [0, 0, 0, 0], "also_seen": ["cr_table"], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true],
			["spawn", "alaric", "king", [6, 2], "E"], ["spawn", "bram", "warden", [8, 2], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [5, 2], "E", {"tint": "vessel"}],
			["spawn", "lyra", "mira", [7, 2], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "The party moves out under a slate-grey sky to strike a supply depot at the Iron Gate, but the road is dead silent. Too silent.", 4.0],
			["walk", "alaric", "@king", {"t": 0.8, "par": true}], ["walk", "bram", "@captain", {"t": 0.8, "par": true}], ["walk", "merc", [4, 3], {"t": 0.8, "par": true}], ["walk", "lyra", [7, 5], {"t": 0.8, "par": true}],
			["narrate", "As they step into a vast, roofless amphitheater of ancient stone, the gates slam shut behind them. Heavy portcullises drop with a deafening crash.", 4.0],
			["join"], ["shake", 0.07, 0.8], ["flash"], ["bubble", "alaric", "!"], ["beat", "slam"],
			["spawn", "vesper", "vesper", [14, 16], "S", {"alpha": 0.0}],
			["spawn", "p1", "ironhollow_sentinel", "@enemy0", "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "p2", "ironhollow_sentinel", "@enemy1", "W", {"tint": "enemy", "alpha": 0.0}],
			["spawn", "l1", "riverband_brute", "@enemy2", "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "x1", "stone_colossus", "@enemy3", "W", {"tint": "enemy", "alpha": 0.0}],
			["spawn", "h1", "hollowmark_assassin", "@enemy4", "W", {"tint": "enemy", "alpha": 0.0}],
			["cam", 12, 1.5], ["fadein", "vesper", 1.0], ["fadein", "p1", 0.8], ["fadein", "p2", 0.8], ["fadein", "l1", 0.8], ["fadein", "x1", 0.8], ["fadein", "h1", 0.8],
			["narrate", "From the shadowed arches above, Captain Vesper steps forward, flanked by an entire phalanx of royal battle-mages and elite executioners.", 4.0],
			["beat", "vesper"],
			["say", "vesper", "VESPER", VESPER_1],
			["walk", "alaric", [[6, 5]], {"t": 0.6}], ["bubble", "alaric", "..."],
			["say", "alaric", "ALARIC", ALARIC_1],
			["walk", "alaric", "@king", {"t": 0.6}],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- the pincer
	"cr_pincer": {
		"id": "cr_pincer", "map": MAP_2, "stage": [0, 0, 0, 0], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [4, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [9, 2], "E", {"tint": "vessel"}],
			["spawn", "m1", "hollowmark_assassin", "@enemy0", "W", {"tint": "enemy"}], ["spawn", "m2", "hollowmark_assassin", "@enemy1", "W", {"tint": "enemy"}],
			["spawn", "m3", "hollowmark_assassin", "@enemy2", "W", {"tint": "enemy"}], ["spawn", "m4", "hollowmark_assassin", "@enemy3", "W", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "Map 2: The Pincer. Vesper triggers the battle-mages' runes, filling the arena with blinding arc-lightning and suppression fire.", 4.5],
			["cam", 18, 1.6], ["act", "m1", "cast"], ["act", "m2", "cast"], ["act", "m3", "cast"], ["act", "m4", "cast"],
			["fx", "m1", "circle", 1.6], ["fx", "m3", "circle", 1.6], ["flash"], ["shake", 0.04, 0.8], ["beat", "runes"],
			["narrate", "Alaric pushes his body to the absolute limit, commanding the field, but a massive volley of magical shrapnel breaks through Bram's defense, pinning the vanguard and leaving Alaric completely exposed in the center.", 6.0],
			["cam", 8, 1.6], ["red"], ["bubble", "alaric", "..."],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- the breaking point
	"cr_breaking": {
		"id": "cr_breaking", "map": MAP_3, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [4, 2], "E", {"tint": "vessel"}],
			["spawn", "lyra", "mira", [7, 2], "E", {"tint": "vessel"}], ["spawn", "vesper", "vesper", [8, 38], "W"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "Vesper raises his obsidian blade, charging directly toward Alaric for a killing blow.", 3.4],
			["walk", "vesper", [[7, 28], [7, 14], [6, 8], [6, 5]], {"anim": "run", "t": 0.12, "par": true}],
			["narrate", "Map 3: The Breaking Point. Alaric tries to summon the deep ether, but his body seizes. The strain is too much; his vision goes black, and he drops to one knee.", 5.0],
			["red"], ["hold", "alaric", "hit", 1], ["join"], ["beat", "knee"],
			["narrate", "Vesper leaps forward, blade flashing down toward Alaric's neck.", 3.0],
			["jump", "vesper", [6, 4]], ["act", "vesper", "attack"],
			["narrate", "Before anyone can move, Lyra steps directly into the path of the blade.", 3.2],
			["walk", "lyra", [[7, 3], [6, 4]], {"t": 0.15}],
			["shake", 0.08, 0.7], ["flash"], ["bubble", "lyra", "CLANG"],
			["narrate", "Instead of passing through her spectral form like smoke, the obsidian edge strikes with a solid, deafening CLANG.", 4.0],
			["beat", "clang"],
			["spawn", "lyra_real", "mira", [7, 4], "S", {"alpha": 0.0}],
			["narrate", "A blinding surge of white-hot, living light explodes from Lyra's chest. The ethereal, translucent blue of her spirit violently shifts, hardening, warming, and catching the natural light.", 5.5],
			["flash"], ["fx", "alaric", "burst", 1.6], ["fx", "alaric", "circle", 1.8], ["fadeout", "lyra", 0.5], ["fadein", "lyra_real", 0.5], ["shake", 0.05, 0.8], ["beat", "flesh"],
			["narrate", "Her breath hitches—a ragged, genuine gasp of physical air filling lungs that haven't drawn a breath in centuries. Her heart violently starts to beat.", 4.5],
			["slide", "vesper", [6, 9]], ["bubble", "vesper", "!"],
			["narrate", "Vesper staggers back, shielding his eyes from the blinding radiance.", 3.0],
			["look", "lyra_real", "E"],
			["narrate", "Lyra stands over Alaric, entirely physical, bleeding a warm, crimson drop from her palm where she caught the blade bare-handed. She isn't just a spell-casting projection anymore; she is flesh, bone, and unbreakable will.", 6.0],
			["say", "lyra_real", "LYRA", LYRA_2],
			["look", "lyra_real", "W"], ["play", "alaric", "idle"],
			["say", "lyra_real", "LYRA", LYRA_3],
			["narrate", "As Lyra's transformation anchors the spatial rift wide open, the shockwave of her resurrection ripples through the ancient battleground. The massive surge of energy pulls two more heavy souls out of the ether to reinforce the crumbling line.", 6.0],
			["spawn", "gideon", "squire", [9, 5], "E", {"tint": "vessel", "alpha": 0.0}], ["spawn", "kaelen", "choir", [4, 5], "E", {"tint": "vessel", "alpha": 0.0}],
			["flash"], ["fadein", "gideon", 0.8], ["fadein", "kaelen", 0.8], ["fx", "gideon", "eruption", 1.8], ["fx", "kaelen", "burst", 1.8], ["beat", "vessels"],
			["narrate", "Vessel IV, the Iron Wall: Gideon, a towering, broad-shouldered mountain of a knight from an older era, wielding a colossal two-handed hammer that shatters the earth with a single blow. Vessel V, the Stormweaver: Kaelen, a fierce, tactical battle-mage whose hands crackle with raw, untamed tempest energy.", 7.0],
			["act", "gideon", "attack"], ["shake", 0.05, 0.6],
			["say", "gideon", "GIDEON", GIDEON_1],
			["act", "kaelen", "cast"], ["fx", "kaelen", "streak", 1.6],
			["say", "kaelen", "KAELEN", KAELEN_1],
			["give_ch3"], ["beat", "party"],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- the end of the chapter
	"cr_end": {
		"id": "cr_end", "map": MAP_3, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.12, 0.1],
			["spawn", "alaric", "king", [7, 8], "E"], ["spawn", "lyra", "mira", [8, 7], "E"], ["spawn", "bram", "warden", [6, 7], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [5, 8], "E", {"tint": "vessel"}],
			["spawn", "gideon", "squire", [9, 9], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 9], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "With Lyra now fully restored to flesh as Alaric's Co-Captain, backed by Gideon and Kaelen, the tide of the battle shatters entirely. The royal phalanx breaks.", 5.0],
			["narrate", "Vesper, bleeding from a deep gash on his shoulder and staring in absolute horror at Lyra's living, breathing form, triggers a desperate smoke-rune and vanishes into the high mountain mists, leaving his routed army behind.", 6.0],
			["look", "alaric", "S"], ["beat", "end"],
			["tint", "#000000", 0.5, 1.5],
			["title", "CO-CAPTAIN SYSTEM UNLOCKED", "Lyra is Alaric's permanent Co-Captain. Deploy her on the field, or keep her as a vessel: never both at once.", 4.0],
			["title", "END OF CHAPTER THREE", "The Crucible and the Crown", 2.6],
			["fade", 1.0, 1.0],
		],
	},
}
