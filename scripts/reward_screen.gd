extends Node2D

@onready var pratic1: GPUParticles2D = $GPUParticles2D
@onready var pratic2: GPUParticles2D = $GPUParticles2D2
@onready var pratic3: GPUParticles2D = $GPUParticles2D3
@onready var pratic4: GPUParticles2D = $GPUParticles2D4

func _ready() -> void:
	pratic1.visible = true
	pratic2.visible = true
	pratic3.visible = true
	pratic4.visible = true
	
