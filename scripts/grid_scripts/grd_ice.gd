extends Node2D


var ice_pieces = []
var ice = preload("res://piece/obstacles_sq/ice.tscn")
var one_time: bool = false

func _ready() -> void:
	one_time = false
	ice_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)

func _on_grd_make_ice(grd_cord) -> void:
	if ice_pieces.size() == 0:
		ice_pieces = Global.make_2d_array(Global.grd_width, Global.grd_height)
	var current = ice.instantiate()
	add_child(current)
	current.position = Vector2(Global.grd_to_pixel(grd_cord.x, grd_cord.y))
	ice_pieces[grd_cord.x][grd_cord.y] = current
	one_time = true

func _on_grd_damage_ice(grd_cord) -> void:
	if ice_pieces[grd_cord.x][grd_cord.y] != null:
		ice_pieces[grd_cord.x][grd_cord.y].take_damage(1)
		if ice_pieces[grd_cord.x][grd_cord.y].health <= 0:
			ice_pieces[grd_cord.x][grd_cord.y].queue_free()
			ice_pieces[grd_cord.x][grd_cord.y] = null
			dmg_enemy_if_all_destroied()

func dmg_enemy_if_all_destroied():
	var is_empty: bool = true
	
	for i in Global.grd_width:
		for j in Global.grd_height:
			if ice_pieces[i][j] != null:
				is_empty = false
				break
		if not is_empty:
			break
	if is_empty and one_time:
		Global.cur_enemy.take_dmg(round(Global.cur_enemy.cur_health / 2), -1)
		one_time = false
