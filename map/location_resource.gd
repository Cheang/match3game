class_name Location
extends Resource

@export_category("Location")
@export var name: String = ""
@export_multiline var description: String = ""
@export var pic: Texture2D
@export var next_scene: String = "res://ui/screens/main_menu.tscn"
@export var transition_color: Color = Color("#2e222f")

@export_category("Enemy")
@export var enemy_encounter: bool = false
@export var cut_scene: CutScene
@export var which_enemy: Array[EnemyResource] = []
@export var level: int = 0

@export_category("Event")
@export var event_encounter: bool = false
@export var event_resource: Event

