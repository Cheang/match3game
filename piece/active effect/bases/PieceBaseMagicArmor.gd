extends PieceActivation
class_name PieceBaseMagicArmor

@export var faith_mult: bool = true
@export var hand_combo_mult: bool = false
@export var mage_armor: int

func activate():
	var cur_char = Global.cur_char
	if cur_char == null:
		return
	
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

func get_effect_description(char_resource = null, upgrades: int = 0) -> String:
	var f: float = 0.0
	if char_resource != null and "faith" in char_resource:
		f = char_resource.faith
	elif Global.cur_char != null and "faith" in Global.cur_char:
		f = Global.cur_char.faith
	
	var total_mage_armor: float = mage_armor + upgrades + (f * float(faith_mult))
	if hand_combo_mult:
		return "Gives: [color=#0b8a8f]%g[/color] Magic Armor * [color=#7a3045]Combo Points[/color]" % [total_mage_armor]
	return "Gives: [color=#0b8a8f]%g[/color] Magic Armor" % [total_mage_armor]
