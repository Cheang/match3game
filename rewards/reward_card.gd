class_name RewardCard
extends PanelContainer

## Visual reward card component used in reward drafting screens.
## Displays reward icon, title, description, and top metadata (rarity, slots, and allowed color badges).

const RARITY_SHADER: Shader = preload("res://assets/shaders/rarity_palette_swap.gdshader")
const PALETTE_SHADER: Shader = preload("res://assets/shaders/palette_swap_5.gdshader")

const ICON_MULTICOLOR: Texture2D = preload("res://assets/sprites/rewards/reward_color_multicolor.png")
const ICON_SINGLECOLOR: Texture2D = preload("res://assets/sprites/rewards/reward_color_singlecolor.png")
const SLOT_ICONS: Dictionary = {
	1: preload("res://assets/sprites/rewards/reward_slots_1.png"),
	2: preload("res://assets/sprites/rewards/reward_slots_2.png"),
	3: preload("res://assets/sprites/rewards/reward_slots_3.png"),
	4: preload("res://assets/sprites/rewards/reward_slots_4.png"),
}
const ICON_SLOT_BUFF: Texture2D = preload("res://assets/sprites/rewards/reward_slots_buff.png")
const ICON_SLOT_PASSIVE: Texture2D = preload("res://assets/sprites/rewards/reward_slots_passive.png")

static var _cached_palette_materials: Dictionary = {}

var reward_resource: Resource
var index: int = 0
var draft_source: String = ""
var is_boss_reward: bool = false
var _is_claiming: bool = false
var _single_color_rects: Array[TextureRect] = []

@onready var backplate: NinePatchRect = get_node_or_null("Backplate")
@onready var reward_base: TextureRect = find_child("reward_base", true, false)
@onready var reward_icon: TextureRect = find_child("reward_icon", true, false)
@onready var reward_name: Label = find_child("reward_name", true, false)
@onready var reward_description: RichTextLabel = find_child("reward_decription", true, false)
@onready var choise_btn: Button = get_node_or_null("choise_btn")
@onready var rarity_label: Label = find_child("rarity_label", true, false)
@onready var meta_icons: HBoxContainer = find_child("meta_icons", true, false)
@onready var colors_container: HBoxContainer = find_child("colors_container", true, false)
@onready var color_multi: TextureRect = find_child("color_multi", true, false)
@onready var slot_container: Control = find_child("slot_container", true, false)
@onready var slot_backplate: TextureRect = find_child("slot_backplate", true, false)
@onready var slot_icon: TextureRect = find_child("slot_icon", true, false)

func _ready() -> void:
	_ensure_nodes()
	if choise_btn != null:
		if not choise_btn.mouse_entered.is_connected(_on_btn_mouse_entered):
			choise_btn.mouse_entered.connect(_on_btn_mouse_entered)
		if not choise_btn.mouse_exited.is_connected(_on_btn_mouse_exited):
			choise_btn.mouse_exited.connect(_on_btn_mouse_exited)
	_ensure_materials()

func _ensure_nodes() -> void:
	if backplate == null:
		backplate = get_node_or_null("Backplate")
	if reward_base == null:
		reward_base = find_child("reward_base", true, false)
	if reward_icon == null:
		reward_icon = find_child("reward_icon", true, false)
	if reward_name == null:
		reward_name = find_child("reward_name", true, false)
	if reward_description == null:
		reward_description = find_child("reward_decription", true, false)
	if choise_btn == null:
		choise_btn = get_node_or_null("choise_btn")
	if rarity_label == null:
		rarity_label = find_child("rarity_label", true, false)
	if meta_icons == null:
		meta_icons = find_child("meta_icons", true, false)
	if colors_container == null:
		colors_container = find_child("colors_container", true, false)
	if color_multi == null:
		color_multi = find_child("color_multi", true, false)
	if slot_container == null:
		slot_container = find_child("slot_container", true, false)
	if slot_backplate == null:
		slot_backplate = find_child("slot_backplate", true, false)
	if slot_icon == null:
		slot_icon = find_child("slot_icon", true, false)
	if _single_color_rects.is_empty() and colors_container != null:
		for c in colors_container.get_children():
			if c is TextureRect and c != color_multi:
				_single_color_rects.append(c as TextureRect)

func _ensure_materials() -> void:
	_ensure_backplate_material()
	_ensure_icon_material()

func _ensure_backplate_material() -> void:
	if backplate == null:
		backplate = get_node_or_null("Backplate")
	if backplate != null:
		if backplate.material == null or not (backplate.material is ShaderMaterial):
			var mat := ShaderMaterial.new()
			mat.shader = RARITY_SHADER
			mat.set_shader_parameter("rarity_tier", 0)
			mat.set_meta("_is_duplicated", true)
			backplate.material = mat
		elif not backplate.material.has_meta("_is_duplicated"):
			backplate.material = backplate.material.duplicate()
			backplate.material.set_meta("_is_duplicated", true)

func _ensure_icon_material() -> void:
	if reward_icon == null:
		reward_icon = find_child("reward_icon", true, false)
	if reward_icon != null:
		if reward_icon.material == null or not (reward_icon.material is ShaderMaterial):
			var mat := ShaderMaterial.new()
			mat.shader = RARITY_SHADER
			mat.set_shader_parameter("rarity_tier", 0)
			mat.set_meta("_is_duplicated", true)
			reward_icon.material = mat
		elif not reward_icon.material.has_meta("_is_duplicated"):
			reward_icon.material = reward_icon.material.duplicate()
			reward_icon.material.set_meta("_is_duplicated", true)

static func get_track_palette_material(c_id: int) -> ShaderMaterial:
	var base_fam: int = ColorLoadoutTrack.get_base_family(c_id)
	if _cached_palette_materials.has(base_fam):
		return _cached_palette_materials[base_fam]
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(base_fam)
	mat.set_shader_parameter("target_color_1", pal.highlight)
	mat.set_shader_parameter("target_color_2", pal.lightbase)
	mat.set_shader_parameter("target_color_3", pal.base)
	mat.set_shader_parameter("target_color_4", pal.shadebase)
	mat.set_shader_parameter("target_color_5", pal.deepshade)
	_cached_palette_materials[base_fam] = mat
	return mat

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

	# 1. Passive Reward Handling (5 passive slots maximum)
	var is_passive: bool = false
	if RewardGrantHandler.get_reward_type(reward_resource) == Reward.RewardType.PASSIVE:
		is_passive = true
	elif is_boss_reward:
		is_passive = true

	if is_passive and Global.cur_char != null:
		if not Global.cur_char.can_equip_passive():
			var p_modal := PassiveReplaceModal.new()
			get_tree().current_scene.add_child(p_modal)
			p_modal.prompt_passive(reward_resource)
			await p_modal.modal_closed
			_proceed_after_reward()
			return
		else:
			Global.cur_char.equip_passive(reward_resource)
			RewardGrantHandler.grant_reward(reward_resource, false)
			_proceed_after_reward()
			return

	# 2. Combat / Equipment Card Handling
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
	var cur_sc = get_tree().current_scene if get_tree() != null else null
	if cur_sc != null and cur_sc.has_method("handle_reward_proceed"):
		cur_sc.handle_reward_proceed(self)
		return
	if Global.boss_beaten:
		SceneManager.change_scene("res://ui/screens/main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	elif Global.post_combat_event != null:
		Global.area_cur_event = Global.post_combat_event
		Global.post_combat_event = null
		SceneManager.change_scene("res://events/event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://map/locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func load_btn() -> void:
	_is_claiming = false
	modulate = Color.WHITE
	if reward_resource == null:
		return
	_ensure_nodes()
	_ensure_materials()

	var r_key: String = RewardGrantHandler.get_rarity_name(reward_resource)
	var r_enum: Equipment.Rarity = RewardGrantHandler.rarity_name_to_equipment_enum(r_key)
	var r_color: Color = Equipment.get_rarity_color(r_enum)
	var r_text: String = Equipment.get_rarity_name(r_enum)

	if backplate != null and backplate.material is ShaderMaterial:
		backplate.material.set_shader_parameter("rarity_tier", int(r_enum))
	if reward_icon != null and reward_icon.material is ShaderMaterial:
		reward_icon.material.set_shader_parameter("rarity_tier", int(r_enum))

	# Resolve equipment if applicable
	var eq: Equipment = null
	if reward_resource is Equipment:
		eq = reward_resource as Equipment
	elif reward_resource is Reward and (reward_resource as Reward).get_effective_reward_type() == Reward.RewardType.EQUIPMENT:
		eq = (reward_resource as Reward).get_primary_equipment()

	if reward_base != null:
		if eq != null:
			reward_base.visible = true
			reward_base.texture = RewardGrantHandler.get_base_texture(reward_resource)
		else:
			reward_base.visible = false
			reward_base.texture = null
	if reward_icon != null:
		reward_icon.texture = RewardGrantHandler.get_icon(reward_resource)

	# 1. Rarity Label: on top of the title, clean text (no brackets), colored by rarity
	if rarity_label != null:
		rarity_label.text = r_text
		rarity_label.add_theme_color_override("font_color", r_color)

	# 2. Title: crisp white text
	if reward_name != null:
		reward_name.text = RewardGrantHandler.get_display_name(reward_resource)
		reward_name.add_theme_color_override("font_color", Color.WHITE)

	# 3. Slots & Colors icons (opposite side of top row)
	if slot_container != null:
		slot_container.visible = true
	if slot_icon != null:
		slot_icon.visible = true
		if eq != null:
			var cost: int = clampi(eq.slot_cost, 1, 4)
			slot_icon.texture = SLOT_ICONS.get(cost, SLOT_ICONS[1])
		elif (reward_resource is Reward and (reward_resource as Reward).get_effective_reward_type() == Reward.RewardType.PASSIVE) or is_boss_reward:
			slot_icon.texture = ICON_SLOT_PASSIVE
		else:
			slot_icon.texture = ICON_SLOT_BUFF

	for cr in _single_color_rects:
		cr.visible = false

	if eq != null:
		if colors_container != null:
			colors_container.visible = true
		var eff_colors: Array[int] = eq.get_effective_allowed_colors() if eq.has_method("get_effective_allowed_colors") else []
		var is_multi: bool = eq.is_colorless() or eff_colors.is_empty() or eff_colors.size() >= 5
		if is_multi:
			if color_multi != null:
				color_multi.visible = true
		else:
			if color_multi != null:
				color_multi.visible = false
			for i in range(mini(eff_colors.size(), _single_color_rects.size())):
				var c_fam: int = eff_colors[i]
				var rect: TextureRect = _single_color_rects[i]
				rect.visible = true
				rect.material = get_track_palette_material(c_fam)
	else:
		if colors_container != null:
			colors_container.visible = false
		if color_multi != null:
			color_multi.visible = false

	# 4. Description taken directly from reward resource
	var body_desc: String = ""
	if eq != null:
		body_desc = eq.get_effect_description()
	else:
		body_desc = RewardGrantHandler.get_description(reward_resource)
	if eq != null:
		var extra_tags: Array[String] = []
		var trig: String = eq.get_trigger_badge_text()
		if trig != "":
			extra_tags.append("[color=#fad65a]Trig:%s[/color]" % trig)
		if eq.once_per_battle:
			extra_tags.append("[color=#f29d4c]1/Battle[/color]")
		elif eq.get_effective_cooldown_turns() > 0:
			extra_tags.append("[color=#f29d4c]CD:%dT[/color]" % eq.get_effective_cooldown_turns())
		if not extra_tags.is_empty():
			var extra_str: String = " • ".join(extra_tags)
			if body_desc != "":
				body_desc = "%s  (%s)" % [body_desc, extra_str]
			else:
				body_desc = extra_str

	if reward_description != null:
		reward_description.text = body_desc
