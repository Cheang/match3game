extends EventChoise
class_name EvtChoiseFight

var type: int = 2

@export var enemy: Array[EnemyResource]

func activate():
	Global.game_is_played = false
	EnemyData.set_minion(enemy.pick_random())
	EnemyData.set_enemie_stats()
	SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
