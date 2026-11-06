extends CanvasLayer
class_name InventoryOverlay

## Standalone Inventory / Loadout Overlay screen.
## Used across all scenes to inspect color tracks, equipped abilities, and passives.
## Displays:
##  1. Top header ("Loadout")
##  2. Passives section (5-slot layout placeholder)
##  3. Top flexible spacer (ensuring tracks, description & buttons are bottom-aligned)
##  4. 5 Loadout tracks with color backgrounds, ultimate slot, and diamond ability icons
##  5. Ability description panel (using ability-description-panel.png)
##  6. Bottom navigation buttons row (using general-button-unpressed.png)

signal overlay_opened
signal overlay_closed
signal ability_selected(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)

static var instance: InventoryOverlay = null

const TEX_OVERLAY_BG = preload("res://assets/scene-assets/combat/inventory-btn-unpressed.png")
const TEX_DESC_PANEL = preload("res://assets/scene-assets/inventory-overlay/ability-description-panel.png")
const TEX_GENERAL_BTN = preload("res://assets/scene-assets/general-button-unpressed.png")
const TRACK_ROW_SCENE = preload("res://scenes/ui/inventory_overlay_track_row.tscn")
const TITLE_FONT = preload("res://assets/theme/title.ttf")

@export var description_panel_height: float = 160.0:
	set(val):
		description_panel_height = val
		if description_panel != null:
			description_panel.custom_minimum_size.y = val

@export var passives_section_height: float = 64.0:
	set(val):
		passives_section_height = val
		if passives_container != null:
			passives_container.custom_minimum_size.y = val

@export var header_title: String = "Loadout":
	set(val):
		header_title = val
		if header_label != null:
			header_label.text = val

var dimmer: ColorRect
var main_panel: NinePatchRect
var header_label: Label
var passives_container: VBoxContainer
var passives_hbox: HBoxContainer
var passive_slots: Array[PanelContainer] = []
var spacer: Control
var tracks_box: VBoxContainer
var track_rows: Array[InventoryOverlayTrackRow] = []
var description_panel: NinePatchRect
var description_label: RichTextLabel
var bottom_nav_box: HBoxContainer
var loadout_nav_btn: Button

var selected_ability: Equipment = null
var selected_track: ColorLoadoutTrack = null
var selected_is_ult: bool = false
var selected_slot_idx: int = -2

var _saved_game_is_played: bool = true

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_if_needed()
	visible = false

static func is_overlay_open() -> bool:
	return instance != null and is_instance_valid(instance) and instance.visible

static func toggle_overlay() -> void:
	if instance != null and is_instance_valid(instance):
		instance.toggle()
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.current_scene != null:
			var found := tree.current_scene.find_child("InventoryOverlay", true, false) as InventoryOverlay
			if found != null:
				found.toggle()

static func open_overlay() -> void:
	if instance != null and is_instance_valid(instance):
		instance.open()

static func close_overlay() -> void:
	if instance != null and is_instance_valid(instance):
		instance.close()

func open() -> void:
	_saved_game_is_played = Global.game_is_played
	Global.game_is_played = false

	_build_ui_if_needed()
	refresh_overlay_data()
	visible = true
	overlay_opened.emit()

func close() -> void:
	visible = false
	Global.game_is_played = _saved_game_is_played
	overlay_closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			close()
			get_viewport().set_input_as_handled()

func _build_ui_if_needed() -> void:
	dimmer = get_node_or_null("Dimmer") as ColorRect
	if dimmer == null:
		dimmer = ColorRect.new()
		dimmer.name = "Dimmer"
		dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		dimmer.color = Color(0.06, 0.05, 0.09, 0.72)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dimmer)
	if not dimmer.gui_input.is_connected(_on_dimmer_gui_input):
		dimmer.gui_input.connect(_on_dimmer_gui_input)

	var center := get_node_or_null("Center") as CenterContainer
	if center == null:
		center = CenterContainer.new()
		center.name = "Center"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(center)

	main_panel = center.get_node_or_null("MainPanel") as NinePatchRect
	if main_panel == null:
		main_panel = NinePatchRect.new()
		main_panel.name = "MainPanel"
		main_panel.texture = TEX_OVERLAY_BG
		main_panel.patch_margin_left = 6
		main_panel.patch_margin_top = 6
		main_panel.patch_margin_right = 6
		main_panel.patch_margin_bottom = 6
		main_panel.custom_minimum_size = Vector2(548, 930)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(main_panel)

	var margin := main_panel.get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		margin.mouse_filter = Control.MOUSE_FILTER_PASS
		main_panel.add_child(margin)

	var vbox := margin.get_node_or_null("ContentVBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "ContentVBox"
		vbox.add_theme_constant_override("separation", 8)
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		margin.add_child(vbox)

	# 1. Header: "Loadout"
	header_label = vbox.get_node_or_null("HeaderLabel") as Label
	if header_label == null:
		header_label = Label.new()
		header_label.name = "HeaderLabel"
		header_label.text = header_title
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_label.add_theme_font_override("font", TITLE_FONT)
		header_label.add_theme_font_size_override("font_size", 28)
		header_label.add_theme_color_override("font_color", Color("#2e2633"))
		vbox.add_child(header_label)

	# 2. Passives Section (5-slot layout placeholder)
	passives_container = vbox.get_node_or_null("PassivesSection") as VBoxContainer
	if passives_container == null:
		passives_container = VBoxContainer.new()
		passives_container.name = "PassivesSection"
		passives_container.custom_minimum_size.y = passives_section_height
		passives_container.add_theme_constant_override("separation", 2)
		vbox.add_child(passives_container)

		var pass_lbl := Label.new()
		pass_lbl.name = "PassivesTitle"
		pass_lbl.text = "Passives"
		pass_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pass_lbl.add_theme_font_override("font", TITLE_FONT)
		pass_lbl.add_theme_font_size_override("font_size", 14)
		pass_lbl.add_theme_color_override("font_color", Color("#5a485a"))
		passives_container.add_child(pass_lbl)

	passives_hbox = passives_container.get_node_or_null("PassivesHBox") as HBoxContainer
	if passives_hbox == null:
		passives_hbox = HBoxContainer.new()
		passives_hbox.name = "PassivesHBox"
		passives_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		passives_hbox.add_theme_constant_override("separation", 10)
		passives_container.add_child(passives_hbox)

	if passive_slots.is_empty():
		for child in passives_hbox.get_children():
			if child is PanelContainer:
				var idx: int = passive_slots.size()
				if not child.gui_input.is_connected(_on_passive_gui_input.bind(idx)):
					child.gui_input.connect(_on_passive_gui_input.bind(idx))
				passive_slots.append(child)

		while passive_slots.size() < 5:
			var slot_idx: int = passive_slots.size()
			var slot_panel := _create_passive_slot_panel(slot_idx)
			passives_hbox.add_child(slot_panel)
			passive_slots.append(slot_panel)

	# 3. Flexible Top Spacer: Expands to make tracks, description & buttons bottom-aligned
	spacer = vbox.get_node_or_null("TopSpacer") as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = "TopSpacer"
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(spacer)

	# 4. Loadout Tracks Section (5 rows, bottom-aligned above description)
	tracks_box = vbox.get_node_or_null("TracksBox") as VBoxContainer
	if tracks_box == null:
		tracks_box = VBoxContainer.new()
		tracks_box.name = "TracksBox"
		tracks_box.add_theme_constant_override("separation", 4)
		vbox.add_child(tracks_box)

	if track_rows.is_empty():
		for child in tracks_box.get_children():
			var r := child as InventoryOverlayTrackRow
			if r != null:
				if not r.slot_clicked.is_connected(_on_slot_clicked):
					r.slot_clicked.connect(_on_slot_clicked)
				if not r.equipment_dropped.is_connected(_on_equipment_dropped):
					r.equipment_dropped.connect(_on_equipment_dropped)
				track_rows.append(r)

		while track_rows.size() < 5:
			var i: int = track_rows.size()
			var row: InventoryOverlayTrackRow = null
			if TRACK_ROW_SCENE != null:
				row = TRACK_ROW_SCENE.instantiate() as InventoryOverlayTrackRow
			if row == null:
				row = InventoryOverlayTrackRow.new()
			row.name = "TrackRow_%d" % i
			row.slot_clicked.connect(_on_slot_clicked)
			row.equipment_dropped.connect(_on_equipment_dropped)
			tracks_box.add_child(row)
			track_rows.append(row)

	# 5. Ability Description Field
	description_panel = vbox.get_node_or_null("DescriptionPanel") as NinePatchRect
	if description_panel == null:
		description_panel = NinePatchRect.new()
		description_panel.name = "DescriptionPanel"
		description_panel.texture = TEX_DESC_PANEL
		description_panel.patch_margin_left = 4
		description_panel.patch_margin_top = 4
		description_panel.patch_margin_right = 4
		description_panel.patch_margin_bottom = 4
		description_panel.custom_minimum_size = Vector2(520, description_panel_height)
		description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(description_panel)

		var d_margin := MarginContainer.new()
		d_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		d_margin.add_theme_constant_override("margin_left", 14)
		d_margin.add_theme_constant_override("margin_top", 10)
		d_margin.add_theme_constant_override("margin_right", 14)
		d_margin.add_theme_constant_override("margin_bottom", 10)
		description_panel.add_child(d_margin)

		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		d_margin.add_child(scroll)

		description_label = RichTextLabel.new()
		description_label.name = "DescriptionLabel"
		description_label.bbcode_enabled = true
		description_label.fit_content = true
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description_label.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll.add_child(description_label)
	else:
		description_label = description_panel.find_child("DescriptionLabel", true, false) as RichTextLabel

	# 6. Bottom Navigation Row (Loadout button)
	bottom_nav_box = vbox.get_node_or_null("BottomNavBox") as HBoxContainer
	if bottom_nav_box == null:
		bottom_nav_box = HBoxContainer.new()
		bottom_nav_box.name = "BottomNavBox"
		bottom_nav_box.custom_minimum_size = Vector2(520, 48)
		bottom_nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_nav_box.add_theme_constant_override("separation", 8)
		vbox.add_child(bottom_nav_box)

	loadout_nav_btn = bottom_nav_box.get_node_or_null("NavBtn_Loadout") as Button
	if loadout_nav_btn == null:
		# Check if older NavBtn_Inventory exists to reuse
		var old_btn := bottom_nav_box.get_node_or_null("NavBtn_Inventory") as Button
		if old_btn != null:
			loadout_nav_btn = old_btn
			loadout_nav_btn.name = "NavBtn_Loadout"
			loadout_nav_btn.text = "Loadout"
		else:
			loadout_nav_btn = _create_nav_button("Loadout")
			loadout_nav_btn.name = "NavBtn_Loadout"
			bottom_nav_box.add_child(loadout_nav_btn)
	else:
		loadout_nav_btn.text = "Loadout"

	if not loadout_nav_btn.pressed.is_connected(_on_loadout_nav_pressed):
		loadout_nav_btn.pressed.connect(_on_loadout_nav_pressed)

func _create_passive_slot_panel(slot_idx: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.name = "PassiveSlot_%d" % slot_idx
	pc.custom_minimum_size = Vector2(46, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.20, 0.27, 0.45)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.48, 0.42, 0.52, 0.6)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	pc.add_theme_stylebox_override("panel", sb)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(icon_rect)

	pc.gui_input.connect(_on_passive_gui_input.bind(slot_idx))
	return pc

func _create_nav_button(btn_text: String) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(100, 44)

	var sb_normal := StyleBoxTexture.new()
	sb_normal.texture = TEX_GENERAL_BTN
	sb_normal.texture_margin_left = 4
	sb_normal.texture_margin_top = 4
	sb_normal.texture_margin_right = 4
	sb_normal.texture_margin_bottom = 4
	sb_normal.content_margin_left = 10
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_right = 10
	sb_normal.content_margin_bottom = 6

	var sb_hover := sb_normal.duplicate() as StyleBoxTexture
	sb_hover.modulate_color = Color(1.12, 1.12, 1.12, 1.0)

	var sb_pressed := sb_normal.duplicate() as StyleBoxTexture
	sb_pressed.modulate_color = Color(0.85, 0.85, 0.85, 1.0)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#2e2633"))
	btn.add_theme_color_override("font_hover_color", Color("#17121b"))
	btn.add_theme_color_override("font_pressed_color", Color("#100c14"))
	return btn

## Refreshes all 5 loadout tracks, passives, and description from Global.cur_char.
func refresh_overlay_data() -> void:
	_build_ui_if_needed()
	if Global.cur_char == null:
		_show_empty_description()
		return

	Global.cur_char.ensure_loadout_tracks()
	var current_pool: Array[int] = Global.cur_char.active_color_pool
	if current_pool.is_empty():
		current_pool = [100, 200, 300, 500]

	# 1. Update 5 Track Rows
	for slot_idx in range(track_rows.size()):
		var row: InventoryOverlayTrackRow = track_rows[slot_idx]
		if slot_idx < current_pool.size():
			var c_id: int = current_pool[slot_idx]
			var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
			row.setup_row(c_id, track)
		else:
			row.setup_row(0, null)

	# 2. Update Passives
	var passives := Global.cur_char.equipped_passives
	for i in range(passive_slots.size()):
		var slot_pc: PanelContainer = passive_slots[i]
		var icon: TextureRect = slot_pc.get_node_or_null("Icon")
		if i < passives.size() and passives[i] != null:
			var p_mod: Equipment = passives[i] as Equipment
			if icon != null and p_mod != null:
				icon.texture = p_mod.icon
				icon.visible = true
		else:
			if icon != null:
				icon.texture = null
				icon.visible = false

	# 3. Update Selection & Description
	if selected_ability != null:
		_display_ability_description(selected_ability, selected_track.color if selected_track != null else 0, selected_is_ult)
	else:
		_show_empty_description()

func _on_slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ult: bool, slot_idx: int) -> void:
	selected_ability = mod
	selected_track = track
	selected_is_ult = is_ult
	selected_slot_idx = slot_idx

	# Update selection highlight across all rows
	for row in track_rows:
		var is_same: bool = (row.track_ref == track)
		row.update_selection(mod, is_ult, slot_idx, is_same)

	if mod != null:
		_display_ability_description(mod, track.color if track != null else 0, is_ult)
		ability_selected.emit(mod, track, is_ult, slot_idx)
	else:
		_show_slot_empty_description(track, is_ult)

## Handles moving, swapping, and reordering equipment via drag-and-drop.
func _on_equipment_dropped(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int) -> void:
	if Global.cur_char == null or target_track == null:
		return

	var source_mod: Equipment = drag_data.get("modifier") as Equipment
	var source_track: ColorLoadoutTrack = drag_data.get("source_track") as ColorLoadoutTrack
	var source_is_ult: bool = drag_data.get("source_is_ult", false)

	if source_mod == null or source_track == null:
		return

	# Type mismatch check: ultimate must match ultimate slot
	if source_is_ult != target_is_ult:
		return

	# Color compatibility check
	if not target_track.is_color_compatible(source_mod):
		return

	if target_is_ult:
		# Ultimate Drag-and-Drop:
		if source_track == target_track:
			return
		var existing_target_ult: Equipment = target_track.ultimate_skill
		if existing_target_ult != null:
			if source_track.is_color_compatible(existing_target_ult):
				source_track.ultimate_skill = existing_target_ult
				target_track.ultimate_skill = source_mod
			else:
				source_track.unequip_ultimate()
				target_track.equip_ultimate(source_mod)
		else:
			source_track.unequip_ultimate()
			target_track.equip_ultimate(source_mod)
	else:
		# Basic Ability Drag-and-Drop:
		if source_track == target_track:
			# Reordering within the SAME track
			var s_idx: int = source_track.equipped_modifiers.find(source_mod)
			if s_idx != -1:
				var target_mod: Equipment = target_track.get_modifier_at_slot_index(target_slot_idx) if target_slot_idx >= 0 else null
				if target_mod != null and target_mod != source_mod:
					var t_idx: int = target_track.equipped_modifiers.find(target_mod)
					if t_idx != -1:
						target_track.equipped_modifiers[s_idx] = target_mod
						target_track.equipped_modifiers[t_idx] = source_mod
				elif target_mod == null:
					source_track.equipped_modifiers.remove_at(s_idx)
					source_track.equipped_modifiers.append(source_mod)
		else:
			# Moving or swapping BETWEEN DIFFERENT tracks
			var target_mod: Equipment = target_track.get_modifier_at_slot_index(target_slot_idx) if target_slot_idx >= 0 else null
			if target_mod != null:
				# Swapping two abilities between tracks
				if source_track.is_color_compatible(target_mod):
					var s_idx: int = source_track.equipped_modifiers.find(source_mod)
					var t_idx: int = target_track.equipped_modifiers.find(target_mod)
					if s_idx != -1 and t_idx != -1:
						var free_in_target: int = target_track.get_free_slots() + target_mod.slot_cost
						var free_in_source: int = source_track.get_free_slots() + source_mod.slot_cost
						if free_in_target >= source_mod.slot_cost and free_in_source >= target_mod.slot_cost:
							source_track.equipped_modifiers.remove_at(s_idx)
							target_track.equipped_modifiers.remove_at(t_idx)
							source_track.equip_modifier(target_mod, s_idx)
							target_track.equip_modifier(source_mod, t_idx)
			else:
				# Moving into empty space on target track
				if target_track.get_free_slots() >= source_mod.slot_cost:
					source_track.unequip_modifier(source_mod)
					target_track.equip_modifier(source_mod)

	source_track.clamp_cursor()
	target_track.clamp_cursor()
	source_track.check_ultimate_ready_at_cycle_start()
	target_track.check_ultimate_ready_at_cycle_start()

	if Global.cur_char != null:
		Global.cur_char.loadoutChanged.emit()

	refresh_overlay_data()
	_on_slot_clicked(source_mod, target_track, target_is_ult, target_slot_idx)

func _on_passive_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Global.cur_char == null:
			return
		var passives := Global.cur_char.equipped_passives
		var p_mod: Equipment = passives[slot_idx] as Equipment if slot_idx < passives.size() else null
		# Clear track highlights
		for row in track_rows:
			row.update_selection(null, false, -2, false)
		if p_mod != null:
			selected_ability = p_mod
			selected_track = null
			selected_is_ult = false
			selected_slot_idx = slot_idx
			_display_ability_description(p_mod, 0, false)
		else:
			_show_slot_empty_description(null, false)

func _display_ability_description(mod: Equipment, color_id: int, is_ult: bool) -> void:
	if description_label == null:
		return
	description_label.text = _format_ability_bbcode(mod, color_id, is_ult)

func _show_empty_description() -> void:
	if description_label == null:
		return
	description_label.text = "[center][color=#9babb2]\nSelect an ability or passive to view its details.[/color][/center]"

func _show_slot_empty_description(track: ColorLoadoutTrack, is_ult: bool) -> void:
	if description_label == null:
		return
	var c_name := ColorLoadoutTrack.get_color_name(track.color) if track != null else "Passive"
	var type_str := "Ultimate Slot" if is_ult else "Slot"
	description_label.text = "[center][color=#9babb2]\nEmpty %s %s\nEquip abilities by acquiring them during your run.[/color][/center]" % [c_name, type_str]

func _format_ability_bbcode(mod: Equipment, color_id: int, is_ult: bool) -> String:
	if mod == null:
		return ""

	var r_color := Equipment.get_rarity_hex(mod.rarity)
	var r_name := Equipment.get_rarity_name(mod.rarity)
	var c_name := ColorLoadoutTrack.get_color_name(color_id) if color_id > 0 else "Wild"

	var text := ""
	# Title
	text += "[font_size=20][b][color=%s]%s[/color][/b][/font_size]\n" % [r_color, mod.piece_name]

	# Subtitle
	var type_str := "Ultimate" if (is_ult or mod.is_ultimate) else ("%d Slot%s" % [mod.slot_cost, "" if mod.slot_cost == 1 else "s"])
	var color_tag := "%s Track" % c_name if color_id > 0 else "Wild / Any Track"
	text += "[font_size=12][color=#c7dcd0]%s  •  %s  •  %s[/color][/font_size]\n\n" % [r_name, type_str, color_tag]

	# Trigger condition (if basic ability)
	if not is_ult and not mod.is_ultimate:
		var trig_desc := _get_trigger_description(mod.trigger_condition)
		text += "[font_size=13][color=#f9c22b]Trigger:[/color] [color=#ffffff]%s[/color][/font_size]\n" % trig_desc

	# Effect text
	var eff := mod.get_effect_description()
	if not eff.is_empty():
		text += "[font_size=14]%s[/font_size]\n" % eff

	# Passive stats from tier (if any)
	var tier := mod.get_active_tier()
	if tier != null and not tier.stat_modifiers.is_empty():
		var stat_parts: Array[String] = []
		for stat_name in tier.stat_modifiers:
			var val: int = int(tier.stat_modifiers[stat_name])
			var sign_str := "+" if val > 0 else ""
			stat_parts.append("%s%d %s" % [sign_str, val, stat_name.capitalize()])
		if not stat_parts.is_empty():
			text += "\n[font_size=12][color=#91db69]Passive Stats: %s[/color][/font_size]" % ", ".join(stat_parts)

	return text

func _get_trigger_description(tc: Equipment.TriggerCondition) -> String:
	match tc:
		Equipment.TriggerCondition.ALWAYS: return "Any Match"
		Equipment.TriggerCondition.MATCH_4_PLUS: return "4+ Tile Match"
		Equipment.TriggerCondition.SHAPE_L_OR_T: return "L or T Shape Match"
		Equipment.TriggerCondition.BOTTOM_HALF_GRID: return "Bottom Half of Board"
		Equipment.TriggerCondition.HIGH_MOMENTUM: return "3+ Space Fall"
		Equipment.TriggerCondition.SECOND_MATCH_IN_TURN: return "2nd Match In Turn"
		Equipment.TriggerCondition.THIRD_MATCH_IN_TURN: return "3rd Match In Turn"
		Equipment.TriggerCondition.EXOTIC_INFUSED: return "Exotic Tile Infused"
		Equipment.TriggerCondition.HAZARD_INTERACTION: return "Clears Hazard"
	return "Any Match"

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()

func _on_loadout_nav_pressed() -> void:
	close()
