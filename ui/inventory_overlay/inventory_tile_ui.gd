class_name InventoryTileUI
extends PanelContainer

signal tile_clicked(mod: Equipment, bag_index: int)
signal modifier_dropped_on_bag(drag_data: Dictionary, target_bag_index: int)

var modifier: Equipment = null
var bag_index: int = -1
var source_type: String = "bag" # "bag" or "pickup"
var drag_enabled: bool = true
var is_selected_tile: bool = false
var _is_hovered: bool = false
var _cached_tint: Color = Color.WHITE

var base_rect: TextureRect
var icon_rect: TextureRect
var cost_label: Label
var badge_label: Label
var name_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(98, 88)
	size_flags_horizontal = Control.SIZE_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.18, 0.94)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.42, 0.36, 0.48, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_bar)

	cost_label = Label.new()
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	cost_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 0.95))
	cost_label.add_theme_constant_override("outline_size", 2)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(cost_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	badge_label = Label.new()
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	badge_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 0.95))
	badge_label.add_theme_constant_override("outline_size", 2)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(badge_label)

	var center_box := CenterContainer.new()
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center_box)

	base_rect = TextureRect.new()
	base_rect.custom_minimum_size = Vector2(40, 40)
	base_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(base_rect)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.set_anchors_preset(Control.PRESET_CENTER)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(icon_rect)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.88))
	name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 0.9))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup_tile(mod: Equipment, idx_in_bag: int = -1, interactive: bool = true, src_type: String = "bag") -> void:
	modifier = mod
	bag_index = idx_in_bag
	drag_enabled = interactive
	source_type = src_type

	if mod == null:
		visible = false
		return
	visible = true
	var c_id: int = 0
	var eff_colors: Array[int] = mod.get_effective_allowed_colors()
	if not mod.is_colorless() and not eff_colors.is_empty():
		c_id = eff_colors[0]
	_cached_tint = Global.get_color_ui_tint(c_id)
	_apply_style()

	base_rect.texture = Global.get_color_base_texture(c_id)
	icon_rect.texture = mod.icon

	var short_color_tag: String = "ANY"
	if not mod.is_colorless():
		var tags: Array[String] = []
		for ec in eff_colors:
			var sl: String = Global.get_color_short_label(ec)
			if not tags.has(sl):
				tags.append(sl)
		short_color_tag = "/".join(tags)

	cost_label.text = "%dS•%s" % [clampi(mod.slot_cost, 1, 6), short_color_tag]

	var b_txt: String = mod.get_trigger_badge_text()
	if b_txt == "":
		if mod.once_per_battle:
			b_txt = "1x"
		elif mod.get_effective_cooldown_turns() > 0:
			b_txt = "%dT" % mod.get_effective_cooldown_turns()
	badge_label.text = b_txt

	var upg_str: String = ("+%d" % mod.upgrade) if mod.upgrade > 0 else ""
	name_label.text = (mod.piece_name if mod.piece_name != "" else "Item") + upg_str
	if mod.rarity > Equipment.Rarity.COMMON:
		name_label.add_theme_color_override("font_color", Equipment.get_rarity_color(mod.rarity).lightened(0.18))
	else:
		name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.88))

	var color_desc: String = "Colorless (Any Track)" if mod.is_colorless() else Global.get_color_name(c_id)
	var rarity_prefix: String = ("[%s] " % Equipment.get_rarity_name(mod.rarity)) if mod.rarity > Equipment.Rarity.COMMON else ""
	tooltip_text = "%s%s%s (%s, %d-Slot)\n%s" % [
		rarity_prefix,
		mod.piece_name,
		upg_str,
		color_desc,
		mod.slot_cost,
		_strip_bbcode(mod.get_effect_description(Global.cur_char))
	]

func _strip_bbcode(src: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(src, "", true)

func set_selected(selected: bool) -> void:
	is_selected_tile = selected
	_apply_style()

func _apply_style() -> void:
	if modifier == null:
		return
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var bg: Color = _cached_tint.darkened(0.65)
	if _is_hovered:
		bg = bg.lightened(0.14)
	sb.bg_color = bg

	if is_selected_tile:
		sb.border_color = Color(1.0, 0.92, 0.35, 1.0)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
	elif modifier.rarity > Equipment.Rarity.COMMON:
		sb.border_color = Equipment.get_rarity_color(modifier.rarity)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	else:
		sb.border_color = _cached_tint.lightened(0.18)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	add_theme_stylebox_override("panel", sb)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_style()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_style()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_clicked.emit(modifier, bag_index)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or modifier == null:
		return null
	if get_viewport() != null and get_viewport().gui_is_dragging():
		var preview := InventoryTileUI.new()
		preview.setup_tile(modifier, bag_index, false, source_type)
		preview.modulate = Color(1.1, 1.1, 1.1, 0.92)
		set_drag_preview(preview)
	return {
		"type": "modifier_drag",
		"source": source_type,
		"modifier": modifier,
		"bag_index": bag_index
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drag_enabled:
		return false
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "modifier_drag":
		return false
	return data.get("source", "") in ["track", "pickup", "bag"]

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "modifier_drag":
		modifier_dropped_on_bag.emit(data, bag_index)
