extends Node

var enemy_loc_cards: Array[Location] = []
var services_loc_cards: Array[Location] = []
var event_loc_cards: Array[Location] = []
var boss_loc_cards: Array[Location] = []


func _scan_area_dir(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and not dir.current_is_dir():
			var clean := entry.trim_suffix(".remap")
			if clean.ends_with(".tres"):
				var full := dir_path.path_join(clean)
				if not seen.has(full):
					var res := ResourceLoader.load(full)
					if res is LocationLoader:
						seen[full] = true
						paths.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func get_area_paths_in_stage(stage_id_or_path: String) -> Array[String]:
	if stage_id_or_path.ends_with(".tres") and ResourceLoader.exists(stage_id_or_path):
		var direct_res := ResourceLoader.load(stage_id_or_path)
		if direct_res is LocationLoader:
			return [stage_id_or_path]

	var stage_dir := Global.AREAS_ROOT_DIR.path_join(stage_id_or_path)
	var direct_list := _scan_area_dir(stage_dir)
	if not direct_list.is_empty():
		return direct_list

	# Graceful fallback down lower level folders while later levels are authored
	if stage_id_or_path.begins_with("level"):
		var level_str := stage_id_or_path.substr(5)
		if level_str.is_valid_int():
			var level_num := int(level_str)
			for i in range(level_num - 1, 0, -1):
				var fallback_dir := Global.AREAS_ROOT_DIR.path_join("level%d" % i)
				var fallback_list := _scan_area_dir(fallback_dir)
				if not fallback_list.is_empty():
					return fallback_list

	# Final legacy/default fallback
	for candidate in [
		Global.AREAS_ROOT_DIR.path_join("level1/area_1.tres"),
		Global.AREAS_ROOT_DIR.path_join("area_1.tres")
	]:
		if ResourceLoader.exists(candidate):
			var res := ResourceLoader.load(candidate)
			if res is LocationLoader:
				return [candidate]
	return []


func pick_random_area_for_stage(stage_id_or_path: String, visited_paths: Array[String] = []) -> LocationLoader:
	var pool := get_area_paths_in_stage(stage_id_or_path)
	if pool.is_empty():
		return null

	var unvisited: Array[String] = []
	for p in pool:
		if not visited_paths.has(p):
			unvisited.append(p)

	var candidates := unvisited if not unvisited.is_empty() else pool
	var chosen_path: String = candidates.pick_random()
	Global.current_area_path = chosen_path
	if not Global.visited_area_paths.has(chosen_path):
		Global.visited_area_paths.append(chosen_path)

	var loaded := ResourceLoader.load(chosen_path) as LocationLoader
	return loaded


func _location_identity(loc: Location) -> String:
	if loc == null:
		return ""
	if loc.resource_path != "":
		return loc.resource_path
	return loc.name + ":" + str(loc.get_instance_id())


func roll_boss_choices(area: LocationLoader, player: PlayerResource = null, level_num: int = 1) -> Array[Location]:
	var result: Array[Location] = []
	if area == null:
		return result

	var seen_ids: Dictionary = {}
	var base_pool: Array[Location] = []
	for b in area.boss:
		if b != null:
			var bid := _location_identity(b)
			if not seen_ids.has(bid):
				seen_ids[bid] = true
				base_pool.append(b)

	base_pool.shuffle()
	var base_limit := clampi(area.max_base_boss_choices, 1, 5)
	var base_count := mini(base_limit, base_pool.size())
	for i in range(base_count):
		result.append(base_pool[i])

	var bonus_added := 0
	var bonus_limit := clampi(area.max_conditional_boss_choices, 0, 2)
	for cond in area.conditional_bosses:
		if bonus_added >= bonus_limit:
			break
		if cond != null and cond.is_met(player, level_num):
			var bonus_loc := cond.boss_location
			if bonus_loc != null:
				var cid := _location_identity(bonus_loc)
				if not seen_ids.has(cid):
					seen_ids[cid] = true
					result.append(bonus_loc)
					bonus_added += 1

	return result


func load_locations_from_directory(locations: LocationLoader) -> void:
	Global.minions_needed = locations.enemy_needed
	enemy_loc_cards = locations.enemy.duplicate(true)
	services_loc_cards = locations.services.duplicate(true)
	event_loc_cards = locations.event.duplicate(true)
	boss_loc_cards = locations.boss.duplicate(true)


func pick_locations(target: Array[Location], enemies_numb: int = 4, event_numb: int = 4, services_numb: int = 2, chosen_boss: Location = null) -> void:
	target.clear()
	if not Locations.enemy_loc_cards.is_empty():
		for i in enemies_numb:
			var loc: Location = Locations.enemy_loc_cards.pick_random()
			target.append(loc)
	if not Locations.event_loc_cards.is_empty():
		for i in event_numb:
			var loc: Location = Locations.event_loc_cards.pick_random()
			target.append(loc)
	if not Locations.services_loc_cards.is_empty():
		for i in services_numb:
			var loc: Location = Locations.services_loc_cards.pick_random()
			target.append(loc)
	if chosen_boss != null:
		Global.area_cur_boss = chosen_boss.duplicate(true)
	elif not Locations.boss_loc_cards.is_empty():
		var loc: Location = Locations.boss_loc_cards.pick_random()
		Global.area_cur_boss = loc
	target.shuffle()


func add_boss_to_locations(target: Array[Location], req: int = 4) -> void:
	if not Global.boss_added and Global.minions_killed >= req and Global.area_cur_boss != null:
		var pick: Location = Global.area_cur_boss
		target.append(pick)
		Global.area_cur_boss = null
		Global.boss_added = true
