extends PanelContainer
class_name LoadoutDock

var rows_box: GridContainer
var row_map: Dictionary = {} # base_color (int) -> ColorTrackRow
var _active_pool_signature: Array[int] = []
var _inspect_popup: PanelContainer = null
var _inspect_label: RichTextLabel = null
var _inspect_tween: Tween = null

func _init() -> void:
	_build_dock()

func _ready() -> void:
	if rows_box == null:
		_build_dock()
	if Global.cur_char != null:
		if not Global.cur_char.loadoutChanged.is_connected(_on_char_loadout_changed):
			Global.cur_char.loadoutChanged.connect(_on_char_loadout_changed)
	refresh_dock(true)

func _exit_tree() -> void:
	if Global.cur_char != null and Global.cur_char.loadoutChanged.is_connected(_on_char_loadout_changed):
		Global.cur_char.loadoutChanged.disconnect(_on_char_loadout_changed)

func _on_char_loadout_changed() -> void:
	refresh_dock(true)

func _build_dock() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.13, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.38, 0.32, 0.44, 0.95)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	add_theme_stylebox_override("panel", sb)

	rows_box = GridContainer.new()
	rows_box.columns = 2
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("h_separation", 8)
	rows_box.add_theme_constant_override("v_separation", 3)
	add_child(rows_box)

func refresh_dock(force_rebuild: bool = false) -> void:
	if rows_box == null:
		_build_dock()
	if Global.cur_char == null:
		return
	Global.cur_char.ensure_loadout_tracks()

	var current_pool: Array[int] = Global.cur_char.active_color_pool
	rows_box.columns = 2 if current_pool.size() >= 3 else max(1, current_pool.size())

	if not force_rebuild and _active_pool_signature == current_pool and row_map.size() == current_pool.size():
		var all_valid: bool = true
		for c_id in current_pool:
			var base_c: int = Global.get_base_family(c_id)
			if not row_map.has(base_c) or not is_instance_valid(row_map[base_c]):
				all_valid = false
				break
		if all_valid:
			for c_id in current_pool:
				var base_c: int = Global.get_base_family(c_id)
				var existing_row: ColorTrackRow = row_map[base_c]
				existing_row.update_row_state()
			return

	for child in rows_box.get_children():
		child.queue_free()
	row_map.clear()
	_active_pool_signature = current_pool.duplicate()

	for c_id in current_pool:
		var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
		var row := ColorTrackRow.new()
		rows_box.add_child(row)
		row.setup_row(c_id, track, false, true)
		row.row_slot_selected.connect(_on_combat_slot_tapped)
		row_map[Global.get_base_family(c_id)] = row

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
	var c_name: String = Global.get_color_name(track.color) if track != null else "Track"
	var state_str: String = ""
	if mod.once_per_battle and mod.used_this_battle:
		state_str = " • [color=#f26b6b]USED[/color]"
	elif mod.current_cooldown > 0:
		state_str = " • [color=#f29d4c]CD: %dT[/color]" % mod.current_cooldown

	_inspect_label.text = "[color=%s][b]%s[/b][/color] [color=#b2b8a3](%s • %d-Slot • %s%s%s)[/color]%s\n%s" % [
		r_hex,
		mod.piece_name,
		r_name,
		mod.slot_cost,
		c_name,
		trig_str,
		state_str,
		next_tag,
		mod.get_effect_description(Global.cur_char)
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
