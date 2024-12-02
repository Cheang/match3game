extends Node

var enemy_loc_cards: Array[Location] 
var services_loc_cards: Array[Location] 
var event_loc_cards: Array[Location] 
var boss_loc_cards: Array[Location] 

func _ready() -> void:
	load_locations_from_directory("res://locations/enemie_encounters", enemy_loc_cards)
	load_locations_from_directory("res://locations/services_encounters", services_loc_cards)
	load_locations_from_directory("res://locations/event_encounters", event_loc_cards)
	load_locations_from_directory("res://locations/boss_encounters", boss_loc_cards)

func load_locations_from_directory(directory_path: String, target_array:Array[Location]) -> void:
	var dir = DirAccess.open(directory_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				if file_name.ends_with(".tres"):
					var scene = load(directory_path + "/" + file_name)
					if scene is Location:
						target_array.append(scene)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Failed to open directory: %s" % directory_path)

func pick_locations(target: Array[Location], enemies_numb: int = 4, event_numb: int = 4, services_numb: int = 2):
	target.clear()
	if !Locations.enemy_loc_cards.is_empty():
		for i in enemies_numb:
			var loc: Location = Locations.enemy_loc_cards.pick_random()
			target.append(loc)
	if !Locations.event_loc_cards.is_empty():
		for i in event_numb:
			var loc: Location = Locations.event_loc_cards.pick_random()
			target.append(loc)
	if !Locations.services_loc_cards.is_empty():
		for i in services_numb:
			var loc: Location = Locations.services_loc_cards.pick_random()
			target.append(loc)
	target.shuffle()

func add_boss_to_locations(target: Array[Location], req: int = 4):
	if !Global.boss_added:
		if Global.minions_killed >= req:
			if !Global.is_null(boss_loc_cards):
				var pick: Location = boss_loc_cards.pick_random()
				if pick.level != 0:
					while pick.level != null and pick.level <= Global.current_level:
						randomize()
						pick = boss_loc_cards.pick_random()
				target.append(pick)
				Global.boss_added = true
