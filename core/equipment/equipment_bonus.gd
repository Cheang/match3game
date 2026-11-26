class_name EquipmentBonus
extends Resource

## Types of bonuses that an equipment piece can offer.
enum BonusType {
	# Core Stats
	MIGHT,
	GRIT,
	AGILITY,
	SPIRIT,

	# Secondary Stats
	MAX_HEALTH,
	CRIT_CHANCE,
	CRIT_MULTIPLIER,
	LIFESTEAL,
	START_ARMOR,
	START_MYSTIC_ARMOR,
	DAMAGE_REDUCTION,
	DAMAGE_REDUCTION_FLAT,
	GOLD_CHANCE,
	START_COMBO,

	# Mechanics & Utility
	LOWER_COOLDOWN,       ## Lowers cooldown_turns (minimum floor of 0)
	REMOVE_SLOT_COST,     ## Lowers slot_cost (minimum floor of 1)
	EXTRA_COLOR,          ## Adds an extra allowed track color (or colorless if 0)
	MAKE_COLORLESS,       ## Allows equipping on ANY color track

	# Trigger & Combat Buffs
	GAIN_BUFF_ON_TRIGGER, ## Grants buff/utility on activation (e.g. combo, dodge, moves, heal, armor)
	BONUS_BASE_DAMAGE,    ## Adds flat bonus to base damage (applied BEFORE multipliers)
	BONUS_DAMAGE,         ## Adds flat bonus damage (applied AFTER multipliers)
	BONUS_HIT_COUNT       ## Adds extra hit count
}

@export var type: BonusType = BonusType.MIGHT
@export var min_val: float = 1.0
@export var max_val: float = 2.0

## Target color family for EXTRA_COLOR (e.g. 100 for Red, 200 for Blue). 0 = Colorless.
@export var color_value: int = 0

## Trigger buff identifier for GAIN_BUFF_ON_TRIGGER (e.g. "combo", "dodge", "moves", "armor", "mystic_armor", "heal").
@export var trigger_buff: String = "combo"

## Optional custom display name or description override (used for unique Godly perks).
@export var custom_text: String = ""

static func get_bonus_type_name(b_type: BonusType) -> String:
	match b_type:
		BonusType.MIGHT: return "Might"
		BonusType.GRIT: return "Grit"
		BonusType.AGILITY: return "Agility"
		BonusType.SPIRIT: return "Spirit"
		BonusType.MAX_HEALTH: return "Max Health"
		BonusType.CRIT_CHANCE: return "Crit Chance"
		BonusType.CRIT_MULTIPLIER: return "Crit Damage"
		BonusType.LIFESTEAL: return "Lifesteal"
		BonusType.START_ARMOR: return "Starting Armor"
		BonusType.START_MYSTIC_ARMOR: return "Starting Mystic Armor"
		BonusType.DAMAGE_REDUCTION: return "Damage Reduction"
		BonusType.DAMAGE_REDUCTION_FLAT: return "Flat Damage Reduction"
		BonusType.GOLD_CHANCE: return "Gold Tile Chance"
		BonusType.START_COMBO: return "Starting Combo"
		BonusType.LOWER_COOLDOWN: return "Cooldown Reduction"
		BonusType.REMOVE_SLOT_COST: return "Reduced Slot Cost"
		BonusType.EXTRA_COLOR: return "Extra Color"
		BonusType.MAKE_COLORLESS: return "Colorless"
		BonusType.GAIN_BUFF_ON_TRIGGER: return "Activation Buff"
		BonusType.BONUS_BASE_DAMAGE: return "Base Damage"
		BonusType.BONUS_DAMAGE: return "Bonus Damage"
		BonusType.BONUS_HIT_COUNT: return "Bonus Hits"
	return "Bonus"

## Rolls a concrete EquipmentRolledBonus instance applying the rarity multiplier.
func roll(multiplier: float = 1.0, is_godly: bool = false, rng: RandomNumberGenerator = null) -> EquipmentRolledBonus:
	var rolled := EquipmentRolledBonus.new()
	rolled.type = type
	rolled.color_value = color_value
	rolled.trigger_buff = trigger_buff
	rolled.custom_text = custom_text
	rolled.is_godly_perk = is_godly

	# Roll base value in range [min_val, max_val]
	var raw_val: float = min_val
	if max_val > min_val:
		if rng != null:
			raw_val = rng.randf_range(min_val, max_val)
		else:
			raw_val = randf_range(min_val, max_val)
	else:
		raw_val = min_val

	# Integer-based stats round cleanly
	if _is_integer_stat(type):
		raw_val = roundf(raw_val)

	rolled.base_val = raw_val

	# Apply multiplier to effective value
	# For utility like LOWER_COOLDOWN, REMOVE_SLOT_COST, and COLOR, keep base integer value
	if type == BonusType.LOWER_COOLDOWN or type == BonusType.REMOVE_SLOT_COST or type == BonusType.EXTRA_COLOR or type == BonusType.MAKE_COLORLESS:
		rolled.effective_val = raw_val
	else:
		var eff: float = raw_val * multiplier
		rolled.effective_val = roundf(eff) if _is_integer_stat(type) else snappedf(eff, 0.05)

	return rolled

static func _is_integer_stat(b_type: BonusType) -> bool:
	match b_type:
		BonusType.MIGHT, BonusType.GRIT, BonusType.AGILITY, BonusType.SPIRIT, \
		BonusType.MAX_HEALTH, BonusType.CRIT_CHANCE, BonusType.GOLD_CHANCE, \
		BonusType.START_COMBO, BonusType.LOWER_COOLDOWN, BonusType.REMOVE_SLOT_COST, \
		BonusType.BONUS_HIT_COUNT, BonusType.BONUS_BASE_DAMAGE, BonusType.BONUS_DAMAGE:
			return true
	return false
