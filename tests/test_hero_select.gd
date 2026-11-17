extends Node

const HERO_SELECT_SCENE := preload("res://ui/screens/hero_select_screen.tscn")
const WARRIOR_RES := preload("res://entities/player/warrior/warrior.tres")
const SAMPLE_PORTRAIT := preload("res://assets/sprites/ui/main_menu/folktiles_logo.png")

var _failures: int = 0


func _assert_true(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _ready() -> void:
	await get_tree().process_frame

	# 1. Verify Border z-order across all updated menus (directly above Background/event_bg, z_index == 0)
	for p in [
		"res://ui/screens/main_menu.tscn",
		"res://ui/screens/settings_screen.tscn",
		"res://ui/screens/thank_you_screen.tscn",
		"res://ui/screens/hero_select_screen.tscn",
	]:
		var ps: PackedScene = load(p)
		var inst := ps.instantiate()
		add_child(inst)
		var bg := inst.get_node_or_null("Background")
		if bg == null:
			bg = inst.get_node_or_null("event_bg")
		var border := inst.get_node_or_null("Border") as CanvasItem
		_assert_true(bg != null and border != null, p + " has Background and Border")
		if bg != null and border != null:
			_assert_true(border.z_index == 0, p + " Border z_index == 0")
			_assert_true(border.get_index() == bg.get_index() + 1, p + " Border immediately above Background")
		inst.queue_free()
		await get_tree().process_frame

	# 2. Verify HeroSelectScreen default Warrior state
	Global.cur_char = null
	var screen := HERO_SELECT_SCENE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var cur_hero: PlayerResource = screen.get_current_hero()
	_assert_true(cur_hero != null and cur_hero.player_class == "Warrior", "Default hero is Warrior")
	_assert_true(screen.nameplate_label.text == "Warrior", "Nameplate displays Warrior")
	_assert_true(screen.might_label.text == "20", "Might globe shows 20")
	_assert_true(screen.grit_label.text == "3", "Grit globe shows 3")
	_assert_true(screen.agility_label.text == "2", "Agility globe shows 2")
	_assert_true(screen.spirit_label.text == "0", "Spirit globe shows 0")
	_assert_true(screen.placeholder_overlay.visible, "Placeholder visible when portrait_art is null")
	_assert_true(not screen.portrait_art.visible, "PortraitArt hidden when portrait_art is null")
	_assert_true(screen.loadout_dock != null, "LoadoutDock exists")
	if screen.loadout_dock != null:
		var deco := screen.loadout_dock.get_node_or_null("BgDecoration") as CanvasItem
		_assert_true(deco != null and not deco.visible, "LoadoutDock BgDecoration is hidden")
		_assert_true(screen.loadout_dock.preview_character != null and screen.loadout_dock.preview_character.player_class == cur_hero.player_class, "LoadoutDock previews current hero")
		_assert_true(not screen.loadout_dock.row_map.is_empty(), "LoadoutDock populated track rows")
		var red_track: ColorLoadoutTrack = screen.loadout_dock.preview_character.get_track_for_color(100)
		_assert_true(red_track != null and not red_track.equipped_modifiers.is_empty(), "LoadoutDock preview shows equipped starting modifiers")
	_assert_true(Global.cur_char == null, "Global.cur_char stays null during preview")

	# Verify globes shader is non-animated
	var might_rect := screen.find_child("MightLiquid", true, false) as ColorRect
	_assert_true(might_rect != null, "MightLiquid exists")
	if might_rect != null and might_rect.material is ShaderMaterial:
		var mat := might_rect.material as ShaderMaterial
		_assert_true(is_zero_approx(float(mat.get_shader_parameter("wave_amplitude"))), "Globe wave_amplitude == 0")
		_assert_true(not bool(mat.get_shader_parameter("enable_specks")), "Globe enable_specks == false")

	# 3. Verify 2-hero cycling with portrait_art set
	var custom_hero := WARRIOR_RES.duplicate(true) as PlayerResource
	custom_hero.player_class = "Ranger"
	custom_hero.portrait_art = SAMPLE_PORTRAIT
	custom_hero.might = 12.0
	custom_hero.grit = 5.0
	custom_hero.agility = 8.0
	custom_hero.spirit = 3.0

	var typed_roster: Array[PlayerResource] = [WARRIOR_RES, custom_hero]
	screen.available_characters = typed_roster
	screen._build_roster()
	screen._refresh_hero_display()
	await get_tree().process_frame

	_assert_true(not screen.prev_hero_btn.disabled and not screen.next_hero_btn.disabled, "Arrow buttons enabled for multi-hero roster")
	screen._on_next_hero_pressed()
	await get_tree().process_frame

	_assert_true(screen.nameplate_label.text == "Ranger", "Next arrow switches nameplate to Ranger")
	_assert_true(screen.portrait_art.visible and screen.portrait_art.texture == SAMPLE_PORTRAIT, "PortraitArt shows custom portrait_art")
	_assert_true(not screen.placeholder_overlay.visible, "Placeholder hidden when portrait_art is assigned")
	_assert_true(
		screen.might_label.text == "12" and screen.grit_label.text == "5" and screen.agility_label.text == "8" and screen.spirit_label.text == "3",
		"Stat globes update to Ranger values"
	)

	screen._on_prev_hero_pressed()
	await get_tree().process_frame
	_assert_true(screen.nameplate_label.text == "Warrior", "Prev arrow cycles back to Warrior")

	screen.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
