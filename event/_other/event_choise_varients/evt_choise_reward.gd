extends EventChoise
class_name EvtChoiseReward

var type: int = 3

@export var reward: Reward

@export var fight_overwrite: bool
@export var enemy: Array[EnemyResource]

func activate():
	Global.game_is_played = false
	reward.activate()
	if fight_overwrite:
		EnemyData.set_minion(enemy.pick_random())
		EnemyData.set_enemie_stats()
		SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		return
	SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
