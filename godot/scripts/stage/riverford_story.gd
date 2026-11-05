class_name RiverfordStory
extends RefCounted
## Chapter two, "The Price of Embers": the scenes (StoryScene plays them). The text is the owner's, word for word wherever it is quoted
## in "Chapter Two: The Price of Embers" (the market scene, the squire captain's aide, Merc's death and rise, Vesper's wrath); the owner's
## stage directions are played, not shown. LINES the owner did not write are marked DRAFT below and listed in godot/HANDOFF.md.

static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {"id": "", "map": Riverford.MARKET, "steps": []})


const SCENES := {}
