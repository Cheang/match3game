class_name BossOfferCondition
extends Resource

## Defines an optional conditional boss entry that can appear on the Boss Select table
## (typically +1 or +2 bonus posters beyond the area's 1-3 base bosses).

@export var boss_location: Location
## All listed player flags/unlock tags must be active on the player.
@export var required_player_flags: Array[String] = []
## None of these flags may be active on the player.
@export var forbidden_player_flags: Array[String] = []
## Optional class filter (e.g. "Warrior"); empty allows any class.
@export var required_player_class: String = ""
## Minimum run level (1-based; 0 = any).
@export var min_level: int = 0
## Minimum player gold required (0 = any).
@export var min_gold: int = 0


func is_met(player: PlayerResource, current_level: int) -> bool:
	if boss_location == null:
		return false
	if min_level > 0 and current_level < min_level:
		return false
	if player == null:
		return required_player_flags.is_empty() and required_player_class == "" and min_gold <= 0
	if required_player_class != "" and player.player_class.to_lower() != required_player_class.to_lower():
		return false
	if min_gold > 0 and player.gold < min_gold:
		return false
	for f in required_player_flags:
		if f != "" and not player.has_flag(f):
			return false
	for f in forbidden_player_flags:
		if f != "" and player.has_flag(f):
			return false
	return true
