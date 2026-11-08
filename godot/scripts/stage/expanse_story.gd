class_name ExpanseStory
extends RefCounted
## Chapter six, "The General Who Would Not Kneel": the scenes StoryScene plays (step language in story_scene.gd). The owner's dialogue is word for word; lines I wrote to
## join it are marked DRAFT. STORY CANON (godot/STORY_CANON.md): nothing here names Reave or Elowen, says who gave the order, or explains the regiment. Cassian has no proof
## about the King and never joins in this chapter; the King's palace scene is shown to the player only.
##   ex_opening                      first click on map 1: the old battlefield, then the creatures
##   ex_b1_post                      the marker of Cassian's last campaign
##   ex_arrival / ex_b2_post         the academy and Cassian; the critique of the gates
##   ex_king_talk / ex_b3_post -> ex_archive    what Cassian remembers of the King; the lesson; the record of the regiment that should not exist
##   ex_b4_pre / ex_b4_post          the academy failing and the cadet
##   ex_b5_pre / ex_b5_post -> ex_decision -> ex_king -> ex_leaving    the duel; Cassian refuses and gives the record; the King alone; the road

const E1 := "res://samples/expanse_1.json"
const E3 := "res://samples/expanse_3.json"
const E4 := "res://samples/expanse_4.json"
const E5 := "res://samples/expanse_5.json"
const ACAD := "res://samples/expanse_academy.json"
const ARC := "res://samples/archive.json"
const PAL := "res://samples/palace.json"


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["warden", "Bram", "Keep close. Whatever this is, it was a soldier once."], ["kaelen", "Kaelen", "Cadets on the left, archers on the walls. Stay off the open ground."],
		["gideon", "Gideon", "A shield line. Break it at one end, not the middle."], ["mira", "Lyra", "Alaric. Let them do their part."], ["warden", "Bram", "Right. Show the old man what we've learned."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


const SCENES := {
	# ---------------------------------------------------------------------------------------------- the old battlefield
	"ex_opening": {
		"id": "ex_opening", "map": E1, "stage": [0, 0, 0, 0], "cam": 8,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#9a9890", 0.18, 0.1],
			["title", "CHAPTER SIX", "The General Who Would Not Kneel", 2.8],
			["spawn", "alaric", "king", [7, 3], "E"], ["spawn", "bram", "warden", [8, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 2], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 2], "E", {"tint": "vessel"}],
			["spawn", "a1", "ironhollow_sentinel", [6, 13], "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "a2", "hollowmark_assassin", [10, 15], "W", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 6], {"t": 0.55, "par": true}], ["walk", "bram", [8, 5], {"t": 0.55, "par": true}], ["walk", "lyra", [6, 5], {"t": 0.55, "par": true}],
			["walk", "merc", [5, 6], {"t": 0.55, "par": true}], ["walk", "gideon", [9, 6], {"t": 0.55, "par": true}], ["walk", "kaelen", [4, 5], {"t": 0.55, "par": true}], ["join"],
			["look", "kaelen", "S"], ["bubble", "kaelen", "!"], ["wait", 0.4],
			["say", "kaelen", "KAELEN", "Lovely place. Nothing says pleasant afternoon like a thousand abandoned swords."],
			["look", "bram", "N"],
			["say", "bram", "BRAM", "Keep your voice down."],
			["say", "kaelen", "KAELEN", "Afraid you'll wake someone?"],
			["say", "bram", "BRAM", "In a place like this? Yes."],
			["walk", "gideon", [9, 9], {"t": 0.45}], ["look", "gideon", "S"], ["wait", 0.8], ["beat", "standard"],
			["say", "gideon", "GIDEON", "This battlefield was organized. Whoever commanded these men knew what he was doing."],
			["look", "alaric", "E"],
			["say", "alaric", "ALARIC", "Cassian Vale."],
			["say", "gideon", "GIDEON", "You've heard of him?"],
			["say", "alaric", "ALARIC", "They say he never lost a battle."],
			["say", "gideon", "GIDEON", "That doesn't mean he won the war."],
			["say", "alaric", "ALARIC", "I mean to find him."],  # DRAFT: the brief says Alaric explains that he wants to find Cassian
			["say", "lyra", "LYRA", "Another vessel?"],
			["say", "alaric", "ALARIC", "A commander."],
			["say", "merc", "MERC", "You already have Gideon."],
			["say", "kaelen", "KAELEN", "And he only complains about half our decisions."],
			["say", "gideon", "GIDEON", "More than half."],
			["wait", 0.8], ["look", "alaric", "E"],
			["say", "alaric", "ALARIC", "If I mean to face the King's forces, I have to learn to lead more than a handful of companions."],
			["wait", 1.0], ["shake", 0.03, 1.2], ["fadein", "a1", 0.8], ["fadein", "a2", 0.8], ["fx", "a1", "smoke", 1.0], ["bubble", "bram", "!"], ["beat", "rise"],
			["say", "bram", "BRAM", "Something's moving."],  # DRAFT: lead-in to the first battle
			["fade", 1.0, 1.0],
		],
	},
	"ex_b1_post": {
		"id": "ex_b1_post", "map": E1, "stage": [0, 0, 0, 0], "cam": 14,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#9a9890", 0.18, 0.1],
			["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "bram", "warden", [8, 13], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 13], "E"],
			["spawn", "merc", "merc", [5, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 14], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 13], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "gideon", [7, 17], {"t": 0.5}], ["look", "gideon", "S"], ["wait", 1.0], ["beat", "marker"],
			["say", "gideon", "GIDEON", "A marker. 'Fifth Army, final campaign.' Cassian Vale's."],  # DRAFT: the brief says only that the marker names Cassian's final campaign
			["wait", 0.6], ["look", "gideon", "E"],
			["say", "gideon", "GIDEON", "Brilliant, by every account. And notoriously difficult."],  # DRAFT
			["say", "gideon", "GIDEON", "If the stories are true, he'll be insufferable."],
			["say", "kaelen", "KAELEN", "You two should get along beautifully."],
			["wait", 0.6], ["look", "alaric", "E"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the academy
	"ex_arrival": {
		"id": "ex_arrival", "map": ACAD, "stage": [0, 0, 0, 0], "follow": [8, 11],
		"folk": [["squire", [5, 8]], ["squire", [7, 8]], ["squire", [9, 8]], ["squire", [6, 12]], ["squire", [8, 12]]],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0b890", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 2], "E"], ["spawn", "bram", "warden", [8, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 2], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [12, 11], "W", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 8], {"t": 0.5, "par": true}], ["walk", "bram", [8, 7], {"t": 0.5, "par": true}], ["walk", "lyra", [6, 7], {"t": 0.5, "par": true}],
			["walk", "merc", [5, 8], {"t": 0.5, "par": true}], ["walk", "gideon", [9, 8], {"t": 0.5, "par": true}], ["walk", "kaelen", [4, 7], {"t": 0.5, "par": true}], ["join"],
			["wait", 1.0], ["fadein", "cassian", 1.2], ["fx", "cassian", "burst", 1.0], ["cam", 12, 0.1], ["beat", "cassian"],
			["say", "cassian", "CASSIAN", "You are trespassing."],
			["say", "alaric", "ALARIC", "We're looking for General Cassian Vale."],
			["say", "cassian", "CASSIAN", "Then you've found him."],
			["say", "bram", "BRAM", "That was easy."],
			["say", "cassian", "CASSIAN", "Finding me is easy. Convincing me you're worth speaking to is another matter."],
			["say", "alaric", "ALARIC", "I'm building an army. I need someone who knows how."],  # DRAFT: the brief says Alaric explains he is assembling an army
			["say", "cassian", "CASSIAN", "How many?"],
			["say", "alaric", "ALARIC", "Four vessels. And Lyra."],
			["say", "cassian", "CASSIAN", "Five companions, then. Not an army."],
			["say", "alaric", "ALARIC", "That's why I'm here."],
			["say", "cassian", "CASSIAN", "And you believe I should entrust my experience to a young man who cannot distinguish between a friend and a soldier?"],
			["wait", 1.0], ["look", "alaric", "N"],
			["say", "alaric", "ALARIC", "I came to learn."],
			["wait", 1.0], ["bubble", "cassian", "?"], ["beat", "surprised"],
			["say", "cassian", "CASSIAN", "Then we shall see what you have learned. The gates."],  # DRAFT: "he agrees to test the party"
			["shake", 0.05, 1.2], ["flash"],
			["fade", 1.0, 1.0],
		],
	},
	"ex_b2_post": {
		"id": "ex_b2_post", "map": ACAD, "stage": [0, 0, 0, 0], "follow": [8, 12],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0b890", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 10], "E"], ["spawn", "bram", "warden", [8, 9], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 9], "E"],
			["spawn", "merc", "merc", [5, 10], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 10], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 9], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [12, 11], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["wait", 0.8],
			["say", "cassian", "CASSIAN", "Your companions are capable."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "cassian", "CASSIAN", "Then why do you insist on fighting as though they're extensions of yourself?"],
			["say", "alaric", "ALARIC", "I don't."],
			["wait", 0.6], ["look", "cassian", "S"],
			["say", "cassian", "CASSIAN", "Good. Then you'll have no difficulty proving it."],
			["say", "cassian", "CASSIAN", "The drill field. Now."],  # DRAFT: "Cassian challenges Alaric to another test"
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the king cassian remembers
	"ex_king_talk": {
		"id": "ex_king_talk", "map": ACAD, "stage": [0, 0, 0, 0], "follow": [8, 11],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0b890", 0.2, 0.1],
			["spawn", "alaric", "king", [7, 9], "E"], ["spawn", "cassian", "spectral_duelist", [9, 12], "W", {"tint": "enemy"}],
			["spawn", "bram", "warden", [8, 5], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [5, 5], "E"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["say", "cassian", "CASSIAN", "You intend to kill him?"],
			["say", "alaric", "ALARIC", "Yes."],
			["say", "cassian", "CASSIAN", "Why?"],
			["say", "alaric", "ALARIC", "His soldiers burned my village."],
			["wait", 0.8], ["look", "cassian", "S"],
			["say", "cassian", "CASSIAN", "Did you see the order?"],
			["say", "alaric", "ALARIC", "I saw the soldiers."],
			["say", "cassian", "CASSIAN", "And their banners?"],
			["say", "alaric", "ALARIC", "Yes."],
			["say", "cassian", "CASSIAN", "Then you saw soldiers carrying royal banners. That tells you who they wanted you to think they served."],
			["say", "alaric", "ALARIC", "You weren't there."],
			["say", "cassian", "CASSIAN", "No. I wasn't."],
			["say", "alaric", "ALARIC", "Then don't tell me what happened."],
			["say", "cassian", "CASSIAN", "I'm not. I'm asking how certain you are of the man who ordered it."],
			["wait", 1.0], ["look", "alaric", "W"], ["bubble", "alaric", "..."], ["beat", "refuses"],
			["tint", "#b08850", 0.26, 3.0], ["wait", 1.6], ["beat", "later"],
			["walk", "alaric", [8, 11], {"t": 0.5}], ["look", "cassian", "N"],
			["say", "cassian", "CASSIAN", "I knew a man who walked through a plague-ridden town when his own advisers begged him to stay behind."],
			["say", "alaric", "ALARIC", "People change."],
			["say", "cassian", "CASSIAN", "They do."],
			["say", "alaric", "ALARIC", "And you think he couldn't have become cruel?"],
			["say", "cassian", "CASSIAN", "I think you should know the man you're planning to kill."],
			["wait", 1.2], ["beat", "end"],
			["fade", 1.0, 1.2],
		],
	},
	"ex_b3_post": {
		"id": "ex_b3_post", "map": E3, "stage": [0, 0, 0, 0], "next": "ex_archive", "cam": 14,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0b890", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "bram", "warden", [8, 13], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 13], "E"],
			["spawn", "merc", "merc", [5, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 14], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 13], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [7, 19], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "cassian", [7, 16], {"t": 0.5}], ["look", "cassian", "S"],
			["say", "cassian", "CASSIAN", "You protect your companions. But you carry every decision yourself, and you hand out responsibility as if it were a debt."],  # DRAFT: "he notices Alaric struggles to delegate"
			["say", "cassian", "CASSIAN", "You have courage."],
			["say", "alaric", "ALARIC", "Thank you."],
			["say", "cassian", "CASSIAN", "It wasn't a compliment."],
			["say", "bram", "BRAM", "I like him."],
			["say", "cassian", "CASSIAN", "Courage without judgment gets soldiers killed."],
			["wait", 0.8], ["look", "alaric", "N"],
			["say", "alaric", "ALARIC", "I've learned that."],
			["say", "cassian", "CASSIAN", "Then demonstrate it."],
			["wait", 0.8],
			["fade", 1.0, 1.2],
		],
	},
	"ex_archive": {
		"id": "ex_archive", "map": ARC, "stage": [0, 0, 0, 0], "also_seen": ["ex_b3_post"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0a860", 0.18, 0.1],
			["spawn", "alaric", "king", [8, 4], "E"], ["spawn", "cassian", "spectral_duelist", [9, 9], "W", {"tint": "enemy"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "bram", "warden", [5, 4], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 7], {"t": 0.55}], ["wait", 0.6], ["bubble", "alaric", "!"], ["beat", "found"],
			["narrate", "An old record: an illustration of a crowned falcon over two crossed blades. 'Royal regiment, disbanded after the Northern Campaign.'", 5.0],  # DRAFT: the brief describes the record only
			["say", "alaric", "ALARIC", "This regiment. What happened to it?"],
			["say", "cassian", "CASSIAN", "Disbanded after the Northern Campaign."],
			["say", "alaric", "ALARIC", "When?"],
			["say", "cassian", "CASSIAN", "Long before your time."],
			["say", "alaric", "ALARIC", "I saw these soldiers."],
			["wait", 0.6], ["look", "cassian", "S"],
			["say", "cassian", "CASSIAN", "Where?"],
			["say", "alaric", "ALARIC", "My village."],
			["say", "cassian", "CASSIAN", "You're certain of the insignia?"],
			["say", "alaric", "ALARIC", "Yes."],
			["say", "cassian", "CASSIAN", "Then either someone revived a forgotten regiment, or someone wanted you to recognize it."],
			["say", "alaric", "ALARIC", "Could the King have ordered its return?"],  # DRAFT: "Alaric asks whether the King could have ordered its return"
			["say", "cassian", "CASSIAN", "Perhaps. But there would be records. Men to equip. Officers to appoint. A regiment does not appear from nothing."],
			["wait", 0.6], ["bubble", "alaric", "!"],
			["say", "alaric", "ALARIC", "Then explain what I saw."],
			["say", "cassian", "CASSIAN", "I can't."],
			["wait", 1.4], ["beat", "unsolved"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 4: the price of victory
	"ex_b4_pre": {
		"id": "ex_b4_pre", "map": E4, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a89080", 0.18, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [7, 6], "W", {"tint": "enemy"}], ["spawn", "cadet", "squire", [7, 15], "S", {"tint": "vessel"}],
			["spawn", "c1", "squire", [3, 11], "E", {"tint": "enemy", "alpha": 0.0}], ["spawn", "c2", "squire", [12, 12], "W", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["shake", 0.06, 1.4], ["tint", "#ff6a5a", 0.3, 1.0], ["red"], ["fadein", "c1", 0.8], ["fadein", "c2", 0.8], ["beat", "failing"],
			["look", "cassian", "N"],
			["say", "cassian", "CASSIAN", "The academy's spirit-light is failing. The chambers are opening on their own."],  # DRAFT: "Cassian realizes the academy's energy is deteriorating"
			["bubble", "cadet", "!"], ["look", "alaric", "N"], ["beat", "cadet"],
			["say", "cassian", "CASSIAN", "Leave the cadet. Finish this quickly."],  # DRAFT: "he initially recommends abandoning the cadet"
			["say", "alaric", "ALARIC", "No."],  # DRAFT
			["wait", 0.6],
			["say", "alaric", "ALARIC", "Gideon, Kaelen: the cadet. The rest of us hold the line."],  # DRAFT: he coordinates rather than rushing
			["say", "gideon", "GIDEON", "Understood."],  # DRAFT
			["say", "kaelen", "KAELEN", "Finally, a plan that includes me."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"ex_b4_post": {
		"id": "ex_b4_post", "map": E4, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a89080", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 12], "E"], ["spawn", "bram", "warden", [8, 11], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 11], "E"],
			["spawn", "merc", "merc", [5, 12], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 13], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 13], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [7, 16], "W", {"tint": "enemy"}], ["spawn", "cadet", "squire", [9, 14], "W", {"tint": "vessel"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["wait", 0.8], ["look", "cassian", "S"], ["walk", "cassian", [7, 14], {"t": 0.5}],
			["say", "cassian", "CASSIAN", "You could have ended the battle sooner."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "cassian", "CASSIAN", "You risked your entire company for one soldier."],
			["say", "alaric", "ALARIC", "I trusted them to handle it."],
			["say", "cassian", "CASSIAN", "And if they'd failed?"],
			["say", "alaric", "ALARIC", "Then I'd have been responsible."],
			["wait", 1.2], ["beat", "pause"],
			["say", "cassian", "CASSIAN", "At least you understand that much."],
			["say", "cassian", "CASSIAN", "One last test. The duelling ground."],  # DRAFT: "He offers one final challenge"
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 5: the unbowed general
	"ex_b5_pre": {
		"id": "ex_b5_pre", "map": E5, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0b890", 0.14, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [7, 16], "W", {"tint": "enemy"}],
			["spawn", "g1", "ironhollow_sentinel", [3, 15], "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "g2", "ironhollow_sentinel", [12, 15], "W", {"tint": "enemy", "alpha": 0.0}],
			["spawn", "s1", "spectral_duelist", [5, 12], "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "s2", "spectral_duelist", [10, 12], "W", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["say", "cassian", "CASSIAN", "Anyone who asks for my allegiance should first be able to defeat me."],  # DRAFT: the brief says he believes this
			["act", "cassian", "attack"], ["flash"], ["fadein", "g1", 0.8], ["fadein", "g2", 0.8], ["fadein", "s1", 0.8], ["fadein", "s2", 0.8], ["fx", "cassian", "circle", 1.6], ["beat", "guard"],
			["say", "cassian", "CASSIAN", "My honor guard. Show him what an army looks like."],  # DRAFT
			["say", "alaric", "ALARIC", "Together."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"ex_b5_post": {
		"id": "ex_b5_post", "map": E5, "stage": [0, 0, 0, 0], "next": "ex_decision",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0b890", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 10], "E"], ["spawn", "bram", "warden", [8, 9], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 9], "E"],
			["spawn", "merc", "merc", [5, 10], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 10], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 9], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [7, 14], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["hold", "cassian", "hit", 2], ["wait", 1.0], ["play", "cassian", "idle"], ["beat", "defeated"],
			["say", "cassian", "CASSIAN", "You could have sacrificed one soldier and ended the battle sooner."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "cassian", "CASSIAN", "You risked five to save one."],
			["say", "alaric", "ALARIC", "And brought six home."],
			["say", "cassian", "CASSIAN", "You will not always be so fortunate."],
			["say", "alaric", "ALARIC", "Then I'll have to be better."],
			["wait", 0.8], ["look", "cassian", "S"],
			["say", "cassian", "CASSIAN", "You believe you can lead an army without losing anyone?"],
			["say", "alaric", "ALARIC", "No."],
			["say", "cassian", "CASSIAN", "Then what makes you different from me?"],
			["say", "alaric", "ALARIC", "I won't call their deaths a victory."],
			["wait", 1.4], ["beat", "different"],
			["fade", 1.0, 1.2],
		],
	},
	"ex_decision": {
		"id": "ex_decision", "map": ACAD, "stage": [0, 0, 0, 0], "next": "ex_king", "also_seen": ["ex_b5_post"], "follow": [8, 11],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.2, 0.1],
			["spawn", "alaric", "king", [7, 9], "E"], ["spawn", "bram", "warden", [8, 6], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 6], "E"],
			["spawn", "merc", "merc", [5, 7], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 7], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 6], "E", {"tint": "vessel"}],
			["spawn", "cassian", "spectral_duelist", [9, 12], "W", {"tint": "enemy"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["say", "alaric", "ALARIC", "Come with us."],
			["say", "cassian", "CASSIAN", "No."],
			["say", "merc", "MERC", "Well, that's new."],
			["say", "alaric", "ALARIC", "Why?"],
			["say", "cassian", "CASSIAN", "You've learned to lead five companions. You have not learned to lead five hundred."],
			["say", "alaric", "ALARIC", "Then teach me."],
			["say", "cassian", "CASSIAN", "Return when you have an army worth teaching."],
			["wait", 1.0], ["bubble", "cassian", "~"], ["beat", "records"],
			["say", "cassian", "CASSIAN", "The academy's records are yours to read: old battles, forgotten strongholds, places where powerful spirits may still linger."],  # DRAFT: the brief says he allows access to the surviving records
			["wait", 0.8], ["walk", "alaric", [8, 11], {"t": 0.4}],
			["say", "cassian", "CASSIAN", "Take it."],
			["say", "alaric", "ALARIC", "Why?"],
			["say", "cassian", "CASSIAN", "Because you're going to keep asking questions."],
			["say", "alaric", "ALARIC", "You think I'm wrong about the King."],
			["say", "cassian", "CASSIAN", "I think you're certain of something you haven't proved."],
			["say", "alaric", "ALARIC", "I know what happened to my village."],
			["say", "cassian", "CASSIAN", "I believe you."],
			["wait", 1.2],
			["say", "cassian", "CASSIAN", "Find out who gave the order."],
			["wait", 1.0], ["bubble", "alaric", "..."], ["beat", "accepts"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the king, alone (the player sees it; Alaric does not)
	"ex_king": {
		"id": "ex_king", "map": PAL, "stage": [0, 0, 0, 0], "next": "ex_leaving", "also_seen": ["ex_decision"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#2a2a40", 0.3, 0.1],
			["spawn", "king_npc", "last_king", [6, 7], "E"], ["spawn", "messenger", "villager_man", [5, 2], "E", {"alpha": 0.0}],
			["fade", 0.0, 2.2], ["beat", "start"],
			["wait", 2.0], ["fadein", "messenger", 0.6], ["walk", "messenger", [5, 5], {"t": 0.5}], ["beat", "arrives"],
			["say", "messenger", "MESSENGER", "Your Majesty. There are new reports concerning the summoner."],
			["say", "king_npc", "KING", "The young man?"],
			["say", "messenger", "MESSENGER", "Yes, Your Majesty."],
			["say", "king_npc", "KING", "Has he been found?"],
			["say", "messenger", "MESSENGER", "Not yet."],
			["look", "king_npc", "W"], ["wait", 1.4], ["beat", "portrait"],
			["say", "king_npc", "KING", "They say he can call the dead."],
			["say", "messenger", "MESSENGER", "So we've heard."],
			["say", "king_npc", "KING", "Do they remember?"],
			["say", "messenger", "MESSENGER", "Your Majesty?"],
			["say", "king_npc", "KING", "The spirits. Do they remember who they were?"],
			["say", "messenger", "MESSENGER", "I don't know."],
			["wait", 1.2], ["hold", "king_npc", "idle", 0],
			["say", "king_npc", "KING", "Then find him."],
			["walk", "messenger", [5, 1], {"t": 0.4}], ["fadeout", "messenger", 0.6],
			["wait", 2.0],
			["say", "king_npc", "KING", "Please."],
			["wait", 2.0], ["beat", "alone"],
			["fade", 1.0, 1.6],
		],
	},
	"ex_leaving": {
		"id": "ex_leaving", "map": E1, "stage": [0, 0, 0, 0], "cam": 18, "also_seen": ["ex_king"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.2, 0.1],
			["spawn", "alaric", "king", [7, 20], "E"], ["spawn", "gideon", "gideon", [8, 19], "E", {"tint": "vessel"}], ["spawn", "bram", "warden", [6, 18], "E", {"tint": "vessel"}],
			["spawn", "kaelen", "kaelen", [5, 20], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [9, 18], "E"], ["spawn", "merc", "merc", [4, 18], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 22], {"t": 0.6, "par": true}], ["walk", "bram", [6, 20], {"t": 0.6, "par": true}], ["walk", "kaelen", [5, 22], {"t": 0.6, "par": true}],
			["walk", "lyra", [9, 20], {"t": 0.6, "par": true}], ["walk", "merc", [4, 20], {"t": 0.6, "par": true}], ["walk", "gideon", [8, 21], {"t": 0.5}], ["join"],
			["say", "gideon", "GIDEON", "You handled him well."],
			["say", "alaric", "ALARIC", "He refused."],
			["say", "gideon", "GIDEON", "Aye."],
			["say", "alaric", "ALARIC", "Then we failed."],
			["say", "gideon", "GIDEON", "Did we?"],
			["say", "alaric", "ALARIC", "We came for a commander."],
			["say", "gideon", "GIDEON", "And left knowing what one looks like."],
			["act", "bram", "attack"], ["bubble", "bram", "!"],
			["say", "bram", "BRAM", "Careful, Gideon. Keep talking like that and he'll start charging us for lessons."],
			["wait", 0.8], ["look", "kaelen", "E"],
			["say", "kaelen", "KAELEN", "Still thinking about those soldiers?"],
			["say", "alaric", "ALARIC", "Yes."],
			["say", "kaelen", "KAELEN", "What are you going to do?"],
			["look", "alaric", "E"], ["wait", 1.0],
			["say", "alaric", "ALARIC", "Find out who sent them."],
			["wait", 1.6],
			["title", "END OF CHAPTER SIX", "The General Who Would Not Kneel", 3.2],
		],
	},
}
