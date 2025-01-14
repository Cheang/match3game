extends PieceActivation
class_name PieceBaseAttack

@export_enum(
	"physical",
	"magic",
	) var type: int = 0

@export var atk_dmg: float
@export var atk_numb: int

func activate():
	for i in atk_numb:
		var f_value: float
		f_value = atk_dmg + Global.cur_char.proficiency
		if criting:
			f_value = f_value * (1 + Global.cur_char.crit_mutly / 100)

		EnemyData.take_dmg(f_value, type)
