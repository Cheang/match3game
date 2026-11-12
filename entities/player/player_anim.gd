class_name PlayerArt
extends Node2D

var anim_player: AnimationPlayer


func _ready() -> void:
	anim_player = get_child(0) as AnimationPlayer
	set_animp("idle")


func set_animp(animation: String) -> void:
	if anim_player != null:
		anim_player.current_animation = animation

