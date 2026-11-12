extends Node2D

@warning_ignore("unused_signal")
signal remove_rock(grd_cord: Vector2)

const ROCK_SCENE: PackedScene = preload("res://combat/tiles/obstacles/rock.tscn")

var rock_pieces: Array = []


func _ready() -> void:
	rock_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)


func _on_grd_make_rock(grd_cord: Vector2) -> void:
	if rock_pieces.is_empty():
		rock_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current: Node2D = ROCK_SCENE.instantiate() as Node2D
	add_child(current)
	current.position = Global.grd_to_pixel(grd_cord.x, grd_cord.y)
	rock_pieces[grd_cord.x][grd_cord.y] = current


func _on_grd_damage_rock(grd_cord: Vector2) -> void:
	if rock_pieces[grd_cord.x][grd_cord.y] != null:
		rock_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if rock_pieces[grd_cord.x][grd_cord.y].health <= 0:
			rock_pieces[grd_cord.x][grd_cord.y].queue_free()
			rock_pieces[grd_cord.x][grd_cord.y] = null
			remove_rock.emit(grd_cord)

