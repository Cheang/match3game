extends Node2D
class_name EnemyAttackOverlay

const BORDER_TEXTURE = preload("res://assets/gold_border_sq.png")
const INDICATOR_COLOR = Color(1.0, 0.22, 0.22, 0.85)

# Dictionary of active cells: Vector2i -> Sprite2D
var _indicators: Dictionary = {}
var _tweens: Dictionary = {}

func _init() -> void:
	z_index = 25

func update_targets(cells: Array[Vector2i], grid_to_pixel_fn: Callable) -> void:
	# Remove any indicators that are no longer targeted
	var to_remove: Array[Vector2i] = []
	for old_cell in _indicators.keys():
		if not cells.has(old_cell):
			to_remove.append(old_cell)

	for rem_cell in to_remove:
		_remove_indicator(rem_cell)

	# Add indicators for new cells
	for cell in cells:
		if not _indicators.has(cell):
			_add_indicator(cell, grid_to_pixel_fn.call(cell.x, cell.y))

func clear_targets() -> void:
	for cell in _indicators.keys():
		_remove_indicator(cell)
	_indicators.clear()
	_tweens.clear()

func _add_indicator(cell: Vector2i, world_pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "TargetIndicator_%d_%d" % [cell.x, cell.y]
	sprite.texture = BORDER_TEXTURE
	sprite.position = world_pos
	sprite.modulate = INDICATOR_COLOR
	add_child(sprite)
	_indicators[cell] = sprite

	# Smooth pulsing tween
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "modulate:a", 0.35, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sprite, "modulate:a", 0.95, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens[cell] = tw

func _remove_indicator(cell: Vector2i) -> void:
	if _tweens.has(cell):
		var tw: Tween = _tweens[cell]
		if tw != null and tw.is_valid():
			tw.kill()
		_tweens.erase(cell)

	if _indicators.has(cell):
		var sprite: Sprite2D = _indicators[cell]
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		_indicators.erase(cell)
