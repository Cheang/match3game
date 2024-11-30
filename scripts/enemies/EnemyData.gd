extends Node

var resource: EnemyResource
var all_minions: Array[EnemyResource] = [preload("res://enemies/lamia.tres")]
var bosses_lvl1: Array[EnemyResource]
var bosses_lvl2: Array[EnemyResource]
var bosses_lvl3: Array[EnemyResource]
var bosses_lvl4: Array[EnemyResource]
var bosses_lvl5: Array[EnemyResource]

var enemy_max_health: float
var enemy_cur_health: float
var enemy_damage: float
var enemy_attacks: Array[EnemyAttackBase]
var enemy_next_attack: EnemyAttackBase
var enemy_type: int
var enemy_sprite: PackedScene
var health_bar: Texture2D

var empty_spaces: Array[Vector2]
var ice_spaces: Array[Vector2]
var freeze_spaces: Array[Vector2]

func set_enemie_stats():
	enemy_max_health = resource.health
	enemy_cur_health = resource.health
	enemy_damage = resource.damage
	enemy_attacks = resource.attacks
	enemy_type = resource.type
	empty_spaces = resource.empty_spaces
	ice_spaces = resource.ice_spaces
	freeze_spaces = resource.freeze_spaces
	enemy_sprite = resource.sprite
	health_bar = resource.health_bar

func take_dmg(dmg):
	enemy_cur_health -= dmg

func pick_random_minion():
	resource = all_minions.pick_random()

func pick_bosses():
	pass
	
func pick_next_attack():
	randomize()
	enemy_next_attack = enemy_attacks.pick_random()
