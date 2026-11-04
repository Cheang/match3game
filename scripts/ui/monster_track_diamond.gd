@tool
extends Control
class_name MonsterTrackDiamond

const SHADER_RES = preload("res://assets/shaders/palette_swap_5.gdshader")
const TEX_BOTTOM = preload("res://assets/scene-assets/combat/enm-move-bottom.png")
const TEX_MIDDLE = preload("res://assets/scene-assets/combat/enm-move-middle.png")
const TEX_TOP = preload("res://assets/scene-assets/combat/enm-move-top.png")

const PALETTES: Dictionary = {
	# Red (100)
	100: {
		"highlight": Color("#F9C22B"),
		"lightbase": Color("#FB6B1D"),
		"base": Color("#E83B3B"),
		"shadebase": Color("#AE2334"),
		"deepshade": Color("#7A3045")
	},
	# Blue (200)
	200: {
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#8FD3FF"),
		"base": Color("#4D9BE6"),
		"shadebase": Color("#4D65B4"),
		"deepshade": Color("#484A77")
	},
	# Green (300)
	300: {
		"highlight": Color("#FBFF86"),
		"lightbase": Color("#91DB69"),
		"base": Color("#1EBC73"),
		"shadebase": Color("#239063"),
		"deepshade": Color("#165A4C")
	},
	# Purple (400)
	400: {
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#EAADED"),
		"base": Color("#A884F3"),
		"shadebase": Color("#905EA9"),
		"deepshade": Color("#6B3E75")
	},
	# White (500)
	500: { 
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#FFFFFF"),
		"base": Color("#c7dcd0"),
		"shadebase": Color("#9babb2"),
		"deepshade": Color("#694f62")
	},
	# Wild / Colorless (0)
	0: {
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#FDCBB0"),
		"base": Color("#AB947A"),
		"shadebase": Color("#966C6C"),
		"deepshade": Color("#3E3546")
	}
}

@export var default_color: int = 100:
	set(val):
		default_color = val
		_apply_palette(val)

@export var preview_number: String = "":
	set(val):
		preview_number = val
		if quantity_label != null:
			quantity_label.text = val

var bottom_fill: TextureRect
var middle_icon: TextureRect
var top_border: TextureRect
var quantity_label: Label
var cycle_timer: Timer

var current_track_color: int = 100
var modifiers_queue: Array[Equipment] = []
var active_mod_index: int = 0
var mat_bottom: ShaderMaterial
var mat_middle: ShaderMaterial

func _init() -> void:
	custom_minimum_size = Vector2(68, 68)
	size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_hierarchy()
	_apply_palette(default_color)
	if preview_number != "" and quantity_label != null:
		quantity_label.text = preview_number

func _ensure_hierarchy() -> void:
	bottom_fill = get_node_or_null("BottomFill")
	middle_icon = get_node_or_null("MiddleIcon")
	top_border = get_node_or_null("TopBorder")
	quantity_label = get_node_or_null("QuantityLabel")
	cycle_timer = get_node_or_null("CycleTimer")

	if bottom_fill == null:
		mat_bottom = ShaderMaterial.new()
		mat_bottom.shader = SHADER_RES

		bottom_fill = TextureRect.new()
		bottom_fill.name = "BottomFill"
		bottom_fill.texture = TEX_BOTTOM
		bottom_fill.material = mat_bottom
		bottom_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bottom_fill)
	else:
		if bottom_fill.material is ShaderMaterial:
			mat_bottom = bottom_fill.material
		else:
			mat_bottom = ShaderMaterial.new()
			mat_bottom.shader = SHADER_RES
			bottom_fill.material = mat_bottom

	if middle_icon == null:
		mat_middle = ShaderMaterial.new()
		mat_middle.shader = SHADER_RES

		middle_icon = TextureRect.new()
		middle_icon.name = "MiddleIcon"
		middle_icon.texture = TEX_MIDDLE
		middle_icon.material = mat_middle
		middle_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(middle_icon)
	else:
		if middle_icon.material is ShaderMaterial:
			mat_middle = middle_icon.material
		else:
			mat_middle = ShaderMaterial.new()
			mat_middle.shader = SHADER_RES
			middle_icon.material = mat_middle

	if top_border == null:
		top_border = TextureRect.new()
		top_border.name = "TopBorder"
		top_border.texture = TEX_TOP
		top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(top_border)

	if quantity_label == null:
		quantity_label = Label.new()
		quantity_label.name = "QuantityLabel"
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quantity_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		quantity_label.offset_top = 34.0
		quantity_label.offset_bottom = -2.0
		quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quantity_label.add_theme_font_size_override("font_size", 14)
		quantity_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		quantity_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.15, 1.0))
		quantity_label.add_theme_constant_override("outline_size", 3)
		add_child(quantity_label)

	if cycle_timer == null:
		cycle_timer = Timer.new()
		cycle_timer.name = "CycleTimer"
		cycle_timer.wait_time = 2.4
		cycle_timer.one_shot = false
		cycle_timer.timeout.connect(_on_cycle_timer_timeout)
		add_child(cycle_timer)

func setup_track(track_color: int, mods: Array[Equipment]) -> void:
	_ensure_hierarchy()
	current_track_color = track_color
	modifiers_queue.clear()
	for m in mods:
		if m != null:
			modifiers_queue.append(m)
	active_mod_index = 0
	_apply_palette(track_color)
	_display_active_move()

	if modifiers_queue.size() > 1 and not Engine.is_editor_hint():
		cycle_timer.start()
	else:
		cycle_timer.stop()

func _apply_palette(track_color: int) -> void:
	_ensure_hierarchy()
	var base_c: int = int(track_color / 100) * 100 if track_color > 0 else 0
	var pal: Dictionary = PALETTES.get(base_c, PALETTES[0])
	
	for mat: ShaderMaterial in [mat_bottom, mat_middle]:
		if mat != null:
			mat.set_shader_parameter("target_color_1", pal.highlight)
			mat.set_shader_parameter("target_color_2", pal.lightbase)
			mat.set_shader_parameter("target_color_3", pal.base)
			mat.set_shader_parameter("target_color_4", pal.shadebase)
			mat.set_shader_parameter("target_color_5", pal.deepshade)

func _display_active_move() -> void:
	if modifiers_queue.is_empty():
		if middle_icon != null:
			middle_icon.visible = true
		if quantity_label != null:
			quantity_label.text = preview_number
		tooltip_text = "%s Track (Empty)" % _get_track_name(current_track_color)
		return

	var mod: Equipment = modifiers_queue[active_mod_index]
	if middle_icon != null:
		middle_icon.visible = true

	# Read quantity (damage, armor, etc.)
	var val: int = 0
	if "base_damage" in mod and mod.base_damage > 0.0:
		val = int(roundf(mod.base_damage))
	elif "base_armor" in mod and mod.base_armor > 0.0:
		val = int(roundf(mod.base_armor))
	elif "base_magic_armor" in mod and mod.base_magic_armor > 0.0:
		val = int(roundf(mod.base_magic_armor))
	elif "base_heal" in mod and mod.base_heal > 0.0:
		val = int(roundf(mod.base_heal))
	elif "moves_to_give" in mod and mod.moves_to_give > 0:
		val = mod.moves_to_give

	if quantity_label != null:
		if val > 0:
			quantity_label.text = str(val)
		else:
			quantity_label.text = ""

	var multi_note: String = " (%d/%d)" % [active_mod_index + 1, modifiers_queue.size()] if modifiers_queue.size() > 1 else ""
	tooltip_text = "%s Track: %s%s\n%s" % [
		_get_track_name(current_track_color),
		mod.piece_name,
		multi_note,
		mod.description if mod.description != "" else "Value: %d" % val
	]

func _on_cycle_timer_timeout() -> void:
	if modifiers_queue.size() <= 1:
		return
	active_mod_index = (active_mod_index + 1) % modifiers_queue.size()
	if middle_icon != null:
		middle_icon.scale = Vector2.ONE
	_display_active_move()

func _get_track_name(c: int) -> String:
	match c:
		0: return "Wild"
		100: return "Red"
		200: return "Blue"
		300: return "Green"
		400: return "Purple"
		500: return "White"
	return "Track"
