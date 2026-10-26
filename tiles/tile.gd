extends Node2D
class_name PieceClass

@export_category("Main")
@export var id: int = 100
@export var piece_name: String = ""
@export var description: String = ""
@export var color: String = "red"
@export var family: String = ""
@export_enum("fluf", "normal", "one_per_battle", "glass") var type: int = 0
@export var action: Array[Equipment] = []
@export_category("Art")
@export var base_texture: Texture
@export var icon_texture: Texture
@export var row_texture: Texture2D
@export var col_texture: Texture2D
@export var adj_texture: Texture2D

var row_teture: Texture2D:
	get: return row_texture
	set(v): row_texture = v
var col_teture: Texture2D:
	get: return col_texture
	set(v): col_texture = v
var adj_teture: Texture2D:
	get: return adj_texture
	set(v): adj_texture = v
@export_category("Other")
@export var cooldown: int = 0
var original_cd: int = 0
@export var can_upgrade: bool = true
@export var upgrades_to_increse_cd: int = 3
@export_group("Other")
@export var crit_shader: Resource
@export var upgrades: int = 0
@export_group("Autofill")
@export var location: String = ""

@onready var icon: Sprite2D = $icon
@onready var base: Sprite2D = $base
@onready var gold_border: Sprite2D = $gold_border

var color_id: int = 100
var fall_distance: int = 0

var matched: bool = false
var is_criting: bool = false
var is_gold: bool = false
var is_preview_highlighted: bool = false

var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_adj_bomb: bool = false

const COLOR_SCENE_ASSETS := {
	100: {
		"name": "red",
		"base": preload("res://assets/red_0_sq.png"),
		"row": preload("res://assets/_red_icons/red_icon_6_1.png"),
		"col": preload("res://assets/_red_icons/red_icon_6_2.png"),
		"adj": preload("res://assets/_red_icons/red_icon_6_3.png"),
	},
	200: {
		"name": "blue",
		"base": preload("res://assets/blue_0_sq.png"),
		"row": preload("res://assets/_blue_icons/blue_icon_7_1.png"),
		"col": preload("res://assets/_blue_icons/blue_icon_7_2.png"),
		"adj": preload("res://assets/_blue_icons/blue_icon_7_3.png"),
	},
	300: {
		"name": "green",
		"base": preload("res://assets/green_0_sq.png"),
		"row": preload("res://assets/_green_icons/green_icon_6_1.png"),
		"col": preload("res://assets/_green_icons/green_icon_6_2.png"),
		"adj": preload("res://assets/_green_icons/green_icon_6_3.png"),
	},
	400: {
		"name": "purple",
		"base": preload("res://assets/purple_0_sq.png"),
		"row": preload("res://assets/_purple_icons/purprle_icon_4_1.png"),
		"col": preload("res://assets/_purple_icons/purprle_icon_4_2.png"),
		"adj": preload("res://assets/_purple_icons/purprle_icon_4_3.png"),
	},
	500: {
		"name": "white",
		"base": preload("res://assets/white_0_sq.png"),
		"row": preload("res://assets/_white_icons/white_icon_2_1.png"),
		"col": preload("res://assets/_white_icons/white_icon_2_2.png"),
		"adj": preload("res://assets/_white_icons/white_icon_2_3.png"),
	}
}

func _ready() -> void:
	original_cd = cooldown
	if color_id == 100 and id >= 100:
		color_id = id
	elif color != "":
		color_id = Global.color_string_to_id(color)
	apply_color_visuals(color_id)
	will_gold()
	will_crit()

func setup_chromatic(new_color_id: int) -> void:
	color_id = new_color_id
	id = new_color_id
	type = 0
	fall_distance = 0
	apply_color_visuals(color_id)
	if is_inside_tree():
		will_gold()
		will_crit()

func apply_color_visuals(c_id: int) -> void:
	var base_fam: int = Global.get_base_family(c_id)
	var cfg: Dictionary = COLOR_SCENE_ASSETS.get(base_fam, COLOR_SCENE_ASSETS[100])
	color = cfg["name"]
	base_texture = cfg["base"]
	row_texture = cfg["row"]
	col_texture = cfg["col"]
	adj_texture = cfg["adj"]

	if base != null and base_texture != null:
		base.texture = base_texture
	if icon != null and not is_row_bomb and not is_col_bomb and not is_adj_bomb:
		icon.texture = icon_texture

	_apply_exotic_tint()

func _apply_exotic_tint() -> void:
	if base == null:
		return
	if matched:
		base.modulate = Color(1, 1, 1, 0.5)
		return
	if is_preview_highlighted:
		base.modulate = Color(1.35, 1.35, 1.35, 1.0)
		scale = Vector2(1.08, 1.08)
		return
	scale = Vector2.ONE
	if Global.is_exotic_color(color_id):
		match color_id:
			Global.TileColor.DARK_CRIMSON:
				base.modulate = Color(0.65, 0.18, 0.28, 1.0)
			Global.TileColor.COBALT_FROST:
				base.modulate = Color(0.55, 0.92, 1.25, 1.0)
			Global.TileColor.VENOM_GREEN:
				base.modulate = Color(0.75, 1.25, 0.35, 1.0)
			Global.TileColor.ELDRITCH_VOID:
				base.modulate = Color(0.52, 0.25, 0.78, 1.0)
			Global.TileColor.SOLAR_GOLD:
				base.modulate = Color(1.25, 1.05, 0.45, 1.0)
			_:
				base.modulate = Color(0.8, 0.8, 1.2, 1.0)
	else:
		base.modulate = Color(1, 1, 1, 1)

func set_preview_highlight(active: bool) -> void:
	is_preview_highlighted = active
	_apply_exotic_tint()

func move(target, time = 0.3):
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func mark(_activate: bool = true):
	matched = true
	is_preview_highlighted = false
	scale = Vector2.ONE
	if base != null:
		base.modulate = Color(1, 1, 1, 0.5)

func unmark():
	matched = false
	is_preview_highlighted = false
	scale = Vector2.ONE
	if icon != null:
		icon.texture = icon_texture
	cooldown = original_cd
	is_criting = false
	is_gold = false
	will_gold()
	will_crit()
	if is_row_bomb or is_col_bomb or is_adj_bomb:
		is_row_bomb = false
		is_col_bomb = false
		is_adj_bomb = false
	_apply_exotic_tint()

func will_crit():
	if Global.cur_char == null or base == null:
		return
	var rand = floor(randf_range(1, 100))
	var effective_crit: int = Global.cur_char.crit_chance + max(0, (Global.cur_char.speed - 2) * 2)
	if rand <= effective_crit:
		base.material = crit_shader
		is_criting = true
	else:
		base.material = null

func will_gold():
	if Global.cur_char == null or gold_border == null:
		return
	var rand = floor(randf_range(1, 100))
	if rand <= Global.cur_char.gold_chance:
		gold_border.visible = true
		is_gold = true
	else:
		gold_border.visible = false

func lower_cooldown():
	cooldown -= 1

func set_node_values():
	var node_values = {
		"scene_path": location,
		"cooldown": cooldown,
		"upgrades": upgrades,
		"color_id": color_id
	}
	return node_values

func make_col_bomb():
	is_col_bomb = true
	if icon != null:
		icon.texture = col_texture
	_apply_exotic_tint()

func make_row_bomb():
	is_row_bomb = true
	if icon != null:
		icon.texture = row_texture
	_apply_exotic_tint()

func make_adj_bomb():
	is_adj_bomb = true
	if icon != null:
		icon.texture = adj_texture
	_apply_exotic_tint()

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
