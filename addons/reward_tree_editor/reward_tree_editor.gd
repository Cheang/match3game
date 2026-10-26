@tool
extends Control

# Data structures
var current_tree_path: String = ""
var tree_name: String = "Default Reward Tree"
var starting_combat_rewards: Array[Reward] = []
var starting_passive_rewards: Array[Reward] = []
var branch_nodes: Array[Dictionary] = [] # [{ "id": "", "title": "", "pos": Vector2, "req_tags": [], "unlocks": [], "removes": [], "incoming": [] }]
var selected_node_id: String = ""
var is_dirty: bool = false

# UI references
@onready var file_label: Label = $VBox/Header/HBox/FileLabel
@onready var status_label: Label = $VBox/Footer/StatusLabel
@onready var graph_edit: GraphEdit = $VBox/Main/Left/VBox/Graph
@onready var tree_name_edit: LineEdit = $VBox/Main/Right/Scroll/Inspector/TreeBox/VBox/Grid/TreeNameEdit
@onready var node_header_lbl: Label = $VBox/Main/Right/Scroll/Inspector/NodeBox/VBox/NodeHeaderLbl
@onready var node_content: VBoxContainer = $VBox/Main/Right/Scroll/Inspector/NodeBox/VBox/NodeContent
@onready var file_dialog: FileDialog = $FileDialog

# Simulation modal
@onready var draft_modal: PanelContainer = $TestDraftModal
@onready var draft_cards_holder: HBoxContainer = $TestDraftModal/Margin/VBox/CardsHolder
@onready var draft_tags_label: Label = $TestDraftModal/Margin/VBox/TagsLabel
@onready var draft_result_label: Label = $TestDraftModal/Margin/VBox/DraftResultLbl

var file_dialog_mode: String = "open" # "open", "save_as", "pick_card"
var active_card_target_list: Array = []
var sim_tree: RewardTree = null

func _ready() -> void:
	if not file_dialog:
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	if draft_modal:
		draft_modal.visible = false

	if ResourceLoader.exists("res://rewards/warrior_tree.tres"):
		load_tree_from_path("res://rewards/warrior_tree.tres")
	else:
		new_tree()

func set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

func update_file_label() -> void:
	if file_label:
		var fn = current_tree_path.get_file() if current_tree_path != "" else "Untitled Tree"
		file_label.text = "File: " + fn + ("*" if is_dirty else "")

# ==============================================================================
# TREE DATA MANAGEMENT
# ==============================================================================
func new_tree() -> void:
	current_tree_path = ""
	tree_name = "New Reward Tree"
	if tree_name_edit:
		tree_name_edit.text = tree_name
	starting_combat_rewards.clear()
	starting_passive_rewards.clear()
	branch_nodes.clear()
	selected_node_id = "start_node"
	is_dirty = false
	update_file_label()
	rebuild_graph_ui()
	load_selected_node_into_inspector()
	set_status("Created new blank reward tree.")

func load_tree_from_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var res = load(path)
	if not (res is RewardTree):
		set_status("Selected file is not a RewardTree resource.")
		return

	var tree_res: RewardTree = res
	current_tree_path = path
	tree_name = tree_res.tree_name
	if tree_name_edit:
		tree_name_edit.text = tree_name

	starting_combat_rewards.clear()
	for r in tree_res.starting_combat_rewards:
		if r != null: starting_combat_rewards.append(r)

	starting_passive_rewards.clear()
	for r in tree_res.starting_passive_rewards:
		if r != null: starting_passive_rewards.append(r)

	branch_nodes.clear()
	for n in tree_res.nodes:
		if n != null:
			var node_dict := {
				"id": n.id if n.id != "" else ("node_" + str(randi() % 10000)),
				"title": n.title,
				"pos": n.graph_pos,
				"req_tags": n.required_tags.duplicate(),
				"unlocks": n.unlocked_rewards.duplicate(),
				"removes": n.removed_rewards.duplicate(),
				"incoming": n.incoming_connections.duplicate()
			}
			branch_nodes.append(node_dict)

	selected_node_id = "start_node"
	is_dirty = false
	update_file_label()
	rebuild_graph_ui()
	load_selected_node_into_inspector()
	set_status("Loaded tree: " + path)

func save_tree_to_path(path: String) -> void:
	var tree_res := RewardTree.new()
	tree_res.tree_name = tree_name
	tree_res.starting_combat_rewards = starting_combat_rewards.duplicate()
	tree_res.starting_passive_rewards = starting_passive_rewards.duplicate()
	tree_res.nodes.clear()

	for d in branch_nodes:
		var n = RewardTreeNode.new()
		n.id = d["id"]
		n.title = d["title"]
		n.graph_pos = d["pos"]
		n.required_tags.clear()
		for t in d["req_tags"]: n.required_tags.append(str(t))
		n.unlocked_rewards.clear()
		for r in d["unlocks"]: if r is Reward: n.unlocked_rewards.append(r)
		n.removed_rewards.clear()
		for r in d["removes"]: if r is Reward: n.removed_rewards.append(r)
		n.incoming_connections.clear()
		for inc in d["incoming"]: n.incoming_connections.append(str(inc))
		tree_res.nodes.append(n)

	var err = ResourceSaver.save(tree_res, path)
	if err == OK:
		current_tree_path = path
		is_dirty = false
		update_file_label()
		set_status("Saved reward tree to " + path)
	else:
		set_status("Error saving tree: " + str(err))

# ==============================================================================
# GRAPH CANVAS RENDERING
# ==============================================================================
func rebuild_graph_ui() -> void:
	if not graph_edit:
		return
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()

	# 1. Start Node (Special Root Node)
	var start_gn := GraphNode.new()
	start_gn.name = "start_node"
	start_gn.title = "🌱 Starting Pools"
	start_gn.position_offset = Vector2(40, 80)
	start_gn.resizable = false
	start_gn.custom_minimum_size = Vector2(200, 140)

	var start_lbl := Label.new()
	start_lbl.text = "Combat Cards: %d\nPassive Cards: %d" % [starting_combat_rewards.size(), starting_passive_rewards.size()]
	start_gn.add_child(start_lbl)
	start_gn.set_slot(0, false, 0, Color.TRANSPARENT, true, 0, Color("#f2c94c"))
	start_gn.node_selected.connect(func(): _select_node("start_node"))
	graph_edit.add_child(start_gn)

	# 2. Branch Nodes
	for d in branch_nodes:
		var gn := GraphNode.new()
		gn.name = d["id"]
		gn.title = d["title"]
		gn.position_offset = d["pos"]
		gn.resizable = false
		gn.custom_minimum_size = Vector2(220, 150)

		var info_vbox := VBoxContainer.new()
		info_vbox.name = "info_vbox"
		var req_lbl := Label.new()
		req_lbl.name = "req_lbl"
		req_lbl.text = "Req: " + (", ".join(d["req_tags"]) if not d["req_tags"].is_empty() else "None")
		req_lbl.add_theme_color_override("font_color", Color("#85d7ff"))
		req_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info_vbox.add_child(req_lbl)

		var unl_lbl := Label.new()
		unl_lbl.name = "unl_lbl"
		unl_lbl.text = "Unlocks: +%d cards" % d["unlocks"].size()
		unl_lbl.add_theme_color_override("font_color", Color("#69e68b"))
		info_vbox.add_child(unl_lbl)

		var rem_lbl := Label.new()
		rem_lbl.name = "rem_lbl"
		rem_lbl.text = "Removes: -%d cards" % d["removes"].size()
		rem_lbl.add_theme_color_override("font_color", Color("#ff7b88"))
		info_vbox.add_child(rem_lbl)

		gn.add_child(info_vbox)
		# Slot 0: Input (left), Output (right)
		gn.set_slot(0, true, 0, Color("#85d7ff"), true, 0, Color("#f2c94c"))
		var n_id = d["id"]
		gn.node_selected.connect(func(): _select_node(n_id))
		gn.dragged.connect(func(from_pos, to_pos): _on_node_dragged(n_id, to_pos))
		graph_edit.add_child(gn)

	# 3. Connections
	for d in branch_nodes:
		for inc_id in d.get("incoming", []):
			graph_edit.connect_node(inc_id, 0, d["id"], 0)

func _select_node(node_id: String) -> void:
	selected_node_id = node_id
	load_selected_node_into_inspector()

func _on_node_dragged(node_id: String, to_pos: Vector2) -> void:
	for d in branch_nodes:
		if d["id"] == node_id:
			d["pos"] = to_pos
			is_dirty = true
			update_file_label()
			break

func _update_node_canvas_item(node_id: String) -> void:
	if not graph_edit:
		return
	var gn = graph_edit.get_node_or_null(node_id)
	if gn is GraphNode:
		var d = _get_node_dict(node_id)
		if not d.is_empty():
			gn.title = d["title"]
			var req_lbl = gn.get_node_or_null("info_vbox/req_lbl")
			if req_lbl is Label:
				req_lbl.text = "Req: " + (", ".join(d["req_tags"]) if not d["req_tags"].is_empty() else "None")
			var unl_lbl = gn.get_node_or_null("info_vbox/unl_lbl")
			if unl_lbl is Label:
				unl_lbl.text = "Unlocks: +%d cards" % d["unlocks"].size()
			var rem_lbl = gn.get_node_or_null("info_vbox/rem_lbl")
			if rem_lbl is Label:
				rem_lbl.text = "Removes: -%d cards" % d["removes"].size()

# ==============================================================================
# RIGHT INSPECTOR PANEL
# ==============================================================================
func load_selected_node_into_inspector() -> void:
	if not node_content:
		return
	for c in node_content.get_children():
		c.queue_free()

	if selected_node_id == "start_node":
		node_header_lbl.text = "🌱 Starting Pools Configuration"
		_build_start_node_inspector()
	else:
		var d = _get_node_dict(selected_node_id)
		if not d.is_empty() and d.has("title"):
			node_header_lbl.text = "Branch: " + str(d["title"])
			_build_branch_node_inspector(d)
		else:
			node_header_lbl.text = "No Node Selected"

func _get_node_dict(n_id: String) -> Dictionary:
	for d in branch_nodes:
		if d["id"] == n_id:
			return d
	return {}

func _build_start_node_inspector() -> void:
	# Combat Cards Section
	var combat_hdr := Label.new()
	combat_hdr.text = "⚔️ Starting Combat Reward Cards:"
	combat_hdr.add_theme_color_override("font_color", Color("#f2c94c"))
	node_content.add_child(combat_hdr)

	var combat_list_box := VBoxContainer.new()
	node_content.add_child(combat_list_box)
	_render_card_list_items(combat_list_box, starting_combat_rewards)

	var add_combat_btn := Button.new()
	add_combat_btn.text = "+ Add Combat Card..."
	add_combat_btn.pressed.connect(func(): _open_card_picker(starting_combat_rewards))
	node_content.add_child(add_combat_btn)

	var sep := HSeparator.new()
	node_content.add_child(sep)

	# Passive Cards Section
	var passive_hdr := Label.new()
	passive_hdr.text = "🏆 Starting Boss Passive / Talent Cards:"
	passive_hdr.add_theme_color_override("font_color", Color("#f2c94c"))
	node_content.add_child(passive_hdr)

	var passive_list_box := VBoxContainer.new()
	node_content.add_child(passive_list_box)
	_render_card_list_items(passive_list_box, starting_passive_rewards)

	var add_passive_btn := Button.new()
	add_passive_btn.text = "+ Add Passive Card..."
	add_passive_btn.pressed.connect(func(): _open_card_picker(starting_passive_rewards))
	node_content.add_child(add_passive_btn)

func _build_branch_node_inspector(d: Dictionary) -> void:
	# Title Edit
	var title_lbl := Label.new()
	title_lbl.text = "Branch Title:"
	node_content.add_child(title_lbl)

	var title_edit := LineEdit.new()
	title_edit.text = d["title"]
	var node_id = d["id"]
	title_edit.text_changed.connect(func(t):
		d["title"] = t
		is_dirty = true
		update_file_label()
		_update_node_canvas_item(node_id)
	)
	node_content.add_child(title_edit)

	# Required Tags Edit
	var tags_lbl := Label.new()
	tags_lbl.text = "Required Tags (Comma separated):"
	node_content.add_child(tags_lbl)

	var tags_edit := LineEdit.new()
	tags_edit.text = ", ".join(d["req_tags"])
	tags_edit.placeholder_text = "e.g. flg_rew_fists_lvl_1, flg_rew_body_1"
	tags_edit.text_changed.connect(func(t):
		var raw_tags = t.split(",")
		d["req_tags"].clear()
		for rt in raw_tags:
			var trimmed = rt.strip_edges()
			if trimmed != "":
				d["req_tags"].append(trimmed)
		is_dirty = true
		update_file_label()
		_update_node_canvas_item(node_id)
	)
	node_content.add_child(tags_edit)

	var sep1 := HSeparator.new()
	node_content.add_child(sep1)

	# Unlocked Cards Section
	var unl_lbl := Label.new()
	unl_lbl.text = "🟢 Cards Unlocked Into Pool:"
	unl_lbl.add_theme_color_override("font_color", Color("#69e68b"))
	node_content.add_child(unl_lbl)

	var unl_box := VBoxContainer.new()
	node_content.add_child(unl_box)
	_render_card_list_items(unl_box, d["unlocks"])

	var add_unl_btn := Button.new()
	add_unl_btn.text = "+ Add Unlocked Card..."
	add_unl_btn.pressed.connect(func(): _open_card_picker(d["unlocks"]))
	node_content.add_child(add_unl_btn)

	var sep2 := HSeparator.new()
	node_content.add_child(sep2)

	# Removed Cards Section
	var rem_lbl := Label.new()
	rem_lbl.text = "🔴 Cards Removed From Pool:"
	rem_lbl.add_theme_color_override("font_color", Color("#ff7b88"))
	node_content.add_child(rem_lbl)

	var rem_box := VBoxContainer.new()
	node_content.add_child(rem_box)
	_render_card_list_items(rem_box, d["removes"])

	var add_rem_btn := Button.new()
	add_rem_btn.text = "+ Add Card To Remove..."
	add_rem_btn.pressed.connect(func(): _open_card_picker(d["removes"]))
	node_content.add_child(add_rem_btn)

func _render_card_list_items(container: VBoxContainer, card_list: Array) -> void:
	for i in range(card_list.size()):
		var rew = card_list[i]
		if rew == null:
			continue
		var row := HBoxContainer.new()

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex = rew.get("icon")
		if icon_tex != null:
			icon_rect.texture = icon_tex
		row.add_child(icon_rect)

		var name_lbl := Label.new()
		var card_name = rew.get("name")
		if card_name == null or str(card_name) == "":
			card_name = rew.resource_path.get_file()
		name_lbl.text = str(card_name)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.tooltip_text = _get_card_desc_str(rew)
		row.add_child(name_lbl)

		var del_btn := Button.new()
		del_btn.text = "✖"
		var idx = i
		del_btn.pressed.connect(func():
			card_list.remove_at(idx)
			is_dirty = true
			update_file_label()
			rebuild_graph_ui()
			load_selected_node_into_inspector()
		)
		row.add_child(del_btn)

		container.add_child(row)

func _open_card_picker(target_list: Array) -> void:
	active_card_target_list = target_list
	file_dialog_mode = "pick_card"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://rewards/cards"
	file_dialog.filters = PackedStringArray(["*.tres ; Reward Resources"])
	file_dialog.popup_centered(Vector2i(800, 500))

# ==============================================================================
# BUTTON & GRAPH SIGNALS
# ==============================================================================
func _on_new_btn_pressed() -> void:
	new_tree()

func _on_open_btn_pressed() -> void:
	file_dialog_mode = "open"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://rewards"
	file_dialog.filters = PackedStringArray(["*.tres ; Reward Tree Resources"])
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_save_btn_pressed() -> void:
	if current_tree_path != "":
		save_tree_to_path(current_tree_path)
	else:
		_on_save_as_btn_pressed()

func _on_save_as_btn_pressed() -> void:
	file_dialog_mode = "save_as"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_dir = "res://rewards"
	file_dialog.filters = PackedStringArray(["*.tres ; Reward Tree Resources"])
	file_dialog.popup_centered(Vector2i(800, 500))

func _on_add_branch_btn_pressed() -> void:
	var new_id = "node_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var pos = Vector2(360, 120)
	if not branch_nodes.is_empty():
		pos = branch_nodes.back()["pos"] + Vector2(260, 40)

	var new_node := {
		"id": new_id,
		"title": "New Branch Tier " + str(branch_nodes.size() + 1),
		"pos": pos,
		"req_tags": [],
		"unlocks": [],
		"removes": [],
		"incoming": [selected_node_id if selected_node_id != "" else "start_node"]
	}
	branch_nodes.append(new_node)
	selected_node_id = new_id
	is_dirty = true
	update_file_label()
	rebuild_graph_ui()
	load_selected_node_into_inspector()
	set_status("Added new branch node.")

func _on_del_branch_btn_pressed() -> void:
	if selected_node_id == "" or selected_node_id == "start_node":
		set_status("Cannot delete Starting Pools node.")
		return

	for i in range(branch_nodes.size() - 1, -1, -1):
		if branch_nodes[i]["id"] == selected_node_id:
			branch_nodes.remove_at(i)
			break

	# Clean up incoming references
	for d in branch_nodes:
		d["incoming"].erase(selected_node_id)

	selected_node_id = "start_node"
	is_dirty = true
	update_file_label()
	rebuild_graph_ui()
	load_selected_node_into_inspector()
	set_status("Deleted branch node.")

func _on_auto_layout_pressed() -> void:
	var x_offset = 360
	var y_offset = 80
	for i in range(branch_nodes.size()):
		branch_nodes[i]["pos"] = Vector2(x_offset + (i % 3) * 280, y_offset + int(i / 3) * 220)
	is_dirty = true
	update_file_label()
	rebuild_graph_ui()
	set_status("Auto-arranged branch layout.")

func _on_center_view_pressed() -> void:
	if graph_edit:
		graph_edit.scroll_offset = Vector2.ZERO

func _on_tree_name_changed(new_text: String) -> void:
	tree_name = new_text
	is_dirty = true
	update_file_label()

func _on_graph_connection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	if str(to_node) == "start_node":
		return
	var target = _get_node_dict(str(to_node))
	if not target.is_empty():
		if not target["incoming"].has(str(from_node)):
			target["incoming"].append(str(from_node))
			is_dirty = true
			update_file_label()
			rebuild_graph_ui()
			set_status("Connected: %s -> %s" % [from_node, to_node])

func _on_graph_disconnection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	var target = _get_node_dict(str(to_node))
	if not target.is_empty():
		target["incoming"].erase(str(from_node))
		is_dirty = true
		update_file_label()
		rebuild_graph_ui()
		set_status("Disconnected: %s from %s" % [from_node, to_node])

func _on_graph_delete_nodes_request(nodes_to_del: Array[StringName]) -> void:
	for n in nodes_to_del:
		if str(n) != "start_node":
			selected_node_id = str(n)
			_on_del_branch_btn_pressed()

func _on_graph_node_selected(node: Node) -> void:
	_select_node(node.name)

func _on_graph_node_deselected(_node: Node) -> void:
	pass

func _on_file_dialog_file_selected(path: String) -> void:
	match file_dialog_mode:
		"open":
			load_tree_from_path(path)
		"save_as":
			save_tree_to_path(path)
		"pick_card":
			if ResourceLoader.exists(path):
				var res = load(path)
				if res is Reward:
					active_card_target_list.append(res)
					is_dirty = true
					update_file_label()
					rebuild_graph_ui()
					load_selected_node_into_inspector()
					set_status("Added reward card: " + path.get_file())
				else:
					set_status("File is not a Reward resource.")

# ==============================================================================
# TEST DRAFT SIMULATION
# ==============================================================================
func _on_test_draft_btn_pressed() -> void:
	_reset_simulation_state()
	draft_modal.visible = true

func _close_draft_modal() -> void:
	draft_modal.visible = false

func _reset_simulation_state() -> void:
	sim_tree = RewardTree.new()
	sim_tree.tree_name = tree_name
	sim_tree.starting_combat_rewards = starting_combat_rewards.duplicate()
	sim_tree.starting_passive_rewards = starting_passive_rewards.duplicate()
	sim_tree.nodes.clear()

	for d in branch_nodes:
		var n = RewardTreeNode.new()
		n.id = d["id"]
		n.title = d["title"]
		n.graph_pos = d["pos"]
		for t in d["req_tags"]: n.required_tags.append(str(t))
		for r in d["unlocks"]: if r is Reward: n.unlocked_rewards.append(r)
		for r in d["removes"]: if r is Reward: n.removed_rewards.append(r)
		sim_tree.nodes.append(n)

	sim_tree.initialize_run()
	_update_sim_tags_display()
	_roll_simulation_draft()

func _update_sim_tags_display() -> void:
	if not sim_tree: return
	var tag_keys = sim_tree.unlocked_tags.keys()
	if tag_keys.is_empty():
		draft_tags_label.text = "Acquired Tags: (None) • Active Combat Pool: %d cards" % sim_tree.active_combat_pool.size()
	else:
		draft_tags_label.text = "Acquired Tags: [%s] • Active Combat Pool: %d cards" % [", ".join(tag_keys), sim_tree.active_combat_pool.size()]

func _roll_simulation_draft() -> void:
	if not sim_tree or not draft_cards_holder:
		return
	for c in draft_cards_holder.get_children():
		c.queue_free()

	var pool = sim_tree.get_combat_pool()
	if pool.is_empty():
		draft_result_label.text = "Active combat pool is empty!"
		return

	var rolled_cards: Array[Reward] = []
	var pool_copy = pool.duplicate()
	pool_copy.shuffle()

	for i in range(min(3, pool_copy.size())):
		rolled_cards.append(pool_copy[i])

	for rew in rolled_cards:
		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(180, 140)
		var card_name = rew.get("name")
		if card_name == null or str(card_name) == "":
			card_name = rew.resource_path.get_file()
		var r_str = _get_card_rarity_str(rew)
		var d_str = _get_card_desc_str(rew)
		card_btn.text = "%s\n[%s]\n\n%s" % [card_name, r_str, d_str]
		card_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var chosen_rew = rew
		card_btn.pressed.connect(func(): _pick_simulation_card(chosen_rew))
		draft_cards_holder.add_child(card_btn)

	draft_result_label.text = "Showing 3 cards drawn from active tree pool."

func _get_card_rarity_str(rew) -> String:
	if rew == null: return "COMMON"
	var r = rew.get("rarity")
	if r != null:
		var idx = int(r)
		if idx >= 0 and idx < Reward.Rarity.size():
			return Reward.Rarity.keys()[idx]
	return "COMMON"

func _get_card_desc_str(rew) -> String:
	if rew == null: return ""
	var d = rew.get("description")
	if d != null and str(d) != "":
		return str(d)
	return ""

func _pick_simulation_card(rew) -> void:
	if not sim_tree: return
	sim_tree.on_reward_chosen(rew)
	_update_sim_tags_display()
	var card_name = rew.get("name")
	if card_name == null or str(card_name) == "":
		card_name = rew.resource_path.get_file()
	draft_result_label.text = "Picked '%s'! Tags updated. Rolling next combat reward draft..." % card_name
	_roll_simulation_draft()
