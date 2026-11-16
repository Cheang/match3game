@tool
class_name SettingsPanel
extends VBoxContainer

## Reusable settings panel component shared between the Main Menu Settings screen
## and the in-run InventoryOverlay Settings tab.
## Automatically saves settings to Global.setting_res whenever any setting changes.

var master_slider: HSlider = null
var music_slider: HSlider = null
var sfx_slider: HSlider = null
var master_mute: CheckBox = null
var music_mute: CheckBox = null
var sfx_mute: CheckBox = null

var almanac_btn: Button = null
var sound_btn: Button = null
var graphics_btn: Button = null

var _is_syncing: bool = false

func _ready() -> void:
	_resolve_nodes()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if Engine.is_editor_hint():
		return
	_connect_signals()
	sync_from_settings()

func _resolve_nodes() -> void:
	master_slider = find_child("MasterSlider", true, false) as HSlider
	music_slider = find_child("MusicSlider", true, false) as HSlider
	sfx_slider = find_child("SFXSlider", true, false) as HSlider
	master_mute = find_child("MasterMute", true, false) as CheckBox
	music_mute = find_child("MusicMute", true, false) as CheckBox
	sfx_mute = find_child("SFXMute", true, false) as CheckBox

	almanac_btn = find_child("AlmanacBtn", true, false) as Button
	sound_btn = find_child("SoundBtn", true, false) as Button
	graphics_btn = find_child("GraphicsBtn", true, false) as Button

func _connect_signals() -> void:
	if master_slider != null:
		if not master_slider.value_changed.is_connected(_on_master_slider_value_changed):
			master_slider.value_changed.connect(_on_master_slider_value_changed)
		if not master_slider.mouse_exited.is_connected(_on_slider_mouse_exited.bind(master_slider)):
			master_slider.mouse_exited.connect(_on_slider_mouse_exited.bind(master_slider))
	if music_slider != null:
		if not music_slider.value_changed.is_connected(_on_music_slider_value_changed):
			music_slider.value_changed.connect(_on_music_slider_value_changed)
		if not music_slider.mouse_exited.is_connected(_on_slider_mouse_exited.bind(music_slider)):
			music_slider.mouse_exited.connect(_on_slider_mouse_exited.bind(music_slider))
	if sfx_slider != null:
		if not sfx_slider.value_changed.is_connected(_on_sfx_slider_value_changed):
			sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
		if not sfx_slider.mouse_exited.is_connected(_on_slider_mouse_exited.bind(sfx_slider)):
			sfx_slider.mouse_exited.connect(_on_slider_mouse_exited.bind(sfx_slider))

	if master_mute != null and not master_mute.toggled.is_connected(_on_master_mute_toggled):
		master_mute.toggled.connect(_on_master_mute_toggled)
	if music_mute != null and not music_mute.toggled.is_connected(_on_music_mute_toggled):
		music_mute.toggled.connect(_on_music_mute_toggled)
	if sfx_mute != null and not sfx_mute.toggled.is_connected(_on_sfx_mute_toggled):
		sfx_mute.toggled.connect(_on_sfx_mute_toggled)

func _on_visibility_changed() -> void:
	if not Engine.is_editor_hint() and is_visible_in_tree():
		sync_from_settings()

func sync_from_settings() -> void:
	if Engine.is_editor_hint() or Global.setting_res == null:
		return
	_resolve_nodes()
	_is_syncing = true
	if master_slider != null:
		master_slider.value = Global.setting_res.set_audio_audio_lvl
	if music_slider != null:
		music_slider.value = Global.setting_res.set_audio_music_lvl
	if sfx_slider != null:
		sfx_slider.value = Global.setting_res.set_audio_sfx_lvl
	if master_mute != null:
		master_mute.button_pressed = Global.setting_res.set_audio_audio_playing
	if music_mute != null:
		music_mute.button_pressed = Global.setting_res.set_audio_music_playing
	if sfx_mute != null:
		sfx_mute.button_pressed = Global.setting_res.set_audio_sfx_playing
	_is_syncing = false

func _set_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))

func _set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

func _on_slider_mouse_exited(slider: HSlider) -> void:
	if slider != null:
		slider.release_focus()

func _on_master_slider_value_changed(value: float) -> void:
	if Engine.is_editor_hint() or Global.setting_res == null or _is_syncing:
		return
	Global.setting_res.set_audio_audio_lvl = value
	_set_bus_volume("Master", value)
	Global.save()

func _on_music_slider_value_changed(value: float) -> void:
	if Engine.is_editor_hint() or Global.setting_res == null or _is_syncing:
		return
	Global.setting_res.set_audio_music_lvl = value
	_set_bus_volume("Music", value)
	Global.save()

func _on_sfx_slider_value_changed(value: float) -> void:
	if Engine.is_editor_hint() or Global.setting_res == null or _is_syncing:
		return
	Global.setting_res.set_audio_sfx_lvl = value
	_set_bus_volume("SFX", value)
	Global.save()

func _on_master_mute_toggled(toggled_on: bool) -> void:
	if Engine.is_editor_hint() or Global.setting_res == null or _is_syncing:
		return
	Global.setting_res.set_audio_audio_playing = toggled_on
	_set_bus_mute("Master", toggled_on)
	Global.save()

func _on_music_mute_toggled(toggled_on: bool) -> void:
	if Engine.is_editor_hint() or Global.setting_res == null or _is_syncing:
		return
	Global.setting_res.set_audio_music_playing = toggled_on
	_set_bus_mute("Music", toggled_on)
	Global.save()

func _on_sfx_mute_toggled(toggled_on: bool) -> void:
	if Engine.is_editor_hint() or Global.setting_res == null or _is_syncing:
		return
	Global.setting_res.set_audio_sfx_playing = toggled_on
	_set_bus_mute("SFX", toggled_on)
	Global.save()
