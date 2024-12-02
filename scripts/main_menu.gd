extends Node2D

func _on_start_pressed() -> void:
	Global.set_up_player()
	Global.set_up_variable()
	Global.pick_locations()
	SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_char_select_pressed() -> void:
	SceneManager.change_scene("res://hero_select_screen.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_quit_pressed() -> void:
	get_tree().quit()
