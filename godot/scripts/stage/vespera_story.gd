class_name VesperaStory
extends RefCounted
## Chapter seven, "The City of Silent Bells": the scenes StoryScene plays. The owner's dialogue is word for word; lines I wrote to join it are marked DRAFT.
## STORY CANON (godot/STORY_CANON.md): nothing here names Reave or Elowen, explains Lyra's return, or says the soldiers were summoned by someone. Malrec is independent of the
## King's story. The King's palace scene is shown to the player only.
##   vs_arrival                          first click on map 1: the silent towers, the woman at the grave, the vanished travellers
##   vs_b1_post                          the spirits are drawn toward the great bell tower
##   vs_seraphine / vs_b2_post           the Last Bell Keeper; what the cemetery and the resonance crystals reveal
##   vs_lyra / vs_b3_post                Seraphine and Lyra; the collection system was changed recently
##   vs_b4_pre / vs_b4_post              Malrec's argument; his escape up the tower
##   vs_b5_pre / vs_b5_post -> vs_decision (Seraphine joins) -> vs_archive (the officer) -> vs_king -> vs_leaving

const CITY := "res://samples/vespera_city.json"
const V1 := "res://samples/vespera_1.json"
const V2 := "res://samples/vespera_2.json"
const V3 := "res://samples/vespera_3.json"
const V4 := "res://samples/vespera_4.json"
const V5 := "res://samples/vespera_5.json"
const ARC := "res://samples/archive.json"
const PAL := "res://samples/palace.json"


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["choir", "Kaelen", "Quiet streets. I like them less than loud ones."], ["warden", "Bram", "Mind the graves. Somebody's grandmother is down there."],
		["squire", "Gideon", "Tight quarters. Hold the corridors."], ["mira", "Lyra", "They're not monsters. They're frightened. Remember that."], ["sorc", "Seraphine", "Ring it true, Malrec. Or I will."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


const SCENES := {
	# ---------------------------------------------------------------------------------------------- arrival in Vespera
	"vs_arrival": {
		"id": "vs_arrival", "map": CITY, "stage": [0, 0, 0, 0], "follow": [8, 10],
		"folk": [["villager_man", [5, 10]], ["villager_kid", [7, 12]], ["mechanic", [9, 6]], ["villager_girl", [6, 17]]],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#c88a60", 0.2, 0.1],
			["title", "CHAPTER SEVEN", "The City of Silent Bells", 2.8],
			["spawn", "alaric", "king", [7, 2], "E"], ["spawn", "bram", "warden", [8, 1], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 1], "E"],
			["spawn", "merc", "merc", [5, 2], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 2], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 1], "E", {"tint": "vessel"}],
			["spawn", "mourner", "villager_girl", [8, 12], "W"],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 6], {"t": 0.55, "par": true}], ["walk", "bram", [8, 5], {"t": 0.55, "par": true}], ["walk", "lyra", [6, 5], {"t": 0.55, "par": true}],
			["walk", "merc", [5, 6], {"t": 0.55, "par": true}], ["walk", "gideon", [9, 6], {"t": 0.55, "par": true}], ["walk", "kaelen", [4, 5], {"t": 0.55, "par": true}], ["join"],
			["look", "kaelen", "N"], ["wait", 0.6], ["tint", "#6a5a8a", 0.28, 3.0], ["beat", "silence"],
			["say", "kaelen", "KAELEN", "That's unsettling."],
			["say", "bram", "BRAM", "What is?"],
			["say", "kaelen", "KAELEN", "All those towers. Not a single bell."],
			["say", "gideon", "GIDEON", "Perhaps they've abandoned the tradition."],
			["say", "merc", "MERC", "Or someone stole the bells."],
			["say", "bram", "BRAM", "Who steals a bell?"],
			["say", "merc", "MERC", "Someone with a very large cart."],
			["look", "lyra", "S"], ["walk", "lyra", [7, 10], {"t": 0.5}], ["wait", 0.6], ["beat", "grave"],
			["say", "lyra", "LYRA", "Excuse me. The bells. Why have they stopped?"],  # DRAFT
			["say", "mourner", "WOMAN", "The bell keepers have vanished, one by one. Without them nobody dares ring the evening toll."],  # DRAFT: the brief says she explains it
			["say", "mourner", "WOMAN", "The city is frightened. And at night there are figures in the streets."],  # DRAFT
			["wait", 0.6], ["look", "alaric", "E"],
			["say", "alaric", "ALARIC", "We're only passing through."],  # DRAFT: Alaric initially intends to continue
			["say", "mourner", "WOMAN", "Then pass quickly, and not by the north road. A party of travelers went that way yesterday and never came back."],  # DRAFT: travelers vanished on the road beyond
			["wait", 0.8], ["bubble", "alaric", "..."],
			["say", "alaric", "ALARIC", "We'll look into it before we go."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"vs_b1_post": {
		"id": "vs_b1_post", "map": V1, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#6a5a8a", 0.3, 0.1],
			["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "bram", "warden", [8, 13], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 13], "E"],
			["spawn", "merc", "merc", [5, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 14], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 13], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["fx", "alaric", "burst", 1.4], ["fx", "bram", "streak", 1.2], ["wait", 1.2], ["look", "alaric", "N"], ["beat", "pulled"],
			["wait", 0.6], ["look", "lyra", "N"],
			["say", "lyra", "LYRA", "Where did they go?"],
			["say", "alaric", "ALARIC", "I don't know."],
			["say", "lyra", "LYRA", "You usually know."],
			["say", "alaric", "ALARIC", "Usually."],
			["wait", 1.0],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- meeting Seraphine
	"vs_seraphine": {
		"id": "vs_seraphine", "map": CITY, "stage": [0, 0, 0, 0], "follow": [8, 12],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#6a5a8a", 0.3, 0.1],
			["spawn", "alaric", "king", [7, 8], "E"], ["spawn", "bram", "warden", [8, 6], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 6], "E"],
			["spawn", "merc", "merc", [5, 7], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 7], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 6], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [8, 13], "W", {"tint": "vessel", "alpha": 0.0}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["wait", 1.0], ["fadein", "seraphine", 1.2], ["fx", "seraphine", "circle", 1.2], ["beat", "appears"],
			["say", "seraphine", "SERAPHINE", "Another summoner."],
			["say", "alaric", "ALARIC", "You say that like it's a problem."],
			["say", "seraphine", "SERAPHINE", "In my experience, it usually is."],
			["say", "bram", "BRAM", "Charming."],
			["say", "seraphine", "SERAPHINE", "And you must be one of his."],
			["say", "bram", "BRAM", "I prefer 'colleague.'"],
			["wait", 0.8], ["look", "seraphine", "N"],
			["say", "seraphine", "SERAPHINE", "Spirits have been vanishing from the burial grounds. Someone is gathering them. And until you can show me your companions stand beside you by choice, I won't trust you."],  # DRAFT: the brief describes her explanation and her condition
			["wait", 0.8], ["bubble", "alaric", "..."],
			["say", "alaric", "ALARIC", "I won't force you to do anything. But I'll help you look."],  # DRAFT: he does not try to compel her; he offers to investigate
			["fade", 1.0, 1.0],
		],
	},
	"vs_b2_post": {
		"id": "vs_b2_post", "map": V2, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#6a5a8a", 0.3, 0.1],
			["spawn", "alaric", "king", [7, 20], "E"], ["spawn", "bram", "warden", [8, 19], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 19], "E"],
			["spawn", "merc", "merc", [5, 20], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 20], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 19], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [8, 21], "W", {"tint": "vessel"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "alaric", [7, 22], {"t": 0.5}], ["bubble", "alaric", "!"], ["wait", 0.6], ["beat", "passage"],
			["say", "seraphine", "SERAPHINE", "The bell keepers' lanterns. Their satchels. They came down here and did not leave."],  # DRAFT: the brief says the party finds the belongings
			["say", "seraphine", "SERAPHINE", "This city once set resonance crystals to help restless spirits pass peacefully into the Vessel World. They were never meant to imprison anyone."],
			["wait", 0.6],
			["say", "seraphine", "SERAPHINE", "Someone has changed the system."],
			["say", "alaric", "ALARIC", "So the spirits aren't wandering off."],  # DRAFT
			["say", "alaric", "ALARIC", "Someone is collecting them."],  # DRAFT: "Alaric begins to suspect they are being collected deliberately"
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- Lyra and Seraphine
	"vs_lyra": {
		"id": "vs_lyra", "map": CITY, "stage": [0, 0, 0, 0], "follow": [8, 12],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#6a5a8a", 0.3, 0.1],
			["spawn", "lyra", "mira", [7, 10], "E"], ["spawn", "seraphine", "sorc", [8, 12], "W", {"tint": "vessel"}], ["spawn", "alaric", "king", [6, 6], "E"],
			["spawn", "bram", "warden", [8, 5], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["wait", 0.8], ["look", "seraphine", "S"],
			["say", "seraphine", "SERAPHINE", "You're not like them."],
			["say", "lyra", "LYRA", "No."],
			["say", "seraphine", "SERAPHINE", "But you were."],
			["say", "lyra", "LYRA", "Yes."],
			["wait", 0.8], ["bubble", "seraphine", "?"],
			["say", "seraphine", "SERAPHINE", "How?"],
			["say", "lyra", "LYRA", "I don't know."],
			["say", "seraphine", "SERAPHINE", "You returned to life?"],
			["say", "lyra", "LYRA", "Something like that."],
			["wait", 1.2], ["bubble", "seraphine", "!"], ["beat", "stunned"],
			["say", "seraphine", "SERAPHINE", "Do you wish to return to the Vessel World?"],  # DRAFT: the brief says she asks whether Lyra wishes to return
			["say", "lyra", "LYRA", "No."],
			["say", "seraphine", "SERAPHINE", "Not even to see what you left behind?"],
			["say", "lyra", "LYRA", "I remember what I left behind."],
			["say", "seraphine", "SERAPHINE", "And?"],
			["say", "lyra", "LYRA", "I have a life now."],
			["wait", 1.4], ["beat", "understands"],
			["fade", 1.0, 1.2],
		],
	},
	"vs_b3_post": {
		"id": "vs_b3_post", "map": V3, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#5a6a9a", 0.3, 0.1],
			["spawn", "alaric", "king", [7, 20], "E"], ["spawn", "bram", "warden", [8, 19], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 19], "E"],
			["spawn", "merc", "merc", [5, 20], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 20], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 19], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [8, 22], "W", {"tint": "vessel"}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "seraphine", [8, 21], {"t": 0.5}], ["fx", "seraphine", "circle", 1.0], ["wait", 0.8], ["beat", "crystals"],
			["say", "seraphine", "SERAPHINE", "Look at the brackets. This was my city's design. A channel, not a cage."],  # DRAFT: she recognizes the original design
			["say", "seraphine", "SERAPHINE", "It was meant to guide spirits, not imprison them."],
			["say", "gideon", "GIDEON", "The new work is clean. Recent, within the year."],  # DRAFT: "the modifications are relatively recent"
			["say", "kaelen", "KAELEN", "Whoever did it hasn't left a name."],  # DRAFT: "the person has not yet been identified"
			["wait", 0.8], ["look", "alaric", "N"],
			["say", "alaric", "ALARIC", "Then we keep looking."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- Malrec
	"vs_b4_pre": {
		"id": "vs_b4_pre", "map": V4, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#4a5a9a", 0.3, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [7, 4], "E", {"tint": "vessel"}], ["spawn", "malrec", "hollowmark_assassin", [7, 16], "W"],
			["spawn", "c1", "squire", [5, 11], "E", {"tint": "vessel", "alpha": 0.0}], ["spawn", "c2", "squire", [10, 11], "W", {"tint": "vessel", "alpha": 0.0}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["wait", 0.8], ["shake", 0.03, 1.2], ["fadein", "c1", 1.0], ["fadein", "c2", 1.0], ["beat", "collection"],
			["say", "malrec", "MALREC", "Do you know how many voices have vanished from this world?"],
			["say", "alaric", "ALARIC", "They deserve to rest."],
			["say", "malrec", "MALREC", "And be forgotten?"],
			["say", "alaric", "ALARIC", "Remembering someone doesn't mean keeping them prisoner."],
			["say", "malrec", "MALREC", "Easy words from a man who summons the dead."],
			["say", "alaric", "ALARIC", "Mine can refuse."],
			["wait", 1.0], ["look", "malrec", "S"],
			["say", "malrec", "MALREC", "Every summoner uses the dead for their own purposes. You simply call it companionship."],  # DRAFT: the brief says he believes this
			["say", "alaric", "ALARIC", "No."],  # DRAFT: Alaric rejects the idea
			["fade", 1.0, 1.0],
		],
	},
	"vs_b4_post": {
		"id": "vs_b4_post", "map": V4, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#4a5a9a", 0.28, 0.1],
			["spawn", "alaric", "king", [7, 12], "E"], ["spawn", "bram", "warden", [8, 11], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 11], "E"],
			["spawn", "merc", "merc", [5, 12], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 12], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 11], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [7, 10], "E", {"tint": "vessel"}], ["spawn", "malrec", "hollowmark_assassin", [7, 16], "W"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["fx", "alaric", "burst", 1.6], ["fx", "bram", "burst", 1.2], ["flash"], ["wait", 0.8], ["beat", "released"],
			["walk", "malrec", [7, 18], {"t": 0.5, "anim": "run"}], ["fadeout", "malrec", 0.6], ["beat", "escapes"],
			["say", "seraphine", "SERAPHINE", "He's gone up. The great bell is joined to the remaining crystals now. Rung wrongly, it will pull in every spirit it can reach."],  # DRAFT: the brief says she warns of the bell
			["say", "alaric", "ALARIC", "Then we follow him."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- the last toll
	"vs_b5_pre": {
		"id": "vs_b5_pre", "map": V5, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#4a5a9a", 0.26, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", [8, 3], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 3], "E"],
			["spawn", "merc", "merc", [5, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 3], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 3], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [7, 5], "E", {"tint": "vessel"}], ["spawn", "malrec", "hollowmark_assassin", [7, 16], "W"],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "seraphine", [7, 8], {"t": 0.5}], ["look", "seraphine", "E"],
			["say", "seraphine", "SERAPHINE", "You were supposed to guide them."],
			["say", "malrec", "MALREC", "I was supposed to remember them."],
			["say", "seraphine", "SERAPHINE", "Then remember them. Don't imprison them."],
			["wait", 1.0], ["look", "malrec", "N"],
			["say", "malrec", "MALREC", "No."],  # DRAFT: "Malrec refuses to surrender"
			["shake", 0.05, 1.0], ["fx", "malrec", "circle", 1.8], ["flash"], ["beat", "bell"],
			["fade", 1.0, 1.0],
		],
	},
	"vs_b5_post": {
		"id": "vs_b5_post", "map": V5, "stage": [0, 0, 0, 0], "next": "vs_decision",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#4a5a9a", 0.26, 0.1],
			["spawn", "alaric", "king", [7, 9], "E"], ["spawn", "bram", "warden", [8, 8], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 8], "E"],
			["spawn", "merc", "merc", [5, 9], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, 9], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 8], "E", {"tint": "vessel"}],
			["spawn", "seraphine", "sorc", [7, 12], "E", {"tint": "vessel"}], ["spawn", "malrec", "hollowmark_assassin", [7, 15], "W"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["hold", "malrec", "ko", 2], ["fx", "malrec", "burst", 1.6], ["shake", 0.06, 1.2], ["beat", "collapse"],
			["fx", "alaric", "burst", 2.0], ["fx", "bram", "burst", 1.6], ["fx", "lyra", "burst", 1.6], ["flash"], ["wait", 0.8], ["beat", "released"],
			["walk", "seraphine", [7, 14], {"t": 0.55}], ["act", "seraphine", "cast"], ["fx", "seraphine", "circle", 2.4], ["shake", 0.04, 2.0], ["tint", "#ffd88a", 0.26, 3.0], ["beat", "toll"],
			["wait", 2.0], ["fx", "alaric", "streak", 1.4], ["fx", "merc", "burst", 1.4], ["beat", "answer"],
			["fade", 1.0, 1.4],
		],
	},
	# ---------------------------------------------------------------------------------------------- Seraphine's decision
	"vs_decision": {
		"id": "vs_decision", "map": CITY, "stage": [0, 0, 0, 0], "next": "vs_archive", "also_seen": ["vs_b5_post"], "follow": [8, 11],
		"folk": [["villager_man", [5, 10]], ["villager_kid", [7, 12]], ["mechanic", [9, 6]], ["villager_girl", [6, 17]], ["villager_man", [10, 14]]],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#ffd88a", 0.22, 0.1],
			["spawn", "alaric", "king", [7, 9], "E"], ["spawn", "seraphine", "sorc", [8, 12], "W", {"tint": "vessel"}], ["spawn", "lyra", "mira", [5, 7], "E"],
			["spawn", "bram", "warden", [8, 6], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [6, 6], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["fx", "seraphine", "burst", 1.4], ["bubble", "bram", "~"], ["bubble", "merc", "~"], ["wait", 1.2], ["beat", "bells"],
			["say", "seraphine", "SERAPHINE", "You came here looking for something."],
			["say", "alaric", "ALARIC", "We were passing through."],
			["say", "seraphine", "SERAPHINE", "And yet you stayed."],
			["say", "alaric", "ALARIC", "People needed help."],
			["say", "seraphine", "SERAPHINE", "That simple?"],
			["say", "alaric", "ALARIC", "Usually isn't."],
			["wait", 0.8], ["bubble", "seraphine", "~"],
			["say", "seraphine", "SERAPHINE", "I've spent decades guarding this city. Now that the bells ring again, I am finally free to leave. I would like to see what lies beyond these walls."],  # DRAFT: the brief says she is free and offers to join
			["say", "alaric", "ALARIC", "You understand what that means?"],
			["say", "seraphine", "SERAPHINE", "I do. I remain myself. You sustain my presence."],
			["say", "alaric", "ALARIC", "And if you change your mind?"],
			["say", "seraphine", "SERAPHINE", "Then I expect you to listen."],
			["say", "alaric", "ALARIC", "Fair."],
			["fx", "seraphine", "circle", 1.6], ["flash"], ["give_seraphine"], ["beat", "joins"],
			["title", "SERAPHINE JOINS THE PARTY", "The Last Bell Keeper is now a vessel you can summon: support, hymns and lullabies.", 3.4],
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- the second clue
	"vs_archive": {
		"id": "vs_archive", "map": ARC, "stage": [0, 0, 0, 0], "next": "vs_king", "also_seen": ["vs_decision"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#d0a860", 0.18, 0.1],
			["spawn", "alaric", "king", [8, 4], "E"], ["spawn", "lyra", "mira", [6, 3], "E"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 7], {"t": 0.55}], ["wait", 0.8], ["bubble", "alaric", "!"], ["wait", 0.6], ["beat", "recognizes"],
			["narrate", "A burial record, and beside it a drawing of a commanding officer in old royal armor, the crowned falcon on his breast.", 5.0],  # DRAFT: the brief describes a portrait or description of the officer
			["say", "alaric", "ALARIC", "That's him."],
			["walk", "lyra", [7, 6], {"t": 0.4}],
			["say", "lyra", "LYRA", "Who?"],
			["say", "alaric", "ALARIC", "One of the soldiers."],
			["say", "lyra", "LYRA", "From your village?"],
			["say", "alaric", "ALARIC", "He was there."],
			["wait", 0.6], ["look", "lyra", "S"],
			["say", "lyra", "LYRA", "Alaric... this says he died a hundred and twelve years ago."],
			["wait", 1.2],
			["say", "alaric", "ALARIC", "Then someone made a mistake."],
			["say", "lyra", "LYRA", "Maybe."],
			["wait", 1.2],
			["say", "lyra", "LYRA", "Or maybe what you saw wasn't what you thought."],
			["wait", 1.4], ["bubble", "alaric", "..."], ["beat", "closes_book"],
			["fade", 1.0, 1.4],
		],
	},
	"vs_king": {
		"id": "vs_king", "map": PAL, "stage": [0, 0, 0, 0], "next": "vs_leaving", "also_seen": ["vs_archive"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#2a2a40", 0.3, 0.1],
			["spawn", "king_npc", "lancer", [6, 7], "E"], ["spawn", "messenger", "villager_man", [5, 2], "E", {"alpha": 0.0}],
			["fade", 0.0, 2.0], ["beat", "start"],
			["wait", 1.6], ["fadein", "messenger", 0.6], ["walk", "messenger", [5, 5], {"t": 0.5}], ["beat", "report"],
			["say", "messenger", "MESSENGER", "Your Majesty. The summoner has been sighted in Vespera."],
			["say", "king_npc", "KING", "Is he well?"],
			["say", "messenger", "MESSENGER", "As far as we know."],
			["say", "king_npc", "KING", "Good."],
			["wait", 0.8], ["bubble", "messenger", "..."],
			["say", "messenger", "MESSENGER", "Shall we send soldiers?"],
			["wait", 1.4],
			["say", "king_npc", "KING", "No."],
			["say", "messenger", "MESSENGER", "Your Majesty?"],
			["say", "king_npc", "KING", "Send an invitation."],
			["walk", "messenger", [5, 1], {"t": 0.4}], ["fadeout", "messenger", 0.6],
			["look", "king_npc", "W"], ["wait", 2.0],
			["say", "king_npc", "KING", "I only wish to speak with him."],
			["wait", 2.0], ["beat", "alone"],
			["fade", 1.0, 1.6],
		],
	},
	"vs_leaving": {
		"id": "vs_leaving", "map": CITY, "stage": [0, 0, 0, 0], "also_seen": ["vs_king"], "follow": [8, 14],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#ffd88a", 0.2, 0.1],
			["spawn", "alaric", "king", [7, 17], "E"], ["spawn", "lyra", "mira", [6, 16], "E"], ["spawn", "bram", "warden", [8, 15], "E", {"tint": "vessel"}],
			["spawn", "kaelen", "choir", [5, 15], "E", {"tint": "vessel"}], ["spawn", "seraphine", "sorc", [9, 16], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [4, 16], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [10, 15], "E", {"tint": "vessel"}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["wait", 1.0], ["look", "seraphine", "N"], ["fx", "seraphine", "burst", 1.4], ["tint", "#ffd88a", 0.28, 3.0], ["beat", "bells"],
			["say", "seraphine", "SERAPHINE", "I spent so long waiting to hear that sound again."],
			["say", "bram", "BRAM", "You'll miss it?"],
			["say", "seraphine", "SERAPHINE", "Terribly."],
			["say", "kaelen", "KAELEN", "We could turn around."],
			["say", "seraphine", "SERAPHINE", "And spend another century listening to you complain? No, thank you."],
			["bubble", "merc", "~"], ["bubble", "bram", "~"], ["wait", 1.0],
			["walk", "lyra", [7, 16], {"t": 0.4}], ["look", "lyra", "E"],
			["say", "lyra", "LYRA", "Still thinking about that soldier?"],
			["say", "alaric", "ALARIC", "He was dead before I was born."],
			["say", "lyra", "LYRA", "Yes."],
			["say", "alaric", "ALARIC", "And I saw him standing in my village."],
			["wait", 1.4],
			["say", "alaric", "ALARIC", "Someone brought him back."],
			["wait", 1.8],
			["title", "END OF CHAPTER SEVEN", "The City of Silent Bells", 3.2],
		],
	},
}
