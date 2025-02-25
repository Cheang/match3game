extends Resource
class_name PlayerResource
#------------------------------------------------------------------------------#
@export_category("Player Stats")
@export var player_class: String
#------------------------------------------------------------------------------#
@export_group("Health")
@export var max_health: float:
	set(new_max_health):
		var diff = new_max_health - max_health
		max_health = new_max_health
		cur_health += diff
@export var cur_health: float:
	set(new_cur_health):
		cur_health = clamp(new_cur_health, 0, max_health)
		if cur_health <= 0:
			playerDied.emit()
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
@export_range(0, 100) var gold_chance: int
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
@export_range(0, 100) var crit_chance: int:
	set(new_crit_chance):
		crit_chance = clamp(new_crit_chance, 0, 100) 
@export var crit_mutly: float 
@export_subgroup("")
@export var start_hand_combo: int = 0
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

@export_category("Flags")
@export var flg_flesh_coruption: bool = false
@export var flg_can_spawn_col_bombs: bool = false
@export var flg_can_spawn_row_bombs: bool = false
@export var flg_can_spawn_adj_bombs: bool = false
@export var flg_can_spawn_clr_bombs: bool = false
@export_group("Rewards")
@export_subgroup("General")
@export var flg_rew_body_1: bool = false:
	set(value):
		const BODY_1_STRONG_BODY_2 = "res://rewards/pieces/body1_strong_body_2.tres"
		const BODY_1_STRONG_BODY_3 = "res://rewards/pieces/body1_strong_body_3.tres"
		flg_rew_body_1 = flag_setter(flg_rew_body_1, value, [BODY_1_STRONG_BODY_2, BODY_1_STRONG_BODY_3], [])
		flg_rew_fists_irn_body = true
@export var flg_rew_body_2: bool = false:
	set(value):
		const BODY_3_STRONG_BODY_5 = "res://rewards/pieces/body3_strong_body_5.tres"
		flg_rew_body_2 = flag_setter(flg_rew_body_2, value, [BODY_3_STRONG_BODY_5], [])
@export var flg_rew_rush: bool = false:
	set(value):
		const SMOKE_SCREEN = "res://rewards/pieces/general_rush_smoke_screen.tres"
		flg_rew_rush = flag_setter(flg_rew_rush, value, [SMOKE_SCREEN], [])

@export_subgroup("Fists")
@export var flg_rew_fists_lvl_1: bool = false:
	set(value):
		const CRUSHING_FIST = "res://rewards/pieces/fists/fists1-crushing_fist.tres"
		const BLOCK = "res://rewards/pieces/fists/fists1-block.tres"
		const PUNCH = "res://rewards/pieces/fists/fists1-punch.tres"
		const WAY_OF_THE_FISTS = "res://rewards/pieces/fists/fists1-way_of_the_fists.tres"
		
		const WAY_OF_THE_FIST = "res://rewards/pieces/fists/fists0-way_of_the_fist.tres"
		
		flg_rew_fists_lvl_1 = flag_setter(flg_rew_fists_lvl_1, value, [CRUSHING_FIST, BLOCK, PUNCH, WAY_OF_THE_FISTS], [WAY_OF_THE_FIST])
@export var flg_rew_fists_lvl_1_5: bool = false:
	set(value):
		const IRON_MUSCILES = "res://rewards/pieces/fists/fists1_5-iron_musciles.tres"
		const IRON_WILL = "res://rewards/pieces/fists/fists1_5-iron_will.tres"
		
		flg_rew_fists_lvl_1_5 = flag_setter(flg_rew_fists_lvl_1_5, value, [IRON_MUSCILES, IRON_WILL], [])
@export var flg_rew_fists_lvl_1_5_picked: bool = false:
	set(value):
		flg_rew_fists_lvl_1_5_picked = value
		flg_rew_fists_irn_body = true
@export var flg_rew_fists_lvl_2: bool = false:
	set(value):
		const SMALL_SWORD = "res://rewards/pieces/sword/sword0_small_sword.tres"
		const SWORD_PRACTICE = "res://rewards/pieces/sword/sword0-sword_practice.tres"
		flg_rew_fists_lvl_2 = flag_setter(flg_rew_fists_lvl_2, value, [], [SMALL_SWORD, SWORD_PRACTICE])
@export var flg_rew_fists_irn_body: bool = false:
	set(value):
		const BODY_2_STRONG_BODY_4 = "res://rewards/pieces/body2_strong_body_4.tres"
		flg_rew_fists_irn_body = flag_setter(flg_rew_fists_irn_body, value, [BODY_2_STRONG_BODY_4], [], [flg_rew_fists_lvl_1_5_picked,flg_rew_body_1])

#Signals
signal updateUIPlayer(stat: String)
signal playerDied
signal playerFinishedTurn

#Functions_____________________________________________________________________#
#Player_functions --------------------------------------------------------------
func take_damage(enemy_damage, piercing: bool = false, type: int = 0):
	if dodging and type == 0: # Check if dodging (only for physical attacks, type == 0)
		dodging = false
		return
	
	if dmg_reduction_flat > 0: # Apply flat damage reduction
		enemy_damage -= clamp(dmg_reduction_flat, 0, enemy_damage - 1)
	if dmg_reduction > 0: # Apply percentage-based damage reduction
		enemy_damage = round(enemy_damage * (1 - clamp(dmg_reduction, 0, max_dmg_reduction) / 100.0))
	
	if cur_mage_armor > 0 and enemy_damage > 0 and not piercing: # Reduce damage using mage armor (if available and not piercing)
		enemy_damage = apply_armor_reduction(enemy_damage, "cur_mage_armor")
	if cur_armor > 0 and enemy_damage > 0: # Reduce damage using regular armor
		enemy_damage = apply_armor_reduction(enemy_damage, "cur_armor")
	
	if enemy_damage > 0: # Apply remaining damage to health
		modify_stat("cur_health", -enemy_damage)

func modify_stat(stat: String, value, increment: bool = true) -> void:
	if not stat in self:
		print("Stat does not exist:", stat)
		return
	set(stat, get(stat) + value if increment else value)
	# Handle "moves_left" logic
	if stat == "moves_left" and moves_left <= 0:
		playerFinishedTurn.emit()
	updateUIPlayer.emit(stat)

func reset_stats_at_beging_of_game():
	deck_in_game.clear()
	unpack_deck(deck, deck_in_game)
	modify_stat("cur_health", max_health, false)
	modify_stat("gold", start_gold, false)
	modify_stat("rerolls", start_reroll, false)

func reset_stats_at_beging_of_fight():
	modify_stat("dodging", false, false)
	modify_stat("moves_left", speed, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("cur_armor", start_armor, false)
	modify_stat("cur_mage_armor", start_mage_armor, false)

func reset_stats_at_beging_of_turn():
	modify_stat("cur_armor", 0, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("moves_left", speed, false)

#Helper_functions --------------------------------------------------------------
func apply_armor_reduction(damage: int, armor_property: String) -> int:
	var armor_value = get(armor_property)
	var remaining_armor = armor_value - damage
	if remaining_armor >= 0:
		set(armor_property, remaining_armor)
		return 0  # All damage absorbed
	set(armor_property, 0)
	return abs(remaining_armor)  # Return leftover damage

func set_flag(flag: String, value = true):
	if flag in self:
		set(flag, value)
	else: 
		print("Flag does not exists: ", flag)

func flag_setter(flag: bool, value, array_to_add: Array, array_to_remove: Array, req:Array = []) -> bool:
	if flag != value:
		var req_test = 0
		if req.is_empty():
			flag = value
		else:
			for item in req:
				if item == true:
					req_test += 1
			if req_test >= req.size():
				flag = value
		if flag:
			if not array_to_add.is_empty():
				add_to_array(rewards_piece, array_to_add)
			if not array_to_remove.is_empty():
				remove_from_array(rewards_piece, array_to_remove)
		return flag
	return flag

func unpack_deck(deck_to_unpack, target):
	for scene in deck_to_unpack:
		if scene is PackedScene:
			var instance = scene.instantiate()
			if instance is Node2D:
				instance.location = scene.resource_path
				target.append(instance)

func add_to_array(target_array: Array, items: Array):
	for item in items:
		var reward = load(item)
		if reward not in target_array:
			target_array.append(reward)

func remove_from_array(target_array: Array, items: Array):
	for item in items:
		var reward = load(item)
		target_array.erase(reward)
