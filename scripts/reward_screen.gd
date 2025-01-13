extends Control

@onready var pratic1: GPUParticles2D = $background/GPUParticles2D
@onready var pratic2: GPUParticles2D = $background/GPUParticles2D2
@onready var pratic3: GPUParticles2D = $background/GPUParticles2D3
@onready var pratic4: GPUParticles2D = $background/GPUParticles2D4

@onready var rc_: reward_card = $rewards/VBoxContainer/rc_
@onready var rc_2: reward_card = $rewards/VBoxContainer/rc_2
@onready var rc_3: reward_card = $rewards/VBoxContainer/rc_3

@onready var skip: Button = $rewards/VBoxContainer/HBoxContainer/skip
@onready var reroll: Button = $rewards/VBoxContainer/HBoxContainer/reroll

var reward_cards: Array[reward_card]
var rewards: Array[Reward]

func _ready() -> void:
	Global.game_is_played = true
	particles(true)
	reward_cards = [rc_, rc_2, rc_3]
	if Global.cur_char.rerolls <= 0:
		reroll.disabled = true
	get_rewards()

func _process(_delta: float) -> void:
	reroll.text = "Reroll X" + str(Global.cur_char.rerolls)

func get_rewards():
	var picked_rewards: Array[Reward]
	
	if Global.boss_beaten == true:
		rewards = Global.cur_char.rewards_passive.duplicate()
		Global.boss_beaten = false
	else:
		rewards = Global.cur_char.rewards_piece.duplicate()
	
	for i in range(3):
		picked_rewards.append(choose_reward())
		if i == 1 and picked_rewards[i] == picked_rewards[i-1]:
			var loops = 0
			while picked_rewards[i] == picked_rewards[i-1] and loops < 50:
				picked_rewards.pop_back()
				picked_rewards.append(choose_reward())
				loops += 1
		if i == 2:
			if picked_rewards[i] == picked_rewards[i-1] or picked_rewards[i] == picked_rewards[i-2]:
				var loops = 0
				while picked_rewards[i] == picked_rewards[i-1] or picked_rewards[i] == picked_rewards[i-2] and loops < 50:
					picked_rewards.pop_back()
					picked_rewards.append(choose_reward())
					loops += 1
		reward_cards[i].reward_resource = picked_rewards[i]
		reward_cards[i].load_btn()

func choose_reward():
	var common_rewards = [] 
	var uncommon_rewards = [] 
	var rare_rewards = [] 
	var legendary_rewards = []
	
	for rew in rewards:
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

func particles(value: bool):
	pratic1.visible = value
	pratic2.visible = value
	pratic3.visible = value
	pratic4.visible = value

func _on_skip_pressed() -> void:
	Global.game_is_played = false
	SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func _on_reroll_pressed() -> void:
	if Global.cur_char.rerolls > 0:
		get_rewards()
		Global.cur_char.rerolls -= 1
	if Global.cur_char.rerolls <= 0:
		reroll.disabled = true
