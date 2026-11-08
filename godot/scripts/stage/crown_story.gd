class_name CrownStory
extends RefCounted
## Chapter eight, "The Road to the Crown": the scenes StoryScene plays. The owner's dialogue is word for word; lines I wrote to join it are marked DRAFT.
## STORY CANON (godot/STORY_CANON.md): nothing here names Reave or Elowen, shows or mentions the grave, explains the messages that never arrived, or says why the King wants
## Alaric. The King is tired and sorrowful, not cruel; the royal soldiers are honorable and the scenes show them disarmed, hurt or retreating, never slaughtered.
##   cw_hill -> cw_b1_pre         first click on map 1: the capital in sight; the patrol on the King's highway
##   cw_b1_post                   the commander survives; the invitation that never arrived
##   cw_refugees                  the road of refugees (before Battle 2)
##   cw_b2_post                   the restraint of the defenders
##   cw_aldren / cw_b3_post       Captain Aldren's offer and oath; he is spared
##   cw_city / cw_b4_post -> cw_king    the city of crowns; Lyra's question; the retreating defenders left alone; the King's private scene (player only)
##   cw_b5_pre / cw_b5_post -> cw_throne    the palace gates; the commander steps aside; the doors open (chapter eight ends here)

const HILL := "res://samples/crown_hill.json"
const C1 := "res://samples/crown_1.json"
const C2 := "res://samples/crown_2.json"
const C3 := "res://samples/crown_3.json"
const C4 := "res://samples/crown_4.json"
const C5 := "res://samples/crown_5.json"
const STREET := "res://samples/crown_street.json"
const HALL := "res://samples/crown_hall.json"
const PAL := "res://samples/palace.json"


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["gideon", "Gideon", "They hold formation. Break the line, don't chase it."], ["seraphine", "Seraphine", "Archers on the wall. Stay out of their lines."],
		["warden", "Bram", "Eyes on that captain. The rest follow him."], ["mira", "Lyra", "Aim to stop them. Not to kill them."], ["kaelen", "Kaelen", "Last stretch. They'll be at their best."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


const SCENES := {
	# ---------------------------------------------------------------------------------------------- the capital in sight
	"cw_hill": {
		"id": "cw_hill", "map": HILL, "stage": [0, 0, 0, 0], "next": "cw_b1_pre", "follow": [8, 14],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.18, 0.1],
			["title", "CHAPTER EIGHT", "The Road to the Crown", 2.8],
			["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "bram", "warden", [8, 13], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 13], "E"],
			["spawn", "merc", "merc", [5, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 14], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 13], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 12], "E", {"tint": "vessel"}],
			["fade", 0.0, 2.0], ["beat", "start"],
			["walk", "alaric", [7, 17], {"t": 0.6}], ["look", "alaric", "E"], ["wait", 1.6], ["beat", "capital"],
			["walk", "gideon", [9, 17], {"t": 0.5}], ["look", "gideon", "E"], ["wait", 0.6],
			["say", "gideon", "GIDEON", "Those walls have stood for centuries."],
			["say", "kaelen", "KAELEN", "Comforting."],
			["say", "gideon", "GIDEON", "They're designed to withstand an army."],
			["say", "bram", "BRAM", "Good thing we're not an army."],
			["say", "merc", "MERC", "Not a very big one, anyway."],
			["wait", 0.8], ["look", "alaric", "E"],
			["say", "lyra", "LYRA", "There it is."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "lyra", "LYRA", "Are you ready?"],
			["wait", 1.6], ["bubble", "alaric", "..."],
			["say", "alaric", "ALARIC", "I don't know."],
			["wait", 0.8], ["look", "bram", "S"],
			["say", "bram", "BRAM", "That's a first."],
			["say", "alaric", "ALARIC", "What?"],
			["say", "bram", "BRAM", "You admitting it."],
			["bubble", "alaric", "~"], ["wait", 0.8],
			["say", "alaric", "ALARIC", "Don't get used to it."],
			["walk", "alaric", [7, 21], {"t": 0.6, "par": true}], ["walk", "bram", [8, 20], {"t": 0.6, "par": true}], ["walk", "lyra", [6, 20], {"t": 0.6, "par": true}],
			["walk", "merc", [5, 21], {"t": 0.6, "par": true}], ["walk", "gideon", [9, 20], {"t": 0.6, "par": true}], ["walk", "kaelen", [4, 20], {"t": 0.6, "par": true}], ["join"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 1: the King's highway
	"cw_b1_pre": {
		"id": "cw_b1_pre", "map": C1, "stage": [0, 0, 0, 0], "also_seen": ["cw_hill"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.12, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 4], "E", {"tint": "vessel"}],
			["spawn", "cmd", "riverband_brute", [7, 13], "W"], ["spawn", "p1", "squire", [5, 12], "W"], ["spawn", "p2", "squire", [9, 12], "W"], ["spawn", "p3", "hooded_cutthroat", [12, 14], "W"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 7], {"t": 0.5, "par": true}], ["walk", "bram", [8, 6], {"t": 0.5, "par": true}], ["walk", "lyra", [6, 6], {"t": 0.5, "par": true}], ["join"],
			["wait", 0.8], ["look", "cmd", "S"], ["beat", "patrol"],
			["say", "cmd", "COMMANDER", "Alaric. By order of His Majesty, you are to accompany us to the palace."],
			["say", "alaric", "ALARIC", "And if I refuse?"],
			["say", "cmd", "COMMANDER", "We have orders to bring you in."],
			["say", "alaric", "ALARIC", "Alive?"],
			["say", "cmd", "COMMANDER", "Yes."],
			["say", "alaric", "ALARIC", "So he can decide what to do with me himself."],
			["say", "cmd", "COMMANDER", "I don't know His Majesty's reasons."],
			["say", "alaric", "ALARIC", "Then stand aside."],
			["wait", 0.8], ["act", "cmd", "attack"],
			["say", "cmd", "COMMANDER", "I can't."],  # DRAFT: "the commander refuses"
			["fade", 1.0, 1.0],
		],
	},
	"cw_b1_post": {
		"id": "cw_b1_post", "map": C1, "stage": [0, 0, 0, 0], "cam": 14,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.12, 0.1],
			["spawn", "alaric", "king", [7, 12], "E"], ["spawn", "bram", "warden", [8, 11], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 11], "E"],
			["spawn", "merc", "merc", [5, 12], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 12], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 11], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 10], "E", {"tint": "vessel"}],
			["spawn", "cmd", "riverband_brute", [7, 15], "W"], ["spawn", "p1", "squire", [5, 16], "N"], ["spawn", "p2", "squire", [9, 17], "N"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["hold", "cmd", "hit", 2], ["hold", "p1", "ko", 2], ["hold", "p2", "hit", 2], ["wait", 0.8], ["beat", "patrol_down"],
			["say", "cmd", "COMMANDER", "You don't understand. The King wants to speak with you."],
			["say", "alaric", "ALARIC", "Then he should have sent an invitation."],
			["say", "cmd", "COMMANDER", "We did."],
			["wait", 1.2], ["bubble", "alaric", "!"],
			["say", "cmd", "COMMANDER", "Riders were sent weeks ago. None of them reached you."],  # DRAFT: "messengers were dispatched but never reached him" (who stopped them is not said)
			["wait", 1.4], ["look", "alaric", "N"], ["beat", "mystery"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the road of refugees
	"cw_refugees": {
		"id": "cw_refugees", "map": C1, "stage": [0, 0, 0, 0], "cam": 12,
		"folk": [["villager_man", [6, 10]], ["villager_girl", [8, 14]], ["villager_kid", [7, 16]], ["mechanic", [9, 20]]],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#c8a880", 0.2, 0.1],
			["spawn", "alaric", "king", [7, 4], "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 4], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 4], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 2], "E", {"tint": "vessel"}],
			["spawn", "woman", "villager_girl", [7, 11], "W"], ["spawn", "child", "villager_kid", [8, 11], "W"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 8], {"t": 0.5}], ["wait", 0.6], ["look", "woman", "S"], ["bubble", "woman", "!"], ["beat", "recognized"],
			["say", "woman", "WOMAN", "You're him."],
			["say", "alaric", "ALARIC", "Who?"],
			["say", "woman", "WOMAN", "The summoner."],
			["wait", 0.6], ["look", "child", "S"],
			["say", "woman", "WOMAN", "Please don't hurt us."],
			["wait", 0.6], ["bubble", "alaric", "..."],
			["say", "alaric", "ALARIC", "I'm not here for you."],
			["say", "woman", "WOMAN", "That's what soldiers always say."],
			["walk", "woman", [7, 18], {"t": 0.5, "par": true}], ["walk", "child", [8, 18], {"t": 0.5, "par": true}], ["join"],
			["wait", 1.0], ["walk", "lyra", [7, 7], {"t": 0.4}], ["look", "lyra", "E"],
			["say", "lyra", "LYRA", "They don't know you."],
			["say", "alaric", "ALARIC", "No."],
			["say", "lyra", "LYRA", "They only know what they've heard."],
			["wait", 1.6], ["beat", "rumors"],
			["fade", 1.0, 1.2],
		],
	},
	"cw_b2_post": {
		"id": "cw_b2_post", "map": C2, "stage": [0, 0, 0, 0], "cam": 12,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a8a8b0", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "bram", "warden", [8, 13], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 13], "E"],
			["spawn", "merc", "merc", [5, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 14], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 13], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 12], "E", {"tint": "vessel"}],
			["spawn", "d1", "ironhollow_sentinel", [8, 17], "N"], ["spawn", "d2", "hooded_cutthroat", [11, 16], "N"], ["spawn", "d3", "squire", [5, 18], "N"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["hold", "d1", "hit", 2], ["hold", "d2", "ko", 2], ["hold", "d3", "hit", 2], ["wait", 0.8], ["beat", "defenders"],
			["say", "gideon", "GIDEON", "They had opportunities to kill us."],
			["say", "alaric", "ALARIC", "They tried."],
			["say", "gideon", "GIDEON", "Not as hard as they could have."],
			["say", "kaelen", "KAELEN", "Perhaps we're charming."],
			["say", "gideon", "GIDEON", "I doubt that's it."],
			["wait", 1.2], ["look", "alaric", "N"], ["bubble", "alaric", "..."], ["beat", "notices"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Captain Aldren
	"cw_aldren": {
		"id": "cw_aldren", "map": C3, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a8a8b0", 0.16, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 4], "E", {"tint": "vessel"}],
			["spawn", "aldren", "aldren", [8, 14], "W"], ["spawn", "g1", "spectral_duelist", [5, 12], "W"], ["spawn", "g2", "spectral_duelist", [10, 12], "W"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 8], {"t": 0.5, "par": true}], ["walk", "lyra", [6, 7], {"t": 0.5, "par": true}], ["join"],
			["look", "aldren", "S"], ["wait", 0.6],
			["say", "aldren", "ALDREN", "You have made your point."],
			["say", "alaric", "ALARIC", "I haven't reached the King."],
			["say", "aldren", "ALDREN", "And how many more people must be hurt before you do?"],
			["say", "alaric", "ALARIC", "Tell your men to stand down."],
			["say", "aldren", "ALDREN", "I could ask the same of you."],
			["wait", 0.8],
			["say", "aldren", "ALDREN", "Surrender your weapons, send your companions back to wherever they came from, and I will take you to His Majesty under guard. You have my word."],  # DRAFT: "safe passage under guard if he surrenders his weapons and dismisses his vessels"
			["wait", 1.0], ["look", "alaric", "W"],
			["say", "alaric", "ALARIC", "And when I'm unarmed and alone?"],  # DRAFT: "Alaric refuses because he fears being imprisoned or executed"
			["say", "aldren", "ALDREN", "I don't know His Majesty's mind."],  # DRAFT: Aldren does not know the full reason
			["say", "alaric", "ALARIC", "Then we have nothing more to say."],  # DRAFT
			["wait", 0.8], ["act", "aldren", "attack"], ["flash"],
			["fade", 1.0, 1.0],
		],
	},
	"cw_b3_post": {
		"id": "cw_b3_post", "map": C3, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a8a8b0", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 11], "E"], ["spawn", "bram", "warden", [8, 10], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 10], "E"],
			["spawn", "merc", "merc", [5, 11], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 11], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 10], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 9], "E", {"tint": "vessel"}],
			["spawn", "aldren", "aldren", [7, 14], "W"], ["spawn", "g1", "spectral_duelist", [5, 15], "N"], ["spawn", "g2", "spectral_duelist", [10, 15], "N"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["hold", "aldren", "hit", 2], ["hold", "g1", "ko", 2], ["hold", "g2", "hit", 2], ["wait", 0.8],
			["walk", "alaric", [7, 13], {"t": 0.5}], ["beat", "approaches"],
			["say", "aldren", "ALDREN", "Finish it, then."],
			["say", "alaric", "ALARIC", "I'm not here to kill you."],
			["say", "aldren", "ALDREN", "Yet you've fought your way through half the capital's defenses."],
			["say", "alaric", "ALARIC", "I gave them a chance to stand aside."],
			["say", "aldren", "ALDREN", "And they gave you a chance to surrender."],
			["wait", 1.4], ["bubble", "alaric", "..."], ["beat", "no_answer"],
			["say", "aldren", "ALDREN", "You think you're the only man here fighting for something?"],
			["wait", 1.2], ["look", "alaric", "S"],
			["say", "alaric", "ALARIC", "Leave them. Bandage them if they'll allow it."],  # DRAFT: "He orders the party to leave Aldren alive"
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the city of crowns
	"cw_city": {
		"id": "cw_city", "map": STREET, "stage": [0, 0, 0, 0], "follow": [8, 11],
		"folk": [["villager_man", [5, 10]], ["villager_kid", [9, 16]], ["mechanic", [6, 19]], ["villager_girl", [8, 6]]],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.16, 0.1],
			["spawn", "alaric", "king", [7, 3], "E"], ["spawn", "bram", "warden", [8, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 2], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 2], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 1], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 9], {"t": 0.6, "par": true}], ["walk", "lyra", [6, 8], {"t": 0.6, "par": true}], ["walk", "bram", [8, 8], {"t": 0.6, "par": true}], ["join"],
			["look", "alaric", "N"], ["wait", 1.4], ["beat", "city"],
			["look", "lyra", "E"],
			["say", "lyra", "LYRA", "We can still stop."],
			["say", "alaric", "ALARIC", "We're almost there."],
			["say", "lyra", "LYRA", "That's not what I asked."],
			["wait", 1.4], ["look", "alaric", "E"],
			["say", "alaric", "ALARIC", "I need answers."],
			["say", "lyra", "LYRA", "Then remember that when you get them."],
			["wait", 1.2], ["shake", 0.03, 1.0], ["beat", "defense"],
			["say", "alaric", "ALARIC", "Whoever's in command: stand aside."],  # DRAFT: "the royal commander orders the party to surrender; Alaric refuses"
			["say", "alaric", "ALARIC", "No."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"cw_b4_post": {
		"id": "cw_b4_post", "map": C4, "stage": [0, 0, 0, 0], "next": "cw_king", "cam": 4,
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.16, 0.1],
			["spawn", "alaric", "king", [7, 16], "E"], ["spawn", "bram", "warden", [8, 15], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 15], "E"],
			["spawn", "merc", "merc", [5, 16], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 16], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 15], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 14], "E", {"tint": "vessel"}],
			["spawn", "r1", "squire", [5, 22], "E", {"alpha": 1.0}], ["spawn", "r2", "hooded_cutthroat", [9, 23], "E"], ["spawn", "r3", "ironhollow_sentinel", [7, 24], "E"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "r1", [5, 27], {"t": 0.35, "par": true}], ["walk", "r2", [9, 27], {"t": 0.35, "par": true}], ["walk", "r3", [7, 27], {"t": 0.35, "par": true}], ["wait", 1.0], ["beat", "retreat"],
			["say", "gideon", "GIDEON", "We could prevent them from regrouping."],
			["say", "alaric", "ALARIC", "They're retreating."],
			["say", "gideon", "GIDEON", "They may fight us again."],
			["say", "alaric", "ALARIC", "Then we'll deal with that when it happens."],
			["wait", 1.0], ["look", "gideon", "N"], ["bubble", "gideon", "~"], ["beat", "acknowledged"],
			["join"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- the King, alone (shown to the player only)
	"cw_king": {
		"id": "cw_king", "map": PAL, "stage": [0, 0, 0, 0], "also_seen": ["cw_b4_post"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#2a2a40", 0.3, 0.1],
			["spawn", "king_npc", "last_king", [6, 7], "E"], ["spawn", "adviser", "villager_man", [5, 2], "E", {"alpha": 0.0}],
			["fade", 0.0, 2.0], ["beat", "start"],
			["wait", 1.6], ["fadein", "adviser", 0.6], ["walk", "adviser", [5, 5], {"t": 0.5}], ["beat", "report"],
			["say", "king_npc", "KING", "How many dead?"],
			["say", "adviser", "ADVISER", "The reports are still coming in, Your Majesty."],
			["say", "king_npc", "KING", "And the summoner?"],
			["say", "adviser", "ADVISER", "He continues toward the palace."],
			["say", "king_npc", "KING", "I told them to bring him here."],
			["say", "adviser", "ADVISER", "He refuses to surrender."],
			["wait", 1.4], ["look", "king_npc", "W"],
			["say", "king_npc", "KING", "Then let him come."],
			["say", "adviser", "ADVISER", "Your Majesty?"],
			["say", "king_npc", "KING", "Withdraw the remaining soldiers from the streets. I will speak with him myself."],
			["wait", 0.8], ["bubble", "adviser", "..."],
			["say", "adviser", "ADVISER", "He may try to kill you."],
			["say", "king_npc", "KING", "I know."],
			["wait", 1.8], ["beat", "portrait"],
			["say", "king_npc", "KING", "But I have to try."],
			["wait", 2.0], ["beat", "alone"],
			["fade", 1.0, 1.6],
		],
	},
	# ---------------------------------------------------------------------------------------------- the palace gates
	"cw_b5_pre": {
		"id": "cw_b5_pre", "map": C5, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.16, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 4], "E", {"tint": "vessel"}],
			["spawn", "pcmd", "riverband_brute", [7, 17], "W"], ["spawn", "k1", "spectral_duelist", [4, 14], "W"], ["spawn", "k2", "spectral_duelist", [10, 14], "W"],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 8], {"t": 0.55, "par": true}], ["walk", "lyra", [6, 7], {"t": 0.55, "par": true}], ["join"],
			["look", "pcmd", "S"], ["wait", 0.8],
			["say", "pcmd", "COMMANDER", "The King has ordered the streets cleared. He has not ordered me to open these doors to an armed summoner."],  # DRAFT: a personal decision, not an order to kill
			["say", "pcmd", "COMMANDER", "I have guarded his family for thirty years. I will not stop now."],  # DRAFT
			["say", "alaric", "ALARIC", "I'm not asking you to die for him."],  # DRAFT
			["say", "pcmd", "COMMANDER", "No. Only to stand."],  # DRAFT
			["wait", 0.8], ["act", "pcmd", "attack"], ["flash"],
			["fade", 1.0, 1.0],
		],
	},
	"cw_b5_post": {
		"id": "cw_b5_post", "map": C5, "stage": [0, 0, 0, 0], "next": "cw_throne",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.16, 0.1],
			["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "bram", "warden", [8, 13], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 13], "E"],
			["spawn", "merc", "merc", [5, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 14], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 13], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 12], "E", {"tint": "vessel"}],
			["spawn", "pcmd", "riverband_brute", [7, 18], "W"], ["spawn", "k1", "spectral_duelist", [4, 17], "N"], ["spawn", "k2", "spectral_duelist", [10, 17], "N"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["hold", "pcmd", "hit", 2], ["hold", "k1", "ko", 2], ["hold", "k2", "hit", 2], ["wait", 1.0], ["beat", "kneels"],
			["say", "pcmd", "COMMANDER", "His Majesty is beyond those doors."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "pcmd", "COMMANDER", "Whatever you believe he's done... he is not the man you think."],
			["say", "alaric", "ALARIC", "Then I'll hear it from him."],
			["wait", 1.0], ["walk", "pcmd", [6, 18], {"t": 0.5}], ["look", "pcmd", "S"], ["beat", "steps_aside"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- before the throne
	"cw_throne": {
		"id": "cw_throne", "map": HALL, "stage": [0, 0, 0, 0], "also_seen": ["cw_b5_post"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8c890", 0.18, 0.1],
			["spawn", "alaric", "king", [7, 3], "E"], ["spawn", "bram", "warden", [8, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 2], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, 2], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "seraphine", [7, 1], "E", {"tint": "vessel"}],
			["fade", 0.0, 2.0], ["beat", "start"],
			["walk", "alaric", [7, 9], {"t": 0.7}], ["wait", 1.2], ["beat", "stops"],
			["walk", "bram", [8, 8], {"t": 0.4, "par": true}], ["walk", "lyra", [6, 8], {"t": 0.4, "par": true}], ["walk", "merc", [5, 8], {"t": 0.4, "par": true}],
			["walk", "gideon", [9, 8], {"t": 0.4, "par": true}], ["walk", "kaelen", [4, 8], {"t": 0.4, "par": true}], ["walk", "seraphine", [7, 7], {"t": 0.4, "par": true}], ["join"],
			["say", "bram", "BRAM", "Well, lad. This is it."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "merc", "MERC", "You've been talking about this since the beginning."],
			["say", "kaelen", "KAELEN", "No turning back now."],
			["look", "gideon", "E"],
			["say", "gideon", "GIDEON", "There is always a choice."],
			["wait", 0.6], ["look", "alaric", "S"],
			["say", "gideon", "GIDEON", "Remember that."],
			["look", "seraphine", "N"],
			["say", "seraphine", "SERAPHINE", "Whatever happens beyond those doors, the dead will not give you every answer."],
			["look", "alaric", "W"],
			["say", "lyra", "LYRA", "Whatever happens in there, you don't have to face it alone."],
			["wait", 1.0], ["look", "alaric", "S"],
			["say", "alaric", "ALARIC", "I never did."],
			["wait", 0.8], ["walk", "alaric", [7, 12], {"t": 0.8}], ["beat", "doors"],
			["shake", 0.03, 2.0], ["tint", "#ffffff", 0.45, 2.5], ["flash"], ["tint", "#ffffff", 0.9, 1.6],
			["fade", 1.0, 1.6],
			["title", "CHAPTER EIGHT COMPLETE", "The Road to the Crown", 3.4],
		],
	},
}
