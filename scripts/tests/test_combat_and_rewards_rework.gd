extends Node

var tests_passed: int = 0
var tests_failed: int = 0

func _ready() -> void:
	print("==================================================")
	print("RUNNING LORETILES COMBAT & REWARDS REWORK TESTS")
	print("==================================================")
	await _run_all_tests()
	print("==================================================")
	print("RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	if tests_failed == 0:
		print("[ALL REWORK TESTS PASSED]")
	else:
		print("[SOME REWORK TESTS FAILED]")
	print("==================================================")
	get_tree().quit(0 if tests_failed == 0 else 1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] " + message)
	else:
		tests_failed += 1
		push_error("  [FAIL] " + message)
		print("  [FAIL] " + message)

func _make_test_equipment(eq_name: String, dmg: float, cost: int = 1) -> Equipment:
	var eq := Equipment.new()
	eq.piece_name = eq_name
	eq.base_damage = dmg
	eq.damage_stat_scaling = Equipment.StatScaling.NONE
	eq.slot_cost = cost
	return eq

func _run_all_tests() -> void:
	_test_shared_entity_resource()
	_test_six_slot_capacity_and_sequential_chains()
	_test_trigger_budgets_and_blocked_entries()
	_test_monster_tracks_and_colorless_fallback()
	await _test_board_smart_beast_hybrid_and_bombs()
	await _test_enemy_target_preview_and_cascade_suppression()
	await _test_direct_equipment_rewards_and_three_source_draft()
	_test_per_action_critical_hits()
	_test_unified_buffs_and_debuffs()
	_test_save_load_persistence()

# ------------------------------------------------------------------------------
# 1. Shared Entity Foundation
# ------------------------------------------------------------------------------
func _test_shared_entity_resource() -> void:
	print("\n--- 1. Shared Entity Foundation ---")
	var player := PlayerResource.new()
	var enemy := EnemyResource.new()
	_assert(player is EntityResource, "PlayerResource extends EntityResource")
	_assert(enemy is EntityResource, "EnemyResource extends EntityResource")
	_assert(player.agility == 2, "PlayerResource defaults to agility = 2")
	_assert(player.speed == 2, "PlayerResource speed alias returns agility (2)")
	_assert(player.max_energy == 2, "PlayerResource default max_energy = 2 (1 + floor(2/2))")
	_assert(enemy.agility == 1, "EnemyResource defaults to agility = 1")
	_assert(enemy.speed == 1, "EnemyResource speed alias returns agility (1)")
	_assert(enemy.max_energy == 1, "EnemyResource default max_energy = 1 (1 + floor(1/2))")

	# Max energy scaling formula tests: max(1, 1 + int(floor(agility / 2.0)))
	player.agility = 0
	_assert(player.max_energy == 1, "Agility 0 -> max_energy = 1")
	player.agility = 1
	_assert(player.max_energy == 1, "Agility 1 -> max_energy = 1")
	player.agility = 2
	_assert(player.max_energy == 2, "Agility 2 -> max_energy = 2")
	player.agility = 3
	_assert(player.max_energy == 2, "Agility 3 -> max_energy = 2")
	player.agility = 4
	_assert(player.max_energy == 3, "Agility 4 -> max_energy = 3")
	player.agility = 6
	_assert(player.max_energy == 4, "Agility 6 -> max_energy = 4")
	player.agility = -5
	_assert(player.max_energy == 1, "Agility negative (-5) respects hard floor of 1")

	# Backward compat setter alias test
	player.speed = 4
	_assert(player.agility == 4, "Setting speed=4 updates agility to 4")
	_assert(player.max_energy == 3, "Agility 4 derived max_energy = 3")
	player.agility = 2

	# Moves_left strict clamping to max_energy
	player.agility = 2 # max_energy = 2
	player.moves_left = 10
	_assert(player.moves_left == 2, "moves_left capped at max_energy (2) when assigned 10")
	player.modify_stat("moves_left", 5)
	_assert(player.moves_left == 2, "modify_stat('moves_left', +5) capped at max_energy (2)")
	player.modify_stat("moves_left", -1)
	_assert(player.moves_left == 1, "modify_stat('moves_left', -1) decrements to 1")
	player.modify_stat("moves_left", -10)
	_assert(player.moves_left == 0, "modify_stat('moves_left', -10) clamps floor to 0")

	# Agility change clamps existing moves_left if exceeding new max_energy
	player.agility = 4 # max_energy = 3
	player.moves_left = 3
	_assert(player.moves_left == 3, "moves_left can reach 3 when max_energy is 3")
	player.agility = 2 # max_energy = 2
	_assert(player.moves_left == 2, "Reducing agility from 4 to 2 automatically clamps moves_left down to 2")

	# Verify enemy lifesteal heals the enemy (attacker) and NOT Global.cur_char
	player.max_health = 30.0
	player.cur_health = 20.0
	enemy.max_health = 30.0
	enemy.cur_health = 10.0
	enemy.life_steal = 0.5
	Global.cur_char = player
	Global.cur_enemy = enemy

	player.take_damage(10.0, false, 0, enemy)
	_assert(is_equal_approx(player.cur_health, 10.0), "Player took 10 damage from enemy")
	_assert(is_equal_approx(enemy.cur_health, 15.0), "Enemy lifesteal healed the enemy (+5 HP), not the player")

	# Verify equipment cooldown reduction reads from the acting entity
	enemy.cooldown_reduction = 1
	enemy.spirit = 4.0 # +1 CDR from spirit * 0.25
	var cd_eq := _make_test_equipment("Heavy Slam", 5.0)
	cd_eq.cooldown_turns = 3
	cd_eq.on_triggered(enemy)
	_assert(cd_eq.current_cooldown == 1, "Equipment on_triggered(enemy) uses enemy CDR (3 - 2 = 1)")

# ------------------------------------------------------------------------------
# 2. 5 Normal Slots + 1 Ultimate Slot Capacity & Chain Execution
# ------------------------------------------------------------------------------
func _test_six_slot_capacity_and_sequential_chains() -> void:
	print("\n--- 2. 5-Slot Normal + 1 Ultimate Slot Capacity & Sequential Chains ---")
	var player := PlayerResource.new()
	player.ensure_loadout_tracks()
	var red_track: ColorLoadoutTrack = player.get_track_for_color(Global.TileColor.RED)
	var blue_track: ColorLoadoutTrack = player.get_track_for_color(Global.TileColor.BLUE)
	_assert(red_track != null and red_track.max_slots == 5, "Player Red track defaults to 5 open normal slots")

	var eq_a := _make_test_equipment("A", 2.0, 2)
	var eq_b := _make_test_equipment("B", 3.0, 2)
	var eq_c := _make_test_equipment("C", 4.0, 1)
	_assert(red_track.equip_modifier(eq_a), "Equipped A (cost 2) into 5-slot track")
	_assert(red_track.equip_modifier(eq_b), "Equipped B (cost 2) into 5-slot track")
	_assert(red_track.equip_modifier(eq_c), "Equipped C (cost 1) into 5-slot track")
	_assert(red_track.get_used_slots() == 5 and red_track.get_remaining_slots() == 0, "5-slot capacity accounting (2+2+1 = 5 used, 0 remaining)")
	_assert(not red_track.can_fit(_make_test_equipment("D", 1.0, 1)), "6th normal slot point is rejected when 5/5 normal slots are full")

	# Ultimate slot restrictions
	var ult_skill := _make_test_equipment("Red Comet", 15.0, 1)
	ult_skill.is_ultimate = true
	var normal_skill := _make_test_equipment("Normal Slash", 5.0, 1)

	_assert(not red_track.equip_ultimate(normal_skill), "Non-ultimate cannot be equipped into the Ultimate slot")
	_assert(not red_track.equip_modifier(ult_skill), "Ultimate skill cannot be equipped into normal slots (1-5)")
	_assert(red_track.equip_ultimate(ult_skill), "Ultimate skill equipped successfully into dedicated slot 0")
	_assert(red_track.ultimate_skill == ult_skill, "Track ultimate_skill references the equipped ultimate")

	# Ultimate readiness at cycle start & visual states
	var dummy_ctx := MatchContext.new()
	dummy_ctx.base_color = Global.TileColor.RED
	dummy_ctx.match_count = 3

	_assert(red_track.is_ultimate_active_for_cycle == true, "Ultimate is active for cycle because all 5 skills are ready at reset start")
	_assert(red_track.get_ultimate_visual_state() == ColorLoadoutTrack.UltimateVisualState.ACTIVATED, "Ultimate slot shows ACTIVATED state (lighter U)")
	_assert(red_track.can_trigger_ultimate(dummy_ctx), "Ultimate can trigger when active for cycle")

	# Normal slot visual states (NEXT, NORMAL, DARK, EMPTY)
	red_track.next_entry_cursor = 0
	_assert(red_track.get_normal_slot_visual_state(0) == ColorLoadoutTrack.NormalSlotVisualState.NEXT, "Slot 0 (first skill A) is NEXT (lighter state)")
	_assert(red_track.get_normal_slot_visual_state(1) == ColorLoadoutTrack.NormalSlotVisualState.NEXT, "Slot 1 (part of A) is NEXT (lighter state)")
	_assert(red_track.get_normal_slot_visual_state(2) == ColorLoadoutTrack.NormalSlotVisualState.NORMAL, "Slot 2 (skill B) is NORMAL (ready)")
	_assert(red_track.get_normal_slot_visual_state(4) == ColorLoadoutTrack.NormalSlotVisualState.NORMAL, "Slot 4 (skill C) is NORMAL (ready)")

	# UI texture binding verification
	var test_slot_ui := ModifierSlotUI.new()
	test_slot_ui.setup_slot(null, 100, red_track, 0, false, false, false) # Next
	_assert(test_slot_ui.texture_rect.visible == true and test_slot_ui.texture_rect.texture == ModifierSlotUI.TEX_CRISTAL_BRIGHT, "UI binds bright crystal texture to NEXT slot")

	var empty_slot_ui := ModifierSlotUI.new()
	var empty_track := ColorLoadoutTrack.new()
	empty_track.color = 100
	_assert(empty_track.get_normal_slot_visual_state(0) == ColorLoadoutTrack.NormalSlotVisualState.EMPTY, "Unassigned slot returns EMPTY visual state")
	empty_slot_ui.setup_slot(null, 100, empty_track, 0, false, false, false)
	_assert(empty_slot_ui.texture_rect.visible == false, "Empty slot texture_rect is invisible so base socket shows through")

	# When skill A is used: becomes DARK state
	red_track.record_skill_activated(eq_a)
	_assert(red_track.get_normal_slot_visual_state(0) == ColorLoadoutTrack.NormalSlotVisualState.DARK, "Slot 0 becomes DARK once used")
	_assert(red_track.get_normal_slot_visual_state(1) == ColorLoadoutTrack.NormalSlotVisualState.DARK, "Slot 1 becomes DARK once used")
	test_slot_ui.setup_slot(eq_a, 100, red_track, 0, false, false, false)
	_assert(test_slot_ui.texture_rect.visible == true and test_slot_ui.texture_rect.texture == ModifierSlotUI.TEX_CRISTAL_DARK, "UI binds dark crystal texture to DARK slot")
	test_slot_ui.free()
	empty_slot_ui.free()

	# Cooldown ticks down on loadout reset, and determines ultimate readiness for next cycle
	eq_a.current_cooldown = 2
	red_track.reset_activation_cycle()
	_assert(eq_a.current_cooldown == 1, "Cooldown ticks down on loadout reset (2 -> 1)")
	_assert(red_track.is_ultimate_active_for_cycle == false, "Ultimate is NOT active for new cycle because skill A was on cooldown at reset start")
	_assert(red_track.get_ultimate_visual_state() == ColorLoadoutTrack.UltimateVisualState.NORMAL, "Ultimate visual state is NORMAL (not lighter/activated) when unready")
	_assert(not red_track.can_trigger_ultimate(dummy_ctx), "Ultimate cannot trigger when not active for cycle")

	# Ticking down remaining cooldown to 0 restores readiness at next reset
	red_track.reset_activation_cycle()
	_assert(eq_a.current_cooldown == 0, "Cooldown ticked to 0 on next loadout reset")
	_assert(red_track.is_ultimate_active_for_cycle == true, "Ultimate becomes active again once all skills are ready at reset start")

	# Test: Reset happens when no more tiles can be activated in the color track
	var partial_track := ColorLoadoutTrack.new()
	partial_track.color = 100
	var skill_1 := _make_test_equipment("Skill1", 5.0, 1)
	var skill_2 := _make_test_equipment("Skill2", 5.0, 1)
	skill_2.current_cooldown = 2
	partial_track.equip_modifier(skill_1)
	partial_track.equip_modifier(skill_2)

	_assert(partial_track.has_activatable_tiles() == true, "Track has activatable tiles because skill_1 is ready")
	partial_track.record_skill_activated(skill_1)
	_assert(partial_track.has_activatable_tiles() == false, "No more activatable tiles (skill_1 used, skill_2 on cooldown)")
	partial_track.reset_activation_cycle()
	_assert(skill_2.current_cooldown == 1, "Reset on no more activatable tiles ticks cooldown (2 -> 1)")
	_assert(partial_track.has_activatable_tiles() == true, "After reset, skill_1 is ready again")
	partial_track.record_skill_activated(skill_1)
	_assert(partial_track.has_activatable_tiles() == false, "Skill 1 used again, skill 2 still on cooldown")
	partial_track.reset_activation_cycle()
	_assert(skill_2.current_cooldown == 0, "Second reset ticks skill 2 cooldown to 0")
	_assert(partial_track.has_activatable_tiles() == true, "Now both skills are ready")

	# Bypass activation check test
	var bypass_ult := _make_test_equipment("Free Comet", 10.0, 1)
	bypass_ult.is_ultimate = true
	bypass_ult.bypass_activation_check = true
	red_track.equip_ultimate(bypass_ult)
	_assert(red_track.can_trigger_ultimate(dummy_ctx), "Ultimate with bypass_activation_check=true triggers regardless")
	red_track.equip_ultimate(ult_skill) # Restore strict ultimate

	# Sequential normal matches + ultimate at end of cycle: A -> B -> C -> ULT -> A
	red_track.next_entry_cursor = 0
	var fired_names: Array[String] = []
	for _i in range(5):
		var m: Equipment = red_track.step_next_entry()
		fired_names.append(m.piece_name)
	_assert(fired_names == ["A", "B", "C", "Red Comet", "A"], "Successive matches step A -> B -> C -> Red Comet (Ultimate) -> A")
	_assert(red_track.next_entry_cursor == 1, "After full cycle + 1 step, cursor points to B (index 1)")

	# Advance cursor to C (index 2), then execute a 4-tile match (2 triggers): C -> ULT, leaving A next
	red_track.next_entry_cursor = 2
	var ctx_4 := MatchContext.new()
	ctx_4.base_color = Global.TileColor.RED
	ctx_4.match_count = 4
	ctx_4.shape_type = "LINE_4"
	var budget_4: int = red_track.get_trigger_budget(ctx_4)
	_assert(budget_4 == 2, "4-tile match grants 2 triggers")

	var match4_fired: Array[String] = []
	for _i in range(budget_4):
		match4_fired.append(red_track.step_next_entry().piece_name)
	_assert(match4_fired == ["C", "Red Comet"], "4-tile match starting at C executes C then Red Comet")
	_assert(red_track.next_entry_cursor == 0, "After C then Ultimate, cursor wraps around leaving A next (index 0)")

	# Track independence: Blue track cursor was never touched
	_assert(blue_track.next_entry_cursor == 0, "Matching Red does not advance Blue track cursor")

	# Cursor lifetime: turn reset does NOT reset cursor; battle reset DOES reset cursor
	red_track.next_entry_cursor = 1
	player.reset_stats_at_beginning_of_turn()
	_assert(red_track.next_entry_cursor == 1, "Turn start does NOT reset next_entry_cursor")
	player.reset_modifiers_for_battle()
	_assert(red_track.next_entry_cursor == 0, "Battle start resets next_entry_cursor to 0")

# ------------------------------------------------------------------------------
# 3. Trigger Budgets (5+, L/T, Bombs) & Blocked Entry Consumption
# ------------------------------------------------------------------------------
func _test_trigger_budgets_and_blocked_entries() -> void:
	print("\n--- 3. Trigger Budgets & Blocked Entry Consumption ---")
	var track := ColorLoadoutTrack.new()
	var eq_a := _make_test_equipment("A", 2.0)
	var eq_b := _make_test_equipment("B_Blocked", 10.0)
	eq_b.trigger_condition = Equipment.TriggerCondition.MATCH_4_PLUS
	var eq_c := _make_test_equipment("C", 3.0)
	track.equip_modifier(eq_a)
	track.equip_modifier(eq_b)
	track.equip_modifier(eq_c)

	var ctx_3 := MatchContext.new()
	ctx_3.match_count = 3
	ctx_3.shape_type = "LINE_3"
	_assert(track.get_trigger_budget(ctx_3) == 1, "3-tile match = 1 trigger")

	var ctx_5 := MatchContext.new()
	ctx_5.match_count = 5
	ctx_5.shape_type = "LINE_5"
	_assert(track.get_trigger_budget(ctx_5) == 3, "5-tile match = 3 triggers (5 - 2)")

	var ctx_l5 := MatchContext.new()
	ctx_l5.match_count = 5
	ctx_l5.shape_type = "L_SHAPE"
	_assert(track.get_trigger_budget(ctx_l5) == 4, "5-tile L-shape match = 4 triggers ((5 - 2) + 1)")

	var ctx_t5 := MatchContext.new()
	ctx_t5.match_count = 5
	ctx_t5.shape_type = "T_SHAPE"
	_assert(track.get_trigger_budget(ctx_t5) == 4, "5-tile T-shape match = 4 triggers ((5 - 2) + 1)")

	# Test blocked equipment on a 3-tile match:
	# Cursor 0 (A) fires; Cursor 1 (B_Blocked requires 4+) cannot trigger on a 3-tile match,
	# so the trigger is still consumed and the cursor moves to Cursor 2 (C)!
	track.next_entry_cursor = 1
	var stepped: Equipment = track.step_next_entry()
	var did_fire: bool = stepped != null and stepped.can_trigger(ctx_3)
	_assert(stepped == eq_b and not did_fire, "Blocked entry B_Blocked fails condition on 3-tile match")
	_assert(track.next_entry_cursor == 2, "Blocked entry still consumes trigger and advances cursor to C (index 2)")

# ------------------------------------------------------------------------------
# 4. Monster Tracks & Colorless Fallback
# ------------------------------------------------------------------------------
func _test_monster_tracks_and_colorless_fallback() -> void:
	print("\n--- 4. Monster Tracks & Colorless Fallback ---")
	var boar: EnemyResource = load("res://enemies/minion/wild_boar/wild_boar_1.tres").duplicate(true)
	boar.ensure_loadout_tracks()
	_assert(boar.has_explicit_track_for_color(Global.TileColor.RED), "Boar has explicit Red track")
	_assert(boar.has_explicit_track_for_color(Global.TileColor.BLUE), "Boar has explicit Blue track")
	_assert(not boar.has_explicit_track_for_color(Global.TileColor.GREEN), "Boar does not have explicit Green track")

	var red_t := boar.get_track_for_color(Global.TileColor.RED)
	var blue_t := boar.get_track_for_color(Global.TileColor.BLUE)
	var green_t := boar.get_track_for_color(Global.TileColor.GREEN)
	var purple_t := boar.get_track_for_color(Global.TileColor.PURPLE)
	_assert(red_t != boar.colorless_fallback_track, "Boar Red routes to explicit Red track")
	_assert(blue_t != boar.colorless_fallback_track, "Boar Blue routes to explicit Blue track")
	_assert(green_t == boar.colorless_fallback_track, "Boar Green routes to colorless fallback track")
	_assert(purple_t == boar.colorless_fallback_track, "Boar Purple routes to colorless fallback track")

	var enemy_paths := [
		"res://enemies/minion/wild_boar/wild_boar_1.tres",
		"res://enemies/minion/bear_stravnica/bear_stravnica.tres",
		"res://enemies/minion/pesents/pesent_1.tres",
		"res://enemies/minion/vila/vila.tres",
		"res://enemies/minion/karjaliia_cap/karjaliia_cap_1.tres",
		"res://enemies/boss/lamia/lamia.tres"
	]
	for ep in enemy_paths:
		var er: EnemyResource = load(ep)
		_assert(er != null and not er.loot_table.is_empty(), "Authored monster resource loads cleanly with loot_table: " + ep.get_file())

# ------------------------------------------------------------------------------
# 5. Board AI: Smart, Beast, Hybrid, and Bomb Majority Color
# ------------------------------------------------------------------------------
func _test_board_smart_beast_hybrid_and_bombs() -> void:
	print("\n--- 5. Board AI (Smart, Beast, Hybrid) & Bomb Majority Color ---")
	var player: PlayerResource = load("res://players/warrior/warrior.tres").duplicate(true)
	player.reset_stats_at_beginning_of_game()
	var cap: EnemyResource = load("res://enemies/minion/karjaliia_cap/karjaliia_cap_1.tres").duplicate(true)
	cap.cur_health = cap.max_health
	cap.reset_stats_at_beginning_of_fight()

	# Verify Hybrid alternation per action
	_assert(cap.behavior_category == EnemyResource.BehaviorCategory.HYBRID, "Kardzaliia Capitan is HYBRID")
	var modes: Array[int] = []
	for _i in range(4):
		modes.append(int(cap.get_current_action_behavior()))
		cap.advance_hybrid_action_state()
	_assert(modes == [
		int(EnemyResource.BehaviorCategory.SMART),
		int(EnemyResource.BehaviorCategory.BEAST),
		int(EnemyResource.BehaviorCategory.SMART),
		int(EnemyResource.BehaviorCategory.BEAST)
	], "Hybrid monster switches between SMART and BEAST on every action")

	# Instantiate game_window to test real board resolution for Smart, Beast, and Bomb majority color
	Global.cur_char = player
	Global.set_up_enemy(cap)
	var gw_scene: PackedScene = load("res://scenes/game_window.tscn")
	var gw: GameMaster = gw_scene.instantiate()
	add_child(gw)
	await get_tree().create_timer(0.55).timeout

	var grd = gw.grd
	_assert(grd != null and grd.all_pieces.size() == grd.grd_width, "Combat board initialized cleanly")

	# Set controlled colors in a 3x3 area around (3, 3): 5 RED tiles, 2 BLUE tiles, 2 GREEN tiles
	var red_coords := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(3, 3)]
	var blue_coords := [Vector2i(4, 3), Vector2i(2, 4)]
	var green_coords := [Vector2i(3, 4), Vector2i(4, 4)]
	for c in red_coords:
		grd.all_pieces[c.x][c.y].setup_chromatic(Global.TileColor.RED)
	for c in blue_coords:
		grd.all_pieces[c.x][c.y].setup_chromatic(Global.TileColor.BLUE)
	for c in green_coords:
		grd.all_pieces[c.x][c.y].setup_chromatic(Global.TileColor.GREEN)

	var positions_3x3: Array[Vector2] = []
	for ofs in Global.cur_enemy.get_beast_destruction_shape():
		positions_3x3.append(Vector2(3 + ofs.x, 3 + ofs.y))

	var beast_ctx: MatchContext = grd.build_majority_color_context(positions_3x3, Global.cur_enemy, Global.cur_char, false)
	_assert(beast_ctx != null and beast_ctx.base_color == Global.TileColor.RED, "Beast 3x3 majority color is RED (5 of 9 tiles)")
	_assert(beast_ctx.match_count == 5, "Beast majority color count is 5")
	var enemy_red_track: ColorLoadoutTrack = Global.cur_enemy.get_track_for_color(beast_ctx.base_color)
	_assert(enemy_red_track.get_trigger_budget(beast_ctx) == 3, "Beast 5-tile majority color grants 3 sequential triggers (5 - 2)")

	var bomb_ctx: MatchContext = grd.build_majority_color_context(positions_3x3, Global.cur_char, Global.cur_enemy, true)
	_assert(bomb_ctx != null and bomb_ctx.is_bomb_clear and bomb_ctx.base_color == Global.TileColor.RED and bomb_ctx.match_count == 5, "Bomb clear uses identical majority-color rule (RED, count 5 -> 3 triggers)")

	# Execute enemy turn on the live board and verify player takes damage from monster's track
	var hp_before: float = Global.cur_char.cur_health
	var armor_before: float = Global.cur_char.cur_armor
	await gw._execute_match_context(beast_ctx)
	_assert(Global.cur_char.cur_health < hp_before or Global.cur_char.cur_armor < armor_before, "Monster sequential track execution dealt damage to player")
	_assert(enemy_red_track.next_entry_cursor == (3 % enemy_red_track.get_filled_entry_count()), "Monster track cursor advanced by 3 triggers with wraparound")

	gw.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------------------------
# 5b. Enemy Target Visualization & AOE Cascade Exclusion
# ------------------------------------------------------------------------------
func _test_enemy_target_preview_and_cascade_suppression() -> void:
	print("\n--- 5b. Enemy Target Visualization & AOE Cascade Exclusion ---")
	var player: PlayerResource = load("res://players/warrior/warrior.tres").duplicate(true)
	player.reset_stats_at_beginning_of_game()
	var cap: EnemyResource = load("res://enemies/minion/karjaliia_cap/karjaliia_cap_1.tres").duplicate(true)
	cap.cur_health = cap.max_health
	cap.reset_stats_at_beginning_of_fight()

	Global.cur_char = player
	Global.set_up_enemy(cap)
	var gw_scene: PackedScene = load("res://scenes/game_window.tscn")
	var gw: GameMaster = gw_scene.instantiate()
	add_child(gw)
	await get_tree().create_timer(0.55).timeout

	var grd = gw.grd
	_assert(grd != null, "Combat board valid for target preview tests")

	# 1. Test PieceClass visual highlight
	var test_piece: PieceClass = grd.all_pieces[3][3]
	test_piece.set_enemy_target_highlight(true)
	_assert(test_piece.is_enemy_target_highlighted == true, "Tile marked as enemy target")
	_assert(test_piece.base.modulate == Color(1.25, 0.75, 0.75, 1.0), "Tile applies danger reddish tint for enemy target")
	test_piece.set_enemy_target_highlight(false)
	_assert(test_piece.is_enemy_target_highlighted == false, "Tile unmarks enemy target")

	# 2. Test Beast Target Preview & Center Locking
	Global.cur_enemy.hybrid_next_is_beast = true
	grd.update_enemy_target_preview()
	var beast_cells: Array[Vector2i] = grd.current_enemy_target_cells
	_assert(not beast_cells.is_empty(), "Beast upcoming action highlights target cells on board")
	var locked_center: Vector2i = grd.planned_enemy_target_center
	_assert(locked_center != Vector2i(-1, -1), "Beast planned center is stored")
	var offsets: Array[Vector2i] = Global.cur_enemy.get_beast_destruction_shape()
	_assert(grd.get_or_choose_beast_target_center(offsets) == locked_center, "Enemy turn execution locks to previewed beast center")
	for c in beast_cells:
		var p: PieceClass = grd.all_pieces[c.x][c.y]
		_assert(p != null and p.is_enemy_target_highlighted, "Targeted cell (%d, %d) has active highlight" % [c.x, c.y])
	_assert(grd.enemy_attack_overlay != null and grd.enemy_attack_overlay._indicators.size() == beast_cells.size(), "EnemyAttackOverlay displays all active target borders")

	# 3. Test Smart Target Preview
	Global.cur_enemy.hybrid_next_is_beast = false
	grd.update_enemy_target_preview()
	var smart_cells: Array[Vector2i] = grd.current_enemy_target_cells
	_assert(smart_cells.size() == 2 or not smart_cells.is_empty(), "Smart upcoming action highlights target swap cells")
	_assert(grd.enemy_attack_overlay._indicators.size() == smart_cells.size(), "EnemyAttackOverlay updates to smart target swap cells")

	# 4. Clear Preview
	grd.clear_enemy_target_preview()
	_assert(grd.current_enemy_target_cells.is_empty(), "Clear preview removes all active cell targets")
	_assert(grd.enemy_attack_overlay._indicators.is_empty(), "EnemyAttackOverlay clears all indicators")

	# 5. Test Secondary Cascade Exclusion for Beast / AOE attacks
	# Ensure monster equipment only triggers on first tiles destroyed, not on secondary cascades
	var enemy_red_track: ColorLoadoutTrack = cap.get_track_for_color(Global.TileColor.RED)
	var cursor_before: int = enemy_red_track.next_entry_cursor
	var player_hp_before: float = player.cur_health

	# Create a secondary cascade match context (e.g. formed by tiles falling after AOE)
	var cascade_ctx := MatchContext.new()
	cascade_ctx.actor = cap
	cascade_ctx.target = player
	cascade_ctx.base_color = Global.TileColor.RED
	cascade_ctx.match_count = 3
	cascade_ctx.is_secondary_cascade = true
	cascade_ctx.ignore_equipment_triggers = true

	await gw._execute_match_context(cascade_ctx)

	_assert(player.cur_health == player_hp_before, "Secondary cascade does not damage player")
	_assert(enemy_red_track.next_entry_cursor == cursor_before, "Secondary cascade does not advance monster loadout cursor or trigger equipment")

	gw.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------------------------
# 6. Direct-Resource Rewards & 3-Option Post-Combat Draft
# ------------------------------------------------------------------------------
func _test_direct_equipment_rewards_and_three_source_draft() -> void:
	print("\n--- 6. Direct-Resource Rewards & 3-Source Draft ---")
	var player: PlayerResource = load("res://players/warrior/warrior.tres").duplicate(true)
	player.reset_stats_at_beginning_of_game()
	var boar: EnemyResource = load("res://enemies/minion/wild_boar/wild_boar_1.tres").duplicate(true)
	Global.cur_char = player
	Global.set_up_enemy(boar)

	# Check that warrior_tree.tres contains direct Equipment resources
	var combat_pool: Array[Resource] = player.active_reward_tree.get_combat_pool()
	var has_direct_equipment: bool = false
	for item in combat_pool:
		if item is Equipment:
			has_direct_equipment = true
			break
	_assert(has_direct_equipment, "Warrior RewardTree contains direct Equipment resources without Reward wrappers")
	_assert(not boar.loot_table.is_empty(), "Wild Boar has a populated monster loot_table")

	var reward_scene: PackedScene = load("res://scenes/reward_screen.tscn")
	var rs = reward_scene.instantiate()
	add_child(rs)
	await get_tree().process_frame

	# Test deterministic 3rd-slot source selection: < 0.5 chooses monster, >= 0.5 chooses class
	var draft_monster_3rd: Array[Resource] = rs.generate_three_choice_draft(boar.loot_table, combat_pool, 0.25)
	_assert(draft_monster_3rd.size() == 3, "Post-combat draft offers exactly 3 choices")
	_assert(rs.last_draft_sources == ["monster", "class", "monster"], "With roll 0.25 (< 0.5), sources are [monster, class, monster]")

	var draft_class_3rd: Array[Resource] = rs.generate_three_choice_draft(boar.loot_table, combat_pool, 0.75)
	_assert(rs.last_draft_sources == ["monster", "class", "class"], "With roll 0.75 (>= 0.5), sources are [monster, class, class]")

	# Verify resource isolation when drafting direct Equipment with rolled rarity
	var template_rush: Equipment = load("res://tiles/equipment/rush.tres")
	var orig_rarity: Equipment.Rarity = template_rush.rarity
	var drafted_epic_rush: Resource = RewardGrantHandler.prepare_draft_instance(template_rush, "EPIC")
	_assert(drafted_epic_rush is Equipment and drafted_epic_rush != template_rush, "Drafted Equipment is an independent instance")
	_assert((drafted_epic_rush as Equipment).rarity == Equipment.Rarity.EPIC, "Drafted Equipment takes the rolled rarity (EPIC)")
	_assert(template_rush.rarity == orig_rarity, "Source Equipment template in pool was NOT mutated by rarity roll")

	# Verify claiming direct Equipment adds an independent copy to the player
	var owned_before: int = player.get_all_owned_modifiers().size()
	RewardGrantHandler.grant_reward(drafted_epic_rush, true, player)
	var owned_after: int = player.get_all_owned_modifiers().size()
	_assert(owned_after == owned_before + 1, "Claiming direct Equipment reward grants 1 independent item to player")

	rs.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------------------------
# 7. Per-Action Critical Hits
# ------------------------------------------------------------------------------
func _test_per_action_critical_hits() -> void:
	print("\n--- 7. Per-Action Critical Hits ---")
	var player := PlayerResource.new()
	var enemy := EnemyResource.new()

	# 1. 0% crit chance never rolls true
	player.crit_chance = 0
	var zero_crit_procs: int = 0
	for _i in range(50):
		if player.roll_crit():
			zero_crit_procs += 1
	_assert(zero_crit_procs == 0, "0% crit chance never produces critical strike")

	# 2. 100% crit chance always rolls true
	player.crit_chance = 100
	var full_crit_procs: int = 0
	for _i in range(50):
		if player.roll_crit():
			full_crit_procs += 1
	_assert(full_crit_procs == 50, "100% crit chance always produces critical strike")

	# 3. Statistical distribution with 5% crit chance
	player.crit_chance = 5
	var count_5pct: int = 0
	for _i in range(1000):
		if player.roll_crit():
			count_5pct += 1
	_assert(count_5pct >= 15 and count_5pct <= 90, "5% crit chance rolls within expected statistical range (got " + str(count_5pct) + " / 1000)")

	# 4. Independent actor rolling: player vs enemy
	player.crit_chance = 0
	enemy.crit_chance = 100
	_assert(not player.roll_crit(), "Player with 0% crit does not crit")
	_assert(enemy.roll_crit(), "Enemy with 100% crit crits independently of player")

	# 5. Equipment damage scaling with explicit is_crit = true
	var attacker := PlayerResource.new()
	attacker.crit_chance = 0
	attacker.crit_mutly = 100.0 # +100% damage bonus = 2x total
	var dummy_target := EnemyResource.new()
	dummy_target.max_health = 100.0
	dummy_target.cur_health = 100.0

	var strike_eq := Equipment.new()
	strike_eq.piece_name = "Test Strike"
	strike_eq.base_damage = 10.0
	strike_eq.damage_stat_scaling = Equipment.StatScaling.NONE
	strike_eq.hit_count = 1

	# Normal non-crit hit: exactly 10 damage
	strike_eq.activate({
		"attacker": attacker,
		"target": dummy_target,
		"is_crit": false
	})
	_assert(is_equal_approx(dummy_target.cur_health, 90.0), "Non-crit equipment deals exact base damage (100 -> 90)")

	# Crit hit: 10 * 2.0 = 20 damage (90 -> 70)
	strike_eq.activate({
		"attacker": attacker,
		"target": dummy_target,
		"is_crit": true
	})
	_assert(is_equal_approx(dummy_target.cur_health, 70.0), "Critical equipment strike deals base * (1 + crit_mutly/100) (90 -> 70)")

	# 6. Manual criting property consumption
	strike_eq.criting = true
	strike_eq.activate({
		"attacker": attacker,
		"target": dummy_target
	})
	_assert(is_equal_approx(dummy_target.cur_health, 50.0), "Equipment with criting=true deals critical damage (70 -> 50)")
	_assert(strike_eq.criting == false, "Equipment criting flag resets to false after activation")

	# 7. Tile neutrality: board tile scene has no crit_shader or is_criting
	var tile_scene: PackedScene = load("res://tiles/tile.tscn")
	_assert(tile_scene != null, "Tile scene loads cleanly")
	var tile_instance = tile_scene.instantiate()
	_assert(not ("is_criting" in tile_instance), "Tile has no is_criting property")
	_assert(not ("crit_shader" in tile_instance), "Tile has no crit_shader property")
	tile_instance.queue_free()

# ------------------------------------------------------------------------------
# 8. Save/Load Persistence
# ------------------------------------------------------------------------------
func _test_save_load_persistence() -> void:
	print("\n--- 8. Save/Load Persistence ---")
	var user_dir_path := ProjectSettings.globalize_path("user://")
	if not DirAccess.dir_exists_absolute(user_dir_path):
		DirAccess.make_dir_recursive_absolute(user_dir_path)
	var test_save_path := "user://test_rework_save.tres"
	var prev_save_path: String = Global.save_path
	Global.save_path = test_save_path

	var player: PlayerResource = load("res://players/warrior/warrior.tres").duplicate(true)
	player.reset_stats_at_beginning_of_game()
	var red_track: ColorLoadoutTrack = player.get_track_for_color(Global.TileColor.RED)
	red_track.next_entry_cursor = 1
	player.active_reward_tree.unlocked_tags["test_tag_persisted"] = true

	var cap: EnemyResource = load("res://enemies/minion/karjaliia_cap/karjaliia_cap_1.tres").duplicate(true)
	cap.cur_health = cap.max_health
	cap.reset_stats_at_beginning_of_fight()
	cap.advance_hybrid_action_state() # hybrid_next_is_beast = true

	Global.cur_char = player
	Global.cur_enemy = cap
	Global.cur_scene = "res://scenes/locations_screen.tscn"
	Global.save()

	# Clear runtime state and reload
	Global.cur_char = null
	Global.cur_enemy = null
	Global.load_data()

	_assert(Global.cur_char != null, "Reloaded cur_char from save")
	var loaded_red: ColorLoadoutTrack = Global.cur_char.get_track_for_color(Global.TileColor.RED)
	_assert(loaded_red != null and loaded_red.max_slots == 5, "Reloaded Red track preserves 5-slot normal capacity")
	_assert(loaded_red.next_entry_cursor == 1, "Reloaded Red track preserves next_entry_cursor == 1")
	_assert(Global.cur_char.active_reward_tree.unlocked_tags.has("test_tag_persisted"), "Reloaded RewardTree preserves unlocked_tags")
	_assert(Global.cur_enemy != null and Global.cur_enemy.hybrid_next_is_beast == true, "Reloaded EnemyResource preserves hybrid_next_is_beast state")

	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	Global.save_path = prev_save_path

# ------------------------------------------------------------------------------
# 9. Unified Buffs & Debuffs System (Player & Enemy + UI)
# ------------------------------------------------------------------------------
func _test_unified_buffs_and_debuffs() -> void:
	print("\n--- 9. Unified Buffs & Debuffs System ---")
	var dodge_def: BuffRegistry.BuffDef = BuffRegistry.get_def("dodge")
	var combo_def: BuffRegistry.BuffDef = BuffRegistry.get_def("hand_combo")
	_assert(dodge_def != null and dodge_def.get_icon() != null, "BuffRegistry loads buff-dodge.png icon")
	_assert(combo_def != null and combo_def.get_icon() != null, "BuffRegistry loads buff-combo.png icon")
	_assert(BuffRegistry.normalize_id("dodging") == "dodge", "BuffRegistry normalizes 'dodging' -> 'dodge'")
	_assert(BuffRegistry.normalize_id("combo") == "hand_combo", "BuffRegistry normalizes 'combo' -> 'hand_combo'")

	var plr := PlayerResource.new()
	var enm := EnemyResource.new()
	plr.max_health = 50.0
	plr.cur_health = 50.0
	enm.max_health = 50.0
	enm.cur_health = 50.0

	# Test Player & Enemy buff API and property bridging
	plr.add_buff("dodge", 1)
	plr.add_buff("hand_combo", 3)
	_assert(plr.has_buff("dodge") and plr.dodging == true, "Player has_buff('dodge') syncs with plr.dodging")
	_assert(plr.get_buff_stacks("hand_combo") == 3 and plr.hand_combo == 3, "Player get_buff_stacks('hand_combo') syncs with plr.hand_combo")

	enm.modify_stat("dodging", true, false)
	enm.modify_stat("hand_combo", 4, false)
	_assert(enm.has_buff("dodge") and enm.dodging == true, "Enemy modify_stat('dodging') activates 'dodge' buff")
	_assert(enm.get_buff_stacks("hand_combo") == 4, "Enemy modify_stat('hand_combo') sets 'hand_combo' stacks to 4")

	# Test Dodge negating physical damage on both Player and Enemy
	var dealt_to_plr: float = plr.take_damage(15.0, false, 0, enm)
	_assert(is_equal_approx(dealt_to_plr, 0.0) and is_equal_approx(plr.cur_health, 50.0), "Player Dodge negates incoming physical attack")
	_assert(not plr.has_buff("dodge") and plr.dodging == false, "Player Dodge buff is consumed after dodging")

	var dealt_to_enm: float = enm.take_damage(20.0, false, 0, plr)
	_assert(is_equal_approx(dealt_to_enm, 0.0) and is_equal_approx(enm.cur_health, 50.0), "Enemy Dodge negates incoming physical attack")
	_assert(not enm.has_buff("dodge") and enm.dodging == false, "Enemy Dodge buff is consumed after dodging")

	# Test Custom Debuff Registration & Turn-Start Decay
	BuffRegistry.register_buff(
		"test_bleed",
		"Bleed",
		"res://assets/scene-assets/combat/buff-combo.png",
		true,
		true,
		false,
		1,
		"Loses stacks each turn."
	)
	enm.add_buff("test_bleed", 2)
	_assert(enm.get_buff_stacks("test_bleed") == 2, "Custom debuff 'test_bleed' applied with 2 stacks on Enemy")
	enm.tick_buffs_at_turn_start()
	_assert(enm.get_buff_stacks("test_bleed") == 1, "Turn start decays 'test_bleed' from 2 -> 1 and clears 'hand_combo'")
	_assert(enm.get_buff_stacks("hand_combo") == 0, "Turn start clears turn-scoped 'hand_combo' buff")

	# Test BuffContainer UI for both Player and Enemy
	var buff_scene: PackedScene = load("res://scenes/ui/buff_container.tscn")
	var plr_buff_ui: BuffContainer = buff_scene.instantiate() as BuffContainer
	var enm_buff_ui: BuffContainer = buff_scene.instantiate() as BuffContainer
	add_child(plr_buff_ui)
	add_child(enm_buff_ui)

	plr.clear_all_buffs()
	plr_buff_ui.bind_entity(plr)
	_assert(plr_buff_ui.get_active_slot_count() == 0, "BuffContainer shows 0 active slots when entity has no buffs")

	plr.set_buff("dodge", 1)
	plr.set_buff("hand_combo", 5)
	_assert(plr_buff_ui.get_active_slot_count() == 2, "BuffContainer reactively shows 2 active slots for Dodge + Combo")
	_assert(plr_buff_ui.get_slot_buff_id(0) == "dodge", "Slot 0 displays 'dodge'")
	var slot0_lbl: Label = plr_buff_ui.get_slot_node(0).get_node("StackLabel") as Label
	_assert(slot0_lbl.visible == false, "Single-stack Dodge hides stack number badge")
	_assert(plr_buff_ui.get_slot_buff_id(1) == "hand_combo" and plr_buff_ui.get_slot_stacks(1) == 5, "Slot 1 displays 'hand_combo' with 5 stacks")
	var slot1_lbl: Label = plr_buff_ui.get_slot_node(1).get_node("StackLabel") as Label
	_assert(slot1_lbl.visible == true and slot1_lbl.text == "5", "Combo slot displays stack count '5'")

	enm_buff_ui.bind_entity(enm)
	_assert(enm_buff_ui.get_active_slot_count() == 1 and enm_buff_ui.get_slot_buff_id(0) == "test_bleed", "Enemy BuffContainer displays active debuff")
	enm.remove_buff("test_bleed")
	_assert(enm_buff_ui.get_active_slot_count() == 0, "Enemy BuffContainer clears slot when debuff is removed")

	# Test 5xX dynamic row expansion when more than 10 buffs/debuffs are active
	plr.clear_all_buffs()
	for i in range(12):
		var extra_id := "test_buff_%d" % i
		BuffRegistry.register_buff(
			extra_id,
			"Test Buff %d" % i,
			"res://assets/scene-assets/combat/buff-dodge.png",
			false,
			false,
			true,
			0,
			"Test buff slot overflow."
		)
		plr.set_buff(extra_id, 1)
	_assert(plr_buff_ui.get_active_slot_count() == 12, "BuffContainer dynamically expands to display all 12 active buffs")
	var slot_10: Control = plr_buff_ui.get_slot_node(10)
	var slot_11: Control = plr_buff_ui.get_slot_node(11)
	_assert(slot_10 != null and slot_10.position == Vector2(0, 84), "11th buff (index 10) creates a new 3rd row at (0, 84)")
	_assert(slot_11 != null and slot_11.position == Vector2(42, 84), "12th buff (index 11) sits on 3rd row col 1 at (42, 84)")

	plr_buff_ui.queue_free()
	enm_buff_ui.queue_free()
