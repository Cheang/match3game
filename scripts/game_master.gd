extends Node2D
class_name GameMaster

signal enemy_attacking

@onready var grd: Node2D = $grd
@onready var enemy: Enemy = $enemy
@onready var player: Player = $player
@onready var trun_changer: Control = $CanvasLayer/trun_changer
@onready var defeat_overlay: PanelContainer = $CanvasLayer/defeat_overlay
@onready var pause: Control = $CanvasLayer/pause

var last_enemy_health: float
var enemy_attacked_once: bool = false

func _ready() -> void:
	Global.save()
	defeat_overlay.visible = false
	pause.set_title(Global.cur_enemy.name)
	grd.on_startup()
	last_enemy_health = Global.cur_enemy.cur_health
	Global.game_is_played = true
	grd.state = grd.move

func _process(_delta: float) -> void:
	if Global.cur_enemy.cur_health <= 0:
		enemy_died()


func _on_enemy_enemy_attacked() -> void:
	Global.cur_char.reset_stats_at_beging_of_turn()
	enemy_attacked_once = false
	trun_changer.change_turn(0)
	await get_tree().create_timer(.8).timeout
	grd.state = grd.move

func _on_back_to_mm_pressed() -> void:
	SceneManager.change_scene("res://main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_tree_entered() -> void:
	Global.cur_char.playerDied.connect(player_died)
	Global.cur_char.playerFinishedTurn.connect(player_finished_turn)
	Global.cur_enemy.enemyDied.connect(enemy_died)
	Global.cur_enemy.destroyPieces.connect(destroy_tile)
func _on_tree_exiting() -> void:
	Global.cur_char.playerDied.disconnect(player_died)
	Global.cur_char.playerFinishedTurn.disconnect(player_finished_turn)
	Global.cur_enemy.enemyDied.disconnect(enemy_died)
	Global.cur_enemy.destroyPieces.disconnect(destroy_tile)


#Helper_functions --------------------------------------------------------------
func player_finished_turn():
	grd.state = grd.wait
	if !enemy_attacked_once:
		enemy_attacked_once = true
		trun_changer.change_turn(1)
		await get_tree().create_timer(1.1).timeout
		enemy_attacking.emit()

func player_died():
	grd.state = grd.wait
	defeat_overlay.visible = true
	Global.game_is_played = false
	Global.game_is_over = true
	Global.save()

func enemy_died():
	if Global.game_is_played:
		Global.game_is_played = false
		grd.state = grd.wait
		SceneManager.fade_in_place( {"pattern": "diagonal", "color": Color('#2e222f')} )
		await SceneManager.fade_complete
		grd.clean_deck_to_dest()
		grd.clear_board()
		if Global.cur_enemy.type == 1:
			Global.boss_beaten = true
			Global.bosses_killed += 1
			if Global.bosses_killed >= Global.bosses_killed_needed:
				Global.game_is_over = true
				SceneManager.change_scene("res://thank_you_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })
				return
		SceneManager.change_scene("res://reward_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })

func destroy_tile(space_to_destroy: Array[Vector2]):
	grd.mark_for_destruction(space_to_destroy)
