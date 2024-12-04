extends Resource
class_name EnemyResource

@export var name: String
@export var health: float
@export var damage: float
@export var attacks: Array[EnemyAttackBase]
@export_group("attacks")
@export var attacks_p2: Array[EnemyAttackBase]
@export var attacks_p3: Array[EnemyAttackBase]
@export var attacks_p4: Array[EnemyAttackBase]
@export_group("")
@export var speed: int
@export_enum("minion", "boss") var type: int
@export var has_phases: bool
@export var sprite: PackedScene
@export var health_bar: Texture2D

@export var empty_spaces: Array[Vector2]
@export var ice_spaces: Array[Vector2]
@export var freeze_spaces: Array[Vector2]
