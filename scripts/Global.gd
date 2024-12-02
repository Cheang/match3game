extends Node

var cur_char: PlayerResource
var selected_char: PlayerResource

var grd_x_start: int = 64
var grd_y_start: int = 800
var grd_width: int = 8
var grd_height: int = 9
var grd_offset: int = 64

var game_is_played: bool = false
var current_wave: int = 0
var current_level: int = 1

var locations: Array[Location]

#for boss spawning
var minions_killed: int = 0
var boss_added: bool = false

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

func set_cur_character(character: PlayerResource):
	cur_char = character

func reset_character_stats():
	cur_char.moves_left = cur_char.speed
	cur_char.armor = cur_char.start_armor
	cur_char.mage_armor = cur_char.start_mage_armor

func pick_locations(enemies_numb: int = 4, event_num: int = 4, services_num: int = 2):
	locations.clear()
	if !Locations.enemy_loc_cards.is_empty():
		for i in enemies_numb:
			var loc: Location = Locations.enemy_loc_cards.pick_random()
			locations.append(loc)
	if !Locations.event_loc_cards.is_empty():
		for i in event_num:
			var loc: Location = Locations.event_loc_cards.pick_random()
			locations.append(loc)
	if !Locations.services_loc_cards.is_empty():
		for i in services_num:
			var loc: Location = Locations.services_loc_cards.pick_random()
			locations.append(loc)
	locations.shuffle()

func add_boss_to_locations(req: int):
	if !boss_added:
		if minions_killed >= req:
			if !is_null(Locations.boss_loc_cards):
				locations.append(Locations.boss_loc_cards.pick_random())
				boss_added = true

func set_up_player():
	if is_null(selected_char):
		var def_char: PlayerResource = preload("res://players/warrior/warrior.tres")
		selected_char = def_char.duplicate()
	cur_char = selected_char.duplicate()
	cur_char.cur_health = cur_char.max_health
	cur_char.armor = cur_char.start_armor
	cur_char.mage_armor = cur_char.start_mage_armor

func set_up_variable():
	current_wave = 0
	minions_killed = 0
	boss_added = false
