extends Node2D
class_name PieceClass

@export var color: String
@export var base_texture: Texture
@export var icon_texture: Texture
@export_enum("fluf","normal","one_per_battle","glass") var type: int
@export var crit_shader: Resource
@export var scene_location: String
@export var cooldown: int

@export var action: Array[PieceActivation]

@onready var icon: Sprite2D = $icon
@onready var base: Sprite2D = $base

var matched: bool = false
var is_criting: bool = false

func _ready() -> void:
	if icon_texture != null:
		icon.texture = icon_texture
	if base_texture != null:
		base.texture = base_texture
	will_crit()

func move(target, time = .3):
	var tween: Tween = create_tween()
	tween.tween_property(self,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func mark(activate: bool = true):
	base.modulate = Color(1, 1, 1, .5)
	matched = true
	if activate:
		activate_actions(action)


func will_crit():
	randomize()
	var rand = floor(randf_range(1,100))
	if rand <= Global.cur_char.crit_chanse:
		base.material = crit_shader
		is_criting = true

func activate_actions(to_activate: Array):
	if !to_activate.is_empty():
		for i in to_activate.size():
			if !Global.is_null(to_activate[i]):
				to_activate[i].criting = is_criting
				to_activate[i].activate()

func lower_cooldown():
	cooldown -= 1
