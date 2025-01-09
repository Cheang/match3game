extends Control

@export var song: MusicTrack

const AREA_1 = preload("res://locations/_loc_loaders/area_1.tres")
var area_to_load = AREA_1
var choise_made: bool = false

func _ready() -> void:
	choise_made = false
	Global.changeSong(song)

func _on_start_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.set_up_player()
		Locations.load_locations_from_directory(area_to_load)
		Locations.pick_locations(Global.area_locations, area_to_load.enemy_loc_numb, area_to_load.event_loc_numb, area_to_load.services_loc_numb)
		if Global.area_cur_boss.cut_scene:
			Global.cur_cutscene = Global.area_cur_boss.cut_scene
			SceneManager.change_scene("res://cut_scene.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		else:
			SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
func _on_load_pressed() -> void:
	if not choise_made:
		choise_made = true

func _on_char_select_pressed() -> void:
	if not choise_made:
		choise_made = true
		SceneManager.change_scene(" ", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_settings_pressed() -> void:
	if not choise_made:
		choise_made = true

func _on_quit_pressed() -> void:
	get_tree().quit()
