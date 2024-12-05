extends Node2D

@onready var loc_card_1: location_card = $loaction_cards/MarginContainer/VBoxContainer/loc_howder/loc_card
@onready var loc_card_2: location_card = $loaction_cards/MarginContainer/VBoxContainer/loc_howder/loc_card2
@onready var loc_card_3: location_card = $loaction_cards/MarginContainer/VBoxContainer/loc_howder/loc_card3

const LOC_DEADEND = preload("res://locations/loc_deadend.tres")

var loc_cards: Array[location_card] 

func _ready() -> void:
	loc_cards = [loc_card_1,loc_card_2,loc_card_3]
	Locations.add_boss_to_locations(Global.locations, Global.minions_needed)
	get_locations()


func get_locations():
	for i in range(3):
		if i >= Global.locations.size():
			loc_cards[i].loc_res = LOC_DEADEND
			loc_cards[i].load_btn()
		else:
			var location = Global.locations[i]
			loc_cards[i].loc_res = location
			loc_cards[i].load_btn()
