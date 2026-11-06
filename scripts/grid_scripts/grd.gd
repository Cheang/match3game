extends Node2D

#state machine
enum {wait, move} 
var state

signal match_resolved(ctx: MatchContext)
signal drag_preview_updated(sim_contexts: Array[MatchContext])
signal drag_preview_cleared
signal action_cycle_finished

#Grid Variables
var grd_x_start: int = Global.grd_x_start
var grd_y_start: int = Global.grd_y_start
var grd_width: int = Global.grd_width
var grd_height: int = Global.grd_height
var grd_offset: int = Global.grd_offset

const CHROMATIC_PIECE_SCENE = preload("res://tiles/tile.tscn")

#the current pieces in the game
var all_pieces = []
var cur_matches = []
var pending_match_contexts: Array[MatchContext] = []
var active_turn_hazards: Array[String] = []

#turn & cascade state tracking
var is_player_swap_phase: bool = false
var _player_move_deducted_this_action: bool = false
var cascade_step: int = 0
var color_match_counts_this_turn: Dictionary = {}
var temp_cascade_momentum_bonus: int = 0
var current_actor: EntityResource = null
var current_target: EntityResource = null
var is_resolving_action: bool = false
var is_aoe_destruction_resolving: bool = false
var aoe_initial_resolved: bool = false
const EnemyAttackOverlayScript = preload("res://scripts/grid_scripts/enemy_attack_overlay.gd")

var planned_enemy_target_center: Vector2i = Vector2i(-1, -1)
var current_enemy_target_cells: Array[Vector2i] = []
var enemy_attack_overlay = null

#obstacles
var empty_spaces: Array[Vector2]
var ice_spaces: Array[Vector2]
var freeze_spaces: Array[Vector2]
var rock_spaces: Array[Vector2]
var flesh_spaces: Array[Vector2]
var damaged_flesh: bool = false
@onready var grd_flesh: Node2D = $grd_flesh
@onready var grd_ice: Node2D = $grd_ice
@onready var grd_freeze: Node2D = $grd_freeze
@onready var grd_rock: Node2D = $grd_rock
@onready var audio_player: AudioStreamPlayer = $audioPlayer
@onready var destroy_timer: Timer = $destroy_timer
@onready var collapse_timer: Timer = $collapse_timer
@onready var refill_timer: Timer = $refill_timer

#obstacles signals
@warning_ignore("unused_signal")
signal damage_ice
@warning_ignore("unused_signal")
signal make_ice
@warning_ignore("unused_signal")
signal damage_freeze
@warning_ignore("unused_signal")
signal make_freeze
@warning_ignore("unused_signal")
signal damage_rock
@warning_ignore("unused_signal")
signal make_rock
@warning_ignore("unused_signal")
signal damage_flesh
@warning_ignore("unused_signal")
signal make_flesh

#slap back
var piece_one = null
var piece_two = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)
var move_checked = false

#touch & drag preview variables
var first_touch = Vector2(0, 0)
var final_touch = Vector2(0, 0)
var controling_grd: bool = false
var current_drag_target = Vector2(-1, -1)
var previewed_cells: Array[Vector2] = []

var enemy_attacked: bool = false

func on_startup() -> void:
	grd_x_start = Global.grd_x_start
	grd_y_start = Global.grd_y_start
	grd_width = Global.grd_width
	grd_height = Global.grd_height
	grd_offset = Global.grd_offset

	if Global.cur_char != null:
		Global.cur_char.ensure_loadout_tracks()
	if Global.cur_enemy != null:
		get_obstacles(Global.cur_enemy)

	all_pieces = Global.make_2d_array(grd_width, grd_height)
	await get_tree().create_timer(0.4).timeout
	spawn_color_tiles()
	spawn_obstacles(ice_spaces, "make_ice")
	spawn_obstacles(freeze_spaces, "make_freeze")
	spawn_obstacles(rock_spaces, "make_rock")
	spawn_obstacles(flesh_spaces, "make_flesh")
	state = move
	update_enemy_target_preview()

func _process(_delta: float) -> void:
	if state == move:
		touch_input()

func get_active_color_pool() -> Array[int]:
	if Global.cur_char != null and not Global.cur_char.active_color_pool.is_empty():
		return Global.cur_char.active_color_pool
	return [100, 200, 300, 500]

func is_exotic_color(color_id: int) -> bool:
	return Global.is_exotic_color(color_id)

func get_base_family(color_id: int) -> int:
	return Global.get_base_family(color_id)

func can_tiles_match(tile_a: PieceClass, tile_b: PieceClass, is_manual_swap: bool) -> bool:
	if tile_a == null or tile_b == null:
		return false
	if tile_a.color_id == tile_b.color_id:
		return true
	if is_manual_swap and get_base_family(tile_a.color_id) == get_base_family(tile_b.color_id):
		return true
	return false

func can_color_ids_match(color_a: int, color_b: int, is_manual_swap: bool) -> bool:
	if color_a == color_b:
		return true
	if is_manual_swap and get_base_family(color_a) == get_base_family(color_b):
		return true
	return false

func restricted_fill(place: Vector2) -> bool:
	return empty_spaces.has(place) or rock_spaces.has(place) or flesh_spaces.has(place)

func restricted_move(place: Vector2) -> bool:
	return freeze_spaces.has(place)

func spawn_obstacles(ob_spaces, signal_str: String):
	for i in ob_spaces.size():
		emit_signal(signal_str, ob_spaces[i])

func spawn_color_tiles() -> void:
	var pool: Array[int] = get_active_color_pool()
	if pool.is_empty():
		return
	for i in range(grd_width):
		for j in range(grd_height):
			if !restricted_fill(Vector2(i, j)) and all_pieces[i][j] == null:
				var valid_colors: Array[int] = []
				for c_id in pool:
					if not match_at_color_id(i, j, c_id, false):
						valid_colors.append(c_id)
				var chosen_color: int = valid_colors.pick_random() if not valid_colors.is_empty() else pool.pick_random()
				var piece: PieceClass = CHROMATIC_PIECE_SCENE.instantiate()
				piece.color_id = chosen_color
				piece.id = chosen_color
				add_child(piece)
				piece.setup_chromatic(chosen_color)
				piece.position = Global.grd_to_pixel(i, grd_height + 1)
				piece.move(Global.grd_to_pixel(i, j), 0.35)
				all_pieces[i][j] = piece

# Transforms a random non-exotic tile in the visual bottom 3 rows (internal row 0, 1, 2)
# into an exotic variation or special buff tile (Anti-top-camping rule 5.1.3).
func transform_bottom_tile_to_exotic(exotic_color_id: int) -> bool:
	var candidates: Array[Vector2i] = []
	for col in range(grd_width):
		for internal_row in range(min(3, grd_height)): # internal rows 0..2 are visual bottom 3 rows
			var p: PieceClass = all_pieces[col][internal_row]
			if p != null and not is_exotic_color(p.color_id):
				if get_base_family(p.color_id) == get_base_family(exotic_color_id):
					candidates.append(Vector2i(col, internal_row))
	if candidates.is_empty():
		for col in range(grd_width):
			for internal_row in range(min(3, grd_height)):
				var p: PieceClass = all_pieces[col][internal_row]
				if p != null and not is_exotic_color(p.color_id):
					candidates.append(Vector2i(col, internal_row))
	if candidates.is_empty():
		return false
	var pick: Vector2i = candidates.pick_random()
	var target_piece: PieceClass = all_pieces[pick.x][pick.y]
	target_piece.setup_chromatic(exotic_color_id)
	return true

func match_at_color_id(col: int, row: int, c_id: int, manual_swap: bool = false) -> bool:
	if col > 1:
		if all_pieces[col-1][row] != null and all_pieces[col-2][row] != null:
			if can_color_ids_match(all_pieces[col-1][row].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col-2][row].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col-1][row].color_id, all_pieces[col-2][row].color_id, manual_swap):
				return true
	if col < grd_width - 2:
		if all_pieces[col+1][row] != null and all_pieces[col+2][row] != null:
			if can_color_ids_match(all_pieces[col+1][row].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col+2][row].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col+1][row].color_id, all_pieces[col+2][row].color_id, manual_swap):
				return true
	if col > 0 and col < grd_width - 1:
		if all_pieces[col-1][row] != null and all_pieces[col+1][row] != null:
			if can_color_ids_match(all_pieces[col-1][row].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col+1][row].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col-1][row].color_id, all_pieces[col+1][row].color_id, manual_swap):
				return true
	if row > 1:
		if all_pieces[col][row-1] != null and all_pieces[col][row-2] != null:
			if can_color_ids_match(all_pieces[col][row-1].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col][row-2].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col][row-1].color_id, all_pieces[col][row-2].color_id, manual_swap):
				return true
	if row < grd_height - 2:
		if all_pieces[col][row+1] != null and all_pieces[col][row+2] != null:
			if can_color_ids_match(all_pieces[col][row+1].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col][row+2].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col][row+1].color_id, all_pieces[col][row+2].color_id, manual_swap):
				return true
	if row > 0 and row < grd_height - 1:
		if all_pieces[col][row-1] != null and all_pieces[col][row+1] != null:
			if can_color_ids_match(all_pieces[col][row-1].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col][row+1].color_id, c_id, manual_swap) and can_color_ids_match(all_pieces[col][row-1].color_id, all_pieces[col][row+1].color_id, manual_swap):
				return true
	return false

func is_in_grd(grid_position) -> bool:
	if grid_position.x >= 0 and grid_position.x < grd_width:
		if grid_position.y >= 0 and grid_position.y < grd_height:
			return true
	return false

func touch_input():
	if state != move:
		if controling_grd:
			clear_drag_preview()
		controling_grd = false
		return
	if InventoryOverlay.is_overlay_open():
		if controling_grd:
			clear_drag_preview()
		controling_grd = false
		return
	if Global.cur_char != null and Global.cur_char.moves_left <= 0:
		if controling_grd:
			clear_drag_preview()
		controling_grd = false
		state = wait
		return
	if not Global.game_is_played:
		if controling_grd:
			clear_drag_preview()
		controling_grd = false
		state = wait
		return

	if Input.is_action_just_pressed("ui_touch"):
		var mouse_pos: Vector2 = get_local_mouse_position()
		var mouse_grd = Global.pixel_to_grd(mouse_pos.x, mouse_pos.y)
		if is_in_grd(mouse_grd):
			first_touch = mouse_grd
			current_drag_target = mouse_grd
			controling_grd = true

	elif controling_grd and Input.is_action_pressed("ui_touch"):
		var hover_pos: Vector2 = get_local_mouse_position()
		var hover_grd = Global.pixel_to_grd(hover_pos.x, hover_pos.y)
		hover_grd = Vector2(clamp(hover_grd.x, 0, grd_width - 1), clamp(hover_grd.y, 0, grd_height - 1))
		var target_cell = _get_adjacent_drag_target(first_touch, hover_grd)
		if target_cell != current_drag_target:
			current_drag_target = target_cell
			if current_drag_target == first_touch:
				clear_drag_preview()
			else:
				update_drag_preview(first_touch, current_drag_target - first_touch)

	elif Input.is_action_just_released("ui_touch"):
		if controling_grd:
			controling_grd = false
			var release_pos: Vector2 = get_local_mouse_position()
			final_touch = Global.pixel_to_grd(release_pos.x, release_pos.y)
			final_touch = Vector2(clamp(final_touch.x, 0, grd_width - 1), clamp(final_touch.y, 0, grd_height - 1))
			var target_cell = _get_adjacent_drag_target(first_touch, final_touch)
			clear_drag_preview()
			if target_cell != first_touch:
				touch_difference(first_touch, target_cell)

func _get_adjacent_drag_target(origin: Vector2, current: Vector2) -> Vector2:
	var diff = current - origin
	if diff.length_squared() < 0.25:
		return origin
	var dir := Vector2.ZERO
	if abs(diff.x) >= abs(diff.y):
		dir = Vector2(sign(diff.x), 0)
	else:
		dir = Vector2(0, sign(diff.y))
	var candidate = origin + dir
	if is_in_grd(candidate):
		return candidate
	return origin

func update_drag_preview(origin: Vector2, direction: Vector2) -> void:
	clear_drag_preview(false)
	var col1 := int(origin.x)
	var row1 := int(origin.y)
	var col2 := int(origin.x + direction.x)
	var row2 := int(origin.y + direction.y)
	if not is_in_grd(Vector2(col1, row1)) or not is_in_grd(Vector2(col2, row2)):
		drag_preview_cleared.emit()
		return
	if restricted_move(Vector2(col1, row1)) or restricted_move(Vector2(col2, row2)):
		drag_preview_cleared.emit()
		return
	var p1: PieceClass = all_pieces[col1][row1]
	var p2: PieceClass = all_pieces[col2][row2]
	if p1 == null or p2 == null:
		drag_preview_cleared.emit()
		return

	# Temporarily swap in array to simulate manual swap match contexts
	all_pieces[col1][row1] = p2
	all_pieces[col2][row2] = p1
	var sim_contexts: Array[MatchContext] = _evaluate_board_matches(true, true)
	# Restore array immediately
	all_pieces[col1][row1] = p1
	all_pieces[col2][row2] = p2

	for ctx in sim_contexts:
		for pos in ctx.matched_positions:
			var tile: PieceClass = all_pieces[int(pos.x)][int(pos.y)]
			if tile != null:
				tile.set_preview_highlight(true)
			previewed_cells.append(pos)

	if not sim_contexts.is_empty():
		p1.set_preview_highlight(true)
		p2.set_preview_highlight(true)
		var pos1 := Vector2(col1, row1)
		var pos2 := Vector2(col2, row2)
		if not previewed_cells.has(pos1):
			previewed_cells.append(pos1)
		if not previewed_cells.has(pos2):
			previewed_cells.append(pos2)
	drag_preview_updated.emit(sim_contexts)

func clear_drag_preview(emit_clear_signal: bool = true) -> void:
	for pos in previewed_cells:
		var cx := int(pos.x)
		var cy := int(pos.y)
		if cx >= 0 and cx < grd_width and cy >= 0 and cy < grd_height and all_pieces[cx][cy] != null:
			all_pieces[cx][cy].set_preview_highlight(false)
	previewed_cells.clear()
	current_drag_target = Vector2(-1, -1)
	if emit_clear_signal:
		drag_preview_cleared.emit()

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
	var target_col = int(col + direction.x)
	var target_row = int(row + direction.y)
	if not is_in_grd(Vector2(col, row)) or not is_in_grd(Vector2(target_col, target_row)):
		return
	var first_piece = all_pieces[col][row]
	var other_piece = all_pieces[target_col][target_row]
	if !Global.is_null(first_piece) and !Global.is_null(other_piece):
		if !restricted_move(Vector2(col,row)) and !restricted_move(Vector2(target_col, target_row)):
			piece_one = first_piece
			piece_two = other_piece
			last_place = Vector2(col, row)
			last_direction = direction
			state = wait
			all_pieces[col][row] = other_piece
			all_pieces[target_col][target_row] = first_piece
			first_piece.move(Global.grd_to_pixel(target_col, target_row), 0.2)
			other_piece.move(Global.grd_to_pixel(col, row), 0.2)
			if !move_checked:
				if not enemy_attacked:
					current_actor = Global.cur_char
					current_target = Global.cur_enemy
				is_resolving_action = true
				is_player_swap_phase = true
				_player_move_deducted_this_action = false
				cascade_step = 0
				color_match_counts_this_turn.clear()
				temp_cascade_momentum_bonus = 0
				reset_all_fall_distances()
				find_matches()

func swap_back():
	if piece_one != null and piece_two != null:
		is_player_swap_phase = false
		_player_move_deducted_this_action = false
		swap_pieces(last_place.x, last_place.y, last_direction)
		state = move
		move_checked = false

func reset_all_fall_distances() -> void:
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] != null:
				all_pieces[i][j].fall_distance = 0

func _evaluate_board_matches(manual_swap: bool, simulation_only: bool = false) -> Array[MatchContext]:
	var h_runs: Array = [] # Array of Array[Vector2i]
	var v_runs: Array = [] # Array of Array[Vector2i]

	# Horizontal runs of 3+
	for j in range(grd_height):
		var i: int = 0
		while i < grd_width:
			var start_p: PieceClass = all_pieces[i][j]
			if start_p == null:
				i += 1
				continue
			var run: Array[Vector2i] = [Vector2i(i, j)]
			var k: int = i + 1
			while k < grd_width:
				var next_p: PieceClass = all_pieces[k][j]
				if next_p != null and can_tiles_match(start_p, next_p, manual_swap) and can_tiles_match(all_pieces[k - 1][j], next_p, manual_swap):
					run.append(Vector2i(k, j))
					k += 1
				else:
					break
			if run.size() >= 3:
				h_runs.append(run)
			i = k

	# Vertical runs of 3+
	for i in range(grd_width):
		var j: int = 0
		while j < grd_height:
			var start_p: PieceClass = all_pieces[i][j]
			if start_p == null:
				j += 1
				continue
			var run: Array[Vector2i] = [Vector2i(i, j)]
			var k: int = j + 1
			while k < grd_height:
				var next_p: PieceClass = all_pieces[i][k]
				if next_p != null and can_tiles_match(start_p, next_p, manual_swap) and can_tiles_match(all_pieces[i][k - 1], next_p, manual_swap):
					run.append(Vector2i(i, k))
					k += 1
				else:
					break
			if run.size() >= 3:
				v_runs.append(run)
			j = k

	# Merge overlapping/intersecting runs of compatible family into connected match groups
	var all_runs: Array = []
	for r in h_runs:
		all_runs.append({"cells": r, "dir": "H"})
	for r in v_runs:
		all_runs.append({"cells": r, "dir": "V"})

	var visited_runs: Array[bool] = []
	visited_runs.resize(all_runs.size())
	visited_runs.fill(false)

	var contexts: Array[MatchContext] = []
	var sim_color_counts: Dictionary = color_match_counts_this_turn.duplicate()

	for idx in range(all_runs.size()):
		if visited_runs[idx]:
			continue
		visited_runs[idx] = true
		var group_runs: Array = [all_runs[idx]]
		var group_cells_dict: Dictionary = {}
		for c in all_runs[idx]["cells"]:
			group_cells_dict[c] = true

		var first_cell: Vector2i = all_runs[idx]["cells"][0]
		var first_piece: PieceClass = all_pieces[first_cell.x][first_cell.y]
		var group_base_color: int = get_base_family(first_piece.color_id)

		var changed: bool = true
		while changed:
			changed = false
			for other_idx in range(all_runs.size()):
				if visited_runs[other_idx]:
					continue
				var other_run = all_runs[other_idx]
				var other_first: Vector2i = other_run["cells"][0]
				var other_piece: PieceClass = all_pieces[other_first.x][other_first.y]
				if get_base_family(other_piece.color_id) != group_base_color:
					continue
				if not manual_swap and other_piece.color_id != first_piece.color_id:
					continue
				var intersects: bool = false
				for c in other_run["cells"]:
					if group_cells_dict.has(c):
						intersects = true
						break
				if intersects:
					visited_runs[other_idx] = true
					group_runs.append(other_run)
					for c in other_run["cells"]:
						group_cells_dict[c] = true
					changed = true

		# Build MatchContext for this connected match group
		var ctx := MatchContext.new()
		ctx.actor = current_actor if current_actor != null else Global.cur_char
		ctx.target = current_target if current_target != null else Global.cur_enemy
		ctx.base_color = group_base_color
		ctx.is_manual_swap = manual_swap
		ctx.cascade_step = 0 if manual_swap else cascade_step

		var has_h: bool = false
		var has_v: bool = false
		var max_line_len: int = 0
		for gr in group_runs:
			if gr["dir"] == "H":
				has_h = true
			else:
				has_v = true
			if gr["cells"].size() > max_line_len:
				max_line_len = gr["cells"].size()

		var unique_cells: Array = group_cells_dict.keys()
		ctx.match_count = unique_cells.size()

		if has_h and has_v:
			# Distinguish L_SHAPE vs T_SHAPE by checking if intersection is a corner of both runs
			var is_l_corner: bool = false
			for h_r in group_runs:
				if h_r["dir"] != "H": continue
				for v_r in group_runs:
					if v_r["dir"] != "V": continue
					var h_ends = [h_r["cells"][0], h_r["cells"][h_r["cells"].size() - 1]]
					var v_ends = [v_r["cells"][0], v_r["cells"][v_r["cells"].size() - 1]]
					for he in h_ends:
						if he in v_ends:
							is_l_corner = true
							break
			ctx.shape_type = "L_SHAPE" if is_l_corner else "T_SHAPE"
		else:
			if max_line_len >= 5:
				ctx.shape_type = "LINE_5"
			elif max_line_len == 4:
				ctx.shape_type = "LINE_4"
			else:
				ctx.shape_type = "LINE_3"

		var base_tile_count: int = 0
		var exotic_tile_count: int = 0
		var detected_exotic_id: int = group_base_color
		var max_spec_row: int = 0
		var sum_momentum: int = temp_cascade_momentum_bonus

		for c in unique_cells:
			var pos := Vector2(c.x, c.y)
			ctx.matched_positions.append(pos)
			var p: PieceClass = all_pieces[c.x][c.y]
			if p != null:
				if is_exotic_color(p.color_id):
					exotic_tile_count += 1
					detected_exotic_id = p.color_id
				else:
					base_tile_count += 1
				sum_momentum += p.fall_distance
				if p.is_gold:
					ctx.gold_count += 1
			var spec_r: int = Global.to_spec_row(c.y)
			if spec_r > max_spec_row:
				max_spec_row = spec_r
			# Check adjacent/overlapping hazards for simulation or resolution
			_collect_adjacent_hazards_for_cell(c.x, c.y, ctx.hazards_cleared)

		ctx.exotic_count = exotic_tile_count
		ctx.is_exotic_blend = manual_swap and exotic_tile_count > 0 and base_tile_count > 0
		ctx.primary_color = detected_exotic_id if (exotic_tile_count > 0 and base_tile_count == 0) else group_base_color
		ctx.lowest_row = max_spec_row
		ctx.total_fall_momentum = sum_momentum

		var prev_count: int = sim_color_counts.get(group_base_color, 0) + 1
		sim_color_counts[group_base_color] = prev_count
		ctx.match_index_for_color_this_turn = prev_count

		if not simulation_only:
			color_match_counts_this_turn[group_base_color] = prev_count

		contexts.append(ctx)

	return contexts

func _collect_adjacent_hazards_for_cell(col: int, row: int, out_hazards: Array[String]) -> void:
	var cell := Vector2(col, row)
	if ice_spaces.has(cell) or (grd_ice != null and grd_ice.ice_pieces.size() > col and grd_ice.ice_pieces[col][row] != null):
		if not out_hazards.has("ice"):
			out_hazards.append("ice")
	if freeze_spaces.has(cell):
		if not out_hazards.has("freeze"):
			out_hazards.append("freeze")
	var neighbors := [
		Vector2(col + 1, row),
		Vector2(col - 1, row),
		Vector2(col, row + 1),
		Vector2(col, row - 1)
	]
	for n in neighbors:
		if freeze_spaces.has(n) and not out_hazards.has("freeze"):
			out_hazards.append("freeze")
		if rock_spaces.has(n) and not out_hazards.has("rock"):
			out_hazards.append("rock")
		if flesh_spaces.has(n) and not out_hazards.has("flesh"):
			out_hazards.append("flesh")

func find_matches():
	pending_match_contexts = _evaluate_board_matches(is_player_swap_phase, false)
	for ctx in pending_match_contexts:
		for pos in ctx.matched_positions:
			var p: PieceClass = all_pieces[int(pos.x)][int(pos.y)]
			if p != null:
				p.mark(false)
			add_to_array(pos, cur_matches)

	get_bombed_pieces()
	_update_timer_pacing()
	destroy_timer.start()

func _update_timer_pacing() -> void:
	# Section 7.3: Scale cascade step delay timers downwards (0.18s -> 0.14s -> 0.10s)
	var delay: float = 0.18
	if cascade_step == 1:
		delay = 0.14
	elif cascade_step >= 2:
		delay = 0.10
	destroy_timer.wait_time = delay
	collapse_timer.wait_time = delay * 0.75
	refill_timer.wait_time = delay * 0.75

func get_bombed_pieces():
	var bomb_blast_dict: Dictionary = {}
	for i in grd_width:
		for j in grd_height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					if all_pieces[i][j].is_col_bomb:
						for r in range(grd_height):
							bomb_blast_dict[Vector2(i, r)] = true
						match_all_in_col(i)
					elif all_pieces[i][j].is_row_bomb:
						for c in range(grd_width):
							bomb_blast_dict[Vector2(c, j)] = true
						match_all_in_row(j)
					elif all_pieces[i][j].is_adj_bomb:
						for dx in range(-1, 2):
							for dy in range(-1, 2):
								var bpos := Vector2(i + dx, j + dy)
								if is_in_grd(bpos):
									bomb_blast_dict[bpos] = true
						match_all_adj(i, j)
	if not bomb_blast_dict.is_empty():
		var blast_positions: Array[Vector2] = []
		for k in bomb_blast_dict.keys():
			blast_positions.append(k)
		var bomb_ctx: MatchContext = build_majority_color_context(blast_positions, current_actor, current_target, true)
		if bomb_ctx != null:
			pending_match_contexts.append(bomb_ctx)

## Counts destroyed tile colors across `positions`, picks the majority color,
## and builds a MatchContext where match_count = majority color count
## (so trigger budget = max(1, count - 2), matching Beast monster and Bomb rules).
func build_majority_color_context(
	positions: Array[Vector2],
	actor_override: EntityResource = null,
	target_override: EntityResource = null,
	is_bomb: bool = false
) -> MatchContext:
	var color_counts: Dictionary = {}
	var color_order: Array[int] = []
	var valid_positions: Array[Vector2] = []
	var gold_tiles: int = 0
	var exotic_tiles: int = 0
	var max_spec_row: int = 0
	var sum_momentum: int = temp_cascade_momentum_bonus
	var hazards: Array[String] = []

	for pos in positions:
		if not is_in_grd(pos):
			continue
		var col := int(pos.x)
		var row := int(pos.y)
		var p: PieceClass = all_pieces[col][row]
		if p == null:
			continue
		valid_positions.append(pos)
		var base_c: int = get_base_family(p.color_id)
		if not color_counts.has(base_c):
			color_counts[base_c] = 0
			color_order.append(base_c)
		color_counts[base_c] = int(color_counts[base_c]) + 1
		if is_exotic_color(p.color_id):
			exotic_tiles += 1
		if p.is_gold:
			gold_tiles += 1
		sum_momentum += p.fall_distance
		var spec_r: int = Global.to_spec_row(row)
		if spec_r > max_spec_row:
			max_spec_row = spec_r
		_collect_adjacent_hazards_for_cell(col, row, hazards)

	if color_order.is_empty():
		return null

	var majority_color: int = color_order[0]
	var majority_count: int = int(color_counts[majority_color])
	for c in color_order:
		var cnt: int = int(color_counts[c])
		if cnt > majority_count:
			majority_count = cnt
			majority_color = c

	var ctx := MatchContext.new()
	ctx.actor = actor_override if actor_override != null else (current_actor if current_actor != null else Global.cur_char)
	ctx.target = target_override if target_override != null else (current_target if current_target != null else Global.cur_enemy)
	ctx.base_color = majority_color
	ctx.primary_color = majority_color
	ctx.match_count = majority_count
	ctx.shape_type = "BOMB" if is_bomb else "BEAST"
	ctx.is_bomb_clear = is_bomb
	ctx.is_manual_swap = false
	ctx.cascade_step = cascade_step
	ctx.matched_positions = valid_positions
	ctx.gold_count = gold_tiles
	ctx.exotic_count = exotic_tiles
	ctx.lowest_row = max_spec_row
	ctx.total_fall_momentum = sum_momentum
	ctx.hazards_cleared = hazards
	var prev_count: int = int(color_match_counts_this_turn.get(majority_color, 0)) + 1
	color_match_counts_this_turn[majority_color] = prev_count
	ctx.match_index_for_color_this_turn = prev_count
	return ctx

func mark_for_destruction(space_to_destroy: Array[Vector2], activate_piece = false):
	is_aoe_destruction_resolving = true
	aoe_initial_resolved = false
	enemy_attacked = true
	is_resolving_action = true
	current_actor = Global.cur_enemy
	current_target = Global.cur_char
	var ctx: MatchContext = build_majority_color_context(space_to_destroy, current_actor, current_target, false)
	if ctx != null:
		pending_match_contexts.append(ctx)
	for i in space_to_destroy.size():
		var pos: Vector2 = space_to_destroy[i]
		if is_in_grd(pos) and all_pieces[pos.x][pos.y] != null:
			all_pieces[pos.x][pos.y].mark(activate_piece)
	destroy_timer.start()

func find_bombs():
	var acting_entity: EntityResource = current_actor if current_actor != null else Global.cur_char
	if acting_entity != null and not (acting_entity is PlayerResource):
		return
	for ctx in pending_match_contexts:
		var color_str: String = Global.get_color_name(ctx.base_color).to_lower()
		if ctx.shape_type == "LINE_5":
			return
		elif ctx.shape_type in ["L_SHAPE", "T_SHAPE"] and Global.cur_char != null and Global.cur_char.flg_can_spawn_adj_bombs:
			make_bomb(0, color_str)
			return
		elif ctx.shape_type == "LINE_4" and Global.cur_char != null:
			if Global.cur_char.flg_can_spawn_row_bombs:
				make_bomb(1, color_str)
				return
			elif Global.cur_char.flg_can_spawn_col_bombs:
				make_bomb(2, color_str)
				return

func destroy_matched(should_collapse: bool = true):
	find_bombs()
	var was_matched = false
	active_turn_hazards.clear()
	var acting_entity: EntityResource = current_actor if current_actor != null else Global.cur_char

	for i in grd_width:
		for j in grd_height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					if all_pieces[i][j].is_gold and Global.cur_char != null and (acting_entity == null or acting_entity is PlayerResource):
						Global.cur_char.modify_stat("gold", 1)
					damage_specials(i, j)
					was_matched = true
					var p: PieceClass = all_pieces[i][j]
					all_pieces[i][j] = null
					remove_child(p)
					p.queue_free()

	if was_matched:
		var was_enemy_turn: bool = enemy_attacked or (current_actor is EnemyResource)
		if not was_enemy_turn and is_player_swap_phase and not _player_move_deducted_this_action and Global.cur_char != null:
			_player_move_deducted_this_action = true
			Global.cur_char.modify_stat("moves_left", -1)
		audio_player.play_on_destruction(cascade_step)
		for ctx in pending_match_contexts:
			for h in active_turn_hazards:
				if not ctx.hazards_cleared.has(h):
					ctx.hazards_cleared.append(h)
			if ctx.hazards_cleared.has("ice"):
				temp_cascade_momentum_bonus += 1
			if is_aoe_destruction_resolving and aoe_initial_resolved and ctx.actor is EnemyResource:
				# Secondary cascade from monster AOE destruction:
				# Monsters benefit only from their first tiles destroyed.
				ctx.is_secondary_cascade = true
				ctx.ignore_equipment_triggers = true
				continue
			match_resolved.emit(ctx)
		if is_aoe_destruction_resolving:
			aoe_initial_resolved = true
		pending_match_contexts.clear()

	move_checked = true
	if was_matched and should_collapse:
		# Clear manual swap flag as soon as collapse begins (Section 3.2)
		is_player_swap_phase = false
		cascade_step += 1
		collapse_timer.start()
	else:
		swap_back()
		is_resolving_action = false
		is_aoe_destruction_resolving = false
		aoe_initial_resolved = false
		action_cycle_finished.emit()
	cur_matches.clear()

func collapse_col():
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] == null and !restricted_fill(Vector2(i,j)):
				for k in range(j+1, grd_height):
					if all_pieces[i][k] != null:
						var drop_dist: int = k - j
						all_pieces[i][k].fall_distance += drop_dist
						all_pieces[i][k].move(Global.grd_to_pixel(i,j), 0.22)
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	# Overlap collapse & refill pacing (Section 7.3)
	refill_timer.start()

func refill_col():
	spawn_color_tiles()
	after_refill()

func after_refill():
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] != null:
				if match_at_color_id(i, j, all_pieces[i][j].color_id, false):
					find_matches()
					return

	# Turn resolution complete: reset fall_distance on all board pieces
	reset_all_fall_distances()
	is_player_swap_phase = false
	cascade_step = 0
	temp_cascade_momentum_bonus = 0
	is_aoe_destruction_resolving = false
	aoe_initial_resolved = false

	var was_enemy_turn: bool = enemy_attacked or (current_actor is EnemyResource)
	if not was_enemy_turn and not _player_move_deducted_this_action:
		if Global.cur_char != null:
			Global.cur_char.modify_stat("moves_left", -1)
	_player_move_deducted_this_action = false
	enemy_attacked = false
	if not was_enemy_turn and !damaged_flesh:
		await generate_flesh()
	if Global.cur_char != null:
		if flesh_spaces.size() >= 5:
			Global.cur_char.modify_stat("flg_flesh_coruption", true, false)
		else:
			Global.cur_char.modify_stat("flg_flesh_coruption", false, false)
	move_checked = false
	damaged_flesh = false
	is_resolving_action = false
	if was_enemy_turn:
		state = wait
	elif Global.cur_char != null and Global.cur_char.moves_left <= 0:
		state = wait
	elif not Global.game_is_played:
		state = wait
	else:
		state = move
		update_enemy_target_preview()
	action_cycle_finished.emit()
	current_actor = null
	current_target = null

#==============================================================================#
# MONSTER BOARD AI HELPERS
#==============================================================================#

## Returns all legal adjacent swaps on the current board that produce at least one match.
## Each entry is {"origin": Vector2, "direction": Vector2, "contexts": Array[MatchContext]}.
func find_all_valid_swaps() -> Array[Dictionary]:
	var valid_swaps: Array[Dictionary] = []
	var dirs := [Vector2(1, 0), Vector2(0, 1)]
	for col in range(grd_width):
		for row in range(grd_height):
			var p1: PieceClass = all_pieces[col][row]
			if p1 == null or restricted_move(Vector2(col, row)):
				continue
			for dir in dirs:
				var col2 := int(col + dir.x)
				var row2 := int(row + dir.y)
				if not is_in_grd(Vector2(col2, row2)):
					continue
				if restricted_move(Vector2(col2, row2)):
					continue
				var p2: PieceClass = all_pieces[col2][row2]
				if p2 == null:
					continue
				all_pieces[col][row] = p2
				all_pieces[col2][row2] = p1
				var has_local_match: bool = match_at_color_id(col, row, p2.color_id, true) or match_at_color_id(col2, row2, p1.color_id, true)
				var sim_contexts: Array[MatchContext] = []
				if has_local_match:
					sim_contexts = _evaluate_board_matches(true, true)
				all_pieces[col][row] = p1
				all_pieces[col2][row2] = p2
				if not sim_contexts.is_empty():
					valid_swaps.append({
						"origin": Vector2(col, row),
						"direction": dir,
						"contexts": sim_contexts
					})
	return valid_swaps

## Chooses a legal swap for a SMART monster, preferring swaps that match an explicit track
## color or maximize trigger budget.
func choose_smart_monster_swap(monster: EnemyResource) -> Dictionary:
	var swaps: Array[Dictionary] = find_all_valid_swaps()
	if swaps.is_empty():
		return {}
	swaps.shuffle()
	var best_swap: Dictionary = swaps[0]
	var best_score: int = -1
	for s in swaps:
		var score: int = 0
		var ctxs: Array = s["contexts"]
		for ctx in ctxs:
			var c_ctx: MatchContext = ctx
			var track: ColorLoadoutTrack = monster.get_track_for_color(c_ctx.base_color) if monster != null else null
			var budget: int = track.get_trigger_budget(c_ctx) if track != null else maxi(1, c_ctx.match_count - 2)
			score += budget * 10
			if monster != null and monster.has_explicit_track_for_color(c_ctx.base_color):
				score += 5
		if score > best_score:
			best_score = score
			best_swap = s
	return best_swap

## Executes a board swap on behalf of `actor` against `target` without consuming player moves.
func execute_external_swap(origin: Vector2, direction: Vector2, actor: EntityResource, target: EntityResource) -> void:
	current_actor = actor
	current_target = target
	enemy_attacked = actor is EnemyResource
	is_resolving_action = true
	move_checked = false
	swap_pieces(int(origin.x), int(origin.y), direction)

## Picks a valid target center for BEAST area destruction, guaranteeing the shape stays strictly within grid boundaries.
func choose_beast_target_center(shape_offsets: Array[Vector2i]) -> Vector2i:
	var perfect_candidates: Array[Vector2i] = []
	var partial_candidates: Array[Dictionary] = []

	for col in range(grd_width):
		for row in range(grd_height):
			# Entire shape MUST stay strictly within grid boundaries
			var fits_in_grid: bool = true
			for ofs in shape_offsets:
				var p := Vector2(col + ofs.x, row + ofs.y)
				if not is_in_grd(p):
					fits_in_grid = false
					break
			if not fits_in_grid:
				continue

			# Count how many playable pieces are under the shape
			var valid_tiles: int = 0
			for ofs in shape_offsets:
				var px: int = col + ofs.x
				var py: int = row + ofs.y
				if all_pieces[px][py] != null and not restricted_move(Vector2(px, py)):
					valid_tiles += 1

			if valid_tiles == shape_offsets.size():
				perfect_candidates.append(Vector2i(col, row))
			elif valid_tiles > 0:
				partial_candidates.append({"center": Vector2i(col, row), "count": valid_tiles})

	if not perfect_candidates.is_empty():
		return perfect_candidates.pick_random()

	if not partial_candidates.is_empty():
		partial_candidates.sort_custom(func(a, b): return a["count"] > b["count"])
		var best_count: int = partial_candidates[0]["count"]
		var best_candidates: Array[Vector2i] = []
		for entry in partial_candidates:
			if entry["count"] == best_count:
				best_candidates.append(entry["center"])
			else:
				break
		return best_candidates.pick_random()

	return Vector2i(grd_width >> 1, grd_height >> 1)

## Validates whether a given center coordinate can still serve as a Beast destruction center.
func is_valid_beast_center(center: Vector2i, shape_offsets: Array[Vector2i]) -> bool:
	if center.x < 0 or center.x >= grd_width or center.y < 0 or center.y >= grd_height:
		return false
	# All offsets MUST be strictly within grid bounds
	for ofs in shape_offsets:
		var p := Vector2(center.x + ofs.x, center.y + ofs.y)
		if not is_in_grd(p):
			return false
	var valid_tiles: int = 0
	for ofs in shape_offsets:
		var px: int = center.x + ofs.x
		var py: int = center.y + ofs.y
		if all_pieces[px][py] != null and not restricted_move(Vector2(px, py)):
			valid_tiles += 1
	return valid_tiles >= min(3, shape_offsets.size())

## Returns the planned center if still valid, or picks a new center.
func get_or_choose_beast_target_center(shape_offsets: Array[Vector2i]) -> Vector2i:
	if is_valid_beast_center(planned_enemy_target_center, shape_offsets):
		return planned_enemy_target_center
	planned_enemy_target_center = choose_beast_target_center(shape_offsets)
	return planned_enemy_target_center

## Returns grid coordinates of tiles targeted by the enemy's upcoming action.
func get_planned_enemy_target_cells() -> Array[Vector2i]:
	if Global.cur_enemy == null or not Global.game_is_played:
		return []
	var mode: EnemyResource.BehaviorCategory = Global.cur_enemy.get_current_action_behavior()
	var cells: Array[Vector2i] = []
	if mode == EnemyResource.BehaviorCategory.SMART:
		var chosen_swap: Dictionary = choose_smart_monster_swap(Global.cur_enemy)
		if not chosen_swap.is_empty():
			var orig: Vector2 = chosen_swap["origin"]
			var dir: Vector2 = chosen_swap["direction"]
			cells.append(Vector2i(int(orig.x), int(orig.y)))
			cells.append(Vector2i(int(orig.x + dir.x), int(orig.y + dir.y)))
			return cells
	# BEAST or fallback
	var offsets: Array[Vector2i] = Global.cur_enemy.get_beast_destruction_shape()
	var center: Vector2i = get_or_choose_beast_target_center(offsets)
	for ofs in offsets:
		var p := Vector2i(center.x + ofs.x, center.y + ofs.y)
		if is_in_grd(Vector2(p.x, p.y)):
			cells.append(p)
	return cells

## Updates the enemy upcoming attack visual indicator on board tiles.
func update_enemy_target_preview() -> void:
	if Global.cur_enemy == null or not Global.game_is_played:
		clear_enemy_target_preview()
		return
	var target_cells: Array[Vector2i] = get_planned_enemy_target_cells()
	preview_enemy_target_cells(target_cells)

func _ensure_enemy_attack_overlay() -> Node2D:
	if enemy_attack_overlay == null or not is_instance_valid(enemy_attack_overlay):
		enemy_attack_overlay = get_node_or_null("EnemyAttackOverlay")
		if enemy_attack_overlay == null:
			enemy_attack_overlay = EnemyAttackOverlayScript.new()
			enemy_attack_overlay.name = "EnemyAttackOverlay"
			add_child(enemy_attack_overlay)
	return enemy_attack_overlay

## Highlights specified cells with the enemy target visual indicator overlay.
func preview_enemy_target_cells(cells: Array[Vector2i]) -> void:
	for old_cell in current_enemy_target_cells:
		if not cells.has(old_cell) and is_in_grd(Vector2(old_cell.x, old_cell.y)):
			var p: PieceClass = all_pieces[old_cell.x][old_cell.y]
			if p != null:
				p.set_enemy_target_highlight(false)

	current_enemy_target_cells = cells.duplicate()
	for cell in current_enemy_target_cells:
		if is_in_grd(Vector2(cell.x, cell.y)):
			var p: PieceClass = all_pieces[cell.x][cell.y]
			if p != null:
				p.set_enemy_target_highlight(true)

	var overlay := _ensure_enemy_attack_overlay()
	if overlay != null:
		overlay.update_targets(current_enemy_target_cells, Global.grd_to_pixel)

## Clears all enemy target visual indicators from board tiles.
func clear_enemy_target_preview() -> void:
	for cell in current_enemy_target_cells:
		if is_in_grd(Vector2(cell.x, cell.y)):
			var p: PieceClass = all_pieces[cell.x][cell.y]
			if p != null:
				p.set_enemy_target_highlight(false)
	current_enemy_target_cells.clear()
	if enemy_attack_overlay != null and is_instance_valid(enemy_attack_overlay):
		enemy_attack_overlay.clear_targets()

## Executes a BEAST area destruction centered at `center` using `shape_offsets`,
## routing the majority destroyed color to `actor`'s track against `target`.
func execute_beast_destruction(
	center: Vector2i,
	shape_offsets: Array[Vector2i],
	actor: EntityResource,
	target: EntityResource
) -> MatchContext:
	is_aoe_destruction_resolving = true
	aoe_initial_resolved = false
	planned_enemy_target_center = Vector2i(-1, -1)
	current_actor = actor
	current_target = target
	enemy_attacked = actor is EnemyResource
	is_resolving_action = true
	is_player_swap_phase = false
	state = wait
	cascade_step = 0
	color_match_counts_this_turn.clear()
	temp_cascade_momentum_bonus = 0
	reset_all_fall_distances()

	var target_positions: Array[Vector2] = []
	for ofs in shape_offsets:
		var pos := Vector2(center.x + ofs.x, center.y + ofs.y)
		if is_in_grd(pos) and all_pieces[int(pos.x)][int(pos.y)] != null:
			if not target_positions.has(pos):
				target_positions.append(pos)

	pending_match_contexts.clear()
	var ctx: MatchContext = build_majority_color_context(target_positions, actor, target, false)
	if ctx != null:
		pending_match_contexts.append(ctx)

	for pos in target_positions:
		var p: PieceClass = all_pieces[int(pos.x)][int(pos.y)]
		if p != null:
			p.mark(false)
		add_to_array(pos, cur_matches)

	get_bombed_pieces()
	_update_timer_pacing()
	destroy_timer.start()
	return ctx

func generate_flesh():
	if flesh_spaces.size() > 0:
		var flesh_made = false
		var loops = 0
		while not flesh_made and loops < 100:
			var rand = floor(randf_range(0, flesh_spaces.size()))
			var cur_x = flesh_spaces[rand].x
			var cur_y = flesh_spaces[rand].y
			var neighbor = find_normal_neighbor(cur_x,cur_y)
			if neighbor != null:
				var direction: Vector2 = Vector2(cur_x - neighbor.x, cur_y - neighbor.y)
				if grd_flesh.flesh_pieces[cur_x][cur_y] != null:
					grd_flesh.flesh_pieces[cur_x][cur_y].corupt(direction)
				await get_tree().create_timer(0.5).timeout
				if all_pieces[neighbor.x][neighbor.y] != null:
					all_pieces[neighbor.x][neighbor.y].queue_free()
					all_pieces[neighbor.x][neighbor.y] = null
					flesh_spaces.append(Vector2(neighbor.x, neighbor.y))
					emit_signal("make_flesh", Vector2(neighbor.x, neighbor.y))
					flesh_made = true
			loops += 1

func find_normal_neighbor(col, row):
	var directions = [
		Vector2(1, 0),  # Right
		Vector2(-1, 0), # Left
		Vector2(0, 1),  # Up
		Vector2(0, -1)  # Down
	]
	directions.shuffle()
	
	for direction in directions:
		var neighbor_pos = Vector2(col, row) + direction
		if is_in_grd(neighbor_pos) and all_pieces[neighbor_pos.x][neighbor_pos.y] != null:
			return neighbor_pos
	return null

#Helper_functions --------------------------------------------------------------
func damage_specials(col, row):
	if grd_ice != null and grd_ice.ice_pieces.size() > col and grd_ice.ice_pieces[col].size() > row and grd_ice.ice_pieces[col][row] != null:
		if not active_turn_hazards.has("ice"):
			active_turn_hazards.append("ice")
	emit_signal("damage_ice", Vector2(col,row))
	check_freeze(col, row)
	check_rock(col, row)
	check_flesh(col, row)

func clear_board():
	clear_enemy_target_preview()
	planned_enemy_target_center = Vector2i(-1, -1)
	for i in range(grd_width):
		for j in range(grd_height):
			if all_pieces[i][j] != null:
				all_pieces[i][j].queue_free()
				all_pieces[i][j] = null

func check_freeze(col, row):
	emit_signal("damage_freeze", Vector2(col, row))
	if col < grd_width - 1:
		emit_signal("damage_freeze", Vector2(col+1, row))
	if col > 0:
		emit_signal("damage_freeze", Vector2(col-1, row))
	if row < grd_height - 1:
		emit_signal("damage_freeze", Vector2(col, row+1))
	if row > 0:
		emit_signal("damage_freeze", Vector2(col, row-1))

func check_rock(col, row):
	if col < grd_width - 1:
		emit_signal("damage_rock", Vector2(col+1, row))
	if col > 0:
		emit_signal("damage_rock", Vector2(col-1, row))
	if row < grd_height - 1:
		emit_signal("damage_rock", Vector2(col, row+1))
	if row > 0:
		emit_signal("damage_rock", Vector2(col, row-1))

func check_flesh(col, row):
	if col < grd_width - 1:
		emit_signal("damage_flesh", Vector2(col+1, row))
	if col > 0:
		emit_signal("damage_flesh", Vector2(col-1, row))
	if row < grd_height - 1:
		emit_signal("damage_flesh", Vector2(col, row+1))
	if row > 0:
		emit_signal("damage_flesh", Vector2(col, row-1))

func get_obstacles(target):
	empty_spaces = _filter_valid_coords(target.empty_spaces)
	ice_spaces = _filter_valid_coords(target.ice_spaces)
	freeze_spaces = _filter_valid_coords(target.freeze_spaces)
	rock_spaces = _filter_valid_coords(target.rock_spaces)
	flesh_spaces = _filter_valid_coords(target.flesh_spaces)

func _filter_valid_coords(arr: Array[Vector2]) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	for v in arr:
		if v.x >= 0 and v.x < grd_width and v.y >= 0 and v.y < grd_height:
			valid.append(v)
	return valid

func add_to_array(value, array_to_add):
	if not array_to_add.has(value):
		array_to_add.append(value)

func make_bomb(bomb_type, color):
	for c_match in cur_matches:
		var cur_col = c_match.x
		var cur_row = c_match.y
		if all_pieces[cur_col][cur_row] == piece_one and piece_one.color == color:
			piece_one.unmark()
			change_bomb(bomb_type, piece_one)
		if all_pieces[cur_col][cur_row] == piece_two and piece_two.color == color:
			piece_two.unmark()
			change_bomb(bomb_type, piece_two)

func change_bomb(bomb_type, piece):
	match bomb_type:
		0:
			piece.make_adj_bomb()
		1:
			piece.make_row_bomb()
		2:
			piece.make_col_bomb()

func match_all_in_col(col):
	for i in grd_height:
		if all_pieces[col][i] != null:
			all_pieces[col][i].mark(false)

func match_all_in_row(row):
	for i in grd_width:
		if all_pieces[i][row] != null:
			all_pieces[i][row].mark(false)

func match_all_adj(col, row):
	for i in range(-1, 2):
		for j in range(-1, 2):
			if is_in_grd(Vector2(col+i, row+j)):
				if all_pieces[col+i][row+j] != null:
					all_pieces[col+i][row+j].mark(false)

#On Signal __________________________________________________
func _on_destroy_timer_timeout() -> void:
	destroy_matched()
func _on_collapse_timer_timeout() -> void:
	collapse_col()
func _on_refill_timer_timeout() -> void:
	refill_col()
func _on_grd_freeze_remove_freeze(place) -> void:
	if not active_turn_hazards.has("freeze"):
		active_turn_hazards.append("freeze")
	Global.remove_from_array(freeze_spaces, place)
func _on_grd_rock_remove_rock(place) -> void:
	if not active_turn_hazards.has("rock"):
		active_turn_hazards.append("rock")
	Global.remove_from_array(rock_spaces, place)
func _on_grd_flesh_remove_flesh(place) -> void:
	damaged_flesh = true
	if not active_turn_hazards.has("flesh"):
		active_turn_hazards.append("flesh")
	Global.remove_from_array(flesh_spaces, place)
