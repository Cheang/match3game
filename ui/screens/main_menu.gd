extends Control

@export var song: MusicTrack
@export var def_area: LocationLoader

var area_to_load: LocationLoader
var choise_made: bool = false
var _sway_time: float = 0.0

@onready var load_btn: Button = find_child("load", true, false) as Button
@onready var cloth_banner: NinePatchRect = find_child("ClothBanner", true, false) as NinePatchRect
@onready var buttons_vbox: VBoxContainer = find_child("ButtonsVBox", true, false) as VBoxContainer


func _ready() -> void:
	call_deferred("_initialize_scene")


func _process(delta: float) -> void:
	_sway_time += delta * 1.8
	_apply_button_sway()


func _apply_button_sway() -> void:
	if cloth_banner == null or buttons_vbox == null or cloth_banner.size.y <= 0.0:
		return
	for child in buttons_vbox.get_children():
		var btn: Button = child as Button
		if btn == null or not btn.visible:
			continue
		var rel_y: float = (btn.global_position.y + btn.size.y * 0.5) - cloth_banner.global_position.y
		var y_norm: float = clampf(rel_y / maxf(cloth_banner.size.y, 1.0), 0.0, 1.0)
		var pin_factor: float = pow(y_norm, 1.35)
		var phase: float = y_norm * 2.6 * PI
		var wave: float = sin(phase - _sway_time) * 0.72 + sin(phase * 1.9 - _sway_time * 1.35 + 0.7) * 0.28
		var dx: float = floor(wave * 3.5 * pin_factor + 0.5)
		btn.position.x = (buttons_vbox.size.x - btn.size.x) * 0.5 + dx


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
		SceneManager.change_scene("res://ui/screens/settings_screen.tscn", { "pattern": "diagonal", "color": Color("#2e222f") })


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
