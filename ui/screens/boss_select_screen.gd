extends Control

## Boss Selection screen shown after Hero Select and after clearing each run level.
## Picks a random Area for the current stage folder, rolls 1-3 base bosses (plus up to
## 2 conditional bonus bosses), animates wanted posters dropping onto a dynamically
## candle-lit wooden table, lets the player inspect and confirm a boss, and launches the level.

enum State {
	DROPPING,
	BROWSING,
	INSPECTING,
	LOCKING,
	CONFIRMED,
	TRANSITIONING,
}

const WANTED_POSTER_SCENE: PackedScene = preload("res://ui/screens/wanted_poster.tscn")
const CUT_SCENE_PATH: String = "res://events/cut_scene.tscn"
const LOCATIONS_SCREEN_PATH: String = "res://map/locations_screen.tscn"
const TABLE_CENTER_POS: Vector2 = Vector2(288.0, 495.0)
const CANDLE_TABLE_LIGHT_OFFSET: Vector2 = Vector2(94.0, 128.0)
const CENTERED_POSTER_SCALE: Vector2 = Vector2(1.15, 1.15)
const POST_SELECT_LAUNCH_DELAY: float = 0.35
const POSTER_DROP_START_Y: float = -300.0
const POSTER_DROP_DURATION: float = 0.55
const POSTER_DROP_STAGGER: float = 0.16
const TABLE_FADE_IN_DURATION: float = 0.40
const POST_REVEAL_DROP_DELAY: float = 0.12
const INSPECT_ART_WIDTH: float = 412.0
const INSPECT_ART_MAX_HEIGHT: float = 360.0

@export_group("Lighting")
@export_range(0.0, 2.5, 0.05) var light_strength: float = 1.0:
	set(value):
		light_strength = clampf(value, 0.0, 2.5)
		if is_node_ready():
			_update_lighting_visuals()
@export_range(0.0, 2.0, 0.05) var light_contrast: float = 1.0:
	set(value):
		light_contrast = clampf(value, 0.0, 2.0)
		if is_node_ready():
			_update_lighting_visuals()

@export_group("Interaction")
## Bounds within TableStage where wanted contracts can be dragged (below candle & "Choose Boss" carving).
@export var poster_drag_bounds: Rect2 = Rect2(24.0, 270.0, 528.0, 734.0)

var current_state: State = State.DROPPING
var auto_transition_on_select: bool = true
var current_area: LocationLoader = null
var boss_choices: Array[Location] = []
var spawned_posters: Array[WantedPoster] = []
var inspected_poster: WantedPoster = null
var selected_poster: WantedPoster = null

var _poster_slots: Dictionary = {} # WantedPoster -> { "center": Vector2, "rot": float }
var _intro_tween: Tween = null
var _drop_tween: Tween = null
var _inspect_tween: Tween = null
var _lock_tween: Tween = null
var _inspect_panel_home_pos: Vector2 = Vector2(48.0, 134.0)

@onready var table_sprite: TextureRect = find_child("TableSprite", true, false) as TextureRect
@onready var table_sides_sprite: TextureRect = find_child("TableSidesSprite", true, false) as TextureRect
@onready var candle_glow: Control = find_child("CandleGlow", true, false) as Control
@onready var candle_sprite: TextureRect = find_child("CandleSprite", true, false) as TextureRect
@onready var candle_flame: CandleFlame = find_child("CandleFlame", true, false) as CandleFlame
@onready var poster_layer: Control = find_child("PosterLayer", true, false) as Control
@onready var inspect_overlay: Control = find_child("InspectOverlay", true, false) as Control
@onready var dim_backdrop: Control = find_child("DimBackdrop", true, false) as Control
@onready var bounty_info_panel: Control = find_child("BountyInfoPanel", true, false) as Control
@onready var inspect_title_label: Label = find_child("InspectTitleLabel", true, false) as Label
@onready var inspect_art_frame: Control = find_child("InspectArtFrame", true, false) as Control
@onready var inspect_art_rect: TextureRect = find_child("InspectArtRect", true, false) as TextureRect
@onready var inspect_desc_label: Label = find_child("InspectDescLabel", true, false) as Label
@onready var select_poster_btn: Button = find_child("SelectPosterBtn", true, false) as Button
@onready var put_back_btn: Button = find_child("PutBackBtn", true, false) as Button


func _ready() -> void:
	if Global.run_stage_queue.is_empty():
		Global.init_default_run_stages(Global.DEFAULT_RUN_LEVELS)
	if Global.cur_char == null:
		Global.set_up_player()

	Global.cur_scene = "res://ui/screens/boss_select_screen.tscn"
	Global.game_is_played = false

	if inspect_overlay != null:
		inspect_overlay.visible = false
		inspect_overlay.modulate.a = 0.0

	if bounty_info_panel != null:
		_inspect_panel_home_pos = bounty_info_panel.position
		bounty_info_panel.pivot_offset = bounty_info_panel.size * 0.5

	if dim_backdrop != null and not dim_backdrop.gui_input.is_connected(_on_dim_backdrop_gui_input):
		dim_backdrop.gui_input.connect(_on_dim_backdrop_gui_input)
	if select_poster_btn != null and not select_poster_btn.pressed.is_connected(_on_select_poster_pressed):
		select_poster_btn.pressed.connect(_on_select_poster_pressed)
	if put_back_btn != null and not put_back_btn.pressed.is_connected(_on_put_back_pressed):
		put_back_btn.pressed.connect(_on_put_back_pressed)

	_roll_stage_and_bosses()
	_spawn_posters()
	_update_lighting_visuals()
	call_deferred("_begin_intro_sequence")


func _exit_tree() -> void:
	if SceneManager != null and SceneManager.transition_finished.is_connected(_on_scene_transition_finished):
		SceneManager.transition_finished.disconnect(_on_scene_transition_finished)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if current_state == State.INSPECTING and (_inspect_tween == null or not _inspect_tween.is_running()):
			if bounty_info_panel != null:
				bounty_info_panel.position = _get_inspect_panel_home_pos()


func _process(_delta: float) -> void:
	_update_lighting_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_state == State.INSPECTING:
			put_back_poster()
			get_viewport().set_input_as_handled()


func get_state() -> State:
	return current_state


func _roll_stage_and_bosses() -> void:
	var stage_id: String = Global.get_current_stage_id()
	current_area = Locations.pick_random_area_for_stage(stage_id, Global.visited_area_paths)
	if current_area != null:
		boss_choices = Locations.roll_boss_choices(current_area, Global.cur_char, Global.current_level)
	else:
		boss_choices.clear()


func _get_slot_layouts(count: int) -> Array[Dictionary]:
	match count:
		1:
			return [
				{ "center": TABLE_CENTER_POS, "rot": deg_to_rad(-2.0) }
			]
		2:
			return [
				{ "center": Vector2(175.0, 430.0), "rot": deg_to_rad(6.0) },
				{ "center": Vector2(395.0, 550.0), "rot": deg_to_rad(-5.0) },
			]
		_:
			var slots: Array[Dictionary] = [
				{ "center": Vector2(396.0, 390.0), "rot": deg_to_rad(-6.0) },
				{ "center": Vector2(160.0, 490.0), "rot": deg_to_rad(7.0) },
				{ "center": Vector2(380.0, 650.0), "rot": deg_to_rad(-5.0) },
				{ "center": Vector2(165.0, 760.0), "rot": deg_to_rad(5.0) },
				{ "center": Vector2(280.0, 405.0), "rot": deg_to_rad(2.0) },
			]
			return slots


func _spawn_posters() -> void:
	if poster_layer == null:
		return
	for child in poster_layer.get_children():
		child.queue_free()
	spawned_posters.clear()
	_poster_slots.clear()

	var layouts := _get_slot_layouts(boss_choices.size())
	for i in range(boss_choices.size()):
		var poster := WANTED_POSTER_SCENE.instantiate() as WantedPoster
		poster_layer.add_child(poster)
		poster.setup(boss_choices[i])
		poster.set_interactive(false)
		if not poster.poster_clicked.is_connected(_on_poster_clicked):
			poster.poster_clicked.connect(_on_poster_clicked)
		if not poster.poster_drag_started.is_connected(_on_poster_drag_started):
			poster.poster_drag_started.connect(_on_poster_drag_started)
		if not poster.poster_drag_moved.is_connected(_on_poster_drag_moved):
			poster.poster_drag_moved.connect(_on_poster_drag_moved)
		if not poster.poster_drag_ended.is_connected(_on_poster_drag_ended):
			poster.poster_drag_ended.connect(_on_poster_drag_ended)

		var slot: Dictionary = layouts[mini(i, layouts.size() - 1)]
		var slot_center: Vector2 = slot["center"]
		var slot_rot: float = float(slot["rot"])
		_poster_slots[poster] = {
			"center": slot_center,
			"rot": slot_rot,
			"index": i
		}

		# Position above the viewport before dropping onto the table
		poster.set_center_position(Vector2(slot_center.x + randf_range(-16.0, 16.0), POSTER_DROP_START_Y))
		poster.rotation = slot_rot + randf_range(-0.14, 0.14)
		poster.scale = Vector2(1.14, 1.14)
		spawned_posters.append(poster)


func _begin_intro_sequence() -> void:
	if current_state != State.DROPPING:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if SceneManager != null and SceneManager.is_transitioning:
		for node in [table_sprite, table_sides_sprite, candle_sprite, candle_glow]:
			if node != null:
				node.modulate.a = 1.0
		if not SceneManager.transition_finished.is_connected(_on_scene_transition_finished):
			SceneManager.transition_finished.connect(_on_scene_transition_finished, CONNECT_ONE_SHOT)
	else:
		for node in [table_sprite, table_sides_sprite, candle_sprite, candle_glow]:
			if node != null:
				node.modulate.a = 0.0
		_intro_tween = create_tween().set_parallel(true)
		for node in [table_sprite, table_sides_sprite, candle_sprite, candle_glow]:
			if node != null:
				_intro_tween.tween_property(node, "modulate:a", 1.0, TABLE_FADE_IN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_intro_tween.chain().tween_interval(POST_REVEAL_DROP_DELAY)
		_intro_tween.chain().tween_callback(_run_drop_in_animation)


func _on_scene_transition_finished() -> void:
	if current_state != State.DROPPING:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(POST_REVEAL_DROP_DELAY)
	_intro_tween.tween_callback(_run_drop_in_animation)


func _run_drop_in_animation() -> void:
	if current_state != State.DROPPING:
		return
	if spawned_posters.is_empty():
		current_state = State.BROWSING
		return

	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()

	_drop_tween = create_tween().set_parallel(true)
	for i in range(spawned_posters.size()):
		var poster := spawned_posters[i]
		var slot: Dictionary = _poster_slots[poster]
		var target_top_left := poster.get_top_left_for_center(slot["center"])
		var target_rot: float = float(slot["rot"])
		var delay := float(i) * POSTER_DROP_STAGGER
		_drop_tween.tween_property(poster, "position", target_top_left, POSTER_DROP_DURATION).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_drop_tween.tween_property(poster, "rotation", target_rot, POSTER_DROP_DURATION).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_drop_tween.tween_property(poster, "scale", Vector2.ONE, POSTER_DROP_DURATION).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_drop_tween.chain().tween_callback(_finish_drop_in)


func finish_drop_immediately() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if SceneManager != null and SceneManager.transition_finished.is_connected(_on_scene_transition_finished):
		SceneManager.transition_finished.disconnect(_on_scene_transition_finished)
	for node in [table_sprite, table_sides_sprite, candle_sprite, candle_glow]:
		if node != null:
			node.modulate.a = 1.0
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	for poster in spawned_posters:
		var slot: Dictionary = _poster_slots[poster]
		poster.set_center_position(slot["center"])
		poster.rotation = float(slot["rot"])
		poster.scale = Vector2.ONE
	_finish_drop_in()


func _finish_drop_in() -> void:
	if current_state != State.DROPPING:
		return
	current_state = State.BROWSING
	for poster in spawned_posters:
		poster.set_interactive(true)


func clamp_poster_center_to_bounds(poster: WantedPoster, center: Vector2) -> Vector2:
	var half: Vector2 = (poster.size * 0.5) if (poster != null and poster.size.x > 0.0 and poster.size.y > 0.0) else Vector2(90.0, 100.0)
	var min_x := poster_drag_bounds.position.x + half.x
	var max_x := poster_drag_bounds.end.x - half.x
	var min_y := poster_drag_bounds.position.y + half.y
	var max_y := poster_drag_bounds.end.y - half.y
	var cx := (min_x + max_x) * 0.5 if min_x > max_x else clampf(center.x, min_x, max_x)
	var cy := (min_y + max_y) * 0.5 if min_y > max_y else clampf(center.y, min_y, max_y)
	return Vector2(cx, cy)


func _on_poster_clicked(poster: WantedPoster) -> void:
	if poster == null:
		return
	if current_state == State.BROWSING:
		inspect_poster_node(poster)


func _on_poster_drag_started(poster: WantedPoster) -> void:
	if poster == null or current_state != State.BROWSING:
		return
	if poster_layer != null and poster.get_parent() == poster_layer:
		poster_layer.move_child(poster, -1)
	poster.z_index = 4


func _on_poster_drag_moved(poster: WantedPoster, target_center: Vector2) -> void:
	if poster == null or current_state != State.BROWSING:
		return
	var clamped := clamp_poster_center_to_bounds(poster, target_center)
	poster.set_center_position(clamped)
	if _poster_slots.has(poster):
		_poster_slots[poster]["center"] = clamped


func _on_poster_drag_ended(poster: WantedPoster) -> void:
	if poster == null:
		return
	poster.z_index = 0
	var clamped := clamp_poster_center_to_bounds(poster, poster.get_center_position())
	poster.set_center_position(clamped)
	if _poster_slots.has(poster):
		_poster_slots[poster]["center"] = clamped
		_poster_slots[poster]["rot"] = poster.get_resting_rotation()


func inspect_poster(index: int) -> void:
	if index >= 0 and index < spawned_posters.size():
		inspect_poster_node(spawned_posters[index])


func inspect_poster_node(poster: WantedPoster) -> void:
	if poster == null or (current_state != State.BROWSING and current_state != State.DROPPING):
		return
	if current_state == State.DROPPING:
		finish_drop_immediately()

	current_state = State.INSPECTING
	inspected_poster = poster
	for p in spawned_posters:
		p.set_interactive(false)
		p.z_index = 0

	_populate_inspect_panel(poster)

	if inspect_overlay != null:
		inspect_overlay.visible = true
		inspect_overlay.modulate.a = 0.0

	var panel_pivot := Vector2(240.0, 378.0)
	var fold_scale := _get_small_poster_scale(poster)
	var home_pos := _get_inspect_panel_home_pos()
	if bounty_info_panel != null:
		bounty_info_panel.pivot_offset = bounty_info_panel.size * 0.5
		panel_pivot = bounty_info_panel.pivot_offset
		var poster_global_center := poster.global_position + poster.pivot_offset
		var overlay_global := inspect_overlay.global_position if inspect_overlay != null else Vector2.ZERO
		bounty_info_panel.position = (poster_global_center - overlay_global) - panel_pivot
		bounty_info_panel.scale = fold_scale
		bounty_info_panel.rotation = poster.rotation
		bounty_info_panel.modulate.a = 0.0

	var overlay_global_pos := inspect_overlay.global_position if inspect_overlay != null else Vector2.ZERO
	var panel_global_center := overlay_global_pos + home_pos + panel_pivot
	var layer_global_pos := poster_layer.global_position if poster_layer != null else Vector2.ZERO
	var target_top_left := poster.get_top_left_for_center(panel_global_center - layer_global_pos)

	if _inspect_tween != null and _inspect_tween.is_valid():
		_inspect_tween.kill()
	_inspect_tween = create_tween().set_parallel(true)
	_inspect_tween.tween_property(poster, "position", target_top_left, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(poster, "scale", Vector2(1.45, 1.45), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(poster, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(poster, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	if bounty_info_panel != null:
		_inspect_tween.tween_property(bounty_info_panel, "position", home_pos, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_inspect_tween.tween_property(bounty_info_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_inspect_tween.tween_property(bounty_info_panel, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_inspect_tween.tween_property(bounty_info_panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if inspect_overlay != null:
		_inspect_tween.tween_property(inspect_overlay, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _get_inspect_art_target_width() -> float:
	if inspect_art_frame != null and inspect_art_frame.size.x > 1.0:
		return inspect_art_frame.size.x
	if bounty_info_panel != null and bounty_info_panel.size.x > 1.0:
		var margin := bounty_info_panel.get_node_or_null("ContentMargin") as MarginContainer
		if margin != null:
			var ml := margin.get_theme_constant("margin_left")
			var mr := margin.get_theme_constant("margin_right")
			return maxf(64.0, bounty_info_panel.size.x - float(ml + mr))
		return maxf(64.0, bounty_info_panel.size.x)
	return INSPECT_ART_WIDTH


func _apply_inspect_art_texture(art_tex: Texture2D) -> void:
	if inspect_art_frame == null or inspect_art_rect == null:
		return
	inspect_art_rect.texture = art_tex
	if art_tex == null:
		inspect_art_rect.visible = false
		inspect_art_frame.visible = false
		inspect_art_frame.custom_minimum_size = Vector2.ZERO
		inspect_art_rect.custom_minimum_size = Vector2.ZERO
		return

	var tex_size := art_tex.get_size()
	var target_w := _get_inspect_art_target_width()
	var target_h := 210.0
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		target_h = clampf(roundf(target_w * (tex_size.y / tex_size.x)), 1.0, INSPECT_ART_MAX_HEIGHT)
	inspect_art_frame.custom_minimum_size = Vector2(0.0, target_h)
	inspect_art_rect.custom_minimum_size = Vector2(0.0, target_h)
	inspect_art_rect.visible = true
	inspect_art_frame.visible = true


func _populate_inspect_panel(poster: WantedPoster) -> void:
	if inspect_title_label != null:
		inspect_title_label.text = poster.get_poster_title()
	_apply_inspect_art_texture(poster.get_inspect_art_texture())
	if inspect_desc_label != null:
		inspect_desc_label.text = poster.get_poster_description()


func _get_small_poster_scale(poster: WantedPoster) -> Vector2:
	if poster != null and bounty_info_panel != null and bounty_info_panel.size.x > 0.0 and bounty_info_panel.size.y > 0.0:
		return Vector2(poster.size.x / bounty_info_panel.size.x, poster.size.y / bounty_info_panel.size.y)
	return Vector2(0.375, 0.375)


func _get_inspect_panel_home_pos() -> Vector2:
	if inspect_overlay != null and bounty_info_panel != null and inspect_overlay.size.x > 0.0 and inspect_overlay.size.y > 0.0:
		return ((inspect_overlay.size - bounty_info_panel.size) * 0.5).round()
	return _inspect_panel_home_pos


func _reset_inspect_panel_transform() -> void:
	if bounty_info_panel != null:
		bounty_info_panel.position = _get_inspect_panel_home_pos()
		bounty_info_panel.scale = Vector2.ONE
		bounty_info_panel.rotation = 0.0
		bounty_info_panel.modulate.a = 1.0


func put_back_poster() -> void:
	if current_state != State.INSPECTING or inspected_poster == null:
		return

	var poster := inspected_poster
	inspected_poster = null
	var slot: Dictionary = _poster_slots[poster]
	var slot_center: Vector2 = slot["center"]
	var slot_top_left := poster.get_top_left_for_center(slot_center)
	var slot_rot: float = float(slot["rot"])

	if _inspect_tween != null and _inspect_tween.is_valid():
		_inspect_tween.kill()
	_inspect_tween = create_tween().set_parallel(true)
	_inspect_tween.tween_property(poster, "position", slot_top_left, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(poster, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(poster, "rotation", slot_rot, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inspect_tween.tween_property(poster, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	if bounty_info_panel != null:
		var slot_global_center := (poster_layer.global_position if poster_layer != null else Vector2.ZERO) + slot_center
		var overlay_global := inspect_overlay.global_position if inspect_overlay != null else Vector2.ZERO
		var back_pos := (slot_global_center - overlay_global) - bounty_info_panel.pivot_offset
		_inspect_tween.tween_property(bounty_info_panel, "position", back_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_inspect_tween.tween_property(bounty_info_panel, "scale", _get_small_poster_scale(poster), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_inspect_tween.tween_property(bounty_info_panel, "rotation", slot_rot, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_inspect_tween.tween_property(bounty_info_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	if inspect_overlay != null:
		_inspect_tween.tween_property(inspect_overlay, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)

	_inspect_tween.chain().tween_callback(func():
		poster.z_index = 0
		if inspect_overlay != null:
			inspect_overlay.visible = false
		_reset_inspect_panel_transform()
		current_state = State.BROWSING
		for p in spawned_posters:
			p.set_interactive(true)
	)


func confirm_poster_selection() -> void:
	if current_state != State.INSPECTING or inspected_poster == null:
		return

	current_state = State.LOCKING
	selected_poster = inspected_poster
	inspected_poster = null
	selected_poster.z_index = 5

	if _inspect_tween != null and _inspect_tween.is_valid():
		_inspect_tween.kill()
	if _lock_tween != null and _lock_tween.is_valid():
		_lock_tween.kill()

	_lock_tween = create_tween().set_parallel(true)
	if bounty_info_panel != null:
		_lock_tween.tween_property(bounty_info_panel, "scale", Vector2(0.60, 0.60), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_lock_tween.tween_property(bounty_info_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	if inspect_overlay != null:
		_lock_tween.tween_property(inspect_overlay, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)

	# Shove all other posters cleanly off the left/right edges of the table
	for p in spawned_posters:
		p.set_interactive(false)
		if p == selected_poster:
			continue
		var p_center := p.get_center_position()
		var go_left := p_center.x < TABLE_CENTER_POS.x
		var off_x := -340.0 if go_left else 916.0
		var off_y := p_center.y + randf_range(-40.0, 60.0)
		var spin := randf_range(-0.55, -0.28) if go_left else randf_range(0.28, 0.55)
		var off_top_left := p.get_top_left_for_center(Vector2(off_x, off_y))
		_lock_tween.tween_property(p, "position", off_top_left, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_lock_tween.tween_property(p, "rotation", p.rotation + spin, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_lock_tween.tween_property(p, "modulate:a", 0.0, 0.32).set_delay(0.06)

	# Center the selected poster neatly in the candlelight on the table
	var centered_top_left := selected_poster.get_top_left_for_center(TABLE_CENTER_POS)
	_lock_tween.tween_property(selected_poster, "position", centered_top_left, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lock_tween.tween_property(selected_poster, "scale", CENTERED_POSTER_SCALE, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lock_tween.tween_property(selected_poster, "rotation", -0.02, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lock_tween.tween_property(selected_poster, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)

	_lock_tween.chain().tween_callback(func():
		if inspect_overlay != null:
			inspect_overlay.visible = false
		_reset_inspect_panel_transform()
		for p in spawned_posters:
			if p != selected_poster:
				p.visible = false
		if selected_poster != null:
			selected_poster.set_interactive(false)
		current_state = State.CONFIRMED
		if auto_transition_on_select:
			var delay_tween := create_tween()
			delay_tween.tween_interval(POST_SELECT_LAUNCH_DELAY)
			delay_tween.tween_callback(_launch_selected_boss)
	)


func _on_dim_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_state == State.INSPECTING:
			put_back_poster()
			get_viewport().set_input_as_handled()


func _on_select_poster_pressed() -> void:
	confirm_poster_selection()


func _on_put_back_pressed() -> void:
	put_back_poster()


func _launch_selected_boss() -> void:
	if current_state == State.TRANSITIONING or selected_poster == null or selected_poster.boss_location == null:
		return
	current_state = State.TRANSITIONING

	var chosen_boss: Location = selected_poster.boss_location
	if current_area != null:
		Locations.load_locations_from_directory(current_area)
		Locations.pick_locations(
			Global.area_locations,
			current_area.enemy_loc_numb,
			current_area.event_loc_numb,
			current_area.services_loc_numb,
			chosen_boss
		)
	else:
		Global.area_cur_boss = chosen_boss.duplicate(true)

	Global.save()

	if Global.area_cur_boss != null and Global.area_cur_boss.cut_scene != null:
		Global.cur_cutscene = Global.area_cur_boss.cut_scene
		Global.cur_scene = CUT_SCENE_PATH
		SceneManager.change_scene(CUT_SCENE_PATH, { "pattern": "diagonal", "color": Color("#2e222f") })
	else:
		Global.cur_scene = LOCATIONS_SCREEN_PATH
		SceneManager.change_scene(LOCATIONS_SCREEN_PATH, { "pattern": "diagonal", "color": Color("#2e222f") })


func _apply_table_light_to_rect(rect: TextureRect, table_light_global: Vector2, flicker: float, source_mat: ShaderMaterial = null) -> void:
	if rect == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		return
	var light_uv := (table_light_global - rect.global_position) / rect.size
	mat.set_shader_parameter("light_pos_uv", light_uv)
	mat.set_shader_parameter("flicker", flicker)
	mat.set_shader_parameter("light_strength", light_strength)
	mat.set_shader_parameter("light_contrast", light_contrast)
	# Keep side-extension table light bands synchronized with Inspector edits on TableSprite
	if source_mat != null and source_mat != mat:
		for param in [
			"pixel_snap",
			"ring_inner_radius",
			"ring_mid_radius",
			"ring_outer_radius",
			"inner_flicker_px",
			"mid_flicker_px",
			"outer_flicker_px",
			"allow_hot_highlight",
			"palette_deep",
			"palette_dark",
			"palette_mid",
			"palette_bright",
			"palette_hot",
		]:
			var val: Variant = source_mat.get_shader_parameter(param)
			if val != null:
				mat.set_shader_parameter(param, val)


func _update_lighting_visuals() -> void:
	var flicker := candle_flame.get_flicker_value() if candle_flame != null else 1.0
	var jitter := candle_flame.get_flame_jitter_offset() if candle_flame != null else Vector2.ZERO
	var table_light_global := (candle_sprite.global_position + CANDLE_TABLE_LIGHT_OFFSET + jitter * 0.5) if candle_sprite != null else Vector2(102.0, 204.0)

	var table_mat := table_sprite.material as ShaderMaterial if table_sprite != null else null
	_apply_table_light_to_rect(table_sprite, table_light_global, flicker)
	_apply_table_light_to_rect(table_sides_sprite, table_light_global, flicker, table_mat)

	if candle_flame != null:
		candle_flame.visible = light_strength > 0.01
		if candle_flame.visible:
			candle_flame.scale = Vector2.ONE * clampf(0.65 + 0.35 * light_strength, 0.4, 1.35)

	if candle_glow != null:
		if candle_flame != null:
			var glow_center := candle_flame.global_position + Vector2(0.0, -6.0) + jitter * 0.5
			candle_glow.global_position = (glow_center - candle_glow.size * 0.5).round()
		var glow_mat := candle_glow.material as ShaderMaterial
		if glow_mat != null:
			glow_mat.set_shader_parameter("flicker", flicker)
			glow_mat.set_shader_parameter("light_strength", light_strength)
			glow_mat.set_shader_parameter("rect_size", candle_glow.size)

	for p in spawned_posters:
		if p != null and p.visible:
			p.update_candle_lighting(table_light_global, flicker, p == inspected_poster, light_strength)
