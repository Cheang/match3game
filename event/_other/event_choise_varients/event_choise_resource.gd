extends Resource
class_name EventChoise

@export_category("General")
@export var text: String
@export var description: String = "None"

@export_category("Gold")
@export var gold_cost: int

@export_category("Requirements")
@export var fail_state: EventChoise
@export var failable: bool = false
@export var req_stat: String = "None"
@export var req_value: float = 0
@export var req_piece_remove: bool = false
@export var req_piece_remove_blacklist: String
@export var req_piece_name: String = "None"
@export var req_piece_numb: int = 1
@export var req_class: String = "None"

func activate():
	pass
