class_name LoadoutDock
extends Control

var bg_decoration: TextureRect
var rows_box: HBoxContainer
var _track_rows: Array[ColorTrackRow] = []
var row_map: Dictionary = {} # base_color (int) -> ColorTrackRow
var _inspect_popup: PanelContainer = null
var _inspect_label: RichTextLabel = null
var _inspect_tween: Tween = null

func _init() -> void:
	custom_minimum_size = Vector2(576, 38)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_structure()
	if Global.cur_char != null:
		if not Global.cur_char.loadoutChanged.is_connected(_on_char_loadout_changed):
			Global.cur_char.loadoutChanged.connect(_on_char_loadout_changed)
	refresh_dock(true)

func _exit_tree() -> void:
	if Global.cur_char != null and Global.cur_char.loadoutChanged.is_connected(_on_char_loadout_changed):
		Global.cur_char.loadoutChanged.disconnect(_on_char_loadout_changed)

func _on_char_loadout_changed() -> void:
	refresh_dock(false)

func _ensure_structure() -> void:
	if bg_decoration == null:
		bg_decoration = get_node_or_null("BgDecoration")
	if rows_box == null:
		rows_box = get_node_or_null("RowsBox")

func get_track_rows() -> Array[ColorTrackRow]:
	if not _track_rows.is_empty():
		return _track_rows
	if rows_box == null:
		_ensure_structure()
	if rows_box != null:
		for child in rows_box.get_children():
			if child is ColorTrackRow:
				_track_rows.append(child)
	return _track_rows

func refresh_dock(force_rebuild: bool = false) -> void:
	_ensure_structure()
	if Global.cur_char == null:
		return
	Global.cur_char.ensure_loadout_tracks()

	var rows := get_track_rows()
	if rows.is_empty():
		return

	var current_pool: Array[int] = Global.cur_char.active_color_pool
	if not force_rebuild and not row_map.is_empty():
		var pool_matches: bool = true
		for slot_idx in range(rows.size()):
			var row: ColorTrackRow = rows[slot_idx]
			var expected_color: int = current_pool[slot_idx] if slot_idx < current_pool.size() else 0
			if row.track_color != expected_color:
				pool_matches = false
				break
		if pool_matches:
			for row in rows:
				row.update_row_state()
			return

	row_map.clear()

	for slot_idx in range(rows.size()):
		var row: ColorTrackRow = rows[slot_idx]
		if slot_idx < current_pool.size():
			var c_id: int = current_pool[slot_idx]
			var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
			row.setup_row(c_id, track, false, false)
			row_map[ColorLoadoutTrack.get_base_family(c_id)] = row
		else:
			# Unassigned module slot on tray: base metal plate with empty sockets
			row.setup_row(0, null, false, false)

		if not row.row_slot_selected.is_connected(_on_combat_slot_tapped):
			row.row_slot_selected.connect(_on_combat_slot_tapped)

func _on_combat_slot_tapped(mod: Equipment, track: ColorLoadoutTrack, mod_index: int) -> void:
	if mod == null:
		return
	_show_inspect_popup(mod, track, mod_index)

func _show_inspect_popup(mod: Equipment, track: ColorLoadoutTrack, mod_index: int) -> void:
	if _inspect_popup == null or not is_instance_valid(_inspect_popup):
		_inspect_popup = PanelContainer.new()
		_inspect_popup.top_level = true
		_inspect_popup.z_index = 2000
		_inspect_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(0.09, 0.07, 0.12, 0.96)
		p_sb.border_width_left = 2
		p_sb.border_width_top = 2
		p_sb.border_width_right = 2
		p_sb.border_width_bottom = 2
		p_sb.border_color = Color(0.88, 0.78, 0.42, 0.95)
		p_sb.corner_radius_top_left = 5
		p_sb.corner_radius_top_right = 5
		p_sb.corner_radius_bottom_left = 5
		p_sb.corner_radius_bottom_right = 5
		p_sb.content_margin_left = 10
		p_sb.content_margin_right = 10
		p_sb.content_margin_top = 6
		p_sb.content_margin_bottom = 6
		_inspect_popup.add_theme_stylebox_override("panel", p_sb)

		_inspect_label = RichTextLabel.new()
		_inspect_label.bbcode_enabled = true
		_inspect_label.fit_content = true
		_inspect_label.scroll_active = false
		_inspect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inspect_label.custom_minimum_size = Vector2(490, 0)
		_inspect_label.add_theme_font_size_override("normal_font_size", 13)
		_inspect_label.add_theme_font_size_override("bold_font_size", 14)
		_inspect_popup.add_child(_inspect_label)
		add_child(_inspect_popup)

	var is_next: bool = (track != null and mod_index == track.next_entry_cursor)
	var next_tag: String = " [color=#59fae0][b]► NEXT[/b][/color]" if is_next else ""
	var r_hex: String = Equipment.get_rarity_hex(mod.rarity)
	var r_name: String = Equipment.get_rarity_name(mod.rarity)
	var trig_badge: String = mod.get_trigger_badge_text()
	var trig_str: String = (" • Trigger: [color=#fad65a]%s[/color]" % trig_badge) if trig_badge != "" else ""
	var c_name: String = ColorLoadoutTrack.get_color_name(track.color) if track != null else "Track"
	var state_str: String = ""
	if mod.once_per_battle and mod.used_this_battle:
		state_str = " • [color=#f26b6b]USED[/color]"
	elif mod.current_cooldown > 0:
		state_str = " • [color=#f29d4c]CD: %dT[/color]" % mod.current_cooldown

	var char_res: Resource = Global.cur_char
	_inspect_label.text = "[color=%s][b]%s[/b][/color] [color=#b2b8a3](%s • %d-Slot • %s%s%s)[/color]%s\n%s" % [
		r_hex,
		mod.piece_name,
		r_name,
		mod.slot_cost,
		c_name,
		trig_str,
		state_str,
		next_tag,
		mod.get_effect_description(char_res)
	]

	_inspect_popup.visible = true
	_inspect_popup.modulate = Color.WHITE
	_inspect_popup.global_position = Vector2(global_position.x + 8.0, global_position.y - 58.0)

	if _inspect_tween != null and _inspect_tween.is_valid():
		_inspect_tween.kill()
	_inspect_tween = create_tween()
	_inspect_tween.tween_interval(2.4)
	_inspect_tween.tween_property(_inspect_popup, "modulate:a", 0.0, 0.35)
	_inspect_tween.tween_callback(func():
		if is_instance_valid(_inspect_popup):
			_inspect_popup.visible = false
	)

func preview_matches(sim_contexts: Array[MatchContext]) -> void:
	clear_preview()
	for ctx in sim_contexts:
		if ctx != null and row_map.has(ctx.base_color):
			var row: ColorTrackRow = row_map[ctx.base_color]
			row.preview_context(ctx)

func clear_preview() -> void:
	for k in row_map.keys():
		var row: ColorTrackRow = row_map[k]
		if row != null:
			row.clear_preview()

func pulse_slot(base_color: int, mod: Equipment) -> void:
	refresh_dock(false)
	if row_map.has(base_color):
		var row: ColorTrackRow = row_map[base_color]
		if row != null:
			row.pulse_modifier(mod)
