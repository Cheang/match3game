extends Control
class_name InventoryOverlayTrackRow

## Dedicated track row for the full Inventory / Loadout Overlay screen.
## Displays the ultimate slot (showing track color & icon) on the left,
## and 5 diamond basic ability slots (showing icons & track color) on the right.
## Supports drag-and-drop to move, reorder, and swap abilities.

signal slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)
signal equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int)

const TEX_BASIC_SELECTED = preload("res://assets/scene-assets/inventory-overlay/ability-basic-selected.png")
const TEX_BASIC_UNSELECTED = preload("res://assets/scene-assets/inventory-overlay/ability-basic-unselected.png")
const TEX_ULT_SELECTED = preload("res://assets/scene-assets/inventory-overlay/ability-ult-selected.png")
const TEX_ULT_UNSELECTED = preload("res://assets/scene-assets/inventory-overlay/ability-ult-unselected.png")
const TEX_TRACK_EMPTY = preload("res://assets/scene-assets/inventory-overlay/ability-color-track-empty.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const OverlaySlotUI = preload("res://scripts/ui/overlay_slot_ui.gd")

const TRACK_SIZE = Vector2(520, 71)
const ULT_POS = Vector2(6, 6)
const ULT_SIZE = Vector2(83, 59)
const DIAMOND_SIZE = Vector2(59, 59)
const DIAMOND_X_POSITIONS = [103.0, 188.0, 273.0, 358.0, 443.0]
const DIAMOND_Y_POS = 6.0

var track_color: int = 100
var track_ref: ColorLoadoutTrack = null

var bg_rect: TextureRect
var ult_slot: OverlaySlotUI
var ult_frame: TextureRect
var ult_icon: TextureRect
var ult_shader_mat: ShaderMaterial

var diamond_slots: Array[OverlaySlotUI] = []
var diamond_frames: Array[TextureRect] = []
var diamond_icons: Array[TextureRect] = []
var diamond_shader_mats: Array[ShaderMaterial] = []

func _init() -> void:
	custom_minimum_size = TRACK_SIZE
	size = TRACK_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_structure()

func _ensure_structure() -> void:
	if bg_rect == null:
		bg_rect = get_node_or_null("BgTexture") as TextureRect
		if bg_rect == null:
			bg_rect = TextureRect.new()
			bg_rect.name = "BgTexture"
			bg_rect.texture = TEX_TRACK_EMPTY
			bg_rect.size = TRACK_SIZE
			bg_rect.custom_minimum_size = TRACK_SIZE
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(bg_rect)

	# 1. Ultimate Slot (Left: 83x59)
	if ult_slot == null:
		ult_slot = get_node_or_null("UltimateSlot") as OverlaySlotUI
		if ult_slot == null:
			ult_slot = OverlaySlotUI.new()
			ult_slot.name = "UltimateSlot"
			ult_slot.is_ultimate = true
			ult_slot.slot_idx = -1
			ult_slot.position = ULT_POS
			ult_slot.size = ULT_SIZE
			ult_slot.custom_minimum_size = ULT_SIZE
			add_child(ult_slot)

		if not ult_slot.slot_clicked.is_connected(_on_child_slot_clicked):
			ult_slot.slot_clicked.connect(_on_child_slot_clicked)
		if not ult_slot.equipment_dropped.is_connected(_on_child_equipment_dropped):
			ult_slot.equipment_dropped.connect(_on_child_equipment_dropped)

		ult_frame = ult_slot.get_node_or_null("Frame") as TextureRect
		if ult_frame == null:
			ult_frame = TextureRect.new()
			ult_frame.name = "Frame"
			ult_frame.size = ULT_SIZE
			ult_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ult_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ult_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ult_slot.add_child(ult_frame)

		if ult_shader_mat == null:
			ult_shader_mat = ShaderMaterial.new()
			ult_shader_mat.shader = PALETTE_SHADER
		ult_frame.material = ult_shader_mat
		ult_slot.frame_rect = ult_frame
		ult_slot.shader_mat = ult_shader_mat

		ult_icon = ult_slot.get_node_or_null("Icon") as TextureRect
		if ult_icon == null:
			ult_icon = TextureRect.new()
			ult_icon.name = "Icon"
			ult_icon.position = Vector2(20, 8)
			ult_icon.size = Vector2(42, 42)
			ult_icon.custom_minimum_size = Vector2(42, 42)
			ult_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ult_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ult_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ult_slot.add_child(ult_icon)
		ult_slot.icon_rect = ult_icon

	# 2. Basic Diamond Slots (Right: 59x59 each at x = 103, 188, 273, 358, 443)
	if diamond_slots.is_empty():
		for i in range(5):
			var slot_name := "DiamondSlot_%d" % i
			var slot_ctrl := get_node_or_null(slot_name) as OverlaySlotUI
			if slot_ctrl == null:
				slot_ctrl = OverlaySlotUI.new()
				slot_ctrl.name = slot_name
				slot_ctrl.is_ultimate = false
				slot_ctrl.slot_idx = i
				slot_ctrl.position = Vector2(DIAMOND_X_POSITIONS[i], DIAMOND_Y_POS)
				slot_ctrl.size = DIAMOND_SIZE
				slot_ctrl.custom_minimum_size = DIAMOND_SIZE
				add_child(slot_ctrl)

			if not slot_ctrl.slot_clicked.is_connected(_on_child_slot_clicked):
				slot_ctrl.slot_clicked.connect(_on_child_slot_clicked)
			if not slot_ctrl.equipment_dropped.is_connected(_on_child_equipment_dropped):
				slot_ctrl.equipment_dropped.connect(_on_child_equipment_dropped)

			var frame_rect := slot_ctrl.get_node_or_null("Frame") as TextureRect
			if frame_rect == null:
				frame_rect = TextureRect.new()
				frame_rect.name = "Frame"
				frame_rect.size = DIAMOND_SIZE
				frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_ctrl.add_child(frame_rect)

			var s_mat := ShaderMaterial.new()
			s_mat.shader = PALETTE_SHADER
			frame_rect.material = s_mat
			slot_ctrl.frame_rect = frame_rect
			slot_ctrl.shader_mat = s_mat

			var icon_rect := slot_ctrl.get_node_or_null("Icon") as TextureRect
			if icon_rect == null:
				icon_rect = TextureRect.new()
				icon_rect.name = "Icon"
				icon_rect.position = Vector2(13, 13)
				icon_rect.size = Vector2(32, 32)
				icon_rect.custom_minimum_size = Vector2(32, 32)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_ctrl.add_child(icon_rect)
			slot_ctrl.icon_rect = icon_rect

			diamond_slots.append(slot_ctrl)
			diamond_frames.append(frame_rect)
			diamond_icons.append(icon_rect)
			diamond_shader_mats.append(s_mat)

## Sets up the row for a specific color track and its equipped abilities.
func setup_row(color_id: int, track: ColorLoadoutTrack) -> void:
	_ensure_structure()
	track_color = color_id
	track_ref = track

	# 1. Setup Ultimate Slot
	ult_slot.track_ref = track
	ult_slot.color_id = color_id
	var ult_mod: Equipment = track.ultimate_skill if track != null else null
	ult_slot.modifier = ult_mod
	ult_slot.is_selected_slot = false

	if track_color > 0:
		_apply_palette(ult_shader_mat, track_color)
		ult_frame.visible = true
		ult_frame.texture = TEX_ULT_UNSELECTED
		if ult_mod != null and ult_mod.icon != null:
			ult_icon.texture = ult_mod.icon
			ult_icon.visible = true
		else:
			ult_icon.texture = null
			ult_icon.visible = false
	else:
		ult_frame.visible = false
		ult_icon.visible = false

	# 2. Setup 5 Diamond Slots
	for i in range(5):
		var slot_ctrl: OverlaySlotUI = diamond_slots[i]
		var frame: TextureRect = diamond_frames[i]
		var icon: TextureRect = diamond_icons[i]
		var s_mat: ShaderMaterial = diamond_shader_mats[i]
		var mod: Equipment = track.get_modifier_at_slot_index(i) if track != null else null

		slot_ctrl.track_ref = track
		slot_ctrl.color_id = color_id
		slot_ctrl.modifier = mod
		slot_ctrl.is_selected_slot = false

		if mod != null:
			_apply_palette(s_mat, track_color)
			frame.visible = true
			frame.texture = TEX_BASIC_UNSELECTED
			if mod.icon != null:
				icon.texture = mod.icon
				icon.visible = true
			else:
				icon.texture = null
				icon.visible = false
		else:
			# Empty slot: let empty track crystal background show through cleanly
			frame.visible = false
			icon.visible = false

## Updates highlight selection state on slots.
func update_selection(selected_mod: Equipment, is_ult: bool, slot_idx: int, is_same_track: bool) -> void:
	_ensure_structure()

	# Ultimate slot selection
	if ult_frame.visible:
		var ult_is_selected: bool = is_same_track and is_ult
		ult_slot.is_selected_slot = ult_is_selected
		ult_frame.texture = TEX_ULT_SELECTED if ult_is_selected else TEX_ULT_UNSELECTED

	# Diamond slots selection
	for i in range(5):
		var slot_ctrl: OverlaySlotUI = diamond_slots[i]
		var frame: TextureRect = diamond_frames[i]
		if not frame.visible:
			slot_ctrl.is_selected_slot = false
			continue
		var mod: Equipment = track_ref.get_modifier_at_slot_index(i) if track_ref != null else null
		var slot_is_selected: bool = false
		if is_same_track and not is_ult and selected_mod != null:
			slot_is_selected = (mod == selected_mod)
		slot_ctrl.is_selected_slot = slot_is_selected
		frame.texture = TEX_BASIC_SELECTED if slot_is_selected else TEX_BASIC_UNSELECTED

func _apply_palette(s_mat: ShaderMaterial, c_id: int) -> void:
	if s_mat == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	s_mat.set_shader_parameter("target_color_1", pal.highlight)
	s_mat.set_shader_parameter("target_color_2", pal.lightbase)
	s_mat.set_shader_parameter("target_color_3", pal.base)
	s_mat.set_shader_parameter("target_color_4", pal.shadebase)
	s_mat.set_shader_parameter("target_color_5", pal.deepshade)

func _on_child_slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ult: bool, s_idx: int) -> void:
	slot_clicked.emit(mod, track, is_ult, s_idx)

func _on_child_equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int) -> void:
	equipment_dropped.emit(drag_data, target_track, target_is_ult, target_slot_idx)

# Fallback drag-and-drop directly onto row background:
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if track_ref == null or track_color <= 0:
		return false
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "equipment_drag":
		return false
	var dragged_mod: Equipment = data.get("modifier", null)
	if dragged_mod == null:
		return false
	return track_ref.is_color_compatible(dragged_mod)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "equipment_drag":
		var dragged_mod: Equipment = data.get("modifier", null)
		var is_ult: bool = dragged_mod != null and dragged_mod.is_ultimate
		equipment_dropped.emit(data, track_ref, is_ult, -1)
