extends PieceActivation
class_name PieceBaseDefence

@export var armor: float
@export var mage_armor: int

func activate():
	if criting:
		Global.cur_char.armor += armor * 2
		Global.cur_char.mage_armor += mage_armor * 2
	else:
		Global.cur_char.armor += armor
		Global.cur_char.mage_armor += mage_armor
