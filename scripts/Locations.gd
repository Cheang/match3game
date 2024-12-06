extends Node


var enemy_loc_cards: Array[Location] 
var services_loc_cards: Array[Location] 
var event_loc_cards: Array[Location] 
var boss_loc_cards: Array[Location] 

func load_locations_from_directory(locations: LocationLoader) -> void:
	enemy_loc_cards = locations.enemy.duplicate(true)
	services_loc_cards = locations.services.duplicate(true)
	event_loc_cards = locations.event.duplicate(true)
	boss_loc_cards = locations.boss.duplicate(true)

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
