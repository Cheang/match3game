extends PieceActivation
class_name PieceBaseArmor

@export var toughness_mult: bool = true
@export var hand_combo_mult: bool = false

@export var armor: float

func activate(context = null):
	var cur_char = context.get("attacker", Global.cur_char) if (context != null and context is Dictionary) else Global.cur_char
	if cur_char == null:
		return
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
	cur_char.modify_stat("cur_armor", f_value)

func get_effect_description(char_resource = null, upgrades: int = 0) -> String:
	var t: float = 0.0
	if char_resource != null and "toughness" in char_resource:
		t = char_resource.toughness
	elif Global.cur_char != null and "toughness" in Global.cur_char:
		t = Global.cur_char.toughness
	
	var total_armor: float = armor + upgrades + (t * float(toughness_mult))
	if hand_combo_mult:
		return "Gives: [color=#4d65b4]%s[/color] Armor * [color=#7a3045]Combo Points[/color]" % [_fmt(total_armor)]
	return "Gives: [color=#4d65b4]%s[/color] Armor" % [_fmt(total_armor)]
