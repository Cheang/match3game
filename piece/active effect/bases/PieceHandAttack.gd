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


func activate(context = null):
	var cur_char = context.get("attacker", Global.cur_char) if (context != null and context is Dictionary) else Global.cur_char
	var cur_enemy = context.get("target", Global.cur_enemy) if (context != null and context is Dictionary) else Global.cur_enemy
	if cur_char == null or cur_enemy == null:
		return
	
	if to_give_before:
		cur_char.modify_stat("hand_combo", hand_combo_points_to_give)
	
	#Calculate base damage
	var f_value: float = atk_dmg + (cur_char.strength * float(use_strength)) + (upgrade * float(use_upgrades_on_dmg))
	#Apply combo multiplier
	f_value += cur_char.hand_combo * (hand_combo_multy + (upgrade * float(use_upgrades_on_multy or use_upgrades_on_dmg)))
	#Apply crit
	if criting:
		f_value *= 1 + cur_char.crit_mutly / 100
	#Damage the enemy
	cur_enemy.take_dmg(f_value, type)
	
	if not to_give_before:
		cur_char.modify_stat("hand_combo", hand_combo_points_to_give)

func get_effect_description(char_resource = null, upgrades: int = 0) -> String:
	var str_val: float = 0.0
	if char_resource != null and "strength" in char_resource:
		str_val = char_resource.strength
	elif Global.cur_char != null and "strength" in Global.cur_char:
		str_val = Global.cur_char.strength
	
	var base_d: float = atk_dmg + (str_val * float(use_strength)) + (upgrades * float(use_upgrades_on_dmg))
	var mult: float = hand_combo_multy + (upgrades * float(use_upgrades_on_multy or use_upgrades_on_dmg))
	var color_str: String = "#3ca370" if type == 1 else "#ae2334"
	var type_label: String = " Magic" if type == 1 else ""
	if mult > 1:
		return "Deals: [color=%s]%s[/color]%s DMG + ([color=#7a3045]Combo Points[/color] * [color=%s]%s[/color])" % [color_str, _fmt(base_d), type_label, color_str, _fmt(mult)]
	return "Deals: [color=%s]%s[/color]%s DMG + [color=#7a3045]Combo Points[/color]" % [color_str, _fmt(base_d), type_label]
