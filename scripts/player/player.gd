extends Node2D
class_name Player

@export var bool_buff_texture: Array[TextureRect] 
@export var bool_buff_stat: Array[String]
@export var buff_texture: Array[TextureRect] 
@export var buff_stat: Array[String]

@onready var player_healthbar: TextureProgressBar = $health_buffs/player_healthbar
@onready var fire: GPUParticles2D = $health_buffs/player_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var move_remaing: Label = $move_remaing
@onready var health: Label = $health_buffs/player_healthbar/health

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

var one_time_fire = false
var cur_character = Global.cur_char

func _ready() -> void:
	Global.cur_char.reset_stats_at_beging_of_fight()
	var player_sprite = Global.cur_char.sprite.instantiate()
	art.add_child(player_sprite)
	update_ui("cur_health")
	update_buffs()

func update_ui(stat: String):
	if stat == "cur_health" or stat == "max_health":
		health.text = "HP: %d / %d" % [Global.cur_char.cur_health, Global.cur_char.max_health]
		player_healthbar.value = Global.cur_char.cur_health * 100.0 / Global.cur_char.max_health
		return
	if stat == "moves_left":
		move_remaing.text = "Moves Remaing: %d" % Global.cur_char.moves_left
		return
	if typeof(Global.cur_char.get(stat)) == TYPE_BOOL:
		for i in bool_buff_texture.size():
			var temp = Global.cur_char.get(bool_buff_stat[i])
			updete_bool_buff(bool_buff_texture[i], temp)
	else:
		for i in buff_texture.size():
			var temp = Global.cur_char.get(buff_stat[i])
			update_buff(buff_texture[i], temp)

func _on_player_healthbar_value_changed(value: float) -> void:
	if not one_time_fire:
		one_time_fire = true
		fire.visible = true
	if cur_character.cur_health == cur_character.max_health and one_time_fire:
		fire.visible = false
		one_time_fire = false
	art.set_material(ATTACKED_GLOW)
	move(Vector2((value * 2.85), fire.position.y), 0.5)
	await get_tree().create_timer(0.3).timeout
	art.set_material(null)

func _on_tree_entered() -> void:
	Global.cur_char.updateUI.connect(update_ui)
func _on_tree_exited() -> void:
	Global.cur_char.updateUI.disconnect(update_ui)



#Helper functions --------------------------------------------------------------
func update_buffs():
	for i in buff_texture.size():
		var stat = Global.cur_char.get(buff_stat[i])
		update_buff(buff_texture[i], stat)
	for i in bool_buff_texture.size():
		var stat = Global.cur_char.get(bool_buff_stat[i])
		updete_bool_buff(bool_buff_texture[i], stat)

func update_buff(buff_art:TextureRect, parameter):
	if !Global.is_null(buff_art):
		if parameter > 0:
			buff_art.visible = true
			buff_art.get_child(0).text = str(parameter)
		elif parameter <= 0:
			buff_art.visible = false

func updete_bool_buff(buff_art:TextureRect, parameter):
	if !Global.is_null(buff_art):
		buff_art.visible = parameter

func move(target, time = 0.3):
	var tween: Tween = create_tween()
	tween.tween_property(fire,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
