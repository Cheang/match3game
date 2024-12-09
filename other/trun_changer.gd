extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var panel_container: PanelContainer = $PanelContainer

@onready var your_turn: Label = $PanelContainer/CenterContainer/your_turn
@onready var enemy_turn: Label = $PanelContainer/CenterContainer/enemy_turn

func change_turn(type: int):
	if type == 0:
		panel_container.visible = true
		your_turn.visible = true
		enemy_turn.visible = false
		animation_player.current_animation = "fade_in"
		await animation_player.animation_finished
		panel_container.visible = false
		
	elif type == 1:
		panel_container.visible = true
		your_turn.visible = false
		enemy_turn.visible = true
		animation_player.current_animation = "fade_in"
		await animation_player.animation_finished
		panel_container.visible = false
