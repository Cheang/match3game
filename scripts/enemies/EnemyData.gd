extends Node

var resource: EnemyResource
var all_minions: Array[EnemyResource] = [preload("res://enemies/minion/karjaliia_cap/karjaliia_cap_1.tres"),]
var bosses: Array[EnemyResource] = [preload("res://enemies/boss/lamia/lamia.tres"),]
#health_variables_____________________________________________________________#
var health_scaler: float = .4
var max_health: float
var cur_health: float
#damageing_variables__________________________________________________________#
var damage_scaler: float = .2
var damage: float
var attacks_p1: Array[EnemyAttackBase]
var attacks_p2: Array[EnemyAttackBase]
var attacks_p3: Array[EnemyAttackBase]
var attacks_p4: Array[EnemyAttackBase]
var next_attack: EnemyAttackBase

var level: int
var type: int
var has_phases: bool
var sprite: PackedScene
var health_bar: Texture2D

var phase: int = 1

var empty_spaces: Array[Vector2]
var ice_spaces: Array[Vector2]
var freeze_spaces: Array[Vector2]

func set_enemie_stats():
	max_health = round(resource.health + (health_scaler * Global.current_wave))
	cur_health = round(resource.health + (health_scaler * Global.current_wave))
	damage = round(resource.damage + (damage_scaler * Global.current_wave))
	attacks_p1 = resource.attacks
	attacks_p2 = resource.attacks_p2
	attacks_p3 = resource.attacks_p3
	attacks_p4 = resource.attacks_p4
	level = resource.level
	type = resource.type
	has_phases = resource.has_phases
	sprite = resource.sprite
	health_bar = resource.health_bar
	
	empty_spaces = resource.empty_spaces
	ice_spaces = resource.ice_spaces
	freeze_spaces = resource.freeze_spaces	

func take_dmg(dmg):
	cur_health -= dmg
	if cur_health <= max_health * .75 and has_phases and phase == 1:
		phase = 2
	elif cur_health <= max_health * .5 and has_phases and phase == 2:
		phase = 3
	elif cur_health <= max_health * .25 and has_phases and phase == 3:
		phase = 4
	

func set_minion(specific_enemy: EnemyResource):
	resource = specific_enemy.duplicate()

func pick_bosses(targ_level: int):
	pass
	
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
	
