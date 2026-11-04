extends Control
class_name ModifierSlotUI

signal modifier_dropped_on_slot(drag_data: Dictionary, target_track: ColorLoadoutTrack, target_mod_index: int)
signal slot_clicked(mod: Equipment)
signal slot_selected(mod: Equipment, track: ColorLoadoutTrack, mod_index: int)

const TEX_CRISTAL_BRIGHT = preload("res://assets/scene-assets/combat/plr-eq-cristal-bright.png")
const TEX_CRISTAL_NORMAL = preload("res://assets/scene-assets/combat/plr-eq-cristal-normal.png")
const TEX_CRISTAL_DARK = preload("res://assets/scene-assets/combat/plr-eq-cristal-dark.png")
const TEX_ULT_ACTIVE = preload("res://assets/scene-assets/combat/plr-eq-ult-active.png")
const TEX_ULT_INACTIVE = preload("res://assets/scene-assets/combat/plr-eq-ult-inactive.png")
const TEX_ULT_NOULT = preload("res://assets/scene-assets/combat/plr-eq-ult-noult.png")
const SHADER_RES = preload("res://assets/shaders/palette_swap_5.gdshader")

@export var is_ultimate_slot: bool = false

var modifier: Equipment = null
var track_ref: ColorLoadoutTrack = null
var mod_index_in_track: int = -1
var drag_enabled: bool = false
var compact_mode: bool = false
var slot_cost: int = 1
var is_empty_slot: bool = true
var is_selected_slot: bool = false
var normal_visual_state: ColorLoadoutTrack.NormalSlotVisualState = ColorLoadoutTrack.NormalSlotVisualState.EMPTY
var ultimate_visual_state: ColorLoadoutTrack.UltimateVisualState = ColorLoadoutTrack.UltimateVisualState.NO_ULTIMATE
var _cached_color: int = 100
var _is_hovered: bool = false

var texture_rect: TextureRect
var shader_mat: ShaderMaterial

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_components()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _ensure_components() -> void:
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect")
		if texture_rect == null:
			texture_rect = TextureRect.new()
			texture_rect.name = "TextureRect"
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			add_child(texture_rect)

	if shader_mat == null:
		shader_mat = ShaderMaterial.new()
		shader_mat.shader = SHADER_RES

	if texture_rect != null and texture_rect.material != shader_mat:
		texture_rect.material = shader_mat

func setup_slot(mod: Equipment, color_id: int, owner_track: ColorLoadoutTrack = null, idx_in_track: int = -1, interactive_drag: bool = false, is_compact: bool = false, is_ult: bool = false) -> void:
	_ensure_components()
	modifier = mod
	track_ref = owner_track
	mod_index_in_track = idx_in_track
	drag_enabled = interactive_drag
	compact_mode = is_compact
	is_ultimate_slot = is_ult or is_ultimate_slot
	_cached_color = color_id
	is_empty_slot = (mod == null)
	mouse_filter = Control.MOUSE_FILTER_STOP if (interactive_drag or mod != null) else Control.MOUSE_FILTER_PASS

	if is_ultimate_slot:
		custom_minimum_size = Vector2(22, 28)

		if owner_track != null:
			ultimate_visual_state = owner_track.get_ultimate_visual_state()
		else:
			ultimate_visual_state = ColorLoadoutTrack.UltimateVisualState.NO_ULTIMATE if is_empty_slot else ColorLoadoutTrack.UltimateVisualState.NORMAL

		if _cached_color == 0 and mod == null and owner_track == null:
			# Unassigned module slot: transparent, shows base plate socket
			if texture_rect != null:
				texture_rect.visible = false
		else:
			if texture_rect != null:
				texture_rect.visible = true
				match ultimate_visual_state:
					ColorLoadoutTrack.UltimateVisualState.NO_ULTIMATE:
						texture_rect.texture = TEX_ULT_NOULT
					ColorLoadoutTrack.UltimateVisualState.NORMAL:
						texture_rect.texture = TEX_ULT_INACTIVE
					ColorLoadoutTrack.UltimateVisualState.ACTIVATED:
						texture_rect.texture = TEX_ULT_ACTIVE
				_apply_palette(_cached_color)
	else:
		custom_minimum_size = Vector2(13, 20)

		if owner_track != null and idx_in_track >= 0:
			normal_visual_state = owner_track.get_normal_slot_visual_state(idx_in_track)
		else:
			normal_visual_state = ColorLoadoutTrack.NormalSlotVisualState.EMPTY if is_empty_slot else ColorLoadoutTrack.NormalSlotVisualState.NORMAL

		if texture_rect != null:
			match normal_visual_state:
				ColorLoadoutTrack.NormalSlotVisualState.EMPTY:
					# Empty slot: transparent, underlying base plate socket shows through
					texture_rect.visible = false
				ColorLoadoutTrack.NormalSlotVisualState.DARK:
					texture_rect.visible = true
					texture_rect.texture = TEX_CRISTAL_DARK
					_apply_palette(_cached_color)
				ColorLoadoutTrack.NormalSlotVisualState.NEXT:
					texture_rect.visible = true
					texture_rect.texture = TEX_CRISTAL_BRIGHT
					_apply_palette(_cached_color)
				ColorLoadoutTrack.NormalSlotVisualState.NORMAL:
					texture_rect.visible = true
					texture_rect.texture = TEX_CRISTAL_NORMAL
					_apply_palette(_cached_color)

	queue_redraw()
	_update_tooltips()

func _apply_palette(color_id: int) -> void:
	if shader_mat == null:
		return
	var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(color_id)
	shader_mat.set_shader_parameter("target_color_1", pal.highlight)
	shader_mat.set_shader_parameter("target_color_2", pal.lightbase)
	shader_mat.set_shader_parameter("target_color_3", pal.base)
	shader_mat.set_shader_parameter("target_color_4", pal.shadebase)
	shader_mat.set_shader_parameter("target_color_5", pal.deepshade)

func _draw() -> void:
	if is_selected_slot:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1.0, 0.95, 0.35, 0.95), false, 1.5)

func _update_tooltips() -> void:
	if is_ultimate_slot:
		if modifier != null:
			var active_str: String = " [ACTIVE - WILL TRIGGER]" if ultimate_visual_state == ColorLoadoutTrack.UltimateVisualState.ACTIVATED else ""
			tooltip_text = "★ Ultimate: %s%s\n%s" % [modifier.piece_name, active_str, _strip_bbcode(modifier.get_effect_description())]
		else:
			tooltip_text = "%s Ultimate Slot (Empty)" % ColorLoadoutTrack.get_color_name(_cached_color)
		return

	if modifier != null:
		var state_str: String = ""
		match normal_visual_state:
			ColorLoadoutTrack.NormalSlotVisualState.DARK:
				state_str = " (Used / Cooldown)"
			ColorLoadoutTrack.NormalSlotVisualState.NEXT:
				state_str = " [NEXT]"
			ColorLoadoutTrack.NormalSlotVisualState.NORMAL:
				state_str = " (Ready)"

		tooltip_text = "%s%s (%dS)\n%s" % [
			modifier.piece_name,
			state_str,
			modifier.slot_cost,
			_strip_bbcode(modifier.get_effect_description())
		]
	else:
		tooltip_text = "%s Skill Slot (Empty)" % ColorLoadoutTrack.get_color_name(_cached_color)

func _strip_bbcode(src: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(src, "", true)

func set_selected(selected: bool) -> void:
	is_selected_slot = selected
	queue_redraw()

func _on_mouse_entered() -> void:
	_is_hovered = true
	if texture_rect != null and texture_rect.visible:
		texture_rect.modulate = Color(1.2, 1.2, 1.2, 1.0)

func _on_mouse_exited() -> void:
	_is_hovered = false
	if texture_rect != null:
		texture_rect.modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if modifier != null:
			slot_clicked.emit(modifier)
			slot_selected.emit(modifier, track_ref, mod_index_in_track)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or modifier == null or track_ref == null:
		return null
	if get_viewport() != null and get_viewport().gui_is_dragging():
		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(96, 30)
		var p_sb := StyleBoxFlat.new()
		var pal: Dictionary = ColorLoadoutTrack.get_palette_for_color(track_ref.color)
		p_sb.bg_color = pal.base.darkened(0.2)
		p_sb.border_width_left = 2
		p_sb.border_width_top = 2
		p_sb.border_width_right = 2
		p_sb.border_width_bottom = 2
		p_sb.border_color = pal.highlight
		p_sb.corner_radius_top_left = 4
		p_sb.corner_radius_top_right = 4
		p_sb.corner_radius_bottom_left = 4
		p_sb.corner_radius_bottom_right = 4
		p_sb.content_margin_left = 6
		p_sb.content_margin_right = 6
		preview.add_theme_stylebox_override("panel", p_sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		preview.add_child(hbox)
		var lbl := Label.new()
		lbl.text = ("★ %s" if is_ultimate_slot else "%s") % modifier.piece_name
		lbl.add_theme_font_size_override("font_size", 10)
		hbox.add_child(lbl)
		set_drag_preview(preview)

	return {
		"type": "modifier_drag",
		"source": "track",
		"modifier": modifier,
		"source_track": track_ref,
		"source_index": mod_index_in_track,
		"is_ultimate": is_ultimate_slot
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drag_enabled or track_ref == null:
		return false
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "modifier_drag":
		return false
	var dragged_mod: Equipment = data.get("modifier", null)
	if dragged_mod == null:
		return false
	if not track_ref.is_color_compatible(dragged_mod):
		return false
	if is_ultimate_slot:
		return dragged_mod.is_ultimate
	return not dragged_mod.is_ultimate

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "modifier_drag":
		modifier_dropped_on_slot.emit(data, track_ref, mod_index_in_track)

func set_preview_active(active: bool, _color_tint: Color) -> void:
	if active and not is_empty_slot:
		scale = Vector2(1.15, 1.15)
	else:
		scale = Vector2.ONE
	queue_redraw()

func pulse_activation() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
