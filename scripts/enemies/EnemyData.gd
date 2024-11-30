extends Node

var resource: EnemyResource
var all_minions: Array[EnemyResource] = [preload("res://enemies/lamia.tres"), preload("res://enemies/minion/karjaliia_cap/karjaliia_cap.tres")]
var bosses: Array[EnemyResource]
#_____________________________________________________________________________#
var max_health: float
var cur_health: float
var damage: float
var attacks: Array[EnemyAttackBase]
var next_attack: EnemyAttackBase
var level: int
var type: int
var sprite: PackedScene
var health_bar: Texture2D

var empty_spaces: Array[Vector2]
var ice_spaces: Array[Vector2]
var freeze_spaces: Array[Vector2]

func set_enemie_stats():
	max_health = resource.health
	cur_health = resource.health
	damage = resource.damage
	attacks = resource.attacks
	level = resource.level
	type = resource.type
	sprite = resource.sprite
	health_bar = resource.health_bar
	
	empty_spaces = resource.empty_spaces
	ice_spaces = resource.ice_spaces
	freeze_spaces = resource.freeze_spaces	

func take_dmg(dmg):
	cur_health -= dmg

func pick_random_minion():
	resource = all_minions.pick_random()

func pick_bosses(targ_level: int):
	pass
	
func pick_next_attack():
	randomize()
	next_attack = attacks.pick_random()

func destroy_pieces(space_to_destroy: Array[Vector2]):
	get_node("/root/game_window/grd").mark_for_destruction(space_to_destroy)
	
