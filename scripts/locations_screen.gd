extends Control

@onready var loc_card_1: location_card = $loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card
@onready var loc_card_2: location_card = $loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card2
@onready var loc_card_3: location_card = $loaction_cards/CenterContainer/VBoxContainer/loc_howder/loc_card3

const LOC_DEADEND = preload("res://locations/loc_deadend.tres")

var loc_cards: Array[location_card] 

func _ready() -> void:
	call_deferred("_initialize_scene")
func _initialize_scene():
	loc_cards = [loc_card_1,loc_card_2,loc_card_3]
	Locations.add_boss_to_locations(Global.area_locations, Global.minions_needed)
	Global.area_locations.shuffle()
	get_locations()
	Global.game_is_played = true

func get_locations():
	for i in range(3):
		if i >= Global.area_locations.size():
			loc_cards[i].loc_res = LOC_DEADEND
			loc_cards[i].load_btn()
		else:
			var location = Global.area_locations[i]
			loc_cards[i].loc_res = location
			loc_cards[i].load_btn()
