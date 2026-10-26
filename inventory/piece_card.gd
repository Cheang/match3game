extends PanelContainer

@onready var base: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer2/base
@onready var icon: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer2/base/icon
@onready var upgrade_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/upgrade_numb
@onready var slot_cost_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer2/Label
@onready var slot_cost_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer2/upgrade_numb
@onready var cd_numb: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/cd_numb
@onready var p_name: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/name
@onready var p_desc: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/desc
@onready var piece_type: Label = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer3/piece_type

func set_card_modifier(mod: Equipment) -> void:
	if mod == null:
		return
	var eff_colors: Array[int] = mod.get_effective_allowed_colors()
	var primary_c: int = eff_colors[0] if not eff_colors.is_empty() else 0
	base.texture = Global.get_color_base_texture(primary_c)
	icon.texture = mod.icon
	if not mod.can_upgrade:
		upgrade_numb.text = "-X-"
	else:
		upgrade_numb.text = str(mod.upgrade)

	if slot_cost_label != null:
		slot_cost_label.text = "Slot Cost:"
	if slot_cost_numb != null:
		slot_cost_numb.text = str(mod.slot_cost)

	cd_numb.text = str(mod.cooldown_turns)
	p_name.text = mod.piece_name

	var badge: String = mod.get_trigger_badge_text()
	if mod.once_per_battle:
		piece_type.text = "1/Battle" + ((" [" + badge + "]") if badge != "" else "")
	elif badge != "":
		piece_type.text = badge
	else:
		piece_type.text = "Always"

	var dyn_desc: String = mod.get_effect_description(Global.cur_char)
	p_desc.text = dyn_desc if dyn_desc != "" else mod.description

func set_card(piece):
	if piece is Equipment:
		set_card_modifier(piece)
		return
	if piece is PieceClass:
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
			1: piece_type.text = "Normal"
			2: piece_type.text = "Heavy"
			3: piece_type.text = "Glass"
		var dyn_desc = piece.get_dynamic_description(Global.cur_char)
		if dyn_desc != "":
			p_desc.text = dyn_desc
		else:
			p_desc.text = piece.description
