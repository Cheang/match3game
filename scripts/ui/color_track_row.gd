extends Control
class_name ColorTrackRow

signal modifier_dropped_on_row(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int)
signal row_slot_clicked(mod: Equipment)
signal row_slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_index: int)

const TEX_BOTTOM = preload("res://assets/scene-assets/combat/plr-eq-bottom.png")

var track_color: int = 100
var track_ref: ColorLoadoutTrack = null
var interactive_drag: bool = false
var compact_mode: bool = false

var bg_texture: TextureRect
var ultimate_slot: ModifierSlotUI
var normal_slot_widgets: Array[ModifierSlotUI] = []
var all_slot_widgets: Array[ModifierSlotUI] = []

func _init() -> void:
	custom_minimum_size = Vector2(102, 38)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_nodes()
	_connect_slots()

func _ensure_nodes() -> void:
	if bg_texture == null:
		bg_texture = get_node_or_null("BgTexture")
		if bg_texture == null:
			bg_texture = TextureRect.new()
			bg_texture.name = "BgTexture"
			bg_texture.texture = TEX_BOTTOM
			bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_texture.size = Vector2(102, 38)
			add_child(bg_texture)

	if ultimate_slot == null:
		ultimate_slot = get_node_or_null("UltimateSlot")
		if ultimate_slot == null:
			ultimate_slot = ModifierSlotUI.new()
			ultimate_slot.name = "UltimateSlot"
			ultimate_slot.is_ultimate_slot = true
			ultimate_slot.position = Vector2(3, 5)
			ultimate_slot.size = Vector2(22, 28)
			add_child(ultimate_slot)

	if normal_slot_widgets.is_empty():
		for slot_idx in range(ColorLoadoutTrack.NORMAL_MAX_SLOTS):
			var slot_name := "NormalSlot_%d" % slot_idx
			var slot_ui: ModifierSlotUI = get_node_or_null(slot_name)
			if slot_ui == null:
				slot_ui = ModifierSlotUI.new()
				slot_ui.name = slot_name
				slot_ui.position = Vector2(27 + slot_idx * 15, 9)
				slot_ui.size = Vector2(13, 20)
				add_child(slot_ui)
			normal_slot_widgets.append(slot_ui)

	all_slot_widgets.clear()
	if ultimate_slot != null:
		all_slot_widgets.append(ultimate_slot)
	for s in normal_slot_widgets:
		all_slot_widgets.append(s)

func _connect_slots() -> void:
	if ultimate_slot != null:
		if not ultimate_slot.slot_clicked.is_connected(_on_slot_clicked):
			ultimate_slot.slot_clicked.connect(_on_slot_clicked)
		if not ultimate_slot.slot_selected.is_connected(_on_slot_selected):
			ultimate_slot.slot_selected.connect(_on_slot_selected)
		if not ultimate_slot.modifier_dropped_on_slot.is_connected(_on_slot_dropped):
			ultimate_slot.modifier_dropped_on_slot.connect(_on_slot_dropped)

	for slot_ui in normal_slot_widgets:
		if slot_ui != null:
			if not slot_ui.slot_clicked.is_connected(_on_slot_clicked):
				slot_ui.slot_clicked.connect(_on_slot_clicked)
			if not slot_ui.slot_selected.is_connected(_on_slot_selected):
				slot_ui.slot_selected.connect(_on_slot_selected)
			if not slot_ui.modifier_dropped_on_slot.is_connected(_on_slot_dropped):
				slot_ui.modifier_dropped_on_slot.connect(_on_slot_dropped)

func setup_row(color_id: int, track: ColorLoadoutTrack, enable_drag: bool = false, is_compact: bool = false) -> void:
	_ensure_nodes()
	_connect_slots()
	track_color = color_id
	track_ref = track
	interactive_drag = enable_drag
	compact_mode = is_compact

	# 1. Setup Ultimate Slot
	var ult_mod: Equipment = track.ultimate_skill if track != null else null
	if ultimate_slot != null:
		ultimate_slot.setup_slot(ult_mod, color_id, track, -1, interactive_drag, compact_mode, true)

	# 2. Setup 5 Normal Diamond Slots
	for slot_idx in range(normal_slot_widgets.size()):
		var mod: Equipment = track.get_modifier_at_slot_index(slot_idx) if track != null else null
		normal_slot_widgets[slot_idx].setup_slot(mod, color_id, track, slot_idx, interactive_drag, compact_mode, false)

func update_row_state() -> void:
	if track_ref != null:
		track_ref.clamp_cursor()

	# Update Ultimate Slot
	var ult_mod: Equipment = track_ref.ultimate_skill if track_ref != null else null
	if ultimate_slot != null:
		ultimate_slot.setup_slot(ult_mod, track_color, track_ref, -1, interactive_drag, compact_mode, true)

	# Update Normal Slots
	for slot_idx in range(normal_slot_widgets.size()):
		var mod: Equipment = track_ref.get_modifier_at_slot_index(slot_idx) if track_ref != null else null
		normal_slot_widgets[slot_idx].setup_slot(mod, track_color, track_ref, slot_idx, interactive_drag, compact_mode, false)

func highlight_selected_mod(selected_mod: Equipment) -> void:
	for slot_ui in all_slot_widgets:
		if is_instance_valid(slot_ui):
			slot_ui.set_selected(selected_mod != null and slot_ui.modifier == selected_mod)

func _on_slot_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> void:
	modifier_dropped_on_row.emit(drag_data, target_track, target_mod_index)

func _on_slot_clicked(mod: Equipment) -> void:
	row_slot_clicked.emit(mod)

func _on_slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_index: int) -> void:
	row_slot_selected.emit(mod, track, mod_index)

func preview_context(ctx: MatchContext) -> void:
	var firing_indices: Array[int] = []
	if track_ref != null and ctx != null:
		var actor: Resource = ctx.actor if ctx.actor != null else (Global.cur_char if not Engine.is_editor_hint() else null)
		firing_indices = track_ref.peek_firing_indices(ctx, actor)

	if ultimate_slot != null:
		ultimate_slot.set_preview_active(firing_indices.has(-1), Color.WHITE)

	for slot_idx in range(normal_slot_widgets.size()):
		var slot_ui: ModifierSlotUI = normal_slot_widgets[slot_idx]
		if slot_ui != null and slot_ui.modifier != null and track_ref != null:
			var mod_idx: int = track_ref.equipped_modifiers.find(slot_ui.modifier)
			var triggers: bool = firing_indices.has(mod_idx)
			slot_ui.set_preview_active(triggers, Color.WHITE)
		elif slot_ui != null:
			slot_ui.set_preview_active(false, Color.WHITE)

func clear_preview() -> void:
	for slot_ui in all_slot_widgets:
		if slot_ui != null:
			slot_ui.set_preview_active(false, Color.WHITE)

func pulse_modifier(mod: Equipment) -> void:
	for slot_ui in all_slot_widgets:
		if is_instance_valid(slot_ui) and slot_ui.modifier == mod:
			slot_ui.pulse_activation()
