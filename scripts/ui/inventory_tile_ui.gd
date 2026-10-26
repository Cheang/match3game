extends PanelContainer
class_name InventoryTileUI

signal tile_clicked(mod: Equipment, bag_index: int)
signal modifier_dropped_on_bag(drag_data: Dictionary, target_bag_index: int)

var modifier: Equipment = null
var bag_index: int = -1
var source_type: String = "bag" # "bag" or "pickup"
var drag_enabled: bool = true

var base_rect: TextureRect
var icon_rect: TextureRect
var cost_label: Label
var badge_label: Label
var name_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(96, 86)
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
	sb.content_margin_left = 4
	sb.content_margin_right = 4
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
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(cost_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	badge_label = Label.new()
	badge_label.add_theme_font_size_override("font_size", 11)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
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
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

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
	if not mod.is_colorless():
		c_id = mod.bound_color if mod.bound_color >= 100 else (mod.allowed_colors[0] if not mod.allowed_colors.is_empty() else 0)
	var tint: Color = Global.get_color_ui_tint(c_id)
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.bg_color = tint.darkened(0.68)
	sb.border_color = tint.lightened(0.15)
	add_theme_stylebox_override("panel", sb)

	base_rect.texture = Global.get_color_base_texture(c_id)
	icon_rect.texture = mod.icon
	cost_label.text = "%dS" % clampi(mod.slot_cost, 1, 3)
	badge_label.text = mod.get_trigger_badge_text()
	name_label.text = mod.piece_name if mod.piece_name != "" else "Item"
	var color_desc: String = "Colorless (Any Track)" if mod.is_colorless() else Global.get_color_name(c_id)
	tooltip_text = "%s (%s, %d-Slot)\n%s" % [
		mod.piece_name,
		color_desc,
		mod.slot_cost,
		mod.get_effect_description(Global.cur_char)
	]

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
