extends PieceActivation
class_name PieceBaseAttack

@export var atk_dmg: float
@export var atk_numb: int

func activate():
	for i in atk_numb:
		var final_dmg: float
		if criting:
			final_dmg = (atk_dmg + Global.cur_char.proficiency) * (1 + Global.cur_char.crit_mutly / 100)
		else:
			final_dmg = atk_dmg + Global.cur_char.proficiency
		EnemyData.take_dmg(final_dmg)
