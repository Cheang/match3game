extends Control

const LOC_DEADEND: Location = preload("res://core/map/encounters/loc_deadend.tres")
const CARD_INTRO_INITIAL_DELAY: float = 0.08
const CARD_INTRO_STAGGER: float = 0.16
const CARD_INTRO_FADE_DURATION: float = 0.34

@export var bg_frames: Array[Texture2D] = []
@export_range(0.03, 1.0, 0.005) var bg_frame_duration: float = 0.115

var transition_on_select: bool = true

var _bg_frame_timer: float = 0.0
var _bg_frame_index: int = 0
var _is_selecting: bool = false
var _intro_tween: Tween = null
var _selection_tween: Tween = null

@onready var background_rect: TextureRect = $background
@onready var bottom_bar: Control = get_node_or_null("bottom_bar") as Control
@onready var loc_holder: VBoxContainer = $loaction_cards/CenterContainer/VBoxContainer/loc_howder
@onready var loc_cards: Array[LocationCard] = [
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card,
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card2,
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card3,
]


func _ready() -> void:
	if background_rect != null and not bg_frames.is_empty():
		background_rect.texture = bg_frames[0]
	for card in loc_cards:
		if card != null:
			if not card.location_selected.is_connected(_on_location_card_selected):
				card.location_selected.connect(_on_location_card_selected)
			card.modulate.a = 0.0
			card.set_interactive(false)
	call_deferred("initialize_scene")


func _exit_tree() -> void:
	if SceneManager != null and SceneManager.transition_finished.is_connected(_on_scene_transition_finished):
		SceneManager.transition_finished.disconnect(_on_scene_transition_finished)


func _process(delta: float) -> void:
	if bg_frames.size() <= 1 or background_rect == null or bg_frame_duration <= 0.0:
		return
	_bg_frame_timer += delta
	if _bg_frame_timer >= bg_frame_duration:
		var steps := int(_bg_frame_timer / bg_frame_duration)
		_bg_frame_timer -= float(steps) * bg_frame_duration
		_bg_frame_index = (_bg_frame_index + steps) % bg_frames.size()
		background_rect.texture = bg_frames[_bg_frame_index]


func initialize_scene() -> void:
	Locations.add_boss_to_locations(Global.area_locations, Global.minions_needed)
	shuffle_areas()
	_set_locations()
	Global.cur_scene = "res://scenes/locations/locations_screen.tscn"
	Global.save()
	Global.game_is_played = true
	_begin_cards_intro()


func _begin_cards_intro() -> void:
	if SceneManager != null and SceneManager.is_transitioning:
		if not SceneManager.transition_finished.is_connected(_on_scene_transition_finished):
			SceneManager.transition_finished.connect(_on_scene_transition_finished, CONNECT_ONE_SHOT)
	else:
		_play_cards_fade_in()


func _on_scene_transition_finished() -> void:
	if not _is_selecting:
		_play_cards_fade_in()


func _play_cards_fade_in() -> void:
	if _is_selecting:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween().set_parallel(true)
	for i in range(loc_cards.size()):
		var card := loc_cards[i]
		if card == null:
			continue
		var delay := CARD_INTRO_INITIAL_DELAY + float(i) * CARD_INTRO_STAGGER
		card.modulate.a = 0.0
		card.set_interactive(false)
		_intro_tween.tween_property(card, "modulate:a", 1.0, CARD_INTRO_FADE_DURATION).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_intro_tween.tween_callback(func():
			if not _is_selecting and is_instance_valid(card):
				card.set_interactive(true)
		).set_delay(delay + CARD_INTRO_FADE_DURATION)


func finish_intro_immediately() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if SceneManager != null and SceneManager.transition_finished.is_connected(_on_scene_transition_finished):
		SceneManager.transition_finished.disconnect(_on_scene_transition_finished)
	if _is_selecting:
		return
	for card in loc_cards:
		if card != null:
			card.modulate.a = 1.0
			card.set_interactive(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _is_selecting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			InventoryOverlay.toggle_overlay()
			get_viewport().set_input_as_handled()


func _on_location_card_selected(card: LocationCard) -> void:
	select_location_card(card)


func select_location_card(selected_card: LocationCard) -> void:
	if _is_selecting or selected_card == null or selected_card.loc_res == null:
		return
	_is_selecting = true
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	Global.game_is_played = false
	selected_card.selected = true
	selected_card.modulate.a = 1.0

	for card in loc_cards:
		if card != null:
			card.set_interactive(false)

	# Keep a spacer in loc_holder so the other two cards stay anchored while burning
	var saved_global_pos := selected_card.global_position
	var saved_size := selected_card.size
	var slot_index := selected_card.get_index()
	if loc_holder != null and selected_card.get_parent() == loc_holder:
		var placeholder := Control.new()
		placeholder.name = "SelectedCardPlaceholder"
		placeholder.custom_minimum_size = saved_size
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loc_holder.add_child(placeholder)
		loc_holder.move_child(placeholder, slot_index)

	selected_card.top_level = true
	selected_card.position = saved_global_pos
	selected_card.size = saved_size
	selected_card.pivot_offset = saved_size * 0.5
	selected_card.z_index = 10

	var stagger_idx := 0
	for card in loc_cards:
		if card != null and card != selected_card:
			card.play_burn_animation(0.62, float(stagger_idx) * 0.06, 1.7 + float(stagger_idx) * 3.13)
			stagger_idx += 1

	var veil := ColorRect.new()
	veil.name = "TransitionVeil"
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = 20
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = selected_card.loc_res.transition_color
	veil.modulate.a = 0.0
	add_child(veil)

	var env_tween := create_tween().set_parallel(true)
	if bottom_bar != null:
		env_tween.tween_property(bottom_bar, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if background_rect != null:
		background_rect.pivot_offset = background_rect.size * 0.5
		env_tween.tween_property(background_rect, "scale", Vector2(1.14, 1.14), 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		env_tween.tween_property(background_rect, "modulate", Color(0.58, 0.50, 0.60, 1.0), 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_selection_tween = create_tween().set_parallel(true)

	var vp_center := get_viewport_rect().size * 0.5
	var center_top_left := vp_center - selected_card.pivot_offset
	_selection_tween.tween_property(selected_card, "position", center_top_left, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_selection_tween.tween_property(selected_card, "scale", Vector2(1.12, 1.12), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_selection_tween.chain().tween_property(selected_card, "scale", Vector2(2.65, 2.65), 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_selection_tween.tween_property(veil, "modulate:a", 1.0, 0.28).set_delay(0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_selection_tween.chain().tween_callback(func():
		selected_card.commit_transition(transition_on_select)
	)


func shuffle_areas() -> void:
	if not Global.flg_game_is_loaded:
		Global.area_locations.shuffle()
	else:
		Global.flg_game_is_loaded = false


func _set_locations() -> void:
	for i in loc_cards.size():
		loc_cards[i].loc_res = Global.area_locations[i] if i < Global.area_locations.size() else LOC_DEADEND
		loc_cards[i].load_btn()
