class_name FloatingShardDock
extends Control

## Dedicated dock at the bottom of the Inventory Overlay for new/floating equipment shards.
## Displays ONLY the floating diamond shard hovering with a smooth sinusoidal bob and rising fire/ember
## particles matching the equipment's color. No square box, no text.
## Supports direct drag-and-drop to slots and drop-to-unequip interactions.

signal shard_selected(eq: Equipment)
signal drag_requested(eq: Equipment, mouse_pos: Vector2)
signal shard_dropped_on_dock(drag_data: Dictionary)
signal floating_equipment_changed(eq: Equipment)

const TEX_BASIC_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_unselected.png")
const TEX_ULT_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_ult_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const PixelFireParticlesClass = preload("res://ui/inventory_overlay/pixel_fire_particles.gd")
const DIAMOND_SIZE = Vector2(59, 59)
const ULT_SIZE = Vector2(83, 59)
const DOCK_SIZE = Vector2(168, 168)
const MAX_STACK = 5
const STACK_OFFSET_X = 7.0

var current_equipment: Equipment = null
var _bob_timer: float = 0.0
var _jolt_timers: Array[float] = []
var _jolt_offsets: Array[Vector2] = []
var _stack_count: int = 1
var is_shard_hidden: bool = false

var shard_item: FloatingShardItem
var stack_frames: Array[TextureRect] = []
var frame_rect: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial
var fire_particles: Node2D

func _init() -> void:
	custom_minimum_size = DOCK_SIZE
	size = DOCK_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_components()
	set_process(current_equipment != null)

func _ensure_components() -> void:
	if shard_item != null:
		return

	# Centered floating shard item (no socket background box, no label text)
	shard_item = FloatingShardItem.new(self)
	shard_item.name = "FloatingShardItem"
	shard_item.pivot_offset = DIAMOND_SIZE / 2.0
	shard_item.scale = Vector2(2.0, 2.0)
	var base_x: float = (DOCK_SIZE.x - DIAMOND_SIZE.x) / 2.0
	var base_y: float = (DOCK_SIZE.y - DIAMOND_SIZE.y) / 2.0
	shard_item.position = Vector2(base_x, base_y)
	add_child(shard_item)

	# 1. Fire Particles (rising flames in shard color)
	_setup_particles()

	# 2. Stacked Diamond Frames (back shards first so index 0 is front-most)
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = PALETTE_SHADER
	stack_frames.clear()
	_jolt_timers.clear()
	_jolt_offsets.clear()
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
		shard_item.add_child(f)
	# Store in front-to-back order (0 = front-most)
	for i in range(MAX_STACK):
		var node := shard_item.get_node("Frame_%d" % i) as TextureRect
		stack_frames.append(node)
		_jolt_timers.append(randf_range(0.2, 1.0))
		_jolt_offsets.append(Vector2.ZERO)
	frame_rect = stack_frames[0]

	# 3. Equipment Icon (attached to front-most shard frame so it moves with frame 0)
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

func _setup_particles() -> void:
	fire_particles = PixelFireParticlesClass.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = false
	fire_particles.local_coords = true
	fire_particles.spawn_rate = 135.0
	fire_particles.max_particles = 160
	fire_particles.position = Vector2(29.0, 34.0)
	fire_particles.emission_rect_extents = Vector2(18.0, 8.0)
	shard_item.add_child(fire_particles)

func set_shard_hidden(hidden: bool) -> void:
	is_shard_hidden = hidden
	if shard_item != null:
		shard_item.visible = not hidden and (current_equipment != null)
	if not hidden:
		for i in range(stack_frames.size()):
			if stack_frames[i] != null:
				stack_frames[i].visible = (current_equipment != null and i < _stack_count)

func set_shard_slot_hidden(idx: int, hidden: bool) -> void:
	if idx >= 0 and idx < stack_frames.size() and stack_frames[idx] != null:
		stack_frames[idx].visible = (not hidden) and (current_equipment != null and idx < _stack_count)

func get_shard_global_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(_stack_count):
		if i < stack_frames.size() and stack_frames[i] != null:
			result.append(stack_frames[i].global_position)
	return result

func set_equipment(eq: Equipment) -> void:
	_ensure_components()
	current_equipment = eq
	_bob_timer = 0.0
	var is_ult: bool = (eq != null and eq.is_ultimate)
	_stack_count = 1 if is_ult else (clampi(eq.slot_cost, 1, MAX_STACK) if eq != null else 1)

	if current_equipment != null:
		var c_id: int = _get_equipment_color(current_equipment)
		_apply_frame_palette(c_id)
		_update_particles_color(c_id)

		var sz: Vector2 = ULT_SIZE if is_ult else DIAMOND_SIZE
		shard_item.size = sz
		shard_item.custom_minimum_size = sz
		shard_item.pivot_offset = sz / 2.0
		frame_rect.size = sz
		frame_rect.custom_minimum_size = sz
		frame_rect.texture = TEX_ULT_UNSELECTED if is_ult else TEX_BASIC_UNSELECTED
		icon_rect.size = sz
		icon_rect.custom_minimum_size = sz
		fire_particles.position = Vector2(41.0, 34.0) if is_ult else Vector2(29.0, 34.0)
		fire_particles.emission_rect_extents = Vector2(26.0, 8.0) if is_ult else Vector2(18.0, 8.0)

		shard_item.visible = not is_shard_hidden
		var center_shift: float = -float(_stack_count - 1) * STACK_OFFSET_X * 0.5
		for i in range(stack_frames.size()):
			var f: TextureRect = stack_frames[i]
			if f != null:
				f.visible = (i < _stack_count)
				if i > 0:
					f.size = DIAMOND_SIZE
					f.custom_minimum_size = DIAMOND_SIZE
					f.texture = TEX_BASIC_UNSELECTED
				f.position = Vector2(center_shift + float(i) * STACK_OFFSET_X, 0.0)
				_jolt_offsets[i] = Vector2.ZERO
		icon_rect.visible = (current_equipment.icon != null)
		icon_rect.texture = current_equipment.icon
		fire_particles.emitting = true
		set_process(true)
	else:
		shard_item.visible = false
		for f in stack_frames:
			if f != null:
				f.visible = false
		icon_rect.visible = false
		icon_rect.texture = null
		fire_particles.emitting = false
		set_process(false)

	floating_equipment_changed.emit(current_equipment)

func _process(delta: float) -> void:
	if not visible or current_equipment == null or shard_item == null:
		return
	_bob_timer += delta * 3.5

	var cur_w: float = size.x if size.x > 0.0 else DOCK_SIZE.x
	var cur_h: float = size.y if size.y > 0.0 else DOCK_SIZE.y
	var item_sz: Vector2 = shard_item.size
	var base_x: float = (cur_w - item_sz.x) / 2.0
	var base_y: float = (cur_h - item_sz.y) / 2.0
	shard_item.position = Vector2(roundf(base_x), roundf(base_y))

	var center_shift: float = -float(_stack_count - 1) * STACK_OFFSET_X * 0.5
	for i in range(_stack_count):
		if i >= stack_frames.size() or stack_frames[i] == null:
			continue
		_jolt_timers[i] -= delta
		if _jolt_timers[i] <= 0.0:
			_jolt_timers[i] = randf_range(0.45, 1.15)
			var angle := randf_range(0.0, TAU)
			var strength := randf_range(1.0, 2.0)
			_jolt_offsets[i] = Vector2(cos(angle), sin(angle)) * strength
		else:
			_jolt_offsets[i] = _jolt_offsets[i].lerp(Vector2.ZERO, minf(1.0, delta * 18.0))

		var phase := float(i) * 1.35
		var bob_y := sin(_bob_timer + phase) * 3.5
		stack_frames[i].position = Vector2(
			roundf(center_shift + float(i) * STACK_OFFSET_X + _jolt_offsets[i].x),
			roundf(bob_y + _jolt_offsets[i].y)
		)

func _get_equipment_color(eq: Equipment) -> int:
	if eq == null or eq.is_colorless():
		return 100
	var eff: Array[int] = eq.get_effective_allowed_colors()
	return eff[0] if not eff.is_empty() else 100

func _apply_frame_palette(c_id: int) -> void:
	OverlaySlotUI.apply_palette(shader_mat, c_id)

func _update_particles_color(c_id: int) -> void:
	if fire_particles == null:
		return
	fire_particles.set_palette_for_color(c_id)

func get_floating_drag_data(_at_position: Vector2) -> Variant:
	if current_equipment == null:
		return null

	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = -DIAMOND_SIZE / 2.0
	preview_root.add_child(inner)

	var preview_frame := TextureRect.new()
	preview_frame.size = DIAMOND_SIZE
	preview_frame.custom_minimum_size = DIAMOND_SIZE
	preview_frame.texture = TEX_BASIC_UNSELECTED
	preview_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var s_mat := ShaderMaterial.new()
	s_mat.shader = PALETTE_SHADER
	var c_id: int = _get_equipment_color(current_equipment)
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	s_mat.set_shader_parameter("target_color_1", pal.highlight)
	s_mat.set_shader_parameter("target_color_2", pal.lightbase)
	s_mat.set_shader_parameter("target_color_3", pal.base)
	s_mat.set_shader_parameter("target_color_4", pal.shadebase)
	s_mat.set_shader_parameter("target_color_5", pal.deepshade)
	preview_frame.material = s_mat
	inner.add_child(preview_frame)

	if current_equipment.icon != null:
		var preview_icon := TextureRect.new()
		preview_icon.position = Vector2.ZERO
		preview_icon.size = DIAMOND_SIZE
		preview_icon.custom_minimum_size = DIAMOND_SIZE
		preview_icon.texture = current_equipment.icon
		preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		inner.add_child(preview_icon)

	if shard_item.is_inside_tree() and shard_item.get_viewport() != null and shard_item.get_viewport().gui_is_dragging():
		shard_item.set_drag_preview(preview_root)
	elif not (shard_item.is_inside_tree() and shard_item.get_viewport() != null and shard_item.get_viewport().gui_is_dragging()):
		preview_root.queue_free()

	return {
		"type": "equipment_drag",
		"modifier": current_equipment,
		"source_track": null,
		"source_is_floating": true,
		"source_is_ult": current_equipment.is_ultimate,
		"source_slot_idx": -1
	}

func can_drop_on_dock(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "equipment_drag":
		return false
	var mod: Equipment = data.get("modifier") as Equipment
	if mod == null:
		return false
	var src_is_floating: bool = data.get("source_is_floating", false)
	return not src_is_floating

func drop_on_dock(_at_position: Vector2, data: Variant) -> void:
	shard_dropped_on_dock.emit(data)


## Direct interactive control for the floating shard diamond.
class FloatingShardItem extends Control:
	var dock_ref: FloatingShardDock = null

	func _init(dock: FloatingShardDock) -> void:
		dock_ref = dock
		custom_minimum_size = FloatingShardDock.DIAMOND_SIZE
		size = FloatingShardDock.DIAMOND_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if dock_ref != null and dock_ref.current_equipment != null:
				dock_ref.drag_requested.emit(dock_ref.current_equipment, event.global_position)
				accept_event()

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if dock_ref != null:
			dock_ref.drop_on_dock(at_position, data)
