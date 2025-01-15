extends PieceActivation
class_name PieceBaseHeal

@export var health: float

func activate():
	var cur_char = Global.cur_char
	
	var f_value = health
	if criting:
		f_value *= (1 + cur_char.crit_mutly / 100)
	cur_char.add_stat("cur_health",f_value)
