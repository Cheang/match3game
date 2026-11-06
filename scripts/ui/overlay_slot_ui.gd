extends Control
class_name OverlaySlotUI

## Interactive slot on an InventoryOverlay track row.
## Supports:
##  1. Left-click to select / inspect ability.
##  2. Dragging to move/swap equipment on this track or between tracks.
##  3. Receiving dropped equipment.

signal slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)
signal equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int)

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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_clicked.emit(modifier, track_ref, is_ultimate, slot_idx)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if modifier == null or track_ref == null:
		return null

	var preview := Control.new()
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(50, 50)
	box.size = Vector2(50, 50)
	box.position = Vector2(-25, -25)

	var sb := StyleBoxFlat.new()
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(track_ref.color)
	sb.bg_color = pal.base.darkened(0.3)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = pal.highlight
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	box.add_theme_stylebox_override("panel", sb)

	var icon_preview := TextureRect.new()
	icon_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_preview.texture = modifier.icon
	box.add_child(icon_preview)

	preview.add_child(box)
	set_drag_preview(preview)

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
