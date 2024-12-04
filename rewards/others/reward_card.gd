extends PanelContainer
class_name reward_card

var reward_res: Reward
var index: int

@onready var reward_base: TextureRect = $HBoxContainer/reward_texture/reward_base
@onready var reward_icon: TextureRect = $HBoxContainer/reward_texture/reward_icon
@onready var reward_name: Label = $HBoxContainer/MarginContainer/VBoxContainer/reward_name
@onready var reward_decription: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/reward_decription

func _on_choise_btn_pressed() -> void:
	reward_res.activate()
	SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	if Global.boss_beaten:
		SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })


func load_btn():
	if reward_res.base != null:
		reward_base.texture = reward_res.base
	if reward_res.icon != null:
		reward_icon.texture = reward_res.icon
	if reward_res.name != null:
		reward_name.text = reward_res.name
	if reward_res.description != null:
		reward_decription.text = reward_res.description
