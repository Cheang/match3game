class_name BottomBar
extends Control

## Reusable Bottom Bar HUD component for non-combat screens (Rewards, Events, Map, etc.).
## Layout:
## - Left: HP globe with animated sloshing pixel liquid shader and HP label
## - Middle: Inventory button embedded in central stone frame
## - Right: Gold globe with gold icon and gold count label

@onready var left_globe: Control = find_child("LeftGlobe", true, false)
@onready var hp_liquid: ColorRect = find_child("HPLiquid", true, false)
@onready var hp_label: Label = find_child("HPLabel", true, false)
@onready var right_globe: Control = find_child("RightGlobe", true, false)
@onready var backplate: TextureRect = find_child("Backplate", true, false)
@onready var inventory_button: InventoryButton = find_child("inventory_button", true, false)
@onready var gold_container: Control = find_child("GoldContainer", true, false)
@onready var gold_icon: TextureRect = find_child("GoldIcon", true, false)
@onready var gold_label: Label = find_child("GoldLabel", true, false)

var _hp_mat: ShaderMaterial
var _hp_tween: Tween
var _bound_player: PlayerResource = null

var current_hp: float = 20.0
var max_hp: float = 20.0
var current_gold: int = 0

# Base wave amplitudes matching combat screen
const BASE_WAVE_AMP: float = 0.022
const SLOSH_WAVE_AMP: float = 0.045

# Liquid Palette Colors (HP)
const HP_HIGHLIGHT := Color("#F9C22B")
const HP_BASE := Color("#E83B3B")
const HP_SHADOW := Color("#7A3045")

# Label Colors
const COLOR_HP_TEXT := Color(1.0, 1.0, 1.0)
const COLOR_HP_OUTLINE := Color(0.12, 0.08, 0.15)
const COLOR_GOLD_TEXT := Color("#F9C22B")
const COLOR_GOLD_OUTLINE := Color(0.12, 0.08, 0.15)


func _ready() -> void:
	# Duplicate shader material so instances have independent parameters
	if hp_liquid and hp_liquid.material is ShaderMaterial:
		_hp_mat = hp_liquid.material.duplicate() as ShaderMaterial
		hp_liquid.material = _hp_mat
	elif hp_liquid:
		_hp_mat = ShaderMaterial.new()
		_hp_mat.shader = preload("res://assets/shaders/pixel_liquid_globe.gdshader")
		hp_liquid.material = _hp_mat

	if _hp_mat:
		_hp_mat.set_shader_parameter("col_highlight", HP_HIGHLIGHT)
		_hp_mat.set_shader_parameter("col_base", HP_BASE)
		_hp_mat.set_shader_parameter("col_shadow", HP_SHADOW)
		_hp_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		_hp_mat.set_shader_parameter("wave_frequency", 13.0)
		_hp_mat.set_shader_parameter("wave_speed", 3.2)
		_hp_mat.set_shader_parameter("pixel_grid_size", 128.0)
		_hp_mat.set_shader_parameter("radius", 0.485)
		_hp_mat.set_shader_parameter("enable_specks", true)
		_hp_mat.set_shader_parameter("speck_rise_speed", 0.28)

	_bind_to_player()
	update_from_player(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_bind_to_player()
	elif what == NOTIFICATION_EXIT_TREE:
		_unbind_from_player()


func _bind_to_player() -> void:
	if _bound_player != Global.cur_char:
		_unbind_from_player()
	if Global.cur_char != null:
		_bound_player = Global.cur_char
		if not _bound_player.updateUIPlayer.is_connected(_on_player_stat_changed):
			_bound_player.updateUIPlayer.connect(_on_player_stat_changed)


func _unbind_from_player() -> void:
	if _bound_player != null:
		if _bound_player.updateUIPlayer.is_connected(_on_player_stat_changed):
			_bound_player.updateUIPlayer.disconnect(_on_player_stat_changed)
		_bound_player = null


func _on_player_stat_changed(stat: String) -> void:
	if stat == "cur_health" or stat == "max_health":
		if _bound_player != null:
			set_hp(_bound_player.cur_health, _bound_player.max_health, true)
	elif stat == "gold":
		if _bound_player != null:
			set_gold(int(_bound_player.gold), true)


func update_from_player(animate: bool = true) -> void:
	_bind_to_player()
	if _bound_player != null:
		set_hp(_bound_player.cur_health, _bound_player.max_health, animate)
		set_gold(int(_bound_player.gold), animate)
	else:
		set_hp(current_hp, max_hp, false)
		set_gold(current_gold, false)


func set_hp(new_hp: float, new_max_hp: float, animate: bool = true) -> void:
	current_hp = new_hp
	max_hp = max(1.0, new_max_hp)

	if hp_label:
		hp_label.text = str(max(0, int(roundf(current_hp))))

	var target_fill: float = clampf(current_hp / max_hp, 0.0, 1.0)
	if not _hp_mat:
		return

	if not animate or not is_inside_tree():
		_hp_mat.set_shader_parameter("fill_amount", target_fill)
		_hp_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		return

	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()

	_hp_tween = create_tween().set_parallel(true)
	var cur_fill: float = float(_hp_mat.get_shader_parameter("fill_amount"))
	_hp_tween.tween_method(
		func(val: float): _hp_mat.set_shader_parameter("fill_amount", val),
		cur_fill, target_fill, 0.35
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Dynamic slosh reaction
	_hp_mat.set_shader_parameter("wave_amplitude", SLOSH_WAVE_AMP)
	var slosh_tween := create_tween()
	slosh_tween.tween_method(
		func(val: float): _hp_mat.set_shader_parameter("wave_amplitude", val),
		SLOSH_WAVE_AMP, BASE_WAVE_AMP, 0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func set_gold(new_gold: int, _animate: bool = true) -> void:
	current_gold = max(0, new_gold)
	if gold_label:
		gold_label.text = str(current_gold)


func set_defenses(new_hp: float, new_max_hp: float, _new_armor: float = 0.0, _new_mystic_armor: float = 0.0, animate: bool = true) -> void:
	set_hp(new_hp, new_max_hp, animate)
