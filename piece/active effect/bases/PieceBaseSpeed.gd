extends PieceActivation
class_name PieceBaseSpeed

@export var moves_to_give: int

func activate():
	if criting:
		Global.cur_char.moves_left += moves_to_give * 2
	else:
		Global.cur_char.moves_left += moves_to_give
