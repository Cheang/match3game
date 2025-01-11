extends EventChoise
class_name EvtChoiseSceneChange

var type: int = 1

@export var next_scene: String = "res://locations_screen.tscn"

func activate():
	Global.game_is_played = false
	SceneManager.change_scene(next_scene, { "pattern": "diagonal", "color": Color('#2e222f') })
