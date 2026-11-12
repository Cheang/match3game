extends Control


func _on_button_pressed() -> void:
	SceneManager.change_scene("res://ui/screens/main_menu.tscn", { "pattern": "diagonal", "color": Color("#484a77") })

