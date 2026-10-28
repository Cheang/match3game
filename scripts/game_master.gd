extends Node2D
class_name GameMaster

signal enemy_attacking

@onready var grd: Node2D = $grd
@onready var enemy: Enemy = $enemy
@onready var player: Player = $player
@onready var loadout_dock: LoadoutDock = get_node_or_null("loadout_dock")
@onready var trun_changer: Control = $CanvasLayer/trun_changer
@onready var defeat_overlay: PanelContainer = $CanvasLayer/defeat_overlay
@onready var pause: Control = $CanvasLayer/pause

var last_enemy_health: float
var enemy_attacked_once: bool = false
var execution_queue: Array[MatchContext] = []
var is_executing_matches: bool = false

func _ready() -> void:
	Global.save()
	defeat_overlay.visible = false
	if Global.cur_enemy != null:
		pause.set_title(Global.cur_enemy.name)
		last_enemy_health = Global.cur_enemy.cur_health
	else:
		pause.set_title("Battle")

	if grd != null:
		if grd.has_signal("match_resolved") and not grd.match_resolved.is_connected(_on_grd_match_resolved):
			grd.match_resolved.connect(_on_grd_match_resolved)
		if grd.has_signal("drag_preview_updated") and loadout_dock != null and not grd.drag_preview_updated.is_connected(loadout_dock.preview_matches):
			grd.drag_preview_updated.connect(loadout_dock.preview_matches)
		if grd.has_signal("drag_preview_cleared") and loadout_dock != null and not grd.drag_preview_cleared.is_connected(loadout_dock.clear_preview):
			grd.drag_preview_cleared.connect(loadout_dock.clear_preview)
		grd.on_startup()
		grd.state = grd.move

	if loadout_dock != null:
		loadout_dock.refresh_dock()

	Global.game_is_played = true

func _on_grd_match_resolved(ctx: MatchContext) -> void:
	if ctx == null:
		return
	execution_queue.append(ctx)
	if not is_executing_matches:
		_process_execution_queue()

func _process_execution_queue() -> void:
	if is_executing_matches:
		return
	is_executing_matches = true

	while not execution_queue.is_empty():
		var ctx: MatchContext = execution_queue.pop_front()
		if Global.cur_char == null or Global.cur_enemy == null or not Global.game_is_played:
			break
		await _execute_match_context(ctx)

	is_executing_matches = false
	if loadout_dock != null:
		loadout_dock.refresh_dock()

func _execute_match_context(ctx: MatchContext) -> void:
	if Global.cur_char == null or Global.cur_enemy == null:
		return

	# 1. Exotic Blend & Corrupted Tile Pre-Processing (Section 4.3 & 5.2)
	if ctx.is_exotic_blend or ctx.exotic_count > 0:
		if ctx.base_color == Global.TileColor.RED or ctx.primary_color == Global.TileColor.DARK_CRIMSON:
			if ctx.hazards_cleared.has("flesh"):
				Global.cur_char.modify_stat("cur_health", 2.0)
			else:
				if Global.cur_char.cur_health > 1.0:
					Global.cur_char.modify_stat("cur_health", -1.0)
			ctx.potency_multiplier *= 1.5
			ctx.lifesteal_bonus += 0.25
		else:
			ctx.potency_multiplier *= 1.25

	if ctx.base_color == Global.TileColor.PURPLE and ctx.hazards_cleared.has("flesh"):
		Global.cur_char.modify_stat("cur_health", 2.0)

	if ctx.hazards_cleared.has("freeze") and Global.cur_enemy != null:
		var shatter_dmg: float = max(2.0, 2.0 + Global.cur_char.might)
		Global.cur_enemy.take_dmg(shatter_dmg, 1)

	# 2. Fetch ColorLoadoutTrack and iterate left-to-right (Slot 1 -> Slot 2 -> Slot 3)
	var track: ColorLoadoutTrack = Global.cur_char.get_track_for_color(ctx.base_color)
	var fists_triggered: bool = false
	var any_modifier_fired: bool = false

	if track != null:
		for mod in track.equipped_modifiers:
			if mod == null:
				continue
			if mod.can_trigger(ctx):
				any_modifier_fired = true
				if mod.family == "fists":
					fists_triggered = true
				mod.criting = ctx.has_crit
				mod.activate({
					"attacker": Global.cur_char,
					"target": Global.cur_enemy,
					"ctx": ctx
				})
				mod.on_triggered()
				if loadout_dock != null:
					loadout_dock.pulse_slot(ctx.base_color, mod)
				await get_tree().create_timer(0.1).timeout

	# Fallback baseline damage if fluf_damage is active or track has no modifiers
	if not any_modifier_fired and Global.cur_char.fluf_damage > 0 and Global.cur_enemy != null:
		Global.cur_enemy.take_dmg(Global.cur_char.fluf_damage * ctx.match_count, 0)

	# 3. Interactive Hazard Follow-up: Fists-family modifiers hurl cleared grd_rock
	if fists_triggered and ctx.hazards_cleared.has("rock") and Global.cur_enemy != null:
		var rock_dmg: float = roundf((4.0 + Global.cur_char.might * 2.0) * ctx.get_momentum_multiplier())
		Global.cur_enemy.take_dmg(rock_dmg, 0)

func _on_enemy_enemy_attacked() -> void:
	if Global.cur_char != null:
		Global.cur_char.reset_stats_at_beginning_of_turn()
	if loadout_dock != null:
		loadout_dock.refresh_dock()
	enemy_attacked_once = false
	trun_changer.change_turn(0)
	await get_tree().create_timer(0.8).timeout
	grd.state = grd.move

func _on_back_to_mm_pressed() -> void:
	Global.post_combat_event = null
	SceneManager.change_scene("res://scenes/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_tree_entered() -> void:
	if Global.cur_char != null:
		Global.cur_char.playerDied.connect(player_died)
		Global.cur_char.playerFinishedTurn.connect(player_finished_turn)
	if Global.cur_enemy != null:
		Global.cur_enemy.enemyDied.connect(enemy_died)
		Global.cur_enemy.destroyPieces.connect(destroy_tile)

func _on_tree_exiting() -> void:
	if Global.cur_char != null:
		if Global.cur_char.playerDied.is_connected(player_died):
			Global.cur_char.playerDied.disconnect(player_died)
		if Global.cur_char.playerFinishedTurn.is_connected(player_finished_turn):
			Global.cur_char.playerFinishedTurn.disconnect(player_finished_turn)
	if Global.cur_enemy != null:
		if Global.cur_enemy.enemyDied.is_connected(enemy_died):
			Global.cur_enemy.enemyDied.disconnect(enemy_died)
		if Global.cur_enemy.destroyPieces.is_connected(destroy_tile):
			Global.cur_enemy.destroyPieces.disconnect(destroy_tile)

#Helper_functions --------------------------------------------------------------
func player_finished_turn():
	grd.state = grd.wait
	while is_executing_matches:
		await get_tree().process_frame
	if !enemy_attacked_once and Global.game_is_played:
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
		if Global.cur_char != null:
			Global.cur_char.reset_modifiers_for_battle()
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
				SceneManager.change_scene("res://scenes/thank_you_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })
				return
		SceneManager.change_scene("res://scenes/reward_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f'), "skip_fade_out": true })

func destroy_tile(space_to_destroy: Array[Vector2]):
	grd.mark_for_destruction(space_to_destroy)
