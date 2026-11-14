class_name FacePicker
extends RefCounted
## Which of a character's expression portraits (meta.json `portrait_names`) a line of dialogue shows. A line can name its own face (the story
## steps' optional last element: ["say", id, name, text, "angry"]); a line that does not gets one guessed from its words and punctuation
## here, so every spoken line has a fitting face. The names are Alaric's sixteen (Bram's and Lyra's sheets, Nov 2026, use the same sixteen in the same order): neutral, calm, surprised, shout, eyes_closed, smile, laugh,
## cry_out, startled, worried, angry, looking_up, sad, pained, head_down, faint.

## Checked in order; the first rule that matches wins. [face, words...] (a word matches inside the line, lower case).
const WORDS := [
	["pained", ["wound", "bleed", "blood", "my side", "it hurts", "the pain", "ache", "stagger", "burns", "can't breathe", "hold on, i"]],
	["angry", ["kill", "murder", "traitor", "liar", "lies", "monster", "how dare", "enough", "never again", "bastard", "betray", "vengeance", "tyrant", "coward", "i will not", "i won't let", "no more", "regret it", "make them answer", "answer for", "i'll make sure"]],
	["sad", ["sorry", "forgive me", "forgive", "gone", "dead", "died", "grave", "buried", "mourn", "alone", "grief", "loss", "lost her", "lost him", "ashes", "i miss", "too late", "never came back"]],
	["worried", ["afraid", "careful", "what if", "are you sure", "can't lose", "if we fail", "dangerous", "trap", "something is wrong", "wrong with", "not safe", "be careful", "i don't like", "worried", "trust"]],
	["smile", ["thank", "glad", "well done", "good.", "together", "friend", "welcome", "proud", "hope", "rest now", "we did it", "you're safe", "safe now", "stay with us", "i'm here"]],
	["laugh", ["ha!", "ha ha", "haha", "laugh"]],
	["eyes_closed", ["remember", "i can still", "once,", "long ago", "a memory", "dream", "listen.", "quiet", "breathe", "the night my", "i was a boy", "when i was"]],
	["looking_up", ["the sky", "stars", "sunrise", "dawn", "above us", "the light"]],
]


## The expression for `text` ("neutral" when nothing fits). Deterministic: the same line always gets the same face. `data/alaric_faces.json`
## holds faces chosen by hand for particular lines (by their exact text) and wins over the guess.
static var _chosen := {}
static var _loaded := false


static func pick(text: String) -> String:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open("res://data/alaric_faces.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_chosen = parsed if parsed is Dictionary else {}
	var t := text.strip_edges()
	if _chosen.has(t):
		return String(_chosen[t])
	var low := t.to_lower()
	if t.contains("?!") or t.contains("!?"):
		return "startled"
	var short := t.length() <= 60
	if t.ends_with("!") and short and _any(low, ["run", "move", "now", "get back", "behind me", "hold", "go", "stand", "to me", "forward", "charge", "fall back", "down"]):
		return "shout"
	for rule in WORDS:
		if _any(low, rule[1]):
			return rule[0]
	if t.ends_with("...") or t.begins_with("...") or t.begins_with("\u2026") or t.ends_with("\u2026"):
		return "head_down"
	if t.ends_with("!"):
		return "shout" if short else "angry"
	if t.ends_with("?"):
		var words := t.split(" ", false).size()
		if words <= 2:
			return "surprised"  # "What?", "Who?", "The King?"
		return "worried" if t.length() > 60 else "neutral"  # a longer question is asked, not gasped
	return "calm" if t.length() > 40 else "neutral"


## Whether any of `words` is in `low` as a whole word or phrase ("ache" is not in "reached").
static func _any(low: String, words: Array) -> bool:
	for w in words:
		var rx := RegEx.new()
		rx.compile("(^|[^a-z'])" + String(w).replace(".", "\\.") + "($|[^a-z'])")
		if rx.search(low) != null:
			return true
	return false
