extends Control

const CHOISE_BTN: PackedScene = preload("res://events/choices/choice_btn_n.tscn")

var resource: Event

@onready var pause: Control = $pause
@onready var event_bg: TextureRect = $event_bg
@onready var event_text: VBoxContainer = $MarginContainer/VBoxContainer/event_text
@onready var choises_holder: VBoxContainer = $MarginContainer/VBoxContainer/choises_holder
@onready var reward: Control = $reward


func _ready() -> void:
	if Global.area_cur_event != null:
		display_event(Global.area_cur_event, false)
		Global.area_cur_event = null
	Global.game_is_played = true


func display_event(event_res: Event, animate_transition: bool = false) -> void:
	if event_res == null:
		return
	resource = event_res

	if animate_transition:
		var tween: Tween = create_tween()
		tween.tween_property($MarginContainer, "modulate:a", 0.0, 0.15)
		await tween.finished
		_populate_event_data()
		var tween_in: Tween = create_tween()
		tween_in.tween_property($MarginContainer, "modulate:a", 1.0, 0.15)
	else:
		_populate_event_data()


func get_reward(texture: Texture2D, text: String, icon: Texture2D, description: String = "") -> void:
	var reward_texture: TextureRect = $reward/PanelContainer/MarginContainer/VBoxContainer/TextureRect
	var reward_icon: TextureRect = reward_texture.get_child(0) as TextureRect
	var reward_text: Label = $reward/PanelContainer/MarginContainer/VBoxContainer/Label
	var reward_description: Label = $reward/PanelContainer/MarginContainer/VBoxContainer/Label2
	var reward_animator: AnimationPlayer = $reward/AnimationPlayer

	reward_texture.texture = texture
	reward_icon.texture = icon
	reward_text.text = text
	if description:
		reward_description.text = description
		reward_description.visible = true
	else:
		reward_description.visible = false

	reward.visible = true
	reward_animator.current_animation = "drop_down"


func has_enough_pieces(piece_name: String, req: int) -> bool:
	if req <= 0:
		return true
	if Global.cur_char == null:
		return false
	var count: int = 0
	var target_lower: String = piece_name.to_lower()
	for mod in Global.cur_char.get_all_owned_modifiers():
		if mod == null:
			continue
		var matches_name: bool = mod.piece_name.to_lower() == target_lower
		var matches_color: bool = false
		for c in mod.get_effective_allowed_colors():
			if Global.get_color_name(c).to_lower() == target_lower:
				matches_color = true
				break
		if matches_name or matches_color:
			count += 1
			if count >= req:
				return true
	return false


func _populate_event_data() -> void:
	if resource == null:
		return

	var cur_char: PlayerResource = Global.cur_char
	var title_label: Label = event_text.get_child(0).get_child(0).get_child(0) as Label
	var description_label: RichTextLabel = event_text.get_child(1).get_child(0).get_child(0) as RichTextLabel

	pause.set_title(resource.categorie if resource.categorie else "Event")
	title_label.text = resource.title
	description_label.text = resource.description

	if resource.background != null:
		event_bg.texture = resource.background

	for child in choises_holder.get_children():
		child.queue_free()

	for choise in resource.choises:
		if choise == null:
			continue
		if cur_char != null:
			if (choise.req_class != "None" and choise.req_class != cur_char.player_class) or (choise.req_piece_name != "None" and not has_enough_pieces(choise.req_piece_name, choise.req_piece_numb)):
				continue
			if choise.req_stat != "None" and choise.req_value != 0:
				var stat: Variant = cur_char.get(choise.req_stat)
				if choise.failable and choise.fail_state:
					var btn: PanelContainer = CHOISE_BTN.instantiate() as PanelContainer
					btn.resource = choise
					choises_holder.add_child(btn)
					if btn.has_signal("reward_requested"):
						btn.reward_requested.connect(get_reward)
					if btn.has_signal("next_event_requested"):
						btn.next_event_requested.connect(display_event.bind(true))
					btn.set_btn()
					continue
				if stat != null and stat < choise.req_value:
					continue
		var btn1: PanelContainer = CHOISE_BTN.instantiate() as PanelContainer
		btn1.resource = choise
		choises_holder.add_child(btn1)
		if btn1.has_signal("reward_requested"):
			btn1.reward_requested.connect(get_reward)
		if btn1.has_signal("next_event_requested"):
			btn1.next_event_requested.connect(display_event.bind(true))
		btn1.set_btn()

