extends Node

const PlayerGlobesScene := preload("res://ui/hud/player_globes.tscn")

func _ready() -> void:
	print("==================================================")
	print("RUNNING PLAYER GLOBES TESTS")
	print("==================================================")

	var globes := PlayerGlobesScene.instantiate() as PlayerGlobes
	add_child(globes)

	assert(globes != null, "PlayerGlobes instance must not be null")
	assert(globes.hp_label != null, "HP label must exist")
	assert(globes.energy_label != null, "Energy label must exist")
	assert(globes.armor_plate != null, "ArmorPlate must exist")
	assert(globes.magic_armor_shield != null, "MagicArmorShield must exist")
	assert(globes.stat_tracker != null, "StatTracker must exist")
	assert(globes.gold_label != null, "GoldLabel must exist")
	assert(globes._hp_mat != null, "HP shader material must exist")
	assert(globes._energy_mat != null, "Energy shader material must exist")
	assert(globes._armor_mat != null, "Armor shader material must exist")
	assert(globes._magic_mat != null, "Magic armor shader material must exist")
	assert(globes._hp_mat != globes._energy_mat, "HP and Energy must have independent materials")
	print("  [PASS] PlayerGlobes scene, armor/magic nodes, and shader materials initialized")

	# Test 1: Full values (No armor)
	globes.set_defenses(20.0, 20.0, 0.0, 0.0, false)
	globes.set_energy(2, 2, false)
	assert(globes.hp_label.text == "20", "HP label text should be '20'")
	assert(globes.energy_label.text == "2", "Energy label text should be '2'")
	assert(not globes.armor_plate.visible, "ArmorPlate should be hidden with 0 armor")
	assert(not globes.magic_armor_shield.visible, "MagicArmorShield should be hidden with 0 magic armor")
	var hp_fill: float = float(globes._hp_mat.get_shader_parameter("fill_amount"))
	var energy_fill: float = float(globes._energy_mat.get_shader_parameter("fill_amount"))
	assert(is_equal_approx(hp_fill, 1.0), "HP fill should be 1.0")
	assert(is_equal_approx(energy_fill, 1.0), "Energy fill should be 1.0")
	print("  [PASS] Full HP (20/20) and Energy (2/2) values and fill verified")

	# Test 2: Half values
	globes.set_hp(10.0, 20.0, false)
	globes.set_energy(1, 2, false)
	assert(globes.hp_label.text == "10", "HP label text should be '10'")
	assert(globes.energy_label.text == "1", "Energy label text should be '1'")
	hp_fill = float(globes._hp_mat.get_shader_parameter("fill_amount"))
	energy_fill = float(globes._energy_mat.get_shader_parameter("fill_amount"))
	assert(is_equal_approx(hp_fill, 0.5), "HP fill should be 0.5")
	assert(is_equal_approx(energy_fill, 0.5), "Energy fill should be 0.5")
	print("  [PASS] Half HP (10/20) and Energy (1/2) values and fill verified")

	# Test 3: Zero / empty values
	globes.set_hp(0.0, 20.0, false)
	globes.set_energy(0, 2, false)
	assert(globes.hp_label.text == "0", "HP label text should be '0'")
	assert(globes.energy_label.text == "0", "Energy label text should be '0'")
	hp_fill = float(globes._hp_mat.get_shader_parameter("fill_amount"))
	energy_fill = float(globes._energy_mat.get_shader_parameter("fill_amount"))
	assert(is_equal_approx(hp_fill, 0.0), "HP fill should be 0.0")
	assert(is_equal_approx(energy_fill, 0.0), "Energy fill should be 0.0")
	print("  [PASS] Zero HP (0/20) and Energy (0/2) values and fill verified")

	# Test 4: Dynamic palettes
	var hp_high: Color = globes._hp_mat.get_shader_parameter("col_highlight")
	var hp_base: Color = globes._hp_mat.get_shader_parameter("col_base")
	var hp_shad: Color = globes._hp_mat.get_shader_parameter("col_shadow")
	assert(hp_high == Color("#F9C22B"), "HP highlight should be #F9C22B")
	assert(hp_base == Color("#E83B3B"), "HP base should be #E83B3B")
	assert(hp_shad == Color("#7A3045"), "HP shadow should be #7A3045")

	var en_high: Color = globes._energy_mat.get_shader_parameter("col_highlight")
	var en_base: Color = globes._energy_mat.get_shader_parameter("col_base")
	var en_shad: Color = globes._energy_mat.get_shader_parameter("col_shadow")
	assert(en_high == Color("#FBFF86"), "Energy highlight should be #FBFF86")
	assert(en_base == Color("#1EBC73"), "Energy base should be #1EBC73")
	assert(en_shad == Color("#165A4C"), "Energy shadow should be #165A4C")
	print("  [PASS] Exact 3-color palettes verified for both HP and Energy globes")

	# Test 5: Energy clamped to max_energy
	globes.set_energy(5, 2, false)
	assert(globes.energy_label.text == "2", "Energy label text should be clamped to '2' when given 5")
	energy_fill = float(globes._energy_mat.get_shader_parameter("fill_amount"))
	assert(is_equal_approx(energy_fill, 1.0), "Energy fill should be 1.0 when capped")
	print("  [PASS] Energy globe strictly clamps to max_energy")

	# Test 6: Physical Armor only (globe turns to metal, displays armor value)
	globes.set_defenses(20.0, 20.0, 15.0, 0.0, false)
	assert(globes.armor_plate.visible, "ArmorPlate should be visible when physical armor > 0")
	assert(not globes.magic_armor_shield.visible, "MagicArmorShield should be hidden when magic armor is 0")
	assert(globes.hp_label.text == "15", "HP label should show physical armor value '15'")
	print("  [PASS] Physical Armor only: Globe turns to metal, shows armor value 15")

	# Test 7: Magic Armor only (magic shield appears, displays magic armor value)
	globes.set_defenses(20.0, 20.0, 0.0, 12.0, false)
	assert(not globes.armor_plate.visible, "ArmorPlate should be hidden when physical armor is 0")
	assert(globes.magic_armor_shield.visible, "MagicArmorShield should be visible when magic armor > 0")
	assert(globes.hp_label.text == "12", "HP label should show magic armor value '12'")
	print("  [PASS] Magic Armor only: Magic shield appears, shows magic armor value 12")

	# Test 8: Stacked Defenses (Both Physical and Magic Armor active)
	globes.set_defenses(20.0, 20.0, 15.0, 8.0, false)
	assert(globes.armor_plate.visible, "ArmorPlate visible underneath")
	assert(globes.magic_armor_shield.visible, "MagicArmorShield visible on top")
	assert(globes.hp_label.text == "8", "HP label should show Magic Armor value '8' (takes damage first)")
	print("  [PASS] Stacked Defenses: Steel armor underneath, magic shield on top, shows Magic Armor 8")

	# Test 9: Depletion sequence (Magic Armor depleted -> shows Physical Armor -> shows Health)
	# Magic armor depleted to 0, physical armor 15 remains
	globes.set_defenses(20.0, 20.0, 15.0, 0.0, false)
	assert(not globes.magic_armor_shield.visible, "MagicArmorShield fades on depletion")
	assert(globes.armor_plate.visible, "ArmorPlate remains active")
	assert(globes.hp_label.text == "15", "HP label transitions to physical armor '15'")

	# Physical armor depleted to 0, base health 20 remains
	globes.set_defenses(20.0, 20.0, 0.0, 0.0, false)
	assert(not globes.armor_plate.visible, "ArmorPlate fades on depletion")
	assert(not globes.magic_armor_shield.visible, "MagicArmorShield is hidden")
	assert(globes.hp_label.text == "20", "HP label transitions back to base HP '20'")
	print("  [PASS] Depletion sequence: Magic Armor (8) -> Armor (15) -> Health (20) transitions verified")

	# Test 10: Stat Tracker Gold Display (format: 10g, 11g, etc.)
	globes.set_gold(10)
	assert(globes.gold_label.text == "10g", "Gold label should show '10g'")
	globes.set_gold(11)
	assert(globes.gold_label.text == "11g", "Gold label should show '11g'")
	globes.set_gold(100)
	assert(globes.gold_label.text == "100g", "Gold label should show '100g'")
	globes.set_gold(0)
	assert(globes.gold_label.text == "0g", "Gold label should show '0g'")
	print("  [PASS] Stat Tracker gold display format (10g, 11g) verified")

	# Test 11: Standalone Inventory Button component
	const InvBtnScene := preload("res://ui/hud/inventory_button.tscn")
	var inv_btn := InvBtnScene.instantiate() as InventoryButton
	assert(inv_btn != null, "InventoryButton instance must not be null")
	add_child(inv_btn)
	assert(inv_btn.icon != null, "InventoryButton icon child must exist")
	assert(inv_btn.texture_normal != null, "InventoryButton texture_normal must be configured")
	var pressed_count := [0]
	inv_btn.pressed.connect(func(): pressed_count[0] += 1)
	inv_btn.emit_signal("pressed")
	assert(pressed_count[0] == 1, "Emitting pressed on InventoryButton must fire signal")
	inv_btn.queue_free()
	print("  [PASS] Standalone InventoryButton component verified")

	globes.queue_free()
	print("==================================================")
	print("ALL PLAYER GLOBES TESTS PASSED")
	print("==================================================")
	get_tree().quit()
