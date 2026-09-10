extends Resource
class_name PieceActivation

var criting: bool = false
var upgrade: int = 0

@export var hand_combo_points_to_give: int

func activate(_context = null):
	pass

func _fmt(val: float) -> String:
	if is_equal_approx(val, roundf(val)):
		return str(int(roundf(val)))
	return str(snappedf(val, 0.1))

func get_effect_description(_char_resource = null, _upgrades: int = 0) -> String:
	return ""
