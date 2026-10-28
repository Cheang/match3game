extends Control

@onready var load_btn: Button = $VBoxContainer/VBoxContainer/load

@export var song: MusicTrack
@export var def_area: LocationLoader

var area_to_load 
var choise_made: bool = false

func _ready() -> void:
	call_deferred("_initialize_scene")

func _initialize_scene():
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
		Global.game_seed = Time.get_unix_time_from_system() * (2 * Time.get_unix_time_from_system())
		print(Global.game_seed)
		seed(Global.game_seed)
		Global.set_up_player()
		if not area_to_load:
			area_to_load = def_area
		Locations.load_locations_from_directory(area_to_load)
		Locations.pick_locations(Global.area_locations, area_to_load.enemy_loc_numb, area_to_load.event_loc_numb, area_to_load.services_loc_numb)
		if Global.area_cur_boss != null and Global.area_cur_boss.cut_scene:
			Global.cur_cutscene = Global.area_cur_boss.cut_scene
			Global.cur_scene = "res://scenes/cut_scene.tscn"
			SceneManager.change_scene("res://scenes/cut_scene.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		else:
			Global.cur_scene = "res://scenes/locations_screen.tscn"
			SceneManager.change_scene("res://scenes/locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_load_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.flg_game_is_loaded = true
		Global.load_data()
		print(Global.game_seed)
		seed(Global.game_seed)
		SceneManager.change_scene(Global.cur_scene, { "pattern": "diagonal", "color": Color('#2e222f') })
func _on_char_select_pressed() -> void:
	if not choise_made:
		const HERO_SELECT_SCENE := "res://scenes/hero_select_screen.tscn"
		if ResourceLoader.exists(HERO_SELECT_SCENE):
			choise_made = true
			SceneManager.change_scene(HERO_SELECT_SCENE, { "pattern": "diagonal", "color": Color('#484a77') })
		else:
			print("[LoreTiles] Character select screen is under development.")
func _on_settings_pressed() -> void:
	if not choise_made:
		choise_made = true
		SceneManager.change_scene("res://scenes/setting.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
func _on_quit_pressed() -> void:
	Global.save()
	get_tree().quit()
