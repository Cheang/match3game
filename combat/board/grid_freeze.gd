extends Node2D

@warning_ignore("unused_signal")
signal remove_freeze(grd_cord: Vector2)

const FREEZE_SCENE: PackedScene = preload("res://combat/tiles/obstacles/freeze.tscn")

var freeze_pieces: Array = []


func _ready() -> void:
	freeze_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)


func _on_grd_make_freeze(grd_cord: Vector2) -> void:
	if freeze_pieces.is_empty():
		freeze_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current: Node2D = FREEZE_SCENE.instantiate() as Node2D
	add_child(current)
	current.position = Global.grd_to_pixel(grd_cord.x, grd_cord.y)
	freeze_pieces[grd_cord.x][grd_cord.y] = current


func _on_grd_damage_freeze(grd_cord: Vector2) -> void:
	if freeze_pieces[grd_cord.x][grd_cord.y] != null:
		freeze_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if freeze_pieces[grd_cord.x][grd_cord.y].health <= 0:
			freeze_pieces[grd_cord.x][grd_cord.y].queue_free()
			freeze_pieces[grd_cord.x][grd_cord.y] = null
			remove_freeze.emit(grd_cord)

