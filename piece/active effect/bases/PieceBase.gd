extends Resource
class_name PieceActivation

var criting: bool = false
var upgrade: int = 0

@export var hand_combo_points_to_give: int

func activate():
	pass

func get_effect_description(_char_resource = null, _upgrades: int = 0) -> String:
	return ""
