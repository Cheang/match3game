class_name WantedPoster
extends Control

## Interactive wanted poster placed on the Boss Select table.
## Displays wanted_poster_art (falling back to location portrait) on the parchment sheet.

signal poster_clicked(poster: WantedPoster)
signal poster_drag_started(poster: WantedPoster)
signal poster_drag_moved(poster: WantedPoster, target_center: Vector2)
signal poster_drag_ended(poster: WantedPoster)

const CARD_BURN_SHADER: Shader = preload("res://assets/shaders/card_burn.gdshader")
const POSTER_WIDTH: float = 226.0
const SMALL_ART_WIDTH: float = 190.0
const SMALL_ART_MAX_HEIGHT: float = 170.0
const DRAG_THRESHOLD_PX: float = 8.0
const DRAG_LIFT_SCALE: Vector2 = Vector2(1.08, 1.08)
const DRAG_MAX_TILT_RAD: float = 0.14

var boss_location: Location = null
var enemy_resource: EnemyResource = null
var is_interactive: bool = false
var is_dragging: bool = false
var burn_progress: float = 0.0
var _is_hovered: bool = false
var _pointer_down: bool = false
var _press_global_pos: Vector2 = Vector2.ZERO
var _drag_grab_offset: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _hover_tween: Tween = null
var _burn_material: ShaderMaterial = null
var _burn_tween: Tween = null
var _burn_particles: CPUParticles2D = null

@onready var drop_shadow: Control = find_child("DropShadow", true, false) as Control
@onready var poster_body: Control = find_child("PosterBody", true, false) as Control
@onready var fallback_parchment: Control = find_child("FallbackParchment", true, false) as Control
@onready var content_margin: MarginContainer = find_child("ContentMargin", true, false) as MarginContainer
@onready var portrait_box: TextureRect = find_child("PortraitBox", true, false) as TextureRect
@onready var boss_title_label: Label = find_child("BossTitleLabel", true, false) as Label
@onready var click_area: Button = find_child("ClickArea", true, false) as Button


func _ready() -> void:
	pivot_offset = size * 0.5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if click_area != null:
		if not click_area.gui_input.is_connected(_on_click_area_gui_input):
			click_area.gui_input.connect(_on_click_area_gui_input)
		if not click_area.mouse_entered.is_connected(_on_click_area_mouse_entered):
			click_area.mouse_entered.connect(_on_click_area_mouse_entered)
		if not click_area.mouse_exited.is_connected(_on_click_area_mouse_exited):
			click_area.mouse_exited.connect(_on_click_area_mouse_exited)
	_refresh_visuals()


func setup(loc: Location) -> void:
	boss_location = loc
	enemy_resource = null
	if loc != null and not loc.which_enemy.is_empty():
		enemy_resource = loc.which_enemy[0]
	_refresh_visuals()


func set_interactive(enabled: bool) -> void:
	is_interactive = enabled
	if click_area != null:
		click_area.disabled = not enabled
		click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if not enabled:
		if _pointer_down or is_dragging:
			_cancel_drag()
		if _is_hovered:
			_is_hovered = false
			_apply_hover_visuals(false)


func get_resting_rotation() -> float:
	return _base_rotation


func set_center_position(center_pos: Vector2) -> void:
	position = center_pos - pivot_offset


func get_center_position() -> Vector2:
	return position + pivot_offset


func get_top_left_for_center(center_pos: Vector2) -> Vector2:
	return center_pos - pivot_offset


func get_poster_title() -> String:
	if enemy_resource != null:
		if enemy_resource.wanted_title != "":
			return enemy_resource.wanted_title
		if enemy_resource.name != "":
			return enemy_resource.name
	if boss_location != null and boss_location.name != "":
		return boss_location.name
	return "Unknown Threat"


func get_poster_description() -> String:
	if enemy_resource != null and enemy_resource.wanted_description != "":
		return enemy_resource.wanted_description
	if boss_location != null and boss_location.description != "" and boss_location.description != "Lorem Ipsum":
		return boss_location.description
	if enemy_resource != null:
		return "A dangerous creature lurking nearby."
	return "Approach with caution."


func get_inspect_art_texture() -> Texture2D:
	if enemy_resource != null and enemy_resource.wanted_poster_art != null:
		return enemy_resource.wanted_poster_art
	if boss_location != null and boss_location.pic != null:
		return boss_location.pic
	return null


func get_poster_bounty_text() -> String:
	if enemy_resource != null and enemy_resource.wanted_bounty_text != "":
		return enemy_resource.wanted_bounty_text
	if enemy_resource != null:
		return "HP: %d" % int(roundf(enemy_resource.max_health))
	return ""


func update_candle_lighting(candle_global_pos: Vector2, flicker: float, is_zoomed: bool, light_strength: float = 1.0) -> void:
	if poster_body == null:
		return
	if is_zoomed:
		poster_body.modulate = Color.WHITE
		if drop_shadow != null:
			drop_shadow.position = Vector2(12.0, 18.0)
			drop_shadow.modulate = Color(0.05, 0.03, 0.07, 0.70)
		return

	var center_global := global_position + pivot_offset
	var diff := center_global - candle_global_pos
	var dist := diff.length()
	var strength := maxf(0.0, light_strength)
	var f_delta := flicker - 1.0

	var final_tint := Color(0.76, 0.67, 0.72, 1.0)
	if strength > 0.001:
		var r_inner := (152.0 + f_delta * 40.0) * strength
		var r_mid := (392.0 + f_delta * 75.0) * strength
		if dist <= r_inner:
			final_tint = Color(1.06, 0.98, 0.88, 1.0)
		elif dist <= r_mid:
			final_tint = Color(0.98, 0.93, 0.87, 1.0)

	if is_dragging:
		final_tint = final_tint * Color(1.06, 1.05, 1.03, 1.0)
	elif _is_hovered and is_interactive:
		final_tint = final_tint * Color(1.07, 1.07, 1.07, 1.0)
	poster_body.modulate = final_tint

	if drop_shadow != null:
		var dir := diff.normalized() if diff.length_squared() > 1.0 else Vector2(0.7, 0.7)
		if is_dragging:
			drop_shadow.position = (dir * 16.0 + Vector2(0.0, 6.0)).round()
			drop_shadow.modulate = Color(0.04, 0.02, 0.06, 0.45)
		else:
			drop_shadow.position = (dir * lerpf(5.0, 10.0, clampf(dist / 650.0, 0.0, 1.0))).round()
			drop_shadow.modulate = Color(0.05, 0.03, 0.07, 0.56)


func _refresh_visuals() -> void:
	if fallback_parchment == null:
		return

	fallback_parchment.visible = true
	if boss_title_label != null:
		boss_title_label.text = get_poster_title()
	if portrait_box != null:
		var art_tex := get_inspect_art_texture()
		portrait_box.texture = art_tex
		if art_tex != null:
			var tex_size := art_tex.get_size()
			var target_h := 100.0
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				target_h = clampf(roundf(SMALL_ART_WIDTH * (tex_size.y / tex_size.x)), 30.0, SMALL_ART_MAX_HEIGHT)
			portrait_box.custom_minimum_size = Vector2(0.0, target_h)
			portrait_box.visible = true
		else:
			portrait_box.custom_minimum_size = Vector2.ZERO
			portrait_box.visible = false

	_fit_height_to_content()
	if is_inside_tree():
		call_deferred("_fit_height_to_content")


func _fit_height_to_content() -> void:
	if content_margin == null:
		return
	var target_h: float = maxf(100.0, ceilf(content_margin.get_combined_minimum_size().y))
	var prev_center := position + pivot_offset
	size = Vector2(POSTER_WIDTH, target_h)
	pivot_offset = size * 0.5
	position = prev_center - pivot_offset


func _global_to_parent_local(global_pos: Vector2) -> Vector2:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl != null:
		return parent_ctrl.get_global_transform_with_canvas().affine_inverse() * global_pos
	return global_pos


func _cancel_drag() -> void:
	var was_dragging := is_dragging
	_pointer_down = false
	is_dragging = false
	if click_area != null:
		click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_interactive else Control.CURSOR_ARROW
	if was_dragging:
		scale = Vector2.ONE
		rotation = _base_rotation
		z_index = 0


func _on_click_area_gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down = true
			is_dragging = false
			_press_global_pos = event.global_position
			_base_rotation = rotation
			_drag_grab_offset = get_center_position() - _global_to_parent_local(event.global_position)
			click_area.accept_event()
		elif _pointer_down:
			var was_dragging := is_dragging
			_pointer_down = false
			is_dragging = false
			click_area.accept_event()
			if was_dragging:
				click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				if _hover_tween != null and _hover_tween.is_valid():
					_hover_tween.kill()
				_hover_tween = create_tween().set_parallel(true)
				var settle_scale := Vector2(1.06, 1.06) if _is_hovered else Vector2.ONE
				_hover_tween.tween_property(self, "scale", settle_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_hover_tween.tween_property(self, "rotation", _base_rotation, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				poster_drag_ended.emit(self)
			else:
				poster_clicked.emit(self)
	elif event is InputEventMouseMotion and _pointer_down:
		if not is_dragging and event.global_position.distance_to(_press_global_pos) >= DRAG_THRESHOLD_PX:
			is_dragging = true
			click_area.mouse_default_cursor_shape = Control.CURSOR_DRAG
			if _hover_tween != null and _hover_tween.is_valid():
				_hover_tween.kill()
			_hover_tween = create_tween()
			_hover_tween.tween_property(self, "scale", DRAG_LIFT_SCALE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			poster_drag_started.emit(self)
		if is_dragging:
			var target_center := _global_to_parent_local(event.global_position) + _drag_grab_offset
			var target_rot := clampf(_base_rotation + clampf(event.relative.x * 0.004, -DRAG_MAX_TILT_RAD, DRAG_MAX_TILT_RAD), -0.32, 0.32)
			rotation = lerpf(rotation, target_rot, 0.25)
			poster_drag_moved.emit(self, target_center)
			click_area.accept_event()


func _on_click_area_mouse_entered() -> void:
	if not is_interactive:
		return
	_is_hovered = true
	if not is_dragging:
		_apply_hover_visuals(true)


func _on_click_area_mouse_exited() -> void:
	_is_hovered = false
	if not is_dragging:
		_apply_hover_visuals(false)


func _apply_hover_visuals(hovered: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	if not is_interactive and hovered:
		return
	_hover_tween = create_tween()
	var target_scale := Vector2(1.06, 1.06) if (hovered and is_interactive) else Vector2.ONE
	_hover_tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
	var corners: Array[Vector2] = [
		xform * Vector2.ZERO,
		xform * Vector2(size.x, 0.0),
		xform * Vector2(0.0, size.y),
		xform * size,
	]
	var min_pt := corners[0]
	var max_pt := corners[0]
	for pt in corners:
		min_pt.x = minf(min_pt.x, pt.x)
		min_pt.y = minf(min_pt.y, pt.y)
		max_pt.x = maxf(max_pt.x, pt.x)
		max_pt.y = maxf(max_pt.y, pt.y)
	_burn_material.set_shader_parameter("card_canvas_rect", Vector4(min_pt.x, min_pt.y, maxf(1.0, max_pt.x - min_pt.x), maxf(1.0, max_pt.y - min_pt.y)))


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
	p.emission_rect_extents = Vector2(maxf(16.0, size.x * 0.42), maxf(16.0, size.y * 0.40))
	p.amount = 30
	p.lifetime = 0.55
	p.explosiveness = 0.25
	p.one_shot = true
	p.emitting = false
	p.direction = Vector2(0.0, -1.0)
	p.spread = 32.0
	p.gravity = Vector2(0.0, -90.0)
	p.initial_velocity_min = 38.0
	p.initial_velocity_max = 98.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.72, 1.0])
	grad.colors = PackedColorArray([Color("#fee761"), Color("#f77622"), Color("#9e2835"), Color(0.180392, 0.133333, 0.184314, 0.0)])
	p.color_ramp = grad
	add_child(p)
	_burn_particles = p
