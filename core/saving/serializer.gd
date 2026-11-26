class_name Serializer
extends Resource

@export var cur_char: PlayerResource
@export var cur_char_deck: Array = []
@export var selected_char: PlayerResource
@export var settings: SettingsResource
@export var cur_scene: String = ""
@export var cur_enemy: EnemyResource

@export var game_is_over: bool = false
@export var cur_cutscene: CutScene
@export var current_wave: int = 0
@export var current_level: int = 0
@export var run_stage_queue: Array[String] = []
@export var current_stage_index: int = 0
@export var current_area_path: String = ""
@export var visited_area_paths: Array[String] = []

@export var area_locations: Array[Location] = []
@export var area_cur_boss: Location
@export var area_cur_event: Event
@export var post_combat_event: Resource = null

@export var minions_needed: int = 0
@export var minions_killed: int = 0
@export var boss_added: bool = false
@export var boss_beaten: bool = false
@export var bosses_killed_needed: int = 1
@export var bosses_killed: int = 0

@export var game_seed: int = 0

@export var saved_color_loadouts: Dictionary = {}
@export var saved_modifier_inventory: Array[Equipment] = []
@export var saved_equipped_passives: Array[Resource] = []
@export var saved_active_passive_stat_contributions: Dictionary = {}
@export var saved_active_equipment_stat_contributions: Dictionary = {}
@export var saved_unlocked_tags: Dictionary = {}
@export var saved_activated_node_ids: Dictionary = {}
@export var saved_active_combat_pool: Array[Resource] = []
@export var saved_active_passive_pool: Array[Resource] = []
@export var saved_pending_reward_context: Dictionary = {}
@export var saved_enemy_hybrid_next_is_beast: bool = false
@export var saved_enemy_track_cursors: Dictionary = {}

const LEGACY_RESOURCE_PATH_REMAP: Dictionary = {
	"res://assets/sprites/locations/loc_lamia_boss.png": "res://core/entities/enemies/bosses/lamia/assets/lamia_loc.png",
	"res://assets/sprites/enemies/lamia_head.png": "res://core/entities/enemies/bosses/lamia/assets/lamia_head.png",
	"res://assets/sprites/enemies/lamia_body.png": "res://core/entities/enemies/bosses/lamia/assets/lamia_body.png",
	"res://map/areas/area_1.tres": "res://core/map/areas/level1/area_1.tres",
	"res://map/locations_screen.tscn": "res://scenes/locations/locations_screen.tscn",
	"res://map/location_card.tscn": "res://scenes/locations/location_card.tscn",
	"res://ui/screens/main_menu.tscn": "res://scenes/main_menu/main_menu.tscn",
	"res://ui/screens/hero_select_screen.tscn": "res://scenes/hero_select/hero_select_screen.tscn",
	"res://ui/screens/boss_select_screen.tscn": "res://scenes/boss_select/boss_select_screen.tscn",
	"res://ui/screens/settings_screen.tscn": "res://scenes/settings/settings_screen.tscn",
	"res://ui/screens/thank_you_screen.tscn": "res://scenes/thank_you/thank_you_screen.tscn",
	"res://assets/sprites/equipment/wild-tusk.png": "res://core/entities/enemies/minions/wild_boar/assets/wild-tusk.png",
	"res://assets/shaders/rarity_palette_swap.gdshader": "res://scenes/rewards/assets/rarity_palette_swap.gdshader",
	"res://assets/shaders/rarity_palette_swap.tres": "res://scenes/rewards/assets/rarity_palette_swap.tres",
}

const LEGACY_RESOURCE_PREFIX_REMAP: Array = [
	["res://assets/sprites/rewards/icons/wild_boar/", "res://core/entities/enemies/minions/wild_boar/assets/"],
	["res://assets/sprites/enemies/lamia/", "res://core/entities/enemies/bosses/lamia/assets/"],
	["res://assets/sprites/enemies/corupted_pitka/", "res://core/entities/enemies/bosses/corrupted_pitka/assets/"],
	["res://assets/sprites/enemies/bear_stravnica/", "res://core/entities/enemies/minions/bear_stravnica/assets/"],
	["res://assets/sprites/enemies/karjaliia/", "res://core/entities/enemies/minions/karjaliia_cap/assets/"],
	["res://assets/sprites/enemies/pesent/", "res://core/entities/enemies/minions/peasant/assets/"],
	["res://assets/sprites/enemies/vila/", "res://core/entities/enemies/minions/vila/assets/"],
	["res://assets/sprites/enemies/wild_boar/", "res://core/entities/enemies/minions/wild_boar/assets/"],
	["res://assets/sprites/ui/character_select/", "res://scenes/hero_select/assets/"],
	["res://assets/sprites/ui/boss_select/", "res://scenes/boss_select/assets/"],
	["res://assets/sprites/ui/locations/", "res://scenes/locations/assets/"],
	["res://assets/sprites/ui/bottom_bar/", "res://ui/hud/assets/"],
	["res://assets/sprites/ui/inventory_overlay/", "res://ui/inventory_overlay/assets/"],
	["res://assets/sprites/ui/combat/", "res://scenes/combat/assets/"],
	["res://assets/sprites/locations/", "res://scenes/locations/assets/"],
	["res://assets/sprites/rewards/", "res://scenes/rewards/assets/"],
	["res://assets/sprites/events/", "res://scenes/events/assets/"],
	["res://assets/sprites/player/", "res://core/entities/player/classes/warrior/assets/"],
	["res://assets/sprites/tiles/", "res://scenes/combat/assets/tiles/"],
	["res://assets/sprites/obstacles/", "res://scenes/combat/assets/obstacles/"],
	["res://events/", "res://scenes/events/"],
	["res://scenes/rewards/enemy_loot/wild_boar/", "res://core/entities/enemies/minions/wild_boar/rewards/"],
	["res://rewards/enemy_loot/wild_boar/", "res://core/entities/enemies/minions/wild_boar/rewards/"],
	["res://rewards/", "res://scenes/rewards/"],
	["res://combat/", "res://scenes/combat/"],
	["res://map/", "res://core/map/"],
	["res://equipment/", "res://core/equipment/"],
	["res://entities/", "res://core/entities/"],
]

var save_path: String = "user://save1.tres"


func _remap_legacy_resource_path(res_path: String) -> String:
	if LEGACY_RESOURCE_PATH_REMAP.has(res_path):
		return LEGACY_RESOURCE_PATH_REMAP[res_path]
	for pair in LEGACY_RESOURCE_PREFIX_REMAP:
		var old_prefix: String = pair[0]
		if res_path.begins_with(old_prefix):
			var new_prefix: String = pair[1]
			return new_prefix + res_path.substr(old_prefix.length())
	return ""


func save_data() -> void:
	var dir_path: String = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var error: Error = ResourceSaver.save(self, save_path)
	if error != OK:
		print_debug("Error saving game: ", error)


func _prepare_save_file_for_load() -> bool:
	var text: String = FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		return false

	var regex := RegEx.new()
	if regex.compile('\\[ext_resource[^\\]]*path="(res://[^"]+)"') != OK:
		return true

	var checked: Dictionary = {}
	var missing_paths: Array[String] = []
	var modified: bool = false
	for m in regex.search_all(text):
		var res_path: String = m.get_string(1)
		if checked.has(res_path):
			continue
		checked[res_path] = true
		var mapped_path: String = _remap_legacy_resource_path(res_path)
		if mapped_path != "":
			if ResourceLoader.exists(mapped_path):
				text = text.replace('path="%s"' % res_path, 'path="%s"' % mapped_path)
				modified = true
			else:
				missing_paths.append(res_path)
		elif not ResourceLoader.exists(res_path):
			missing_paths.append(res_path)

	if not missing_paths.is_empty():
		print_debug("Skipping incompatible save file (", save_path, ") missing resources: ", missing_paths)
		return false

	if modified:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()

	return true


func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		print_debug("Save file not found: ", save_path)
		return  # Prevents loading from a non-existent file
	if not _prepare_save_file_for_load():
		return

	var data: Serializer = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Serializer
	if not data:
		print_debug("Failed to load save data.")
		return
	
	cur_char = data.cur_char if data.cur_char else null
	cur_char_deck = data.cur_char_deck if data.cur_char_deck else []
	selected_char = data.selected_char if data.selected_char else null
	settings = data.settings if data.settings else null
	var loaded_scene: String = data.cur_scene if data.cur_scene != null else ""
	var mapped_scene: String = _remap_legacy_resource_path(loaded_scene)
	cur_scene = mapped_scene if (mapped_scene != "" and ResourceLoader.exists(mapped_scene)) else loaded_scene
	cur_enemy = data.cur_enemy if data.cur_enemy else null
	
	game_is_over = data.game_is_over
	cur_cutscene = data.cur_cutscene
	current_wave = data.current_wave
	current_level = data.current_level
	run_stage_queue.clear()
	if data.run_stage_queue != null:
		for s in data.run_stage_queue:
			run_stage_queue.append(str(s))
	current_stage_index = data.current_stage_index
	var loaded_area_path: String = data.current_area_path if data.current_area_path != null else ""
	var mapped_area_path: String = _remap_legacy_resource_path(loaded_area_path)
	current_area_path = mapped_area_path if (mapped_area_path != "" and ResourceLoader.exists(mapped_area_path)) else loaded_area_path
	visited_area_paths.clear()
	if data.visited_area_paths != null:
		for p in data.visited_area_paths:
			var raw_p := str(p)
			var mapped_p: String = _remap_legacy_resource_path(raw_p)
			visited_area_paths.append(mapped_p if (mapped_p != "" and ResourceLoader.exists(mapped_p)) else raw_p)
	
	area_locations.clear()
	if data.area_locations != null:
		for loc in data.area_locations:
			if loc is Location:
				area_locations.append(loc)
	area_cur_boss = data.area_cur_boss if data.area_cur_boss else null
	area_cur_event = data.area_cur_event
	post_combat_event = data.post_combat_event
	
	minions_needed = data.minions_needed
	minions_killed = data.minions_killed
	boss_added = data.boss_added
	boss_beaten = data.boss_beaten
	bosses_killed_needed = data.bosses_killed_needed
	bosses_killed = data.bosses_killed
	
	game_seed = data.game_seed
	saved_color_loadouts = data.saved_color_loadouts if data.saved_color_loadouts != null else {}
	saved_modifier_inventory = data.saved_modifier_inventory if data.saved_modifier_inventory != null else []
	saved_equipped_passives = data.saved_equipped_passives if data.saved_equipped_passives != null else []
	saved_active_passive_stat_contributions = data.saved_active_passive_stat_contributions if data.saved_active_passive_stat_contributions != null else {}
	saved_active_equipment_stat_contributions = data.saved_active_equipment_stat_contributions if data.saved_active_equipment_stat_contributions != null else {}
	saved_unlocked_tags = data.saved_unlocked_tags if data.saved_unlocked_tags != null else {}
	saved_activated_node_ids = data.saved_activated_node_ids if data.saved_activated_node_ids != null else {}
	saved_active_combat_pool = data.saved_active_combat_pool if data.saved_active_combat_pool != null else []
	saved_active_passive_pool = data.saved_active_passive_pool if data.saved_active_passive_pool != null else []
	saved_pending_reward_context = data.saved_pending_reward_context if data.saved_pending_reward_context != null else {}
	saved_enemy_hybrid_next_is_beast = data.saved_enemy_hybrid_next_is_beast
	saved_enemy_track_cursors = data.saved_enemy_track_cursors if data.saved_enemy_track_cursors != null else {}
