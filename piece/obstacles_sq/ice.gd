extends Node2D

@export var health: int
@export var gpu_particles_2d_3: GPUParticles2D

func take_damage(dmg):
	health -= dmg

func corupt(directionV: Vector2):
	print(directionV)
	if directionV.x == 1:
		rotate_particles(90)
	elif directionV.x == -1:
		rotate_particles(-90)
	elif directionV.y == 1:
		rotate_particles(0)
	elif directionV.y == -1:
		rotate_particles(180)

func rotate_particles(deg: float):
	gpu_particles_2d_3.visible = true
	gpu_particles_2d_3.rotation_degrees = deg
	await get_tree().create_timer(1).timeout
	gpu_particles_2d_3.visible = false
