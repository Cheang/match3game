class_name Enemy
extends Node2D

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@onready var healthBar: TextureProgressBar = get_node_or_null("healthBar") if has_node("healthBar") else get_node_or_null("enemy_healthbar")
@onready var armorBar: TextureProgressBar = get_node_or_null("healthBar/armorBar") if has_node("healthBar/armorBar") else get_node_or_null("armorBar")
@onready var art: Node2D = $art
@onready var health: Label = get_node_or_null("healthBar/health") if has_node("healthBar/health") else get_node_or_null("enemy_healthbar/health")
@onready var enemy_audio: AudioStreamPlayer = $enemy_audio
@onready var attack_dock: AttackDock = get_node_or_null("attackDock") if has_node("attackDock") else get_node_or_null("monster_attack_dock")
@onready var buff_container: Control = get_node_or_null("buff_container")
@onready var name_box: Control = get_node_or_null("name_box")
@onready var name_label: Label = get_node_or_null("name_box/name") if has_node("name_box/name") else get_node_or_null("name")

var _is_initialized: bool = false
var _last_hp: float = 0.0
var _popup_seq: int = 0
var _cached_track_tooltip: String = ""

signal enemy_attacked

func _ready() -> void:
	if Global.cur_enemy == null:
		Global.set_up_enemy()
	if Global.cur_enemy == null:
		return
	Global.cur_enemy.ensure_loadout_tracks()
	Global.cur_enemy.pick_next_attack()
	_cache_track_tooltip()
	if attack_dock != null:
		attack_dock.refresh_tracks(Global.cur_enemy)
	if buff_container != null:
		buff_container.bind_entity(Global.cur_enemy)
	if Global.cur_enemy.sprite != null:
		var enemy_sprite = Global.cur_enemy.sprite.instantiate()
		art.add_child(enemy_sprite)
	if Global.cur_enemy.shader != null:
		art.set_material(Global.cur_enemy.shader)
	if Global.cur_enemy.health_bar != null and healthBar != null and healthBar.name == "enemy_healthbar":
		healthBar.texture_progress = Global.cur_enemy.health_bar
	_is_initialized = false
	update_name()
	update_health()
	_last_hp = Global.cur_enemy.cur_health
	_is_initialized = true

func update_name() -> void:
	if name_label != null:
		if Global.cur_enemy != null:
			name_label.text = Global.cur_enemy.name
			if name_box != null:
				name_box.visible = true
		else:
			name_label.text = ""
			if name_box != null:
				name_box.visible = false

func _on_health_bar_value_changed(value: float) -> void:
	_on_enemy_healthbar_value_changed(value)

func _on_enemy_healthbar_value_changed(_value: float) -> void:
	art.set_material(ATTACKED_GLOW)
	await get_tree().create_timer(.3).timeout
	if Global.cur_enemy != null:
		art.set_material(Global.cur_enemy.shader)

func _on_game_window_enemy_attacking() -> void:
	if Global.cur_enemy == null:
		enemy_attacked.emit()
		return
	if Global.cur_enemy.next_attack != null:
		if Global.cur_enemy.next_attack.animation != null and art.get_child_count() > 0:
			var sprite_node = art.get_child(0)
			if sprite_node.has_method("set_animp"):
				sprite_node.set_animp(Global.cur_enemy.next_attack.animation)
		if Global.cur_enemy.next_attack.sound != null:
			enemy_audio.stream = Global.cur_enemy.next_attack.sound
			enemy_audio.play()
		await get_tree().create_timer(Global.cur_enemy.next_attack.animation_time).timeout
	else:
		await get_tree().create_timer(0.3).timeout

	var parent_gm = get_parent()
	if parent_gm != null and parent_gm.has_method("execute_enemy_turn"):
		await parent_gm.execute_enemy_turn()
	elif Global.cur_enemy != null and Global.cur_enemy.next_attack != null:
		Global.cur_enemy.next_attack.attack()

	if Global.cur_enemy != null:
		Global.cur_enemy.reset_stats_at_end_of_turn()

	if art.get_child_count() > 0:
		var sprite_node = art.get_child(0)
		if sprite_node.has_method("set_animp"):
			sprite_node.set_animp("RESET")
			sprite_node.set_animp("idle")
	if Global.cur_enemy != null:
		Global.cur_enemy.pick_next_attack()
	enemy_attacked.emit()

func _on_game_window_enemy_health_change() -> void:
	update_health()

func _on_tree_entered() -> void:
	if Global.cur_enemy != null and not Global.cur_enemy.updateUIEnemy.is_connected(update_ui):
		Global.cur_enemy.updateUIEnemy.connect(update_ui)

func _on_tree_exiting() -> void:
	if Global.cur_enemy != null and Global.cur_enemy.updateUIEnemy.is_connected(update_ui):
		Global.cur_enemy.updateUIEnemy.disconnect(update_ui)

#Helper_functions --------------------------------------------------------------
func _cache_track_tooltip() -> void:
	if Global.cur_enemy == null:
		_cached_track_tooltip = ""
		return
	var e: EnemyResource = Global.cur_enemy
	var lines: Array[String] = []
	for k in e.color_loadouts.keys():
		var track: ColorLoadoutTrack = e.color_loadouts[k]
		if track != null and not track.equipped_modifiers.is_empty():
			var names: Array[String] = []
			for m in track.equipped_modifiers:
				if m != null:
					names.append(m.piece_name)
			lines.append("%s Track: %s" % [Global.get_color_name(int(k)), " → ".join(names)])
	if e.colorless_fallback_track != null and not e.colorless_fallback_track.equipped_modifiers.is_empty():
		var fb_names: Array[String] = []
		for m in e.colorless_fallback_track.equipped_modifiers:
			if m != null:
				fb_names.append(m.piece_name)
		lines.append("Fallback Track: %s" % " → ".join(fb_names))
	_cached_track_tooltip = ("\n" + "\n".join(lines)) if not lines.is_empty() else ""

func _build_enemy_tooltip() -> String:
	if Global.cur_enemy == null:
		return ""
	var e: EnemyResource = Global.cur_enemy
	var mode: EnemyResource.BehaviorCategory = e.get_current_action_behavior()
	var mode_desc: String = "Swaps highlighted tiles to make matches" if mode == EnemyResource.BehaviorCategory.SMART else "Crushes highlighted board area"
	return "%s (HP: %d/%d • Agility: %d • Might: %d)\nNext Action: %s%s" % [
		e.name,
		int(roundf(e.cur_health)),
		int(roundf(e.max_health)),
		max(1, e.agility),
		int(roundf(e.might)),
		mode_desc,
		_cached_track_tooltip
	]

func update_health():
	if Global.cur_enemy == null:
		return
	var cur_hp: float = Global.cur_enemy.cur_health
	var max_hp: float = max(1.0, Global.cur_enemy.max_health)
	var armor_str: String = ""
	if Global.cur_enemy.cur_armor > 0:
		armor_str += " [Armor:%d]" % int(roundf(Global.cur_enemy.cur_armor))
	if Global.cur_enemy.cur_mystic_armor > 0:
		armor_str += " [Mystic Armor:%d]" % int(roundf(Global.cur_enemy.cur_mystic_armor))
	if health != null:
		health.text = "HP: %d / %d%s" % [int(roundf(cur_hp)), int(roundf(max_hp)), armor_str]
	if healthBar != null:
		healthBar.value = cur_hp * 100.0 / max_hp
		healthBar.tooltip_text = _build_enemy_tooltip()
	if armorBar != null:
		var total_armor: float = Global.cur_enemy.cur_armor + Global.cur_enemy.cur_mystic_armor
		armorBar.value = clampf(total_armor * 100.0 / max_hp, 0.0, 100.0)

	if _is_initialized:
		var diff: float = cur_hp - _last_hp
		if diff < -0.05:
			_spawn_enemy_popup("-%d DMG" % int(roundf(abs(diff))), Color(1.0, 0.35, 0.32))
		elif diff > 0.05:
			_spawn_enemy_popup("+%d HP" % int(roundf(diff)), Color(0.4, 0.95, 0.55))
	_last_hp = cur_hp

func _spawn_enemy_popup(text_str: String, col: Color) -> void:
	if not is_inside_tree():
		return
	var lbl := Label.new()
	lbl.top_level = true
	lbl.z_index = 1800
	lbl.text = text_str
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.1, 0.98))
	lbl.add_theme_constant_override("outline_size", 4)

	var slot_ofs: int = _popup_seq % 3
	_popup_seq += 1
	var base_pos: Vector2 = healthBar.global_position if healthBar != null else Vector2(34.0, 179.0)
	var start_pos := Vector2(base_pos.x + 56.0 + slot_ofs * 62.0, base_pos.y - 14.0 - (slot_ofs % 2) * 14.0)
	lbl.global_position = start_pos
	add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", start_pos.y - 40.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

func update_ui(stat: String):
	if stat in ["cur_health", "max_health", "cur_armor", "cur_mystic_armor"]:
		update_health()
	elif stat in ["combo", "hand_combo", "dodge", "dodging"]:
		if buff_container != null and Global.cur_enemy != null:
			buff_container.refresh(Global.cur_enemy)
