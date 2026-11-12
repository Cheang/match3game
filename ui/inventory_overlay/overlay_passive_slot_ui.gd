class_name OverlayPassiveSlotUI
extends Control

## Slot control representing one of the 5 passive slots in the pentagon ring.
## Supports clicking to select and inspect in the description box,
## as well as drag-and-drop to reorder and swap equipped passives.

signal slot_clicked(slot_idx: int, passive_ref: Resource)
signal passive_dropped(source_idx: int, target_idx: int)

const TEX_PASSIVE_SELECTED = preload("res://assets/sprites/ui/inventory_overlay/passive_selected.png")
const TEX_PASSIVE_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/passive_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")

@export var slot_index: int = 0

var passive_ref: Resource = null
var is_selected_slot: bool = false
var track_color: int = 500

var frame: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ensure_structure()

func _ensure_structure() -> void:
	if frame == null:
		frame = get_node_or_null("Frame") as TextureRect
		if frame == null:
			frame = TextureRect.new()
			frame.name = "Frame"
			frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.visible = false
			add_child(frame)

	if shader_mat == null:
		if frame.material is ShaderMaterial:
			shader_mat = frame.material as ShaderMaterial
		else:
			shader_mat = ShaderMaterial.new()
			shader_mat.shader = PALETTE_SHADER
			frame.material = shader_mat

	if icon_rect == null:
		icon_rect = get_node_or_null("Icon") as TextureRect
		if icon_rect == null:
			icon_rect = TextureRect.new()
			icon_rect.name = "Icon"
			icon_rect.position = Vector2(12, 12)
			icon_rect.size = Vector2(40, 40)
			icon_rect.custom_minimum_size = Vector2(40, 40)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.visible = false
			add_child(icon_rect)

func set_passive(p_res: Resource, color_id: int = 500) -> void:
	_ensure_structure()
	passive_ref = p_res
	track_color = color_id

	if p_res == null:
		frame.visible = false
		icon_rect.visible = false
		icon_rect.texture = null
	else:
		_apply_palette(color_id)
		frame.texture = TEX_PASSIVE_SELECTED if is_selected_slot else TEX_PASSIVE_UNSELECTED
		frame.visible = true

		var ic: Texture2D = p_res.get("icon") as Texture2D
		if ic != null:
			icon_rect.texture = ic
			icon_rect.visible = true
		else:
			icon_rect.texture = null
			icon_rect.visible = false

func set_selected(val: bool) -> void:
	_ensure_structure()
	is_selected_slot = val
	if frame.visible:
		frame.texture = TEX_PASSIVE_SELECTED if val else TEX_PASSIVE_UNSELECTED

func _apply_palette(c_id: int) -> void:
	if shader_mat == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	shader_mat.set_shader_parameter("target_color_1", pal.highlight)
	shader_mat.set_shader_parameter("target_color_2", pal.lightbase)
	shader_mat.set_shader_parameter("target_color_3", pal.base)
	shader_mat.set_shader_parameter("target_color_4", pal.shadebase)
	shader_mat.set_shader_parameter("target_color_5", pal.deepshade)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_clicked.emit(slot_index, passive_ref)
		accept_event()

# ==============================================================================
# DRAG AND DROP
# ==============================================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	if passive_ref == null:
		return null

	var preview_root := Control.new()
	var preview_icon := TextureRect.new()
	preview_icon.texture = passive_ref.get("icon") as Texture2D
	preview_icon.custom_minimum_size = Vector2(40, 40)
	preview_icon.size = Vector2(40, 40)
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.position = -Vector2(20, 20)
	preview_root.add_child(preview_icon)
	set_drag_preview(preview_root)

	return {
		"type": "passive_drag",
		"source_index": slot_index,
		"passive": passive_ref
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "passive_drag"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		var src_idx: int = int(data.get("source_index", -1))
		passive_dropped.emit(src_idx, slot_index)
