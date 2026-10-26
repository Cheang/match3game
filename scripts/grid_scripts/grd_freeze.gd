extends Node2D

@warning_ignore("unused_signal")
signal remove_freeze

var freeze_pieces = []
var freeze = preload("res://tiles/obstacles/freeze.tscn")

func _ready() -> void:
	freeze_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	pass

func _on_grd_make_freeze(grd_cord) -> void:
	if freeze_pieces.size() == 0:
		freeze_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current = freeze.instantiate()
	add_child(current)
	current.position = Vector2(Global.grd_to_pixel(grd_cord.x, grd_cord.y))
	freeze_pieces[grd_cord.x][grd_cord.y] = current

func _on_grd_damage_freeze(grd_cord) -> void:
	if freeze_pieces[grd_cord.x][grd_cord.y] != null:
		freeze_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if freeze_pieces[grd_cord.x][grd_cord.y].health <= 0:
			freeze_pieces[grd_cord.x][grd_cord.y].queue_free()
			freeze_pieces[grd_cord.x][grd_cord.y] = null
			emit_signal("remove_freeze",grd_cord)
