extends Node2D
class_name enemy_art

var anim_player: AnimationPlayer 

func _ready() -> void:
	anim_player = get_child(0)
	set_animp("idle")

func set_animp(animation: String):
	if anim_player != null:
		anim_player.current_animation = animation
	pass
