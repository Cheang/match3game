extends Resource
class_name PlayerResource

#==============================================================================#
# INSPECTOR CONFIGURATION PROPERTIES
#==============================================================================#

@export_category("Character Identity")
## Display name of the character class shown in the UI and checked by class-specific event choices.
@export var player_class: String = "Warrior"
## Character portrait and animation scene instantiated in combat.
@export var sprite: PackedScene

#------------------------------------------------------------------------------#
@export_category("Core Attributes")
## Red Pillar: Increases physical attack damage and scales with fall momentum.
@export var might: float = 1.0
## Blue Pillar: Increases physical armor and magic armor granted by defensive equipment.
@export var grit: float = 0.0
## Green Pillar: Determines base tile swaps (moves) per turn and scales mobility effects.
@export var speed: int = 2
## Purple/White Pillar: Increases healing potency, magic effects, and status scaling.
@export var spirit: float = 0.0

#------------------------------------------------------------------------------#
@export_category("Combat Stats")
@export_group("Health & Sustain")
## Maximum health points the character starts the run with.
@export var max_health: float = 20.0:
	set(new_max_health):
		var diff = new_max_health - max_health
		max_health = new_max_health
		cur_health += diff
## Fraction of physical attack damage restored as health (e.g. 0.25 = 25% lifesteal).
@export var life_steal: float = 0.0

@export_group("Defense & Mitigation")
## Physical armor granted automatically at the start of every battle.
@export var start_armor: float = 0.0
## Magic armor granted automatically at the start of every battle.
@export var start_mage_armor: float = 0.0
## Flat amount of damage subtracted from every incoming enemy hit before percentage reduction.
@export var dmg_reduction_flat: float = 0.0
## Percentage of incoming enemy damage reduced (0% to max_dmg_reduction).
@export var dmg_reduction: float = 0.0
## Upper cap on percentage-based damage reduction (default 90%).
@export var max_dmg_reduction: float = 90.0

@export_group("Critical & Combo")
## Base chance (0% to 100%) for spawned grid tiles to roll as critical strike tiles.
@export_range(0, 100) var crit_chance: int = 5:
	set(new_crit_chance):
		crit_chance = clamp(new_crit_chance, 0, 100)
## Bonus critical damage percentage added when a match includes a critical tile (100.0 = +100% damage).
@export var crit_mutly: float = 100.0
## Starting hand combo points at the beginning of each turn for Fists-family equipment.
@export var start_hand_combo: int = 0
## Baseline damage dealt per matched tile when a color track triggers no equipment modifiers.
@export var fluf_damage: float = 0.0

@export_group("Economy & Utility")
## Flat reduction (in turns) applied to equipment cooldowns when triggered.
@export var cooldown_reduction: int = 0
## Amount of gold the character starts a new run with.
@export var start_gold: int = 100
## Chance (0% to 100%) for a newly spawned grid tile to carry a gold bonus border.
@export_range(0, 100) var gold_chance: int = 1
## Number of reward screen rerolls the character starts a new run with.
@export var start_reroll: int = 1

#------------------------------------------------------------------------------#
@export_category("Loadout & Rewards")
## Active tile colors that can spawn on the combat grid (100=Red, 200=Blue, 300=Green, 400=Purple, 500=White; +1 for Exotic). Minimum 3.
@export var active_color_pool: Array[int] = [100, 200, 300, 500]
## Equipment modifiers automatically slotted into the character's color tracks at the start of a run.
@export var starting_modifiers: Array[Equipment] = []
## Standalone reward tree resource that manages this character class's combat and passive rewards.
@export var reward_tree: RewardTree

var _raw_rewards_piece: Array[Reward] = []
var _raw_rewards_passive: Array[Reward] = []

## Pool of equipment modifier rewards that can be offered to this character after combat.
var rewards_piece: Array[Reward]:
	get:
		if active_reward_tree != null:
			return active_reward_tree.get_combat_pool()
		return _raw_rewards_piece
	set(val):
		_raw_rewards_piece = val

## Pool of passive stat rewards that can be offered to this character after combat.
var rewards_passive: Array[Reward]:
	get:
		if active_reward_tree != null:
			return active_reward_tree.get_passive_pool()
		return _raw_rewards_passive
	set(val):
		_raw_rewards_passive = val

#==============================================================================#
# RUNTIME STATE & COMPATIBILITY PROPERTIES (Non-exported to keep Inspector clean)
#==============================================================================#
var active_reward_tree: RewardTree = null

## Current health points during a run. Clamped between 0 and max_health; emits playerDied at 0.
var cur_health: float = 20.0:
	set(new_cur_health):
		cur_health = clamp(new_cur_health, 0, max_health)
		if cur_health <= 0:
			playerDied.emit()

## Current physical armor during combat. Resets at the start of each player turn.
var cur_armor: float = 0.0
## Current magic armor during combat. Persists across turns within a battle.
var cur_mage_armor: float = 0.0
## Remaining tile swaps (moves) in the current combat turn.
var moves_left: int = 0
## Whether the character will dodge the next incoming physical enemy attack.
var dodging: bool = false
## Current reward rerolls remaining in the run.
var rerolls: int = 0
## Current gold carried in the run.
var gold: int = 0
## Current accumulated hand combo points in the active combat turn.
var hand_combo: int = 0

## Runtime dictionary mapping color ID (int) to its 3-slot ColorLoadoutTrack.
var color_loadouts: Dictionary = {}
## Unslotted equipment modifiers stored in the player's inventory bag.
var modifier_inventory: Array[Equipment] = []

# Legacy Attribute Aliases (maps old stat names used in existing rewards/events to the 4 core pillars)
var strength: float:
	get: return might
	set(v): might = v
var proficiency: float:
	get: return might
	set(v): might = v
var toughness: float:
	get: return grit
	set(v): grit = v
var agility: float:
	get: return float(speed)
	set(v): speed = int(v)
var faith: float:
	get: return spirit
	set(v): spirit = v
var mana: float:
	get: return spirit
	set(v): spirit = v

# Legacy Deck & Progression Flags (retained internally for reward tree & save compatibility)
var deck: Array[PackedScene] = []
var deck_in_game: Array[PieceClass] = []
var fluf: Array[PackedScene] = []

var flg_flesh_coruption: bool = false
var flg_can_spawn_col_bombs: bool = false
var flg_can_spawn_row_bombs: bool = false
var flg_can_spawn_adj_bombs: bool = false
var flg_can_spawn_clr_bombs: bool = false

var flg_rew_body_1: bool = false
var flg_rew_body_2: bool = false
var flg_rew_rush: bool = false
var flg_rew_fists_lvl_1: bool = false
var flg_rew_fists_lvl_1_5: bool = false
var flg_rew_fists_lvl_1_5_picked: bool = false
var flg_rew_fists_lvl_2: bool = false
var flg_rew_fists_irn_body: bool = false

#------------------------------------------------------------------------------#
# Signals
signal updateUIPlayer(stat: String)
signal loadoutChanged
signal playerDied
signal playerFinishedTurn

#==============================================================================#
# COLOR POOL & LOADOUT FUNCTIONS
#==============================================================================#

func ensure_loadout_tracks() -> void:
	if active_color_pool.size() < 3:
		active_color_pool = [100, 200, 300, 500]
	for c in active_color_pool:
		var base_c: int = get_base_family(c)
		if not color_loadouts.has(c) and not color_loadouts.has(base_c):
			var track := ColorLoadoutTrack.new()
			track.color = c
			track.max_slots = 3
			color_loadouts[c] = track

func get_track_for_color(color_id: int) -> ColorLoadoutTrack:
	ensure_loadout_tracks()
	if color_loadouts.has(color_id):
		return color_loadouts[color_id]
	var base_c: int = get_base_family(color_id)
	if color_loadouts.has(base_c):
		return color_loadouts[base_c]
	for k in color_loadouts.keys():
		if get_base_family(int(k)) == base_c:
			return color_loadouts[k]
	var new_track := ColorLoadoutTrack.new()
	new_track.color = base_c
	new_track.max_slots = 3
	color_loadouts[base_c] = new_track
	return new_track

func add_color_to_pool(new_color: int) -> void:
	if not active_color_pool.has(new_color):
		active_color_pool.append(new_color)
	if not color_loadouts.has(new_color):
		var track := ColorLoadoutTrack.new()
		track.color = new_color
		track.max_slots = 3
		color_loadouts[new_color] = track
	loadoutChanged.emit()

func remove_color_from_pool(target_color: int) -> bool:
	if active_color_pool.size() <= 3:
		return false
	if not active_color_pool.has(target_color):
		return false
	active_color_pool.erase(target_color)
	if color_loadouts.has(target_color):
		var track: ColorLoadoutTrack = color_loadouts[target_color]
		for mod in track.equipped_modifiers:
			if mod != null:
				modifier_inventory.append(mod)
		color_loadouts.erase(target_color)
	loadoutChanged.emit()
	return true

func transmute_color(old_color: int, exotic_color: int) -> void:
	var idx: int = active_color_pool.find(old_color)
	if idx != -1:
		active_color_pool[idx] = exotic_color
	elif not active_color_pool.has(exotic_color):
		active_color_pool.append(exotic_color)

	if color_loadouts.has(old_color):
		var track: ColorLoadoutTrack = color_loadouts[old_color]
		track.color = exotic_color
		color_loadouts.erase(old_color)
		color_loadouts[exotic_color] = track
	elif not color_loadouts.has(exotic_color):
		var track := ColorLoadoutTrack.new()
		track.color = exotic_color
		track.max_slots = 3
		color_loadouts[exotic_color] = track
	loadoutChanged.emit()

func is_exotic_color(color: int) -> bool:
	return (int(color) % 100) != 0

func get_base_family(color: int) -> int:
	return int(color / 100) * 100

func _get_preferred_auto_equip_color(mod: Equipment) -> int:
	if mod == null:
		return 100
	if not mod.is_colorless():
		return mod.bound_color if mod.bound_color >= 100 else mod.allowed_colors[0]
	
	# Special check for magic-oriented shields
	if mod.family == "shields" and mod.base_magic_armor > 0.0:
		return 500 if active_color_pool.has(500) else 200

	# Query the central registry in Global
	var mapped_color: int = Global.get_family_default_color(mod.family)
	if mapped_color != 0 and active_color_pool.has(mapped_color):
		return mapped_color

	return active_color_pool[0] if not active_color_pool.is_empty() else 100

func add_modifier_reward(mod: Equipment, auto_equip: bool = false) -> bool:
	if mod == null:
		return false
	var dup_mod: Equipment = mod.duplicate(true)
	ensure_loadout_tracks()
	if auto_equip:
		var pref_c: int = _get_preferred_auto_equip_color(dup_mod)
		var candidate_colors: Array[int] = [pref_c]
		for c in dup_mod.get_effective_allowed_colors():
			if not candidate_colors.has(c):
				candidate_colors.append(c)
		for c in candidate_colors:
			var track: ColorLoadoutTrack = get_track_for_color(c)
			if track != null and track.can_equip(dup_mod):
				if not active_color_pool.has(c) and not active_color_pool.has(get_base_family(c)):
					add_color_to_pool(get_base_family(c))
				track.equip_modifier(dup_mod)
				loadoutChanged.emit()
				return true
	modifier_inventory.append(dup_mod)
	loadoutChanged.emit()
	return false

func handle_modifier_drop_on_track(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> bool:
	if target_track == null:
		return false
	var dragged_mod: Equipment = drag_data.get("modifier", null)
	if dragged_mod == null or not target_track.is_color_compatible(dragged_mod):
		return false

	var source: String = drag_data.get("source", "")
	var source_track: ColorLoadoutTrack = drag_data.get("source_track", null)
	var source_index: int = drag_data.get("source_index", -1)
	var bag_index: int = drag_data.get("bag_index", -1)

	if source == "track" and source_track == target_track:
		if source_index < 0 or source_index >= target_track.equipped_modifiers.size():
			return false
		if target_mod_index == source_index:
			return true
		target_track.equipped_modifiers.remove_at(source_index)
		if target_mod_index >= 0 and target_mod_index <= target_track.equipped_modifiers.size():
			target_track.equipped_modifiers.insert(target_mod_index, dragged_mod)
		else:
			target_track.equipped_modifiers.append(dragged_mod)
		loadoutChanged.emit()
		return true

	if source == "track" and source_track != null:
		source_track.unequip_modifier(dragged_mod)
	elif source == "bag":
		if bag_index >= 0 and bag_index < modifier_inventory.size() and modifier_inventory[bag_index] == dragged_mod:
			modifier_inventory.remove_at(bag_index)
		else:
			modifier_inventory.erase(dragged_mod)

	var base_c: int = get_base_family(target_track.color)
	if not active_color_pool.has(target_track.color) and not active_color_pool.has(base_c):
		add_color_to_pool(base_c)

	var insert_pos: int = target_mod_index
	if target_mod_index >= 0 and target_mod_index < target_track.equipped_modifiers.size():
		if not target_track.can_equip(dragged_mod):
			var displaced: Equipment = target_track.unequip_at(target_mod_index)
			if displaced != null:
				modifier_inventory.append(displaced)

	while not target_track.can_equip(dragged_mod) and not target_track.equipped_modifiers.is_empty():
		var displaced_end: Equipment = target_track.equipped_modifiers.pop_back()
		if displaced_end != null:
			modifier_inventory.append(displaced_end)

	if not target_track.equip_modifier(dragged_mod, insert_pos):
		modifier_inventory.append(dragged_mod)
		loadoutChanged.emit()
		return false

	loadoutChanged.emit()
	return true

func handle_modifier_drop_on_bag(drag_data: Dictionary, target_bag_index: int = -1) -> bool:
	var dragged_mod: Equipment = drag_data.get("modifier", null)
	if dragged_mod == null:
		return false
	var source: String = drag_data.get("source", "")
	var source_track: ColorLoadoutTrack = drag_data.get("source_track", null)
	var bag_index: int = drag_data.get("bag_index", -1)

	if source == "track" and source_track != null:
		source_track.unequip_modifier(dragged_mod)
		if target_bag_index >= 0 and target_bag_index <= modifier_inventory.size():
			modifier_inventory.insert(target_bag_index, dragged_mod)
		else:
			modifier_inventory.append(dragged_mod)
		loadoutChanged.emit()
		return true
	elif source == "bag":
		if bag_index >= 0 and bag_index < modifier_inventory.size():
			modifier_inventory.remove_at(bag_index)
		else:
			modifier_inventory.erase(dragged_mod)
		if target_bag_index >= 0 and target_bag_index <= modifier_inventory.size():
			modifier_inventory.insert(target_bag_index, dragged_mod)
		else:
			modifier_inventory.append(dragged_mod)
		loadoutChanged.emit()
		return true
	elif source == "pickup":
		if target_bag_index >= 0 and target_bag_index <= modifier_inventory.size():
			modifier_inventory.insert(target_bag_index, dragged_mod)
		else:
			modifier_inventory.append(dragged_mod)
		loadoutChanged.emit()
		return true
	return false

func get_all_owned_modifiers() -> Array[Equipment]:
	ensure_loadout_tracks()
	var list: Array[Equipment] = []
	for k in color_loadouts.keys():
		var track: ColorLoadoutTrack = color_loadouts[k]
		if track != null:
			for m in track.equipped_modifiers:
				if m != null:
					list.append(m)
	for m in modifier_inventory:
		if m != null:
			list.append(m)
	return list

func reset_modifiers_for_battle() -> void:
	ensure_loadout_tracks()
	for k in color_loadouts.keys():
		var track: ColorLoadoutTrack = color_loadouts[k]
		if track != null:
			track.reset_for_battle()
	for mod in modifier_inventory:
		if mod != null:
			mod.reset_for_battle()

#==============================================================================#
# COMBAT & LIFECYCLE FUNCTIONS
#==============================================================================#

func take_damage(enemy_damage, piercing: bool = false, type: int = 0):
	if dodging and type == 0:
		dodging = false
		updateUIPlayer.emit("dodging")
		return

	if dmg_reduction_flat > 0:
		enemy_damage -= clamp(dmg_reduction_flat, 0, enemy_damage - 1)
	if dmg_reduction > 0:
		enemy_damage = round(enemy_damage * (1 - clamp(dmg_reduction, 0, max_dmg_reduction) / 100.0))

	if cur_mage_armor > 0 and enemy_damage > 0 and not piercing:
		enemy_damage = apply_armor_reduction(enemy_damage, "cur_mage_armor")
	if cur_armor > 0 and enemy_damage > 0:
		enemy_damage = apply_armor_reduction(enemy_damage, "cur_armor")

	if enemy_damage > 0:
		modify_stat("cur_health", -enemy_damage)

func modify_stat(stat: String, value, increment: bool = true) -> void:
	if not stat in self:
		print("Stat does not exist:", stat)
		return
	set(stat, get(stat) + value if increment else value)
	if stat == "moves_left" and moves_left <= 0:
		playerFinishedTurn.emit()
	updateUIPlayer.emit(stat)

func reset_stats_at_beginning_of_game() -> void:
	deck_in_game.clear()
	color_loadouts.clear()
	modifier_inventory.clear()
	ensure_loadout_tracks()

	if reward_tree != null:
		active_reward_tree = reward_tree.duplicate(true)
		active_reward_tree.initialize_run(self)

	if not starting_modifiers.is_empty():
		for mod in starting_modifiers:
			if mod != null:
				add_modifier_reward(mod, true)
	elif not deck.is_empty():
		unpack_deck(deck, deck_in_game)

	modify_stat("cur_health", max_health, false)
	modify_stat("gold", start_gold, false)
	modify_stat("rerolls", start_reroll, false)

func reset_stats_at_beginning_of_fight() -> void:
	reset_modifiers_for_battle()
	modify_stat("dodging", false, false)
	modify_stat("moves_left", speed, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("cur_armor", start_armor, false)
	modify_stat("cur_mage_armor", start_mage_armor, false)

func reset_stats_at_beginning_of_turn() -> void:
	ensure_loadout_tracks()
	for k in color_loadouts.keys():
		var track: ColorLoadoutTrack = color_loadouts[k]
		if track != null:
			track.tick_cooldowns(1)
	modify_stat("cur_armor", 0, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("moves_left", speed, false)
	loadoutChanged.emit()

# Backward-compatibility aliases for legacy typos
func reset_stats_at_beging_of_game() -> void:
	reset_stats_at_beginning_of_game()

func reset_stats_at_beging_of_fight() -> void:
	reset_stats_at_beginning_of_fight()

func reset_stats_at_beging_of_turn() -> void:
	reset_stats_at_beginning_of_turn()

#==============================================================================#
# HELPER FUNCTIONS
#==============================================================================#

func apply_armor_reduction(damage: float, armor_property: String) -> float:
	var armor_value = get(armor_property)
	var remaining_armor = armor_value - damage
	if remaining_armor >= 0:
		set(armor_property, remaining_armor)
		updateUIPlayer.emit(armor_property)
		return 0.0
	set(armor_property, 0)
	updateUIPlayer.emit(armor_property)
	return abs(remaining_armor)

func set_flag(flag: String, value = true):
	if active_reward_tree != null and value:
		active_reward_tree.unlocked_tags[flag] = true
		active_reward_tree.check_progression()
	if flag in self:
		set(flag, value)

func extract_modifier_from_scene(scene: PackedScene) -> Equipment:
	if scene == null:
		return null
	var path: String = scene.resource_path
	const SCENE_TO_MOD_MAP := {
		"res://piece/_red_sq/r_shor_sword.tscn": "res://tiles/equipment/short_sword.tres",
		"res://piece/_red_sq/r_punch.tscn": "res://tiles/equipment/punch.tres",
		"res://piece/_red_sq/r_uppercut.tscn": "res://tiles/equipment/uppercut.tres",
		"res://piece/_blue_sq/b_round_shield.tscn": "res://tiles/equipment/round_shield.tres",
		"res://piece/_blue_sq/b_iron_shield.tscn": "res://tiles/equipment/iron_shield.tres",
		"res://piece/_blue_sq/b_block.tscn": "res://tiles/equipment/block.tres",
		"res://piece/_blue_sq/b_magic_shield.tscn": "res://tiles/equipment/magic_shield.tres",
		"res://piece/_green_sq/g_rush.tscn": "res://tiles/equipment/rush.tres",
		"res://piece/_green_sq/g_dodge.tscn": "res://tiles/equipment/dodge.tres",
		"res://piece/_purple_sq/p_bandage.tscn": "res://tiles/equipment/bandage.tres",
		"res://piece/_purple_sq/p_healing_potion_1.tscn": "res://tiles/equipment/healing_potion.tres",
		"res://piece/_white_sq/w_holy_shield.tscn": "res://tiles/equipment/holy_shield.tres"
	}
	if SCENE_TO_MOD_MAP.has(path) and ResourceLoader.exists(SCENE_TO_MOD_MAP[path]):
		var res = load(SCENE_TO_MOD_MAP[path])
		if res is Equipment:
			return res.duplicate(true)

	var instance = scene.instantiate()
	var extracted: Equipment = null
	if instance is PieceClass and not instance.action.is_empty() and instance.action[0] != null:
		extracted = instance.action[0].duplicate(true)
		if extracted.piece_name == "":
			extracted.piece_name = instance.piece_name
		if extracted.icon == null:
			extracted.icon = instance.icon_texture
		if extracted.description == "":
			extracted.description = instance.description
		if extracted.family == "":
			extracted.family = instance.family
		extracted.bound_color = 0
		extracted.allowed_colors = []
	if instance != null:
		instance.queue_free()
	return extracted

func unpack_deck(deck_to_unpack, _target = null):
	ensure_loadout_tracks()
	for item in deck_to_unpack:
		if item is Equipment:
			add_modifier_reward(item, true)
		elif item is PackedScene:
			var mod: Equipment = extract_modifier_from_scene(item)
			if mod != null:
				add_modifier_reward(mod, true)
