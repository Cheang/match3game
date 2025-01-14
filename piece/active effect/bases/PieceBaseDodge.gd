extends PieceActivation
class_name PieceBaseDodge

func activate():
	Global.cur_char.add_stat("dodging", true)
