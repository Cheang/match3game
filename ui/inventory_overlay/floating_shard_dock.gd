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
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const DIAMOND_SIZE = Vector2(59, 59)
const DOCK_SIZE = Vector2(90, 160)

var current_equipment: Equipment = null
var _bob_timer: float = 0.0
var is_shard_hidden: bool = false

var shard_item: FloatingShardItem
var frame_rect: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial
var fire_particles: CPUParticles2D

func _init() -> void:
	custom_minimum_size = DOCK_SIZE
	size = DOCK_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_components()

func _ensure_components() -> void:
	if shard_item != null:
		return

	# Centered floating shard item (no socket background box, no label text)
	shard_item = FloatingShardItem.new(self)
	shard_item.name = "FloatingShardItem"
	var base_x: float = (DOCK_SIZE.x - DIAMOND_SIZE.x) / 2.0
	var base_y: float = (DOCK_SIZE.y - DIAMOND_SIZE.y) / 2.0
	shard_item.position = Vector2(base_x, base_y)
	add_child(shard_item)

	# 1. Fire Particles (rising flames in shard color)
	_setup_particles()

	# 2. Diamond Frame (59x59)
	frame_rect = TextureRect.new()
	frame_rect.name = "Frame"
	frame_rect.size = DIAMOND_SIZE
	frame_rect.custom_minimum_size = DIAMOND_SIZE
	frame_rect.texture = TEX_BASIC_UNSELECTED
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = PALETTE_SHADER
	frame_rect.material = shader_mat
	shard_item.add_child(frame_rect)

	# 3. Equipment Icon (59x59, full diamond size, pixel-perfect unaltered artwork)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.position = Vector2.ZERO
	icon_rect.size = DIAMOND_SIZE
	icon_rect.custom_minimum_size = DIAMOND_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shard_item.add_child(icon_rect)

func _setup_particles() -> void:
	fire_particles = CPUParticles2D.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = false
	fire_particles.amount = 32
	fire_particles.lifetime = 0.75
	fire_particles.lifetime_randomness = 0.35
	fire_particles.speed_scale = 1.0
	fire_particles.direction = Vector2(0, -1)
	fire_particles.spread = 24.0
	fire_particles.gravity = Vector2(0, -55.0)
	fire_particles.initial_velocity_min = 28.0
	fire_particles.initial_velocity_max = 58.0
	fire_particles.scale_amount_min = 2.0
	fire_particles.scale_amount_max = 4.5
	fire_particles.position = Vector2(29.5, 38.0)
	fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire_particles.emission_rect_extents = Vector2(14.0, 6.0)
	shard_item.add_child(fire_particles)

func set_shard_hidden(hidden: bool) -> void:
	is_shard_hidden = hidden
	if shard_item != null:
		shard_item.visible = not hidden and (current_equipment != null)

func set_equipment(eq: Equipment) -> void:
	_ensure_components()
	current_equipment = eq
	_bob_timer = 0.0

	if current_equipment != null:
		var c_id: int = _get_equipment_color(current_equipment)
		_apply_frame_palette(c_id)
		_update_particles_color(c_id)

		shard_item.visible = not is_shard_hidden
		frame_rect.visible = true
		icon_rect.visible = (current_equipment.icon != null)
		icon_rect.texture = current_equipment.icon
		fire_particles.emitting = true
	else:
		shard_item.visible = false
		frame_rect.visible = false
		icon_rect.visible = false
		icon_rect.texture = null
		fire_particles.emitting = false

	floating_equipment_changed.emit(current_equipment)

func _process(delta: float) -> void:
	if not visible or current_equipment == null or shard_item == null:
		return
	_bob_timer += delta * 3.5
	var base_x: float = (DOCK_SIZE.x - DIAMOND_SIZE.x) / 2.0
	var base_y: float = (DOCK_SIZE.y - DIAMOND_SIZE.y) / 2.0
	shard_item.position = Vector2(base_x, base_y + sin(_bob_timer) * 4.0)

func _get_equipment_color(eq: Equipment) -> int:
	if eq == null or eq.is_colorless():
		return 100
	var eff: Array[int] = eq.get_effective_allowed_colors()
	return eff[0] if not eff.is_empty() else 100

func _apply_frame_palette(c_id: int) -> void:
	if shader_mat == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	shader_mat.set_shader_parameter("target_color_1", pal.highlight)
	shader_mat.set_shader_parameter("target_color_2", pal.lightbase)
	shader_mat.set_shader_parameter("target_color_3", pal.base)
	shader_mat.set_shader_parameter("target_color_4", pal.shadebase)
	shader_mat.set_shader_parameter("target_color_5", pal.deepshade)

func _update_particles_color(c_id: int) -> void:
	if fire_particles == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	var grad := Gradient.new()
	grad.set_color(0, Color(pal.highlight.r, pal.highlight.g, pal.highlight.b, 1.0))
	grad.add_point(0.35, Color(pal.lightbase.r, pal.lightbase.g, pal.lightbase.b, 0.9))
	grad.add_point(0.7, Color(pal.base.r, pal.base.g, pal.base.b, 0.6))
	grad.set_color(1, Color(pal.deepshade.r, pal.deepshade.g, pal.deepshade.b, 0.0))
	fire_particles.color_ramp = grad

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

func _can_drop_data(at_pos: Vector2, data: Variant) -> bool:
	return can_drop_on_dock(at_pos, data)

func _drop_data(at_pos: Vector2, data: Variant) -> void:
	drop_on_dock(at_pos, data)


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

	func _get_drag_data(at_position: Vector2) -> Variant:
		if dock_ref != null:
			return dock_ref.get_floating_drag_data(at_position)
		return null

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		if dock_ref != null:
			return dock_ref.can_drop_on_dock(at_position, data)
		return false

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if dock_ref != null:
			dock_ref.drop_on_dock(at_position, data)
