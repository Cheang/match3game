extends RefCounted
class_name BuffRegistry

## Central registry for all Buffs and Debuffs in LoreTiles.
## Provides a unified, data-driven definition catalog used by both PlayerResource
## and EnemyResource (via EntityResource) as well as the BuffContainer UI.

class BuffDef extends RefCounted:
	var id: String = ""
	var title: String = ""
	var icon_path: String = ""
	var icon: Texture2D = null
	var is_debuff: bool = false
	var show_stacks: bool = true
	var clear_on_turn_start: bool = false
	var clear_on_turn_end: bool = false
	var decay_per_turn: int = 0
	var description: String = ""
	var popup_color: Color = Color.WHITE

	func _init(
		p_id: String = "",
		p_title: String = "",
		p_icon_path: String = "",
		p_is_debuff: bool = false,
		p_show_stacks: bool = true,
		p_clear_on_turn_start: bool = false,
		p_decay_per_turn: int = 0,
		p_description: String = "",
		p_popup_color: Color = Color.WHITE,
		p_clear_on_turn_end: bool = false
	) -> void:
		id = p_id
		title = p_title
		icon_path = p_icon_path
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon = load(icon_path) as Texture2D
		is_debuff = p_is_debuff
		show_stacks = p_show_stacks
		clear_on_turn_start = p_clear_on_turn_start
		clear_on_turn_end = p_clear_on_turn_end
		decay_per_turn = p_decay_per_turn
		description = p_description
		popup_color = p_popup_color

	func get_icon() -> Texture2D:
		if icon == null and icon_path != "" and ResourceLoader.exists(icon_path):
			icon = load(icon_path) as Texture2D
		return icon

	func build_tooltip(stacks: int) -> String:
		var kind_label: String = "Debuff" if is_debuff else "Buff"
		var stack_suffix: String = " (x%d)" % stacks if (show_stacks or stacks > 1) else ""
		if description != "":
			return "%s%s [%s]\n%s" % [title, stack_suffix, kind_label, description]
		return "%s%s [%s]" % [title, stack_suffix, kind_label]


static var _defs: Dictionary = {}
static var _aliases: Dictionary = {
	"dodging": "dodge",
	"dodge": "dodge",
	"hand_combo": "combo",
	"combo": "combo",
	"hndcombo": "combo",
}
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	register_buff(
		"dodge",
		"Dodge",
		"res://assets/scene-assets/combat/buff-dodge.png",
		false,
		false,
		false,
		0,
		"Negates the next incoming physical attack.",
		Color(0.42, 0.94, 0.48),
		false
	)

	register_buff(
		"combo",
		"Combo",
		"res://assets/scene-assets/combat/buff-combo.png",
		false,
		true,
		true,
		0,
		"Increases scaling damage and effects of combo-enabled skills.",
		Color(0.98, 0.84, 0.35),
		true
	)


static func normalize_id(raw_id: String) -> String:
	_ensure_initialized()
	var key: String = raw_id.strip_edges().to_lower()
	if _aliases.has(key):
		return _aliases[key]
	return key


static func register_alias(alias_id: String, target_id: String) -> void:
	_ensure_initialized()
	_aliases[alias_id.strip_edges().to_lower()] = target_id.strip_edges().to_lower()


static func register_buff(
	id: String,
	title: String,
	icon_path: String = "",
	is_debuff: bool = false,
	show_stacks: bool = true,
	clear_on_turn_start: bool = false,
	decay_per_turn: int = 0,
	description: String = "",
	popup_color: Color = Color.WHITE,
	clear_on_turn_end: bool = false
) -> BuffDef:
	_ensure_initialized()
	var norm_id: String = id.strip_edges().to_lower()
	var def := BuffDef.new(
		norm_id,
		title,
		icon_path,
		is_debuff,
		show_stacks,
		clear_on_turn_start,
		decay_per_turn,
		description,
		popup_color,
		clear_on_turn_end
	)
	_defs[norm_id] = def
	if not _aliases.has(norm_id):
		_aliases[norm_id] = norm_id
	return def


static func has_buff_def(raw_id: String) -> bool:
	_ensure_initialized()
	var norm_id: String = normalize_id(raw_id)
	return _defs.has(norm_id)


static func get_def(raw_id: String) -> BuffDef:
	_ensure_initialized()
	var norm_id: String = normalize_id(raw_id)
	if _defs.has(norm_id):
		return _defs[norm_id]
	# Fallback definition for dynamically applied custom buffs/debuffs
	return BuffDef.new(
		norm_id,
		norm_id.capitalize(),
		"",
		false,
		true,
		false,
		0,
		"",
		Color.WHITE,
		false
	)


static func get_all_defs() -> Dictionary:
	_ensure_initialized()
	return _defs
