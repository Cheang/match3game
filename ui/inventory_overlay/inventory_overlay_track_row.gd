class_name InventoryOverlayTrackRow
extends Control

## Dedicated track row for the full Inventory / Loadout Overlay screen.
## Displays the ultimate slot (showing track color & icon) on the left,
## and 5 diamond basic ability slots (showing icons & track color) on the right.
## Displays multislot connection graphics when an ability occupies multiple slots.
## Supports drag-and-drop to move, reorder, and swap abilities.

signal slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)
signal slot_drag_requested(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int, mouse_pos: Vector2)
signal equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int)

const TEX_BASIC_SELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_selected.png")
const TEX_BASIC_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_basic_unselected.png")
const TEX_ULT_SELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_ult_selected.png")
const TEX_ULT_UNSELECTED = preload("res://assets/sprites/ui/inventory_overlay/ability_ult_unselected.png")
const TEX_TRACK_EMPTY = preload("res://assets/sprites/ui/inventory_overlay/ability_color_track_empty.png")
const TEX_TRACK_EMPTY_DISABLED = preload("res://assets/sprites/ui/inventory_overlay/ability_color_track_empty-disabled.png")
const TEX_MULTISLOT_CONNECTION = preload("res://assets/sprites/ui/inventory_overlay/ability_multislot_connection.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")

const TRACK_SIZE = Vector2(520, 71)
const ULT_POS = Vector2(6, 6)
const ULT_SIZE = Vector2(83, 59)
const DIAMOND_SIZE = Vector2(59, 59)
const DIAMOND_X_POSITIONS = [103.0, 188.0, 273.0, 358.0, 443.0]
const DIAMOND_Y_POS = 6.0

const CONNECTION_SIZE = Vector2(40, 43)
const CONNECTION_Y_POS = 14.0
const CONNECTION_X_POSITIONS = [155.0, 240.0, 325.0, 410.0]

var track_color: int = 100
var track_ref: ColorLoadoutTrack = null

var bg_rect: TextureRect
var connection_rects: Array[TextureRect] = []
var connection_shader_mats: Array[ShaderMaterial] = []

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
	mouse_filter = Control.MOUSE_FILTER_STOP

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

	# 1. Multi-slot Connection Graphics (Between diamonds 0-1, 1-2, 2-3, 3-4)
	# Added before slots so diamond borders render cleanly on top of connection edges
	if connection_rects.is_empty():
		for i in range(4):
			var conn_name := "Connection_%d" % i
			var conn_rect := get_node_or_null(conn_name) as TextureRect
			if conn_rect == null:
				conn_rect = TextureRect.new()
				conn_rect.name = conn_name
				conn_rect.texture = TEX_MULTISLOT_CONNECTION
				conn_rect.position = Vector2(CONNECTION_X_POSITIONS[i], CONNECTION_Y_POS)
				conn_rect.size = CONNECTION_SIZE
				conn_rect.custom_minimum_size = CONNECTION_SIZE
				conn_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				conn_rect.visible = false
				add_child(conn_rect)

			var s_mat := conn_rect.material as ShaderMaterial
			if s_mat == null:
				s_mat = ShaderMaterial.new()
				s_mat.shader = PALETTE_SHADER
				conn_rect.material = s_mat

			connection_rects.append(conn_rect)
			connection_shader_mats.append(s_mat)

	# 2. Ultimate Slot (Left: 83x59)
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
		if not ult_slot.slot_drag_requested.is_connected(_on_child_slot_drag_requested):
			ult_slot.slot_drag_requested.connect(_on_child_slot_drag_requested)
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
			ult_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
			ult_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ult_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ult_slot.add_child(ult_icon)
		ult_icon.position = Vector2.ZERO
		ult_icon.size = ULT_SIZE
		ult_icon.custom_minimum_size = ULT_SIZE
		ult_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ult_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ult_slot.icon_rect = ult_icon

	# 3. Basic Diamond Slots (Right: 59x59 each at x = 103, 188, 273, 358, 443)
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
			if not slot_ctrl.slot_drag_requested.is_connected(_on_child_slot_drag_requested):
				slot_ctrl.slot_drag_requested.connect(_on_child_slot_drag_requested)
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
				frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				slot_ctrl.add_child(icon_rect)
			icon_rect.position = Vector2.ZERO
			icon_rect.size = DIAMOND_SIZE
			icon_rect.custom_minimum_size = DIAMOND_SIZE
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

	if track_color > 0 and track_ref != null:
		if bg_rect != null:
			bg_rect.texture = TEX_TRACK_EMPTY
		if ult_slot != null:
			ult_slot.modulate = Color.WHITE
		for s in diamond_slots:
			if s != null:
				s.modulate = Color.WHITE
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
		# Empty / unused track row: always use disabled sprite and gray out
		if bg_rect != null:
			bg_rect.texture = TEX_TRACK_EMPTY_DISABLED
		if ult_slot != null:
			ult_slot.modulate = Color(0.35, 0.35, 0.4, 0.5)
		for s in diamond_slots:
			if s != null:
				s.modulate = Color(0.35, 0.35, 0.4, 0.5)
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

			var slot_indices: Array[int] = track.get_slot_indices_for_modifier(mod) if track != null else []
			var is_primary_slot: bool = slot_indices.is_empty() or slot_indices[0] == i
			if mod.icon != null and is_primary_slot:
				icon.texture = mod.icon
				icon.visible = true
			else:
				icon.texture = null
				icon.visible = false
		else:
			# Empty slot: let empty track crystal background show through cleanly
			frame.visible = false
			icon.visible = false

	# 3. Setup Multi-slot Connectors
	for i in range(4):
		var conn_rect: TextureRect = connection_rects[i]
		var s_mat: ShaderMaterial = connection_shader_mats[i]

		var left_mod: Equipment = track.get_modifier_at_slot_index(i) if track != null else null
		var right_mod: Equipment = track.get_modifier_at_slot_index(i + 1) if track != null else null

		if track_color > 0 and left_mod != null and left_mod == right_mod:
			_apply_palette(s_mat, track_color)
			conn_rect.visible = true
		else:
			conn_rect.visible = false

## Updates highlight selection state on slots.
func update_selection(selected_mod: Equipment, is_ult: bool, _slot_idx: int, is_same_track: bool) -> void:
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

## Sets compatibility visual state (disabled track sprite & grayed-out slots) for candidate equipment.
func set_compatibility_state(candidate: Equipment) -> void:
	_ensure_structure()
	# Unused / empty tracks: always disabled
	if track_ref == null or track_color <= 0:
		if bg_rect != null:
			bg_rect.texture = TEX_TRACK_EMPTY_DISABLED
		if ult_slot != null:
			ult_slot.modulate = Color(0.35, 0.35, 0.4, 0.5)
		for s in diamond_slots:
			if s != null:
				s.modulate = Color(0.35, 0.35, 0.4, 0.5)
		return

	if candidate == null:
		if bg_rect != null:
			bg_rect.texture = TEX_TRACK_EMPTY
		if ult_slot != null:
			ult_slot.modulate = Color.WHITE
		for s in diamond_slots:
			if s != null:
				s.modulate = Color.WHITE
		return

	var is_compat: bool = track_ref.is_color_compatible(candidate)
	if not is_compat:
		if bg_rect != null:
			bg_rect.texture = TEX_TRACK_EMPTY_DISABLED
		if ult_slot != null:
			ult_slot.modulate = Color(0.35, 0.35, 0.4, 0.5)
		for s in diamond_slots:
			if s != null:
				s.modulate = Color(0.35, 0.35, 0.4, 0.5)
	else:
		if bg_rect != null:
			bg_rect.texture = TEX_TRACK_EMPTY
		if candidate.is_ultimate:
			if ult_slot != null:
				ult_slot.modulate = Color.WHITE
			for s in diamond_slots:
				if s != null:
					s.modulate = Color(0.35, 0.35, 0.4, 0.5)
		else:
			if ult_slot != null:
				ult_slot.modulate = Color(0.35, 0.35, 0.4, 0.5)
			for s in diamond_slots:
				if s != null:
					s.modulate = Color.WHITE

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

func _on_child_slot_drag_requested(mod: Equipment, track: ColorLoadoutTrack, is_ult: bool, s_idx: int, m_pos: Vector2) -> void:
	slot_drag_requested.emit(mod, track, is_ult, s_idx, m_pos)

func _on_child_equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int) -> void:
	equipment_dropped.emit(drag_data, target_track, target_is_ult, target_slot_idx)
