@tool
extends Resource
class_name Equipment

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
	PHYSICAL = 0,           ## Reduced by enemy Armor.
	MAGIC = 1               ## Reduced by enemy Magic Armor.
}

## Player stat used to scale an equipment effect.
enum StatScaling {
	NONE = 0,               ## Flat value only (no stat scaling).
	MIGHT = 1,              ## Adds the player's Might stat.
	GRIT = 2,               ## Adds the player's Grit stat.
	SPEED = 3,              ## Adds the player's Speed stat.
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
@export_enum("sword", "fists", "shields", "mobility", "healing") var family: String = "sword"
## Number of slots this equipment occupies on a 3-slot color track (1 = small, 2 = medium, 3 = full track).
@export_range(1, 3) var slot_cost: int = 1

# ==============================================================================
# 2. RARITY & SCALING
# ==============================================================================
@export_group("Rarity & Scaling")
## Current rarity tier of this equipment.
## Base version (COMMON) grants 0 passive hero stat boosts.
## Higher rarities grant passive stats, scaled effects, and extra colors configured in rarity_tiers.
@export var rarity: Rarity = Rarity.COMMON
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
## If true, this equipment can only trigger once per combat encounter.
@export var once_per_battle: bool = false
## Leave empty for Colorless (equippable on any color track). Add colors here only to restrict this equipment to specific color tracks.
@export var allowed_colors: Array[Global.TileColor] = []

# ==============================================================================
# 3. ATTACK & DAMAGE (Set base_damage > 0 to enable)
# ==============================================================================
@export_group("Attack & Damage")
## Base damage dealt per hit (0 = does not deal damage).
@export var base_damage: float = 0.0
## Whether the attack deals Physical (0) or Magic (1) damage.
@export var damage_type: DamageType = DamageType.PHYSICAL
## Number of times the attack strikes when triggered (1 = single hit, 2+ = multi-hit).
@export var hit_count: int = 1
## Which player stat is added to base_damage on each hit.
@export var damage_stat_scaling: StatScaling = StatScaling.MIGHT
## Bonus damage added per point of current Hand Combo (0 = no combo scaling; 1 = +1 DMG per Combo; 3 = +3 DMG per Combo).
@export var damage_combo_multiplier: float = 0.0

# ==============================================================================
# 4. DEFENSE & HEALING (Set > 0 to enable)
# ==============================================================================
@export_group("Defense & Healing")
## Base Physical Armor granted when triggered (0 = none).
@export var base_armor: float = 0.0
## Which player stat is added to base_armor.
@export var armor_stat_scaling: StatScaling = StatScaling.GRIT
## If true, multiplies total Physical Armor granted by the player's current Hand Combo (e.g. Block).
@export var multiply_armor_by_combo: bool = false
## Base Magic Armor granted when triggered (0 = none).
@export var base_magic_armor: float = 0.0
## Which player stat is added to base_magic_armor.
@export var magic_armor_stat_scaling: StatScaling = StatScaling.SPIRIT
## If true, multiplies total Magic Armor granted by the player's current Hand Combo.
@export var multiply_magic_armor_by_combo: bool = false
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
# RUNTIME STATE (Non-exported)
# ==============================================================================
var bound_color: int = 0
var criting: bool = false
var current_cooldown: int = 0
var used_this_battle: bool = false

func can_trigger(ctx: MatchContext) -> bool:
	if once_per_battle and used_this_battle:
		return false
	if current_cooldown > 0:
		return false
	if ctx == null:
		return trigger_condition == TriggerCondition.ALWAYS

	var grid_h: int = Global.grd_height if (Engine.get_main_loop() != null and Global != null) else 9
	var half_row: int = int(grid_h / 2)

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

func get_context_potency_multiplier(ctx: MatchContext) -> float:
	if ctx == null:
		return 1.0
	var mult: float = ctx.get_momentum_multiplier() * ctx.potency_multiplier
	var grid_h: int = Global.grd_height if (Engine.get_main_loop() != null and Global != null) else 9
	if trigger_condition == TriggerCondition.BOTTOM_HALF_GRID and ctx.lowest_row >= int(grid_h / 2):
		mult *= 1.5
	return mult

func on_triggered() -> void:
	if once_per_battle:
		used_this_battle = true
	var eff_cd: int = get_effective_cooldown_turns()
	if eff_cd > 0:
		var cdr: int = 0
		if Global.cur_char != null:
			cdr = Global.cur_char.cooldown_reduction + int(floor(Global.cur_char.spirit * 0.25))
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
		StatScaling.SPEED:
			return float(c_res.speed) if "speed" in c_res else 0.0
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

func get_effective_base_magic_armor() -> float:
	var tier = get_active_tier()
	if tier == null:
		return base_magic_armor
	if tier.is_effect_override:
		return tier.base_magic_armor if tier.base_magic_armor > 0.0 else base_magic_armor
	return base_magic_armor + tier.base_magic_armor

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
	if Engine.get_main_loop() != null and Global != null and Global.cur_char != null:
		Global.cur_char.recalculate_equipment_passives()

## Creates an independent clone of this equipment initialized to a specific rarity tier.
## Designed for Reward Trees, Combat Drops, and Shop inventories.
func duplicate_with_rarity(target_rarity: Rarity) -> Equipment:
	var dup: Equipment = duplicate(true)
	dup.rarity = target_rarity
	return dup

## Executes all active effects configured on this equipment.
func activate(context = null) -> void:
	var cur_char: PlayerResource = _resolve_char(context)
	var cur_enemy: EnemyResource = _resolve_enemy(context)
	var ctx: MatchContext = _resolve_match_ctx(context)
	if cur_char == null:
		return

	var mult: float = get_context_potency_multiplier(ctx)
	var is_crit: bool = criting or (ctx != null and ctx.has_crit)
	var crit_factor: float = (1.0 + cur_char.crit_mutly / 100.0) if is_crit else 1.0

	# 1. Pre-Effect Hand Combo
	var eff_combo_before: int = get_effective_combo_points_before()
	if eff_combo_before != 0:
		cur_char.modify_stat("hand_combo", eff_combo_before)

	# 2. Attack & Damage Effect
	var eff_dmg: float = get_effective_base_damage()
	var eff_combo_mult: float = get_effective_damage_combo_multiplier()
	if eff_dmg > 0.0 or eff_combo_mult > 0.0:
		if cur_enemy != null:
			var loops: int = get_effective_hit_count()
			var stat_bonus: float = _get_stat_value(cur_char, damage_stat_scaling)
			var flat_upg: float = float(upgrade) if not upgrade_scales_combo_mult else 0.0
			var total_combo_mult: float = eff_combo_mult + (float(upgrade) if upgrade_scales_combo_mult else 0.0)

			for i in loops:
				var dmg_val: float = eff_dmg + stat_bonus + flat_upg
				if total_combo_mult > 0.0:
					dmg_val += cur_char.hand_combo * total_combo_mult
				dmg_val = max(1.0, roundf(dmg_val * mult * crit_factor))
				cur_enemy.take_dmg(dmg_val, int(damage_type))
				if ctx != null and ctx.lifesteal_bonus > 0.0:
					var heal_amt: float = max(1.0, roundf(dmg_val * ctx.lifesteal_bonus))
					cur_char.modify_stat("cur_health", heal_amt)

	# 3. Physical Armor Effect
	var eff_arm: float = get_effective_base_armor()
	if eff_arm > 0.0:
		var arm_val: float = eff_arm + float(upgrade) + _get_stat_value(cur_char, armor_stat_scaling)
		if multiply_armor_by_combo:
			arm_val *= max(1, cur_char.hand_combo)
		arm_val = roundf(arm_val * mult * crit_factor)
		cur_char.modify_stat("cur_armor", arm_val)

	# 4. Magic Armor Effect
	var eff_m_arm: float = get_effective_base_magic_armor()
	if eff_m_arm > 0.0:
		var m_arm_val: float = eff_m_arm + float(upgrade) + _get_stat_value(cur_char, magic_armor_stat_scaling)
		if multiply_magic_armor_by_combo:
			m_arm_val *= max(1, cur_char.hand_combo)
		m_arm_val = roundf(m_arm_val * mult * crit_factor)
		cur_char.modify_stat("cur_mage_armor", m_arm_val)

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
		cur_char.modify_stat("dodging", true, false)

	var eff_gold: int = get_effective_gold_to_give()
	if eff_gold > 0:
		cur_char.modify_stat("gold", eff_gold + upgrade)

	# 7. Post-Effect Hand Combo / Finisher Consumption
	var eff_combo_after: int = get_effective_combo_points_after()
	if consume_all_combo:
		cur_char.modify_stat("hand_combo", 0, false)
	elif eff_combo_after != 0:
		cur_char.modify_stat("hand_combo", eff_combo_after)

	_on_custom_activate(cur_char, cur_enemy, ctx)

## Optional virtual hook for unique one-off equipment scripts.
func _on_custom_activate(_cur_char: PlayerResource, _cur_enemy: EnemyResource, _ctx: MatchContext) -> void:
	pass

## Builds a rich BBCode description reflecting current player stats, rarity bonuses, and upgrades across all active effects.
func get_effect_description(char_resource = null, upgrades: int = -1) -> String:
	var upg: int = upgrade if upgrades < 0 else upgrades
	var c_res = char_resource if char_resource != null else Global.cur_char
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
		var stat_bonus: float = _get_stat_value(c_res, damage_stat_scaling)
		var flat_upg: float = float(upg) if not upgrade_scales_combo_mult else 0.0
		var dmg: float = eff_dmg + stat_bonus + flat_upg
		var combo_mult: float = eff_combo_mult + (float(upg) if upgrade_scales_combo_mult else 0.0)
		var count: int = get_effective_hit_count()
		var color_str: String = "#3ca370" if damage_type == DamageType.MAGIC else "#ae2334"
		var type_label: String = " Magic" if damage_type == DamageType.MAGIC else ""

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
		var total_armor: float = eff_arm + float(upg) + _get_stat_value(c_res, armor_stat_scaling)
		if multiply_armor_by_combo:
			parts.append("Gives: [color=#4d65b4]%s[/color] Armor * [color=#7a3045]Combo[/color]" % [_fmt(total_armor)])
		else:
			parts.append("Gives: [color=#4d65b4]%s[/color] Armor" % [_fmt(total_armor)])

	var eff_m_arm: float = get_effective_base_magic_armor()
	if eff_m_arm > 0.0:
		var total_m_armor: float = eff_m_arm + float(upg) + _get_stat_value(c_res, magic_armor_stat_scaling)
		if multiply_magic_armor_by_combo:
			parts.append("Gives: [color=#0b8a8f]%s[/color] Magic Armor * [color=#7a3045]Combo[/color]" % [_fmt(total_m_armor)])
		else:
			parts.append("Gives: [color=#0b8a8f]%s[/color] Magic Armor" % [_fmt(total_m_armor)])

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

func _resolve_char(context) -> PlayerResource:
	if context is Dictionary and context.has("attacker"):
		return context["attacker"]
	return Global.cur_char

func _resolve_enemy(context) -> EnemyResource:
	if context is Dictionary and context.has("target"):
		return context["target"]
	return Global.cur_enemy

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
	var target_base: int = int(target_color / 100) * 100
	if bound_color > 0 and int(bound_color / 100) * 100 == target_base:
		return true
	for c in allowed_colors:
		if int(c) == 0 or int(int(c) / 100) * 100 == target_base:
			return true
	var tier = get_active_tier()
	if tier != null:
		if tier.allow_all_colors:
			return true
		for c in tier.extra_allowed_colors:
			if int(c) == 0 or int(int(c) / 100) * 100 == target_base:
				return true
	return false

func get_effective_allowed_colors() -> Array[int]:
	if is_colorless():
		if Engine.get_main_loop() != null and Global != null and Global.cur_char != null and not Global.cur_char.active_color_pool.is_empty():
			return Global.cur_char.active_color_pool
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
