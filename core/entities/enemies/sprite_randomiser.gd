extends Sprite2D

@export var textures: Array[Texture2D] = []


func _ready() -> void:
	if not textures.is_empty():
		texture = textures.pick_random()

