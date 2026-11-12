class_name PlayerGlobes
extends Control

## High-performance pixel art liquid HP & Energy globes UI component with stacked defenses.
## Displays HP in the left globe (red liquid), Physical Armor (forged steel plate),
## Magic Armor (animated arcane shield), and Energy/Moves in the right globe (green liquid).

@onready var hp_liquid: ColorRect = $LiquidContainer/HPLiquid
@onready var energy_liquid: ColorRect = $LiquidContainer/EnergyLiquid
@onready var armor_plate: TextureRect = $ArmorPlate
@onready var magic_armor_shield: TextureRect = $MagicArmorShield
@onready var hp_label: Label = $ValueLabels/HPLabel
@onready var energy_label: Label = $ValueLabels/EnergyLabel
@onready var stat_tracker: TextureRect = get_node_or_null("StatTracker")
@onready var gold_label: Label = get_node_or_null("StatTracker/GoldLabel")

var _hp_mat: ShaderMaterial
var _energy_mat: ShaderMaterial
var _armor_mat: ShaderMaterial
var _magic_mat: ShaderMaterial

var _hp_tween: Tween
var _energy_tween: Tween
var _armor_tween: Tween
var _magic_tween: Tween

var current_hp: float = 20.0
var max_hp: float = 20.0
var current_armor: float = 0.0
var current_mystic_armor: float = 0.0
var current_energy: int = 2
var max_energy: int = 2
var current_gold: int = 10

# Base wave amplitudes
const BASE_WAVE_AMP: float = 0.022
const SLOSH_WAVE_AMP: float = 0.048

# Palette Colors (HP)
const HP_HIGHLIGHT := Color("#F9C22B")
const HP_BASE := Color("#E83B3B")
const HP_SHADOW := Color("#7A3045")

# Palette Colors (Energy)
const ENERGY_HIGHLIGHT := Color("#FBFF86")
const ENERGY_BASE := Color("#1EBC73")
const ENERGY_SHADOW := Color("#165A4C")

# Label Colors
const COLOR_HP_TEXT := Color(1.0, 1.0, 1.0)
const COLOR_HP_OUTLINE := Color(0.12, 0.08, 0.15)

const COLOR_ARMOR_TEXT := Color(1.0, 1.0, 1.0)
const COLOR_ARMOR_OUTLINE := Color(0.11, 0.15, 0.22)

const COLOR_MYSTIC_TEXT := Color(0.72, 0.95, 1.0)
const COLOR_MYSTIC_OUTLINE := Color(0.04, 0.10, 0.26)


func _ready() -> void:
	# Duplicate materials so instances have independent shader parameters
	if hp_liquid and hp_liquid.material is ShaderMaterial:
		_hp_mat = hp_liquid.material.duplicate() as ShaderMaterial
		hp_liquid.material = _hp_mat
	elif hp_liquid:
		_hp_mat = ShaderMaterial.new()
		_hp_mat.shader = preload("res://assets/shaders/pixel_liquid_globe.gdshader")
		hp_liquid.material = _hp_mat

	if energy_liquid and energy_liquid.material is ShaderMaterial:
		_energy_mat = energy_liquid.material.duplicate() as ShaderMaterial
		energy_liquid.material = _energy_mat
	elif energy_liquid:
		_energy_mat = ShaderMaterial.new()
		_energy_mat.shader = preload("res://assets/shaders/pixel_liquid_globe.gdshader")
		energy_liquid.material = _energy_mat

	if armor_plate and armor_plate.material is ShaderMaterial:
		_armor_mat = armor_plate.material.duplicate() as ShaderMaterial
		armor_plate.material = _armor_mat

	if magic_armor_shield and magic_armor_shield.material is ShaderMaterial:
		_magic_mat = magic_armor_shield.material.duplicate() as ShaderMaterial
		magic_armor_shield.material = _magic_mat

	# Red Palette (HP)
	if _hp_mat:
		_hp_mat.set_shader_parameter("col_highlight", HP_HIGHLIGHT)
		_hp_mat.set_shader_parameter("col_base", HP_BASE)
		_hp_mat.set_shader_parameter("col_shadow", HP_SHADOW)
		_hp_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		_hp_mat.set_shader_parameter("wave_frequency", 13.0)
		_hp_mat.set_shader_parameter("wave_speed", 3.2)
		_hp_mat.set_shader_parameter("time_offset", 0.0)

	# Green Palette (Energy / Moves)
	if _energy_mat:
		_energy_mat.set_shader_parameter("col_highlight", ENERGY_HIGHLIGHT)
		_energy_mat.set_shader_parameter("col_base", ENERGY_BASE)
		_energy_mat.set_shader_parameter("col_shadow", ENERGY_SHADOW)
		_energy_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		_energy_mat.set_shader_parameter("wave_frequency", 15.0)
		_energy_mat.set_shader_parameter("wave_speed", 3.8)
		_energy_mat.set_shader_parameter("time_offset", 2.7)

	# Set initial visual state
	set_defenses(current_hp, max_hp, current_armor, current_mystic_armor, false)
	set_energy(current_energy, max_energy, false)
	set_gold(current_gold)


func set_defenses(new_hp: float, new_max_hp: float, new_armor: float, new_mystic_armor: float, animate: bool = true) -> void:
	current_hp = new_hp
	max_hp = max(1.0, new_max_hp)
	current_armor = max(0.0, new_armor)
	current_mystic_armor = max(0.0, new_mystic_armor)

	# 1. Update Number Display (Priority: Mystic Armor -> Armor -> Health)
	_update_number_display()

	# 2. Update Red Health Liquid Fill Level
	var target_fill: float = clampf(current_hp / max_hp, 0.0, 1.0)
	if _hp_mat:
		if not animate or not is_inside_tree():
			_hp_mat.set_shader_parameter("fill_amount", target_fill)
			_hp_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		else:
			if _hp_tween and _hp_tween.is_valid():
				_hp_tween.kill()
			_hp_tween = create_tween().set_parallel(true)
			var cur_fill: float = float(_hp_mat.get_shader_parameter("fill_amount"))
			_hp_tween.tween_method(
				func(val: float): _hp_mat.set_shader_parameter("fill_amount", val),
				cur_fill, target_fill, 0.35
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

			_hp_mat.set_shader_parameter("wave_amplitude", SLOSH_WAVE_AMP)
			var slosh_tween := create_tween()
			slosh_tween.tween_method(
				func(val: float): _hp_mat.set_shader_parameter("wave_amplitude", val),
				SLOSH_WAVE_AMP, BASE_WAVE_AMP, 0.6
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 3. Update Stacked Armor Visuals (Steel plate & Mystic shield)
	_update_armor_layers(animate)


func _update_number_display() -> void:
	if not hp_label:
		return

	if current_mystic_armor > 0.0:
		# Mystic Armor is taking incoming damage first
		hp_label.text = str(int(roundf(current_mystic_armor)))
		hp_label.add_theme_color_override("font_color", COLOR_MYSTIC_TEXT)
		hp_label.add_theme_color_override("font_outline_color", COLOR_MYSTIC_OUTLINE)
		hp_label.add_theme_constant_override("outline_size", 4)
	elif current_armor > 0.0:
		# Physical Armor is taking incoming damage
		hp_label.text = str(int(roundf(current_armor)))
		hp_label.add_theme_color_override("font_color", COLOR_ARMOR_TEXT)
		hp_label.add_theme_color_override("font_outline_color", COLOR_ARMOR_OUTLINE)
		hp_label.add_theme_constant_override("outline_size", 5)
	else:
		# Base Health
		hp_label.text = str(max(0, int(roundf(current_hp))))
		hp_label.add_theme_color_override("font_color", COLOR_HP_TEXT)
		hp_label.add_theme_color_override("font_outline_color", COLOR_HP_OUTLINE)
		hp_label.add_theme_constant_override("outline_size", 3)


func _update_armor_layers(animate: bool) -> void:
	var has_armor: bool = current_armor > 0.0
	var has_mystic_armor: bool = current_mystic_armor > 0.0

	# When Mystic Armor is stacked on top of Physical Armor, mask the outer rim of the steel plate
	if _armor_mat:
		_armor_mat.set_shader_parameter("hide_outer_rim", 1.0 if has_mystic_armor else 0.0)

	# Physical Armor Plate Layer
	if armor_plate:
		if _armor_tween and _armor_tween.is_valid():
			_armor_tween.kill()

		if has_armor:
			armor_plate.visible = true
			if animate and is_inside_tree():
				_armor_tween = create_tween()
				_armor_tween.tween_property(armor_plate, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			else:
				armor_plate.modulate.a = 1.0
		else:
			if animate and is_inside_tree() and armor_plate.visible:
				_armor_tween = create_tween()
				_armor_tween.tween_property(armor_plate, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_armor_tween.tween_callback(func(): armor_plate.visible = false)
			else:
				armor_plate.visible = false
				armor_plate.modulate.a = 0.0

	# Mystic Armor Shield Layer
	if magic_armor_shield:
		if _magic_tween and _magic_tween.is_valid():
			_magic_tween.kill()

		if has_mystic_armor:
			magic_armor_shield.visible = true
			if animate and is_inside_tree():
				_magic_tween = create_tween()
				_magic_tween.tween_property(magic_armor_shield, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			else:
				magic_armor_shield.modulate.a = 1.0
		else:
			if animate and is_inside_tree() and magic_armor_shield.visible:
				_magic_tween = create_tween()
				_magic_tween.tween_property(magic_armor_shield, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_magic_tween.tween_callback(func(): magic_armor_shield.visible = false)
			else:
				magic_armor_shield.visible = false
				magic_armor_shield.modulate.a = 0.0


func set_hp(new_hp: float, new_max_hp: float, animate: bool = true) -> void:
	set_defenses(new_hp, new_max_hp, current_armor, current_mystic_armor, animate)


func set_armor(new_armor: float, new_mystic_armor: float, animate: bool = true) -> void:
	set_defenses(current_hp, max_hp, new_armor, new_mystic_armor, animate)


func set_gold(new_gold: int) -> void:
	current_gold = max(0, new_gold)
	if gold_label != null:
		gold_label.text = "%dg" % current_gold


func set_energy(new_energy: int, new_max_energy: int, animate: bool = true) -> void:
	max_energy = max(1, new_max_energy)
	current_energy = clamp(new_energy, 0, max_energy)

	if energy_label:
		energy_label.text = str(current_energy)

	var target_fill: float = clampf(float(current_energy) / float(max_energy), 0.0, 1.0)
	if not _energy_mat:
		return

	if not animate or not is_inside_tree():
		_energy_mat.set_shader_parameter("fill_amount", target_fill)
		_energy_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		return

	if _energy_tween and _energy_tween.is_valid():
		_energy_tween.kill()

	_energy_tween = create_tween().set_parallel(true)
	var cur_fill: float = float(_energy_mat.get_shader_parameter("fill_amount"))
	_energy_tween.tween_method(
		func(val: float): _energy_mat.set_shader_parameter("fill_amount", val),
		cur_fill, target_fill, 0.28
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Dynamic slosh reaction
	_energy_mat.set_shader_parameter("wave_amplitude", SLOSH_WAVE_AMP)
	var slosh_tween := create_tween()
	slosh_tween.tween_method(
		func(val: float): _energy_mat.set_shader_parameter("wave_amplitude", val),
		SLOSH_WAVE_AMP, BASE_WAVE_AMP, 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
