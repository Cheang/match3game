extends Control

@onready var load_btn: Button = $VBoxContainer/load

@export var song: MusicTrack
@export var def_area: LocationLoader

var area_to_load 
var choise_made: bool = false

func _ready() -> void:
	call_deferred("_initialize_scene")
	
	
func _initialize_scene():
	choise_made = false
	Global.changeSong(song)
	if Global.cur_char and Global.cur_scene:
		load_btn.disabled = false

func _on_start_pressed() -> void:
	if not choise_made:
		choise_made = true
		Global.set_up_player()
		if not area_to_load:
			area_to_load = def_area
		Locations.load_locations_from_directory(area_to_load)
		Locations.pick_locations(Global.area_locations, area_to_load.enemy_loc_numb, area_to_load.event_loc_numb, area_to_load.services_loc_numb)
		if Global.area_cur_boss.cut_scene:
			Global.cur_cutscene = Global.area_cur_boss.cut_scene
			Global.cur_scene = "res://cut_scene.tscn"
			SceneManager.change_scene("res://cut_scene.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		else:
			Global.cur_scene = "res://locations_screen.tscn"
			SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
func _on_load_pressed() -> void:
	if not choise_made:
		choise_made = true
func _on_char_select_pressed() -> void:
	if not choise_made:
		choise_made = true
		SceneManager.change_scene(" ", { "pattern": "diagonal", "color": Color('#484a77') })
func _on_settings_pressed() -> void:
	if not choise_made:
		choise_made = true
		SceneManager.change_scene("res://setting.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
func _on_quit_pressed() -> void:
	Global.save()
	get_tree().quit()
