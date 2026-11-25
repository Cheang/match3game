class_name EnemyArt
extends Node2D

var anim_player: AnimationPlayer


func _ready() -> void:
	anim_player = get_child(0) as AnimationPlayer
	set_animp("idle")


func has_animp(animation: String) -> bool:
	return anim_player != null and animation != "" and anim_player.has_animation(animation)


func get_animp_length(animation: String) -> float:
	if not has_animp(animation):
		return 0.0
	var anim: Animation = anim_player.get_animation(animation)
	return anim.length if anim != null else 0.0


func set_animp(animation: String) -> void:
	if not has_animp(animation):
		return
	anim_player.stop()
	anim_player.play(animation)
	if animation == "RESET":
		anim_player.advance(0.0)
