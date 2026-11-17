extends Control

@export var song: MusicTrack
@export var def_area: LocationLoader

static var returning_from_settings: bool = false

const CLOTH_VERTICAL_PADDING: float = 84.0 # 42px top + 42px bottom padding
const CLOTH_TILE_HEIGHT: float = 8.0

var area_to_load: LocationLoader
var choise_made: bool = false

@onready var load_btn: Button = find_child("load", true, false) as Button
@onready var logo_rect: Control = find_child("LogoRect", true, false) as Control
@onready var banner_viewport_container: SubViewportContainer = find_child("BannerViewportContainer", true, false) as SubViewportContainer
@onready var banner_viewport: SubViewport = find_child("BannerViewport", true, false) as SubViewport
@onready var banner_root: Control = find_child("BannerRoot", true, false) as Control
@onready var buttons_vbox: VBoxContainer = find_child("ButtonsVBox", true, false) as VBoxContainer


func _ready() -> void:
	if buttons_vbox != null:
		for child in buttons_vbox.get_children():
			var ctrl := child as Control
			if ctrl != null and not ctrl.visibility_changed.is_connected(_update_cloth_banner_size):
				ctrl.visibility_changed.connect(_update_cloth_banner_size)
	_update_cloth_banner_size()
	if returning_from_settings:
		returning_from_settings = false
		_set_menu_fade(0.0)
		create_tween().tween_method(_set_menu_fade, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_set_menu_fade(1.0)
	call_deferred("_initialize_scene")


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


func _set_menu_fade(alpha: float) -> void:
	if logo_rect != null:
		logo_rect.modulate.a = alpha
	if banner_viewport_container != null:
		var mat := banner_viewport_container.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("fade_alpha", alpha)


func _initialize_scene() -> void:
	choise_made = false
	Global.cur_enemy = null
	if Global.game_is_over:
		Global.cur_char = null
		Global.cur_scene = ""
		Global.game_is_over = false
		Global.save()

	Global.changeSong(song)
	if Global.cur_char and Global.cur_scene:
		load_btn.disabled = false
		load_btn.visible = true
	else:
		load_btn.disabled = true
		load_btn.visible = false
	_update_cloth_banner_size()


func _on_start_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.game_seed = int(Time.get_unix_time_from_system() * (2.0 * Time.get_unix_time_from_system()))
		seed(Global.game_seed)
		Global.set_up_player()
		if not area_to_load:
			area_to_load = def_area
		Locations.load_locations_from_directory(area_to_load)
		Locations.pick_locations(Global.area_locations, area_to_load.enemy_loc_numb, area_to_load.event_loc_numb, area_to_load.services_loc_numb)
		if Global.area_cur_boss != null and Global.area_cur_boss.cut_scene:
			Global.cur_cutscene = Global.area_cur_boss.cut_scene
			Global.cur_scene = "res://events/cut_scene.tscn"
			SceneManager.change_scene("res://events/cut_scene.tscn", { "pattern": "diagonal", "color": Color("#2e222f") })
		else:
			Global.cur_scene = "res://map/locations_screen.tscn"
			SceneManager.change_scene("res://map/locations_screen.tscn", { "pattern": "diagonal", "color": Color("#2e222f") })


func _on_load_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.flg_game_is_loaded = true
		Global.load_data()
		seed(Global.game_seed)
		SceneManager.change_scene(Global.cur_scene, { "pattern": "diagonal", "color": Color("#2e222f") })


func _on_settings_pressed() -> void:
	if not choise_made:
		choise_made = true
		var tw := create_tween()
		tw.tween_method(_set_menu_fade, 1.0, 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		SceneManager.change_scene("res://ui/screens/settings_screen.tscn", {
			"skip_fade_out": true,
			"skip_fade_in": true,
			"wait_time": 0.0,
		})


func _on_test_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.game_seed = int(Time.get_unix_time_from_system() * 2)
		seed(Global.game_seed)
		Global.set_up_player()
		var test_enemy_res: EnemyResource = load("res://entities/enemies/minions/wild_boar/wild_boar_1.tres")
		if test_enemy_res != null:
			Global.set_up_enemy(test_enemy_res)
		Global.cur_scene = "res://combat/combat_screen.tscn"
		SceneManager.change_scene("res://combat/combat_screen.tscn", { "pattern": "diagonal", "color": Color("#2e222f") })


func _on_quit_pressed() -> void:
	Global.save()
	get_tree().quit()
