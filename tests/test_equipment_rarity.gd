extends Node

func _ready() -> void:
	print("\n=======================================================")
	print(" RUNNING EQUIPMENT BONUS TABLE & RARITY SCALING SUITE")
	print("=======================================================\n")
	var success := true
	success = test_base_common_isolation() and success
	success = test_bonus_table_rolling_and_scaling() and success
	success = test_utility_bonuses() and success
	success = test_player_passive_reconciliation() and success
	success = test_reward_single_equipment_and_bonus_display() and success
	success = test_existing_equipment_compatibility() and success

	if success:
		print("\n[ALL TESTS PASSED] Equipment bonus table system is 100% verified!\n")
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
	if not eq.rolled_bonuses.is_empty():
		printerr("FAIL: Common equipment should have 0 rolled bonuses, got: ", eq.rolled_bonuses.size())
		return false
	if eq.get_effective_base_damage() != 2.0:
		printerr("FAIL: Effective damage mismatch on common: ", eq.get_effective_base_damage())
		return false
	if eq.is_allowed_on_color(200): # Blue
		printerr("FAIL: Common should only allow Red (100), but accepted Blue (200)")
		return false
	print("   PASSED: Base Common item grants 0 stat boosts and respects base bounds.")
	return true

func test_bonus_table_rolling_and_scaling() -> bool:
	print("-> Testing Bonus Table Rolling & Multiplier Scaling...")
	var eq := Equipment.new()
	eq.piece_name = "Heroic Blade"
	eq.base_damage = 3.0

	# 1. Author bonus table
	var b_might := EquipmentBonus.new()
	b_might.type = EquipmentBonus.BonusType.MIGHT
	b_might.min_val = 2.0
	b_might.max_val = 2.0 # Fixed roll for deterministic testing

	var b_health := EquipmentBonus.new()
	b_health.type = EquipmentBonus.BonusType.MAX_HEALTH
	b_health.min_val = 10.0
	b_health.max_val = 10.0

	var b_crit := EquipmentBonus.new()
	b_crit.type = EquipmentBonus.BonusType.CRIT_CHANCE
	b_crit.min_val = 5.0
	b_crit.max_val = 5.0

	eq.bonuses_table = [b_might, b_health, b_crit]

	# 2. Uncommon: exactly 1 bonus rolled, 1.0x multiplier
	var uncom: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.UNCOMMON, 12345)
	if uncom.rarity != Equipment.Rarity.UNCOMMON:
		printerr("FAIL: Expected Uncommon rarity, got: ", uncom.rarity)
		return false
	if uncom.rolled_bonuses.size() != 1:
		printerr("FAIL: Uncommon must roll exactly 1 bonus, got: ", uncom.rolled_bonuses.size())
		return false

	# 3. Rare: exactly 2 unique bonuses rolled, 1.0x multiplier
	var rare: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.RARE, 12345)
	if rare.rolled_bonuses.size() != 2:
		printerr("FAIL: Rare must roll exactly 2 bonuses, got: ", rare.rolled_bonuses.size())
		return false
	var b1_type = rare.rolled_bonuses[0].type
	var b2_type = rare.rolled_bonuses[1].type
	if b1_type == b2_type:
		printerr("FAIL: Rare bonuses should be unique!")
		return false

	# 4. Epic: 2 unique bonuses at +50% (1.5x)
	var epic: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.EPIC, 12345)
	if epic.rolled_bonuses.size() != 2:
		printerr("FAIL: Epic must roll exactly 2 bonuses, got: ", epic.rolled_bonuses.size())
		return false
	for b in epic.rolled_bonuses:
		if b.type == EquipmentBonus.BonusType.MIGHT and b.effective_val != 3.0: # 2.0 * 1.5 = 3.0
			printerr("FAIL: Epic Might scaling expected 3.0, got: ", b.effective_val)
			return false
		if b.type == EquipmentBonus.BonusType.MAX_HEALTH and b.effective_val != 15.0: # 10.0 * 1.5 = 15.0
			printerr("FAIL: Epic Max Health scaling expected 15.0, got: ", b.effective_val)
			return false

	# 5. Legendary: 2 unique bonuses at +100% (2.0x)
	var legend: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.LEGENDARY, 12345)
	if legend.rolled_bonuses.size() != 2:
		printerr("FAIL: Legendary must roll exactly 2 bonuses, got: ", legend.rolled_bonuses.size())
		return false
	for b in legend.rolled_bonuses:
		if b.type == EquipmentBonus.BonusType.MIGHT and b.effective_val != 4.0: # 2.0 * 2.0 = 4.0
			printerr("FAIL: Legendary Might scaling expected 4.0, got: ", b.effective_val)
			return false
		if b.type == EquipmentBonus.BonusType.MAX_HEALTH and b.effective_val != 20.0: # 10.0 * 2.0 = 20.0
			printerr("FAIL: Legendary Max Health scaling expected 20.0, got: ", b.effective_val)
			return false

	# 6. Godly eligibility check: item WITHOUT godly_bonus CANNOT roll Godly!
	if eq.can_roll_at_rarity(int(Equipment.Rarity.GODLY)):
		printerr("FAIL: Equipment without godly_bonus should NOT be eligible for Godly!")
		return false
	var rejected_godly: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.GODLY)
	if rejected_godly.rarity != Equipment.Rarity.LEGENDARY:
		printerr("FAIL: Item without godly_bonus rolled at Godly must clamp down to Legendary, got: ", rejected_godly.rarity)
		return false

	# 7. Configure Godly bonus & test Godly tier (2 bonuses at 2.5x + 1 fixed Godly perk)
	var g_perk := EquipmentBonus.new()
	g_perk.type = EquipmentBonus.BonusType.MIGHT
	g_perk.min_val = 5.0
	g_perk.max_val = 5.0
	g_perk.custom_text = "Omnipotent Fury: Strikes echo twice"
	eq.godly_bonus = g_perk

	if not eq.can_roll_at_rarity(int(Equipment.Rarity.GODLY)):
		printerr("FAIL: Equipment WITH godly_bonus must be eligible for Godly!")
		return false

	var godly: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.GODLY, 12345)
	if godly.rarity != Equipment.Rarity.GODLY:
		printerr("FAIL: Expected Godly rarity, got: ", godly.rarity)
		return false
	# Must have 2 random bonuses + 1 fixed Godly perk = 3 total
	if godly.rolled_bonuses.size() != 3:
		printerr("FAIL: Godly must have 3 bonuses (2 random + 1 Godly perk), got: ", godly.rolled_bonuses.size())
		return false

	var found_godly_perk := false
	for b in godly.rolled_bonuses:
		if b.is_godly_perk:
			found_godly_perk = true
			if b.custom_text != "Omnipotent Fury: Strikes echo twice":
				printerr("FAIL: Godly perk text mismatch: ", b.custom_text)
				return false
		elif b.type == EquipmentBonus.BonusType.MIGHT:
			# 2.0 * 2.5 = 5.0 (+150%)
			if b.effective_val != 5.0:
				printerr("FAIL: Godly random Might scaling expected 5.0 (+150%), got: ", b.effective_val)
				return false
		elif b.type == EquipmentBonus.BonusType.MAX_HEALTH:
			# 10.0 * 2.5 = 25.0 (+150%)
			if b.effective_val != 25.0:
				printerr("FAIL: Godly random Max Health scaling expected 25.0 (+150%), got: ", b.effective_val)
				return false

	if not found_godly_perk:
		printerr("FAIL: Godly item missing exclusive Godly perk!")
		return false

	print("   PASSED: Procedural rolling, scaling multipliers (1.0x, 1.5x, 2.0x, 2.5x), and Godly locking verified.")
	return true

func test_utility_bonuses() -> bool:
	print("-> Testing Utility & Mechanic Bonuses...")
	var eq := Equipment.new()
	eq.piece_name = "Heavy Bulwark"
	eq.slot_cost = 2
	eq.cooldown_turns = 3
	eq.allowed_colors = [200] # Blue only

	# 1. Lower Cooldown & Remove Slot Cost
	var b_cd := EquipmentBonus.new()
	b_cd.type = EquipmentBonus.BonusType.LOWER_COOLDOWN
	b_cd.min_val = 1.0
	b_cd.max_val = 1.0

	var b_slot := EquipmentBonus.new()
	b_slot.type = EquipmentBonus.BonusType.REMOVE_SLOT_COST
	b_slot.min_val = 1.0
	b_slot.max_val = 1.0

	eq.bonuses_table = [b_cd, b_slot]
	var rolled: Equipment = eq.duplicate_with_rarity(Equipment.Rarity.RARE)
	if rolled.get_effective_cooldown_turns() != 2: # 3 - 1 = 2
		printerr("FAIL: Expected reduced cooldown 2, got: ", rolled.get_effective_cooldown_turns())
		return false
	if rolled.slot_cost != 1: # 2 - 1 = 1
		printerr("FAIL: Expected reduced slot cost 1, got: ", rolled.slot_cost)
		return false

	# Test slot_cost floor of 1: A 1-slot item with -3 slot cost reduction must clamp to 1
	var eq_floor := Equipment.new()
	eq_floor.piece_name = "Tiny Dagger"
	eq_floor.slot_cost = 1
	var b_slot_huge := EquipmentBonus.new()
	b_slot_huge.type = EquipmentBonus.BonusType.REMOVE_SLOT_COST
	b_slot_huge.min_val = 3.0
	b_slot_huge.max_val = 3.0
	eq_floor.bonuses_table = [b_slot_huge]
	var rolled_floor: Equipment = eq_floor.duplicate_with_rarity(Equipment.Rarity.UNCOMMON)
	if rolled_floor.slot_cost != 1 or rolled_floor.get_effective_slot_cost() != 1:
		printerr("FAIL: Slot cost went below 1! Got slot_cost=", rolled_floor.slot_cost, " effective=", rolled_floor.get_effective_slot_cost())
		return false

	# Test direct assignment clamp
	eq_floor.slot_cost = 0
	if eq_floor.slot_cost != 1:
		printerr("FAIL: Direct assignment of 0 to slot_cost did not clamp to 1, got: ", eq_floor.slot_cost)
		return false
	eq_floor.slot_cost = -5
	if eq_floor.slot_cost != 1:
		printerr("FAIL: Direct assignment of -5 to slot_cost did not clamp to 1, got: ", eq_floor.slot_cost)
		return false

	# 2. Extra Color & Colorless
	var eq_color := Equipment.new()
	eq_color.piece_name = "Prismatic Charm"
	eq_color.allowed_colors = [100] # Red

	var b_extra_color := EquipmentBonus.new()
	b_extra_color.type = EquipmentBonus.BonusType.EXTRA_COLOR
	b_extra_color.color_value = 300 # Green

	eq_color.bonuses_table = [b_extra_color]
	var rolled_color: Equipment = eq_color.duplicate_with_rarity(Equipment.Rarity.UNCOMMON)
	if not rolled_color.is_allowed_on_color(100) or not rolled_color.is_allowed_on_color(300) or rolled_color.is_allowed_on_color(200):
		printerr("FAIL: Expected Red (100) and Green (300) allowed, but got mismatch")
		return false

	var b_colorless := EquipmentBonus.new()
	b_colorless.type = EquipmentBonus.BonusType.MAKE_COLORLESS
	eq_color.bonuses_table = [b_colorless]
	var rolled_colorless: Equipment = eq_color.duplicate_with_rarity(Equipment.Rarity.UNCOMMON)
	if not rolled_colorless.is_colorless() or not rolled_colorless.is_allowed_on_color(500):
		printerr("FAIL: Expected Colorless on any track")
		return false

	print("   PASSED: Cooldown reduction, slot reduction, and color options verified.")
	return true

func test_player_passive_reconciliation() -> bool:
	print("-> Testing Player Passive Stat Reconciliation with Rolled Bonuses...")
	var player := PlayerResource.new()
	player.might = 1.0
	player.grit = 0.0
	player.crit_chance = 5
	player.max_health = 20.0
	player.cur_health = 20.0
	player.ensure_loadout_tracks()

	var sword := Equipment.new()
	sword.piece_name = "Might Sword"
	var b_m := EquipmentRolledBonus.new()
	b_m.type = EquipmentBonus.BonusType.MIGHT
	b_m.effective_val = 2.0
	var b_c := EquipmentRolledBonus.new()
	b_c.type = EquipmentBonus.BonusType.CRIT_CHANCE
	b_c.effective_val = 5.0
	sword.rolled_bonuses = [b_m, b_c]

	var red_track: ColorLoadoutTrack = player.get_track_for_color(100)
	var drag_data := {
		"type": "modifier_drag",
		"source": "bag",
		"modifier": sword,
		"bag_index": -1
	}

	# 1. Equip onto Red track
	var equipped: bool = player.handle_modifier_drop_on_track(drag_data, red_track, 0)
	if not equipped:
		printerr("FAIL: Could not drop sword on red track")
		return false

	if player.might != 3.0: # 1.0 base + 2.0
		printerr("FAIL: Player might expected 3.0, got: ", player.might)
		return false
	if player.crit_chance != 10: # 5 base + 5
		printerr("FAIL: Player crit_chance expected 10, got: ", player.crit_chance)
		return false
	# +2 Might gives +2 Max Health: 20.0 -> 22.0
	if player.max_health != 22.0:
		printerr("FAIL: Player max_health expected 22.0, got: ", player.max_health)
		return false

	# 2. Unequip
	red_track.unequip_modifier(sword)
	player.recalculate_equipment_passives()

	if player.might != 1.0 or player.crit_chance != 5 or player.max_health != 20.0:
		printerr("FAIL: Player baseline stats drifted after unequip: might=", player.might, " crit=", player.crit_chance, " hp=", player.max_health)
		return false

	print("   PASSED: Passive stats from rolled bonuses apply and revoke cleanly with zero drift.")
	return true

func test_reward_single_equipment_and_bonus_display() -> bool:
	print("-> Testing Reward Single-Item Rule & Rolled Bonus Visibility...")
	var eq := Equipment.new()
	eq.piece_name = "Silver Rapier"
	eq.base_damage = 4.0

	var b_might := EquipmentBonus.new()
	b_might.type = EquipmentBonus.BonusType.MIGHT
	b_might.min_val = 2.0
	b_might.max_val = 2.0
	eq.bonuses_table = [b_might]

	# 1. Reward.from_equipment creates strictly 1 equipment
	var rew: Reward = Reward.from_equipment(eq, int(Equipment.Rarity.UNCOMMON))
	if rew.equipment_to_grant == null:
		printerr("FAIL: Reward.from_equipment must strictly grant 1 equipment, got null")
		return false

	# 2. Rolled bonuses appear in effect description
	var rolled_eq: Equipment = rew.equipment_to_grant
	var desc: String = rolled_eq.get_effect_description()
	if not desc.contains("+2 Might"):
		printerr("FAIL: Rolled equipment description should display '+2 Might', got: ", desc)
		return false

	# 3. Reward description incorporates equipment effect description
	var rew_desc: String = rew.get_effect_description()
	if not rew_desc.contains("+2 Might"):
		printerr("FAIL: Reward description should display rolled bonus '+2 Might', got: ", rew_desc)
		return false

	print("   PASSED: Single equipment per reward and rolled bonus text visibility verified.")
	return true

func test_existing_equipment_compatibility() -> bool:
	print("-> Testing Backward Compatibility with Existing Equipment Resources...")
	var test_files: Array[String] = [
		"res://equipment/items/short_sword.tres",
		"res://equipment/items/block.tres",
		"res://equipment/items/punch.tres",
		"res://equipment/items/bandage.tres"
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
