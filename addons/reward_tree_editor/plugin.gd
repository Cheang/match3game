@tool
extends EditorPlugin

const RewardTreeEditorScene = preload("res://addons/reward_tree_editor/reward_tree_editor.tscn")
var editor_instance: Control

func _enter_tree() -> void:
	editor_instance = RewardTreeEditorScene.instantiate()
	EditorInterface.get_editor_main_screen().add_child(editor_instance)
	editor_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)

func _exit_tree() -> void:
	if editor_instance:
		editor_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if editor_instance:
		editor_instance.visible = visible

func _get_plugin_name() -> String:
	return "Reward Trees"

func _get_plugin_icon() -> Texture2D:
	if is_instance_valid(EditorInterface.get_base_control()):
		return EditorInterface.get_base_control().get_theme_icon("CurveCreate", "EditorIcons")
	return null
