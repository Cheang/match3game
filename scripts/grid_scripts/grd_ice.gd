extends Node2D


var ice_pieces = []
var ice = preload("res://piece/obstacles_sq/ice.tscn")

func _ready() -> void:
	ice_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	pass

func _on_grd_make_ice(grd_cord) -> void:
	if ice_pieces.size() == 0:
		ice_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current = ice.instantiate()
	add_child(current)
	current.position = Vector2(Global.grd_to_pixel(grd_cord.x, grd_cord.y))
	ice_pieces[grd_cord.x][grd_cord.y] = current

func _on_grd_damage_ice(grd_cord) -> void:
	if ice_pieces[grd_cord.x][grd_cord.y] != null:
		ice_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if ice_pieces[grd_cord.x][grd_cord.y].health <= 0:
			ice_pieces[grd_cord.x][grd_cord.y].queue_free()
			ice_pieces[grd_cord.x][grd_cord.y] = null
