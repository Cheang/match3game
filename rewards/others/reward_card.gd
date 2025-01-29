extends PanelContainer
class_name reward_card

const REWARD_PANELS = {
	"COMMON": preload("res://assets/level_ui/reward_panel_com.png"),
	"UNCOMMON": preload("res://assets/level_ui/reward_panel_uncom.png"),
	"RARE": preload("res://assets/level_ui/reward_panel_rare.png"),
	"EPIC": preload("res://assets/level_ui/reward_panel_epic.png"),
	"LEGENDARY": preload("res://assets/level_ui/reward_panel_leg.png"),
	"GODLY": preload("res://assets/level_ui/reward_panel_god.png")
}

@onready var reward_base: TextureRect = $HBoxContainer/reward_texture/reward_base
@onready var reward_icon: TextureRect = $HBoxContainer/reward_texture/reward_icon
@onready var reward_name: Label = $HBoxContainer/MarginContainer/VBoxContainer/reward_name
@onready var reward_description: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/reward_decription

var reward_resource: Reward
var index: int

func _on_choise_btn_pressed() -> void:
	Global.game_is_played = false
	reward_resource.activate()
	reward_resource.boost()
	
	if Global.boss_beaten:
		#this will go to the next level
		SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })


func load_btn():
	reward_base.texture = reward_resource.base if reward_resource.base != null else null
	reward_icon.texture = reward_resource.icon if reward_resource.icon != null else null
	reward_name.text = reward_resource.name
	reward_description.text = reward_resource.description

	# Apply rarity-based style
	var style_box = StyleBoxTexture.new()
	for margin in ["bottom", "top", "left", "right"]:
		style_box.set("texture_margin_" + margin, 15)
		style_box.set("content_margin_" + margin, 10)

	if reward_resource.rearity in REWARD_PANELS:
		style_box.texture = REWARD_PANELS[reward_resource.rearity]

	add_theme_stylebox_override("panel", style_box)
