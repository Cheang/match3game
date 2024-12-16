extends Control

@export var gold_counter: bool = true
@export var pause_btn: bool = true
@export var player_stats_btn = true
@export var title_container: bool = true
@export var title_text: String

@onready var pausebtn: Button = $MarginContainer/VBoxContainer/HBoxContainer/pause_btn
@onready var goldbox: Control = $MarginContainer/VBoxContainer/HBoxContainer/Control
@onready var title: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/PanelContainer
@onready var player_stats: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer2/Control/player_stats

@onready var pause_overlay: PanelContainer = $pause_overlay
@onready var gold: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/CenterContainer/HBoxContainer/VBoxContainer/gold
var grd 
var gold_on_label: int

func _ready() -> void:
	#grd = get_parent().get_parent().get_node("grd")
	pause_overlay.visible = false
	if not gold_counter:
		goldbox.modulate = Color(1, 1, 1, 0)
	if not pause_btn:
		pausebtn.modulate = Color(1, 1, 1, 0)
		pausebtn.disabled = true
	if not title_container:
		title.modulate = Color(1, 1, 1, 0)
	player_stats.visible = player_stats_btn
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
