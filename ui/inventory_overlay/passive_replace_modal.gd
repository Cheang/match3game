class_name PassiveReplaceModal
extends CanvasLayer

signal modal_closed

const OUTER_FRAME_TEX = preload("res://assets/sprites/ui/legacy/btn/btn_2.png")
const INNER_PANEL_TEX = preload("res://assets/sprites/ui/legacy/btn/btn_2_hover.png")
const BTN_LIGHT_TEX = preload("res://assets/sprites/ui/legacy/btn/btn_2_light.png")

var new_passive: Resource = null
var selected_replace_index: int = -1

var root_panel: PanelContainer
var title_label: Label
var new_passive_summary: RichTextLabel
var passives_container: HBoxContainer
var replace_btn: Button
var discard_btn: Button
var passive_cards: Array[PanelContainer] = []

func _init() -> void:
	layer = 10
	_build_ui()

func _make_9slice_stylebox(tex: Texture2D, margin: float = 8.0, pad_h: float = 10.0, pad_v: float = 8.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

func _style_button(btn: Button, font_sz: int = 16) -> void:
	var sb_normal := _make_9slice_stylebox(OUTER_FRAME_TEX, 8.0, 10.0, 6.0)
	var sb_hover := _make_9slice_stylebox(BTN_LIGHT_TEX, 8.0, 10.0, 6.0)
	var sb_pressed := _make_9slice_stylebox(INNER_PANEL_TEX, 8.0, 10.0, 6.0)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.88, 0.86, 0.76))
	btn.add_theme_color_override("font_hover_color", Color(0.24, 0.18, 0.22))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.92, 0.82))

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.06, 0.04, 0.08, 0.88)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	root_panel = PanelContainer.new()
	root_panel.custom_minimum_size = Vector2(530, 0)
	root_panel.add_theme_stylebox_override("panel", _make_9slice_stylebox(OUTER_FRAME_TEX, 8.0, 14.0, 14.0))
	center.add_child(root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root_panel.add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	title_label.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.2, 1.0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.text = "Passive Slots Full (5/5)"
	vbox.add_child(title_label)

	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.8, 0.72))
	subtitle.text = "Select an equipped passive to replace, or discard the new passive."
	vbox.add_child(subtitle)

	# 1. New Passive Card Banner
	var new_card_panel := PanelContainer.new()
	var new_sb := StyleBoxFlat.new()
	new_sb.bg_color = Color(0.14, 0.11, 0.18, 0.95)
	new_sb.border_width_left = 2
	new_sb.border_width_top = 2
	new_sb.border_width_right = 2
	new_sb.border_width_bottom = 2
	new_sb.border_color = Color(0.95, 0.82, 0.35)
	new_sb.corner_radius_top_left = 6
	new_sb.corner_radius_top_right = 6
	new_sb.corner_radius_bottom_left = 6
	new_sb.corner_radius_bottom_right = 6
	new_sb.content_margin_left = 10
	new_sb.content_margin_right = 10
	new_sb.content_margin_top = 8
	new_sb.content_margin_bottom = 8
	new_card_panel.add_theme_stylebox_override("panel", new_sb)
	vbox.add_child(new_card_panel)

	new_passive_summary = RichTextLabel.new()
	new_passive_summary.bbcode_enabled = true
	new_passive_summary.fit_content = true
	new_passive_summary.scroll_active = false
	new_passive_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_passive_summary.custom_minimum_size = Vector2(480, 48)
	new_card_panel.add_child(new_passive_summary)

	# 2. Currently Equipped 5 Passives Section
	var eq_label := Label.new()
	eq_label.text = "Currently Equipped Passives (Tap one to select for replacement):"
	eq_label.add_theme_font_size_override("font_size", 13)
	eq_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	vbox.add_child(eq_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	passives_container = HBoxContainer.new()
	passives_container.add_theme_constant_override("separation", 8)
	scroll.add_child(passives_container)

	# 3. Action Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	replace_btn = Button.new()
	replace_btn.custom_minimum_size = Vector2(240, 40)
	replace_btn.text = "Replace Selected Passive"
	replace_btn.disabled = true
	_style_button(replace_btn, 15)
	replace_btn.pressed.connect(_on_replace_pressed)
	btn_hbox.add_child(replace_btn)

	discard_btn = Button.new()
	discard_btn.custom_minimum_size = Vector2(180, 40)
	discard_btn.text = "Discard New Passive"
	_style_button(discard_btn, 15)
	discard_btn.pressed.connect(_on_discard_pressed)
	btn_hbox.add_child(discard_btn)

func prompt_passive(passive: Resource) -> void:
	new_passive = passive
	selected_replace_index = -1
	_refresh_display()

func _refresh_display() -> void:
	if new_passive == null or Global.cur_char == null:
		modal_closed.emit()
		queue_free()
		return

	# Display new passive details
	var p_name: String = new_passive.name if ("name" in new_passive and new_passive.name != "") else "Passive Perk"
	var p_desc: String = ""
	if new_passive is Reward:
		p_desc = (new_passive as Reward).get_dynamic_description()
	elif new_passive.has_method("get_effect_description"):
		p_desc = new_passive.get_effect_description(Global.cur_char)

	new_passive_summary.text = "[color=#59fae0][b]NEW PASSIVE:[/b][/color] [color=#f2e6b6][b]%s[/b][/color]\n[color=#b2b8a3]%s[/color]" % [
		p_name,
		p_desc
	]

	# Build cards for 5 equipped passives
	for child in passives_container.get_children():
		child.queue_free()
	passive_cards.clear()

	var equipped: Array[Resource] = Global.cur_char.get_equipped_passives()
	for i in range(PlayerResource.MAX_PASSIVE_SLOTS):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(92, 130)
		card.mouse_filter = Control.MOUSE_FILTER_STOP

		var is_selected: bool = (i == selected_replace_index)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.14, 0.22, 0.95) if is_selected else Color(0.11, 0.08, 0.14, 0.9)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.95, 0.82, 0.35) if is_selected else Color(0.42, 0.36, 0.48)
		sb.corner_radius_top_left = 5
		sb.corner_radius_top_right = 5
		sb.corner_radius_bottom_left = 5
		sb.corner_radius_bottom_right = 5
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", sb)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)

		if i < equipped.size() and equipped[i] != null:
			var item: Resource = equipped[i]
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(36, 36)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if "icon" in item and item.icon != null:
				icon_rect.texture = item.icon
			card_vbox.add_child(icon_rect)

			var name_lbl := Label.new()
			name_lbl.text = item.name if ("name" in item and item.name != "") else "Slot %d" % (i + 1)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75) if is_selected else Color(0.8, 0.76, 0.7))
			card_vbox.add_child(name_lbl)

			var desc_lbl := Label.new()
			var desc_text: String = ""
			if item is Reward:
				desc_text = (item as Reward).description
			name_lbl.tooltip_text = desc_text
			desc_lbl.text = desc_text
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 8)
			desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.65, 0.62))
			card_vbox.add_child(desc_lbl)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "Empty\nSlot %d" % (i + 1)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 11)
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.55))
			card_vbox.add_child(empty_lbl)

		var slot_idx: int = i
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_selected(slot_idx)
		)

		passives_container.add_child(card)
		passive_cards.append(card)

	replace_btn.disabled = (selected_replace_index < 0)
	if selected_replace_index >= 0:
		replace_btn.text = "Replace Slot %d" % (selected_replace_index + 1)
	else:
		replace_btn.text = "Replace Selected Passive"

func _on_card_selected(idx: int) -> void:
	selected_replace_index = idx
	_refresh_display()

func _on_replace_pressed() -> void:
	if Global.cur_char != null and new_passive != null and selected_replace_index >= 0:
		Global.cur_char.equip_passive(new_passive, selected_replace_index)
	modal_closed.emit()
	queue_free()

func _on_discard_pressed() -> void:
	modal_closed.emit()
	queue_free()
