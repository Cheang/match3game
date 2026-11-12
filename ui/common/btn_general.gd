extends Button

var btn_pressed: bool = false

@onready var sound: AudioStreamPlayer = $sound


func reset() -> void:
	btn_pressed = false
	disabled = false


func _on_pressed() -> void:
	if not btn_pressed:
		btn_pressed = true
		sound.play()
		disabled = true
		await get_tree().create_timer(0.8).timeout
		reset()

