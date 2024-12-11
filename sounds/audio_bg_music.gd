extends AudioStreamPlayer
class_name audioBGMusic

func _on_finished() -> void:
	if Global.intro_played == true:
		if !Global.cur_song.accents.is_empty():
			var rand = randi_range(0,100)
			if rand < 10:
				self.stream = Global.cur_song.accents.pick_random()
			else:
				self.stream = Global.cur_song.main_loop
		self.play()
