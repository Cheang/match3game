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
	_assert(player.speed == 2, "PlayerResource defaults to speed = 2")
	_assert(enemy.speed == 1, "EnemyResource defaults to speed = 1")

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
# 2. 6-Slot Capacity & Sequential Chain Execution
# ------------------------------------------------------------------------------
func _test_six_slot_capacity_and_sequential_chains() -> void:
	print("\n--- 2. 6-Slot Capacity & Sequential Chains ---")
	var player := PlayerResource.new()
	player.ensure_loadout_tracks()
	var red_track: ColorLoadoutTrack = player.get_track_for_color(Global.TileColor.RED)
	var blue_track: ColorLoadoutTrack = player.get_track_for_color(Global.TileColor.BLUE)
	_assert(red_track != null and red_track.max_slots == 6, "Player Red track defaults to 6 open slots")

	var eq_a := _make_test_equipment("A", 2.0, 2)
	var eq_b := _make_test_equipment("B", 3.0, 2)
	var eq_c := _make_test_equipment("C", 4.0, 2)
	_assert(red_track.equip_modifier(eq_a), "Equipped A (cost 2) into 6-slot track")
	_assert(red_track.equip_modifier(eq_b), "Equipped B (cost 2) into 6-slot track")
	_assert(red_track.equip_modifier(eq_c), "Equipped C (cost 2) into 6-slot track")
	_assert(red_track.get_used_slots() == 6 and red_track.get_remaining_slots() == 0, "6-slot capacity accounting (2+2+2 = 6 used, 0 remaining)")
	_assert(not red_track.can_fit( _make_test_equipment("D", 1.0, 1) ), "7th slot point is rejected when 6/6 slots are full")

	# Sequential normal matches (1 trigger each): A -> B -> C -> A
	var fired_names: Array[String] = []
	for _i in range(4):
		var m: Equipment = red_track.step_next_entry()
		fired_names.append(m.piece_name)
	_assert(fired_names == ["A", "B", "C", "A"], "Successive normal matches execute A -> B -> C -> A")
	_assert(red_track.next_entry_cursor == 1, "After A->B->C->A, cursor points to B (index 1)")

	# Advance cursor to C (index 2), then execute a 4-tile match (2 triggers): C -> A, leaving B next
	red_track.next_entry_cursor = 2
	var ctx_4 := MatchContext.new()
	ctx_4.base_color = Global.TileColor.RED
	ctx_4.match_count = 4
	ctx_4.shape_type = "LINE_4"
	var budget_4: int = red_track.get_trigger_budget(ctx_4)
	_assert(budget_4 == 2, "4-tile match grants 2 triggers")

	var preview_4: Array[int] = red_track.peek_firing_indices(ctx_4, player)
	_assert(preview_4 == [2, 0], "Preview from cursor C for 4-tile match highlights [2, 0] without mutating cursor")
	_assert(red_track.next_entry_cursor == 2, "Cursor remains at 2 after preview")

	var match4_fired: Array[String] = []
	for _i in range(budget_4):
		match4_fired.append(red_track.step_next_entry().piece_name)
	_assert(match4_fired == ["C", "A"], "4-tile match starting at C executes C then A")
	_assert(red_track.next_entry_cursor == 1, "After C then A, cursor leaves B next (index 1)")

	# Track independence: Blue track cursor was never touched
	_assert(blue_track.next_entry_cursor == 0, "Matching Red does not advance Blue track cursor")

	# Cursor lifetime: turn reset does NOT reset cursor; battle reset DOES reset cursor
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
	_assert(test_piece._enemy_target_border != null and test_piece._enemy_target_border.visible == true, "Tile creates and displays enemy target border")
	_assert(test_piece.base.modulate == Color(1.25, 0.75, 0.75, 1.0), "Tile applies danger reddish tint for enemy target")
	test_piece.set_enemy_target_highlight(false)
	_assert(test_piece.is_enemy_target_highlighted == false, "Tile unmarks enemy target")
	_assert(test_piece._enemy_target_border.visible == false, "Enemy target border hidden when unhighlighted")

	# 2. Test Beast Target Preview & Center Locking
	cap.hybrid_next_is_beast = true
	grd.update_enemy_target_preview()
	var beast_cells: Array[Vector2i] = grd.current_enemy_target_cells
	_assert(not beast_cells.is_empty(), "Beast upcoming action highlights target cells on board")
	var locked_center: Vector2i = grd.planned_enemy_target_center
	_assert(locked_center != Vector2i(-1, -1), "Beast planned center is stored")
	var offsets: Array[Vector2i] = cap.get_beast_destruction_shape()
	_assert(grd.get_or_choose_beast_target_center(offsets) == locked_center, "Enemy turn execution locks to previewed beast center")
	for c in beast_cells:
		var p: PieceClass = grd.all_pieces[c.x][c.y]
		_assert(p != null and p.is_enemy_target_highlighted, "Targeted cell (%d, %d) has active highlight" % [c.x, c.y])

	# 3. Test Smart Target Preview
	cap.hybrid_next_is_beast = false
	grd.update_enemy_target_preview()
	var smart_cells: Array[Vector2i] = grd.current_enemy_target_cells
	_assert(smart_cells.size() == 2 or not smart_cells.is_empty(), "Smart upcoming action highlights target swap cells")

	# 4. Clear Preview
	grd.clear_enemy_target_preview()
	_assert(grd.current_enemy_target_cells.is_empty(), "Clear preview removes all active cell targets")

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
# 7. Save/Load Persistence
# ------------------------------------------------------------------------------
func _test_save_load_persistence() -> void:
	print("\n--- 7. Save/Load Persistence ---")
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
	_assert(loaded_red != null and loaded_red.max_slots == 6, "Reloaded Red track preserves 6-slot capacity")
	_assert(loaded_red.next_entry_cursor == 1, "Reloaded Red track preserves next_entry_cursor == 1")
	_assert(Global.cur_char.active_reward_tree.unlocked_tags.has("test_tag_persisted"), "Reloaded RewardTree preserves unlocked_tags")
	_assert(Global.cur_enemy != null and Global.cur_enemy.hybrid_next_is_beast == true, "Reloaded EnemyResource preserves hybrid_next_is_beast state")

	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	Global.save_path = prev_save_path
