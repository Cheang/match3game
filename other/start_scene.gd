extends Control

func _ready() -> void:
	Global.changeSong(null)
	await get_tree().create_timer(.1).timeout
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
