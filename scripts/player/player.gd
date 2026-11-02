extends Node2D
class_name Player

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@export var bool_buff_texture: Array[TextureRect]
@export var bool_buff_stat: Array[String]
@export var buff_texture: Array[TextureRect]
@export var buff_stat: Array[String]

@onready var player_healthbar: TextureProgressBar = $health_buffs/player_healthbar
@onready var fire: GPUParticles2D = $health_buffs/player_healthbar/fire_particles
@onready var art: Node2D = $art
@onready var move_remaing: Label = $move_remaing
@onready var health: Label = $health_buffs/player_healthbar/health

var one_time_fire = false
var cur_character = Global.cur_char

var _is_initialized: bool = false
var _last_hp: float = 0.0
var _last_armor: float = 0.0
var _last_mage_armor: float = 0.0
var _last_combo: int = 0
var _last_dodging: bool = false
var _popup_seq: int = 0

func _ready() -> void:
	if Global.cur_char == null:
		return
	cur_character = Global.cur_char
	Global.cur_char.reset_stats_at_beging_of_fight()
	if Global.cur_char.sprite != null:
		var player_sprite = Global.cur_char.sprite.instantiate()
		art.add_child(player_sprite)
	_is_initialized = false
	update_ui("cur_health")
	update_ui("moves_left")
	update_buffs()
	_last_hp = Global.cur_char.cur_health
	_last_armor = Global.cur_char.cur_armor
	_last_mage_armor = Global.cur_char.cur_mage_armor
	_last_combo = Global.cur_char.hand_combo
	_last_dodging = Global.cur_char.dodging
	_is_initialized = true

func update_ui(stat: String):
	if Global.cur_char == null:
		return
	cur_character = Global.cur_char
	if stat == "cur_health" or stat == "max_health":
		var cur_hp: float = Global.cur_char.cur_health
		var max_hp: float = max(1.0, Global.cur_char.max_health)
		health.text = "HP: %d / %d" % [int(roundf(cur_hp)), int(roundf(max_hp))]
		player_healthbar.value = cur_hp * 100.0 / max_hp
		player_healthbar.tooltip_text = "Player Health: %d / %d" % [int(roundf(cur_hp)), int(roundf(max_hp))]
		if _is_initialized and stat == "cur_health":
			var diff: float = cur_hp - _last_hp
			if diff < -0.05:
				_spawn_combat_popup("-%d HP" % int(roundf(abs(diff))), Color(1.0, 0.34, 0.34))
			elif diff > 0.05:
				_spawn_combat_popup("+%d HP" % int(roundf(diff)), Color(0.38, 0.96, 0.54))
		_last_hp = cur_hp
		return

	if stat == "moves_left":
		var moves: int = max(0, Global.cur_char.moves_left)
		move_remaing.text = "Moves Remaining: %d" % moves
		if moves > 0:
			move_remaing.add_theme_color_override("font_color", Color(0.78, 0.92, 0.84, 1.0))
		else:
			move_remaing.add_theme_color_override("font_color", Color(0.68, 0.62, 0.72, 0.88))
		if _is_initialized and is_inside_tree():
			move_remaing.pivot_offset = move_remaing.size * 0.5
			var tw := create_tween()
			tw.tween_property(move_remaing, "scale", Vector2(1.07, 1.07), 0.07)
			tw.tween_property(move_remaing, "scale", Vector2.ONE, 0.12)
		return

	if _is_initialized:
		if stat == "cur_armor":
			var diff_a: float = Global.cur_char.cur_armor - _last_armor
			if diff_a > 0.05:
				_spawn_combat_popup("+%d Armor" % int(roundf(diff_a)), Color(0.42, 0.68, 1.0))
			_last_armor = Global.cur_char.cur_armor
		elif stat == "cur_mage_armor":
			var diff_ma: float = Global.cur_char.cur_mage_armor - _last_mage_armor
			if diff_ma > 0.05:
				_spawn_combat_popup("+%d M.Armor" % int(roundf(diff_ma)), Color(0.28, 0.88, 0.98))
			_last_mage_armor = Global.cur_char.cur_mage_armor
		elif stat == "hand_combo":
			var diff_c: int = Global.cur_char.hand_combo - _last_combo
			if diff_c > 0:
				_spawn_combat_popup("+%d Combo" % diff_c, Color(0.98, 0.84, 0.35))
			_last_combo = Global.cur_char.hand_combo
		elif stat == "dodging":
			if Global.cur_char.dodging and not _last_dodging:
				_spawn_combat_popup("+Dodge", Color(0.42, 0.94, 0.48))
			elif not Global.cur_char.dodging and _last_dodging and Global.cur_char.moves_left <= 0:
				_spawn_combat_popup("DODGED!", Color(0.45, 1.0, 0.55))
			_last_dodging = Global.cur_char.dodging

	if typeof(Global.cur_char.get(stat)) == TYPE_BOOL:
		for i in bool_buff_texture.size():
			var temp = Global.cur_char.get(bool_buff_stat[i])
			updete_bool_buff(bool_buff_texture[i], temp, bool_buff_stat[i])
	else:
		for i in buff_texture.size():
			var temp = Global.cur_char.get(buff_stat[i])
			update_buff(buff_texture[i], temp, buff_stat[i])

func _spawn_combat_popup(text_str: String, col: Color) -> void:
	if not is_inside_tree():
		return
	var lbl := Label.new()
	lbl.top_level = true
	lbl.z_index = 1800
	lbl.text = text_str
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.1, 0.98))
	lbl.add_theme_constant_override("outline_size", 4)

	var slot_ofs: int = _popup_seq % 3
	_popup_seq += 1
	var base_pos: Vector2 = player_healthbar.global_position if player_healthbar != null else Vector2(200.0, 894.0)
	var start_pos := Vector2(base_pos.x + 60.0 + slot_ofs * 56.0, base_pos.y - 12.0 - (slot_ofs % 2) * 14.0)
	lbl.global_position = start_pos
	add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", start_pos.y - 38.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

func _on_player_healthbar_value_changed(value: float) -> void:
	if not one_time_fire:
		one_time_fire = true
		fire.visible = true
	if cur_character != null and cur_character.cur_health == cur_character.max_health and one_time_fire:
		fire.visible = false
		one_time_fire = false
	art.set_material(ATTACKED_GLOW)
	move(Vector2((value * 2.85), fire.position.y), 0.5)
	await get_tree().create_timer(0.3).timeout
	art.set_material(null)

func _on_tree_entered() -> void:
	if Global.cur_char != null and not Global.cur_char.updateUIPlayer.is_connected(update_ui):
		Global.cur_char.updateUIPlayer.connect(update_ui)

func _on_tree_exiting() -> void:
	if Global.cur_char != null and Global.cur_char.updateUIPlayer.is_connected(update_ui):
		Global.cur_char.updateUIPlayer.disconnect(update_ui)

#Helper functions --------------------------------------------------------------
func update_buffs():
	if Global.cur_char == null:
		return
	for i in buff_texture.size():
		var stat_name: String = buff_stat[i]
		var stat = Global.cur_char.get(stat_name)
		update_buff(buff_texture[i], stat, stat_name)
	for i in bool_buff_texture.size():
		var stat_name: String = bool_buff_stat[i]
		var stat = Global.cur_char.get(stat_name)
		updete_bool_buff(bool_buff_texture[i], stat, stat_name)

func update_buff(buff_art: TextureRect, parameter, stat_name: String = ""):
	if !Global.is_null(buff_art):
		if parameter > 0:
			buff_art.visible = true
			var val_int: int = int(roundf(float(parameter)))
			buff_art.get_child(0).text = str(val_int)
			match stat_name:
				"cur_armor":
					buff_art.tooltip_text = "Physical Armor (%d)\nAbsorbs incoming physical damage until your next turn." % val_int
				"cur_mage_armor":
					buff_art.tooltip_text = "Magic Armor (%d)\nAbsorbs incoming damage and persists across turns." % val_int
				"hand_combo":
					buff_art.tooltip_text = "Hand Combo (%d)\nScales Fists & Combo equipment effects this turn." % val_int
		elif parameter <= 0:
			buff_art.visible = false

func updete_bool_buff(buff_art: TextureRect, parameter, stat_name: String = ""):
	if !Global.is_null(buff_art):
		buff_art.visible = bool(parameter)
		if stat_name == "dodging" and bool(parameter):
			buff_art.tooltip_text = "Dodge Active\nEvades the next incoming physical enemy attack."

func move(target, time = 0.3):
	var tween: Tween = create_tween()
	tween.tween_property(fire, "position", target, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
