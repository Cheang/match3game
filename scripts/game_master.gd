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
var _toast_seq: int = 0

func _ready() -> void:
	Global.save()
	defeat_overlay.visible = false
	if Global.cur_enemy != null:
		Global.cur_enemy.reset_stats_at_beginning_of_fight()
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
		grd.update_enemy_target_preview()

	if loadout_dock != null:
		loadout_dock.refresh_dock(true)

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
		loadout_dock.refresh_dock(false)

func _spawn_action_toast(mod: Equipment, ctx: MatchContext, is_player: bool) -> void:
	if not is_inside_tree() or mod == null:
		return
	var pill := PanelContainer.new()
	pill.top_level = true
	pill.z_index = 1750
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var c_tint: Color = Global.get_color_ui_tint(ctx.base_color if ctx != null else 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c_tint.darkened(0.55)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.9, 0.35) if (ctx != null and ctx.has_crit) else c_tint.lightened(0.28)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(hbox)

	if mod.icon != null:
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = mod.icon
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(ic)

	var lbl := Label.new()
	var crit_prefix: String = "CRIT! " if (ctx != null and ctx.has_crit) else ""
	var actor_prefix: String = "" if is_player else "Enemy: "
	lbl.text = "%s%s%s" % [actor_prefix, crit_prefix, mod.piece_name]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72) if (ctx != null and ctx.has_crit) else Color(0.95, 0.96, 0.92))
	lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	var slot_ofs: int = _toast_seq % 2
	_toast_seq += 1
	var anchor_pos := Vector2(340.0, 805.0 if is_player else 195.0)
	if is_player and player != null and player.player_healthbar != null:
		anchor_pos = player.player_healthbar.global_position + Vector2(20.0, -32.0)
	elif not is_player and enemy != null and enemy.healthBar != null:
		anchor_pos = enemy.healthBar.global_position + Vector2(20.0, -32.0)
	var start_pos := Vector2(anchor_pos.x, anchor_pos.y - slot_ofs * 24.0)
	pill.global_position = start_pos
	add_child(pill)

	var tw := pill.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pill, "global_position:y", start_pos.y - 26.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 0.0, 0.65).set_delay(0.22)
	tw.chain().tween_callback(pill.queue_free)

func _execute_match_context(ctx: MatchContext) -> void:
	if ctx == null or ctx.ignore_equipment_triggers:
		return
	var actor: EntityResource = ctx.actor if ctx.actor != null else Global.cur_char
	var target: EntityResource = ctx.target if ctx.target != null else Global.cur_enemy
	if actor == null or target == null:
		return
	if not Global.game_is_played or actor.cur_health <= 0 or target.cur_health <= 0:
		return
	if actor is EnemyResource and ctx.is_secondary_cascade:
		return

	# 1. Exotic Blend & Corrupted Tile Pre-Processing (Section 4.3 & 5.2)
	if ctx.is_exotic_blend or ctx.exotic_count > 0:
		if ctx.base_color == Global.TileColor.RED or ctx.primary_color == Global.TileColor.DARK_CRIMSON:
			if ctx.hazards_cleared.has("flesh"):
				actor.modify_stat("cur_health", 2.0)
			else:
				if actor.cur_health > 1.0:
					actor.modify_stat("cur_health", -1.0)
			ctx.potency_multiplier *= 1.5
			ctx.lifesteal_bonus += 0.25
		else:
			ctx.potency_multiplier *= 1.25

	if ctx.base_color == Global.TileColor.PURPLE and ctx.hazards_cleared.has("flesh"):
		actor.modify_stat("cur_health", 2.0)

	if ctx.hazards_cleared.has("freeze") and target.cur_health > 0:
		var shatter_dmg: float = max(2.0, 2.0 + actor.might)
		target.take_damage(shatter_dmg, false, 1, actor)

	# 2. Fetch acting entity's ColorLoadoutTrack and execute sequential chain triggers
	var track: ColorLoadoutTrack = actor.get_track_for_color(ctx.base_color)
	var fists_triggered: bool = false
	var any_modifier_fired: bool = false
	var track_had_entries: bool = track != null and track.get_filled_entry_count() > 0
	var trigger_budget: int = track.get_trigger_budget(ctx) if track != null else maxi(1, ctx.match_count - 2)

	if track_had_entries:
		for _trigger_idx in range(trigger_budget):
			if not Global.game_is_played or actor.cur_health <= 0 or target.cur_health <= 0:
				break
			var mod: Equipment = track.step_next_entry()
			if mod == null:
				continue
			if mod.can_trigger(ctx):
				any_modifier_fired = true
				if mod.family == "fists":
					fists_triggered = true
				mod.criting = ctx.has_crit
				mod.activate({
					"attacker": actor,
					"target": target,
					"ctx": ctx
				})
				mod.on_triggered(actor)
				_spawn_action_toast(mod, ctx, actor is PlayerResource)
				if actor is PlayerResource and loadout_dock != null:
					loadout_dock.pulse_slot(ctx.base_color, mod)
				if is_inside_tree():
					await get_tree().create_timer(0.1).timeout
			else:
				# Blocked equipment consumes the trigger and cursor has already advanced to the next entry.
				if actor is PlayerResource and loadout_dock != null:
					loadout_dock.refresh_dock(false)

	# Fallback baseline damage if track has no equipped modifiers
	if not track_had_entries and not any_modifier_fired and target.cur_health > 0:
		if actor.fluf_damage > 0:
			target.take_damage(actor.fluf_damage * ctx.match_count, false, 0, actor)
		elif actor is EnemyResource:
			var enemy_actor := actor as EnemyResource
			target.take_damage(max(1.0, enemy_actor.damage) * trigger_budget, false, 0, actor)

	# 3. Interactive Hazard Follow-up: Fists-family modifiers hurl cleared grd_rock
	if fists_triggered and ctx.hazards_cleared.has("rock") and target.cur_health > 0:
		var rock_dmg: float = roundf((4.0 + actor.might * 2.0) * ctx.get_momentum_multiplier())
		target.take_damage(rock_dmg, false, 0, actor)

## Executes the monster's board actions for its turn using its speed and behavior category.
func execute_enemy_turn() -> void:
	if Global.cur_enemy == null or Global.cur_char == null or not Global.game_is_played:
		return
	Global.cur_enemy.reset_stats_at_beginning_of_turn()

	while Global.cur_enemy != null and Global.cur_char != null and Global.game_is_played and Global.cur_enemy.moves_left > 0 and Global.cur_enemy.cur_health > 0 and Global.cur_char.cur_health > 0:
		Global.cur_enemy.modify_stat("moves_left", -1)
		var mode: EnemyResource.BehaviorCategory = Global.cur_enemy.get_current_action_behavior()
		Global.cur_enemy.advance_hybrid_action_state()

		if grd != null:
			if mode == EnemyResource.BehaviorCategory.SMART:
				var chosen_swap: Dictionary = grd.choose_smart_monster_swap(Global.cur_enemy)
				if not chosen_swap.is_empty():
					grd.clear_enemy_target_preview()
					grd.execute_external_swap(
						chosen_swap["origin"],
						chosen_swap["direction"],
						Global.cur_enemy,
						Global.cur_char
					)
				else:
					var fallback_offsets: Array[Vector2i] = Global.cur_enemy.get_beast_destruction_shape()
					var fallback_center: Vector2i = grd.get_or_choose_beast_target_center(fallback_offsets)
					grd.clear_enemy_target_preview()
					grd.execute_beast_destruction(fallback_center, fallback_offsets, Global.cur_enemy, Global.cur_char)
			else:
				var beast_offsets: Array[Vector2i] = Global.cur_enemy.get_beast_destruction_shape()
				var beast_center: Vector2i = grd.get_or_choose_beast_target_center(beast_offsets)
				grd.clear_enemy_target_preview()
				grd.execute_beast_destruction(beast_center, beast_offsets, Global.cur_enemy, Global.cur_char)

			while grd.is_resolving_action or is_executing_matches or not execution_queue.is_empty():
				if not is_inside_tree():
					break
				await get_tree().process_frame

		if Global.cur_enemy != null and Global.cur_enemy.moves_left > 0 and Global.game_is_played and Global.cur_enemy.cur_health > 0 and Global.cur_char.cur_health > 0:
			if grd != null:
				grd.update_enemy_target_preview()
			if is_inside_tree():
				await get_tree().create_timer(0.25).timeout

func _on_enemy_enemy_attacked() -> void:
	if Global.cur_char != null:
		Global.cur_char.reset_stats_at_beginning_of_turn()
	if loadout_dock != null:
		loadout_dock.refresh_dock(false)
	enemy_attacked_once = false
	trun_changer.change_turn(0)
	await get_tree().create_timer(0.8).timeout
	grd.state = grd.move
	if grd != null:
		grd.update_enemy_target_preview()

func _on_back_to_mm_pressed() -> void:
	Global.post_combat_event = null
	SceneManager.change_scene("res://scenes/main_menu.tscn", { "pattern": "diagonal", "color": Color('#484a77') })

func _on_tree_entered() -> void:
	if Global.cur_char == null:
		Global.set_up_player()
	if Global.cur_enemy == null and ResourceLoader.exists("res://enemies/minion/wild_boar/wild_boar_1.tres"):
		Global.set_up_enemy(load("res://enemies/minion/wild_boar/wild_boar_1.tres"))
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
	while (grd != null and grd.is_resolving_action) or is_executing_matches or not execution_queue.is_empty():
		await get_tree().process_frame
	if !enemy_attacked_once and Global.game_is_played and Global.cur_enemy != null and Global.cur_enemy.cur_health > 0 and Global.cur_char != null and Global.cur_char.cur_health > 0:
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
		if Global.has_method("prepare_post_combat_rewards"):
			Global.prepare_post_combat_rewards(Global.cur_enemy)
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
