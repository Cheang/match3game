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
	var dir = DirAccess.open(directory_path)  # Create and open the directory
	if dir:
		dir.list_dir_begin()  # Begin listing files in the directory
		var file_name = dir.get_next()  # Get the first file
		# Loop through the files in the directory
		while file_name != "":
			if !dir.current_is_dir():  # Only process files (skip directories)
				# Check if the file is a scene file (.tscn or .scn)
				if file_name.ends_with(".tres"):
					var scene = load(directory_path + "/" + file_name)  # Load the scene as a PackedScene
					if scene is Location:
						target_array.append(scene)  # Add the PackedScene to the array
			file_name = dir.get_next()  # Get the next file
		dir.list_dir_end()  # End the directory listing
	else:
		print("Failed to open directory: %s" % directory_path)
