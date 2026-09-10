extends PieceActivation
class_name PieceBaseHeal

@export var health: float

func activate(context = null):
	var cur_char = context.get("attacker", Global.cur_char) if (context != null and context is Dictionary) else Global.cur_char
	if cur_char == null:
		return
	
	var f_value = health + upgrade
	if criting:
		f_value *= (1 + cur_char.crit_mutly / 100)
	cur_char.modify_stat("cur_health", f_value)

func get_effect_description(_char_resource = null, upgrades: int = 0) -> String:
	var total_heal: float = health + upgrades
	return "Heals: [color=#a854a8]%s[/color] HP" % [_fmt(total_heal)]
