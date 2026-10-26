extends PanelContainer
class_name InventoryBagGrid

signal modifier_dropped_on_bag_grid(drag_data: Dictionary, target_bag_index: int)
signal bag_tile_clicked(mod: Equipment, bag_index: int)

var flow_grid: HFlowContainer
var empty_label: Label
var interactive_drag: bool = true

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(440, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.14, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.35, 0.30, 0.42, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	empty_label = Label.new()
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 14)
	empty_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.6))
	empty_label.text = "Inventory Bag is empty (Drag equipped items here to unequip)"
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(empty_label)

	flow_grid = HFlowContainer.new()
	flow_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flow_grid.add_theme_constant_override("h_separation", 8)
	flow_grid.add_theme_constant_override("v_separation", 8)
	flow_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(flow_grid)

func populate_bag(items: Array[Equipment], enable_drag: bool = true) -> void:
	interactive_drag = enable_drag
	for child in flow_grid.get_children():
		child.queue_free()

	empty_label.visible = items.is_empty()
	for idx in range(items.size()):
		var mod: Equipment = items[idx]
		if mod == null:
			continue
		var tile := InventoryTileUI.new()
		flow_grid.add_child(tile)
		tile.setup_tile(mod, idx, interactive_drag, "bag")
		tile.tile_clicked.connect(_on_tile_clicked)
		tile.modifier_dropped_on_bag.connect(_on_tile_dropped)

func _on_tile_clicked(mod: Equipment, idx: int) -> void:
	bag_tile_clicked.emit(mod, idx)

func _on_tile_dropped(drag_data: Dictionary, target_bag_index: int) -> void:
	modifier_dropped_on_bag_grid.emit(drag_data, target_bag_index)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not interactive_drag:
		return false
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "modifier_drag":
		return false
	return data.get("source", "") in ["track", "pickup", "bag"]

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "modifier_drag":
		modifier_dropped_on_bag_grid.emit(data, -1)
