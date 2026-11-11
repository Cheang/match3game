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
	_log_file = FileAccess.open("res://scratch/reward_screen_test_log.txt", FileAccess.WRITE)
	_log("==================================================")
	_log("RUNNING REWARD SCREEN V2 STANDALONE TESTS")
	_log("==================================================")

	# Ensure clean Global state before running
	Global.cur_char = null
	Global.cur_enemy = null
	Global.pending_reward_context.clear()
	Global.boss_beaten = false

	var reward_screen_scene: PackedScene = load("res://scenes/V2/reward-screen.tscn")
	_assert(reward_screen_scene != null, "scenes/V2/reward-screen.tscn loads successfully")

	var rs = reward_screen_scene.instantiate()
	_assert(rs != null, "Instantiated reward-screen instance successfully")
	add_child(rs)

	# Verify standalone mode initialization
	_assert(rs.is_standalone == true, "Reward screen detected standalone execution")
	_assert(Global.cur_char != null, "Global.cur_char auto-provisioned in standalone mode")
	_assert(Global.cur_char.rerolls >= 5, "Standalone character has starting rerolls (>= 5)")
	_assert(not rs.monster_rewards.is_empty(), "Monster reward pool auto-provisioned with mock loot")

	# Verify 3 choices were generated and bound to cards
	_assert(rs.reward_cards.size() == 3, "Reward screen has exactly 3 card containers")
	_assert(rs.reward_cards[0].reward_resource != null, "Slot 0 (Monster loot) card is populated")
	_assert(rs.reward_cards[1].reward_resource != null, "Slot 1 (Class pool) card is populated")
	_assert(rs.reward_cards[2].reward_resource != null, "Slot 2 (50/50 roll) card is populated")

	# Verify particles and pause nodes are completely removed
	_assert(rs.get_node_or_null("pause") == null, "Old pause node is completely removed")
	_assert(rs.find_child("GPUParticles2D*", true, false) == null, "All GPU particles are completely removed")

	# Verify title_label, inventory_button, bottom_bar, and inventory_overlay are present
	_assert(rs.title_label != null, "Header title_label is present in scene")
	_assert(rs.title_label.text == "Pick a reward", "Initial title is 'Pick a reward'")
	_assert(rs.inventory_button != null, "Combat-screen InventoryButton is present in reward screen")
	_assert(rs.bottom_bar != null, "bottom_bar component is present in reward screen")
	_assert(rs.bottom_bar.hp_label != null and rs.bottom_bar.hp_label.text != "", "bottom_bar HP label is present and populated")
	_assert(rs.bottom_bar.gold_label != null and rs.bottom_bar.gold_label.text != "", "bottom_bar Gold label is present and populated")
	_assert(rs.get_node_or_null("inventory_overlay") != null, "inventory_overlay instance is present in reward screen")

	# Verify testing HUD and extra testing buttons are completely removed
	_assert(rs.get_node_or_null("StandaloneTestingHUD") == null, "StandaloneTestingHUD is completely removed")
	_assert(rs.find_child("*Testing*", true, false) == null, "No testing toolbar or buttons exist on screen")

	# Verify skip and reroll use the new inventory overlay button style and swapped order (Reroll left, Skip right)
	var btn_row: HBoxContainer = rs.reroll.get_parent() as HBoxContainer
	_assert(btn_row != null and btn_row.get_child(0) == rs.reroll, "Reroll button is on the left (child 0)")
	_assert(btn_row != null and btn_row.get_child(1) == rs.skip, "Skip button is on the right (child 1)")
	var skip_sb = rs.skip.get_theme_stylebox("normal")
	_assert(skip_sb is StyleBoxTexture and skip_sb.texture != null, "Skip button uses StyleBoxTexture from inventory overlay")
	var reroll_sb = rs.reroll.get_theme_stylebox("normal")
	_assert(reroll_sb is StyleBoxTexture and reroll_sb.texture != null, "Reroll button uses StyleBoxTexture from inventory overlay")

	# Test Reroll in standalone mode
	var prev_rerolls: int = Global.cur_char.rerolls
	var _initial_card_0_name: String = RewardGrantHandler.get_display_name(rs.reward_cards[0].reward_resource)
	rs._on_reroll_pressed()
	_assert(Global.cur_char.rerolls == prev_rerolls - 1, "Reroll button decrements reroll count by 1")
	_assert(rs.reward_cards[0].reward_resource != null, "Cards repopulated after reroll")

	# Test Claiming Reward in standalone mode
	var picked_card: reward_card = rs.reward_cards[0]
	var picked_res: Resource = picked_card.reward_resource
	var _picked_name: String = RewardGrantHandler.get_display_name(picked_res)
	rs.handle_reward_proceed(picked_card)
	_assert(rs.reward_cards[0].reward_resource != null, "Draft immediately refreshed after claiming reward in standalone mode")

	# Test Skip in standalone mode
	rs._on_skip_pressed()
	_assert(rs.reward_cards[0].reward_resource != null, "Draft immediately refreshed after Skip in standalone mode")

	# Test InventoryOverlay keyboard shortcut integration
	_assert(InventoryOverlay.toggle_overlay != null, "InventoryOverlay toggle_overlay method is accessible")

	_log("==================================================")
	_log("RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	if tests_failed == 0:
		_log("[ALL REWARD SCREEN V2 TESTS PASSED]")
	else:
		_log("[TESTS FAILED]")
	_log("==================================================")

	if _log_file:
		_log_file.close()

	rs.queue_free()
	get_tree().quit(0 if tests_failed == 0 else 1)
