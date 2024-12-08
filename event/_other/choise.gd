extends Button

@onready var choise_btn: Button = $"."
var resource: EventChoise

func set_btn():
	if resource != null:
		choise_btn.text = resource.text
		if resource.gold_cost > 0:
			if resource.gold_cost > Global.cur_char.gold:
				choise_btn.disabled = true

func _on_pressed() -> void:
	if resource.gold_cost > 0:
		Global.cur_char.gold -= resource.gold_cost
	if resource.req_piece_remove:
		for piece in Global.cur_char.deck_in_game:
			if piece.piece_name == resource.req_piece:
				var index = Global.cur_char.deck_in_game.find(piece)
				Global.cur_char.deck_in_game.pop_at(index)
				break
	match resource.type:
		0: #go to locations
			SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		1: #continue event
			Global.cur_event = resource.next_event_res
			SceneManager.change_scene("res://event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true, "skip_fade_in": true })
		2: #fight
			EnemyData.set_minion(resource.enemy)
			EnemyData.set_enemie_stats()
			Global.game_is_played = true
			SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		3: #get after fight reward
			SceneManager.change_scene("res://reward_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		4: #get piece
			resource.piece_res.activate()
			resource.piece_res.boost()
			SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		5: #get passive
			pass
		6: #get stat
			get_parent().get_parent().get_parent().get_parent().get_parent().get_reward(resource.stat_res.base, resource.stat_res.name, resource.stat_res.icon, resource.stat_res.description)
			await get_tree().create_timer(1.5).timeout
			resource.stat_res.activate()
			SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
