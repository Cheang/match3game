class_name FloatingShardDock
extends Control

## Dedicated dock at the bottom of the Inventory Overlay for new/floating equipment shards.
## Displays the diamond shard hovering with a smooth sinusoidal bob and rising fire/ember particles
## matching the equipment's color. Supports drag-to-slot and drop-to-unequip interactions.

signal shard_selected(eq: Equipment)
signal shard_dropped_on_dock(drag_data: Dictionary)
signal floating_equipment_changed(eq: Equipment)

const TEX_BASIC_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const TITLE_FONT = preload("res://assets/theme/title.ttf")
const DIAMOND_SIZE = Vector2(59, 59)
const DOCK_SIZE = Vector2(520, 84)

var current_equipment: Equipment = null
var _bob_timer: float = 0.0
var _is_hovered: bool = false

var center_container: CenterContainer
var socket_box: PanelContainer
var shard_pivot: Control
var frame_rect: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial
var fire_particles: CPUParticles2D
var hint_label: Label

func _init() -> void:
	custom_minimum_size = DOCK_SIZE
	size = DOCK_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_components()

func _ensure_components() -> void:
	if center_container != null:
		return

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 4)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(main_vbox)

	center_container = CenterContainer.new()
	center_container.custom_minimum_size = Vector2(520, 64)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	main_vbox.add_child(center_container)

	# 1. Subtle Socket Background / Drop Zone
	socket_box = PanelContainer.new()
	socket_box.custom_minimum_size = DIAMOND_SIZE
	socket_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var socket_sb := StyleBoxFlat.new()
	socket_sb.bg_color = Color(0.12, 0.09, 0.15, 0.6)
	socket_sb.border_width_left = 1
	socket_sb.border_width_top = 1
	socket_sb.border_width_right = 1
	socket_sb.border_width_bottom = 1
	socket_sb.border_color = Color(0.48, 0.42, 0.35, 0.5)
	socket_sb.corner_radius_top_left = 4
	socket_sb.corner_radius_top_right = 4
	socket_sb.corner_radius_bottom_left = 4
	socket_sb.corner_radius_bottom_right = 4
	socket_box.add_theme_stylebox_override("panel", socket_sb)
	center_container.add_child(socket_box)

	# 2. Shard Pivot (for sinusoidal bobbing animation & particles)
	shard_pivot = Control.new()
	shard_pivot.custom_minimum_size = DIAMOND_SIZE
	shard_pivot.size = DIAMOND_SIZE
	shard_pivot.mouse_filter = Control.MOUSE_FILTER_PASS
	socket_box.add_child(shard_pivot)

	# 3. Fire Particles (rising flames in shard color)
	_setup_particles()

	# 4. Diamond Frame
	frame_rect = TextureRect.new()
	frame_rect.name = "Frame"
	frame_rect.size = DIAMOND_SIZE
	frame_rect.custom_minimum_size = DIAMOND_SIZE
	frame_rect.texture = TEX_BASIC_UNSELECTED
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = PALETTE_SHADER
	frame_rect.material = shader_mat
	shard_pivot.add_child(frame_rect)

	# 5. Equipment Icon (59x59, full diamond size)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.position = Vector2.ZERO
	icon_rect.size = DIAMOND_SIZE
	icon_rect.custom_minimum_size = DIAMOND_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shard_pivot.add_child(icon_rect)

	# 6. Hint Label below
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_override("font", TITLE_FONT)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74, 0.9))
	hint_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1, 0.95))
	hint_label.add_theme_constant_override("outline_size", 2)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.text = "Drag shard to a slot to equip"
	main_vbox.add_child(hint_label)

	socket_box.gui_input.connect(_on_socket_gui_input)
	socket_box.mouse_entered.connect(_on_mouse_entered)
	socket_box.mouse_exited.connect(_on_mouse_exited)

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
	shard_pivot.add_child(fire_particles)

func set_equipment(eq: Equipment) -> void:
	_ensure_components()
	current_equipment = eq
	_bob_timer = 0.0

	if current_equipment != null:
		var c_id: int = _get_equipment_color(current_equipment)
		_apply_frame_palette(c_id)
		_update_particles_color(c_id)

		frame_rect.visible = true
		icon_rect.visible = (current_equipment.icon != null)
		icon_rect.texture = current_equipment.icon
		fire_particles.emitting = true
		hint_label.text = "Drag shard to a slot to equip • Tap to inspect"
		socket_box.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		frame_rect.visible = false
		icon_rect.visible = false
		icon_rect.texture = null
		fire_particles.emitting = false
		hint_label.text = "Empty socket • Drag an equipped shard here to unequip"
		socket_box.mouse_filter = Control.MOUSE_FILTER_STOP

	floating_equipment_changed.emit(current_equipment)

func _process(delta: float) -> void:
	if not visible or current_equipment == null or shard_pivot == null:
		return
	_bob_timer += delta * 3.5
	shard_pivot.position.y = sin(_bob_timer) * 4.0

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

func _on_socket_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_equipment != null:
			shard_selected.emit(current_equipment)

func _on_mouse_entered() -> void:
	_is_hovered = true
	if current_equipment != null:
		shard_pivot.scale = Vector2(1.05, 1.05)
		shard_pivot.position.x = -1.5

func _on_mouse_exited() -> void:
	_is_hovered = false
	if shard_pivot != null:
		shard_pivot.scale = Vector2.ONE
		shard_pivot.position.x = 0.0

func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_equipment == null:
		return null

	var preview := Control.new()
	var preview_frame := TextureRect.new()
	preview_frame.size = DIAMOND_SIZE
	preview_frame.custom_minimum_size = DIAMOND_SIZE
	preview_frame.texture = TEX_BASIC_UNSELECTED
	preview_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

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
	preview.add_child(preview_frame)

	if current_equipment.icon != null:
		var preview_icon := TextureRect.new()
		preview_icon.position = Vector2.ZERO
		preview_icon.size = DIAMOND_SIZE
		preview_icon.custom_minimum_size = DIAMOND_SIZE
		preview_icon.texture = current_equipment.icon
		preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(preview_icon)

	preview.position = -DIAMOND_SIZE / 2.0
	set_drag_preview(preview)

	return {
		"type": "equipment_drag",
		"modifier": current_equipment,
		"source_track": null,
		"source_is_floating": true,
		"source_is_ult": current_equipment.is_ultimate,
		"source_slot_idx": -1
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "equipment_drag":
		return false
	var mod: Equipment = data.get("modifier") as Equipment
	if mod == null:
		return false
	var src_is_floating: bool = data.get("source_is_floating", false)
	return not src_is_floating

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	shard_dropped_on_dock.emit(data)
