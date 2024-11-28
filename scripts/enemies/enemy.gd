extends Node2D
class_name Enemy

signal enemy_attacked

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@onready var enemy_healthbar: TextureProgressBar = $enemy_healthbar
@onready var fire: GPUParticles2D = $enemy_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var health: Label = $PanelContainer/HBoxContainer/health
@onready var attack: Label = $PanelContainer/HBoxContainer/attack

var one_time = false
	
func update():
	attack.text = EnemyData.enemy_next_attack.tooltip
	health.text = "Health: " + str(EnemyData.enemy_max_health) + "/" + str(EnemyData.enemy_cur_health)
	if EnemyData.enemy_cur_health < 0:
		EnemyData.enemy_cur_health = 0
	if EnemyData.enemy_max_health != EnemyData.enemy_cur_health or EnemyData.enemy_cur_health <= 0:
		enemy_healthbar.value = EnemyData.enemy_cur_health * 100 / EnemyData.enemy_max_health

func _on_enemy_healthbar_value_changed(value: float) -> void:
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

func _on_game_window_enemy_attacking() -> void:
	if EnemyData.enemy_next_attack.animation != null:
		art.get_child(0).set_animp(EnemyData.enemy_next_attack.animation)
	Global.moves_done = PlayerData.speed
	EnemyData.enemy_next_attack.attack()
	await get_tree().create_timer(.8).timeout
	art.get_child(0).set_animp("idle")
	EnemyData.pick_next_attack()
	emit_signal("enemy_attacked")
	pass # Replace with function body.
