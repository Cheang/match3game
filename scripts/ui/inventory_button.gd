extends TextureButton
class_name InventoryButton

## Dedicated Inventory Button component for player HUD / combat UI.
## When pressed, toggles the standalone InventoryOverlay.

@onready var icon: TextureRect = get_node_or_null("Icon")

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	InventoryOverlay.toggle_overlay()
