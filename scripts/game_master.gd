extends Node2D
class_name GameMaster

signal enemy_attacking
signal player_health_change
signal enemy_health_change

@onready var grd: Node2D = $grd
@onready var enemy: Enemy = $enemy
@onready var player: Player = $player
@onready var defeat_overlay: PanelContainer = $defeat_overlay
@onready var pause_overlay: PanelContainer = $pause_overlay

var last_player_health: float
var last_enemy_health: float
var enemy_attacked_once: bool = false

func _ready() -> void:
	defeat_overlay.visible = false
	pause_overlay.visible = false
	load_player()
	load_enemie()
	grd.on_startup()
	last_enemy_health = EnemyData.cur_health
	last_player_health = Global.cur_char.cur_health
	grd.state = grd.move

func _process(_delta: float) -> void:
	EnemyData.cur_health = clamp(EnemyData.cur_health, 0, EnemyData.max_health)
	Global.cur_char.cur_health = clamp(Global.cur_char.cur_health, 0, Global.cur_char.max_health)
	
	if last_enemy_health != EnemyData.cur_health:
		emit_signal("enemy_health_change")
	last_enemy_health = EnemyData.cur_health
	
	if last_player_health != Global.cur_char.cur_health:
		emit_signal("player_health_change")
	last_player_health = Global.cur_char.cur_health
	
	if Global.cur_char.moves_left <= 0:
		grd.state = grd.wait
		if !enemy_attacked_once:
			enemy_attacked_once = true
			emit_signal("enemy_attacking")
	if EnemyData.cur_health <= 0:
		if Global.game_is_played:
			Global.game_is_played = false
			grd.state = grd.wait
			SceneManager.fade_in_place( {"pattern": "diagonal", "color": Color('#2e222f')} )
			await SceneManager.fade_complete
			grd.clean_deck_to_dest()
			grd.clear_board()
			if EnemyData.type == 1:
				Global.boss_beaten = true
			SceneManager.change_scene("res://reward_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })
	if Global.cur_char.cur_health <= 0:
		if Global.game_is_played:
			grd.state = grd.wait
			defeat_overlay.visible = true
			Global.game_is_played = false

func _on_enemy_enemy_attacked() -> void:
	await get_tree().create_timer(.1).timeout
	Global.cur_char.reset_stats_at_the_beging_of_turn()
	player._on_grd_move_made()
	enemy_attacked_once = false
	grd.state = grd.move

func load_player():
	Global.cur_char.reset_stats_at_beging_of_fight()
	var player_sprite = Global.cur_char.sprite.instantiate()
	get_node("player").get_child(0).add_child(player_sprite)
	
func load_enemie():
	EnemyData.pick_next_attack()
	grd.empty_spaces = EnemyData.empty_spaces
	grd.ice_spaces = EnemyData.ice_spaces
	grd.freeze_spaces = EnemyData.freeze_spaces
	var enemy_sprite = EnemyData.sprite.instantiate()
	enemy.enemy_healthbar.texture_progress = EnemyData.health_bar
	enemy.enemy_name.text = EnemyData.enemy.name
	enemy.attack.text = EnemyData.next_attack.tooltip
	get_node("enemy").get_child(0).add_child(enemy_sprite)

func _on_back_to_mm_pressed() -> void:
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_pause_btn_pressed() -> void:
	if Global.game_is_played == true:
		grd.state = grd.wait
		Global.game_is_played = false
		pause_overlay.visible = true

func _on_resume_pressed() -> void:
	grd.state = grd.move
	Global.game_is_played = true
	pause_overlay.visible = false
