extends Control

@onready var skip: Button = $rewards/VBoxContainer/HBoxContainer/skip
@onready var reroll: Button = $rewards/VBoxContainer/HBoxContainer/reroll
@onready var reward_cards: Array[reward_card] = [
	$rewards/VBoxContainer/rc_,
	$rewards/VBoxContainer/rc_2,
	$rewards/VBoxContainer/rc_3
]

var rewards
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

func _ready() -> void:
	get_rewards_from_player()
	update_reroll_btn()
	get_rewards()
	Global.game_is_played = true

func get_rewards():
	if !Global.cur_char:
		return
	var chosen_set := {}
	
	for i in reward_cards.size():
		var new_reward = choose_reward()
		# Ensure unique rewards
		var attempts = 0
		while new_reward in chosen_set and attempts < 50:
			new_reward = choose_reward()
			attempts += 1
		chosen_set[new_reward] = true
		reward_cards[i].reward_resource = new_reward
		reward_cards[i].load_btn()

func choose_reward():
	var bonus: int = 0
	if Global.cur_char != null and "rarity_bonus" in Global.cur_char:
		bonus = int(Global.cur_char.get("rarity_bonus"))
	var random_number = (randi() % 100) + bonus
	# Select based on probability
	for tier in rarity_tiers:
		var rarity = tier[0]
		var threshold = tier[1]
		if random_number >= threshold and rarity_dict.get(rarity, []).size() > 0:
			return rarity_dict[rarity][randi() % rarity_dict[rarity].size()]
	
	# Fallback: Select the first non-empty category (skipping GODLY without bonus)
	for tier in rarity_tiers:
		var rarity = tier[0]
		if rarity == "GODLY" and bonus <= 0:
			continue
		if rarity_dict.get(rarity, []).size() > 0:
			return rarity_dict[rarity][randi() % rarity_dict[rarity].size()]
	return null

#Helper Functions --------------------------------------------------------------
func update_reroll_btn():
	if Global.cur_char:
		reroll.text = "Reroll X%d" % Global.cur_char.rerolls

func get_rewards_from_player():
	for k in rarity_dict:
		rarity_dict[k].clear()
	if Global.cur_char == null:
		return
	rewards = (Global.cur_char.rewards_passive if Global.boss_beaten else Global.cur_char.rewards_piece).duplicate()
	Global.boss_beaten = false
	for rew in rewards:
		if rew != null and rarity_dict.has(rew.rearity):
			rarity_dict[rew.rearity].append(rew)

#On Signals---------------------------------------------------------------------
func _on_skip_pressed() -> void:
	Global.game_is_played = false
	if Global.post_combat_event != null:
		Global.area_cur_event = Global.post_combat_event
		Global.post_combat_event = null
		SceneManager.change_scene("res://event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_reroll_pressed() -> void:
	if Global.cur_char != null and Global.cur_char.rerolls > 0:
		Global.cur_char.modify_stat("rerolls", -1)
		get_rewards()
	update_reroll_btn()

func _on_background_child_entered_tree(node: Node) -> void:
	node.visible = true


func _on_reroll_mouse_exited() -> void:
	release_focus()
