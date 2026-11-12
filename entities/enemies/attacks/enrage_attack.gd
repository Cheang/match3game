class_name EnrageAttack
extends EnemyAttackBase

@export var damage: float = 0.0


func attack(context: Variant = null) -> void:
	var attacker: EnemyResource = context.get("attacker", Global.cur_enemy) if (context != null and context is Dictionary) else Global.cur_enemy
	if attacker != null:
		attacker.damage += damage

