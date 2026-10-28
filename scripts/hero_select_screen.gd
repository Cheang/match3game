extends Node2D


func _on_button_pressed() -> void:
	SceneManager.change_scene("res://scenes/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })
