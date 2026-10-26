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
	get_stat_and_set(Global.cur_char.max_health, cat_health_max, false, "Max Health")
	get_stat_and_set(Global.cur_char.cur_health, cat_health_cur, false, "Current Health")
	get_stat_and_set(Global.cur_char.life_steal, cat_health_lifesteal, true, "Life Steal")
	
	get_stat_and_set(Global.cur_char.grit, cat_defence_startarmor, false, "Grit (Blue)")
	get_stat_and_set(Global.cur_char.start_mage_armor, cat_defence_startmagearmor, true, "Starting Magic Armor")
	get_stat_and_set(Global.cur_char.dmg_reduction_flat, cat_defence_dmgreduction, true, "Flat DMG Reduction")
	get_stat_and_set(Global.cur_char.dmg_reduction, cat_defence_dmgreduction2, true, "Damage Reduction")
	
	get_stat_and_set(Global.cur_char.might, cat_offence_str, false, "Might (Red)")
	if cat_offence_prof != null:
		cat_offence_prof.visible = false
	get_stat_and_set(Global.cur_char.fluf_damage, cat_offence_dmgfluf, true, "Empty Tile Damage")
	get_stat_and_set(Global.cur_char.crit_chance, cat_offence_crit, false, "Critical Strike Chance")
	get_stat_and_set(Global.cur_char.crit_mutly, cat_offence_critdmg, false, "Critical Strike Damage")
	
	get_stat_and_set(Global.cur_char.spirit, cat_magic_mana, false, "Spirit (Purple/White)")
	
	get_stat_and_set(Global.cur_char.speed, cat_utility_spd, false, "Speed (Green / Moves)")
	if cat_utility_agility != null:
		cat_utility_agility.visible = false
	get_stat_and_set(Global.cur_char.rerolls, cat_utility_rerolls, false, "Rerolls")
	get_stat_and_set(Global.cur_char.cooldown_reduction, cat_utility_cd, true, "Cooldown Reduction")
	
func get_stat_and_set(value, to_set: HBoxContainer, hide_if_empty: bool = false, custom_name: String = ""):
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
		label_to_set.text = str(value)
