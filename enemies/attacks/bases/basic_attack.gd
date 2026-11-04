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
		var is_crit: bool = attacker.roll_crit() if attacker != null else false
		var crit_factor: float = (1.0 + attacker.crit_mutly / 100.0) if (is_crit and attacker != null) else 1.0
		var final_dmg: float = max(1.0, roundf(damage * mult * crit_factor))
		target.take_damage(final_dmg, false, 0, attacker)
		
