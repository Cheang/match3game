@tool
extends Resource
class_name Reward

## Defines the rarity tier of this reward card (influences draft probabilities and card borders).
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	GODLY
}

## Defines whether this card is offered in standard post-battle drafts or post-boss talent drafts.
enum RewardCategory {
	COMBAT,     ## Regular reward card offered after defeating standard enemies.
	PASSIVE     ## Powerful passive/talent reward card offered after defeating bosses.
}

# ==============================================================================
# 1. PRESENTATION & IDENTITY
# ==============================================================================
@export_group("Presentation & Identity")
## Title displayed at the top of the reward card.
@export var name: String = ""
## Optional custom narrative description. If left blank, descriptions are automatically generated from effects.
@export_multiline var description: String = ""
## Card illustration / icon texture.
@export var icon: Texture2D
## Background card frame texture (usually matches tile style).
@export var base: Texture2D
## Rarity tier of this reward card.
@export var rarity: Rarity = Rarity.COMMON
## Whether this card belongs to the combat pool or the post-boss passive pool.
@export var category: RewardCategory = RewardCategory.COMBAT

# ==============================================================================
# 2. EQUIPMENT GRANTED (Optional)
# ==============================================================================
@export_group("Equipment Granted")
## Equipment resources added to the player's inventory or prompted for track equip when this card is chosen.
@export var equipment_to_grant: Array[Equipment] = []

# ==============================================================================
# 3. STAT INCREASES (Optional)
# ==============================================================================
@export_group("Stat Increases")
## Permanent increase to the player's Might stat (boosts physical attacks).
@export var might: float = 0.0
## Permanent increase to the player's Grit stat (boosts physical armor).
@export var grit: float = 0.0
## Permanent increase to the player's Spirit stat (boosts magic and healing).
@export var spirit: float = 0.0
## Permanent increase to the player's Speed stat (grants extra moves per turn).
@export var speed: int = 0
## Permanent increase to the player's Maximum Health.
@export var max_health: float = 0.0
## Immediate restoration of current HP.
@export var heal_hp: float = 0.0
## Gold coins awarded immediately.
@export var gold: int = 0
## Extra combat reward rerolls granted.
@export var rerolls: int = 0
## Permanent increase to the player's critical strike chance percentage.
@export var crit_chance: int = 0

# ==============================================================================
# 4. ABILITIES & BOMBS (Optional)
# ==============================================================================
@export_group("Abilities & Bombs")
## Unlocks the ability for 4-tile vertical matches to spawn row bombs.
@export var unlock_row_bombs: bool = false
## Unlocks the ability for 4-tile horizontal matches to spawn column bombs.
@export var unlock_col_bombs: bool = false
## Unlocks the ability for L/T-shaped matches to spawn adjacent area bombs.
@export var unlock_adj_bombs: bool = false
## Custom progression flags set on the player when this card is selected.
@export var custom_flags: Array[String] = []

# ==============================================================================
# 5. TREE PROGRESSION & POOL BEHAVIOR
# ==============================================================================
@export_group("Tree Progression & Pool")
## Progression tags emitted when this reward is picked (used by RewardTree to unlock downstream nodes).
@export var unlock_tags: Array[String] = []
## If true, this reward is permanently removed from the draft pool once chosen (default for equipment & unique passives).
@export var remove_from_pool_when_picked: bool = true

# ==============================================================================
# BACKWARD COMPATIBILITY ACCESSORS
# ==============================================================================
## Legacy getter/setter for rearity string format used by older reward cards.
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

## Returns resolved equipment items granted by this reward.
func get_resolved_modifiers() -> Array[Equipment]:
	var mods: Array[Equipment] = []
	for eq in equipment_to_grant:
		if eq != null:
			mods.append(eq.duplicate(true))
	return mods

## Activates all effects of this reward on the current player.
## If grant_equipment is false (e.g. when already slotted via SlotEquipModal), equipment is skipped.
func activate(grant_equipment: bool = true) -> void:
	if Global.cur_char == null:
		return
	var p = Global.cur_char

	# 1. Apply Stats
	if might != 0.0: p.modify_stat("might", might)
	if grit != 0.0: p.modify_stat("grit", grit)
	if spirit != 0.0: p.modify_stat("spirit", spirit)
	if speed != 0: p.modify_stat("speed", speed)
	if max_health != 0.0: p.modify_stat("max_health", max_health)
	if heal_hp != 0.0: p.modify_stat("cur_health", heal_hp)
	if gold != 0: p.modify_stat("gold", gold)
	if rerolls != 0: p.modify_stat("rerolls", rerolls)
	if crit_chance != 0: p.modify_stat("crit_chance", crit_chance)

	# 2. Apply Abilities
	if unlock_row_bombs: p.set_flag("flg_can_spawn_row_bombs", true)
	if unlock_col_bombs: p.set_flag("flg_can_spawn_col_bombs", true)
	if unlock_adj_bombs: p.set_flag("flg_can_spawn_adj_bombs", true)
	for f in custom_flags:
		p.set_flag(f, true)

	# 3. Apply Equipment (if not handled by modal UI)
	if grant_equipment:
		for eq in get_resolved_modifiers():
			p.add_modifier_reward(eq, true)

	# 4. Tree Progression
	apply_progression()

## Emits unlock tags to the player's active RewardTree and records flags.
func apply_progression() -> void:
	if Global.cur_char == null:
		return
	var p = Global.cur_char
	for f in custom_flags:
		p.set_flag(f, true)
	if p.active_reward_tree != null:
		p.active_reward_tree.on_reward_chosen(self, p)

## Legacy alias for apply_progression().
func boost() -> void:
	apply_progression()

## Returns dynamic BBCode text summarizing all effects granted by this reward.
func get_effect_description() -> String:
	if description != "" and not description.begins_with("Gain") and not description.begins_with("Adds") and not description.begins_with("Heals"):
		return description

	var lines: Array[String] = []

	for eq in equipment_to_grant:
		if eq != null:
			lines.append("Gain 1 [color=#f2c94c]%s[/color]: %s" % [eq.piece_name, eq.get_effect_description()])

	if might != 0.0: lines.append("[color=#ae2334]Might +%s[/color]" % _fmt(might))
	if grit != 0.0: lines.append("[color=#4d65b4]Grit +%s[/color]" % _fmt(grit))
	if spirit != 0.0: lines.append("[color=#a854a8]Spirit +%s[/color]" % _fmt(spirit))
	if speed != 0: lines.append("[color=#3ca370]Speed +%d[/color]" % speed)
	if max_health != 0.0: lines.append("[color=#e06f8b]Max Health +%s[/color]" % _fmt(max_health))
	if heal_hp != 0.0: lines.append("[color=#5ac54f]Heal %s HP[/color]" % _fmt(heal_hp))
	if gold != 0: lines.append("[color=#f2c94c]+%d Gold[/color]" % gold)
	if rerolls != 0: lines.append("[color=#639bff]+%d Reroll(s)[/color]" % rerolls)
	if crit_chance != 0: lines.append("[color=#e28335]+%d%% Crit Chance[/color]" % crit_chance)

	if unlock_row_bombs: lines.append("Unlocks [color=#d4d2c5]Row Bombs[/color]")
	if unlock_col_bombs: lines.append("Unlocks [color=#d4d2c5]Column Bombs[/color]")
	if unlock_adj_bombs: lines.append("Unlocks [color=#d4d2c5]Area Bombs[/color]")

	if not lines.is_empty():
		return "\n".join(lines)
	return description

func _fmt(val: float) -> String:
	if is_equal_approx(val, roundf(val)):
		return str(int(roundf(val)))
	return str(snappedf(val, 0.1))
