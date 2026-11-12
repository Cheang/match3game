class_name InventoryOverlay
extends CanvasLayer

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
signal slotting_completed
signal ability_selected(mod: Equipment, track: ColorLoadoutTrack, is_ultimate: bool, slot_idx: int)

static var instance: InventoryOverlay = null

const TEX_OVERLAY_BG = preload("res://assets/sprites/ui/combat/inventory_btn_unpressed.png")
const TEX_DESC_PANEL = preload("res://assets/sprites/ui/inventory_overlay/ability_description_panel.png")
const TEX_GENERAL_BTN = preload("res://assets/sprites/ui/general_button_unpressed.png")
const TRACK_ROW_SCENE = preload("res://ui/inventory_overlay/inventory_overlay_track_row.tscn")
const PASSIVES_RING_SCENE = preload("res://ui/inventory_overlay/inventory_overlay_passives_ring.tscn")
const TITLE_FONT = preload("res://assets/theme/title.ttf")

@export var description_panel_height: float = 160.0:
	set(val):
		description_panel_height = val
		if description_panel != null:
			description_panel.custom_minimum_size.y = val

@export var header_title: String = "Loadout":
	set(val):
		header_title = val
		if header_label != null:
			header_label.text = val

enum Tab { LOADOUT, STATS, SETTINGS }
var current_tab: Tab = Tab.LOADOUT

var dimmer: ColorRect
var main_panel: NinePatchRect
var header_label: Label

var loadout_view: VBoxContainer
var passives_ring: InventoryOverlayPassivesRing = null
var spacer: Control
var tracks_box: VBoxContainer
var track_rows: Array[InventoryOverlayTrackRow] = []
var description_panel: NinePatchRect
var description_label: RichTextLabel

var stats_view: Control

var settings_view: Control
var settings_vbox: VBoxContainer
var almanac_btn: Button
var sound_btn: Button
var graphics_btn: Button
var main_menu_btn: Button

var bottom_nav_box: HBoxContainer
var loadout_nav_btn: Button
var stats_nav_btn: Button
var settings_nav_btn: Button
var done_btn: Button

var is_slotting_mode: bool = false
var pending_slotting_queue: Array[Equipment] = []
var floating_shard_dock: FloatingShardDock = null
var _cached_floating_equipment: Equipment = null

var selected_ability: Equipment = null
var selected_track: ColorLoadoutTrack = null
var selected_is_ult: bool = false
var selected_slot_idx: int = -2

var selected_passive: Resource = null
var selected_passive_idx: int = -1

var _saved_game_is_played: bool = true

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	instance = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_if_needed()
	visible = false

static func _get_active_instance() -> InventoryOverlay:
	if instance != null and is_instance_valid(instance) and instance.is_inside_tree() and not instance.is_queued_for_deletion():
		return instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var search_roots: Array[Node] = []
		if tree.current_scene != null:
			search_roots.append(tree.current_scene)
		if tree.root != null and not search_roots.has(tree.root):
			search_roots.append(tree.root)
		for root_node in search_roots:
			for child in root_node.find_children("*", "InventoryOverlay", true, false):
				if child is InventoryOverlay and not child.is_queued_for_deletion():
					instance = child
					return instance
			var by_snake := root_node.find_child("inventory_overlay", true, false) as InventoryOverlay
			if by_snake != null and not by_snake.is_queued_for_deletion():
				instance = by_snake
				return instance
			var by_pascal := root_node.find_child("InventoryOverlay", true, false) as InventoryOverlay
			if by_pascal != null and not by_pascal.is_queued_for_deletion():
				instance = by_pascal
				return instance
	return null

static func is_overlay_open() -> bool:
	var active := _get_active_instance()
	return active != null and active.visible

static func toggle_overlay() -> void:
	var active := _get_active_instance()
	if active != null:
		active.toggle()

static func open_overlay() -> void:
	var active := _get_active_instance()
	if active != null:
		active.open()

static func close_overlay() -> void:
	var active := _get_active_instance()
	if active != null:
		active.close()

## Finds active instance or instantiates inventory_overlay.tscn under parent/root.
static func get_or_create(parent: Node = null) -> InventoryOverlay:
	var active := _get_active_instance()
	if active != null:
		return active
	var tree := Engine.get_main_loop() as SceneTree
	var p: Node = parent
	if p == null and tree != null:
		p = tree.current_scene if tree.current_scene != null else tree.root
	var overlay_scene: PackedScene = preload("res://ui/inventory_overlay/inventory_overlay.tscn")
	var overlay: InventoryOverlay = overlay_scene.instantiate() as InventoryOverlay
	if p != null:
		p.add_child(overlay)
	return overlay

## Interactive slotting session for newly acquired equipment rewards.
## Displays the floating diamond shard with fire particles at the bottom and a single Done button.
## Suspends execution via await until the player finishes moving shards and clicks Done.
func prompt_slotting(equipment_list: Array) -> void:
	var typed_list: Array[Equipment] = []
	for item in equipment_list:
		if item is Equipment:
			typed_list.append(item)
	if typed_list.is_empty():
		return
	_build_ui_if_needed()
	start_slotting_mode(typed_list)
	await slotting_completed

func start_slotting_mode(equipment_list: Array) -> void:
	_build_ui_if_needed()
	is_slotting_mode = true
	pending_slotting_queue.clear()
	for item in equipment_list:
		if item is Equipment:
			pending_slotting_queue.append(item)
	var first_eq: Equipment = pending_slotting_queue.pop_front() if not pending_slotting_queue.is_empty() else null
	_update_slotting_mode_ui(true)
	open()
	set_floating_equipment(first_eq)

func set_floating_equipment(eq: Equipment) -> void:
	_cached_floating_equipment = eq
	if floating_shard_dock != null:
		floating_shard_dock.set_equipment(eq)
	for row in track_rows:
		if row != null:
			row.set_compatibility_state(eq)
	if eq != null:
		_display_ability_description(eq, _get_equipment_color(eq), eq.is_ultimate)
	else:
		_show_empty_description()

func _update_slotting_mode_ui(slotting_active: bool) -> void:
	_build_ui_if_needed()
	is_slotting_mode = slotting_active
	if header_label != null:
		header_label.text = "Equip Shard" if slotting_active else header_title
	if floating_shard_dock != null:
		floating_shard_dock.visible = slotting_active
	if description_panel != null:
		description_panel.custom_minimum_size.y = 80.0 if slotting_active else description_panel_height
	if done_btn != null:
		done_btn.visible = slotting_active
	if loadout_nav_btn != null:
		loadout_nav_btn.visible = not slotting_active
	if stats_nav_btn != null:
		stats_nav_btn.visible = not slotting_active
	if settings_nav_btn != null:
		settings_nav_btn.visible = not slotting_active

func _get_equipment_color(eq: Equipment) -> int:
	if eq == null or eq.is_colorless():
		return 100
	var eff: Array[int] = eq.get_effective_allowed_colors()
	return eff[0] if not eff.is_empty() else 100

func open() -> void:
	if Global.game_is_over:
		return
	_saved_game_is_played = Global.game_is_played
	Global.game_is_played = false

	_build_ui_if_needed()
	switch_tab(Tab.LOADOUT)
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
	if is_slotting_mode:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I):
			_on_done_btn_pressed()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif not Global.game_is_over:
			open()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			if visible:
				close()
				get_viewport().set_input_as_handled()
			elif not Global.game_is_over:
				open()
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
		main_panel.custom_minimum_size = Vector2(548, 970)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(main_panel)

	var margin := main_panel.get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_PASS
		main_panel.add_child(margin)

	var vbox := margin.get_node_or_null("ContentVBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "ContentVBox"
		vbox.add_theme_constant_override("separation", 6)
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		margin.add_child(vbox)

	# Optional Header Label (only configured if present in scene)
	header_label = vbox.find_child("HeaderLabel", true, false) as Label
	if header_label != null:
		header_label.text = header_title
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_label.add_theme_font_override("font", TITLE_FONT)
		header_label.add_theme_font_size_override("font_size", 28)
		header_label.add_theme_color_override("font_color", Color("#2e2633"))

	# 2. Views Container or Direct Views in ContentVBox
	loadout_view = vbox.find_child("LoadoutView", true, false) as VBoxContainer
	if loadout_view == null:
		loadout_view = VBoxContainer.new()
		loadout_view.name = "LoadoutView"
		loadout_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		loadout_view.add_theme_constant_override("separation", 8)
		vbox.add_child(loadout_view)

	# Passives Ring Section (342x313 pentagonal ring)
	passives_ring = vbox.find_child("PassivesRing", true, false) as InventoryOverlayPassivesRing
	if passives_ring == null:
		if PASSIVES_RING_SCENE != null:
			passives_ring = PASSIVES_RING_SCENE.instantiate() as InventoryOverlayPassivesRing
		if passives_ring == null:
			passives_ring = InventoryOverlayPassivesRing.new()
		passives_ring.name = "PassivesRing"
		passives_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		loadout_view.add_child(passives_ring)
	elif passives_ring.get_parent() != loadout_view and loadout_view != null:
		passives_ring.reparent(loadout_view)

	if not passives_ring.passive_clicked.is_connected(_on_passive_clicked):
		passives_ring.passive_clicked.connect(_on_passive_clicked)
	if not passives_ring.passive_dropped.is_connected(_on_passive_dropped):
		passives_ring.passive_dropped.connect(_on_passive_dropped)

	# Optional spacer (hidden/disabled if passives ring is present)
	spacer = vbox.find_child("TopSpacer", true, false) as Control
	if spacer != null:
		spacer.visible = false
		spacer.size_flags_vertical = 0

	# Loadout Tracks Section (5 rows)
	tracks_box = vbox.find_child("TracksBox", true, false) as VBoxContainer
	if tracks_box == null:
		tracks_box = VBoxContainer.new()
		tracks_box.name = "TracksBox"
		tracks_box.add_theme_constant_override("separation", 4)
		loadout_view.add_child(tracks_box)
	elif tracks_box.get_parent() != loadout_view and loadout_view != null:
		tracks_box.reparent(loadout_view)

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

	# Ability Description Field
	description_panel = vbox.find_child("DescriptionPanel", true, false) as NinePatchRect
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
		loadout_view.add_child(description_panel)

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
		if description_panel.get_parent() != loadout_view and loadout_view != null:
			description_panel.reparent(loadout_view)

	# Floating Shard Dock (Slotting Mode only, below DescriptionPanel in LoadoutView)
	floating_shard_dock = loadout_view.find_child("FloatingShardDock", true, false) as FloatingShardDock
	if floating_shard_dock == null:
		floating_shard_dock = FloatingShardDock.new()
		floating_shard_dock.name = "FloatingShardDock"
		loadout_view.add_child(floating_shard_dock)
	floating_shard_dock.visible = is_slotting_mode
	if not floating_shard_dock.shard_selected.is_connected(_on_floating_shard_selected):
		floating_shard_dock.shard_selected.connect(_on_floating_shard_selected)
	if not floating_shard_dock.shard_dropped_on_dock.is_connected(_on_shard_dropped_to_dock):
		floating_shard_dock.shard_dropped_on_dock.connect(_on_shard_dropped_to_dock)

	# 3. Stats View (empty placeholder for future design)
	stats_view = vbox.find_child("StatsView", true, false) as Control
	if stats_view == null:
		stats_view = Control.new()
		stats_view.name = "StatsView"
		stats_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_view.visible = false
		vbox.add_child(stats_view)

	# 4. Settings View (CenterContainer with 4 buttons)
	settings_view = vbox.find_child("SettingsView", true, false) as Control
	if settings_view == null:
		settings_view = CenterContainer.new()
		settings_view.name = "SettingsView"
		settings_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		settings_view.visible = false
		vbox.add_child(settings_view)

	settings_vbox = settings_view.find_child("SettingsVBox", true, false) as VBoxContainer
	if settings_vbox == null:
		settings_vbox = VBoxContainer.new()
		settings_vbox.name = "SettingsVBox"
		settings_vbox.custom_minimum_size = Vector2(280, 0)
		settings_vbox.add_theme_constant_override("separation", 14)
		settings_view.add_child(settings_vbox)

	almanac_btn = settings_vbox.find_child("AlmanacBtn", true, false) as Button
	if almanac_btn == null:
		almanac_btn = _create_nav_button("Almanac", true)
		almanac_btn.name = "AlmanacBtn"
		almanac_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(almanac_btn)

	sound_btn = settings_vbox.find_child("SoundBtn", true, false) as Button
	if sound_btn == null:
		sound_btn = _create_nav_button("Sound", true)
		sound_btn.name = "SoundBtn"
		sound_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(sound_btn)

	graphics_btn = settings_vbox.find_child("GraphicsBtn", true, false) as Button
	if graphics_btn == null:
		graphics_btn = _create_nav_button("Graphics", true)
		graphics_btn.name = "GraphicsBtn"
		graphics_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(graphics_btn)

	main_menu_btn = settings_vbox.find_child("MainMenuBtn", true, false) as Button
	if main_menu_btn == null:
		main_menu_btn = _create_nav_button("Main Menu", false)
		main_menu_btn.name = "MainMenuBtn"
		main_menu_btn.custom_minimum_size = Vector2(280, 48)
		settings_vbox.add_child(main_menu_btn)

	if not main_menu_btn.pressed.is_connected(_on_main_menu_pressed):
		main_menu_btn.pressed.connect(_on_main_menu_pressed)

	# 5. Bottom Navigation Row (Loadout, Stats, Settings)
	bottom_nav_box = vbox.find_child("BottomNavBox", true, false) as HBoxContainer
	if bottom_nav_box == null:
		bottom_nav_box = HBoxContainer.new()
		bottom_nav_box.name = "BottomNavBox"
		bottom_nav_box.custom_minimum_size = Vector2(520, 44)
		bottom_nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_nav_box.add_theme_constant_override("separation", 8)
		vbox.add_child(bottom_nav_box)

	# 5a. Stats Nav Button (Left: index 0)
	stats_nav_btn = bottom_nav_box.find_child("NavBtn_Stats", true, false) as Button
	if stats_nav_btn == null:
		stats_nav_btn = _create_nav_button("Stats")
		stats_nav_btn.name = "NavBtn_Stats"
		bottom_nav_box.add_child(stats_nav_btn)
	else:
		stats_nav_btn.text = "Stats"
	if not stats_nav_btn.pressed.is_connected(_on_stats_nav_pressed):
		stats_nav_btn.pressed.connect(_on_stats_nav_pressed)

	# 5b. Loadout Nav Button (Middle: index 1)
	loadout_nav_btn = bottom_nav_box.find_child("NavBtn_Loadout", true, false) as Button
	if loadout_nav_btn == null:
		var old_btn := bottom_nav_box.find_child("NavBtn_Inventory", true, false) as Button
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

	# 5c. Settings Nav Button (Right: index 2)
	settings_nav_btn = bottom_nav_box.find_child("NavBtn_Settings", true, false) as Button
	if settings_nav_btn == null:
		settings_nav_btn = _create_nav_button("Settings")
		settings_nav_btn.name = "NavBtn_Settings"
		bottom_nav_box.add_child(settings_nav_btn)
	else:
		settings_nav_btn.text = "Settings"
	if not settings_nav_btn.pressed.is_connected(_on_settings_nav_pressed):
		settings_nav_btn.pressed.connect(_on_settings_nav_pressed)

	# Explicitly ensure child order: 0 = Loadout, 1 = Stats, 2 = Settings
	bottom_nav_box.move_child(loadout_nav_btn, 0)
	bottom_nav_box.move_child(stats_nav_btn, 1)
	bottom_nav_box.move_child(settings_nav_btn, 2)

	# 5d. Done Nav Button (Slotting Mode only)
	done_btn = bottom_nav_box.find_child("NavBtn_Done", true, false) as Button
	if done_btn == null:
		done_btn = _create_nav_button("Done")
		done_btn.name = "NavBtn_Done"
		bottom_nav_box.add_child(done_btn)
	else:
		done_btn.text = "Done"
	done_btn.visible = is_slotting_mode
	if not done_btn.pressed.is_connected(_on_done_btn_pressed):
		done_btn.pressed.connect(_on_done_btn_pressed)

func _create_nav_button(btn_text: String, is_disabled: bool = false) -> Button:
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

	var sb_disabled := sb_normal.duplicate() as StyleBoxTexture
	sb_disabled.modulate_color = Color(0.65, 0.65, 0.65, 0.7)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#2e2633"))
	btn.add_theme_color_override("font_hover_color", Color("#17121b"))
	btn.add_theme_color_override("font_pressed_color", Color("#100c14"))
	btn.add_theme_color_override("font_disabled_color", Color(0.44, 0.38, 0.46, 0.8))
	btn.disabled = is_disabled
	return btn

## Switches the visible tab view between Loadout, Stats, and Settings.
func switch_tab(tab: Tab) -> void:
	current_tab = tab
	_build_ui_if_needed()

	if loadout_view != null:
		loadout_view.visible = (tab == Tab.LOADOUT)
	if stats_view != null:
		stats_view.visible = (tab == Tab.STATS)
	if settings_view != null:
		settings_view.visible = (tab == Tab.SETTINGS)

	match tab:
		Tab.LOADOUT:
			if header_label != null:
				header_label.text = "Loadout"
			_update_nav_button_highlights(loadout_nav_btn)
			refresh_overlay_data()
		Tab.STATS:
			if header_label != null:
				header_label.text = "Stats"
			_update_nav_button_highlights(stats_nav_btn)
		Tab.SETTINGS:
			if header_label != null:
				header_label.text = "Settings"
			_update_nav_button_highlights(settings_nav_btn)

func _update_nav_button_highlights(active_btn: Button) -> void:
	for btn in [loadout_nav_btn, stats_nav_btn, settings_nav_btn]:
		if btn == null:
			continue
		if btn == active_btn:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.modulate = Color(0.72, 0.72, 0.78, 0.85)

func _on_loadout_nav_pressed() -> void:
	if current_tab == Tab.LOADOUT and visible:
		close()
		return
	switch_tab(Tab.LOADOUT)

func _on_stats_nav_pressed() -> void:
	if current_tab == Tab.STATS and visible:
		close()
		return
	switch_tab(Tab.STATS)

func _on_settings_nav_pressed() -> void:
	if current_tab == Tab.SETTINGS and visible:
		close()
		return
	switch_tab(Tab.SETTINGS)

func _on_main_menu_pressed() -> void:
	close()
	Global.game_is_played = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		tree = get_tree()
	if tree != null:
		var sm = tree.root.get_node_or_null("SceneManager")
		if sm != null and sm.has_method("change_scene"):
			sm.change_scene("res://ui/screens/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })
		else:
			tree.change_scene_to_file("res://ui/screens/main_menu.tscn")

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

	if is_slotting_mode:
		for row in track_rows:
			row.set_compatibility_state(_cached_floating_equipment)

	# 2. Update Passives Ring
	var passives: Array = Global.cur_char.equipped_passives if Global.cur_char != null else []
	if passives_ring != null:
		passives_ring.setup_passives(passives)
		if selected_passive_idx >= 0:
			passives_ring.update_selection(selected_passive_idx)
		else:
			passives_ring.update_selection(-1)

	# 3. Update Selection & Description
	if selected_ability != null:
		_display_ability_description(selected_ability, selected_track.color if selected_track != null else 0, selected_is_ult)
	elif selected_passive != null:
		_display_passive_description(selected_passive)
	elif selected_passive_idx >= 0:
		_show_passive_empty_description()
	else:
		_show_empty_description()

func _on_slot_clicked(mod: Equipment, track: ColorLoadoutTrack, is_ult: bool, slot_idx: int) -> void:
	selected_passive = null
	selected_passive_idx = -1
	if passives_ring != null:
		passives_ring.update_selection(-1)

	selected_ability = mod
	selected_track = track
	selected_is_ult = is_ult
	selected_slot_idx = slot_idx

	# Update selection highlight across all rows
	for row in track_rows:
		var is_same_track: bool = (row.track_ref == track)
		row.update_selection(mod, is_ult, slot_idx, is_same_track)

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
	var source_is_floating: bool = drag_data.get("source_is_floating", false)

	if source_is_floating:
		_handle_floating_shard_drop(source_mod, target_track, target_is_ult, target_slot_idx)
		return

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

func _handle_floating_shard_drop(source_mod: Equipment, target_track: ColorLoadoutTrack, target_is_ult: bool, target_slot_idx: int) -> void:
	if target_track == null or source_mod == null:
		return
	if not target_track.is_color_compatible(source_mod):
		return

	var displaced_item: Equipment = null

	if target_is_ult:
		if not source_mod.is_ultimate:
			return
		displaced_item = target_track.ultimate_skill
		target_track.equip_ultimate(source_mod)
	else:
		if source_mod.is_ultimate:
			return
		var target_mod: Equipment = target_track.get_modifier_at_slot_index(target_slot_idx) if target_slot_idx >= 0 else null
		if target_mod != null:
			# Replacing an occupied slot
			var t_idx: int = target_track.equipped_modifiers.find(target_mod)
			if t_idx != -1:
				displaced_item = target_mod
				target_track.equipped_modifiers.remove_at(t_idx)
				while target_track.get_free_slots() < source_mod.slot_cost and not target_track.equipped_modifiers.is_empty():
					displaced_item = target_track.equipped_modifiers.pop_back()
				target_track.equip_modifier(source_mod, t_idx)
		else:
			# Dropping onto empty slot or row
			if target_track.can_equip(source_mod):
				target_track.equip_modifier(source_mod, target_slot_idx)
			else:
				# Track full or not enough slots: displace from end
				if not target_track.equipped_modifiers.is_empty():
					displaced_item = target_track.equipped_modifiers.pop_back()
				while not target_track.can_equip(source_mod) and not target_track.equipped_modifiers.is_empty():
					displaced_item = target_track.equipped_modifiers.pop_back()
				target_track.equip_modifier(source_mod)

	# Displaced item becomes the new floating shard so the player can keep moving shards
	if displaced_item != null:
		set_floating_equipment(displaced_item)
	else:
		if not pending_slotting_queue.is_empty():
			set_floating_equipment(pending_slotting_queue.pop_front())
		else:
			set_floating_equipment(null)

	target_track.clamp_cursor()
	target_track.check_ultimate_ready_at_cycle_start()
	if Global.cur_char != null:
		Global.cur_char.recalculate_equipment_passives()
		Global.cur_char.loadoutChanged.emit()

	refresh_overlay_data()
	_on_slot_clicked(source_mod, target_track, target_is_ult, target_slot_idx)

func _on_shard_dropped_to_dock(drag_data: Dictionary) -> void:
	if not is_slotting_mode:
		return
	var source_mod: Equipment = drag_data.get("modifier") as Equipment
	var source_track: ColorLoadoutTrack = drag_data.get("source_track") as ColorLoadoutTrack
	var source_is_ult: bool = drag_data.get("source_is_ult", false)
	if source_mod == null or source_track == null:
		return

	var old_floating: Equipment = _cached_floating_equipment
	if old_floating == null:
		if source_is_ult:
			source_track.unequip_ultimate()
		else:
			source_track.unequip_modifier(source_mod)
		set_floating_equipment(source_mod)
	else:
		if source_track.is_color_compatible(old_floating) and source_is_ult == old_floating.is_ultimate:
			if source_is_ult:
				source_track.equip_ultimate(old_floating)
				set_floating_equipment(source_mod)
			else:
				var s_idx: int = source_track.equipped_modifiers.find(source_mod)
				if s_idx != -1:
					source_track.equipped_modifiers.remove_at(s_idx)
					if source_track.get_free_slots() >= old_floating.slot_cost:
						source_track.equip_modifier(old_floating, s_idx)
						set_floating_equipment(source_mod)
					else:
						source_track.equip_modifier(source_mod, s_idx)

	source_track.clamp_cursor()
	source_track.check_ultimate_ready_at_cycle_start()
	if Global.cur_char != null:
		Global.cur_char.recalculate_equipment_passives()
		Global.cur_char.loadoutChanged.emit()
	refresh_overlay_data()

func _on_floating_shard_selected(eq: Equipment) -> void:
	if eq == null:
		_show_empty_description()
		return
	selected_ability = eq
	selected_track = null
	selected_is_ult = eq.is_ultimate
	selected_slot_idx = -2
	for row in track_rows:
		row.update_selection(null, false, -2, false)
	var c_id: int = _get_equipment_color(eq)
	_display_ability_description(eq, c_id, eq.is_ultimate)

func _on_done_btn_pressed() -> void:
	if is_slotting_mode:
		_cached_floating_equipment = null
		pending_slotting_queue.clear()
		if floating_shard_dock != null:
			floating_shard_dock.set_equipment(null)
		for row in track_rows:
			row.set_compatibility_state(null)
		is_slotting_mode = false
		_update_slotting_mode_ui(false)
		close()
		slotting_completed.emit()

func _on_passive_clicked(slot_idx: int, passive_res: Resource) -> void:
	selected_ability = null
	selected_track = null
	selected_is_ult = false
	selected_slot_idx = -2

	# Deselect track highlights across all rows
	for row in track_rows:
		row.update_selection(null, false, -2, false)

	selected_passive_idx = slot_idx
	selected_passive = passive_res

	if passives_ring != null:
		passives_ring.update_selection(slot_idx)

	if passive_res != null:
		_display_passive_description(passive_res)
	else:
		_show_passive_empty_description()

func _on_passive_dropped(source_idx: int, target_idx: int) -> void:
	if Global.cur_char == null:
		return
	var passives: Array = Global.cur_char.equipped_passives
	if source_idx < 0 or source_idx >= passives.size():
		return
	if target_idx < 0 or target_idx >= passives.size():
		return
	if source_idx == target_idx:
		return

	var temp = passives[source_idx]
	passives[source_idx] = passives[target_idx]
	passives[target_idx] = temp

	Global.cur_char.recalculate_passive_bonuses()
	Global.cur_char.passivesChanged.emit()
	Global.cur_char.loadoutChanged.emit()

	refresh_overlay_data()
	_on_passive_clicked(target_idx, passives[target_idx])

func _display_ability_description(mod: Equipment, color_id: int, is_ult: bool) -> void:
	if description_label == null:
		return
	description_label.text = _format_ability_bbcode(mod, color_id, is_ult)

func _display_passive_description(p_res: Resource) -> void:
	if description_label == null:
		return
	description_label.text = _format_passive_bbcode(p_res)

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

func _show_passive_empty_description() -> void:
	if description_label == null:
		return
	description_label.text = "[center][color=#9babb2]\nEmpty Passive Slot\nAcquire passives during your run to fill this slot.[/color][/center]"

func _format_passive_bbcode(p_res: Resource) -> String:
	if p_res == null:
		return ""

	var text := ""
	if p_res is Reward:
		var rew := p_res as Reward
		var r_color := Equipment.get_rarity_hex(int(rew.rarity))
		var r_name := Equipment.get_rarity_name(int(rew.rarity))
		text += "[font_size=20][b][color=%s]%s[/color][/b][/font_size]\n" % [r_color, rew.name]
		text += "[font_size=12][color=#c7dcd0]%s  •  Passive Card[/color][/font_size]\n\n" % r_name
		var eff := rew.get_effect_description()
		if not eff.is_empty():
			text += "[font_size=14]%s[/font_size]\n" % eff
	elif p_res is Equipment:
		var eq := p_res as Equipment
		var r_color := Equipment.get_rarity_hex(eq.rarity)
		var r_name := Equipment.get_rarity_name(eq.rarity)
		text += "[font_size=20][b][color=%s]%s[/color][/b][/font_size]\n" % [r_color, eq.piece_name]
		text += "[font_size=12][color=#c7dcd0]%s  •  Passive Equipment[/color][/font_size]\n\n" % r_name
		var eff := eq.get_effect_description()
		if not eff.is_empty():
			text += "[font_size=14]%s[/font_size]\n" % eff
		var boosts := eq.get_stat_boosts()
		if not boosts.is_empty():
			var stat_parts: Array[String] = []
			for stat_name in boosts:
				var val: float = boosts[stat_name]
				var sign_str := "+" if val > 0 else ""
				stat_parts.append("%s%s %s" % [sign_str, str(int(roundf(val))), stat_name.capitalize()])
			if not stat_parts.is_empty():
				text += "\n[font_size=12][color=#91db69]Passive Stats: %s[/color][/font_size]" % ", ".join(stat_parts)
	else:
		var p_name: String = p_res.get("piece_name") if p_res.get("piece_name") != null else (p_res.get("name") if p_res.get("name") != null else "Passive")
		text += "[font_size=20][b][color=#ffffff]%s[/color][/b][/font_size]\n" % p_name
		text += "[font_size=12][color=#c7dcd0]Passive[/color][/font_size]\n\n"
		var desc: String = p_res.get("description") if p_res.get("description") != null else ""
		if not desc.is_empty():
			text += "[font_size=14]%s[/font_size]\n" % desc
	return text

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

	# Passive stats (if any)
	var boosts := mod.get_stat_boosts()
	if not boosts.is_empty():
		var stat_parts: Array[String] = []
		for stat_name in boosts:
			var val: float = boosts[stat_name]
			var sign_str := "+" if val > 0 else ""
			stat_parts.append("%s%s %s" % [sign_str, str(int(roundf(val))), stat_name.capitalize()])
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
