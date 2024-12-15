extends Control

const CHOISE_BTN = preload("res://event/_other/choise_btn_n.tscn")

var resource: Event

@onready var pause: Control = $pause

@onready var event_bg: TextureRect = $event_bg
@onready var event_text: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer/event_text
@onready var choises_holder: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer/choises_holder

@onready var reward: Control = $reward

func _ready() -> void:
	Global.game_is_played = true
	resource = Global.cur_event
	pause.set_title(resource.categorie)
	event_text.get_child(0).text = resource.title
	event_text.get_child(1).text = resource.description
	if resource.background != null:
		event_bg.texture = resource.background
	for choise in resource.choises:
		if choise.req_class != "None" and choise.req_class != Global.cur_char.player_class:
			continue
		if choise.req_piece != "None":
			var match_found: bool
			for piece in Global.cur_char.deck_in_game:
				if piece.piece_name == choise.req_piece:
					match_found = true
			if not match_found:
				continue
		if choise.req_stat != "None" and choise.req_value != 0:
			var stat = Global.cur_char.get(choise.req_stat)
			if choise.failable and choise.fail_state:
				var btn = CHOISE_BTN.instantiate()
				btn.resource = choise
				choises_holder.add_child(btn)
				btn.set_btn()
				continue
			if stat < choise.req_value:
				continue
		var btn1 = CHOISE_BTN.instantiate()
		btn1.resource = choise
		choises_holder.add_child(btn1)
		btn1.set_btn()
	Global.cur_event = null

func get_reward(texture: Texture2D, text: String,icon: Texture2D, description: String = "", ):
	reward.get_child(2).get_child(0).get_child(0).get_child(0).texture = texture
	reward.get_child(2).get_child(0).get_child(0).get_child(0).get_child(0).texture = icon
	reward.get_child(2).get_child(0).get_child(0).get_child(1).text = text
	if description != "":
		reward.get_child(2).get_child(0).get_child(0).get_child(2).visible = true
		reward.get_child(2).get_child(0).get_child(0).get_child(2).text = description
	reward.get_child(0).current_animation = "drop_down"
	reward.visible = true
	pass
