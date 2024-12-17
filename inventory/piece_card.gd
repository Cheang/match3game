extends PanelContainer

@onready var base: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/base
@onready var icon: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/base/icon
@onready var upgrade_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/upgrade_numb
@onready var stat_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/stat_numb
@onready var cd_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer3/cd_numb
@onready var p_name: Label = $MarginContainer/VBoxContainer/name
@onready var p_desc: Label = $MarginContainer/VBoxContainer/desc

func set_card(piece: PieceClass):
	base.texture = piece.base_texture
	icon.texture = piece.icon_texture
	upgrade_numb.text = str(piece.upgrades)

	cd_numb.text = str(piece.cooldown)
	p_name.text = piece.piece_name
	p_desc.text = "none"
