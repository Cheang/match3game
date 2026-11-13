class_name DragAvatar
extends Control

## Visual drag avatar that follows the cursor during custom equipment dragging.
## Displays the diamond/ultimate frame, equipment icon, and LIVE rising fire particles
## that trail behind the cursor in real-time.

const TEX_BASIC_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_unselected.png")
const TEX_ULT_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_ult_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const PixelFireParticlesClass = preload("res://ui/inventory_overlay/pixel_fire_particles.gd")
const DIAMOND_SIZE = Vector2(59, 59)
const ULT_SIZE = Vector2(83, 59)
const MAX_STACK = 5
const STACK_OFFSET_X = 7.0

var current_equipment: Equipment = null
var stack_frames: Array[TextureRect] = []
var frame_rect: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial
var fire_particles: Node2D
var _return_tween: Tween = null
var _group_tween: Tween = null
var _group_progress: float = 1.0
var _group_start_offsets: Array[Vector2] = []
var _bob_timer: float = 0.0
var _jolt_timers: Array[float] = []
var _jolt_offsets: Array[Vector2] = []
var _stack_count: int = 1
var _active_return_cleanup: Callable = Callable()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	visible = false
	set_process(false)
	_build_ui()

func _build_ui() -> void:
	# 1. Fire Particles (pixel-grid-aligned rising flames, trailing in world space)
	fire_particles = PixelFireParticlesClass.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = false
	fire_particles.local_coords = false # Leaves trails behind moving cursor!
	fire_particles.spawn_rate = 155.0
	fire_particles.max_particles = 180
	fire_particles.position = Vector2(29.0, 34.0)
	fire_particles.emission_rect_extents = Vector2(18.0, 8.0)
	add_child(fire_particles)

	# 2. Stacked Diamond Frames (back shards first so index 0 is front-most)
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = PALETTE_SHADER
	stack_frames.clear()
	_jolt_timers.clear()
	_jolt_offsets.clear()
	_group_start_offsets.clear()
	for i in range(MAX_STACK - 1, -1, -1):
		var f := TextureRect.new()
		f.name = "Frame_%d" % i
		f.size = DIAMOND_SIZE
		f.custom_minimum_size = DIAMOND_SIZE
		f.texture = TEX_BASIC_UNSELECTED
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		f.material = shader_mat
		f.visible = (i == 0)
		add_child(f)
	for i in range(MAX_STACK):
		var node := get_node("Frame_%d" % i) as TextureRect
		stack_frames.append(node)
		_jolt_timers.append(randf_range(0.2, 1.0))
		_jolt_offsets.append(Vector2.ZERO)
		_group_start_offsets.append(Vector2.ZERO)
	frame_rect = stack_frames[0]

	# 3. Equipment Icon (attached to front-most frame)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.position = Vector2.ZERO
	icon_rect.size = DIAMOND_SIZE
	icon_rect.custom_minimum_size = DIAMOND_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_rect.add_child(icon_rect)

func get_shard_global_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(_stack_count):
		if i < stack_frames.size() and stack_frames[i] != null:
			result.append(stack_frames[i].global_position)
	return result

func start_drag(eq: Equipment, start_mouse_pos: Vector2, color_override: int = -1, source_slot_positions: Array[Vector2] = []) -> void:
	_cancel_active_return()
	if _group_tween != null:
		_group_tween.kill()
		_group_tween = null
	if eq == null:
		return
	current_equipment = eq
	_bob_timer = 0.0
	var is_ult: bool = eq.is_ultimate
	_stack_count = 1 if is_ult else clampi(eq.slot_cost, 1, MAX_STACK)
	var sz: Vector2 = ULT_SIZE if is_ult else DIAMOND_SIZE
	size = sz
	custom_minimum_size = sz

	frame_rect.size = sz
	frame_rect.custom_minimum_size = sz
	frame_rect.texture = TEX_ULT_UNSELECTED if is_ult else TEX_BASIC_UNSELECTED

	for i in range(stack_frames.size()):
		var f: TextureRect = stack_frames[i]
		if f != null:
			f.visible = (i < _stack_count)
			if i > 0:
				f.size = DIAMOND_SIZE
				f.custom_minimum_size = DIAMOND_SIZE
				f.texture = TEX_BASIC_UNSELECTED

	icon_rect.size = sz
	icon_rect.custom_minimum_size = sz
	icon_rect.texture = eq.icon
	icon_rect.visible = (eq.icon != null)

	var c_id: int = color_override
	if c_id <= 0:
		var eff: Array[int] = eq.get_effective_allowed_colors()
		c_id = eff[0] if not eff.is_empty() else 100

	_apply_palette(c_id)
	_update_particles(c_id, is_ult)

	global_position = start_mouse_pos - sz / 2.0
	visible = true
	fire_particles.emitting = true
	fire_particles.restart()
	set_process(not is_ult)

	# If picked up from multiple track slots, animate the shards grouping up into the stack
	if _stack_count > 1 and source_slot_positions.size() >= _stack_count and is_inside_tree():
		_group_progress = 0.0
		var center_shift: float = -float(_stack_count - 1) * STACK_OFFSET_X * 0.5
		for i in range(_stack_count):
			var target_local := Vector2(center_shift + float(i) * STACK_OFFSET_X, 0.0)
			var start_local := source_slot_positions[i] - global_position
			_group_start_offsets[i] = start_local - target_local
			stack_frames[i].position = start_local
		_group_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_group_tween.tween_property(self, "_group_progress", 1.0, 0.18)
	else:
		_group_progress = 1.0
		var center_shift: float = -float(_stack_count - 1) * STACK_OFFSET_X * 0.5
		for i in range(_stack_count):
			_group_start_offsets[i] = Vector2.ZERO
			stack_frames[i].position = Vector2(center_shift + float(i) * STACK_OFFSET_X, 0.0)

func _process(delta: float) -> void:
	if not visible or current_equipment == null or current_equipment.is_ultimate:
		return
	_bob_timer += delta * 4.0
	var center_shift: float = -float(_stack_count - 1) * STACK_OFFSET_X * 0.5
	var inv_group: float = 1.0 - _group_progress
	for i in range(_stack_count):
		if i >= stack_frames.size() or stack_frames[i] == null:
			continue
		_jolt_timers[i] -= delta
		if _jolt_timers[i] <= 0.0:
			_jolt_timers[i] = randf_range(0.45, 1.15)
			var angle := randf_range(0.0, TAU)
			var strength := randf_range(0.8, 1.6)
			_jolt_offsets[i] = Vector2(cos(angle), sin(angle)) * strength
		else:
			_jolt_offsets[i] = _jolt_offsets[i].lerp(Vector2.ZERO, minf(1.0, delta * 18.0))

		var bob_y: float = sin(_bob_timer + float(i) * 1.35) * 2.5 * _group_progress
		var base_pos := Vector2(center_shift + float(i) * STACK_OFFSET_X, 0.0) + _group_start_offsets[i] * inv_group
		stack_frames[i].position = Vector2(
			roundf(base_pos.x + _jolt_offsets[i].x * _group_progress),
			roundf(base_pos.y + bob_y + _jolt_offsets[i].y * _group_progress)
		)

func update_position(mouse_pos: Vector2) -> void:
	var sz: Vector2 = ULT_SIZE if (current_equipment != null and current_equipment.is_ultimate) else DIAMOND_SIZE
	global_position = mouse_pos - sz / 2.0

func is_returning() -> bool:
	return _return_tween != null and _return_tween.is_valid()

func return_to(target_global_pos: Vector2, on_complete: Callable = Callable()) -> void:
	_cancel_active_return()
	_active_return_cleanup = on_complete
	var dist: float = global_position.distance_to(target_global_pos)
	if dist < 4.0 or not is_inside_tree():
		_finish_return()
		return

	var dur: float = clampf(dist / 1200.0, 0.14, 0.28)
	_return_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(self, "global_position", target_global_pos, dur)
	_return_tween.tween_callback(_finish_return)

func _finish_return() -> void:
	_return_tween = null
	var cb: Callable = _active_return_cleanup
	_active_return_cleanup = Callable()
	visible = false
	set_process(false)
	fire_particles.emitting = false
	current_equipment = null
	if cb.is_valid():
		cb.call()

func _cancel_active_return() -> void:
	if _return_tween != null:
		_return_tween.kill()
		_return_tween = null
	if _active_return_cleanup.is_valid():
		var cb: Callable = _active_return_cleanup
		_active_return_cleanup = Callable()
		cb.call()

func end_drag() -> void:
	_cancel_active_return()
	visible = false
	set_process(false)
	fire_particles.emitting = false
	current_equipment = null

func _apply_palette(c_id: int) -> void:
	OverlaySlotUI.apply_palette(shader_mat, c_id)

func _update_particles(c_id: int, is_ult: bool) -> void:
	if fire_particles == null:
		return
	fire_particles.set_palette_for_color(c_id)

	if is_ult:
		fire_particles.position = Vector2(41.0, 34.0)
		fire_particles.emission_rect_extents = Vector2(26.0, 8.0)
	else:
		fire_particles.position = Vector2(29.0, 34.0)
		fire_particles.emission_rect_extents = Vector2(18.0, 8.0)
