extends EnemyAttackBase
class_name Basic_Attack

@export var damage: float
@export var attacks: int = 1

func attack():
	for i in attacks:
		Global.cur_char.take_damage(damage*EnemyData.enemy_damage)
		
