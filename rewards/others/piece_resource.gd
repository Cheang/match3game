extends Reward
class_name R_Piece

@export_category("Piece")
@export var piece_to_add: Array[PackedScene]

func activate():
	if !piece_to_add.is_empty():
		Global.cur_char.unpack_deck(piece_to_add, Global.cur_char.deck_in_game)
	
