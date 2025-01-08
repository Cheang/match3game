extends PieceActivation
class_name PieceBaseDefence

@export var toughness_mult: bool = true
@export var faith_mult: bool = true

@export var armor: float
@export var mage_armor: int

func activate():
	if criting:
		Global.cur_char.cur_armor += (armor + upgrade + Global.cur_char.toughness*float(toughness_mult)) * (1 + Global.cur_char.crit_dmg / 100)
		Global.cur_char.cur_mage_armor += (mage_armor + upgrade + Global.cur_char.faith*float(faith_mult)) * (1 + Global.cur_char.crit_dmg / 100)
	else:
		Global.cur_char.cur_armor += armor + upgrade + Global.cur_char.toughness*float(toughness_mult)
		Global.cur_char.cur_mage_armor += mage_armor + upgrade + Global.cur_char.faith*float(faith_mult)
