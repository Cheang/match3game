extends PieceActivation
class_name PieceBaseMagicArmor

@export var faith_mult: bool = true
@export var hand_combo_mult: bool = false
@export var mage_armor: int

func activate():
	var cur_char = Global.cur_char
	
	#Calculate base mage armor
	var f_value: float = mage_armor + upgrade + cur_char.faith*float(faith_mult)
	#Apply combo multypler
	if hand_combo_mult:
		cur_char.hand_combo += hand_combo_points_to_give
		f_value *= cur_char.hand_combo
	#Apply crit
	if criting:
		f_value *= (1 + cur_char.crit_mutly / 100)
	#Apply mage armor
	cur_char.modify_stat("cur_mage_armor", f_value)
