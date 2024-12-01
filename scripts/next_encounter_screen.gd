extends Node2D

@onready var loc_holder: VBoxContainer = $loaction_cards/MarginContainer/VBoxContainer/loc_howder

func _ready() -> void:
	add_random_controls(Global.locations, loc_holder)
	pass

# Function to choose 3 random Controls and add them to the scene
func add_random_controls(control_array: Array, target_node: Node):
	# Ensure there are at least 3 controls to choose from
	if control_array.size() < 3:
		print("Not enough controls in the array to choose from.")
		return
	
	var selected_controls = control_array.duplicate()
	selected_controls.shuffle()
	selected_controls = selected_controls.slice(0, 3)
	for card in selected_controls:
		var instance = card
		target_node.add_child(instance)
