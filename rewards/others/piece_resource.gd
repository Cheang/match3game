extends Reward
class_name R_Piece

@export var piece_to_add: Array[PackedScene]
@export var passives_to_boost: Array[Reward]

func activate():
	if !piece_to_add.is_empty():
		Global.cur_char.add_piece(Global.cur_char.deck, piece_to_add)
	if !passives_to_boost.is_empty():
		Global.cur_char.add_piece(Global.cur_char.rewards_passive, passives_to_boost)
	
