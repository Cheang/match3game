extends Node

var cur_char: PlayerResource
var selected_char: PlayerResource

var cur_enemy: EnemyResource

var grd_x_start: int = 64
var grd_y_start: int = 800
var grd_width: int = 8
var grd_height: int = 9
var grd_offset: int = 64

var game_is_played: bool = false
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
#audio
var cur_song: String = ""
var audio_plaing: bool = true # all of the sounds
var music_plaing: bool = true # just the music
var sfx_playing: bool = true # just the sfx
var audio_lvl: float = 75.0
var music_lvl: float = 100
var sfx_lvl: float = 100

var def_char: PlayerResource = preload("res://players/warrior/warrior.tres")


#Functions_____________________________________________________________________#
#Player_functions --------------------------------------------------------------
func set_up_player():
	if is_null(selected_char):
		selected_char = def_char
	cur_char = selected_char.duplicate()
	cur_char.set_stats_at_beging_of_game()
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
