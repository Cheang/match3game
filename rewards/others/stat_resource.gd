extends Reward
class_name R_Stat

@export var stats: Array[String] = []
@export var increase: Array = []

func activate():
	for stat in stats:
		var i = 0
		var cur = Global.cur_char.get(stat)
		Global.cur_char.set(stat,cur + increase[i])
		i += 1
	
