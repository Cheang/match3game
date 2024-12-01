extends Node2D

var temp_player: PlayerResource = preload("res://players/warrior/warrior.tres")

func _on_start_pressed() -> void:
	#this needs to become dynamic______________________________________|
	if Global.is_null(Global.selected_char):
		Global.selected_char = temp_player.duplicate()
	Global.cur_char = Global.selected_char.duplicate()
	Global.cur_char.cur_health = Global.cur_char.max_health
	#__________________________________________________________________|
	Global.current_wave = 0
	SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_char_select_pressed() -> void:
	SceneManager.change_scene("res://hero_select_screen.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_quit_pressed() -> void:
	get_tree().quit()
