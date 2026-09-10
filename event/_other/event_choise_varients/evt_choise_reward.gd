extends EventChoise
class_name EvtChoiseReward

var type: int = 3

@export var reward: Reward

@export var fight_overwrite: bool = false
@export var enemy: Array[EnemyResource] = []
@export var next_event: Event = null
@export var next_scene: String = "res://locations_screen.tscn"

var handled_in_place: bool = false

func activate():
	Global.game_is_played = false
	if reward != null:
		reward.activate()
		reward.boost()
	if fight_overwrite and not enemy.is_empty():
		Global.set_up_enemy(enemy.pick_random())
		SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		return
	if next_event != null:
		if handled_in_place:
			handled_in_place = false
			return
		Global.area_cur_event = next_event
		SceneManager.change_scene("res://event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true, "skip_fade_in": true })
		return
	SceneManager.change_scene(next_scene if next_scene != "" else "res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
