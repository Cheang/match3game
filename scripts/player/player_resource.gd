extends Resource
class_name PlayerResource

#Health & Armor
@export_group("Health")
@export var max_health: float
@export var life_steal: float
@export var start_armor: float
@export var start_mage_armor: float

#Utility
@export_group("Utility")
@export var speed: int
@export var cooldown_reduction: int

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

#Art
@export_group("Art")
@export var sprite: PackedScene

#Stats that change in-game
var cur_health: float = max_health
var armor: float 
var mage_armor: float 
var moves_left: int = 0





func take_damage(enemy_damage, piercing: bool = false):
	if !piercing:
		var temp
		temp = armor - enemy_damage 
		if temp >= 0:
			armor = temp
		else:
			armor = 0
			temp = mage_armor + temp
			if temp >= 0:
				mage_armor = temp
			else:
				mage_armor = 0
				cur_health += temp
	else:
		var temp
		temp = mage_armor - enemy_damage
		if temp >= 0:
			mage_armor = temp
		else:
			mage_armor = 0
			cur_health += temp
