extends Control
class_name location_card

var loc_res: Location
@export var index: int

@onready var loc_texture: TextureRect = $HBoxContainer/loc_texture
@onready var loc_name_l: Label = $HBoxContainer/MarginContainer/VBoxContainer/loc_name
@onready var loc_description_l: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/loc_decription

var selected: bool = false

func load_btn():
	if loc_res.pic != null:
		loc_texture.texture = loc_res.pic
	if loc_name_l.text != null:
		loc_name_l.text = loc_res.name
	if loc_description_l.text != null:
		loc_description_l.text = loc_res.description
	
func _on_selection_btn_pressed() -> void:
	if !Global.is_null(loc_res.next_scene):
		if loc_res.enemy_encounter and !loc_res.which_enemy.is_empty():
			var enemy_chosen = loc_res.which_enemy.pick_random()
			if !Global.is_null(enemy_chosen):
				EnemyData.set_minion(enemy_chosen)
				EnemyData.set_enemie_stats()
				Global.game_is_played = true
				loc_res.next_scene = "res://game_window.tscn"
		if loc_res.event_encounter and loc_res.event_resource:
			Global.cur_event = loc_res.event_resource
			loc_res.next_scene = "res://event_screen.tscn"
		Global.current_wave += 1
		selected = true
		if loc_res.next_scene != "":
			SceneManager.change_scene(loc_res.next_scene, { "pattern": "diagonal", "color": loc_res.transition_color })

func _on_tree_exiting() -> void:
	if selected:
		Global.locations.pop_at(index)
