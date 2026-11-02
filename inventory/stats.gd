extends VBoxContainer

@onready var stat_container: VBoxContainer = $ScrollContainer/stat_container

@onready var cat_health_max: HBoxContainer = $ScrollContainer/stat_container/health_part/VBoxContainer/cat_health_max
@onready var cat_health_cur: HBoxContainer = $ScrollContainer/stat_container/health_part/VBoxContainer/cat_health_cur
@onready var cat_health_lifesteal: HBoxContainer = $ScrollContainer/stat_container/health_part/VBoxContainer/cat_health_lifesteal

@onready var cat_defence_startarmor: HBoxContainer = $ScrollContainer/stat_container/defence_part/VBoxContainer/cat_defence_startarmor
@onready var cat_defence_startmagearmor: HBoxContainer = $ScrollContainer/stat_container/defence_part/VBoxContainer/cat_defence_startmagearmor
@onready var cat_defence_dmgreduction: HBoxContainer = $ScrollContainer/stat_container/defence_part/VBoxContainer/cat_defence_dmgreduction
@onready var cat_defence_dmgreduction2: HBoxContainer = $ScrollContainer/stat_container/defence_part/VBoxContainer/cat_defence_dmgreduction2

@onready var cat_offence_prof: HBoxContainer = $ScrollContainer/stat_container/offence_part/VBoxContainer/cat_offence_prof
@onready var cat_offence_str: HBoxContainer = $ScrollContainer/stat_container/offence_part/VBoxContainer/cat_offence_str
@onready var cat_offence_dmgfluf: HBoxContainer = $ScrollContainer/stat_container/offence_part/VBoxContainer/cat_offence_dmgfluf
@onready var cat_offence_crit: HBoxContainer = $ScrollContainer/stat_container/offence_part/VBoxContainer/cat_offence_crit
@onready var cat_offence_critdmg: HBoxContainer = $ScrollContainer/stat_container/offence_part/VBoxContainer/cat_offence_critdmg

@onready var cat_magic_mana: HBoxContainer = $ScrollContainer/stat_container/magic_part/VBoxContainer/cat_magic_mana

@onready var cat_utility_spd: HBoxContainer = $ScrollContainer/stat_container/utility_part/VBoxContainer/cat_utility_spd
@onready var cat_utility_agility: HBoxContainer = $ScrollContainer/stat_container/utility_part/VBoxContainer/cat_utility_agility
@onready var cat_utility_rerolls: HBoxContainer = $ScrollContainer/stat_container/utility_part/VBoxContainer/cat_utility_rerolls
@onready var cat_utility_cd: HBoxContainer = $ScrollContainer/stat_container/utility_part/VBoxContainer/cat_utility_cd

func expand():
	if Global.cur_char == null:
		return
	var eq_bonuses: Dictionary = Global.cur_char._active_equipment_stat_contributions if "_active_equipment_stat_contributions" in Global.cur_char else {}

	get_stat_and_set(Global.cur_char.max_health, cat_health_max, false, "Max Health", eq_bonuses.get("max_health", 0.0))
	get_stat_and_set(Global.cur_char.cur_health, cat_health_cur, false, "Current Health")
	var ls_display = roundf(Global.cur_char.life_steal * 100.0) if Global.cur_char.life_steal > 0.0 and Global.cur_char.life_steal <= 1.0 else Global.cur_char.life_steal
	get_stat_and_set(ls_display, cat_health_lifesteal, true, "Life Steal (%)")

	get_stat_and_set(Global.cur_char.grit, cat_defence_startarmor, false, "Grit (Blue)", eq_bonuses.get("grit", 0.0))
	get_stat_and_set(Global.cur_char.start_mage_armor, cat_defence_startmagearmor, true, "Starting Magic Armor", eq_bonuses.get("start_mage_armor", 0.0))
	get_stat_and_set(Global.cur_char.dmg_reduction_flat, cat_defence_dmgreduction, true, "Flat DMG Reduction", eq_bonuses.get("dmg_reduction_flat", 0.0))
	get_stat_and_set(Global.cur_char.dmg_reduction, cat_defence_dmgreduction2, true, "Damage Reduction", eq_bonuses.get("dmg_reduction", 0.0))

	get_stat_and_set(Global.cur_char.might, cat_offence_str, false, "Might (Red)", eq_bonuses.get("might", 0.0))
	if cat_offence_prof != null:
		cat_offence_prof.visible = false
	get_stat_and_set(Global.cur_char.fluf_damage, cat_offence_dmgfluf, true, "Unarmed Track DMG", eq_bonuses.get("fluf_damage", 0.0))
	var eff_crit: int = Global.cur_char.crit_chance + max(0, (Global.cur_char.speed - 2) * 2)
	get_stat_and_set(eff_crit, cat_offence_crit, false, "Crit Chance", eq_bonuses.get("crit_chance", 0.0))
	get_stat_and_set(Global.cur_char.crit_mutly, cat_offence_critdmg, false, "Crit Bonus DMG", eq_bonuses.get("crit_mutly", 0.0))

	get_stat_and_set(Global.cur_char.spirit, cat_magic_mana, false, "Spirit (Purple/White)", eq_bonuses.get("spirit", 0.0))

	get_stat_and_set(Global.cur_char.speed, cat_utility_spd, false, "Speed (Moves/Turn)", eq_bonuses.get("speed", 0.0))
	if cat_utility_agility != null:
		cat_utility_agility.visible = false
	get_stat_and_set(Global.cur_char.rerolls, cat_utility_rerolls, false, "Draft Rerolls")
	var eff_cdr: int = Global.cur_char.cooldown_reduction + int(floor(Global.cur_char.spirit * 0.25))
	get_stat_and_set(eff_cdr, cat_utility_cd, true, "Cooldown Reduction", eq_bonuses.get("cooldown_reduction", 0.0))

func _fmt_num(val) -> String:
	if typeof(val) == TYPE_FLOAT:
		if is_equal_approx(val, roundf(val)):
			return str(int(roundf(val)))
		return str(snappedf(val, 0.1))
	return str(val)

func get_stat_and_set(value, to_set: HBoxContainer, hide_if_empty: bool = false, custom_name: String = "", eq_bonus: float = 0.0):
	if to_set == null:
		return
	var name_lbl = to_set.get_child(0)
	var label_to_set = to_set.get_child(1)
	if custom_name != "" and name_lbl is Label:
		name_lbl.text = custom_name
	if value <= 0 and hide_if_empty:
		to_set.visible = false
	else:
		to_set.visible = true
	if label_to_set:
		var base_txt: String = _fmt_num(value)
		if not is_zero_approx(eq_bonus):
			var sign_str: String = "+" if eq_bonus > 0 else ""
			label_to_set.text = "%s (%s%s)" % [base_txt, sign_str, _fmt_num(eq_bonus)]
		else:
			label_to_set.text = base_txt
