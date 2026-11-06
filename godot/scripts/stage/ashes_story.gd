class_name AshesStory
extends RefCounted
## Chapter ten, "Ashes of a Lie": the scenes StoryScene plays. The owner's dialogue is word for word; every line, caption or beat I wrote to join it is marked DRAFT.
## STORY CANON (godot/STORY_CANON.md): Reave is introduced as a charismatic public revolutionary whose criticisms of the crown are partly fair; nothing proves he did anything.
## Elowen is never named or shown. No document is signed by Reave, nobody says who summoned the Falcon Guard, and the vessels of Battle 4 are not shown to be controlled. The King
## is alive, takes responsibility for his neglect, and begins to govern. Aldren travels with the party as a story companion only.
## ART GAPS (see godot/HANDOFF.md): Reave, Aldren, the King, the archivist, the citizens, the messenger and the Falcon Guard have no sprites of their own (existing sheets stand in).
##   an_morning -> an_offer -> an_archives -> (Battle 1)    the morning after, the King's offer, the Falcon Guard in the records
##   an_b1_post                                             Aldren and Alaric on mercy
##   an_speech -> an_reave -> (Battle 2)                    the town square and Reave's speech; Alaric meets him
##   an_b2_post -> an_memorial                              Aldren and the insignia; the memorial chamber, the absent traces
##   an_sentinels_pre -> (Battle 3) -> an_b3_post -> an_cost    the sealed archives; the lie that travelled too fast
##   an_stolen_pre -> (Battle 4) -> an_b4_post              the Falcon Guard vessels: "The rightful one."
##   an_collapse_pre -> (Battle 5) -> an_b5_post -> an_king -> an_reave_private -> an_final     the Last Sentinel; the King's accountability; Reave in private; the next village

const ROOM := "res://samples/palace.json"
const ARC := "res://samples/archive.json"
const TOWN := "res://samples/ashes_town.json"
const MEMORIAL := "res://samples/ashes_memorial.json"
const NIGHT := "res://samples/ashes_night.json"
const A1 := "res://samples/ashes_1.json"
const A2 := "res://samples/ashes_2.json"
const A3 := "res://samples/ashes_3.json"
const A4 := "res://samples/ashes_4.json"
const A5 := "res://samples/ashes_5.json"
const OUTSIDE := "res://samples/crown_street.json"

const KING_SHEET := "lancer"  ## stand-in: the King has no sheet of his own
const REAVE_SHEET := "spectral_duelist"  ## stand-in: Reave has no sheet yet


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["squire", "Gideon", "Deserters. Watch the roadblock, and watch the trees."], ["warden", "Bram", "Old iron, and it still moves. Don't trade blows with the big ones."],
		["sorc", "Seraphine", "The sentinels are keeping to their old orders. Break the line, not the hall."], ["mira", "Lyra", "These ones think. Don't take them lightly."],
		["sorc", "Seraphine", "The vault is failing around it. Finish this before the roof does."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


static func _cast(y: int, alaric_at = null) -> Array:
	return [["spawn", "alaric", "king", alaric_at if alaric_at != null else [7, y], "E"], ["spawn", "bram", "warden", [8, y - 1], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, y - 1], "E"],
		["spawn", "merc", "merc", [5, y], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, y], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, y - 1], "E", {"tint": "vessel"}],
		["spawn", "seraphine", "sorc", [7, y + 1], "E", {"tint": "vessel"}], ["spawn", "aldren", "ironhollow_sentinel", [10, y], "E"]]  # stand-in: Aldren has no sheet


static func _march(y: int, t := 0.5) -> Array:
	return [["walk", "alaric", [7, y], {"t": t, "par": true}], ["walk", "bram", [8, y - 1], {"t": t, "par": true}], ["walk", "lyra", [6, y - 1], {"t": t, "par": true}],
		["walk", "merc", [5, y], {"t": t, "par": true}], ["walk", "gideon", [9, y], {"t": t, "par": true}], ["walk", "kaelen", [4, y - 1], {"t": t, "par": true}],
		["walk", "seraphine", [7, y + 1], {"t": t, "par": true}], ["walk", "aldren", [10, y], {"t": t, "par": true}], ["join"]]


static func _scene(id: String, map: String, tint: String, a: float, steps: Array, opts := {}) -> Dictionary:
	var d := {"id": id, "map": map, "stage": [0, 0, 0, 0], "steps": [["fade", 1.0, 0.0], ["bars", true], ["tint", tint, a, 0.1]] + steps}
	d.merge(opts, true)
	return d


static var SCENES: Dictionary = _build()


static func _build() -> Dictionary:
	var s := {}
	# ---------------------------------------------------------------------------------------------- the morning after
	s["an_morning"] = _scene("an_morning", ROOM, "#c8c8e0", 0.12, [
		["title", "CHAPTER TEN", "Ashes of a Lie", 2.8],
		["spawn", "alaric", "king", [6, 8], "W"], ["spawn", "lyra", "mira", [6, 3], "E", {"alpha": 0.0}],
		["fade", 0.0, 2.4], ["beat", "start"],
		["narrate", "The morning after. A guest chamber in the royal palace. The first morning since the fire that Alaric has nowhere he must be.", 3.6],  # DRAFT: the owner's note on the setting
		["wait", 1.8], ["look", "alaric", "N"], ["wait", 1.2],
		["fadein", "lyra", 0.6], ["walk", "lyra", [6, 6], {"t": 0.6}], ["beat", "lyra"],
		["say", "lyra", "LYRA", "You didn't sleep."],
		["say", "alaric", "ALARIC", "A little."],
		["say", "lyra", "LYRA", "That's what you said yesterday."],
		["say", "alaric", "ALARIC", "Then I'm consistent."],
		["wait", 0.8], ["bubble", "lyra", "~"],
		["say", "lyra", "LYRA", "What are you thinking?"],
		["say", "alaric", "ALARIC", "I spent so long imagining what I'd say when I reached him."],
		["say", "lyra", "LYRA", "And?"],
		["say", "alaric", "ALARIC", "None of it mattered."],
		["say", "lyra", "LYRA", "It mattered to you."],
		["wait", 1.4], ["look", "alaric", "E"],
		["say", "alaric", "ALARIC", "I nearly killed a man who didn't destroy my home."],
		["walk", "lyra", [6, 7], {"t": 0.5}], ["wait", 0.6],
		["say", "lyra", "LYRA", "You didn't."],
		["say", "alaric", "ALARIC", "Because he stopped fighting."],
		["say", "lyra", "LYRA", "Because you chose not to."],
		["wait", 1.8], ["bubble", "alaric", "..."], ["wait", 1.0],
		["say", "alaric", "ALARIC", "I need to know who did it."],
		["say", "lyra", "LYRA", "Then we'll find them."],
		["wait", 1.6], ["fade", 1.0, 1.4],
	], {"next": "an_offer"})
	s["an_offer"] = _scene("an_offer", ROOM, "#2a2a40", 0.16, [
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "aldren", "ironhollow_sentinel", [4, 9], "E"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 1.8], ["beat", "start"],
		["walk", "alaric", [6, 6], {"t": 0.6}], ["wait", 0.8], ["hold", "king_npc", "hit", 2], ["beat", "king"],
		["say", "king_npc", "KING", "I trust you slept better than I did."],
		["say", "alaric", "ALARIC", "Not particularly."],
		["say", "king_npc", "KING", "Then we have something in common."],
		["wait", 0.8], ["look", "aldren", "S"],
		["say", "aldren", "ALDREN", "Your Majesty, perhaps we should begin."],
		["wait", 0.8],
		["narrate", "The King, still unhealed, tells it plainly. His investigators have read the records Alaric brought.", 3.2],  # DRAFT: the owner's exposition, staged as a caption
		["say", "king_npc", "KING", "No orders. No deployments. No missing soldiers."],
		["say", "alaric", "ALARIC", "But they were there."],
		["say", "king_npc", "KING", "I believe you."],
		["wait", 1.0],
		["narrate", "The regiment ceased to exist generations ago. There is no record of its return. The King gives Alaric leave to search the kingdom's military archives and to travel under royal protection.", 4.4],  # DRAFT
		["say", "king_npc", "KING", "You owe me no allegiance."],
		["say", "alaric", "ALARIC", "And you expect me to believe you'll help?"],
		["say", "king_npc", "KING", "I expect you to judge me by what I do next."],
		["wait", 1.2], ["look", "king_npc", "W"],
		["narrate", "He asks Captain Aldren to go with Alaric as the crown's representative. Aldren agrees, reluctantly.", 3.4],  # DRAFT: the owner's staging
		["bubble", "aldren", "~"], ["wait", 1.4], ["fade", 1.0, 1.4],
	], {"next": "an_archives"})
	s["an_archives"] = _scene("an_archives", ARC, "#d0a860", 0.18, [
		["spawn", "alaric", "king", [8, 4], "E"], ["spawn", "lyra", "mira", [6, 3], "E"], ["spawn", "seraphine", "sorc", [5, 4], "E", {"tint": "vessel"}],
		["spawn", "aldren", "ironhollow_sentinel", [9, 3], "E"], ["spawn", "archivist", "villager_man", [8, 10], "W"],  # stand-in: the archivist has no sheet
		["fade", 0.0, 1.6], ["beat", "start"],
		["walk", "alaric", [7, 8], {"t": 0.55}], ["wait", 0.6], ["beat", "records"],
		["narrate", "The royal military archives. Shelves of ledgers, muster rolls and campaign maps. Here the old regiment has a name: the Falcon Guard.", 4.2],  # DRAFT: the owner's name for the regiment
		["narrate", "It served the royal family generations ago, and its members died in a long-forgotten campaign. Their armor, insignia and weapons match what Alaric saw.", 4.2],  # DRAFT
		["say", "archivist", "ARCHIVIST", "There hasn't been a living Falcon Guard soldier in over a century."],
		["say", "alaric", "ALARIC", "Then someone summoned them."],
		["wait", 0.8], ["look", "seraphine", "E"],
		["say", "seraphine", "SERAPHINE", "A summoner could materialize soldiers who died long ago."],
		["say", "aldren", "ALDREN", "An entire regiment?"],
		["say", "seraphine", "SERAPHINE", "That would require extraordinary ability."],
		["wait", 1.2], ["bubble", "alaric", "..."],
		["say", "alaric", "ALARIC", "Someone did it."],
		["wait", 0.8],
		["say", "archivist", "ARCHIVIST", "There is a memorial fortress, far out on the old campaign road. More of the Falcon Guard's records are kept there."],  # DRAFT: the owner says the archivist reveals the fortress
		["say", "alaric", "ALARIC", "Then that's where we're going."],  # DRAFT: the party decides to travel there
		["wait", 1.0], ["fade", 1.0, 1.2],
	], {"also_seen": ["an_morning", "an_offer"]})
	# ---------------------------------------------------------------------------------------------- Battle 1
	s["an_b1_post"] = _scene("an_b1_post", A1, "#c8c8e0", 0.1, _cast(14) + [
		["spawn", "d1", "squire", [5, 19], "N"], ["spawn", "d2", "squire", [9, 20], "N"], ["spawn", "d3", "riverband_brute", [7, 22], "N"],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "d1", "hit", 2], ["hold", "d2", "ko", 2], ["hold", "d3", "hit", 2], ["wait", 1.0], ["look", "aldren", "W"], ["beat", "aldren"],
		["say", "aldren", "ALDREN", "You fought your way through the capital."],
		["say", "alaric", "ALARIC", "I remember."],
		["say", "aldren", "ALDREN", "Yet you spare men who attack you."],
		["say", "alaric", "ALARIC", "I spared your men too."],
		["say", "aldren", "ALDREN", "Not all of them escaped uninjured."],
		["say", "alaric", "ALARIC", "Neither did mine."],
		["wait", 1.6], ["look", "aldren", "E"], ["bubble", "aldren", "~"],
		["narrate", "Aldren says nothing more. But he no longer walks a step behind.", 3.0],  # DRAFT: the owner's note that he begins to respect Alaric
		["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- the revolutionary
	s["an_speech"] = _scene("an_speech", TOWN, "#e8c890", 0.14, _cast(2) + [
		["spawn", "reave", REAVE_SHEET, [7, 15], "W"],  # stand-in: Reave has no sheet of his own
		["spawn", "citizen", "villager_man", [6, 11], "E"],
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + [
		["wait", 0.8], ["narrate", "A town near the memorial fortress. A crowd in the square, and a young man in good, plain clothes speaking from the well's edge.", 3.6],  # DRAFT: the owner's staging
		["beat", "speech"],
		["say", "reave", "REAVE", "A kingdom should not depend upon the mood of one man."],
		["wait", 0.8],
		["say", "reave", "REAVE", "When the crown grieves, the people starve. When the crown looks away, the roads crumble. And when the crown fails, who answers for it?"],
		["wait", 0.8], ["bubble", "citizen", "!"],
		["say", "citizen", "CITIZEN", "No one!"],
		["say", "reave", "REAVE", "Exactly."],
		["wait", 0.8],
		["say", "reave", "REAVE", "I don't ask you to hate your King. I ask you to imagine a kingdom that doesn't need one."],
		["wait", 1.0], ["shake", 0.01, 0.8], ["bubble", "citizen", "!"], ["wait", 1.2], ["beat", "cheers"],
		["look", "lyra", "E"], ["wait", 0.6],
		["say", "lyra", "LYRA", "He's not wrong about everything."],
		["say", "alaric", "ALARIC", "No."],
		["wait", 0.6], ["look", "aldren", "E"],
		["say", "aldren", "ALDREN", "He speaks as though the King has done nothing for this country."],
		["say", "alaric", "ALARIC", "He hasn't done enough lately."],
		["wait", 1.4], ["bubble", "aldren", "..."], ["wait", 1.0],
		["fade", 1.0, 1.0],
	], {"folk": [["villager_man", [5, 12]], ["villager_girl", [9, 12]], ["villager_kid", [8, 13]], ["mechanic", [6, 14]], ["villager_man", [10, 14]]], "next": "an_reave"})
	s["an_reave"] = _scene("an_reave", TOWN, "#e8c890", 0.14, _cast(4) + [
		["spawn", "reave", REAVE_SHEET, [7, 14], "W"],
		["fade", 0.0, 1.6], ["beat", "start"],
		["walk", "alaric", [7, 10], {"t": 0.5}], ["wait", 0.6], ["look", "reave", "S"], ["beat", "notice"],
		["say", "reave", "REAVE", "You're Alaric."],
		["say", "alaric", "ALARIC", "Do I know you?"],
		["say", "reave", "REAVE", "Not yet."],
		["wait", 0.6],
		["say", "reave", "REAVE", "Reave. I make speeches. Occasionally people listen."],
		["say", "alaric", "ALARIC", "I noticed."],
		["say", "reave", "REAVE", "I heard you fought the King."],
		["say", "alaric", "ALARIC", "I did."],
		["say", "reave", "REAVE", "And yet he's still alive."],
		["say", "alaric", "ALARIC", "Yes."],
		["say", "reave", "REAVE", "Interesting."],
		["wait", 0.8],
		["say", "alaric", "ALARIC", "Disappointed?"],
		["wait", 0.6], ["bubble", "reave", "~"],
		["say", "reave", "REAVE", "Curious."],
		["wait", 0.8],
		["narrate", "Reave says he believes the kingdom needs another kind of government. He asks whether Alaric means to stand with the King now.", 3.6],  # DRAFT: the owner's exposition
		["say", "alaric", "ALARIC", "I'm looking for the people who destroyed my village."],
		["say", "reave", "REAVE", "Then I hope you find them."],
		["wait", 1.4], ["look", "reave", "E"], ["walk", "reave", [7, 20], {"t": 0.6}], ["beat", "gone"],
		["wait", 0.8], ["look", "alaric", "E"], ["bubble", "alaric", "..."], ["wait", 1.0],
		["fade", 1.0, 1.2],
	])
	s["an_b2_post"] = _scene("an_b2_post", A2, "#c8c8e0", 0.12, _cast(15) + [
		["fade", 0.0, 1.4], ["beat", "start"],
		["narrate", "The gate of the old Falcon Guard memorial fortress. A crowned falcon over two crossed blades is cut into the keystone.", 3.6],  # DRAFT
		["look", "aldren", "N"], ["wait", 1.0],
		["say", "aldren", "ALDREN", "My grandfather told stories about them."],
		["say", "alaric", "ALARIC", "Were they loyal?"],
		["say", "aldren", "ALDREN", "To the crown. Absolutely."],
		["say", "alaric", "ALARIC", "Even after death?"],
		["wait", 1.0], ["look", "aldren", "E"],
		["say", "aldren", "ALDREN", "That's what we're here to find out."],
		["wait", 1.0], ["beat", "enter"],
	] + _march(21, 0.5) + [["fade", 1.0, 1.2]], {"next": "an_memorial"})
	s["an_memorial"] = _scene("an_memorial", MEMORIAL, "#b8b8d8", 0.18, _cast(2, [7, 2]) + [
		["fade", 0.0, 2.0], ["beat", "start"]] + _march(10, 0.6) + [
		["narrate", "A great chamber. The names of the Falcon Guard's fallen are cut into the stone, row on row.", 3.4],  # DRAFT: the owner's description of the memorial
		["wait", 0.6], ["look", "alaric", "N"], ["wait", 1.0],
		["say", "alaric", "ALARIC", "I know some of these names."],  # DRAFT: Alaric recognises names from chapter seven's burial records
		["wait", 1.0], ["walk", "seraphine", [10, 14], {"t": 0.5}], ["look", "seraphine", "N"], ["fx", "seraphine", "circle", 1.0], ["beat", "traces"],
		["say", "seraphine", "SERAPHINE", "This place remembers them."],
		["say", "alaric", "ALARIC", "Can you reach them?"],
		["say", "seraphine", "SERAPHINE", "Not all of them."],
		["wait", 1.0],
		["narrate", "Several of the soldiers' spiritual traces feel strangely absent. It proves nothing. They may have been summoned elsewhere.", 4.0],  # DRAFT: the owner's note that this does not prove the spirits are gone
		["wait", 1.0], ["look", "alaric", "W"], ["bubble", "alaric", "..."], ["wait", 1.0],
		["say", "alaric", "ALARIC", "Someone else is doing this."],  # DRAFT: Alaric becomes more convinced another summoner is involved
		["wait", 1.0], ["shake", 0.025, 1.2], ["bubble", "kaelen", "!"],
		["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- Battle 3 and the cost of the lie
	s["an_sentinels_pre"] = _scene("an_sentinels_pre", A3, "#b8b8d8", 0.16, _cast(2, "@king") + [
		["spawn", "g1", "ironhollow_sentinel", [7, 14], "W"], ["spawn", "g2", "stone_colossus", [4, 12], "W"], ["spawn", "g3", "stone_colossus", [10, 12], "W"],
		["fade", 0.0, 1.6], ["beat", "start"]] + _march(8, 0.55) + [
		["narrate", "The inner hall. Beyond it, the sealed archives. The fortress's old defenses wake and take their places.", 3.2],  # DRAFT: the owner's staging
		["wait", 0.6], ["shake", 0.03, 1.0], ["flash"], ["fade", 1.0, 1.0],
	])
	s["an_b3_post"] = _scene("an_b3_post", A3, "#b8b8d8", 0.12, _cast(14) + [
		["fade", 0.0, 1.4], ["beat", "start"],
		["narrate", "The sealed archives open. The Falcon Guard's commanders are listed by name. One of them is the soldier Alaric saw in Vespera's burial record. He died more than a century ago.", 4.6],  # DRAFT: the owner's note that the officer matches
		["wait", 0.8], ["look", "aldren", "N"],
		["say", "aldren", "ALDREN", "Then it wasn't our army."],
		["say", "alaric", "ALARIC", "No."],
		["say", "aldren", "ALDREN", "Someone wanted you to think it was."],
		["wait", 1.2], ["look", "alaric", "N"], ["bubble", "alaric", "..."], ["wait", 0.8],
		["say", "alaric", "ALARIC", "And it worked."],
		["wait", 1.0], ["fade", 1.0, 1.0],
	], {"next": "an_cost"})
	s["an_cost"] = _scene("an_cost", A3, "#b8b8d8", 0.14, _cast(14) + [
		["fade", 0.0, 1.4], ["beat", "start"],
		["narrate", "Among the papers, a ledger of dispatches. The tale of the massacre reached distant towns before any witness could have walked there.", 4.2],  # DRAFT: the owner's rumours-spread-too-quickly evidence; it names nobody
		["look", "aldren", "N"], ["wait", 0.8], ["beat", "disturbed"],
		["say", "aldren", "ALDREN", "Someone prepared the story before the attack."],
		["say", "alaric", "ALARIC", "They wanted people to believe it."],
		["say", "lyra", "LYRA", "And they wanted you to believe it."],
		["wait", 1.4],
		["say", "alaric", "ALARIC", "I gave them exactly what they wanted."],
		["say", "lyra", "LYRA", "You survived. They didn't plan for that."],
		["wait", 1.6], ["look", "alaric", "N"],
		["say", "alaric", "ALARIC", "Then I'll make sure they regret it."],
		["wait", 1.4], ["fade", 1.0, 1.2],
	], {"also_seen": ["an_b3_post"]})
	# ---------------------------------------------------------------------------------------------- Battle 4: the stolen dead
	s["an_stolen_pre"] = _scene("an_stolen_pre", A4, "#b8b8d8", 0.16, _cast(2, "@king") + [
		["spawn", "f1", "spectral_duelist", [4, 14], "W", {"alpha": 0.0}], ["spawn", "f2", "ironhollow_sentinel", [9, 14], "W", {"alpha": 0.0}], ["spawn", "f3", "riverband_brute", [7, 18], "W", {"alpha": 0.0}],
		["fade", 0.0, 1.6], ["beat", "start"]] + _march(8, 0.55) + [
		["wait", 0.8], ["shake", 0.02, 1.2], ["fadein", "f1", 0.8], ["fadein", "f2", 0.8], ["fadein", "f3", 0.8], ["fx", "f3", "smoke", 1.0], ["beat", "appear"],
		["narrate", "Soldiers in the old armor of the Falcon Guard step out of the air, in good order. They are not mindless. They are watching the party as soldiers do.", 4.2],  # DRAFT: vessels with discipline and judgement of their own
		["say", "alaric", "ALARIC", "That armor."],  # DRAFT
		["wait", 0.8], ["act", "f3", "attack"], ["flash"], ["fade", 1.0, 1.0],
	])
	s["an_b4_post"] = _scene("an_b4_post", A4, "#b8b8d8", 0.12, _cast(12) + [
		["spawn", "f1", "spectral_duelist", [7, 17], "W"], ["spawn", "f2", "ironhollow_sentinel", [5, 18], "N"],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "f1", "ko", 2], ["hold", "f2", "ko", 2], ["wait", 1.0],
		["walk", "alaric", [7, 15], {"t": 0.6}], ["look", "alaric", "E"], ["beat", "last"],
		["say", "alaric", "ALARIC", "Who summoned you?"],
		["wait", 0.8], ["look", "f1", "S"],
		["say", "f1", "SOLDIER", "I serve the crown."],
		["say", "alaric", "ALARIC", "Which crown?"],
		["wait", 1.2], ["bubble", "f1", "..."],
		["say", "f1", "SOLDIER", "The rightful one."],
		["wait", 0.8], ["fadeout", "f1", 1.2], ["fadeout", "f2", 1.2], ["wait", 1.6], ["beat", "gone"],
		["look", "alaric", "W"], ["bubble", "alaric", "..."], ["wait", 1.0],
		["look", "seraphine", "E"],
		["say", "seraphine", "SERAPHINE", "Summoned vessels may stay loyal to beliefs and causes from their former lives."],  # DRAFT: the owner's explanation, put in Seraphine's mouth
		["say", "seraphine", "SERAPHINE", "That doesn't mean they understand what their summoner wants."],  # DRAFT
		["wait", 1.4], ["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- Battle 5: the last sentinel
	s["an_collapse_pre"] = _scene("an_collapse_pre", A5, "#a8a8c8", 0.18, _cast(2, "@king") + [
		["spawn", "boss", "stone_colossus", [7, 17], "W", {"alpha": 0.0}],
		["fade", 0.0, 1.6], ["beat", "start"]] + _march(8, 0.55) + [
		["shake", 0.04, 1.6], ["wait", 0.6],
		["narrate", "The vessels' arrival has shaken the memorial's old wards. Dust falls from the vault. Something enormous wakes at its heart.", 3.8],  # DRAFT: the owner's cause for the collapse
		["fadein", "boss", 1.2], ["beat", "sentinel"],
		["say", "seraphine", "SERAPHINE", "It isn't a spirit. It's a mechanism: it thinks we are the threat."],  # DRAFT: the Sentinel is an old security mechanism, not an evil spirit
		["say", "aldren", "ALDREN", "If the vault falls, the records go with it."],  # DRAFT
		["wait", 0.6], ["flash"], ["fade", 1.0, 1.0],
	])
	s["an_b5_post"] = _scene("an_b5_post", A5, "#a8a8c8", 0.12, _cast(10) + [
		["spawn", "boss", "stone_colossus", [7, 16], "W"],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "boss", "ko", 2], ["wait", 1.6], ["shake", 0.02, 1.0], ["wait", 1.0], ["beat", "stabilized"],
		["narrate", "The guardian collapses. The vault settles. Seraphine and Aldren gather what the stone has kept.", 3.4],  # DRAFT
		["narrate", "The records confirm it. The Falcon Guard died generations ago. Their vessels were materialized only recently. Someone spread the tale of a royal massacre far faster than any witness could carry it. And the summoner's name is nowhere written.", 6.0],  # DRAFT: the owner's four findings
		["wait", 1.0], ["look", "alaric", "N"], ["bubble", "alaric", "..."], ["wait", 1.2],
		["narrate", "It was not a crime of rage. It was a plan.", 3.2],  # DRAFT: the owner's note that Alaric now understands this was a planned deception
		["wait", 1.0], ["fade", 1.0, 1.4],
	], {"next": "an_king"})
	# ---------------------------------------------------------------------------------------------- the King's accountability
	s["an_king"] = _scene("an_king", ROOM, "#2a2a40", 0.16, [
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 1.8], ["beat", "start"],
		["walk", "alaric", [6, 6], {"t": 0.6}], ["wait", 1.0], ["narrate", "Alaric lays the evidence on the King's table.", 2.6],  # DRAFT
		["look", "king_npc", "S"], ["wait", 1.2], ["beat", "evidence"],
		["say", "king_npc", "KING", "Someone used the soldiers of my ancestors to destroy your village."],
		["say", "alaric", "ALARIC", "Yes."],
		["say", "king_npc", "KING", "And made you believe I ordered it."],
		["say", "alaric", "ALARIC", "Yes."],
		["wait", 1.2], ["look", "king_npc", "W"],
		["say", "king_npc", "KING", "Then this was never only about your village."],
		["say", "alaric", "ALARIC", "No."],
		["say", "king_npc", "KING", "Someone wanted the kingdom to turn against me."],
		["wait", 0.8], ["look", "king_npc", "S"],
		["say", "king_npc", "KING", "And while I was grieving, I gave them every opportunity."],
		["wait", 1.6],
		["say", "alaric", "ALARIC", "You didn't burn my village."],
		["wait", 1.4],
		["say", "alaric", "ALARIC", "But you weren't watching your kingdom."],
		["wait", 1.6],
		["say", "king_npc", "KING", "No. I wasn't."],
		["wait", 2.0], ["beat", "accountable"],
		["narrate", "From that day the King sits again in his council, and reads the letters he left sealed.", 3.4],  # DRAFT: the owner's note that he begins to govern
		["wait", 1.0], ["fade", 1.0, 1.4],
	], {"next": "an_reave_private"})
	s["an_reave_private"] = _scene("an_reave_private", NIGHT, "#05050f", 0.4, [
		["spawn", "reave", REAVE_SHEET, [6, 14], "W"], ["spawn", "associate", "villager_man", [6, 6], "E", {"tint": "shadow"}],  # an unnamed shadow: not Elowen
		["fade", 0.0, 2.4], ["beat", "start"],
		["wait", 1.4], ["walk", "associate", [6, 10], {"t": 0.5}], ["beat", "report"],
		["say", "associate", "ASSOCIATE", "The summoner has found the old records."],
		["say", "reave", "REAVE", "Has he?"],
		["say", "associate", "ASSOCIATE", "He knows the soldiers were dead."],
		["wait", 1.2],
		["say", "reave", "REAVE", "Then he's cleverer than I expected."],
		["say", "associate", "ASSOCIATE", "Should we stop him?"],
		["wait", 1.0], ["bubble", "reave", "~"], ["wait", 0.6],
		["say", "reave", "REAVE", "Not yet."],
		["wait", 1.0], ["walk", "associate", [6, 4], {"t": 0.5, "hide": true}], ["wait", 1.0],
		["look", "reave", "N"], ["wait", 1.6],
		["say", "reave", "REAVE", "Let's see what he does with the truth."],
		["wait", 2.4], ["fade", 1.0, 2.0],
	], {"next": "an_final"})
	s["an_final"] = _scene("an_final", OUTSIDE, "#d8a870", 0.2, [
		["spawn", "alaric", "king", [7, 8], "E"], ["spawn", "lyra", "mira", [6, 7], "E"], ["spawn", "messenger", "villager_man", [7, 1], "E", {"alpha": 0.0}],  # stand-in: the messenger has no sheet
		["fade", 0.0, 2.2], ["beat", "start"],
		["narrate", "Outside the palace. The capital is quieter than before.", 3.0],  # DRAFT: the owner's setting
		["wait", 1.4], ["beat", "lyra"],
		["say", "lyra", "LYRA", "You finally know what happened."],
		["say", "alaric", "ALARIC", "Part of it."],
		["say", "lyra", "LYRA", "Someone used the dead to start a war."],
		["say", "alaric", "ALARIC", "And they almost got one."],
		["wait", 1.2],
		["say", "lyra", "LYRA", "What happens when you find them?"],
		["wait", 1.6],
		["say", "alaric", "ALARIC", "I ask why."],
		["say", "lyra", "LYRA", "And if you don't like the answer?"],
		["wait", 1.4], ["look", "alaric", "E"],
		["say", "alaric", "ALARIC", "Then I'll decide what to do."],
		["wait", 1.6], ["fadein", "messenger", 0.5], ["walk", "messenger", [7, 5], {"t": 0.35}], ["look", "alaric", "N"], ["beat", "messenger"],
		["say", "messenger", "MESSENGER", "Alaric. His Majesty requests your presence."],
		["say", "alaric", "ALARIC", "Why?"],
		["say", "messenger", "MESSENGER", "Another village has been attacked."],
		["wait", 1.0], ["look", "alaric", "N"],
		["say", "messenger", "MESSENGER", "And the witnesses say the soldiers were already dead."],
		["wait", 1.6], ["shake", 0.02, 1.0], ["fade", 1.0, 2.0],
		["title", "CHAPTER TEN COMPLETE", "Ashes of a Lie", 3.6],
		["unlock", "falcon"],  # chapter eleven opens on the world map
	])
	return s
