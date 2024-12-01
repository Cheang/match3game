extends Node2D

@onready var loc_holder: VBoxContainer = $loaction_cards/MarginContainer/VBoxContainer/loc_howder

func _ready() -> void:
	add_random_cards(Global.locations, loc_holder)
	pass

func add_random_cards(control_array: Array, target_node: Node):
	if control_array.size() < 3:
		print("Not enough controls in the array to choose from.")
		return
	control_array.shuffle()
	for i in 3:
		var instance = control_array.pop_back()
		target_node.add_child(instance)
