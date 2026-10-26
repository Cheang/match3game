extends PanelContainer
class_name LoadoutDock

var rows_box: HBoxContainer
var row_map: Dictionary = {} # base_color (int) -> ColorTrackRow

func _init() -> void:
	_build_dock()

func _ready() -> void:
	if rows_box == null:
		_build_dock()
	if Global.cur_char != null:
		if not Global.cur_char.loadoutChanged.is_connected(refresh_dock):
			Global.cur_char.loadoutChanged.connect(refresh_dock)
	refresh_dock()

func _exit_tree() -> void:
	if Global.cur_char != null and Global.cur_char.loadoutChanged.is_connected(refresh_dock):
		Global.cur_char.loadoutChanged.disconnect(refresh_dock)

func _build_dock() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.13, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.34, 0.29, 0.38, 0.95)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	rows_box = HBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 6)
	add_child(rows_box)

func refresh_dock() -> void:
	if rows_box == null:
		_build_dock()
	for child in rows_box.get_children():
		child.queue_free()
	row_map.clear()

	if Global.cur_char == null:
		return
	Global.cur_char.ensure_loadout_tracks()
	for c_id in Global.cur_char.active_color_pool:
		var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(c_id)
		var row := ColorTrackRow.new()
		rows_box.add_child(row)
		row.setup_row(c_id, track, false, true)
		row_map[Global.get_base_family(c_id)] = row

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
	if row_map.has(base_color):
		var row: ColorTrackRow = row_map[base_color]
		if row != null:
			row.pulse_modifier(mod)
	refresh_dock()
