extends Node2D
class_name Player

@export var buff_texture: Array[TextureRect] 
@export var buff_stat: Array[String]

@onready var player_healthbar: TextureProgressBar = $player_healthbar
@onready var fire: GPUParticles2D = $player_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var move_remaing: Label = $move_remaing
@onready var health: Label = $health

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

var one_time = false
var char = Global.cur_char

func _ready() -> void:
	health.text = "Health: %d / %d" % [char.cur_health, char.max_health]
	player_healthbar.value = char.cur_health * 100.0 / char.max_health
	update_buffs()

func _on_player_healthbar_value_changed(value: float) -> void:
	if not one_time:
		one_time = true
		fire.visible = true
	if char.cur_health == char.max_health and one_time:
		fire.visible = false
		one_time = false
	art.set_material(ATTACKED_GLOW)
	move(Vector2((value * 2.85), fire.position.y), 0.5)
	await get_tree().create_timer(0.3).timeout
	art.set_material(null)

func move(target, time = 0.3):
	var tween: Tween = create_tween()
	tween.tween_property(fire,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func update_buff(buff_art:TextureRect, parameter):
	if !Global.is_null(buff_art):
		if parameter > 0:
			buff_art.visible = true
			buff_art.get_child(0).text = str(parameter)
		elif parameter <= 0:
			buff_art.visible = false

func update_buffs():
	for i in buff_texture.size():
		var stat = Global.cur_char.get(buff_stat[i])
		update_buff(buff_texture[i], stat)

func update_move_counter():
	move_remaing.text = "Moves Remaing: %d" % char.moves_left

func _on_grd_move_made() -> void:
	update_move_counter()
	update_buffs()

func _on_game_window_player_health_change() -> void:
	health.text = "Health: %d / %d" % [char.cur_health, char.max_health]
	player_healthbar.value = char.cur_health * 100.0 / char.max_health
	update_buffs()
