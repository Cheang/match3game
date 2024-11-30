extends Sprite2D

@export var textures: Array[Texture2D]

func _ready() -> void:
	self.texture = textures.pick_random()
