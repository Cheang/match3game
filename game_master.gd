extends Node2D
class_name GameMaster

signal enemy_attacking

@onready var grd: Node2D = $grd
@onready var enemy: Enemy = $enemy
@onready var player: Player = $player

func _ready() -> void:
	EnemyData.pick_next_attack()
	load_player()
	load_enemie()
	Global.moves_done = PlayerData.speed
	grd.on_startup()
	grd.state = grd.move

func _process(_delta: float) -> void:
	if Global.moves_done <= 0:
		grd.state = grd.wait
		emit_signal("enemy_attacking")
	if PlayerData.cur_health <= 0 or EnemyData.enemy_cur_health <= 0:
		if Global.game_is_played:
			grd.state = grd.wait
			Global.game_is_played = false
			SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
	enemy.update()
	player.update()

func _on_enemy_enemy_attacked() -> void:
	await get_tree().create_timer(.5).timeout
	PlayerData.armor = 0
	grd.state = grd.move

func load_player():
	var player_sprite = PlayerData.sprite.instantiate()
	get_node("player").get_child(0).add_child(player_sprite)

func load_enemie():
	grd.empty_spaces = EnemyData.empty_spaces
	grd.ice_spaces = EnemyData.ice_spaces
	grd.freeze_spaces = EnemyData.freeze_spaces
	var enemy_sprite = EnemyData.enemy_sprite.instantiate()
	get_node("enemy").get_child(0).add_child(enemy_sprite)
