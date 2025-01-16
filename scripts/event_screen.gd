extends Control

const CHOISE_BTN = preload("res://event/_other/choise_btn_n.tscn")

var resource: Event

@onready var pause: Control = $pause

@onready var event_bg: TextureRect = $event_bg
@onready var event_text: VBoxContainer = $MarginContainer/VBoxContainer/event_text
@onready var choises_holder: VBoxContainer = $MarginContainer/VBoxContainer/choises_holder

@onready var reward: Control = $reward

func _ready() -> void:
	var cur_char = Global.cur_char
	var title_label = event_text.get_child(0).get_child(0).get_child(0)
	var description_label = event_text.get_child(1).get_child(0).get_child(0)
	
	resource = Global.area_cur_event
	pause.set_title(resource.categorie)
	
	title_label.text = resource.title
	description_label.text = resource.description
	
	if resource.background != null:
		event_bg.texture = resource.background
		
	for choise in resource.choises:
		if (choise.req_class != "None" and choise.req_class != cur_char.player_class) or (choise.req_piece_name != "None" and not has_enough_pieces(choise.req_piece_name, choise.req_piece_numb)):
			continue
		if choise.req_stat != "None" and choise.req_value != 0:
			var stat = cur_char.get(choise.req_stat)
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
	
	Global.area_cur_event = null
	Global.game_is_played = true

func has_enough_pieces(piece_name: String, req: int) -> bool:
	var numb = 0
	if req <= 0:
		return true
	for piece in Global.cur_char.deck_in_game:
		if piece.color == piece_name:
			numb += 1
		if piece.piece_name == piece_name:
			numb += 1
	if numb >= req:
		return true
	return false


func get_reward(texture: Texture2D, text: String,icon: Texture2D, description: String = "", ):
	var reward_texture = reward.get_child(2).get_child(0).get_child(0).get_child(0)
	var reward_icon = reward_texture.get_child(0)
	var reward_text = reward.get_child(2).get_child(0).get_child(0).get_child(1)
	var reward_description = reward.get_child(2).get_child(0).get_child(0).get_child(2)
	var reward_animator = reward.get_child(0)
	
	reward_texture.texture = texture
	reward_icon.texture = icon
	reward_text.text = text
	
	if description != "":
		reward_description.text = description
		reward_description.visible = true
	
	reward_animator.current_animation = "drop_down"
	reward.visible = true
