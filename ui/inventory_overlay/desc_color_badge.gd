@tool
class_name DescColorBadge
extends Control

## Pixel-art color badge using the project's reward color icons.

const ICON_MULTICOLOR: Texture2D = preload("res://assets/sprites/rewards/reward_color_multicolor.png")
const ICON_SINGLECOLOR: Texture2D = preload("res://assets/sprites/rewards/reward_color_singlecolor.png")
const PALETTE_SHADER: Shader = preload("res://assets/shaders/palette_swap_5.gdshader")

const FALLBACK_PALETTES: Dictionary = {
	100: { "highlight": Color("#F9C22B"), "lightbase": Color("#FB6B1D"), "base": Color("#E83B3B"), "shadebase": Color("#AE2334"), "deepshade": Color("#7A3045") },
	200: { "highlight": Color("#FFFFFF"), "lightbase": Color("#8FD3FF"), "base": Color("#4D9BE6"), "shadebase": Color("#4D65B4"), "deepshade": Color("#484A77") },
	300: { "highlight": Color("#FBFF86"), "lightbase": Color("#91DB69"), "base": Color("#1EBC73"), "shadebase": Color("#239063"), "deepshade": Color("#165A4C") },
	400: { "highlight": Color("#FFFFFF"), "lightbase": Color("#EAADED"), "base": Color("#A884F3"), "shadebase": Color("#905EA9"), "deepshade": Color("#6B3E75") },
	500: { "highlight": Color("#FFFFFF"), "lightbase": Color("#FFFFFF"), "base": Color("#c7dcd0"), "shadebase": Color("#9babb2"), "deepshade": Color("#694f62") },
}

@export var color_id: int = 100:
	set(val):
		color_id = val
		_sync_visuals()

var _icon_rect: TextureRect = null

func _init() -> void:
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_ensure_icon_rect()
	_sync_visuals()

func set_color_id(c_id: int) -> void:
	color_id = c_id

func _ensure_icon_rect() -> void:
	if _icon_rect == null or not is_instance_valid(_icon_rect):
		_icon_rect = get_node_or_null("IconRect") as TextureRect
	if _icon_rect == null:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "IconRect"
		_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_rect)

func _sync_visuals() -> void:
	if not is_inside_tree() and _icon_rect == null:
		return
	_ensure_icon_rect()
	if color_id == 0:
		_icon_rect.texture = ICON_MULTICOLOR
		_icon_rect.material = null
	else:
		_icon_rect.texture = ICON_SINGLECOLOR
		_icon_rect.material = _build_palette_material(color_id)

func _build_palette_material(c_id: int) -> ShaderMaterial:
	var base_fam: int = (c_id / 100) * 100 if c_id >= 100 else c_id
	var pal: Dictionary = FALLBACK_PALETTES.get(base_fam, FALLBACK_PALETTES[100])
	if not Engine.is_editor_hint():
		base_fam = ColorLoadoutTrack.get_base_family(c_id)
		pal = ColorLoadoutTrack.get_palette_for_color(base_fam)
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	mat.set_shader_parameter("target_color_1", pal.highlight)
	mat.set_shader_parameter("target_color_2", pal.lightbase)
	mat.set_shader_parameter("target_color_3", pal.base)
	mat.set_shader_parameter("target_color_4", pal.shadebase)
	mat.set_shader_parameter("target_color_5", pal.deepshade)
	return mat
