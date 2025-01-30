extends Resource
class_name EnemyResource
#------------------------------------------------------------------------------#
@export_category("Enemy Stats")
@export var name: String
@export_enum("minion", "boss", "miniboss") var type: int
#------------------------------------------------------------------------------#
@export_group("Defence")
@export var max_health: float:
	set(new_max_health):
		var diff = new_max_health - max_health
		max_health = new_max_health
		cur_health += diff
@export var cur_health: float:
	set(new_cur_health):
		cur_health = clamp(new_cur_health, 0, max_health)
		if cur_health <= 0:
			enemyDied.emit()

@export var physical_dmg_reduction: float = 0
#------------------------------------------------------------------------------#
@export_group("Offence")
@export var damage: float
@export var has_phases: bool = false
@export var phase: int = 1:
	set(new_phase):
		phase = clamp(new_phase, 1, 4)
@export var attacks: Array[EnemyAttackBase]
@export_subgroup("Phase Attacks ")
@export var attacks_p2: Array[EnemyAttackBase]
@export var attacks_p3: Array[EnemyAttackBase]
@export var attacks_p4: Array[EnemyAttackBase]
@export var next_attack: EnemyAttackBase
#------------------------------------------------------------------------------#
@export_group("Utility")
@export var speed: int = 1
#------------------------------------------------------------------------------#
@export_category("Art")
@export var sprite: PackedScene
@export var health_bar: Texture2D = preload("res://assets/level_ui/enemy_health.png")
@export var shader: ShaderMaterial
#------------------------------------------------------------------------------#
@export_category("Obstacles")
@export var empty_spaces: Array[Vector2]
@export var ice_spaces: Array[Vector2]
@export var freeze_spaces: Array[Vector2]
@export var rock_spaces: Array[Vector2]
@export var flesh_spaces: Array[Vector2]
#------------------------------------------------------------------------------#

#signals
signal destroyPieces(space_to_destroy: Array[Vector2])
signal updateUIEnemy(stat: String)
signal enemyDied

#Functions_____________________________________________________________________#
func take_dmg(dmg, dmg_type = 0):
	if physical_dmg_reduction > 0 and dmg_type == 0:
		dmg = round(dmg * (1 - physical_dmg_reduction / 100.0))
	add_stat("cur_health",-dmg)
	
	#get this out of here
	if Global.cur_char.life_steal > 0:
		var value = round(dmg * Global.cur_char.life_steal)
		Global.cur_char.modify_stat("cur_health",value)
	
	if has_phases:
		phase_change()

#Helper_functions --------------------------------------------------------------
func phase_change():
	var thresholds := [0.75, 0.5, 0.25]
	if phase <= thresholds.size() and cur_health <= max_health * thresholds[phase - 1]:
		phase += 1

func pick_next_attack():
	next_attack = attacks.pick_random()
	if has_phases:
		var phase_attacks = [null, attacks_p2, attacks_p3, attacks_p4]
		if phase > 1 and phase < phase_attacks.size() and !phase_attacks[phase - 1].is_empty():
			next_attack = phase_attacks[phase - 1].pick_random()

func destroy_pieces(space_to_destroy: Array[Vector2]):
	destroyPieces.emit(space_to_destroy)

func add_stat(stat: String, value):
	if stat in self:
		set(stat, get(stat)+value)
		updateUIEnemy.emit(str(stat))
	else: 
		print("Stat does not exist: ", stat)

func set_stat(stat: String, value):
	if stat in self:
		set(stat, value)
		updateUIEnemy.emit(str(stat))
	else: 
		print("Stat does not exist: ", stat)
