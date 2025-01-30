extends PieceActivation
class_name PieceHandAttack

@export_enum("physical","magic",) 
var type: int = 0

@export var atk_dmg: float
@export var hand_combo_multy: float = 1
@export var use_strength: bool = true
@export var use_upgrades_on_dmg: bool = true
@export var use_upgrades_on_multy: bool = false
@export var to_give_before: bool = true


func activate():
	var cur_char = Global.cur_char
	var cur_enemy = Global.cur_enemy
	
	if to_give_before:
		cur_char.modify_stat("hand_combo", hand_combo_points_to_give)
	
	#Calculate base damage
	var f_value: float = atk_dmg + (cur_char.strength * float(use_strength)) + (upgrade * float(use_upgrades_on_dmg))
	#Apply combo multypler
	f_value += cur_char.hand_combo * (hand_combo_multy + (upgrade * float(use_upgrades_on_dmg)))
	#Apply crit
	if criting:
		f_value *= 1 + cur_char.crit_mutly / 100
	#Damage the enemy
	cur_enemy.take_dmg(f_value, type)
	
	if not to_give_before:
		cur_char.modify_stat("hand_combo", hand_combo_points_to_give)
