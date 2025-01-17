extends Control

func _ready() -> void:
	Global.load_data()
	
	load_settings()
	
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })

func load_settings():
	AudioServer.set_bus_volume_db(0,linear_to_db(Global.setting_res.set_audio_audio_lvl))
	AudioServer.set_bus_mute(0,Global.setting_res.set_audio_audio_playing)
	AudioServer.set_bus_volume_db(1,linear_to_db(Global.setting_res.set_audio_music_lvl))
	AudioServer.set_bus_mute(1,Global.setting_res.set_audio_music_playing)
	AudioServer.set_bus_volume_db(2,linear_to_db(Global.setting_res.set_audio_sfx_lvl))
	AudioServer.set_bus_mute(2,Global.setting_res.set_audio_sfx_playing)
