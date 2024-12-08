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
	match resource.type:
		0: #go to locations
			SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
		1: #continue event
			Global.cur_event = resource.next_event_res
			SceneManager.change_scene("res://event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true, "skip_fade_in": true })
		2: #fight
			EnemyData.enemy = resource.enemy
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
			resource.stat_res.activate()
			resource.stat_res.boost()
			SceneManager.change_scene("res://next_encounter_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
