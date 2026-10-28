extends Control
class_name location_card

var loc_res: Location
@export var index: int

@onready var loc_texture: TextureRect = $MarginContainer/HBoxContainer/loc_texture
@onready var loc_name_l: Label = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/loc_name
@onready var loc_description_l: Label = $MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/loc_decription

var selected: bool = false

func load_btn() -> void:
	loc_texture.texture = loc_res.pic if loc_res.pic else null
	loc_name_l.text = loc_res.name 
	loc_description_l.text = loc_res.description 
	
func _on_selection_btn_pressed() -> void:
	if loc_res == null or loc_res.next_scene == null:
		return
	var destination_scene: String = loc_res.next_scene
	if loc_res.enemy_encounter and not loc_res.which_enemy.is_empty():
		var enemy_chosen = loc_res.which_enemy.pick_random()
		Global.set_up_enemy(enemy_chosen)
		Global.minions_killed += 1
		destination_scene = "res://scenes/game_window.tscn"
	elif loc_res.event_encounter and loc_res.event_resource:
		Global.area_cur_event = loc_res.event_resource
		destination_scene = "res://scenes/event_screen.tscn"
	selected = true
	Global.game_is_played = false
	if destination_scene != "":
		SceneManager.change_scene(destination_scene, { "pattern": "diagonal", "color": loc_res.transition_color })

func _on_tree_exiting() -> void:
	if selected:
		Global.area_locations.pop_at(index)
