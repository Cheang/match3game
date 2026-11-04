extends Node2D
class_name Player

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@onready var art: Node2D = $art
@onready var loadout_dock: LoadoutDock = get_node_or_null("loadout_dock")
@onready var globes: PlayerGlobes = get_node_or_null("player_globes")

# Legacy exports preserved for backward compatibility
@export var bool_buff_texture: Array = []
@export var bool_buff_stat: Array = []
@export var buff_texture: Array = []
@export var buff_stat: Array = []
var player_healthbar = null

var cur_character: PlayerResource = null

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
	if Global.cur_char.sprite != null and art != null:
		var player_sprite = Global.cur_char.sprite.instantiate()
		art.add_child(player_sprite)
	_is_initialized = false
	update_ui("cur_health")
	update_ui("moves_left")
	_last_hp = Global.cur_char.cur_health
	_last_armor = Global.cur_char.cur_armor
	_last_mage_armor = Global.cur_char.cur_mage_armor
	_last_combo = Global.cur_char.hand_combo
	_last_dodging = Global.cur_char.dodging
	_is_initialized = true

func update_ui(stat: String) -> void:
	if Global.cur_char == null:
		return
	cur_character = Global.cur_char

	if stat == "cur_health" or stat == "max_health":
		var cur_hp: float = Global.cur_char.cur_health
		var max_hp: float = max(1.0, Global.cur_char.max_health)
		if globes != null:
			globes.set_hp(cur_hp, max_hp, _is_initialized)

		if _is_initialized and stat == "cur_health":
			var diff: float = cur_hp - _last_hp
			if diff < -0.05:
				_spawn_combat_popup("-%d HP" % int(roundf(abs(diff))), Color(1.0, 0.34, 0.34))
				_flash_attacked_glow()
			elif diff > 0.05:
				_spawn_combat_popup("+%d HP" % int(roundf(diff)), Color(0.38, 0.96, 0.54))
		_last_hp = cur_hp
		return

	if stat == "moves_left" or stat == "agility" or stat == "speed" or stat == "max_energy":
		var moves: int = max(0, Global.cur_char.moves_left)
		var max_moves: int = Global.cur_char.max_energy
		if globes != null:
			globes.set_energy(moves, max_moves, _is_initialized)
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
				_spawn_combat_popup("-Dodge", Color(0.72, 0.68, 0.75))
			_last_dodging = Global.cur_char.dodging

func _flash_attacked_glow() -> void:
	if art == null:
		return
	art.set_material(ATTACKED_GLOW)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func(): if art != null: art.set_material(null))

func _spawn_combat_popup(text_str: String, col: Color) -> void:
	if not is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = text_str
	lbl.z_index = 999
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.15, 1.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_font_size_override("font_size", 18)
	var slot_ofs := _popup_seq % 4
	_popup_seq += 1
	var base_pos: Vector2 = globes.global_position if globes != null else Vector2(221.0, 872.0)
	var start_pos := Vector2(base_pos.x + 20.0 + slot_ofs * 30.0, base_pos.y - 18.0 - (slot_ofs % 2) * 14.0)
	lbl.global_position = start_pos
	add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", start_pos.y - 38.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

func _on_tree_entered() -> void:
	if Global.cur_char != null and not Global.cur_char.updateUIPlayer.is_connected(update_ui):
		Global.cur_char.updateUIPlayer.connect(update_ui)

func _on_tree_exiting() -> void:
	if Global.cur_char != null and Global.cur_char.updateUIPlayer.is_connected(update_ui):
		Global.cur_char.updateUIPlayer.disconnect(update_ui)
