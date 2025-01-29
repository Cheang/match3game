extends Resource
class_name Serializer

var save_path = "user://save1.tres"

@export var cur_char: PlayerResource
@export var cur_char_deck: Array
@export var selected_char: PlayerResource
@export var settings: SettingsResource
@export var cur_scene: String
@export var cur_enemy: EnemyResource

@export var game_is_over: bool = false
@export var cur_cutscene: CutScene
@export var current_wave: int = 0
@export var current_level: int = 0

@export var area_locations: Array[Location]
@export var area_cur_boss: Location
@export var area_cur_event: Event

@export var minions_needed: int = 0
@export var minions_killed: int = 0
@export var boss_added: bool = false
@export var boss_beaten: bool = false
@export var bosses_killed_needed = 1
@export var bosses_killed = 0 

@export var game_seed: int = 0

func save_data() -> void:
	var error = ResourceSaver.save(self, save_path)
	if error != OK:
		print_debug("Error saving game: ", error)

func load_data():
	if not FileAccess.file_exists(save_path):
		print_debug("Save file not found: ", save_path)
		return  # Prevents loading from a non-existent file
	
	var data: Serializer = ResourceLoader.load(save_path, "") as Serializer
	if not data:
		print_debug("Failed to load save data.")
		return
	
	cur_char = data.cur_char if data.cur_char else null
	cur_char_deck = data.cur_char_deck if data.cur_char_deck else []
	selected_char = data.selected_char if data.selected_char else null
	settings = data.settings if data.settings else null
	cur_scene = data.cur_scene 
	cur_enemy = data.cur_enemy if data.cur_enemy else null
	
	game_is_over = data.game_is_over
	cur_cutscene = data.cur_cutscene
	current_wave = data.current_wave
	current_level = data.current_level
	
	area_locations = data.area_locations if data.area_locations else []
	area_cur_boss = data.area_cur_boss if data.area_cur_boss else null
	area_cur_event = data.area_cur_event
	
	minions_needed = data.minions_needed
	minions_killed = data.minions_killed
	boss_added = data.boss_added
	boss_beaten = data.boss_beaten
	bosses_killed_needed = data.bosses_killed_needed
	bosses_killed = data.bosses_killed
	
	game_seed = data.game_seed
