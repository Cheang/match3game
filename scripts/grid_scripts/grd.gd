extends Node2D

#state machine
enum {wait, move} 
var state

#Grid Variables
var grd_x_start: int = Global.grd_x_start
var grd_y_start: int = Global.grd_y_start
var grd_width: int = Global.grd_width
var grd_height: int = Global.grd_height
var grd_offset: int = Global.grd_offset

#player tiles will go in here
var deck : Array[PackedScene]
var deck_on_cd : Array[PieceClass] = []
var fluf : Array[PackedScene]

#the current pieces in the game
var all_pieces = []

#obstacles
var empty_spaces: Array[Vector2]
var ice_spaces: Array[Vector2]
var freeze_spaces: Array[Vector2]

#obstacles signals
signal damage_ice
signal make_ice
signal damage_freeze
signal make_freeze

#slap back
var piece_one = null
var piece_two = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)
var move_checked = false

#touch variables
var first_touch = Vector2(0, 0)
var final_touch = Vector2(0, 0)
var controling_grd: bool = false


func on_startup() -> void:
	deck = Global.cur_char.deck.duplicate()
	fluf = Global.cur_char.fluf.duplicate()
	deck.shuffle()
	fluf.shuffle()
	randomize()
	all_pieces = Global.make_2d_array(grd_width, grd_height)
	await get_tree().create_timer(.8).timeout
	spawn_deck_pieces_random(deck)
	spawn_fluf_piece(fluf)
	spawn_obstacles(ice_spaces, "make_ice")
	spawn_obstacles(freeze_spaces, "make_freeze")

func _process(_delta: float) -> void:
	if state == move:
		touch_input()

func restricted_fill(place: Vector2):
	if Global.is_in_array(empty_spaces, place):
			return true
	return false

func restricted_move(place: Vector2):
	if Global.is_in_array(freeze_spaces, place):
		return true
	return false

func spawn_obstacles(ob_spaces, signal_str: String):
	for i in ob_spaces.size():
		emit_signal(signal_str, ob_spaces[i])

func spawn_fluf_piece(deck_to_use):
	for i in range(grd_width):
		for j in range(grd_height):
			if !restricted_fill(Vector2(i, j)):
				if all_pieces[i][j] == null:
					#choose piece
					var rand = floor(randf_range(0,deck_to_use.size()))
					var piece = deck_to_use[rand].instantiate()
					var loops = 0;
					while match_at(i, j, piece.color) && loops < 100:
						piece.queue_free()
						rand = floor(randf_range(0,deck_to_use.size()))
						loops += 1 
						piece = deck_to_use[rand].instantiate()
					#create piece
					add_child(piece)
					piece.position = Global.grd_to_pixel(i,grd_height+1)
					piece.move(Global.grd_to_pixel(i,j), .5)
					all_pieces[i][j] = piece

func spawn_deck_pieces_random(deck_to_use):
	if !deck_to_use.is_empty():
		for i in deck_to_use.size():
			var rand_col = floor(randf_range(0,grd_width))
			var rand_row = floor(randf_range(0,grd_height))
			if !deck_to_use.is_empty():
				if !restricted_fill(Vector2(rand_col, rand_row)):
					if all_pieces[rand_col][rand_row] == null:
						var rand = floor(randf_range(0,deck_to_use.size()))
						var piece = deck_to_use[rand].instantiate()
						var loops = 0;
						while match_at(rand_col, rand_row, piece.color) && loops < 100:
							piece.queue_free()
							if loops >= 99:
									return
							rand = floor(randf_range(0,deck_to_use.size()))
							loops += 1 
							piece = deck_to_use[rand].instantiate()
						add_child(piece)
						deck_to_use.pop_at(rand)
						piece.position = Global.grd_to_pixel(rand_col,grd_height+1)
						piece.move(Global.grd_to_pixel(rand_col,rand_row), .5)
						all_pieces[rand_col][rand_row] = piece
			else:
				break

func spawn_deck_pieces_fill(deck_to_use):
	if !deck_to_use.is_empty():
		for i in range(grd_width):
			for j in range(grd_height):
				if !restricted_fill(Vector2(i, j)):
					if !deck_to_use.is_empty():
						if all_pieces[i][j] == null:
							var rand = floor(randf_range(0,deck_to_use.size()))
							var piece = deck_to_use[rand].instantiate()
							var loops = 0;
							while match_at(i, j, piece.color) && loops < 100:
								piece.queue_free()
								if loops >= 99:
									return
								rand = floor(randf_range(0,deck_to_use.size()))
								loops += 1 
								piece = deck_to_use[rand].instantiate()
							add_child(piece)
							deck_to_use.pop_at(rand)
							piece.position = Global.grd_to_pixel(i,grd_height+1)
							piece.move(Global.grd_to_pixel(i,j), .5)
							all_pieces[i][j] = piece

func match_at(col, row, color: String):
	if col > 1:
		if all_pieces[col-1][row] != null and all_pieces[col-2][row] != null:
			if all_pieces[col-1][row].color == color && all_pieces[col-2][row].color == color:
				return true
	if col < grd_width - 2:
		if all_pieces[col+1][row] != null and all_pieces[col+2][row] != null:
			if all_pieces[col+1][row].color == color && all_pieces[col+2][row].color == color:
				return true
	if row > 1:
		if all_pieces[col][row-1] != null and all_pieces[col][row-2] != null:
			if all_pieces[col][row-1].color == color && all_pieces[col][row-2].color == color:
				return true
	if row < grd_height - 2:
		if all_pieces[col][row+1] != null and all_pieces[col][row+2] != null:
			if all_pieces[col][row+1].color == color && all_pieces[col][row+2].color == color:
				return true

func is_in_grd(grid_position):
	if grid_position.x >= 0 and grid_position.x < grd_width:
		if grid_position.y >= 0 and grid_position.y < grd_height:
			return true
	return false

func touch_input():
	if Input.is_action_just_pressed("ui_touch"):
		if is_in_grd(Global.pixel_to_grd(get_global_mouse_position().x, get_global_mouse_position().y)):
			first_touch = Global.pixel_to_grd(get_global_mouse_position().x, get_global_mouse_position().y)
			controling_grd = true
	if Input.is_action_just_released("ui_touch"):
		if is_in_grd(Global.pixel_to_grd(get_global_mouse_position().x, get_global_mouse_position().y)) and controling_grd: 
			controling_grd = false
			final_touch = Global.pixel_to_grd(get_global_mouse_position().x, get_global_mouse_position().y)
			touch_difference(first_touch, final_touch)

func touch_difference(grd_1, grd_2):
	var diff = grd_2 - grd_1
	if abs(diff.x) > abs(diff.y):
		if diff.x > 0:
			swap_pieces(grd_1.x, grd_1.y, Vector2(1, 0))
		elif diff.x < 0:
			swap_pieces(grd_1.x, grd_1.y, Vector2(-1, 0))
	elif abs(diff.x) < abs(diff.y):
		if diff.y > 0:
			swap_pieces(grd_1.x, grd_1.y, Vector2(0, 1))
		elif diff.y < 0:
			swap_pieces(grd_1.x, grd_1.y, Vector2(0, -1))

func swap_pieces(col, row, direction):
	var first_piece = all_pieces[col][row]
	var other_piece = all_pieces[col + direction.x][row + direction.y]
	if !Global.is_null(first_piece) and !Global.is_null(other_piece):
		if !restricted_move(Vector2(col,row)) and !restricted_move(Vector2(col,row) + direction):
			piece_one = first_piece
			piece_two = other_piece
			last_place = Vector2(col, row)
			last_direction = direction
			state = wait
			all_pieces[col][row] = other_piece
			all_pieces[col + direction.x][row + direction.y] = first_piece
			first_piece.move(Global.grd_to_pixel(col + direction.x, row + direction.y))
			other_piece.move(Global.grd_to_pixel(col, row))
			if !move_checked:
				find_matches()

func swap_back():
	if piece_one != null and piece_two != null:
		swap_pieces(last_place.x, last_place.y, last_direction)
		state = move
		move_checked = false
	pass

func find_matches():
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] != null:
				var cur_color = all_pieces[i][j].color
				if i > 0 and i < grd_width - 1:
					if !Global.is_null(all_pieces[i-1][j]) and !Global.is_null(all_pieces[i+1][j]):
						if all_pieces[i-1][j].color == cur_color and all_pieces[i+1][j].color == cur_color:
							all_pieces[i-1][j].mark()
							all_pieces[i][j].mark()
							all_pieces[i+1][j].mark()
				if j > 0 and j < grd_height - 1:
					if !Global.is_null(all_pieces[i][j-1]) and !Global.is_null(all_pieces[i][j+1]):
						if all_pieces[i][j-1].color == cur_color and all_pieces[i][j+1].color == cur_color:
							all_pieces[i][j-1].mark()
							all_pieces[i][j].mark()
							all_pieces[i][j+1].mark()
		get_node("destroy_timer").start()

func mark_for_destruction(space_to_destroy: Array[Vector2]):
	for i in space_to_destroy.size():
		all_pieces[space_to_destroy[i].x][space_to_destroy[i].y].mark(false)
	get_node("destroy_timer").start()

func destroy_matched():
	var was_matched = false
	for i in grd_width:
		for j in grd_height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					damage_specials(i,j)
					if all_pieces[i][j].type == 1:
						deck_on_cd.push_back(all_pieces[i][j])
					if all_pieces[i][j].type == 3:
						for k in Global.cur_char.deck.size():
							if Global.cur_char.deck[k].resource_path == all_pieces[i][j].scene_location:
								Global.cur_char.deck.pop_at(k)
								break
					was_matched = true
					remove_child(all_pieces[i][j])
					all_pieces[i][j] = null
	move_checked = true
	if was_matched:
		get_node("collapse_timer").start()
	else:
		swap_back()

func collapse_col():
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] == null and !restricted_fill(Vector2(i,j)):
				for k in range(j+1, grd_height):
					if all_pieces[i][k] != null:
						all_pieces[i][k].move(Global.grd_to_pixel(i,j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	get_node("refill_timer").start()

func refill_col():
	
	if !deck.is_empty():
		spawn_deck_pieces_fill(deck)
	spawn_fluf_piece(fluf)
	after_refill()

func after_refill():
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] != null:
				if match_at(i,j,all_pieces[i][j].color):
					find_matches()
					return
	Global.cur_char.moves_left -= 1
	cooldown_and_refill_deck()
	state = move
	move_checked = false

func cooldown_and_refill_deck():
	for i in deck_on_cd.size():
		if !Global.is_null(deck_on_cd[i]):
			deck_on_cd[i].lower_cooldown()
			if deck_on_cd[i].cooldown == 0:
				var piece_to_add = load(deck_on_cd[i].scene_location)
				deck.push_back(piece_to_add)
				deck_on_cd[i].queue_free()
	for i in deck_on_cd.size():
		if i >= deck_on_cd.size():
			break
		if Global.is_null(deck_on_cd[i]):
			deck_on_cd.pop_at(i)

#Helper _____________________________________________________
func damage_specials(col, row):
	emit_signal("damage_ice", Vector2(col,row))
	emit_signal("damage_freeze", Vector2(col,row))

#On Signal __________________________________________________
func _on_destroy_timer_timeout() -> void:
	destroy_matched()
func _on_collapse_timer_timeout() -> void:
	collapse_col()
func _on_refill_timer_timeout() -> void:
	refill_col()
func _on_grd_freeze_remove_freeze(place) -> void:
	for i in range(freeze_spaces.size()-1, -1, -1):
		if freeze_spaces[i] == place:
			freeze_spaces.remove_at(i)
func _on_game_window_enemy_attacking() -> void:
	
	pass # Replace with function body.
