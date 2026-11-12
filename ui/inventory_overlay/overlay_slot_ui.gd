class_name OverlaySlotUI
extends Control

## Interactive slot on an InventoryOverlay track row.
## Supports:
##  1. Left-click to select / inspect ability.
##  2. Dragging to move/swap equipment on this track or between tracks.
##  3. Receiving dropped equipment.

signal slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)
signal equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int)

const TEX_BASIC_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_unselected.png")
const TEX_ULT_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_ult_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")

@export var is_ultimate: bool = false
@export var slot_idx: int = -1

var track_ref: ColorLoadoutTrack = null
var color_id: int = 100
var modifier: Equipment = null
var is_selected_slot: bool = false

var frame_rect: TextureRect
var icon_rect: TextureRect
var shader_mat: ShaderMaterial

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	_ensure_nodes()

func _ensure_nodes() -> void:
	if frame_rect == null:
		frame_rect = get_node_or_null("Frame") as TextureRect
	if icon_rect == null:
		icon_rect = get_node_or_null("Icon") as TextureRect
	if shader_mat == null and frame_rect != null and frame_rect.material is ShaderMaterial:
		shader_mat = frame_rect.material as ShaderMaterial
	if frame_rect != null:
		frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if icon_rect != null:
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_clicked.emit(modifier, track_ref, is_ultimate, slot_idx)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if modifier == null or track_ref == null:
		return null

	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_sz := Vector2(83, 59) if is_ultimate else Vector2(59, 59)

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = -preview_sz / 2.0
	preview.add_child(inner)

	var preview_frame := TextureRect.new()
	preview_frame.size = preview_sz
	preview_frame.custom_minimum_size = preview_sz
	preview_frame.texture = TEX_ULT_UNSELECTED if is_ultimate else TEX_BASIC_UNSELECTED
	preview_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var s_mat := ShaderMaterial.new()
	s_mat.shader = PALETTE_SHADER
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(track_ref.color)
	s_mat.set_shader_parameter("target_color_1", pal.highlight)
	s_mat.set_shader_parameter("target_color_2", pal.lightbase)
	s_mat.set_shader_parameter("target_color_3", pal.base)
	s_mat.set_shader_parameter("target_color_4", pal.shadebase)
	s_mat.set_shader_parameter("target_color_5", pal.deepshade)
	preview_frame.material = s_mat
	inner.add_child(preview_frame)

	if modifier.icon != null:
		var icon_preview := TextureRect.new()
		icon_preview.position = Vector2.ZERO
		icon_preview.size = preview_sz
		icon_preview.custom_minimum_size = preview_sz
		icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_preview.texture = modifier.icon
		icon_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		inner.add_child(icon_preview)

	if is_inside_tree() and get_viewport() != null and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.queue_free()

	return {
		"type": "equipment_drag",
		"modifier": modifier,
		"source_track": track_ref,
		"source_is_ult": is_ultimate,
		"source_slot_idx": slot_idx
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if track_ref == null or color_id <= 0:
		return false
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "equipment_drag":
		return false

	var dragged_mod: Equipment = data.get("modifier", null)
	if dragged_mod == null:
		return false

	if not track_ref.is_color_compatible(dragged_mod):
		return false

	if is_ultimate:
		return dragged_mod.is_ultimate
	else:
		return not dragged_mod.is_ultimate

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "equipment_drag":
		equipment_dropped.emit(data, track_ref, is_ultimate, slot_idx)
