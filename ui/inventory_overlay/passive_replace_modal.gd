class_name PassiveReplaceModal
extends CanvasLayer

signal modal_closed

const TEX_PANEL_BG = preload("res://scenes/combat/assets/inventory_btn_unpressed.png")
const TEX_INNER_PANEL = preload("res://ui/inventory_overlay/assets/ability_description_panel.png")
const TEX_GENERAL_BTN = preload("res://assets/sprites/ui/general_button_unpressed.png")
const TEX_PASSIVE_SELECTED = preload("res://ui/inventory_overlay/assets/passive_selected.png")
const TEX_PASSIVE_UNSELECTED = preload("res://ui/inventory_overlay/assets/passive_unselected.png")
const PALETTE_SHADER = preload("res://assets/shaders/palette_swap_5.gdshader")
const TITLE_FONT = preload("res://assets/theme/title.ttf")
const BODY_FONT = preload("res://assets/theme/font_153.ttf")

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
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _make_9slice_stylebox(tex: Texture2D, margin: float = 8.0, pad_h: float = 10.0, pad_v: float = 8.0, mod_col: Color = Color.WHITE) -> StyleBoxTexture:
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
	sb.modulate_color = mod_col
	return sb

func _style_button(btn: Button, font_sz: int = 18) -> void:
	btn.add_theme_stylebox_override("normal", _make_9slice_stylebox(TEX_GENERAL_BTN, 4.0, 10.0, 6.0, Color.WHITE))
	btn.add_theme_stylebox_override("hover", _make_9slice_stylebox(TEX_GENERAL_BTN, 4.0, 10.0, 6.0, Color(1.12, 1.12, 1.12, 1.0)))
	btn.add_theme_stylebox_override("pressed", _make_9slice_stylebox(TEX_GENERAL_BTN, 4.0, 10.0, 6.0, Color(0.85, 0.85, 0.85, 1.0)))
	btn.add_theme_stylebox_override("disabled", _make_9slice_stylebox(TEX_GENERAL_BTN, 4.0, 10.0, 6.0, Color(0.65, 0.65, 0.65, 0.7)))
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color("#2e2633"))
	btn.add_theme_color_override("font_hover_color", Color("#17121b"))
	btn.add_theme_color_override("font_pressed_color", Color("#100c14"))
	btn.add_theme_color_override("font_disabled_color", Color(0.44, 0.38, 0.46, 0.8))

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.06, 0.05, 0.09, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	root_panel = PanelContainer.new()
	root_panel.custom_minimum_size = Vector2(536, 0)
	root_panel.add_theme_stylebox_override("panel", _make_9slice_stylebox(TEX_PANEL_BG, 15.0, 16.0, 16.0))
	center.add_child(root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root_panel.add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", TITLE_FONT)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("#2e2633"))
	title_label.text = "Passive Slots Full (5/5)"
	vbox.add_child(title_label)

	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", BODY_FONT)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#3b3042"))
	subtitle.text = "Select an equipped passive to replace, or discard the new passive."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	# 1. New Passive Card Banner (dark pixel-art description panel style)
	var new_card_panel := PanelContainer.new()
	new_card_panel.add_theme_stylebox_override("panel", _make_9slice_stylebox(TEX_INNER_PANEL, 4.0, 12.0, 10.0))
	vbox.add_child(new_card_panel)

	new_passive_summary = RichTextLabel.new()
	new_passive_summary.bbcode_enabled = true
	new_passive_summary.fit_content = true
	new_passive_summary.scroll_active = false
	new_passive_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_passive_summary.custom_minimum_size = Vector2(484, 54)
	new_passive_summary.add_theme_font_override("normal_font", BODY_FONT)
	new_passive_summary.add_theme_font_override("bold_font", TITLE_FONT)
	new_passive_summary.add_theme_font_size_override("normal_font_size", 16)
	new_passive_summary.add_theme_font_size_override("bold_font_size", 18)
	new_passive_summary.add_theme_color_override("default_color", Color("#f4f1f8"))
	new_passive_summary.add_theme_constant_override("outline_size", 0)
	new_card_panel.add_child(new_passive_summary)

	# 2. Currently Equipped 5 Passives Section
	var eq_label := Label.new()
	eq_label.text = "Currently Equipped Passives (Tap to select):"
	eq_label.add_theme_font_override("font", BODY_FONT)
	eq_label.add_theme_font_size_override("font_size", 16)
	eq_label.add_theme_color_override("font_color", Color("#2e2633"))
	vbox.add_child(eq_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 152)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	passives_container = HBoxContainer.new()
	passives_container.add_theme_constant_override("separation", 8)
	passives_container.alignment = BoxContainer.ALIGNMENT_CENTER
	passives_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(passives_container)

	# 3. Action Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	replace_btn = Button.new()
	replace_btn.custom_minimum_size = Vector2(240, 44)
	replace_btn.text = "Replace Selected"
	replace_btn.disabled = true
	_style_button(replace_btn, 18)
	replace_btn.pressed.connect(_on_replace_pressed)
	btn_hbox.add_child(replace_btn)

	discard_btn = Button.new()
	discard_btn.custom_minimum_size = Vector2(180, 44)
	discard_btn.text = "Discard New"
	_style_button(discard_btn, 18)
	discard_btn.pressed.connect(_on_discard_pressed)
	btn_hbox.add_child(discard_btn)

func prompt_passive(passive: Resource) -> void:
	new_passive = passive
	selected_replace_index = -1
	_refresh_display()

func _determine_passive_color(p_res: Resource) -> int:
	if p_res == null:
		return 500
	if p_res is Equipment:
		match (p_res as Equipment).family:
			"sword", "fists": return 100
			"shields": return 200
			"mobility", "healing", "beast": return 300
		return 500
	if p_res is Reward:
		var rew := p_res as Reward
		if rew.might > 0.0:
			return 100
		elif rew.grit > 0.0:
			return 200
		elif rew.agility > 0 or rew.heal_hp > 0.0:
			return 300
		elif rew.spirit > 0.0:
			return 400
	return 500

func _refresh_display() -> void:
	if new_passive == null or Global.cur_char == null:
		modal_closed.emit()
		queue_free()
		return

	var p_name: String = new_passive.name if ("name" in new_passive and new_passive.name != "") else "Passive Perk"
	var p_desc: String = RewardGrantHandler.get_description(new_passive)
	if p_desc != "":
		p_desc = InventoryOverlay._remap_colors_for_dark_panel(p_desc)

	new_passive_summary.text = "[color=#72e89d][b]NEW PASSIVE:[/b][/color] [color=#ffd966][b]%s[/b][/color]\n[color=#e6e2ec]%s[/color]" % [
		p_name,
		p_desc
	]

	for child in passives_container.get_children():
		child.queue_free()
	passive_cards.clear()

	var equipped: Array[Resource] = Global.cur_char.get_equipped_passives()
	for i in range(PlayerResource.MAX_PASSIVE_SLOTS):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(92, 138)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var is_selected: bool = (i == selected_replace_index)
		var mod_tint: Color = Color(1.12, 1.08, 0.98, 1.0) if is_selected else Color.WHITE
		card.add_theme_stylebox_override("panel", _make_9slice_stylebox(TEX_INNER_PANEL, 4.0, 6.0, 6.0, mod_tint))

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)

		if i < equipped.size() and equipped[i] != null:
			var item: Resource = equipped[i]

			var socket_holder := Control.new()
			socket_holder.custom_minimum_size = Vector2(56, 56)
			socket_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			socket_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_vbox.add_child(socket_holder)

			var frame_tex := TextureRect.new()
			frame_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			frame_tex.texture = TEX_PASSIVE_SELECTED if is_selected else TEX_PASSIVE_UNSELECTED
			frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			frame_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var s_mat := ShaderMaterial.new()
			s_mat.shader = PALETTE_SHADER
			OverlaySlotUI.apply_palette(s_mat, _determine_passive_color(item))
			frame_tex.material = s_mat
			socket_holder.add_child(frame_tex)

			var icon_rect := TextureRect.new()
			icon_rect.position = Vector2(10, 10)
			icon_rect.size = Vector2(36, 36)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if "icon" in item and item.icon != null:
				icon_rect.texture = item.icon
			socket_holder.add_child(icon_rect)

			var name_lbl := Label.new()
			name_lbl.text = item.name if ("name" in item and item.name != "") else "Slot %d" % (i + 1)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.add_theme_font_override("font", BODY_FONT)
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", Color("#ffd966") if is_selected else Color.WHITE)
			card_vbox.add_child(name_lbl)

			var desc_text: String = (item as Reward).description if (item is Reward) else ""
			card.tooltip_text = "%s\n%s" % [name_lbl.text, desc_text]
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "Empty\nSlot %d" % (i + 1)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_override("font", BODY_FONT)
			empty_lbl.add_theme_font_size_override("font_size", 14)
			empty_lbl.add_theme_color_override("font_color", Color("#8c829b"))
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
		replace_btn.text = "Replace Selected"

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
