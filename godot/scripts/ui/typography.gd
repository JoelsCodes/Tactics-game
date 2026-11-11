class_name Typography
extends RefCounted
## The game's one typography system (owner, Nov 2026): Cinzel Bold for the fantasy headings, Inter for everything a player reads while playing (skill names,
## descriptions, stats, buttons, tooltips, battle information). Every menu asks for a ROLE, never for a font file or a pixel size, so changing a size or a weight
## here changes every screen. `HudStyle.font()` and `MenuKit.font()` (the old entry points) now return these fonts, and `install` puts them in a Theme, so a label
## that sets nothing already gets Inter at body size.
##
##   role           face                     size at 1080p   used for
##   TITLE          Cinzel Bold              44              a screen's title
##   HEADING        Cinzel Bold              30              a menu's or panel's heading
##   SUBHEADING     Cinzel Bold              26              a skill's or character's name in a detail pane
##   SECTION        Cinzel Bold              22              a section title ("Choose a skill", "Teachers"): mixed case, not capitals
##   BODY           Inter Regular            19              ordinary text, descriptions
##   BODY_STRONG    Inter SemiBold           20              skill names, list rows, buttons
##   NUMBER         Inter SemiBold, tabular  19              levels, SP, HP, percentages: digits that do not jiggle
##   LABEL          Inter Medium             17              tags, stat captions, secondary lines
##   CAPTION        Inter Regular            16              hints and footnotes: the smallest text anywhere
##   TOOLTIP        Inter Regular            18              hover text
##   TINY           Inter Medium             14              the HP tag on a turn-order card: the only text under 16
##
## Sizes are for the 1920 x 1080 layout; the project stretches the whole UI with the window (canvas_items), and the fonts are rasterized at the real size
## (FontFile oversampling is automatic), so text stays crisp at other resolutions. `scale` is a player-facing text size multiplier (1.0 normal).

enum Role { TITLE, HEADING, SUBHEADING, SECTION, BODY, BODY_STRONG, NUMBER, LABEL, CAPTION, TOOLTIP, TINY }

const DIR := "res://assets/fonts/"
const SIZES := {
	Role.TITLE: 44, Role.HEADING: 30, Role.SUBHEADING: 26, Role.SECTION: 22, Role.BODY: 19, Role.BODY_STRONG: 20, Role.NUMBER: 19,
	Role.LABEL: 17, Role.CAPTION: 16, Role.TOOLTIP: 18, Role.TINY: 14,
}
const MIN_SIZE := 16  ## nothing is set smaller than this (before `scale`), except TINY: the HP tag on the dense turn-order cards
const LINE_SPACING := 4  ## extra pixels between wrapped lines of body text

static var scale := 1.0
static var _cache := {}


# ---------- fonts ----------

## Cinzel Bold: the fantasy face, for headings only.
static func display() -> Font:
	return _load("Cinzel-Bold.ttf")


## Inter at a weight: "regular", "medium", "semibold" or "bold".
static func ui(weight := "regular") -> Font:
	match weight:
		"medium":
			return _load("Inter-Medium.ttf")
		"semibold":
			return _load("Inter-SemiBold.ttf")
		"bold":
			return _load("Inter-Bold.ttf")
	return _load("Inter-Regular.ttf")


## Inter SemiBold with tabular figures (every digit the same width), for numbers that change or line up.
static func numbers() -> Font:
	if not _cache.has("numbers"):
		var v := FontVariation.new()
		v.base_font = ui("semibold")
		v.opentype_features = {"tnum": 1, "zero": 0}
		_cache["numbers"] = v
	return _cache["numbers"]


static func font(role: Role) -> Font:
	match role:
		Role.TITLE, Role.HEADING, Role.SUBHEADING, Role.SECTION:
			return display()
		Role.BODY_STRONG:
			return ui("semibold")
		Role.NUMBER:
			return numbers()
		Role.LABEL, Role.TINY:
			return ui("medium")
	return ui("regular")


static func size(role: Role) -> int:
	return roundi(float(SIZES[role] if role == Role.TINY else maxi(int(SIZES[role]), MIN_SIZE)) * scale)


## The old two-flag call (`HudStyle.font(bold, display)`): Cinzel Bold for display, else Inter SemiBold (bold) or Inter Regular.
static func legacy(bold := false, display_face := false) -> Font:
	if display_face:
		return display()
	return ui("semibold") if bold else ui("regular")


static func _load(file: String) -> Font:
	if not _cache.has(file):
		_cache[file] = load(DIR + file)
	return _cache[file]


# ---------- applying a role ----------

## Gives a Label, Button, RichTextLabel or similar control a role's font and size (and optionally a colour): the one call menus make instead of
## add_theme_font_override / add_theme_font_size_override.
static func apply(c: Control, role: Role, color = null) -> void:
	c.add_theme_font_override("font", font(role))
	c.add_theme_font_size_override("font_size", size(role))
	if c is Label:
		(c as Label).add_theme_constant_override("line_spacing", LINE_SPACING if role in [Role.BODY, Role.TOOLTIP, Role.LABEL, Role.CAPTION] else 0)
	if color != null:
		c.add_theme_color_override("font_color", color)


static func label(text: String, role: Role, color = null) -> Label:
	var l := Label.new()
	l.text = text
	apply(l, role, color)
	return l


# ---------- the theme ----------

## Puts the typography into `t`: Inter at body size as the default, the standard controls (Label, Button, ItemList, LineEdit, tooltips...) and the type
## variations the menus use (TitleLabel, HeadingLabel, SectionLabel, SmallLabel, StrongLabel, NumberLabel). Colours and boxes stay with HudStyle / MenuKit.
static func install(t: Theme) -> void:
	t.default_font = font(Role.BODY)
	t.default_font_size = size(Role.BODY)
	for ctrl in ["Label", "ItemList", "LineEdit", "TextEdit", "RichTextLabel", "OptionButton", "CheckBox", "PopupMenu"]:
		t.set_font("font", ctrl, font(Role.BODY))
		t.set_font_size("font_size", ctrl, size(Role.BODY))
	t.set_font("normal_font", "RichTextLabel", font(Role.BODY))
	t.set_font("bold_font", "RichTextLabel", font(Role.BODY_STRONG))
	t.set_font_size("normal_font_size", "RichTextLabel", size(Role.BODY))
	t.set_font_size("bold_font_size", "RichTextLabel", size(Role.BODY))
	t.set_font("font", "Button", font(Role.BODY_STRONG))
	t.set_font_size("font_size", "Button", size(Role.BODY_STRONG))
	t.set_font("font", "TooltipLabel", font(Role.TOOLTIP))
	t.set_font_size("font_size", "TooltipLabel", size(Role.TOOLTIP))
	t.set_constant("line_spacing", "Label", LINE_SPACING)
	for pair in [["TitleLabel", Role.TITLE], ["HeadingLabel", Role.HEADING], ["SubheadingLabel", Role.SUBHEADING], ["SectionLabel", Role.SECTION], ["SmallLabel", Role.CAPTION],
			["StrongLabel", Role.BODY_STRONG], ["NumberLabel", Role.NUMBER], ["TagLabel", Role.LABEL]]:
		t.set_type_variation(pair[0], "Label")
		t.set_font("font", pair[0], font(pair[1]))
		t.set_font_size("font_size", pair[0], size(pair[1]))
