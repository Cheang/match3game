class_name EvtChoiseSceneChange
extends EventChoise

@export var next_scene: String = "res://map/locations_screen.tscn"

var type: int = 1


func activate() -> void:
	Global.game_is_played = false
	SceneManager.change_scene(next_scene, { "pattern": "diagonal", "color": Color("#2e222f") })

