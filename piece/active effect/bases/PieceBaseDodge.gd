extends PieceActivation
class_name PieceBaseDodge

func activate(context = null):
	var cur_char = context.get("attacker", Global.cur_char) if (context != null and context is Dictionary) else Global.cur_char
	if cur_char != null:
		cur_char.modify_stat("dodging", true)

func get_effect_description(_char_resource = null, _upgrades: int = 0) -> String:
	return "Grants: [color=#5ac54f]Dodge[/color]"
