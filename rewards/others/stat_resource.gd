extends Reward
class_name R_Stat

@export_category("Stats")
@export var stats: Array[String] = []
@export var increase: Array = []

func activate():
	if Global.cur_char == null:
		return
	var i = 0
	for stat in stats:
		var inc = increase[i] if i < increase.size() else (increase[0] if not increase.is_empty() else 0)
		var cur = Global.cur_char.get(stat)
		if cur != null:
			Global.cur_char.set(stat, cur + inc)
		i += 1
