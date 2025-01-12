extends PieceActivation
class_name PieceHandAttack

@export var atk_dmg: float
@export var hand_combo_multy: float = 1
@export var to_give_before: = true

func activate():
	if to_give_before:
		Global.cur_char.hand_combo += hand_combo_points_to_give
		
	var f_value: float
	f_value = (atk_dmg+Global.cur_char.strength) * (Global.cur_char.hand_combo*hand_combo_multy)
	if criting:
		f_value = f_value * (1 + Global.cur_char.crit_mutly / 100)
	EnemyData.take_dmg(f_value)
	
	if not to_give_before:
		Global.cur_char.hand_combo += hand_combo_points_to_give
	
