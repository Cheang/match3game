extends EntityResource
class_name EnemyResource

## Defines how this monster interacts with the match-3 board on its turn.
enum BehaviorCategory {
	SMART = 0,   ## Makes legal tile matches like the player; match color selects the track.
	BEAST = 1,   ## Destroys a board section (3x3 default or custom shape); majority destroyed color selects the track.
	HYBRID = 2   ## Alternates between SMART and BEAST on every action.
}

#------------------------------------------------------------------------------#
@export_category("Enemy Identity & Classification")
@export var name: String = "Monster"
@export_enum("minion", "boss", "miniboss") var type: int = 0
@export var behavior_category: BehaviorCategory = BehaviorCategory.SMART
## For HYBRID monsters, whether the first action of a fight is BEAST (true) or SMART (false).
@export var hybrid_starts_with_beast: bool = false
## Optional custom relative tile offsets for BEAST destruction. If empty, defaults to a 3x3 area (-1..1, -1..1).
@export var beast_custom_shape: Array[Vector2i] = []

#------------------------------------------------------------------------------#
@export_category("Monster Tracks & Loadout")
## Explicit colors that this monster has dedicated tracks for. All other colors route to the Colorless Fallback Track.
@export var explicit_track_colors: Array[int] = []
@export var red_track_modifiers: Array[Equipment] = []
@export var blue_track_modifiers: Array[Equipment] = []
@export var green_track_modifiers: Array[Equipment] = []
@export var purple_track_modifiers: Array[Equipment] = []
@export var white_track_modifiers: Array[Equipment] = []
## Fallback track used whenever the monster triggers a color not present in its explicit tracks.
@export var colorless_fallback_modifiers: Array[Equipment] = []

#------------------------------------------------------------------------------#
@export_category("Monster Loot")
## Pool of rewards (direct Equipment resources or Reward resources) specific to this monster.
@export var loot_table: Array[Resource] = []

#------------------------------------------------------------------------------#
@export_category("Legacy Offence & Phases")
@export var damage: float = 1.0
@export var has_phases: bool = false
@export var phase: int = 1:
	set(new_phase):
		phase = clamp(new_phase, 1, 4)
@export var attacks: Array[EnemyAttackBase] = []
@export_subgroup("Phase Attacks ")
@export var attacks_p2: Array[EnemyAttackBase] = []
@export var attacks_p3: Array[EnemyAttackBase] = []
@export var attacks_p4: Array[EnemyAttackBase] = []
@export var next_attack: EnemyAttackBase

#------------------------------------------------------------------------------#
@export_category("Art")
@export var health_bar: Texture2D = preload("res://assets/level_ui/enemy_health.png")
@export var shader: ShaderMaterial

#------------------------------------------------------------------------------#
@export_category("Obstacles")
@export var empty_spaces: Array[Vector2] = []
@export var ice_spaces: Array[Vector2] = []
@export var freeze_spaces: Array[Vector2] = []
@export var rock_spaces: Array[Vector2] = []
@export var flesh_spaces: Array[Vector2] = []

#==============================================================================#
# RUNTIME STATE
#==============================================================================#
var colorless_fallback_track: ColorLoadoutTrack = null
var hybrid_next_is_beast: bool = false
var _tracks_initialized: bool = false

# Signals (preserved for UI and GameMaster compatibility)
signal destroyPieces(space_to_destroy: Array[Vector2])
signal updateUIEnemy(stat: String)
signal enemyDied

func _init() -> void:
	super._init()
	speed = 1

func _on_entity_died() -> void:
	super._on_entity_died()
	enemyDied.emit()

func _on_stat_modified(stat: String) -> void:
	updateUIEnemy.emit(str(stat))

func _on_after_damage_taken(_net_damage: float, _type: int, _attacker: EntityResource) -> void:
	if has_phases:
		phase_change()

#==============================================================================#
# MONSTER TRACK RESOLUTION
#==============================================================================#

func ensure_loadout_tracks() -> void:
	var has_authored_explicit: bool = (
		not explicit_track_colors.is_empty()
		or not red_track_modifiers.is_empty()
		or not blue_track_modifiers.is_empty()
		or not green_track_modifiers.is_empty()
		or not purple_track_modifiers.is_empty()
		or not white_track_modifiers.is_empty()
	)
	if _tracks_initialized and colorless_fallback_track != null:
		if not (color_loadouts.is_empty() and has_authored_explicit):
			return
	rebuild_loadout_tracks()

func rebuild_loadout_tracks() -> void:
	_tracks_initialized = true
	color_loadouts.clear()

	var color_map := {
		100: red_track_modifiers,
		200: blue_track_modifiers,
		300: green_track_modifiers,
		400: purple_track_modifiers,
		500: white_track_modifiers
	}

	# Register explicit colors from explicit_track_colors array
	for c in explicit_track_colors:
		var base_c: int = get_base_family(int(c))
		if base_c > 0 and not color_loadouts.has(base_c):
			var track := ColorLoadoutTrack.new()
			track.color = base_c
			track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
			color_loadouts[base_c] = track

	# Populate explicit color tracks from exported modifier arrays
	for base_c in color_map.keys():
		var mods: Array[Equipment] = color_map[base_c]
		if not mods.is_empty():
			if not color_loadouts.has(base_c):
				var track := ColorLoadoutTrack.new()
				track.color = base_c
				track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
				color_loadouts[base_c] = track
			var target_track: ColorLoadoutTrack = color_loadouts[base_c]
			for m in mods:
				if m != null:
					target_track.equip_modifier(m.duplicate(true))

	# Initialize colorless fallback track
	colorless_fallback_track = ColorLoadoutTrack.new()
	colorless_fallback_track.color = 0
	colorless_fallback_track.max_slots = ColorLoadoutTrack.DEFAULT_MAX_SLOTS
	for m in colorless_fallback_modifiers:
		if m != null:
			colorless_fallback_track.equip_modifier(m.duplicate(true))

	# If no track modifiers were authored yet, synthesize fallback equipment from legacy attacks/damage
	if colorless_fallback_track.equipped_modifiers.is_empty() and color_loadouts.is_empty():
		_populate_default_fallback_from_legacy()

func _populate_default_fallback_from_legacy() -> void:
	var fallback_eq := Equipment.new()
	fallback_eq.piece_name = name + " Strike"
	fallback_eq.base_damage = max(1.0, damage)
	fallback_eq.damage_stat_scaling = Equipment.StatScaling.NONE
	fallback_eq.slot_cost = 1
	colorless_fallback_track.equip_modifier(fallback_eq)

func has_explicit_track_for_color(color_id: int) -> bool:
	ensure_loadout_tracks()
	if color_loadouts.has(color_id):
		return true
	var base_c: int = get_base_family(color_id)
	return color_loadouts.has(base_c)

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
	return colorless_fallback_track

func get_all_tracks() -> Array[ColorLoadoutTrack]:
	var tracks: Array[ColorLoadoutTrack] = super.get_all_tracks()
	if colorless_fallback_track != null and not tracks.has(colorless_fallback_track):
		tracks.append(colorless_fallback_track)
	return tracks

## Returns the active behavior mode for the next action (resolves HYBRID alternation).
func get_current_action_behavior() -> BehaviorCategory:
	if behavior_category == BehaviorCategory.HYBRID:
		return BehaviorCategory.BEAST if hybrid_next_is_beast else BehaviorCategory.SMART
	return behavior_category

## Advances HYBRID alternation state after an action is performed.
func advance_hybrid_action_state() -> void:
	if behavior_category == BehaviorCategory.HYBRID:
		hybrid_next_is_beast = not hybrid_next_is_beast

## Returns the relative Vector2i offsets for a BEAST destruction action.
## Defaults to a 3x3 area (-1..1, -1..1) unless beast_custom_shape is configured.
func get_beast_destruction_shape() -> Array[Vector2i]:
	if not beast_custom_shape.is_empty():
		return beast_custom_shape
	var default_3x3: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			default_3x3.append(Vector2i(dx, dy))
	return default_3x3

func reset_stats_at_beginning_of_fight() -> void:
	_tracks_initialized = false
	ensure_loadout_tracks()
	hybrid_next_is_beast = hybrid_starts_with_beast
	reset_modifiers_for_battle()
	recalculate_equipment_passives()
	modify_stat("dodging", false, false)
	modify_stat("moves_left", max(1, speed), false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("cur_armor", start_armor, false)
	modify_stat("cur_mage_armor", start_mage_armor, false)

func reset_stats_at_beginning_of_turn() -> void:
	tick_all_track_cooldowns(1)
	modify_stat("cur_armor", 0, false)
	modify_stat("hand_combo", start_hand_combo, false)
	modify_stat("moves_left", max(1, speed), false)

#==============================================================================#
# LEGACY HELPER FUNCTIONS
#==============================================================================#
func phase_change() -> void:
	var thresholds := [0.75, 0.5, 0.25]
	if phase <= thresholds.size() and cur_health <= max_health * thresholds[phase - 1]:
		phase += 1

func pick_next_attack() -> void:
	if not attacks.is_empty():
		next_attack = attacks.pick_random()
	if has_phases:
		var phase_attacks = [null, attacks_p2, attacks_p3, attacks_p4]
		if phase > 1 and phase <= phase_attacks.size() and phase_attacks[phase - 1] != null and not phase_attacks[phase - 1].is_empty():
			next_attack = phase_attacks[phase - 1].pick_random()

func destroy_pieces(space_to_destroy: Array[Vector2]) -> void:
	destroyPieces.emit(space_to_destroy)
