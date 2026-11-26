extends AudioStreamPlayer

const HIT_HURT: AudioStream = preload("res://assets/audio/sfx/hit_hurt.wav")


func play_on_destruction(cascade_step: int = 0) -> void:
	stream = HIT_HURT
	volume_db = -6.0
	pitch_scale = 1.0 + float(cascade_step) * 0.1
	play()

