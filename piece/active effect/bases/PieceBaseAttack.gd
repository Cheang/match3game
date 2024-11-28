extends PieceActivation
class_name PieceBaseAttack

@export var atk_dmg: float
@export var atk_numb: int

func activate():
	for i in atk_numb:
		var final_dmg: float
		if criting:
			final_dmg = (atk_dmg + PlayerData.dmg) * PlayerData.crit_dmg
		else:
			final_dmg = atk_dmg + PlayerData.dmg
		EnemyData.take_dmg(final_dmg)
