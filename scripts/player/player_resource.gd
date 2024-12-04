extends Resource
class_name PlayerResource

#Health & Armor
@export_group("Health")
@export var max_health: float
@export var life_steal: float
@export var dmg_reduction: float
@export var start_armor: float
@export var start_mage_armor: float

#Utility
@export_group("Utility")
@export var speed: int
@export var cooldown_reduction: int
@export var start_gold: int
@export var start_reroll: int

#Magic
@export_group("Magic")
@export var mana: float 

#Damage
@export_group("Damage")
@export var dmg: float 
@export var fluf_dmg: float 
@export_range(0, 100) var crit_chanse: int 
@export var crit_dmg: float 

#Decks
@export_group("Decks")
@export var deck: Array[PackedScene]
@export var fluf: Array[PackedScene]
@export var rewards_piece: Array[Reward]
@export var rewards_passive: Array[Reward]

#Art
@export_group("Art")
@export var sprite: PackedScene

#Stats that change in-game
var cur_health: float = max_health
var cur_armor: float 
var cur_mage_armor: float 
var moves_left: int = 0
var gold: int = 0
var rerolls: int = 0


func take_damage(enemy_damage, piercing: bool = false):
	enemy_damage -= dmg_reduction
	if !piercing:
		var temp
		temp = cur_mage_armor - enemy_damage 
		if temp >= 0:
			cur_mage_armor = temp
		else:
			cur_mage_armor = 0
			temp = cur_armor + temp
			if temp >= 0:
				cur_armor = temp
			else:
				cur_armor = 0
				cur_health += temp
	else:
		var temp
		temp = cur_mage_armor - enemy_damage
		if temp >= 0:
			cur_mage_armor = temp
		else:
			cur_mage_armor = 0
			cur_health += temp

func add_piece(deck_to_add, pieces):
	if deck_to_add != null and pieces != null:
		for piece in pieces:
			deck_to_add.append(piece)
