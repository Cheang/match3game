extends PieceActivation
class_name PieceBaseHeal

@export var health: float


func activate():
	if criting:
		var value: float = health * Global.cur_char.crit_dmg
		Global.cur_char.set_cur_health(Global.cur_char.cur_health + value)
	else:
		var value: float = health
		Global.cur_char.set_cur_health(Global.cur_char.cur_health + value)
