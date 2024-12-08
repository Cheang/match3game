extends Control

const CHOISE_BTN = preload("res://event/_other/choise_btn.tscn")

var resource: Event

@onready var event_bg: TextureRect = $event_bg
@onready var event_text: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer/event_text
@onready var choises_holder: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer/choises_holder

func _ready() -> void:
	resource = Global.cur_event
	event_text.get_child(0).text = resource.title
	event_text.get_child(1).text = resource.description
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
			if stat < choise.req_value:
				continue
		var btn = CHOISE_BTN.instantiate()
		btn.resource = choise
		choises_holder.add_child(btn)
		btn.set_btn()
	Global.cur_event = null
