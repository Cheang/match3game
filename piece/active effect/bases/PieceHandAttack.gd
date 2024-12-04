extends PieceActivation
class_name PieceHandAttack

@export var atk_dmg: float

func activate():
	Global.cur_char.hand_combo += 1
	var final_dmg: float
	if criting:
		final_dmg = (atk_dmg * Global.cur_char.hand_combo) * Global.cur_char.crit_dmg
	else:
		final_dmg = atk_dmg * Global.cur_char.hand_combo
	EnemyData.take_dmg(final_dmg)
