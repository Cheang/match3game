extends Node

var enemy_dir: String = "res://locations/enemie_encounters"
var enemy_loc_cards: Array[PackedScene] 
var services_dir: String = "res://locations/services_encounters"
var services_loc_cards: Array[PackedScene] 
var event_dir: String = "res://locations/event_encounters"
var event_loc_cards: Array[PackedScene] 
var boss_dir: String = "res://locations/boss_encounters"
var boss_loc_cards: Array[PackedScene] 

func _ready() -> void:
	load_scenes_from_directory(enemy_dir, enemy_loc_cards)
	load_scenes_from_directory(services_dir, services_loc_cards)
	load_scenes_from_directory(event_dir, event_loc_cards)
	load_scenes_from_directory(boss_dir, boss_loc_cards)


func load_scenes_from_directory(directory_path: String, target_array:Array[PackedScene]) -> void:
	var dir = DirAccess.open(directory_path)  # Create and open the directory
	if dir:
		dir.list_dir_begin()  # Begin listing files in the directory
		var file_name = dir.get_next()  # Get the first file
		# Loop through the files in the directory
		while file_name != "":
			if !dir.current_is_dir():  # Only process files (skip directories)
				# Check if the file is a scene file (.tscn or .scn)
				if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
					var scene = load(directory_path + "/" + file_name)  # Load the scene as a PackedScene
					if scene is PackedScene:
						target_array.append(scene)  # Add the PackedScene to the array
			file_name = dir.get_next()  # Get the next file
		dir.list_dir_end()  # End the directory listing
	else:
		print("Failed to open directory: %s" % directory_path)
