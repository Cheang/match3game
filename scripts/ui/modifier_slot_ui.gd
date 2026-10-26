extends PanelContainer
class_name ModifierSlotUI

signal modifier_dropped_on_slot(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int)
signal slot_clicked(mod: Equipment)

var modifier: Equipment = null
var track_ref: ColorLoadoutTrack = null
var mod_index_in_track: int = -1
var drag_enabled: bool = false
var compact_mode: bool = false
var slot_cost: int = 1
var is_empty_slot: bool = true

var center_holder: CenterContainer
var icon_rect: TextureRect
var name_label: Label
var badge_label: Label
var state_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(28, 30)
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
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.85))
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	var overlay_control := Control.new()
	overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_control)

	badge_label = Label.new()
	badge_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_label.add_theme_font_size_override("font_size", 9)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.35))
	badge_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1, 0.95))
	badge_label.add_theme_constant_override("outline_size", 2)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_control.add_child(badge_label)

	state_label = Label.new()
	state_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	state_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	state_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_font_size_override("font_size", 9)
	state_label.add_theme_color_override("font_color", Color(0.95, 0.42, 0.42))
	state_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1, 0.95))
	state_label.add_theme_constant_override("outline_size", 2)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_control.add_child(state_label)

func setup_slot(mod: Equipment, color_tint: Color, owner_track: ColorLoadoutTrack = null, idx_in_track: int = -1, interactive_drag: bool = false, is_compact: bool = false) -> void:
	modifier = mod
	track_ref = owner_track
	mod_index_in_track = idx_in_track
	drag_enabled = interactive_drag
	compact_mode = is_compact
	mouse_filter = Control.MOUSE_FILTER_STOP if (interactive_drag or mod != null) else Control.MOUSE_FILTER_PASS

	custom_minimum_size = Vector2(24, 28) if compact_mode else Vector2(40, 32)
	icon_rect.custom_minimum_size = Vector2(20, 20) if compact_mode else Vector2(22, 22)

	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if mod == null:
		is_empty_slot = true
		slot_cost = 1
		size_flags_stretch_ratio = 1.0
		icon_rect.visible = false
		name_label.visible = false
		name_label.text = ""
		badge_label.text = ""
		state_label.text = ""
		sb.bg_color = Color(0.11, 0.09, 0.14, 0.6)
		sb.border_color = color_tint.darkened(0.45)
		tooltip_text = "Empty Slot — Drop modifier here" if interactive_drag else ""
	else:
		is_empty_slot = false
		slot_cost = clampi(mod.slot_cost, 1, 3)
		size_flags_stretch_ratio = float(slot_cost)
		icon_rect.visible = mod.icon != null
		icon_rect.texture = mod.icon
		if compact_mode:
			name_label.visible = false
			name_label.text = ""
		else:
			name_label.visible = true
			name_label.text = mod.piece_name if mod.piece_name != "" else "Item"
			name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9))

		badge_label.text = mod.get_trigger_badge_text()
		if not interactive_drag and mod.once_per_battle and mod.used_this_battle:
			state_label.text = "X" if compact_mode else "USED"
			modulate = Color(0.55, 0.55, 0.55, 0.85)
		elif not interactive_drag and mod.current_cooldown > 0:
			state_label.text = str(mod.current_cooldown) if compact_mode else ("CD:%d" % mod.current_cooldown)
			modulate = Color(0.7, 0.7, 0.75, 0.9)
		else:
			state_label.text = ""
			modulate = Color.WHITE
		sb.bg_color = color_tint.darkened(0.58)
		sb.border_color = color_tint.lightened(0.12)
		tooltip_text = "%s (%d-Slot)\n%s" % [mod.piece_name, slot_cost, mod.get_effect_description()]
	add_theme_stylebox_override("panel", sb)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if modifier != null:
			slot_clicked.emit(modifier)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or modifier == null or track_ref == null:
		return null
	if get_viewport() != null and get_viewport().gui_is_dragging():
		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(88, 32)
		var p_sb := StyleBoxFlat.new()
		var c_tint: Color = Global.get_color_ui_tint(track_ref.color)
		p_sb.bg_color = c_tint.darkened(0.4)
		p_sb.border_width_left = 2
		p_sb.border_width_top = 2
		p_sb.border_width_right = 2
		p_sb.border_width_bottom = 2
		p_sb.border_color = Color(1.0, 0.92, 0.35)
		p_sb.corner_radius_top_left = 4
		p_sb.corner_radius_top_right = 4
		p_sb.corner_radius_bottom_left = 4
		p_sb.corner_radius_bottom_right = 4
		p_sb.content_margin_left = 5
		p_sb.content_margin_right = 5
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
		sb.border_color = Color(1.0, 0.92, 0.35, 1.0)
		sb.bg_color = color_tint.darkened(0.32)
		scale = Vector2(1.04, 1.04)
	else:
		sb.border_color = color_tint.darkened(0.45) if is_empty_slot else color_tint.lightened(0.12)
		sb.bg_color = Color(0.11, 0.09, 0.14, 0.6) if is_empty_slot else color_tint.darkened(0.58)
		scale = Vector2.ONE
	add_theme_stylebox_override("panel", sb)

func pulse_activation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.5, 0.9, 1.0), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.14)
