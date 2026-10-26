extends CanvasLayer
class_name SlotEquipModal

signal modal_closed

const OUTER_FRAME_TEX = preload("res://assets/level_ui/btn/btn_2.png")
const INNER_PANEL_TEX = preload("res://assets/level_ui/btn/btn_2_hover.png")
const BTN_LIGHT_TEX = preload("res://assets/level_ui/btn/btn_2_light.png")

var pending_queue: Array[Equipment] = []
var current_mod: Equipment = null

var root_panel: PanelContainer
var title_label: Label
var pickup_tile_holder: CenterContainer
var mod_summary_label: RichTextLabel
var tracks_box: VBoxContainer
var bag_header_label: Label
var bag_grid: InventoryBagGrid
var bag_btn: Button

func _init() -> void:
	layer = 10
	_build_modal_ui()

func _make_9slice_stylebox(tex: Texture2D, margin: float = 8.0, content_pad_h: float = 10.0, content_pad_v: float = 8.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content_pad_h
	sb.content_margin_right = content_pad_h
	sb.content_margin_top = content_pad_v
	sb.content_margin_bottom = content_pad_v
	return sb

func _style_pixel_button(btn: Button, font_sz: int = 18) -> void:
	var sb_normal := _make_9slice_stylebox(OUTER_FRAME_TEX, 8.0, 8.0, 4.0)
	var sb_hover := _make_9slice_stylebox(BTN_LIGHT_TEX, 8.0, 8.0, 4.0)
	var sb_pressed := _make_9slice_stylebox(INNER_PANEL_TEX, 8.0, 8.0, 4.0)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.698, 0.729, 0.565))
	btn.add_theme_color_override("font_hover_color", Color(0.28, 0.2, 0.25))
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.88, 0.75))

func _build_modal_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.06, 0.04, 0.08, 0.86)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	root_panel = PanelContainer.new()
	root_panel.custom_minimum_size = Vector2(520, 0)
	root_panel.add_theme_stylebox_override("panel", _make_9slice_stylebox(OUTER_FRAME_TEX, 8.0, 14.0, 14.0))
	center.add_child(root_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	root_panel.add_child(outer_vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.698, 0.729, 0.565))
	title_label.add_theme_color_override("font_outline_color", Color(0.28, 0.22, 0.3, 1.0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.text = "New Equipment Acquired"
	outer_vbox.add_child(title_label)

	var inner_panel := PanelContainer.new()
	inner_panel.add_theme_stylebox_override("panel", _make_9slice_stylebox(INNER_PANEL_TEX, 8.0, 12.0, 12.0))
	outer_vbox.add_child(inner_panel)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	inner_panel.add_child(content_vbox)

	# 1. Showcase Card for New Item
	var showcase_panel := PanelContainer.new()
	var show_sb := StyleBoxFlat.new()
	show_sb.bg_color = Color(0.13, 0.1, 0.16, 0.95)
	show_sb.border_width_left = 2
	show_sb.border_width_top = 2
	show_sb.border_width_right = 2
	show_sb.border_width_bottom = 2
	show_sb.border_color = Color(0.58, 0.54, 0.42, 0.9)
	show_sb.corner_radius_top_left = 6
	show_sb.corner_radius_top_right = 6
	show_sb.corner_radius_bottom_left = 6
	show_sb.corner_radius_bottom_right = 6
	show_sb.content_margin_left = 10
	show_sb.content_margin_right = 10
	show_sb.content_margin_top = 8
	show_sb.content_margin_bottom = 8
	showcase_panel.add_theme_stylebox_override("panel", show_sb)
	content_vbox.add_child(showcase_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase_panel.add_child(top_hbox)

	pickup_tile_holder = CenterContainer.new()
	top_hbox.add_child(pickup_tile_holder)

	mod_summary_label = RichTextLabel.new()
	mod_summary_label.bbcode_enabled = true
	mod_summary_label.fit_content = true
	mod_summary_label.scroll_active = false
	mod_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mod_summary_label.custom_minimum_size = Vector2(320, 72)
	top_hbox.add_child(mod_summary_label)

	# 2. Color Loadout Tracks Section
	var tracks_lbl := Label.new()
	tracks_lbl.text = "Color Loadout Tracks (Drag tile onto slot or tap +Equip)"
	tracks_lbl.add_theme_font_size_override("font_size", 14)
	tracks_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	content_vbox.add_child(tracks_lbl)

	tracks_box = VBoxContainer.new()
	tracks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_box.add_theme_constant_override("separation", 5)
	content_vbox.add_child(tracks_box)

	# 3. Equipment Bag Section
	bag_header_label = Label.new()
	bag_header_label.text = "Equipment Bag (Drop here to store or reorganize)"
	bag_header_label.add_theme_font_size_override("font_size", 14)
	bag_header_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	content_vbox.add_child(bag_header_label)

	bag_grid = InventoryBagGrid.new()
	bag_grid.custom_minimum_size = Vector2(460, 175)
	bag_grid.modifier_dropped_on_bag_grid.connect(_on_dropped_on_bag)
	content_vbox.add_child(bag_grid)

	# 4. Bottom Action Button
	bag_btn = Button.new()
	bag_btn.custom_minimum_size = Vector2(0, 44)
	bag_btn.text = "Put in Equipment Bag"
	_style_pixel_button(bag_btn, 20)
	bag_btn.pressed.connect(_on_put_in_bag_pressed)
	outer_vbox.add_child(bag_btn)

func prompt_modifiers(mods: Array[Equipment]) -> void:
	for m in mods:
		if m != null:
			pending_queue.append(m.duplicate(true))
	_show_next_modifier()

func _show_next_modifier() -> void:
	if pending_queue.is_empty():
		modal_closed.emit()
		queue_free()
		return
	current_mod = pending_queue.pop_front()
	_refresh_modal_view()

func _refresh_modal_view() -> void:
	if current_mod == null or Global.cur_char == null:
		_show_next_modifier()
		return

	Global.cur_char.ensure_loadout_tracks()
	for child in pickup_tile_holder.get_children():
		child.queue_free()

	var pickup_tile := InventoryTileUI.new()
	pickup_tile_holder.add_child(pickup_tile)
	pickup_tile.setup_tile(current_mod, -1, true, "pickup")

	var badge: String = current_mod.get_trigger_badge_text()
	var badge_str: String = (" • Trigger: [color=#fad65a]%s[/color]" % badge) if badge != "" else ""
	var allowed_list: Array[int] = current_mod.get_effective_allowed_colors()
	var color_label_str: String = "Any Track (Colorless)"
	if not current_mod.is_colorless():
		var color_names: Array[String] = []
		for c in allowed_list:
			color_names.append(Global.get_color_name(c))
		color_label_str = ", ".join(color_names)

	mod_summary_label.text = "[color=#f2e6b6][b]%s[/b][/color]  [color=#b2b8a3](%d-Slot • %s%s)[/color]\n%s" % [
		current_mod.piece_name,
		current_mod.slot_cost,
		color_label_str,
		badge_str,
		current_mod.get_effect_description(Global.cur_char)
	]

	for child in tracks_box.get_children():
		child.queue_free()

	for c_id in allowed_list:
		var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 6)
		tracks_box.add_child(row_hbox)

		var row_preview := ColorTrackRow.new()
		row_hbox.add_child(row_preview)
		row_preview.setup_row(track.color, track, true, false)
		row_preview.modifier_dropped_on_row.connect(_on_dropped_on_track_row)

		var quick_btn := Button.new()
		quick_btn.custom_minimum_size = Vector2(68, 34)
		quick_btn.text = "+Equip"
		_style_pixel_button(quick_btn, 13)
		quick_btn.tooltip_text = "Auto-equip into %s Track" % Global.get_color_name(track.color)
		quick_btn.pressed.connect(_on_quick_slot_pressed.bind(track))
		row_hbox.add_child(quick_btn)

	if bag_header_label != null:
		bag_header_label.text = "Equipment Bag (%d) — Drop here to store or reorganize" % Global.cur_char.modifier_inventory.size()
	bag_grid.populate_bag(Global.cur_char.modifier_inventory, true)

func _on_dropped_on_track_row(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> void:
	if Global.cur_char == null:
		return
	var src: String = drag_data.get("source", "")
	var ok: bool = Global.cur_char.handle_modifier_drop_on_track(drag_data, target_track, target_mod_index)
	if ok and src == "pickup":
		_show_next_modifier()
	else:
		_refresh_modal_view()

func _on_dropped_on_bag(drag_data: Dictionary, target_bag_index: int) -> void:
	if Global.cur_char == null:
		return
	var src: String = drag_data.get("source", "")
	var ok: bool = Global.cur_char.handle_modifier_drop_on_bag(drag_data, target_bag_index)
	if ok and src == "pickup":
		_show_next_modifier()
	else:
		_refresh_modal_view()

func _on_quick_slot_pressed(track: ColorLoadoutTrack) -> void:
	if current_mod != null and track != null and Global.cur_char != null:
		var drag_data := {
			"type": "modifier_drag",
			"source": "pickup",
			"modifier": current_mod
		}
		Global.cur_char.handle_modifier_drop_on_track(drag_data, track, -1)
	_show_next_modifier()

func _on_put_in_bag_pressed() -> void:
	if current_mod != null and Global.cur_char != null:
		Global.cur_char.modifier_inventory.append(current_mod)
		Global.cur_char.loadoutChanged.emit()
	_show_next_modifier()
