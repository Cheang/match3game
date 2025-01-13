extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var background: TextureRect = $background
@onready var foreground: TextureRect = $foreground
@onready var title: Label = $MarginContainer/VBoxContainer/title/MarginContainer/label
@onready var label: RichTextLabel = $MarginContainer/VBoxContainer/description/MarginContainer/label
@onready var npc: TextureRect = $npc

var cur_scene: CutScene
var cur_page: int = 0
var anim_runing: bool = false

func _ready() -> void:
	call_deferred("_initialize_scene")

func _initialize_scene():
	Global.game_is_played = true
	cur_scene = Global.cur_cutscene
	if cur_scene.npc.size() != cur_scene.description.size():
		cur_scene.npc.resize(cur_scene.description.size())
	if cur_scene.background:
		background.texture = cur_scene.background
	if cur_scene.foreground:
		foreground.texture = cur_scene.foreground
	if cur_scene.title != "None":
		title.text = cur_scene.title
	else: 
		title.visible = false
	npc.texture = cur_scene.npc[cur_page]
	label.text = cur_scene.description[cur_page]
	await get_tree().create_timer(.1).timeout
	anim_player.current_animation = "show_text"
	anim_runing = true

func _on_button_pressed() -> void:
	if Global.game_is_played:
		if anim_runing:
			anim_player.stop()
			anim_runing = false
			label.visible_ratio = 1
			return
		cur_page += 1
		if cur_page >= cur_scene.description.size():
			Global.cur_cutscene = null
			Global.game_is_played = false
			SceneManager.change_scene(cur_scene.next_location, { "pattern": "diagonal", "color": Color('#2e222f') })
			return
		label.visible_ratio = 0
		label.text = cur_scene.description[cur_page]
		npc.texture = cur_scene.npc[cur_page]
		await get_tree().create_timer(.1).timeout
		anim_player.current_animation = "show_text"
		anim_runing = true
	
func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	anim_runing = false
