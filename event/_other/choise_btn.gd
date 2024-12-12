extends PanelContainer

const BUTTON = preload("res://assets/level_ui/button.png")

const CHOISE_BTN_D = preload("res://event/_other/choise_btn_d.tres")
const CHOISE_BTN_N = preload("res://event/_other/choise_btn_n.tres")

@onready var btn: Button = $btn

@onready var description: RichTextLabel = $MarginContainer/VBoxContainer/description
@onready var title: Label = $MarginContainer/VBoxContainer/title

var resource: EventChoise

func set_btn():
	if resource != null:
		if resource.description == "None":
			description.visible = false
		else:
			description.visible = true
			description.text = resource.description
		title.text = resource.text
		if resource.gold_cost > 0:
			if resource.gold_cost > Global.cur_char.gold:
				btn.disabled = true
				self.add_theme_stylebox_override("panel", CHOISE_BTN_D)
				title.add_theme_color_override("font_color", Color8(127, 112, 138))
				description.add_theme_color_override("default_color", Color8(127, 112, 138))
			else: 
				btn.disabled = false
				self.add_theme_stylebox_override("panel", CHOISE_BTN_N)
				title.add_theme_color_override("font_color", Color8(55, 78, 74))
				description.add_theme_color_override("default_color", Color8(84, 126, 100))

func _on_btn_pressed() -> void:
	if Global.game_is_played == true:
		if resource.gold_cost > 0:
			Global.cur_char.gold -= resource.gold_cost
		if resource.req_piece_remove:
			for piece in Global.cur_char.deck_in_game:
				if piece.piece_name == resource.req_piece:
					var index = Global.cur_char.deck_in_game.find(piece)
					Global.cur_char.deck_in_game.pop_at(index)
					break
		if resource.failable and resource.req_stat != "None" and resource.fail_state and resource.req_value > 0:
			var stat_to_check = Global.cur_char.get(resource.req_stat)
			if stat_to_check < resource.req_value:
				var new_resource: EventChoise = resource.fail_state
				resource = new_resource
		match resource.type:
			0: #go to locations
				Global.game_is_played = false
				SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
			1: #continue event
				Global.game_is_played = false
				Global.cur_event = resource.next_event_res
				SceneManager.change_scene("res://event_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true, "skip_fade_in": true })
			2: #fight
				Global.game_is_played = false
				EnemyData.set_minion(resource.enemy)
				EnemyData.set_enemie_stats()
				SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
			3: #get after fight reward
				Global.game_is_played = false
				SceneManager.change_scene("res://reward_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
			4: #get piece
				Global.game_is_played = false
				get_parent().get_parent().get_parent().get_parent().get_parent().get_reward(resource.piece_res.base, resource.piece_res.name, resource.piece_res.icon, resource.piece_res.description)
				await get_tree().create_timer(1.5).timeout
				resource.piece_res.activate()
				resource.piece_res.boost()
				if resource.fight_overwrite:
					EnemyData.set_minion(resource.enemy)
					EnemyData.set_enemie_stats()
					SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
					return
				SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
			5: #get passive
				Global.game_is_played = false
				if resource.fight_overwrite:
					EnemyData.set_minion(resource.enemy)
					EnemyData.set_enemie_stats()
					SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
					return
			6: #get stat
				Global.game_is_played = false
				get_parent().get_parent().get_parent().get_parent().get_parent().get_reward(resource.stat_res.base, resource.stat_res.name, resource.stat_res.icon, resource.stat_res.description)
				await get_tree().create_timer(1.5).timeout
				resource.stat_res.activate()
				if resource.fight_overwrite:
					EnemyData.set_minion(resource.enemy)
					EnemyData.set_enemie_stats()
					SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
					return
				SceneManager.change_scene("res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
