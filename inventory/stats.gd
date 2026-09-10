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
	get_stat_and_set(Global.cur_char.max_health, cat_health_max)
	get_stat_and_set(Global.cur_char.cur_health, cat_health_cur)
	get_stat_and_set(Global.cur_char.life_steal, cat_health_lifesteal, true)
	
	get_stat_and_set(Global.cur_char.start_armor, cat_defence_startarmor)
	get_stat_and_set(Global.cur_char.start_mage_armor, cat_defence_startmagearmor)
	get_stat_and_set(Global.cur_char.dmg_reduction_flat, cat_defence_dmgreduction, true)
	get_stat_and_set(Global.cur_char.dmg_reduction, cat_defence_dmgreduction2, true)
	
	get_stat_and_set(Global.cur_char.proficiency, cat_offence_prof)
	get_stat_and_set(Global.cur_char.strength, cat_offence_str)
	get_stat_and_set(Global.cur_char.fluf_damage, cat_offence_dmgfluf, true)
	get_stat_and_set(Global.cur_char.crit_chance, cat_offence_crit)
	get_stat_and_set(Global.cur_char.crit_mutly, cat_offence_critdmg)
	
	get_stat_and_set(Global.cur_char.mana, cat_magic_mana)
	
	get_stat_and_set(Global.cur_char.speed, cat_utility_spd)
	get_stat_and_set(Global.cur_char.agility, cat_utility_agility)
	get_stat_and_set(Global.cur_char.rerolls, cat_utility_rerolls)
	get_stat_and_set(Global.cur_char.cooldown_reduction, cat_utility_cd, true)
	
func get_stat_and_set(value, to_set: HBoxContainer, hide_if_empty: bool = false):
	var label_to_set = to_set.get_child(1)
	if value <= 0 and hide_if_empty:
		to_set.visible = false
	if label_to_set:
		label_to_set.text = str(value)
