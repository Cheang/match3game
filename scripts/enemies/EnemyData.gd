extends Node

var enemy: EnemyResource

#health_variables_____________________________________________________________#
var health_scaler: float = .1
var max_health: float
var cur_health: float
#damageing_variables__________________________________________________________#
var damage_scaler: float = .1
var damage: float
var attacks_p1: Array[EnemyAttackBase]
var attacks_p2: Array[EnemyAttackBase]
var attacks_p3: Array[EnemyAttackBase]
var attacks_p4: Array[EnemyAttackBase]
var next_attack: EnemyAttackBase

var type: int
var has_phases: bool
var sprite: PackedScene
var health_bar: Texture2D

var phase: int = 1

var empty_spaces: Array[Vector2]
var ice_spaces: Array[Vector2]
var freeze_spaces: Array[Vector2]
var rock_spaces: Array[Vector2]
var flesh_spaces: Array[Vector2]

func set_enemie_stats():
	max_health = round(enemy.health + (((health_scaler * Global.current_wave) * Global.current_level)* enemy.health))
	cur_health = round(enemy.health + (((health_scaler * Global.current_wave) * Global.current_level) * enemy.health))
	damage = round(enemy.damage + (damage_scaler * Global.current_wave))
	attacks_p1 = enemy.attacks
	attacks_p2 = enemy.attacks_p2
	attacks_p3 = enemy.attacks_p3
	attacks_p4 = enemy.attacks_p4
	type = enemy.type
	has_phases = enemy.has_phases
	sprite = enemy.sprite
	health_bar = enemy.health_bar
	
	empty_spaces = enemy.empty_spaces
	ice_spaces = enemy.ice_spaces
	freeze_spaces = enemy.freeze_spaces
	rock_spaces = enemy.rock_spaces
	flesh_spaces = enemy.flesh_spaces

func take_dmg(dmg):
	cur_health -= dmg
	if Global.cur_char.life_steal > 0:
		var value = round(dmg * Global.cur_char.life_steal)
		Global.cur_char.set_cur_health(Global.cur_char.cur_health + value)
	if cur_health <= max_health * .75 and has_phases and phase == 1:
		phase = 2
	elif cur_health <= max_health * .5 and has_phases and phase == 2:
		phase = 3
	elif cur_health <= max_health * .25 and has_phases and phase == 3:
		phase = 4

func set_minion(specific_enemy: EnemyResource):
	enemy = specific_enemy.duplicate()

func pick_next_attack():
	randomize()
	if phase == 2 and !attacks_p2.is_empty():
		next_attack = attacks_p2.pick_random()
	elif phase == 3 and !attacks_p3.is_empty():
		next_attack = attacks_p3.pick_random()
	elif phase == 4 and !attacks_p4.is_empty():
		next_attack = attacks_p4.pick_random()
	else:
		next_attack = attacks_p1.pick_random()

func destroy_pieces(space_to_destroy: Array[Vector2]):
	get_node("/root/game_window/grd").mark_for_destruction(space_to_destroy)
