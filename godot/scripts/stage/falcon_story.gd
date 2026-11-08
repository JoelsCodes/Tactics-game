class_name FalconStory
extends RefCounted
## Chapter eleven, "The Dead King's Army": the scenes StoryScene plays. The owner's dialogue is word for word; every line, caption or beat I wrote to join it is marked DRAFT.
## STORY CANON (godot/STORY_CANON.md): "the rightful heir" is the chapter's mystery and points at the royal bloodline without naming anyone. Elowen is never named or shown and nobody
## says who summoned the Falcon Guard; Reave is generous and compelling in public and nothing proves what he did. The Falcon Guard are free-willed: Vaelor knows who summoned him and
## will not say, and he answers for what he did at the village. The King believes his daughter is dead and does not think of her.
## ART GAPS (see godot/HANDOFF.md): Vaelor, Reave, Aldren, the King, the Greyhaven townsfolk and the messenger have no sprites of their own (stand-ins); the Falcon Guard use royal sheets
## with a spectral tint; there is no falcon crest art and no music.
##   fl_report -> fl_greyhaven -> fl_ashes_pre -> (Battle 1)   the second massacre; Greyhaven; the vessels in the lane
##   fl_b1_post -> fl_survivors -> fl_reave_greyhaven          "There is more than one claim to a crown."; the survivors; Reave with supplies
##   fl_farm_pre -> (Battle 2) -> fl_b2_post                   the farmlands; the staging area and the range of a summoner
##   fl_tower_pre -> (Battle 3) -> fl_b3_post -> fl_king_response   the Last Falcon; "Then we are not so different."; the King sends his soldiers to the villages
##   fl_army_pre -> (Battle 4) -> fl_b4_post -> fl_reave_offer     the army without graves; Seraphine; Reave's offer
##   fl_assault_pre -> (Battle 5) -> fl_b5_post -> fl_king_heir -> fl_reave_private -> fl_final    "The rightful heir."; the King's list of distant branches; Reave; a name

const ROOM := "res://samples/palace.json"
const VILLAGE := "res://samples/falcon_village.json"
const NIGHT := "res://samples/ashes_night.json"
const OUTSIDE := "res://samples/crown_street.json"
const F1 := "res://samples/falcon_1.json"
const F2 := "res://samples/falcon_2.json"
const F3 := "res://samples/falcon_3.json"
const F4 := "res://samples/falcon_4.json"
const F5 := "res://samples/falcon_5.json"

const KING_SHEET := "last_king"  ## the owner's sheet (Nov 2026)
const REAVE_SHEET := "reave"  ## the owner's sheet (Nov 2026)
const VAELOR_SHEET := "riverband_brute"  ## stand-in: Vaelor has no sheet yet
const VAELOR_FADE_3 := "The oath holds... even as I fade."  # DRAFT: Vaelor's word as he yields in Battle 3
const VAELOR_FADE_5 := "The bloodline survives."  # the owner's line, said as he yields in Battle 5


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["gideon", "Gideon", "Disciplined. Whoever drilled them drilled them well."], ["sorc", "Seraphine", "Keep clear of the field constructs: they answer to nobody."],
		["warden", "Bram", "That one gives the orders. Take him last, or take him first and hard."], ["mira", "Lyra", "A real army, in a real line. Stay together."],
		["gideon", "Gideon", "Vaelor again. He will not break, so do not give him time."]][n]


static func vaelor_fades(n: int) -> Array:
	return [VAELOR_SHEET, "Vaelor", VAELOR_FADE_3 if n == 3 else VAELOR_FADE_5]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


static func _cast(y: int, alaric_at = null) -> Array:
	return [["spawn", "alaric", "king", alaric_at if alaric_at != null else [7, y], "E"], ["spawn", "bram", "warden", [8, y - 1], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, y - 1], "E"],
		["spawn", "merc", "merc", [5, y], "E", {"tint": "vessel"}], ["spawn", "gideon", "gideon", [9, y], "E", {"tint": "vessel"}], ["spawn", "kaelen", "kaelen", [4, y - 1], "E", {"tint": "vessel"}],
		["spawn", "seraphine", "sorc", [7, y + 1], "E", {"tint": "vessel"}]]


static func _march(y: int, t := 0.5) -> Array:
	return [["walk", "alaric", [7, y], {"t": t, "par": true}], ["walk", "bram", [8, y - 1], {"t": t, "par": true}], ["walk", "lyra", [6, y - 1], {"t": t, "par": true}],
		["walk", "merc", [5, y], {"t": t, "par": true}], ["walk", "gideon", [9, y], {"t": t, "par": true}], ["walk", "kaelen", [4, y - 1], {"t": t, "par": true}],
		["walk", "seraphine", [7, y + 1], {"t": t, "par": true}], ["join"]]


static func _scene(id: String, map: String, tint: String, a: float, steps: Array, opts := {}) -> Dictionary:
	var d := {"id": id, "map": map, "stage": [0, 0, 0, 0], "steps": [["fade", 1.0, 0.0], ["bars", true], ["tint", tint, a, 0.1]] + steps}
	d.merge(opts, true)
	return d


static var SCENES: Dictionary = _build()


static func _build() -> Dictionary:
	var s := {}
	# ---------------------------------------------------------------------------------------------- the second massacre
	s["fl_report"] = _scene("fl_report", ROOM, "#2a2a40", 0.16, [
		["title", "CHAPTER ELEVEN", "The Dead King's Army", 2.8],
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "aldren", "ironhollow_sentinel", [4, 9], "E"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 2.0], ["beat", "start"],
		["walk", "alaric", [6, 6], {"t": 0.6}], ["wait", 0.8],
		["narrate", "A report from a village called Greyhaven. Witnesses say soldiers wearing the Falcon Guard's insignia attacked the settlement. It was not destroyed. The attackers withdrew before the royal reinforcements arrived.", 5.0],  # DRAFT: the owner's exposition of the report
		["look", "king_npc", "S"], ["bubble", "king_npc", "!"], ["beat", "king"],
		["say", "king_npc", "KING", "Again?"],
		["say", "aldren", "ALDREN", "Yes, Your Majesty."],
		["say", "king_npc", "KING", "How many dead?"],
		["say", "aldren", "ALDREN", "We don't have a final count."],
		["wait", 0.8], ["look", "king_npc", "E"],
		["say", "king_npc", "KING", "The same soldiers?"],
		["say", "alaric", "ALARIC", "That's what the witnesses say."],
		["say", "king_npc", "KING", "Then we stop them."],
		["wait", 1.0],
		["narrate", "The King orders relief supplies and healers sent to Greyhaven, and soldiers posted to the settlements around it. He asks Alaric to find the attackers. Alaric agrees.", 4.4],  # DRAFT: the owner's staging of the King's orders
		["wait", 1.0], ["fade", 1.0, 1.2],
	], {"next": "fl_greyhaven"})
	s["fl_greyhaven"] = _scene("fl_greyhaven", VILLAGE, "#d8b888", 0.18, _cast(3) + [
		["fade", 0.0, 2.2], ["beat", "start"]] + _march(10, 0.6) + [
		["narrate", "Greyhaven: fields, wooded hills, a lane of cottages. Some are burned. People are mending roofs and carrying water, helping one another.", 4.0],  # DRAFT: the owner's setting
		["wait", 1.2], ["look", "alaric", "N"], ["wait", 1.6], ["bubble", "alaric", "..."], ["wait", 1.6], ["beat", "home"],
		["look", "lyra", "E"],
		["say", "lyra", "LYRA", "You don't have to stay here."],
		["say", "alaric", "ALARIC", "Yes, I do."],
		["say", "lyra", "LYRA", "Alaric—"],
		["wait", 0.8],
		["say", "alaric", "ALARIC", "Someone stayed for me once."],
		["wait", 1.8], ["bubble", "lyra", "~"], ["wait", 1.4], ["fade", 1.0, 1.2],
	], {"folk": [["villager_man", [5, 14]], ["villager_girl", [9, 16]], ["villager_kid", [7, 18]], ["mechanic", [10, 20]], ["villager_man", [4, 21]]], "next": "fl_ashes_pre"})
	s["fl_ashes_pre"] = _scene("fl_ashes_pre", F1, "#b8c0d8", 0.14, _cast(2, "@king") + [
		["spawn", "off", "riverband_brute", [7, 17], "W", {"tint": "falcon"}], ["spawn", "v1", "spectral_duelist", [4, 14], "W", {"tint": "falcon"}], ["spawn", "v2", "ironhollow_sentinel", [9, 15], "W", {"tint": "falcon"}],
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + [
		["wait", 0.8], ["look", "off", "S"],
		["narrate", "Falcon Guard vessels stand in the lane at Greyhaven's edge, in good order, preparing to attack the settlement again.", 3.4],  # DRAFT: the owner's staging
		["say", "alaric", "ALARIC", "Stand down. I only want to know who summoned you."],  # DRAFT: Alaric attempts to speak to them
		["say", "off", "OFFICER", "We will not name them."],  # DRAFT: the soldiers refuse to identify their summoner
		["say", "off", "OFFICER", "Withdraw, summoner. This is not your quarrel."],  # DRAFT: the commander orders the party to withdraw
		["wait", 0.8], ["act", "off", "attack"], ["flash"], ["fade", 1.0, 1.0],
	], {"also_seen": ["fl_report", "fl_greyhaven"]})
	s["fl_b1_post"] = _scene("fl_b1_post", F1, "#b8c0d8", 0.12, _cast(10) + [
		["spawn", "v1", "spectral_duelist", [7, 14], "W", {"tint": "falcon"}], ["spawn", "v2", "ironhollow_sentinel", [5, 15], "N", {"tint": "falcon"}],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "v1", "ko", 2], ["hold", "v2", "ko", 2], ["wait", 1.0],
		["walk", "alaric", [7, 12], {"t": 0.6}], ["look", "alaric", "E"], ["beat", "soldier"],
		["say", "alaric", "ALARIC", "Who summoned you?"],
		["say", "v1", "SOLDIER", "I serve the crown."],
		["say", "alaric", "ALARIC", "The King didn't send you."],
		["say", "v1", "SOLDIER", "There is more than one claim to a crown."],
		["wait", 1.0], ["bubble", "alaric", "?"],
		["say", "alaric", "ALARIC", "What does that mean?"],
		["wait", 0.8], ["fadeout", "v1", 1.4], ["fadeout", "v2", 1.4], ["wait", 1.8], ["beat", "gone"],
		["look", "alaric", "W"], ["wait", 1.0], ["fade", 1.0, 1.2],
	], {"next": "fl_survivors"})
	s["fl_survivors"] = _scene("fl_survivors", VILLAGE, "#d8b888", 0.16, _cast(4) + [
		["spawn", "elder", "villager_man", [7, 12], "W"], ["spawn", "woman", "villager_girl", [8, 15], "W"],
		["fade", 0.0, 1.6], ["beat", "start"],
		["walk", "alaric", [7, 10], {"t": 0.5}], ["look", "elder", "S"], ["wait", 0.6],
		["narrate", "An old man tells it: they moved with extraordinary discipline. Their armor looked ancient. They appeared out of nothing and vanished after the attack.", 4.2],  # DRAFT: the owner's account of the elder's testimony
		["walk", "alaric", [7, 13], {"t": 0.4}], ["look", "woman", "S"], ["wait", 0.6], ["beat", "woman"],
		["say", "woman", "WOMAN", "They said the crown had abandoned us."],
		["say", "alaric", "ALARIC", "While wearing its colors?"],
		["say", "woman", "WOMAN", "Yes."],
		["wait", 1.4], ["look", "alaric", "W"], ["bubble", "alaric", "..."],
		["narrate", "It was not an ordinary raid. It was a statement.", 3.0],  # DRAFT: Alaric realises the attackers were making a political point
		["wait", 0.8], ["walk", "gideon", [8, 10], {"t": 0.5}], ["look", "gideon", "E"], ["look", "alaric", "E"],
		["say", "gideon", "GIDEON", "Captain Aldren's riders report protests against the crown, growing in the nearby towns."],  # DRAFT: the owner says Aldren reports the protests; Aldren is not on this stage, so Gideon carries it
		["wait", 1.4], ["look", "alaric", "S"], ["bubble", "alaric", "..."], ["wait", 1.0], ["fade", 1.0, 1.2],
	], {"next": "fl_reave_greyhaven"})
	s["fl_reave_greyhaven"] = _scene("fl_reave_greyhaven", VILLAGE, "#d8b888", 0.16, _cast(4) + [
		["spawn", "reave", REAVE_SHEET, [7, 22], "W"], ["spawn", "vol1", "villager_man", [6, 22], "W"], ["spawn", "vol2", "villager_girl", [8, 22], "W"],
		["fade", 0.0, 1.6], ["beat", "start"],
		["walk", "alaric", [7, 10], {"t": 0.5}], ["wait", 0.6],
		["walk", "reave", [7, 17], {"t": 0.5, "par": true}], ["walk", "vol1", [6, 16], {"t": 0.5, "par": true}], ["walk", "vol2", [8, 16], {"t": 0.5, "par": true}], ["join"],
		["narrate", "Reave comes up the lane with a column of volunteers carrying food and bandages. He kneels to a crying child before he looks up.", 3.8],  # DRAFT: he is helping, genuinely
		["look", "reave", "W"], ["beat", "reave"],
		["say", "reave", "REAVE", "We meet again."],
		["say", "alaric", "ALARIC", "You travel quickly."],
		["say", "reave", "REAVE", "So does bad news."],
		["wait", 0.8],
		["say", "alaric", "ALARIC", "I thought you made speeches."],
		["say", "reave", "REAVE", "Occasionally I do something useful."],
		["wait", 0.8],
		["say", "reave", "REAVE", "Have you found the attackers?"],  # DRAFT: Reave asks, as the owner has it
		["say", "alaric", "ALARIC", "Some of them."],
		["say", "reave", "REAVE", "And?"],
		["say", "alaric", "ALARIC", "They're dead."],
		["wait", 0.8], ["bubble", "reave", "?"],
		["say", "reave", "REAVE", "That sounds inconvenient."],
		["say", "alaric", "ALARIC", "They were dead before they attacked."],
		["wait", 1.2],
		["say", "reave", "REAVE", "A summoner, then."],
		["say", "alaric", "ALARIC", "Looks that way."],
		["wait", 0.8],
		["say", "reave", "REAVE", "Has the King responded?"],  # DRAFT: Reave asks whether the King has responded
		["say", "alaric", "ALARIC", "He sent supplies and soldiers."],  # DRAFT: Alaric explains what the King did
		["say", "reave", "REAVE", "Good. Perhaps he's finally remembered he has a kingdom."],
		["say", "alaric", "ALARIC", "He's trying."],
		["say", "reave", "REAVE", "Trying is a beginning."],
		["wait", 0.8], ["bubble", "reave", "~"],
		["say", "reave", "REAVE", "Whether it's enough is another question."],
		["wait", 1.6], ["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- Battle 2
	s["fl_farm_pre"] = _scene("fl_farm_pre", F2, "#e0d0a0", 0.14, _cast(2, "@king") + [
		["spawn", "v1", "squire", [6, 16], "W", {"tint": "falcon"}], ["spawn", "v2", "hooded_cutthroat", [10, 17], "W", {"tint": "falcon"}], ["spawn", "boar", "boar", [4, 18], "W"],
		["fade", 0.0, 1.6], ["beat", "start"]] + _march(7, 0.55) + [
		["narrate", "A district of farms east of Greyhaven. Falcon Guard vessels have been seen here, and the fighting has stirred up the beasts of the hedgerows.", 3.6],  # DRAFT: the owner's staging
		["wait", 0.8], ["look", "alaric", "E"], ["shake", 0.02, 0.8], ["bubble", "kaelen", "!"], ["wait", 0.8], ["flash"], ["fade", 1.0, 1.0],
	])
	s["fl_b2_post"] = _scene("fl_b2_post", F2, "#e0d0a0", 0.12, _cast(15) + [
		["fade", 0.0, 1.4], ["beat", "start"],
		["narrate", "Beyond the barn, a staging area: trampled ground, cleared brush, a line of marks in the earth where ranks stood. No wagons. No cookfires. No living soldiers' leavings.", 4.2],  # DRAFT: the owner's note that there are no ordinary supply wagons or living soldiers
		["wait", 0.8], ["look", "gideon", "N"], ["beat", "gideon"],
		["say", "gideon", "GIDEON", "An army that doesn't need roads or provisions."],
		["say", "alaric", "ALARIC", "It still needs a summoner."],
		["say", "gideon", "GIDEON", "And that summoner must be somewhere close enough to sustain them."],
		["wait", 1.4], ["look", "alaric", "E"], ["bubble", "alaric", "..."], ["wait", 1.0], ["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- the Last Falcon
	s["fl_tower_pre"] = _scene("fl_tower_pre", F3, "#b8b8d0", 0.16, _cast(2, "@king") + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 19], "W", {"tint": "falcon"}], ["spawn", "h1", "ironhollow_sentinel", [4, 15], "W", {"tint": "falcon"}], ["spawn", "h2", "ironhollow_sentinel", [11, 14], "W", {"tint": "falcon"}],
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + [
		["narrate", "An abandoned watchtower. At its foot, a soldier in the armor of the old Falcon Guard stands waiting: Commander Vaelor, the Last Falcon. A century dead. Proud, upright, and entirely unhurried.", 4.6],  # DRAFT: the owner's introduction of Vaelor
		["look", "vaelor", "S"], ["wait", 0.8], ["beat", "vaelor"],
		["say", "vaelor", "VAELOR", "You survived."],
		["bubble", "alaric", "!"], ["wait", 1.0],
		["say", "alaric", "ALARIC", "You remember me."],
		["say", "vaelor", "VAELOR", "I remember the village."],
		["say", "alaric", "ALARIC", "You were there."],
		["say", "vaelor", "VAELOR", "Yes."],
		["wait", 0.8], ["walk", "alaric", [7, 11], {"t": 0.5}],
		["say", "alaric", "ALARIC", "You killed them."],
		["say", "vaelor", "VAELOR", "I carried out my orders."],
		["say", "alaric", "ALARIC", "Whose orders?"],
		["wait", 1.2],
		["say", "vaelor", "VAELOR", "My oath did not end with my death."],
		["say", "alaric", "ALARIC", "Then perhaps it should have."],
		["wait", 0.8], ["act", "vaelor", "attack"], ["flash"], ["fade", 1.0, 1.0],
	])
	s["fl_b3_post"] = _scene("fl_b3_post", F3, "#b8b8d0", 0.12, _cast(10) + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 14], "W", {"tint": "falcon"}],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "vaelor", "ko", 2], ["wait", 1.2],
		["walk", "alaric", [7, 12], {"t": 0.6}], ["look", "alaric", "E"], ["beat", "fading"],
		["say", "alaric", "ALARIC", "Tell me who summoned you."],
		["say", "vaelor", "VAELOR", "You seek a name."],
		["say", "alaric", "ALARIC", "Yes."],
		["say", "vaelor", "VAELOR", "And when you have it?"],
		["say", "alaric", "ALARIC", "I'll make them answer."],
		["wait", 1.2],
		["say", "vaelor", "VAELOR", "Then we are not so different."],
		["say", "alaric", "ALARIC", "I didn't burn a village."],
		["wait", 1.6], ["look", "vaelor", "W"], ["bubble", "vaelor", "..."], ["wait", 1.0],
		["say", "vaelor", "VAELOR", "No."],
		["wait", 1.4], ["fadeout", "vaelor", 1.8], ["wait", 2.0], ["beat", "gone"],
		["narrate", "Alaric is angry, and something more. These soldiers chose what they did.", 3.2],  # DRAFT: the owner's note that Alaric now sees the soldiers made choices
		["wait", 1.0], ["fade", 1.0, 1.2],
	], {"next": "fl_king_response"})
	s["fl_king_response"] = _scene("fl_king_response", ROOM, "#2a2a40", 0.16, [
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "aldren", "ironhollow_sentinel", [4, 9], "E"],
		["fade", 0.0, 1.8], ["beat", "start"],
		["narrate", "Reports arrive from the provinces: the Falcon Guard is appearing in more than one region. The King orders more defenses around the vulnerable settlements.", 4.0],  # DRAFT: the owner's staging
		["wait", 0.8], ["look", "aldren", "S"],
		["say", "aldren", "ALDREN", "We cannot defend every village."],
		["say", "king_npc", "KING", "Then defend the ones most at risk."],
		["say", "aldren", "ALDREN", "And the capital?"],
		["wait", 1.4], ["look", "king_npc", "W"],
		["say", "king_npc", "KING", "The capital has walls. They do not."],
		["wait", 1.6], ["beat", "resolve"], ["fade", 1.0, 1.2],
	], {"also_seen": ["fl_b3_post"]})
	# ---------------------------------------------------------------------------------------------- Battle 4
	s["fl_army_pre"] = _scene("fl_army_pre", F4, "#b8b8d0", 0.16, _cast(2, "@king") + [
		["spawn", "v1", "ironhollow_sentinel", [5, 14], "W", {"tint": "falcon"}], ["spawn", "v2", "riverband_brute", [10, 15], "W", {"tint": "falcon"}], ["spawn", "std", "spectral_duelist", [7, 21], "W", {"tint": "falcon"}],
		["fade", 0.0, 1.6], ["beat", "start"]] + _march(7, 0.55) + [
		["narrate", "An abandoned encampment, and in it more of the dead than Alaric has yet seen together: heavy infantry, riders, mages and archers drawn up under a standard. They mean to march on another populated region.", 4.6],  # DRAFT: the owner's staging
		["wait", 0.8], ["say", "alaric", "ALARIC", "Not this time."],  # DRAFT: Alaric decides to stop them
		["wait", 0.8], ["flash"], ["fade", 1.0, 1.0],
	])
	s["fl_b4_post"] = _scene("fl_b4_post", F4, "#b8b8d0", 0.12, _cast(12) + [
		["fade", 0.0, 1.4], ["beat", "start"],
		["narrate", "The defeated vessels dissolve. The air still hums with the energy that held so many of them together, and it is steady, unbroken, patient.", 3.8],  # DRAFT: the owner's note that the summoning energy is unusually stable
		["look", "seraphine", "E"], ["wait", 0.6], ["beat", "seraphine"],
		["say", "seraphine", "SERAPHINE", "Sustaining so many would take exceptional control, and a great deal of energy."],  # DRAFT: the owner's explanation, in Seraphine's voice
		["say", "seraphine", "SERAPHINE", "Whoever is doing this has been summoning for a long time."],
		["say", "alaric", "ALARIC", "Longer than me?"],
		["say", "seraphine", "SERAPHINE", "Almost certainly."],
		["wait", 1.6], ["look", "alaric", "N"], ["bubble", "alaric", "..."], ["wait", 1.0], ["fade", 1.0, 1.2],
	], {"next": "fl_reave_offer"})
	s["fl_reave_offer"] = _scene("fl_reave_offer", VILLAGE, "#d8a870", 0.2, _cast(4) + [
		["spawn", "reave", REAVE_SHEET, [7, 20], "W"],
		["fade", 0.0, 1.6], ["beat", "start"],
		["walk", "alaric", [7, 10], {"t": 0.5}], ["walk", "reave", [7, 15], {"t": 0.5}], ["look", "reave", "W"], ["beat", "reave"],
		["narrate", "Reave has heard that Alaric has been defending the villages against the Falcon Guard. He praises him for it.", 3.2],  # DRAFT: the owner's staging
		["say", "reave", "REAVE", "You could have stayed in the palace."],
		["say", "alaric", "ALARIC", "People needed help."],
		["say", "reave", "REAVE", "That's what makes you dangerous."],
		["say", "alaric", "ALARIC", "Dangerous?"],
		["say", "reave", "REAVE", "People follow someone who acts."],
		["wait", 1.2],
		["narrate", "He offers Alaric a place in his movement, and says the kingdom's failings are not one man's but the system's.", 3.6],  # DRAFT: the owner's exposition of the offer
		["say", "reave", "REAVE", "You can replace one King with another. The problem remains."],
		["say", "alaric", "ALARIC", "And your solution?"],
		["say", "reave", "REAVE", "A kingdom where no one inherits the right to rule."],
		["wait", 1.4], ["look", "alaric", "E"],
		["say", "alaric", "ALARIC", "And how many people have to die to build it?"],
		["wait", 1.2], ["bubble", "reave", "..."], ["wait", 0.8],
		["say", "reave", "REAVE", "Fewer than will die if nothing changes."],
		["say", "alaric", "ALARIC", "That's not an answer."],
		["wait", 1.0], ["bubble", "reave", "~"],
		["say", "reave", "REAVE", "No. I suppose it isn't."],
		["wait", 1.6], ["fade", 1.0, 1.2],
	], {"also_seen": ["fl_b4_post"]})
	# ---------------------------------------------------------------------------------------------- the dead king's army
	s["fl_assault_pre"] = _scene("fl_assault_pre", F5, "#b0b0d0", 0.18, _cast(2, "@king") + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 22], "W", {"tint": "falcon"}], ["spawn", "h1", "ironhollow_sentinel", [5, 20], "W", {"tint": "falcon"}], ["spawn", "h2", "ironhollow_sentinel", [10, 21], "W", {"tint": "falcon"}],
		["fade", 0.0, 1.6], ["beat", "start"],
		["narrate", "Word reaches the party: a large force of Falcon Guard is gathering to strike Greyhaven again. Alaric turns back to defend it.", 3.6],  # DRAFT: the owner's staging of the final assault
		] + _march(8, 0.55) + [
		["narrate", "Vaelor stands at the head of them, summoned again.", 2.8],  # DRAFT: Vaelor reappears, materialized once more
		["look", "vaelor", "S"], ["beat", "vaelor"],
		["say", "alaric", "ALARIC", "You again."],
		["say", "vaelor", "VAELOR", "My duty remains."],
		["say", "alaric", "ALARIC", "Your duty is killing innocent people?"],
		["wait", 1.2], ["bubble", "vaelor", "..."],
		["say", "vaelor", "VAELOR", "My duty is to the rightful heir."],
		["wait", 0.8], ["bubble", "alaric", "!"],
		["say", "alaric", "ALARIC", "The rightful heir?"],
		["wait", 1.0], ["look", "vaelor", "W"], ["wait", 0.8], ["look", "vaelor", "S"],
		["say", "vaelor", "VAELOR", "You will go no further."],
		["act", "vaelor", "attack"], ["flash"], ["fade", 1.0, 1.0],
	])
	s["fl_b5_post"] = _scene("fl_b5_post", F5, "#b0b0d0", 0.12, _cast(12) + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 17], "W", {"tint": "falcon"}],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "vaelor", "ko", 2], ["wait", 1.2],
		["walk", "alaric", [7, 14], {"t": 0.6}], ["look", "alaric", "E"], ["beat", "heir"],
		["say", "alaric", "ALARIC", "Who is the heir?"],
		["wait", 1.4], ["look", "vaelor", "W"], ["wait", 1.0],
		["say", "vaelor", "VAELOR", "The bloodline survives."],
		["say", "alaric", "ALARIC", "What does that mean?"],
		["wait", 1.6], ["fadeout", "vaelor", 1.8], ["wait", 2.0], ["beat", "gone"],
		["look", "alaric", "W"], ["bubble", "alaric", "..."],
		["narrate", "Someone of the royal blood may be behind the attacks.", 3.0],  # DRAFT: the owner's disturbing new clue; nobody is named
		["wait", 1.0], ["fade", 1.0, 1.4],
	], {"next": "fl_king_heir"})
	s["fl_king_heir"] = _scene("fl_king_heir", ROOM, "#2a2a40", 0.16, [
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 1.8], ["beat", "start"],
		["walk", "alaric", [6, 6], {"t": 0.6}], ["wait", 0.8],
		["say", "alaric", "ALARIC", "He said he served the rightful heir."],
		["wait", 1.4], ["look", "king_npc", "S"],
		["say", "king_npc", "KING", "The Falcon Guard served my ancestors."],
		["say", "alaric", "ALARIC", "Could someone in your family be behind this?"],
		["wait", 1.4],
		["say", "king_npc", "KING", "There are distant branches of the royal family."],
		["say", "alaric", "ALARIC", "Someone with a claim to the throne?"],
		["say", "king_npc", "KING", "Possibly."],
		["wait", 1.4], ["look", "king_npc", "W"],
		["narrate", "The King will have the surviving royal lines searched. He does not look to his own house. He believes his own child is dead and past reaching.", 3.8],  # DRAFT: states what the owner says the King does not consider, without naming her
		["wait", 1.0], ["fade", 1.0, 1.2],
	], {"next": "fl_reave_private"})
	s["fl_reave_private"] = _scene("fl_reave_private", NIGHT, "#05050f", 0.4, [
		["spawn", "reave", REAVE_SHEET, [6, 14], "W"], ["spawn", "associate", "villager_man", [6, 6], "E", {"tint": "shadow"}],
		["fade", 0.0, 2.4], ["beat", "start"],
		["wait", 1.4], ["walk", "associate", [6, 10], {"t": 0.5}], ["beat", "report"],
		["narrate", "Vaelor's forces have been defeated. Alaric has begun to look into the royal bloodline.", 3.0],  # DRAFT: the owner's report, as a caption
		["say", "associate", "ASSOCIATE", "He knows the soldiers serve an heir."],
		["say", "reave", "REAVE", "Does he?"],
		["say", "associate", "ASSOCIATE", "He'll find the truth eventually."],
		["wait", 1.4],
		["say", "reave", "REAVE", "Then perhaps we should stop waiting."],
		["say", "associate", "ASSOCIATE", "Do we attack the capital?"],  # DRAFT: the associate asks whether they should attack
		["say", "reave", "REAVE", "Not yet."],
		["wait", 1.0], ["walk", "associate", [6, 4], {"t": 0.5, "hide": true}], ["wait", 0.8],
		["look", "reave", "N"], ["wait", 1.4],
		["say", "reave", "REAVE", "First, we give the people something to believe in."],
		["wait", 2.4], ["fade", 1.0, 2.0],
	], {"next": "fl_final"})
	s["fl_final"] = _scene("fl_final", OUTSIDE, "#d8a870", 0.2, [
		["spawn", "alaric", "king", [7, 8], "E"], ["spawn", "lyra", "mira", [6, 7], "E"], ["spawn", "messenger", "villager_man", [7, 1], "E", {"alpha": 0.0}],
		["fade", 0.0, 2.2], ["beat", "start"],
		["narrate", "Outside the palace. The city is bracing for unrest.", 3.0],  # DRAFT: the owner's setting
		["wait", 1.4], ["beat", "lyra"],
		["say", "lyra", "LYRA", "You think someone in the royal family summoned those soldiers?"],
		["say", "alaric", "ALARIC", "I think Vaelor believed he was serving an heir."],
		["say", "lyra", "LYRA", "That doesn't mean he was telling the truth."],
		["say", "alaric", "ALARIC", "No."],
		["wait", 1.2], ["look", "alaric", "E"],
		["say", "alaric", "ALARIC", "But it means someone wants the crown."],
		["wait", 1.0],
		["say", "lyra", "LYRA", "And what do you want?"],
		["wait", 1.6],
		["say", "alaric", "ALARIC", "To make sure no one else loses their home because of it."],
		["wait", 1.6], ["fadein", "messenger", 0.5], ["walk", "messenger", [7, 5], {"t": 0.35}], ["look", "alaric", "N"], ["beat", "messenger"],
		["say", "messenger", "MESSENGER", "Alaric. The King has found something."],
		["say", "alaric", "ALARIC", "What?"],
		["say", "messenger", "MESSENGER", "A name."],
		["wait", 1.6], ["shake", 0.02, 1.0], ["fade", 1.0, 2.0],
		["title", "CHAPTER ELEVEN COMPLETE", "The Dead King's Army", 3.6],
		["unlock", "heir"],  # chapter twelve opens on the world map
	])
	return s
