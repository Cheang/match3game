extends EnemyAttackBase
class_name Enrage_Attack

@export var damage: float

func attack(context = null):
	var attacker = context.get("attacker", Global.cur_enemy) if (context != null and context is Dictionary) else Global.cur_enemy
	if attacker != null:
		attacker.damage += damage
