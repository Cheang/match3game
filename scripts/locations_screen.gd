extends Control

const LOC_DEADEND = preload("res://locations/loc_deadend.tres")

@onready var loc_cards: Array[location_card] = [
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card,
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card2,
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card3
]

func _ready() -> void:
	call_deferred("_initialize_scene")
func _initialize_scene() -> void:
	Locations.add_boss_to_locations(Global.area_locations, Global.minions_needed)
	Global.area_locations.shuffle()
	_set_locations()
	Global.game_is_played = true

func _set_locations() -> void:
	for i in range(loc_cards.size()):
		var location
		if i <  Global.area_locations.size():
			location = Global.area_locations[i]
		else:
			location = LOC_DEADEND
		loc_cards[i].loc_res = location
		loc_cards[i].load_btn()
