extends Node


var enemy_loc_cards: Array[Location] 
var services_loc_cards: Array[Location] 
var event_loc_cards: Array[Location] 
var boss_loc_cards: Array[Location] 

func load_locations_from_directory(locations: LocationLoader) -> void:
	Global.minions_needed = locations.enemy_needed
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
	if !Locations.boss_loc_cards.is_empty():
		var loc: Location = Locations.boss_loc_cards.pick_random()
		Global.area_cur_boss = loc
	target.shuffle()

func add_boss_to_locations(target: Array[Location], req: int = 4):
	if !Global.boss_added:
		if Global.minions_killed >= req:
			if Global.area_cur_boss != null:
				var pick: Location = Global.area_cur_boss
				target.append(pick)
				Global.area_cur_boss = null
				Global.boss_added = true
