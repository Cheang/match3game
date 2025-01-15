extends PieceActivation
class_name PieceBaseAttack

@export_enum(
	"physical",
	"magic",
	) var type: int = 0

@export var atk_dmg: float
@export var atk_numb: int

func activate():
	var cur_char = Global.cur_char
	var cur_enemy = Global.cur_enemy
	
	for i in atk_numb:
		var f_value: float = atk_dmg + cur_char.proficiency
		if criting:
			f_value *= (1 + cur_char.crit_mutly / 100)

		cur_enemy.take_dmg(f_value, type)
