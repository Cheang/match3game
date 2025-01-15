extends PieceActivation
class_name PieceBaseArmor

@export var toughness_mult: bool = true
@export var hand_combo_mult: bool = false

@export var armor: float

func activate():
	var cur_char = Global.cur_char
	#Calculate base armor
	var f_value: float = armor + upgrade + cur_char.toughness*float(toughness_mult)
	#Apply combo multypler
	if hand_combo_mult:
		cur_char.hand_combo += hand_combo_points_to_give
		f_value *= cur_char.hand_combo
	#Apply crit
	if criting:
		f_value *= (1 + cur_char.crit_mutly / 100)
	#Apply armor
	cur_char.add_stat("cur_armor", f_value)
