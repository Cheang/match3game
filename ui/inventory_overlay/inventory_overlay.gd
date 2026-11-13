class_name InventoryOverlay
extends CanvasLayer

## Standalone Inventory / Loadout Overlay screen.
## Used across all scenes to inspect color tracks, equipped abilities, and passives.
## Displays:
##  1. Top header ("Loadout")
##  2. Passives section (5-slot layout placeholder)
##  3. Top flexible spacer (ensuring tracks, description & buttons are bottom-aligned)
##  4. 5 Loadout tracks with color backgrounds, ultimate slot, and diamond ability icons
##  5. Ability description panel (using ability-description-panel.png)
##  6. Bottom navigation buttons row (using general-button-unpressed.png)

signal overlay_opened
signal overlay_closed
signal slotting_completed
signal ability_selected(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)

static var instance: InventoryOverlay = null

const TEX_OVERLAY_BG = preload("res://assets/sprites/ui/combat/inventory_btn_unpressed.png")
const TEX_DESC_PANEL = preload("res://assets/sprites/ui/inventory_overlay/ability_description_panel.png")
const TEX_GENERAL_BTN = preload("res://assets/sprites/ui/general_button_unpressed.png")
const TRACK_ROW_SCENE = preload("res://ui/inventory_overlay/inventory_overlay_track_row.tscn")
const PASSIVES_RING_SCENE = preload("res://ui/inventory_overlay/inventory_overlay_passives_ring.tscn")
const TITLE_FONT = preload("res://assets/theme/title.ttf")
const BODY_FONT = preload("res://assets/theme/plain.ttf")

@export var description_panel_height: float = 160.0:
	set(val):
		description_panel_height = val
		if description_panel != null:
			description_panel.custom_minimum_size.y = val

@export var header_title: String = "Loadout":
	set(val):
		header_title = val
		if header_label != null:
			header_label.text = val

enum Tab { LOADOUT, STATS, SETTINGS }
var current_tab: Tab = Tab.LOADOUT

var dimmer: ColorRect
var main_panel: NinePatchRect
var header_label: Label

var loadout_view: VBoxContainer
var passives_ring: InventoryOverlayPassivesRing = null
var spacer: Control
var tracks_box: VBoxContainer
var track_rows: Array[InventoryOverlayTrackRow] = []
var description_hbox: HBoxContainer = null
var description_panel: NinePatchRect
var description_label: RichTextLabel

var stats_view: Control

var settings_view: Control
var settings_vbox: VBoxContainer
var almanac_btn: Button
var sound_btn: Button
var graphics_btn: Button
var main_menu_btn: Button

var bottom_nav_box: HBoxContainer
var loadout_nav_btn: Button
var stats_nav_btn: Button
var settings_nav_btn: Button
var done_btn: Button

const DragAvatarClass = preload("res://ui/inventory_overlay/drag_avatar.gd")

var is_slotting_mode: bool = false
var pending_slotting_queue: Array[Equipment] = []
var floating_shard_dock: FloatingShardDock = null
var _cached_floating_equipment: Equipment = null

var drag_avatar: Control = null
var _drag_pending: bool = false
var _drag_start_mouse_pos: Vector2 = Vector2.ZERO
var _drag_candidate_item: Equipment = null
var _drag_source_is_floating: bool = false
var _drag_source_track: ColorLoadoutTrack = null
var _drag_source_is_ult: bool = false
var _drag_source_slot_idx: int = -1
var is_custom_dragging: bool = false

var selected_ability: Equipment = null
var selected_track: ColorLoadoutTrack = null
var selected_is_ult: bool = false
var selected_slot_idx: int = -2

var selected_passive: Resource = null
var selected_passive_idx: int = -1

var _saved_game_is_played: bool = true

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	instance = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_if_needed()
	visible = false

static func _get_active_instance() -> InventoryOverlay:
	if instance != null and is_instance_valid(instance) and instance.is_inside_tree() and not instance.is_queued_for_deletion():
		return instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var search_roots: Array[Node] = []
		if tree.current_scene != null:
			search_roots.append(tree.current_scene)
		if tree.root != null and not search_roots.has(tree.root):
			search_roots.append(tree.root)
		for root_node in search_roots:
			for child in root_node.find_children("*", "InventoryOverlay", true, false):
				if child is InventoryOverlay and not child.is_queued_for_deletion():
					instance = child
					return instance
			var by_snake := root_node.find_child("inventory_overlay", true, false) as InventoryOverlay
			if by_snake != null and not by_snake.is_queued_for_deletion():
				instance = by_snake
				return instance
			var by_pascal := root_node.find_child("InventoryOverlay", true, false) as InventoryOverlay
			if by_pascal != null and not by_pascal.is_queued_for_deletion():
				instance = by_pascal
				return instance
	return null

static func is_overlay_open() -> bool:
	var active := _get_active_instance()
	return active != null and active.visible

static func toggle_overlay() -> void:
	var active := _get_active_instance()
	if active != null:
		active.toggle()

static func open_overlay() -> void:
	var active := _get_active_instance()
	if active != null:
		active.open()

static func close_overlay() -> void:
	var active := _get_active_instance()
	if active != null:
		active.close()

## Finds active instance or instantiates inventory_overlay.tscn under parent/root.
static func get_or_create(parent: Node = null) -> InventoryOverlay:
	var active := _get_active_instance()
	if active != null:
		return active
	var tree := Engine.get_main_loop() as SceneTree
	var p: Node = parent
	if p == null and tree != null:
		p = tree.current_scene if tree.current_scene != null else tree.root
	var overlay_scene: PackedScene = preload("res://ui/inventory_overlay/inventory_overlay.tscn")
	var overlay: InventoryOverlay = overlay_scene.instantiate() as InventoryOverlay
	if p != null:
		p.add_child(overlay)
	return overlay

## Interactive slotting session for newly acquired equipment rewards.
## Displays the floating diamond shard with fire particles at the bottom and a single Done button.
## Suspends execution via await until the player finishes moving shards and clicks Done.
func prompt_slotting(equipment_list: Array) -> void:
	var typed_list: Array[Equipment] = []
	for item in equipment_list:
		if item is Equipment:
			typed_list.append(item)
	if typed_list.is_empty():
		return
	_build_ui_if_needed()
	start_slotting_mode(typed_list)
	await slotting_completed

func start_slotting_mode(equipment_list: Array) -> void:
	_build_ui_if_needed()
	is_slotting_mode = true
	pending_slotting_queue.clear()
	for item in equipment_list:
		if item is Equipment:
			pending_slotting_queue.append(item)
	var first_eq: Equipment = pending_slotting_queue.pop_front() if not pending_slotting_queue.is_empty() else null
	_update_slotting_mode_ui(true)
	open()
	set_floating_equipment(first_eq)

func set_floating_equipment(eq: Equipment) -> void:
	_cached_floating_equipment = eq
	if floating_shard_dock != null:
		floating_shard_dock.set_equipment(eq)
	for row in track_rows:
		if row != null:
			row.set_compatibility_state(eq)
	if eq != null:
		_display_ability_description(eq, _get_equipment_color(eq), eq.is_ultimate)
	else:
		_show_empty_description()

func _update_slotting_mode_ui(slotting_active: bool) -> void:
	_build_ui_if_needed()
	is_slotting_mode = slotting_active
	if header_label != null:
		header_label.text = "Equip Shard" if slotting_active else header_title
	if floating_shard_dock != null:
		floating_shard_dock.visible = slotting_active
	if description_panel != null:
		description_panel.custom_minimum_size.y = description_panel_height
	if done_btn != null:
		done_btn.visible = slotting_active
	if loadout_nav_btn != null:
		loadout_nav_btn.visible = not slotting_active
	if stats_nav_btn != null:
		stats_nav_btn.visible = not slotting_active
	if settings_nav_btn != null:
		settings_nav_btn.visible = not slotting_active

func _get_equipment_color(eq: Equipment) -> int:
	if eq == null or eq.is_colorless():
		return 100
	var eff: Array[int] = eq.get_effective_allowed_colors()
	return eff[0] if not eff.is_empty() else 100

func open() -> void:
	if Global.game_is_over:
		return
	_saved_game_is_played = Global.game_is_played
	Global.game_is_played = false

	_build_ui_if_needed()
	switch_tab(Tab.LOADOUT)
	visible = true
	overlay_opened.emit()

func close() -> void:
	_cleanup_custom_drag()
	if is_slotting_mode:
		_cached_floating_equipment = null
		pending_slotting_queue.clear()
		if floating_shard_dock != null:
			floating_shard_dock.set_equipment(null)
		for row in track_rows:
			if row != null:
				row.set_compatibility_state(null)
		is_slotting_mode = false
		_update_slotting_mode_ui(false)
		visible = false
		Global.game_is_played = _saved_game_is_played
		overlay_closed.emit()
		slotting_completed.emit()
		return
	visible = false
	Global.game_is_played = _saved_game_is_played
	overlay_closed.emit()

func toggle() -> void:
	if is_slotting_mode:
		return
	if visible:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _drag_pending and not is_custom_dragging:
		if event is InputEventMouseMotion:
			if event.global_position.distance_to(_drag_start_mouse_pos) > 3.0:
				_start_custom_drag(event.global_position)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drag_pending = false
			if _drag_source_is_floating:
				_on_floating_shard_selected(_drag_candidate_item)
			else:
				_on_slot_clicked(_drag_candidate_item, _drag_source_track, _drag_source_is_ult, _drag_source_slot_idx)
			get_viewport().set_input_as_handled()

	elif is_custom_dragging:
		if event is InputEventMouseMotion:
			if drag_avatar != null:
				drag_avatar.update_position(event.global_position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_custom_drop(event.global_position)
			get_viewport().set_input_as_handled()

func _on_floating_shard_drag_requested(eq: Equipment, mouse_pos: Vector2) -> void:
	if eq == null:
		return
	_drag_pending = true
	_drag_start_mouse_pos = mouse_pos
	_drag_candidate_item = eq
	_drag_source_is_floating = true
	_drag_source_track = null
	_drag_source_is_ult = eq.is_ultimate
	_drag_source_slot_idx = -1

func _on_row_slot_drag_requested(eq: Equipment, track: ColorLoadoutTrack, is_ult: bool, slot_idx: int, mouse_pos: Vector2) -> void:
	if eq == null:
		return
	_drag_pending = true
	_drag_start_mouse_pos = mouse_pos
	_drag_candidate_item = eq
	_drag_source_is_floating = false
	_drag_source_track = track
	_drag_source_is_ult = is_ult
	_drag_source_slot_idx = slot_idx

func _start_custom_drag(mouse_pos: Vector2) -> void:
	if _drag_candidate_item == null:
		_drag_pending = false
		return
	is_custom_dragging = true
	_drag_pending = false

	if _drag_source_is_floating:
		if floating_shard_dock != null:
			floating_shard_dock.set_shard_hidden(true)
	else:
		_set_slot_visual_lifted(_drag_source_track, _drag_source_is_ult, _drag_source_slot_idx, true)

	if drag_avatar != null:
		var c_id: int = _drag_source_track.color if _drag_source_track != null else -1
		drag_avatar.start_drag(_drag_candidate_item, mouse_pos, c_id)

	for row in track_rows:
		if row != null:
			row.set_compatibility_state(_drag_candidate_item)

func _finish_custom_drop(pos: Vector2) -> void:
	if not is_custom_dragging or _drag_candidate_item == null:
		_cleanup_custom_drag()
		return

	var target := _find_drop_target_at_pos(pos)
	var dropped_item: Equipment = _drag_candidate_item
	var src_floating: bool = _drag_source_is_floating
	var src_track: ColorLoadoutTrack = _drag_source_track
	var src_is_ult: bool = _drag_source_is_ult
	var src_slot_idx: int = _drag_source_slot_idx

	_reset_drag_input_state()

	match target.get("type", "none"):
		"dock":
			if not src_floating:
				var dock_ok: bool = _on_shard_dropped_to_dock({
					"type": "equipment_drag",
					"modifier": dropped_item,
					"source_track": src_track,
					"source_is_ult": src_is_ult,
					"source_slot_idx": src_slot_idx,
					"source_is_floating": false
				})
				if dock_ok:
					if drag_avatar != null:
						drag_avatar.end_drag()
					if floating_shard_dock != null:
						floating_shard_dock.set_shard_hidden(false)
				else:
					_cancel_custom_drag(dropped_item, src_floating, src_track, src_is_ult, src_slot_idx)
			else:
				_cancel_custom_drag(dropped_item, src_floating, src_track, src_is_ult, src_slot_idx)
		"slot":
			var target_track: ColorLoadoutTrack = target.get("track")
			var target_is_ult: bool = target.get("is_ult", false)
			var target_slot_idx: int = target.get("slot_idx", -1)

			if target_track != null and target_track.is_color_compatible(dropped_item) and target_is_ult == dropped_item.is_ultimate:
				var drop_ok: bool = false
				if src_floating:
					drop_ok = _handle_floating_shard_drop(dropped_item, target_track, target_is_ult, target_slot_idx)
				else:
					drop_ok = _on_equipment_dropped({
						"type": "equipment_drag",
						"modifier": dropped_item,
						"source_track": src_track,
						"source_is_ult": src_is_ult,
						"source_slot_idx": src_slot_idx,
						"source_is_floating": false
					}, target_track, target_is_ult, target_slot_idx)
				if drop_ok:
					if drag_avatar != null:
						drag_avatar.end_drag()
					if floating_shard_dock != null:
						floating_shard_dock.set_shard_hidden(false)
				else:
					_cancel_custom_drag(dropped_item, src_floating, src_track, src_is_ult, src_slot_idx)
			else:
				_cancel_custom_drag(dropped_item, src_floating, src_track, src_is_ult, src_slot_idx)
		_:
			_cancel_custom_drag(dropped_item, src_floating, src_track, src_is_ult, src_slot_idx)

func _get_drag_origin_global_pos(from_dock: bool, src_track: ColorLoadoutTrack, src_is_ult: bool, src_slot_idx: int) -> Vector2:
	if from_dock:
		if floating_shard_dock != null and floating_shard_dock.shard_item != null:
			return floating_shard_dock.shard_item.global_position
		return Vector2(INF, INF)
	for row in track_rows:
		if row != null and row.track_ref == src_track:
			if src_is_ult and row.ult_slot != null:
				return row.ult_slot.global_position
			if src_slot_idx >= 0 and src_slot_idx < row.diamond_slots.size() and row.diamond_slots[src_slot_idx] != null:
				return row.diamond_slots[src_slot_idx].global_position
	return Vector2(INF, INF)

func _cancel_custom_drag(_item: Equipment, from_dock: bool, src_track: ColorLoadoutTrack, src_is_ult: bool, src_slot_idx: int) -> void:
	var restore_cb := func() -> void:
		if from_dock:
			if floating_shard_dock != null:
				floating_shard_dock.set_shard_hidden(false)
		else:
			_set_slot_visual_lifted(src_track, src_is_ult, src_slot_idx, false)

	if drag_avatar != null and drag_avatar.visible:
		var origin_pos := _get_drag_origin_global_pos(from_dock, src_track, src_is_ult, src_slot_idx)
		if origin_pos.is_finite():
			drag_avatar.return_to(origin_pos, restore_cb)
			return
		drag_avatar.end_drag()
	restore_cb.call()

func _reset_drag_input_state() -> void:
	is_custom_dragging = false
	_drag_pending = false
	_drag_candidate_item = null
	var restore_eq: Equipment = _cached_floating_equipment if is_slotting_mode else null
	for row in track_rows:
		if row != null:
			row.set_compatibility_state(restore_eq)

func _cleanup_custom_drag() -> void:
	_reset_drag_input_state()
	if drag_avatar != null:
		drag_avatar.end_drag()
	if floating_shard_dock != null:
		floating_shard_dock.set_shard_hidden(false)

func _set_slot_visual_lifted(track: ColorLoadoutTrack, is_ult: bool, slot_idx: int, lifted: bool) -> void:
	if track == null:
		return
	for row in track_rows:
		if row != null and row.track_ref == track:
			if is_ult:
				if row.ult_slot != null:
					row.ult_slot.modulate.a = 0.25 if lifted else 1.0
			elif slot_idx >= 0 and slot_idx < row.diamond_slots.size():
				if row.diamond_slots[slot_idx] != null:
					row.diamond_slots[slot_idx].modulate.a = 0.25 if lifted else 1.0

func _find_drop_target_at_pos(pos: Vector2) -> Dictionary:
	if floating_shard_dock != null and floating_shard_dock.visible:
		if floating_shard_dock.get_global_rect().has_point(pos) or (description_panel != null and description_panel.get_global_rect().has_point(pos)):
			return { "type": "dock" }

	for row in track_rows:
		if row == null or not row.visible or row.track_ref == null or row.track_color <= 0:
			continue
		if not row.get_global_rect().has_point(pos):
			continue

		if row.ult_slot != null and row.ult_slot.visible and row.ult_slot.get_global_rect().has_point(pos):
			return {
				"type": "slot",
				"track": row.track_ref,
				"is_ult": true,
				"slot_idx": -1
			}

		for i in range(row.diamond_slots.size()):
			var s: OverlaySlotUI = row.diamond_slots[i]
			if s != null and s.visible and s.get_global_rect().has_point(pos):
				return {
					"type": "slot",
					"track": row.track_ref,
					"is_ult": false,
					"slot_idx": i
				}

		return {
			"type": "slot",
			"track": row.track_ref,
			"is_ult": _drag_candidate_item != null and _drag_candidate_item.is_ultimate,
			"slot_idx": -1
		}

	return { "type": "none" }

func _unhandled_input(event: InputEvent) -> void:
	if is_slotting_mode:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I):
			_on_done_btn_pressed()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif not Global.game_is_over:
			open()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			if visible:
				close()
				get_viewport().set_input_as_handled()
			elif not Global.game_is_over:
				open()
				get_viewport().set_input_as_handled()

func _build_ui_if_needed() -> void:
	dimmer = get_node_or_null("Dimmer") as ColorRect
	if dimmer == null:
		dimmer = ColorRect.new()
		dimmer.name = "Dimmer"
		dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		dimmer.color = Color(0.06, 0.05, 0.09, 0.72)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dimmer)
	if not dimmer.gui_input.is_connected(_on_dimmer_gui_input):
		dimmer.gui_input.connect(_on_dimmer_gui_input)

	var center := get_node_or_null("Center") as CenterContainer
	if center == null:
		center = CenterContainer.new()
		center.name = "Center"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(center)

	main_panel = center.get_node_or_null("MainPanel") as NinePatchRect
	if main_panel == null:
		main_panel = NinePatchRect.new()
		main_panel.name = "MainPanel"
		main_panel.texture = TEX_OVERLAY_BG
		main_panel.patch_margin_left = 6
		main_panel.patch_margin_top = 6
		main_panel.patch_margin_right = 6
		main_panel.patch_margin_bottom = 6
		main_panel.custom_minimum_size = Vector2(548, 970)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(main_panel)

	var margin := main_panel.get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_PASS
		main_panel.add_child(margin)

	var vbox := margin.get_node_or_null("ContentVBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "ContentVBox"
		vbox.add_theme_constant_override("separation", 6)
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		margin.add_child(vbox)

	# Optional Header Label (only configured if present in scene)
	header_label = vbox.find_child("HeaderLabel", true, false) as Label
	if header_label != null:
		header_label.text = header_title
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_label.add_theme_font_override("font", TITLE_FONT)
		header_label.add_theme_font_size_override("font_size", 28)
		header_label.add_theme_color_override("font_color", Color("#2e2633"))

	# 2. Views Container or Direct Views in ContentVBox
	loadout_view = vbox.find_child("LoadoutView", true, false) as VBoxContainer
	if loadout_view == null:
		loadout_view = VBoxContainer.new()
		loadout_view.name = "LoadoutView"
		loadout_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		loadout_view.add_theme_constant_override("separation", 8)
		vbox.add_child(loadout_view)

	# Passives Ring Section (342x313 pentagonal ring)
	passives_ring = vbox.find_child("PassivesRing", true, false) as InventoryOverlayPassivesRing
	if passives_ring == null:
		if PASSIVES_RING_SCENE != null:
			passives_ring = PASSIVES_RING_SCENE.instantiate() as InventoryOverlayPassivesRing
		if passives_ring == null:
			passives_ring = InventoryOverlayPassivesRing.new()
		passives_ring.name = "PassivesRing"
		passives_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		loadout_view.add_child(passives_ring)
	elif passives_ring.get_parent() != loadout_view and loadout_view != null:
		passives_ring.reparent(loadout_view)

	if not passives_ring.passive_clicked.is_connected(_on_passive_clicked):
		passives_ring.passive_clicked.connect(_on_passive_clicked)
	if not passives_ring.passive_dropped.is_connected(_on_passive_dropped):
		passives_ring.passive_dropped.connect(_on_passive_dropped)

	# Optional spacer (hidden/disabled if passives ring is present)
	spacer = vbox.find_child("TopSpacer", true, false) as Control
	if spacer != null:
		spacer.visible = false
		spacer.size_flags_vertical = 0

	# Loadout Tracks Section (5 rows)
	tracks_box = vbox.find_child("TracksBox", true, false) as VBoxContainer
	if tracks_box == null:
		tracks_box = VBoxContainer.new()
		tracks_box.name = "TracksBox"
		tracks_box.add_theme_constant_override("separation", 4)
		loadout_view.add_child(tracks_box)
	elif tracks_box.get_parent() != loadout_view and loadout_view != null:
		tracks_box.reparent(loadout_view)

	if track_rows.is_empty():
		for child in tracks_box.get_children():
			var r := child as InventoryOverlayTrackRow
			if r != null:
				if not r.slot_clicked.is_connected(_on_slot_clicked):
					r.slot_clicked.connect(_on_slot_clicked)
				if not r.slot_drag_requested.is_connected(_on_row_slot_drag_requested):
					r.slot_drag_requested.connect(_on_row_slot_drag_requested)
				if not r.equipment_dropped.is_connected(_on_equipment_dropped):
					r.equipment_dropped.connect(_on_equipment_dropped)
				track_rows.append(r)

		while track_rows.size() < 5:
			var i: int = track_rows.size()
			var row: InventoryOverlayTrackRow = null
			if TRACK_ROW_SCENE != null:
				row = TRACK_ROW_SCENE.instantiate() as InventoryOverlayTrackRow
			if row == null:
				row = InventoryOverlayTrackRow.new()
			row.name = "TrackRow_%d" % i
			row.slot_clicked.connect(_on_slot_clicked)
			row.slot_drag_requested.connect(_on_row_slot_drag_requested)
			row.equipment_dropped.connect(_on_equipment_dropped)
			tracks_box.add_child(row)
			track_rows.append(row)

	# Ability Description Field (full-width 520x160 NinePatchRect as in normal inventory screen)
	description_panel = vbox.find_child("DescriptionPanel", true, false) as NinePatchRect
	if description_panel == null:
		description_panel = NinePatchRect.new()
		description_panel.name = "DescriptionPanel"
		description_panel.texture = TEX_DESC_PANEL
		description_panel.patch_margin_left = 4
		description_panel.patch_margin_top = 4
		description_panel.patch_margin_right = 4
		description_panel.patch_margin_bottom = 4
		description_panel.custom_minimum_size = Vector2(520, description_panel_height)
		description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		loadout_view.add_child(description_panel)
	else:
		description_panel.custom_minimum_size = Vector2(520, description_panel_height)
		description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if description_panel.get_parent() != loadout_view and loadout_view != null:
			description_panel.reparent(loadout_view)

	# Clean up obsolete DescriptionRow if present
	var old_row := loadout_view.find_child("DescriptionRow", true, false)
	if old_row != null and old_row != description_panel:
		old_row.queue_free()

	var d_margin := description_panel.find_child("Margin", true, false) as MarginContainer
	if d_margin == null:
		d_margin = MarginContainer.new()
		d_margin.name = "Margin"
		d_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		d_margin.add_theme_constant_override("margin_left", 14)
		d_margin.add_theme_constant_override("margin_top", 10)
		d_margin.add_theme_constant_override("margin_right", 14)
		d_margin.add_theme_constant_override("margin_bottom", 10)
		description_panel.add_child(d_margin)

	description_hbox = d_margin.find_child("DescriptionHBox", true, false) as HBoxContainer
	if description_hbox == null:
		description_hbox = HBoxContainer.new()
		description_hbox.name = "DescriptionHBox"
		description_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		description_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description_hbox.add_theme_constant_override("separation", 8)
		d_margin.add_child(description_hbox)

	var scroll := description_hbox.find_child("Scroll", true, false) as ScrollContainer
	if scroll == null:
		scroll = d_margin.find_child("Scroll", true, false) as ScrollContainer
		if scroll == null:
			scroll = ScrollContainer.new()
			scroll.name = "Scroll"
			scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			description_hbox.add_child(scroll)
		else:
			scroll.reparent(description_hbox)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	description_label = scroll.find_child("DescriptionLabel", true, false) as RichTextLabel
	if description_label == null:
		description_label = RichTextLabel.new()
		description_label.name = "DescriptionLabel"
		description_label.bbcode_enabled = true
		description_label.fit_content = true
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description_label.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll.add_child(description_label)
	_style_description_label()

	# Floating Shard Dock (Slotting Mode only, on top of DescriptionPanel on the right side)
	floating_shard_dock = vbox.find_child("FloatingShardDock", true, false) as FloatingShardDock
	if floating_shard_dock == null:
		floating_shard_dock = FloatingShardDock.new()
		floating_shard_dock.name = "FloatingShardDock"
		description_hbox.add_child(floating_shard_dock)
	else:
		if floating_shard_dock.get_parent() != description_hbox:
			floating_shard_dock.reparent(description_hbox)
	floating_shard_dock.size_flags_horizontal = Control.SIZE_SHRINK_END
	floating_shard_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	floating_shard_dock.custom_minimum_size = FloatingShardDock.DOCK_SIZE
	floating_shard_dock.visible = is_slotting_mode
	if not floating_shard_dock.shard_selected.is_connected(_on_floating_shard_selected):
		floating_shard_dock.shard_selected.connect(_on_floating_shard_selected)
	if not floating_shard_dock.drag_requested.is_connected(_on_floating_shard_drag_requested):
		floating_shard_dock.drag_requested.connect(_on_floating_shard_drag_requested)
	if not floating_shard_dock.shard_dropped_on_dock.is_connected(_on_shard_dropped_to_dock):
		floating_shard_dock.shard_dropped_on_dock.connect(_on_shard_dropped_to_dock)

	# Ensure horizontal ordering: Description text on left, FloatingShardDock on right
	if scroll != null and scroll.get_parent() == description_hbox:
		description_hbox.move_child(scroll, 0)
	if floating_shard_dock != null and floating_shard_dock.get_parent() == description_hbox:
		description_hbox.move_child(floating_shard_dock, 1)

	if drag_avatar == null:
		drag_avatar = DragAvatarClass.new()
		drag_avatar.name = "DragAvatar"
		add_child(drag_avatar)

	# 3. Stats View (empty placeholder for future design)
	stats_view = vbox.find_child("StatsView", true, false) as Control
	if stats_view == null:
		stats_view = Control.new()
		stats_view.name = "StatsView"
		stats_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_view.visible = false
		vbox.add_child(stats_view)

	# 4. Settings View (CenterContainer with 4 buttons)
	settings_view = vbox.find_child("SettingsView", true, false) as Control
	if settings_view == null:
		settings_view = CenterContainer.new()
		settings_view.name = "SettingsView"
		settings_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		settings_view.visible = false
		vbox.add_child(settings_view)

	settings_vbox = settings_view.find_child("SettingsVBox", true, false) as VBoxContainer
	if settings_vbox == null:
		settings_vbox = VBoxContainer.new()
		settings_vbox.name = "SettingsVBox"
		settings_vbox.custom_minimum_size = Vector2(280, 0)
		settings_vbox.add_theme_constant_override("separation", 14)
		settings_view.add_child(settings_vbox)

	almanac_btn = settings_vbox.find_child("AlmanacBtn", true, false) as Button
	if almanac_btn == null:
		almanac_btn = _create_nav_button("Almanac", true)
		almanac_btn.name = "AlmanacBtn"
		almanac_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(almanac_btn)

	sound_btn = settings_vbox.find_child("SoundBtn", true, false) as Button
	if sound_btn == null:
		sound_btn = _create_nav_button("Sound", true)
		sound_btn.name = "SoundBtn"
		sound_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(sound_btn)

	graphics_btn = settings_vbox.find_child("GraphicsBtn", true, false) as Button
	if graphics_btn == null:
		graphics_btn = _create_nav_button("Graphics", true)
		graphics_btn.name = "GraphicsBtn"
		graphics_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(graphics_btn)

	main_menu_btn = settings_vbox.find_child("MainMenuBtn", true, false) as Button
	if main_menu_btn == null:
		main_menu_btn = _create_nav_button("Main Menu", false)
		main_menu_btn.name = "MainMenuBtn"
		main_menu_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(main_menu_btn)

	if not main_menu_btn.pressed.is_connected(_on_main_menu_pressed):
		main_menu_btn.pressed.connect(_on_main_menu_pressed)

	# 5. Bottom Navigation Row (Loadout, Stats, Settings)
	bottom_nav_box = vbox.find_child("BottomNavBox", true, false) as HBoxContainer
	if bottom_nav_box == null:
		bottom_nav_box = HBoxContainer.new()
		bottom_nav_box.name = "BottomNavBox"
		bottom_nav_box.custom_minimum_size = Vector2(520, 44)
		bottom_nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_nav_box.add_theme_constant_override("separation", 8)
		vbox.add_child(bottom_nav_box)

	# 5a. Stats Nav Button (Left: index 0)
	stats_nav_btn = bottom_nav_box.find_child("NavBtn_Stats", true, false) as Button
	if stats_nav_btn == null:
		stats_nav_btn = _create_nav_button("Stats")
		stats_nav_btn.name = "NavBtn_Stats"
		bottom_nav_box.add_child(stats_nav_btn)
	else:
		stats_nav_btn.text = "Stats"
	if not stats_nav_btn.pressed.is_connected(_on_stats_nav_pressed):
		stats_nav_btn.pressed.connect(_on_stats_nav_pressed)

	# 5b. Loadout Nav Button (Middle: index 1)
	loadout_nav_btn = bottom_nav_box.find_child("NavBtn_Loadout", true, false) as Button
	if loadout_nav_btn == null:
		var old_btn := bottom_nav_box.find_child("NavBtn_Inventory", true, false) as Button
		if old_btn != null:
			loadout_nav_btn = old_btn
			loadout_nav_btn.name = "NavBtn_Loadout"
			loadout_nav_btn.text = "Loadout"
		else:
			loadout_nav_btn = _create_nav_button("Loadout")
			loadout_nav_btn.name = "NavBtn_Loadout"
			bottom_nav_box.add_child(loadout_nav_btn)
	else:
		loadout_nav_btn.text = "Loadout"
	if not loadout_nav_btn.pressed.is_connected(_on_loadout_nav_pressed):
		loadout_nav_btn.pressed.connect(_on_loadout_nav_pressed)

	# 5c. Settings Nav Button (Right: index 2)
	settings_nav_btn = bottom_nav_box.find_child("NavBtn_Settings", true, false) as Button
	if settings_nav_btn == null:
		settings_nav_btn = _create_nav_button("Settings")
		settings_nav_btn.name = "NavBtn_Settings"
		bottom_nav_box.add_child(settings_nav_btn)
	else:
		settings_nav_btn.text = "Settings"
	if not settings_nav_btn.pressed.is_connected(_on_settings_nav_pressed):
		settings_nav_btn.pressed.connect(_on_settings_nav_pressed)

	# Explicitly ensure child order: 0 = Loadout, 1 = Stats, 2 = Settings
	bottom_nav_box.move_child(loadout_nav_btn, 0)
	bottom_nav_box.move_child(stats_nav_btn, 1)
	bottom_nav_box.move_child(settings_nav_btn, 2)

	# 5d. Done Nav Button (Slotting Mode only)
	done_btn = bottom_nav_box.find_child("NavBtn_Done", true, false) as Button
	if done_btn == null:
		done_btn = _create_nav_button("Done")
		done_btn.name = "NavBtn_Done"
		bottom_nav_box.add_child(done_btn)
	else:
		done_btn.text = "Done"
	done_btn.visible = is_slotting_mode
	if not done_btn.pressed.is_connected(_on_done_btn_pressed):
		done_btn.pressed.connect(_on_done_btn_pressed)

func _create_nav_button(btn_text: String, is_disabled: bool = false) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(100, 44)

	var sb_normal := StyleBoxTexture.new()
	sb_normal.texture = TEX_GENERAL_BTN
	sb_normal.texture_margin_left = 4
	sb_normal.texture_margin_top = 4
	sb_normal.texture_margin_right = 4
	sb_normal.texture_margin_bottom = 4
	sb_normal.content_margin_left = 10
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_right = 10
	sb_normal.content_margin_bottom = 6

	var sb_hover := sb_normal.duplicate() as StyleBoxTexture
	sb_hover.modulate_color = Color(1.12, 1.12, 1.12, 1.0)

	var sb_pressed := sb_normal.duplicate() as StyleBoxTexture
	sb_pressed.modulate_color = Color(0.85, 0.85, 0.85, 1.0)

	var sb_disabled := sb_normal.duplicate() as StyleBoxTexture
	sb_disabled.modulate_color = Color(0.65, 0.65, 0.65, 0.7)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#2e2633"))
	btn.add_theme_color_override("font_hover_color", Color("#17121b"))
	btn.add_theme_color_override("font_pressed_color", Color("#100c14"))
	btn.add_theme_color_override("font_disabled_color", Color(0.44, 0.38, 0.46, 0.8))
	btn.disabled = is_disabled
	return btn

## Switches the visible tab view between Loadout, Stats, and Settings.
func switch_tab(tab: Tab) -> void:
	current_tab = tab
	_build_ui_if_needed()

	if loadout_view != null:
		loadout_view.visible = (tab == Tab.LOADOUT)
	if stats_view != null:
		stats_view.visible = (tab == Tab.STATS)
	if settings_view != null:
		settings_view.visible = (tab == Tab.SETTINGS)

	match tab:
		Tab.LOADOUT:
			if header_label != null:
				header_label.text = "Loadout"
			_update_nav_button_highlights(loadout_nav_btn)
			refresh_overlay_data()
		Tab.STATS:
			if header_label != null:
				header_label.text = "Stats"
			_update_nav_button_highlights(stats_nav_btn)
		Tab.SETTINGS:
			if header_label != null:
				header_label.text = "Settings"
			_update_nav_button_highlights(settings_nav_btn)

func _update_nav_button_highlights(active_btn: Button) -> void:
	for btn in [loadout_nav_btn, stats_nav_btn, settings_nav_btn]:
		if btn == null:
			continue
		if btn == active_btn:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.modulate = Color(0.72, 0.72, 0.78, 0.85)

func _on_loadout_nav_pressed() -> void:
	if current_tab == Tab.LOADOUT and visible:
		close()
		return
	switch_tab(Tab.LOADOUT)

func _on_stats_nav_pressed() -> void:
	if current_tab == Tab.STATS and visible:
		close()
		return
	switch_tab(Tab.STATS)

func _on_settings_nav_pressed() -> void:
	if current_tab == Tab.SETTINGS and visible:
		close()
		return
	switch_tab(Tab.SETTINGS)

func _on_main_menu_pressed() -> void:
	close()
	Global.game_is_played = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		tree = get_tree()
	if tree != null:
		var sm = tree.root.get_node_or_null("SceneManager")
		if sm != null and sm.has_method("change_scene"):
			sm.change_scene("res://ui/screens/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })
		else:
			tree.change_scene_to_file("res://ui/screens/main_menu.tscn")

## Refreshes all 5 loadout tracks, passives, and description from Global.cur_char.
func refresh_overlay_data() -> void:
	_build_ui_if_needed()
	if Global.cur_char == null:
		_show_empty_description()
		return

	Global.cur_char.ensure_loadout_tracks()
	var current_pool: Array[int] = Global.cur_char.active_color_pool
	if current_pool.is_empty():
		current_pool = [100, 200, 300, 500]

	# 1. Update 5 Track Rows
	for slot_idx in range(track_rows.size()):
		var row: InventoryOverlayTrackRow = track_rows[slot_idx]
		if slot_idx < current_pool.size():
			var c_id: int = current_pool[slot_idx]
			var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
			row.setup_row(c_id, track)
		else:
			row.setup_row(0, null)

	if is_slotting_mode:
		for row in track_rows:
			row.set_compatibility_state(_cached_floating_equipment)

	# 2. Update Passives Ring
	var passives: Array = Global.cur_char.equipped_passives if Global.cur_char != null else []
	if passives_ring != null:
		passives_ring.setup_passives(passives)
		if selected_passive_idx >= 0:
			passives_ring.update_selection(selected_passive_idx)
		else:
			passives_ring.update_selection(-1)

	# 3. Update Selection & Description
	if selected_ability != null:
		_display_ability_description(selected_ability, selected_track.color if selected_track != null else 0, selected_is_ult)
	elif selected_passive != null:
		_display_passive_description(selected_passive)
	elif selected_passive_idx >= 0:
		_show_passive_empty_description()
	else:
		_show_empty_description()

func _on_slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ult: bool, slot_idx: int) -> void:
	selected_passive = null
	selected_passive_idx = -1
	if passives_ring != null:
		passives_ring.update_selection(-1)

	selected_ability = mod
	selected_track = track
	selected_is_ult = is_ult
	selected_slot_idx = slot_idx

	# Update selection highlight across all rows
	for row in track_rows:
		var is_same_track: bool = (row.track_ref == track)
		row.update_selection(mod, is_ult, slot_idx, is_same_track)

	if mod != null:
		_display_ability_description(mod, track.color if track != null else 0, is_ult)
		ability_selected.emit(mod, track, is_ult, slot_idx)
	else:
		_show_slot_empty_description(track, is_ult)

func _is_equipment_equipped_anywhere(eq: Equipment) -> bool:
	if eq == null:
		return false
	if Global.cur_char != null:
		for c_id in Global.cur_char.active_color_pool:
			var tr: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
			if tr != null and (tr.ultimate_skill == eq or eq in tr.equipped_modifiers):
				return true
	for row in track_rows:
		if row != null and row.track_ref != null:
			var tr: ColorLoadoutTrack = row.track_ref
			if tr.ultimate_skill == eq or eq in tr.equipped_modifiers:
				return true
	return false

## Handles moving, swapping, and reordering equipment via drag-and-drop.
func _on_equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int) -> bool:
	if Global.cur_char == null or target_track == null:
		return false

	var source_mod: Equipment = drag_data.get("modifier") as Equipment
	var source_is_floating: bool = drag_data.get("source_is_floating", false)

	if source_is_floating:
		return _handle_floating_shard_drop(source_mod, target_track, target_is_ult, target_slot_idx)

	var source_track: ColorLoadoutTrack = drag_data.get("source_track") as ColorLoadoutTrack
	var source_is_ult: bool = drag_data.get("source_is_ult", false)

	if source_mod == null or source_track == null:
		return false

	# Type mismatch check: ultimate must match ultimate slot
	if source_is_ult != target_is_ult:
		return false

	# Color compatibility check
	if not target_track.is_color_compatible(source_mod):
		return false

	var changed: bool = false
	if target_is_ult:
		# Ultimate Drag-and-Drop:
		if source_track == target_track:
			return false
		var existing_target_ult: Equipment = target_track.ultimate_skill
		if existing_target_ult != null:
			if source_track.is_color_compatible(existing_target_ult):
				source_track.unequip_ultimate()
				target_track.unequip_ultimate()
				source_track.equip_ultimate(existing_target_ult)
				target_track.equip_ultimate(source_mod)
				changed = true
			else:
				return false
		else:
			source_track.unequip_ultimate()
			target_track.equip_ultimate(source_mod)
			changed = true
	else:
		# Basic Ability Drag-and-Drop:
		if source_track == target_track:
			# Reordering within the SAME track
			var s_idx: int = source_track.equipped_modifiers.find(source_mod)
			if s_idx != -1:
				var target_mod: Equipment = target_track.get_modifier_at_slot_index(target_slot_idx) if target_slot_idx >= 0 else null
				if target_mod != null and target_mod != source_mod:
					var t_idx: int = target_track.equipped_modifiers.find(target_mod)
					if t_idx != -1:
						target_track.equipped_modifiers[s_idx] = target_mod
						target_track.equipped_modifiers[t_idx] = source_mod
						changed = true
				elif target_mod == null:
					source_track.equipped_modifiers.remove_at(s_idx)
					source_track.equipped_modifiers.append(source_mod)
					changed = true
		else:
			# Moving or swapping BETWEEN DIFFERENT tracks
			var target_mod: Equipment = target_track.get_modifier_at_slot_index(target_slot_idx) if target_slot_idx >= 0 else null
			if target_mod != null:
				# Swapping two abilities between tracks
				if source_track.is_color_compatible(target_mod):
					var s_idx: int = source_track.equipped_modifiers.find(source_mod)
					var t_idx: int = target_track.equipped_modifiers.find(target_mod)
					if s_idx != -1 and t_idx != -1:
						var s_cost: int = clampi(source_mod.slot_cost, 1, target_track.max_slots)
						var t_cost: int = clampi(target_mod.slot_cost, 1, source_track.max_slots)
						var free_in_target: int = target_track.get_free_slots() + t_cost
						var free_in_source: int = source_track.get_free_slots() + s_cost
						if free_in_target >= s_cost and free_in_source >= t_cost:
							source_track.equipped_modifiers.remove_at(s_idx)
							target_track.equipped_modifiers.remove_at(t_idx)
							source_track.equip_modifier(target_mod, s_idx)
							target_track.equip_modifier(source_mod, t_idx)
							changed = true
			else:
				# Moving into empty space on target track
				var s_cost: int = clampi(source_mod.slot_cost, 1, target_track.max_slots)
				if target_track.get_free_slots() >= s_cost and not (source_mod in target_track.equipped_modifiers):
					source_track.unequip_modifier(source_mod)
					target_track.equip_modifier(source_mod)
					changed = true

	if not changed:
		return false

	source_track.clamp_cursor()
	target_track.clamp_cursor()
	source_track.check_ultimate_ready_at_cycle_start()
	target_track.check_ultimate_ready_at_cycle_start()

	if Global.cur_char != null:
		Global.cur_char.recalculate_equipment_passives()
		Global.cur_char.loadoutChanged.emit()

	refresh_overlay_data()
	_on_slot_clicked(source_mod, target_track, target_is_ult, target_slot_idx)
	return true

func _handle_floating_shard_drop(source_mod: Equipment, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int) -> bool:
	if target_track == null or source_mod == null:
		return false
	if not target_track.is_color_compatible(source_mod):
		return false
	if _is_equipment_equipped_anywhere(source_mod):
		push_warning("InventoryOverlay: Prevented duplicating already-equipped shard '%s'." % source_mod.piece_name)
		return false

	var displaced_item: Equipment = null

	if target_is_ult:
		if not source_mod.is_ultimate:
			return false
		displaced_item = target_track.ultimate_skill
		target_track.unequip_ultimate()
		if not target_track.equip_ultimate(source_mod):
			if displaced_item != null:
				target_track.equip_ultimate(displaced_item)
			return false
	else:
		if source_mod.is_ultimate:
			return false
		var needed_slots: int = clampi(source_mod.slot_cost, 1, target_track.max_slots)
		if needed_slots > target_track.max_slots:
			return false
		var target_mod: Equipment = target_track.get_modifier_at_slot_index(target_slot_idx) if target_slot_idx >= 0 else null
		if target_mod != null:
			# Replacing an occupied slot
			var t_idx: int = target_track.equipped_modifiers.find(target_mod)
			if t_idx != -1:
				displaced_item = target_mod
				target_track.equipped_modifiers.remove_at(t_idx)
				while target_track.get_free_slots() < needed_slots and not target_track.equipped_modifiers.is_empty():
					var extra_displaced: Equipment = target_track.equipped_modifiers.pop_back()
					if extra_displaced != null:
						pending_slotting_queue.push_front(extra_displaced)
				if not target_track.equip_modifier(source_mod, t_idx):
					return false
		else:
			# Dropping onto empty slot or row
			if target_track.can_equip(source_mod):
				if not target_track.equip_modifier(source_mod, target_slot_idx):
					return false
			else:
				# Track full or not enough slots: displace from end without losing extra items
				while not target_track.can_equip(source_mod) and not target_track.equipped_modifiers.is_empty():
					var popped: Equipment = target_track.equipped_modifiers.pop_back()
					if popped != null:
						if displaced_item == null:
							displaced_item = popped
						else:
							pending_slotting_queue.push_front(popped)
				if not target_track.equip_modifier(source_mod):
					return false

	# Displaced item becomes the new floating shard so the player can keep moving shards
	if displaced_item != null:
		set_floating_equipment(displaced_item)
	else:
		if not pending_slotting_queue.is_empty():
			set_floating_equipment(pending_slotting_queue.pop_front())
		else:
			set_floating_equipment(null)

	target_track.clamp_cursor()
	target_track.check_ultimate_ready_at_cycle_start()
	if Global.cur_char != null:
		Global.cur_char.recalculate_equipment_passives()
		Global.cur_char.loadoutChanged.emit()

	refresh_overlay_data()
	_on_slot_clicked(source_mod, target_track, target_is_ult, target_slot_idx)
	return true

func _on_shard_dropped_to_dock(drag_data: Dictionary) -> bool:
	if not is_slotting_mode:
		return false
	var source_mod: Equipment = drag_data.get("modifier") as Equipment
	var source_track: ColorLoadoutTrack = drag_data.get("source_track") as ColorLoadoutTrack
	var source_is_ult: bool = drag_data.get("source_is_ult", false)
	if source_mod == null or source_track == null:
		return false

	var changed: bool = false
	var old_floating: Equipment = _cached_floating_equipment
	if old_floating == null:
		if source_is_ult:
			source_track.unequip_ultimate()
			changed = true
		else:
			changed = source_track.unequip_modifier(source_mod)
		if changed:
			set_floating_equipment(source_mod)
	else:
		if source_track.is_color_compatible(old_floating) and source_is_ult == old_floating.is_ultimate:
			if source_is_ult:
				source_track.unequip_ultimate()
				if source_track.equip_ultimate(old_floating):
					set_floating_equipment(source_mod)
					changed = true
				else:
					source_track.equip_ultimate(source_mod)
			else:
				var s_idx: int = source_track.equipped_modifiers.find(source_mod)
				if s_idx != -1:
					source_track.equipped_modifiers.remove_at(s_idx)
					if source_track.get_free_slots() >= clampi(old_floating.slot_cost, 1, source_track.max_slots):
						source_track.equip_modifier(old_floating, s_idx)
						set_floating_equipment(source_mod)
						changed = true
					else:
						source_track.equip_modifier(source_mod, s_idx)

	if not changed:
		return false

	source_track.clamp_cursor()
	source_track.check_ultimate_ready_at_cycle_start()
	if Global.cur_char != null:
		Global.cur_char.recalculate_equipment_passives()
		Global.cur_char.loadoutChanged.emit()
	refresh_overlay_data()
	return true

func _on_floating_shard_selected(eq: Equipment) -> void:
	if eq == null:
		_show_empty_description()
		return
	selected_ability = eq
	selected_track = null
	selected_is_ult = eq.is_ultimate
	selected_slot_idx = -2
	for row in track_rows:
		row.update_selection(null, false, -2, false)
	var c_id: int = _get_equipment_color(eq)
	_display_ability_description(eq, c_id, eq.is_ultimate)

func _on_done_btn_pressed() -> void:
	_cleanup_custom_drag()
	if is_slotting_mode:
		_cached_floating_equipment = null
		pending_slotting_queue.clear()
		if floating_shard_dock != null:
			floating_shard_dock.set_equipment(null)
		for row in track_rows:
			row.set_compatibility_state(null)
		is_slotting_mode = false
		_update_slotting_mode_ui(false)
		close()
		slotting_completed.emit()

func _on_passive_clicked(slot_idx: int, passive_res: Resource) -> void:
	selected_ability = null
	selected_track = null
	selected_is_ult = false
	selected_slot_idx = -2

	# Deselect track highlights across all rows
	for row in track_rows:
		row.update_selection(null, false, -2, false)

	selected_passive_idx = slot_idx
	selected_passive = passive_res

	if passives_ring != null:
		passives_ring.update_selection(slot_idx)

	if passive_res != null:
		_display_passive_description(passive_res)
	else:
		_show_passive_empty_description()

func _on_passive_dropped(source_idx: int, target_idx: int) -> void:
	if Global.cur_char == null:
		return
	var passives: Array = Global.cur_char.equipped_passives
	if source_idx < 0 or source_idx >= passives.size():
		return
	if target_idx < 0 or target_idx >= passives.size():
		return
	if source_idx == target_idx:
		return

	var temp = passives[source_idx]
	passives[source_idx] = passives[target_idx]
	passives[target_idx] = temp

	Global.cur_char.recalculate_passive_bonuses()
	Global.cur_char.passivesChanged.emit()
	Global.cur_char.loadoutChanged.emit()

	refresh_overlay_data()
	_on_passive_clicked(target_idx, passives[target_idx])

func _display_ability_description(mod: Equipment, color_id: int, is_ult: bool) -> void:
	if description_label == null:
		return
	description_label.text = _format_ability_bbcode(mod, color_id, is_ult)

func _display_passive_description(p_res: Resource) -> void:
	if description_label == null:
		return
	description_label.text = _format_passive_bbcode(p_res)

func _style_description_label() -> void:
	if description_label == null:
		return
	description_label.add_theme_font_override("normal_font", BODY_FONT)
	description_label.add_theme_font_override("bold_font", TITLE_FONT)
	description_label.add_theme_color_override("default_color", Color("#f4f1f8"))
	description_label.add_theme_color_override("font_outline_color", Color("#1e1824"))
	description_label.add_theme_constant_override("outline_size", 3)
	description_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.12, 0.75))
	description_label.add_theme_constant_override("shadow_offset_x", 1)
	description_label.add_theme_constant_override("shadow_offset_y", 1)
	description_label.add_theme_constant_override("line_separation", 2)

static func _get_dark_panel_rarity_hex(r: int) -> String:
	match r:
		Equipment.Rarity.COMMON: return "#e6e2ec"
		Equipment.Rarity.UNCOMMON: return "#72e89d"
		Equipment.Rarity.RARE: return "#7eb8ff"
		Equipment.Rarity.EPIC: return "#e394ff"
		Equipment.Rarity.LEGENDARY: return "#ffd966"
		Equipment.Rarity.GODLY: return "#7bf0ff"
	return "#e6e2ec"

static func _remap_colors_for_dark_panel(bbcode_str: String) -> String:
	return bbcode_str \
		.replace("#ae2334", "#ff7b7b") \
		.replace("#7a3045", "#ffb86c") \
		.replace("#3ca370", "#72e89d") \
		.replace("#4d65b4", "#7eb8ff") \
		.replace("#a854a8", "#e394ff") \
		.replace("#b0b0b0", "#e6e2ec")

func _show_empty_description() -> void:
	if description_label == null:
		return
	description_label.text = "[center][color=#d6d0e0]\nSelect an ability or passive to view its details.[/color][/center]"

func _show_slot_empty_description(track: ColorLoadoutTrack, is_ult: bool) -> void:
	if description_label == null:
		return
	var c_name := ColorLoadoutTrack.get_color_name(track.color) if track != null else "Passive"
	var type_str := "Ultimate Slot" if is_ult else "Slot"
	description_label.text = "[center][color=#d6d0e0]\nEmpty %s %s\nEquip abilities by acquiring them during your run.[/color][/center]" % [c_name, type_str]

func _show_passive_empty_description() -> void:
	if description_label == null:
		return
	description_label.text = "[center][color=#d6d0e0]\nEmpty Passive Slot\nAcquire passives during your run to fill this slot.[/color][/center]"

func _format_passive_bbcode(p_res: Resource) -> String:
	if p_res == null:
		return ""

	var text := ""
	if p_res is Reward:
		var rew := p_res as Reward
		var r_color := _get_dark_panel_rarity_hex(int(rew.rarity))
		var r_name := Equipment.get_rarity_name(int(rew.rarity))
		text += "[font_size=18][b][color=%s]%s[/color][/b][/font_size]\n" % [r_color, rew.name]
		text += "[font_size=12][color=#d6d0e0]%s  •  Passive Card[/color][/font_size]\n" % r_name
		var eff := _remap_colors_for_dark_panel(rew.get_effect_description())
		if not eff.is_empty():
			text += "[font_size=14]%s[/font_size]\n" % eff
	elif p_res is Equipment:
		var eq := p_res as Equipment
		var r_color := _get_dark_panel_rarity_hex(eq.rarity)
		var r_name := Equipment.get_rarity_name(eq.rarity)
		text += "[font_size=18][b][color=%s]%s[/color][/b][/font_size]\n" % [r_color, eq.piece_name]
		text += "[font_size=12][color=#d6d0e0]%s  •  Passive Equipment[/color][/font_size]\n" % r_name
		var eff := _remap_colors_for_dark_panel(eq.get_effect_description())
		if not eff.is_empty():
			text += "[font_size=14]%s[/font_size]\n" % eff
		var boosts := eq.get_stat_boosts()
		if not boosts.is_empty() and not eff.contains("• "):
			var stat_parts: Array[String] = []
			for stat_name in boosts:
				var val: float = boosts[stat_name]
				var sign_str := "+" if val > 0 else ""
				stat_parts.append("%s%s %s" % [sign_str, str(int(roundf(val))), stat_name.capitalize()])
			if not stat_parts.is_empty():
				text += "[font_size=12][color=#8ff0a4]Passive Stats: %s[/color][/font_size]" % ", ".join(stat_parts)
	else:
		var p_name: String = p_res.get("piece_name") if p_res.get("piece_name") != null else (p_res.get("name") if p_res.get("name") != null else "Passive")
		text += "[font_size=18][b][color=#ffffff]%s[/color][/b][/font_size]\n" % p_name
		text += "[font_size=12][color=#d6d0e0]Passive[/color][/font_size]\n"
		var desc: String = p_res.get("description") if p_res.get("description") != null else ""
		if not desc.is_empty():
			text += "[font_size=14]%s[/font_size]\n" % desc
	return text

func _format_ability_bbcode(mod: Equipment, color_id: int, is_ult: bool) -> String:
	if mod == null:
		return ""

	var r_color := _get_dark_panel_rarity_hex(mod.rarity)
	var r_name := Equipment.get_rarity_name(mod.rarity)
	var c_name := ColorLoadoutTrack.get_color_name(color_id) if color_id > 0 else "Wild"

	var text := ""
	# Title
	text += "[font_size=18][b][color=%s]%s[/color][/b][/font_size]\n" % [r_color, mod.piece_name]

	# Subtitle
	var type_str := "Ultimate" if (is_ult or mod.is_ultimate) else ("%d Slot%s" % [mod.slot_cost, "" if mod.slot_cost == 1 else "s"])
	var color_tag := "%s Track" % c_name if color_id > 0 else "Wild / Any Track"
	text += "[font_size=12][color=#d6d0e0]%s  •  %s  •  %s[/color][/font_size]\n" % [r_name, type_str, color_tag]

	# Trigger condition (if basic ability)
	if not is_ult and not mod.is_ultimate:
		var trig_desc := _get_trigger_description(mod.trigger_condition)
		text += "[font_size=13][color=#ffd966]Trigger:[/color] [color=#ffffff]%s[/color][/font_size]\n" % trig_desc

	# Effect text (remapped for high contrast on dark purple panel)
	var eff := _remap_colors_for_dark_panel(mod.get_effect_description())
	if not eff.is_empty():
		text += "[font_size=14]%s[/font_size]\n" % eff

	# Passive stats fallback (only if not already included in eff)
	var boosts := mod.get_stat_boosts()
	if not boosts.is_empty() and not eff.contains("• "):
		var stat_parts: Array[String] = []
		for stat_name in boosts:
			var val: float = boosts[stat_name]
			var sign_str := "+" if val > 0 else ""
			stat_parts.append("%s%s %s" % [sign_str, str(int(roundf(val))), stat_name.capitalize()])
		if not stat_parts.is_empty():
			text += "[font_size=12][color=#8ff0a4]Passive Stats: %s[/color][/font_size]" % ", ".join(stat_parts)

	return text

func _get_trigger_description(tc: Equipment.TriggerCondition) -> String:
	match tc:
		Equipment.TriggerCondition.ALWAYS: return "Any Match"
		Equipment.TriggerCondition.MATCH_4_PLUS: return "4+ Tile Match"
		Equipment.TriggerCondition.SHAPE_L_OR_T: return "L or T Shape Match"
		Equipment.TriggerCondition.BOTTOM_HALF_GRID: return "Bottom Half of Board"
		Equipment.TriggerCondition.HIGH_MOMENTUM: return "3+ Space Fall"
		Equipment.TriggerCondition.SECOND_MATCH_IN_TURN: return "2nd Match In Turn"
		Equipment.TriggerCondition.THIRD_MATCH_IN_TURN: return "3rd Match In Turn"
		Equipment.TriggerCondition.EXOTIC_INFUSED: return "Exotic Tile Infused"
		Equipment.TriggerCondition.HAZARD_INTERACTION: return "Clears Hazard"
	return "Any Match"

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()
