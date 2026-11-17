extends Control

const MAIN_MENU_SCRIPT := preload("res://ui/screens/main_menu.gd")
const DEFAULT_HERO := preload("res://entities/player/warrior/warrior.tres")
const DEFAULT_AREA: LocationLoader = preload("res://map/areas/area_1.tres")

const CLOTH_VERTICAL_PADDING: float = 64.0
const CLOTH_TILE_HEIGHT: float = 8.0

## Explicit ordered roster for character select. When left empty, all PlayerResource assets under characters_dir are loaded automatically.
@export var available_characters: Array[PlayerResource] = []
## Directory scanned for PlayerResource .tres files when available_characters is empty.
@export_dir var characters_dir: String = "res://entities/player"
## Starting area used when launching a new story run.
@export var def_area: LocationLoader = DEFAULT_AREA

var _roster: Array[PlayerResource] = []
var _current_index: int = 0
var _choice_made: bool = false

@onready var showcase_area: Control = find_child("ShowcaseArea", true, false) as Control
@onready var nameplate_label: Label = find_child("NameLabel", true, false) as Label
@onready var portrait_art: TextureRect = find_child("PortraitArt", true, false) as TextureRect
@onready var placeholder_overlay: Control = find_child("PlaceholderOverlay", true, false) as Control
@onready var prev_hero_btn: Button = find_child("PrevHeroBtn", true, false) as Button
@onready var next_hero_btn: Button = find_child("NextHeroBtn", true, false) as Button

@onready var might_label: Label = find_child("MightValueLabel", true, false) as Label
@onready var grit_label: Label = find_child("GritValueLabel", true, false) as Label
@onready var agility_label: Label = find_child("AgilityValueLabel", true, false) as Label
@onready var spirit_label: Label = find_child("SpiritValueLabel", true, false) as Label

@onready var loadout_center: Control = find_child("LoadoutCenter", true, false) as Control
@onready var loadout_dock: LoadoutDock = find_child("LoadoutDock", true, false) as LoadoutDock

@onready var banner_viewport_container: SubViewportContainer = find_child("BannerViewportContainer", true, false) as SubViewportContainer
@onready var banner_viewport: SubViewport = find_child("BannerViewport", true, false) as SubViewport
@onready var banner_root: Control = find_child("BannerRoot", true, false) as Control
@onready var buttons_vbox: VBoxContainer = find_child("ButtonsVBox", true, false) as VBoxContainer
@onready var select_btn: Button = find_child("SelectBtn", true, false) as Button
@onready var back_btn: Button = find_child("BackBtn", true, false) as Button


func _ready() -> void:
	_build_roster()
	_hide_loadout_decoration()
	_update_cloth_banner_size()
	_refresh_hero_display()

	_set_screen_fade(0.0)
	create_tween().tween_method(_set_screen_fade, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _choice_made:
		return
	if event.is_action_pressed("ui_left"):
		_on_prev_hero_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next_hero_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func get_current_hero() -> PlayerResource:
	if _roster.is_empty():
		return null
	return _roster[_current_index]


func get_roster() -> Array[PlayerResource]:
	return _roster


func _build_roster() -> void:
	_roster.clear()
	var seen_paths: Dictionary = {}

	for hero in available_characters:
		if hero != null:
			var p := hero.resource_path
			if p == "" or not seen_paths.has(p):
				if p != "":
					seen_paths[p] = true
				_roster.append(hero)

	if _roster.is_empty():
		if characters_dir != "":
			_scan_directory_for_heroes(characters_dir, seen_paths)
		if _roster.is_empty():
			var fallback: PlayerResource = DEFAULT_HERO
			if fallback == null:
				fallback = Global.def_char
			if fallback != null:
				_roster.append(fallback)

	_current_index = 0
	var active_target := Global.selected_char if Global.selected_char != null else Global.def_char
	if active_target != null:
		for i in range(_roster.size()):
			if _roster[i] == active_target or (_roster[i].resource_path != "" and _roster[i].resource_path == active_target.resource_path):
				_current_index = i
				break


func _scan_directory_for_heroes(dir_path: String, seen_paths: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	var subdirs: Array[String] = []
	var tres_files: Array[String] = []
	while entry != "":
		if not entry.begins_with("."):
			if dir.current_is_dir():
				subdirs.append(dir_path.path_join(entry))
			else:
				var clean_name := entry.trim_suffix(".remap")
				if clean_name.ends_with(".tres"):
					tres_files.append(dir_path.path_join(clean_name))
		entry = dir.get_next()
	dir.list_dir_end()

	tres_files.sort()
	for file_path in tres_files:
		if seen_paths.has(file_path):
			continue
		var res := ResourceLoader.load(file_path)
		if res is PlayerResource:
			seen_paths[file_path] = true
			_roster.append(res as PlayerResource)

	subdirs.sort()
	for subdir in subdirs:
		_scan_directory_for_heroes(subdir, seen_paths)


func _hide_loadout_decoration() -> void:
	if loadout_dock != null:
		var deco := loadout_dock.get_node_or_null("BgDecoration") as CanvasItem
		if deco != null:
			deco.visible = false


func _refresh_hero_display() -> void:
	var hero := get_current_hero()
	var has_multiple := _roster.size() > 1
	if prev_hero_btn != null:
		prev_hero_btn.disabled = not has_multiple
	if next_hero_btn != null:
		next_hero_btn.disabled = not has_multiple
	if select_btn != null:
		select_btn.disabled = (hero == null)

	if hero == null:
		if nameplate_label != null:
			nameplate_label.text = ""
		if portrait_art != null:
			portrait_art.texture = null
			portrait_art.visible = false
		if placeholder_overlay != null:
			placeholder_overlay.visible = true
		return

	var display_hero := hero.duplicate(true) as PlayerResource
	if display_hero != null:
		display_hero.reset_stats_at_beginning_of_game()
	else:
		display_hero = hero

	if nameplate_label != null:
		nameplate_label.text = display_hero.player_class if display_hero.player_class != "" else "Hero"

	if portrait_art != null:
		portrait_art.texture = display_hero.portrait_art
		portrait_art.visible = (display_hero.portrait_art != null)
	if placeholder_overlay != null:
		placeholder_overlay.visible = (display_hero.portrait_art == null)

	if might_label != null:
		might_label.text = _format_stat(display_hero.might)
	if grit_label != null:
		grit_label.text = _format_stat(display_hero.grit)
	if agility_label != null:
		agility_label.text = _format_stat(display_hero.agility)
	if spirit_label != null:
		spirit_label.text = _format_stat(display_hero.spirit)

	if loadout_dock != null:
		_hide_loadout_decoration()
		loadout_dock.set_preview_character(display_hero)


func _format_stat(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return "%.1f" % value


func _update_cloth_banner_size() -> void:
	if buttons_vbox == null or banner_viewport_container == null:
		return
	var separation: float = float(buttons_vbox.get_theme_constant("separation"))
	var visible_count: int = 0
	var total_btn_height: float = 0.0
	for child in buttons_vbox.get_children():
		var ctrl := child as Control
		if ctrl != null and ctrl.visible:
			visible_count += 1
			var btn_h: float = maxf(ctrl.custom_minimum_size.y, ctrl.get_combined_minimum_size().y)
			total_btn_height += btn_h
	if visible_count > 1:
		total_btn_height += float(visible_count - 1) * separation
	var raw_height: float = total_btn_height + CLOTH_VERTICAL_PADDING
	var snapped_height: float = ceilf(raw_height / CLOTH_TILE_HEIGHT) * CLOTH_TILE_HEIGHT
	snapped_height = maxf(snapped_height, 64.0)

	banner_viewport_container.custom_minimum_size = Vector2(340.0, snapped_height)
	banner_viewport_container.size = Vector2(340.0, snapped_height)
	if banner_viewport != null:
		banner_viewport.size = Vector2i(340, int(snapped_height))
	if banner_root != null:
		banner_root.custom_minimum_size = Vector2(340.0, snapped_height)
	var mat := banner_viewport_container.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("banner_height", snapped_height)


func _set_screen_fade(alpha: float) -> void:
	if showcase_area != null:
		showcase_area.modulate.a = alpha
	if loadout_center != null:
		loadout_center.modulate.a = alpha
	if banner_viewport_container != null:
		var mat := banner_viewport_container.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("fade_alpha", alpha)


func _on_prev_hero_pressed() -> void:
	if _choice_made or _roster.size() <= 1:
		return
	_current_index = posmod(_current_index - 1, _roster.size())
	_refresh_hero_display()


func _on_next_hero_pressed() -> void:
	if _choice_made or _roster.size() <= 1:
		return
	_current_index = posmod(_current_index + 1, _roster.size())
	_refresh_hero_display()


func _on_select_pressed() -> void:
	if _choice_made:
		return
	var hero := get_current_hero()
	if hero == null:
		return
	_choice_made = true

	Global.select_character(hero)
	Global.game_seed = int(Time.get_unix_time_from_system() * (2.0 * Time.get_unix_time_from_system()))
	seed(Global.game_seed)
	Global.set_up_player()

	var area_to_load := def_area if def_area != null else DEFAULT_AREA
	Locations.load_locations_from_directory(area_to_load)
	Locations.pick_locations(Global.area_locations, area_to_load.enemy_loc_numb, area_to_load.event_loc_numb, area_to_load.services_loc_numb)

	if Global.area_cur_boss != null and Global.area_cur_boss.cut_scene:
		Global.cur_cutscene = Global.area_cur_boss.cut_scene
		Global.cur_scene = "res://events/cut_scene.tscn"
		SceneManager.change_scene("res://events/cut_scene.tscn", { "pattern": "diagonal", "color": Color("#2e222f") })
	else:
		Global.cur_scene = "res://map/locations_screen.tscn"
		SceneManager.change_scene("res://map/locations_screen.tscn", { "pattern": "diagonal", "color": Color("#2e222f") })


func _on_back_pressed() -> void:
	if _choice_made:
		return
	_choice_made = true
	MAIN_MENU_SCRIPT.returning_from_settings = true
	var tw := create_tween()
	tw.tween_method(_set_screen_fade, 1.0, 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		SceneManager.change_scene("res://ui/screens/main_menu.tscn", {
			"skip_fade_out": true,
			"skip_fade_in": true,
			"wait_time": 0.0,
		})
	)
