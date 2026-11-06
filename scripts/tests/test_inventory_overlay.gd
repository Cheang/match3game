extends Node

const InventoryOverlayClass = preload("res://scripts/ui/inventory_overlay.gd")

func _ready() -> void:
	print("--- TEST INVENTORY OVERLAY CORRECTIONS START ---")
	var overlay_scene := load("res://scenes/ui/inventory_overlay.tscn") as PackedScene
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

	# 2. Test Bottom Alignment: TopSpacer exists and expands
	var spacer = overlay.spacer
	assert(spacer != null, "TopSpacer must exist")
	assert(spacer.size_flags_vertical == Control.SIZE_EXPAND_FILL, "TopSpacer must expand vertically to bottom-align tracks, description & buttons")

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

	overlay.close()
	overlay.queue_free()
	print("--- ALL INVENTORY OVERLAY CORRECTIONS PASSED ---")
	get_tree().quit(0)
