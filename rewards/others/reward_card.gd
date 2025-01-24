extends PanelContainer
class_name reward_card

var reward_resource: Reward
var index: int

const REWARD_PANEL_COM = preload("res://assets/level_ui/reward_panel_com.png")
const REWARD_PANEL_UNCOM = preload("res://assets/level_ui/reward_panel_uncom.png")
const REWARD_PANEL_RARE = preload("res://assets/level_ui/reward_panel_rare.png")
const REWARD_PANEL_EPIC = preload("res://assets/level_ui/reward_panel_epic.png")
const REWARD_PANEL_LEG = preload("res://assets/level_ui/reward_panel_leg.png")
const REWARD_PANEL_GOD = preload("res://assets/level_ui/reward_panel_god.png")

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
	else: 
		reward_base.texture = null
	if reward_resource.icon != null:
		reward_icon.texture = reward_resource.icon
	else: 
		reward_icon.texture = null
	if reward_resource.name != null:
		reward_name.text = reward_resource.name
	if reward_resource.description != null:
		reward_decription.text = reward_resource.description
	var style_box = StyleBoxTexture.new()
	style_box.texture_margin_bottom = 15
	style_box.texture_margin_top = 15
	style_box.texture_margin_left = 15
	style_box.texture_margin_right = 15
	style_box.content_margin_bottom = 10
	style_box.content_margin_top = 10
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	match reward_resource.rearity:
		"COMMON":
			style_box.texture = REWARD_PANEL_COM
		"UNCOMMON":
			style_box.texture = REWARD_PANEL_UNCOM
		"RARE":
			style_box.texture = REWARD_PANEL_RARE
		"EPIC":
			style_box.texture = REWARD_PANEL_EPIC
		"LEGENDARY":
			style_box.texture = REWARD_PANEL_LEG
		"GODLY":
			style_box.texture = REWARD_PANEL_GOD
	self.add_theme_stylebox_override("panel", style_box)
