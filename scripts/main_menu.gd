extends Node2D

const AREA_1 = preload("res://locations/_loc_loaders/area_1.tres")

func _on_start_pressed() -> void:
	Global.set_up_player()
	Locations.load_locations_from_directory(AREA_1)
	Locations.pick_locations(Global.locations, Global.enemy_loc_numb, Global.event_loc_numb, Global.services_loc_numb)
	SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_char_select_pressed() -> void:
	SceneManager.change_scene("res://hero_select_screen.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_quit_pressed() -> void:
	get_tree().quit()
