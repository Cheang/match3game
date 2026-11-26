extends Node

var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func():
		printerr("TEST TIMEOUT: test_boss_select_and_progression took longer than 15.0s")
		get_tree().quit(1)
	)
	print("==================================================")
	print("RUNNING BOSS SELECT & RUN PROGRESSION TESTS")
	print("==================================================")
	await _run_all_tests()
	print("==================================================")
	print("RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	if tests_failed == 0:
		print("[ALL BOSS SELECT & PROGRESSION TESTS PASSED]")
	else:
		print("[SOME BOSS SELECT TESTS FAILED]")
	print("==================================================")
	get_tree().quit(0 if tests_failed == 0 else 1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		tests_passed += 1
		print("  [PASS] " + msg)
	else:
		tests_failed += 1
		push_error("  [FAIL] " + msg)
		print("  [FAIL] " + msg)


func _make_boss_loc(title: String, desc: String = "", bounty: String = "") -> Location:
	var e := EnemyResource.new()
	e.name = title
	e.type = 1
	e.max_health = 50.0
	e.damage = 3.0
	e.wanted_title = title
	e.wanted_description = desc
	e.wanted_bounty_text = bounty

	var loc := Location.new()
	loc.name = title
	loc.enemy_encounter = true
	loc.which_enemy = [e]
	return loc


func _run_all_tests() -> void:
	_test_stage_queue_progression()
	_test_area_discovery_and_fallback()
	_test_boss_rolling_and_conditions()
	await _test_boss_select_screen_interactions()
	_test_save_load_stage_queue()


func _test_stage_queue_progression() -> void:
	print("\n--- 1. Stage Queue Progression ---")
	Global.init_default_run_stages(6)
	var expected_default: Array[String] = ["level1", "level2", "level3", "level4", "level5", "level6"]
	_assert(Global.run_stage_queue == expected_default, "Default 6-level stage queue created")
	_assert(Global.get_current_stage_id() == "level1", "Initial stage is level1")
	_assert(Global.current_level == 1, "Initial current_level == 1")
	_assert(Global.bosses_killed_needed == 6, "Initial bosses_killed_needed == 6")
	_assert(Global.has_more_stages(), "has_more_stages() is true at start")

	# Insert bonus/hidden level immediately after level1
	Global.insert_next_stage("bonus_crypt")
	_assert(Global.run_stage_queue.size() == 7 and Global.run_stage_queue[1] == "bonus_crypt", "insert_next_stage inserts bonus_crypt after level1")
	_assert(Global.bosses_killed_needed == 7, "bosses_killed_needed updates to 7")

	# Append higher level
	Global.append_stage("level7")
	_assert(Global.run_stage_queue.size() == 8 and Global.run_stage_queue[7] == "level7", "append_stage adds level7 at end")

	# Advance cleanly into bonus_crypt
	var has_next := Global.advance_to_next_stage()
	_assert(has_next and Global.get_current_stage_id() == "bonus_crypt", "advance_to_next_stage moves into bonus_crypt")
	has_next = Global.advance_to_next_stage()
	_assert(has_next and Global.get_current_stage_id() == "level2", "advance_to_next_stage moves from bonus_crypt into level2")

	# Jump to final stage
	Global.jump_to_stage("level7")
	_assert(Global.get_current_stage_id() == "level7", "jump_to_stage lands on level7")
	_assert(not Global.has_more_stages(), "has_more_stages() is false on final stage")
	has_next = Global.advance_to_next_stage()
	_assert(not has_next, "advance_to_next_stage returns false after final stage")


func _test_area_discovery_and_fallback() -> void:
	print("\n--- 2. Area Discovery & Fallback ---")
	Global.init_default_run_stages(6)
	var level1_paths := Locations.get_area_paths_in_stage("level1")
	_assert(level1_paths.has("res://core/map/areas/level1/area_1.tres"), "Discovers area_1.tres inside res://core/map/areas/level1")

	var picked1 := Locations.pick_random_area_for_stage("level1", Global.visited_area_paths)
	_assert(picked1 != null and picked1 is LocationLoader, "pick_random_area_for_stage('level1') loads LocationLoader")
	_assert(Global.current_area_path == "res://core/map/areas/level1/area_1.tres", "Records Global.current_area_path")

	# Level 2 is currently empty; should gracefully fall back to level1
	var picked2 := Locations.pick_random_area_for_stage("level2", Global.visited_area_paths)
	_assert(picked2 != null and Global.current_area_path == "res://core/map/areas/level1/area_1.tres", "Empty level2 falls back to populated lower level")


func _test_boss_rolling_and_conditions() -> void:
	print("\n--- 3. Base (1-3) & Conditional (+1..+2) Boss Rolling ---")
	var area_single := LocationLoader.new()
	area_single.boss = [_make_boss_loc("Only Boss")]
	var single_roll := Locations.roll_boss_choices(area_single, null, 1)
	_assert(single_roll.size() == 1 and single_roll[0].name == "Only Boss", "Area with 1 boss yields 1 unique poster without fabricating extras")

	var area_many := LocationLoader.new()
	area_many.boss = [
		_make_boss_loc("Boss A"),
		_make_boss_loc("Boss B"),
		_make_boss_loc("Boss C"),
		_make_boss_loc("Boss D"),
		_make_boss_loc("Boss E"),
	]
	var base_roll := Locations.roll_boss_choices(area_many, null, 1)
	_assert(base_roll.size() == 3, "Area with 5 base bosses caps base selection to 3")

	# Add 3 conditional entries (capped at max 2, plus condition filtering)
	var cond_flag := BossOfferCondition.new()
	cond_flag.boss_location = _make_boss_loc("Secret Flag Boss")
	cond_flag.required_player_flags = ["cursed_relic"]

	var cond_gold := BossOfferCondition.new()
	cond_gold.boss_location = _make_boss_loc("Greedy Warlord")
	cond_gold.min_gold = 100

	var cond_extra := BossOfferCondition.new()
	cond_extra.boss_location = _make_boss_loc("Extra Cap Boss")
	cond_extra.min_level = 1

	area_many.conditional_bosses = [cond_flag, cond_gold, cond_extra]

	var player := PlayerResource.new()
	player.gold = 20
	var roll_unmet := Locations.roll_boss_choices(area_many, player, 1)
	_assert(roll_unmet.size() == 4, "3 base + 1 met conditional boss (min_level) -> 4 posters")

	player.gold = 200
	player.set_flag("cursed_relic", true)
	var roll_all_met := Locations.roll_boss_choices(area_many, player, 1)
	_assert(roll_all_met.size() == 5, "3 base + max 2 conditional bosses -> 5 posters even when 3 conditions pass")


func _test_boss_select_screen_interactions() -> void:
	print("\n--- 4. BossSelectScreen UI, Lighting & State Machine ---")
	Global.init_default_run_stages(6)
	Global.set_up_player()
	var screen_ps := load("res://scenes/boss_select/boss_select_screen.tscn") as PackedScene
	_assert(screen_ps != null, "boss_select_screen.tscn loads cleanly")

	var scr := screen_ps.instantiate()
	add_child(scr)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(scr.table_sprite != null and scr.table_sprite.material is ShaderMaterial, "TableSprite has dynamic candlelight ShaderMaterial")
	var table_mat := scr.table_sprite.material as ShaderMaterial
	_assert(table_mat != null and table_mat.shader != null and table_mat.shader.resource_path == "res://scenes/boss_select/assets/table_candle_light.gdshader", "TableSprite uses table_candle_light.gdshader")
	_assert(
		scr.table_sides_sprite != null
		and scr.table_sides_sprite.texture != null
		and scr.table_sides_sprite.texture.resource_path == "res://scenes/boss_select/assets/table-sides.png"
		and scr.table_sides_sprite.material is ShaderMaterial,
		"TableSidesSprite uses table-sides.png with dynamic candlelight ShaderMaterial"
	)
	var table_sides_mat := scr.table_sides_sprite.material as ShaderMaterial
	_assert(
		table_sides_mat != null
		and table_sides_mat != table_mat
		and table_sides_mat.shader != null
		and table_sides_mat.shader.resource_path == "res://scenes/boss_select/assets/table_candle_light.gdshader",
		"TableSidesSprite uses its own table_candle_light.gdshader material"
	)
	_assert(float(table_mat.get_shader_parameter("ring_inner_radius")) > 0.0 and float(table_mat.get_shader_parameter("ring_mid_radius")) > float(table_mat.get_shader_parameter("ring_inner_radius")) and float(table_mat.get_shader_parameter("ring_outer_radius")) > float(table_mat.get_shader_parameter("ring_mid_radius")) and float(table_mat.get_shader_parameter("pixel_snap")) >= 1.0, "TableSprite has valid pixel-art ring and snap shader parameters")
	var glow_mat: ShaderMaterial = null
	if scr.candle_glow != null:
		glow_mat = scr.candle_glow.material as ShaderMaterial
	_assert(glow_mat != null and glow_mat.shader != null and glow_mat.shader.resource_path == "res://scenes/boss_select/assets/candle_pixel_glow.gdshader", "CandleGlow uses crisp candle_pixel_glow.gdshader")
	_assert(scr.candle_flame != null and scr.candle_flame is CandleFlame, "CandleFlame node attached to CandleSprite")
	_assert(scr.find_child("StageHeaderLabel", true, false) == null, "StageHeaderLabel removed from BossSelectScreen")
	_assert(scr.candle_glow != null and scr.candle_glow.size.x >= 520.0 and scr.candle_glow.size.y >= 520.0, "CandleGlow area enlarged to >= 520x520")
	var init_strength: float = scr.light_strength
	var init_contrast: float = scr.light_contrast
	_assert(
		init_strength >= 0.0 and init_strength <= 2.5
		and init_contrast >= 0.0 and init_contrast <= 2.0
		and is_equal_approx(float(table_mat.get_shader_parameter("light_strength")), init_strength)
		and is_equal_approx(float(table_mat.get_shader_parameter("light_contrast")), init_contrast)
		and is_equal_approx(float(glow_mat.get_shader_parameter("light_strength")), init_strength),
		"Initial light_strength and light_contrast within range and synced to shaders"
	)
	scr.light_strength = 1.5
	scr.light_contrast = 1.4
	_assert(
		is_equal_approx(float(table_mat.get_shader_parameter("light_strength")), 1.5)
		and is_equal_approx(float(table_mat.get_shader_parameter("light_contrast")), 1.4)
		and is_equal_approx(float(table_sides_mat.get_shader_parameter("light_strength")), 1.5)
		and is_equal_approx(float(table_sides_mat.get_shader_parameter("light_contrast")), 1.4)
		and is_equal_approx(float(glow_mat.get_shader_parameter("light_strength")), 1.5),
		"Changing light_strength and light_contrast propagates to table, table sides, and candle shaders"
	)
	scr.light_strength = 0.0
	_assert(
		not scr.candle_flame.visible
		and is_equal_approx(float(table_mat.get_shader_parameter("light_strength")), 0.0)
		and is_equal_approx(float(glow_mat.get_shader_parameter("light_strength")), 0.0),
		"Setting light_strength to 0.0 hides candle flame and zeroes shader light"
	)
	scr.light_strength = 1.0
	scr.light_contrast = 1.0
	_assert(scr.candle_flame.visible, "Restoring light_strength to 1.0 shows candle flame again")
	scr.light_strength = init_strength
	scr.light_contrast = init_contrast
	_assert(scr.spawned_posters.size() >= 1, "Spawned poster nodes for level1")
	_assert(scr.find_child("ContinueBanner", true, false) == null and scr.find_child("ContinueBtn", true, false) == null, "Continue button and banner removed from BossSelectScreen")
	_assert(scr.auto_transition_on_select, "Selecting a poster auto-transitions into the run by default")
	_assert(scr.inspect_overlay != null and not scr.inspect_overlay.visible, "InspectOverlay starts hidden")
	_assert(scr.inspect_overlay.get_parent() == scr, "InspectOverlay is a root child so it expands with the display")
	var orig_scr_size: Vector2 = scr.size
	scr.size = Vector2(576.0, 1284.0)
	await get_tree().process_frame
	_assert(scr.inspect_overlay.size.is_equal_approx(Vector2(576.0, 1284.0)) and scr.dim_backdrop.size.is_equal_approx(Vector2(576.0, 1284.0)), "InspectOverlay and DimBackdrop expand to fill tall display")
	scr.size = orig_scr_size
	await get_tree().process_frame
	_assert(scr.get_state() == scr.State.DROPPING, "BossSelectScreen starts in DROPPING state while intro/drop runs")
	_assert(scr.spawned_posters[0].get_center_position().y < 0.0, "Wanted poster waits off-screen above table before dropping in")

	# Fast-forward drop animation for deterministic state transition checks
	scr.finish_drop_immediately()
	await get_tree().process_frame
	_assert(is_equal_approx(scr.table_sprite.modulate.a, 1.0) and is_equal_approx(scr.table_sides_sprite.modulate.a, 1.0), "TableSprite and TableSidesSprite reach full opacity after intro completion")
	_assert(scr.get_state() == scr.State.BROWSING, "Transitions cleanly to BROWSING state")

	# Click / inspect poster 0
	var target_poster: WantedPoster = scr.spawned_posters[0]
	var small_paper_bg := target_poster.find_child("PaperBackground", true, false) as TextureRect
	_assert(small_paper_bg != null and small_paper_bg.texture != null and small_paper_bg.texture.resource_path == "res://scenes/boss_select/assets/paperback.png", "Small WantedPoster uses paperback.png backing texture")
	_assert(target_poster.fallback_parchment != null and target_poster.fallback_parchment.visible and target_poster.find_child("CustomArtRect", true, false) == null, "Small WantedPoster always renders on FallbackParchment without CustomArtRect")
	_assert(target_poster.boss_title_label != null and target_poster.boss_title_label.text == target_poster.get_poster_title(), "Small WantedPoster displays boss title at top")
	_assert(target_poster.enemy_resource != null and target_poster.enemy_resource.wanted_poster_art != null, "Lamia EnemyResource has wanted_poster_art assigned")
	_assert(target_poster.portrait_box != null and target_poster.portrait_box.texture == target_poster.enemy_resource.wanted_poster_art and target_poster.portrait_box.visible, "Small WantedPoster displays boss wanted_poster_art inside PortraitBox")
	var faux_lines := target_poster.find_child("FauxTextLines", true, false)
	_assert(faux_lines != null and faux_lines.get_children().filter(func(c): return c is ColorRect).size() >= 4, "Small WantedPoster has stylized text lines below art")
	_assert(target_poster.find_child("WantedHeader", true, false) == null and target_poster.find_child("BountyFooterLabel", true, false) == null, "Old WantedHeader and BountyFooterLabel removed from small poster")
	_assert(is_equal_approx(target_poster.size.x, 226.0) and target_poster.size.y < 325.0, "Small WantedPoster shrinks vertically to fit its content")
	_assert(target_poster.pivot_offset.is_equal_approx(target_poster.size * 0.5), "Small WantedPoster pivot stays centered after content fit")
	var orig_wanted_art: Texture2D = target_poster.enemy_resource.wanted_poster_art
	var initial_h: float = target_poster.size.y
	var short_img := Image.create(412, 120, false, Image.FORMAT_RGBA8)
	var short_tex := ImageTexture.create_from_image(short_img)
	target_poster.enemy_resource.wanted_poster_art = short_tex
	target_poster._refresh_visuals()
	await get_tree().process_frame
	_assert(target_poster.size.y < initial_h, "Shorter wide art reduces small WantedPoster height cleanly")
	target_poster.enemy_resource.wanted_poster_art = null
	target_poster._refresh_visuals()
	await get_tree().process_frame
	_assert(target_poster.get_inspect_art_texture() == target_poster.boss_location.pic and target_poster.portrait_box.texture == target_poster.boss_location.pic, "Falls back to Location.pic when wanted_poster_art is unset")
	target_poster.enemy_resource.wanted_poster_art = orig_wanted_art
	target_poster._refresh_visuals()
	await get_tree().process_frame

	# Dragging a contract stays inside poster_drag_bounds, does not open inspect, and persists across put-back
	var parent_xform := (target_poster.get_parent() as Control).get_global_transform_with_canvas()
	var start_center := target_poster.get_center_position()
	var start_global := parent_xform * start_center

	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	drag_press.position = start_global
	drag_press.global_position = start_global
	target_poster._on_click_area_gui_input(drag_press)

	var drag_in := InputEventMouseMotion.new()
	drag_in.position = parent_xform * (start_center + Vector2(60.0, 90.0))
	drag_in.global_position = drag_in.position
	drag_in.relative = Vector2(60.0, 90.0)
	target_poster._on_click_area_gui_input(drag_in)

	var drag_oob := InputEventMouseMotion.new()
	drag_oob.position = parent_xform * Vector2(-120.0, 20.0)
	drag_oob.global_position = drag_oob.position
	drag_oob.relative = Vector2(-180.0, -400.0)
	target_poster._on_click_area_gui_input(drag_oob)

	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	drag_release.pressed = false
	drag_release.position = drag_oob.position
	drag_release.global_position = drag_oob.global_position
	target_poster._on_click_area_gui_input(drag_release)
	await get_tree().process_frame

	_assert(scr.get_state() == scr.State.BROWSING, "Dragging contract does not trigger inspect overlay")
	var clamped_center := target_poster.get_center_position()
	var half_sz := target_poster.size * 0.5
	_assert(
		clamped_center.x - half_sz.x >= scr.poster_drag_bounds.position.x - 0.5
		and clamped_center.y - half_sz.y >= scr.poster_drag_bounds.position.y - 0.5
		and clamped_center.x + half_sz.x <= scr.poster_drag_bounds.end.x + 0.5
		and clamped_center.y + half_sz.y <= scr.poster_drag_bounds.end.y + 0.5,
		"Dragging out of bounds clamps contract strictly within poster_drag_bounds"
	)

	var desired_spot := Vector2(360.0, 560.0)
	var p2_global := parent_xform * clamped_center
	var d2_press := InputEventMouseButton.new()
	d2_press.button_index = MOUSE_BUTTON_LEFT
	d2_press.pressed = true
	d2_press.position = p2_global
	d2_press.global_position = p2_global
	target_poster._on_click_area_gui_input(d2_press)

	var d2_move := InputEventMouseMotion.new()
	d2_move.position = parent_xform * desired_spot
	d2_move.global_position = d2_move.position
	d2_move.relative = desired_spot - clamped_center
	target_poster._on_click_area_gui_input(d2_move)

	var d2_release := InputEventMouseButton.new()
	d2_release.button_index = MOUSE_BUTTON_LEFT
	d2_release.pressed = false
	d2_release.position = d2_move.position
	d2_release.global_position = d2_move.global_position
	target_poster._on_click_area_gui_input(d2_release)
	await get_tree().process_frame
	_assert(target_poster.get_center_position().distance_to(desired_spot) < 2.0, "Dragging contract inside table area moves it to release position")

	# Quick tap via gui_input still opens inspect
	var tap_global := parent_xform * desired_spot
	var tap_press := InputEventMouseButton.new()
	tap_press.button_index = MOUSE_BUTTON_LEFT
	tap_press.pressed = true
	tap_press.position = tap_global
	tap_press.global_position = tap_global
	target_poster._on_click_area_gui_input(tap_press)

	var tap_release := InputEventMouseButton.new()
	tap_release.button_index = MOUSE_BUTTON_LEFT
	tap_release.pressed = false
	tap_release.position = tap_global + Vector2(2.0, 1.0)
	tap_release.global_position = tap_release.position
	target_poster._on_click_area_gui_input(tap_release)
	_assert(scr.get_state() == scr.State.INSPECTING, "Clicking poster enters INSPECTING state")
	_assert(scr.inspect_overlay.visible, "InspectOverlay becomes visible when zooming poster")
	_assert(scr.inspect_title_label.text == target_poster.get_poster_title(), "Inspect panel displays poster title")

	await get_tree().create_timer(0.32).timeout
	_assert(scr.bounty_info_panel != null and scr.bounty_info_panel.scale.is_equal_approx(Vector2.ONE), "Unified parchment inspect sheet unfolds to full scale")
	var paper_bg := scr.bounty_info_panel.find_child("PaperBackground", true, false) as TextureRect
	_assert(paper_bg != null and paper_bg.texture != null and paper_bg.texture.resource_path == "res://scenes/boss_select/assets/paperback.png", "Inspect sheet uses paperback.png parchment texture")
	_assert(scr.inspect_art_rect != null and scr.inspect_art_rect.texture == target_poster.enemy_resource.wanted_poster_art, "Inspect poster displays boss wanted_poster_art")
	_assert(scr.inspect_art_frame != null and scr.inspect_art_frame.visible and is_equal_approx(scr.inspect_art_frame.custom_minimum_size.y, 256.0), "InspectArtFrame visible and sized dynamically for 412x256 wanted_poster_art")
	_assert(scr.find_child("InspectMetaLabel", true, false) == null and scr.find_child("InspectBountyLabel", true, false) == null, "Removed InspectMetaLabel and InspectBountyLabel handled cleanly")
	var orig_art: Texture2D = scr.inspect_art_rect.texture
	var wide_img := Image.create(206, 100, false, Image.FORMAT_RGBA8)
	var wide_tex := ImageTexture.create_from_image(wide_img)
	scr._apply_inspect_art_texture(wide_tex)
	_assert(is_equal_approx(scr.inspect_art_frame.custom_minimum_size.y, 200.0), "206x100 wide art scales to height 200 at width 412")
	var tall_img := Image.create(412, 600, false, Image.FORMAT_RGBA8)
	var tall_tex := ImageTexture.create_from_image(tall_img)
	scr._apply_inspect_art_texture(tall_tex)
	_assert(is_equal_approx(scr.inspect_art_frame.custom_minimum_size.y, scr.INSPECT_ART_MAX_HEIGHT), "Tall 412x600 art clamps height to INSPECT_ART_MAX_HEIGHT (360)")
	scr._apply_inspect_art_texture(orig_art)
	_assert(target_poster.modulate.a < 0.05, "Small table poster fades out while unified inspect sheet is open")

	# Put poster back
	scr.put_back_poster()
	await get_tree().create_timer(0.28).timeout
	_assert(scr.get_state() == scr.State.BROWSING, "Putting poster back returns to BROWSING")
	_assert(not scr.inspect_overlay.visible, "InspectOverlay hides when put back")
	_assert(is_equal_approx(target_poster.modulate.a, 1.0) and target_poster.scale.is_equal_approx(Vector2.ONE), "Table poster restores full opacity and scale when put back")
	_assert(target_poster.get_center_position().distance_to(desired_spot) < 2.0, "Putting poster back remembers its dragged resting position")

	# Re-inspect and confirm selection -> burns other contracts & zooms directly from inspect sheet
	var other_poster: WantedPoster = scr.WANTED_POSTER_SCENE.instantiate() as WantedPoster
	scr.poster_layer.add_child(other_poster)
	other_poster.setup(target_poster.boss_location)
	other_poster.set_center_position(Vector2(170.0, 420.0))
	other_poster.rotation = deg_to_rad(6.0)
	scr.spawned_posters.append(other_poster)
	await get_tree().process_frame

	scr.auto_transition_on_select = false
	scr.inspect_poster(0)
	await get_tree().create_timer(0.10).timeout
	scr.confirm_poster_selection()
	await get_tree().create_timer(0.95).timeout
	_assert(scr.get_state() == scr.State.CONFIRMED, "Confirming selection transitions to CONFIRMED")
	_assert(scr.selected_poster == target_poster, "selected_poster set to chosen poster")
	_assert(scr.inspect_overlay.visible and not target_poster.visible, "Zooms directly from inspect sheet without returning contract to table")
	_assert(scr.bounty_info_panel.scale.x >= 2.2 and scr.bounty_info_panel.scale.y >= 2.2, "Inspected contract zooms in strongly on selection")
	_assert(
		other_poster.material is ShaderMaterial
		and (other_poster.material as ShaderMaterial).shader != null
		and (other_poster.material as ShaderMaterial).shader.resource_path == "res://assets/shaders/card_burn.gdshader"
		and is_equal_approx(other_poster.burn_progress, 1.0)
		and not other_poster.visible,
		"Other contracts burn completely in background and hide after confirmation"
	)

	# Verify pick_locations honors chosen boss without scene-changing away during test
	Locations.load_locations_from_directory(scr.current_area)
	Locations.pick_locations(Global.area_locations, scr.current_area.enemy_loc_numb, scr.current_area.event_loc_numb, scr.current_area.services_loc_numb, target_poster.boss_location)
	_assert(Global.area_cur_boss != null and Global.area_cur_boss.name == target_poster.boss_location.name, "Chosen boss locked into Global.area_cur_boss")

	scr.queue_free()
	await get_tree().process_frame


func _test_save_load_stage_queue() -> void:
	print("\n--- 5. Serializer Stage Queue Round-Trip ---")
	var orig_save_path: String = Global.save_path
	var tmp_path := "user://test_boss_progression_save.tres"
	Global.save_path = tmp_path

	Global.init_default_run_stages(6)
	Global.insert_next_stage("bonus_swamp")
	Global.advance_to_next_stage()
	Global.current_area_path = "res://core/map/areas/level1/area_1.tres"
	Global.visited_area_paths = ["res://core/map/areas/level1/area_1.tres"] as Array[String]
	Global.cur_scene = "res://scenes/boss_select/boss_select_screen.tscn"
	Global.save()

	# Wipe and reload
	Global.run_stage_queue.clear()
	Global.current_stage_index = 0
	Global.current_area_path = ""
	Global.visited_area_paths.clear()
	Global.load_data()

	var expected_saved: Array[String] = ["level1", "bonus_swamp", "level2", "level3", "level4", "level5", "level6"]
	_assert(Global.run_stage_queue == expected_saved, "Serializer restores run_stage_queue")
	_assert(Global.current_stage_index == 1 and Global.get_current_stage_id() == "bonus_swamp", "Serializer restores current_stage_index == 1")
	_assert(Global.current_area_path == "res://core/map/areas/level1/area_1.tres", "Serializer restores current_area_path")
	_assert(Global.visited_area_paths.has("res://core/map/areas/level1/area_1.tres"), "Serializer restores visited_area_paths")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

	var migrate_path := "user://test_legacy_save_migrate.tres"
	var migrate_txt := '[gd_resource type="Resource" script_class="Serializer" format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/locations/loc_lamia_boss.png" id="1_old"]\n[ext_resource type="Script" path="res://core/saving/serializer.gd" id="2_ser"]\n\n[resource]\nscript = ExtResource("2_ser")\ncurrent_level = 3\n'
	var mf := FileAccess.open(migrate_path, FileAccess.WRITE)
	mf.store_string(migrate_txt)
	mf.close()
	var ser_migrate := Serializer.new()
	ser_migrate.save_path = migrate_path
	ser_migrate.load_data()
	var migrated_txt := FileAccess.get_file_as_string(migrate_path)
	_assert(ser_migrate.current_level == 3, "Serializer loads migrated legacy save cleanly")
	_assert(migrated_txt.contains("res://core/entities/enemies/bosses/lamia/assets/lamia_loc.png") and not migrated_txt.contains("loc_lamia_boss.png"), "Serializer rewrites legacy ext_resource paths on disk")

	var bad_path := "user://test_bad_save_guard.tres"
	var bad_txt := '[gd_resource type="Resource" script_class="Serializer" format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/nonexistent_missing_test_file.png" id="1_bad"]\n[ext_resource type="Script" path="res://core/saving/serializer.gd" id="2_ser"]\n\n[resource]\nscript = ExtResource("2_ser")\ncurrent_level = 5\n'
	var bf := FileAccess.open(bad_path, FileAccess.WRITE)
	bf.store_string(bad_txt)
	bf.close()
	var ser_bad := Serializer.new()
	ser_bad.save_path = bad_path
	ser_bad.load_data()
	_assert(ser_bad.current_level == 0, "Serializer skips save files with unmapped missing resources without crashing")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(migrate_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	Global.save_path = orig_save_path
