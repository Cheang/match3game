extends Resource
class_name PlayerResource
#------------------------------------------------------------------------------#
@export_category("Player Stats")
@export var player_class: String
#------------------------------------------------------------------------------#
@export_group("Health")
@export var max_health: float
@export var cur_health: float 
@export var life_steal: float
#------------------------------------------------------------------------------#
@export_group("Defence")
@export var toughness: float
@export var start_armor: float = 0
@export var start_mage_armor: float = 0
@export var cur_armor: float = 0
@export var cur_mage_armor: float = 0
@export_subgroup("Damage Rediction")
@export var dmg_reduction_flat: float
@export var dmg_reduction: float = 0
@export var max_dmg_reduction: float = 90
#------------------------------------------------------------------------------#
@export_group("Utility")
@export var speed: int
@export var moves_left: int = 0
@export var agility: float
@export var dodging: bool = false
@export var cooldown_reduction: int
@export var start_reroll: int
@export var rerolls: int = 0
@export_subgroup("Gold")
@export var start_gold: int
@export var gold: int = 0
@export_range(0, 100) var gold_chanse: int
#------------------------------------------------------------------------------#
@export_group("Magic")
@export var mana: float 
@export var faith: float
#------------------------------------------------------------------------------#
@export_group("Damage")
@export var strength: float
@export var proficiency: float 
@export var fluf_damage: float
@export_subgroup("Critical")
@export_range(0, 100) var crit_chanse: int 
@export var crit_mutly: float 
@export_subgroup("")
@export var start_hand_combo: float = 0
@export var hand_combo: int = 0
#------------------------------------------------------------------------------#
@export_category("Art")
@export var sprite: PackedScene
#------------------------------------------------------------------------------#
@export_category("Decks")
@export var deck: Array[PackedScene]
var deck_in_game: Array[PieceClass]
@export var fluf: Array[PackedScene]
@export var rewards_piece: Array[Reward]
@export var rewards_passive: Array[Reward]

#Flags
@export var flesh_coruption: bool = false

#Signals
signal updateUIPlayer(stat: String)
signal playerDied
signal playerFinishedTurn

#Functions_____________________________________________________________________#
#Player_functions --------------------------------------------------------------
func take_damage(enemy_damage, piercing: bool = false, type: int = 0):
	if dmg_reduction_flat > 0:
		enemy_damage -= clamp(dmg_reduction_flat, 0, enemy_damage - 1)
	if dmg_reduction > 0:
		enemy_damage = round(enemy_damage * (1 - clamp(dmg_reduction, 0, max_dmg_reduction) / 100.0))
	if dodging and type == 0:
		dodging = false
		enemy_damage = 0
	if cur_mage_armor > 0 and enemy_damage > 0 and !piercing:
		var temp_dmg
		temp_dmg = cur_mage_armor - enemy_damage
		if temp_dmg >= 0:
			cur_mage_armor = temp_dmg
			enemy_damage = 0
		else:
			cur_mage_armor = 0
			enemy_damage = abs(temp_dmg)
	if cur_armor > 0 and enemy_damage > 0:
		var temp_dmg
		temp_dmg = cur_armor - enemy_damage
		if temp_dmg >= 0:
			cur_armor = temp_dmg
			enemy_damage = 0
		else:
			cur_armor = 0
			enemy_damage = abs(temp_dmg)
	if enemy_damage > 0:
		Global.cur_char.add_stat("cur_health",enemy_damage*-1)

func add_stat(stat: String, value):
	if stat in self:
		if stat == "cur_health":
			set(stat, clamp(get(stat)+value, 0, max_health))
			if get(stat) == 0:
				playerDied.emit()
			updateUIPlayer.emit(str(stat))
			return
		
		set(stat, get(stat)+value)
		
		if stat == "moves_left" and get(stat) <= 0:
			playerFinishedTurn.emit()
		updateUIPlayer.emit(str(stat))
	else: 
		print("Stat does not exist: ", stat)

func set_stat(stat: String, value):
	if stat in self:
		if stat == "cur_health":
			set(stat, clamp(value, 0, max_health))
			updateUIPlayer.emit(str(stat))
			return
		
		set(stat, value)
		
		if stat == "moves_left" and get(stat) <= 0:
			playerFinishedTurn.emit()
		updateUIPlayer.emit(str(stat))
	else: 
		print("Stat does not exist: ", stat)

func add_piece(deck_to_add, pieces):
	if deck_to_add and pieces:
		for piece in pieces:
			deck_to_add.append(piece)

func unpack_deck(deck_to_unpack, target):
	for scene in deck_to_unpack:
		if scene and scene is PackedScene:
			var file_path = ResourceLoader.exists(scene.resource_path)
			var instance = scene.instantiate()
			if instance and instance is Node2D:
				if file_path:
					instance.location = scene.resource_path
				target.append(instance)

func reset_stats_at_beging_of_fight():
	set_stat("dodging", false)
	set_stat("moves_left", speed)
	set_stat("hand_combo", start_hand_combo)
	set_stat("cur_armor", start_armor)
	set_stat("cur_mage_armor", start_mage_armor)

func reset_stats_at_the_beging_of_turn():
	set_stat("cur_armor", 0)
	set_stat("hand_combo", start_hand_combo)
	set_stat("moves_left", speed)

func set_stats_at_beging_of_game():
	deck_in_game.clear()
	unpack_deck(deck, deck_in_game)
	set_stat("cur_health", max_health)
	set_stat("gold", start_gold)
	set_stat("rerolls", start_reroll)
