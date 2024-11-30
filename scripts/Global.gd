extends Node

var cur_char: PlayerResource

var grd_x_start: int = 64
var grd_y_start: int = 800
var grd_width: int = 8
var grd_height: int = 9
var grd_offset: int = 64

var game_is_played: bool = false

#_________________________________________________________#

func grd_to_pixel(col, row):
	var new_x = grd_x_start + grd_offset * col
	var new_y = grd_y_start + -grd_offset * row
	return Vector2(new_x, new_y)

func pixel_to_grd(x, y):
	var new_x = round((x - grd_x_start) / grd_offset)
	var new_y = round((y - grd_y_start) / -grd_offset)
	return Vector2(new_x, new_y)

func make_2d_array(width, height):
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

func is_null(item):
	if item == null:
		return true
	return false

func is_in_array(array, item):
	for i in array.size():
		if array[i] == item:
			return true
	return false

func set_cur_character(char: PlayerResource):
	cur_char = char

func reset_character_stats():
	cur_char.moves_left = cur_char.speed
	cur_char.armor = cur_char.start_armor
	cur_char.mage_armor = cur_char.start_mage_armor
