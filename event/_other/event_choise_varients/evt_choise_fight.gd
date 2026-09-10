extends EventChoise
class_name EvtChoiseFight

var type: int = 2

@export var enemy: Array[EnemyResource]
@export var next_event: Resource = null

func activate():
	Global.game_is_played = false
	Global.post_combat_event = next_event
	if not enemy.is_empty():
		Global.set_up_enemy(enemy.pick_random())

	SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
