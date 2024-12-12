extends Control

@onready var pause_overlay: PanelContainer = $pause_overlay
@onready var gold: Label = $MarginContainer/VBoxContainer/HBoxContainer/Control/PanelContainer/CenterContainer/HBoxContainer/VBoxContainer/gold
var grd 
var gold_on_label: int

func _ready() -> void:
	grd = get_parent().get_parent().get_node("grd")
	pause_overlay.visible = false
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
	await get_tree().create_timer(.4).timeout
	Global.game_is_played = true
	if grd != null:
		grd.state = grd.move
	pause_overlay.visible = false

func _on_options_pressed() -> void:
	await get_tree().create_timer(.4).timeout
	pass # Replace with function body.

func _on_back_to_mm_pressed() -> void:
	await get_tree().create_timer(.4).timeout
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })
