extends Node2D
class_name PieceClass


@export_category("Main")
@export var id: int
@export var piece_name: String
@export var description: String
@export var color: String
@export var family: String
@export_enum("fluf","normal","one_per_battle","glass") var type: int
@export var action: Array[PieceActivation]
@export_category("Art")
@export var base_texture: Texture
@export var icon_texture: Texture
@export var row_teture: Texture2D
@export var col_teture: Texture2D
@export var adj_teture: Texture2D
@export_category("Other")
@export var cooldown: int
var original_cd: int
@export var can_upgrade: bool = true
@export var upgrades_to_increse_cd: int = 3
@export_group("Other")
@export var crit_shader: Resource
@export var upgrades: int = 0
@export_group("Autofill")
#Location of the origina Scene and is autofillied on creation
@export var location: String

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
	if icon_texture != null:
		icon.texture = icon_texture
	cooldown = original_cd
	matched = false
	is_criting = false
	is_gold = false
	will_gold()
	will_crit()
	if is_row_bomb or is_col_bomb or is_adj_bomb:
		is_row_bomb = false
		is_col_bomb = false
		is_adj_bomb = false

func will_crit():
	var rand = floor(randf_range(1,100))
	if rand <= Global.cur_char.crit_chance:
		base.material = crit_shader
		is_criting = true
	else:
		base.material = null

func will_gold():
	var rand = floor(randf_range(1,100))
	if rand <= Global.cur_char.gold_chance:
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

func get_dynamic_description(char_resource = null) -> String:
	if not action.is_empty():
		var desc_parts: Array[String] = []
		for act in action:
			if act != null:
				var d: String = act.get_effect_description(char_resource, upgrades)
				if d != "":
					desc_parts.append(d)
		if not desc_parts.is_empty():
			return "\n".join(desc_parts)
	return description
