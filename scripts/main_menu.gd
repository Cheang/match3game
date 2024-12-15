extends Control

const AREA_1 = preload("res://locations/_loc_loaders/area_1.tres")
var choise_made: bool = false

func _ready() -> void:
	Global.change_music("MM_song")
	choise_made = false

func _on_start_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.set_up_player()
		Locations.load_locations_from_directory(AREA_1)
		Locations.pick_locations(Global.locations, Global.enemy_loc_numb, Global.event_loc_numb, Global.services_loc_numb)
		await get_tree().create_timer(.1).timeout
		SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_load_pressed() -> void:
	if not choise_made:
		choise_made = true
		await get_tree().create_timer(.1).timeout

func _on_char_select_pressed() -> void:
	if not choise_made:
		choise_made = true
		await get_tree().create_timer(.1).timeout
		SceneManager.change_scene("res://hero_select_screen.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_settings_pressed() -> void:
	if not choise_made:
		choise_made = true
		await get_tree().create_timer(.1).timeout

func _on_quit_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	get_tree().quit()
