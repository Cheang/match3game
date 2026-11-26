class_name LocationCard
extends Control

signal location_selected(card: LocationCard)

const CARD_BURN_SHADER: Shader = preload("res://assets/shaders/card_burn.gdshader")

@export var index: int = 0

var loc_res: Location
var selected: bool = false
var is_interactive: bool = true
var burn_progress: float = 0.0

var _burn_material: ShaderMaterial = null
var _burn_tween: Tween = null
var _burn_particles: CPUParticles2D = null

@onready var loc_texture: TextureRect = $MarginContainer/HBoxContainer/loc_texture
@onready var loc_name_l: Label = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/loc_name
@onready var loc_description_l: Label = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/loc_decription
@onready var selection_btn: TextureButton = $selection_btn


func _ready() -> void:
	if selection_btn != null:
		if not selection_btn.mouse_entered.is_connected(_on_btn_mouse_entered):
			selection_btn.mouse_entered.connect(_on_btn_mouse_entered)
		if not selection_btn.mouse_exited.is_connected(_on_btn_mouse_exited):
			selection_btn.mouse_exited.connect(_on_btn_mouse_exited)


func load_btn() -> void:
	modulate = Color(1.0, 1.0, 1.0, modulate.a)
	loc_texture.texture = loc_res.pic if loc_res.pic else null
	loc_name_l.text = loc_res.name
	loc_description_l.text = loc_res.description


func set_interactive(enabled: bool) -> void:
	is_interactive = enabled
	if selection_btn != null:
		selection_btn.disabled = not enabled
		selection_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if not enabled:
		modulate = Color(1.0, 1.0, 1.0, modulate.a)


func _on_btn_mouse_entered() -> void:
	if is_interactive and not selected:
		modulate = Color(1.07, 1.07, 1.07, modulate.a)


func _on_btn_mouse_exited() -> void:
	modulate = Color(1.0, 1.0, 1.0, modulate.a)


func _on_selection_btn_pressed() -> void:
	if not is_interactive or selected or not Global.game_is_played or loc_res == null or loc_res.next_scene == null:
		return
	if not location_selected.get_connections().is_empty():
		location_selected.emit(self)
	else:
		commit_transition(true)


func commit_transition(trigger_scene_change: bool = true) -> String:
	if loc_res == null:
		return ""
	var destination_scene: String = loc_res.next_scene
	if loc_res.enemy_encounter:
		var enemy_chosen: EnemyResource = null
		if not loc_res.which_enemy.is_empty():
			enemy_chosen = loc_res.which_enemy.pick_random()
		Global.set_up_enemy(enemy_chosen)
		destination_scene = "res://scenes/combat/combat_screen.tscn"
	elif loc_res.event_encounter and loc_res.event_resource:
		Global.area_cur_event = loc_res.event_resource
		destination_scene = "res://scenes/events/event_screen.tscn"
	selected = true
	modulate = Color.WHITE
	Global.game_is_played = false
	if trigger_scene_change and destination_scene != "":
		SceneManager.change_scene(destination_scene, {
			"pattern": "fade",
			"color": loc_res.transition_color,
			"speed": 3.5,
			"wait_time": 0.05,
		})
	return destination_scene


func play_burn_animation(duration: float = 0.62, delay: float = 0.0, seed_val: float = 1.0) -> Tween:
	set_interactive(false)
	_burn_material = ShaderMaterial.new()
	_burn_material.shader = CARD_BURN_SHADER
	_burn_material.set_shader_parameter("burn_seed", seed_val)
	_burn_material.set_shader_parameter("burn_progress", 0.0)
	_update_burn_canvas_rect()

	material = _burn_material
	_apply_use_parent_material(self, true)
	_ensure_burn_particles()

	if _burn_tween != null and _burn_tween.is_valid():
		_burn_tween.kill()
	burn_progress = 0.0
	_burn_tween = create_tween()
	if delay > 0.0:
		_burn_tween.tween_interval(delay)
	_burn_tween.tween_callback(func():
		if _burn_particles != null:
			_burn_particles.position = size * 0.5
			_burn_particles.emitting = true
	)
	_burn_tween.tween_method(_set_burn_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return _burn_tween


func _set_burn_progress(value: float) -> void:
	burn_progress = clampf(value, 0.0, 1.0)
	_update_burn_canvas_rect()
	if _burn_material != null:
		_burn_material.set_shader_parameter("burn_progress", burn_progress)


func _update_burn_canvas_rect() -> void:
	if _burn_material == null:
		return
	var xform := get_global_transform_with_canvas()
	var p0 := xform * Vector2.ZERO
	var p1 := xform * size
	_burn_material.set_shader_parameter("card_canvas_rect", Vector4(p0.x, p0.y, maxf(1.0, p1.x - p0.x), maxf(1.0, p1.y - p0.y)))


func _apply_use_parent_material(root_node: Node, enabled: bool) -> void:
	for child in root_node.get_children():
		if child is CanvasItem and child != _burn_particles:
			(child as CanvasItem).use_parent_material = enabled
		_apply_use_parent_material(child, enabled)


func _ensure_burn_particles() -> void:
	if _burn_particles != null and is_instance_valid(_burn_particles):
		return
	var p := CPUParticles2D.new()
	p.name = "BurnEmbers"
	p.use_parent_material = false
	p.z_index = 2
	p.position = size * 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(maxf(20.0, size.x * 0.44), maxf(16.0, size.y * 0.36))
	p.amount = 36
	p.lifetime = 0.55
	p.explosiveness = 0.25
	p.one_shot = true
	p.emitting = false
	p.direction = Vector2(0.0, -1.0)
	p.spread = 32.0
	p.gravity = Vector2(0.0, -90.0)
	p.initial_velocity_min = 42.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.72, 1.0])
	grad.colors = PackedColorArray([Color("#fee761"), Color("#f77622"), Color("#9e2835"), Color(0.180392, 0.133333, 0.184314, 0.0)])
	p.color_ramp = grad
	add_child(p)
	_burn_particles = p


func _on_tree_exiting() -> void:
	if selected and index >= 0 and index < Global.area_locations.size():
		Global.area_locations.pop_at(index)
