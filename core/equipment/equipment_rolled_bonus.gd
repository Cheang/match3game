class_name EquipmentRolledBonus
extends Resource

@export var type: EquipmentBonus.BonusType = EquipmentBonus.BonusType.MIGHT
@export var base_val: float = 1.0
@export var effective_val: float = 1.0
@export var color_value: int = 0
@export var trigger_buff: String = "combo"
@export var custom_text: String = ""
@export var is_godly_perk: bool = false

func _fmt(val: float) -> String:
	if is_equal_approx(val, roundf(val)):
		return str(int(roundf(val)))
	return str(snappedf(val, 0.1))

## Formats this rolled bonus as a BBCode text bullet.
## If multiplier_pct > 0, appends the scaling indicator (e.g. (+50%)).
func get_display_text(multiplier_pct: int = 0) -> String:
	var mult_tag: String = ""
	if multiplier_pct > 0 and not is_godly_perk:
		mult_tag = " [color=#7a3045](+%d%%)[/color]" % multiplier_pct

	if custom_text != "":
		if is_godly_perk:
			return "[color=#44ddff]★ Godly: %s[/color]" % custom_text
		return "• %s%s" % [custom_text, mult_tag]

	if is_godly_perk:
		return "[color=#44ddff]★ Godly: %s[/color]" % _format_stat_summary()

	return "• %s%s" % [_format_stat_summary(), mult_tag]

func _format_stat_summary() -> String:
	match type:
		EquipmentBonus.BonusType.MIGHT:
			return "+%s Might" % _fmt(effective_val)
		EquipmentBonus.BonusType.GRIT:
			return "+%s Grit" % _fmt(effective_val)
		EquipmentBonus.BonusType.AGILITY:
			return "+%s Agility" % _fmt(effective_val)
		EquipmentBonus.BonusType.SPIRIT:
			return "+%s Spirit" % _fmt(effective_val)
		EquipmentBonus.BonusType.MAX_HEALTH:
			return "+%s Max Health" % _fmt(effective_val)
		EquipmentBonus.BonusType.CRIT_CHANCE:
			return "+%s%% Crit Chance" % _fmt(effective_val)
		EquipmentBonus.BonusType.CRIT_MULTIPLIER:
			return "+%s%% Crit Damage" % _fmt(effective_val)
		EquipmentBonus.BonusType.LIFESTEAL:
			return "+%s%% Lifesteal" % _fmt(effective_val * 100.0 if effective_val <= 1.0 else effective_val)
		EquipmentBonus.BonusType.START_ARMOR:
			return "+%s Starting Armor" % _fmt(effective_val)
		EquipmentBonus.BonusType.START_MYSTIC_ARMOR:
			return "+%s Starting Mystic Armor" % _fmt(effective_val)
		EquipmentBonus.BonusType.DAMAGE_REDUCTION:
			return "+%s%% Damage Reduction" % _fmt(effective_val)
		EquipmentBonus.BonusType.DAMAGE_REDUCTION_FLAT:
			return "+%s Flat Damage Reduction" % _fmt(effective_val)
		EquipmentBonus.BonusType.GOLD_CHANCE:
			return "+%s%% Gold Tile Chance" % _fmt(effective_val)
		EquipmentBonus.BonusType.START_COMBO:
			return "+%s Starting Combo" % _fmt(effective_val)
		EquipmentBonus.BonusType.LOWER_COOLDOWN:
			var cd_int: int = int(roundf(effective_val))
			return "-%d Cooldown Turn%s" % [cd_int, "" if cd_int == 1 else "s"]
		EquipmentBonus.BonusType.REMOVE_SLOT_COST:
			var slot_int: int = int(roundf(effective_val))
			return "-%d Slot Cost" % slot_int
		EquipmentBonus.BonusType.EXTRA_COLOR:
			var c_name := ColorLoadoutTrack.get_color_name(color_value) if color_value > 0 else "Colorless"
			return "Adds %s Color Track" % c_name
		EquipmentBonus.BonusType.MAKE_COLORLESS:
			return "Colorless (Equippable on ANY Track)"
		EquipmentBonus.BonusType.GAIN_BUFF_ON_TRIGGER:
			match trigger_buff.to_lower():
				"dodge": return "On Trigger: Grants Dodge"
				"combo": return "On Trigger: +%s Combo" % _fmt(effective_val)
				"moves": return "On Trigger: +%s Move" % _fmt(effective_val)
				"armor": return "On Trigger: +%s Armor" % _fmt(effective_val)
				"mystic_armor": return "On Trigger: +%s Mystic Armor" % _fmt(effective_val)
				"heal": return "On Trigger: +%s HP" % _fmt(effective_val)
			return "On Trigger: +%s %s" % [_fmt(effective_val), trigger_buff.capitalize()]
		EquipmentBonus.BonusType.BONUS_BASE_DAMAGE:
			return "+%s Base Damage" % _fmt(effective_val)
		EquipmentBonus.BonusType.BONUS_DAMAGE:
			return "+%s Bonus Damage" % _fmt(effective_val)
		EquipmentBonus.BonusType.BONUS_HIT_COUNT:
			var h_int: int = int(roundf(effective_val))
			return "+%d Hit%s" % [h_int, "" if h_int == 1 else "s"]
	return "+%s Bonus" % _fmt(effective_val)
