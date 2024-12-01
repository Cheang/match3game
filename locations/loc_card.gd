extends Control
class_name location_card
@export_category("Location")
@export var loc_name: String
@export var loc_description: String
@export var loc_pic: Texture2D
@export var next_scene: String = "res://main_menu.tscn"
@export var transition_color: Color = Color('#2e222f')

@export_category("Enemy")
@export var enemy_encounter: bool
@export var which_enemy: Array[EnemyResource]

@onready var loc_texture: TextureRect = $HBoxContainer/loc_texture
@onready var loc_name_l: Label = $HBoxContainer/MarginContainer/VBoxContainer/loc_name
@onready var loc_description_l: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/loc_decription


func _ready() -> void:
	loc_texture.texture = loc_pic
	loc_name_l.text = loc_name
	loc_description_l.text = loc_description

func _on_selection_btn_pressed() -> void:
	if !Global.is_null(next_scene):
		if enemy_encounter and !which_enemy.is_empty():
			var enemy_chosen = which_enemy.pick_random()
			if !Global.is_null(enemy_chosen):
				EnemyData.set_minion(enemy_chosen)
				EnemyData.set_enemie_stats()
				Global.game_is_played = true
				next_scene = "res://game_window.tscn"
		Global.current_wave += 1
		SceneManager.change_scene(next_scene, { "pattern": "diagonal", "color": transition_color })
