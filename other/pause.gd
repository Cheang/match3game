extends Node2D

@onready var pause_overlay: PanelContainer = $pause_overlay


func _on_pause_btn_pressed() -> void:
	pause_overlay.visible = true

func _on_resume_pressed() -> void:
	pause_overlay.visible = false

func _on_back_to_mm_pressed() -> void:
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_options_pressed() -> void:
	pass # Replace with function body.
