extends Resource
class_name EventChoise

@export_category("General")
@export var text: String
@export var description: String = "None"

@export_category("Type")
@export_enum(
	"go_to_locations",
	"continue_event",
	"fight",
	"get_after_fight_reward",
	"get_piece",
	"get_passive",
	"get_stat"
	) var type: int

@export_category("Continue Event")
@export var next_event_res: Event

@export_category("Fight")
@export var enemy: Array[EnemyResource]
@export var fight_overwrite: bool

@export_category("Get Piece")
@export var piece_res: R_Piece

@export_category("Get Stat")
@export var stat_res: R_Stat

@export_category("Gold")
@export var gold_cost: int

@export_category("Requirements")
@export var fail_state: EventChoise
@export var failable: bool = false
@export var req_stat: String = "None"
@export var req_value: float = 0
@export var req_piece_remove: bool = false
@export var req_piece: String = "None"
@export var req_class: String = "None"
