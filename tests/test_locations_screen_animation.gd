extends Node2D

const LOCATIONS_SCREEN_SCENE: PackedScene = preload("res://scenes/locations/locations_screen.tscn")
const LOC_BOAR: Location = preload("res://core/map/encounters/enemy/loc_wild_boar_1.tres")
const LOC_EVENT: Location = preload("res://core/map/encounters/event/event_fallen_tree.tres")

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("==================================================")
	print("RUNNING LOCATIONS SCREEN BURN & ZOOM TESTS")
	print("==================================================")
	await _test_burn_and_zoom_animation()
	print("==================================================")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		printerr("[LOCATIONS SCREEN TESTS FAILED]")
		get_tree().quit(1)
	else:
		print("[ALL LOCATIONS SCREEN TESTS PASSED]")
		get_tree().quit(0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] " + msg)
	else:
		_failed += 1
		printerr("  [FAIL] " + msg)


func _test_burn_and_zoom_animation() -> void:
	Global.area_locations = [LOC_BOAR.duplicate(), LOC_EVENT.duplicate(), LOC_BOAR.duplicate()] as Array[Location]
	var scr := LOCATIONS_SCREEN_SCENE.instantiate()
	add_child(scr)
	scr.transition_on_select = false

	_assert(scr.loc_cards.size() == 3, "LocationsScreen exposes 3 LocationCards")
	var card0: LocationCard = scr.loc_cards[0]
	var card1: LocationCard = scr.loc_cards[1]
	var card2: LocationCard = scr.loc_cards[2]
	_assert(card0 != null and card1 != null and card2 != null, "All 3 LocationCards instantiated")

	_assert(card0.modulate.a < 0.05 and card1.modulate.a < 0.05 and card2.modulate.a < 0.05, "Location cards start faded out on entry")
	_assert(not card0.is_interactive and not card1.is_interactive and not card2.is_interactive, "Cards are non-interactive until fade-in finishes")

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.22).timeout
	_assert(card0.modulate.a > card1.modulate.a and card1.modulate.a >= card2.modulate.a and card0.modulate.a > 0.3 and card2.modulate.a < card0.modulate.a, "Cards fade in sequentially one after another")

	await get_tree().create_timer(0.65).timeout
	_assert(
		is_equal_approx(card0.modulate.a, 1.0)
		and is_equal_approx(card1.modulate.a, 1.0)
		and is_equal_approx(card2.modulate.a, 1.0)
		and card0.is_interactive
		and card1.is_interactive
		and card2.is_interactive,
		"All 3 cards reach full opacity and interactivity after staggered intro"
	)

	var orig_y1: float = card1.global_position.y
	var orig_y2: float = card2.global_position.y

	scr.select_location_card(card0)
	await get_tree().process_frame

	_assert(not Global.game_is_played, "Selecting a location locks Global.game_is_played immediately")
	_assert(card0.material == null, "Selected card stays unburned without burn material")
	_assert(card1.material is ShaderMaterial and card2.material is ShaderMaterial, "Unselected cards receive ShaderMaterial for burning")
	var m1 := card1.material as ShaderMaterial
	var m2 := card2.material as ShaderMaterial
	_assert(m1.shader != null and m1.shader.resource_path == "res://assets/shaders/card_burn.gdshader", "Card 1 uses card_burn.gdshader")
	_assert(m2.shader != null and m2.shader.resource_path == "res://assets/shaders/card_burn.gdshader", "Card 2 uses card_burn.gdshader")
	_assert(card1.loc_name_l.use_parent_material and card1.loc_texture.use_parent_material, "Burning card children inherit parent burn material")
	_assert(absf(card1.global_position.y - orig_y1) < 1.0 and absf(card2.global_position.y - orig_y2) < 1.0, "Burning cards keep vertical positions without container collapse")

	await get_tree().create_timer(0.95).timeout

	_assert(is_equal_approx(card1.burn_progress, 1.0) and is_equal_approx(card2.burn_progress, 1.0), "Both unselected cards burn completely to 1.0")
	var vp_center: Vector2 = scr.get_viewport_rect().size * 0.5
	var card0_center: Vector2 = card0.get_global_transform_with_canvas() * card0.pivot_offset
	_assert(card0.scale.x >= 2.5 and card0.scale.y >= 2.5, "Selected card zooms in strongly")
	_assert(card0_center.distance_to(vp_center) < 3.0, "Selected card moves cleanly to viewport center")
	if scr.bottom_bar != null:
		_assert(scr.bottom_bar.modulate.a < 0.05, "Bottom bar fades out cleanly during location selection")

	scr.queue_free()
	await get_tree().process_frame
