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

func save_data():
	ResourceSaver.save(self, save_path)

func load_data():
	var data = ResourceLoader.load(save_path, "")
	if data.cur_char:
		cur_char = data.cur_char.duplicate(true)
		cur_char_deck = data.cur_char_deck.duplicate()
	selected_char = data.selected_char.duplicate(true)
	settings = data.settings
	cur_scene = data.cur_scene
	if data.cur_enemy:
		cur_enemy = data.cur_enemy.duplicate(true)
	
	game_is_over = data.game_is_over
	cur_cutscene = data.cur_cutscene
	current_wave = data.current_wave
	current_level = data.current_level
	
	area_locations = data.area_locations.duplicate(true)
	if area_cur_boss:
		area_cur_boss = data.area_cur_boss.duplicate(true)
	area_cur_event = data.area_cur_event
	
	minions_needed = data.minions_needed
	minions_killed = data.minions_killed
	boss_added = data.boss_added
	boss_beaten = data.boss_beaten
	bosses_killed_needed = data.bosses_killed_needed
	bosses_killed = data.bosses_killed
	
	
