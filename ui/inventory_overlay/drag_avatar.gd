class_name DragAvatar
extends Control

## Visual drag avatar that follows the cursor during custom equipment dragging.
## Displays the diamond/ultimate frame, equipment icon, and LIVE rising fire particles
## that trail behind the cursor in real-time.

const TEX_BASIC_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_unselected.png")
const TEX_ULT_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_ult_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const DIAMOND_SIZE = Vector2(59, 59)
const ULT_SIZE = Vector2(83, 59)

var current_equipment: Equipment = null
var frame_rect: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial
var fire_particles: CPUParticles2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	visible = false
	_build_ui()

func _build_ui() -> void:
	# 1. Fire Particles (rising flames in shard color, trailing in world space)
	fire_particles = CPUParticles2D.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = false
	fire_particles.amount = 56
	fire_particles.lifetime = 0.75
	fire_particles.lifetime_randomness = 0.35
	fire_particles.speed_scale = 1.0
	fire_particles.direction = Vector2(0, -1)
	fire_particles.spread = 26.0
	fire_particles.gravity = Vector2(0, -60.0)
	fire_particles.initial_velocity_min = 35.0
	fire_particles.initial_velocity_max = 65.0
	fire_particles.scale_amount_min = 1.0
	fire_particles.scale_amount_max = 1.0
	fire_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire_particles.position = Vector2(29.5, 38.0)
	fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire_particles.emission_rect_extents = Vector2(14.0, 6.0)
	fire_particles.local_coords = false # Leaves trails behind moving cursor!
	add_child(fire_particles)

	# 2. Diamond Frame
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
	add_child(frame_rect)

	# 3. Equipment Icon
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.position = Vector2.ZERO
	icon_rect.size = DIAMOND_SIZE
	icon_rect.custom_minimum_size = DIAMOND_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(icon_rect)

func start_drag(eq: Equipment, start_mouse_pos: Vector2, color_override: int = -1) -> void:
	if eq == null:
		return
	current_equipment = eq
	var is_ult: bool = eq.is_ultimate
	var sz: Vector2 = ULT_SIZE if is_ult else DIAMOND_SIZE
	size = sz
	custom_minimum_size = sz

	frame_rect.size = sz
	frame_rect.custom_minimum_size = sz
	frame_rect.texture = TEX_ULT_UNSELECTED if is_ult else TEX_BASIC_UNSELECTED

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

func update_position(mouse_pos: Vector2) -> void:
	var sz: Vector2 = ULT_SIZE if (current_equipment != null and current_equipment.is_ultimate) else DIAMOND_SIZE
	global_position = mouse_pos - sz / 2.0

func end_drag() -> void:
	visible = false
	fire_particles.emitting = false
	current_equipment = null

func _apply_palette(c_id: int) -> void:
	if shader_mat == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	shader_mat.set_shader_parameter("target_color_1", pal.highlight)
	shader_mat.set_shader_parameter("target_color_2", pal.lightbase)
	shader_mat.set_shader_parameter("target_color_3", pal.base)
	shader_mat.set_shader_parameter("target_color_4", pal.shadebase)
	shader_mat.set_shader_parameter("target_color_5", pal.deepshade)

func _update_particles(c_id: int, is_ult: bool) -> void:
	if fire_particles == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 0.92])
	grad.colors = PackedColorArray([
		Color(pal.highlight.r, pal.highlight.g, pal.highlight.b, 1.0),
		Color(pal.lightbase.r, pal.lightbase.g, pal.lightbase.b, 1.0),
		Color(pal.base.r, pal.base.g, pal.base.b, 1.0),
		Color(pal.shadebase.r, pal.shadebase.g, pal.shadebase.b, 1.0),
		Color(pal.deepshade.r, pal.deepshade.g, pal.deepshade.b, 0.0)
	])
	fire_particles.color_ramp = grad

	if is_ult:
		fire_particles.position = Vector2(41.5, 38.0)
		fire_particles.emission_rect_extents = Vector2(24.0, 6.0)
	else:
		fire_particles.position = Vector2(29.5, 38.0)
		fire_particles.emission_rect_extents = Vector2(14.0, 6.0)
