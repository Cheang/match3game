extends EnemyAttackBase
class_name Enrage_Attack

@export var damage: float

func attack():
	EnemyData.enemy_damage += damage
