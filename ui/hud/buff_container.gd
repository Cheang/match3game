class_name BuffContainer
extends Control

## Reusable 5xX grid container for displaying active Buffs and Debuffs on either
## the Player or an Enemy. Automatically syncs with EntityResource.buffsChanged
## and expands to additional rows when more than 10 buffs/debuffs are active.
## Shows live preview buffs in the editor so you can see how it looks at design time.

const FONT_TITLE := preload("res://assets/theme/title.ttf")
const ICON_DODGE := preload("res://assets/sprites/ui/combat/buff_dodge.png")
const ICON_COMBO := preload("res://assets/sprites/ui/combat/buff_combo.png")

const PREVIEW_DEFS: Array[Dictionary] = [
	{"id": "dodge", "title": "Dodge", "icon": ICON_DODGE, "stacks": 1, "show_stacks": false, "desc": "Negates the next incoming physical attack."},
	{"id": "combo", "title": "Combo", "icon": ICON_COMBO, "stacks": 3, "show_stacks": true, "desc": "Increases damage of combo skills."},
	{"id": "dodge", "title": "Dodge", "icon": ICON_DODGE, "stacks": 2, "show_stacks": true, "desc": "Dodge incoming physical hits."},
	{"id": "combo", "title": "Combo", "icon": ICON_COMBO, "stacks": 5, "show_stacks": true, "desc": "Increases damage of combo skills."},
	{"id": "dodge", "title": "Dodge", "icon": ICON_DODGE, "stacks": 1, "show_stacks": false, "desc": "Dodge next physical hit."},
	{"id": "combo", "title": "Combo", "icon": ICON_COMBO, "stacks": 10, "show_stacks": true, "desc": "Massive combo multiplier."},
	{"id": "dodge", "title": "Dodge", "icon": ICON_DODGE, "stacks": 4, "show_stacks": true, "desc": "Multiple dodges stored."},
	{"id": "combo", "title": "Combo", "icon": ICON_COMBO, "stacks": 7, "show_stacks": true, "desc": "Heavy combo strike charged."},
	{"id": "dodge", "title": "Dodge", "icon": ICON_DODGE, "stacks": 2, "show_stacks": true, "desc": "Dodges active."},
	{"id": "combo", "title": "Combo", "icon": ICON_COMBO, "stacks": 12, "show_stacks": true, "desc": "Ultimate combo scaling ready."},
	{"id": "dodge", "title": "Dodge", "icon": ICON_DODGE, "stacks": 3, "show_stacks": true, "desc": "Row 3 dynamic overflow buff."},
	{"id": "combo", "title": "Combo", "icon": ICON_COMBO, "stacks": 15, "show_stacks": true, "desc": "Row 3 dynamic overflow buff."},
]

@export var columns: int = 5:
	set(val):
		columns = maxi(1, val)
		_on_layout_param_changed()

@export var rows: int = 2:
	set(val):
		rows = maxi(1, val)
		_on_layout_param_changed()

@export var slot_size: Vector2 = Vector2(32, 32):
	set(val):
		slot_size = val
		_on_layout_param_changed()

@export var h_separation: int = 10:
	set(val):
		h_separation = val
		_on_layout_param_changed()

@export var v_separation: int = 10:
	set(val):
		v_separation = val
		_on_layout_param_changed()

@export_group("Editor Preview")
@export var editor_preview: bool = true:
	set(val):
		editor_preview = val
		if Engine.is_editor_hint():
			_update_editor_preview()

@export_range(0, 25) var editor_preview_count: int = 10:
	set(val):
		editor_preview_count = val
		if Engine.is_editor_hint():
			_update_editor_preview()

var _bound_entity: EntityResource = null
var _slots: Array[Control] = []
var _slot_buff_ids: Array[String] = []
var _slot_stacks: Array[int] = []
var _is_refreshing: bool = false


func _ready() -> void:
	_ensure_slots()
	if Engine.is_editor_hint():
		_update_editor_preview()
	else:
		refresh()


func _exit_tree() -> void:
	_unbind_current()


func _on_layout_param_changed() -> void:
	if not is_inside_tree():
		return
	_ensure_slots()
	if Engine.is_editor_hint():
		_update_editor_preview()
	else:
		refresh()


func _reposition_slots(cols: int, needed_rows: int) -> void:
	for i in range(_slots.size()):
		var slot: Control = _slots[i]
		if slot == null:
			continue
		var col: int = i % cols
		var row: int = int(float(i) / float(cols))
		slot.position = Vector2(
			col * (slot_size.x + h_separation),
			row * (slot_size.y + v_separation)
		)
		slot.size = slot_size
		slot.custom_minimum_size = slot_size
		var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
		if icon != null:
			icon.size = slot_size
			icon.custom_minimum_size = slot_size
		var lbl: Label = slot.get_node_or_null("StackLabel") as Label
		if lbl != null:
			lbl.size = Vector2(slot_size.x - 1.0, slot_size.y + 1.0)

	var total_width: float = cols * slot_size.x + maxi(0, cols - 1) * h_separation
	var total_height: float = needed_rows * slot_size.y + maxi(0, needed_rows - 1) * v_separation
	custom_minimum_size = Vector2(total_width, total_height)
	size = Vector2(maxf(size.x, total_width), total_height)


func _ensure_slots(required_count: int = 0) -> void:
	var cols: int = maxi(1, columns)
	var min_rows: int = maxi(1, rows)
	var needed_rows: int = maxi(min_rows, ceili(float(required_count) / float(cols)))
	var target_total_slots: int = cols * needed_rows

	if _slots.is_empty():
		for child in get_children():
			if child is Control and child.name.begins_with("BuffSlot_"):
				_slots.append(child)
				_slot_buff_ids.append("")
				_slot_stacks.append(0)

	while _slots.size() < target_total_slots:
		var i: int = _slots.size()
		var col: int = i % cols
		var row: int = int(float(i) / float(cols))
		var pos := Vector2(
			col * (slot_size.x + h_separation),
			row * (slot_size.y + v_separation)
		)

		var slot := Control.new()
		slot.name = "BuffSlot_%d" % i
		slot.position = pos
		slot.size = slot_size
		slot.custom_minimum_size = slot_size
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.visible = false

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2.ZERO
		icon.size = slot_size
		icon.custom_minimum_size = slot_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var lbl := Label.new()
		lbl.name = "StackLabel"
		lbl.position = Vector2(0, 0)
		lbl.size = Vector2(slot_size.x - 1.0, slot_size.y + 1.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.15, 1.0))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.visible = false
		slot.add_child(lbl)

		add_child(slot)
		_slots.append(slot)
		_slot_buff_ids.append("")
		_slot_stacks.append(0)

	_reposition_slots(cols, needed_rows)


func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	if _bound_entity != null:
		refresh()
		return

	if not editor_preview or editor_preview_count <= 0:
		_ensure_slots(0)
		for s in _slots:
			s.visible = false
		return

	_ensure_slots(editor_preview_count)

	for i in range(_slots.size()):
		var slot: Control = _slots[i]
		var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
		var lbl: Label = slot.get_node_or_null("StackLabel") as Label

		if i < editor_preview_count:
			var data: Dictionary = PREVIEW_DEFS[i % PREVIEW_DEFS.size()]
			var stacks: int = int(data.get("stacks", 1))
			var show_stk: bool = bool(data.get("show_stacks", true))

			if icon != null:
				icon.texture = data["icon"]
			slot.tooltip_text = "%s%s [Preview]\n%s" % [
				data["title"],
				(" (x%d)" % stacks) if (show_stk or stacks > 1) else "",
				data["desc"]
			]
			slot.visible = true

			if lbl != null:
				if show_stk or stacks > 1:
					lbl.text = str(stacks)
					lbl.visible = true
				else:
					lbl.text = ""
					lbl.visible = false

			_slot_buff_ids[i] = data["id"]
			_slot_stacks[i] = stacks
		else:
			if icon != null:
				icon.texture = null
			slot.tooltip_text = ""
			slot.visible = false
			if lbl != null:
				lbl.text = ""
				lbl.visible = false
			_slot_buff_ids[i] = ""
			_slot_stacks[i] = 0

	_is_refreshing = false


func bind_entity(entity: EntityResource) -> void:
	if _bound_entity != entity:
		_unbind_current()
		_bound_entity = entity
		if _bound_entity != null and not _bound_entity.buffsChanged.is_connected(_on_entity_buffs_changed):
			_bound_entity.buffsChanged.connect(_on_entity_buffs_changed)
	refresh()


func _unbind_current() -> void:
	if _bound_entity != null and _bound_entity.buffsChanged.is_connected(_on_entity_buffs_changed):
		_bound_entity.buffsChanged.disconnect(_on_entity_buffs_changed)
	_bound_entity = null


func _on_entity_buffs_changed() -> void:
	refresh()


func refresh(entity: EntityResource = null) -> void:
	if _is_refreshing:
		return
	_is_refreshing = true

	if entity != null and entity != _bound_entity:
		bind_entity(entity)
		_is_refreshing = false
		return

	if Engine.is_editor_hint() and _bound_entity == null and editor_preview:
		_update_editor_preview()
		_is_refreshing = false
		return

	var target: EntityResource = entity if entity != null else _bound_entity
	var entries: Array[Dictionary] = []
	if target != null:
		entries = target.get_active_buff_entries()

	_ensure_slots(entries.size())

	for i in range(_slots.size()):
		var slot: Control = _slots[i]
		var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
		var lbl: Label = slot.get_node_or_null("StackLabel") as Label

		if i < entries.size():
			var entry: Dictionary = entries[i]
			var def = entry["def"]
			var stacks: int = int(entry["stacks"])

			if icon != null:
				icon.texture = def.get_icon()
			slot.tooltip_text = def.build_tooltip(stacks)
			slot.visible = true

			if lbl != null:
				if def.show_stacks or stacks > 1:
					lbl.text = str(stacks)
					lbl.visible = true
				else:
					lbl.text = ""
					lbl.visible = false

			_slot_buff_ids[i] = def.id
			_slot_stacks[i] = stacks
		else:
			if icon != null:
				icon.texture = null
			slot.tooltip_text = ""
			slot.visible = false
			if lbl != null:
				lbl.text = ""
				lbl.visible = false
			_slot_buff_ids[i] = ""
			_slot_stacks[i] = 0

	_is_refreshing = false


func get_active_slot_count() -> int:
	var count: int = 0
	for s in _slots:
		if s.visible:
			count += 1
	return count


func get_slot_buff_id(index: int) -> String:
	if index >= 0 and index < _slot_buff_ids.size():
		return _slot_buff_ids[index]
	return ""


func get_slot_stacks(index: int) -> int:
	if index >= 0 and index < _slot_stacks.size():
		return _slot_stacks[index]
	return 0


func get_slot_node(index: int) -> Control:
	_ensure_slots(index + 1)
	if index >= 0 and index < _slots.size():
		return _slots[index]
	return null
