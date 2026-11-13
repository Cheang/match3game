extends Node

const InventoryOverlayClass = preload("res://ui/inventory_overlay/inventory_overlay.gd")

func _ready() -> void:
	print("--- TEST INVENTORY OVERLAY CORRECTIONS START ---")
	# Failsafe timeout to ensure test never hangs or runs too long
	get_tree().create_timer(4.0).timeout.connect(func():
		printerr("TEST TIMEOUT: test_inventory_overlay took longer than 4.0s")
		get_tree().quit(1)
	)
	var overlay_scene := load("res://ui/inventory_overlay/inventory_overlay.tscn") as PackedScene
	if overlay_scene == null:
		push_error("Failed to load inventory_overlay.tscn")
		get_tree().quit(1)
		return

	var overlay = overlay_scene.instantiate()
	add_child(overlay)

	# 1. Test Grid Interaction Block & Global.game_is_played
	Global.game_is_played = true
	assert(InventoryOverlayClass.is_overlay_open() == false, "Overlay should be closed initially")
	overlay.open()
	assert(InventoryOverlayClass.is_overlay_open() == true, "Overlay should report open")
	assert(Global.game_is_played == false, "Global.game_is_played must be false when overlay is open to block grid interaction")
	overlay.close()
	assert(Global.game_is_played == true, "Global.game_is_played must restore to true after closing overlay")
	assert(InventoryOverlayClass.is_overlay_open() == false, "Overlay should report closed")

	# Re-open for further tests
	overlay.open()

	# 2. Test Layout Structure
	assert(overlay.passives_ring != null, "Passives ring component must exist")
	assert(overlay.tracks_box != null, "TracksBox must exist")
	assert(overlay.description_panel != null, "DescriptionPanel must exist")

	# 3. Test Button Text is 'Loadout'
	assert(overlay.loadout_nav_btn != null, "Loadout nav button must exist")
	assert(overlay.loadout_nav_btn.text == "Loadout", "Button text must be 'Loadout' (was: %s)" % overlay.loadout_nav_btn.text)

	# 4. Test Drag-and-Drop Equipment Moving & Reordering
	if Global.cur_char == null:
		Global.cur_char = PlayerResource.new()
	Global.cur_char.ensure_loadout_tracks()

	var red_track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(100)
	var blue_track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(200)
	red_track.equipped_modifiers.clear()
	blue_track.equipped_modifiers.clear()

	var sword := Equipment.new()
	sword.piece_name = "Red Sword"
	sword.slot_cost = 1
	sword.allowed_colors = [Global.TileColor.RED]
	red_track.equipped_modifiers.append(sword)

	var shield := Equipment.new()
	shield.piece_name = "Red Shield"
	shield.slot_cost = 1
	shield.allowed_colors = [Global.TileColor.RED]
	red_track.equipped_modifiers.append(shield)

	var ring := Equipment.new()
	ring.piece_name = "Wild Ring"
	ring.slot_cost = 1 # colorless: allowed on any track
	blue_track.equipped_modifiers.append(ring)

	overlay.refresh_overlay_data()

	# A. Test reordering within the same track (swap sword and shield)
	print("Testing drag-and-drop reorder on same track...")
	var drag_data_sword := {
		"type": "equipment_drag",
		"modifier": sword,
		"source_track": red_track,
		"source_is_ult": false,
		"source_slot_idx": 0
	}
	overlay._on_equipment_dropped(drag_data_sword, red_track, false, 1)
	assert(red_track.equipped_modifiers[0] == shield, "Shield should now be at index 0")
	assert(red_track.equipped_modifiers[1] == sword, "Sword should now be at index 1")
	print("Same-track reordering verified!")

	# B. Test moving colorless ring from Blue track to Red track
	print("Testing drag-and-drop move from Blue track to Red track...")
	var drag_data_ring := {
		"type": "equipment_drag",
		"modifier": ring,
		"source_track": blue_track,
		"source_is_ult": false,
		"source_slot_idx": 0
	}
	overlay._on_equipment_dropped(drag_data_ring, red_track, false, -1)
	assert(blue_track.equipped_modifiers.is_empty(), "Blue track should now be empty")
	assert(red_track.equipped_modifiers.has(ring), "Red track should now contain the Ring")
	print("Inter-track move verified!")

	# C. Test Multi-slot Connection Graphic
	print("Testing multi-slot connection graphic...")
	red_track.equipped_modifiers.clear()
	var greatsword := Equipment.new()
	greatsword.piece_name = "Greatsword"
	greatsword.slot_cost = 2
	greatsword.allowed_colors = [Global.TileColor.RED]
	red_track.equipped_modifiers.append(greatsword)

	overlay.refresh_overlay_data()

	var red_row: InventoryOverlayTrackRow = overlay.track_rows[0]
	assert(red_row != null, "Red row must exist")
	assert(red_row.connection_rects.size() == 4, "Must have 4 connection rects")
	# Since greatsword occupies slots 0 and 1, connection 0 (between slot 0 and 1) must be visible!
	assert(red_row.connection_rects[0].visible == true, "Connection 0 must be visible for 2-slot item")
	assert(red_row.connection_rects[1].visible == false, "Connection 1 must be hidden")
	assert(red_row.connection_rects[2].visible == false, "Connection 2 must be hidden")
	assert(red_row.connection_rects[3].visible == false, "Connection 3 must be hidden")

	# Verify shader palette parameter on connection
	var conn_mat: ShaderMaterial = red_row.connection_rects[0].material as ShaderMaterial
	assert(conn_mat != null, "Connection must have ShaderMaterial")
	var pal_red: Dictionary = ColorLoadoutTrack.get_palette_for_color(100)
	var mat_base: Color = conn_mat.get_shader_parameter("target_color_3")
	assert(mat_base == pal_red.base, "Connection shader must match row base color (%s vs %s)" % [mat_base, pal_red.base])
	print("2-slot connection graphic verified!")

	# Test 3-slot item: connections 0 and 1 should both be visible
	greatsword.slot_cost = 3
	overlay.refresh_overlay_data()
	assert(red_row.connection_rects[0].visible == true, "Connection 0 must be visible for 3-slot item")
	assert(red_row.connection_rects[1].visible == true, "Connection 1 must be visible for 3-slot item")
	assert(red_row.connection_rects[2].visible == false, "Connection 2 must be hidden")
	print("3-slot connection graphic verified!")

	# D. Test Pentagonal Passives Ring Component
	print("Testing pentagonal passives ring component...")
	var p_ring = overlay.passives_ring
	assert(p_ring != null, "Passives ring component must exist on overlay")
	assert(p_ring.slots.size() == 5, "Passives ring must have 5 slots")

	# Check exact positions
	assert(p_ring.slots[0].position == Vector2(139.0, 0.0), "Slot 0 must be at (139, 0)")
	assert(p_ring.slots[1].position == Vector2(278.0, 99.0), "Slot 1 must be at (278, 99)")
	assert(p_ring.slots[2].position == Vector2(248.0, 248.0), "Slot 2 must be at (248, 248)")
	assert(p_ring.slots[3].position == Vector2(29.0, 248.0), "Slot 3 must be at (29, 248)")
	assert(p_ring.slots[4].position == Vector2(0.0, 99.0), "Slot 4 must be at (0, 99)")

	# Verify empty state: all frames and icons hidden so dark sockets show through
	Global.cur_char.equipped_passives.clear()
	overlay.refresh_overlay_data()
	for i in range(5):
		assert(p_ring.slots[i].frame.visible == false, "Empty slot %d frame must be hidden" % i)
		assert(p_ring.slots[i].icon_rect.visible == false, "Empty slot %d icon must be hidden" % i)

	# Equip a Reward passive into slot 0 and Equipment passive into slot 1
	var dummy_tex := PlaceholderTexture2D.new()
	dummy_tex.size = Vector2(32, 32)

	var p_reward := Reward.new()
	p_reward.name = "Iron Will"
	p_reward.description = "Might +5 and Grit +3"
	p_reward.might = 5.0
	p_reward.grit = 3.0
	p_reward.icon = dummy_tex
	p_reward.rarity = Reward.Rarity.RARE
	Global.cur_char.equip_passive(p_reward)

	var p_equip := Equipment.new()
	p_equip.piece_name = "Amulet of Vitality"
	p_equip.description = "Max Health +10"
	p_equip.family = "healing"
	p_equip.icon = dummy_tex
	p_equip.rarity = Equipment.Rarity.EPIC
	Global.cur_char.equip_passive(p_equip)

	overlay.refresh_overlay_data()

	# Slot 0 should have p_reward visible, slot 1 should have p_equip visible, slots 2-4 hidden
	assert(p_ring.slots[0].frame.visible == true, "Slot 0 frame must be visible")
	assert(p_ring.slots[0].icon_rect.visible == true, "Slot 0 icon must be visible")
	assert(p_ring.slots[0].icon_rect.texture != null, "Slot 0 icon texture must be set")
	assert(p_ring.slots[1].frame.visible == true, "Slot 1 frame must be visible")
	assert(p_ring.slots[2].frame.visible == false, "Slot 2 frame must remain hidden")

	# Test Clicking Slot 0: Description updates with Iron Will details & slot becomes selected
	p_ring.slots[0].slot_clicked.emit(0, p_reward)
	assert(p_ring.selected_slot_index == 0, "Slot 0 must be selected")
	assert(p_ring.slots[0].is_selected_slot == true, "Slot 0 must report is_selected_slot")
	assert(p_ring.slots[1].is_selected_slot == false, "Slot 1 must not be selected")
	assert(overlay.description_label.text.contains("Iron Will"), "Description must contain 'Iron Will'")
	assert(overlay.description_label.text.contains("Rare"), "Description must show Rarity")

	# Test Clicking Slot 1: Description updates with Amulet details & slot 1 becomes selected
	p_ring.slots[1].slot_clicked.emit(1, p_equip)
	assert(p_ring.selected_slot_index == 1, "Slot 1 must be selected")
	assert(p_ring.slots[0].is_selected_slot == false, "Slot 0 must no longer be selected")
	assert(p_ring.slots[1].is_selected_slot == true, "Slot 1 must report is_selected_slot")
	assert(overlay.description_label.text.contains("Amulet of Vitality"), "Description must contain 'Amulet of Vitality'")

	# Test Drag and Drop: Drag p_equip (slot 1) onto slot 0 (swapping with p_reward)
	print("Testing drag and drop swap on passives ring...")
	overlay._on_passive_dropped(1, 0)
	assert(Global.cur_char.equipped_passives[0].piece_name == "Amulet of Vitality", "Slot 0 should now hold Amulet")
	assert(Global.cur_char.equipped_passives[1].name == "Iron Will", "Slot 1 should now hold Iron Will")
	print("Passive swap verified!")

	# Test clicking track ability deselects passives ring
	overlay._on_slot_clicked(greatsword, red_track, false, 0)
	assert(p_ring.selected_slot_index == -1, "Passives ring must deselect when track ability clicked")
	assert(p_ring.slots[0].is_selected_slot == false, "Slot 0 is_selected_slot must be false")
	assert(overlay.description_label.text.contains("Greatsword"), "Description must switch to Greatsword")
	print("Passives ring component verified!")

	# E. Test Multi-tab Views (Loadout, Stats, Settings)
	print("Testing multi-tab views (Loadout, Stats, Settings)...")
	assert(overlay.loadout_nav_btn != null, "Loadout button must exist")
	assert(overlay.stats_nav_btn != null, "Stats button must exist")
	assert(overlay.settings_nav_btn != null, "Settings button must exist")

	assert(overlay.loadout_view.visible == true, "LoadoutView must be visible initially")
	assert(overlay.stats_view.visible == false, "StatsView must be hidden initially")
	assert(overlay.settings_view.visible == false, "SettingsView must be hidden initially")

	# Test Stats Tab
	overlay._on_stats_nav_pressed()
	assert(overlay.current_tab == overlay.Tab.STATS, "Current tab should be STATS")
	assert(overlay.stats_view.visible == true, "StatsView must be visible")
	assert(overlay.loadout_view.visible == false, "LoadoutView must be hidden")
	assert(overlay.settings_view.visible == false, "SettingsView must be hidden")
	print("Stats tab verified!")

	# Test Settings Tab
	overlay._on_settings_nav_pressed()
	assert(overlay.current_tab == overlay.Tab.SETTINGS, "Current tab should be SETTINGS")
	assert(overlay.settings_view.visible == true, "SettingsView must be visible")
	assert(overlay.loadout_view.visible == false, "LoadoutView must be hidden")
	assert(overlay.stats_view.visible == false, "StatsView must be hidden")

	# Verify Settings Buttons
	assert(overlay.almanac_btn != null, "Almanac button must exist")
	assert(overlay.almanac_btn.disabled == true, "Almanac button must be disabled")
	assert(overlay.sound_btn != null, "Sound button must exist")
	assert(overlay.sound_btn.disabled == true, "Sound button must be disabled")
	assert(overlay.graphics_btn != null, "Graphics button must exist")
	assert(overlay.graphics_btn.disabled == true, "Graphics button must be disabled")
	assert(overlay.main_menu_btn != null, "Main Menu button must exist")
	assert(overlay.main_menu_btn.disabled == false, "Main Menu button must be enabled")
	print("Settings tab and buttons verified!")

	# Test Nav Button Order: 0 = Loadout (Left), 1 = Stats (Middle), 2 = Settings (Right)
	assert(overlay.bottom_nav_box.get_child(0) == overlay.loadout_nav_btn, "Child 0 must be Loadout nav button")
	assert(overlay.bottom_nav_box.get_child(1) == overlay.stats_nav_btn, "Child 1 must be Stats nav button")
	assert(overlay.bottom_nav_box.get_child(2) == overlay.settings_nav_btn, "Child 2 must be Settings nav button")
	print("Nav button ordering (Loadout, Stats, Settings) verified!")

	# Test Switching Back to Loadout Tab
	overlay._on_loadout_nav_pressed()
	assert(overlay.current_tab == overlay.Tab.LOADOUT, "Current tab should be LOADOUT")
	assert(overlay.loadout_view.visible == true, "LoadoutView must be visible")
	assert(overlay.stats_view.visible == false, "StatsView must be hidden")
	assert(overlay.settings_view.visible == false, "SettingsView must be hidden")
	print("Return to Loadout tab verified!")

	# Test Clicking Active Tab Closes Overlay
	assert(overlay.visible == true, "Overlay should be open")
	overlay._on_loadout_nav_pressed()
	assert(overlay.visible == false, "Clicking active Loadout tab must close overlay")
	print("Closing overlay via active Loadout tab verified!")

	overlay.open()
	overlay._on_stats_nav_pressed()
	assert(overlay.visible == true and overlay.current_tab == overlay.Tab.STATS, "Switched to Stats tab")
	overlay._on_stats_nav_pressed()
	assert(overlay.visible == false, "Clicking active Stats tab must close overlay")
	print("Closing overlay via active Stats tab verified!")

	overlay.open()
	overlay._on_settings_nav_pressed()
	assert(overlay.visible == true and overlay.current_tab == overlay.Tab.SETTINGS, "Switched to Settings tab")
	overlay._on_settings_nav_pressed()
	assert(overlay.visible == false, "Clicking active Settings tab must close overlay")
	print("Closing overlay via active Settings tab verified!")

	# F. Test Slotting Mode with Floating Shard, Fire Particles & Compatibility Highlights
	print("Testing slotting mode with floating shard, particles, and disabled track sprites...")
	var red_shard := Equipment.new()
	red_shard.piece_name = "Crimson Shard"
	red_shard.allowed_colors = [100] # Red only
	red_shard.base_damage = 4.0

	var shards_to_slot: Array[Equipment] = [red_shard]
	overlay.start_slotting_mode(shards_to_slot)
	assert(overlay.is_slotting_mode == true, "Overlay should be in slotting mode")
	assert(overlay.visible == true, "Overlay should be open")
	assert(overlay.done_btn != null and overlay.done_btn.visible == true, "Done button must be visible in slotting mode")
	assert(overlay.loadout_nav_btn.visible == false, "Normal nav buttons must be hidden in slotting mode")
	assert(overlay.stats_nav_btn.visible == false, "Stats nav button must be hidden in slotting mode")
	assert(overlay.settings_nav_btn.visible == false, "Settings nav button must be hidden in slotting mode")
	assert(overlay.floating_shard_dock != null and overlay.floating_shard_dock.visible == true, "Floating shard dock must be visible")
	assert(overlay.floating_shard_dock.current_equipment == red_shard, "Floating shard dock must hold the new shard")
	assert(overlay.floating_shard_dock.fire_particles.emitting == true, "Fire particles must be emitting on floating shard")
	assert(overlay.description_panel.custom_minimum_size == Vector2(520, overlay.description_panel_height), "Description panel must maintain full 520x%f normal size in slotting mode" % overlay.description_panel_height)
	assert(overlay.description_panel.get_parent() == overlay.loadout_view, "Description panel must be a direct child of LoadoutView with normal full size")
	assert(overlay.floating_shard_dock.custom_minimum_size == Vector2(90, 140), "Floating shard dock must be 90x140 side-dock")
	assert(overlay.description_panel.is_ancestor_of(overlay.floating_shard_dock) == true, "Floating shard dock must be on top of (inside) DescriptionPanel")
	assert(overlay.description_hbox != null, "DescriptionHBox HBoxContainer must exist inside DescriptionPanel Margin")

	# Verify compatibility highlights: Red track normal, other tracks disabled (including empty tracks)
	for row in overlay.track_rows:
		if row.track_color == 100:
			assert(row.bg_rect.texture == row.TEX_TRACK_EMPTY, "Red track must use normal empty sprite")
			assert(row.diamond_slots[0].modulate == Color.WHITE, "Red track diamond slots must not be dimmed")
			assert(row.ult_slot.modulate.a < 0.9, "Ultimate slot must be dimmed for non-ultimate shard")
		else:
			assert(row.bg_rect.texture == row.TEX_TRACK_EMPTY_DISABLED, "Incompatible or empty track (%d) must use disabled sprite" % row.track_color)
			assert(row.diamond_slots[0].modulate.a < 0.9, "Incompatible/empty track slots must be grayed out")

	# Verify drag data helper from floating shard dock (without triggering native Godot drag)
	var drag_data: Variant = overlay.floating_shard_dock.get_floating_drag_data(Vector2(20, 20))
	assert(drag_data != null and drag_data is Dictionary, "Floating shard item must provide valid drag data on drag")
	assert(drag_data.get("modifier") == red_shard, "Drag data must hold the red shard")
	assert(drag_data.get("source_is_floating") == true, "Drag data must mark source_is_floating")

	# Verify custom interactive drag and drop: picking up shard moves avatar + fire particles
	overlay._on_floating_shard_drag_requested(red_shard, Vector2(260, 500))
	overlay._start_custom_drag(Vector2(260, 500))
	assert(overlay.is_custom_dragging == true, "Overlay must report is_custom_dragging")
	assert(overlay.drag_avatar != null and overlay.drag_avatar.visible == true, "Drag avatar must be visible")
	assert(overlay.drag_avatar.fire_particles.emitting == true, "Drag avatar fire particles must be emitting during drag")
	assert(overlay.floating_shard_dock.is_shard_hidden == true, "Dock shard must hide while being dragged by cursor")

	# Move cursor
	overlay.drag_avatar.update_position(Vector2(200, 300))
	assert(overlay.drag_avatar.global_position == Vector2(200, 300) - overlay.drag_avatar.DIAMOND_SIZE / 2.0, "Drag avatar must follow cursor position")

	# Dropping outside valid slots initiates smooth float-back instead of snapping
	overlay._finish_custom_drop(Vector2(-50, -50))
	assert(overlay.is_custom_dragging == false, "Custom dragging should be false after drop release")
	assert(overlay.drag_avatar.is_returning() == true, "Drag avatar must smoothly float back when released outside valid slots")

	# Cleanup custom drag cancels return tween cleanly and restores dock shard
	overlay._cleanup_custom_drag()
	assert(overlay.drag_avatar.is_returning() == false, "Return tween must stop after cleanup")
	assert(overlay.drag_avatar.visible == false, "Drag avatar must be hidden after cleanup")
	assert(overlay.floating_shard_dock.is_shard_hidden == false, "Dock shard must unhide after drag ends")

	# Test dropping floating shard on Red track slot 0 to replace existing Greatsword
	var initial_item: Equipment = red_track.get_modifier_at_slot_index(0)
	overlay._handle_floating_shard_drop(red_shard, red_track, false, 0)
	assert(red_track.get_modifier_at_slot_index(0) == red_shard, "Slot 0 should now hold Crimson Shard")
	assert(overlay.floating_shard_dock.current_equipment == initial_item, "Replaced Greatsword must become the new floating shard")
	assert(overlay.floating_shard_dock.fire_particles.emitting == true, "Particles must remain active on replaced shard")
	print("Shard replacement and floating swap verified!")

	# Test clicking Done button
	overlay._on_done_btn_pressed()
	assert(overlay.is_slotting_mode == false, "Slotting mode must be false after Done")
	assert(overlay.visible == false, "Overlay must close after Done")
	assert(overlay.done_btn.visible == false, "Done button must be hidden after Done")
	assert(overlay.loadout_nav_btn.visible == true, "Nav buttons must restore after Done")
	for row in overlay.track_rows:
		if row.track_color > 0:
			assert(row.bg_rect.texture == row.TEX_TRACK_EMPTY, "Tracks must restore normal empty sprite")
			assert(row.diamond_slots[0].modulate == Color.WHITE, "Slots must restore normal modulate")
	print("Slotting mode completion and cleanup verified!")

	# Test dragging an equipped shard in normal inventory mode disables incompatible tracks
	overlay.open()
	overlay._on_row_slot_drag_requested(red_shard, red_track, false, 0, Vector2(100, 300))
	overlay._start_custom_drag(Vector2(100, 300))
	for row in overlay.track_rows:
		if row.track_color == 100:
			assert(row.bg_rect.texture == row.TEX_TRACK_EMPTY, "Red track must stay normal while dragging red shard")
		else:
			assert(row.bg_rect.texture == row.TEX_TRACK_EMPTY_DISABLED, "Incompatible/empty track (%d) must be disabled while dragging red shard" % row.track_color)
	overlay._cleanup_custom_drag()
	for row in overlay.track_rows:
		if row.track_color > 0:
			assert(row.bg_rect.texture == row.TEX_TRACK_EMPTY, "Active tracks must restore normal sprite after drag ends")
	print("Track disabling during normal inventory drag verified!")

	# Test description panel readability styling and high-contrast BBCode remapping
	assert(overlay.description_label.get_theme_font("normal_font") == overlay.BODY_FONT, "DescriptionLabel must use pixel BODY_FONT")
	assert(overlay.description_label.get_theme_constant("outline_size") == 3, "DescriptionLabel must have crisp outline_size 3")
	var rare_dagger := Equipment.new()
	rare_dagger.piece_name = "Tusk Dagger"
	rare_dagger.rarity = Equipment.Rarity.RARE
	rare_dagger.base_damage = 6.0
	rare_dagger.hit_count = 2
	var rare_bonus := EquipmentRolledBonus.new()
	rare_bonus.type = EquipmentBonus.BonusType.CRIT_CHANCE
	rare_bonus.base_val = 4.0
	rare_bonus.effective_val = 4.0
	rare_dagger.rolled_bonuses.append(rare_bonus)
	var bb: String = overlay._format_ability_bbcode(rare_dagger, 100, false)
	assert(bb.contains("#7eb8ff"), "Rare title and bonus on dark purple panel must use bright sky blue #7eb8ff")
	assert(bb.contains("#ff7b7b"), "Damage text on dark purple panel must remap dark red to bright coral #ff7b7b")
	assert(not bb.contains("Passive Stats:"), "Passive Stats footer must not duplicate bulleted rarity bonuses")
	print("Description panel readability styling verified!")

	# Test anti-duplication and edge-case fixes in normal & reward slotting modes
	# 1. Native Godot drag must NOT be enabled on OverlaySlotUI or FloatingShardItem (prevents dual-drag double-drop)
	assert(not overlay.track_rows[0].diamond_slots[0].has_method("_get_drag_data"), "OverlaySlotUI must not implement _get_drag_data alongside custom drag")
	assert(not overlay.floating_shard_dock.shard_item.has_method("_get_drag_data"), "FloatingShardItem must not implement _get_drag_data alongside custom drag")

	# 2. ColorLoadoutTrack must reject equipping an already-equipped modifier/ultimate
	var dupe_test_item := Equipment.new()
	dupe_test_item.piece_name = "Dupe Guard Blade"
	dupe_test_item.allowed_colors = [100]
	dupe_test_item.slot_cost = 1
	red_track.equipped_modifiers.clear()
	red_track.ultimate_skill = null
	assert(red_track.equip_modifier(dupe_test_item), "First equip must succeed")
	assert(not red_track.equip_modifier(dupe_test_item), "Equipping same modifier twice on track must be rejected")
	assert(red_track.equipped_modifiers.size() == 1, "Track must still have only 1 copy")

	# 3. Dropping an already-equipped item as a floating shard must be rejected (no dupe!)
	overlay.start_slotting_mode([dupe_test_item])
	var dupe_drop_ok: bool = overlay._handle_floating_shard_drop(dupe_test_item, red_track, false, 1)
	assert(not dupe_drop_ok, "Floating drop of already-equipped shard must be rejected")
	assert(red_track.equipped_modifiers.size() == 1, "Already-equipped item must not be duplicated")
	overlay._on_done_btn_pressed()

	# 4. Multi-slot replacement in slotting mode must queue extra displaced items instead of deleting them
	var s1 := Equipment.new(); s1.piece_name = "S1"; s1.allowed_colors = [100]; s1.slot_cost = 1
	var s2 := Equipment.new(); s2.piece_name = "S2"; s2.allowed_colors = [100]; s2.slot_cost = 1
	var s3 := Equipment.new(); s3.piece_name = "S3"; s3.allowed_colors = [100]; s3.slot_cost = 1
	var s4 := Equipment.new(); s4.piece_name = "S4"; s4.allowed_colors = [100]; s4.slot_cost = 1
	var s5 := Equipment.new(); s5.piece_name = "S5"; s5.allowed_colors = [100]; s5.slot_cost = 1
	var big2 := Equipment.new(); big2.piece_name = "Big2"; big2.allowed_colors = [100]; big2.slot_cost = 2
	red_track.equipped_modifiers.clear()
	red_track.equip_modifier(s1)
	red_track.equip_modifier(s2)
	red_track.equip_modifier(s3)
	red_track.equip_modifier(s4)
	red_track.equip_modifier(s5)
	overlay.start_slotting_mode([big2])
	var multi_ok: bool = overlay._handle_floating_shard_drop(big2, red_track, false, 0)
	assert(multi_ok, "2-slot floating shard replacement on full track must succeed")
	assert(red_track.equipped_modifiers.has(big2), "Big2 must be equipped")
	assert(overlay._cached_floating_equipment == s1, "First displaced shard S1 must be in floating dock")
	assert(overlay.pending_slotting_queue.has(s5), "Extra displaced shard S5 must be queued, not deleted")
	overlay._on_done_btn_pressed()

	# 5. Incompatible ultimate swap in normal mode must refuse without deleting target ultimate
	var red_ult := Equipment.new(); red_ult.piece_name = "Red Ult"; red_ult.allowed_colors = [100]; red_ult.is_ultimate = true
	var blue_ult := Equipment.new(); blue_ult.piece_name = "Blue Ult"; blue_ult.allowed_colors = [200]; blue_ult.is_ultimate = true
	var any_ult := Equipment.new(); any_ult.piece_name = "Wild Ult"; any_ult.allowed_colors = []; any_ult.is_ultimate = true
	red_track.ultimate_skill = red_ult
	blue_track.ultimate_skill = any_ult
	var ult_swap_ok: bool = overlay._on_equipment_dropped({
		"type": "equipment_drag",
		"modifier": any_ult,
		"source_track": blue_track,
		"source_is_ult": true,
		"source_slot_idx": -1
	}, red_track, true, -1)
	assert(not ult_swap_ok, "Incompatible ultimate swap must be rejected")
	assert(red_track.ultimate_skill == red_ult, "Target ultimate must not be deleted on rejected swap")
	assert(blue_track.ultimate_skill == any_ult, "Source ultimate must remain intact on rejected swap")

	# 6. toggle() is blocked during slotting mode, and close() cleanly finishes slotting mode
	var slotting_done_count := [0]
	overlay.slotting_completed.connect(func(): slotting_done_count[0] += 1)
	overlay.start_slotting_mode([blue_ult])
	overlay.toggle()
	assert(overlay.visible and overlay.is_slotting_mode, "toggle() must not close overlay while in slotting mode")
	overlay.close()
	assert(not overlay.visible and not overlay.is_slotting_mode, "close() must clean up slotting mode")
	assert(slotting_done_count[0] == 1, "close() during slotting mode must emit slotting_completed")
	print("Anti-duplication and edge-case regression tests verified!")

	overlay.close()
	overlay.queue_free()
	print("--- ALL INVENTORY OVERLAY CORRECTIONS PASSED ---")
	get_tree().quit(0)
