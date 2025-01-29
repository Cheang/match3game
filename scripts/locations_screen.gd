extends Control

const LOC_DEADEND = preload("res://locations/loc_deadend.tres")

@onready var loc_cards: Array[location_card] = [
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card,
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card2,
	$loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card3
]

func _ready() -> void:
	call_deferred("initialize_scene")
	
func initialize_scene() -> void:
	Locations.add_boss_to_locations(Global.area_locations, Global.minions_needed)
	shuffle_areas()
	_set_locations()
	Global.save()
	Global.game_is_played = true

func _set_locations() -> void:
	for i in loc_cards.size():
		loc_cards[i].loc_res = Global.area_locations[i] if i < Global.area_locations.size() else LOC_DEADEND
		loc_cards[i].load_btn()

func shuffle_areas() -> void:
	if !Global.flg_game_is_loaded:
		Global.area_locations.shuffle()
	else:
		Global.flg_game_is_loaded = false
