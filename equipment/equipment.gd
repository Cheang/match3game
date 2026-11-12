class_name Equipment
extends Resource

## Defines when this equipment triggers during a board match.
enum TriggerCondition {
	ALWAYS,                 ## Triggers on any match of the track's color.
	MATCH_4_PLUS,           ## Triggers only when 4 or more tiles are matched at once.
	SHAPE_L_OR_T,           ## Triggers only on L-shaped or T-shaped matches.
	BOTTOM_HALF_GRID,       ## Triggers only when the lowest matched tile is in the bottom half of the board (+50% potency).
	HIGH_MOMENTUM,          ## Triggers only when matched tiles fell 3+ spaces before matching.
	SECOND_MATCH_IN_TURN,   ## Triggers only on the 2nd+ match of this color in the same turn.
	THIRD_MATCH_IN_TURN,    ## Triggers only on the 3rd+ match of this color in the same turn.
	EXOTIC_INFUSED,         ## Triggers only when the match includes an Exotic tile.
	HAZARD_INTERACTION      ## Triggers only when the match clears an adjacent board obstacle/hazard.
}

## Damage type dealt to enemies.
enum DamageType {
	PHYSICAL = 0,           ## Reduced by enemy Armor, scales with Might, cooldown reduced by Agility.
	MYSTICAL = 1            ## Reduced by enemy Mystic Armor, scales with Spirit, cooldown reduced by Spirit.
}
const MAGIC = DamageType.MYSTICAL ## Backwards compatibility alias.

## Player stat used to scale an equipment effect.
enum StatScaling {
	NONE = 0,               ## Flat value only (no stat scaling).
	MIGHT = 1,              ## Adds the player's Might stat.
	GRIT = 2,               ## Adds the player's Grit stat.
	AGILITY = 3,            ## Adds the player's Agility stat.
	SPIRIT = 4,             ## Adds the player's Spirit stat.
	CURRENT_ARMOR = 5       ## Adds the player's current Physical Armor in combat.
}

## Equipment rarity tiers.
enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4,
	GODLY = 5
}

static func get_rarity_name(r: Rarity) -> String:
	match r:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.GODLY: return "Godly"
	return "Common"

static func get_rarity_color(r: Rarity) -> Color:
	match r:
		Rarity.COMMON: return Color("#b0b0b0")
		Rarity.UNCOMMON: return Color("#3ca370")
		Rarity.RARE: return Color("#4d65b4")
		Rarity.EPIC: return Color("#a854a8")
		Rarity.LEGENDARY: return Color("#f2c94c")
		Rarity.GODLY: return Color("#44ddff")
	return Color("#b0b0b0")

static func get_rarity_hex(r: Rarity) -> String:
	match r:
		Rarity.COMMON: return "#b0b0b0"
		Rarity.UNCOMMON: return "#3ca370"
		Rarity.RARE: return "#4d65b4"
		Rarity.EPIC: return "#a854a8"
		Rarity.LEGENDARY: return "#f2c94c"
		Rarity.GODLY: return "#44ddff"
	return "#b0b0b0"

# ==============================================================================
# 1. IDENTITY & SLOT
# ==============================================================================
@export_group("Identity & Slot")
## Display name of this equipment shown in tooltips and inventory UI.
@export var piece_name: String = ""
## Icon texture displayed in combat tracks and inventory bag slots.
@export var icon: Texture2D
## Optional custom tooltip text. Leave blank or standard to auto-generate dynamic stat descriptions.
@export_multiline var description: String = ""
## Synergy tag chosen from defined equipment families. Determines auto-slotting color and triggers passives/synergies.
@export_enum("sword", "fists", "shields", "mobility", "healing", "beast") var family: String = "sword"
## Number of slots this equipment occupies on a color track (1 = small, 2 = medium, 3 = large, up to 5).
@export_range(1, 5) var slot_cost: int = 1
## Whether this skill is an Ultimate ability (can ONLY be equipped in the dedicated Ultimate slot 0).
@export var is_ultimate: bool = false
## If true, this ultimate does not require all 5 normal skills to be activated before it can trigger.
@export var bypass_activation_check: bool = false

# ==============================================================================
# 2. RARITY & SCALING
# ==============================================================================
@export_group("Rarity & Scaling")
## Current rarity tier of this equipment.
## Base version (COMMON) grants 0 passive hero stat boosts.
## Higher rarities grant passive stats, scaled effects, and extra colors configured in rarity_tiers.
@export var rarity: Rarity = Rarity.COMMON
## If true, this equipment is locked to its configured `rarity` and will only appear at that exact tier.
@export var fixed_rarity: bool = false
## Minimum rarity tier this equipment can roll (Rarity Floor).
@export var min_rarity: Rarity = Rarity.COMMON
## Maximum rarity tier this equipment can roll (Rarity Ceiling).
@export var max_rarity: Rarity = Rarity.GODLY
## Specific tier configurations (passive stats, effect scaling, and color options) for higher rarities.
@export var rarity_tiers: Array[EquipmentRarityTier] = []

# ==============================================================================
# 3. TRIGGER & RESTRICTIONS
# ==============================================================================
@export_group("Trigger & Restrictions")
## Board condition required for this equipment to fire when its track color is matched.
@export var trigger_condition: TriggerCondition = TriggerCondition.ALWAYS
## Number of player turns before this equipment can trigger again (0 = no cooldown, can fire multiple times per turn).
@export var cooldown_turns: int = 0
## Discipline flag for skills/utility with cooldowns: if true, cooldown reduces with Spirit (Mystical).
## If false (default), cooldown reduces with Agility (Physical).
## (For attack equipment with base_damage > 0, this is automatically synchronized with Damage Type).
@export var is_mystical: bool:
	get:
		if base_damage > 0.0 or damage_combo_multiplier > 0.0:
			return damage_type == DamageType.MYSTICAL or _is_mystical
		return _is_mystical
	set(val):
		_is_mystical = val
		if base_damage > 0.0 or damage_combo_multiplier > 0.0:
			damage_type = DamageType.MYSTICAL if val else DamageType.PHYSICAL
## If true, this equipment can only trigger once per combat encounter.
@export var once_per_battle: bool = false
## Leave empty for Colorless (equippable on any color track). Add colors here only to restrict this equipment to specific color tracks.
@export var allowed_colors: Array[Global.TileColor] = []

# ==============================================================================
# 4. ATTACK & DAMAGE (Set base_damage > 0 to enable)
# ==============================================================================
@export_group("Attack & Damage")
## Base damage dealt per hit (0 = does not deal damage).
@export var base_damage: float = 0.0
## Damage discipline: Physical (scales with Might, Agility CDR) or Mystical (scales with Spirit, Spirit CDR).
@export var damage_type: DamageType = DamageType.PHYSICAL:
	set(val):
		damage_type = val
		_is_mystical = (damage_type == DamageType.MYSTICAL)
## Stat scaling ratio for this attack (0.25 = 25%, 0.50 = 50%).
## Physical attacks scale with Might; Mystical attacks scale with Spirit. Default is 0.50 (50%).
@export_range(0.0, 1.0, 0.05) var stat_scaling_ratio: float = 0.50
## Number of times the attack strikes when triggered (1 = single hit, 2+ = multi-hit).
@export var hit_count: int = 1
## Bonus damage added per point of current Hand Combo (0 = no combo scaling; 1 = +1 DMG per Combo; 3 = +3 DMG per Combo).
@export var damage_combo_multiplier: float = 0.0

# ==============================================================================
# 5. DEFENSE & HEALING (Set > 0 to enable)
# ==============================================================================
@export_group("Defense & Healing")
## Base Physical Armor granted when triggered (0 = none).
@export var base_armor: float = 0.0
## Which player stat is added to base_armor.
@export var armor_stat_scaling: StatScaling = StatScaling.GRIT
## If true, multiplies total Physical Armor granted by the player's current Hand Combo (e.g. Block).
@export var multiply_armor_by_combo: bool = false
## Base Mystic Armor granted when triggered (0 = none).
@export var base_mystic_armor: float = 0.0
## Compatibility alias for base_mystic_armor
var base_magic_armor: float:
	get: return base_mystic_armor
	set(val): base_mystic_armor = val

## Which player stat is added to base_mystic_armor.
@export var mystic_armor_stat_scaling: StatScaling = StatScaling.SPIRIT
## Compatibility alias for mystic_armor_stat_scaling
var magic_armor_stat_scaling: StatScaling:
	get: return mystic_armor_stat_scaling
	set(val): mystic_armor_stat_scaling = val

## If true, multiplies total Mystic Armor granted by the player's current Hand Combo.
@export var multiply_mystic_armor_by_combo: bool = false
## Compatibility alias for multiply_mystic_armor_by_combo
var multiply_magic_armor_by_combo: bool:
	get: return multiply_mystic_armor_by_combo
	set(val): multiply_mystic_armor_by_combo = val

## Base HP restored to the player when triggered (0 = none).
@export var base_heal: float = 0.0
## Which player stat is added to base_heal.
@export var heal_stat_scaling: StatScaling = StatScaling.SPIRIT

# ==============================================================================
# 5. COMBO & UTILITY (Set > 0 or true to enable)
# ==============================================================================
@export_group("Combo & Utility")
## Hand Combo points added BEFORE damage and armor effects are calculated (e.g. Punch +1, Block +1).
@export var combo_points_before: int = 0
## Hand Combo points added AFTER damage and armor effects are calculated (e.g. Uppercut +1).
@export var combo_points_after: int = 0
## If true, resets the player's Hand Combo to 0 after this equipment resolves (for combo finishers).
@export var consume_all_combo: bool = false
## Extra board swaps/moves granted to the player when triggered (e.g. Rush +1).
@export var moves_to_give: int = 0
## If true, grants Dodge so the player evades the next incoming enemy attack.
@export var grant_dodge: bool = false
## Bonus Gold coins awarded to the player when triggered.
@export var gold_to_give: int = 0

# ==============================================================================
# 6. UPGRADES
# ==============================================================================
@export_group("Upgrades")
## Whether this equipment can be upgraded at events or upgrade rewards.
@export var can_upgrade: bool = true
## Current upgrade level (+1 per upgrade). Adds to active effects automatically.
@export var upgrade: int = 0
## If true, upgrades increase damage_combo_multiplier instead of flat base_damage (e.g. Uppercut).
@export var upgrade_scales_combo_mult: bool = false

# ==============================================================================
# 7. REWARD POOL & PROGRESSION
# ==============================================================================
@export_group("Reward Pool & Progression")
## Progression tags emitted when this equipment is claimed from a reward draft.
@export var unlock_tags: Array[String] = []
## If true, this equipment is removed from the active draft pool once chosen.
@export var remove_from_pool_when_picked: bool = true

# ==============================================================================
# RUNTIME STATE (Non-exported)
# ==============================================================================
var _is_mystical: bool = false
var _custom_damage_stat_scaling: int = -1

## Player stat used for damage scaling.
## Automatically inferred from damage_type / is_mystical (Physical -> Might, Mystical -> Spirit).
## Can be explicitly overridden via code if needed (e.g. StatScaling.NONE).
var damage_stat_scaling: StatScaling:
	get:
		if _custom_damage_stat_scaling >= 0:
			return _custom_damage_stat_scaling as StatScaling
		return StatScaling.SPIRIT if is_mystical else StatScaling.MIGHT
	set(val):
		_custom_damage_stat_scaling = val

var bound_color: int = 0
var criting: bool = false
var current_cooldown: int = 0
var used_this_battle: bool = false
var source_template: Resource = null

## Direct-resource reward presentation accessors (compatible with RewardCard and Event UI)
var name: String:
	get:
		return piece_name
	set(val):
		piece_name = val

var base: Texture2D:
	get:
		if not Engine.is_editor_hint() and is_instance_valid(Global) and ("get_color_base_texture" in Global):
			var eff_colors: Array[int] = get_effective_allowed_colors()
			if not eff_colors.is_empty() and not is_colorless():
				return Global.get_color_base_texture(eff_colors[0])
			var fam_c: int = Global.get_family_default_color(family)
			return Global.get_color_base_texture(fam_c)
		match family.to_lower():
			"sword", "fists": return preload("res://assets/sprites/tiles/red_0_sq.png")
			"shields": return preload("res://assets/sprites/tiles/blue_0_sq.png")
			"mobility": return preload("res://assets/sprites/tiles/green_0_sq.png")
			"healing": return preload("res://assets/sprites/tiles/purple_0_sq.png")
		return preload("res://assets/sprites/tiles/white_0_sq.png")

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

func can_trigger(ctx: MatchContext) -> bool:
	if once_per_battle and used_this_battle:
		return false
	if current_cooldown > 0:
		return false
	if ctx == null:
		return trigger_condition == TriggerCondition.ALWAYS

	var grid_h: int = 9
	if not Engine.is_editor_hint() and is_instance_valid(Global) and ("grd_height" in Global):
		grid_h = Global.grd_height
	var half_row: int = grid_h >> 1

	match trigger_condition:
		TriggerCondition.ALWAYS:
			return true
		TriggerCondition.MATCH_4_PLUS:
			return ctx.match_count >= 4
		TriggerCondition.SHAPE_L_OR_T:
			return ctx.shape_type in ["L_SHAPE", "T_SHAPE"]
		TriggerCondition.BOTTOM_HALF_GRID:
			return ctx.lowest_row >= half_row
		TriggerCondition.HIGH_MOMENTUM:
			return ctx.total_fall_momentum >= 3
		TriggerCondition.SECOND_MATCH_IN_TURN:
			return ctx.match_index_for_color_this_turn >= 2
		TriggerCondition.THIRD_MATCH_IN_TURN:
			return ctx.match_index_for_color_this_turn >= 3
		TriggerCondition.EXOTIC_INFUSED:
			return ctx.is_exotic_blend or ctx.exotic_count > 0
		TriggerCondition.HAZARD_INTERACTION:
			return not ctx.hazards_cleared.is_empty()
	return true

## Returns how many triggers from the trigger budget this equipment consumes to activate.
## Normal skills take 1 trigger. 4+ match skills (e.g. Rush) take 2 triggers to trigger once.
func get_trigger_cost() -> int:
	if trigger_condition == TriggerCondition.MATCH_4_PLUS:
		return 2
	return 1

func get_context_potency_multiplier(ctx: MatchContext) -> float:
	if ctx == null:
		return 1.0
	var mult: float = ctx.get_momentum_multiplier() * ctx.potency_multiplier
	var grid_h: int = 9
	if not Engine.is_editor_hint() and is_instance_valid(Global) and ("grd_height" in Global):
		grid_h = Global.grd_height
	if trigger_condition == TriggerCondition.BOTTOM_HALF_GRID and ctx.lowest_row >= (grid_h >> 1):
		mult *= 1.5
	return mult

func on_triggered(actor: EntityResource = null) -> void:
	if once_per_battle:
		used_this_battle = true
	var eff_cd: int = get_effective_cooldown_turns()
	if eff_cd > 0:
		var owner_entity: EntityResource = actor if actor != null else _safe_get_global_char()
		var cdr: int = 0
		if owner_entity != null:
			var stat_cdr: int = 0
			if is_mystical:
				stat_cdr = int(floor(owner_entity.spirit / 5.0))
			else:
				stat_cdr = int(floor(owner_entity.agility / 5.0))
			cdr = int(roundf(owner_entity.cooldown_reduction)) + stat_cdr
		current_cooldown = max(0, eff_cd - cdr)

func reset_for_battle() -> void:
	current_cooldown = 0
	used_this_battle = false
	criting = false

func tick_cooldown(amount: int = 1) -> void:
	if current_cooldown > 0:
		current_cooldown = max(0, current_cooldown - amount)

func _get_stat_value(c_res, scaling: StatScaling) -> float:
	if c_res == null:
		return 0.0
	match scaling:
		StatScaling.MIGHT:
			return float(c_res.might) if "might" in c_res else 0.0
		StatScaling.GRIT:
			return float(c_res.grit) if "grit" in c_res else 0.0
		StatScaling.AGILITY:
			return float(c_res.agility) if "agility" in c_res else 0.0
		StatScaling.SPIRIT:
			return float(c_res.spirit) if "spirit" in c_res else 0.0
		StatScaling.CURRENT_ARMOR:
			return float(c_res.cur_armor) if "cur_armor" in c_res else 0.0
	return 0.0

# ==============================================================================
# DYNAMIC RARITY & TIER RESOLUTION
# ==============================================================================

## Returns the active EquipmentRarityTier for this item's current rarity.
## Returns null if this item is COMMON (base) or has no configuration for this tier.
func get_active_tier() -> EquipmentRarityTier:
	if rarity == Rarity.COMMON:
		return null
	for tier in rarity_tiers:
		if tier != null and int(tier.rarity) == int(rarity):
			return tier
	return null

## Returns dictionary of all passive hero stat boosts for the current rarity tier.
## Base (COMMON) items return an empty dictionary (0 stat boosts).
func get_stat_boosts() -> Dictionary:
	var tier = get_active_tier()
	if tier == null:
		return {}
	return tier.get_stat_boosts()

func get_effective_base_damage() -> float:
	var tier = get_active_tier()
	if tier == null:
		return base_damage
	if tier.is_effect_override:
		return tier.base_damage if tier.base_damage > 0.0 else base_damage
	return base_damage + tier.base_damage

func get_effective_hit_count() -> int:
	var tier = get_active_tier()
	if tier == null:
		return max(1, hit_count)
	if tier.is_effect_override:
		return max(1, tier.hit_count) if tier.hit_count > 0 else max(1, hit_count)
	return max(1, hit_count + tier.hit_count)

func get_effective_damage_combo_multiplier() -> float:
	var tier = get_active_tier()
	if tier == null:
		return damage_combo_multiplier
	if tier.is_effect_override:
		return tier.damage_combo_multiplier if tier.damage_combo_multiplier > 0.0 else damage_combo_multiplier
	return damage_combo_multiplier + tier.damage_combo_multiplier

func get_effective_base_armor() -> float:
	var tier = get_active_tier()
	if tier == null:
		return base_armor
	if tier.is_effect_override:
		return tier.base_armor if tier.base_armor > 0.0 else base_armor
	return base_armor + tier.base_armor

func get_effective_base_mystic_armor() -> float:
	var tier = get_active_tier()
	if tier == null:
		return base_mystic_armor
	if tier.is_effect_override:
		var tier_m_arm: float = tier.base_mystic_armor if ("base_mystic_armor" in tier and tier.base_mystic_armor > 0.0) else (tier.base_magic_armor if "base_magic_armor" in tier else 0.0)
		return tier_m_arm if tier_m_arm > 0.0 else base_mystic_armor
	var tier_m_arm_add: float = tier.base_mystic_armor if "base_mystic_armor" in tier else (tier.base_magic_armor if "base_magic_armor" in tier else 0.0)
	return base_mystic_armor + tier_m_arm_add

func get_effective_base_magic_armor() -> float:
	return get_effective_base_mystic_armor()

func get_effective_base_heal() -> float:
	var tier = get_active_tier()
	if tier == null:
		return base_heal
	if tier.is_effect_override:
		return tier.base_heal if tier.base_heal > 0.0 else base_heal
	return base_heal + tier.base_heal

func get_effective_moves_to_give() -> int:
	var tier = get_active_tier()
	if tier == null:
		return moves_to_give
	if tier.is_effect_override:
		return tier.moves_to_give if tier.moves_to_give > 0 else moves_to_give
	return moves_to_give + tier.moves_to_give

func get_effective_gold_to_give() -> int:
	var tier = get_active_tier()
	if tier == null:
		return gold_to_give
	if tier.is_effect_override:
		return tier.gold_to_give if tier.gold_to_give > 0 else gold_to_give
	return gold_to_give + tier.gold_to_give

func get_effective_combo_points_before() -> int:
	var tier = get_active_tier()
	if tier == null:
		return combo_points_before
	if tier.is_effect_override:
		return tier.combo_points_before if tier.combo_points_before != 0 else combo_points_before
	return combo_points_before + tier.combo_points_before

func get_effective_combo_points_after() -> int:
	var tier = get_active_tier()
	if tier == null:
		return combo_points_after
	if tier.is_effect_override:
		return tier.combo_points_after if tier.combo_points_after != 0 else combo_points_after
	return combo_points_after + tier.combo_points_after

func get_effective_cooldown_turns() -> int:
	var tier = get_active_tier()
	if tier != null and tier.cooldown_override >= 0:
		return tier.cooldown_override
	return cooldown_turns

## Dynamically sets this equipment instance's rarity and notifies player to recalculate passives.
func set_rarity(new_rarity: Rarity) -> void:
	rarity = new_rarity
	var p = _safe_get_global_char()
	if p != null:
		p.recalculate_equipment_passives()

## Returns true if this equipment can be rolled at `target_rarity` given its fixed_rarity, min_rarity (floor), and max_rarity (ceiling).
func can_roll_at_rarity(target_rarity: int) -> bool:
	if fixed_rarity:
		return int(rarity) == target_rarity
	var floor_r: int = mini(int(min_rarity), int(max_rarity))
	var ceil_r: int = maxi(int(min_rarity), int(max_rarity))
	return target_rarity >= floor_r and target_rarity <= ceil_r

## Clamps `target_rarity` into this equipment's valid [min_rarity, max_rarity] range (or `rarity` if fixed_rarity is true).
func clamp_to_allowed_rarity(target_rarity: int) -> Rarity:
	if fixed_rarity:
		return rarity
	var floor_r: int = mini(int(min_rarity), int(max_rarity))
	var ceil_r: int = maxi(int(min_rarity), int(max_rarity))
	return clampi(target_rarity, floor_r, ceil_r) as Rarity

## Creates an independent clone of this equipment initialized to a specific rarity tier (respecting floor/ceiling/fixed rules).
## Designed for Class Pools, Combat Drops, Events, and Shop inventories.
func duplicate_with_rarity(target_rarity: Rarity) -> Equipment:
	var dup: Equipment = duplicate(true)
	dup.rarity = clamp_to_allowed_rarity(int(target_rarity))
	dup.source_template = source_template if source_template != null else self
	dup.reset_for_battle()
	return dup

## Returns an independent owned instance of this equipment for reward granting.
func get_resolved_modifiers() -> Array[Equipment]:
	var inst: Equipment = duplicate_with_rarity(rarity)
	return [inst]

## Applies reward progression (unlock tags and pool removal) when this equipment is claimed directly.
func apply_progression() -> void:
	var p = _safe_get_global_char()
	if p == null:
		return
	for tag in unlock_tags:
		p.set_flag(tag, true)
	if p.has_method("on_reward_chosen"):
		p.on_reward_chosen(self)

func boost() -> void:
	apply_progression()

## Executes all active effects configured on this equipment.
func activate(context = null) -> void:
	var cur_char: EntityResource = _resolve_char(context)
	var cur_enemy: EntityResource = _resolve_enemy(context)
	var ctx: MatchContext = _resolve_match_ctx(context)
	if cur_char == null:
		return

	var mult: float = get_context_potency_multiplier(ctx)
	var is_crit: bool = false
	if context is Dictionary and context.has("is_crit"):
		is_crit = bool(context["is_crit"])
	elif criting:
		is_crit = true
	elif cur_char != null:
		is_crit = cur_char.roll_crit()
	criting = false
	var crit_factor: float = cur_char.get_crit_damage_multiplier() if is_crit else 1.0

	# 1. Pre-Effect Hand Combo
	var eff_combo_before: int = get_effective_combo_points_before()
	if eff_combo_before != 0:
		cur_char.modify_stat("combo", eff_combo_before)

	# 2. Attack & Damage Effect
	var eff_dmg: float = get_effective_base_damage()
	var eff_combo_mult: float = get_effective_damage_combo_multiplier()
	if eff_dmg > 0.0 or eff_combo_mult > 0.0:
		if cur_enemy != null:
			var loops: int = get_effective_hit_count()
			var raw_stat: float = _get_stat_value(cur_char, damage_stat_scaling)
			var eff_ratio: float = 0.50 if (damage_type == DamageType.MYSTICAL or is_mystical) else stat_scaling_ratio
			var stat_bonus: float = roundf(raw_stat * eff_ratio)
			var flat_upg: float = float(upgrade) if not upgrade_scales_combo_mult else 0.0
			var total_combo_mult: float = eff_combo_mult + (float(upgrade) if upgrade_scales_combo_mult else 0.0)

			for i in loops:
				var dmg_val: float = eff_dmg + stat_bonus + flat_upg
				if total_combo_mult > 0.0:
					dmg_val += cur_char.combo * total_combo_mult
				dmg_val = max(1.0, roundf(dmg_val * mult * crit_factor))
				cur_enemy.take_damage(dmg_val, false, int(damage_type), cur_char)
				if ctx != null and ctx.lifesteal_bonus > 0.0:
					var heal_amt: float = max(1.0, roundf(dmg_val * ctx.lifesteal_bonus))
					cur_char.modify_stat("cur_health", heal_amt)

	# 3. Physical Armor Effect (Fixed 25% scaling from Grit)
	var eff_arm: float = get_effective_base_armor()
	if eff_arm > 0.0:
		var raw_stat_arm: float = _get_stat_value(cur_char, armor_stat_scaling)
		var arm_val: float = eff_arm + float(upgrade) + roundf(raw_stat_arm * 0.25)
		if multiply_armor_by_combo:
			arm_val *= max(1, cur_char.combo)
		arm_val = roundf(arm_val * mult * crit_factor)
		cur_char.modify_stat("cur_armor", arm_val)

	# 4. Mystic Armor Effect (Fixed 50% scaling from Spirit)
	var eff_m_arm: float = get_effective_base_mystic_armor()
	if eff_m_arm > 0.0:
		var raw_stat_m_arm: float = _get_stat_value(cur_char, mystic_armor_stat_scaling)
		var m_arm_val: float = eff_m_arm + float(upgrade) + roundf(raw_stat_m_arm * 0.50)
		if multiply_mystic_armor_by_combo:
			m_arm_val *= max(1, cur_char.combo)
		m_arm_val = roundf(m_arm_val * mult * crit_factor)
		cur_char.modify_stat("cur_mystic_armor", m_arm_val)

	# 5. Heal HP Effect
	var eff_heal: float = get_effective_base_heal()
	if eff_heal > 0.0:
		var heal_val: float = eff_heal + float(upgrade) + _get_stat_value(cur_char, heal_stat_scaling)
		heal_val = roundf(heal_val * mult * crit_factor)
		cur_char.modify_stat("cur_health", heal_val)

	# 6. Utility Effects (Moves, Dodge, Gold)
	var eff_moves: int = get_effective_moves_to_give()
	if eff_moves > 0:
		var total_moves: int = eff_moves + upgrade
		cur_char.modify_stat("moves_left", total_moves * 2 if is_crit else total_moves)

	if grant_dodge:
		cur_char.modify_stat("dodge", true, false)

	var eff_gold: int = get_effective_gold_to_give()
	if eff_gold > 0 and "gold" in cur_char:
		cur_char.modify_stat("gold", eff_gold + upgrade)

	# 7. Post-Effect Hand Combo / Finisher Consumption
	var eff_combo_after: int = get_effective_combo_points_after()
	if consume_all_combo:
		cur_char.modify_stat("combo", 0, false)
	elif eff_combo_after != 0:
		cur_char.modify_stat("combo", eff_combo_after)

	_on_custom_activate(cur_char, cur_enemy, ctx)

## Optional virtual hook for unique one-off equipment scripts.
func _on_custom_activate(_cur_char: EntityResource, _cur_enemy: EntityResource, _ctx: MatchContext) -> void:
	pass

## Builds a rich BBCode description reflecting current player stats, rarity bonuses, and upgrades across all active effects.
func get_effect_description(char_resource = null, upgrades: int = -1) -> String:
	var upg: int = upgrade if upgrades < 0 else upgrades
	var c_res = char_resource if char_resource != null else _safe_get_global_char()
	var parts: Array[String] = []

	var tier = get_active_tier()
	if tier != null:
		var stat_bbcode: String = tier.get_stat_boosts_bbcode()
		if stat_bbcode != "":
			parts.append(stat_bbcode)
		if tier.custom_description != "":
			parts.append(tier.custom_description)

	var eff_combo_before: int = get_effective_combo_points_before()
	if eff_combo_before > 0:
		parts.append("[color=#7a3045]+%d Combo[/color]" % eff_combo_before)

	var eff_dmg: float = get_effective_base_damage()
	var eff_combo_mult: float = get_effective_damage_combo_multiplier()
	if eff_dmg > 0.0 or eff_combo_mult > 0.0:
		var raw_stat: float = _get_stat_value(c_res, damage_stat_scaling)
		var eff_ratio: float = 0.50 if (damage_type == DamageType.MYSTICAL or is_mystical) else stat_scaling_ratio
		var stat_bonus: float = roundf(raw_stat * eff_ratio)
		var flat_upg: float = float(upg) if not upgrade_scales_combo_mult else 0.0
		var dmg: float = eff_dmg + stat_bonus + flat_upg
		var combo_mult: float = eff_combo_mult + (float(upg) if upgrade_scales_combo_mult else 0.0)
		var count: int = get_effective_hit_count()
		var is_myst: bool = (damage_type == DamageType.MYSTICAL or is_mystical)
		var color_str: String = "#3ca370" if is_myst else "#ae2334"
		var type_label: String = " Mystical" if is_myst else ""

		if combo_mult > 0.0:
			if combo_mult > 1.0:
				parts.append("Deals: [color=%s]%s[/color]%s DMG + ([color=#7a3045]Combo[/color] * [color=%s]%s[/color])" % [color_str, _fmt(dmg), type_label, color_str, _fmt(combo_mult)])
			else:
				parts.append("Deals: [color=%s]%s[/color]%s DMG + [color=#7a3045]Combo[/color]" % [color_str, _fmt(dmg), type_label])
		elif count > 1:
			parts.append("Deals: [color=%s]%s x %d[/color]%s DMG" % [color_str, _fmt(dmg), count, type_label])
		else:
			parts.append("Deals: [color=%s]%s[/color]%s DMG" % [color_str, _fmt(dmg), type_label])

	var eff_arm: float = get_effective_base_armor()
	if eff_arm > 0.0:
		var raw_stat_arm: float = _get_stat_value(c_res, armor_stat_scaling)
		var total_armor: float = eff_arm + float(upg) + roundf(raw_stat_arm * 0.25)
		if multiply_armor_by_combo:
			parts.append("Gives: [color=#4d65b4]%s[/color] Armor * [color=#7a3045]Combo[/color]" % [_fmt(total_armor)])
		else:
			parts.append("Gives: [color=#4d65b4]%s[/color] Armor" % [_fmt(total_armor)])

	var eff_m_arm: float = get_effective_base_mystic_armor()
	if eff_m_arm > 0.0:
		var raw_stat_m_arm: float = _get_stat_value(c_res, mystic_armor_stat_scaling)
		var total_m_armor: float = eff_m_arm + float(upg) + roundf(raw_stat_m_arm * 0.50)
		if multiply_mystic_armor_by_combo:
			parts.append("Gives: [color=#0b8a8f]%s[/color] Mystic Armor * [color=#7a3045]Combo[/color]" % [_fmt(total_m_armor)])
		else:
			parts.append("Gives: [color=#0b8a8f]%s[/color] Mystic Armor" % [_fmt(total_m_armor)])

	var eff_heal: float = get_effective_base_heal()
	if eff_heal > 0.0:
		var total_heal: float = eff_heal + float(upg) + _get_stat_value(c_res, heal_stat_scaling)
		parts.append("Heals: [color=#a854a8]%s[/color] HP" % [_fmt(total_heal)])

	var eff_moves: int = get_effective_moves_to_give()
	if eff_moves > 0:
		parts.append("Gives: [color=#639bff]+%d[/color] Move(s)" % [eff_moves + upg])

	if grant_dodge:
		parts.append("Grants: [color=#5ac54f]Dodge[/color]")

	var eff_gold: int = get_effective_gold_to_give()
	if eff_gold > 0:
		parts.append("Gives: [color=#f2c94c]+%d[/color] Gold" % [eff_gold + upg])

	var eff_combo_after: int = get_effective_combo_points_after()
	if eff_combo_after > 0:
		parts.append("Then [color=#7a3045]+%d Combo[/color]" % eff_combo_after)

	if consume_all_combo:
		parts.append("Consumes all [color=#7a3045]Combo[/color]")

	if not parts.is_empty():
		return " | ".join(parts)
	return description

func _resolve_char(context) -> EntityResource:
	if context is Dictionary and context.has("attacker"):
		return context["attacker"]
	if context is MatchContext and context.actor != null:
		return context.actor
	return _safe_get_global_char()

func _resolve_enemy(context) -> EntityResource:
	if context is Dictionary and context.has("target"):
		return context["target"]
	if context is MatchContext and context.target != null:
		return context.target
	return _safe_get_global_enemy()

func _safe_get_global_char() -> EntityResource:
	if Engine.is_editor_hint():
		return null
	if Engine.get_main_loop() != null and is_instance_valid(Global):
		var val = Global.get("cur_char")
		if val is EntityResource:
			return val
	return null

func _safe_get_global_enemy() -> EntityResource:
	if Engine.is_editor_hint():
		return null
	if Engine.get_main_loop() != null and is_instance_valid(Global):
		var val = Global.get("cur_enemy")
		if val is EntityResource:
			return val
	return null

func _resolve_match_ctx(context) -> MatchContext:
	if context is MatchContext:
		return context
	if context is Dictionary and context.has("ctx"):
		return context["ctx"]
	return null

func _fmt(val: float) -> String:
	if is_equal_approx(val, roundf(val)):
		return str(int(roundf(val)))
	return str(snappedf(val, 0.1))

func is_colorless() -> bool:
	var tier = get_active_tier()
	if tier != null and tier.allow_all_colors:
		return true
	return bound_color == 0 and allowed_colors.is_empty()

func is_allowed_on_color(target_color: int) -> bool:
	if is_colorless():
		return true
	var target_base: int = target_color - (target_color % 100) if target_color > 0 else 0
	if bound_color > 0 and (bound_color - (bound_color % 100)) == target_base:
		return true
	for c in allowed_colors:
		var c_int: int = int(c)
		if c_int == 0 or (c_int - (c_int % 100)) == target_base:
			return true
	var tier = get_active_tier()
	if tier != null:
		if tier.allow_all_colors:
			return true
		for c in tier.extra_allowed_colors:
			var c_int: int = int(c)
			if c_int == 0 or (c_int - (c_int % 100)) == target_base:
				return true
	return false

func get_effective_allowed_colors() -> Array[int]:
	if is_colorless():
		var p = _safe_get_global_char()
		if p != null and not p.active_color_pool.is_empty():
			return p.active_color_pool
		return [100, 200, 300, 400, 500]
	var res: Array[int] = []
	if not allowed_colors.is_empty():
		for c in allowed_colors:
			if not res.has(int(c)):
				res.append(int(c))
	elif bound_color > 0:
		res.append(bound_color)
	var tier = get_active_tier()
	if tier != null:
		for c in tier.extra_allowed_colors:
			if not res.has(int(c)):
				res.append(int(c))
	if res.is_empty():
		return [100, 200, 300, 400, 500]
	return res

func get_trigger_badge_text() -> String:
	match trigger_condition:
		TriggerCondition.ALWAYS: return ""
		TriggerCondition.MATCH_4_PLUS: return "4+"
		TriggerCondition.SHAPE_L_OR_T: return "L/T"
		TriggerCondition.BOTTOM_HALF_GRID: return "BOT"
		TriggerCondition.HIGH_MOMENTUM: return "MOM"
		TriggerCondition.SECOND_MATCH_IN_TURN: return "2nd"
		TriggerCondition.THIRD_MATCH_IN_TURN: return "3rd"
		TriggerCondition.EXOTIC_INFUSED: return "EXO"
		TriggerCondition.HAZARD_INTERACTION: return "HAZ"
	return ""
