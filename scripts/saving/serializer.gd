extends Resource
class_name Serializer

var save_path = "user://save1.tres"

@export var cur_scene: String
@export var cur_char: PlayerResource

@export var settings: SettingsResource
@export var selected_char: PlayerResource

func save_data():
	ResourceSaver.save(self, save_path)

func load_data():
	var data = ResourceLoader.load(save_path, "")
	settings = data.settings
	selected_char = data.selected_char
	cur_scene = data.cur_scene
	cur_char = data.cur_char
