extends Node

enum TileColor {
	# Base Colors
	RED = 100,
	BLUE = 200,
	GREEN = 300,
	PURPLE = 400,
	WHITE = 500,

	# Exotic / Corrupted Variations (Parent = Base Color / 100 * 100)
	DARK_CRIMSON = 101,  # Parent: RED
	COBALT_FROST = 201,  # Parent: BLUE
	VENOM_GREEN = 301,   # Parent: GREEN
	ELDRITCH_VOID = 401, # Parent: PURPLE
	SOLAR_GOLD = 501     # Parent: WHITE
}

## Central registry mapping each Equipment Family to its natural TileColor.
## When adding a new family to the game, define it here.
const EQUIPMENT_FAMILY_COLORS: Dictionary = {
	"sword": TileColor.RED,
	"fists": TileColor.RED,
	"shields": TileColor.BLUE,
	"mobility": TileColor.GREEN,
	"healing": TileColor.PURPLE,
}

## Returns the default preferred color for a given equipment family name.
func get_family_default_color(family_name: String) -> int:
	return EQUIPMENT_FAMILY_COLORS.get(family_name.to_lower(), 0)

var def_char: PlayerResource = null

func _ready():
	if ResourceLoader.exists("res://players/warrior/warrior.tres"):
		def_char = load("res://players/warrior/warrior.tres")
	if setting_res == null:
		setting_res = SettingsResource.new()

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
var post_combat_event: Resource = null
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
#Color_functions ---------------------------------------------------------------
func is_exotic_color(color: int) -> bool:
	return (int(color) % 100) != 0

func get_base_family(color: int) -> int:
	return int(color / 100) * 100

func get_color_name(color: int) -> String:
	match color:
		0: return "Any Color"
		TileColor.RED: return "Red"
		TileColor.BLUE: return "Blue"
		TileColor.GREEN: return "Green"
		TileColor.PURPLE: return "Purple"
		TileColor.WHITE: return "White"
		TileColor.DARK_CRIMSON: return "Crimson"
		TileColor.COBALT_FROST: return "Frost"
		TileColor.VENOM_GREEN: return "Venom"
		TileColor.ELDRITCH_VOID: return "Void"
		TileColor.SOLAR_GOLD: return "Solar"
	return "Any Color"

func get_color_short_label(color: int) -> String:
	match color:
		0: return "ANY"
		TileColor.RED: return "R"
		TileColor.BLUE: return "B"
		TileColor.GREEN: return "G"
		TileColor.PURPLE: return "P"
		TileColor.WHITE: return "W"
		TileColor.DARK_CRIMSON: return "R*"
		TileColor.COBALT_FROST: return "B*"
		TileColor.VENOM_GREEN: return "G*"
		TileColor.ELDRITCH_VOID: return "P*"
		TileColor.SOLAR_GOLD: return "W*"
	return "ANY"

func get_color_ui_tint(color: int) -> Color:
	match color:
		0: return Color("#7f798a")
		TileColor.RED: return Color("#ae2334")
		TileColor.BLUE: return Color("#4d65b4")
		TileColor.GREEN: return Color("#3ca370")
		TileColor.PURPLE: return Color("#8b408b")
		TileColor.WHITE: return Color("#d4d2c5")
		TileColor.DARK_CRIMSON: return Color("#6e0d25")
		TileColor.COBALT_FROST: return Color("#36c5f4")
		TileColor.VENOM_GREEN: return Color("#8fde5d")
		TileColor.ELDRITCH_VOID: return Color("#4b1d52")
		TileColor.SOLAR_GOLD: return Color("#f9c22b")
	return Color("#7f798a")

func get_color_base_texture(color: int) -> Texture2D:
	if color == 0:
		return preload("res://assets/white_0_sq.png")
	match get_base_family(color):
		TileColor.RED: return preload("res://assets/red_0_sq.png")
		TileColor.BLUE: return preload("res://assets/blue_0_sq.png")
		TileColor.GREEN: return preload("res://assets/green_0_sq.png")
		TileColor.PURPLE: return preload("res://assets/purple_0_sq.png")
		TileColor.WHITE: return preload("res://assets/white_0_sq.png")
	return preload("res://assets/white_0_sq.png")

func color_string_to_id(color_str: String) -> int:
	match color_str.to_lower():
		"red": return TileColor.RED
		"blue": return TileColor.BLUE
		"green": return TileColor.GREEN
		"purple": return TileColor.PURPLE
		"white": return TileColor.WHITE
	return TileColor.RED

#Player_functions --------------------------------------------------------------
func set_up_player():
	if selected_char == null:
		selected_char = def_char
	if selected_char != null:
		cur_char = selected_char.duplicate(true)
		cur_char.reset_stats_at_beginning_of_game()
		reset_variable()

func select_character(character: PlayerResource):
	selected_char = character

#Enemy_functions ---------------------------------------------------------------
func set_up_enemy(specific_enemy: EnemyResource):
	if !is_null(specific_enemy):
		cur_enemy = specific_enemy.duplicate()
		cur_enemy.cur_health = cur_enemy.max_health

#Game_functions ----------------------------------------------------------------
func reset_variable():
	current_wave = 0
	minions_killed = 0
	boss_added = false
	boss_beaten = false
	post_combat_event = null
	current_level += 1

func compare_deck_pieces(a, b):
	if a is Equipment and b is Equipment:
		var ca: int = a.allowed_colors[0] if not a.allowed_colors.is_empty() else 100
		var cb: int = b.allowed_colors[0] if not b.allowed_colors.is_empty() else 100
		if ca == cb:
			if a.piece_name == b.piece_name:
				return a.upgrade < b.upgrade
			return a.piece_name.to_lower() < b.piece_name.to_lower()
		return ca < cb
	if "color" in a and "color" in b:
		if a.color == b.color:
			if a.piece_name == b.piece_name:
				return a.upgrades - b.upgrades
			return a.piece_name.to_lower() < b.piece_name.to_lower()
		return a.color.to_lower() < b.color.to_lower()
	return false

func changeSong(new_song: MusicTrack = null, new_playlist: MusicPlaylist = null):
	var mm = get_node_or_null("/root/MusicManager")
	if mm == null:
		return
	if new_song != null:
		var new_song_name = new_song.name
		if new_song_name != cur_song:
			cur_song = new_song_name
			mm.play_song.emit(new_song, true, true, 1.0)
	if new_playlist != null:
		var new_song_name = new_playlist.name
		if new_song_name != cur_song:
			cur_song = new_song_name
			mm.play_playlist.emit(new_playlist, true, true, 1.0)

#Helper_functions --------------------------------------------------------------
func is_null(item) -> bool:
	return item == null

func grd_to_pixel(col, row) -> Vector2:
	var new_x = grd_x_start + grd_offset * col
	var new_y = grd_y_start + -grd_offset * row
	return Vector2(new_x, new_y)

func pixel_to_grd(x, y) -> Vector2:
	var new_x = round((x - grd_x_start) / grd_offset)
	var new_y = round((y - grd_y_start) / -grd_offset)
	return Vector2(new_x, new_y)

# Converts internal row index (where row 0 is visual bottom at y=grd_y_start)
# to spec depth row index (where 0 is top of grid and grd_height - 1 is bottom of grid).
func to_spec_row(internal_row: int) -> int:
	return clampi((grd_height - 1) - internal_row, 0, grd_height - 1)

func make_2d_array(width: int, height: int) -> Array:
	var array: Array = []
	for i in width:
		var col: Array = []
		col.resize(height)
		array.append(col)
	return array

func is_in_array(array: Array, item) -> bool:
	return array.has(item)

func remove_from_array(array: Array, item) -> void:
	array.erase(item)

func save():
	var save_file = Serializer.new()
	if cur_char:
		save_file.cur_char = cur_char.duplicate(true)
		save_file.cur_char_deck = get_tiles_from_player()
	if selected_char:
		save_file.selected_char = selected_char.duplicate(true)
	save_file.settings = setting_res
	save_file.cur_scene = cur_scene
	if cur_enemy:
		save_file.cur_enemy = cur_enemy.duplicate(true)
	
	save_file.game_is_over = game_is_over
	save_file.cur_cutscene = cur_cutscene
	save_file.current_wave = current_wave
	save_file.current_level = current_level
	
	save_file.area_locations.clear()
	if area_locations != null:
		for loc in area_locations:
			if loc is Location:
				save_file.area_locations.append(loc.duplicate(true))
	if area_cur_boss:
		save_file.area_cur_boss = area_cur_boss.duplicate(true)
	save_file.area_cur_event = area_cur_event
	save_file.post_combat_event = post_combat_event
	
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
		if save_file.selected_char:
			selected_char = save_file.selected_char.duplicate(true)
		elif def_char:
			selected_char = def_char
		if save_file.settings:
			setting_res = save_file.settings
		elif setting_res == null:
			setting_res = SettingsResource.new()
		
		if save_file.cur_char and save_file.cur_scene:
			cur_char = save_file.cur_char.duplicate(true)
			cur_char.ensure_loadout_tracks()
			cur_scene = save_file.cur_scene
			if save_file.cur_enemy:
				cur_enemy = save_file.cur_enemy.duplicate(true)
			game_is_over = save_file.game_is_over
			cur_cutscene = save_file.cur_cutscene
			current_wave = save_file.current_wave
			current_level = save_file.current_level
			
			area_locations.clear()
			if save_file.area_locations != null:
				for loc in save_file.area_locations:
					if loc is Location:
						area_locations.append(loc.duplicate(true))
			if save_file.area_cur_boss != null:
				area_cur_boss = save_file.area_cur_boss.duplicate(true)
			area_cur_event = save_file.area_cur_event
			post_combat_event = save_file.post_combat_event
			
			minions_needed = save_file.minions_needed
			minions_killed = save_file.minions_killed
			boss_added = save_file.boss_added
			boss_beaten = save_file.boss_beaten
			bosses_killed_needed = save_file.bosses_killed_needed
			bosses_killed = save_file.bosses_killed
			
			game_seed = save_file.game_seed
	else:
		setting_res = SettingsResource.new()
		if def_char == null and ResourceLoader.exists("res://players/warrior/warrior.tres"):
			def_char = load("res://players/warrior/warrior.tres")
		selected_char = def_char

func get_tiles_from_player():
	var array_to_return: Array = []
	if cur_char != null:
		for tile in cur_char.deck_in_game:
			if tile != null and tile.has_method("set_node_values"):
				array_to_return.append(tile.set_node_values())
	return array_to_return
