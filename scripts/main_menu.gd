extends Node2D

var temp_player: PlayerResource = preload("res://players/warrior/warrior.tres")

func _on_start_pressed() -> void:
	EnemyData.pick_bosses()
	EnemyData.pick_random_minion()
	EnemyData.set_enemie_stats()
	#this needs to become dynamic______________________________________|
	if Global.is_null(Global.cur_char):
		Global.cur_char = temp_player.duplicate()
	Global.cur_char.cur_health = Global.cur_char.max_health
	#__________________________________________________________________|
	Global.game_is_played = true
	SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_char_select_pressed() -> void:
	SceneManager.change_scene("res://hero_select_screen.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_quit_pressed() -> void:
	get_tree().quit()
