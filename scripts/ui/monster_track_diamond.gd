extends Control
class_name MonsterTrackDiamond

@export var default_color: int = 100:
	set(val):
		default_color = val
		_apply_palette(val)

@export var preview_number: String = "":
	set(val):
		preview_number = val
		if quantity_label != null:
			quantity_label.text = val

@onready var bottom_fill: TextureRect = get_node_or_null("BottomFill")
@onready var middle_icon: TextureRect = get_node_or_null("MiddleIcon")
@onready var top_border: TextureRect = get_node_or_null("TopBorder")
@onready var quantity_label: Label = get_node_or_null("QuantityLabel")
@onready var cycle_timer: Timer = get_node_or_null("CycleTimer")

var current_track_color: int = 100
var modifiers_queue: Array[Equipment] = []
var active_mod_index: int = 0

func _ready() -> void:
	if cycle_timer != null and not cycle_timer.timeout.is_connected(_on_cycle_timer_timeout):
		cycle_timer.timeout.connect(_on_cycle_timer_timeout)
	_apply_palette(default_color)
	if preview_number != "" and quantity_label != null:
		quantity_label.text = preview_number

func setup_track(track_color: int, mods: Array[Equipment]) -> void:
	current_track_color = track_color
	modifiers_queue.clear()
	for m in mods:
		if m != null:
			modifiers_queue.append(m)
	active_mod_index = 0
	_apply_palette(track_color)
	_display_active_move()

	if cycle_timer != null:
		if modifiers_queue.size() > 1:
			cycle_timer.start()
		else:
			cycle_timer.stop()

func _apply_palette(track_color: int) -> void:
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(track_color)
	for icon_node in [bottom_fill, middle_icon]:
		if icon_node != null and icon_node.material is ShaderMaterial:
			var mat: ShaderMaterial = icon_node.material
			mat.set_shader_parameter("target_color_1", pal.highlight)
			mat.set_shader_parameter("target_color_2", pal.lightbase)
			mat.set_shader_parameter("target_color_3", pal.base)
			mat.set_shader_parameter("target_color_4", pal.shadebase)
			mat.set_shader_parameter("target_color_5", pal.deepshade)

func _display_active_move() -> void:
	var track_name: String = "Wild" if current_track_color == 0 else ColorLoadoutTrack.get_color_name(current_track_color)
	if modifiers_queue.is_empty():
		if middle_icon != null:
			middle_icon.visible = true
		if quantity_label != null:
			quantity_label.text = preview_number
		tooltip_text = "%s Track (Empty)" % track_name
		return

	var mod: Equipment = modifiers_queue[active_mod_index]
	if middle_icon != null:
		middle_icon.visible = true

	var val: int = 0
	if mod.base_damage > 0.0:
		val = int(roundf(mod.base_damage))
	elif mod.base_armor > 0.0:
		val = int(roundf(mod.base_armor))
	elif mod.base_magic_armor > 0.0:
		val = int(roundf(mod.base_magic_armor))
	elif mod.base_heal > 0.0:
		val = int(roundf(mod.base_heal))
	elif mod.moves_to_give > 0:
		val = mod.moves_to_give

	if quantity_label != null:
		quantity_label.text = str(val) if val > 0 else ""

	var multi_note: String = " (%d/%d)" % [active_mod_index + 1, modifiers_queue.size()] if modifiers_queue.size() > 1 else ""
	tooltip_text = "%s Track: %s%s\n%s" % [
		track_name,
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
