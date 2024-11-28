extends Node2D

var temp_player: PlayerResource = preload("res://players/warrior.tres")

func _on_start_pressed() -> void:
	EnemyData.pick_bosses()
	EnemyData.pick_random_minion()
	EnemyData.set_enemie_stats()
	#this needs to become dynamic______________________________________|
	PlayerData.set_player_stats(temp_player)
	#__________________________________________________________________|
	Global.game_is_played = true
	SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_quit_pressed() -> void:
	get_tree().quit()
