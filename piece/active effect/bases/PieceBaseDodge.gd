extends PieceActivation
class_name PieceBaseDodge

func activate():
	if Global.cur_char != null:
		Global.cur_char.modify_stat("dodging", true)

func get_effect_description(_char_resource = null, _upgrades: int = 0) -> String:
	return "Grants: [color=#5ac54f]Dodge[/color]"
