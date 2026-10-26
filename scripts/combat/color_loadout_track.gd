extends Resource
class_name ColorLoadoutTrack

@export var color: int = 100
@export var max_slots: int = 3
@export var equipped_modifiers: Array[Equipment] = []

func get_used_slots() -> int:
	var total: int = 0
	for mod in equipped_modifiers:
		if mod != null:
			total += clampi(mod.slot_cost, 1, 3)
	return total

func get_free_slots() -> int:
	return max(0, max_slots - get_used_slots())

func can_equip(mod: Equipment) -> bool:
	if mod == null:
		return false
	if not is_color_compatible(mod):
		return false
	return get_used_slots() + clampi(mod.slot_cost, 1, 3) <= max_slots

func is_color_compatible(mod: Equipment) -> bool:
	if mod == null:
		return false
	return mod.is_allowed_on_color(color)

func equip_modifier(mod: Equipment, insert_index: int = -1) -> bool:
	if mod == null or not can_equip(mod):
		return false
	if insert_index >= 0 and insert_index < equipped_modifiers.size():
		equipped_modifiers.insert(insert_index, mod)
	else:
		equipped_modifiers.append(mod)
	return true

func unequip_modifier(mod: Equipment) -> bool:
	var idx: int = equipped_modifiers.find(mod)
	if idx != -1:
		equipped_modifiers.remove_at(idx)
		return true
	return false

func unequip_at(index: int) -> Equipment:
	if index >= 0 and index < equipped_modifiers.size():
		var mod: Equipment = equipped_modifiers[index]
		equipped_modifiers.remove_at(index)
		return mod
	return null

func reset_for_battle() -> void:
	for mod in equipped_modifiers:
		if mod != null:
			mod.reset_for_battle()

func tick_cooldowns(amount: int = 1) -> void:
	for mod in equipped_modifiers:
		if mod != null:
			mod.tick_cooldown(amount)
