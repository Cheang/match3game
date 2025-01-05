extends PieceActivation
class_name PieceBaseHeal

@export var health: float


func activate():
	if criting:
		var value: float = health * (1 + Global.cur_char.crit_dmg / 100)
		Global.cur_char.set_cur_health(Global.cur_char.cur_health + value)
	else:
		var value: float = health
		Global.cur_char.set_cur_health(Global.cur_char.cur_health + value)
