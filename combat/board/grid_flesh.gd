extends Node2D

@warning_ignore("unused_signal")
signal remove_flesh(grd_cord: Vector2)

const FLESH_SCENE: PackedScene = preload("res://combat/tiles/obstacles/flesh.tscn")

var flesh_pieces: Array = []


func _ready() -> void:
	flesh_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)


func _on_grd_make_flesh(grd_cord: Vector2) -> void:
	if flesh_pieces.is_empty():
		flesh_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current: Node2D = FLESH_SCENE.instantiate() as Node2D
	add_child(current)
	current.position = Global.grd_to_pixel(grd_cord.x, grd_cord.y)
	flesh_pieces[grd_cord.x][grd_cord.y] = current


func _on_grd_damage_flesh(grd_cord: Vector2) -> void:
	if flesh_pieces[grd_cord.x][grd_cord.y] != null:
		flesh_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if flesh_pieces[grd_cord.x][grd_cord.y].health <= 0:
			flesh_pieces[grd_cord.x][grd_cord.y].queue_free()
			flesh_pieces[grd_cord.x][grd_cord.y] = null
			remove_flesh.emit(grd_cord)

