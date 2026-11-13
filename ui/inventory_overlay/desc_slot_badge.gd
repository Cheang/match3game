@tool
class_name DescSlotBadge
extends Control

## Pixel-art slot-cost / type badge using the project's reward slot icons.

const TEX_BACKPLATE: Texture2D = preload("res://assets/sprites/rewards/reward_slots_backplate.png")
const SLOT_ICONS: Dictionary = {
	"I": preload("res://assets/sprites/rewards/reward_slots_1.png"),
	"II": preload("res://assets/sprites/rewards/reward_slots_2.png"),
	"III": preload("res://assets/sprites/rewards/reward_slots_3.png"),
	"IV": preload("res://assets/sprites/rewards/reward_slots_4.png"),
	"U": preload("res://assets/sprites/rewards/reward_slots_buff.png"),
	"P": preload("res://assets/sprites/rewards/reward_slots_passive.png"),
}

@export var badge_text: String = "I":
	set(val):
		badge_text = val
		_sync_visuals()

var _backplate_rect: TextureRect = null
var _icon_rect: TextureRect = null

func _init() -> void:
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_ensure_rects()
	_sync_visuals()

func set_badge_text(t: String) -> void:
	badge_text = t

func _ensure_rects() -> void:
	if _backplate_rect == null or not is_instance_valid(_backplate_rect):
		_backplate_rect = get_node_or_null("BackplateRect") as TextureRect
	if _backplate_rect == null:
		_backplate_rect = TextureRect.new()
		_backplate_rect.name = "BackplateRect"
		_backplate_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backplate_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_backplate_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_backplate_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_backplate_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backplate_rect.texture = TEX_BACKPLATE
		add_child(_backplate_rect)
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
	_ensure_rects()
	_backplate_rect.texture = TEX_BACKPLATE
	_icon_rect.texture = SLOT_ICONS.get(badge_text, SLOT_ICONS["I"])
