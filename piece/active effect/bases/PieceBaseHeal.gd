extends PieceActivation
class_name PieceBaseHeal

@export var health: float

func activate():
	var f_value = health
	if criting:
		f_value = f_value * (1 + Global.cur_char.crit_mutly / 100)
	Global.cur_char.add_stat("cur_health",f_value)
