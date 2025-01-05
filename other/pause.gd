extends Control

@export var gold_counter: bool = true
@export var pause_btn: bool = true
@export var player_stats_btn = true
@export var title_container: bool = true
@export var title_text: String

@onready var player_class: Label = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/TabContainer/Deck/player_class
@onready var stats: VBoxContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/TabContainer/Stats
@onready var pausebtn: Button = $MarginContainer/VBoxContainer/HBoxContainer/pause_btn
@onready var goldbox: Control = $MarginContainer/VBoxContainer/HBoxContainer/Control
@onready var title: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/PanelContainer
@onready var stats_overlay: MarginContainer = $stats_overlay
@onready var deck_container: HFlowContainer = $stats_overlay/Container/MarginContainer/VBoxContainer/MarginContainer/TabContainer/Deck/ScrollContainer/deck_container
const PIECE_CARD = preload("res://inventory/piece_card.tscn")
var stats_open = false

@onready var pause_overlay: PanelContainer = $pause_overlay
@onready var gold: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/CenterContainer/HBoxContainer/VBoxContainer/gold
var grd 
var gold_on_label: int

func _ready() -> void:
	grd = get_parent().get_parent().get_node("grd")
	pause_overlay.visible = false
	stats_overlay.position = Vector2(stats_overlay.position.x, (stats_overlay.position.y + (stats_overlay.size.y - 200)))
	stats_overlay.visible = true
	if not gold_counter:
		goldbox.modulate = Color(1, 1, 1, 0)
	if not pause_btn:
		pausebtn.modulate = Color(1, 1, 1, 0)
		pausebtn.disabled = true
	if not title_container:
		title.modulate = Color(1, 1, 1, 0)
	set_title(title_text)
	if Global.cur_char != null:
		gold_on_label = Global.cur_char.gold
	gold.text = "%s" % [gold_on_label]

func _process(_delta: float) -> void:
	if Global.cur_char != null:
		if gold_on_label != Global.cur_char.gold:
			gold_on_label = Global.cur_char.gold
			gold.text = "%s" % [gold_on_label]

func _on_pause_btn_pressed() -> void:
	if Global.game_is_played == true:
		Global.game_is_played = false
		
		if grd != null:
			grd.state = grd.wait
		pause_overlay.visible = true

func _on_resume_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	Global.game_is_played = true
	if grd != null:
		grd.state = grd.move
	pause_overlay.visible = false

func _on_options_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	pass # Replace with function body.

func _on_back_to_mm_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func set_title(text: String):
	var titletxt: Label = title.get_child(0)
	titletxt.text = text



func _on_texture_button_pressed() -> void:
	var target_1 = Vector2(0,-(stats_overlay.size.y - 200))
	var target_2 = Vector2(0,(stats_overlay.size.y - 200))
	var actual_target 
	if !stats_open:
		player_class.text = str(Global.cur_char.player_class)
		stats.expand()
		actual_target = stats_overlay.position + target_1
		Global.cur_char.deck_in_game.sort_custom(Global.compare_deck_pieces)
		for piece in Global.cur_char.deck_in_game:
			var cur_piece = PIECE_CARD.instantiate()
			deck_container.add_child(cur_piece)
			cur_piece.set_card(piece)
		move(actual_target)
		stats_open = true
	else:
		actual_target = stats_overlay.position + target_2
		move(actual_target, .8)
		await get_tree().create_timer(.8).timeout
		var deck_cont_children = deck_container.get_children()
		for child in deck_cont_children:
			child.queue_free()
		stats_open = false

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(stats_overlay,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
