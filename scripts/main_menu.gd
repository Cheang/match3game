extends Node2D

func _on_start_pressed() -> void:
	Global.set_up_player()
	Locations.pick_locations(Global.locations, Global.enemy_loc_numb, Global.event_loc_numb, Global.services_loc_numb)
	SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_char_select_pressed() -> void:
	SceneManager.change_scene("res://hero_select_screen.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_quit_pressed() -> void:
	get_tree().quit()
