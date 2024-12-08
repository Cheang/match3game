extends EnemyAttackBase
class_name	Tile_Destruction_Attack

@export var space_to_destroy: Array[Vector2]

func attack():
	EnemyData.destroy_pieces(space_to_destroy)
