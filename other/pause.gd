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
var selected_source_type: String = "" # "bag" or "track"
var selected_track: ColorLoadoutTrack = null
var selected_index: int = -1

var inspector_label: RichTextLabel = null
var inspector_actions_box: HFlowContainer = null
var active_track_rows: Array[ColorTrackRow] = []
var active_bag_grid: InventoryBagGrid = null
var inv_btn: Button = null

@onready var pause_overlay: PanelContainer = $pause_overlay
@onready var gold: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/CenterContainer/HBoxContainer/VBoxContainer/gold
var grd
var gold_on_label: int

func _ready() -> void:
	grd = _find_grd()
	pause_overlay.visible = false
	_create_compact_inventory_button()

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
	active_bag_grid = null

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

	var bag_header := Label.new()
	bag_header.text = "Equipment Bag (%d) — Tap to Quick-Equip or Drag onto a Track" % Global.cur_char.modifier_inventory.size()
	bag_header.add_theme_font_size_override("font_size", 14)
	bag_header.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	wrapper.add_child(bag_header)

	var bag_grid := InventoryBagGrid.new()
	bag_grid.custom_minimum_size = Vector2(460, 230)
	wrapper.add_child(bag_grid)
	bag_grid.populate_bag(Global.cur_char.modifier_inventory, can_edit)
	bag_grid.modifier_dropped_on_bag_grid.connect(_on_modifier_dropped_on_bag)
	bag_grid.bag_tile_clicked.connect(_on_bag_tile_clicked)
	active_bag_grid = bag_grid

	_sync_selection_highlights()
	_update_inspector_banner(selected_inspector_mod)

func _sync_selection_highlights() -> void:
	for row in active_track_rows:
		if is_instance_valid(row):
			row.highlight_selected_mod(selected_inspector_mod if selected_source_type == "track" else null)
	if is_instance_valid(active_bag_grid):
		active_bag_grid.highlight_selected_mod(selected_inspector_mod if selected_source_type == "bag" else null)

func _update_inspector_banner(mod: Equipment) -> void:
	if inspector_label == null:
		return
	if inspector_actions_box != null:
		for child in inspector_actions_box.get_children():
			child.queue_free()

	if mod == null:
		inspector_label.text = "[color=#9b95a6]Tap any equipment tile in your Tracks or Bag to inspect details, reorder chain position, or quick-equip/unequip.[/color]"
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

	if selected_source_type == "bag":
		for c_id in Global.cur_char.active_color_pool:
			var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
			if track != null and track.is_color_compatible(mod):
				var eq_btn := Button.new()
				var used_s: int = track.get_used_slots()
				var max_s: int = track.max_slots
				var c_name: String = Global.get_color_name(c_id)
				var fits: bool = track.can_equip(mod)
				eq_btn.text = ("+Equip %s (%d/%d)" % [c_name, used_s, max_s]) if fits else ("Swap %s (%d/%d)" % [c_name, used_s, max_s])
				_style_action_button(eq_btn, 12)
				eq_btn.pressed.connect(_on_quick_equip_from_bag.bind(mod, selected_index, track))
				inspector_actions_box.add_child(eq_btn)
	elif selected_source_type == "track" and selected_track != null:
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

		var unequip_btn := Button.new()
		unequip_btn.text = "Unequip to Bag"
		_style_action_button(unequip_btn, 12)
		unequip_btn.pressed.connect(_on_quick_unequip_from_track.bind(mod, selected_track, selected_index))
		inspector_actions_box.add_child(unequip_btn)

func _on_quick_equip_from_bag(mod: Equipment, bag_idx: int, target_track: ColorLoadoutTrack) -> void:
	if Global.cur_char == null or mod == null or target_track == null:
		return
	var drag_data := {
		"type": "modifier_drag",
		"source": "bag",
		"modifier": mod,
		"bag_index": bag_idx
	}
	if Global.cur_char.handle_modifier_drop_on_track(drag_data, target_track, -1):
		selected_source_type = "track"
		selected_track = target_track
		selected_index = target_track.equipped_modifiers.find(mod)
	if stats != null:
		stats.expand()
	_populate_loadout_view()

func _on_quick_unequip_from_track(mod: Equipment, src_track: ColorLoadoutTrack, src_idx: int) -> void:
	if Global.cur_char == null or mod == null or src_track == null:
		return
	var drag_data := {
		"type": "modifier_drag",
		"source": "track",
		"modifier": mod,
		"source_track": src_track,
		"source_index": src_idx
	}
	if Global.cur_char.handle_modifier_drop_on_bag(drag_data, -1):
		selected_source_type = "bag"
		selected_track = null
		selected_index = Global.cur_char.modifier_inventory.find(mod)
	if stats != null:
		stats.expand()
	_populate_loadout_view()

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

func _on_bag_tile_clicked(mod: Equipment, bag_idx: int) -> void:
	selected_inspector_mod = mod
	selected_source_type = "bag"
	selected_track = null
	selected_index = bag_idx
	_sync_selection_highlights()
	_update_inspector_banner(mod)

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

func _on_modifier_dropped_on_bag(drag_data: Dictionary, target_bag_index: int) -> void:
	if Global.cur_char != null:
		selected_inspector_mod = drag_data.get("modifier", null)
		Global.cur_char.handle_modifier_drop_on_bag(drag_data, target_bag_index)
		selected_source_type = "bag"
		selected_track = null
		selected_index = Global.cur_char.modifier_inventory.find(selected_inspector_mod)
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
