extends PieceActivation
class_name PieceBaseArmor

@export var toughness_mult: bool = true
@export var hand_combo_mult: bool = false

@export var armor: float

func activate():
	var f_value
	
	f_value = armor + upgrade + Global.cur_char.toughness*float(toughness_mult)
	if hand_combo_mult:
		Global.cur_char.hand_combo += hand_combo_points_to_give
		f_value = f_value * Global.cur_char.hand_combo
	if criting:
		f_value = f_value * (1 + Global.cur_char.crit_mutly / 100)

	Global.cur_char.cur_armor += f_value
