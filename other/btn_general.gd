extends Button

@onready var sound: AudioStreamPlayer = $sound
@onready var fire: GPUParticles2D = $GPUParticles2D
var btn_pressed:bool = false

func _on_pressed() -> void:
	if not btn_pressed: 
		btn_pressed = true
		sound.play()
		fire.process_material.emission_box_extents.x = self.size.x/2
		fire.position = Vector2(self.size.x/2, self.size.y)
		fire.visible = true
		move(Vector2(fire.position.x, 0))
		await get_tree().create_timer(.2).timeout
		self.disabled = true
		await get_tree().create_timer(1).timeout
		reset()

func move(target, time = 0.8):
	var tween: Tween = create_tween()
	tween.tween_property(fire,"position",target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func reset():
	btn_pressed = false
	fire.visible = false
	self.disabled = false
