class_name FinalStory
extends RefCounted
## The final arc, chapters twelve to fifteen: the scenes StoryScene plays. The owner's dialogue is word for word; every caption, beat and line I wrote to join it is
## marked DRAFT (lines in `_t` lists are the owner's unless the entry is a ["*id", text] DRAFT line or a ["@n", text] DRAFT caption).
## STORY CANON (godot/STORY_CANON.md, now complete): Elowen is alive (revealed at the end of chapter twelve); Reave planned the village and Elowen summoned the Falcon Guard
## who burned it (revealed in chapter thirteen); they are equal, devoted partners, neither betrays the other, nobody is controlled; the King is innocent of the massacre but
## guilty of neglect; Vaelor answers for his choice; the ending leaves Reave and Elowen in custody, the King reforming, and Alaric building.
## ART GAPS: Reave, Elowen, Vaelor, Cassian, the King, Aldren, the servant, the officers and the revolutionaries are stand-ins (see godot/HANDOFF.md). No music, no credits art.

const ROOM := "res://samples/palace.json"
const COURT := "res://samples/arc_courtyard.json"
const ESTATE := "res://samples/arc_estate.json"
const CHAPEL := "res://samples/arc_chapel.json"
const RUINS := "res://samples/arc_ruins.json"
const TOWN := "res://samples/ashes_town.json"
const NIGHT := "res://samples/ashes_night.json"
const STREET := "res://samples/crown_street.json"
const HILL := "res://samples/crown_hill.json"

const KING_SHEET := "lancer"  ## stand-in: the King has no sheet of his own
const REAVE_SHEET := "spectral_duelist"  ## stand-in
const ELOWEN_SHEET := "villager_girl"  ## stand-in in scenes (the same as the chapter nine teaser); in battle the Soul Warden sheet stands in
const VAELOR_SHEET := "riverband_brute"  ## stand-in, the same as chapter eleven
const CASSIAN_SHEET := "spectral_duelist"  ## stand-in, the same as chapter six

const NAMES := {"alaric": "ALARIC", "lyra": "LYRA", "bram": "BRAM", "merc": "MERC", "gideon": "GIDEON", "kaelen": "KAELEN", "seraphine": "SERAPHINE", "cassian": "CASSIAN",
	"king_npc": "KING", "aldren": "ALDREN", "elowen": "ELOWEN", "reave": "REAVE", "vaelor": "VAELOR", "servant": "SERVANT", "officer": "OFFICER", "woman": "WOMAN"}


static func opening(ch: int, n: int) -> Array:  # DRAFT barks as each battle opens
	var lines := {12: [["squire", "Gideon", "They guard the road, not the villages. Note that."], ["sorc", "Seraphine", "The sentinels are old wards. The spearmen are not."],
			["warden", "Bram", "A drill yard. Let's give them a lesson."], ["choir", "Kaelen", "Underground, cramped, guarded. My favourite."], ["mira", "Lyra", "Vaelor. Stay together."]],
		13: [["squire", "Gideon", "Her guard. Break it and get out."], ["mira", "Lyra", "Keep them off the houses."], ["warden", "Bram", "Reave's own. Mind the duelists."],
			["choir", "Kaelen", "A burning flag. Subtle."], ["squire", "Gideon", "Hold the wall with the royal line."]],
		14: [["merc", "Merc", "Saboteurs. Let's keep this meeting on."], ["sorc", "Seraphine", "They were left behind to stop us. Do not let them."],
			["spectral_duelist", "Cassian", "Watch the cavalry's flank. Then turn it."], ["squire", "Gideon", "Their staging ground. Take it apart."], ["warden", "Bram", "Last road. Then Hollowmark."]],
		15: [["squire", "Gideon", "Outer works first. Offer them a way out."], ["mira", "Lyra", "Vaelor, for the last time."], ["choir", "Kaelen", "Reave's most devoted. Charming."],
			["sorc", "Seraphine", "Her strongest. She is tiring; so are they."], ["mira", "Lyra", "Together, then. So are we."]]}
	return lines[ch][n - 1]


static func vaelor_fades(ch: int) -> Array:
	return [VAELOR_SHEET, "Vaelor", "My oath remains." if ch == 12 else "I called it duty."]


static func lovers_fall() -> Array:
	return [REAVE_SHEET, "Reave", "...Well."]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


## The company on a line at depth `y` (Alaric on the battle's start cell with "@king"); `extra` adds the King, Aldren or Cassian beside them.
static func _cast(y: int, alaric_at = null, extra := []) -> Array:
	var out := [["spawn", "alaric", "king", alaric_at if alaric_at != null else [7, y], "E"], ["spawn", "bram", "warden", [8, y - 1], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, y - 1], "E"],
		["spawn", "merc", "merc", [5, y], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, y], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, y - 1], "E", {"tint": "vessel"}],
		["spawn", "seraphine", "sorc", [7, y + 1], "E", {"tint": "vessel"}]]
	if extra.has("cassian"):
		out.append(["spawn", "cassian", CASSIAN_SHEET, [10, y - 1], "E", {"tint": "vessel"}])
	if extra.has("king"):
		out.append(["spawn", "king_npc", KING_SHEET, [3, y], "E"])
	if extra.has("aldren"):
		out.append(["spawn", "aldren", "ironhollow_sentinel", [10, y], "E"])
	return out


static func _march(y: int, t := 0.5) -> Array:
	return [["walk", "alaric", [7, y], {"t": t, "par": true}], ["walk", "bram", [8, y - 1], {"t": t, "par": true}], ["walk", "lyra", [6, y - 1], {"t": t, "par": true}],
		["walk", "merc", [5, y], {"t": t, "par": true}], ["walk", "gideon", [9, y], {"t": t, "par": true}], ["walk", "kaelen", [4, y - 1], {"t": t, "par": true}],
		["walk", "seraphine", [7, y + 1], {"t": t, "par": true}], ["join"]]


## Turns a list of lines into steps: [id, text] is the owner's line said by id; ["*id", text] is a DRAFT line; ["@", text] or ["@n", text] a caption (DRAFT);
## [seconds] a pause; anything else is passed through as a step.
static func _t(items: Array) -> Array:
	var out := []
	for it in items:
		if it is Array and it.size() == 1 and (it[0] is float or it[0] is int):
			out.append(["wait", float(it[0])])
		elif it is Array and it.size() == 2 and String(it[0]).begins_with("@"):
			out.append(["narrate", String(it[1]), clampf(String(it[1]).length() / 32.0, 2.6, 5.4)])
		elif it is Array and it.size() == 2 and it[0] is String and (NAMES.has(it[0]) or (String(it[0]).begins_with("*") and NAMES.has(String(it[0]).substr(1)))):
			var id := String(it[0]).trim_prefix("*")
			out.append(["say", id, NAMES[id], String(it[1])])
		else:
			out.append(it)
	return out


static func _scene(id: String, map: String, tint: String, a: float, steps: Array, opts := {}) -> Dictionary:
	var d := {"id": id, "map": map, "stage": [0, 0, 0, 0], "steps": [["fade", 1.0, 0.0], ["bars", true], ["tint", tint, a, 0.1]] + steps}
	d.merge(opts, true)
	return d


## A short scene before a battle with no dialogue of the owner's: the company walks in, a DRAFT caption, foes appear, the fight starts.
static func _pre(id: String, map: String, tint: String, caption: String, foes: Array, extra := []) -> Dictionary:
	var steps := _cast(2, "@king", extra) + foes + [["fade", 0.0, 1.6], ["beat", "start"]] + _march(8, 0.55) + [["narrate", caption, 3.6], ["wait", 0.6], ["shake", 0.02, 0.8], ["flash"], ["fade", 1.0, 1.0]]
	return _scene(id, map, tint, 0.16, steps)


static var SCENES: Dictionary = _build()


static func _build() -> Dictionary:
	var s := {}
	_twelve(s)
	_thirteen(s)
	_fourteen(s)
	_fifteen(s)
	return s


static func _ff(id: String, sheet: String, at: Array, dir := "W", alpha := 1.0) -> Array:  # a Falcon Guard vessel on the stage
	return ["spawn", id, sheet, at, dir, {"tint": "falcon", "alpha": alpha}]


static func _rv(id: String, sheet: String, at: Array, dir := "W") -> Array:  # an armed revolutionary on the stage
	return ["spawn", id, sheet, at, dir, {"tint": "revolt"}]


# ================================================================================================ CHAPTER TWELVE: THE WOMAN WHO RETURNED
static func _twelve(s: Dictionary) -> void:
	s["c12_open"] = _scene("c12_open", ROOM, "#2a2a40", 0.16, [
		["title", "CHAPTER TWELVE", "The Woman Who Returned", 2.8],
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "aldren", "ironhollow_sentinel", [4, 9], "E"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 2.0], ["beat", "start"], ["walk", "alaric", [6, 6], {"t": 0.6}]] + _t([
		["@", "The King has found the Falcon Guard's last records. Commander Vaelor once swore an oath directly to the royal line of succession. The records hold a name."],
		[1.0], ["hold", "king_npc", "hit", 2], ["bubble", "king_npc", "..."],
		["king_npc", "That cannot be."], ["alaric", "What did you find?"], ["king_npc", "The Falcon Guard's final oath. They swore themselves to the royal bloodline."],
		["aldren", "And the name, Your Majesty?"], [1.6], ["king_npc", "My daughter."], [1.4], ["look", "alaric", "N"],
		["alaric", "We couldn't find her spirit."], ["king_npc", "I know."], ["alaric", "That doesn't mean—"], ["king_npc", "I buried her."], [1.4],
		["@", "The King will not believe his daughter could be part of this. Someone, he says, is using her name. Alaric agrees to find out who."],
		[1.0], ["fade", 1.0, 1.2]]), {"next": "c12_road_pre"})
	s["c12_road_pre"] = _scene("c12_road_pre", "res://samples/arc12_1.json", "#d8c8a0", 0.14, _cast(2, "@king") + [
		_ff("f1", "spectral_duelist", [5, 13]), _ff("f2", "ironhollow_sentinel", [9, 14]), _ff("f3", "riverband_brute", [7, 19]),
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + _t([
		["@", "Silvermere: a royal summer estate, once Elowen's. Gardens, old training grounds, a small chapel, private archives. Beautiful, and long neglected."],
		[0.8], ["look", "f3", "S"], ["*alaric", "Falcon Guard. Here."], [0.6], ["act", "f3", "attack"], ["flash"], ["fade", 1.0, 1.0]]), {"also_seen": ["c12_open"]})
	s["c12_b1_post"] = _scene("c12_b1_post", "res://samples/arc12_1.json", "#d8c8a0", 0.12, _cast(11) + [
		_ff("f1", "spectral_duelist", [7, 15]), _ff("f2", "ironhollow_sentinel", [5, 16], "N"),
		["fade", 0.0, 1.4], ["beat", "start"], ["hold", "f1", "ko", 2], ["hold", "f2", "ko", 2], [1.0]] + _t([
		["fadeout", "f1", 1.4], ["fadeout", "f2", 1.4], [1.8],
		["@", "The soldiers dissolve. They were not marching on any village. They stood across the road to the estate, as guards stand at a door."],
		["*alaric", "They weren't here to attack anyone. They were guarding the place."], ["*gideon", "Then someone wants it kept."], [1.2], ["fade", 1.0, 1.2]]))
	s["c12_gardens_pre"] = _pre("c12_gardens_pre", "res://samples/arc12_2.json", "#c8d8a8", "The estate gardens. Hedges gone wild, terraces cracked, and on their plinths old enchanted sentinels turning their heads.",
		[["spawn", "g1", "stone_colossus", [5, 14], "W"], _ff("f1", "squire", [9, 15])])
	s["c12_b2_post"] = _scene("c12_b2_post", ESTATE, "#c8b898", 0.16, _cast(3) + [
		["fade", 0.0, 1.6], ["beat", "start"], ["walk", "lyra", [6, 9], {"t": 0.6}], ["look", "lyra", "N"]] + _t([
		["@", "In a gallery off the gardens, a portrait of Princess Elowen. She looks about Lyra's age."],
		["@", "On a desk nearby, her childhood writings: histories of the kingdom, and a girl's questions about why some people inherit authority over others."],
		[1.2], ["bubble", "lyra", "..."],
		["lyra", "I wonder what she would have wanted."], ["alaric", "Who?"], ["lyra", "The Princess. If she could have come back."], ["alaric", "I don't know."],
		[1.4], ["lyra", "Neither do I."], [1.4], ["fade", 1.0, 1.2]]))
	s["c12_grounds_pre"] = _pre("c12_grounds_pre", "res://samples/arc12_3.json", "#d8c8a0", "The estate's old training grounds. Falcon Guard drawn up in drill order, as if they had never stopped.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), _ff("f2", "riverband_brute", [9, 15])])
	s["c12_b3_post"] = _scene("c12_b3_post", ESTATE, "#c8b898", 0.16, _cast(3) + [["fade", 0.0, 1.6], ["beat", "start"]] + _march(9, 0.5) + _t([
		["@", "Inside, small signs that cannot be mistaken: furnishings freshly repaired, books recently read, and one room kept ready for someone who should be dead."],
		[1.0], ["bubble", "kaelen", "!"], ["*kaelen", "Someone lives here."], ["*alaric", "Or did, not long ago."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c12_servant"})
	s["c12_servant"] = _scene("c12_servant", ESTATE, "#c8b898", 0.16, _cast(3) + [
		["spawn", "servant", "villager_man", [7, 14], "W"], ["fade", 0.0, 1.6], ["beat", "start"], ["walk", "alaric", [7, 11], {"t": 0.5}]] + _t([
		["@", "An old servant has been keeping the estate in secret. A young woman came here months ago, he says. She looked exactly like Princess Elowen."],
		["servant", "I thought I was seeing a ghost."], ["alaric", "What did she say?"], ["servant", "She told me not to be afraid."],
		["lyra", "Did she tell you her name?"], [1.4], ["bubble", "servant", "..."], ["servant", "She said I already knew it."], [1.6],
		["@", "Elowen, alive? A woman wearing her face? Something else entirely? Alaric does not know."], [1.0], ["fade", 1.0, 1.2]]), {"also_seen": ["c12_b3_post"]})
	s["c12_chambers_pre"] = _pre("c12_chambers_pre", "res://samples/arc12_4.json", "#a8a8c8", "Beneath the estate, sealed chambers. Falcon Guard stand before the archive doors with an ancient guardian.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), ["spawn", "g1", "stone_golem", [7, 19], "W"]])
	s["c12_b4_post"] = _scene("c12_b4_post", "res://samples/arc12_4.json", "#a8a8c8", 0.14, _cast(12) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "Papers: lists, routes, the marks of someone using the estate as a refuge between journeys. And again and again, references to Reave's movement."],
		[0.8], ["*lyra", "Reave."], ["*alaric", "It doesn't prove anything."], ["*lyra", "No. But it's here."], [1.2], ["fade", 1.0, 1.0]]))
	s["c12_vaelor_pre"] = _scene("c12_vaelor_pre", "res://samples/arc12_5.json", "#c8d8a8", 0.16, _cast(2, "@king") + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 19], "W", {"tint": "falcon"}], _ff("h1", "ironhollow_sentinel", [5, 16]), _ff("h2", "ironhollow_sentinel", [10, 16]),
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + _t([["look", "vaelor", "S"],
		["vaelor", "You have no right to be here."], ["alaric", "Neither do you."], ["vaelor", "I serve the royal bloodline."], ["alaric", "Then tell me who summoned you."],
		["vaelor", "My oath remains."], ["alaric", "Your oath burned my village."], [1.8], ["bubble", "vaelor", "..."], [0.8], ["act", "vaelor", "attack"], ["flash"], ["fade", 1.0, 1.0]]))
	s["c12_b5_post"] = _scene("c12_b5_post", "res://samples/arc12_5.json", "#c8d8a8", 0.12, _cast(12) + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 16], "W", {"tint": "falcon"}], ["fade", 0.0, 1.4], ["beat", "start"], ["hold", "vaelor", "ko", 2], [1.2]] + _t([
		["*alaric", "Where is she?"], [1.2], ["look", "vaelor", "W"], ["fadeout", "vaelor", 1.8], [2.0],
		["@", "Vaelor fades without a word. Beyond the lawn, a hidden passage."], [1.0], ["fade", 1.0, 1.2]]), {"next": "c12_reveal"})
	s["c12_reveal"] = _scene("c12_reveal", COURT, "#d8e0f0", 0.14, [
		["spawn", "alaric", "king", [7, 3], "E"], ["spawn", "lyra", "mira", [6, 2], "E"], ["spawn", "elowen", ELOWEN_SHEET, [7, 13], "N"],
		_ff("v1", "ironhollow_sentinel", [3, 16], "W", 0.0), _ff("v2", "spectral_duelist", [11, 16], "W", 0.0), _ff("v3", "riverband_brute", [7, 19], "W", 0.0),
		["fade", 0.0, 2.2], ["beat", "start"], ["walk", "alaric", [7, 9], {"t": 0.6, "par": true}], ["walk", "lyra", [6, 8], {"t": 0.6, "par": true}], ["join"]] + _t([
		["@", "A private courtyard. A young woman stands by the fountain. She turns. She is the Princess of the royal portraits."],
		[1.0], ["look", "elowen", "W"], [1.0], ["bubble", "alaric", "!"],
		["alaric", "Elowen?"], [1.0], ["woman", "You must be Alaric."], ["alaric", "You're supposed to be dead."], [1.0], ["bubble", "elowen", "~"],
		["elowen", "I was."], ["walk", "lyra", [6, 10], {"t": 0.5}], ["lyra", "You came back?"], [0.8],
		["elowen", "So did you."], [1.4], ["bubble", "alaric", "..."],
		["@", "She knows about Lyra."], ["fadein", "v1", 0.8], ["fadein", "v2", 0.8], ["fadein", "v3", 0.8], ["shake", 0.02, 1.0], [0.8], ["look", "elowen", "E"],
		["elowen", "You shouldn't have come here."], [1.6], ["fade", 1.0, 2.0],
		["title", "CHAPTER TWELVE COMPLETE", "The Woman Who Returned", 3.6], ["unlock", "divided"]]))
	# the woman's line before her name is given is shown as WOMAN, then ELOWEN, as the owner wrote it
	s["c12_reveal"].steps = s["c12_reveal"].steps.map(func(st): return ["say", "elowen", "WOMAN", st[3]] if st is Array and st.size() == 4 and st[0] == "say" and st[1] == "woman" else st)


# ================================================================================================ CHAPTER THIRTEEN: A KINGDOM DIVIDED
static func _thirteen(s: Dictionary) -> void:
	s["c13_open"] = _scene("c13_open", COURT, "#d8e0f0", 0.14, [
		["title", "CHAPTER THIRTEEN", "A Kingdom Divided", 2.8],
		["spawn", "alaric", "king", [7, 9], "E"], ["spawn", "lyra", "mira", [6, 10], "E"], ["spawn", "elowen", ELOWEN_SHEET, [7, 13], "W"],
		_ff("v1", "ironhollow_sentinel", [3, 16]), _ff("v2", "spectral_duelist", [11, 16]), _ff("v3", "riverband_brute", [7, 19]),
		["fade", 0.0, 2.0], ["beat", "start"]] + _t([
		["@", "Alaric knows this energy. He has felt it in every Falcon Guard soldier he has faced."],
		["alaric", "Those soldiers."], ["elowen", "Yes."], ["alaric", "You're summoning them."], ["elowen", "I am."], ["alaric", "How long?"], ["elowen", "Longer than you."],
		[1.0], ["*lyra", "How did you come back?"], [1.0], ["elowen", "I wish I knew."], [1.2],
		["@", "She did not go home to her father, she says, because she no longer believed in the monarchy he stood for."],
		["*alaric", "And the Falcon Guard? My village?"], [1.0],
		["elowen", "You came here looking for a villain."], ["alaric", "I came looking for the truth."], ["elowen", "Then you're going to be disappointed."],
		[0.8], ["walk", "elowen", [7, 21], {"t": 0.5}], ["fadeout", "elowen", 0.8], ["act", "v3", "attack"], ["flash"], ["fade", 1.0, 1.0]]))
	s["c13_b1_post"] = _scene("c13_b1_post", "res://samples/arc13_1.json", "#d8e0f0", 0.12, _cast(12) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "They break out of the estate. Elowen is gone, with a few willing vessels at her side."], ["*alaric", "Her father has to know."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c13_king"})
	s["c13_king"] = _scene("c13_king", ROOM, "#2a2a40", 0.16, [
		["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "aldren", "ironhollow_sentinel", [4, 9], "E"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 1.8], ["beat", "start"], ["walk", "alaric", [6, 6], {"t": 0.6}]] + _t([
		["king_npc", "You saw her?"], ["alaric", "Yes."], ["king_npc", "You're certain?"], ["alaric", "She knew who I was. She summoned the Falcon Guard."], [1.6],
		["king_npc", "I buried her."], ["alaric", "I know."], ["king_npc", "And she's alive?"], ["alaric", "Yes."], [1.0], ["hold", "king_npc", "hit", 2], [2.4],
		["king_npc", "Where is she?"], ["*alaric", "She got away."], ["@", "The King says he must see her. Aldren warns that her bond to the Falcon Guard makes her dangerous."],
		["*aldren", "Your Majesty, she commands the soldiers who burned a village."], ["*king_npc", "She is my daughter. She would not have done that."],
		[1.4], ["fade", 1.0, 1.2]]), {"also_seen": ["c13_b1_post"]})
	s["c13_decl"] = _scene("c13_decl", TOWN, "#e8c890", 0.14, _cast(3) + [["spawn", "reave", REAVE_SHEET, [7, 15], "W"], ["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.5) + _t([
		["@", "Reave speaks to a great crowd: citizens with real grievances, former soldiers, organised volunteers. His movement will no longer recognise the King's authority."],
		["*reave", "We will not ask the crown for what is already ours. From today we answer to one another, not to a bloodline."],
		["*reave", "A new government, chosen by the people who must live under it."], [1.0], ["shake", 0.01, 0.8],
		["@", "Most of the crowd only want a fairer kingdom. But at the edges stand armed men who want a fight."], [1.0], ["fade", 1.0, 1.0]]),
		{"folk": [["villager_man", [5, 12]], ["villager_girl", [9, 12]], ["villager_kid", [8, 13]], ["mechanic", [6, 14]], ["villager_man", [10, 14]]], "next": "c13_streets_pre"})
	s["c13_streets_pre"] = _pre("c13_streets_pre", "res://samples/arc13_2.json", "#e8c890", "Armed extremists and royal soldiers clash in a residential quarter. Alaric moves to keep the fighting out of the homes.",
		[_rv("r1", "hooded_cutthroat", [5, 14]), _rv("r2", "spectral_duelist", [9, 15])])
	s["c13_streets_pre"]["also_seen"] = ["c13_decl"]
	s["c13_b2_post"] = _scene("c13_b2_post", "res://samples/arc13_2.json", "#e8c890", 0.12, _cast(12) + [
		["spawn", "soldier", "squire", [7, 17], "W"], ["spawn", "p1", "villager_man", [6, 20], "W"], ["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "The armed extremists are down. A royal soldier raises his sword over the unarmed protesters who were caught in it."],
		["walk", "alaric", [7, 15], {"t": 0.5}], ["*alaric", "Lower it. They didn't fight."], [0.8], ["look", "soldier", "S"], [1.0],
		["*alaric", "I'm not here to defend the crown. I'm here to keep people alive."], [1.2], ["fade", 1.0, 1.0]]))
	s["c13_truth"] = _scene("c13_truth", NIGHT, "#1a1a2a", 0.3, [
		["spawn", "alaric", "king", [6, 4], "E"], ["spawn", "reave", REAVE_SHEET, [6, 14], "W"], ["fade", 0.0, 1.8], ["beat", "start"], ["walk", "alaric", [6, 10], {"t": 0.6}]] + _t([
		["@", "Reave again. This time he does not pretend to be a friendly organiser."],
		["alaric", "You knew she was alive."], ["reave", "Yes."], ["alaric", "You knew she could summon the dead."], ["reave", "Yes."], ["alaric", "And the Falcon Guard?"],
		[1.2], ["reave", "You've come a long way."], ["alaric", "Answer me."], [1.4],
		["reave", "Your village was meant to turn the kingdom against its King."], [1.0], ["bubble", "alaric", "!"],
		["alaric", "You burned it."], ["reave", "I planned it."], ["alaric", "And Elowen?"], ["reave", "She agreed."], [0.8], ["act", "alaric", "attack"],
		["alaric", "You killed everyone."], ["reave", "I didn't know you existed."], ["alaric", "What?"], ["reave", "You weren't the target. Your village was."], [1.4],
		["reave", "You surviving was never part of the plan."], [1.8],
		["@", "The attack was meant to show the monarchy as cruel and set the kingdom alight."],
		["alaric", "Those people had nothing to do with your war."], ["reave", "Everyone lives beneath the crown."], ["alaric", "That's not an answer."],
		["reave", "It's the world we inherited."], ["alaric", "And you decided to burn it."], [1.6], ["bubble", "reave", "..."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c13_vanguard_pre"})
	s["c13_vanguard_pre"] = _pre("c13_vanguard_pre", "res://samples/arc13_3.json", "#c8b890", "Reave's armed followers burst in between them. In the confusion Reave is gone.",
		[_rv("r1", "spectral_duelist", [5, 14]), _rv("r2", "spectral_duelist", [9, 15])])
	s["c13_vanguard_pre"]["also_seen"] = ["c13_truth"]
	s["c13_b3_post"] = _scene("c13_b3_post", "res://samples/arc13_3.json", "#c8b890", 0.12, _cast(12) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "Alaric knows now. The people who destroyed his village were not acting for the King. They were acting for Reave and Elowen."],
		[1.0], ["bubble", "alaric", "..."], [1.6], ["fade", 1.0, 1.0]]), {"next": "c13_lyra"})
	s["c13_lyra"] = _scene("c13_lyra", HILL, "#d8a870", 0.2, [["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "lyra", "mira", [6, 11], "E"],
		["fade", 0.0, 1.8], ["beat", "start"], ["walk", "lyra", [6, 13], {"t": 0.5}]] + _t([
		["lyra", "She's like me."], ["alaric", "No."], ["lyra", "She died. She came back."], ["alaric", "That doesn't make you the same."], [1.4],
		["lyra", "I wanted to understand her."], ["alaric", "You still can."], ["lyra", "After what she did?"], [1.0], ["alaric", "Understanding isn't forgiving."],
		[1.8], ["fade", 1.0, 1.2]]), {"also_seen": ["c13_b3_post"]})
	s["c13_standard_pre"] = _pre("c13_standard_pre", "res://samples/arc13_4.json", "#d8a080", "Revolutionary extremists and Falcon Guard together try to seize a district by the river gate.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), _rv("r1", "hooded_cutthroat", [9, 15])])
	s["c13_b4_post"] = _scene("c13_b4_post", "res://samples/arc13_4.json", "#d8a080", 0.12, _cast(12) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "Among the dead banners, orders: Reave and Elowen are preparing a coordinated assault on the capital."], ["*gideon", "They mean to strike the walls."],
		["*alaric", "Then we'll be on them."], [1.0], ["fade", 1.0, 1.0]]))
	s["c13_uprising_pre"] = _pre("c13_uprising_pre", "res://samples/arc13_5.json", "#c8b0a0", "The capital's outer defenses. A great revolutionary force comes on; Alaric's company stands with the royal defenders.",
		[_rv("r1", "ironhollow_sentinel", [5, 14]), _ff("f1", "ironhollow_sentinel", [9, 15])], ["aldren"])
	s["c13_b5_post"] = _scene("c13_b5_post", "res://samples/arc13_5.json", "#c8b0a0", 0.12, _cast(12, null, ["aldren"]) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "The assault is thrown back. But the kingdom is openly divided now."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c13_final"})
	s["c13_final"] = _scene("c13_final", ROOM, "#2a2a40", 0.18, [["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 1.8], ["beat", "start"], ["walk", "alaric", [6, 6], {"t": 0.6}]] + _t([
		["alaric", "She helped destroy my village."], [1.6], ["king_npc", "No."], ["alaric", "She summoned the soldiers."], ["king_npc", "No."],
		["alaric", "Reave planned it. She agreed."], [1.6], ["look", "king_npc", "E"], ["@", "The King looks at his daughter's portrait."],
		["king_npc", "I need to hear it from her."], [1.0], ["alaric", "Then we'll find her."], [1.6], ["fade", 1.0, 2.0],
		["title", "CHAPTER THIRTEEN COMPLETE", "A Kingdom Divided", 3.6], ["unlock", "lovers"]]), {"also_seen": ["c13_b5_post"]})


# ================================================================================================ CHAPTER FOURTEEN: THE LOVERS' WAR
static func _fourteen(s: Dictionary) -> void:
	s["c14_open"] = _scene("c14_open", ROOM, "#2a2a40", 0.18, [
		["title", "CHAPTER FOURTEEN", "The Lovers' War", 2.8], ["spawn", "king_npc", KING_SHEET, [6, 9], "W"], ["spawn", "alaric", "king", [6, 5], "E"],
		["fade", 0.0, 2.0], ["beat", "start"]] + _t([
		["@", "The kingdom is at war with itself. Some towns stand with Reave, some with the King, and most only want the fighting to stop. The King's forces are stretched."],
		["@", "Alaric's company has become a power of its own. Not to keep a crown on a head at any cost: to stop the deliberate killing of innocent people."],
		["*king_npc", "I will offer them terms. Before more of my people die."], ["*alaric", "Then we'll get you to the table."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c14_crossing_pre"})
	s["c14_crossing_pre"] = _pre("c14_crossing_pre", "res://samples/arc14_1.json", "#d8c8a0", "On the road to a neutral meeting place, extremists lie in wait in a broken bridge town to wreck the talks.",
		[_rv("r1", "hooded_cutthroat", [5, 14]), _ff("f1", "squire", [9, 15])])
	s["c14_crossing_pre"]["also_seen"] = ["c14_open"]
	s["c14_b1_post"] = _scene("c14_b1_post", "res://samples/arc14_1.json", "#d8c8a0", 0.12, _cast(12) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["*gideon", "They didn't want this meeting to happen."], ["*alaric", "Then it happens."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c14_chapel"})
	s["c14_chapel"] = _scene("c14_chapel", CHAPEL, "#c8b898", 0.16, [
		["spawn", "king_npc", KING_SHEET, [7, 3], "E"], ["spawn", "alaric", "king", [8, 2], "E"], ["spawn", "lyra", "mira", [6, 2], "E"], ["spawn", "aldren", "ironhollow_sentinel", [9, 2], "E"],
		["spawn", "elowen", ELOWEN_SHEET, [7, 16], "W"], ["spawn", "reave", REAVE_SHEET, [8, 16], "W"],
		["fade", 0.0, 2.0], ["beat", "start"], ["walk", "king_npc", [7, 9], {"t": 0.7}], [1.2]] + _t([
		["king_npc", "Elowen?"], ["elowen", "Hello, Father."], ["walk", "king_npc", [7, 12], {"t": 0.9}],
		["king_npc", "I buried you."], ["elowen", "I know."], ["king_npc", "I came to your grave every week."], ["elowen", "I know, Father."],
		["king_npc", "Then why didn't you come home?"], [2.0], ["bubble", "elowen", "..."],
		["elowen", "Because I couldn't return to the life I left."], ["king_npc", "You were my daughter."], ["elowen", "I still am."], ["king_npc", "Then why?"], [1.0],
		["@", "She tells him the monarchy is unjust, and that he let the kingdom rot while he grieved."],
		["king_npc", "I failed my people."], ["elowen", "Yes."], ["king_npc", "But I never stopped loving you."], [1.4], ["elowen", "I know."], [1.2],
		["*king_npc", "The village. Were you part of it?"], [1.0], ["*elowen", "Yes."],
		["king_npc", "Those people were innocent."], ["elowen", "They were."], ["king_npc", "And you killed them?"],
		["elowen", "I gave the soldiers their form. I knew what they were sent to do."], [2.0], ["hold", "king_npc", "hit", 2],
		["king_npc", "I spent years mourning you."], ["elowen", "I never asked you to."], ["king_npc", "You were my child."], ["look", "elowen", "E"], [1.6],
		["reave", "Your Majesty, your kingdom is collapsing."], ["king_npc", "And you have helped tear it apart."], ["reave", "Because it needed to change."],
		["alaric", "You could have changed it without burning my village."], ["look", "reave", "S"], ["reave", "Perhaps."], ["alaric", "Perhaps?"],
		["reave", "I won't pretend I can undo what happened."], ["alaric", "You don't even regret it."], ["reave", "I regret the suffering. I don't regret the cause."],
		["alaric", "Then you haven't learned anything."], [1.4],
		["@", "The talks fail. Reave and Elowen will not surrender. They leave together with their followers."],
		["walk", "elowen", [7, 21], {"t": 0.5, "par": true}], ["walk", "reave", [8, 21], {"t": 0.5, "par": true}], ["join"], [1.0], ["fade", 1.0, 1.2]]), {"also_seen": ["c14_b1_post"]})
	s["c14_guard_pre"] = _pre("c14_guard_pre", "res://samples/arc14_2.json", "#c8b898", "Falcon Guard soldiers stay behind in the chapel yard to stop any pursuit.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), _ff("f2", "hollowmark_assassin", [9, 15])], ["king"])
	s["c14_b2_post"] = _scene("c14_b2_post", "res://samples/arc14_2.json", "#c8b898", 0.12, _cast(12, null, ["king"]) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["walk", "alaric", [7, 13], {"t": 0.4}], ["look", "alaric", "W"], ["*alaric", "You can go back to the capital. No one would blame you."], [1.0],
		["king_npc", "I spent years looking for my daughter."], [1.4], ["king_npc", "I will not look away from what she's become."], [1.4], ["fade", 1.0, 1.0]]))
	s["c14_cassian"] = _scene("c14_cassian", "res://samples/arc14_3.json", "#c8c8b0", 0.14, _cast(2, "@king") + [
		["spawn", "cassian", CASSIAN_SHEET, [7, 12], "W", {"tint": "vessel", "alpha": 0.0}], ["fade", 0.0, 1.6], ["beat", "start"]] + _march(7, 0.5) + _t([
		["@", "Word comes that Cassian Vale has left the academy. He has heard of the war and of the army of summoned soldiers."],
		["fadein", "cassian", 1.0], ["walk", "cassian", [7, 10], {"t": 0.5}], ["look", "cassian", "W"],
		["cassian", "You've made quite a mess."], ["alaric", "Good to see you too."], ["cassian", "I told you to return when you had an army."], ["alaric", "I never did."],
		["cassian", "No. You found something more difficult."], ["alaric", "What's that?"], ["cassian", "People willing to follow you without being ordered."], [1.2],
		["@", "Cassian will help Alaric prepare for what is coming. He remains a vessel; he joins the company."], ["give_cassian"],
		["look", "cassian", "E"], ["shake", 0.02, 0.8], ["flash"], ["fade", 1.0, 1.0]]))
	s["c14_b3_post"] = _scene("c14_b3_post", "res://samples/arc14_3.json", "#c8c8b0", 0.12, _cast(12, null, ["cassian"]) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["look", "cassian", "W"], ["cassian", "You still take unnecessary risks."], ["alaric", "I know."], ["cassian", "But now you know why."],
		["alaric", "Is that a compliment?"], ["cassian", "Don't become accustomed to them."], [1.2], ["fade", 1.0, 1.0]]), {"next": "c14_lovers"})
	s["c14_lovers"] = _scene("c14_lovers", NIGHT, "#0a0a1c", 0.32, [["spawn", "elowen", ELOWEN_SHEET, [6, 12], "N"], ["spawn", "reave", REAVE_SHEET, [6, 6], "E"],
		["fade", 0.0, 2.2], ["beat", "start"], [1.4], ["walk", "reave", [6, 10], {"t": 0.6}]] + _t([
		["reave", "You don't have to pretend with me."], [1.0], ["elowen", "He looked so old."], ["reave", "He's been grieving."], ["elowen", "I know."],
		["walk", "reave", [6, 11], {"t": 0.4}], ["look", "elowen", "W"], [1.0], ["reave", "Do you want to stop?"], [2.0], ["elowen", "No."],
		["reave", "Then we finish what we started."], [1.0], ["elowen", "Together."], ["reave", "Together."], [2.0], ["fade", 1.0, 1.8]]), {"also_seen": ["c14_b3_post"]})
	s["c14_banner_pre"] = _pre("c14_banner_pre", "res://samples/arc14_4.json", "#c8b0a0", "A major Falcon Guard staging position in an old earthwork. The company goes in.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), _ff("f2", "riverband_brute", [9, 15])], ["cassian"])
	s["c14_b4_post"] = _scene("c14_b4_post", "res://samples/arc14_4.json", "#c8b0a0", 0.12, _cast(12, null, ["cassian"]) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "Reave and Elowen are gathering everything they have at an ancient royal fortress called Hollowmark."],
		["@", "It stands where the boundary between this world and the Vessel World runs thin. Summoning is easier there. It still costs energy, it still has a range, and the dead still choose."],
		["*seraphine", "Hollowmark. Of course she would go there."], [1.0], ["fade", 1.0, 1.0]]))
	s["c14_march_pre"] = _pre("c14_march_pre", "res://samples/arc14_5.json", "#a8a8c0", "The last pass before Hollowmark, held by Falcon Guard and revolutionaries together.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), _rv("r1", "spectral_duelist", [9, 15])], ["cassian"])
	s["c14_b5_post"] = _scene("c14_b5_post", "res://samples/arc14_5.json", "#a8a8c0", 0.12, _cast(12, null, ["cassian"]) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "The road to Hollowmark is open."], [1.0], ["fade", 1.0, 1.0]]), {"next": "c14_final"})
	s["c14_final"] = _scene("c14_final", HILL, "#a890a0", 0.22, [["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "king_npc", KING_SHEET, [6, 11], "E"],
		["fade", 0.0, 1.8], ["beat", "start"], ["walk", "king_npc", [6, 13], {"t": 0.5}]] + _t([
		["king_npc", "When we reach her, I want to speak with her once more."], ["alaric", "I know."], ["king_npc", "And if she refuses to surrender?"],
		[1.4], ["alaric", "Then we stop her."], [1.0], ["look", "king_npc", "E"], ["king_npc", "I understand."], [1.6], ["fade", 1.0, 2.0],
		["title", "CHAPTER FOURTEEN COMPLETE", "The Lovers' War", 3.6], ["unlock", "hollowmark"]]), {"also_seen": ["c14_b5_post"]})


# ================================================================================================ CHAPTER FIFTEEN: HOLLOWMARK
static func _fifteen(s: Dictionary) -> void:
	var c := ["cassian", "king", "aldren"]
	s["c15_open"] = _scene("c15_open", "res://samples/arc15_1.json", "#b0b0d0", 0.18, [["title", "CHAPTER FIFTEEN", "Hollowmark", 2.8]] + _cast(2, "@king", c) + [
		["fade", 0.0, 2.0], ["beat", "start"]] + _march(7, 0.55) + _t([
		["@", "Hollowmark. An ancient royal stronghold where the Vessel World presses close. The King and Aldren have come with a small loyal force."],
		["look", "gideon", "E"], ["gideon", "They chose their ground well."], ["kaelen", "Naturally."], ["bram", "You sound pleased."],
		["kaelen", "I'm trying to appreciate the craftsmanship before someone hits me."], [1.0], ["look", "alaric", "E"], ["walk", "lyra", [6, 8], {"t": 0.4}],
		["lyra", "You know what you want to do?"], ["alaric", "Stop them."], ["lyra", "And after?"], [1.4], ["alaric", "Build something better."],
		[1.0], ["flash"], ["fade", 1.0, 1.0]]))
	s["c15_b1_post"] = _scene("c15_b1_post", "res://samples/arc15_1.json", "#b0b0d0", 0.12, _cast(12, null, c) + [
		_rv("r1", "ironhollow_sentinel", [7, 17], "N"), ["fade", 0.0, 1.4], ["beat", "start"], ["hold", "r1", "hit", 2]] + _t([
		["*alaric", "Put down your weapons and walk away. No one else needs to die today."], [1.0], ["bubble", "r1", "..."],
		["@", "Some of the defenders lay their weapons down."], [1.0], ["fade", 1.0, 1.0]]))
	s["c15_vaelor_pre"] = _scene("c15_vaelor_pre", "res://samples/arc15_2.json", "#a8a8c8", 0.16, _cast(2, "@king", ["cassian"]) + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 22], "W", {"tint": "falcon"}], _ff("h1", "ironhollow_sentinel", [5, 18]), _ff("h2", "ironhollow_sentinel", [10, 18]),
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + _t([["look", "vaelor", "S"],
		["vaelor", "My oath remains."], ["alaric", "And the people you killed?"], [1.6], ["alaric", "Does your oath answer for them?"], [1.0],
		["act", "vaelor", "attack"], ["vaelor", "No."], [1.4], ["vaelor", "I must."], ["flash"], ["fade", 1.0, 1.0]]))
	s["c15_b2_post"] = _scene("c15_b2_post", "res://samples/arc15_2.json", "#a8a8c8", 0.12, _cast(12, null, ["cassian"]) + [
		["spawn", "vaelor", VAELOR_SHEET, [7, 16], "W", {"tint": "falcon"}], ["fade", 0.0, 1.4], ["beat", "start"], ["hold", "vaelor", "ko", 2], [1.4]] + _t([
		["vaelor", "I called it duty."], ["alaric", "It was a choice."], [1.4], ["vaelor", "Yes."], [1.6],
		["@", "Vaelor lays down his sword of his own will and returns to the Vessel World. What becomes of him there, no one can say."],
		["fadeout", "vaelor", 2.0], [2.2], ["fade", 1.0, 1.2]]))
	s["c15_heart_pre"] = _pre("c15_heart_pre", "res://samples/arc15_3.json", "#c8a890", "The central fortress. Reave's most devoted fighters hold the barracks and armories.",
		[_rv("r1", "spectral_duelist", [5, 14]), _rv("r2", "riverband_brute", [9, 15])], ["cassian"])
	s["c15_b3_post"] = _scene("c15_b3_post", "res://samples/arc15_3.json", "#c8a890", 0.12, _cast(12, null, ["cassian"]) + [
		_rv("officer", "riverband_brute", [7, 16], "W"), ["fade", 0.0, 1.4], ["beat", "start"], ["hold", "officer", "hit", 2], ["walk", "alaric", [7, 14], {"t": 0.5}]] + _t([
		["@", "A wounded officer: many of them believed they were fighting for a fairer kingdom. Alaric does not tell him the grievances were false. They were not."],
		["alaric", "You wanted a better kingdom."], ["officer", "We still do."], ["alaric", "Then stop burning the people who have to live in it."], [1.6], ["fade", 1.0, 1.0]]))
	s["c15_army_pre"] = _pre("c15_army_pre", "res://samples/arc15_4.json", "#a8a8d0", "The ceremonial halls. Elowen's strongest vessels stand between the company and the central chamber.",
		[_ff("f1", "ironhollow_sentinel", [5, 14]), _ff("f2", "riverband_brute", [9, 15])], ["cassian"])
	s["c15_b4_post"] = _scene("c15_b4_post", "res://samples/arc15_4.json", "#a8a8d0", 0.12, _cast(12, null, ["cassian"]) + [["fade", 0.0, 1.4], ["beat", "start"]] + _t([
		["@", "Her army is broken. Somewhere ahead, Elowen feels it. Sustaining so many has exhausted her, but she can still fight."], [1.0], ["fade", 1.0, 1.0]]))
	s["c15_confront"] = _scene("c15_confront", "res://samples/arc15_5.json", "#d8d0f0", 0.18, _cast(2, "@king", c) + [
		["spawn", "reave", REAVE_SHEET, [7, 17], "W"], ["spawn", "elowen", ELOWEN_SHEET, [8, 17], "W"], ["fade", 0.0, 2.0], ["beat", "start"]] + _march(8, 0.6) + _t([
		["walk", "king_npc", [6, 10], {"t": 0.6}],
		["king_npc", "Elowen."], ["elowen", "Father."], ["king_npc", "Please. This can still end."], ["reave", "It will."], ["alaric", "Not the way you planned."],
		[1.0], ["reave", "You really are remarkable."], ["alaric", "You never knew I existed."], ["reave", "No."], ["alaric", "My village was just a tool."],
		["reave", "It was meant to change the kingdom."], ["alaric", "You killed people who had nothing to do with your cause."], ["reave", "I know."],
		["alaric", "And you'd do it again?"], [1.6], ["reave", "If I believed it was necessary."], [1.0], ["look", "alaric", "E"],
		["alaric", "And you?"], ["elowen", "I made my choice."], ["alaric", "You knew what those soldiers would do."], ["elowen", "Yes."],
		["alaric", "Then you're responsible."], ["elowen", "I know."], [1.4],
		["king_npc", "I failed you."], ["king_npc", "I failed this kingdom."], [1.4], ["king_npc", "But you chose to kill innocent people."], ["elowen", "I did."],
		["king_npc", "I cannot defend that."], [1.0], ["act", "reave", "attack"], ["fx", "elowen", "circle", 1.2],
		["reave", "Then there's nothing left to discuss."], ["alaric", "There is."], [1.0], ["alaric", "You can surrender."], [1.4],
		["look", "elowen", "E"], ["look", "reave", "W"], [1.0], ["elowen", "Together?"], ["reave", "Always."], [0.8], ["look", "reave", "S"], ["look", "elowen", "S"],
		["flash"], ["shake", 0.03, 1.4], ["fade", 1.0, 1.0]]))
	# ------------------------------------------------------------------------------------------ the ending
	s["c15_b5_post"] = _scene("c15_b5_post", "res://samples/arc15_5.json", "#d8d0f0", 0.14, _cast(11, null, c) + [
		["spawn", "reave", REAVE_SHEET, [7, 15], "W"], ["spawn", "elowen", ELOWEN_SHEET, [8, 15], "W"], ["fade", 0.0, 1.6], ["beat", "start"],
		["hold", "reave", "ko", 2], [1.2], ["hold", "elowen", "hit", 2]] + _t([
		["@", "Reave is hurt. Elowen kneels beside him. He reaches for her hand."],
		["reave", "Well."], ["elowen", "Don't."], ["reave", "I was going to say we came rather close."], [0.8], ["bubble", "elowen", "~"], ["elowen", "You always say that."],
		[1.0], ["walk", "alaric", [7, 13], {"t": 0.5}], ["reave", "What happens now?"], ["alaric", "You answer for what you've done."], ["reave", "And our cause?"],
		["alaric", "That isn't mine to decide."], [1.0], ["reave", "You'd leave the future to the people?"], ["alaric", "Shouldn't that be what you wanted?"], [2.2], ["bubble", "reave", "..."],
		["@", "Reave and Elowen are taken into custody, together. What they will answer for is for the kingdom's new courts to decide, not for one man's vengeance."],
		[1.0], ["fade", 1.0, 1.2]]), {"next": "c15_father"})
	s["c15_father"] = _scene("c15_father", "res://samples/arc15_5.json", "#d8d0f0", 0.14, [["spawn", "king_npc", KING_SHEET, [7, 11], "E"], ["spawn", "elowen", ELOWEN_SHEET, [7, 14], "W"],
		["spawn", "aldren", "ironhollow_sentinel", [9, 15], "W"], ["fade", 0.0, 1.6], ["beat", "start"], [1.0], ["walk", "king_npc", [7, 12], {"t": 0.7}]] + _t([
		["king_npc", "I thought I had lost you forever."], ["elowen", "I know."], ["king_npc", "And now I don't know how to speak to you."], [1.0], ["elowen", "Neither do I."],
		[1.8], ["king_npc", "I love you."], [1.4], ["elowen", "I love you too, Father."], [1.0], ["king_npc", "That doesn't change what you've done."], ["elowen", "I know."],
		[2.4], ["@", "They do not embrace. Not yet."], [1.6], ["fade", 1.0, 1.6]]), {"next": "c15_kingdom"})
	s["c15_kingdom"] = _scene("c15_kingdom", STREET, "#e8c890", 0.14, [["spawn", "king_npc", KING_SHEET, [7, 12], "W"], ["spawn", "aldren", "ironhollow_sentinel", [5, 12], "W"],
		["fade", 0.0, 1.8], ["beat", "start"]] + _t([
		["@", "Before his people, the King admits that his grief made him neglect them."],  # DRAFT: the owner's staging of the speech
		["*king_npc", "I left you to suffer while I mourned. That was my failure, and I will not hide it."],
		["*king_npc", "This kingdom must change. Not tomorrow, all at once; but it must begin now."],
		["@", "A council elected by the kingdom's regions. Limits on royal authority. Independent inquiries into abuses by royal officials. More say for the towns over their own welfare. A formal review of the crimes of the uprising."],
		["@", "It is a beginning, and a hard one. What the government becomes will be for the people to decide. The King stays to see the change through, and governs."],
		[1.4], ["fade", 1.0, 1.4]]), {"folk": [["villager_man", [5, 16]], ["villager_girl", [9, 17]], ["villager_kid", [7, 19]], ["mechanic", [6, 21]]], "next": "c15_village"})
	s["c15_village"] = _scene("c15_village", RUINS, "#d8c8a0", 0.16, [["spawn", "alaric", "king", [7, 8], "E"], ["spawn", "lyra", "mira", [6, 5], "E"],
		["fade", 0.0, 2.4], ["beat", "start"], ["walk", "alaric", [7, 12], {"t": 0.8}], [1.6]] + _t([
		["@", "The ruins of Alaric's village. In his hand, the small wooden knight the girl in Bellwether gave him."],
		["walk", "lyra", [6, 11], {"t": 0.6}], ["look", "lyra", "E"],
		["lyra", "What are you thinking?"], ["alaric", "About the people who lived here."], ["lyra", "You found who killed them."], ["alaric", "Yes."],
		["lyra", "Was it enough?"], [1.6], ["alaric", "No."], [1.4], ["alaric", "It doesn't bring them back."], [1.0], ["look", "alaric", "E"],
		["alaric", "But I can make sure this place isn't forgotten."], [1.0], ["lyra", "What will you do?"], [1.4], ["hold", "alaric", "hit", 2],
		["@", "He kneels, and sets the wooden knight on an old stone foundation."], [1.0], ["alaric", "Build."], [2.4], ["fade", 1.0, 2.0]]), {"next": "c15_epilogues"})
	s["c15_epilogues"] = _scene("c15_epilogues", RUINS, "#d8c8a0", 0.16, _cast(10, null, ["cassian"]) + [["fade", 0.0, 2.0], ["beat", "start"]] + _t([
		["@", "Lyra lives. She chooses her own road, day by day. What brought her back is still a mystery; she has decided not to wait for an answer."],
		["@", "Bram stays at Alaric's side, as dry as ever. He will not say he is proud. He does not need to."],
		["@", "Merc travels on, helping the broken towns rebuild, cheerfully, one roof at a time."],
		["@", "Gideon trains defenders for the villages that have none, and leads without repeating the mistakes of his first life."],
		["@", "Kaelen keeps wandering the kingdom, sarcastic to the last word, and always comes back to the company."],
		["@", "Seraphine helps the towns honour their dead without holding a single spirit against its will."],
		["@", "Cassian Vale admits, once, that Alaric became the leader he doubted. He does not admit it twice."],
		[1.4], ["fade", 1.0, 1.6]]), {"next": "c15_first_stone"})
	s["c15_first_stone"] = _scene("c15_first_stone", RUINS, "#e8d8a8", 0.12, _cast(10, null, ["cassian"]) + [["fade", 0.0, 2.4], ["beat", "start"]] + _t([
		["@", "No armies. No banners. No speeches. Only people working together."],
		["walk", "lyra", [6, 11], {"t": 0.5}], ["@", "Lyra hands Alaric a piece of timber."],
		["*bram", "My back was not built for this. It was built for hitting things."], ["*kaelen", "Then hit the nail, Bram. It's a start."],
		["walk", "gideon", [9, 13], {"t": 0.5}], ["*gideon", "Frame first. Then walls. Merc, the supplies, there."], ["walk", "merc", [5, 13], {"t": 0.5}],
		["look", "seraphine", "N"], [1.4], ["look", "alaric", "N"], [1.6],
		["@", "Alaric looks at the foundation of a new home. For the first time since the fire, he smiles, and means it."], [2.4],
		["fade", 1.0, 2.4], ["title", "HOLLOWMARK TACTICS", "", 4.0], [1.0], ["title", "THE END", "", 4.0], [1.4],
		# the final credits: there is no credits screen in the project, so they roll as title cards (names are the cast; the makers' names are the owner's to fill in)
		["title", "CREDITS", "", 2.4], ["title", "Alaric", "the summoner", 2.0], ["title", "Lyra", "who came back", 2.0], ["title", "Bram  ·  Merc  ·  Gideon", "", 2.0],
		["title", "Kaelen  ·  Seraphine  ·  Cassian Vale", "", 2.0], ["title", "The King  ·  Captain Aldren", "", 2.0], ["title", "Reave  ·  Elowen  ·  Commander Vaelor", "", 2.2],
		["title", "Hollowmark Tactics", "made with Godot", 3.0], ["title", "Thank you for playing", "", 3.6]]))
