extends AudioStreamPlayer

const HIT_HURT = preload("res://sounds/hitHurt.wav")

func play_on_destruction():
	self.stream = HIT_HURT
	self.play()
