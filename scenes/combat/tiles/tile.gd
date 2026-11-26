class_name PieceClass
extends Node2D

const PALETTE_SHADER: Shader = preload("res://assets/shaders/palette_swap_5.gdshader")
const COLOR_SCENE_ASSETS: Dictionary = {
	100: {
		"name": "red",
		"row": preload("res://assets/sprites/icons/red/red_icon_6_1.png"),
		"col": preload("res://assets/sprites/icons/red/red_icon_6_2.png"),
		"adj": preload("res://assets/sprites/icons/red/red_icon_6_3.png"),
	},
	200: {
		"name": "blue",
		"row": preload("res://assets/sprites/icons/blue/blue_icon_7_1.png"),
		"col": preload("res://assets/sprites/icons/blue/blue_icon_7_2.png"),
		"adj": preload("res://assets/sprites/icons/blue/blue_icon_7_3.png"),
	},
	300: {
		"name": "green",
		"row": preload("res://assets/sprites/icons/green/green_icon_6_1.png"),
		"col": preload("res://assets/sprites/icons/green/green_icon_6_2.png"),
		"adj": preload("res://assets/sprites/icons/green/green_icon_6_3.png"),
	},
	400: {
		"name": "purple",
		"row": preload("res://assets/sprites/icons/purple/purprle_icon_4_1.png"),
		"col": preload("res://assets/sprites/icons/purple/purprle_icon_4_2.png"),
		"adj": preload("res://assets/sprites/icons/purple/purprle_icon_4_3.png"),
	},
	500: {
		"name": "white",
		"row": preload("res://assets/sprites/icons/white/white_icon_2_1.png"),
		"col": preload("res://assets/sprites/icons/white/white_icon_2_2.png"),
		"adj": preload("res://assets/sprites/icons/white/white_icon_2_3.png"),
	},
}

@export_category("Identity")
@export var color_id: int = 100
@export var color: String = "red"

@export_category("Bomb Art")
@export var row_texture: Texture2D
@export var col_texture: Texture2D
@export var adj_texture: Texture2D

static var _shared_palette_materials: Dictionary = {}

var id: int:
	get: return color_id
	set(val): color_id = val

var fall_distance: int = 0
var matched: bool = false
var is_gold: bool = false
var is_preview_highlighted: bool = false
var is_enemy_target_highlighted: bool = false

var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_adj_bomb: bool = false

@onready var icon: Sprite2D = $icon
@onready var base: Sprite2D = $base
@onready var gold_border: Sprite2D = $gold_border

func _ready() -> void:
	if color != "" and color_id == 100 and color != "red":
		color_id = Global.color_string_to_id(color)
	apply_color_visuals(color_id)
	will_gold()

static func _get_shared_palette_material(c_id: int) -> ShaderMaterial:
	var base_fam: int = ColorLoadoutTrack.get_base_family(c_id)
	if _shared_palette_materials.has(base_fam):
		return _shared_palette_materials[base_fam]
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(base_fam)
	mat.set_shader_parameter("target_color_1", pal.highlight)
	mat.set_shader_parameter("target_color_2", pal.lightbase)
	mat.set_shader_parameter("target_color_3", pal.base)
	mat.set_shader_parameter("target_color_4", pal.shadebase)
	mat.set_shader_parameter("target_color_5", pal.deepshade)
	_shared_palette_materials[base_fam] = mat
	return mat

func setup_chromatic(new_color_id: int) -> void:
	color_id = new_color_id
	fall_distance = 0
	apply_color_visuals(color_id)
	if is_inside_tree():
		will_gold()

func apply_color_visuals(c_id: int) -> void:
	var base_fam: int = ColorLoadoutTrack.get_base_family(c_id)
	var cfg: Dictionary = COLOR_SCENE_ASSETS.get(base_fam, COLOR_SCENE_ASSETS[100])
	color = cfg["name"]
	row_texture = cfg["row"]
	col_texture = cfg["col"]
	adj_texture = cfg["adj"]

	var base_node: Sprite2D = base if base != null else get_node_or_null("base")
	if base_node != null:
		base_node.material = _get_shared_palette_material(c_id)
	if icon != null and not is_row_bomb and not is_col_bomb and not is_adj_bomb:
		icon.texture = null

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
	if is_enemy_target_highlighted:
		scale = Vector2.ONE
		base.modulate = Color(1.25, 0.75, 0.75, 1.0)
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

## Target state for upcoming monster attacks. Visual outlines are managed by EnemyAttackOverlay on grd.
func set_enemy_target_highlight(active: bool) -> void:
	is_enemy_target_highlighted = active
	_apply_exotic_tint()

func move(target: Vector2, time: float = 0.3) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func mark(_activate: bool = true) -> void:
	matched = true
	is_preview_highlighted = false
	set_enemy_target_highlight(false)
	scale = Vector2.ONE
	if base != null:
		base.modulate = Color(1, 1, 1, 0.5)


func unmark() -> void:
	matched = false
	is_preview_highlighted = false
	set_enemy_target_highlight(false)
	scale = Vector2.ONE
	if icon != null:
		icon.texture = null
	is_gold = false
	will_gold()
	if is_row_bomb or is_col_bomb or is_adj_bomb:
		is_row_bomb = false
		is_col_bomb = false
		is_adj_bomb = false
	_apply_exotic_tint()


func will_gold() -> void:
	if Global.cur_char == null or gold_border == null:
		return
	var chance: int = int(roundf(Global.cur_char.get_gold_find_chance())) if Global.cur_char.has_method("get_gold_find_chance") else int(Global.cur_char.gold_chance)
	if chance <= 0:
		gold_border.visible = false
		is_gold = false
		return
	if randi_range(1, 100) <= chance:
		gold_border.visible = true
		is_gold = true
	else:
		gold_border.visible = false
		is_gold = false


func make_col_bomb() -> void:
	is_col_bomb = true
	if icon != null:
		icon.texture = col_texture
	_apply_exotic_tint()


func make_row_bomb() -> void:
	is_row_bomb = true
	if icon != null:
		icon.texture = row_texture
	_apply_exotic_tint()


func make_adj_bomb() -> void:
	is_adj_bomb = true
	if icon != null:
		icon.texture = adj_texture
	_apply_exotic_tint()

