extends Node

func _ready() -> void:
	print("\n=======================================================")
	print(" RUNNING EQUIPMENT RARITY & SCALING TEST SUITE")
	print("=======================================================\n")
	var success := true
	success = test_base_common_isolation() and success
	success = test_tier_creation_and_scaling() and success
	success = test_color_expansion() and success
	success = test_player_passive_reconciliation() and success
	success = test_rarity_duplication() and success
	success = test_existing_equipment_compatibility() and success

	if success:
		print("\n[ALL TESTS PASSED] Equipment rarity and scaling system is 100% verified!\n")
		get_tree().quit(0)
	else:
		printerr("\n[TESTS FAILED] One or more tests failed!\n")
		get_tree().quit(1)

func test_base_common_isolation() -> bool:
	print("-> Testing Base Common Isolation...")
	var eq := Equipment.new()
	eq.piece_name = "Training Sword"
	eq.base_damage = 2.0
	eq.cooldown_turns = 1
	eq.allowed_colors = [100] # Red only
	eq.rarity = Equipment.Rarity.COMMON

	if not eq.get_stat_boosts().is_empty():
		printerr("FAIL: Common equipment should have 0 stat boosts, got: ", eq.get_stat_boosts())
		return false
	if eq.get_effective_base_damage() != 2.0:
		printerr("FAIL: Effective damage mismatch on common: ", eq.get_effective_base_damage())
		return false
	if eq.is_allowed_on_color(200): # Blue
		printerr("FAIL: Common should only allow Red (100), but accepted Blue (200)")
		return false
	print("   PASSED: Base Common item grants 0 stat boosts and respects base bounds.")
	return true

func test_tier_creation_and_scaling() -> bool:
	print("-> Testing Tier Creation & Scaling...")
	var eq := Equipment.new()
	eq.piece_name = "Short Sword"
	eq.base_damage = 1.0
	eq.hit_count = 1
	eq.allowed_colors = [100]

	# Uncommon tier (+1 Might, +1 DMG)
	var t_uncom := EquipmentRarityTier.new()
	t_uncom.rarity = EquipmentRarityTier.Rarity.UNCOMMON
	t_uncom.might = 1.0
	t_uncom.base_damage = 1.0 # additive bonus -> 1 + 1 = 2
	eq.rarity_tiers.append(t_uncom)

	# Rare tier (+2 Might, +5% Crit, +2 DMG)
	var t_rare := EquipmentRarityTier.new()
	t_rare.rarity = EquipmentRarityTier.Rarity.RARE
	t_rare.might = 2.0
	t_rare.crit_chance = 5
	t_rare.base_damage = 2.0 # additive bonus -> 1 + 2 = 3
	eq.rarity_tiers.append(t_rare)

	# Epic tier (+3 Might, +10% Crit, +5 Max HP, Override: 6 DMG, 2 Hits)
	var t_epic := EquipmentRarityTier.new()
	t_epic.rarity = EquipmentRarityTier.Rarity.EPIC
	t_epic.might = 3.0
	t_epic.crit_chance = 10
	t_epic.max_health = 5.0
	t_epic.is_effect_override = true
	t_epic.base_damage = 6.0
	t_epic.hit_count = 2
	eq.rarity_tiers.append(t_epic)

	# Check Uncommon
	eq.rarity = Equipment.Rarity.UNCOMMON
	var uncom_boosts: Dictionary = eq.get_stat_boosts()
	if uncom_boosts.get("might", 0.0) != 1.0 or uncom_boosts.has("crit_chance"):
		printerr("FAIL: Uncommon stat boosts incorrect: ", uncom_boosts)
		return false
	if eq.get_effective_base_damage() != 2.0:
		printerr("FAIL: Uncommon effective damage incorrect: ", eq.get_effective_base_damage())
		return false

	# Check Rare
	eq.rarity = Equipment.Rarity.RARE
	var rare_boosts: Dictionary = eq.get_stat_boosts()
	if rare_boosts.get("might", 0.0) != 2.0 or rare_boosts.get("crit_chance", 0) != 5:
		printerr("FAIL: Rare stat boosts incorrect: ", rare_boosts)
		return false
	if eq.get_effective_base_damage() != 3.0:
		printerr("FAIL: Rare effective damage incorrect: ", eq.get_effective_base_damage())
		return false

	# Check Epic (Override)
	eq.rarity = Equipment.Rarity.EPIC
	var epic_boosts: Dictionary = eq.get_stat_boosts()
	if epic_boosts.get("might", 0.0) != 3.0 or epic_boosts.get("crit_chance", 0) != 10 or epic_boosts.get("max_health", 0.0) != 5.0:
		printerr("FAIL: Epic stat boosts incorrect: ", epic_boosts)
		return false
	if eq.get_effective_base_damage() != 6.0 or eq.get_effective_hit_count() != 2:
		printerr("FAIL: Epic effective overrides incorrect: DMG=", eq.get_effective_base_damage(), " Hits=", eq.get_effective_hit_count())
		return false

	print("   PASSED: Tiers scale damage, hits, and passive stats dynamically.")
	return true

func test_color_expansion() -> bool:
	print("-> Testing Color Availability Expansion...")
	var eq := Equipment.new()
	eq.piece_name = "Red Lance"
	eq.allowed_colors = [100] # Red only at base

	var t_rare := EquipmentRarityTier.new()
	t_rare.rarity = EquipmentRarityTier.Rarity.RARE
	t_rare.extra_allowed_colors = [200] # Add Blue
	eq.rarity_tiers.append(t_rare)

	var t_legend := EquipmentRarityTier.new()
	t_legend.rarity = EquipmentRarityTier.Rarity.LEGENDARY
	t_legend.allow_all_colors = true # Colorless on any track!
	eq.rarity_tiers.append(t_legend)

	# At Common: Only Red
	eq.rarity = Equipment.Rarity.COMMON
	if not eq.is_allowed_on_color(100) or eq.is_allowed_on_color(200) or eq.is_allowed_on_color(300):
		printerr("FAIL: Common should only allow Red")
		return false

	# At Rare: Red and Blue
	eq.rarity = Equipment.Rarity.RARE
	if not eq.is_allowed_on_color(100) or not eq.is_allowed_on_color(200) or eq.is_allowed_on_color(300):
		printerr("FAIL: Rare should allow Red and Blue, but not Green")
		return false

	# At Legendary: Colorless (any track)
	eq.rarity = Equipment.Rarity.LEGENDARY
	if not eq.is_colorless() or not eq.is_allowed_on_color(100) or not eq.is_allowed_on_color(200) or not eq.is_allowed_on_color(300) or not eq.is_allowed_on_color(500):
		printerr("FAIL: Legendary should be colorless and allow all colors")
		return false

	print("   PASSED: Color options expand correctly per rarity tier.")
	return true

func test_player_passive_reconciliation() -> bool:
	print("-> Testing Player Passive Stat Reconciliation...")
	var player := PlayerResource.new()
	player.might = 1.0
	player.grit = 0.0
	player.crit_chance = 5
	player.max_health = 20.0
	player.cur_health = 20.0
	player.ensure_loadout_tracks()

	var rare_sword := Equipment.new()
	rare_sword.piece_name = "Rare Sword"
	rare_sword.rarity = Equipment.Rarity.RARE
	var t_rare := EquipmentRarityTier.new()
	t_rare.rarity = EquipmentRarityTier.Rarity.RARE
	t_rare.might = 2.0
	t_rare.crit_chance = 5
	rare_sword.rarity_tiers.append(t_rare)

	var red_track: ColorLoadoutTrack = player.get_track_for_color(100)
	var drag_data := {
		"type": "modifier_drag",
		"source": "bag",
		"modifier": rare_sword,
		"bag_index": -1
	}

	# 1. Equip Rare Sword onto Red track
	var equipped: bool = player.handle_modifier_drop_on_track(drag_data, red_track, 0)
	if not equipped:
		printerr("FAIL: Could not drop rare sword on red track")
		return false

	if player.might != 3.0:
		printerr("FAIL: Player might expected 3.0, got: ", player.might)
		return false
	if player.crit_chance != 10:
		printerr("FAIL: Player crit_chance expected 10, got: ", player.crit_chance)
		return false

	# 2. Add Epic Armor onto Blue track
	var epic_shield := Equipment.new()
	epic_shield.piece_name = "Epic Shield"
	epic_shield.rarity = Equipment.Rarity.EPIC
	var t_epic := EquipmentRarityTier.new()
	t_epic.rarity = EquipmentRarityTier.Rarity.EPIC
	t_epic.grit = 3.0
	t_epic.max_health = 5.0
	epic_shield.rarity_tiers.append(t_epic)

	var blue_track: ColorLoadoutTrack = player.get_track_for_color(200)
	var drag_shield := {
		"type": "modifier_drag",
		"source": "bag",
		"modifier": epic_shield,
		"bag_index": -1
	}
	player.handle_modifier_drop_on_track(drag_shield, blue_track, 0)

	if player.grit != 3.0:
		printerr("FAIL: Player grit expected 3.0, got: ", player.grit)
		return false
	if player.max_health != 25.0 or player.cur_health != 25.0:
		printerr("FAIL: Player max_health expected 25.0, got: ", player.max_health)
		return false

	# 3. Unequip Epic Shield to Bag
	var unequip_shield := {
		"type": "modifier_drag",
		"source": "track",
		"modifier": epic_shield,
		"source_track": blue_track,
		"source_index": 0
	}
	player.handle_modifier_drop_on_bag(unequip_shield)

	if player.grit != 0.0:
		printerr("FAIL: Player grit expected 0.0 after unequip, got: ", player.grit)
		return false
	if player.max_health != 20.0:
		printerr("FAIL: Player max_health expected 20.0 after unequip, got: ", player.max_health)
		return false

	# 4. Unequip Rare Sword to Bag
	var unequip_sword := {
		"type": "modifier_drag",
		"source": "track",
		"modifier": rare_sword,
		"source_track": red_track,
		"source_index": 0
	}
	player.handle_modifier_drop_on_bag(unequip_sword)

	if player.might != 1.0 or player.crit_chance != 5:
		printerr("FAIL: Player baseline stats drifted: might=", player.might, " crit=", player.crit_chance)
		return false

	print("   PASSED: Passive stats applied on equip and revoked cleanly with zero drift.")
	return true

func test_rarity_duplication() -> bool:
	print("-> Testing Rarity Duplication (Reward / Shop Spawning)...")
	var base_item := Equipment.new()
	base_item.piece_name = "Dagger"
	base_item.rarity = Equipment.Rarity.COMMON
	var t_epic := EquipmentRarityTier.new()
	t_epic.rarity = EquipmentRarityTier.Rarity.EPIC
	t_epic.might = 4.0
	base_item.rarity_tiers.append(t_epic)

	var rolled_item: Equipment = base_item.duplicate_with_rarity(Equipment.Rarity.EPIC)
	if base_item.rarity != Equipment.Rarity.COMMON:
		printerr("FAIL: Base blueprint item rarity was mutated!")
		return false
	if rolled_item.rarity != Equipment.Rarity.EPIC:
		printerr("FAIL: Rolled item should be EPIC, got: ", rolled_item.rarity)
		return false
	if rolled_item.get_stat_boosts().get("might", 0.0) != 4.0:
		printerr("FAIL: Rolled item does not have Epic stat boosts!")
		return false

	print("   PASSED: duplicate_with_rarity creates independent instances safely.")
	return true

func test_existing_equipment_compatibility() -> bool:
	print("-> Testing Backward Compatibility with Existing Equipment Resources...")
	var test_files: Array[String] = [
		"res://tiles/equipment/short_sword.tres",
		"res://tiles/equipment/block.tres",
		"res://tiles/equipment/punch.tres",
		"res://tiles/equipment/bandage.tres"
	]
	for path in test_files:
		var eq = load(path)
		if eq == null:
			printerr("FAIL: Could not load: ", path)
			return false
		if not (eq is Equipment):
			printerr("FAIL: Not an Equipment instance: ", path)
			return false
		if eq.rarity != Equipment.Rarity.COMMON:
			printerr("FAIL: Legacy item should default to COMMON: ", path)
			return false
		if not eq.get_stat_boosts().is_empty():
			printerr("FAIL: Legacy item should have 0 stat boosts: ", path)
			return false
		var desc: String = eq.get_effect_description()
		if desc == "":
			printerr("FAIL: Empty description on legacy item: ", path)
			return false

	print("   PASSED: All existing equipment resources load and function flawlessly.")
	return true
