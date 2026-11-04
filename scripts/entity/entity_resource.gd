extends Resource
class_name EntityResource

#==============================================================================#
# SHARED ENTITY FOUNDATION (Player & Monster Common Contract)
#==============================================================================#

@export_category("Entity Identity & Art")
## Character or monster portrait/animation scene instantiated in combat.
@export var sprite: PackedScene

#------------------------------------------------------------------------------#
@export_category("Core Attributes")
## Red Pillar: Increases physical attack damage and scales with fall momentum.
@export var might: float = 1.0
## Blue Pillar: Increases physical armor and magic armor granted by defensive equipment.
@export var grit: float = 0.0
## Green Pillar: Determines base tile swaps / actions per turn and scales mobility effects.
@export var speed: int = 1
## Purple/White Pillar: Increases healing potency, magic effects, and status scaling.
@export var spirit: float = 0.0

#------------------------------------------------------------------------------#
@export_category("Combat Stats")
@export_group("Health & Sustain")
## Maximum health points.
@export var max_health: float = 20.0:
	set(new_max_health):
		var diff = new_max_health - max_health
		max_health = new_max_health
		cur_health += diff
## Fraction of attack damage restored as health (e.g. 0.25 = 25% lifesteal).
@export var life_steal: float = 0.0

@export_group("Defense & Mitigation")
## Physical armor granted automatically at the start of every battle.
@export var start_armor: float = 0.0
## Magic armor granted automatically at the start of every battle.
@export var start_mage_armor: float = 0.0
## Flat amount of damage subtracted from every incoming hit before percentage reduction.
@export var dmg_reduction_flat: float = 0.0
## Percentage of incoming damage reduced (0% to max_dmg_reduction).
@export var dmg_reduction: float = 0.0
## Upper cap on percentage-based damage reduction (default 90%).
@export var max_dmg_reduction: float = 90.0
## Physical-only percentage damage reduction (used by armored monsters/entities).
@export var physical_dmg_reduction: float = 0.0

@export_group("Critical & Combo")
## Base chance (0% to 100%) for an action or attack to critically strike.
@export_range(0, 100) var crit_chance: int = 5:
	set(new_crit_chance):
		crit_chance = clamp(new_crit_chance, 0, 100)
## Bonus critical damage percentage added when an action critically strikes (100.0 = +100% damage / 2x multiplier).
@export var crit_mutly: float = 100.0
## Starting hand combo points at the beginning of each turn for Fists-family equipment.
@export var start_hand_combo: int = 0
## Baseline damage dealt per matched tile when a color track triggers no equipment modifiers.
@export var fluf_damage: float = 0.0
## Flat reduction (in turns) applied to equipment cooldowns when triggered.
@export var cooldown_reduction: int = 0

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
## Current magic armor during combat. Persists across turns within a battle.
var cur_mage_armor: float = 0.0
## Remaining actions / tile swaps in the current combat turn.
var moves_left: int = 0
## Whether the entity will dodge the next incoming physical attack.
var dodging: bool = false
## Current accumulated hand combo points in the active combat turn.
var hand_combo: int = 0

## Runtime dictionary mapping color ID (int) to its ColorLoadoutTrack.
var color_loadouts: Dictionary = {}

## Internal tracking of currently active stat boosts from equipped equipment.
var _active_equipment_stat_contributions: Dictionary = {}
var _is_recalculating_passives: bool = false

#==============================================================================#
# SHARED SIGNALS
#==============================================================================#
signal statChanged(stat: String)
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
	return int(color / 100) * 100

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
# UNIFIED DAMAGE & STAT MUTATION API
#==============================================================================#

func take_damage(incoming_damage: float, piercing: bool = false, type: int = 0, attacker: EntityResource = null) -> float:
	if dodging and type == 0:
		dodging = false
		_on_stat_modified("dodging")
		statChanged.emit("dodging")
		return 0.0

	var net_damage: float = float(incoming_damage)

	if dmg_reduction_flat > 0.0:
		net_damage -= clamp(dmg_reduction_flat, 0.0, max(0.0, net_damage - 1.0))

	if dmg_reduction > 0.0:
		net_damage = round(net_damage * (1.0 - clamp(dmg_reduction, 0.0, max_dmg_reduction) / 100.0))

	if physical_dmg_reduction > 0.0 and type == 0:
		net_damage = round(net_damage * (1.0 - clamp(physical_dmg_reduction, 0.0, max_dmg_reduction) / 100.0))

	if cur_mage_armor > 0.0 and net_damage > 0.0 and not piercing:
		net_damage = apply_armor_reduction(net_damage, "cur_mage_armor")
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
		return 0.0
	set(armor_property, 0.0)
	_on_stat_modified(armor_property)
	statChanged.emit(armor_property)
	return abs(remaining_armor)

func modify_stat(stat: String, value, increment: bool = true) -> void:
	if not stat in self:
		print("Stat does not exist:", stat)
		return
	set(stat, get(stat) + value if increment else value)
	if stat == "moves_left" and moves_left <= 0:
		_on_moves_exhausted()
	_on_stat_modified(stat)
	statChanged.emit(stat)

# Compatibility aliases used across existing enemy and event scripts
func take_dmg(dmg: float, dmg_type: int = 0, attacker: EntityResource = null) -> float:
	return take_damage(dmg, false, dmg_type, attacker)

func add_stat(stat: String, value) -> void:
	modify_stat(stat, value, true)

func set_stat(stat: String, value) -> void:
	modify_stat(stat, value, false)

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
