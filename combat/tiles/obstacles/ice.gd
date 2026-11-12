extends Node2D

@export var health: int = 0
@export var gpu_particles_2d_3: GPUParticles2D


func take_damage(dmg: int) -> void:
	health -= dmg


func corupt(direction_vec: Vector2) -> void:
	if direction_vec.x == 1:
		rotate_particles(90.0)
	elif direction_vec.x == -1:
		rotate_particles(-90.0)
	elif direction_vec.y == 1:
		rotate_particles(0.0)
	elif direction_vec.y == -1:
		rotate_particles(180.0)


func rotate_particles(deg: float) -> void:
	gpu_particles_2d_3.visible = true
	gpu_particles_2d_3.rotation_degrees = deg
	await get_tree().create_timer(1.0).timeout
	gpu_particles_2d_3.visible = false

