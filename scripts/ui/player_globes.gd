extends Control
class_name PlayerGlobes

## High-performance pixel art liquid HP & Energy globes UI component.
## Displays HP in the left globe (red liquid) and Energy/Moves in the right globe (green liquid).

@onready var hp_liquid: ColorRect = $LiquidContainer/HPLiquid
@onready var energy_liquid: ColorRect = $LiquidContainer/EnergyLiquid
@onready var hp_label: Label = $ValueLabels/HPLabel
@onready var energy_label: Label = $ValueLabels/EnergyLabel

var _hp_mat: ShaderMaterial
var _energy_mat: ShaderMaterial

var _hp_tween: Tween
var _energy_tween: Tween

var current_hp: float = 20.0
var max_hp: float = 20.0
var current_energy: int = 2
var max_energy: int = 2

# Base wave amplitudes
const BASE_WAVE_AMP: float = 0.022
const SLOSH_WAVE_AMP: float = 0.048

func _ready() -> void:
	# Duplicate materials so HP and Energy have independent shader uniforms
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

	# Red Palette (HP)
	if _hp_mat:
		_hp_mat.set_shader_parameter("col_highlight", Color("#F9C22B"))
		_hp_mat.set_shader_parameter("col_base", Color("#E83B3B"))
		_hp_mat.set_shader_parameter("col_shadow", Color("#7A3045"))
		_hp_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		_hp_mat.set_shader_parameter("wave_frequency", 13.0)
		_hp_mat.set_shader_parameter("wave_speed", 3.2)
		_hp_mat.set_shader_parameter("time_offset", 0.0)

	# Green Palette (Energy / Moves)
	if _energy_mat:
		_energy_mat.set_shader_parameter("col_highlight", Color("#FBFF86"))
		_energy_mat.set_shader_parameter("col_base", Color("#1EBC73"))
		_energy_mat.set_shader_parameter("col_shadow", Color("#165A4C"))
		_energy_mat.set_shader_parameter("wave_amplitude", BASE_WAVE_AMP)
		_energy_mat.set_shader_parameter("wave_frequency", 15.0)
		_energy_mat.set_shader_parameter("wave_speed", 3.8)
		_energy_mat.set_shader_parameter("time_offset", 2.7)

	# Set initial visual state
	set_hp(current_hp, max_hp, false)
	set_energy(current_energy, max_energy, false)


func set_hp(new_hp: float, new_max_hp: float, animate: bool = true) -> void:
	current_hp = new_hp
	max_hp = max(1.0, new_max_hp)

	var display_val: int = max(0, int(roundf(current_hp)))
	if hp_label:
		hp_label.text = str(display_val)

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
		SLOSH_WAVE_AMP, BASE_WAVE_AMP, 0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
