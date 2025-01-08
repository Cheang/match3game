extends Resource
class_name PlayerResource

#Health & Armor
@export_group("Health")
@export var max_health: float
@export var life_steal: float

@export_group("Defence")
@export var toughness: float
@export var dmg_reduction: float
@export var start_armor: float = 0
@export var start_mage_armor: float = 0

#Utility
@export_group("Utility")
@export var speed: int
@export var cooldown_reduction: int
@export var start_gold: int
@export_range(0, 100) var gold_chanse: int
@export var start_reroll: int

#Magic
@export_group("Magic")
@export var mana: float 
@export var faith: float

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
@export var player_class: String
@export var sprite: PackedScene

#Stats that change in-game
var deck_in_game: Array[PieceClass]
var cur_health: float 
var dodging: bool = false
var cur_armor: float = 0
var cur_mage_armor: float = 0
var moves_left: int = 0
var gold: int = 0
var rerolls: int = 0
var hand_combo: int = 0
var flesh_coruption: bool = false


func take_damage(enemy_damage, piercing: bool = false):
	enemy_damage -= dmg_reduction
	if dodging:
		dodging = false
		return
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
	if deck_to_add and pieces:
		for piece in pieces:
			deck_to_add.append(piece)

func unpack_deck(deck_to_unpack, target):
	for scene in deck_to_unpack:
		if scene and scene is PackedScene:
			var instance = scene.instantiate()
			if instance and instance is Node2D:
				target.append(instance)

func reset_stats_at_beging_of_fight():
	dodging = false
	moves_left = speed
	hand_combo = 0
	cur_armor = start_armor
	cur_mage_armor = start_mage_armor

func reset_stats_at_the_beging_of_turn():
	cur_armor = 0
	hand_combo = 0
	moves_left = speed

func set_stats_at_beging_of_game():
	deck_in_game.clear()
	unpack_deck(deck, deck_in_game)
	set_cur_health(max_health)
	gold = start_gold
	rerolls = start_reroll

func set_cur_health(value: float):
	cur_health = clamp(value, 0, max_health)
