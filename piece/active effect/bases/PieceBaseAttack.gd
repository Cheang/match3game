extends PieceActivation
class_name PieceBaseAttack

@export_enum(
	"physical",
	"magic",
	) var type: int = 0

@export var atk_dmg: float
@export var atk_numb: int

func activate(context = null):
	var cur_char = context.get("attacker", Global.cur_char) if (context != null and context is Dictionary) else Global.cur_char
	var cur_enemy = context.get("target", Global.cur_enemy) if (context != null and context is Dictionary) else Global.cur_enemy
	if cur_char == null or cur_enemy == null:
		return
	
	var loops: int = max(1, atk_numb)
	for i in loops:
		var f_value: float = atk_dmg + cur_char.proficiency + upgrade
		if criting:
			f_value *= (1 + cur_char.crit_mutly / 100)

		cur_enemy.take_dmg(f_value, type)

func get_effect_description(char_resource = null, upgrades: int = 0) -> String:
	var prof: float = 0.0
	if char_resource != null and "proficiency" in char_resource:
		prof = char_resource.proficiency
	elif Global.cur_char != null and "proficiency" in Global.cur_char:
		prof = Global.cur_char.proficiency
	
	var dmg: float = atk_dmg + prof + upgrades
	var count: int = max(1, atk_numb)
	var color_str: String = "#3ca370" if type == 1 else "#ae2334"
	var type_label: String = " Magic" if type == 1 else ""
	if count > 1:
		return "Deals: [color=%s]%s x %d[/color]%s DMG" % [color_str, _fmt(dmg), count, type_label]
	return "Deals: [color=%s]%s[/color]%s DMG" % [color_str, _fmt(dmg), type_label]
