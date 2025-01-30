extends Node

const def_char: PlayerResource = preload("res://players/warrior/warrior.tres")

var cur_char: PlayerResource
var selected_char: PlayerResource
var cur_enemy: EnemyResource
var cur_scene: String
var actual_cur_scene: String:
	set(new_scene):
		if new_scene == "res://setting.tscn" or new_scene == "res://main_menu.tscn" or new_scene == "res://reward_screen.tscn" or new_scene == "res://event_screen.tscn":
			actual_cur_scene = new_scene
		else:
			cur_scene = new_scene
			actual_cur_scene = new_scene

var grd_x_start: int = 64
var grd_y_start: int = 800
var grd_width: int = 8
var grd_height: int = 9
var grd_offset: int = 64
var game_is_played: bool = false
var game_is_over: bool = false

var cur_cutscene: CutScene
var current_wave: int = 0
var current_level: int = 0

#for locations
var area_locations: Array[Location]
var area_cur_boss: Location
var area_cur_event: Event
var event_pieces_removed: int

#for boss spawning
var minions_needed: int = 0
var minions_killed: int = 0
var boss_added: bool = false
var boss_beaten: bool = false
var bosses_killed_needed = 1
var bosses_killed = 0 

#setting
var save_path = "user://save1.tres"
var game_seed: int = 0
#audio
var cur_song: String = ""
var setting_res: Resource 

#flags
var flg_game_is_loaded: bool = false

#Functions_____________________________________________________________________#
#Player_functions --------------------------------------------------------------
func set_up_player():
	cur_char = selected_char.duplicate()
	cur_char.reset_stats_at_beging_of_game()
	reset_variable()
func select_character(character: PlayerResource):
	selected_char = character

#Enemy_functions ---------------------------------------------------------------
func set_up_enemy(specific_enemy: EnemyResource):
	if !is_null(specific_enemy):
		cur_enemy = specific_enemy.duplicate()
		cur_enemy.cur_health = cur_enemy.max_health
		pass

#Game_functions ----------------------------------------------------------------
func reset_variable():
	current_wave = 0
	minions_killed = 0
	boss_added = false
	boss_beaten = false
	current_level += 1

func compare_deck_pieces(a, b):
	if a.color == b.color:
		if a.piece_name == b.piece_name:
			return a.upgrades - b.upgrades
		return a.piece_name.to_lower() < b.piece_name.to_lower()
	return a.color.to_lower() < b.color.to_lower()
	
func changeSong(new_song: MusicTrack = null, new_playlist: MusicPlaylist = null):
	if new_song != null:
		var new_song_name = new_song.name
		if new_song_name != cur_song:
			cur_song = new_song_name
			MusicManager.play_song.emit(new_song, true, true, 1.0)
	if new_playlist != null:
		var new_song_name = new_playlist.name
		if new_song_name != cur_song:
			cur_song = new_song_name
			MusicManager.play_playlist.emit(new_playlist, true, true, 1.0)

#Helper_functions --------------------------------------------------------------
func is_null(item):
	if item == null:
		return true
	return false
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
func is_in_array(array, item):
	for i in array.size():
		if array[i] == item:
			return true
	return false
func remove_from_array(array, item):
	for i in range(array.size()-1, -1, -1):
		if array[i] == item:
			array.remove_at(i)

func save():
	var save_file = Serializer.new()
	if cur_char:
		save_file.cur_char = cur_char.duplicate(true)
		save_file.cur_char_deck = get_tiles_from_player()
	save_file.selected_char = selected_char.duplicate(true)
	save_file.settings = setting_res
	save_file.cur_scene = cur_scene
	if cur_enemy:
		save_file.cur_enemy = cur_enemy.duplicate(true)
	
	save_file.game_is_over = game_is_over
	save_file.cur_cutscene = cur_cutscene
	save_file.current_wave = current_wave
	save_file.current_level = current_level
	
	save_file.area_locations = area_locations.duplicate(true)
	if area_cur_boss:
		save_file.area_cur_boss = area_cur_boss.duplicate(true)
	save_file.area_cur_event = area_cur_event
	
	save_file.minions_needed = minions_needed
	save_file.minions_killed = minions_killed
	save_file.boss_added = boss_added
	save_file.boss_beaten = boss_beaten
	save_file.bosses_killed_needed = bosses_killed_needed
	save_file.bosses_killed = bosses_killed
	
	save_file.game_seed = game_seed
	
	save_file.save_data()
func load_data():
	var save_file = Serializer.new()
	if FileAccess.file_exists(save_path):
		save_file.load_data()
		selected_char = save_file.selected_char.duplicate(true)
		setting_res = save_file.settings
		
		if save_file.cur_char and save_file.cur_scene:
			cur_char = save_file.cur_char.duplicate(true)
			cur_scene = save_file.cur_scene
			if save_file.cur_char_deck:
				for scene in save_file.cur_char_deck:
					if scene:
						var scene_resource = load(scene["scene_path"])
						var instance = scene_resource.instantiate()
						if instance and instance is Node2D:
							instance.location = scene["scene_path"]
							instance.upgrades = scene["upgrades"]
							instance.cooldown = scene["cooldown"]
							cur_char.deck_in_game.append(instance)
			if save_file.cur_enemy:
				cur_enemy = save_file.cur_enemy.duplicate(true)
			game_is_over = save_file.game_is_over
			cur_cutscene = save_file.cur_cutscene
			current_wave = save_file.current_wave
			current_level = save_file.current_level
			
			area_locations = save_file.area_locations.duplicate(true)
			if save_file.area_cur_boss != null:
				area_cur_boss = save_file.area_cur_boss.duplicate(true)
			area_cur_event = save_file.area_cur_event
			
			minions_needed = save_file.minions_needed
			minions_killed = save_file.minions_killed
			boss_added = save_file.boss_added
			boss_beaten = save_file.boss_beaten
			bosses_killed_needed = save_file.bosses_killed_needed
			bosses_killed = save_file.bosses_killed
			
			game_seed = save_file.game_seed
	else:
		setting_res = SettingsResource.new()
		selected_char = def_char

func get_tiles_from_player(): 
	var array_to_return: Array = []
	for tile in cur_char.deck_in_game:
		array_to_return.append(tile.set_node_values())
	return array_to_return
