extends Control

@onready var rc_: reward_card = $rewards/VBoxContainer/rc_
@onready var rc_2: reward_card = $rewards/VBoxContainer/rc_2
@onready var rc_3: reward_card = $rewards/VBoxContainer/rc_3

@onready var skip: Button = $rewards/VBoxContainer/HBoxContainer/skip
@onready var reroll: Button = $rewards/VBoxContainer/HBoxContainer/reroll

var reward_cards: Array[reward_card]

func _ready() -> void:
	reward_cards = [rc_, rc_2, rc_3]
	update_reroll_btn()
	get_rewards()
	Global.game_is_played = true

func get_rewards():
	var picked_rewards: Array[Reward]
	var rewards: Array[Reward]
	
	if !Global.cur_char:
		return
	if Global.boss_beaten == true:
		rewards = Global.cur_char.rewards_passive.duplicate()
		Global.boss_beaten = false
	else:
		rewards = Global.cur_char.rewards_piece.duplicate()
	
	for i in range(3):
		picked_rewards.append(choose_reward(rewards))
		if i == 1 and picked_rewards[i] == picked_rewards[i-1]:
			var loops = 0
			while picked_rewards[i] == picked_rewards[i-1] and loops < 50:
				picked_rewards.pop_back()
				picked_rewards.append(choose_reward(rewards))
				loops += 1
		if i == 2:
			if picked_rewards[i] == picked_rewards[i-1] or picked_rewards[i] == picked_rewards[i-2]:
				var loops = 0
				while picked_rewards[i] == picked_rewards[i-1] or picked_rewards[i] == picked_rewards[i-2] and loops < 50:
					picked_rewards.pop_back()
					picked_rewards.append(choose_reward(rewards))
					loops += 1
		reward_cards[i].reward_resource = picked_rewards[i]
		reward_cards[i].load_btn()

func choose_reward(target):
	var common_rewards = [] 
	var uncommon_rewards = [] 
	var rare_rewards = [] 
	var legendary_rewards = []
	
	for rew in target:
		match rew.rearity:
			"COMMON":
				common_rewards.append(rew)
			"UNCOMMON":
				uncommon_rewards.append(rew)
			"RARE":
				rare_rewards.append(rew)
			"LEGENDARY":
				legendary_rewards.append(rew)
				
	var random_number = randi() % 100
	if random_number < 50:
		return common_rewards[randi() % common_rewards.size()]
	elif random_number < 80 and random_number >= 50 and uncommon_rewards.size() > 0:
		return uncommon_rewards[randi() % uncommon_rewards.size()]
	elif random_number < 95 and random_number >= 80 and rare_rewards.size() > 0:
		return rare_rewards[randi() % rare_rewards.size()]
	elif random_number <= 100 and random_number >= 95 and legendary_rewards.size() > 0:
		return legendary_rewards[randi() % legendary_rewards.size()]
	else:
		return common_rewards[randi() % common_rewards.size()]

func update_reroll_btn():
	if Global.cur_char:
		reroll.text = "Reroll X%d" % Global.cur_char.rerolls

#On Signals---------------------------------------------------------------------
func _on_skip_pressed() -> void:
	Global.game_is_played = false
	SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_reroll_pressed() -> void:
	update_reroll_btn()
	if Global.cur_char.rerolls > 0:
		get_rewards()
		Global.cur_char.rerolls -= 1

func _on_background_child_entered_tree(node: Node) -> void:
	node.visible = true
