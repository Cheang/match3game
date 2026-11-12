@tool
class_name Reward
extends Resource

## Defines the 4 core reward types in LoreTiles.
enum RewardType {
	EQUIPMENT = 0,       ## Grants 1 or more active Equipment items for color loadout tracks.
	PASSIVE = 1,         ## Passive item equipped into the 5-slot Passives Ring.
	STAT_BUFF = 2,       ## Permanent stat increase or immediate consumable bonus (HP, Gold, Rerolls).
	MECHANIC_UNLOCK = 3  ## Unlocks a board/loadout gameplay mechanic (Bombs, Color Pool, Track Slots, Flags).
}

## Defines the specific gameplay mechanic unlocked when reward_type == MECHANIC_UNLOCK.
enum MechanicType {
	NONE = 0,
	ROW_BOMBS = 1,             ## 4-tile vertical matches spawn horizontal row bombs.
	COL_BOMBS = 2,             ## 4-tile horizontal matches spawn vertical column bombs.
	ADJ_BOMBS = 3,             ## L/T matches spawn 3x3 area bombs.
	COLOR_BOMBS = 4,           ## 5-tile matches spawn color bombs.
	ADD_COLOR_TO_POOL = 5,     ## Adds target_color to the player's active color pool.
	REMOVE_COLOR_FROM_POOL = 6,## Removes target_color from the player's active color pool.
	TRANSMUTE_COLOR = 7,       ## Transmutes target_color into transmute_to_color (e.g. Red -> Dark Crimson).
	EXPAND_TRACK_SLOTS = 8,    ## Increases max_slots on target_color track (or all tracks if 0).
	CUSTOM_FLAG = 9            ## Sets custom boolean progression/mechanic flags on the player.
}

## Defines the rarity tier of this reward (influences draft probabilities, scaling, shop pricing, and borders).
enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4,
	GODLY = 5
}

## Default automatic stat scaling multiplier per rarity tier when auto_scale_stats_with_rarity is true
## and no explicit RewardRarityTier override is configured for that tier.
const DEFAULT_RARITY_STAT_MULTIPLIERS: Dictionary = {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 1.5,
	Rarity.RARE: 2.0,
	Rarity.EPIC: 2.5,
	Rarity.LEGENDARY: 3.0,
	Rarity.GODLY: 4.0
}

## If false (default), base stats are used directly and higher rarities only change stats if configured in `rarity_tiers`.
## If true, non-zero base stats automatically multiply by DEFAULT_RARITY_STAT_MULTIPLIERS when no explicit RewardRarityTier exists for that tier.
@export var auto_scale_stats_with_rarity: bool = false

## Legacy category enum retained for backward compatibility with older scripts/tests.
enum RewardCategory {
	COMBAT = 0,
	PASSIVE = 1
}

# ==============================================================================
# 1. CORE TYPE & IDENTITY
# ==============================================================================
@export_group("Core Type & Identity")
## The primary classification of this reward (Equipment, Passive, Stat Buff, or Mechanic Unlock).
@export var reward_type: RewardType = RewardType.EQUIPMENT:
	set(val):
		reward_type = val
		notify_property_list_changed()

## Build synergy family tag (e.g. "fists", "sword", "shields", "mobility", "healing", "body", "beast").
## Used by the Build-Affinity algorithm to favor rewards matching the player's equipped build.
## If left blank on an EQUIPMENT reward, it automatically inherits the family of its primary Equipment.
@export var family: String = ""

## Title displayed on the reward card or UI. If blank on an EQUIPMENT reward, inherits from the Equipment.
@export var name: String = ""
## Optional custom description. If blank, dynamically generated from the reward's effects or Equipment.
@export_multiline var description: String = ""
## Illustration / icon texture. If null on an EQUIPMENT reward, inherits from the Equipment.
@export var icon: Texture2D
## Background card frame texture. If null on an EQUIPMENT reward, inherits from the Equipment.
@export var base: Texture2D

# ==============================================================================
# 2. RARITY, FLOOR / CEILING & SCALING
# ==============================================================================
@export_group("Rarity & Scaling")
## Current or specific rarity tier of this reward.
@export var rarity: Rarity = Rarity.COMMON
## If true, this reward is locked to its configured `rarity` and will only roll at that exact tier.
## If false (default), this reward can dynamically roll and scale across [min_rarity .. max_rarity] just like Equipment!
@export var fixed_rarity: bool = false:
	set(val):
		fixed_rarity = val
		notify_property_list_changed()
## Minimum rarity tier this reward can roll (Rarity Floor).
@export var min_rarity: Rarity = Rarity.COMMON
## Maximum rarity tier this reward can roll (Rarity Ceiling).
@export var max_rarity: Rarity = Rarity.GODLY
## Optional explicit per-tier overrides/bonuses for higher rarities (UNCOMMON .. GODLY), matching Equipment's rarity_tiers.
@export var rarity_tiers: Array[RewardRarityTier] = []

# ==============================================================================
# 3. ECONOMY & SOURCING
# ==============================================================================
@export_group("Economy & Sourcing")
## Gold cost in the Shop. If 0, automatically calculated from the reward's rarity tier.
@export var shop_price: int = 0
## Base selection weight multiplier when rolling drafts (default 1.0).
@export var drop_weight: float = 1.0
## Prerequisite tags/flags that must be active on the player before this reward can be offered.
@export var required_flags: Array[String] = []
## Progression tags/flags set on the player when this reward is claimed.
@export var unlock_tags: Array[String] = []
## If true, this reward is removed from the player's class pool once picked.
@export var remove_from_pool_when_picked: bool = true

# ==============================================================================
# 4. EQUIPMENT PAYLOAD (RewardType.EQUIPMENT)
# ==============================================================================
@export_group("Equipment Payload")
## Equipment resources granted when this reward is claimed.
@export var equipment_to_grant: Array[Equipment] = []

# ==============================================================================
# 5. STAT MODIFIERS (RewardType.PASSIVE & RewardType.STAT_BUFF)
# ==============================================================================
@export_group("Stat Modifiers")
## Increase to the player's Might stat (boosts physical attacks).
@export var might: float = 0.0
## Increase to the player's Grit stat (boosts physical armor).
@export var grit: float = 0.0
## Increase to the player's Spirit stat (boosts mystical effects and healing).
@export var spirit: float = 0.0
## Increase to the player's Agility stat (determines actions per turn / Max Energy).
@export var agility: float = 0.0
## Increase to the player's Maximum Health.
@export var max_health: float = 0.0
## Increase to the player's critical strike chance percentage.
@export var crit_chance: int = 0
## Immediate restoration of current HP (Stat Buff / Consumable).
@export var heal_hp: float = 0.0
## Gold coins awarded immediately (Stat Buff / Consumable).
@export var gold: int = 0
## Extra reward rerolls granted immediately (Stat Buff / Consumable).
@export var rerolls: int = 0

# ==============================================================================
# 6. MECHANIC UNLOCKS & FLAGS (RewardType.MECHANIC_UNLOCK & PASSIVE)
# ==============================================================================
@export_group("Mechanic Unlocks")
## Primary mechanic unlocked by this reward.
@export var mechanic_type: MechanicType = MechanicType.NONE
## Unlocks the ability for 4-tile vertical matches to spawn horizontal row bombs.
@export var unlock_row_bombs: bool = false
## Unlocks the ability for 4-tile horizontal matches to spawn vertical column bombs.
@export var unlock_col_bombs: bool = false
## Unlocks the ability for L/T-shaped matches to spawn adjacent 3x3 area bombs.
@export var unlock_adj_bombs: bool = false
## Unlocks the ability for 5-tile matches to spawn color bombs.
@export var unlock_color_bombs: bool = false
## Target color ID (e.g. 100=Red, 200=Blue, 300=Green, 400=Purple, 500=White) for color pool or track mechanics.
@export var target_color: int = 0
## Exotic or target color ID to transmute into when mechanic_type == TRANSMUTE_COLOR.
@export var transmute_to_color: int = 0
## Number of extra normal slots to add when mechanic_type == EXPAND_TRACK_SLOTS.
@export var slot_expansion_amount: int = 1
## Custom boolean flags set on the player when claimed (or while equipped as a Passive).
@export var custom_flags: Array[String] = []

## Reference to the original template resource when duplicated for drafts.
var source_template: Resource = null

# ==============================================================================
# INSPECTOR DYNAMIC FILTERING (@tool)
# ==============================================================================
func _validate_property(property: Dictionary) -> void:
	var p_name: String = property.get("name", "")
	if fixed_rarity and p_name in ["min_rarity", "max_rarity"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	match reward_type:
		RewardType.EQUIPMENT:
			if p_name in ["might", "grit", "spirit", "agility", "max_health", "crit_chance", "heal_hp", "gold", "rerolls", "auto_scale_stats_with_rarity"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			elif p_name in ["mechanic_type", "unlock_row_bombs", "unlock_col_bombs", "unlock_adj_bombs", "unlock_color_bombs", "target_color", "transmute_to_color", "slot_expansion_amount"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		RewardType.PASSIVE:
			if p_name in ["equipment_to_grant", "heal_hp", "gold", "rerolls"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			elif p_name in ["mechanic_type", "target_color", "transmute_to_color", "slot_expansion_amount"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		RewardType.STAT_BUFF:
			if p_name in ["equipment_to_grant"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			elif p_name in ["mechanic_type", "unlock_row_bombs", "unlock_col_bombs", "unlock_adj_bombs", "unlock_color_bombs", "target_color", "transmute_to_color", "slot_expansion_amount"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		RewardType.MECHANIC_UNLOCK:
			if p_name in ["equipment_to_grant", "might", "grit", "spirit", "agility", "max_health", "crit_chance", "heal_hp", "gold", "rerolls", "auto_scale_stats_with_rarity"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# ==============================================================================
# DYNAMIC RARITY, FLOOR / CEILING & SCALING RESOLUTION
# ==============================================================================

## Returns true if this reward can roll at `target_rarity` given its fixed_rarity, min_rarity (floor), and max_rarity (ceiling).
func can_roll_at_rarity(target_rarity: int) -> bool:
	if fixed_rarity:
		return int(rarity) == target_rarity
	var floor_r: int = mini(int(min_rarity), int(max_rarity))
	var ceil_r: int = maxi(int(min_rarity), int(max_rarity))
	return target_rarity >= floor_r and target_rarity <= ceil_r

## Clamps `target_rarity` into this reward's allowed [min_rarity, max_rarity] range (or `rarity` if fixed_rarity is true).
func clamp_to_allowed_rarity(target_rarity: int) -> Rarity:
	if fixed_rarity:
		return rarity
	var floor_r: int = mini(int(min_rarity), int(max_rarity))
	var ceil_r: int = maxi(int(min_rarity), int(max_rarity))
	return clampi(target_rarity, floor_r, ceil_r) as Rarity

## Returns the configured RewardRarityTier for the current `rarity`, or null if none is defined.
func get_active_tier() -> RewardRarityTier:
	for tier in rarity_tiers:
		if tier != null and int(tier.rarity) == int(rarity):
			return tier
	return null

## Creates an independent clone of this reward scaled to `target_rarity` (respecting floor/ceiling/fixed rules).
## Also scales or replaces all granted Equipment inside `equipment_to_grant` according to the active tier!
func duplicate_with_rarity(target_rarity: Rarity) -> Reward:
	var dup: Reward = duplicate(true)
	var final_r: Rarity = clamp_to_allowed_rarity(int(target_rarity))
	dup.rarity = final_r
	dup.source_template = source_template if source_template != null else self

	var tier: RewardRarityTier = dup.get_active_tier()
	var eq_rarity: Equipment.Rarity = int(final_r) as Equipment.Rarity

	# If this rarity tier specifies an explicit equipment_override, use it; otherwise scale base equipment_to_grant
	if tier != null and not tier.equipment_override.is_empty():
		var override_list: Array[Equipment] = []
		for eq in tier.equipment_override:
			if eq != null:
				override_list.append(eq.duplicate_with_rarity(eq_rarity))
		dup.equipment_to_grant = override_list
	elif not dup.equipment_to_grant.is_empty():
		var scaled_eq_list: Array[Equipment] = []
		for eq in dup.equipment_to_grant:
			if eq != null:
				scaled_eq_list.append(eq.duplicate_with_rarity(eq_rarity))
		if tier != null and tier.extra_equipment_copies > 0 and not scaled_eq_list.is_empty():
			var base_eq: Equipment = scaled_eq_list[0]
			for _i in range(tier.extra_equipment_copies):
				scaled_eq_list.append(base_eq.duplicate_with_rarity(eq_rarity))
		dup.equipment_to_grant = scaled_eq_list

	return dup

func _get_scaled_float_stat(base_val: float, tier_val: float) -> float:
	var tier: RewardRarityTier = get_active_tier()
	if tier != null:
		if tier.is_stat_override:
			return tier_val if not is_zero_approx(tier_val) else base_val
		return base_val + tier_val
	if is_zero_approx(base_val):
		return 0.0
	if not auto_scale_stats_with_rarity or fixed_rarity or rarity == Rarity.COMMON:
		return base_val
	var mult: float = float(DEFAULT_RARITY_STAT_MULTIPLIERS.get(rarity, 1.0))
	return roundf(base_val * mult)

func _get_scaled_int_stat(base_val: int, tier_val: int) -> int:
	var tier: RewardRarityTier = get_active_tier()
	if tier != null:
		if tier.is_stat_override:
			return tier_val if tier_val != 0 else base_val
		return base_val + tier_val
	if base_val == 0:
		return 0
	if not auto_scale_stats_with_rarity or fixed_rarity or rarity == Rarity.COMMON:
		return base_val
	var mult: float = float(DEFAULT_RARITY_STAT_MULTIPLIERS.get(rarity, 1.0))
	return int(roundf(float(base_val) * mult))

func get_effective_might() -> float:
	var t := get_active_tier()
	return _get_scaled_float_stat(might, t.might if t != null else 0.0)

func get_effective_grit() -> float:
	var t := get_active_tier()
	return _get_scaled_float_stat(grit, t.grit if t != null else 0.0)

func get_effective_spirit() -> float:
	var t := get_active_tier()
	return _get_scaled_float_stat(spirit, t.spirit if t != null else 0.0)

func get_effective_agility() -> int:
	var t := get_active_tier()
	return _get_scaled_int_stat(agility, t.agility if t != null else 0)

func get_effective_max_health() -> float:
	var t := get_active_tier()
	return _get_scaled_float_stat(max_health, t.max_health if t != null else 0.0)

func get_effective_crit_chance() -> int:
	var t := get_active_tier()
	return _get_scaled_int_stat(crit_chance, t.crit_chance if t != null else 0)

func get_effective_heal_hp() -> float:
	var t := get_active_tier()
	return _get_scaled_float_stat(heal_hp, t.heal_hp if t != null else 0.0)

func get_effective_gold() -> int:
	var t := get_active_tier()
	return _get_scaled_int_stat(gold, t.gold if t != null else 0)

func get_effective_rerolls() -> int:
	var t := get_active_tier()
	return _get_scaled_int_stat(rerolls, t.rerolls if t != null else 0)

# ==============================================================================
# BACKWARD COMPATIBILITY & AUTO-DETECTION ACCESSORS
# ==============================================================================
## Backward-compatible category property: maps PASSIVE <-> RewardType.PASSIVE.
var category: int:
	get:
		return RewardCategory.PASSIVE if reward_type == RewardType.PASSIVE else RewardCategory.COMBAT
	set(val):
		if int(val) == RewardCategory.PASSIVE:
			reward_type = RewardType.PASSIVE
		elif reward_type == RewardType.PASSIVE:
			reward_type = _infer_non_passive_type()

func _infer_non_passive_type() -> RewardType:
	if not equipment_to_grant.is_empty():
		return RewardType.EQUIPMENT
	if mechanic_type != MechanicType.NONE or unlock_row_bombs or unlock_col_bombs or unlock_adj_bombs or unlock_color_bombs:
		return RewardType.MECHANIC_UNLOCK
	if might != 0.0 or grit != 0.0 or spirit != 0.0 or agility != 0 or max_health != 0.0 or heal_hp != 0.0 or gold != 0 or rerolls != 0 or crit_chance != 0:
		return RewardType.STAT_BUFF
	return RewardType.EQUIPMENT

## Returns the effective RewardType, auto-detecting STAT_BUFF or MECHANIC_UNLOCK on legacy unmigrated instances.
func get_effective_reward_type() -> RewardType:
	if reward_type == RewardType.PASSIVE:
		return RewardType.PASSIVE
	if reward_type == RewardType.EQUIPMENT and equipment_to_grant.is_empty():
		if mechanic_type != MechanicType.NONE or unlock_row_bombs or unlock_col_bombs or unlock_adj_bombs or unlock_color_bombs:
			return RewardType.MECHANIC_UNLOCK
		if might != 0.0 or grit != 0.0 or spirit != 0.0 or agility != 0 or max_health != 0.0 or heal_hp != 0.0 or gold != 0 or rerolls != 0 or crit_chance != 0:
			return RewardType.STAT_BUFF
	return reward_type

## Legacy getter/setter for rearity string format.
var rearity: String:
	get:
		match rarity:
			Rarity.COMMON: return "COMMON"
			Rarity.UNCOMMON: return "UNCOMMON"
			Rarity.RARE: return "RARE"
			Rarity.EPIC: return "EPIC"
			Rarity.LEGENDARY: return "LEGENDARY"
			Rarity.GODLY: return "GODLY"
		return "COMMON"
	set(val):
		match str(val).to_upper():
			"COMMON": rarity = Rarity.COMMON
			"UNCOMMON": rarity = Rarity.UNCOMMON
			"RARE": rarity = Rarity.RARE
			"EPIC": rarity = Rarity.EPIC
			"LEGENDARY": rarity = Rarity.LEGENDARY
			"GODLY": rarity = Rarity.GODLY
			_: rarity = Rarity.COMMON

## Legacy accessor for flags property used by event choices and old cards.
var flags: Array[String]:
	get:
		var all_f: Array[String] = custom_flags.duplicate()
		for t in unlock_tags:
			if not all_f.has(t):
				all_f.append(t)
		return all_f
	set(val):
		custom_flags = val

# ==============================================================================
# UNIFIED METADATA & FACTORY HELPERS
# ==============================================================================
## Wraps a standalone Equipment resource into a unified Reward instance of type EQUIPMENT.
static func from_equipment(eq: Equipment, rolled_rarity: int = -1, count: int = 1) -> Reward:
	if eq == null:
		return null
	var rew := Reward.new()
	rew.reward_type = RewardType.EQUIPMENT
	rew.fixed_rarity = eq.fixed_rarity
	rew.min_rarity = int(eq.min_rarity) as Rarity
	rew.max_rarity = int(eq.max_rarity) as Rarity
	var raw_r: int = int(eq.rarity) if rolled_rarity < 0 else rolled_rarity
	var clamped_r: Equipment.Rarity = eq.clamp_to_allowed_rarity(raw_r)
	rew.rarity = int(clamped_r) as Rarity
	for _i in range(maxi(1, count)):
		rew.equipment_to_grant.append(eq.duplicate_with_rarity(clamped_r))
	rew.name = eq.piece_name
	rew.description = eq.description
	rew.icon = eq.icon
	rew.base = eq.base
	rew.family = eq.family
	rew.unlock_tags = eq.unlock_tags.duplicate()
	rew.remove_from_pool_when_picked = eq.remove_from_pool_when_picked
	rew.source_template = eq.source_template if eq.source_template != null else eq
	return rew

func get_primary_equipment() -> Equipment:
	for eq in equipment_to_grant:
		if eq != null:
			return eq
	return null

func get_effective_family() -> String:
	if family != "":
		return family.to_lower()
	var eq := get_primary_equipment()
	if eq != null and eq.family != "":
		return eq.family.to_lower()
	return ""

func get_display_name() -> String:
	var tier: RewardRarityTier = get_active_tier()
	if tier != null and tier.custom_name != "":
		return tier.custom_name
	if name != "":
		return name
	var eq := get_primary_equipment()
	if eq != null and eq.piece_name != "":
		return eq.piece_name
	if resource_path != "":
		return resource_path.get_file().get_basename()
	return "Reward"

func get_display_icon() -> Texture2D:
	var tier: RewardRarityTier = get_active_tier()
	if tier != null and tier.custom_icon != null:
		return tier.custom_icon
	if icon != null:
		return icon
	var eq := get_primary_equipment()
	if eq != null and eq.icon != null:
		return eq.icon
	return null

func get_display_base() -> Texture2D:
	if base != null:
		return base
	var eq := get_primary_equipment()
	if eq != null and eq.base != null:
		return eq.base
	if not Engine.is_editor_hint() and is_instance_valid(Global) and ("get_color_base_texture" in Global):
		return Global.get_color_base_texture(0)
	return preload("res://assets/sprites/tiles/white_0_sq.png")

func get_effective_shop_price() -> int:
	if shop_price > 0:
		return shop_price
	match rarity:
		Rarity.COMMON: return 25
		Rarity.UNCOMMON: return 45
		Rarity.RARE: return 75
		Rarity.EPIC: return 115
		Rarity.LEGENDARY: return 165
		Rarity.GODLY: return 250
	return 25

## Returns a dictionary of non-zero persistent stat bonuses on this reward (scaled by current rarity).
func get_stat_boosts() -> Dictionary:
	var boosts: Dictionary = {}
	var eff_might: float = get_effective_might()
	var eff_grit: float = get_effective_grit()
	var eff_spirit: float = get_effective_spirit()
	var eff_agility: int = get_effective_agility()
	var eff_max_hp: float = get_effective_max_health()
	var eff_crit: int = get_effective_crit_chance()
	if eff_might != 0.0: boosts["might"] = eff_might
	if eff_grit != 0.0: boosts["grit"] = eff_grit
	if eff_spirit != 0.0: boosts["spirit"] = eff_spirit
	if eff_agility != 0: boosts["agility"] = eff_agility
	if eff_max_hp != 0.0: boosts["max_health"] = eff_max_hp
	if eff_crit != 0: boosts["crit_chance"] = eff_crit
	return boosts

## Checks whether the player satisfies all prerequisite flags for this reward.
func meets_requirements(player: Object) -> bool:
	if player == null or required_flags.is_empty():
		return true
	for req in required_flags:
		if req == "":
			continue
		var has_req: bool = false
		if player.has_method("has_flag"):
			has_req = player.has_flag(req)
		else:
			if "unlocked_tags" in player and player.unlocked_tags.has(req):
				has_req = true
			elif req in player and bool(player.get(req)):
				has_req = true
		if not has_req:
			return false
	return true

## Returns true if this reward is a MECHANIC_UNLOCK whose mechanic is already active on the player.
func is_already_unlocked(player: Object) -> bool:
	if player == null or get_effective_reward_type() != RewardType.MECHANIC_UNLOCK:
		return false
	var checks: int = 0
	var already_active: int = 0

	if unlock_row_bombs or mechanic_type == MechanicType.ROW_BOMBS:
		checks += 1
		if bool(player.get("flg_can_spawn_row_bombs")):
			already_active += 1
	if unlock_col_bombs or mechanic_type == MechanicType.COL_BOMBS:
		checks += 1
		if bool(player.get("flg_can_spawn_col_bombs")):
			already_active += 1
	if unlock_adj_bombs or mechanic_type == MechanicType.ADJ_BOMBS:
		checks += 1
		if bool(player.get("flg_can_spawn_adj_bombs")):
			already_active += 1
	if unlock_color_bombs or mechanic_type == MechanicType.COLOR_BOMBS:
		checks += 1
		if bool(player.get("flg_can_spawn_clr_bombs")):
			already_active += 1
	if mechanic_type == MechanicType.ADD_COLOR_TO_POOL and target_color > 0:
		checks += 1
		if "active_color_pool" in player and player.active_color_pool.has(target_color):
			already_active += 1
	if mechanic_type == MechanicType.TRANSMUTE_COLOR and transmute_to_color > 0:
		checks += 1
		if "active_color_pool" in player and player.active_color_pool.has(transmute_to_color):
			already_active += 1

	return checks > 0 and checks == already_active

## Returns resolved equipment items granted by this reward, scaled to this reward's current rarity (and respecting tier overrides).
func get_resolved_modifiers() -> Array[Equipment]:
	var mods: Array[Equipment] = []
	var target_eq_rarity: Equipment.Rarity = int(rarity) as Equipment.Rarity
	var tier: RewardRarityTier = get_active_tier()
	if tier != null and not tier.equipment_override.is_empty():
		for eq in tier.equipment_override:
			if eq != null:
				mods.append(eq.duplicate_with_rarity(target_eq_rarity))
		return mods

	for eq in equipment_to_grant:
		if eq != null:
			var dup_eq: Equipment = eq.duplicate_with_rarity(target_eq_rarity)
			mods.append(dup_eq)
	if tier != null and tier.extra_equipment_copies > 0 and not mods.is_empty():
		var base_eq: Equipment = mods[0]
		for _i in range(tier.extra_equipment_copies):
			mods.append(base_eq.duplicate_with_rarity(target_eq_rarity))
	return mods

## Returns all custom flags active on this reward at its current rarity (base custom_flags + tier extra_custom_flags).
func get_effective_custom_flags() -> Array[String]:
	var all_flags: Array[String] = custom_flags.duplicate()
	var tier: RewardRarityTier = get_active_tier()
	if tier != null:
		for f in tier.extra_custom_flags:
			if f != "" and not all_flags.has(f):
				all_flags.append(f)
	return all_flags

func get_effective_slot_expansion_amount() -> int:
	var tier: RewardRarityTier = get_active_tier()
	if tier != null and tier.slot_expansion_override > 0:
		return tier.slot_expansion_override
	return maxi(1, slot_expansion_amount)

## Applies all effects of this reward to the given player (or Global.cur_char if null).
## If grant_equipment is false (e.g. when already slotted via SlotEquipModal), equipment is skipped.
func apply_to_player(player: Object, grant_equipment: bool = true) -> void:
	if player == null:
		return
	var eff_type: RewardType = get_effective_reward_type()

	if eff_type == RewardType.PASSIVE:
		if player.has_method("equip_passive") and ("equipped_passives" in player) and not player.equipped_passives.has(self):
			player.equip_passive(self)
		apply_progression(player)
		return

	# 1. Apply Permanent & Consumable Stats (using rarity-scaled effective getters)
	var eff_might: float = get_effective_might()
	var eff_grit: float = get_effective_grit()
	var eff_spirit: float = get_effective_spirit()
	var eff_agility: int = get_effective_agility()
	var eff_max_hp: float = get_effective_max_health()
	var eff_heal: float = get_effective_heal_hp()
	var eff_gold: int = get_effective_gold()
	var eff_rerolls: int = get_effective_rerolls()
	var eff_crit: int = get_effective_crit_chance()

	if eff_might != 0.0: player.modify_stat("might", eff_might)
	if eff_grit != 0.0: player.modify_stat("grit", eff_grit)
	if eff_spirit != 0.0: player.modify_stat("spirit", eff_spirit)
	if eff_agility != 0: player.modify_stat("agility", eff_agility)
	if eff_max_hp != 0.0: player.modify_stat("max_health", eff_max_hp)
	if eff_heal != 0.0: player.modify_stat("cur_health", eff_heal)
	if eff_gold != 0: player.modify_stat("gold", eff_gold)
	if eff_rerolls != 0: player.modify_stat("rerolls", eff_rerolls)
	if eff_crit != 0: player.modify_stat("crit_chance", eff_crit)

	# 2. Apply Mechanic Unlocks & Flags
	_apply_mechanics_to_player(player)

	# 3. Apply Equipment (if not already handled interactively by SlotEquipModal)
	if grant_equipment and not equipment_to_grant.is_empty():
		for eq in get_resolved_modifiers():
			player.add_modifier_reward(eq, true)

	# 4. Progression & Pool Removal
	apply_progression(player)

func _apply_mechanics_to_player(player: Object) -> void:
	if unlock_row_bombs or mechanic_type == MechanicType.ROW_BOMBS:
		player.set_flag("flg_can_spawn_row_bombs", true)
	if unlock_col_bombs or mechanic_type == MechanicType.COL_BOMBS:
		player.set_flag("flg_can_spawn_col_bombs", true)
	if unlock_adj_bombs or mechanic_type == MechanicType.ADJ_BOMBS:
		player.set_flag("flg_can_spawn_adj_bombs", true)
	if unlock_color_bombs or mechanic_type == MechanicType.COLOR_BOMBS:
		player.set_flag("flg_can_spawn_clr_bombs", true)

	match mechanic_type:
		MechanicType.ADD_COLOR_TO_POOL:
			if target_color > 0 and player.has_method("add_color_to_pool"):
				player.add_color_to_pool(target_color)
		MechanicType.REMOVE_COLOR_FROM_POOL:
			if target_color > 0 and player.has_method("remove_color_from_pool"):
				player.remove_color_from_pool(target_color)
		MechanicType.TRANSMUTE_COLOR:
			if target_color > 0 and transmute_to_color > 0 and player.has_method("transmute_color"):
				player.transmute_color(target_color, transmute_to_color)
		MechanicType.EXPAND_TRACK_SLOTS:
			var bonus_slots: int = get_effective_slot_expansion_amount()
			if target_color > 0 and player.has_method("get_track_for_color"):
				var trk = player.get_track_for_color(target_color)
				if trk != null:
					trk.max_slots += bonus_slots
			elif "color_loadouts" in player:
				for k in player.color_loadouts.keys():
					var trk = player.color_loadouts[k]
					if trk != null:
						trk.max_slots += bonus_slots

	for f in get_effective_custom_flags():
		if f != "":
			player.set_flag(f, true)

## Activates all effects of this reward on Global.cur_char.
func activate(grant_equipment: bool = true) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(Global):
		return
	var p = Global.get("cur_char")
	if p == null:
		return
	apply_to_player(p, grant_equipment)

## Records unlock_tags and notifies the player's class reward pool.
func apply_progression(player: Object = null) -> void:
	var p: Object = player
	if p == null and not Engine.is_editor_hint() and is_instance_valid(Global):
		p = Global.get("cur_char")
	if p == null:
		return
	for f in custom_flags:
		if f != "":
			p.set_flag(f, true)
	for t in unlock_tags:
		if t != "":
			p.set_flag(t, true)
	if p.has_method("on_reward_chosen"):
		p.on_reward_chosen(self)

## Legacy alias for apply_progression().
func boost() -> void:
	apply_progression()

## Returns dynamic BBCode text summarizing all effects granted by this reward at its current rarity.
func get_effect_description() -> String:
	var tier: RewardRarityTier = get_active_tier()
	if tier != null and tier.custom_description != "":
		return tier.custom_description

	var lines: Array[String] = []
	var target_eq_rarity: Equipment.Rarity = int(rarity) as Equipment.Rarity

	if not equipment_to_grant.is_empty():
		if equipment_to_grant.size() == 1 and equipment_to_grant[0] != null:
			var eq: Equipment = equipment_to_grant[0].duplicate_with_rarity(target_eq_rarity)
			lines.append("Gain 1 [color=#f2c94c]%s[/color]: %s" % [eq.piece_name, eq.get_effect_description()])
		else:
			var counts: Dictionary = {}
			var eq_map: Dictionary = {}
			for eq in equipment_to_grant:
				if eq != null:
					var scaled_eq: Equipment = eq.duplicate_with_rarity(target_eq_rarity)
					counts[scaled_eq.piece_name] = counts.get(scaled_eq.piece_name, 0) + 1
					eq_map[scaled_eq.piece_name] = scaled_eq
			for eq_name in counts.keys():
				var eq_ref: Equipment = eq_map[eq_name]
				lines.append("Gain %d [color=#f2c94c]%s[/color]: %s" % [counts[eq_name], eq_name, eq_ref.get_effect_description()])

	var eff_might: float = get_effective_might()
	var eff_grit: float = get_effective_grit()
	var eff_spirit: float = get_effective_spirit()
	var eff_agility: int = get_effective_agility()
	var eff_max_hp: float = get_effective_max_health()
	var eff_heal: float = get_effective_heal_hp()
	var eff_gold: int = get_effective_gold()
	var eff_rerolls: int = get_effective_rerolls()
	var eff_crit: int = get_effective_crit_chance()

	if eff_might != 0.0: lines.append("[color=#ae2334]Might +%s[/color]" % _fmt(eff_might))
	if eff_grit != 0.0: lines.append("[color=#4d65b4]Grit +%s[/color]" % _fmt(eff_grit))
	if eff_spirit != 0.0: lines.append("[color=#a854a8]Spirit +%s[/color]" % _fmt(eff_spirit))
	if eff_agility != 0: lines.append("[color=#3ca370]Agility +%d[/color]" % eff_agility)
	if eff_max_hp != 0.0: lines.append("[color=#e06f8b]Max Health +%s[/color]" % _fmt(eff_max_hp))
	if eff_heal != 0.0: lines.append("[color=#5ac54f]Heal %s HP[/color]" % _fmt(eff_heal))
	if eff_gold != 0: lines.append("[color=#f2c94c]+%d Gold[/color]" % eff_gold)
	if eff_rerolls != 0: lines.append("[color=#639bff]+%d Reroll(s)[/color]" % eff_rerolls)
	if eff_crit != 0: lines.append("[color=#e28335]+%d%% Crit Chance[/color]" % eff_crit)

	if unlock_row_bombs or mechanic_type == MechanicType.ROW_BOMBS:
		lines.append("Unlocks [color=#d4d2c5]Row Bombs[/color]")
	if unlock_col_bombs or mechanic_type == MechanicType.COL_BOMBS:
		lines.append("Unlocks [color=#d4d2c5]Column Bombs[/color]")
	if unlock_adj_bombs or mechanic_type == MechanicType.ADJ_BOMBS:
		lines.append("Unlocks [color=#d4d2c5]Area Bombs[/color]")
	if unlock_color_bombs or mechanic_type == MechanicType.COLOR_BOMBS:
		lines.append("Unlocks [color=#d4d2c5]Color Bombs[/color]")

	match mechanic_type:
		MechanicType.ADD_COLOR_TO_POOL:
			var c_name: String = Global.get_color_name(target_color) if (not Engine.is_editor_hint() and is_instance_valid(Global)) else str(target_color)
			lines.append("Unlocks [color=#f2c94c]%s[/color] Tile Pool" % c_name)
		MechanicType.REMOVE_COLOR_FROM_POOL:
			var c_name: String = Global.get_color_name(target_color) if (not Engine.is_editor_hint() and is_instance_valid(Global)) else str(target_color)
			lines.append("Removes [color=#f2c94c]%s[/color] from Tile Pool" % c_name)
		MechanicType.TRANSMUTE_COLOR:
			var from_name: String = Global.get_color_name(target_color) if (not Engine.is_editor_hint() and is_instance_valid(Global)) else str(target_color)
			var to_name: String = Global.get_color_name(transmute_to_color) if (not Engine.is_editor_hint() and is_instance_valid(Global)) else str(transmute_to_color)
			lines.append("Transmutes [color=#f2c94c]%s[/color] into [color=#f9c22b]%s[/color]" % [from_name, to_name])
		MechanicType.EXPAND_TRACK_SLOTS:
			lines.append("Expands Track Capacity by [color=#f2c94c]+%d Slot(s)[/color]" % get_effective_slot_expansion_amount())

	if not lines.is_empty():
		return "\n".join(lines)
	return description

func _fmt(val: float) -> String:
	if is_equal_approx(val, roundf(val)):
		return str(int(roundf(val)))
	return str(snappedf(val, 0.1))
