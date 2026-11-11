extends Node

var tests_passed: int = 0
var tests_failed: int = 0
var _log_file: FileAccess

func _log(msg: String) -> void:
	print(msg)
	if _log_file:
		_log_file.store_line(msg)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_log("  [PASS] %s" % msg)
		tests_passed += 1
	else:
		_log("  [FAIL] %s" % msg)
		tests_failed += 1

func _ready() -> void:
	_log_file = FileAccess.open("res://scratch/reward_card_test_log.txt", FileAccess.WRITE)
	_log("==================================================")
	_log("TESTING REWARD CARD REDESIGN")
	_log("==================================================")

	var card_scene: PackedScene = load("res://rewards/others/reward_card.tscn")
	_assert(card_scene != null, "reward_card.tscn loads successfully")

	var card: reward_card = card_scene.instantiate() as reward_card
	_assert(card != null, "reward_card instantiated successfully")
	add_child(card)

	# 1. Editor Hierarchy Verification (Rule #5: Everything built in editor, not runtime code)
	var vbox = card.find_child("VBoxContainer", true, false)
	_assert(vbox != null, "VBoxContainer exists in card")

	var header_row = card.find_child("header_row", true, false)
	_assert(header_row != null, "header_row exists in scene hierarchy")
	_assert(vbox.get_child(0) == header_row, "header_row is the top element (child 0) of VBoxContainer")

	var rarity_lbl = card.find_child("rarity_label", true, false)
	_assert(rarity_lbl != null, "rarity_label exists inside header_row")
	_assert(header_row.get_child(0) == rarity_lbl, "rarity_label is on the left side of header_row")
	_assert(rarity_lbl.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "rarity_label expands horizontally to push icons right")

	var meta_icons = card.find_child("meta_icons", true, false)
	_assert(meta_icons != null, "meta_icons container exists inside header_row")
	_assert(header_row.get_child(1) == meta_icons, "meta_icons is on the right side of header_row")

	var colors_cont = card.find_child("colors_container", true, false)
	_assert(colors_cont != null, "colors_container exists inside meta_icons")
	_assert(meta_icons.get_child(0) == colors_cont, "colors_container is positioned before slot_icon")

	var col_multi = card.find_child("color_multi", true, false)
	_assert(col_multi != null, "color_multi TextureRect exists in colors_container")

	var col_0 = card.find_child("color_0", true, false)
	var col_1 = card.find_child("color_1", true, false)
	var col_2 = card.find_child("color_2", true, false)
	var col_3 = card.find_child("color_3", true, false)
	var col_4 = card.find_child("color_4", true, false)
	_assert(col_0 != null and col_1 != null and col_2 != null and col_3 != null and col_4 != null, "Pre-instantiated single color rects 0..4 exist in editor scene")

	var slot_cont = card.find_child("slot_container", true, false)
	var slot_ic = card.find_child("slot_icon", true, false)
	_assert(slot_ic != null, "slot_icon exists in meta_icons")
	_assert(slot_cont != null and meta_icons.get_child(1) == slot_cont, "slot_container is on the far right of header_row")

	var r_name = card.find_child("reward_name", true, false)
	_assert(r_name != null and vbox.get_child(1) == r_name, "reward_name sits immediately below header_row")
	_assert(r_name.get_theme_color("font_color") == Color.WHITE, "reward_name title is white")

	var r_desc = card.find_child("reward_decription", true, false)
	_assert(r_desc != null and vbox.get_child(2) == r_desc, "reward_decription sits below reward_name")
	_assert(card.reward_icon != null and card.reward_icon.material is ShaderMaterial, "reward_icon has a ShaderMaterial assigned in editor")

	# 2. Test Colorless Equipment (Multicolor)
	var eq_colorless := Equipment.new()
	eq_colorless.piece_name = "Way of the Fists"
	eq_colorless.rearity = "Rare"
	eq_colorless.slot_cost = 1
	eq_colorless.bound_color = 0
	eq_colorless.allowed_colors = []
	eq_colorless.base_damage = 2.0
	eq_colorless.combo_points_before = 2

	card.reward_resource = eq_colorless
	card.load_btn()

	_assert(rarity_lbl.text == "Rare", "Rarity label displays 'Rare' without brackets")
	_assert(not rarity_lbl.text.contains("[") and not rarity_lbl.text.contains("]"), "Rarity label contains no brackets")
	_assert(card.reward_icon.material.get_shader_parameter("rarity_tier") == 2, "reward_icon rarity shader set to RARE (tier 2)")
	_assert(card.reward_base.visible == true, "reward_base is visible for equipment reward")
	_assert(col_multi.visible == true, "Multicolor icon is visible for colorless/any track item")
	_assert(col_0.visible == false, "Single color rects hidden when multicolor is shown")
	_assert(slot_ic.texture.resource_path.ends_with("reward-slots-1.png"), "Slot icon correctly displays Roman numeral 1")
	_assert(not r_desc.text.contains("Class Pool") and not r_desc.text.contains("Monster Loot"), "No Class Pool or Monster Loot in description")

	# 3. Test Single Track Color Equipment (e.g. Red, 2-slot)
	var eq_red := Equipment.new()
	eq_red.piece_name = "Crimson Strike"
	eq_red.rearity = "Uncommon"
	eq_red.slot_cost = 2
	eq_red.bound_color = 100
	eq_red.allowed_colors = [100]

	card.reward_resource = eq_red
	card.load_btn()

	_assert(rarity_lbl.text == "Uncommon", "Rarity label displays 'Uncommon'")
	_assert(card.reward_icon.material.get_shader_parameter("rarity_tier") == 1, "reward_icon rarity shader set to UNCOMMON (tier 1)")
	_assert(col_multi.visible == false, "Multicolor icon hidden for single track item")
	_assert(col_0.visible == true, "color_0 visible for red track")
	_assert(col_1.visible == false and col_2.visible == false, "Unused single color rects hidden")
	_assert(col_0.material is ShaderMaterial, "color_0 has palette shader material applied")
	_assert(slot_ic.texture.resource_path.ends_with("reward-slots-2.png"), "Slot icon correctly displays Roman numeral 2")

	# 4. Test Multiple Specific Colors (e.g. Red and Blue, 3-slot)
	var eq_dual := Equipment.new()
	eq_dual.piece_name = "Frostfire Brand"
	eq_dual.rearity = "Epic"
	eq_dual.slot_cost = 3
	eq_dual.allowed_colors = [100, 200]

	card.reward_resource = eq_dual
	card.load_btn()

	_assert(rarity_lbl.text == "Epic", "Rarity label displays 'Epic'")
	_assert(card.reward_icon.material.get_shader_parameter("rarity_tier") == 3, "reward_icon rarity shader set to EPIC (tier 3)")
	_assert(col_multi.visible == false, "Multicolor icon hidden for dual track item")
	_assert(col_0.visible == true and col_1.visible == true, "Both color_0 and color_1 visible for dual colors")
	_assert(col_2.visible == false, "color_2 hidden")
	_assert(slot_ic.texture.resource_path.ends_with("reward-slots-3.png"), "Slot icon correctly displays Roman numeral 3")

	# 5. Test Passive Reward
	var rew_passive := Reward.new()
	rew_passive.name = "Iron Heart"
	rew_passive.rearity = "Rare"
	rew_passive.reward_type = Reward.RewardType.PASSIVE
	rew_passive.max_health = 15.0

	card.reward_resource = rew_passive
	card.load_btn()

	_assert(slot_ic.texture.resource_path.ends_with("reward-slots-passive.png"), "Slot icon correctly displays passive icon for Passive reward")
	_assert(colors_cont.visible == false, "Colors container hidden for Passive reward")
	_assert(card.reward_base.visible == false, "reward_base is hidden for Passive reward")

	# 6. Test Stat Buff Reward
	var rew_buff := Reward.new()
	rew_buff.name = "Heavy Vitality"
	rew_buff.rearity = "Common"
	rew_buff.reward_type = Reward.RewardType.STAT_BUFF
	rew_buff.might = 5.0

	card.reward_resource = rew_buff
	card.load_btn()

	_assert(slot_ic.texture.resource_path.ends_with("reward-slots-buff.png"), "Slot icon correctly displays buff icon for Stat Buff reward")
	_assert(colors_cont.visible == false, "Colors container hidden for Stat Buff reward")
	_assert(card.reward_base.visible == false, "reward_base is hidden for Stat Buff reward")

	_log("==================================================")
	_log("RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	if tests_failed == 0:
		_log("[ALL REWARD CARD REDESIGN TESTS PASSED]")
	_log("==================================================")

	await get_tree().process_frame
	get_tree().quit(0 if tests_failed == 0 else 1)
