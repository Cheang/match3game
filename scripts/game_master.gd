extends Node2D
class_name GameMaster

signal enemy_attacking
signal enemy_health_change

@onready var grd: Node2D = $grd
@onready var enemy: Enemy = $enemy
@onready var player: Player = $player
@onready var trun_changer: Control = $CanvasLayer/trun_changer
@onready var defeat_overlay: PanelContainer = $CanvasLayer/defeat_overlay
@onready var pause: Control = $CanvasLayer/pause

var last_enemy_health: float
var enemy_attacked_once: bool = false

func _ready() -> void:
	defeat_overlay.visible = false
	load_enemie()
	grd.on_startup()
	last_enemy_health = EnemyData.cur_health
	Global.game_is_played = true
	grd.state = grd.move

func _process(_delta: float) -> void:
	EnemyData.cur_health = clamp(EnemyData.cur_health, 0, EnemyData.max_health)
	
	if last_enemy_health != EnemyData.cur_health:
		enemy_health_change.emit()
	last_enemy_health = EnemyData.cur_health
	
	if Global.cur_char.moves_left <= 0:
		grd.state = grd.wait
		if !enemy_attacked_once:
			enemy_attacked_once = true
			trun_changer.change_turn(1)
			await get_tree().create_timer(1.1).timeout
			enemy_attacking.emit()
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
				Global.bosses_killed += 1
				if Global.bosses_killed >= Global.bosses_killed_needed:
					SceneManager.change_scene("res://thank_you_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })
					return
			SceneManager.change_scene("res://reward_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })
	if Global.cur_char.cur_health <= 0:
		if Global.game_is_played:
			grd.state = grd.wait
			defeat_overlay.visible = true
			Global.game_is_played = false

func _on_enemy_enemy_attacked() -> void:
	await get_tree().create_timer(.5).timeout
	Global.cur_char.reset_stats_at_the_beging_of_turn()

	enemy_attacked_once = false
	trun_changer.change_turn(0)
	await get_tree().create_timer(.8).timeout
	grd.state = grd.move

func load_enemie():
	EnemyData.pick_next_attack()
	grd.empty_spaces = EnemyData.empty_spaces
	grd.ice_spaces = EnemyData.ice_spaces
	grd.freeze_spaces = EnemyData.freeze_spaces
	grd.rock_spaces = EnemyData.rock_spaces
	grd.flesh_spaces = EnemyData.flesh_spaces
	var enemy_sprite = EnemyData.sprite.instantiate()
	enemy.enemy_healthbar.texture_progress = EnemyData.health_bar
	pause.set_title(EnemyData.enemy.name)
	enemy.attack.text = EnemyData.next_attack.tooltip
	get_node("enemy").get_child(0).add_child(enemy_sprite)

func _on_back_to_mm_pressed() -> void:
	await get_tree().create_timer(.4).timeout
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })
