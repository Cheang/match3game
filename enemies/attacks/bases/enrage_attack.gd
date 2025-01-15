extends EnemyAttackBase
class_name Enrage_Attack

@export var damage: float

func attack():
	Global.cur_enemy.damage += damage
