class_name OverlaySlotUI
extends Control

## Interactive slot on an InventoryOverlay track row.
## Supports:
##  1. Left-click to select / inspect ability.
##  2. Dragging to move/swap equipment on this track or between tracks.
##  3. Receiving dropped equipment.

signal slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)
signal slot_drag_requested(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int, mouse_pos: Vector2)
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
		if modifier != null and track_ref != null:
			slot_drag_requested.emit(modifier, track_ref, is_ultimate, slot_idx, event.global_position)
			accept_event()
		else:
			slot_clicked.emit(modifier, track_ref, is_ultimate, slot_idx)
