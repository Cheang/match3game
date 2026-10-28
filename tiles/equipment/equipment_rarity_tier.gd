@tool
extends Resource
class_name EquipmentRarityTier

## Defines which rarity tier this configuration applies to.
## 0 = COMMON, 1 = UNCOMMON, 2 = RARE, 3 = EPIC, 4 = LEGENDARY, 5 = GODLY
enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4,
	GODLY = 5
}

# ==============================================================================
# 1. TIER IDENTITY
# ==============================================================================
@export_group("Tier Identity")
## The rarity tier this resource configures.
@export var rarity: Rarity = Rarity.UNCOMMON
## Optional custom narrative description for this tier. If blank, auto-generates from stats and effects.
@export_multiline var custom_description: String = ""

# ==============================================================================
# 2. PASSIVE HERO STAT BOOSTS
# (These stats are granted to the hero while this equipment is slotted on an active track.
#  They are automatically revoked if the equipment is unequipped or moved to the bag.)
# ==============================================================================
@export_group("Passive Hero Stat Boosts")
## Passive Might granted to the hero (Red Pillar: boosts physical damage).
@export var might: float = 0.0
## Passive Grit granted to the hero (Blue Pillar: boosts armor).
@export var grit: float = 0.0
## Passive Speed granted to the hero (Green Pillar: extra tile swaps per turn).
@export var speed: int = 0
## Passive Spirit granted to the hero (Purple/White Pillar: boosts healing and magic).
@export var spirit: float = 0.0
## Passive Max Health added to the hero.
@export var max_health: float = 0.0
## Passive Critical Strike chance bonus (0% to 100%).
@export_range(0, 100) var crit_chance: int = 0
## Passive Critical Strike damage multiplier bonus (e.g. 25.0 = +25% crit damage).
@export var crit_mutly: float = 0.0
## Passive Lifesteal fraction (e.g. 0.10 = 10% lifesteal).
@export var life_steal: float = 0.0
## Passive Starting Physical Armor granted at the start of every combat encounter.
@export var start_armor: float = 0.0
## Passive Starting Magic Armor granted at the start of every combat encounter.
@export var start_mage_armor: float = 0.0
## Passive percentage damage reduction (0% to 90%).
@export var dmg_reduction: float = 0.0
## Passive flat incoming damage reduction.
@export var dmg_reduction_flat: float = 0.0
## Passive cooldown reduction in turns for all equipment.
@export var cooldown_reduction: int = 0
## Passive bonus gold tile spawn chance (0% to 100%).
@export_range(0, 100) var gold_chance: int = 0
## Passive starting hand combo points at the start of combat turns.
@export var start_hand_combo: int = 0

# ==============================================================================
# 3. EFFECT SCALING & OVERRIDES
# ==============================================================================
@export_group("Effect Scaling & Overrides")
## If true, non-zero values below OVERRIDE the base equipment values.
## If false (default), values below are ADDED as bonuses to the base equipment values.
@export var is_effect_override: bool = false

## Base damage dealt (added as bonus or overrides base_damage if is_effect_override is true).
@export var base_damage: float = 0.0
## Number of hits per trigger (added as bonus or overrides hit_count).
@export var hit_count: int = 0
## Bonus damage added per point of Hand Combo.
@export var damage_combo_multiplier: float = 0.0

## Base Physical Armor granted when triggered.
@export var base_armor: float = 0.0
## Base Magic Armor granted when triggered.
@export var base_magic_armor: float = 0.0
## Base HP restored when triggered.
@export var base_heal: float = 0.0

## Bonus board swaps/moves granted when triggered.
@export var moves_to_give: int = 0
## Bonus Gold coins awarded when triggered.
@export var gold_to_give: int = 0
## Hand combo points added before effects resolve.
@export var combo_points_before: int = 0
## Hand combo points added after effects resolve.
@export var combo_points_after: int = 0

## Cooldown override in turns (-1 = keep base equipment cooldown, >= 0 = use this cooldown).
@export var cooldown_override: int = -1

# ==============================================================================
# 4. COLOR AVAILABILITY EXPANSION
# ==============================================================================
@export_group("Color Availability Expansion")
## If true, this equipment becomes Colorless at this rarity tier (can be equipped on ANY color track).
@export var allow_all_colors: bool = false
## Additional tile colors this equipment can be placed on at this rarity tier.
## (e.g. A Red-only item can add [BLUE, GREEN] here to unlock those tracks at higher rarities).
@export var extra_allowed_colors: Array[Global.TileColor] = []

# ==============================================================================
# HELPER METHODS
# ==============================================================================

## Returns a dictionary of all active, non-zero passive hero stat boosts configured for this tier.
func get_stat_boosts() -> Dictionary:
	var boosts: Dictionary = {}
	if might != 0.0: boosts["might"] = might
	if grit != 0.0: boosts["grit"] = grit
	if speed != 0: boosts["speed"] = speed
	if spirit != 0.0: boosts["spirit"] = spirit
	if max_health != 0.0: boosts["max_health"] = max_health
	if crit_chance != 0: boosts["crit_chance"] = crit_chance
	if crit_mutly != 0.0: boosts["crit_mutly"] = crit_mutly
	if life_steal != 0.0: boosts["life_steal"] = life_steal
	if start_armor != 0.0: boosts["start_armor"] = start_armor
	if start_mage_armor != 0.0: boosts["start_mage_armor"] = start_mage_armor
	if dmg_reduction != 0.0: boosts["dmg_reduction"] = dmg_reduction
	if dmg_reduction_flat != 0.0: boosts["dmg_reduction_flat"] = dmg_reduction_flat
	if cooldown_reduction != 0: boosts["cooldown_reduction"] = cooldown_reduction
	if gold_chance != 0: boosts["gold_chance"] = gold_chance
	if start_hand_combo != 0: boosts["start_hand_combo"] = start_hand_combo
	return boosts

## Returns formatted BBCode summary of the passive stat boosts.
func get_stat_boosts_bbcode() -> String:
	var parts: Array[String] = []
	if might != 0.0:
		parts.append("[color=#d84343]%s Might[/color]" % ("+" + str(might) if might > 0 else str(might)))
	if grit != 0.0:
		parts.append("[color=#4d65b4]%s Grit[/color]" % ("+" + str(grit) if grit > 0 else str(grit)))
	if speed != 0:
		parts.append("[color=#3ca370]%s Speed[/color]" % ("+" + str(speed) if speed > 0 else str(speed)))
	if spirit != 0.0:
		parts.append("[color=#a854a8]%s Spirit[/color]" % ("+" + str(spirit) if spirit > 0 else str(spirit)))
	if max_health != 0.0:
		parts.append("[color=#e05353]%s Max HP[/color]" % ("+" + str(max_health) if max_health > 0 else str(max_health)))
	if crit_chance != 0:
		parts.append("[color=#f2c94c]%s%% Crit[/color]" % ("+" + str(crit_chance) if crit_chance > 0 else str(crit_chance)))
	if crit_mutly != 0.0:
		parts.append("[color=#f2c94c]%s%% Crit DMG[/color]" % ("+" + str(crit_mutly) if crit_mutly > 0 else str(crit_mutly)))
	if life_steal != 0.0:
		parts.append("[color=#934988]%s%% Lifesteal[/color]" % ("+" + str(int(life_steal * 100)) if life_steal > 0 else str(int(life_steal * 100))))
	if start_armor != 0.0:
		parts.append("[color=#4d65b4]%s Start Armor[/color]" % ("+" + str(start_armor) if start_armor > 0 else str(start_armor)))
	if start_mage_armor != 0.0:
		parts.append("[color=#0b8a8f]%s Start M.Armor[/color]" % ("+" + str(start_mage_armor) if start_mage_armor > 0 else str(start_mage_armor)))
	if dmg_reduction != 0.0:
		parts.append("[color=#5d7a88]%s%% DMG Red[/color]" % ("+" + str(dmg_reduction) if dmg_reduction > 0 else str(dmg_reduction)))
	if dmg_reduction_flat != 0.0:
		parts.append("[color=#5d7a88]%s Flat Red[/color]" % ("+" + str(dmg_reduction_flat) if dmg_reduction_flat > 0 else str(dmg_reduction_flat)))
	if cooldown_reduction != 0:
		parts.append("[color=#639bff]-%d CD[/color]" % cooldown_reduction)
	if gold_chance != 0:
		parts.append("[color=#d4af37]%s%% Gold Chance[/color]" % ("+" + str(gold_chance) if gold_chance > 0 else str(gold_chance)))
	if start_hand_combo != 0:
		parts.append("[color=#7a3045]%s Combo[/color]" % ("+" + str(start_hand_combo) if start_hand_combo > 0 else str(start_hand_combo)))
	return " | ".join(parts)
