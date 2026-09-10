extends PanelContainer

@onready var base: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer2/base
@onready var icon: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer2/base/icon
@onready var upgrade_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/upgrade_numb
@onready var cd_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/cd_numb
@onready var p_name: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/name
@onready var p_desc: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/desc
@onready var piece_type: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer3/piece_type

func set_card(piece: PieceClass):
	base.texture = piece.base_texture
	icon.texture = piece.icon_texture
	if piece.can_upgrade == false:
		upgrade_numb.text = "-X-"
	else:
		upgrade_numb.text = str(piece.upgrades)
	cd_numb.text = str(piece.cooldown)
	p_name.text = piece.piece_name
	p_desc.text = piece.description
	
	match piece.type:
		1:
			piece_type.text = "Normal"
		2:
			piece_type.text = "Heavy"
		3:
			piece_type.text = "Glass"
	
	var dyn_desc = piece.get_dynamic_description(Global.cur_char)
	if dyn_desc != "":
		p_desc.text = dyn_desc
	else:
		p_desc.text = piece.description
