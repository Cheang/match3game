extends Node

var tests_passed: int = 0
var tests_failed: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] %s" % msg)
		tests_passed += 1
	else:
		printerr("  [FAIL] %s" % msg)
		tests_failed += 1

func _ready() -> void:
	get_tree().create_timer(8.0).timeout.connect(func():
		printerr("TEST TIMEOUT: test_bottom_bar took longer than 8.0s")
		get_tree().quit(1)
	)
	print("==================================================")
	print("RUNNING BOTTOM BAR STANDALONE TESTS")
	print("==================================================")

	var scene: PackedScene = load("res://ui/hud/bottom_bar.tscn")
	_assert(scene != null, "scenes/ui/bottom_bar.tscn loaded successfully")

	var bar := scene.instantiate() as BottomBar
	_assert(bar != null, "BottomBar instantiated successfully")
	add_child(bar)

	# Verify nodes exist
	_assert(bar.left_globe != null, "LeftGlobe node is present")
	_assert(bar.hp_liquid != null, "HPLiquid ColorRect is present")
	_assert(bar.hp_label != null, "HPLabel is present")
	_assert(bar.right_globe != null, "RightGlobe node is present")
	_assert(bar.backplate != null, "Backplate TextureRect is present")
	_assert(bar.inventory_button != null, "inventory_button is present")
	_assert(bar.gold_container != null, "GoldContainer is present")
	_assert(bar.gold_icon != null, "GoldIcon is present")
	_assert(bar.gold_label != null, "GoldLabel is present")

	# Verify alignment against 626x126 backplate
	_assert(bar.custom_minimum_size == Vector2(626, 126), "BottomBar custom_minimum_size matches 626x126 backplate")
	_assert(bar.offset_left == -313.0 and bar.offset_right == 313.0, "BottomBar is centered with half-width 313")
	_assert(bar.backplate.texture.get_size() == Vector2(626, 126), "Backplate texture is 626x126")
	_assert(bar.backplate.size == Vector2(626, 126), "Backplate control size is 626x126")
	_assert(bar.left_globe.position == Vector2(20, 1) and bar.left_globe.size == Vector2(130, 130), "LeftGlobe aligns to left backplate socket")
	_assert(bar.inventory_button.position == Vector2(246, 6) and bar.inventory_button.size == Vector2(134, 82), "InventoryButton aligns to center backplate socket")
	_assert(bar.right_globe.position == Vector2(476, 1) and bar.right_globe.size == Vector2(130, 130), "RightGlobe aligns to right backplate socket")

	# Test initial HP and Gold
	_assert(bar.hp_label.text == "20", "Default HP label is 20")
	_assert(bar.gold_label.text == "0", "Default Gold label is 0")

	# Test set_hp
	bar.set_hp(15.0, 30.0, false)
	_assert(bar.hp_label.text == "15", "set_hp updates HP label to 15")
	_assert(bar._hp_mat != null, "ShaderMaterial initialized on hp_liquid")
	var fill: float = float(bar._hp_mat.get_shader_parameter("fill_amount"))
	_assert(is_equal_approx(fill, 0.5), "Fill amount set to 0.5 (15/30)")

	# Test set_gold
	bar.set_gold(125, false)
	_assert(bar.gold_label.text == "125", "set_gold updates Gold label to 125")

	# Test player sync when Global.cur_char is present
	var mock_player := PlayerResource.new()
	mock_player.max_health = 25.0
	mock_player.cur_health = 18.0
	mock_player.gold = 77
	Global.cur_char = mock_player

	bar.update_from_player(false)
	_assert(bar.hp_label.text == "18", "update_from_player updates HP label to 18")
	_assert(bar.gold_label.text == "77", "update_from_player updates Gold label to 77")

	# Test dynamic signal update from player
	mock_player.cur_health = 12.0
	mock_player.updateUIPlayer.emit("cur_health")
	_assert(bar.hp_label.text == "12", "Player updateUIPlayer signal updates HP to 12")

	mock_player.gold = 95
	mock_player.updateUIPlayer.emit("gold")
	_assert(bar.gold_label.text == "95", "Player updateUIPlayer signal updates Gold to 95")

	# Test InventoryButton pressed darkening & icon shift
	var inv_btn := bar.inventory_button
	var orig_icon_y: float = inv_btn.icon.position.y
	_assert(inv_btn.modulate.is_equal_approx(Color.WHITE), "InventoryButton starts with normal WHITE modulate")
	inv_btn.button_down.emit()
	_assert(inv_btn.modulate.is_equal_approx(InventoryButton.PRESSED_MODULATE), "InventoryButton darkens when pressed down")
	_assert(is_equal_approx(inv_btn.icon.position.y, orig_icon_y + InventoryButton.PRESSED_ICON_OFFSET_Y), "InventoryButton icon shifts down on press")
	inv_btn.button_up.emit()
	_assert(inv_btn.modulate.is_equal_approx(Color.WHITE), "InventoryButton restores WHITE modulate on release")
	_assert(is_equal_approx(inv_btn.icon.position.y, orig_icon_y), "InventoryButton icon restores position on release")

	print("==================================================")
	print("RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	if tests_failed == 0:
		print("[ALL BOTTOM BAR TESTS PASSED]")
	else:
		print("[TESTS FAILED]")
	print("==================================================")

	bar.queue_free()
	get_tree().quit(0 if tests_failed == 0 else 1)
