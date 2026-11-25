class_name CandleFlame
extends Node2D

## Crisp 1:1 pixel-art flickering candle flame with subtle rising sparks.
## Exposes current flicker intensity and micro-offset so the table shader stays in sync.

const COL_CORE := Color(1.0, 1.0, 1.0, 1.0)         # #ffffff
const COL_INNER := Color(0.984314, 1.0, 0.52549, 1.0) # #fbff86
const COL_MID := Color(0.976471, 0.760784, 0.168627, 1.0) # #f9c22b
const COL_OUTER := Color(0.984314, 0.419608, 0.113725, 1.0) # #fb6b1d

var _time: float = 0.0
var _flicker: float = 1.0
var _jitter: Vector2 = Vector2.ZERO
var _embers: Array[Dictionary] = []
var _ember_timer: float = 0.4


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func get_flicker_value() -> float:
	return _flicker


func get_flame_jitter_offset() -> Vector2:
	return _jitter


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += dt

	# Calm, natural multi-octave candle flicker (no harsh strobing)
	var f1 := sin(_time * 4.3 + 0.7) * 0.045
	var f2 := sin(_time * 7.9 + 2.1) * 0.025
	var f3 := sin(_time * 13.7 + 4.4) * 0.012
	_flicker = clampf(1.0 + f1 + f2 + f3, 0.88, 1.12)

	var sway_x := sin(_time * 3.1 + 0.3) * 1.4 + sin(_time * 6.7) * 0.6
	var sway_y := sin(_time * 5.2 + 1.4) * 0.8
	_jitter = Vector2(sway_x, sway_y)

	_ember_timer -= dt
	if _ember_timer <= 0.0:
		_ember_timer = randf_range(0.55, 1.45)
		if _embers.size() < 4:
			_embers.append({
				"pos": Vector2(randf_range(-2.0, 2.0), -14.0),
				"vel": Vector2(randf_range(-5.0, 5.0), randf_range(-26.0, -16.0)),
				"age": 0.0,
				"life": randf_range(0.55, 1.0)
			})

	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e["age"] = float(e["age"]) + dt
		if float(e["age"]) >= float(e["life"]):
			_embers.remove_at(i)
			continue
		var pos: Vector2 = e["pos"]
		var vel: Vector2 = e["vel"]
		vel.x += sin(_time * 5.0 + float(i)) * 12.0 * dt
		pos += vel * dt
		e["pos"] = pos
		e["vel"] = vel

	queue_redraw()


func _draw() -> void:
	var sway := sin(_time * 3.1 + 0.3) * 1.6 + sin(_time * 6.7) * 0.7
	var stretch := 1.0 + (_flicker - 1.0) * 1.6
	var flame_h := clampf(21.0 * stretch, 16.0, 25.0)
	var max_w := 6.5

	# Outer silhouette teardrop pixels from base (y=+2) up to flame tip
	var top_y := int(roundf(2.0 - flame_h))
	for py in range(top_y, 4):
		var t := clampf(float(3 - py) / maxf(1.0, flame_h), 0.0, 1.0) # 0 at bottom, 1 at tip
		var profile := sin(t * PI) * (1.0 - t * 0.32)
		if t < 0.25:
			profile = lerpf(0.55, profile, t / 0.25)
		var half_w := maxf(0.5, max_w * profile)
		var cx := sway * pow(t, 1.35)

		var x0 := int(floorf(cx - half_w))
		var x1 := int(ceilf(cx + half_w))
		for px in range(x0, x1 + 1):
			var dx := absf((float(px) + 0.5) - cx) / maxf(0.5, half_w)
			if dx > 1.0:
				continue
			var col := COL_OUTER
			if t < 0.58 and dx < 0.72:
				col = COL_MID
			if t < 0.42 and dx < 0.46 and py > top_y + 4:
				col = COL_INNER
			if t >= 0.10 and t < 0.28 and dx < 0.26:
				col = COL_CORE
			draw_rect(Rect2(float(px), float(py), 1.0, 1.0), col, true)

	# Rising tiny ember pixels
	for e in _embers:
		var pos: Vector2 = e["pos"]
		var alpha := clampf(1.0 - float(e["age"]) / maxf(0.01, float(e["life"])), 0.0, 1.0)
		var col := Color(COL_MID.r, COL_MID.g, COL_MID.b, alpha)
		draw_rect(Rect2(floorf(pos.x), floorf(pos.y), 1.0, 1.0), col, true)
