extends Node2D
class_name Enemy

@warning_ignore("unused_signal")
signal enemy_attacked

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@onready var enemy_healthbar: TextureProgressBar = $enemy_healthbar
@onready var fire: GPUParticles2D = $enemy_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var health: Label = $PanelContainer/HBoxContainer/health
@onready var attack: Label = $PanelContainer/HBoxContainer/attack
@onready var enemy_name: Label = $enemy_name
@onready var enemy_audio: AudioStreamPlayer = $enemy_audio

var one_time = false

func _ready() -> void:
	health.text = "Health: %d / %d" % [EnemyData.cur_health, EnemyData.max_health]
	enemy_healthbar.value = EnemyData.cur_health * 100.0 / EnemyData.max_health

func _on_enemy_healthbar_value_changed(value: float) -> void:
	if !one_time:
		fire.visible = true
		one_time = true
	if EnemyData.max_health == EnemyData.cur_health and one_time:
		fire.visible = false
		one_time = false
	art.set_material(ATTACKED_GLOW)
	move(Vector2((value * 2.85), fire.position.y), .5)
	await get_tree().create_timer(.3).timeout
	art.set_material(null)

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(fire,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _on_game_window_enemy_attacking() -> void:
	if EnemyData.next_attack.animation != null:
		art.get_child(0).set_animp(EnemyData.next_attack.animation)
	if EnemyData.next_attack.sound != null:
		enemy_audio.stream = EnemyData.next_attack.sound
		enemy_audio.play()
	await get_tree().create_timer(EnemyData.next_attack.animation_time).timeout
	EnemyData.next_attack.attack()
	art.get_child(0).set_animp("RESET")
	art.get_child(0).set_animp("idle")
	EnemyData.pick_next_attack()
	attack.text = EnemyData.next_attack.tooltip
	emit_signal("enemy_attacked")

func _on_game_window_enemy_health_change() -> void:
	health.text = "Health: %d / %d" % [EnemyData.cur_health, EnemyData.max_health]
	enemy_healthbar.value = EnemyData.cur_health * 100.0 / EnemyData.max_health
