extends Control

const MainMenuScript := preload("res://scenes/main_menu/main_menu.gd")

@onready var settings_panel: Control = find_child("SettingsPanel", true, false) as Control
@onready var back_btn: Button = find_child("BackBtn", true, false) as Button
@onready var cloth_drop_anchor: Control = find_child("ClothDropAnchor", true, false) as Control
@onready var banner_viewport_container: SubViewportContainer = find_child("BannerViewportContainer", true, false) as SubViewportContainer
@onready var banner_viewport: SubViewport = find_child("BannerViewport", true, false) as SubViewport

var _is_leaving: bool = false

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

	if banner_viewport_container != null:
		if not banner_viewport_container.resized.is_connected(_sync_banner_shader_height):
			banner_viewport_container.resized.connect(_sync_banner_shader_height)
		_sync_banner_shader_height()
	if cloth_drop_anchor != null:
		var drop_h: float = maxf(get_viewport_rect().size.y, 1024.0)
		_set_cloth_slide_y(-drop_h)
		var tw := create_tween()
		tw.tween_method(_set_cloth_slide_y, -drop_h, 0.0, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _set_cloth_slide_y(y: float) -> void:
	if cloth_drop_anchor == null:
		return
	cloth_drop_anchor.offset_top = y
	cloth_drop_anchor.offset_bottom = y


func _sync_banner_shader_height() -> void:
	if banner_viewport_container == null:
		return
	var mat := banner_viewport_container.material as ShaderMaterial
	if mat == null:
		return
	var h: float = float(banner_viewport.size.y) if banner_viewport != null and banner_viewport.size.y > 0 else banner_viewport_container.size.y
	if h > 0.0:
		mat.set_shader_parameter("banner_height", h)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	MainMenuScript.returning_from_settings = true
	if cloth_drop_anchor != null and is_inside_tree():
		var retract_h: float = maxf(get_viewport_rect().size.y, 1024.0)
		var tw := create_tween()
		tw.tween_method(_set_cloth_slide_y, cloth_drop_anchor.offset_top, -retract_h, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	SceneManager.change_scene("res://scenes/main_menu/main_menu.tscn", {
		"skip_fade_out": true,
		"skip_fade_in": true,
		"wait_time": 0.0,
	})
