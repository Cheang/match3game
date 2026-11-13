@tool
class_name DescPreviewFrame
extends Control

## Pixel-art dark framed square preview box on the left of the DescriptionPanel.

const BOX_SIZE = Vector2(168, 168)

func _init() -> void:
	custom_minimum_size = BOX_SIZE
	size = BOX_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color("#2b222e"))
	draw_rect(Rect2(0, 0, w, h), Color("#19131c"), false, 2.0)
	draw_rect(Rect2(3, 3, w - 6, h - 6), Color("#4c3d52"), false, 1.0)
	var dot_col := Color("#66546e")
	draw_rect(Rect2(5, 5, 3, 3), dot_col)
	draw_rect(Rect2(w - 8, 5, 3, 3), dot_col)
	draw_rect(Rect2(5, h - 8, 3, 3), dot_col)
	draw_rect(Rect2(w - 8, h - 8, 3, 3), dot_col)
	var mx := floorf(w * 0.5)
	var my := floorf(h * 0.5)
	draw_polygon(PackedVector2Array([Vector2(mx - 4, 4), Vector2(mx + 4, 4), Vector2(mx, 8)]), PackedColorArray([dot_col]))
	draw_polygon(PackedVector2Array([Vector2(mx - 4, h - 4), Vector2(mx + 4, h - 4), Vector2(mx, h - 8)]), PackedColorArray([dot_col]))
	draw_polygon(PackedVector2Array([Vector2(4, my - 4), Vector2(4, my + 4), Vector2(8, my)]), PackedColorArray([dot_col]))
	draw_polygon(PackedVector2Array([Vector2(w - 4, my - 4), Vector2(w - 4, my + 4), Vector2(w - 8, my)]), PackedColorArray([dot_col]))
