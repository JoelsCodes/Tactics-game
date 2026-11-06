class_name FinaleStory
extends RefCounted
## Chapter nine, "The Last King": the scenes StoryScene plays. The owner's dialogue is word for word; every line, caption or beat I wrote to join it is marked DRAFT.
## STORY CANON (godot/STORY_CANON.md): the King is innocent, grieving and not a villain; he did not order the massacre and knows nothing of the plot; he believes Elowen is dead.
## Nothing here names Reave, says Elowen is alive, shows her summoning, or says who burned the village. The post-credits pair is never named and only shown as shadows.
## ART GAPS (see godot/HANDOFF.md): the King has no sprite of his own (the Lancer sheet stands in), Aldren, the official, the attendant and the royal soldiers are stand-ins, the
## portrait on the King's table is not drawn (narrated), there is no music, and no credits roll exists (the end cards are title cards).
##   fn_throne -> (Battle 1)        the empty throne room, the official, the defenders move
##   fn_b1_post                     "Let them."
##   fn_aldren -> (Battle 2)        Aldren's last negotiation; he steps aside and does not fight
##   fn_b2_post                     the Shield's commander is allowed to stand
##   fn_ancestors -> (Battle 3)     the portrait, Lyra, the wards wake
##   fn_b3_post -> fn_chambers      "Old magic."; the King's modest rooms, the portrait, "She died."
##   fn_crown_pre -> (Battle 4)     the Crown's Guard commander
##   fn_b4_post                     "Then ask him why." The doors open.
##   fn_confront -> (Battle 5)      the King and Alaric speak; swords are drawn
##   fn_b5_post -> fn_grave -> fn_alliance -> fn_end_a..d -> fn_postcredits    the choice not to kill, the grave, the alliance, the false ending, the teaser

const THRONE := "res://samples/palace_throne.json"
const GARDEN := "res://samples/palace_garden.json"
const HILL := "res://samples/palace_hill.json"
const P1 := "res://samples/palace_1.json"
const P2 := "res://samples/palace_2.json"
const P3 := "res://samples/palace_3.json"
const P4 := "res://samples/palace_4.json"
const P5 := "res://samples/palace_5.json"
const CHAMBER := "res://samples/palace.json"
const STREET := "res://samples/crown_street.json"
const CROWN_HILL := "res://samples/crown_hill.json"

const KING_SHEET := "lancer"  ## stand-in: the King has no sheet of his own

const KING_YIELD := "Enough. ...Hear me."  # DRAFT, said as the King yields (BattleSetup.flee_line)
const KING_RESOLVE := "I will not fall until you hear me."  # DRAFT, the second phase: resolve, not corruption


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["squire", "Gideon", "They hold the stairs. Take the columns first."], ["sorc", "Seraphine", "Their mages ward the line. Break the ward, then the knights."],
		["sorc", "Seraphine", "These aren't souls. Wards and stone. Do not hold back."], ["mira", "Lyra", "The best they have. Stay together."], ["warden", "Bram", "Whatever he is, he's earned that sword."]][n]


static func king_yield() -> Array:
	return [KING_SHEET, "The King", KING_YIELD]


static func king_resolve() -> Array:
	return [KING_SHEET, "The King", KING_RESOLVE]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


## The whole company, spawned on a line at depth `y` ("@king" puts Alaric on the battle's start cell).
static func _cast(y: int, alaric_at = null) -> Array:
	return [["spawn", "alaric", "king", alaric_at if alaric_at != null else [7, y], "E"], ["spawn", "bram", "warden", [8, y - 1], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, y - 1], "E"],
		["spawn", "merc", "merc", [5, y], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [9, y], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, y - 1], "E", {"tint": "vessel"}],
		["spawn", "seraphine", "sorc", [7, y + 1], "E", {"tint": "vessel"}]]


## The company walks on to depth `y` together.
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
	# ---------------------------------------------------------------------------------------------- the empty throne
	s["fn_throne"] = _scene("fn_throne", THRONE, "#e8e0d0", 0.14, [
		["title", "CHAPTER NINE", "The Last King", 2.8]] + _cast(2) + [
		["spawn", "official", "villager_man", [2, 20], "W", {"alpha": 0.0}],  # stand-in: the royal official has no sheet
		["spawn", "g1", "squire", [4, 8], "E", {"alpha": 0.0}], ["spawn", "g2", "squire", [10, 8], "E", {"alpha": 0.0}], ["spawn", "g3", "riverband_brute", [7, 10], "E", {"alpha": 0.0}],
		["fade", 0.0, 2.2], ["beat", "start"]] + _march(8, 0.6) + [
		["wait", 1.4], ["beat", "empty"],
		["say", "bram", "BRAM", "Well. That's disappointing."],
		["say", "kaelen", "KAELEN", "Perhaps he's gone out for a walk."],
		["look", "gideon", "N"],
		["say", "gideon", "GIDEON", "Something's wrong."],
		["say", "lyra", "LYRA", "Alaric?"],
		["walk", "alaric", [7, 15], {"t": 0.7}], ["wait", 1.2],
		["fadein", "official", 0.8], ["walk", "official", [5, 17], {"t": 0.5}], ["look", "alaric", "W"], ["beat", "official"],
		["say", "official", "OFFICIAL", "His Majesty has been informed of your arrival."],
		["say", "alaric", "ALARIC", "Where is he?"],
		["say", "official", "OFFICIAL", "In the inner royal chambers."],
		["say", "alaric", "ALARIC", "Then take me to him."],
		["say", "official", "OFFICIAL", "You must dismiss your armed companions first."],
		["say", "alaric", "ALARIC", "No."],
		["say", "official", "OFFICIAL", "His Majesty wishes to speak with you."],
		["say", "alaric", "ALARIC", "Then he can speak with all of us."],
		["wait", 1.0], ["look", "official", "N"],
		["narrate", "The official will not admit an armed company to the King's private rooms. He is not afraid. He is only loyal.", 3.2],  # DRAFT: the owner's note that the guards act from loyalty and concern, not cruelty
		["fadein", "g1", 0.5], ["fadein", "g2", 0.5], ["fadein", "g3", 0.5], ["shake", 0.02, 0.8], ["wait", 0.8], ["beat", "defenders"],
		["flash"], ["fade", 1.0, 1.0],
	])
	s["fn_b1_post"] = _scene("fn_b1_post", P1, "#e8e0d0", 0.1, _cast(11) + [
		["spawn", "d1", "squire", [5, 17], "N"], ["spawn", "d2", "squire", [9, 18], "N"], ["spawn", "d3", "riverband_brute", [7, 20], "N"],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "d1", "hit", 2], ["hold", "d2", "ko", 2], ["hold", "d3", "hit", 2], ["wait", 0.8],
		["walk", "d1", [5, 24], {"t": 0.4, "par": true}], ["walk", "d3", [7, 25], {"t": 0.4, "par": true}], ["join"],  # DRAFT: they retreat, they are not pursued
		["look", "gideon", "E"],
		["say", "gideon", "GIDEON", "They're withdrawing."],
		["say", "alaric", "ALARIC", "Let them."],
		["say", "bram", "BRAM", "You're getting soft."],
		["say", "alaric", "ALARIC", "You complained when I wasn't."],
		["say", "bram", "BRAM", "And I'll complain again tomorrow."],
		["wait", 1.0], ["beat", "deeper"],
	] + _march(16, 0.5) + [["fade", 1.0, 1.2]])
	# ---------------------------------------------------------------------------------------------- Aldren's last negotiation
	s["fn_aldren"] = _scene("fn_aldren", P2, "#e8e0d0", 0.12, _cast(2, "@king") + [
		["spawn", "aldren", "ironhollow_sentinel", [7, 14], "W"],  # stand-in
		["spawn", "cmd", "riverband_brute", [7, 20], "W"], ["spawn", "s1", "ironhollow_sentinel", [5, 19], "W"], ["spawn", "s2", "ironhollow_sentinel", [9, 19], "W"],
		["fade", 0.0, 1.6], ["beat", "start"]] + _march(8, 0.5) + [
		["hold", "aldren", "hit", 2], ["wait", 1.2], ["beat", "aldren"],
		["say", "aldren", "ALDREN", "Alaric."],
		["say", "alaric", "ALARIC", "Captain."],
		["say", "aldren", "ALDREN", "You don't have to do this."],
		["say", "alaric", "ALARIC", "I've come too far to leave."],
		["say", "aldren", "ALDREN", "His Majesty has ordered us not to kill you."],
		["say", "alaric", "ALARIC", "I've noticed."],
		["say", "aldren", "ALDREN", "Then why won't you listen?"],
		["say", "alaric", "ALARIC", "Because he has answers I need."],
		["say", "aldren", "ALDREN", "Then speak with him. Alone."],
		["say", "alaric", "ALARIC", "I'm not abandoning my companions."],
		["wait", 1.4], ["bubble", "aldren", "..."],
		["walk", "aldren", [5, 12], {"t": 0.6}], ["look", "aldren", "S"], ["beat", "steps_aside"],
		["wait", 0.8], ["look", "cmd", "S"],
		["narrate", "Aldren steps aside. He will not raise his sword again. The King's own guard will not move.", 3.2],  # DRAFT: Aldren does not fight
		["flash"], ["fade", 1.0, 1.0],
	])
	s["fn_b2_post"] = _scene("fn_b2_post", P2, "#e8e0d0", 0.1, _cast(11) + [
		["spawn", "cmd", "riverband_brute", [7, 15], "W"], ["spawn", "s1", "ironhollow_sentinel", [5, 17], "N"], ["spawn", "s2", "ironhollow_sentinel", [9, 18], "N"],
		["spawn", "aldren", "ironhollow_sentinel", [3, 19], "S"],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "cmd", "hit", 2], ["hold", "s1", "ko", 2], ["hold", "s2", "hit", 2], ["wait", 1.0], ["beat", "commander"],
		["say", "cmd", "COMMANDER", "I swore an oath to protect him."],
		["say", "alaric", "ALARIC", "And you've kept it."],
		["say", "cmd", "COMMANDER", "Then let me stand."],
		["wait", 1.0], ["walk", "cmd", [7, 19], {"t": 0.6}], ["look", "cmd", "S"], ["beat", "allowed"],
		["walk", "s2", [9, 21], {"t": 0.5}], ["wait", 0.8],
		["look", "aldren", "W"], ["wait", 1.0], ["bubble", "aldren", "~"],
		["narrate", "Aldren watches in silence. This is not the killer he feared.", 3.0],  # DRAFT: the owner's note that Aldren begins to understand
		["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- the Hall of Ancestors
	s["fn_ancestors"] = _scene("fn_ancestors", P3, "#c8d0e8", 0.16, _cast(2, "@king") + [
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(10, 0.6) + [
		["wait", 0.8],
		["narrate", "A long ceremonial hall. Statues of the kings who came before. Portraits and plaques that record centuries of royal history.", 3.4],  # DRAFT: the owner's description of the hall
		["look", "alaric", "N"], ["wait", 0.8],
		["narrate", "One portrait shows a younger King beside his wife and his daughter.", 3.0],
		["look", "lyra", "N"], ["wait", 0.6],
		["say", "lyra", "LYRA", "He had a family."],
		["say", "alaric", "ALARIC", "Most people do."],
		["say", "lyra", "LYRA", "I know."],
		["wait", 1.0], ["bubble", "alaric", "..."],
		["say", "alaric", "ALARIC", "Sorry."],
		["wait", 0.6], ["bubble", "lyra", "~"], ["wait", 1.0],
		["walk", "seraphine", [10, 13], {"t": 0.5}], ["look", "seraphine", "N"], ["fx", "seraphine", "circle", 1.0], ["beat", "wards"],
		["say", "seraphine", "SERAPHINE", "These walls are warded. Old wards, laid by hand."],  # DRAFT: Seraphine recognises the hall's spiritual wards
		["wait", 1.0], ["shake", 0.03, 1.4], ["bubble", "kaelen", "!"],
		["narrate", "The palace's old guardians wake. They are constructs and ward-bound protectors, stone and enchanted armor. No soul is held inside them.", 3.6],  # DRAFT: the owner's distinction, said plainly
		["flash"], ["fade", 1.0, 1.0],
	])
	s["fn_b3_post"] = _scene("fn_b3_post", P3, "#c8d0e8", 0.14, _cast(12) + [
		["fade", 0.0, 1.4], ["beat", "start"],
		["walk", "seraphine", [8, 17], {"t": 0.5}], ["look", "seraphine", "E"], ["fx", "seraphine", "circle", 1.0], ["wait", 0.8],
		["say", "seraphine", "SERAPHINE", "Old magic. Very old."],
		["say", "alaric", "ALARIC", "Can you tell who made it?"],
		["say", "seraphine", "SERAPHINE", "Someone who feared what would happen when the palace was left undefended."],
		["say", "kaelen", "KAELEN", "A sensible fear, apparently."],
		["wait", 1.0], ["beat", "continue"],
	] + _march(18, 0.5) + [["fade", 1.0, 1.2]], {"next": "fn_chambers"})
	# ---------------------------------------------------------------------------------------------- the King's private chambers
	s["fn_chambers"] = _scene("fn_chambers", CHAMBER, "#2a2a40", 0.22, [
		["spawn", "alaric", "king", [6, 2], "E"], ["spawn", "bram", "warden", [7, 1], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [5, 1], "E"],
		["spawn", "merc", "merc", [4, 2], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [8, 2], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [3, 1], "E", {"tint": "vessel"}],
		["spawn", "seraphine", "sorc", [6, 0], "E", {"tint": "vessel"}],
		["spawn", "attendant", "villager_girl", [5, 10], "W", {"alpha": 0.0}],  # stand-in: the royal attendant has no sheet
		["fade", 0.0, 2.0], ["beat", "start"],
		["walk", "alaric", [6, 6], {"t": 0.6}], ["wait", 0.8],
		["narrate", "A quiet room. Books. Letters. Worn things a man keeps close. No instruments, no laboratory, no sign of any dark rite.", 3.6],  # DRAFT
		["wait", 0.6],
		["narrate", "On a table, a small portrait of a young girl. Beside it, a heap of letters from the regional governors, still sealed.", 3.6],  # DRAFT: the portrait has no art yet; the letters are unopened
		["walk", "alaric", [6, 8], {"t": 0.5}], ["look", "alaric", "E"], ["wait", 1.0],
		["say", "alaric", "ALARIC", "His daughter."],
		["say", "lyra", "LYRA", "She was young."],
		["say", "bram", "BRAM", "Too young."],
		["wait", 1.0], ["fadein", "attendant", 0.8], ["look", "alaric", "S"], ["beat", "attendant"],
		["say", "attendant", "ATTENDANT", "Her Majesty was the light of this palace."],
		["say", "alaric", "ALARIC", "What happened to her?"],
		["wait", 0.8],
		["say", "attendant", "ATTENDANT", "She died."],
		["wait", 1.4], ["bubble", "attendant", "..."],
		["wait", 1.2], ["look", "alaric", "W"],
		["narrate", "The attendant will say no more. For years, this has been a house in mourning.", 3.2],  # DRAFT: the owner's note that the party learns of the King's years of mourning
		["wait", 0.8], ["beat", "doubt"],
		["fade", 1.0, 1.4],
	])
	# ---------------------------------------------------------------------------------------------- the Crown's Last Stand
	s["fn_crown_pre"] = _scene("fn_crown_pre", P4, "#e8d8b0", 0.14, _cast(2, "@king") + [
		["spawn", "pcmd", "riverband_brute", [7, 19], "W"], ["spawn", "k1", "spectral_duelist", [4, 16], "W"], ["spawn", "k2", "spectral_duelist", [10, 16], "W"],
		["fade", 0.0, 1.8], ["beat", "start"]] + _march(8, 0.55) + [
		["look", "pcmd", "S"], ["wait", 0.8],
		["say", "pcmd", "COMMANDER", "His Majesty has waited years for someone like you."],
		["say", "alaric", "ALARIC", "Then why are you standing in my way?"],
		["say", "pcmd", "COMMANDER", "Because I cannot let you kill him."],
		["say", "alaric", "ALARIC", "Move."],
		["say", "pcmd", "COMMANDER", "I cannot."],
		["wait", 0.8], ["act", "pcmd", "attack"], ["flash"], ["fade", 1.0, 1.0],
	])
	s["fn_b4_post"] = _scene("fn_b4_post", P4, "#e8d8b0", 0.14, _cast(13) + [
		["spawn", "pcmd", "riverband_brute", [7, 17], "W"], ["spawn", "k1", "spectral_duelist", [4, 19], "N"], ["spawn", "k2", "spectral_duelist", [10, 19], "N"],
		["fade", 0.0, 1.4], ["beat", "start"],
		["hold", "pcmd", "hit", 2], ["hold", "k1", "ko", 2], ["hold", "k2", "hit", 2], ["wait", 1.2], ["beat", "kneels"],
		["walk", "alaric", [7, 15], {"t": 0.6}], ["look", "alaric", "E"], ["wait", 0.8],
		["say", "pcmd", "COMMANDER", "If you kill him, you'll destroy what's left of this kingdom."],
		["say", "alaric", "ALARIC", "He destroyed everything I had."],
		["say", "pcmd", "COMMANDER", "Then ask him why."],
		["wait", 1.0], ["walk", "pcmd", [6, 17], {"t": 0.5}], ["look", "pcmd", "S"], ["beat", "steps_aside"],
		["wait", 1.0], ["shake", 0.02, 1.4], ["tint", "#ffffff", 0.4, 1.2], ["flash"], ["beat", "doors"],  # the inner doors open
		["tint", "#e8d8b0", 0.14, 1.0], ["fade", 1.0, 1.2],
	])
	# ---------------------------------------------------------------------------------------------- the confrontation
	s["fn_confront"] = _scene("fn_confront", P5, "#f0e8d0", 0.18, _cast(2, "@king") + [
		["spawn", "king_npc", KING_SHEET, [7, 16], "W"],  # stand-in: the King has no sheet of his own
		["fade", 0.0, 2.0], ["beat", "start"]] + _march(8, 0.6) + [
		["wait", 1.4], ["look", "king_npc", "S"], ["beat", "king"],
		["say", "king_npc", "KING", "You're the summoner."],
		["say", "alaric", "ALARIC", "And you're the King."],
		["say", "king_npc", "KING", "I've been trying to find you."],
		["say", "alaric", "ALARIC", "You found me."],
		["say", "king_npc", "KING", "I had hoped we could speak."],
		["say", "alaric", "ALARIC", "Then answer me."],
		["wait", 1.2],
		["say", "alaric", "ALARIC", "Why did you burn my village?"],
		["wait", 0.8], ["bubble", "king_npc", "?"],
		["say", "king_npc", "KING", "What?"],
		["say", "alaric", "ALARIC", "Your soldiers came in the night. They wore your banners. They killed everyone."],
		["bubble", "king_npc", "!"], ["wait", 0.6],
		["say", "king_npc", "KING", "I gave no such order."],
		["say", "alaric", "ALARIC", "I saw them."],
		["say", "king_npc", "KING", "I believe you saw soldiers."],
		["say", "alaric", "ALARIC", "They carried your crest."],
		["say", "king_npc", "KING", "Then someone has committed a terrible crime in my name."],
		["say", "alaric", "ALARIC", "You expect me to believe that?"],
		["say", "king_npc", "KING", "I expect you to hear me."],
		["say", "alaric", "ALARIC", "I buried people because of you."],
		["wait", 1.0],
		["say", "king_npc", "KING", "Then you have suffered more than I knew."],
		["say", "alaric", "ALARIC", "Don't pity me."],
		["say", "king_npc", "KING", "I'm not."],
		["wait", 1.6],
		["say", "king_npc", "KING", "I'm sorry."],
		["wait", 1.0], ["bubble", "alaric", "..."], ["wait", 0.8],
		["say", "alaric", "ALARIC", "I need more than an apology."],
		["say", "king_npc", "KING", "Then let us find the truth."],
		["say", "alaric", "ALARIC", "After everything that's happened, you think I'll simply trust you?"],
		["say", "king_npc", "KING", "No."],
		["look", "king_npc", "W"], ["wait", 0.6],
		["say", "king_npc", "KING", "And I cannot trust a man who has fought his way through my palace."],
		["wait", 1.0], ["act", "alaric", "attack"], ["look", "king_npc", "S"], ["act", "king_npc", "attack"], ["beat", "swords"],
		["say", "king_npc", "KING", "If this is the only language we have left, then so be it."],
		["flash"], ["shake", 0.03, 1.2], ["fade", 1.0, 1.0],
	])
	# ---------------------------------------------------------------------------------------------- the choice not to kill
	s["fn_b5_post"] = _scene("fn_b5_post", P5, "#f0e8d0", 0.16, _cast(11) + [
		["spawn", "king_npc", KING_SHEET, [7, 15], "S"], ["spawn", "h1", "ironhollow_sentinel", [4, 17], "N"], ["spawn", "h2", "ironhollow_sentinel", [10, 17], "N"],
		["fade", 0.0, 1.6], ["beat", "start"],
		["hold", "king_npc", "ko", 2], ["hold", "h1", "ko", 2], ["hold", "h2", "hit", 2], ["wait", 1.6],
		["narrate", "The King's sword rings on the stone. He sinks to one knee.", 3.0],  # DRAFT: the owner's staging
		["walk", "alaric", [7, 13], {"t": 0.7}], ["look", "alaric", "E"], ["wait", 1.2], ["act", "alaric", "attack"], ["wait", 0.8], ["beat", "choice"],
		["say", "king_npc", "KING", "If you mean to kill me, I cannot stop you."],
		["say", "alaric", "ALARIC", "Give me one reason not to."],
		["say", "king_npc", "KING", "Because I did not order the destruction of your village."],
		["say", "alaric", "ALARIC", "You keep saying that."],
		["say", "king_npc", "KING", "It's the only answer I have."],
		["wait", 1.6], ["bubble", "alaric", "..."], ["narrate", "He remembers the records. Soldiers who had died generations before they burned his home.", 3.4],  # DRAFT: the owner's recollection beat
		["say", "king_npc", "KING", "I searched for you because I heard you could summon the dead."],
		["say", "alaric", "ALARIC", "Why?"],
		["wait", 1.4],
		["say", "king_npc", "KING", "My daughter."],
		["wait", 1.0],
		["say", "king_npc", "KING", "She died years ago."],
		["say", "alaric", "ALARIC", "I'm sorry."],
		["say", "king_npc", "KING", "I have spent every day wondering whether she is somewhere I might still reach."],
		["say", "king_npc", "KING", "I was told you could bring spirits into this world."],
		["say", "alaric", "ALARIC", "Sometimes."],
		["say", "king_npc", "KING", "Then I have one request."],
		["say", "alaric", "ALARIC", "What?"],
		["say", "king_npc", "KING", "Come with me."],
		["wait", 1.4], ["fade", 1.0, 1.4],
	], {"next": "fn_grave"})
	# ---------------------------------------------------------------------------------------------- the graveyard
	s["fn_grave"] = _scene("fn_grave", GARDEN, "#d8d8e0", 0.1, [
		["spawn", "king_npc", KING_SHEET, [7, 4], "E"], ["spawn", "alaric", "king", [7, 3], "E"],
		["spawn", "bram", "warden", [11, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [10, 2], "E"], ["spawn", "merc", "merc", [9, 1], "E", {"tint": "vessel"}],
		["spawn", "gideon", "squire", [12, 1], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [11, 1], "E", {"tint": "vessel"}], ["spawn", "seraphine", "sorc", [10, 1], "E", {"tint": "vessel"}],
		["fade", 0.0, 2.4], ["beat", "start"],
		["wait", 1.8],
		["walk", "king_npc", [9, 15], {"t": 0.7}], ["wait", 0.4], ["walk", "alaric", [8, 14], {"t": 0.7}], ["look", "alaric", "E"],
		["walk", "lyra", [11, 8], {"t": 0.7, "par": true}], ["walk", "bram", [12, 8], {"t": 0.7, "par": true}], ["join"], ["look", "lyra", "E"], ["wait", 1.4], ["beat", "grave"],
		["narrate", "The royal cemetery lies in a quiet garden behind the palace. One simple stone, carefully kept. Fresh flowers beside it.", 3.6],  # DRAFT: the owner's setting
		["walk", "king_npc", [9, 16], {"t": 0.6}], ["hold", "king_npc", "hit", 2], ["wait", 1.6],
		["say", "king_npc", "KING", "Her name was Elowen."],
		["wait", 1.2], ["look", "alaric", "E"],
		["say", "king_npc", "KING", "She was my daughter."],
		["wait", 2.0],
		["say", "king_npc", "KING", "I've searched for someone like you every day."],
		["say", "alaric", "ALARIC", "I can't promise anything."],
		["say", "king_npc", "KING", "I know."],
		["wait", 1.4],
		["walk", "alaric", [9, 15], {"t": 0.6}], ["look", "alaric", "E"], ["wait", 1.0], ["beat", "summon_1"],
		["fx", "alaric", "circle", 1.4], ["wait", 2.6], ["beat", "nothing"],
		["wait", 1.4], ["beat", "summon_2"],
		["fx", "alaric", "circle", 1.4], ["wait", 2.6],
		["wait", 1.0],
		["say", "king_npc", "KING", "Is something wrong?"],
		["say", "alaric", "ALARIC", "I can't find her."],
		["say", "king_npc", "KING", "Try again."],
		["wait", 1.4], ["beat", "summon_3"],
		["fx", "alaric", "circle", 1.0], ["wait", 3.0], ["beat", "faded"],
		["say", "alaric", "ALARIC", "There's no spirit here."],
		["say", "king_npc", "KING", "What does that mean?"],
		["wait", 1.6], ["bubble", "alaric", "..."], ["wait", 1.0],
		["say", "alaric", "ALARIC", "Sometimes souls move beyond where I can reach them."],
		["wait", 1.4],
		["say", "king_npc", "KING", "So she's gone?"],
		["say", "alaric", "ALARIC", "I think so."],
		["wait", 3.2],
		["say", "king_npc", "KING", "I thought if I could hear her voice once more..."],
		["wait", 2.4],
		["walk", "alaric", [9, 14], {"t": 0.5}], ["hold", "alaric", "hit", 2], ["wait", 1.4],
		["say", "alaric", "ALARIC", "I understand."],
		["wait", 2.4], ["beat", "two_men"],
		["narrate", "Not a King and a summoner. Two men who have lost someone.", 3.4],  # DRAFT: the owner's note on how they see one another
		["wait", 3.0], ["fade", 1.0, 2.4],
	], {"next": "fn_alliance"})
	# ---------------------------------------------------------------------------------------------- the alliance
	s["fn_alliance"] = _scene("fn_alliance", CHAMBER, "#2a2a40", 0.18, [
		["spawn", "king_npc", KING_SHEET, [6, 8], "W"], ["spawn", "alaric", "king", [6, 3], "E"],
		["fade", 0.0, 1.8], ["beat", "start"],
		["walk", "alaric", [6, 6], {"t": 0.6}], ["look", "alaric", "E"], ["wait", 1.4],
		["say", "king_npc", "KING", "While I mourned my daughter, I allowed my kingdom to suffer."],
		["say", "alaric", "ALARIC", "You didn't know what happened to my village."],
		["say", "king_npc", "KING", "No."],
		["say", "alaric", "ALARIC", "But someone used your soldiers' banners."],
		["say", "king_npc", "KING", "Then I intend to learn who."],
		["wait", 1.2], ["narrate", "Alaric lays the old military records on the table.", 2.8],  # DRAFT: the owner's staging
		["say", "alaric", "ALARIC", "The soldiers who attacked my village appear to have died more than a century ago."],  # DRAFT: the owner's note that he explains this
		["wait", 1.4], ["look", "king_npc", "S"],
		["say", "king_npc", "KING", "These men served my ancestors."],
		["say", "alaric", "ALARIC", "I saw them alive."],
		["say", "king_npc", "KING", "Then someone brought them back."],
		["wait", 0.8],
		["say", "king_npc", "KING", "Another summoner."],
		["say", "alaric", "ALARIC", "That's what I think."],
		["wait", 1.2],
		["say", "king_npc", "KING", "Someone used the dead to turn you against me."],
		["say", "alaric", "ALARIC", "Yes."],
		["say", "king_npc", "KING", "And nearly succeeded."],
		["wait", 1.0], ["look", "alaric", "W"],
		["say", "alaric", "ALARIC", "I was ready to kill you."],
		["say", "king_npc", "KING", "I know."],
		["wait", 1.4],
		["narrate", "The King offers the royal archives, his investigators and every military record.", 3.0],  # DRAFT: the owner's note on what is offered
		["say", "king_npc", "KING", "Find whoever did this."],
		["say", "alaric", "ALARIC", "I intend to."],
		["say", "king_npc", "KING", "Then you have the crown's assistance."],
		["wait", 1.6], ["look", "alaric", "E"], ["beat", "cautious"],
		["fade", 1.0, 1.6],
	], {"next": "fn_end_a"})
	# ---------------------------------------------------------------------------------------------- the false ending (short scenes)
	s["fn_end_a"] = _scene("fn_end_a", THRONE, "#e8e0d0", 0.14, [
		["spawn", "d1", "squire", [4, 8], "E"], ["spawn", "d2", "squire", [10, 8], "E"], ["spawn", "d3", "riverband_brute", [7, 10], "E"],
		["spawn", "aldren", "ironhollow_sentinel", [6, 16], "W"], ["spawn", "official", "villager_man", [8, 17], "W"],
		["fade", 0.0, 2.0], ["beat", "start"],
		["narrate", "Across the palace, weapons are lowered.", 2.6],  # DRAFT: captions for the montage
		["hold", "d1", "hit", 2], ["hold", "d2", "hit", 2], ["wait", 1.4],
		["walk", "d1", [4, 3], {"t": 0.5, "par": true}], ["walk", "d2", [10, 3], {"t": 0.5, "par": true}], ["join"],
		["narrate", "Captain Aldren is given his orders: stand down.", 2.6],  # DRAFT
		["look", "aldren", "S"], ["wait", 1.2], ["bubble", "aldren", "~"], ["wait", 1.4],
		["fade", 1.0, 1.4],
	], {"next": "fn_end_b"})
	s["fn_end_b"] = _scene("fn_end_b", STREET, "#e8c890", 0.16, _cast(4) + [
		["fade", 0.0, 1.8], ["beat", "start"],
		["narrate", "In the city, the shutters open. The streets fill again.", 2.8],  # DRAFT
		["wait", 1.6],
		["narrate", "Outside the palace, the company gathers.", 2.6],  # DRAFT
		["walk", "bram", [9, 9], {"t": 0.5, "par": true}], ["walk", "kaelen", [4, 9], {"t": 0.5, "par": true}], ["walk", "merc", [5, 9], {"t": 0.5, "par": true}], ["join"],
		["wait", 1.6], ["fade", 1.0, 1.4],
	], {"folk": [["villager_man", [5, 14]], ["villager_kid", [9, 18]], ["villager_girl", [8, 20]], ["mechanic", [6, 22]]], "next": "fn_end_c"})
	s["fn_end_c"] = _scene("fn_end_c", CHAMBER, "#2a2a40", 0.2, [
		["spawn", "king_npc", KING_SHEET, [6, 8], "E"],
		["fade", 0.0, 2.0], ["beat", "start"],
		["narrate", "The King stands quietly before his daughter's portrait.", 3.0],  # DRAFT: the portrait has no art yet
		["wait", 2.2], ["look", "king_npc", "E"], ["wait", 1.6], ["bubble", "king_npc", "~"],
		["wait", 2.4], ["fade", 1.0, 1.6],
	], {"next": "fn_end_d"})
	s["fn_end_d"] = _scene("fn_end_d", CROWN_HILL, "#d8a870", 0.22, [
		["spawn", "alaric", "king", [7, 14], "E"], ["spawn", "lyra", "mira", [6, 10], "E"],
		["fade", 0.0, 2.2], ["beat", "start"],
		["narrate", "Alaric looks toward the horizon.", 2.8],  # DRAFT
		["walk", "alaric", [7, 17], {"t": 0.7}], ["look", "alaric", "E"], ["wait", 2.0],
		["walk", "lyra", [6, 16], {"t": 0.6}], ["look", "lyra", "E"], ["beat", "lyra"],
		["say", "lyra", "LYRA", "You reached him."],
		["say", "alaric", "ALARIC", "Yes."],
		["say", "lyra", "LYRA", "Was it what you expected?"],
		["say", "alaric", "ALARIC", "No."],
		["say", "lyra", "LYRA", "What happens now?"],
		["wait", 1.4],
		["say", "alaric", "ALARIC", "I find the people who burned my home."],
		["say", "lyra", "LYRA", "And after that?"],
		["wait", 1.2], ["look", "alaric", "W"],
		["say", "alaric", "ALARIC", "I don't know."],
		["wait", 1.0], ["bubble", "lyra", "~"],
		["say", "lyra", "LYRA", "That's all right."],
		["wait", 2.0], ["fade", 1.0, 2.4],
		["title", "HOLLOWMARK TACTICS", "", 3.2], ["wait", 1.4],
		["title", "THE END", "", 4.0], ["wait", 2.0],
	], {"next": "fn_postcredits"})
	# ---------------------------------------------------------------------------------------------- the post-credits scene
	s["fn_postcredits"] = _scene("fn_postcredits", HILL, "#0a0a1c", 0.45, [
		["spawn", "man", "spectral_duelist", [11, 16], "W", {"tint": "shadow"}],  # a silhouette: a stand-in for the man with the rapier
		["spawn", "woman", "villager_girl", [11, 17], "W", {"tint": "shadow"}],  # a silhouette: she must resemble the girl in the King's portrait (not drawn yet)
		["fade", 0.0, 3.0], ["beat", "start"],
		["wait", 2.4],
		["say", "woman", "WOMAN", "He survived."],
		["say", "man", "MAN", "Apparently."],
		["say", "woman", "WOMAN", "And my father?"],
		["say", "man", "MAN", "Alive."],
		["wait", 2.0],
		["say", "woman", "WOMAN", "That's unfortunate."],
		["say", "man", "MAN", "Is it?"],
		["say", "woman", "WOMAN", "We were rather close."],
		["wait", 1.0], ["bubble", "man", "~"], ["wait", 1.0],
		["say", "man", "MAN", "Well, there's always another plan."],
		["wait", 1.4], ["look", "man", "E"], ["look", "woman", "W"],
		["say", "woman", "WOMAN", "You promised me a kingdom."],
		["say", "man", "MAN", "I promised you a world without kings."],
		["say", "woman", "WOMAN", "Even better."],
		["wait", 1.4], ["look", "man", "E"], ["bubble", "woman", "~"], ["wait", 3.0], ["beat", "kiss"],
		["fade", 1.0, 3.0],
		["title", "THE STORY CONTINUES", "", 4.0], ["wait", 1.6],
		["unlock", "records"],  # chapter ten opens on the world map
	])
	return s
