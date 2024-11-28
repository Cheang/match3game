extends Resource
class_name EnemyResource

@export var health: float
@export var damage: float
@export var attacks: Array[EnemyAttackBase]
@export var speed: int
@export_enum("minion", "boss") var type: int
@export var sprite: PackedScene

@export var empty_spaces: Array[Vector2]
@export var ice_spaces: Array[Vector2]
@export var freeze_spaces: Array[Vector2]
