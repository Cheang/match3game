@tool
extends Node2D

## Visual guide for the Godot 2D Editor showing the physical phone's screen boundaries.
## Automatically frees itself when the game runs, so there is zero runtime overhead.

@export var phone_width: float = 576.0
@export var phone_height: float = 1288.0
@export var camera_center_y: float = 512.0
@export var base_viewport_height: float = 1024.0

@export_group("Visuals")
@export var phone_border_color: Color = Color(0.22, 0.72, 1.0, 0.9)
@export var extra_area_color: Color = Color(0.18, 0.65, 1.0, 0.07)
@export var base_viewport_line_color: Color = Color(1.0, 0.85, 0.3, 0.45)

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	z_index = 1000

func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var half_h: float = phone_height / 2.0
	var top_y: float = camera_center_y - half_h
	var bot_y: float = camera_center_y + half_h

	# Soft tint highlighting the extra screen space available on phone
	if top_y < 0.0:
		draw_rect(Rect2(0.0, top_y, phone_width, -top_y), extra_area_color, true)
	if bot_y > base_viewport_height:
		draw_rect(Rect2(0.0, base_viewport_height, phone_width, bot_y - base_viewport_height), extra_area_color, true)

	# Crisp phone screen border outline
	draw_rect(Rect2(0.0, top_y, phone_width, phone_height), phone_border_color, false, 2.0)

	# Base viewport reference lines (Y = 0 and Y = 1024)
	draw_line(Vector2(0.0, 0.0), Vector2(phone_width, 0.0), base_viewport_line_color, 1.0)
	draw_line(Vector2(0.0, base_viewport_height), Vector2(phone_width, base_viewport_height), base_viewport_line_color, 1.0)

	var font: Font = ThemeDB.fallback_font
	if font != null:
		var lbl_top: String = "─── PHONE TOP (Y ≈ %d) ───" % int(top_y)
		var lbl_bot: String = "─── PHONE BOTTOM (Y ≈ %d) ───" % int(bot_y)
		draw_string(font, Vector2(16.0, top_y + 18.0), lbl_top, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.82, 1.0, 0.85))
		draw_string(font, Vector2(16.0, bot_y - 10.0), lbl_bot, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.82, 1.0, 0.85))
