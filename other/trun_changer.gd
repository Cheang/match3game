extends Control
class_name TurnChanger

enum TurnType { PLAYER = 0, ENEMY = 1 }

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var panel_container: PanelContainer = $PanelContainer

@onready var your_turn: Label = $PanelContainer/CenterContainer/your_turn
@onready var enemy_turn: Label = $PanelContainer/CenterContainer/enemy_turn

func _ready() -> void:
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(_anim_name: StringName) -> void:
	if panel_container != null:
		panel_container.visible = false

func change_turn(type: int) -> void:
	if panel_container == null or animation_player == null:
		return
	panel_container.visible = true
	your_turn.visible = (type == TurnType.PLAYER)
	enemy_turn.visible = (type == TurnType.ENEMY)
	animation_player.stop()
	animation_player.play("fade_in")
