extends Resource
class_name Reward

@export_category("General")
@export var name: String
@export_multiline var description: String
@export var base: Texture2D
@export var icon: Texture2D

@export var flags: Array[String] 

@export_category("Rarity")
@export_enum("COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "GODLY") var rearity: String = "COMMON"

func activate():
	pass

func boost():
	for flag in flags:
		Global.cur_char.set_flag(flag)
