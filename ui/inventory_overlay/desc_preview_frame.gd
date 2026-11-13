@tool
class_name DescPreviewFrame
extends Control

## Pixel-art dark framed square preview box on the left of the DescriptionPanel.

const BOX_SIZE = Vector2(168, 168)
const TEX_FRAME: Texture2D = preload("res://assets/sprites/ui/legacy/reward_panel_2.png")

var _frame_rect: TextureRect = null

func _init() -> void:
	custom_minimum_size = BOX_SIZE
	size = BOX_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_frame_rect()

func _ensure_frame_rect() -> void:
	if _frame_rect == null or not is_instance_valid(_frame_rect):
		_frame_rect = get_node_or_null("FrameTexture") as TextureRect
	if _frame_rect == null:
		_frame_rect = TextureRect.new()
		_frame_rect.name = "FrameTexture"
		_frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame_rect)
		move_child(_frame_rect, 0)
	_frame_rect.texture = TEX_FRAME
