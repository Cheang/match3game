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
	if reward_resource == null:
		return
	Global.game_is_played = false

	var mods: Array[Equipment] = reward_resource.get_resolved_modifiers()
	if not mods.is_empty():
		var modal := SlotEquipModal.new()
		get_tree().current_scene.add_child(modal)
		modal.prompt_modifiers(mods)
		await modal.modal_closed
		reward_resource.activate(false)
	else:
		reward_resource.activate(true)

	_proceed_after_reward()

func _proceed_after_reward() -> void:
	if Global.boss_beaten:
		SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	elif Global.post_combat_event != null:
		Global.area_cur_event = Global.post_combat_event
		Global.post_combat_event = null
		SceneManager.change_scene("res://event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

static var cached_styleboxes: Dictionary = {}

static func get_rarity_stylebox(rarity: String) -> StyleBoxTexture:
	if cached_styleboxes.has(rarity):
		return cached_styleboxes[rarity]
	var sb = StyleBoxTexture.new()
	sb.texture_margin_bottom = 15
	sb.texture_margin_top = 15
	sb.texture_margin_left = 15
	sb.texture_margin_right = 15
	sb.content_margin_bottom = 10
	sb.content_margin_top = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	if rarity in REWARD_PANELS:
		sb.texture = REWARD_PANELS[rarity]
	cached_styleboxes[rarity] = sb
	return sb

func load_btn():
	if reward_resource == null:
		return
	reward_base.texture = reward_resource.base if reward_resource.base != null else null
	reward_icon.texture = reward_resource.icon if reward_resource.icon != null else null
	reward_name.text = reward_resource.name
	reward_description.text = reward_resource.get_effect_description() if reward_resource.has_method("get_effect_description") else reward_resource.description

	var r_key: String = reward_resource.rearity if reward_resource.rearity != null and reward_resource.rearity != "" else "COMMON"
	add_theme_stylebox_override("panel", get_rarity_stylebox(r_key))
