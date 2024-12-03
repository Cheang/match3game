extends Node2D
class_name Player

@onready var player_healthbar: TextureProgressBar = $player_healthbar
@onready var fire: GPUParticles2D = $player_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var armor: TextureRect = $buff_container/armor
@onready var armorlabel: Label = $buff_container/armor/armorlabel
@onready var marmor: TextureRect = $buff_container/marmor
@onready var marmorlabel: Label = $buff_container/marmor/marmorlabel
@onready var move_remaing: Label = $move_remaing
@onready var health: Label = $health

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

var one_time = false

func update():
	move_remaing.text = "Moves Remaing: " + str(Global.cur_char.moves_left)
	health.text = "Health: " + str(Global.cur_char.cur_health) + "/" + str(Global.cur_char.max_health)
	if Global.cur_char.cur_health < 0:
		Global.cur_char.cur_health = 0
	if Global.cur_char.max_health != Global.cur_char.cur_health or Global.cur_char.cur_health <= 0:
		player_healthbar.value = Global.cur_char.cur_health * 100 / Global.cur_char.max_health
	update_buff(marmor,marmorlabel,Global.cur_char.cur_mage_armor)
	update_buff(armor,armorlabel,Global.cur_char.cur_armor)

func _on_player_healthbar_value_changed(value: float) -> void:
	if !one_time:
		fire.visible = true
		one_time = true
	art.set_material(ATTACKED_GLOW)
	move(Vector2((value * 2.85), fire.position.y), .5)
	await get_tree().create_timer(.3).timeout
	art.set_material(null)

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(fire,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func update_buff(buff_art:TextureRect, buff_lable:Label, parameter):
	if !Global.is_null(buff_art):
		if parameter > 0:
			buff_art.visible = true
			buff_lable.text = str(parameter)
		elif parameter <= 0:
			buff_art.visible = false
