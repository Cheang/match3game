extends PieceActivation
class_name PieceBaseDefence

@export var armor: float
@export var mage_armor: int

func activate():
	if criting:
		PlayerData.armor += armor * 2
		PlayerData.mage_armor += mage_armor * 2
	else:
		PlayerData.armor += armor
		PlayerData.mage_armor += mage_armor
