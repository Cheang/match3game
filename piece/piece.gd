extends Node2D
class_name PieceClass

#Location of the origina Scene
@export var location: String

@export var piece_name: String
@export var description: String
@export var color: String
@export var family: String
@export var base_texture: Texture
@export var icon_texture: Texture
@export var row_teture: Texture2D
@export var col_teture: Texture2D
@export var adj_teture: Texture2D
@export_enum("fluf","normal","one_per_battle","glass") var type: int
@export var crit_shader: Resource
@export var cooldown: int
var original_cd: int

@export var upgrades: int = 0
@export var upgrades_to_increse_cd: int = 3
@export var can_upgrade: bool = true

@export var action: Array[PieceActivation]

@onready var icon: Sprite2D = $icon
@onready var base: Sprite2D = $base
@onready var gold_border: Sprite2D = $gold_border

var matched: bool = false
var is_criting: bool = false
var is_gold: bool = false

var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_adj_bomb: bool = false

func _ready() -> void:
	original_cd = cooldown
	if icon_texture != null:
		icon.texture = icon_texture
	if base_texture != null:
		base.texture = base_texture
	will_gold()
	will_crit()

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(self,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func mark(activate: bool = true):
	base.modulate = Color(1, 1, 1, .5)
	if activate:
		activate_actions(action)
	matched = true

func unmark():
	base.modulate = Color(1, 1, 1, 1)
	cooldown = original_cd
	matched = false
	is_criting = false
	is_gold = false
	will_gold()
	will_crit()

func will_crit():
	randomize()
	var rand = floor(randf_range(1,100))
	if rand <= Global.cur_char.crit_chanse:
		base.material = crit_shader
		is_criting = true
	else:
		base.material = null

func will_gold():
	randomize()
	var rand = floor(randf_range(1,100))
	if rand <= Global.cur_char.gold_chanse:
		gold_border.visible = true
		is_gold = true
	else:
		gold_border.visible = false

func activate_actions(to_activate: Array):
	if not matched:
		if is_gold:
			Global.cur_char.gold += 1
		if !to_activate.is_empty() and !is_row_bomb and !is_col_bomb and !is_adj_bomb:
			for i in to_activate.size():
				if !Global.is_null(to_activate[i]):
					to_activate[i].criting = is_criting
					to_activate[i].upgrade = upgrades
					to_activate[i].activate()

func lower_cooldown():
	cooldown -= 1

func set_node_values(): 
	var node_values = { 
	"scene_path": location,
	 "cooldown": cooldown,
	 "upgrades": upgrades 
	} 
	return node_values

func make_col_bomb():
	is_col_bomb = true
	icon.texture = col_teture
	base.modulate = Color(1, 1, 1, 1)

func make_row_bomb():
	is_row_bomb = true
	icon.texture = row_teture
	base.modulate = Color(1, 1, 1, 1)

func make_adj_bomb():
	is_adj_bomb = true
	icon.texture = adj_teture
	base.modulate = Color(1, 1, 1, 1)
