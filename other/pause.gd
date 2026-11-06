extends Control

@export var gold_counter: bool = true
@export var pause_btn: bool = true
@export var player_stats_btn = true
@export var title_container: bool = true
@export var title_text: String

const BTN_NORMAL_TEX = preload("res://assets/level_ui/btn/btn_2.png")
const BTN_HOVER_TEX = preload("res://assets/level_ui/btn/btn_2_hover.png")
const BTN_LIGHT_TEX = preload("res://assets/level_ui/btn/btn_2_light.png")
const BTN_DISABLED_TEX = preload("res://assets/level_ui/btn/btn_disabled.png")
const BACKPACK_SHEET = preload("res://assets/level_ui/icons/backpack.png")

@onready var player_class: Label = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/player_class

@onready var stats_overlay: MarginContainer = $stats_overlay
@onready var texture_button: TextureButton = $stats_overlay/Container/MarginContainer/VBoxContainer/HBoxContainer/TextureButton
@onready var tabs: HBoxContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/tabs
@onready var infocontainer: VBoxContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/infocontainer
@onready var deck: VBoxContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/infocontainer/Deck
@onready var deck_btn: Button = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/tabs/deck_btn
@onready var deck_container: HFlowContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/infocontainer/Deck/ScrollContainer/deck_container
@onready var stats: VBoxContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/infocontainer/Stats
@onready var stats_btn: Button = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/container/tabs/stats_btn

@onready var pausebtn: Button = $MarginContainer/VBoxContainer/HBoxContainer/pause_btn
@onready var goldbox: Control = $MarginContainer/VBoxContainer/HBoxContainer/Control
@onready var title: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/PanelContainer
@onready var texture_button2: Button = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/TextureButton

var stats_open: bool = false
var selected_inspector_mod: Equipment = null
var selected_source_type: String = "" # "track" or "passive"
var selected_track: ColorLoadoutTrack = null
var selected_index: int = -1

var inspector_label: RichTextLabel = null
var inspector_actions_box: HFlowContainer = null
var active_track_rows: Array[ColorTrackRow] = []
var inv_btn: Button = null

@onready var pause_overlay: PanelContainer = $pause_overlay
@onready var gold: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/CenterContainer/HBoxContainer/VBoxContainer/gold
var grd
var gold_on_label: int

func _ready() -> void:
	grd = _find_grd()
	pause_overlay.visible = false

	var mm_btn: Button = pause_overlay.find_child("back_to_mm", true, false) as Button
	if mm_btn != null and not mm_btn.pressed.is_connected(_on_back_to_mm_pressed):
		mm_btn.pressed.connect(_on_back_to_mm_pressed)

	# Park stats_overlay completely off-screen and hidden when closed so it takes zero space at bottom
	stats_overlay.position = Vector2(stats_overlay.position.x, 1024.0)
	stats_overlay.visible = false
	deck_btn.text = "Loadout"
	_on_deck_btn_pressed()

	if not gold_counter:
		goldbox.modulate = Color(1, 1, 1, 0)
	if not pause_btn:
		pausebtn.modulate = Color(1, 1, 1, 0)
		pausebtn.disabled = true
	if not title_container:
		title.modulate = Color(1, 1, 1, 0)
	if not player_stats_btn:
		stats_overlay.visible = false
		texture_button.disabled = true
		if inv_btn != null:
			inv_btn.visible = false
			inv_btn.disabled = true
	set_title(title_text)
	if Global.cur_char != null:
		gold_on_label = Global.cur_char.gold
		if not Global.cur_char.updateUIPlayer.is_connected(_on_player_stat_updated):
			Global.cur_char.updateUIPlayer.connect(_on_player_stat_updated)
	gold.text = "%s" % [gold_on_label]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if stats_open:
			_on_texture_button_pressed()
			get_viewport().set_input_as_handled()
		elif pause_overlay.visible:
			_on_resume_pressed()
			get_viewport().set_input_as_handled()
		elif pause_btn and not pausebtn.disabled and Global.game_is_played:
			_on_pause_btn_pressed()
			get_viewport().set_input_as_handled()

func _make_small_btn_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 6.0
	sb.texture_margin_top = 6.0
	sb.texture_margin_right = 6.0
	sb.texture_margin_bottom = 6.0
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	return sb

func _style_action_button(btn: Button, font_sz: int = 12) -> void:
	btn.add_theme_stylebox_override("normal", _make_small_btn_style(BTN_NORMAL_TEX))
	btn.add_theme_stylebox_override("hover", _make_small_btn_style(BTN_LIGHT_TEX))
	btn.add_theme_stylebox_override("pressed", _make_small_btn_style(BTN_HOVER_TEX))
	btn.add_theme_stylebox_override("disabled", _make_small_btn_style(BTN_DISABLED_TEX))
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.86, 0.88, 0.76))
	btn.add_theme_color_override("font_hover_color", Color(0.24, 0.18, 0.24))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.92, 0.82))

func _create_compact_inventory_button() -> void:
	if inv_btn != null:
		return
	inv_btn = Button.new()
	inv_btn.name = "compact_inv_btn"
	inv_btn.custom_minimum_size = Vector2(56, 56)
	inv_btn.anchor_left = 0.5
	inv_btn.anchor_right = 0.5
	inv_btn.anchor_top = 0.0
	inv_btn.anchor_bottom = 0.0
	inv_btn.offset_left = 208.0
	inv_btn.offset_right = 264.0
	inv_btn.offset_top = 888.0
	inv_btn.offset_bottom = 944.0
	inv_btn.tooltip_text = "Open Loadout & Character Stats"

	var sb_normal := StyleBoxTexture.new()
	sb_normal.texture = BTN_NORMAL_TEX
	sb_normal.texture_margin_left = 8.0
	sb_normal.texture_margin_top = 8.0
	sb_normal.texture_margin_right = 8.0
	sb_normal.texture_margin_bottom = 8.0

	var sb_hover := StyleBoxTexture.new()
	sb_hover.texture = BTN_HOVER_TEX
	sb_hover.texture_margin_left = 8.0
	sb_hover.texture_margin_top = 8.0
	sb_hover.texture_margin_right = 8.0
	sb_hover.texture_margin_bottom = 8.0

	var sb_disabled := StyleBoxTexture.new()
	sb_disabled.texture = BTN_DISABLED_TEX
	sb_disabled.texture_margin_left = 8.0
	sb_disabled.texture_margin_top = 8.0
	sb_disabled.texture_margin_right = 8.0
	sb_disabled.texture_margin_bottom = 8.0

	inv_btn.add_theme_stylebox_override("normal", sb_normal)
	inv_btn.add_theme_stylebox_override("hover", sb_hover)
	inv_btn.add_theme_stylebox_override("pressed", sb_hover)
	inv_btn.add_theme_stylebox_override("disabled", sb_disabled)

	var bag_atlas := AtlasTexture.new()
	bag_atlas.atlas = BACKPACK_SHEET
	bag_atlas.region = Rect2(240, 0, 44, 44)
	inv_btn.icon = bag_atlas
	inv_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_btn.pressed.connect(_on_texture_button_pressed)

	add_child(inv_btn)
	if stats_overlay != null:
		move_child(inv_btn, stats_overlay.get_index())

func _on_player_stat_updated(stat: String) -> void:
	if stat == "gold" and Global.cur_char != null:
		gold_on_label = Global.cur_char.gold
		gold.text = "%s" % [gold_on_label]
	if stats_open and stats != null:
		stats.expand()

func _exit_tree() -> void:
	if Global.cur_char != null and Global.cur_char.updateUIPlayer.is_connected(_on_player_stat_updated):
		Global.cur_char.updateUIPlayer.disconnect(_on_player_stat_updated)

func _on_pause_btn_pressed() -> void:
	if Global.game_is_played == true:
		Global.game_is_played = false
		if grd != null:
			grd.state = grd.wait
		pause_overlay.visible = true

func _on_resume_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	Global.game_is_played = true
	if grd != null and not stats_open:
		if Global.cur_char != null and Global.cur_char.moves_left <= 0:
			grd.state = grd.wait
		else:
			grd.state = grd.move
	pause_overlay.visible = false

func _on_options_pressed() -> void:
	await get_tree().create_timer(.1).timeout

func _on_back_to_mm_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	SceneManager.change_scene("res://scenes/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func set_title(text: String):
	var titletxt: Label = title.get_child(0)
	titletxt.text = text

func _populate_loadout_view() -> void:
	for child in deck_container.get_children():
		child.queue_free()
	active_track_rows.clear()

	if Global.cur_char == null:
		return
	Global.cur_char.ensure_loadout_tracks()
	var can_edit: bool = true

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(465, 0)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 6)
	deck_container.add_child(wrapper)

	var tracks_title := Label.new()
	tracks_title.text = "Color Loadout Tracks (Tap to Inspect/Manage or Drag & Drop)"
	tracks_title.add_theme_font_size_override("font_size", 14)
	tracks_title.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	wrapper.add_child(tracks_title)

	for c_id in Global.cur_char.active_color_pool:
		var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
		var row := ColorTrackRow.new()
		wrapper.add_child(row)
		row.setup_row(c_id, track, can_edit)
		row.modifier_dropped_on_row.connect(_on_modifier_dropped_on_track_row)
		row.row_slot_selected.connect(_on_track_slot_selected)
		active_track_rows.append(row)

	# Interactive Inspector Card + Quick Action Bar
	var inspector_panel := PanelContainer.new()
	var insp_sb := StyleBoxFlat.new()
	insp_sb.bg_color = Color(0.13, 0.10, 0.16, 0.95)
	insp_sb.border_width_left = 2
	insp_sb.border_width_top = 2
	insp_sb.border_width_right = 2
	insp_sb.border_width_bottom = 2
	insp_sb.border_color = Color(0.52, 0.46, 0.58)
	insp_sb.corner_radius_top_left = 5
	insp_sb.corner_radius_top_right = 5
	insp_sb.corner_radius_bottom_left = 5
	insp_sb.corner_radius_bottom_right = 5
	insp_sb.content_margin_left = 8
	insp_sb.content_margin_right = 8
	insp_sb.content_margin_top = 6
	insp_sb.content_margin_bottom = 6
	inspector_panel.add_theme_stylebox_override("panel", insp_sb)
	wrapper.add_child(inspector_panel)

	var insp_vbox := VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 6)
	inspector_panel.add_child(insp_vbox)

	inspector_label = RichTextLabel.new()
	inspector_label.bbcode_enabled = true
	inspector_label.fit_content = true
	inspector_label.scroll_active = false
	inspector_label.custom_minimum_size = Vector2(440, 38)
	insp_vbox.add_child(inspector_label)

	inspector_actions_box = HFlowContainer.new()
	inspector_actions_box.add_theme_constant_override("h_separation", 6)
	inspector_actions_box.add_theme_constant_override("v_separation", 4)
	insp_vbox.add_child(inspector_actions_box)

	# Active Passives (5 Slots) Section
	var passives_list: Array[Resource] = Global.cur_char.get_equipped_passives() if Global.cur_char != null else []
	var passives_header := Label.new()
	passives_header.text = "Active Passives (%d/5) — Permanent Character Perks" % passives_list.size()
	passives_header.add_theme_font_size_override("font_size", 14)
	passives_header.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	wrapper.add_child(passives_header)

	var passives_scroll := ScrollContainer.new()
	passives_scroll.custom_minimum_size = Vector2(460, 115)
	passives_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	passives_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrapper.add_child(passives_scroll)

	var passives_hbox := HBoxContainer.new()
	passives_hbox.add_theme_constant_override("separation", 8)
	passives_scroll.add_child(passives_hbox)

	for i in range(PlayerResource.MAX_PASSIVE_SLOTS):
		var p_card := PanelContainer.new()
		p_card.custom_minimum_size = Vector2(86, 105)
		p_card.mouse_filter = Control.MOUSE_FILTER_STOP

		var is_selected: bool = (selected_source_type == "passive" and selected_index == i)
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(0.18, 0.14, 0.22, 0.95) if is_selected else Color(0.11, 0.08, 0.14, 0.9)
		p_sb.border_width_left = 1
		p_sb.border_width_top = 1
		p_sb.border_width_right = 1
		p_sb.border_width_bottom = 1
		p_sb.border_color = Color(0.95, 0.82, 0.35) if is_selected else Color(0.48, 0.42, 0.54)
		p_sb.corner_radius_top_left = 4
		p_sb.corner_radius_top_right = 4
		p_sb.corner_radius_bottom_left = 4
		p_sb.corner_radius_bottom_right = 4
		p_sb.content_margin_left = 4
		p_sb.content_margin_right = 4
		p_sb.content_margin_top = 4
		p_sb.content_margin_bottom = 4
		p_card.add_theme_stylebox_override("panel", p_sb)

		var p_vbox := VBoxContainer.new()
		p_vbox.add_theme_constant_override("separation", 3)
		p_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		p_card.add_child(p_vbox)

		if i < passives_list.size() and passives_list[i] != null:
			var item: Resource = passives_list[i]
			var p_icon := TextureRect.new()
			p_icon.custom_minimum_size = Vector2(32, 32)
			p_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			p_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if "icon" in item and item.icon != null:
				p_icon.texture = item.icon
			p_vbox.add_child(p_icon)

			var p_lbl := Label.new()
			p_lbl.text = item.name if ("name" in item and item.name != "") else "Passive %d" % (i + 1)
			p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p_lbl.add_theme_font_size_override("font_size", 9)
			p_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75))
			p_vbox.add_child(p_lbl)

			var p_desc_str: String = (item as Reward).description if (item is Reward) else ""
			p_lbl.tooltip_text = p_desc_str
			var p_desc_lbl := Label.new()
			p_desc_lbl.text = p_desc_str
			p_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p_desc_lbl.add_theme_font_size_override("font_size", 8)
			p_desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.65, 0.62))
			p_vbox.add_child(p_desc_lbl)

			var slot_idx: int = i
			var cur_item: Resource = item
			p_card.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_passive_slot_clicked(cur_item, slot_idx)
			)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "Empty\nPassive Slot"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 10)
			empty_lbl.add_theme_color_override("font_color", Color(0.48, 0.44, 0.52))
			p_vbox.add_child(empty_lbl)

		passives_hbox.add_child(p_card)

	_sync_selection_highlights()
	_update_inspector_banner(selected_inspector_mod)

func _sync_selection_highlights() -> void:
	for row in active_track_rows:
		if is_instance_valid(row):
			row.highlight_selected_mod(selected_inspector_mod if selected_source_type == "track" else null)

func _update_inspector_banner(mod: Equipment) -> void:
	if inspector_label == null:
		return
	if inspector_actions_box != null:
		for child in inspector_actions_box.get_children():
			child.queue_free()

	if mod == null:
		inspector_label.text = "[color=#9b95a6]Tap any equipment tile in your Tracks or Passives to inspect details, reorder chain position, or discard/unequip.[/color]"
		if inspector_actions_box != null:
			inspector_actions_box.visible = false
		return

	var color_str: String = "Any Track (Colorless)"
	if not mod.is_colorless():
		var c_names: Array[String] = []
		for ec in mod.get_effective_allowed_colors():
			var cn: String = Global.get_color_name(ec)
			if not c_names.has(cn):
				c_names.append(cn)
		color_str = ", ".join(c_names)

	var badge: String = mod.get_trigger_badge_text()
	var trig_str: String = (" • Trigger: [color=#fad65a]%s[/color]" % badge) if badge != "" else ""
	var cd_str: String = ""
	if mod.once_per_battle:
		cd_str = " • [color=#f29d4c]Once/Battle[/color]"
	elif mod.get_effective_cooldown_turns() > 0:
		cd_str = " • [color=#f29d4c]%dT Cooldown[/color]" % mod.get_effective_cooldown_turns()

	var r_name: String = Equipment.get_rarity_name(mod.rarity)
	var r_hex: String = Equipment.get_rarity_hex(mod.rarity)
	var upg_str: String = (" +%d" % mod.upgrade) if mod.upgrade > 0 else ""
	var next_str: String = ""
	if selected_source_type == "track" and selected_track != null and selected_index == selected_track.next_entry_cursor:
		next_str = "  [color=#59fae0][b]► NEXT IN CHAIN[/b][/color]"

	inspector_label.text = "[color=%s][b]%s%s[/b] [%s][/color] [color=#b2b8a3](%d-Slot • %s%s%s)[/color]%s\n%s" % [
		r_hex,
		mod.piece_name,
		upg_str,
		r_name,
		mod.slot_cost,
		color_str,
		trig_str,
		cd_str,
		next_str,
		mod.get_effect_description(Global.cur_char)
	]

	if inspector_actions_box == null or Global.cur_char == null:
		return
	inspector_actions_box.visible = true

	if selected_source_type == "track" and selected_track != null:
		var count: int = selected_track.get_filled_entry_count()
		if count > 1:
			var left_btn := Button.new()
			left_btn.text = "◄ Move Left"
			left_btn.disabled = (selected_index <= 0)
			_style_action_button(left_btn, 12)
			left_btn.pressed.connect(_on_reorder_track_item.bind(selected_track, selected_index, selected_index - 1))
			inspector_actions_box.add_child(left_btn)

			var right_btn := Button.new()
			right_btn.text = "Move Right ►"
			right_btn.disabled = (selected_index >= count - 1)
			_style_action_button(right_btn, 12)
			right_btn.pressed.connect(_on_reorder_track_item.bind(selected_track, selected_index, selected_index + 1))
			inspector_actions_box.add_child(right_btn)

		var discard_btn := Button.new()
		discard_btn.text = "Discard Equipment"
		_style_action_button(discard_btn, 12)
		discard_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		discard_btn.pressed.connect(_on_discard_track_item.bind(selected_track, selected_index))
		inspector_actions_box.add_child(discard_btn)

func _on_discard_track_item(src_track: ColorLoadoutTrack, src_idx: int) -> void:
	if Global.cur_char == null or src_track == null:
		return
	if src_idx >= 0 and src_idx < src_track.equipped_modifiers.size():
		src_track.unequip_at(src_idx)
		src_track.clamp_cursor()
		Global.cur_char.recalculate_equipment_passives()
		Global.cur_char.loadoutChanged.emit()
	selected_inspector_mod = null
	selected_source_type = ""
	selected_track = null
	selected_index = -1
	if stats != null:
		stats.expand()
	_populate_loadout_view()

func _on_passive_slot_clicked(item: Resource, slot_idx: int) -> void:
	selected_source_type = "passive"
	selected_track = null
	selected_index = slot_idx
	selected_inspector_mod = null
	_sync_selection_highlights()

	if inspector_label == null:
		return
	if inspector_actions_box != null:
		for child in inspector_actions_box.get_children():
			child.queue_free()

	if item == null:
		inspector_label.text = "[color=#9b95a6]Passive Slot %d is empty. Earn passives and talent perks from post-combat drafts.[/color]" % (slot_idx + 1)
		if inspector_actions_box != null:
			inspector_actions_box.visible = false
		return

	var p_name: String = item.name if ("name" in item and item.name != "") else "Passive Perk"
	var p_desc: String = item.description if (item is Reward and item.description != "") else ""
	inspector_label.text = "[color=#fad65a][b]%s[/b][/color] [color=#b2b8a3](Passive Slot %d/5)[/color]\n%s" % [p_name, slot_idx + 1, p_desc]

	if inspector_actions_box != null:
		inspector_actions_box.visible = true
		var unequip_p_btn := Button.new()
		unequip_p_btn.text = "Unequip / Revoke Passive"
		_style_action_button(unequip_p_btn, 12)
		unequip_p_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		unequip_p_btn.pressed.connect(func():
			if Global.cur_char != null:
				Global.cur_char.unequip_passive(slot_idx)
			selected_source_type = ""
			selected_index = -1
			if stats != null:
				stats.expand()
			_populate_loadout_view()
		)
		inspector_actions_box.add_child(unequip_p_btn)

func _on_reorder_track_item(track: ColorLoadoutTrack, from_idx: int, to_idx: int) -> void:
	if Global.cur_char == null or track == null:
		return
	if from_idx < 0 or from_idx >= track.equipped_modifiers.size():
		return
	var mod: Equipment = track.equipped_modifiers[from_idx]
	var drag_data := {
		"type": "modifier_drag",
		"source": "track",
		"modifier": mod,
		"source_track": track,
		"source_index": from_idx
	}
	if Global.cur_char.handle_modifier_drop_on_track(drag_data, track, to_idx):
		selected_source_type = "track"
		selected_track = track
		selected_index = track.equipped_modifiers.find(mod)
	_populate_loadout_view()

func _on_track_slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_idx: int) -> void:
	selected_inspector_mod = mod
	selected_source_type = "track"
	selected_track = track
	selected_index = mod_idx
	_sync_selection_highlights()
	_update_inspector_banner(mod)

func _on_modifier_dropped_on_track_row(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> void:
	if Global.cur_char != null:
		selected_inspector_mod = drag_data.get("modifier", null)
		Global.cur_char.handle_modifier_drop_on_track(drag_data, target_track, target_mod_index)
		selected_source_type = "track"
		selected_track = target_track
		selected_index = target_track.equipped_modifiers.find(selected_inspector_mod)
		if stats != null:
			stats.expand()
		_populate_loadout_view()

func _on_texture_button_pressed() -> void:
	var anim_speed: float = 0.25
	var vp_h: float = max(1024.0, get_viewport_rect().size.y + 40.0)
	if not stats_open:
		stats_open = true
		if grd != null:
			grd.state = grd.wait
		texture_button.disabled = true
		texture_button2.disabled = true
		if inv_btn != null:
			inv_btn.disabled = true
		texture_button.button_pressed = true
		if Global.cur_char != null:
			player_class.text = str(Global.cur_char.player_class)
			stats.expand()
			_populate_loadout_view()
		stats_overlay.position = Vector2(stats_overlay.position.x, vp_h)
		stats_overlay.visible = true
		move(Vector2(stats_overlay.position.x, 0.0), anim_speed)
		await get_tree().create_timer(anim_speed).timeout
		texture_button.disabled = false
		texture_button2.disabled = false
		if inv_btn != null:
			inv_btn.disabled = false
	else:
		stats_open = false
		texture_button.disabled = true
		texture_button2.disabled = true
		if inv_btn != null:
			inv_btn.disabled = true
		texture_button.button_pressed = false
		move(Vector2(stats_overlay.position.x, vp_h), anim_speed)
		await get_tree().create_timer(anim_speed).timeout
		stats_overlay.visible = false
		var deck_cont_children = deck_container.get_children()
		for child in deck_cont_children:
			child.queue_free()
		if grd != null and Global.game_is_played and not pause_overlay.visible:
			if Global.cur_char != null and Global.cur_char.moves_left <= 0:
				grd.state = grd.wait
			else:
				grd.state = grd.move
		texture_button.disabled = false
		texture_button2.disabled = false
		if inv_btn != null:
			inv_btn.disabled = false

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(stats_overlay, "position", target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

func _on_help_pressed() -> void:
	pass

func _on_deck_btn_pressed() -> void:
	if deck_btn.button_pressed:
		var btns = tabs.get_children()
		for button: Button in btns:
			button.button_pressed = false
		deck_btn.button_pressed = true
		var infoscreens = infocontainer.get_children()
		for screen in infoscreens:
			screen.visible = false
		deck.visible = true

func _on_stats_btn_pressed() -> void:
	if stats_btn.button_pressed:
		var btns = tabs.get_children()
		for button: Button in btns:
			button.button_pressed = false
		stats_btn.button_pressed = true
		if stats != null:
			stats.expand()
		var infoscreens = infocontainer.get_children()
		for screen in infoscreens:
			screen.visible = false
		stats.visible = true

func _find_grd():
	if owner and owner.has_node("grd"):
		return owner.get_node("grd")
	var root = get_tree().current_scene
	if root:
		if root.has_node("grd"):
			return root.get_node("grd")
		return root.find_child("grd", true, false)
	return null
