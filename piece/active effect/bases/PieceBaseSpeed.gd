extends PieceActivation
class_name PieceBaseSpeed

@export var moves_to_give: int



func activate():
	var cur_char = Global.cur_char
	if cur_char == null:
		return
	
	var moves: int = moves_to_give + upgrade
	if criting:
		cur_char.modify_stat("moves_left", moves * 2)
	else:
		cur_char.modify_stat("moves_left", moves)

func get_effect_description(_char_resource = null, upgrades: int = 0) -> String:
	var moves: int = moves_to_give + upgrades
	return "Gives: [color=#639bff]+%d[/color] Move(s)" % [moves]
