class_name EnemyArt
extends Node2D

var anim_player: AnimationPlayer


func _ready() -> void:
	anim_player = get_child(0) as AnimationPlayer
	set_animp("idle")


func set_animp(animation: String) -> void:
	if anim_player != null and anim_player.current_animation != null:
		anim_player.current_animation = animation

