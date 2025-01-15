extends Resource
class_name EnemyResource
#------------------------------------------------------------------------------#
@export_category("Enemy Stats")
@export var name: String
@export_enum("minion", "boss", "miniboss") var type: int
#------------------------------------------------------------------------------#
@export_group("Defence")
@export var max_health: float
var cur_health: float

@export var physical_dmg_reduction: float = 0
#------------------------------------------------------------------------------#
@export_group("Offence")
@export var damage: float
@export var has_phases: bool = false
var phase: int = 1
@export var attacks: Array[EnemyAttackBase]
@export_subgroup("Phase Attacks ")
@export var attacks_p2: Array[EnemyAttackBase]
@export var attacks_p3: Array[EnemyAttackBase]
@export var attacks_p4: Array[EnemyAttackBase]
var next_attack: EnemyAttackBase
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
	add_stat("cur_health",dmg*-1)
	
	#get this out of here
	if Global.cur_char.life_steal > 0:
		var value = round(dmg * Global.cur_char.life_steal)
		Global.cur_char.add_stat("cur_health",value)
	
	phase_change()

func pick_next_attack():
	randomize()
	next_attack = attacks.pick_random()
	if has_phases:
		if phase == 2 and !attacks_p2.is_empty():
			next_attack = attacks_p2.pick_random()
		elif phase == 3 and !attacks_p3.is_empty():
			next_attack = attacks_p3.pick_random()
		elif phase == 4 and !attacks_p4.is_empty():
			next_attack = attacks_p4.pick_random()

func destroy_pieces(space_to_destroy: Array[Vector2]):
	destroyPieces.emit(space_to_destroy)

#Helper_functions --------------------------------------------------------------
func phase_change():
	if has_phases:
		if cur_health <= max_health * .75 and phase == 1:
			phase = 2
		elif cur_health <= max_health * .5 and phase == 2:
			phase = 3
		elif cur_health <= max_health * .25 and phase == 3:
			phase = 4

func add_stat(stat: String, value):
	if stat in self:
		if stat == "cur_health":
			set(stat, clamp(get(stat)+value, 0, max_health))
			if get(stat) == 0:
				enemyDied.emit()
			updateUIEnemy.emit(str(stat))
			return
		set(stat, get(stat)+value)
		updateUIEnemy.emit(str(stat))
	else: 
		print("Stat does not exist: ", stat)

func set_stat(stat: String, value):
	if stat in self:
		if stat == "cur_health":
			set(stat, clamp(value, 0, max_health))
			updateUIEnemy.emit(str(stat))
			return
		set(stat, value)
		updateUIEnemy.emit(str(stat))
	else: 
		print("Stat does not exist: ", stat)
