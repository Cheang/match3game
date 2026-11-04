extends Node

const PlayerGlobesScene := preload("res://scenes/ui/player_globes.tscn")

func _ready() -> void:
	print("==================================================")
	print("RUNNING PLAYER GLOBES TESTS")
	print("==================================================")

	var globes := PlayerGlobesScene.instantiate() as PlayerGlobes
	add_child(globes)

	assert(globes != null, "PlayerGlobes instance must not be null")
	assert(globes.hp_label != null, "HP label must exist")
	assert(globes.energy_label != null, "Energy label must exist")
	assert(globes._hp_mat != null, "HP shader material must exist")
	assert(globes._energy_mat != null, "Energy shader material must exist")
	assert(globes._hp_mat != globes._energy_mat, "HP and Energy must have independent materials")
	print("  [PASS] PlayerGlobes scene and independent shader materials initialized")

	# Test 1: Full values
	globes.set_hp(20.0, 20.0, false)
	globes.set_energy(2, 2, false)
	assert(globes.hp_label.text == "20", "HP label text should be '20'")
	assert(globes.energy_label.text == "2", "Energy label text should be '2'")
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

	globes.queue_free()
	print("==================================================")
	print("ALL PLAYER GLOBES TESTS PASSED")
	print("==================================================")
	get_tree().quit()
