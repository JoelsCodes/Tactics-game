class_name CrucibleStory
extends RefCounted
## Chapter three, rewritten (Nov 2026): the scenes StoryScene plays (the step language is in story_scene.gd). The owner's lines are word for word; the owner's
## paragraphs are shown as narration cards. Lines marked DRAFT are Claude's (listed in HANDOFF.md). The old war-table/gate/pincer/breaking scenes are gone (git history).
##   cr_unquiet          before 1 (first click)   at the base, "The Unquiet Dead"; ends at the world map
##   cr_silent_pre/post  Battle 1 The Silent Village     (map crucible_1)  post: Tomas
##   cr_convoy_pre/post  Battle 2 The Lantern Convoy     (map crucible_2)
##   cr_severing_pre/post Battle 3 The Severing          (map crucible_3)  the Soul Warden, the anchors
##   cr_price_pre/post   Battle 4 The Price of a Soul    (map crucible_4) post: Lyra breaks the bond
##   cr_judgment_pre/post Battle 5 The Warden's Judgment (map crucible_5) post chains into cr_heartbeat, the epilogue

const MAP_1 := "res://samples/crucible_1.json"
const MAP_2 := "res://samples/crucible_2.json"
const MAP_3 := "res://samples/crucible_3.json"
const MAP_4 := "res://samples/crucible_4.json"
const MAP_5 := "res://samples/crucible_5.json"

## DRAFT: Vesper's last word as Vesper flees, and what is said as each battle opens.
const FLEE := "The bond has weakened and yet they stay... Fascinating. I will not lose them to a skirmish. Withdraw!"


static func flee_line() -> Array:
	return ["soul_warden", "Soul Warden", FLEE]


static func opening(n: int) -> Array:
	# DRAFT barks as each battle opens
	return [[], ["warden", "Bram", "Cut the bearers down before they reach the arches."], ["merc", "Merc", "Break the binders. We haven't got long."],
		["mira", "Lyra", "Alaric, stay where I can see you."], ["mira", "Lyra", "Don't look at me. Look at the machine."], ["warden", "Bram", "Keep the lad safe, and the lady close."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})



const SCENES := {
	# ---------------------------------------------------------------------------------------------- the opening
	"cr_unquiet": {
		"id": "cr_unquiet", "map": "res://samples/base.json", "stage": [0, 0, 0, 0], "to_map": true, "follow": [26, 15],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true],
			["title", "CHAPTER THREE", "The Unquiet Dead", 2.4],
			["spawn", "alaric", "king", [26, 15], "S"], ["spawn", "bram", "warden", [26, 13], "S", {"tint": "vessel"}],
			["spawn", "merc", "merc", [26, 17], "S", {"tint": "vessel"}], ["spawn", "lyra", "mira", [24, 15], "N", {"tint": "vessel"}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["narrate", "The party has escaped Riverford. Vesper is still at large, but reports of something stranger begin reaching Alaric.", 4.5],
			["narrate", "Villages are reporting missing graveside apparitions, strange blue lights, and royal soldiers carrying iron lanterns.", 4.5],
			["narrate", "Merc has heard rumors about an abandoned settlement whose residents have stopped holding funerals.", 4.5],
			["beat", "rumors"],
			["say", "bram", "BRAM", "People see one blue light in a graveyard and suddenly every grandmother in the kingdom's being haunted."],
			["say", "merc", "MERC", "You're a ghost."],
			["say", "bram", "BRAM", "And a perfectly respectable one."],
			["look", "lyra", "S"],
			["say", "lyra", "LYRA", "Something is taking the dead. We should investigate."],
			["beat", "lyra"],
			["say", "alaric", "ALARIC", "Then we go."],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 1: The Silent Village
	"cr_silent_pre": {
		"id": "cr_silent_pre", "map": MAP_1, "stage": [0, 0, 0, 0], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["title", "BATTLE ONE", "The Silent Village", 2.2],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", "@captain", "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [8, 3], "E", {"tint": "vessel"}],
			["spawn", "s1", "riverband_brute", "@enemy0", "W", {"tint": "enemy"}], ["spawn", "s2", "riverband_brute", "@enemy1", "W", {"tint": "enemy"}],
			["spawn", "s3", "ironhollow_sentinel", "@enemy2", "W", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "Royal soldiers are dragging lanterns through the streets. Inside each lantern, a faint human silhouette struggles against the glass.", 5.0],
			["beat", "lanterns"],
			["say", "bram", "BRAM", "Grown men dragging lanterns about because they're afraid of ghosts. I've heard it all now."],  # DRAFT: the owner described Bram mocking them, no line
			["bubble", "bram", "!"], ["wait", 0.8],
			["narrate", "Bram's mood changes as he realizes the spirits inside are conscious.", 3.8],
			["say", "bram", "BRAM", "Those lanterns... they're looking back at us. Those aren't rattling chains. Those are men."],  # DRAFT
			["narrate", "Free three captured spirits before the Wardens carry them off the map.", 4.0],
			["fade", 1.0, 1.0],
		],
	},
	"cr_silent_post": {
		"id": "cr_silent_post", "map": MAP_1, "stage": [0, 0, 0, 0], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["spawn", "alaric", "king", [7, 4], "E"], ["spawn", "bram", "warden", [8, 5], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [5, 5], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [9, 4], "E", {"tint": "vessel"}],
			["spawn", "tomas", "squire", [7, 8], "W", {"tint": "vessel", "alpha": 0.0}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "A young soldier's soul is released from its lantern. He asks whether he can go home. He doesn't understand that he's dead.", 5.5],
			["fadein", "tomas", 1.2], ["fx", "tomas", "burst", 1.2], ["beat", "tomas"],
			["say", "tomas", "YOUNG SOLDIER", "My captain said to hold the bridge. I held it. Did we win?"],
			["walk", "bram", [8, 7], {"t": 0.5}], ["look", "bram", "E"],
			["say", "bram", "BRAM", "What's your name, lad?"],
			["say", "tomas", "TOMAS", "Tomas, sir."],
			["say", "bram", "BRAM", "Well, Tomas. You're relieved."],
			["say", "tomas", "TOMAS", "Relieved?"],
			["say", "bram", "BRAM", "Aye. You've done enough."],
			["narrate", "Bram stays beside him until the spirit fades peacefully.", 4.0],
			["fadeout", "tomas", 3.0], ["beat", "fade"],
			["look", "merc", "E"], ["bubble", "merc", "..."],
			["narrate", "Merc notices that Bram has gone quiet, but doesn't push him.", 4.0],
			["narrate", "The lanterns bear the seal of the Royal Office of Final Rest. Their cargo is being transported to a fortress known as the Crucible.", 5.5],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 2: The Lantern Convoy
	"cr_convoy_pre": {
		"id": "cr_convoy_pre", "map": MAP_2, "stage": [0, 0, 0, 0], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a8b8d0", 0.12, 0.1],
			["title", "BATTLE TWO", "The Lantern Convoy", 2.2],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", "@captain", "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [8, 3], "E", {"tint": "vessel"}],
			["spawn", "c1", "ironhollow_sentinel", "@enemy0", "W", {"tint": "enemy"}], ["spawn", "c2", "riverband_brute", "@enemy1", "W", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "The party intercepts the convoy and discovers that the souls aren't merely being imprisoned.", 4.5],
			["narrate", "Stop the convoy and destroy its soul-binding devices without allowing the captured spirits to be consumed.", 4.5],
			["fade", 1.0, 1.0],
		],
	},
	"cr_convoy_post": {
		"id": "cr_convoy_post", "map": MAP_2, "stage": [0, 0, 0, 0], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a8b8d0", 0.12, 0.1],
			["spawn", "alaric", "king", [7, 4], "E"], ["spawn", "bram", "warden", [8, 5], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [5, 5], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [9, 4], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "Their ether is being harvested.", 3.2],
			["narrate", "Documents recovered from the wagons reveal that the extracted energy maintains a protective barrier around several royal settlements.", 5.5],
			["look", "merc", "S"], ["bubble", "merc", "!"], ["beat", "documents"],
			["say", "merc", "MERC", "They're burning people after they're dead?"],
			["say", "bram", "BRAM", "Not people, according to the paperwork."],
			["say", "merc", "MERC", "You don't sound surprised."],
			["say", "bram", "BRAM", "I've heard worse excuses from better men."],
			["say", "lyra", "LYRA", "Does the barrier truly protect innocent families?"],  # DRAFT: the owner described the question, no line
			["say", "alaric", "ALARIC", "It might."],  # DRAFT
			["narrate", "This complicates the mission. Destroying the entire system could endanger civilians.", 4.5],
			["narrate", "The party decides to find another way to free the spirits without collapsing the barrier immediately.", 4.5],
			["narrate", "The Soul Warden has been expecting Alaric. The convoy carried a deliberate invitation to the Crucible.", 5.0],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 3: The Severing
	"cr_severing_pre": {
		"id": "cr_severing_pre", "map": MAP_3, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["title", "BATTLE THREE", "The Severing", 2.2],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [4, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [7, 2], "E", {"tint": "vessel"}],
			["spawn", "warden_foe", "soul_warden", [6, 10], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "The party meets the Soul Warden for the first time. He is calm, articulate, and almost courteous. He addresses Bram and Lyra as people rather than monsters.", 6.0],
			["beat", "warden"],
			["narrate", "Then he asks Alaric a question.", 2.6],
			["say", "warden_foe", "SOUL WARDEN", "When you call the dead, do you ask them to rise?"],
			["say", "alaric", "ALARIC", "They fight willingly."],
			["say", "warden_foe", "SOUL WARDEN", "That was not my question."],
			["say", "lyra", "LYRA", "And when you imprison them in those lanterns, do you ask them to stay?"],
			["say", "warden_foe", "SOUL WARDEN", "I do not ask a fever whether it wishes to be cured."],
			["narrate", "The Warden activates the ether anchors. Bram and Merc begin to flicker as their connections to Alaric weaken.", 4.5],
			["act", "warden_foe", "cast"], ["fx", "warden_foe", "circle", 1.8], ["flash"], ["shake", 0.04, 0.6],
			["fadeout", "bram", 0.3], ["fadeout", "merc", 0.3], ["fadein", "bram", 0.3], ["fadein", "merc", 0.3],
			["fadeout", "bram", 0.3], ["fadeout", "merc", 0.3], ["fadein", "bram", 0.3], ["fadein", "merc", 0.3], ["beat", "flicker"],
			["narrate", "He offers to release them permanently if Alaric relinquishes his power.", 4.0],
			["narrate", "Alaric hesitates.", 2.4],
			["narrate", "Bram steps forward.", 2.2],
			["walk", "bram", [7, 5], {"t": 0.4}],
			["say", "bram", "BRAM", "I spent forty years taking orders. Died following the last one."],
			["say", "warden_foe", "SOUL WARDEN", "And now you follow another master."],
			["say", "bram", "BRAM", "No. Now I follow someone worth following."],
			["narrate", "Alaric voluntarily loosens his hold over the vessels.", 3.6],
			["fx", "alaric", "burst", 1.4], ["fadeout", "bram", 0.6], ["fadeout", "lyra", 0.6], ["fadein", "bram", 0.6], ["fadein", "lyra", 0.6], ["beat", "loosen"],
			["narrate", "For a moment, Bram and Lyra are free to depart.", 3.6],
			["narrate", "Neither leaves.", 2.6],
			["fade", 1.0, 1.0],
		],
	},
	"cr_severing_post": {
		"id": "cr_severing_post", "map": MAP_3, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["spawn", "alaric", "king", [7, 6], "E"], ["spawn", "bram", "warden", [8, 5], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [5, 5], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [9, 6], "E", {"tint": "vessel"}],
			["spawn", "warden_foe", "soul_warden", [7, 12], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "The Warden is visibly shaken. His instruments confirm that the bond has weakened, yet the spirits remain.", 5.0],
			["bubble", "warden_foe", "?"], ["look", "warden_foe", "E"], ["beat", "shaken"],
			["narrate", "The Warden discovers that Alaric's companions can maintain their presence through their own will. He decides Lyra must be studied directly.", 5.5],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 4: The Price of a Soul 
	"cr_price_pre": {
		"id": "cr_price_pre", "map": MAP_4, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["title", "BATTLE FOUR", "The Price of a Soul", 2.2],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [4, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [7, 10], "E", {"tint": "vessel"}],
			["spawn", "warden_foe", "soul_warden", [9, 13], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "The Soul Warden captures Lyra using a device designed to separate a spirit from its summoner.", 4.5],
			["act", "warden_foe", "cast"], ["fx", "lyra", "circle", 1.8], ["flash"], ["shake", 0.05, 0.7], ["beat", "captured"],
			["narrate", "He believes that if he can isolate her, he can prove her loyalty is merely the product of Alaric's magic.", 5.0],
			["narrate", "Alaric attempts to break the device by drawing more ether through himself. It works briefly, but the strain nearly kills him.", 5.5],
			["fx", "alaric", "burst", 1.8], ["red"], ["hold", "alaric", "hit", 1], ["beat", "strain"],
			["narrate", "Bram rushes toward the apparatus, trying to tear its restraints apart.", 4.0],
			["walk", "bram", [7, 6], {"anim": "run", "t": 0.2}], ["shake", 0.04, 0.5],
			["say", "bram", "BRAM", "I've held gates against armies. Don't tell me I can't hold one damned door!"],
			["say", "lyra", "LYRA", "Bram. Stop."],
			["say", "bram", "BRAM", "Not leaving you in there."],
			["say", "lyra", "LYRA", "You're not leaving me. You're letting me choose."],
			["look", "bram", "W"],
			["narrate", "Bram looks toward Alaric, who can barely remain standing. For once, he has no clever remark.", 5.0],
			["narrate", "Lyra realizes the ritual can be reversed, but only if she willingly severs her remaining bond with Alaric.", 5.0],
			["narrate", "The Warden warns her that doing so will destroy her.", 3.4],
			["say", "warden_foe", "SOUL WARDEN", "Without an anchor, you are nothing."],
			["say", "lyra", "LYRA", "Then let us find out."],
			["fade", 1.0, 1.0],
		],
	},
	"cr_price_post": {
		"id": "cr_price_post", "map": MAP_4, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["spawn", "alaric", "king", [6, 5], "E"], ["spawn", "bram", "warden", [8, 5], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [4, 5], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [7, 10], "E", {"tint": "vessel"}],
			["spawn", "lyra_real", "mira", [7, 10], "E", {"alpha": 0.0}], ["spawn", "warden_foe", "soul_warden", [9, 13], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "She breaks the bond.", 3.0],
			["counter", "lyra", "show", 6], ["wait", 0.5], ["counter", "lyra", "shake", 4], ["beat", "counter_shake"],
			["flash"], ["shake", 0.06, 0.8], ["counter", "lyra", "vanish", 0],
			["narrate", "The chamber erupts in light. Her spectral form disappears.", 4.0],
			["fadeout", "lyra", 0.4], ["fx", "alaric", "burst", 2.0], ["fx", "alaric", "circle", 2.2], ["beat", "light"],
			["wait", 1.4],
			["narrate", "Silence. Then a heartbeat.", 3.6],
			["fadein", "lyra_real", 0.8], ["hold", "lyra_real", "hit", 1], ["beat", "kneel"],
			["narrate", "Lyra falls to her knees, breathing for the first time in years.", 4.5],
			["walk", "alaric", [7, 8], {"t": 0.4}],
			["say", "alaric", "ALARIC", "Lyra?"],
			["say", "lyra_real", "LYRA", "I'm here."],
			["say", "bram", "BRAM", "Well, I'll be damned."],
			["say", "merc", "MERC", "You already are."],
			["say", "bram", "BRAM", "Not now, Merc."],
			["narrate", "The Soul Warden's instruments begin registering something impossible: Lyra is fully alive.", 4.5],
			["look", "warden_foe", "E"], ["bubble", "warden_foe", "!"],
			["narrate", "He orders the remaining soldiers to capture her.", 3.4],
			["give_lyra"],
			["tint", "#000000", 0.5, 1.2],
			["title", "CO-CAPTAIN SYSTEM UNLOCKED", "Lyra is now an independent, living companion rather than a spirit sustained by Alaric's summoning bond. Deploy her on the field as your Co-Captain, or keep her as a vessel: never both at once.", 5.0],
			["narrate", "The Warden's ritual didn't create Lyra's new life. It accidentally revealed something unique about the bond she shared with Alaric. Neither the Warden nor the party fully understands it yet.", 6.0],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 5: The Warden's Judgment 
	"cr_judgment_pre": {
		"id": "cr_judgment_pre", "map": MAP_5, "stage": [0, 0, 0, 0], "cam": 9,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["title", "BATTLE FIVE", "The Warden's Judgment", 2.2],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", "@captain", "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [8, 3], "E"],
			["spawn", "warden_foe", "soul_warden", "@enemy0", "W", {"tint": "enemy"}], ["spawn", "g1", "ironhollow_sentinel", "@enemy1", "W", {"tint": "enemy"}],
			["spawn", "g2", "riverband_brute", "@enemy2", "W", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["narrate", "The Soul Warden refuses to allow Lyra to leave. For the first time, his composure begins to crack.", 5.0],
			["say", "warden_foe", "SOUL WARDEN", "You have no understanding of what you've done."],
			["say", "lyra", "LYRA", "Neither do you."],
			["say", "warden_foe", "SOUL WARDEN", "The dead do not return. They cannot. There are laws older than kings."],
			["say", "alaric", "ALARIC", "Then your laws were wrong."],
			["narrate", "The Warden orders his soldiers to capture Lyra alive.", 3.4],
			["walk", "bram", [7, 5], {"t": 0.4}],
			["narrate", "Bram steps between the soldiers and Alaric.", 3.2],
			["say", "bram", "BRAM", "Well, lad. Seems we've annoyed another important man."],
			["say", "merc", "MERC", "We could try diplomacy."],
			["say", "bram", "BRAM", "You tried that in Riverford."],
			["say", "merc", "MERC", "I was hoping we'd forgotten."],
			["narrate", "The battle begins.", 2.4],
			["fade", 1.0, 1.0],
		],
	},
	"cr_judgment_post": {
		"id": "cr_judgment_post", "map": MAP_5, "stage": [0, 0, 0, 0], "cam": 9, "next": "cr_heartbeat",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#7088a8", 0.1, 0.1],
			["spawn", "alaric", "king", [6, 16], "E"], ["spawn", "bram", "warden", [8, 16], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [4, 16], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [7, 17], "E"],
			["spawn", "warden_foe", "soul_warden", [8, 22], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["narrate", "After the battle, the Warden collapses beside his broken lantern.", 4.0],
			["hold", "warden_foe", "ko", 3], ["beat", "collapsed"],
			["say", "warden_foe", "SOUL WARDEN", "Do you understand what you are?"],
			["say", "lyra", "LYRA", "Not yet."],
			["say", "warden_foe", "SOUL WARDEN", "Then you are more dangerous than I imagined."],
			["say", "alaric", "ALARIC", "Release the rest of the spirits. Now."],  # DRAFT: the owner described the demand, no line
			["say", "warden_foe", "SOUL WARDEN", "Without stabilizing the barrier first, the settlements it protects will be left defenseless."],  # DRAFT
			["narrate", "Rather than ignore him, Alaric orders the party to use the remaining generators to maintain the barrier long enough for the spirits to be freed safely.", 6.0],
			["narrate", "Alaric doesn't simply destroy something because his enemy created it. He considers the consequences for innocent people.", 5.0],
			["fx", "bram", "burst", 1.4], ["fx", "merc", "burst", 1.4], ["flash"], ["beat", "generators"],
			["narrate", "The Warden is taken prisoner by surviving royal forces loyal to his office, who withdraw with him after the party leaves. His authority is shattered, but his research survives.", 6.5],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the epilogue
	"cr_heartbeat": {
		"id": "cr_heartbeat", "map": MAP_3, "stage": [0, 0, 0, 0], "cam": 9, "also_seen": ["cr_judgment_post"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#1c2a4a", 0.4, 0.1],
			["title", "EPILOGUE", "A Heartbeat", 2.2],
			["spawn", "alaric", "king", [9, 14], "W"], ["spawn", "lyra", "mira", [8, 9], "E"],
			["spawn", "bram", "warden", [6, 6], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [5, 7], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["narrate", "The party camps outside the ruined fortress. Merc examines the documents recovered from the Crucible. The experiments appear to have been authorized by someone far above the Soul Warden.", 6.5],
			["narrate", "Alaric stands apart from the others. Lyra approaches him.", 4.0],
			["walk", "lyra", [[9, 11], [9, 13]], {"t": 0.5}], ["look", "alaric", "W"], ["beat", "approach"],
			["say", "lyra", "LYRA", "You've been avoiding me."],
			["say", "alaric", "ALARIC", "I thought you might want to leave."],
			["say", "lyra", "LYRA", "Would you stop me?"],
			["say", "alaric", "ALARIC", "No."],
			["say", "lyra", "LYRA", "Good. Then we're making progress."],
			["narrate", "She sits beside him. For the first time, Alaric cannot sense her through ether. She's simply there.", 6.0],
			["beat", "sits"],
			["narrate", "Nearby, Bram is staring into the campfire. Merc joins him.", 4.0],
			["walk", "merc", [6, 7], {"t": 0.4}], ["look", "bram", "S"],
			["say", "merc", "MERC", "You haven't insulted anyone in nearly an hour."],
			["say", "bram", "BRAM", "Give me time."],
			["say", "merc", "MERC", "You're happy for her, aren't you?"],
			["say", "bram", "BRAM", "Course I am."],
			["say", "merc", "MERC", "Then why do you look miserable?"],
			["say", "bram", "BRAM", "Because I remember what it felt like."],
			["look", "merc", "E"],
			["say", "bram", "BRAM", "A heartbeat. Warm hands. Getting tired after a long march. Never thought I'd miss being tired."],
			["say", "merc", "MERC", "Do you want to live again?"],
			["say", "bram", "BRAM", "Don't know."],
			["wait", 1.2],
			["say", "bram", "BRAM", "Don't know if I ought to."],
			["narrate", "Merc doesn't ask what he means. For once, he understands when to remain quiet.", 5.0],
			["beat", "quiet"],
			["narrate", "The scene ends with Lyra watching the sunrise, feeling the warmth on her skin.", 5.0],
			["tint", "#ffd9a0", 0.22, 3.0], ["look", "lyra", "E"], ["beat", "sunrise"], ["wait", 1.5],
			["title", "END OF CHAPTER THREE", "The Unquiet Dead", 3.0],
			["fade", 1.0, 1.2],
		],
	},
}
