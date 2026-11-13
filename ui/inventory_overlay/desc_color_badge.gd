@tool
class_name DescColorBadge
extends Control

## Pixel-art color badge (6-color wheel for Wild, or track-colored orb).

@export var color_id: int = 100:
	set(val):
		color_id = val
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_color_id(c_id: int) -> void:
	color_id = c_id
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var r := 9.0
	draw_circle(center, r + 1.5, Color("#19131c"))
	if color_id <= 0:
		var wheel_colors: Array[Color] = [
			Color("#e04444"),
			Color("#f09838"),
			Color("#4bc468"),
			Color("#84e0f0"),
			Color("#4d78e0"),
			Color("#a65ae0")
		]
		for i in range(6):
			var a0 := -PI * 0.5 + float(i) * (TAU / 6.0)
			var a1 := a0 + (TAU / 6.0)
			var pts := PackedVector2Array([center])
			for s in range(5):
				var a := lerpf(a0, a1, float(s) / 4.0)
				pts.append(center + Vector2(cos(a), sin(a)) * r)
			draw_polygon(pts, PackedColorArray([wheel_colors[i]]))
	else:
		var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(color_id)
		draw_circle(center, r, pal.base)
		draw_circle(center + Vector2(-2, -2), r * 0.45, pal.highlight)
