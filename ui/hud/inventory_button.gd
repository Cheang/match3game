class_name InventoryButton
extends TextureButton

## Dedicated Inventory Button component for player HUD / combat UI.
## When pressed, toggles the standalone InventoryOverlay and darkens for tactile feedback.

const NORMAL_MODULATE := Color.WHITE
const HOVER_MODULATE := Color(1.06, 1.06, 1.08, 1.0)
const PRESSED_MODULATE := Color(0.66, 0.66, 0.70, 1.0)
const PRESSED_ICON_OFFSET_Y: float = 2.0

@onready var icon: TextureRect = get_node_or_null("Icon")

var _icon_base_pos: Vector2 = Vector2.ZERO
var _is_held_down: bool = false


func _ready() -> void:
	if icon != null:
		_icon_base_pos = icon.position
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)
	_apply_visual_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_is_held_down = false
		_apply_visual_state()


func _on_button_down() -> void:
	_is_held_down = true
	_apply_visual_state()


func _on_button_up() -> void:
	_is_held_down = false
	_apply_visual_state()


func _on_mouse_entered() -> void:
	_apply_visual_state()


func _on_mouse_exited() -> void:
	_apply_visual_state()


func _on_focus_exited() -> void:
	if _is_held_down:
		_is_held_down = false
		_apply_visual_state()


func _apply_visual_state() -> void:
	if _is_held_down or button_pressed:
		modulate = PRESSED_MODULATE
		if icon != null:
			icon.position = _icon_base_pos + Vector2(0.0, PRESSED_ICON_OFFSET_Y)
	else:
		modulate = HOVER_MODULATE if is_hovered() else NORMAL_MODULATE
		if icon != null:
			icon.position = _icon_base_pos


func _on_pressed() -> void:
	InventoryOverlay.toggle_overlay()
