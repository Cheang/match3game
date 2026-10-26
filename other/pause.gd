extends Control

@export var gold_counter: bool = true
@export var pause_btn: bool = true
@export var player_stats_btn = true
@export var title_container: bool = true
@export var title_text: String

const BTN_NORMAL_TEX = preload("res://assets/level_ui/btn/btn_2.png")
const BTN_HOVER_TEX = preload("res://assets/level_ui/btn/btn_2_hover.png")
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
var inspector_label: RichTextLabel = null
var inv_btn: Button = null

@onready var pause_overlay: PanelContainer = $pause_overlay
@onready var gold: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/CenterContainer/HBoxContainer/VBoxContainer/gold
var grd
var gold_on_label: int

func _ready() -> void:
	grd = _find_grd()
	pause_overlay.visible = false
	_create_compact_inventory_button()

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
	inv_btn.offset_top = 884.0
	inv_btn.offset_bottom = 940.0
	inv_btn.tooltip_text = "Open Loadout & Inventory"

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
	move_child(inv_btn, stats_overlay.get_index())

func _on_player_stat_updated(stat: String) -> void:
	if stat == "gold" and Global.cur_char != null:
		gold_on_label = Global.cur_char.gold
		gold.text = "%s" % [gold_on_label]

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
	if grd != null:
		if Global.cur_char != null and Global.cur_char.moves_left <= 0:
			grd.state = grd.wait
		else:
			grd.state = grd.move
	pause_overlay.visible = false

func _on_options_pressed() -> void:
	await get_tree().create_timer(.1).timeout

func _on_back_to_mm_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func set_title(text: String):
	var titletxt: Label = title.get_child(0)
	titletxt.text = text

func _populate_loadout_view() -> void:
	for child in deck_container.get_children():
		child.queue_free()
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
	tracks_title.text = "Color Loadout Tracks (Drag & Drop to Equip / Reorder)"
	tracks_title.add_theme_font_size_override("font_size", 15)
	tracks_title.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	wrapper.add_child(tracks_title)

	for c_id in Global.cur_char.active_color_pool:
		var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
		var row := ColorTrackRow.new()
		wrapper.add_child(row)
		row.setup_row(c_id, track, can_edit)
		row.modifier_dropped_on_row.connect(_on_modifier_dropped_on_track_row)
		row.row_slot_clicked.connect(_on_track_slot_clicked)

	# Compact Inspector Banner for clicked item
	var inspector_panel := PanelContainer.new()
	var insp_sb := StyleBoxFlat.new()
	insp_sb.bg_color = Color(0.14, 0.11, 0.17, 0.92)
	insp_sb.border_width_left = 1
	insp_sb.border_width_top = 1
	insp_sb.border_width_right = 1
	insp_sb.border_width_bottom = 1
	insp_sb.border_color = Color(0.45, 0.4, 0.52)
	insp_sb.corner_radius_top_left = 4
	insp_sb.corner_radius_top_right = 4
	insp_sb.corner_radius_bottom_left = 4
	insp_sb.corner_radius_bottom_right = 4
	insp_sb.content_margin_left = 8
	insp_sb.content_margin_right = 8
	insp_sb.content_margin_top = 4
	insp_sb.content_margin_bottom = 4
	inspector_panel.add_theme_stylebox_override("panel", insp_sb)
	wrapper.add_child(inspector_panel)

	inspector_label = RichTextLabel.new()
	inspector_label.bbcode_enabled = true
	inspector_label.fit_content = true
	inspector_label.custom_minimum_size = Vector2(440, 38)
	inspector_panel.add_child(inspector_label)
	_update_inspector_banner(selected_inspector_mod)

	var bag_header := Label.new()
	bag_header.text = "Equipment Bag (%d) — Drag to Track or Drop Here to Unequip" % Global.cur_char.modifier_inventory.size()
	bag_header.add_theme_font_size_override("font_size", 15)
	bag_header.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	wrapper.add_child(bag_header)

	var bag_grid := InventoryBagGrid.new()
	bag_grid.custom_minimum_size = Vector2(460, 280)
	wrapper.add_child(bag_grid)
	bag_grid.populate_bag(Global.cur_char.modifier_inventory, can_edit)
	bag_grid.modifier_dropped_on_bag_grid.connect(_on_modifier_dropped_on_bag)
	bag_grid.bag_tile_clicked.connect(_on_bag_tile_clicked)

func _update_inspector_banner(mod: Equipment) -> void:
	if inspector_label == null:
		return
	if mod == null:
		inspector_label.text = "[color=#9b95a6]Tap any equipment tile to inspect details, or drag & drop between slots and bag.[/color]"
		return
	var color_str: String = "Colorless"
	if not mod.is_colorless():
		var c_id: int = mod.bound_color if mod.bound_color >= 100 else (mod.allowed_colors[0] if not mod.allowed_colors.is_empty() else 0)
		color_str = Global.get_color_name(c_id)
	var badge: String = mod.get_trigger_badge_text()
	var trig_str: String = (" | Trigger: " + badge) if badge != "" else ""
	inspector_label.text = "[b]%s[/b] (%s, %d-Slot%s) — %s" % [
		mod.piece_name,
		color_str,
		mod.slot_cost,
		trig_str,
		mod.get_effect_description(Global.cur_char)
	]

func _on_bag_tile_clicked(mod: Equipment, _bag_idx: int) -> void:
	selected_inspector_mod = mod
	_update_inspector_banner(mod)

func _on_track_slot_clicked(mod: Equipment) -> void:
	selected_inspector_mod = mod
	_update_inspector_banner(mod)

func _on_modifier_dropped_on_track_row(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> void:
	if Global.cur_char != null:
		selected_inspector_mod = drag_data.get("modifier", null)
		Global.cur_char.handle_modifier_drop_on_track(drag_data, target_track, target_mod_index)
		_populate_loadout_view()

func _on_modifier_dropped_on_bag(drag_data: Dictionary, target_bag_index: int) -> void:
	if Global.cur_char != null:
		selected_inspector_mod = drag_data.get("modifier", null)
		Global.cur_char.handle_modifier_drop_on_bag(drag_data, target_bag_index)
		_populate_loadout_view()

func _on_texture_button_pressed() -> void:
	var anim_speed: float = 0.25
	if not stats_open:
		stats_open = true
		texture_button.disabled = true
		texture_button2.disabled = true
		if inv_btn != null:
			inv_btn.disabled = true
		texture_button.button_pressed = true
		if Global.cur_char != null:
			player_class.text = str(Global.cur_char.player_class)
			stats.expand()
			_populate_loadout_view()
		stats_overlay.position = Vector2(stats_overlay.position.x, 1024.0)
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
		move(Vector2(stats_overlay.position.x, 1024.0), anim_speed)
		await get_tree().create_timer(anim_speed).timeout
		stats_overlay.visible = false
		var deck_cont_children = deck_container.get_children()
		for child in deck_cont_children:
			child.queue_free()
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
