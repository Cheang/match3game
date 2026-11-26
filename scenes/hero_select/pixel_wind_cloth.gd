class_name PixelWindCloth
extends Node2D

## Pixel-art cloth strip animated with a stable arc-length wind drape and travelling wave,
## rendered onto a 1:1 pixel grid. Picks a consistent wind direction per scene entry while
## gently varying wind strength over time.

const FIXED_DT: float = 1.0 / 60.0

@export_group("Simulation")
@export_range(8.0, 160.0, 1.0) var length_px: float = 58.0:
	set(value):
		length_px = value
		_rebuild_chain()
@export_range(4, 24, 1) var segment_count: int = 10:
	set(value):
		segment_count = max(4, value)
		_rebuild_chain()
@export_range(20.0, 400.0, 5.0) var gravity: float = 165.0
@export_range(0.80, 0.99, 0.01) var damping: float = 0.92
@export_range(2, 12, 1) var stiffness_iterations: int = 6
@export_range(0.0, 2.5, 0.05) var wind_scale: float = 1.0
@export_range(0.0, 2.5, 0.05) var flutter_scale: float = 1.0
@export_range(-1.0, 1.0, 0.1) var initial_rest_dir: float = -1.0

@export_group("Appearance")
@export_range(2.0, 24.0, 0.5) var base_width_px: float = 13.0:
	set(value):
		base_width_px = value
		queue_redraw()
@export_range(1.0, 20.0, 0.5) var tip_width_px: float = 8.0:
	set(value):
		tip_width_px = value
		queue_redraw()
@export_enum("Angled Cloth", "Torn Notch", "Tapered Sash") var tip_style: int = 0:
	set(value):
		tip_style = value
		queue_redraw()
@export var color_highlight: Color = Color(0.909804, 0.231373, 0.231373, 1.0) # #e83b3b
@export var color_mid: Color = Color(0.682353, 0.137255, 0.203922, 1.0)       # #ae2334
@export var color_shadow: Color = Color(0.478431, 0.188235, 0.270588, 1.0)    # #7a3045
@export var color_deep_shadow: Color = Color(0.270588, 0.160784, 0.247059, 1.0) # #45293f

# Shared session wind state across all PixelWindCloth nodes
static var _weather_initialized: bool = false
static var _weather_frame: int = -1
static var _scene_wind_epoch: int = 0
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _weather_time: float = 0.0
static var _wind_dir: float = -1.0
static var _wind_base_strength: float = 0.62
static var _wind_timer: float = 0.0
static var _wind_current: float = -0.62
static var _wind_target: float = -0.62
static var _wind_slew_rate: float = 0.75
static var _wind_impulse: float = 0.0

var _points: PackedVector2Array = PackedVector2Array()
var _local_time: float = 0.0
var _smooth_wind: float = -0.62
var _piece_phase: float = 0.0
var _piece_freq_mul: float = 1.0
var _piece_impulse: float = 0.0
var _applied_wind_epoch: int = -1
var _seeded_rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Picks a new dominant wind direction (left or right) for the current screen visit
## and sets a calm baseline wind strength so cloth drifts naturally without spasming.
static func pick_new_scene_wind(force_dir: float = 0.0) -> void:
	_weather_initialized = true
	_rng.randomize()
	if absf(force_dir) > 0.01:
		_wind_dir = signf(force_dir)
	else:
		_wind_dir = -1.0 if _rng.randf() < 0.5 else 1.0

	_wind_base_strength = _rng.randf_range(0.52, 0.74)
	var initial_wind := _wind_dir * _wind_base_strength
	_wind_current = initial_wind
	_wind_target = initial_wind
	_wind_impulse = 0.0
	_wind_timer = _rng.randf_range(2.4, 4.8)
	_wind_slew_rate = _rng.randf_range(0.55, 0.95)
	_scene_wind_epoch += 1


static func trigger_global_wind_impulse(impulse_x: float) -> void:
	_init_weather()
	_wind_impulse = clampf(_wind_impulse + impulse_x * 0.35, -0.45, 0.45)


func trigger_wind_impulse(impulse_x: float) -> void:
	_piece_impulse = clampf(_piece_impulse + impulse_x * 0.35, -0.5, 0.5)


func _init() -> void:
	_init_weather()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seeded_rng.seed = hash(name) ^ int(absf(position.x) * 31.0 + absf(position.y) * 97.0)
	_piece_phase = _seeded_rng.randf_range(0.0, TAU)
	_piece_freq_mul = _seeded_rng.randf_range(0.90, 1.10)
	_local_time = _seeded_rng.randf_range(0.0, 20.0)
	_sync_scene_wind_epoch()


func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _points.is_empty():
		_rebuild_chain()


func _process(delta: float) -> void:
	if _points.size() != segment_count:
		_rebuild_chain()

	_sync_scene_wind_epoch()
	var clamped_delta := minf(delta, 0.05)
	_step_shared_weather(clamped_delta)
	_update_cloth_spine(clamped_delta)
	queue_redraw()


static func _init_weather() -> void:
	if _weather_initialized:
		return
	pick_new_scene_wind()


static func _pick_next_wind_episode() -> void:
	# Keep the scene direction fixed and modulate strength gently around _wind_base_strength.
	var strength_mult := _rng.randf_range(0.78, 1.18)
	var target_mag := clampf(_wind_base_strength * strength_mult, 0.38, 0.86)
	_wind_target = _wind_dir * target_mag
	_wind_timer = _rng.randf_range(2.4, 4.8)
	_wind_slew_rate = _rng.randf_range(0.55, 0.95)


static func _step_shared_weather(delta: float) -> void:
	_init_weather()
	var frame := Engine.get_process_frames()
	if _weather_frame == frame:
		return
	_weather_frame = frame

	_weather_time += delta
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_pick_next_wind_episode()

	_wind_current = lerpf(_wind_current, _wind_target, 1.0 - exp(-_wind_slew_rate * delta))
	_wind_impulse = lerpf(_wind_impulse, 0.0, 1.0 - exp(-3.0 * delta))


func _sync_scene_wind_epoch() -> void:
	_init_weather()
	if _applied_wind_epoch == _scene_wind_epoch:
		return
	_applied_wind_epoch = _scene_wind_epoch
	_smooth_wind = _wind_current * wind_scale
	_update_cloth_spine(0.0)
	queue_redraw()


func _sample_local_wind() -> float:
	var gpos := global_position if is_inside_tree() else position
	var travel_dir := signf(_wind_dir) if absf(_wind_dir) > 0.01 else 1.0
	var spatial_lag := gpos.x * 0.0014 * travel_dir + gpos.y * 0.0005
	var t := _weather_time - spatial_lag

	# Slow, natural multi-octave breeze swell around the session direction
	var swell := sin(t * 0.45 + 0.4) * 0.08 + sin(t * 0.85 + 1.9) * 0.04
	var wind := _wind_current + _wind_dir * (swell * _wind_base_strength)
	return wind + _wind_impulse + _piece_impulse


func _rebuild_chain() -> void:
	_smooth_wind = _wind_current * wind_scale
	_update_cloth_spine(0.0)
	queue_redraw()


func _update_cloth_spine(dt: float) -> void:
	var count := maxi(4, segment_count)
	if _points.size() != count:
		_points.resize(count)

	if dt > 0.0:
		_local_time += dt
		var target_wind := _sample_local_wind() * wind_scale
		_smooth_wind = lerpf(_smooth_wind, target_wind, 1.0 - exp(-2.4 * dt))
		_piece_impulse = lerpf(_piece_impulse, 0.0, 1.0 - exp(-3.5 * dt))

	var seg_len := length_px / float(count - 1)
	var abs_wind := absf(_smooth_wind)
	var wave_speed := (1.75 + abs_wind * 0.95) * _piece_freq_mul

	var p := Vector2.ZERO
	_points[0] = p
	for i in range(1, count):
		var t_norm := float(i) / float(count - 1)
		var base_angle := clampf(
			_smooth_wind * (0.58 + 0.34 * smoothstep(0.0, 0.75, t_norm)),
			-0.92,
			0.92
		)

		var phase := t_norm * 3.4 - _local_time * wave_speed + _piece_phase
		var wave := sin(phase) * 0.74 + sin(phase * 1.65 + 0.7) * 0.26
		var pin_factor := smoothstep(0.0, 0.22, t_norm) * (0.35 + 0.65 * t_norm)
		var wave_angle := wave * (0.05 + abs_wind * 0.12) * flutter_scale * pin_factor

		var total_angle := clampf(base_angle + wave_angle, -1.08, 1.08)
		p += Vector2(sin(total_angle), cos(total_angle)) * seg_len
		_points[i] = p


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


## Returns Vector2(top_offset, bot_offset) across the cloth perpendicular for a spine fraction t_len.
func _compute_cloth_half_widths(t_len: float, fold_twist: float) -> Vector2:
	# 1. Knot gather flares smoothly from 68% width into full fabric width
	var gather := 1.0
	if t_len < 0.14:
		gather = lerpf(0.68, 1.0, smoothstep(0.0, 0.14, t_len))

	# 2. Broad fabric body across the middle before tip shaping
	var body_t := clampf((t_len - 0.14) / 0.64, 0.0, 1.0)
	var width := lerpf(base_width_px, tip_width_px, body_t) * gather * fold_twist
	var half := maxf(1.2, width * 0.5)

	# 3. Tip silhouette
	if tip_style == 0:
		# Angled Cloth: diagonal sheared cut ending in a ~2.2px upper corner
		if t_len > 0.78:
			var u := (t_len - 0.78) / 0.22
			var corner_y := half * 0.55
			var top_o := lerpf(half, corner_y + 1.1, pow(u, 1.15))
			var bot_o := lerpf(-half, corner_y - 1.1, pow(u, 0.78))
			return Vector2(top_o, minf(bot_o, top_o - 1.5))
		return Vector2(half, -half)
	elif tip_style == 2:
		# Tapered Sash: stays full until 82%, then tapers cleanly to a ~2.5px tip
		if t_len > 0.82:
			var u2 := (t_len - 0.82) / 0.18
			var tip_h := maxf(1.25, lerpf(half, 1.25, pow(u2, 1.35)))
			return Vector2(tip_h, -tip_h)
		return Vector2(half, -half)
	else:
		# Torn Notch: holds nearly full width while V-notch carves into center in _draw()
		if t_len > 0.78:
			var u1 := (t_len - 0.78) / 0.22
			var notch_h := lerpf(half, maxf(1.5, half * 0.72), u1)
			return Vector2(notch_h, -notch_h)
		return Vector2(half, -half)


func _draw() -> void:
	var count := _points.size()
	if count < 4:
		return

	# Oversample the chain via Catmull-Rom spline for smooth fabric curves
	var samples := PackedVector2Array()
	var sub_steps := 8
	for i in range(count - 1):
		var p0 := _points[maxi(0, i - 1)]
		var p1 := _points[i]
		var p2 := _points[i + 1]
		var p3 := _points[mini(count - 1, i + 2)]
		var start_s := 0 if i == 0 else 1
		for s in range(start_s, sub_steps + 1):
			var t := float(s) / float(sub_steps)
			samples.append(_catmull_rom(p0, p1, p2, p3, t))

	var sample_count := samples.size()
	if sample_count < 3:
		return

	# Bounding box padded by maximum cloth half-width
	var pad := int(ceilf(maxf(base_width_px, tip_width_px) * 0.6)) + 3
	var min_x_f := samples[0].x
	var max_x_f := samples[0].x
	var min_y_f := samples[0].y
	var max_y_f := samples[0].y
	for p in samples:
		min_x_f = minf(min_x_f, p.x)
		max_x_f = maxf(max_x_f, p.x)
		min_y_f = minf(min_y_f, p.y)
		max_y_f = maxf(max_y_f, p.y)

	var min_x := int(floorf(min_x_f)) - pad
	var max_x := int(ceilf(max_x_f)) + pad
	var min_y := int(floorf(min_y_f)) - pad
	var max_y := int(ceilf(max_y_f)) + pad
	var gw := max_x - min_x + 1
	var gh := max_y - min_y + 1
	if gw <= 0 or gh <= 0 or gw * gh > 65536:
		return

	var shade_buf := PackedInt32Array()
	shade_buf.resize(gw * gh)
	shade_buf.fill(0)

	var dist_buf := PackedFloat32Array()
	dist_buf.resize(gw * gh)
	dist_buf.fill(1e9)

	var abs_wind := absf(_smooth_wind)
	var wind_left := _wind_dir < 0.0

	for s in range(sample_count):
		var c := samples[s]
		var prev_s := samples[maxi(0, s - 1)]
		var next_s := samples[mini(sample_count - 1, s + 1)]
		var tangent := next_s - prev_s
		var tan_len := tangent.length()
		if tan_len <= 0.0001:
			continue
		tangent /= tan_len

		# Deterministic skyward-pointing normal so top/bottom shading and angled tip never flip
		var normal := Vector2(-tangent.y, tangent.x) if wind_left else Vector2(tangent.y, -tangent.x)

		# Estimate bend curvature for fold bands
		var curv := 0.0
		if s > 2 and s < sample_count - 3:
			var t_prev := (c - samples[s - 3]).normalized()
			var t_next := (samples[s + 3] - c).normalized()
			curv = (t_next - t_prev).dot(normal)

		var t_len := float(s) / float(sample_count - 1)
		var fold_phase := t_len * 9.0 - _local_time * (1.8 + abs_wind * 1.1) + _piece_phase
		var fold_twist := clampf(0.94 + 0.08 * cos(fold_phase), 0.86, 1.02)
		var bounds := _compute_cloth_half_widths(t_len, fold_twist)
		var top_o := bounds.x
		var bot_o := bounds.y
		var span := maxf(1.0, top_o - bot_o)

		# Torn Notch tip cutout on the center of the last 16% of the strip
		var notch_half := 0.0
		if tip_style == 1 and t_len > 0.84:
			notch_half = ((t_len - 0.84) / 0.16) * (span * 0.24)

		var fold_ripple := sin(fold_phase) * 0.24 * smoothstep(0.10, 0.85, t_len)
		var steps_n := maxi(3, int(ceilf(span / 0.42)))
		for k in range(steps_n + 1):
			var u_k := float(k) / float(steps_n)
			var perp_o := lerpf(bot_o, top_o, u_k)
			if notch_half > 0.05:
				var center_o := 0.5 * (top_o + bot_o)
				if absf(perp_o - center_o) < notch_half:
					continue

			var sample_pos := c + normal * perp_o
			var side := u_k * 2.0 - 1.0 # -1 at shadow edge, +1 at top/lit edge
			var cx := int(floorf(sample_pos.x))
			var cy := int(floorf(sample_pos.y))
			for py in range(cy - 1, cy + 2):
				var gy := py - min_y
				if gy < 0 or gy >= gh:
					continue
				for px in range(cx - 1, cx + 2):
					var gx := px - min_x
					if gx < 0 or gx >= gw:
						continue
					var d := Vector2(float(px) + 0.5 - sample_pos.x, float(py) + 0.5 - sample_pos.y).length()
					if d <= 0.64:
						var idx := gy * gw + gx
						if d < dist_buf[idx]:
							dist_buf[idx] = d
							var top_bias := maxf(0.0, -normal.y) * 0.22
							var light_score := (
								side * 0.44
								+ curv * 1.10
								+ fold_ripple
								+ top_bias
								+ (1.0 - t_len) * 0.08
							)
							var shade_idx := 3
							if side > 0.72 or light_score > 0.34:
								shade_idx = 4
							elif t_len < 0.08 or side < -0.62 or light_score < -0.25:
								shade_idx = 2
							shade_buf[idx] = shade_idx

	# Crisp 1px deep-shadow accent along the bottom exposed rim and knot fold crease
	for gy in range(gh - 1):
		for gx in range(gw):
			var idx := gy * gw + gx
			var val := shade_buf[idx]
			if val > 0 and shade_buf[(gy + 1) * gw + gx] == 0:
				shade_buf[idx] = 1 if val <= 2 else 2

	# Flush contiguous horizontal runs onto 1x1 pixel grid
	var colors: Array[Color] = [
		Color.TRANSPARENT,
		color_deep_shadow,
		color_shadow,
		color_mid,
		color_highlight,
	]
	for gy in range(gh):
		var wy := float(min_y + gy)
		var gx := 0
		while gx < gw:
			var val := shade_buf[gy * gw + gx]
			if val == 0:
				gx += 1
				continue
			var run_end := gx + 1
			while run_end < gw and shade_buf[gy * gw + run_end] == val:
				run_end += 1
			draw_rect(Rect2(float(min_x + gx), wy, float(run_end - gx), 1.0), colors[val], true)
			gx = run_end
