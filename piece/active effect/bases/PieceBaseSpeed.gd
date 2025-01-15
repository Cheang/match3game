extends PieceActivation
class_name PieceBaseSpeed

@export var moves_to_give: int



func activate():
	var cur_char = Global.cur_char
	
	if criting:
		cur_char.add_stat("moves_left", moves_to_give * 2)
	else:
		cur_char.add_stat("moves_left", moves_to_give)
