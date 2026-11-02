extends PanelContainer
class_name ModifierSlotUI

signal modifier_dropped_on_slot(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int)
signal slot_clicked(mod: Equipment)
signal slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_index: int)

var modifier: Equipment = null
var track_ref: ColorLoadoutTrack = null
var mod_index_in_track: int = -1
var drag_enabled: bool = false
var compact_mode: bool = false
var slot_cost: int = 1
var is_empty_slot: bool = true
var is_next_in_chain: bool = false
var is_selected_slot: bool = false
var _cached_tint: Color = Color.WHITE
var _is_hovered: bool = false

var center_holder: CenterContainer
var icon_rect: TextureRect
var name_label: Label
var next_label: Label
var badge_label: Label
var state_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(14, 26)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()

func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.17, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.38, 0.33, 0.42, 1.0)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.88))
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	var overlay_control := Control.new()
	overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_control)

	next_label = Label.new()
	next_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	next_label.add_theme_font_size_override("font_size", 8)
	next_label.add_theme_color_override("font_color", Color(0.35, 0.98, 0.88))
	next_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 0.98))
	next_label.add_theme_constant_override("outline_size", 2)
	next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_control.add_child(next_label)

	badge_label = Label.new()
	badge_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_label.add_theme_font_size_override("font_size", 8)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.35))
	badge_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1, 0.98))
	badge_label.add_theme_constant_override("outline_size", 2)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_control.add_child(badge_label)

	state_label = Label.new()
	state_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	state_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	state_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_font_size_override("font_size", 8)
	state_label.add_theme_color_override("font_color", Color(0.98, 0.45, 0.45))
	state_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1, 0.98))
	state_label.add_theme_constant_override("outline_size", 2)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_control.add_child(state_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup_slot(mod: Equipment, color_tint: Color, owner_track: ColorLoadoutTrack = null, idx_in_track: int = -1, interactive_drag: bool = false, is_compact: bool = false, is_next: bool = false) -> void:
	modifier = mod
	track_ref = owner_track
	mod_index_in_track = idx_in_track
	drag_enabled = interactive_drag
	compact_mode = is_compact
	is_next_in_chain = is_next
	_cached_tint = color_tint
	mouse_filter = Control.MOUSE_FILTER_STOP if (interactive_drag or mod != null) else Control.MOUSE_FILTER_PASS

	var max_s: int = owner_track.max_slots if owner_track != null else ColorLoadoutTrack.DEFAULT_MAX_SLOTS
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if mod == null:
		is_empty_slot = true
		is_next_in_chain = false
		slot_cost = 1
		# In compact combat dock, empty slots take minimal width so equipped items stay legible
		size_flags_stretch_ratio = 0.35 if compact_mode else 1.0
		custom_minimum_size = Vector2(8, 22) if compact_mode else Vector2(28, 34)
		icon_rect.visible = false
		name_label.visible = false
		name_label.text = ""
		next_label.text = ""
		badge_label.text = ""
		state_label.text = ""
		modulate = Color.WHITE
		_apply_resting_stylebox(sb, color_tint)
		tooltip_text = "Empty Slot — Drop modifier here" if interactive_drag else ""
	else:
		is_empty_slot = false
		slot_cost = clampi(mod.slot_cost, 1, max_s)
		size_flags_stretch_ratio = float(slot_cost) * (1.4 if compact_mode else 1.0)
		custom_minimum_size = Vector2(26, 22) if compact_mode else Vector2(36, 34)
		icon_rect.custom_minimum_size = Vector2(16, 16) if compact_mode else Vector2(22, 22)
		icon_rect.visible = mod.icon != null
		icon_rect.texture = mod.icon
		var upg_str: String = ("+%d" % mod.upgrade) if mod.upgrade > 0 else ""
		var disp_name: String = (mod.piece_name if mod.piece_name != "" else "Item") + upg_str
		if compact_mode:
			# Show short label in compact mode if slot_cost >= 2 or track has few items
			var total_filled: int = owner_track.get_filled_entry_count() if owner_track != null else 1
			if slot_cost >= 2 or total_filled <= 2:
				name_label.visible = true
				name_label.add_theme_font_size_override("font_size", 9)
				name_label.text = disp_name
			else:
				name_label.visible = false
				name_label.text = ""
		else:
			name_label.visible = true
			name_label.add_theme_font_size_override("font_size", 11)
			name_label.text = disp_name

		if mod.rarity > Equipment.Rarity.COMMON:
			name_label.add_theme_color_override("font_color", Equipment.get_rarity_color(mod.rarity).lightened(0.2))
		else:
			name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9))

		update_live_state(is_next, color_tint)
		return

	add_theme_stylebox_override("panel", sb)

## Updates cursor, cooldown, once-per-battle state, and tooltip in-place without freeing the node.
func update_live_state(is_next: bool, color_tint: Color) -> void:
	is_next_in_chain = is_next
	_cached_tint = color_tint
	if is_empty_slot or modifier == null:
		return

	next_label.text = ("►" if compact_mode else "►NEXT") if is_next_in_chain else ""
	badge_label.text = modifier.get_trigger_badge_text()

	if not drag_enabled and modifier.once_per_battle and modifier.used_this_battle:
		state_label.text = "X" if compact_mode else "USED"
		modulate = Color(0.55, 0.55, 0.55, 0.85)
	elif not drag_enabled and modifier.current_cooldown > 0:
		state_label.text = ("CD:%d" % modifier.current_cooldown) if not compact_mode else str(modifier.current_cooldown)
		modulate = Color(0.72, 0.72, 0.78, 0.92)
	else:
		if drag_enabled and modifier.cooldown_turns > 0:
			state_label.text = "%dT" % modifier.get_effective_cooldown_turns()
		elif drag_enabled and modifier.once_per_battle:
			state_label.text = "1x"
		else:
			state_label.text = ""
		modulate = Color.WHITE

	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_apply_resting_stylebox(sb, color_tint)
	add_theme_stylebox_override("panel", sb)

	var next_prefix: String = "[NEXT IN CHAIN]\n" if is_next_in_chain else ""
	var upg_suffix: String = (" +%d" % modifier.upgrade) if modifier.upgrade > 0 else ""
	var cd_info: String = ""
	if modifier.once_per_battle:
		cd_info = " • Once/Battle" + (" (USED)" if modifier.used_this_battle else "")
	elif modifier.get_effective_cooldown_turns() > 0:
		cd_info = " • %dT Cooldown" % modifier.get_effective_cooldown_turns()
		if modifier.current_cooldown > 0:
			cd_info += " (%dT left)" % modifier.current_cooldown

	if modifier.rarity > Equipment.Rarity.COMMON:
		tooltip_text = "%s%s%s [%s] (%d-Slot%s)\n%s" % [
			next_prefix,
			modifier.piece_name,
			upg_suffix,
			Equipment.get_rarity_name(modifier.rarity),
			slot_cost,
			cd_info,
			_strip_bbcode(modifier.get_effect_description())
		]
	else:
		tooltip_text = "%s%s%s (%d-Slot%s)\n%s" % [
			next_prefix,
			modifier.piece_name,
			upg_suffix,
			slot_cost,
			cd_info,
			_strip_bbcode(modifier.get_effect_description())
		]

func _strip_bbcode(src: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(src, "", true)

func set_selected(selected: bool) -> void:
	is_selected_slot = selected
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_apply_resting_stylebox(sb, _cached_tint)
	add_theme_stylebox_override("panel", sb)

func _apply_resting_stylebox(sb: StyleBoxFlat, color_tint: Color) -> void:
	if is_empty_slot or modifier == null:
		sb.bg_color = Color(0.10, 0.08, 0.13, 0.45 if compact_mode else 0.65)
		sb.border_color = color_tint.darkened(0.42)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		return

	var base_bg: Color = color_tint.darkened(0.42) if is_next_in_chain else color_tint.darkened(0.56)
	if _is_hovered:
		base_bg = base_bg.lightened(0.14)
	sb.bg_color = base_bg

	if is_selected_slot:
		sb.border_color = Color(1.0, 0.92, 0.35, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	elif is_next_in_chain:
		sb.border_color = Color(0.35, 0.98, 0.88, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	elif modifier.rarity > Equipment.Rarity.COMMON:
		sb.border_color = Equipment.get_rarity_color(modifier.rarity)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	else:
		sb.border_color = color_tint.lightened(0.18)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1

func _on_mouse_entered() -> void:
	_is_hovered = true
	if not is_empty_slot:
		var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		_apply_resting_stylebox(sb, _cached_tint)
		add_theme_stylebox_override("panel", sb)

func _on_mouse_exited() -> void:
	_is_hovered = false
	if not is_empty_slot:
		var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		_apply_resting_stylebox(sb, _cached_tint)
		add_theme_stylebox_override("panel", sb)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if modifier != null:
			slot_clicked.emit(modifier)
			slot_selected.emit(modifier, track_ref, mod_index_in_track)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or modifier == null or track_ref == null:
		return null
	if get_viewport() != null and get_viewport().gui_is_dragging():
		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(96, 34)
		var p_sb := StyleBoxFlat.new()
		var c_tint: Color = Global.get_color_ui_tint(track_ref.color)
		p_sb.bg_color = c_tint.darkened(0.35)
		p_sb.border_width_left = 2
		p_sb.border_width_top = 2
		p_sb.border_width_right = 2
		p_sb.border_width_bottom = 2
		p_sb.border_color = Color(1.0, 0.92, 0.35)
		p_sb.corner_radius_top_left = 4
		p_sb.corner_radius_top_right = 4
		p_sb.corner_radius_bottom_left = 4
		p_sb.corner_radius_bottom_right = 4
		p_sb.content_margin_left = 6
		p_sb.content_margin_right = 6
		preview.add_theme_stylebox_override("panel", p_sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		preview.add_child(hbox)
		if modifier.icon != null:
			var tex := TextureRect.new()
			tex.custom_minimum_size = Vector2(22, 22)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture = modifier.icon
			hbox.add_child(tex)
		var lbl := Label.new()
		lbl.text = "%s (%dS)" % [modifier.piece_name, modifier.slot_cost]
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		set_drag_preview(preview)
	return {
		"type": "modifier_drag",
		"source": "track",
		"modifier": modifier,
		"source_track": track_ref,
		"source_index": mod_index_in_track
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drag_enabled or track_ref == null:
		return false
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "modifier_drag":
		return false
	var dragged_mod: Equipment = data.get("modifier", null)
	if dragged_mod == null:
		return false
	return track_ref.is_color_compatible(dragged_mod)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "modifier_drag":
		modifier_dropped_on_slot.emit(data, track_ref, mod_index_in_track)

func set_preview_active(active: bool, color_tint: Color) -> void:
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if active and not is_empty_slot:
		sb.border_color = Color(1.0, 0.94, 0.35, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.bg_color = color_tint.darkened(0.25)
		pivot_offset = size * 0.5
		scale = Vector2(1.05, 1.05)
	else:
		_apply_resting_stylebox(sb, color_tint)
		scale = Vector2.ONE
	add_theme_stylebox_override("panel", sb)

func pulse_activation() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.75, 1.6, 0.9, 1.0), 0.07)
	tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
