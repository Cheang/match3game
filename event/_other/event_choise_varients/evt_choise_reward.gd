extends EventChoise
class_name EvtChoiseReward

var type: int = 3

@export var reward: Reward

@export var fight_overwrite: bool
@export var enemy: Array[EnemyResource]

func activate():
	Global.game_is_played = false
	reward.activate()
	reward.boost()
	if fight_overwrite:
		Global.set_up_enemy(enemy.pick_random())
		SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		return
	SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
