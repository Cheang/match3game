extends Button

@onready var sound: AudioStreamPlayer = $sound
var btn_pressed:bool = false

func _on_pressed() -> void:
	if not btn_pressed: 
		btn_pressed = true
		sound.play()
		self.disabled = true
		await get_tree().create_timer(.8).timeout
		reset()

func reset():
	btn_pressed = false
	self.disabled = false
