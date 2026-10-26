extends HBoxContainer
class_name ColorTrackRow

signal modifier_dropped_on_row(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int)
signal row_slot_clicked(mod: Equipment)

var track_color: int = 100
var track_ref: ColorLoadoutTrack = null
var interactive_drag: bool = false
var compact_mode: bool = false
var color_badge: PanelContainer
var color_label: Label
var slots_container: HBoxContainer
var slot_widgets: Array[ModifierSlotUI] = []

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 30)
	add_theme_constant_override("separation", 3)
	_build_row()

func _build_row() -> void:
	color_badge = PanelContainer.new()
	color_badge.custom_minimum_size = Vector2(20, 28)
	add_child(color_badge)

	color_label = Label.new()
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	color_label.add_theme_font_size_override("font_size", 11)
	color_badge.add_child(color_label)

	slots_container = HBoxContainer.new()
	slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_container.add_theme_constant_override("separation", 2)
	add_child(slots_container)

func setup_row(color_id: int, track: ColorLoadoutTrack, enable_drag: bool = false, is_compact: bool = false) -> void:
	track_color = color_id
	track_ref = track
	interactive_drag = enable_drag
	compact_mode = is_compact
	var tint: Color = Global.get_color_ui_tint(color_id)

	custom_minimum_size = Vector2(0, 28) if compact_mode else Vector2(0, 34)
	add_theme_constant_override("separation", 2 if compact_mode else 5)
	slots_container.add_theme_constant_override("separation", 2 if compact_mode else 4)
	color_badge.custom_minimum_size = Vector2(16, 28) if compact_mode else Vector2(30, 32)
	color_label.add_theme_font_size_override("font_size", 10 if compact_mode else 12)

	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = tint.darkened(0.22)
	badge_sb.border_width_left = 1 if compact_mode else 2
	badge_sb.border_width_top = 1 if compact_mode else 2
	badge_sb.border_width_right = 1 if compact_mode else 2
	badge_sb.border_width_bottom = 1 if compact_mode else 2
	badge_sb.border_color = tint.lightened(0.25)
	badge_sb.corner_radius_top_left = 3
	badge_sb.corner_radius_top_right = 3
	badge_sb.corner_radius_bottom_left = 3
	badge_sb.corner_radius_bottom_right = 3
	color_badge.add_theme_stylebox_override("panel", badge_sb)
	color_label.text = Global.get_color_short_label(color_id)

	for child in slots_container.get_children():
		child.queue_free()
	slot_widgets.clear()

	var used_slots: int = 0
	var max_slots: int = track.max_slots if track != null else 3

	if track != null:
		for idx in range(track.equipped_modifiers.size()):
			var mod: Equipment = track.equipped_modifiers[idx]
			if mod == null:
				continue
			var slot_ui := ModifierSlotUI.new()
			slots_container.add_child(slot_ui)
			slot_ui.setup_slot(mod, tint, track, idx, interactive_drag, compact_mode)
			slot_ui.slot_clicked.connect(_on_slot_clicked)
			if interactive_drag:
				slot_ui.modifier_dropped_on_slot.connect(_on_slot_dropped)
			slot_widgets.append(slot_ui)
			used_slots += clampi(mod.slot_cost, 1, 3)

	var remaining: int = max(0, max_slots - used_slots)
	for i in range(remaining):
		var empty_ui := ModifierSlotUI.new()
		slots_container.add_child(empty_ui)
		empty_ui.setup_slot(null, tint, track, -1, interactive_drag, compact_mode)
		if interactive_drag:
			empty_ui.modifier_dropped_on_slot.connect(_on_slot_dropped)
		slot_widgets.append(empty_ui)

func _on_slot_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> void:
	modifier_dropped_on_row.emit(drag_data, target_track, target_mod_index)

func _on_slot_clicked(mod: Equipment) -> void:
	row_slot_clicked.emit(mod)

func preview_context(ctx: MatchContext) -> void:
	var tint: Color = Global.get_color_ui_tint(track_color)
	for slot_ui in slot_widgets:
		if slot_ui != null and slot_ui.modifier != null and ctx != null:
			var triggers: bool = slot_ui.modifier.can_trigger(ctx)
			slot_ui.set_preview_active(triggers, tint)
		elif slot_ui != null:
			slot_ui.set_preview_active(false, tint)

func clear_preview() -> void:
	var tint: Color = Global.get_color_ui_tint(track_color)
	for slot_ui in slot_widgets:
		if slot_ui != null:
			slot_ui.set_preview_active(false, tint)

func pulse_modifier(mod: Equipment) -> void:
	for slot_ui in slot_widgets:
		if slot_ui != null and slot_ui.modifier == mod:
			slot_ui.pulse_activation()
			break
