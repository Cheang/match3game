class_name PlayerResource
extends EntityResource

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

## Bonus added directly to reward rarity rolls (0 to 100).
@export var direct_rarity_bonus: int = 0

## Flat bonuses to composite stats
var bonus_luck: float = 0.0
var bonus_magic_find: float = 0.0
var bonus_gold_chance: float = 0.0

## Composite Luck derived from pure sum of Agility + Spirit + bonus_luck.
func get_luck() -> float:
	return agility + spirit + bonus_luck

## Magic Find derived from Luck + bonus_magic_find.
func get_magic_find() -> float:
	return get_luck() + bonus_magic_find

## Total effective Gold Find chance.
func get_gold_find_chance() -> float:
	return float(gold_chance) + (get_luck() * 1.0) + bonus_gold_chance

## Effective Rarity Bonus (Magic Find + direct rarity bonus).
var rarity_bonus: int:
	get:
		return int(roundf(get_magic_find())) + direct_rarity_bonus
	set(val):
		direct_rarity_bonus = val

#------------------------------------------------------------------------------#
@export_category("Loadout & Rewards")
## Active tile colors that can spawn on the combat grid (100=Red, 200=Blue, 300=Green, 400=Purple, 500=White; +1 for Exotic). Minimum 3.
@export var active_color_pool: Array[int] = [100, 200, 300, 500]
## Equipment modifiers automatically slotted into the character's color tracks at the start of a run.
@export var starting_modifiers: Array[Equipment] = []
## Complete list of class-specific rewards (Equipment, Passives, Stat Buffs, Mechanic Unlocks) available to this character.
## The draft system uses a Build-Affinity algorithm to favor rewards matching the player's equipped families.
@export var class_rewards: Array[Resource] = []

var _raw_rewards_piece: Array = []
var _raw_rewards_passive: Array = []

## Pool of combat/equipment/stat/mechanic rewards currently available to be offered to this character after combat.
var rewards_piece: Array:
	get:
		if not active_class_pool.is_empty() or not class_rewards.is_empty():
			return get_active_combat_pool()
		return _raw_rewards_piece
	set(val):
		_raw_rewards_piece = val
		active_class_pool.clear()
		for item in val:
			if item != null:
				active_class_pool.append(item)

## Pool of passive/talent rewards currently available to be offered to this character (e.g. after boss combat).
var rewards_passive: Array:
	get:
		if not active_class_pool.is_empty() or not class_rewards.is_empty():
			return get_active_passive_pool()
		return _raw_rewards_passive
	set(val):
		_raw_rewards_passive = val

#==============================================================================#
# RUNTIME STATE & COMPATIBILITY PROPERTIES (Non-exported to keep Inspector clean)
#==============================================================================#
## Active runtime pool of class rewards for the current run.
var active_class_pool: Array[Resource] = []
## Progression and mechanic tags unlocked during the current run.
var unlocked_tags: Dictionary = {}

## Current reward rerolls remaining in the run.
var rerolls: int = 0
## Current gold carried in the run.
var gold: int = 0

## Unslotted equipment modifiers stored in the player's inventory bag (deprecated: no unequipped inventory storage).
var modifier_inventory: Array[Equipment] = []

## Maximum number of passive/talent cards the player can equip simultaneously.
const MAX_PASSIVE_SLOTS: int = 5
## Currently equipped passive cards (max 5 slots).
var equipped_passives: Array[Resource] = []
var _active_passive_stat_contributions: Dictionary = {}
var _is_recalculating_passive_bonuses: bool = false
signal passivesChanged

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
	base_energy = 2
	might = 2.0
	grit = 3.0
	agility = 2.0
	spirit = 0.0
	base_health = 15.0
	recalculate_max_health()
	cur_health = max_health

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
	
	# Special check for mystic-oriented shields
	if mod.family == "shields" and mod.get_effective_base_mystic_armor() > 0.0:
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
	# No unequipped inventory bag storage: equipment must be equipped to tracks or discarded
	return false

## Replaces the equipment at slot_index in target_track with new_mod.
## Displaced items are discarded (no unequipped inventory storage).
func replace_modifier_on_track(target_track: ColorLoadoutTrack, slot_index: int, new_mod: Equipment) -> bool:
	if target_track == null or new_mod == null:
		return false
	if not target_track.is_color_compatible(new_mod):
		return false
	var base_c: int = get_base_family(target_track.color)
	if not active_color_pool.has(target_track.color) and not active_color_pool.has(base_c):
		add_color_to_pool(base_c)

	var dup_mod: Equipment = new_mod.duplicate(true)
	if slot_index >= 0 and slot_index < target_track.equipped_modifiers.size():
		target_track.unequip_at(slot_index)

	while not target_track.can_equip(dup_mod) and not target_track.equipped_modifiers.is_empty():
		target_track.equipped_modifiers.pop_back()
		target_track.clamp_cursor()

	var ok: bool = target_track.equip_modifier(dup_mod, slot_index)
	target_track.clamp_cursor()
	recalculate_equipment_passives()
	loadoutChanged.emit()
	return ok

func handle_modifier_drop_on_track(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int) -> bool:
	if target_track == null:
		return false
	var dragged_mod: Equipment = drag_data.get("modifier", null)
	if dragged_mod == null or not target_track.is_color_compatible(dragged_mod):
		return false

	var source: String = drag_data.get("source", "")
	var source_track: ColorLoadoutTrack = drag_data.get("source_track", null)
	var source_index: int = drag_data.get("source_index", -1)

	# Reordering within same track
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

	# Moving from another track
	if source == "track" and source_track != null:
		source_track.unequip_modifier(dragged_mod)

	var base_c: int = get_base_family(target_track.color)
	if not active_color_pool.has(target_track.color) and not active_color_pool.has(base_c):
		add_color_to_pool(base_c)

	var insert_pos: int = target_mod_index
	if target_mod_index >= 0 and target_mod_index < target_track.equipped_modifiers.size():
		if not target_track.can_equip(dragged_mod):
			# Displace the item at target_mod_index (discarded, no inventory storage)
			target_track.unequip_at(target_mod_index)

	while not target_track.can_equip(dragged_mod) and not target_track.equipped_modifiers.is_empty():
		# Displace from end until it fits (discarded)
		target_track.equipped_modifiers.pop_back()
		target_track.clamp_cursor()

	if not target_track.equip_modifier(dragged_mod, insert_pos):
		loadoutChanged.emit()
		return false

	loadoutChanged.emit()
	return true

func handle_modifier_drop_on_bag(_drag_data: Dictionary, _target_bag_index: int = -1) -> bool:
	# Inventory bag removed: dropping to bag is disabled
	return false

#==============================================================================#
# PASSIVES SYSTEM (5 SLOTS)
#==============================================================================#

## Returns all currently equipped passive cards.
func get_equipped_passives() -> Array[Resource]:
	return equipped_passives

## Returns true if the player has at least 1 open passive slot (< 5).
func can_equip_passive() -> bool:
	return equipped_passives.size() < MAX_PASSIVE_SLOTS

## Equips a passive card into an open slot or replaces an existing slot (0-4).
## Reconciles stat contributions cleanly with zero stat drift.
func equip_passive(passive: Resource, replace_index: int = -1) -> bool:
	if passive == null:
		return false
	var dup: Resource = passive.duplicate(true)
	if equipped_passives.size() < MAX_PASSIVE_SLOTS:
		if replace_index >= 0 and replace_index < equipped_passives.size():
			equipped_passives[replace_index] = dup
		else:
			equipped_passives.append(dup)
		recalculate_passive_bonuses()
		passivesChanged.emit()
		loadoutChanged.emit()
		return true
	elif replace_index >= 0 and replace_index < MAX_PASSIVE_SLOTS:
		equipped_passives[replace_index] = dup
		recalculate_passive_bonuses()
		passivesChanged.emit()
		loadoutChanged.emit()
		return true
	return false

## Unequips and returns the passive card at slot index, revoking its bonuses.
func unequip_passive(index: int) -> Resource:
	if index >= 0 and index < equipped_passives.size():
		var removed: Resource = equipped_passives.pop_at(index)
		recalculate_passive_bonuses()
		passivesChanged.emit()
		loadoutChanged.emit()
		return removed
	return null

## Recalculates all passive stat boosts and perks from all 5 passive slots.
## Reconciles against previously applied contributions with zero drift.
func recalculate_passive_bonuses() -> void:
	if _is_recalculating_passive_bonuses:
		return
	_is_recalculating_passive_bonuses = true

	var new_totals: Dictionary = {}
	for p_res in equipped_passives:
		if p_res == null:
			continue
		if p_res is Reward:
			var r := p_res as Reward
			var boosts: Dictionary = r.get_stat_boosts()
			for s in boosts.keys():
				new_totals[s] = new_totals.get(s, 0.0) + boosts[s]
			if r.unlock_row_bombs or r.mechanic_type == Reward.MechanicType.ROW_BOMBS:
				set_flag("flg_can_spawn_row_bombs", true)
			if r.unlock_col_bombs or r.mechanic_type == Reward.MechanicType.COL_BOMBS:
				set_flag("flg_can_spawn_col_bombs", true)
			if r.unlock_adj_bombs or r.mechanic_type == Reward.MechanicType.ADJ_BOMBS:
				set_flag("flg_can_spawn_adj_bombs", true)
			if r.unlock_color_bombs or r.mechanic_type == Reward.MechanicType.COLOR_BOMBS:
				set_flag("flg_can_spawn_clr_bombs", true)
			for f in r.get_effective_custom_flags():
				set_flag(f, true)
		elif p_res.has_method("get_stat_boosts"):
			var boosts: Dictionary = p_res.get_stat_boosts()
			for s in boosts.keys():
				new_totals[s] = new_totals.get(s, 0.0) + boosts[s]

	# Reconcile previously applied passive stats
	for s in _active_passive_stat_contributions.keys():
		var old_val = _active_passive_stat_contributions[s]
		var new_val = new_totals.get(s, 0.0)
		var diff = new_val - old_val
		if not is_zero_approx(diff):
			modify_stat(s, diff)

	for s in new_totals.keys():
		if not _active_passive_stat_contributions.has(s):
			var new_val = new_totals[s]
			if not is_zero_approx(new_val):
				modify_stat(s, new_val)

	_active_passive_stat_contributions = new_totals
	_is_recalculating_passive_bonuses = false

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
# CLASS REWARD POOL & BUILD-AFFINITY SYSTEM
#==============================================================================#

## Initializes the runtime class reward pool at the start of a run.
func initialize_class_pool() -> void:
	active_class_pool.clear()
	unlocked_tags.clear()
	for r in class_rewards:
		if r != null:
			active_class_pool.append(r)

## Returns all eligible non-passive rewards from the class pool for standard post-combat drafts.
func get_active_combat_pool() -> Array[Resource]:
	if active_class_pool.is_empty() and not class_rewards.is_empty():
		initialize_class_pool()
	var pool: Array[Resource] = []
	for r in active_class_pool:
		if r == null:
			continue
		if RewardGrantHandler.get_reward_type(r) != Reward.RewardType.PASSIVE:
			if RewardGrantHandler.can_be_offered_to(r, self):
				pool.append(r)
	return pool

## Returns all eligible PASSIVE rewards from the class pool (e.g. for boss drafts).
func get_active_passive_pool() -> Array[Resource]:
	if active_class_pool.is_empty() and not class_rewards.is_empty():
		initialize_class_pool()
	var pool: Array[Resource] = []
	for r in active_class_pool:
		if r == null:
			continue
		if RewardGrantHandler.get_reward_type(r) == Reward.RewardType.PASSIVE:
			if RewardGrantHandler.can_be_offered_to(r, self):
				pool.append(r)
	return pool

## Counts how many items of each family ("fists", "sword", "shields", "mobility", "healing", "body", etc.)
## the player currently has equipped across all color loadout tracks and passive slots.
func get_build_family_counts() -> Dictionary:
	ensure_loadout_tracks()
	var counts: Dictionary = {}
	for k in color_loadouts.keys():
		var track: ColorLoadoutTrack = color_loadouts[k]
		if track != null:
			if track.ultimate_skill != null:
				var u_fam: String = RewardGrantHandler.get_family(track.ultimate_skill)
				if u_fam != "":
					counts[u_fam] = counts.get(u_fam, 0) + 1
			for mod in track.equipped_modifiers:
				if mod != null:
					var m_fam: String = RewardGrantHandler.get_family(mod)
					if m_fam != "":
						counts[m_fam] = counts.get(m_fam, 0) + 1
	for pas in equipped_passives:
		if pas != null:
			var p_fam: String = RewardGrantHandler.get_family(pas)
			if p_fam != "":
				counts[p_fam] = counts.get(p_fam, 0) + 1
	return counts

## Computes the build-affinity weight for a candidate reward based on the player's current build.
func get_reward_affinity_weight(res: Resource) -> float:
	return RewardGrantHandler.compute_selection_weight(res, self, true)

## Called when any reward or direct Equipment is claimed by the player.
func on_reward_chosen(reward: Resource) -> void:
	if reward == null:
		return
	var tpl: Resource = RewardGrantHandler.get_source_template(reward)

	var tags = reward.get("unlock_tags")
	if tags is Array:
		for tag in tags:
			set_flag(str(tag), true)
	if tpl != reward and tpl != null:
		var tpl_tags = tpl.get("unlock_tags")
		if tpl_tags is Array:
			for tag in tpl_tags:
				set_flag(str(tag), true)

	var rem = reward.get("remove_from_pool_when_picked")
	if rem == null and tpl != null:
		rem = tpl.get("remove_from_pool_when_picked")
	if rem == null or rem == true:
		active_class_pool.erase(reward)
		_raw_rewards_piece.erase(reward)
		_raw_rewards_passive.erase(reward)
		if tpl != null:
			active_class_pool.erase(tpl)
			_raw_rewards_piece.erase(tpl)
			_raw_rewards_passive.erase(tpl)
		var id_key: String = RewardGrantHandler.get_identity_key(reward)
		if id_key != "":
			for i in range(active_class_pool.size() - 1, -1, -1):
				if RewardGrantHandler.get_identity_key(active_class_pool[i]) == id_key:
					active_class_pool.remove_at(i)

#==============================================================================#
# COMBAT & LIFECYCLE FUNCTIONS
#==============================================================================#

func reset_stats_at_beginning_of_game() -> void:
	deck_in_game.clear()
	color_loadouts.clear()
	modifier_inventory.clear()
	equipped_passives.clear()
	_active_equipment_stat_contributions.clear()
	_active_passive_stat_contributions.clear()
	ensure_loadout_tracks()
	initialize_class_pool()

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
	super.reset_stats_at_beginning_of_fight()
	recalculate_passive_bonuses()

func reset_stats_at_beginning_of_turn() -> void:
	super.reset_stats_at_beginning_of_turn()

func reset_stats_at_end_of_turn() -> void:
	super.reset_stats_at_end_of_turn()

# Backward-compatibility aliases for legacy typos
func reset_stats_at_beging_of_game() -> void:
	reset_stats_at_beginning_of_game()

func reset_stats_at_beging_of_fight() -> void:
	super.reset_stats_at_beginning_of_fight()

func reset_stats_at_beging_of_turn() -> void:
	super.reset_stats_at_beginning_of_turn()

#==============================================================================#
# HELPER FUNCTIONS
#==============================================================================#

func has_flag(flag: String) -> bool:
	if unlocked_tags.has(flag) and bool(unlocked_tags[flag]):
		return true
	if flag in self:
		return bool(get(flag))
	return false

func set_flag(flag: String, value = true):
	if value:
		unlocked_tags[flag] = true
	else:
		unlocked_tags.erase(flag)
	if flag in self:
		set(flag, value)

func extract_modifier_from_scene(scene: PackedScene) -> Equipment:
	if scene == null:
		return null
	var path: String = scene.resource_path
	const SCENE_TO_MOD_MAP := {
		"res://piece/_red_sq/r_shor_sword.tscn": "res://equipment/items/short_sword.tres",
		"res://piece/_red_sq/r_punch.tscn": "res://equipment/items/punch.tres",
		"res://piece/_red_sq/r_uppercut.tscn": "res://equipment/items/uppercut.tres",
		"res://piece/_blue_sq/b_round_shield.tscn": "res://equipment/items/round_shield.tres",
		"res://piece/_blue_sq/b_iron_shield.tscn": "res://equipment/items/iron_shield.tres",
		"res://piece/_blue_sq/b_block.tscn": "res://equipment/items/block.tres",
		"res://piece/_blue_sq/b_magic_shield.tscn": "res://equipment/items/mystic_shield.tres",
		"res://piece/_green_sq/g_rush.tscn": "res://equipment/items/rush.tres",
		"res://piece/_green_sq/g_dodge.tscn": "res://equipment/items/dodge.tres",
		"res://piece/_purple_sq/p_bandage.tscn": "res://equipment/items/bandage.tres",
		"res://piece/_purple_sq/p_healing_potion_1.tscn": "res://equipment/items/healing_potion.tres",
		"res://piece/_white_sq/w_holy_shield.tscn": "res://equipment/items/holy_shield.tres"
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
