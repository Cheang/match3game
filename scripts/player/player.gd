extends Node2D
class_name Player

const ATTACKED_GLOW = preload("res://assets/shaders/attacked_glow.tres")

@onready var art: Node2D = $art
@onready var loadout_dock: LoadoutDock = get_node_or_null("loadout_dock")
@onready var globes: PlayerGlobes = get_node_or_null("player_globes")
@onready var buff_container: Control = get_node_or_null("buff_container")

var cur_character: PlayerResource = null

var _is_initialized: bool = false
var _last_hp: float = 0.0
var _last_armor: float = 0.0
var _last_mage_armor: float = 0.0
var _last_combo: int = 0
var _last_dodge: bool = false
var _last_dodging: bool:
	get: return _last_dodge
	set(v): _last_dodge = v
var _last_gold: int = 0
var _popup_seq: int = 0
var _is_updating_ui: bool = false

func _ready() -> void:
	if Global.cur_char == null:
		return
	cur_character = Global.cur_char
	Global.cur_char.reset_stats_at_beginning_of_fight()
	if Global.cur_char.sprite != null and art != null:
		var player_sprite = Global.cur_char.sprite.instantiate()
		art.add_child(player_sprite)
	if buff_container != null:
		buff_container.bind_entity(Global.cur_char)
	_is_initialized = false
	update_ui("cur_health")
	update_ui("moves_left")
	update_ui("gold")
	_last_hp = Global.cur_char.cur_health
	_last_armor = Global.cur_char.cur_armor
	_last_mage_armor = Global.cur_char.cur_mage_armor
	_last_combo = Global.cur_char.combo
	_last_dodge = Global.cur_char.dodge
	_last_gold = int(Global.cur_char.gold)
	_is_initialized = true

func update_ui(stat: String) -> void:
	if _is_updating_ui or Global.cur_char == null:
		return
	_is_updating_ui = true
	_update_ui_internal(stat)
	_is_updating_ui = false

func _update_ui_internal(stat: String) -> void:
	if Global.cur_char == null:
		return
	cur_character = Global.cur_char

	if stat == "cur_health" or stat == "max_health" or stat == "cur_armor" or stat == "cur_mage_armor":
		var cur_hp: float = Global.cur_char.cur_health
		var max_hp: float = max(1.0, Global.cur_char.max_health)
		var armor: float = Global.cur_char.cur_armor
		var mage_armor: float = Global.cur_char.cur_mage_armor
		if globes != null:
			globes.set_defenses(cur_hp, max_hp, armor, mage_armor, _is_initialized)

		if _is_initialized:
			if stat == "cur_health":
				var diff: float = cur_hp - _last_hp
				if diff < -0.05:
					_spawn_combat_popup("-%d HP" % int(roundf(abs(diff))), Color(1.0, 0.34, 0.34))
					_flash_attacked_glow()
				elif diff > 0.05:
					_spawn_combat_popup("+%d HP" % int(roundf(diff)), Color(0.38, 0.96, 0.54))
			elif stat == "cur_armor":
				var diff_a: float = armor - _last_armor
				if diff_a > 0.05:
					_spawn_combat_popup("+%d Armor" % int(roundf(diff_a)), Color(0.42, 0.68, 1.0))
				elif diff_a < -0.05:
					_spawn_combat_popup("-%d Armor" % int(roundf(abs(diff_a))), Color(0.65, 0.75, 0.85))
			elif stat == "cur_mage_armor":
				var diff_ma: float = mage_armor - _last_mage_armor
				if diff_ma > 0.05:
					_spawn_combat_popup("+%d M.Armor" % int(roundf(diff_ma)), Color(0.28, 0.88, 0.98))
				elif diff_ma < -0.05:
					_spawn_combat_popup("-%d M.Armor" % int(roundf(abs(diff_ma))), Color(0.28, 0.88, 0.98))
		_last_hp = cur_hp
		_last_armor = armor
		_last_mage_armor = mage_armor
		return

	if stat == "moves_left" or stat == "agility" or stat == "speed" or stat == "max_energy":
		var moves: int = max(0, Global.cur_char.moves_left)
		var max_moves: int = Global.cur_char.max_energy
		if globes != null:
			globes.set_energy(moves, max_moves, _is_initialized)
		return

	if stat == "gold":
		var gold_val: int = int(Global.cur_char.gold)
		if globes != null:
			globes.set_gold(gold_val)
		if _is_initialized:
			var diff_g: int = gold_val - _last_gold
			if diff_g > 0:
				_spawn_combat_popup("+%dg" % diff_g, Color(1.0, 0.88, 0.25))
			elif diff_g < 0:
				_spawn_combat_popup("-%dg" % abs(diff_g), Color(0.9, 0.75, 0.3))
		_last_gold = gold_val
		return

	if stat == "combo" or stat == "hand_combo" or stat == "dodge" or stat == "dodging":
		if buff_container != null:
			buff_container.refresh(Global.cur_char)

	if _is_initialized:
		if stat == "combo" or stat == "hand_combo":
			var diff_c: int = Global.cur_char.combo - _last_combo
			if diff_c > 0:
				_spawn_combat_popup("+%d Combo" % diff_c, Color(0.98, 0.84, 0.35))
			_last_combo = Global.cur_char.combo
		elif stat == "dodge" or stat == "dodging":
			if Global.cur_char.dodge and not _last_dodge:
				_spawn_combat_popup("+Dodge", Color(0.42, 0.94, 0.48))
			elif not Global.cur_char.dodge and _last_dodge and Global.cur_char.moves_left <= 0:
				_spawn_combat_popup("-Dodge", Color(0.72, 0.68, 0.75))
			_last_dodge = Global.cur_char.dodge

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
