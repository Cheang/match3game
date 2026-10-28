extends Control
@onready var master_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/PanelContainer/VBoxContainer2/VBoxContainer/audio_master/HBoxContainer/MasterSlider
@onready var music_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/PanelContainer/VBoxContainer2/VBoxContainer/audio_music/HBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/PanelContainer/VBoxContainer2/VBoxContainer/audio_sfx/HBoxContainer/SFXSlider
@onready var master_mute: CheckBox = $MarginContainer/ScrollContainer/VBoxContainer/PanelContainer/VBoxContainer2/VBoxContainer/audio_master/HBoxContainer/MasterMute
@onready var music_mute: CheckBox = $MarginContainer/ScrollContainer/VBoxContainer/PanelContainer/VBoxContainer2/VBoxContainer/audio_music/HBoxContainer/MusicMute
@onready var sfx_mute: CheckBox = $MarginContainer/ScrollContainer/VBoxContainer/PanelContainer/VBoxContainer2/VBoxContainer/audio_sfx/HBoxContainer/SFXMute




func _ready() -> void:
	master_slider.value = Global.setting_res.set_audio_audio_lvl
	music_slider.value = Global.setting_res.set_audio_music_lvl
	sfx_slider.value = Global.setting_res.set_audio_sfx_lvl
	master_mute.button_pressed = Global.setting_res.set_audio_audio_playing
	music_mute.button_pressed = Global.setting_res.set_audio_music_playing
	sfx_mute.button_pressed = Global.setting_res.set_audio_sfx_playing


func _on_master_slider_value_changed(value: float) -> void:
	Global.setting_res.set_audio_audio_lvl = value
	var idx = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_music_slider_value_changed(value: float) -> void:
	Global.setting_res.set_audio_music_lvl = value
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	Global.setting_res.set_audio_sfx_lvl = value
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


func _on_master_slider_mouse_exited() -> void:
	release_focus()

func _on_music_slider_mouse_exited() -> void:
	release_focus()

func _on_sfx_slider_mouse_exited() -> void:
	release_focus()


func _on_master_mute_toggled(toggled_on: bool) -> void:
	Global.setting_res.set_audio_audio_playing = toggled_on
	var idx = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, toggled_on)


func _on_music_mute_toggled(toggled_on: bool) -> void:
	Global.setting_res.set_audio_music_playing = toggled_on
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, toggled_on)

func _on_sfx_mute_toggled(toggled_on: bool) -> void:
	Global.setting_res.set_audio_sfx_playing = toggled_on
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, toggled_on)

func _on_back_pressed() -> void:
	await get_tree().create_timer(.1).timeout
	SceneManager.change_scene("res://scenes/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })
