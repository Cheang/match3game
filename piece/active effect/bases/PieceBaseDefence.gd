extends PieceActivation
class_name PieceBaseDefence

@export var armor: float
@export var mage_armor: int

func activate():
	if criting:
		Global.cur_char.cur_armor += (armor + upgrade) * (1 + Global.cur_char.crit_dmg / 100)
		Global.cur_char.cur_mage_armor += (mage_armor + upgrade) * (1 + Global.cur_char.crit_dmg / 100)
	else:
		Global.cur_char.cur_armor += armor + upgrade
		Global.cur_char.cur_mage_armor += mage_armor + upgrade
