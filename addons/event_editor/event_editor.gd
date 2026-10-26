@tool
extends Control

# --- Data Structures ---
var current_file_path: String = ""
var pages: Array[Dictionary] = []
var selected_page_index: int = -1
var is_dirty: bool = false

var active_picking_choice: Dictionary = {}
var active_picking_field: String = ""
var active_picking_edit: LineEdit = null

# --- UI Node References ---
@onready var file_label: Label = $VBox/Header/HBox/FileLabel
@onready var status_label: Label = $VBox/Footer/StatusLabel
@onready var graph_edit: GraphEdit = $VBox/Main/Left/VBox/Graph
@onready var page_header_lbl: Label = $VBox/Main/Right/Scroll/Inspector/PageBox/VBox/HeaderLbl
@onready var page_title_edit: LineEdit = $VBox/Main/Right/Scroll/Inspector/PageBox/VBox/Grid/TitleEdit
@onready var page_cat_edit: LineEdit = $VBox/Main/Right/Scroll/Inspector/PageBox/VBox/Grid/CatEdit
@onready var page_bg_edit: LineEdit = $VBox/Main/Right/Scroll/Inspector/PageBox/VBox/Grid/BgBox/BgEdit
@onready var page_bg_preview: TextureRect = $VBox/Main/Right/Scroll/Inspector/PageBox/VBox/Grid/BgBox/BgPreview
@onready var page_desc_edit: TextEdit = $VBox/Main/Right/Scroll/Inspector/PageBox/VBox/DescEdit
@onready var choices_container: VBoxContainer = $VBox/Main/Right/Scroll/Inspector/ChoicesBox/VBox/ChoicesContainer
@onready var file_dialog: FileDialog = $FileDialog
@onready var preview_modal: PanelContainer = $PreviewModal
@onready var preview_title: Label = $PreviewModal/Margin/VBox/TitleLabel
@onready var preview_cat: Label = $PreviewModal/Margin/VBox/TopRow/CatLabel
@onready var preview_bg: TextureRect = $PreviewModal/Margin/VBox/BgTexture
@onready var preview_desc: RichTextLabel = $PreviewModal/Margin/VBox/DescLabel
@onready var preview_choices: VBoxContainer = $PreviewModal/Margin/VBox/ChoicesHolder
@onready var preview_status: Label = $PreviewModal/Margin/VBox/OutcomeStatus

var file_dialog_mode: String = "open" # "open", "save_as", "pick_bg", "pick_enemy", "pick_piece", "pick_scene"

func _ready() -> void:
	_apply_editor_theme()
	if not file_dialog:
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	if preview_modal:
		preview_modal.visible = false
	
	if pages.is_empty():
		new_event()

func _apply_editor_theme() -> void:
	if Engine.is_editor_hint():
		if is_instance_valid(EditorInterface.get_editor_theme()):
			theme = EditorInterface.get_editor_theme()
			return
	var t = Theme.new()
	t.set_font_size("font_size", "Button", 12)
	t.set_font_size("font_size", "Label", 12)
	t.set_font_size("font_size", "LineEdit", 12)
	t.set_font_size("font_size", "TextEdit", 12)
	t.set_font_size("font_size", "OptionButton", 12)
	t.set_font_size("font_size", "SpinBox", 12)
	t.set_font_size("font_size", "CheckButton", 12)
	t.set_font_size("font_size", "RichTextLabel", 12)
	theme = t

# ==============================================================================
# EVENT & PAGE DATA MANAGEMENT
# ==============================================================================

func new_event() -> void:
	pages.clear()
	current_file_path = ""
	var root_page = create_default_page("Page 1 (Start)", "Event", "You stand before a branching path...")
	root_page["graph_pos"] = Vector2(80, 120)
	pages.append(root_page)
	selected_page_index = 0
	is_dirty = false
	update_file_label()
	rebuild_graph_ui()
	load_selected_page_into_inspector()
	set_status("Created new blank event.")

func create_default_page(title: String, category: String = "Event", desc: String = "", incoming_choice: String = "") -> Dictionary:
	return {
		"id": "page_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
		"title": title,
		"category": category,
		"description": desc,
		"background": "res://assets/level_ui/event/event_bg_general.png",
		"choices": [],
		"incoming_choice_text": incoming_choice,
		"graph_pos": Vector2(80, 120)
	}

func get_incoming_choice_text(page_id: String) -> String:
	for p in pages:
		for c in p.get("choices", []):
			var is_branch = (c.get("outcome_type") == "next_page") or (c.get("outcome_type") == "fight") or (c.get("outcome_type") == "reward" and (c.get("after_reward") == "next_page" or c.get("after_reward") == "fight"))
			if is_branch and c.get("target_page_id") == page_id:
				if c.get("text", "").strip_edges() != "":
					return c["text"].strip_edges()
	return ""

func get_page_choice_name(page_dict: Dictionary) -> String:
	var incoming = get_incoming_choice_text(page_dict.get("id", ""))
	if incoming != "":
		return incoming
	if page_dict.get("incoming_choice_text", "").strip_edges() != "":
		return page_dict["incoming_choice_text"].strip_edges()
	return page_dict.get("title", "Page")

func create_default_choice(text: String = "Proceed") -> Dictionary:
	return {
		"text": text,
		"description": "",
		"outcome_type": "scene_change", # "next_page", "reward", "fight", "scene_change"
		"target_page_id": "",
		"after_reward": "scene_change", # "scene_change", "fight", "next_page"
		"reward_type": "stat", # "stat", "piece"
		"reward_name": "Reward",
		"reward_desc": "You received a reward.",
		"reward_stat": "gold",
		"reward_stat_amount": 25.0,
		"reward_piece_path": "res://tiles/equipment/short_sword.tres",
		"enemy_path": "res://enemies/minion/pesents/pesent_1.tres",
		"next_scene": "res://locations_screen.tscn",
		"gold_cost": 0,
		"req_class": "None",
		"req_stat": "None",
		"req_value": 0.0,
		"failable": false,
		"fail_target_page_id": "",
		"req_piece_remove": false,
		"req_piece_name": "None",
		"req_piece_numb": 1
	}

func add_new_page(title: String = "", incoming_choice: String = "") -> String:
	var page_num = pages.size() + 1
	var actual_title = title if title != "" else "Page " + str(page_num)
	var new_page = create_default_page(actual_title, "Event", "Narrative text for " + actual_title + "...", incoming_choice)
	
	var pos = Vector2(80, 120)
	if selected_page_index >= 0 and selected_page_index < pages.size():
		var sel_pos = pages[selected_page_index].get("graph_pos", Vector2(80, 120))
		pos = sel_pos + Vector2(380, 0)
	new_page["graph_pos"] = pos
	
	pages.append(new_page)
	selected_page_index = pages.size() - 1
	is_dirty = true
	rebuild_graph_ui()
	load_selected_page_into_inspector()
	set_status("Added " + actual_title)
	return new_page["id"]

func duplicate_current_page() -> void:
	if selected_page_index < 0 or selected_page_index >= pages.size():
		return
	var src = pages[selected_page_index]
	var dup = src.duplicate(true)
	dup["id"] = "page_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	dup["title"] = src["title"] + " (Copy)"
	dup["graph_pos"] = src.get("graph_pos", Vector2(80, 120)) + Vector2(40, 40)
	pages.append(dup)
	selected_page_index = pages.size() - 1
	is_dirty = true
	rebuild_graph_ui()
	load_selected_page_into_inspector()
	set_status("Duplicated page.")

func delete_current_page() -> void:
	if pages.size() <= 1:
		set_status("Cannot delete the only page in an event.")
		return
	if selected_page_index < 0 or selected_page_index >= pages.size():
		return
	
	var deleted_id = pages[selected_page_index]["id"]
	pages.remove_at(selected_page_index)
	selected_page_index = clamp(selected_page_index, 0, pages.size() - 1)
	
	for p in pages:
		for c in p["choices"]:
			if c.get("target_page_id") == deleted_id:
				c["target_page_id"] = ""
				if c.get("outcome_type") == "next_page":
					c["outcome_type"] = "scene_change"
				elif c.get("outcome_type") == "reward" and c.get("after_reward") == "next_page":
					c["after_reward"] = "scene_change"
	
	is_dirty = true
	rebuild_graph_ui()
	load_selected_page_into_inspector()
	set_status("Deleted page.")

# ==============================================================================
# VISUAL GRAPH CANVAS (GRAPH EDIT)
# ==============================================================================

func rebuild_graph_ui() -> void:
	if not graph_edit:
		return
	
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()
	
	for pi in pages.size():
		var p = pages[pi]
		var gn = GraphNode.new()
		gn.name = p["id"]
		
		var choice_name = get_page_choice_name(p)
		if pi == 0:
			gn.title = "★ [ROOT] " + p["title"]
		else:
			gn.title = "↳ " + choice_name
		
		gn.position_offset = p.get("graph_pos", Vector2(80 + pi * 360, 120))
		gn.selected = (pi == selected_page_index)
		
		gn.dragged.connect(func(from, to):
			p["graph_pos"] = to
			is_dirty = true
		)
		gn.node_selected.connect(func():
			_on_graph_node_selected(gn)
		)
		gn.delete_request.connect(func():
			selected_page_index = pi
			delete_current_page()
		)
		
		# Slot 0: Story preview (Left: Input)
		var slot0_box = VBoxContainer.new()
		slot0_box.add_theme_constant_override("separation", 2)
		
		var desc_str = p.get("description", "").strip_edges()
		if desc_str.length() > 85:
			desc_str = desc_str.substr(0, 85) + "..."
		elif desc_str == "":
			desc_str = "(No story text entered)"
		
		var desc_lbl = Label.new()
		desc_lbl.text = desc_str
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(230, 0)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78, 1))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		slot0_box.add_child(desc_lbl)
		
		gn.add_child(slot0_box)
		gn.set_slot(0, true, 0, Color(0.35, 0.85, 1.0), false, 0, Color.WHITE)
		
		# Slots 1..N: Output for each choice
		var choice_list: Array = p.get("choices", [])
		var port_counter = 0
		var choice_to_port: Dictionary = {}
		var port_to_choice: Dictionary = {}
		
		for ci in choice_list.size():
			var c = choice_list[ci]
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			
			var c_text = c.get("text", "Choice")
			if c_text == "":
				c_text = "Choice #" + str(ci + 1)
			
			var c_lbl = Label.new()
			c_lbl.text = c_text
			c_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c_lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(c_lbl)
			
			var badge = Label.new()
			badge.add_theme_font_size_override("font_size", 10)
			
			var port_color = Color.WHITE
			var has_port = false
			match c.get("outcome_type", "scene_change"):
				"next_page":
					badge.text = "➔ Branch"
					badge.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
					port_color = Color(0.35, 0.85, 1.0)
					has_port = true
				"reward":
					var r_title = c.get("reward_name", "")
					if r_title == "":
						r_title = "Reward"
					var after_act = c.get("after_reward", "scene_change")
					if after_act == "next_page":
						badge.text = "★ " + r_title + " ➔ Branch"
						badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
						port_color = Color(1.0, 0.85, 0.25)
						has_port = true
					elif after_act == "fight":
						if c.get("target_page_id", "") != "":
							badge.text = "★ " + r_title + " ⚔ Fight ➔ Branch"
						else:
							badge.text = "★ " + r_title + " ⚔ Fight"
						badge.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
						port_color = Color(1.0, 0.65, 0.25)
						has_port = true
					else:
						badge.text = "★ " + r_title + " ✓ Leave"
						badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
						port_color = Color(1.0, 0.85, 0.25)
						has_port = false
				"fight":
					var enemy_name = c["enemy_path"].get_file().get_basename()
					if enemy_name == "":
						enemy_name = "Combat"
					if c.get("target_page_id", "") != "":
						badge.text = "⚔ " + enemy_name + " ➔ Branch"
					else:
						badge.text = "⚔ " + enemy_name
					badge.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
					port_color = Color(1.0, 0.4, 0.4)
					has_port = true
				"scene_change":
					badge.text = "✓ Leave"
					badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
					port_color = Color(0.4, 0.9, 0.5)
					has_port = false
			
			if c.get("gold_cost", 0) > 0:
				badge.text += " [" + str(c["gold_cost"]) + "g]"
			
			row.add_child(badge)
			gn.add_child(row)
			gn.set_slot(ci + 1, false, 0, Color.WHITE, has_port, 0, port_color)
			if has_port:
				choice_to_port[ci] = port_counter
				port_to_choice[port_counter] = ci
				port_counter += 1
		
		gn.set_meta("choice_to_port", choice_to_port)
		gn.set_meta("port_to_choice", port_to_choice)
		
		# Slot N+1: Add Choice inline button
		var add_ch_box = HBoxContainer.new()
		var add_ch_btn = Button.new()
		add_ch_btn.text = "+ Add Choice"
		add_ch_btn.flat = true
		add_ch_btn.add_theme_font_size_override("font_size", 11)
		add_ch_btn.pressed.connect(func():
			selected_page_index = pi
			var new_ch = create_default_choice("New Choice")
			p["choices"].append(new_ch)
			is_dirty = true
			rebuild_graph_ui()
			load_selected_page_into_inspector()
		)
		add_ch_box.add_child(add_ch_btn)
		gn.add_child(add_ch_box)
		gn.set_slot(choice_list.size() + 1, false, 0, Color.WHITE, false, 0, Color.WHITE)
		
		graph_edit.add_child(gn)
	
	# Connect next_page & reward branch choice wires
	for p in pages:
		var from_id = p["id"]
		var from_gn = graph_edit.get_node_or_null(NodePath(from_id))
		if from_gn == null:
			continue
		var choice_to_port: Dictionary = from_gn.get_meta("choice_to_port", {})
		var choices = p.get("choices", [])
		for ci in choices.size():
			var c = choices[ci]
			var is_branch = (c.get("outcome_type") == "next_page") or (c.get("outcome_type") == "fight") or (c.get("outcome_type") == "reward" and (c.get("after_reward") == "next_page" or c.get("after_reward") == "fight"))
			if is_branch and c.get("target_page_id", "") != "":
				var to_id = c["target_page_id"]
				var to_gn = graph_edit.get_node_or_null(NodePath(to_id))
				if to_gn != null and choice_to_port.has(ci):
					var from_port_idx = choice_to_port[ci]
					graph_edit.connect_node(from_id, from_port_idx, to_id, 0)

func auto_layout_graph() -> void:
	if pages.is_empty():
		return
	
	var depth_map: Dictionary = {}
	var queue: Array[String] = []
	
	var root_id = pages[0]["id"]
	depth_map[root_id] = 0
	queue.append(root_id)
	
	while not queue.is_empty():
		var curr_id = queue.pop_front()
		var curr_depth = depth_map[curr_id]
		
		var curr_p = null
		for p in pages:
			if p["id"] == curr_id:
				curr_p = p
				break
		if curr_p:
			for c in curr_p.get("choices", []):
				var is_branch = (c.get("outcome_type") == "next_page") or (c.get("outcome_type") == "fight") or (c.get("outcome_type") == "reward" and (c.get("after_reward") == "next_page" or c.get("after_reward") == "fight"))
				if is_branch and c.get("target_page_id", "") != "":
					var target_id = c["target_page_id"]
					if not depth_map.has(target_id):
						depth_map[target_id] = curr_depth + 1
						queue.append(target_id)
	
	var max_depth = 0
	for p in pages:
		if not depth_map.has(p["id"]):
			depth_map[p["id"]] = 1
		max_depth = max(max_depth, depth_map[p["id"]])
	
	var depth_groups: Dictionary = {}
	for p in pages:
		var d = depth_map[p["id"]]
		if not depth_groups.has(d):
			depth_groups[d] = []
		depth_groups[d].append(p)
	
	for d in depth_groups.keys():
		var group: Array = depth_groups[d]
		for gi in group.size():
			var p = group[gi]
			var x = 80 + d * 380
			var y = 100 + gi * 280
			p["graph_pos"] = Vector2(x, y)
	
	rebuild_graph_ui()
	if graph_edit:
		graph_edit.scroll_offset = Vector2.ZERO

# ==============================================================================
# UI POPULATION & INSPECTOR
# ==============================================================================

func load_selected_page_into_inspector() -> void:
	if selected_page_index < 0 or selected_page_index >= pages.size() or not page_title_edit:
		return
	var p = pages[selected_page_index]
	page_title_edit.text = p["title"]
	page_cat_edit.text = p["category"]
	page_bg_edit.text = p["background"]
	update_bg_preview(p["background"])
	page_desc_edit.text = p["description"]
	
	if page_header_lbl:
		if selected_page_index == 0:
			page_header_lbl.text = "★ Root Event Page Configuration"
		else:
			var c_name = get_page_choice_name(p)
			page_header_lbl.text = 'Sub-Page (Choice: "' + c_name + '")'
	
	rebuild_choices_ui()

func update_bg_preview(path: String) -> void:
	if not page_bg_preview:
		return
	if path != "" and ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			page_bg_preview.texture = tex
			page_bg_preview.visible = true
			return
	page_bg_preview.visible = false

func rebuild_choices_ui() -> void:
	if not choices_container:
		return
	for child in choices_container.get_children():
		child.queue_free()
	
	if selected_page_index < 0 or selected_page_index >= pages.size():
		return
	var cur_page = pages[selected_page_index]
	var choice_list: Array = cur_page["choices"]
	
	for i in choice_list.size():
		var c_data = choice_list[i]
		var card = build_choice_card(i, c_data)
		choices_container.add_child(card)

func build_choice_card(choice_idx: int, c_data: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", get_card_stylebox())
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	# Top bar: Choice title on left, Delete button on right
	var top_bar = HBoxContainer.new()
	var num_label = Label.new()
	num_label.text = "Choice #" + str(choice_idx + 1)
	num_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	num_label.add_theme_font_size_override("font_size", 12)
	num_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(num_label)
	
	var del_btn = Button.new()
	del_btn.text = "✖ Delete"
	del_btn.flat = true
	del_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	del_btn.add_theme_font_size_override("font_size", 11)
	del_btn.pressed.connect(func():
		pages[selected_page_index]["choices"].remove_at(choice_idx)
		is_dirty = true
		rebuild_graph_ui()
		rebuild_choices_ui()
	)
	top_bar.add_child(del_btn)
	vbox.add_child(top_bar)
	
	# Full-width Button Text
	var text_edit = LineEdit.new()
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.text = c_data.get("text", "")
	text_edit.placeholder_text = "Button Text (e.g. Accept Deal, Fight, Run)"
	text_edit.text_changed.connect(func(new_text):
		c_data["text"] = new_text
		is_dirty = true
		rebuild_graph_ui()
	)
	vbox.add_child(text_edit)
	
	# Sub-text Row
	var sub_bar = HBoxContainer.new()
	var sub_label = Label.new()
	sub_label.text = "Sub-text:"
	sub_label.custom_minimum_size = Vector2(70, 0)
	sub_bar.add_child(sub_label)
	var sub_edit = LineEdit.new()
	sub_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_edit.text = c_data.get("description", "")
	sub_edit.placeholder_text = "Optional hint (e.g. Lose 20g, Requires Strength)"
	sub_edit.text_changed.connect(func(new_sub):
		c_data["description"] = new_sub
		is_dirty = true
	)
	sub_bar.add_child(sub_edit)
	vbox.add_child(sub_bar)
	
	# Outcome Type Row
	var outcome_bar = HBoxContainer.new()
	var out_label = Label.new()
	out_label.text = "Outcome:"
	out_label.custom_minimum_size = Vector2(70, 0)
	outcome_bar.add_child(out_label)
	
	var outcome_opt = OptionButton.new()
	outcome_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome_opt.clip_text = true
	outcome_opt.add_item("Next Page in Chain", 0)
	outcome_opt.add_item("Reward (Stat / Piece)", 1)
	outcome_opt.add_item("Fight Encounter", 2)
	outcome_opt.add_item("Leave", 3)
	
	match c_data.get("outcome_type", "scene_change"):
		"next_page": outcome_opt.selected = 0
		"reward": outcome_opt.selected = 1
		"fight": outcome_opt.selected = 2
		"scene_change": outcome_opt.selected = 3
		_: outcome_opt.selected = 3
	outcome_bar.add_child(outcome_opt)
	
	var outcome_details = VBoxContainer.new()
	outcome_details.add_theme_constant_override("separation", 4)
	vbox.add_child(outcome_bar)
	vbox.add_child(outcome_details)
	
	outcome_opt.item_selected.connect(func(idx):
		match idx:
			0: c_data["outcome_type"] = "next_page"
			1: c_data["outcome_type"] = "reward"
			2: c_data["outcome_type"] = "fight"
			3: c_data["outcome_type"] = "scene_change"
		is_dirty = true
		rebuild_graph_ui()
		render_choice_outcome_details(outcome_details, c_data)
	)
	render_choice_outcome_details(outcome_details, c_data)
	
	# Requirements foldout
	var req_check = CheckButton.new()
	req_check.text = "Requirements & Conditions"
	req_check.button_pressed = (c_data.get("gold_cost", 0) > 0 or c_data.get("req_class", "None") != "None" or c_data.get("req_stat", "None") != "None" or c_data.get("req_piece_remove", false))
	vbox.add_child(req_check)
	
	var req_panel = PanelContainer.new()
	req_panel.visible = req_check.button_pressed
	var req_vbox = VBoxContainer.new()
	req_vbox.add_theme_constant_override("separation", 4)
	req_panel.add_child(req_vbox)
	vbox.add_child(req_panel)
	
	req_check.toggled.connect(func(toggled):
		req_panel.visible = toggled
	)
	
	var gold_row = HBoxContainer.new()
	var g_lbl = Label.new()
	g_lbl.text = "Gold Cost:"
	g_lbl.custom_minimum_size = Vector2(70, 0)
	gold_row.add_child(g_lbl)
	var g_spin = SpinBox.new()
	g_spin.max_value = 9999
	g_spin.value = c_data.get("gold_cost", 0)
	g_spin.value_changed.connect(func(val): c_data["gold_cost"] = int(val); is_dirty = true; rebuild_graph_ui())
	gold_row.add_child(g_spin)
	req_vbox.add_child(gold_row)
	
	var stat_row = HBoxContainer.new()
	stat_lbl_text(stat_row, c_data)
	req_vbox.add_child(stat_row)
	
	var class_row = HBoxContainer.new()
	var cl_lbl = Label.new()
	cl_lbl.text = "Class Req:"
	cl_lbl.custom_minimum_size = Vector2(70, 0)
	class_row.add_child(cl_lbl)
	var cl_opt = OptionButton.new()
	cl_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl_opt.clip_text = true
	var classes = ["None", "Warrior", "Wizard"]
	for ci in classes.size():
		cl_opt.add_item(classes[ci], ci)
		if classes[ci] == c_data.get("req_class", "None"):
			cl_opt.selected = ci
	cl_opt.item_selected.connect(func(ci): c_data["req_class"] = classes[ci]; is_dirty = true; rebuild_graph_ui())
	class_row.add_child(cl_opt)
	req_vbox.add_child(class_row)
	
	return panel

func stat_lbl_text(stat_row: HBoxContainer, c_data: Dictionary) -> void:
	var st_lbl = Label.new()
	st_lbl.text = "Stat Req:"
	st_lbl.custom_minimum_size = Vector2(70, 0)
	stat_row.add_child(st_lbl)
	var st_opt = OptionButton.new()
	st_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_opt.clip_text = true
	var req_stats = ["None", "strength", "proficiency", "toughness", "faith", "speed", "agility", "gold"]
	for si in req_stats.size():
		st_opt.add_item(req_stats[si], si)
		if req_stats[si] == c_data.get("req_stat", "None"):
			st_opt.selected = si
	st_opt.item_selected.connect(func(si): c_data["req_stat"] = req_stats[si]; is_dirty = true; rebuild_graph_ui())
	stat_row.add_child(st_opt)
	
	var st_val = SpinBox.new()
	st_val.max_value = 500
	st_val.value = c_data.get("req_value", 0.0)
	st_val.value_changed.connect(func(v): c_data["req_value"] = v; is_dirty = true; rebuild_graph_ui())
	stat_row.add_child(st_val)

func render_choice_outcome_details(outcome_details: VBoxContainer, c_data: Dictionary) -> void:
	for ch in outcome_details.get_children():
		ch.queue_free()
	
	match c_data.get("outcome_type", "scene_change"):
		"next_page":
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Target Page:"
			lbl.custom_minimum_size = Vector2(70, 0)
			row.add_child(lbl)
			
			var opt = OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt.clip_text = true
			var target_idx = 0
			var valid_targets: Array[Dictionary] = []
			for p in pages:
				valid_targets.append(p)
			
			for pi in valid_targets.size():
				var p = valid_targets[pi]
				var item_name = ("★ [ROOT] " + p["title"]) if pi == 0 else ("↳ " + get_page_choice_name(p))
				opt.add_item(item_name, pi)
				if p["id"] == c_data.get("target_page_id", ""):
					target_idx = pi
			
			if not valid_targets.is_empty():
				opt.selected = target_idx
				if c_data.get("target_page_id", "") == "":
					c_data["target_page_id"] = valid_targets[target_idx]["id"]
			
			opt.item_selected.connect(func(idx):
				if idx >= 0 and idx < valid_targets.size():
					c_data["target_page_id"] = valid_targets[idx]["id"]
					is_dirty = true
					rebuild_graph_ui()
			)
			row.add_child(opt)
			
			var new_page_btn = Button.new()
			new_page_btn.text = "+ Sub-Page"
			new_page_btn.tooltip_text = "Create a new connected sub-page for this choice"
			new_page_btn.pressed.connect(func():
				var branch_name = c_data["text"] if c_data.get("text", "") != "" else "Choice Branch"
				var new_id = add_new_page(branch_name, c_data.get("text", ""))
				c_data["target_page_id"] = new_id
				is_dirty = true
				rebuild_graph_ui()
				render_choice_outcome_details(outcome_details, c_data)
			)
			row.add_child(new_page_btn)
			outcome_details.add_child(row)
			
		"reward":
			var type_row = HBoxContainer.new()
			var type_lbl = Label.new()
			type_lbl.text = "Reward:"
			type_lbl.custom_minimum_size = Vector2(70, 0)
			type_row.add_child(type_lbl)
			var type_opt = OptionButton.new()
			type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			type_opt.clip_text = true
			type_opt.add_item("Stat Modification", 0)
			type_opt.add_item("Piece Card", 1)
			type_opt.selected = 1 if c_data.get("reward_type", "stat") == "piece" else 0
			type_row.add_child(type_opt)
			outcome_details.add_child(type_row)
			
			var name_row = HBoxContainer.new()
			var name_lbl = Label.new()
			name_lbl.text = "Name:"
			name_lbl.custom_minimum_size = Vector2(70, 0)
			name_row.add_child(name_lbl)
			var name_edit = LineEdit.new()
			name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_edit.text = c_data.get("reward_name", "Reward")
			name_edit.text_changed.connect(func(t): c_data["reward_name"] = t; is_dirty = true; rebuild_graph_ui())
			name_row.add_child(name_edit)
			outcome_details.add_child(name_row)
			
			var desc_row = HBoxContainer.new()
			var desc_lbl = Label.new()
			desc_lbl.text = "Desc:"
			desc_lbl.custom_minimum_size = Vector2(70, 0)
			desc_row.add_child(desc_lbl)
			var desc_edit = LineEdit.new()
			desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_edit.text = c_data.get("reward_desc", "")
			desc_edit.placeholder_text = "Reward description text..."
			desc_edit.text_changed.connect(func(t): c_data["reward_desc"] = t; is_dirty = true)
			desc_row.add_child(desc_edit)
			outcome_details.add_child(desc_row)
			
			if c_data.get("reward_type", "stat") == "stat":
				var stat_row = HBoxContainer.new()
				var stat_lbl = Label.new()
				stat_lbl.text = "Stat & Amt:"
				stat_lbl.custom_minimum_size = Vector2(70, 0)
				stat_row.add_child(stat_lbl)
				
				var st_opt = OptionButton.new()
				st_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				st_opt.clip_text = true
				var stats = ["gold", "health", "max_health", "strength", "proficiency", "toughness", "faith", "speed", "agility"]
				for si in stats.size():
					st_opt.add_item(stats[si], si)
					if stats[si] == c_data.get("reward_stat", "gold"):
						st_opt.selected = si
				st_opt.item_selected.connect(func(si): c_data["reward_stat"] = stats[si]; is_dirty = true; rebuild_graph_ui())
				stat_row.add_child(st_opt)
				
				var amt_spin = SpinBox.new()
				amt_spin.min_value = -500
				amt_spin.max_value = 5000
				amt_spin.value = c_data.get("reward_stat_amount", 25.0)
				amt_spin.value_changed.connect(func(v): c_data["reward_stat_amount"] = v; is_dirty = true; rebuild_graph_ui())
				stat_row.add_child(amt_spin)
				outcome_details.add_child(stat_row)
			else:
				var piece_row = HBoxContainer.new()
				var p_lbl = Label.new()
				p_lbl.text = "Piece Scene:"
				p_lbl.custom_minimum_size = Vector2(70, 0)
				piece_row.add_child(p_lbl)
				var p_edit = LineEdit.new()
				p_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				p_edit.text = c_data.get("reward_piece_path", "")
				p_edit.text_changed.connect(func(t): c_data["reward_piece_path"] = t; is_dirty = true; rebuild_graph_ui())
				piece_row.add_child(p_edit)
				
				var p_browse = Button.new()
				p_browse.text = "Browse..."
				p_browse.pressed.connect(func():
					file_dialog_mode = "pick_piece"
					file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
					file_dialog.current_dir = "res://tiles/equipment"
					file_dialog.filters = PackedStringArray(["*.tres ; Equipment Resources"])
					file_dialog.popup_centered(Vector2i(800, 500))
					active_picking_choice = c_data
					active_picking_field = "reward_piece_path"
					active_picking_edit = p_edit
				)
				piece_row.add_child(p_browse)
				outcome_details.add_child(piece_row)
				
			type_opt.item_selected.connect(func(idx):
				c_data["reward_type"] = "piece" if idx == 1 else "stat"
				is_dirty = true
				rebuild_graph_ui()
				render_choice_outcome_details(outcome_details, c_data)
			)
			
			# Follow-up After Reward Action
			var after_sep = HSeparator.new()
			outcome_details.add_child(after_sep)
			
			var after_row = HBoxContainer.new()
			var after_lbl = Label.new()
			after_lbl.text = "After:"
			after_lbl.custom_minimum_size = Vector2(70, 0)
			after_row.add_child(after_lbl)
			
			var after_opt = OptionButton.new()
			after_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			after_opt.clip_text = true
			after_opt.add_item("Leave", 0)
			after_opt.add_item("Trigger Fight Encounter", 1)
			after_opt.add_item("Continue to Next Page", 2)
			
			var cur_after = c_data.get("after_reward", "scene_change")
			match cur_after:
				"scene_change": after_opt.selected = 0
				"fight": after_opt.selected = 1
				"next_page": after_opt.selected = 2
				_: after_opt.selected = 0
			after_row.add_child(after_opt)
			outcome_details.add_child(after_row)
			
			var after_details = VBoxContainer.new()
			after_details.add_theme_constant_override("separation", 4)
			outcome_details.add_child(after_details)
			
			var render_after_details = func():
				for ch in after_details.get_children():
					ch.queue_free()
				match c_data.get("after_reward", "scene_change"):
					"scene_change":
						var sc_row = HBoxContainer.new()
						var sc_lbl = Label.new()
						sc_lbl.text = "Scene:"
						sc_lbl.custom_minimum_size = Vector2(70, 0)
						sc_row.add_child(sc_lbl)
						
						var cur_scene = c_data.get("next_scene", "")
						if cur_scene == "":
							cur_scene = "res://locations_screen.tscn"
							c_data["next_scene"] = cur_scene
						
						var sc_edit = LineEdit.new()
						sc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						sc_edit.text = cur_scene
						sc_edit.text_changed.connect(func(t):
							c_data["next_scene"] = t
							is_dirty = true
						)
						sc_row.add_child(sc_edit)
						
						var sc_browse = Button.new()
						sc_browse.text = "Change..."
						sc_browse.pressed.connect(func():
							file_dialog_mode = "pick_scene"
							file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
							file_dialog.current_dir = "res://"
							file_dialog.filters = PackedStringArray(["*.tscn ; Packed Scenes"])
							file_dialog.popup_centered(Vector2i(800, 500))
							active_picking_choice = c_data
							active_picking_field = "next_scene"
							active_picking_edit = sc_edit
						)
						sc_row.add_child(sc_browse)
						after_details.add_child(sc_row)
						
					"fight":
						var f_row = HBoxContainer.new()
						var f_lbl = Label.new()
						f_lbl.text = "Enemy:"
						f_lbl.custom_minimum_size = Vector2(70, 0)
						f_row.add_child(f_lbl)
						var en_edit = LineEdit.new()
						en_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						en_edit.text = c_data.get("enemy_path", "res://enemies/minion/pesents/pesent_1.tres")
						en_edit.text_changed.connect(func(t):
							c_data["enemy_path"] = t
							is_dirty = true
							rebuild_graph_ui()
						)
						f_row.add_child(en_edit)
						var en_browse = Button.new()
						en_browse.text = "Browse..."
						en_browse.pressed.connect(func():
							file_dialog_mode = "pick_enemy"
							file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
							file_dialog.current_dir = "res://enemies"
							file_dialog.filters = PackedStringArray(["*.tres ; Enemy Resources"])
							file_dialog.popup_centered(Vector2i(800, 500))
							active_picking_choice = c_data
							active_picking_field = "enemy_path"
							active_picking_edit = en_edit
						)
						f_row.add_child(en_browse)
						after_details.add_child(f_row)
						
						var b_row = HBoxContainer.new()
						var b_lbl = Label.new()
						b_lbl.text = "After Fight:"
						b_lbl.custom_minimum_size = Vector2(70, 0)
						b_row.add_child(b_lbl)
						
						var b_opt = OptionButton.new()
						b_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						b_opt.clip_text = true
						b_opt.add_item("(Leave / Conclude Event)", 0)
						var cur_target = c_data.get("target_page_id", "")
						var sel_idx = 0
						for pi in pages.size():
							var p = pages[pi]
							var item_title = ("★ [ROOT] " + p["title"]) if pi == 0 else ("↳ " + get_page_choice_name(p))
							b_opt.add_item(item_title, pi + 1)
							if p["id"] == cur_target:
								sel_idx = pi + 1
						b_opt.selected = sel_idx
						b_opt.item_selected.connect(func(idx):
							if idx == 0:
								c_data["target_page_id"] = ""
							else:
								c_data["target_page_id"] = pages[idx - 1]["id"]
							is_dirty = true
							rebuild_graph_ui()
						)
						b_row.add_child(b_opt)
						
						var new_sub_btn = Button.new()
						new_sub_btn.text = "+ Sub-Page"
						new_sub_btn.tooltip_text = "Create a new connected sub-page after this combat"
						new_sub_btn.pressed.connect(func():
							var branch_name = (c_data["text"] if c_data.get("text", "") != "" else "Combat Victory") + " (Cont.)"
							var new_id = add_new_page(branch_name, c_data.get("text", ""))
							c_data["target_page_id"] = new_id
							is_dirty = true
							rebuild_graph_ui()
							render_choice_outcome_details(outcome_details, c_data)
						)
						b_row.add_child(new_sub_btn)
						after_details.add_child(b_row)
						
					"next_page":
						var p_row = HBoxContainer.new()
						var p_lbl = Label.new()
						p_lbl.text = "Target:"
						p_lbl.custom_minimum_size = Vector2(70, 0)
						p_row.add_child(p_lbl)
						
						var p_opt = OptionButton.new()
						p_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						p_opt.clip_text = true
						var target_idx = 0
						var valid_targets: Array[Dictionary] = []
						for p in pages:
							valid_targets.append(p)
						
						for pi in valid_targets.size():
							var p = valid_targets[pi]
							var item_name = ("★ [ROOT] " + p["title"]) if pi == 0 else ("↳ " + get_page_choice_name(p))
							p_opt.add_item(item_name, pi)
							if p["id"] == c_data.get("target_page_id", ""):
								target_idx = pi
						
						if not valid_targets.is_empty():
							p_opt.selected = target_idx
							if c_data.get("target_page_id", "") == "":
								c_data["target_page_id"] = valid_targets[target_idx]["id"]
						
						p_opt.item_selected.connect(func(idx):
							if idx >= 0 and idx < valid_targets.size():
								c_data["target_page_id"] = valid_targets[idx]["id"]
								is_dirty = true
								rebuild_graph_ui()
						)
						p_row.add_child(p_opt)
						
						var new_sub_btn = Button.new()
						new_sub_btn.text = "+ Sub-Page"
						new_sub_btn.tooltip_text = "Create a new connected sub-page after this reward"
						new_sub_btn.pressed.connect(func():
							var branch_name = (c_data["text"] if c_data.get("text", "") != "" else "Reward Branch") + " (Cont.)"
							var new_id = add_new_page(branch_name, c_data.get("text", ""))
							c_data["target_page_id"] = new_id
							is_dirty = true
							rebuild_graph_ui()
							render_choice_outcome_details(outcome_details, c_data)
						)
						p_row.add_child(new_sub_btn)
						after_details.add_child(p_row)
			
			after_opt.item_selected.connect(func(idx):
				match idx:
					0: c_data["after_reward"] = "scene_change"
					1: c_data["after_reward"] = "fight"
					2: c_data["after_reward"] = "next_page"
				is_dirty = true
				rebuild_graph_ui()
				render_after_details.call()
			)
			render_after_details.call()
			
		"fight":
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Enemy:"
			lbl.custom_minimum_size = Vector2(70, 0)
			row.add_child(lbl)
			var en_edit = LineEdit.new()
			en_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			en_edit.text = c_data.get("enemy_path", "res://enemies/minion/pesents/pesent_1.tres")
			en_edit.text_changed.connect(func(t): c_data["enemy_path"] = t; is_dirty = true; rebuild_graph_ui())
			row.add_child(en_edit)
			var en_browse = Button.new()
			en_browse.text = "Browse..."
			en_browse.pressed.connect(func():
				file_dialog_mode = "pick_enemy"
				file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
				file_dialog.current_dir = "res://enemies"
				file_dialog.filters = PackedStringArray(["*.tres ; Enemy Resources"])
				file_dialog.popup_centered(Vector2i(800, 500))
				active_picking_choice = c_data
				active_picking_field = "enemy_path"
				active_picking_edit = en_edit
			)
			row.add_child(en_browse)
			outcome_details.add_child(row)
			
			var branch_row = HBoxContainer.new()
			var b_lbl = Label.new()
			b_lbl.text = "After Fight:"
			b_lbl.custom_minimum_size = Vector2(70, 0)
			branch_row.add_child(b_lbl)
			
			var b_opt = OptionButton.new()
			b_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_opt.clip_text = true
			b_opt.add_item("(Leave / Conclude Event)", 0)
			var cur_target = c_data.get("target_page_id", "")
			var sel_idx = 0
			for pi in pages.size():
				var p = pages[pi]
				var item_title = ("★ [ROOT] " + p["title"]) if pi == 0 else ("↳ " + get_page_choice_name(p))
				b_opt.add_item(item_title, pi + 1)
				if p["id"] == cur_target:
					sel_idx = pi + 1
			b_opt.selected = sel_idx
			b_opt.item_selected.connect(func(idx):
				if idx == 0:
					c_data["target_page_id"] = ""
				else:
					c_data["target_page_id"] = pages[idx - 1]["id"]
				is_dirty = true
				rebuild_graph_ui()
			)
			branch_row.add_child(b_opt)
			
			var new_sub_btn = Button.new()
			new_sub_btn.text = "+ Sub-Page"
			new_sub_btn.tooltip_text = "Create a new connected sub-page after this combat"
			new_sub_btn.pressed.connect(func():
				var branch_name = (c_data["text"] if c_data.get("text", "") != "" else "Combat Victory") + " (Cont.)"
				var new_id = add_new_page(branch_name, c_data.get("text", ""))
				c_data["target_page_id"] = new_id
				is_dirty = true
				rebuild_graph_ui()
				render_choice_outcome_details(outcome_details, c_data)
			)
			branch_row.add_child(new_sub_btn)
			outcome_details.add_child(branch_row)
			
		"scene_change":
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Scene:"
			lbl.custom_minimum_size = Vector2(70, 0)
			row.add_child(lbl)
			
			var cur_scene = c_data.get("next_scene", "")
			if cur_scene == "":
				cur_scene = "res://locations_screen.tscn"
				c_data["next_scene"] = cur_scene
			
			var sc_edit = LineEdit.new()
			sc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc_edit.text = cur_scene
			sc_edit.text_changed.connect(func(t):
				c_data["next_scene"] = t
				is_dirty = true
			)
			row.add_child(sc_edit)
			
			var sc_browse = Button.new()
			sc_browse.text = "Change..."
			sc_browse.pressed.connect(func():
				file_dialog_mode = "pick_scene"
				file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
				file_dialog.current_dir = "res://"
				file_dialog.filters = PackedStringArray(["*.tscn ; Packed Scenes"])
				file_dialog.popup_centered(Vector2i(800, 500))
				active_picking_choice = c_data
				active_picking_field = "next_scene"
				active_picking_edit = sc_edit
			)
			row.add_child(sc_browse)
			outcome_details.add_child(row)

func get_card_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.12, 0.16, 1.0)
	sb.border_color = Color(0.3, 0.26, 0.35, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb

# ==============================================================================
# SERIALIZATION & DESERIALIZATION (.TRES)
# ==============================================================================

func save_event_to_file(file_path: String) -> bool:
	if pages.is_empty():
		set_status("Cannot save an empty event.")
		return false
	
	var dir_path = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var page_events: Dictionary = {}
	for p in pages:
		var evt = Event.new()
		evt.title = p["title"]
		evt.categorie = p["category"]
		evt.description = p["description"]
		if p["background"] != "" and ResourceLoader.exists(p["background"]):
			evt.background = load(p["background"])
		page_events[p["id"]] = evt
	
	for p in pages:
		var evt: Event = page_events[p["id"]]
		var event_choices: Array[EventChoise] = []
		
		for c in p["choices"]:
			var choice_res: EventChoise = null
			
			match c["outcome_type"]:
				"next_page":
					var c_evt = EvtChoiseEvent.new()
					if page_events.has(c.get("target_page_id", "")):
						c_evt.next_event = page_events[c["target_page_id"]]
					choice_res = c_evt
					
				"fight":
					var c_fight = EvtChoiseFight.new()
					if c.get("enemy_path", "") != "" and ResourceLoader.exists(c["enemy_path"]):
						var en_res = load(c["enemy_path"])
						if en_res is EnemyResource:
							c_fight.enemy.append(en_res)
					if c.get("target_page_id", "") != "" and page_events.has(c["target_page_id"]):
						c_fight.next_event = page_events[c["target_page_id"]]
					choice_res = c_fight
					
				"reward":
					var c_rew = EvtChoiseReward.new()
					if c.get("reward_type", "stat") == "piece":
						var r_p = R_Piece.new()
						r_p.name = c.get("reward_name", "Reward")
						r_p.description = c.get("reward_desc", "")
						if c.get("reward_piece_path", "") != "" and ResourceLoader.exists(c["reward_piece_path"]):
							var p_scene = load(c["reward_piece_path"])
							if p_scene is Equipment:
								r_p.modifiers_to_add.append(p_scene)
							elif p_scene is PackedScene:
								r_p.piece_to_add.append(p_scene)
						c_rew.reward = r_p
					else:
						var r_s = R_Stat.new()
						r_s.name = c.get("reward_name", "Reward")
						r_s.description = c.get("reward_desc", "")
						r_s.stats.append(c.get("reward_stat", "gold"))
						r_s.increase.append(c.get("reward_stat_amount", 25.0))
						c_rew.reward = r_s
					
					var after_act = c.get("after_reward", "scene_change")
					match after_act:
						"fight":
							c_rew.fight_overwrite = true
							if c.get("enemy_path", "") != "" and ResourceLoader.exists(c["enemy_path"]):
								var en_res = load(c["enemy_path"])
								if en_res is EnemyResource:
									c_rew.enemy.append(en_res)
							if c.get("target_page_id", "") != "" and page_events.has(c["target_page_id"]):
								c_rew.next_event = page_events[c["target_page_id"]]
							else:
								c_rew.next_event = null
						"next_page":
							c_rew.fight_overwrite = false
							if page_events.has(c.get("target_page_id", "")):
								c_rew.next_event = page_events[c["target_page_id"]]
						"scene_change":
							c_rew.fight_overwrite = false
							c_rew.next_event = null
							c_rew.next_scene = c.get("next_scene", "res://locations_screen.tscn")
					
					choice_res = c_rew
					
				"scene_change":
					var c_sc = EvtChoiseSceneChange.new()
					c_sc.next_scene = c.get("next_scene", "res://locations_screen.tscn")
					choice_res = c_sc
			
			if choice_res != null:
				choice_res.text = c["text"]
				choice_res.description = c["description"] if c["description"] != "" else "None"
				choice_res.gold_cost = c.get("gold_cost", 0)
				choice_res.req_class = c.get("req_class", "None")
				choice_res.req_stat = c.get("req_stat", "None")
				choice_res.req_value = c.get("req_value", 0.0)
				choice_res.failable = c.get("failable", false)
				choice_res.req_piece_remove = c.get("req_piece_remove", false)
				choice_res.req_piece_name = c.get("req_piece_name", "None")
				choice_res.req_piece_numb = c.get("req_piece_numb", 1)
				event_choices.append(choice_res)
		
		evt.choises = event_choices
	
	var root_event: Event = page_events[pages[0]["id"]]
	var err = ResourceSaver.save(root_event, file_path)
	if err == OK:
		current_file_path = file_path
		is_dirty = false
		update_file_label()
		set_status("Successfully saved event to " + file_path)
		return true
	else:
		set_status("Error saving event: " + str(err))
		return false

func load_event_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		set_status("File not found: " + file_path)
		return false
	
	var res = ResourceLoader.load(file_path, "Event", ResourceLoader.CACHE_MODE_REUSE)
	if not (res is Event):
		set_status("Resource is not a valid Event: " + file_path)
		return false
	
	pages.clear()
	var visited_events: Dictionary = {}
	
	_parse_event_recursive(res as Event, visited_events)
	
	if pages.is_empty():
		new_event()
		return false
	
	current_file_path = file_path
	selected_page_index = 0
	is_dirty = false
	update_file_label()
	auto_layout_graph()
	load_selected_page_into_inspector()
	set_status("Loaded " + file_path + " (" + str(pages.size()) + " pages)")
	return true

func _parse_event_recursive(evt: Event, visited: Dictionary, incoming_choice_text: String = "") -> String:
	if evt == null:
		return ""
	if visited.has(evt):
		return visited[evt]
	
	var page_id = "page_" + str(pages.size())
	visited[evt] = page_id
	
	var page_data: Dictionary = {
		"id": page_id,
		"title": evt.title if evt.title else ("Page " + str(pages.size() + 1)),
		"category": evt.categorie if evt.categorie else "Event",
		"description": evt.description if evt.description else "",
		"background": evt.background.resource_path if evt.background else "",
		"choices": [],
		"incoming_choice_text": incoming_choice_text,
		"graph_pos": Vector2(80, 120)
	}
	pages.append(page_data)
	
	for c in evt.choises:
		if c == null:
			continue
		var c_data = create_default_choice(c.text if c.text else "Choice")
		c_data["description"] = "" if c.description == "None" else c.description
		c_data["gold_cost"] = c.gold_cost
		c_data["req_class"] = c.req_class
		c_data["req_stat"] = c.req_stat
		c_data["req_value"] = c.req_value
		c_data["failable"] = c.failable
		c_data["req_piece_remove"] = c.req_piece_remove
		c_data["req_piece_name"] = c.req_piece_name
		c_data["req_piece_numb"] = c.req_piece_numb
		
		if c is EvtChoiseEvent:
			c_data["outcome_type"] = "next_page"
			if c.next_event != null:
				c_data["target_page_id"] = _parse_event_recursive(c.next_event, visited, c.text if c.text else "")
		elif c is EvtChoiseFight:
			c_data["outcome_type"] = "fight"
			if not c.enemy.is_empty() and c.enemy[0] != null:
				c_data["enemy_path"] = c.enemy[0].resource_path
			if c.next_event != null:
				c_data["target_page_id"] = _parse_event_recursive(c.next_event, visited, c.text if c.text else "")
		elif c is EvtChoiseReward:
			c_data["outcome_type"] = "reward"
			if c.reward != null:
				c_data["reward_name"] = c.reward.name
				c_data["reward_desc"] = c.reward.description
				if c.reward is R_Piece:
					c_data["reward_type"] = "piece"
					if not c.reward.modifiers_to_add.is_empty() and c.reward.modifiers_to_add[0] != null:
						c_data["reward_piece_path"] = c.reward.modifiers_to_add[0].resource_path
					elif not c.reward.piece_to_add.is_empty() and c.reward.piece_to_add[0] != null:
						c_data["reward_piece_path"] = c.reward.piece_to_add[0].resource_path
				elif c.reward is R_Stat:
					c_data["reward_type"] = "stat"
					if not c.reward.stats.is_empty():
						c_data["reward_stat"] = c.reward.stats[0]
					if not c.reward.increase.is_empty():
						c_data["reward_stat_amount"] = c.reward.increase[0]
			
			if c.fight_overwrite:
				c_data["after_reward"] = "fight"
				if not c.enemy.is_empty() and c.enemy[0] != null:
					c_data["enemy_path"] = c.enemy[0].resource_path
				if c.next_event != null:
					c_data["target_page_id"] = _parse_event_recursive(c.next_event, visited, c.text if c.text else "")
			elif c.next_event != null:
				c_data["after_reward"] = "next_page"
				c_data["target_page_id"] = _parse_event_recursive(c.next_event, visited, c.text if c.text else "")
			else:
				c_data["after_reward"] = "scene_change"
				if c.next_scene != "":
					c_data["next_scene"] = c.next_scene
					
		elif c is EvtChoiseSceneChange:
			c_data["outcome_type"] = "scene_change"
			c_data["next_scene"] = c.next_scene
		
		page_data["choices"].append(c_data)
	
	return page_id

# ==============================================================================
# PLAYTEST PREVIEW SIMULATION
# ==============================================================================

func open_playtest_preview() -> void:
	if pages.is_empty() or not preview_modal:
		return
	preview_modal.visible = true
	preview_status.visible = false
	render_preview_page(pages[0]["id"])

func render_preview_page(page_id: String) -> void:
	var page = null
	for p in pages:
		if p["id"] == page_id:
			page = p
			break
	if page == null:
		return
	
	preview_title.text = page["title"]
	preview_cat.text = page["category"]
	preview_desc.text = page["description"]
	if page["background"] != "" and ResourceLoader.exists(page["background"]):
		preview_bg.texture = load(page["background"])
	else:
		preview_bg.texture = null
	
	for child in preview_choices.get_children():
		child.queue_free()
	
	for c in page["choices"]:
		var btn = Button.new()
		btn.text = c["text"] + (" (" + c["description"] + ")" if c["description"] != "" else "")
		if c.get("gold_cost", 0) > 0:
			btn.text += " [Cost: " + str(c["gold_cost"]) + "g]"
		btn.custom_minimum_size = Vector2(0, 42)
		
		btn.pressed.connect(func():
			match c["outcome_type"]:
				"next_page":
					if c.get("target_page_id", "") != "":
						render_preview_page(c["target_page_id"])
					else:
						preview_status.text = "Reached unlinked page."
						preview_status.visible = true
				"reward":
					var reward_msg = "★ Reward: " + c.get("reward_name", "Reward") + " (" + c.get("reward_desc", "") + ")"
					var after_act = c.get("after_reward", "scene_change")
					match after_act:
						"fight":
							var en_f = c.get("enemy_path", "").get_file()
							if c.get("target_page_id", "") != "":
								preview_status.text = reward_msg + "\n⚔ Combat Won vs: " + en_f + " (Continuing to next page...)"
								preview_status.visible = true
								render_preview_page(c["target_page_id"])
							else:
								preview_status.text = reward_msg + "\n⚔ Combat Won vs: " + en_f + " -> Event Concluded"
								preview_status.visible = true
						"next_page":
							if c.get("target_page_id", "") != "":
								preview_status.text = reward_msg + " (Continuing to next page...)"
								preview_status.visible = true
								render_preview_page(c["target_page_id"])
							else:
								preview_status.text = reward_msg + " (Target page unlinked)"
								preview_status.visible = true
						"scene_change":
							preview_status.text = reward_msg + "\n✓ Event Concluded -> " + c.get("next_scene", "locations_screen.tscn").get_file()
							preview_status.visible = true
				"fight":
					var en_f = c.get("enemy_path", "").get_file()
					if c.get("target_page_id", "") != "":
						preview_status.text = "⚔ Combat Won vs: " + en_f + " (Continuing to next page...)"
						preview_status.visible = true
						render_preview_page(c["target_page_id"])
					else:
						preview_status.text = "⚔ Combat Won vs: " + en_f + " -> Event Concluded"
						preview_status.visible = true
				"scene_change":
					preview_status.text = "✓ Event Concluded -> " + c["next_scene"].get_file()
					preview_status.visible = true
		)
		preview_choices.add_child(btn)

func close_playtest_preview() -> void:
	if preview_modal:
		preview_modal.visible = false

# ==============================================================================
# QUICK TEMPLATES
# ==============================================================================

func apply_template(template_type: String) -> void:
	pages.clear()
	match template_type:
		"dilemma":
			var root = create_default_page("The Crossroads", "Event", "The dark forest path forks into two distinct routes.")
			var p_left = create_default_page("The River Crossing", "Event", "You reach a rushing river with a rickety bridge.", "Take the river road")
			var p_right = create_default_page("The Ancient Altar", "Event", "An altar covered in moss and strange runes stands before you.", "Inspect the mossy altar")
			
			var ch1 = create_default_choice("Take the river road")
			ch1["outcome_type"] = "next_page"
			ch1["target_page_id"] = p_left["id"]
			
			var ch2 = create_default_choice("Inspect the mossy altar")
			ch2["outcome_type"] = "next_page"
			ch2["target_page_id"] = p_right["id"]
			
			root["choices"] = [ch1, ch2]
			p_left["choices"].append(create_default_choice("Cross safely and return"))
			p_right["choices"].append(create_default_choice("Pray and leave"))
			pages = [root, p_left, p_right]
			
		"risk_reward":
			var root = create_default_page("Old Hermit's Shack", "Event", "A cloaked hermit offers you a glowing elixir.")
			var ch_safe = create_default_choice("Decline politely and leave")
			var ch_gamble = create_default_choice("Drink the strange concoction")
			ch_gamble["outcome_type"] = "reward"
			ch_gamble["reward_type"] = "stat"
			ch_gamble["reward_name"] = "Vigor of the Woods"
			ch_gamble["reward_desc"] = "Permanently gain +5 Max HP"
			ch_gamble["reward_stat"] = "max_health"
			ch_gamble["reward_stat_amount"] = 5.0
			ch_gamble["after_reward"] = "scene_change"
			root["choices"] = [ch_gamble, ch_safe]
			pages = [root]
			
	selected_page_index = 0
	is_dirty = true
	auto_layout_graph()
	load_selected_page_into_inspector()
	set_status("Applied template: " + template_type)

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_new_btn_pressed() -> void:
	new_event()

func _on_open_btn_pressed() -> void:
	file_dialog_mode = "open"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://event"
	file_dialog.filters = PackedStringArray(["*.tres ; Event Resource Files"])
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_save_btn_pressed() -> void:
	if current_file_path != "":
		save_event_to_file(current_file_path)
	else:
		_on_save_as_btn_pressed()

func _on_save_as_btn_pressed() -> void:
	file_dialog_mode = "save_as"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_dir = "res://event"
	file_dialog.filters = PackedStringArray(["*.tres ; Event Resource Files"])
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_preview_btn_pressed() -> void:
	open_playtest_preview()

func _on_file_dialog_file_selected(path: String) -> void:
	match file_dialog_mode:
		"open":
			load_event_from_file(path)
		"save_as":
			save_event_to_file(path)
		"pick_bg":
			page_bg_edit.text = path
			if selected_page_index >= 0 and selected_page_index < pages.size():
				pages[selected_page_index]["background"] = path
				update_bg_preview(path)
				is_dirty = true
				rebuild_graph_ui()
		"pick_piece", "pick_enemy", "pick_scene":
			if not active_picking_choice.is_empty() and active_picking_field != "":
				active_picking_choice[active_picking_field] = path
				if active_picking_edit != null:
					active_picking_edit.text = path
				is_dirty = true
				rebuild_graph_ui()

func _on_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_id = str(from_node)
	var to_id = str(to_node)
	
	var from_gn = graph_edit.get_node_or_null(NodePath(from_node))
	var choice_idx = from_port
	if from_gn != null:
		var port_to_choice: Dictionary = from_gn.get_meta("port_to_choice", {})
		if port_to_choice.has(from_port):
			choice_idx = port_to_choice[from_port]
	
	for p in pages:
		if p["id"] == from_id:
			var choices = p.get("choices", [])
			if choice_idx >= 0 and choice_idx < choices.size():
				var c = choices[choice_idx]
				if c.get("outcome_type") == "reward":
					if c.get("after_reward") == "fight":
						c["target_page_id"] = to_id
						set_status("Connected reward combat follow-up to: " + to_id)
					else:
						c["after_reward"] = "next_page"
						c["target_page_id"] = to_id
						set_status("Connected reward branch to: " + to_id)
				elif c.get("outcome_type") == "fight":
					c["target_page_id"] = to_id
					set_status("Connected combat follow-up branch to: " + to_id)
				else:
					c["outcome_type"] = "next_page"
					c["target_page_id"] = to_id
					set_status("Connected choice to: " + to_id)
				is_dirty = true
				break
				
	rebuild_graph_ui()
	if selected_page_index >= 0 and selected_page_index < pages.size():
		load_selected_page_into_inspector()

func _on_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_id = str(from_node)
	
	var from_gn = graph_edit.get_node_or_null(NodePath(from_node))
	var choice_idx = from_port
	if from_gn != null:
		var port_to_choice: Dictionary = from_gn.get_meta("port_to_choice", {})
		if port_to_choice.has(from_port):
			choice_idx = port_to_choice[from_port]
	
	for p in pages:
		if p["id"] == from_id:
			var choices = p.get("choices", [])
			if choice_idx >= 0 and choice_idx < choices.size():
				var c = choices[choice_idx]
				if c.get("outcome_type") == "reward":
					if c.get("after_reward") == "fight":
						c["target_page_id"] = ""
						set_status("Disconnected reward combat follow-up.")
					else:
						c["after_reward"] = "scene_change"
						c["target_page_id"] = ""
						set_status("Disconnected reward branch.")
				elif c.get("outcome_type") == "fight":
					c["target_page_id"] = ""
					set_status("Disconnected combat follow-up branch.")
				else:
					c["outcome_type"] = "scene_change"
					c["target_page_id"] = ""
					set_status("Disconnected choice.")
				is_dirty = true
				break
				
	rebuild_graph_ui()
	if selected_page_index >= 0 and selected_page_index < pages.size():
		load_selected_page_into_inspector()

func _on_graph_node_selected(node: Node) -> void:
	var page_id = str(node.name)
	for i in pages.size():
		if pages[i]["id"] == page_id:
			selected_page_index = i
			load_selected_page_into_inspector()
			break

func _on_graph_node_deselected(node: Node) -> void:
	pass

func _on_graph_delete_nodes_request(nodes: Array[StringName]) -> void:
	for n_name in nodes:
		var del_id = str(n_name)
		for i in pages.size():
			if pages[i]["id"] == del_id:
				if i == 0:
					set_status("Cannot delete the root event page.")
					continue
				selected_page_index = i
				delete_current_page()
				break

func _on_add_page_btn_pressed() -> void:
	add_new_page()

func _on_auto_layout_pressed() -> void:
	auto_layout_graph()
	set_status("Auto-arranged graph layout.")

func _on_center_view_pressed() -> void:
	if graph_edit:
		graph_edit.scroll_offset = Vector2.ZERO

func _on_del_page_btn_pressed() -> void:
	delete_current_page()

func _on_add_choice_btn_pressed() -> void:
	if selected_page_index < 0 or selected_page_index >= pages.size():
		return
	var ch = create_default_choice("New Choice")
	pages[selected_page_index]["choices"].append(ch)
	is_dirty = true
	rebuild_graph_ui()
	rebuild_choices_ui()

func _on_title_changed(new_title: String) -> void:
	if selected_page_index >= 0 and selected_page_index < pages.size():
		pages[selected_page_index]["title"] = new_title
		is_dirty = true
		rebuild_graph_ui()

func _on_cat_changed(new_cat: String) -> void:
	if selected_page_index >= 0 and selected_page_index < pages.size():
		pages[selected_page_index]["category"] = new_cat
		is_dirty = true
		rebuild_graph_ui()

func _on_desc_changed() -> void:
	if selected_page_index >= 0 and selected_page_index < pages.size():
		pages[selected_page_index]["description"] = page_desc_edit.text
		is_dirty = true
		rebuild_graph_ui()

func _on_browse_bg_pressed() -> void:
	file_dialog_mode = "pick_bg"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://assets"
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Texture Images"])
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_template_selected(idx: int) -> void:
	match idx:
		1: apply_template("dilemma")
		2: apply_template("risk_reward")

func set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

func update_file_label() -> void:
	if not file_label:
		return
	var label_str = current_file_path if current_file_path != "" else "Untitled Event*"
	file_label.text = "File: " + label_str
