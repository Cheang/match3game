extends Reward
class_name R_Piece

@export_category("Piece")
@export var piece_to_add: Array[PackedScene]
@export var use_previous_event_data: bool = false

func activate():
	if !piece_to_add.is_empty():
		if use_previous_event_data:
			var taget = Global.event_pieces_removed
			var i = 0
			while i < taget:
				Global.cur_char.unpack_deck(piece_to_add, Global.cur_char.deck_in_game)
				i += 1
		else:
			Global.cur_char.unpack_deck(piece_to_add, Global.cur_char.deck_in_game)
