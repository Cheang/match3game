extends PieceActivation
class_name PieceBaseDodge

func activate():
	Global.cur_char.modify_stat("dodging", true)
