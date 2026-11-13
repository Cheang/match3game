@tool
class_name DescSlotBadge
extends Control

## Pixel-art circular Roman numeral slot-cost badge (I, II, III, U, P).

@export var badge_text: String = "I":
	set(val):
		badge_text = val
		_sync_label()

var _label: Label

func _init() -> void:
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_label()

func _ready() -> void:
	_ensure_label()
	_sync_label()

func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", preload("res://assets/theme/title.ttf"))
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.text = badge_text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _sync_label() -> void:
	if _label != null:
		_label.text = badge_text
		if badge_text == "U":
			_label.add_theme_color_override("font_color", Color("#ffd966"))
		else:
			_label.add_theme_color_override("font_color", Color.WHITE)
	queue_redraw()

func set_badge_text(t: String) -> void:
	badge_text = t

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 10.5, Color("#19131c"))
	draw_circle(center, 9.5, Color("#d6d0e0"))
	draw_circle(center, 7.5, Color("#3b2f3d"))
