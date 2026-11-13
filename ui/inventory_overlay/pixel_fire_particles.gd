class_name PixelFireParticles
extends Node2D

## Pixel-grid-aligned fire particle system for equipment shards.
## Renders crisp integer-snapped pixel blobs (4x4 -> 2x2 -> 1x1) using the exact
## 5-color shard palette from ColorLoadoutTrack.

var emitting: bool = false
var local_coords: bool = true
var emission_rect_extents: Vector2 = Vector2(18.0, 8.0)
var spawn_rate: float = 135.0
var max_particles: int = 160
var palette_colors: Array[Color] = [
	Color.WHITE,
	Color.LIGHT_GRAY,
	Color.GRAY,
	Color.DARK_GRAY,
	Color.DIM_GRAY
]

var _particles: Array[Dictionary] = []
var _spawn_accum: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_palette_for_color(c_id: int) -> void:
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(c_id)
	palette_colors = [
		Color(pal.highlight.r, pal.highlight.g, pal.highlight.b, 1.0),
		Color(pal.lightbase.r, pal.lightbase.g, pal.lightbase.b, 1.0),
		Color(pal.base.r, pal.base.g, pal.base.b, 1.0),
		Color(pal.shadebase.r, pal.shadebase.g, pal.shadebase.b, 1.0),
		Color(pal.deepshade.r, pal.deepshade.g, pal.deepshade.b, 1.0)
	]

func restart() -> void:
	_particles.clear()
	_spawn_accum = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if emitting:
		_spawn_accum += spawn_rate * delta
		while _spawn_accum >= 1.0:
			_spawn_accum -= 1.0
			if _particles.size() < max_particles:
				_spawn_particle()

	if _particles.is_empty():
		return

	var i: int = _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p.age += delta
		if p.age >= p.lifetime:
			_particles.remove_at(i)
		else:
			p.vel.y -= 42.0 * delta
			p.vel.x += sin(p.age * 12.0 + p.phase) * 16.0 * delta
			p.pos += p.vel * delta
		i -= 1

	queue_redraw()

func _spawn_particle() -> void:
	# Triangle-biased horizontal distribution for a fuller flame core
	var rx: float = (randf() + randf() - 1.0) * emission_rect_extents.x
	var ry: float = randf_range(-emission_rect_extents.y, emission_rect_extents.y)
	var origin: Vector2 = Vector2.ZERO if local_coords else global_position
	var pos: Vector2 = origin + Vector2(rx, ry)

	var roll: float = randf()
	var blob_type: int = 0 if roll < 0.35 else (1 if roll < 0.78 else 2)

	_particles.append({
		"pos": pos,
		"vel": Vector2(randf_range(-10.0, 10.0), randf_range(-48.0, -24.0)),
		"age": 0.0,
		"lifetime": randf_range(0.45, 0.90),
		"blob_type": blob_type,
		"phase": randf_range(0.0, TAU)
	})

func _draw() -> void:
	if palette_colors.size() < 5:
		return
	for p in _particles:
		var t: float = clampf(p.age / p.lifetime, 0.0, 1.0)
		var col: Color
		if t < 0.22:
			col = palette_colors[0]
		elif t < 0.45:
			col = palette_colors[1]
		elif t < 0.70:
			col = palette_colors[2]
		elif t < 0.88:
			col = palette_colors[3]
		else:
			col = palette_colors[4]

		var local_p: Vector2 = p.pos if local_coords else (p.pos - global_position)
		var gx: float = floor(local_p.x)
		var gy: float = floor(local_p.y)

		var blob_type: int = p.blob_type
		if blob_type == 0:
			if t < 0.32:
				# 4x4 pixel-grid rounded fire blob
				draw_rect(Rect2(gx - 1.0, gy, 4.0, 2.0), col)
				draw_rect(Rect2(gx, gy - 1.0, 2.0, 4.0), col)
			elif t < 0.65:
				# 2x2 pixel blob
				draw_rect(Rect2(gx, gy, 2.0, 2.0), col)
			else:
				# 1x1 pixel ember
				draw_rect(Rect2(gx, gy, 1.0, 1.0), col)
		elif blob_type == 1:
			if t < 0.40:
				# 3x3 pixel-grid plus blob
				draw_rect(Rect2(gx - 1.0, gy, 3.0, 1.0), col)
				draw_rect(Rect2(gx, gy - 1.0, 1.0, 3.0), col)
			elif t < 0.72:
				draw_rect(Rect2(gx, gy, 2.0, 2.0), col)
			else:
				draw_rect(Rect2(gx, gy, 1.0, 1.0), col)
		else:
			if t < 0.50:
				draw_rect(Rect2(gx, gy, 2.0, 2.0), col)
			else:
				draw_rect(Rect2(gx, gy, 1.0, 1.0), col)
