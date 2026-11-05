extends EntityResource
class_name PlayerResource

#==============================================================================#
# INSPECTOR CONFIGURATION PROPERTIES
#==============================================================================#

@export_category("Character Identity")
## Display name of the character class shown in the UI and checked by class-specific event choices.
@export var player_class: String = "Warrior"

@export_category("Combat Stats")
@export_group("Economy & Utility")
## Amount of gold the character starts a new run with.
@export var start_gold: int = 100
## Chance (0% to 100%) for a newly spawned grid tile to carry a gold bonus border.
@export_range(0, 100) var gold_chance: int = 1
## Number of reward screen rerolls the character starts a new run with.
@export var start_reroll: int = 1
## Bonus added to reward rarity rolls (0 to 100).
@export var rarity_bonus: int = 0

#------------------------------------------------------------------------------#
@export_category("Loadout & Rewards")
## Active tile colors that can spawn on the combat grid (100=Red, 200=Blue, 300=Green, 400=Purple, 500=White; +1 for Exotic). Minimum 3.
@export var active_color_pool: Array[int] = [100, 200, 300, 500]
## Equipment modifiers automatically slotted into the character's color tracks at the start of a run.
@export var starting_modifiers: Array[Equipment] = []
## Standalone reward tree resource that manages this character class's combat and passive rewards.
@export var reward_tree: RewardTree

var _raw_rewards_piece: Array = []
var _raw_rewards_passive: Array = []

## Pool of combat/equipment rewards that can be offered to this character after combat.
var rewards_piece: Array:
	get:
		if active_reward_tree != null:
			return active_reward_tree.get_combat_pool()
		return _raw_rewards_piece
	set(val):
		_raw_rewards_piece = val

## Pool of passive/talent rewards that can be offered to this character after combat.
var rewards_passive: Array:
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

## Current reward rerolls remaining in the run.
var rerolls: int = 0
## Current gold carried in the run.
var gold: int = 0

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
# Legacy Player-Specific Signals (bridged from EntityResource)
signal updateUIPlayer(stat: String)
signal playerDied
signal playerFinishedTurn

func _init() -> void:
	super._init()
	agility = 2

func _on_entity_died() -> void:
	super._on_entity_died()
	playerDied.emit()

func _on_stat_modified(stat: String) -> void:
	updateUIPlayer.emit(stat)

func _on_moves_exhausted() -> void:
	super._on_moves_exhausted()
	playerFinishedTurn.emit()

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
			track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
			color_loadouts[c] = track

func get_track_for_color(color_id: int) -> ColorLoadoutTrack:
	var found: ColorLoadoutTrack = super.get_track_for_color(color_id)
	if found != null:
		return found
	var base_c: int = get_base_family(color_id)
	var new_track := ColorLoadoutTrack.new()
	new_track.color = base_c
	new_track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
	color_loadouts[base_c] = new_track
	return new_track

func add_color_to_pool(new_color: int) -> void:
	if not active_color_pool.has(new_color):
		active_color_pool.append(new_color)
	if not color_loadouts.has(new_color):
		var track := ColorLoadoutTrack.new()
		track.color = new_color
		track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
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
		if track.ultimate_skill != null:
			modifier_inventory.append(track.ultimate_skill)
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
		track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
		color_loadouts[exotic_color] = track
	loadoutChanged.emit()

func _get_preferred_auto_equip_color(mod: Equipment) -> int:
	if mod == null:
		return 100
	if not mod.is_colorless():
		return mod.bound_color if mod.bound_color >= 100 else mod.allowed_colors[0]
	
	# Special check for magic-oriented shields
	if mod.family == "shields" and mod.get_effective_base_magic_armor() > 0.0:
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
		target_track.clamp_cursor()
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
		target_track.clamp_cursor()

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
			if track.ultimate_skill != null:
				list.append(track.ultimate_skill)
			for m in track.equipped_modifiers:
				if m != null:
					list.append(m)
	for m in modifier_inventory:
		if m != null:
			list.append(m)
	return list

func reset_modifiers_for_battle() -> void:
	super.reset_modifiers_for_battle()
	for mod in modifier_inventory:
		if mod != null:
			mod.reset_for_battle()

#==============================================================================#
# COMBAT & LIFECYCLE FUNCTIONS
#==============================================================================#

func reset_stats_at_beginning_of_game() -> void:
	deck_in_game.clear()
	color_loadouts.clear()
	modifier_inventory.clear()
	_active_equipment_stat_contributions.clear()
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
	clear_all_buffs()
	modify_stat("dodging", false, false)
	modify_stat("moves_left", max_energy, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("cur_armor", start_armor, false)
	modify_stat("cur_mage_armor", start_mage_armor, false)

func reset_stats_at_beginning_of_turn() -> void:
	tick_all_track_cooldowns(1)
	tick_buffs_at_turn_start()
	modify_stat("cur_armor", 0, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("moves_left", max_energy, false)
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
