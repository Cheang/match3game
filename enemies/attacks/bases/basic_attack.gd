extends EnemyAttackBase
class_name Basic_Attack

@export var damage: float
@export var attacks: int = 1

func attack(context = null):
	var target = context.get("target", Global.cur_char) if (context != null and context is Dictionary) else Global.cur_char
	var attacker = context.get("attacker", Global.cur_enemy) if (context != null and context is Dictionary) else Global.cur_enemy
	if target == null:
		return
	var mult: float = attacker.damage if attacker != null else 1.0
	for i in attacks:
		target.take_damage(damage * mult)
		
