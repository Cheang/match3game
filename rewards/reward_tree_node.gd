@tool
extends Resource
class_name RewardTreeNode

@export var id: String = ""
@export var title: String = "Progression Node"
@export var graph_pos: Vector2 = Vector2(100, 100)
@export var required_tags: Array[String] = []
@export var unlocked_rewards: Array[Reward] = []
@export var removed_rewards: Array[Reward] = []
@export var incoming_connections: Array[String] = []
