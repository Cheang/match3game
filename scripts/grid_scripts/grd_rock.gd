extends Node2D

@warning_ignore("unused_signal")
signal remove_rock

var rock_pieces = []
var rock = preload("res://piece/obstacles_sq/rock.tscn")

func _ready() -> void:
	rock_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	pass

func _on_grd_make_rock(grd_cord) -> void:
	if rock_pieces.size() == 0:
		rock_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current = rock.instantiate()
	add_child(current)
	current.position = Vector2(Global.grd_to_pixel(grd_cord.x, grd_cord.y))
	rock_pieces[grd_cord.x][grd_cord.y] = current

func _on_grd_damage_rock(grd_cord) -> void:
	if rock_pieces[grd_cord.x][grd_cord.y] != null:
		rock_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if rock_pieces[grd_cord.x][grd_cord.y].health <= 0:
			rock_pieces[grd_cord.x][grd_cord.y].queue_free()
			rock_pieces[grd_cord.x][grd_cord.y] = null
			emit_signal("remove_rock",grd_cord)
