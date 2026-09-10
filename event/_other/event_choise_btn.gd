extends PanelContainer

const CHOISE_BTN_D = preload("res://event/_other/choise_btn_d.tres")
const CHOISE_BTN_N = preload("res://event/_other/choise_btn_n.tres")

@onready var btn: Button = $btn
@onready var sound: AudioStreamPlayer = $sound

@onready var description: RichTextLabel = $MarginContainer/VBoxContainer/description
@onready var title: Label = $MarginContainer/VBoxContainer/title

var resource: EventChoise

func set_btn():
	if resource != null:
		title.text = resource.text
		if resource.description == "None":
			description.visible = false
		else:
			description.visible = true
			description.text = resource.description
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

signal reward_requested(texture: Texture2D, text: String, icon: Texture2D, description: String)
signal next_event_requested(next_event: Event)

func _on_btn_pressed() -> void:
	if Global.game_is_played == true:
		if resource.gold_cost > 0:
			Global.cur_char.gold -= resource.gold_cost
		if resource.req_piece_remove:
			var i = 0
			var numb = 0
			while i < Global.cur_char.deck_in_game.size():
				if (Global.cur_char.deck_in_game[i].piece_name == resource.req_piece_name or Global.cur_char.deck_in_game[i].color == resource.req_piece_name) and Global.cur_char.deck_in_game[i].piece_name != resource.req_piece_remove_blacklist:
					Global.cur_char.deck_in_game.remove_at(i)
					numb += 1
					if resource.req_piece_numb != 0 and numb == resource.req_piece_numb:
						break
				else:
					i += 1
			Global.event_pieces_removed = numb
		if resource.failable and resource.req_stat != "None" and resource.fail_state and resource.req_value > 0:
			var stat_to_check = Global.cur_char.get(resource.req_stat)
			if stat_to_check < resource.req_value:
				var new_resource: EventChoise = resource.fail_state
				resource = new_resource
		match resource.type:
			1:
				pass
			2:
				pass
			3:
				_show_reward(resource.reward.base, resource.reward.name, resource.reward.icon, resource.reward.description)
				await get_tree().create_timer(1.5).timeout
				if resource is EvtChoiseReward and resource.next_event != null:
					resource.handled_in_place = true
					next_event_requested.emit(resource.next_event)
					var screen = find_parent("event_screen")
					if screen and screen.has_method("display_event"):
						screen.display_event(resource.next_event, true)
						return
			4:
				if resource is EvtChoiseEvent and resource.next_event != null:
					resource.handled_in_place = true
					next_event_requested.emit(resource.next_event)
					var screen = find_parent("event_screen")
					if screen and screen.has_method("display_event"):
						screen.display_event(resource.next_event, true)
						return
		resource.activate()

func _show_reward(texture: Texture2D, text: String, icon: Texture2D, desc: String) -> void:
	reward_requested.emit(texture, text, icon, desc)
	var screen = find_parent("event_screen")
	if screen and screen.has_method("get_reward"):
		screen.get_reward(texture, text, icon, desc)
