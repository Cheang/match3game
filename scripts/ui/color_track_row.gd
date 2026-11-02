extends HBoxContainer
class_name ColorTrackRow

signal modifier_dropped_on_row(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int)
signal row_slot_clicked(mod: Equipment)
signal row_slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_index: int)

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
	custom_minimum_size = Vector2(0, 24)
	add_theme_constant_override("separation", 2)
	_build_row()

func _build_row() -> void:
	color_badge = PanelContainer.new()
	color_badge.custom_minimum_size = Vector2(18, 22)
	add_child(color_badge)

	color_label = Label.new()
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	color_label.add_theme_font_size_override("font_size", 10)
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

	custom_minimum_size = Vector2(0, 22) if compact_mode else Vector2(0, 36)
	add_theme_constant_override("separation", 3 if compact_mode else 5)
	slots_container.add_theme_constant_override("separation", 2 if compact_mode else 4)
	color_badge.custom_minimum_size = Vector2(20, 22) if compact_mode else Vector2(44, 34)
	color_label.add_theme_font_size_override("font_size", 10 if compact_mode else 11)

	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = tint.darkened(0.24)
	badge_sb.border_width_left = 1 if compact_mode else 2
	badge_sb.border_width_top = 1 if compact_mode else 2
	badge_sb.border_width_right = 1 if compact_mode else 2
	badge_sb.border_width_bottom = 1 if compact_mode else 2
	badge_sb.border_color = tint.lightened(0.28)
	badge_sb.corner_radius_top_left = 3
	badge_sb.corner_radius_top_right = 3
	badge_sb.corner_radius_bottom_left = 3
	badge_sb.corner_radius_bottom_right = 3
	color_badge.add_theme_stylebox_override("panel", badge_sb)

	for child in slots_container.get_children():
		child.queue_free()
	slot_widgets.clear()

	var used_slots: int = 0
	var max_slots: int = track.max_slots if track != null else ColorLoadoutTrack.DEFAULT_MAX_SLOTS

	if track != null:
		track.clamp_cursor()
		for idx in range(track.equipped_modifiers.size()):
			var mod: Equipment = track.equipped_modifiers[idx]
			if mod == null:
				continue
			var is_next: bool = (idx == track.next_entry_cursor)
			var slot_ui := ModifierSlotUI.new()
			slots_container.add_child(slot_ui)
			slot_ui.setup_slot(mod, tint, track, idx, interactive_drag, compact_mode, is_next)
			slot_ui.slot_clicked.connect(_on_slot_clicked)
			slot_ui.slot_selected.connect(_on_slot_selected)
			if interactive_drag:
				slot_ui.modifier_dropped_on_slot.connect(_on_slot_dropped)
			slot_widgets.append(slot_ui)
			used_slots += clampi(mod.slot_cost, 1, max_slots)

	var short_c: String = Global.get_color_short_label(color_id)
	if compact_mode:
		color_label.text = short_c
	else:
		color_label.text = "%s\n%d/%d" % [short_c, used_slots, max_slots]
		color_label.add_theme_constant_override("line_spacing", -3)
	color_badge.tooltip_text = "%s Track (%d/%d Slots Used)" % [Global.get_color_name(color_id), used_slots, max_slots]

	var remaining: int = max(0, max_slots - used_slots)
	for i in range(remaining):
		var empty_ui := ModifierSlotUI.new()
		slots_container.add_child(empty_ui)
		empty_ui.setup_slot(null, tint, track, -1, interactive_drag, compact_mode, false)
		if interactive_drag:
			empty_ui.modifier_dropped_on_slot.connect(_on_slot_dropped)
		slot_widgets.append(empty_ui)

## Checks whether existing slot_widgets match the track's current equipped_modifiers list.
## If they match, updates cursor and cooldowns in-place so active tweens (e.g. pulse_activation) are preserved.
func update_row_state() -> void:
	if track_ref == null:
		return
	track_ref.clamp_cursor()
	var filled_widgets: Array[ModifierSlotUI] = []
	for w in slot_widgets:
		if is_instance_valid(w) and not w.is_empty_slot:
			filled_widgets.append(w)

	var needs_rebuild: bool = (filled_widgets.size() != track_ref.equipped_modifiers.size())
	if not needs_rebuild:
		for i in range(filled_widgets.size()):
			if filled_widgets[i].modifier != track_ref.equipped_modifiers[i]:
				needs_rebuild = true
				break

	if needs_rebuild:
		setup_row(track_color, track_ref, interactive_drag, compact_mode)
		return

	var tint: Color = Global.get_color_ui_tint(track_color)
	for i in range(filled_widgets.size()):
		var is_next: bool = (i == track_ref.next_entry_cursor)
		filled_widgets[i].mod_index_in_track = i
		filled_widgets[i].update_live_state(is_next, tint)

func highlight_selected_mod(selected_mod: Equipment) -> void:
	for slot_ui in slot_widgets:
		if is_instance_valid(slot_ui) and not slot_ui.is_empty_slot:
			slot_ui.set_selected(selected_mod != null and slot_ui.modifier == selected_mod)

func _on_slot_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> void:
	modifier_dropped_on_row.emit(drag_data, target_track, target_mod_index)

func _on_slot_clicked(mod: Equipment) -> void:
	row_slot_clicked.emit(mod)

func _on_slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_index: int) -> void:
	row_slot_selected.emit(mod, track, mod_index)

func preview_context(ctx: MatchContext) -> void:
	var tint: Color = Global.get_color_ui_tint(track_color)
	var firing_indices: Array[int] = []
	if track_ref != null and ctx != null:
		var actor: Resource = ctx.actor if ctx.actor != null else Global.cur_char
		firing_indices = track_ref.peek_firing_indices(ctx, actor)

	for slot_ui in slot_widgets:
		if slot_ui != null and slot_ui.modifier != null and ctx != null:
			var triggers: bool = firing_indices.has(slot_ui.mod_index_in_track)
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
