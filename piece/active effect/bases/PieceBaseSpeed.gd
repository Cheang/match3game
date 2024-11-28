extends PieceActivation
class_name PieceBaseSpeed

@export var moves_to_give: int

func activate():
	if criting:
		Global.moves_done += moves_to_give * 2
	else:
		Global.moves_done += moves_to_give
