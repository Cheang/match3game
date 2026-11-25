class_name LocationLoader
extends Resource

@export var area_name: String = ""
@export var enemy_needed: int = 0
@export var enemy_loc_numb: int = 0
@export var event_loc_numb: int = 0
@export var services_loc_numb: int = 0

@export var enemy: Array[Location] = []
@export var services: Array[Location] = []
@export var event: Array[Location] = []
@export var boss: Array[Location] = []

@export_group("Boss Selection")
## Maximum number of random base bosses offered on the table (naturally shows fewer if area.boss has 1-2).
@export_range(1, 5) var max_base_boss_choices: int = 3
## Maximum number of bonus conditional bosses that can appear alongside base bosses when conditions are met.
@export_range(0, 2) var max_conditional_boss_choices: int = 2
## Conditional boss encounters checked against player flags, class, level, or gold.
@export var conditional_bosses: Array[BossOfferCondition] = []

