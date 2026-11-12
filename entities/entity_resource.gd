class_name EntityResource
extends Resource

const BuffRegistryRef = preload("res://combat/buff_registry.gd")

#==============================================================================#
# SHARED ENTITY FOUNDATION (Player & Monster Common Contract)
#==============================================================================#

@export_category("Entity Identity & Art")
## Character or monster portrait/animation scene instantiated in combat.
@export var sprite: PackedScene

#------------------------------------------------------------------------------#
@export_category("Core Attributes")
## Red Pillar: Increases physical attack damage and scales with fall momentum.
@export var might: float = 1.0:
	set(new_might):
		might = new_might
		recalculate_max_health()

## Blue Pillar: Increases physical armor and magic armor granted by defensive equipment.
@export var grit: float = 0.0:
	set(new_grit):
		grit = new_grit
		recalculate_max_health()

## Green Pillar: Determines base actions / energy per turn and scales mobility effects.
@export var agility: float = 1.0:
	set(new_val):
		agility = new_val
		moves_left = clamp(moves_left, 0, max_energy)

## Purple/White Pillar: Increases healing potency, magic effects, and status scaling.
@export var spirit: float = 0.0

## Base energy (moves per turn) before Agility scaling. Players default to 2; enemies default to 1.
@export var base_energy: int = 2
## Flat bonus to max energy.
var bonus_energy: float = 0.0

## Maximum energy (actions / moves per turn), derived from Agility with a hard floor of 1.
## Formula: Base Energy + 1 for every 5 Agility + bonus_energy, clamped with minimum 1.
var max_energy: int:
	get: return get_max_energy()

func get_max_energy() -> int:
	return max(1, base_energy + int(floor(agility / 5.0)) + int(roundf(bonus_energy)))

#------------------------------------------------------------------------------#
@export_category("Combat Stats")
@export_group("Health & Sustain")
## Base health before Might, Grit, and bonus health scaling.
@export var base_health: float = 15.0
## Direct flat bonus to max health from gear, passives, or stat buffs.
var bonus_max_health: float = 0.0
var _is_recalculating_hp: bool = false

## Maximum health points.
@export var max_health: float = 20.0:
	set(new_max_health):
		var diff = new_max_health - max_health
		max_health = new_max_health
		cur_health += diff
		cur_mystic_armor = clampf(cur_mystic_armor, 0.0, max(0.0, max_health))
		if not _is_recalculating_hp:
			bonus_max_health = max_health - (base_health + (might * 1.0) + (grit * 2.0))

func get_derived_max_health() -> float:
	return base_health + (might * 1.0) + (grit * 2.0) + bonus_max_health

func recalculate_max_health() -> void:
	if _is_recalculating_hp:
		return
	_is_recalculating_hp = true
	var target_max: float = get_derived_max_health()
	if not is_equal_approx(max_health, target_max):
		max_health = target_max
	_is_recalculating_hp = false

## Fraction of attack damage restored as health (e.g. 0.25 = 25% lifesteal).
@export var life_steal: float = 0.0

@export_group("Defense & Mitigation")
## Physical armor granted automatically at the start of every battle.
@export var start_armor: float = 0.0
## Mystic armor granted automatically at the start of every battle.
@export var start_mystic_armor: float = 0.0
## Compatibility alias for start_mystic_armor
var start_mage_armor: float:
	get: return start_mystic_armor
	set(val): start_mystic_armor = val

## Flat bonus to physical armor gain.
var bonus_armor_gain: float = 0.0
## Flat bonus to mystic armor gain.
var bonus_mystic_armor_gain: float = 0.0

## Flat amount of damage subtracted from every incoming hit before percentage reduction.
@export var dmg_reduction_flat: float = 0.0
## Percentage of incoming damage reduced (0% to max_dmg_reduction).
@export var dmg_reduction: float = 0.0
## Upper cap on percentage-based damage reduction (default 90%).
@export var max_dmg_reduction: float = 90.0
## Physical-only percentage damage reduction (used by armored monsters/entities).
@export var physical_dmg_reduction: float = 0.0

@export_group("Critical & Combo")
## Base critical chance percentage before agility and bonus scaling.
@export var base_crit_chance: float = 5.0
var bonus_crit_chance: float = 0.0

## Critical strike chance percentage.
## Formula: Base 5% + (Agility * 2%) + bonus_crit_chance.
var crit_chance: float:
	get: return base_crit_chance + (agility * 2.0) + bonus_crit_chance
	set(val): bonus_crit_chance = val - base_crit_chance - (agility * 2.0)

## Flat bonus to physical attack damage.
var bonus_phys_dmg: float = 0.0
## Flat bonus to mystic attack damage.
var bonus_mystic_dmg: float = 0.0
## Flat bonus to critical strike damage percentage.
var bonus_crit_dmg: float = 0.0

## Bonus critical damage percentage added when an action critically strikes (50.0 = +50% / 1.5x multiplier base).
## Formula: 50.0% + (Might * 5.0%) + bonus_crit_dmg.
var crit_mutly: float:
	get: return 50.0 + (might * 5.0) + bonus_crit_dmg
	set(val): bonus_crit_dmg = val - 50.0 - (might * 5.0)

func get_crit_damage_multiplier() -> float:
	return 1.0 + (crit_mutly / 100.0)

## Starting combo points at the beginning of each turn for Fists-family equipment.
@export var start_combo: int = 0
var start_hand_combo: int:
	get: return start_combo
	set(val): start_combo = val
## Baseline damage dealt per matched tile when a color track triggers no equipment modifiers.
@export var fluf_damage: float = 0.0
## Flat reduction (in turns) applied to equipment cooldowns when triggered.
@export var cooldown_reduction: float = 0.0

#==============================================================================#
# RUNTIME COMBAT STATE
#==============================================================================#

## Current health points. Clamped between 0 and max_health; triggers death hook at 0.
@export var cur_health: float = 20.0:
	set(new_cur_health):
		cur_health = clamp(new_cur_health, 0, max_health)
		if cur_health <= 0:
			_on_entity_died()

## Current physical armor during combat. Resets at the start of the entity's turn.
var cur_armor: float = 0.0
## Current mystic armor during combat. Persists across turns within a battle; capped at max_health.
var cur_mystic_armor: float = 0.0:
	set(new_mystic_armor):
		var cap: float = max(0.0, max_health)
		cur_mystic_armor = clampf(new_mystic_armor, 0.0, cap)

## Compatibility alias for cur_mystic_armor
var cur_mage_armor: float:
	get: return cur_mystic_armor
	set(val): cur_mystic_armor = val
## Remaining actions / tile swaps in the current combat turn. Clamped between 0 and max_energy.
var moves_left: int = 0:
	set(new_moves):
		moves_left = clamp(new_moves, 0, max_energy)

## Runtime dictionary mapping canonical buff/debuff ID (String) to active stack count (int > 0).
var active_buffs: Dictionary = {}

## Whether the entity will dodge the next incoming physical attack (backed by the 'dodge' buff).
var dodge: bool:
	get:
		return get_buff_stacks("dodge") > 0
	set(val):
		_set_buff_internal("dodge", 1 if bool(val) else 0, false)
var dodging: bool:
	get: return dodge
	set(val): dodge = val

## Current accumulated combo points in the active combat turn (backed by the 'combo' buff).
var combo: int:
	get:
		return get_buff_stacks("combo")
	set(val):
		_set_buff_internal("combo", maxi(0, int(val)), false)
var hand_combo: int:
	get: return combo
	set(val): combo = val

## Runtime dictionary mapping color ID (int) to its ColorLoadoutTrack.
var color_loadouts: Dictionary = {}

## Internal tracking of currently active stat boosts from equipped equipment.
var _active_equipment_stat_contributions: Dictionary = {}
var _is_recalculating_passives: bool = false

#==============================================================================#
# SHARED SIGNALS
#==============================================================================#
signal statChanged(stat: String)
signal buffsChanged
signal died
signal finishedTurn
signal loadoutChanged

func _init() -> void:
	if not loadoutChanged.is_connected(_on_loadout_changed):
		loadoutChanged.connect(_on_loadout_changed)

func _on_loadout_changed() -> void:
	recalculate_equipment_passives()

#==============================================================================#
# SHARED EQUIPMENT & TRACK PASSIVES
#==============================================================================#

func is_exotic_color(color: int) -> bool:
	return (int(color) % 100) != 0

func get_base_family(color: int) -> int:
	return (color - (color % 100)) if color > 0 else 0

func ensure_loadout_tracks() -> void:
	pass

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
	return null

## Iterates all tracks owned by this entity (can be overridden to include fallback tracks).
func get_all_tracks() -> Array[ColorLoadoutTrack]:
	var tracks: Array[ColorLoadoutTrack] = []
	for k in color_loadouts.keys():
		var t: ColorLoadoutTrack = color_loadouts[k]
		if t != null and not tracks.has(t):
			tracks.append(t)
	return tracks

## Recalculates all passive stat boosts from all equipped equipment across all active tracks.
## Reconciles against previously applied contributions with zero stat drift.
func recalculate_equipment_passives() -> void:
	if _is_recalculating_passives:
		return
	_is_recalculating_passives = true

	var new_totals: Dictionary = {}
	for track in get_all_tracks():
		if track == null:
			continue
		for mod in track.equipped_modifiers:
			if mod == null:
				continue
			var boosts: Dictionary = mod.get_stat_boosts()
			for stat_name in boosts.keys():
				var val = boosts[stat_name]
				new_totals[stat_name] = new_totals.get(stat_name, 0.0) + val

	# Reconcile previously boosted stats
	for stat_name in _active_equipment_stat_contributions.keys():
		var old_val = _active_equipment_stat_contributions[stat_name]
		var new_val = new_totals.get(stat_name, 0.0)
		var diff = new_val - old_val
		if not is_zero_approx(diff):
			modify_stat(stat_name, diff)

	# Apply new stats not in previous contributions
	for stat_name in new_totals.keys():
		if not _active_equipment_stat_contributions.has(stat_name):
			var new_val = new_totals[stat_name]
			if not is_zero_approx(new_val):
				modify_stat(stat_name, new_val)

	_active_equipment_stat_contributions = new_totals
	_is_recalculating_passives = false

func refresh_equipment_stats() -> void:
	recalculate_equipment_passives()

func reset_modifiers_for_battle() -> void:
	ensure_loadout_tracks()
	for track in get_all_tracks():
		if track != null:
			track.reset_for_battle()

func tick_all_track_cooldowns(amount: int = 1) -> void:
	ensure_loadout_tracks()
	for track in get_all_tracks():
		if track != null:
			track.tick_cooldowns(amount)

#==============================================================================#
# CRITICAL STRIKE RESOLUTION
#==============================================================================#

## Returns the clamped critical strike chance (0% to 100%) for this entity.
func get_effective_crit_chance() -> int:
	return clampi(crit_chance, 0, 100)

## Rolls whether an individual action or attack from this entity critically strikes.
func roll_crit() -> bool:
	var chance: int = get_effective_crit_chance()
	if chance <= 0:
		return false
	if chance >= 100:
		return true
	return randi_range(1, 100) <= chance

#==============================================================================#
# UNIFIED BUFF & DEBUFF SYSTEM
#==============================================================================#

## Returns the active stack count for the given buff/debuff ID (0 if inactive).
func get_buff_stacks(buff_id: String) -> int:
	var norm_id: String = BuffRegistryRef.normalize_id(buff_id)
	return int(active_buffs.get(norm_id, 0))

## Returns true if the entity currently has at least 1 stack of the given buff/debuff.
func has_buff(buff_id: String) -> bool:
	return get_buff_stacks(buff_id) > 0

## Sets the exact stack count for a buff/debuff (removes it if stacks <= 0).
func set_buff(buff_id: String, stacks: int) -> void:
	_set_buff_internal(buff_id, stacks, true)

## Adds (or subtracts if negative) stacks to a buff/debuff.
func add_buff(buff_id: String, delta: int = 1) -> void:
	var norm_id: String = BuffRegistryRef.normalize_id(buff_id)
	_set_buff_internal(norm_id, get_buff_stacks(norm_id) + delta, true)

## Removes a buff/debuff completely.
func remove_buff(buff_id: String) -> void:
	_set_buff_internal(buff_id, 0, true)

## Clears all active buffs and debuffs from this entity.
func clear_all_buffs() -> void:
	if active_buffs.is_empty():
		return
	active_buffs.clear()
	buffsChanged.emit()

## Processes turn-start buff/debuff expiration and per-turn stack decay.
func tick_buffs_at_turn_start() -> void:
	var buffs_changed: bool = false
	var keys: Array = active_buffs.keys()
	for k in keys:
		var def = BuffRegistryRef.get_def(str(k))
		if def.clear_on_turn_start:
			active_buffs.erase(k)
			buffs_changed = true
		elif def.decay_per_turn > 0:
			var next_stacks: int = int(active_buffs[k]) - def.decay_per_turn
			if next_stacks > 0:
				active_buffs[k] = next_stacks
			else:
				active_buffs.erase(k)
			buffs_changed = true
	if buffs_changed:
		buffsChanged.emit()

## Processes turn-end buff/debuff expiration (e.g. combo points, turn-only buffs).
func tick_buffs_at_turn_end() -> void:
	var buffs_changed: bool = false
	var keys: Array = active_buffs.keys()
	for k in keys:
		var def = BuffRegistryRef.get_def(str(k))
		if def.clear_on_turn_end:
			active_buffs.erase(k)
			buffs_changed = true
	if buffs_changed:
		buffsChanged.emit()

## Returns an ordered list of active buff/debuff entries: { "id": String, "stacks": int, "def": BuffDef }
func get_active_buff_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for k in active_buffs.keys():
		var stacks: int = int(active_buffs[k])
		if stacks > 0:
			var def = BuffRegistryRef.get_def(str(k))
			result.append({
				"id": def.id,
				"stacks": stacks,
				"def": def,
			})
	return result

func _set_buff_internal(buff_id: String, stacks: int, emit_stat_signals: bool) -> void:
	var norm_id: String = BuffRegistryRef.normalize_id(buff_id)
	var clamped: int = maxi(0, stacks)
	var prev: int = int(active_buffs.get(norm_id, 0))
	if clamped > 0:
		active_buffs[norm_id] = clamped
	else:
		active_buffs.erase(norm_id)
	if prev != clamped:
		buffsChanged.emit()
		if emit_stat_signals:
			_on_stat_modified(norm_id)
			statChanged.emit(norm_id)

#==============================================================================#
# UNIFIED DAMAGE & STAT MUTATION API
#==============================================================================#

func take_damage(incoming_damage: float, piercing: bool = false, type: int = 0, attacker: EntityResource = null) -> float:
	if has_buff("dodge") and type == 0:
		add_buff("dodge", -1)
		return 0.0

	var net_damage: float = float(incoming_damage)

	if dmg_reduction_flat > 0.0:
		net_damage -= clamp(dmg_reduction_flat, 0.0, max(0.0, net_damage - 1.0))

	if dmg_reduction > 0.0:
		net_damage = round(net_damage * (1.0 - clamp(dmg_reduction, 0.0, max_dmg_reduction) / 100.0))

	if physical_dmg_reduction > 0.0 and type == 0:
		net_damage = round(net_damage * (1.0 - clamp(physical_dmg_reduction, 0.0, max_dmg_reduction) / 100.0))

	if cur_mystic_armor > 0.0 and net_damage > 0.0 and not piercing:
		net_damage = apply_armor_reduction(net_damage, "cur_mystic_armor")
	if cur_armor > 0.0 and net_damage > 0.0:
		net_damage = apply_armor_reduction(net_damage, "cur_armor")

	if net_damage > 0.0:
		modify_stat("cur_health", -net_damage)
		if attacker != null and attacker != self and attacker.life_steal > 0.0:
			var heal_value: float = round(net_damage * attacker.life_steal)
			if heal_value > 0.0:
				attacker.modify_stat("cur_health", heal_value)

	_on_after_damage_taken(net_damage, type, attacker)
	return net_damage

func apply_armor_reduction(damage: float, armor_property: String) -> float:
	var armor_value: float = float(get(armor_property))
	var remaining_armor: float = armor_value - damage
	if remaining_armor >= 0.0:
		set(armor_property, remaining_armor)
		_on_stat_modified(armor_property)
		statChanged.emit(armor_property)
		if armor_property == "cur_mystic_armor":
			_on_stat_modified("cur_mage_armor")
			statChanged.emit("cur_mage_armor")
		return 0.0
	set(armor_property, 0.0)
	_on_stat_modified(armor_property)
	statChanged.emit(armor_property)
	if armor_property == "cur_mystic_armor":
		_on_stat_modified("cur_mage_armor")
		statChanged.emit("cur_mage_armor")
	return abs(remaining_armor)

func modify_stat(stat: String, value, increment: bool = true) -> void:
	if BuffRegistryRef.has_buff_def(stat):
		var norm_id: String = BuffRegistryRef.normalize_id(stat)
		var next_stacks: int = 0
		if value is bool:
			next_stacks = 1 if value else 0
		else:
			next_stacks = (get_buff_stacks(norm_id) + int(value)) if increment else int(value)
		set_buff(norm_id, next_stacks)
		return
	if stat == "cur_mage_armor":
		stat = "cur_mystic_armor"
	elif stat == "start_mage_armor":
		stat = "start_mystic_armor"
	elif stat == "max_health":
		if increment:
			bonus_max_health += float(value)
		else:
			bonus_max_health = float(value) - (base_health + (might * 1.0) + (grit * 2.0))
		recalculate_max_health()
		_on_stat_modified("max_health")
		statChanged.emit("max_health")
		return
	if not stat in self:
		print("Stat does not exist:", stat)
		return
	var prev_moves: int = moves_left if stat == "moves_left" else 0
	set(stat, get(stat) + value if increment else value)
	if stat == "moves_left" and prev_moves > 0 and moves_left <= 0:
		_on_moves_exhausted()
	_on_stat_modified(stat)
	statChanged.emit(stat)
	if stat == "cur_mystic_armor":
		_on_stat_modified("cur_mage_armor")
		statChanged.emit("cur_mage_armor")
	elif stat == "start_mystic_armor":
		_on_stat_modified("start_mage_armor")
		statChanged.emit("start_mage_armor")

# Compatibility aliases used across existing enemy and event scripts
func take_dmg(dmg: float, dmg_type: int = 0, attacker: EntityResource = null) -> float:
	return take_damage(dmg, false, dmg_type, attacker)

func add_stat(stat: String, value) -> void:
	modify_stat(stat, value, true)

func set_stat(stat: String, value) -> void:
	modify_stat(stat, value, false)

#==============================================================================#
# UNIFIED COMBAT & TURN LIFECYCLE
#==============================================================================#

## Resets an entity's combat stats at the beginning of a battle.
func reset_stats_at_beginning_of_fight() -> void:
	reset_modifiers_for_battle()
	recalculate_equipment_passives()
	clear_all_buffs()
	modify_stat("dodge", false, false)
	modify_stat("moves_left", max_energy, false)
	modify_stat("combo", start_combo, false)
	modify_stat("cur_armor", start_armor, false)
	modify_stat("cur_mystic_armor", start_mystic_armor, false)
	_on_battle_started()

## Processes turn-start upkeep: cooldowns tick, energy refills, physical armor resets, and turn buffs tick.
func reset_stats_at_beginning_of_turn() -> void:
	tick_all_track_cooldowns(1)
	tick_buffs_at_turn_start()
	modify_stat("cur_armor", 0, false)
	modify_stat("combo", start_combo, false)
	modify_stat("moves_left", max_energy, false)
	loadoutChanged.emit()
	_on_turn_started()

## Processes turn-end cleanup: clears turn-scoped momentum (combo), residual moves, and turn-end buffs.
func reset_stats_at_end_of_turn() -> void:
	tick_buffs_at_turn_end()
	modify_stat("combo", start_combo, false)
	if moves_left != 0:
		moves_left = 0
		_on_stat_modified("moves_left")
		statChanged.emit("moves_left")
	_on_turn_ended()

# Common aliases for clean developer UX and legacy compatibility
func start_battle() -> void:
	reset_stats_at_beginning_of_fight()

func start_turn() -> void:
	reset_stats_at_beginning_of_turn()

func end_turn() -> void:
	reset_stats_at_end_of_turn()

func reset_stats_at_beging_of_fight() -> void:
	reset_stats_at_beginning_of_fight()

func reset_stats_at_beging_of_turn() -> void:
	reset_stats_at_beginning_of_turn()

func reset_stats_at_beging_of_game() -> void:
	reset_stats_at_beginning_of_fight()

#==============================================================================#
# SUBCLASS HOOKS
#==============================================================================#

func _on_entity_died() -> void:
	died.emit()

func _on_stat_modified(_stat: String) -> void:
	pass

func _on_moves_exhausted() -> void:
	finishedTurn.emit()

func _on_after_damage_taken(_net_damage: float, _type: int, _attacker: EntityResource) -> void:
	pass

func _on_battle_started() -> void:
	pass

func _on_turn_started() -> void:
	pass

func _on_turn_ended() -> void:
	pass
