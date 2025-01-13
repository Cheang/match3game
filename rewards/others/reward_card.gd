extends PanelContainer
class_name reward_card

var reward_resource: Reward
var index: int

@onready var reward_base: TextureRect = $HBoxContainer/reward_texture/reward_base
@onready var reward_icon: TextureRect = $HBoxContainer/reward_texture/reward_icon
@onready var reward_name: Label = $HBoxContainer/MarginContainer/VBoxContainer/reward_name
@onready var reward_decription: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/reward_decription

func _on_choise_btn_pressed() -> void:
	Global.game_is_played = false
	reward_resource.activate()
	reward_resource.boost()
	SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	if Global.boss_beaten:
		SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })


func load_btn():
	if reward_resource.base != null:
		reward_base.texture = reward_resource.base
	if reward_resource.icon != null:
		reward_icon.texture = reward_resource.icon
	if reward_resource.name != null:
		reward_name.text = reward_resource.name
	if reward_resource.description != null:
		reward_decription.text = reward_resource.description
