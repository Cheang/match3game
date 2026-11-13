class_name InventoryOverlayPassivesRing
extends Control

## Component for the full Inventory / Loadout Overlay screen.
## Renders the 5-slot pentagonal ring for passives using:
##  1. passive-deco-ring.png (background decorative ring)
##  2. passive-slots.png (5 empty socket frames)
##  3. 5 interactive OverlayPassiveSlotUI controls with palette shader,
##     equipped icons, selection highlights, and drag-and-drop support.

signal passive_clicked(slot_idx: int, passive_res: Resource)
signal passive_dropped(source_idx: int, target_idx: int)

const TEX_DECO_RING = preload("res://assets/sprites/ui/inventory_overlay/passive_deco_ring.png")
const TEX_SLOTS_BG = preload("res://assets/sprites/ui/inventory_overlay/passive_slots.png")

const RING_POS = Vector2(18, 27)
const RING_SIZE = Vector2(306, 306)
const SLOTS_SIZE = Vector2(342, 313)
const CONTROL_SIZE = Vector2(342, 333)

# Exact pixel offsets for the 5 octagon sockets:
# 0: Top, 1: Mid-Right, 2: Bottom-Right, 3: Bottom-Left, 4: Mid-Left
const SLOT_POSITIONS: Array[Vector2] = [
	Vector2(139.0, 0.0),
	Vector2(278.0, 99.0),
	Vector2(248.0, 248.0),
	Vector2(29.0, 248.0),
	Vector2(0.0, 99.0)
]

var deco_ring_rect: TextureRect
var sockets_bg_rect: TextureRect
var slots: Array[OverlayPassiveSlotUI] = []
var selected_slot_index: int = -1

func _ready() -> void:
	custom_minimum_size = CONTROL_SIZE
	size = CONTROL_SIZE
	_ensure_structure()

func _ensure_structure() -> void:
	# 1. Decorative Ring Texture (behind slots)
	if deco_ring_rect == null:
		deco_ring_rect = get_node_or_null("DecoRing") as TextureRect
		if deco_ring_rect == null:
			deco_ring_rect = TextureRect.new()
			deco_ring_rect.name = "DecoRing"
			deco_ring_rect.texture = TEX_DECO_RING
			deco_ring_rect.position = RING_POS
			deco_ring_rect.size = RING_SIZE
			deco_ring_rect.custom_minimum_size = RING_SIZE
			deco_ring_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(deco_ring_rect)

	# 2. Sockets Background Texture (5 dark empty sockets)
	if sockets_bg_rect == null:
		sockets_bg_rect = get_node_or_null("SocketsBg") as TextureRect
		if sockets_bg_rect == null:
			sockets_bg_rect = TextureRect.new()
			sockets_bg_rect.name = "SocketsBg"
			sockets_bg_rect.texture = TEX_SLOTS_BG
			sockets_bg_rect.position = Vector2.ZERO
			sockets_bg_rect.size = SLOTS_SIZE
			sockets_bg_rect.custom_minimum_size = SLOTS_SIZE
			sockets_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(sockets_bg_rect)

	# 3. 5 Interactive Slot Controls
	if slots.is_empty():
		for i in range(5):
			var s_name := "Slot_%d" % i
			var slot_ctrl := get_node_or_null(s_name) as OverlayPassiveSlotUI
			if slot_ctrl == null:
				slot_ctrl = OverlayPassiveSlotUI.new()
				slot_ctrl.name = s_name
				slot_ctrl.slot_index = i
				slot_ctrl.position = SLOT_POSITIONS[i]
				slot_ctrl.size = Vector2(64, 64)
				slot_ctrl.custom_minimum_size = Vector2(64, 64)
				add_child(slot_ctrl)

			if not slot_ctrl.slot_clicked.is_connected(_on_slot_clicked):
				slot_ctrl.slot_clicked.connect(_on_slot_clicked)
			if not slot_ctrl.passive_dropped.is_connected(_on_passive_dropped):
				slot_ctrl.passive_dropped.connect(_on_passive_dropped)

			slots.append(slot_ctrl)

## Refreshes all 5 passive slots from an equipped passives array.
func setup_passives(passives: Array) -> void:
	_ensure_structure()
	for i in range(5):
		var slot_ctrl: OverlayPassiveSlotUI = slots[i]
		var p_res: Resource = passives[i] if (i < passives.size() and passives[i] != null) else null
		var color_id: int = _determine_passive_color(p_res)
		slot_ctrl.set_passive(p_res, color_id)
		slot_ctrl.set_selected(i == selected_slot_index)

## Updates selection highlight on the passives ring.
## Pass -1 to deselect all passive slots.
func update_selection(selected_idx: int) -> void:
	_ensure_structure()
	selected_slot_index = selected_idx
	for i in range(slots.size()):
		slots[i].set_selected(i == selected_idx)

## Returns the passive resource at the given slot index (or null).
func get_slot_passive(slot_idx: int) -> Resource:
	if slot_idx >= 0 and slot_idx < slots.size():
		return slots[slot_idx].passive_ref
	return null

func _on_slot_clicked(slot_idx: int, passive_ref: Resource) -> void:
	update_selection(slot_idx)
	passive_clicked.emit(slot_idx, passive_ref)

func _on_passive_dropped(src_idx: int, target_idx: int) -> void:
	passive_dropped.emit(src_idx, target_idx)

## Maps passive properties to a thematic track color palette.
func _determine_passive_color(p_res: Resource) -> int:
	if p_res == null:
		return 500

	if p_res is Equipment:
		var eq := p_res as Equipment
		match eq.family:
			"sword": return 100
			"shields": return 200
			"mobility", "healing", "beast": return 300
			"fists": return 100
		return 500

	if p_res is Reward:
		var rew := p_res as Reward
		if rew.might > 0.0:
			return 100 # Red
		elif rew.grit > 0.0:
			return 200 # Blue
		elif rew.agility > 0 or rew.heal_hp > 0.0:
			return 300 # Green
		elif rew.spirit > 0.0:
			return 400 # Purple
		return 500 # Silver / White

	return 500
