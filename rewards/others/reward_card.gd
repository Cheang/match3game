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
@onready var choise_btn: Button = $choise_btn

var reward_resource: Resource
var index: int
var draft_source: String = ""
var is_boss_reward: bool = false
var _is_claiming: bool = false

func _ready() -> void:
	if choise_btn != null:
		if not choise_btn.mouse_entered.is_connected(_on_btn_mouse_entered):
			choise_btn.mouse_entered.connect(_on_btn_mouse_entered)
		if not choise_btn.mouse_exited.is_connected(_on_btn_mouse_exited):
			choise_btn.mouse_exited.connect(_on_btn_mouse_exited)

func _on_btn_mouse_entered() -> void:
	if not _is_claiming:
		modulate = Color(1.08, 1.08, 1.08, 1.0)

func _on_btn_mouse_exited() -> void:
	modulate = Color.WHITE

func _on_choise_btn_pressed() -> void:
	if reward_resource == null or _is_claiming:
		return
	if not RewardGrantHandler.is_supported_reward(reward_resource):
		push_error("reward_card: Unsupported reward resource: %s" % [str(reward_resource)])
		return
	_is_claiming = true
	modulate = Color.WHITE
	Global.game_is_played = false

	var mods: Array[Equipment] = RewardGrantHandler.get_resolved_modifiers(reward_resource)
	if not mods.is_empty():
		var modal := SlotEquipModal.new()
		get_tree().current_scene.add_child(modal)
		modal.prompt_modifiers(mods)
		await modal.modal_closed
		RewardGrantHandler.grant_reward(reward_resource, false)
	else:
		RewardGrantHandler.grant_reward(reward_resource, true)

	_proceed_after_reward()

func _proceed_after_reward() -> void:
	if Global.boss_beaten:
		SceneManager.change_scene("res://scenes/main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	elif Global.post_combat_event != null:
		Global.area_cur_event = Global.post_combat_event
		Global.post_combat_event = null
		SceneManager.change_scene("res://scenes/event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://scenes/locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

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

func _build_meta_header(res: Resource, r_key: String) -> String:
	var r_enum: Equipment.Rarity = RewardGrantHandler.rarity_name_to_equipment_enum(r_key)
	var r_hex: String = Equipment.get_rarity_hex(r_enum)
	var r_label: String = Equipment.get_rarity_name(r_enum)
	var tags: Array[String] = ["[color=%s][b][%s][/b][/color]" % [r_hex, r_label]]

	if draft_source == "monster":
		tags.append("[color=#f2a65a]Monster Loot[/color]")
	elif draft_source == "class":
		tags.append("[color=#9ec4d6]%s[/color]" % ("Boss Relic" if is_boss_reward else "Class Pool"))

	if res is Equipment:
		var eq := res as Equipment
		tags.append("%d-Slot" % clampi(eq.slot_cost, 1, 6))
		if eq.is_colorless():
			tags.append("Any Track")
		else:
			var c_names: Array[String] = []
			for c in eq.get_effective_allowed_colors():
				var cn: String = Global.get_color_name(c)
				if not c_names.has(cn):
					c_names.append(cn)
			tags.append("/".join(c_names))
		var trig: String = eq.get_trigger_badge_text()
		if trig != "":
			tags.append("[color=#fad65a]Trig:%s[/color]" % trig)
		if eq.once_per_battle:
			tags.append("[color=#f29d4c]1/Battle[/color]")
		elif eq.get_effective_cooldown_turns() > 0:
			tags.append("[color=#f29d4c]CD:%dT[/color]" % eq.get_effective_cooldown_turns())
	else:
		tags.append("Passive / Bonus")

	return "[color=#b5baa8]" + " • ".join(tags) + "[/color]"

func load_btn():
	_is_claiming = false
	modulate = Color.WHITE
	if reward_resource == null:
		return
	var r_key: String = RewardGrantHandler.get_rarity_name(reward_resource)
	var r_enum: Equipment.Rarity = RewardGrantHandler.rarity_name_to_equipment_enum(r_key)

	reward_base.texture = RewardGrantHandler.get_base_texture(reward_resource)
	reward_icon.texture = RewardGrantHandler.get_icon(reward_resource)
	reward_name.text = RewardGrantHandler.get_display_name(reward_resource)
	if r_enum > Equipment.Rarity.COMMON:
		reward_name.add_theme_color_override("font_color", Equipment.get_rarity_color(r_enum).lightened(0.22))
	else:
		reward_name.add_theme_color_override("font_color", Color(0.92, 0.94, 0.88))

	var meta_line: String = _build_meta_header(reward_resource, r_key)
	var body_desc: String = RewardGrantHandler.get_description(reward_resource)
	reward_description.text = "%s\n%s" % [meta_line, body_desc]

	add_theme_stylebox_override("panel", get_rarity_stylebox(r_key))
