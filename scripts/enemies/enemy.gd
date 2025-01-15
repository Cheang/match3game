extends Node2D
class_name Enemy

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@onready var enemy_healthbar: TextureProgressBar = $enemy_healthbar
@onready var fire: GPUParticles2D = $enemy_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var health: Label = $enemy_healthbar/health
@onready var attack: Label = $PanelContainer/HBoxContainer/attack
@onready var enemy_audio: AudioStreamPlayer = $enemy_audio

var one_time_fire = false

signal enemy_attacked



func _ready() -> void:
	Global.cur_enemy.pick_next_attack()
	attack.text = Global.cur_enemy.next_attack.tooltip
	var enemy_sprite = Global.cur_enemy.sprite.instantiate()
	art.add_child(enemy_sprite)
	art.set_material(Global.cur_enemy.shader)
	enemy_healthbar.texture_progress = Global.cur_enemy.health_bar
	update_health()

func _on_enemy_healthbar_value_changed(value: float) -> void:
	if !one_time_fire:
		fire.visible = true
		one_time_fire = true
	if Global.cur_enemy.max_health == Global.cur_enemy.cur_health and one_time_fire:
		fire.visible = false
		one_time_fire = false
	art.set_material(ATTACKED_GLOW)
	move(Vector2((value * 2.85), fire.position.y), .5)
	await get_tree().create_timer(.3).timeout
	art.set_material(Global.cur_enemy.shader)

func _on_game_window_enemy_attacking() -> void:
	if Global.cur_enemy.next_attack.animation != null:
		art.get_child(0).set_animp(Global.cur_enemy.next_attack.animation)
	if Global.cur_enemy.next_attack.sound != null:
		enemy_audio.stream = Global.cur_enemy.next_attack.sound
		enemy_audio.play()
	await get_tree().create_timer(Global.cur_enemy.next_attack.animation_time).timeout
	Global.cur_enemy.next_attack.attack()
	art.get_child(0).set_animp("RESET")
	art.get_child(0).set_animp("idle")
	Global.cur_enemy.pick_next_attack()
	attack.text = Global.cur_enemy.next_attack.tooltip
	enemy_attacked.emit()

func _on_game_window_enemy_health_change() -> void:
	update_health()

func _on_tree_entered() -> void:
	Global.cur_enemy.updateUIEnemy.connect(update_ui)
	pass # Replace with function body.

func _on_tree_exiting() -> void:
	Global.cur_enemy.updateUIEnemy.disconnect(update_ui)
	pass # Replace with function body.



#Helper_functions --------------------------------------------------------------
func update_health():
	health.text = "HP: %d / %d" % [Global.cur_enemy.cur_health, Global.cur_enemy.max_health]
	enemy_healthbar.value = Global.cur_enemy.cur_health * 100.0 / Global.cur_enemy.max_health

func update_ui(stat: String):
	if stat == "cur_health" or stat == "max_health":
		health.text = "HP: %d / %d" % [Global.cur_enemy.cur_health, Global.cur_enemy.max_health]
		enemy_healthbar.value = Global.cur_enemy.cur_health * 100.0 / Global.cur_enemy.max_health

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(fire,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
