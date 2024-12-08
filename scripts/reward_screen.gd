extends Node2D

@onready var pratic1: GPUParticles2D = $GPUParticles2D
@onready var pratic2: GPUParticles2D = $GPUParticles2D2
@onready var pratic3: GPUParticles2D = $GPUParticles2D3
@onready var pratic4: GPUParticles2D = $GPUParticles2D4

@onready var reward_card_0: reward_card = $Control/MarginContainer/VBoxContainer/reward_card_0
@onready var reward_card_1: reward_card = $Control/MarginContainer/VBoxContainer/reward_card_1
@onready var reward_card_2: reward_card = $Control/MarginContainer/VBoxContainer/reward_card_2
@onready var reroll: Button = $Control/MarginContainer/VBoxContainer/HBoxContainer/reroll

var reward_cards: Array[reward_card]

func _ready() -> void:
	particles(true)
	reward_cards = [reward_card_0, reward_card_1, reward_card_2]
	if Global.cur_char.rerolls <= 0:
		reroll.disabled = true
	get_rewards()

func _process(_delta: float) -> void:
	reroll.text = "Reroll X" + str(Global.cur_char.rerolls)

func get_rewards():
	var rewards: Array[Reward]
	var picked_rewards: Array[Reward]
	if Global.boss_beaten == true:
		rewards = Global.cur_char.rewards_passive.duplicate()
		Global.boss_beaten = false
	else:
		rewards = Global.cur_char.rewards_piece.duplicate()
	for i in range(3):
		rewards.shuffle()
		picked_rewards.append(rewards[-1])
		if i == 1 and picked_rewards[i] == picked_rewards[i-1]:
			var loops = 0
			while picked_rewards[i] == picked_rewards[i-1] and loops < 50:
				picked_rewards.pop_back()
				rewards.shuffle()
				picked_rewards.append(rewards[-1])
				loops += 1
		if i == 2:
			if picked_rewards[i] == picked_rewards[i-1] or picked_rewards[i] == picked_rewards[i-2]:
				var loops = 0
				while picked_rewards[i] == picked_rewards[i-1] or picked_rewards[i] == picked_rewards[i-2] and loops < 50:
					picked_rewards.pop_back()
					rewards.shuffle()
					picked_rewards.append(rewards[-1])
					loops += 1
		reward_cards[i].reward_res = picked_rewards[i]
		rewards.pop_back()
		reward_cards[i].load_btn()

func _on_skip_pressed() -> void:
	if Global.boss_beaten == true:
		SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	else:
		SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func particles(value: bool):
	pratic1.visible = value
	pratic2.visible = value
	pratic3.visible = value
	pratic4.visible = value

func _on_reroll_pressed() -> void:
	if Global.cur_char.rerolls > 0:
		get_rewards()
		Global.cur_char.rerolls -= 1
	if Global.cur_char.rerolls <= 0:
		reroll.disabled = true
