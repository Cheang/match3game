extends PieceActivation
class_name PieceBaseHeal

@export var health: float

func activate():
	var cur_char = Global.cur_char
	if cur_char == null:
		return
	
	var f_value = health + upgrade
	if criting:
		f_value *= (1 + cur_char.crit_mutly / 100)
	cur_char.modify_stat("cur_health", f_value)

func get_effect_description(_char_resource = null, upgrades: int = 0) -> String:
	var total_heal: float = health + upgrades
	return "Heals: [color=#a854a8]%g[/color] HP" % [total_heal]
