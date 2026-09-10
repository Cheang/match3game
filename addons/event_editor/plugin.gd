@tool
extends EditorPlugin

const EventEditorScene = preload("res://addons/event_editor/event_editor.tscn")
var event_editor_instance: Control

func _enter_tree() -> void:
	event_editor_instance = EventEditorScene.instantiate()
	EditorInterface.get_editor_main_screen().add_child(event_editor_instance)
	event_editor_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_editor_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_editor_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)

func _exit_tree() -> void:
	if event_editor_instance:
		event_editor_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if event_editor_instance:
		event_editor_instance.visible = visible

func _get_plugin_name() -> String:
	return "Events"

func _get_plugin_icon() -> Texture2D:
	if is_instance_valid(EditorInterface.get_base_control()):
		return EditorInterface.get_base_control().get_theme_icon("RichTextLabel", "EditorIcons")
	return null
