extends Control

@onready var settings_panel: Control = find_child("SettingsPanel", true, false) as Control
@onready var back_btn: Button = find_child("BackBtn", true, false) as Button

var master_slider: HSlider:
	get: return settings_panel.master_slider if settings_panel != null else null
var music_slider: HSlider:
	get: return settings_panel.music_slider if settings_panel != null else null
var sfx_slider: HSlider:
	get: return settings_panel.sfx_slider if settings_panel != null else null
var master_mute: CheckBox:
	get: return settings_panel.master_mute if settings_panel != null else null
var music_mute: CheckBox:
	get: return settings_panel.music_mute if settings_panel != null else null
var sfx_mute: CheckBox:
	get: return settings_panel.sfx_mute if settings_panel != null else null


func _ready() -> void:
	if settings_panel == null:
		settings_panel = find_child("SettingsPanel", true, false) as Control
	if back_btn == null:
		back_btn = find_child("BackBtn", true, false) as Button
	if back_btn != null and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	await get_tree().create_timer(0.1).timeout
	SceneManager.change_scene("res://ui/screens/main_menu.tscn", { "pattern": "diagonal", "color": Color("#484a77") })
