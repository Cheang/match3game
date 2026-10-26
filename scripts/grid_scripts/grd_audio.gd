extends AudioStreamPlayer

const HIT_HURT = preload("res://sounds/hitHurt.wav")

func play_on_destruction(cascade_step: int = 0):
	self.stream = HIT_HURT
	self.volume_db = -6.0
	self.pitch_scale = 1.0 + float(cascade_step) * 0.1
	self.play()
