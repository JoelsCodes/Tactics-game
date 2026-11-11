class_name SkillLook
extends RefCounted
## Which effect look a skill has (EffectLibrary: "fire", "ice", "spark" or "holy"), or "" for a skill the library does not dress. Worked out from the skill
## itself, so no skill file changes: first an explicit `fx.look` in the skill's JSON, then (non-physical skills only) its name, its status and its
## proficiency. Physical skills keep their weapon's own effects (slashes, sparks, dust).
##
## Only four looks have art so far (the owner's sheet), so earth, wind, water, poison and void skills take the nearest: a cold one is ice, a plain
## elemental or a curse is spark (the purple and gold one), anything that heals, shields or rallies is holy. More looks are a new set of strips and a
## line in data/effect_looks.json; the rules below are the only place that decides.

const LOOKS := ["fire", "ice", "spark", "holy"]
const FIRE_WORDS := ["ember", "flame", "fire", "burn", "scorch", "inferno", "meteor", "phoenix", "hot ", "cinder", "blaze", "magma", "pyre", "sun", "flare"]
const ICE_WORDS := ["frost", "ice", "glacier", "snow", "blizzard", "zero", "chill", "freez", "soak", "rain", "lullaby", "sandman", "nightfall", "slow", "lethargy", "hush", "tar trap", "stalemate", "checkmate", "entangle", "ankle", "snare"]
const SPARK_WORDS := ["spark", "static", "thunder", "storm", "lightning", "bolt", "shock", "volt", "tempest", "chain", "pulse"]
const HOLY_WORDS := ["heal", "mend", "pray", "bless", "grace", "miracle", "sanctuary", "renew", "purify", "angel", "radiant", "hymn", "rally", "fortify", "bulwark", "phalanx", "haste", "brace", "ward", "aura", "oath", "salts", "blanket", "soup", "hat", "tune", "lollipop"]

static var _cache := {}


static func of(skill: SkillData) -> String:
	if skill == null:
		return ""
	if _cache.has(skill):
		return _cache[skill]
	var look := _work_out(skill)
	_cache[skill] = look
	return look


static func _work_out(skill: SkillData) -> String:
	var own := String(skill.fx.get("look", ""))
	if own != "" and LOOKS.has(own):
		return own
	if skill.category == Proficiency.Category.PHYSICAL:
		return ""
	var n := skill.display_name.to_lower() + " "
	# a skill that heals or shields is holy whatever its name says
	if skill.category == Proficiency.Category.HEALING:
		return "holy"
	for w in FIRE_WORDS:
		if n.contains(w):
			return "fire"
	if skill.status == "burn" or String(skill.fx.get("status", {}).keys().front() if skill.fx.get("status", {}) is Dictionary and not skill.fx.get("status", {}).is_empty() else "") == "burn":
		return "fire"
	for w in ICE_WORDS:
		if n.contains(w):
			return "ice"
	for w in SPARK_WORDS:
		if n.contains(w):
			return "spark"
	for w in HOLY_WORDS:
		if n.contains(w):
			return "holy"
	if skill.support != "" or skill.allies_only or skill.fx.has("guard") or skill.fx.has("cleanse") or skill.fx.has("mods"):
		return "holy"
	var st = skill.fx.get("status", {})
	if st is Dictionary:
		for k in st.keys():
			if k in ["sleep", "slowed", "root", "silence", "freeze"]:
				return "ice"
			if k in ["ward", "regen", "haste"]:
				return "holy"
	return "spark"
