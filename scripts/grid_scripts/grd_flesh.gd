extends Node2D

@warning_ignore("unused_signal")
signal remove_flesh

var flesh_pieces = []
var flesh = preload("res://tiles/obstacles/flesh.tscn")

func _ready() -> void:
	flesh_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)

func _on_grd_make_flesh(grd_cord) -> void:
	if flesh_pieces.size() == 0:
		flesh_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current = flesh.instantiate()
	add_child(current)
	current.position = Vector2(Global.grd_to_pixel(grd_cord.x, grd_cord.y))
	flesh_pieces[grd_cord.x][grd_cord.y] = current

func _on_grd_damage_flesh(grd_cord) -> void:
	if flesh_pieces[grd_cord.x][grd_cord.y] != null:
		flesh_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if flesh_pieces[grd_cord.x][grd_cord.y].health <= 0:
			flesh_pieces[grd_cord.x][grd_cord.y].queue_free()
			flesh_pieces[grd_cord.x][grd_cord.y] = null
			emit_signal("remove_flesh",grd_cord)
