extends EnemyAttackBase
class_name	Tile_Destruction_Attack

@export var space_to_destroy: Array[Vector2]

func attack(context = null):
	var attacker = context.get("attacker", Global.cur_enemy) if (context != null and context is Dictionary) else Global.cur_enemy
	if attacker != null:
		attacker.destroy_pieces(space_to_destroy)
