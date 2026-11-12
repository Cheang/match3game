extends Control

## Reward Screen V2 (reward-screen.gd)
## Copy of the reward screen for V2 iteration and standalone testing.
## Supports:
##  1. Standard post-combat 3-choice reward drafting (Monster pool, Class pool, 50/50 roll).
##  2. Build-affinity weighting based on player's current equipment build.
##  3. Fixed-rarity locks, rarity floors, and rarity ceilings.
##  4. Automatic standalone test mode when played on its own (F6 in Godot):
##     - Automatically provisions a test Warrior with loadouts and rerolls.
##     - Provisions mock monster rewards if none exist.
##     - Continuous testing loop: claiming a card or skipping generates the next draft.
##     - Standalone Testing Toolbar: toggle Normal / Boss draft mode, add rerolls,
##       reset Warrior, roll new draft, and inspect full loadout overlay (Key: I).

signal draft_generated(choices: Array[Resource])
signal reward_claimed_in_test(reward: Resource)

@onready var skip: Button = find_child("skip", true, false)
@onready var reroll: Button = find_child("reroll", true, false)
@onready var title_label: Label = find_child("title_label", true, false)
@onready var inventory_button: InventoryButton = find_child("inventory_button", true, false)
@onready var bottom_bar: Control = find_child("bottom_bar", true, false)
@onready var reward_cards: Array[RewardCard] = _init_reward_cards()

func _init_reward_cards() -> Array[RewardCard]:
	var cards: Array[RewardCard] = []
	for card_name in ["rc_", "rc_2", "rc_3"]:
		var c = find_child(card_name, true, false)
		if c is RewardCard:
			cards.append(c)
	if cards.is_empty():
		var r_cont = find_child("reward_cont", true, false)
		if r_cont == null:
			r_cont = find_child("rewards", true, false)
		if r_cont != null:
			for child in r_cont.get_children():
				if child is RewardCard:
					cards.append(child)
	return cards

func _ensure_nodes() -> void:
	if skip == null:
		skip = find_child("skip", true, false)
	if reroll == null:
		reroll = find_child("reroll", true, false)
	if title_label == null:
		title_label = find_child("title_label", true, false)
	if inventory_button == null:
		inventory_button = find_child("inventory_button", true, false)
	if bottom_bar == null:
		bottom_bar = find_child("bottom_bar", true, false)
	if reward_cards.is_empty():
		reward_cards = _init_reward_cards()

var rewards: Array = []
var monster_rewards: Array = []
var rarity_dict := {
	"COMMON": [],
	"UNCOMMON": [],
	"RARE": [],
	"EPIC": [],
	"LEGENDARY": [],
	"GODLY": []
}
var rarity_tiers = [
	["GODLY", 110],
	["LEGENDARY", 97],
	["EPIC", 90],
	["RARE", 75],
	["UNCOMMON", 50],
	["COMMON", 0]
]

var is_boss_draft: bool = false
## Records which source ("monster" or "class") each of the 3 draft slots drew from on the most recent roll.
var last_draft_sources: Array[String] = []

## Standalone testing properties
var is_standalone: bool = false

func _ready() -> void:
	_ensure_nodes()
	# Detect standalone execution (run scene directly or no active character loaded)
	if Global.cur_char == null:
		is_standalone = true
		_init_standalone_mode()
	elif Global.cur_enemy == null:
		Global.set_up_enemy()

	if not Global.pending_reward_context.is_empty():
		is_boss_draft = bool(Global.pending_reward_context.get("is_boss", Global.boss_beaten))
	else:
		is_boss_draft = Global.boss_beaten
	Global.boss_beaten = false

	_update_title()
	get_rewards_from_player()
	update_reroll_btn()
	get_rewards()
	Global.game_is_played = true

func _update_title() -> void:
	if title_label != null:
		title_label.text = "Boss Reward" if is_boss_draft else "Pick a reward"

func get_rewards() -> void:
	if Global.cur_char == null:
		return
	get_rewards_from_player()
	var drafted: Array[Resource] = generate_three_choice_draft(monster_rewards, rewards)
	for i in range(reward_cards.size()):
		if i < drafted.size():
			reward_cards[i].reward_resource = drafted[i]
			reward_cards[i].draft_source = last_draft_sources[i] if i < last_draft_sources.size() else ""
			reward_cards[i].is_boss_reward = is_boss_draft
			reward_cards[i].visible = drafted[i] != null
			if drafted[i] != null:
				reward_cards[i].load_btn()
		else:
			reward_cards[i].reward_resource = null
			reward_cards[i].visible = false

	draft_generated.emit(drafted)

## Generates the 3 post-combat choices:
## Slot 0: Defeated monster's loot_table
## Slot 1: Player's class reward pool
## Slot 2: 50/50 random draw from either the monster's loot_table (< 0.5) or the player's class pool (>= 0.5)
func generate_three_choice_draft(
	monster_pool: Array,
	class_pool: Array,
	third_slot_roll: float = -1.0
) -> Array[Resource]:
	var result: Array[Resource] = []
	last_draft_sources.clear()
	var chosen_identities: Dictionary = {}

	var roll_val: float = third_slot_roll if third_slot_roll >= 0.0 else randf()
	var third_is_monster: bool = roll_val < 0.5

	var slot_sources: Array[String] = [
		"monster",
		"class",
		"monster" if third_is_monster else "class"
	]

	for slot_idx in range(3):
		var preferred_source: String = slot_sources[slot_idx]
		var primary_pool: Array = monster_pool if preferred_source == "monster" else class_pool
		var fallback_pool: Array = class_pool if preferred_source == "monster" else monster_pool
		var actual_source: String = preferred_source

		var rolled_rarity: String = roll_rarity_tier()
		var picked: Resource = _draw_from_pool(primary_pool, rolled_rarity, chosen_identities, preferred_source == "class")
		if picked == null:
			# If unique pool is smaller than 3, allow duplicate identity from primary pool first
			var empty_ids: Dictionary = {}
			picked = _draw_from_pool(primary_pool, rolled_rarity, empty_ids, preferred_source == "class")
		if picked == null:
			var fallback_source: String = "class" if preferred_source == "monster" else "monster"
			picked = _draw_from_pool(fallback_pool, rolled_rarity, chosen_identities, fallback_source == "class")
			if picked != null:
				actual_source = fallback_source
		if picked == null:
			var fallback_source: String = "class" if preferred_source == "monster" else "monster"
			var empty_ids: Dictionary = {}
			picked = _draw_from_pool(fallback_pool, rolled_rarity, empty_ids, fallback_source == "class")
			if picked != null:
				actual_source = fallback_source

		if picked != null:
			var id_key: String = RewardGrantHandler.get_identity_key(picked)
			if id_key != "":
				chosen_identities[id_key] = true
		result.append(picked)
		last_draft_sources.append(actual_source)

	return result

func roll_rarity_tier() -> String:
	var bonus: int = 0
	if Global.cur_char != null and "rarity_bonus" in Global.cur_char:
		bonus = int(Global.cur_char.get("rarity_bonus"))
	var random_number: int = (randi() % 100) + bonus
	for tier in rarity_tiers:
		var rarity: String = tier[0]
		var threshold: int = tier[1]
		if random_number >= threshold:
			if rarity == "GODLY" and bonus <= 0:
				continue
			return rarity
	return "COMMON"

func _draw_from_pool(pool: Array, rolled_rarity: String, excluded_identities: Dictionary, use_build_affinity: bool = false) -> Resource:
	if pool == null or pool.is_empty():
		return null

	var unique_candidates: Array[Resource] = []
	for item in pool:
		if item == null or not (item is Resource):
			continue
		if not RewardGrantHandler.is_supported_reward(item):
			continue
		if not RewardGrantHandler.can_be_offered_to(item, Global.cur_char):
			continue
		var id_key: String = RewardGrantHandler.get_identity_key(item)
		if id_key != "" and excluded_identities.has(id_key):
			continue
		unique_candidates.append(item)

	if unique_candidates.is_empty():
		return null

	# Filter candidates eligible to roll at rolled_rarity (respecting fixed_rarity, min_rarity floor, and max_rarity ceiling!)
	var tier_matches: Array[Resource] = []
	for cand in unique_candidates:
		if RewardGrantHandler.can_roll_at_rarity(cand, rolled_rarity):
			tier_matches.append(cand)

	var chosen_template: Resource = null
	var chosen_rarity: String = rolled_rarity
	if not tier_matches.is_empty():
		chosen_template = RewardGrantHandler.pick_weighted_candidate(tier_matches, Global.cur_char, use_build_affinity)
	else:
		# Fallback across rarity_tiers if pool only contains rewards constrained to another tier range
		var bonus: int = int(Global.cur_char.get("rarity_bonus")) if (Global.cur_char != null and "rarity_bonus" in Global.cur_char) else 0
		for tier in rarity_tiers:
			var fallback_r: String = tier[0]
			if fallback_r == "GODLY" and bonus <= 0:
				continue
			var fallback_matches: Array[Resource] = []
			for cand in unique_candidates:
				if RewardGrantHandler.can_roll_at_rarity(cand, fallback_r):
					fallback_matches.append(cand)
			if not fallback_matches.is_empty():
				chosen_template = RewardGrantHandler.pick_weighted_candidate(fallback_matches, Global.cur_char, use_build_affinity)
				chosen_rarity = fallback_r
				break
		if chosen_template == null:
			chosen_template = RewardGrantHandler.pick_weighted_candidate(unique_candidates, Global.cur_char, use_build_affinity)

	return RewardGrantHandler.prepare_draft_instance(chosen_template, chosen_rarity)

func choose_reward() -> Resource:
	var rolled_rarity: String = roll_rarity_tier()
	var empty_ids: Dictionary = {}
	return _draw_from_pool(rewards, rolled_rarity, empty_ids, true)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
func update_reroll_btn() -> void:
	if reroll != null and Global.cur_char != null:
		reroll.text = "Reroll X%d" % Global.cur_char.rerolls
		reroll.disabled = (Global.cur_char.rerolls <= 0)

func get_rewards_from_player() -> void:
	for k in rarity_dict:
		rarity_dict[k].clear()
	rewards.clear()
	monster_rewards.clear()

	if Global.cur_char != null:
		if is_boss_draft and not Global.cur_char.rewards_passive.is_empty():
			rewards = Global.cur_char.rewards_passive.duplicate()
		else:
			rewards = Global.cur_char.rewards_piece.duplicate()

	if not Global.pending_reward_context.is_empty() and Global.pending_reward_context.has("monster_loot"):
		var ctx_loot: Array = Global.pending_reward_context["monster_loot"]
		for item in ctx_loot:
			if item != null:
				monster_rewards.append(item)
	elif Global.cur_enemy != null and Global.cur_enemy.loot_table != null:
		for item in Global.cur_enemy.loot_table:
			if item != null:
				monster_rewards.append(item)
	elif Global.def_enemy != null and Global.def_enemy.loot_table != null:
		for item in Global.def_enemy.loot_table:
			if item != null:
				monster_rewards.append(item)

	# If monster rewards are still empty (e.g. standalone test mode), populate defaults
	if monster_rewards.is_empty() and is_standalone:
		_populate_standalone_monster_rewards()

	for rew in rewards:
		if rew != null:
			var r_name: String = RewardGrantHandler.get_rarity_name(rew)
			if rarity_dict.has(r_name):
				rarity_dict[r_name].append(rew)

# ==============================================================================
# CARD CLAIMING & PROCEED HANDLER
# ==============================================================================
## Called by reward_card.gd when a reward is claimed.
## In standalone test mode, prevents leaving the scene and generates a fresh draft immediately!
func handle_reward_proceed(card: RewardCard) -> void:
	var claimed_res: Resource = card.reward_resource if card != null else null
	var _r_name: String = RewardGrantHandler.get_display_name(claimed_res)
	var _r_rarity: String = RewardGrantHandler.get_rarity_name(claimed_res)

	reward_claimed_in_test.emit(claimed_res)

	if is_standalone:
		get_rewards()
		update_reroll_btn()
	else:
		if Global.boss_beaten:
			SceneManager.change_scene("res://ui/screens/main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		elif Global.post_combat_event != null:
			Global.area_cur_event = Global.post_combat_event
			Global.post_combat_event = null
			SceneManager.change_scene("res://events/event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		else:
			SceneManager.change_scene("res://map/locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

# ==============================================================================
# BUTTON SIGNALS
# ==============================================================================
func _on_skip_pressed() -> void:
	if is_standalone:
		get_rewards()
		return

	Global.game_is_played = false
	if Global.post_combat_event != null:
		Global.area_cur_event = Global.post_combat_event
		Global.post_combat_event = null
		SceneManager.change_scene("res://events/event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://map/locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_reroll_pressed() -> void:
	if Global.cur_char != null and Global.cur_char.rerolls > 0:
		Global.cur_char.modify_stat("rerolls", -1)
		get_rewards()
	update_reroll_btn()

func _on_background_child_entered_tree(node: Node) -> void:
	node.visible = true

func _on_reroll_mouse_exited() -> void:
	release_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			# Toggle full Loadout / Inventory Overlay
			InventoryOverlay.toggle_overlay()
			get_viewport().set_input_as_handled()

# ==============================================================================
# STANDALONE TESTING INITIALIZATION & CONTROLS
# ==============================================================================
func _init_standalone_mode() -> void:
	# Load Warrior player resource as active test character
	var warrior_template: PlayerResource = load("res://entities/player/warrior/warrior.tres")
	if warrior_template != null:
		Global.cur_char = warrior_template.duplicate(true)
	else:
		Global.cur_char = PlayerResource.new()

	Global.cur_char.ensure_loadout_tracks()
	Global.cur_char.rerolls = 5
	Global.cur_char.gold = 100

	# Ensure starting red track has Punch equipped so build-affinity can be verified
	var red_track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(100)
	if red_track != null and red_track.equipped_modifiers.is_empty():
		var punch_card: Reward = load("res://rewards/cards/fists/fists1_punch.tres")
		if punch_card != null:
			RewardGrantHandler.grant_reward(punch_card, false, Global.cur_char)

	_populate_standalone_monster_rewards()

func _populate_standalone_monster_rewards() -> void:
	if Global.def_enemy != null and Global.def_enemy.loot_table != null:
		for item in Global.def_enemy.loot_table:
			if item != null and not monster_rewards.has(item):
				monster_rewards.append(item)
	var sample_paths: Array[String] = [
		"res://rewards/enemy_loot/wild_boar/boar_meat.tres",
		"res://rewards/cards/utility/bomb0_hbombs.tres",
		"res://rewards/cards/utility/bomb0_vbombs.tres",
		"res://rewards/cards/utility/bomb0_adjbombs.tres",
		"res://rewards/cards/utility/iron_wall.tres",
		"res://rewards/cards/utility/shields_up.tres",
		"res://rewards/cards/utility/general_healing_potion.tres",
		"res://rewards/cards/utility/general_rush.tres",
		"res://rewards/cards/stats/tavern_heal_small.tres",
		"res://rewards/cards/stats/tavern_heal_large.tres",
		"res://rewards/cards/body/body0_strong_body_1.tres"
	]
	for p in sample_paths:
		var item: Resource = load(p)
		if item != null and not monster_rewards.has(item):
			monster_rewards.append(item)
