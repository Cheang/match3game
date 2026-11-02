extends Resource
class_name ColorLoadoutTrack

const DEFAULT_MAX_SLOTS: int = 6

@export var color: int = 100
@export var max_slots: int = DEFAULT_MAX_SLOTS
@export var equipped_modifiers: Array[Equipment] = []
@export var next_entry_cursor: int = 0

func _compact_null_entries() -> void:
	for i in range(equipped_modifiers.size() - 1, -1, -1):
		if equipped_modifiers[i] == null:
			equipped_modifiers.remove_at(i)

func clamp_cursor() -> void:
	_compact_null_entries()
	if equipped_modifiers.is_empty():
		next_entry_cursor = 0
	else:
		next_entry_cursor = posmod(next_entry_cursor, equipped_modifiers.size())

func get_used_slots() -> int:
	var total: int = 0
	for mod in equipped_modifiers:
		if mod != null:
			total += clampi(mod.slot_cost, 1, max_slots)
	return total

func get_free_slots() -> int:
	return max(0, max_slots - get_used_slots())

func get_remaining_slots() -> int:
	return get_free_slots()

func get_filled_entry_count() -> int:
	_compact_null_entries()
	return equipped_modifiers.size()

func can_fit(mod: Equipment) -> bool:
	return can_equip(mod)

func can_equip(mod: Equipment) -> bool:
	if mod == null:
		return false
	if not is_color_compatible(mod):
		return false
	return get_used_slots() + clampi(mod.slot_cost, 1, max_slots) <= max_slots

func is_color_compatible(mod: Equipment) -> bool:
	if mod == null:
		return false
	if color == 0:
		# Colorless fallback track accepts any equipment assigned to it
		return true
	return mod.is_allowed_on_color(color)

func equip_modifier(mod: Equipment, insert_index: int = -1) -> bool:
	if mod == null or not can_equip(mod):
		return false
	if insert_index >= 0 and insert_index < equipped_modifiers.size():
		equipped_modifiers.insert(insert_index, mod)
	else:
		equipped_modifiers.append(mod)
	clamp_cursor()
	return true

func unequip_modifier(mod: Equipment) -> bool:
	var idx: int = equipped_modifiers.find(mod)
	if idx != -1:
		equipped_modifiers.remove_at(idx)
		if idx < next_entry_cursor:
			next_entry_cursor = max(0, next_entry_cursor - 1)
		clamp_cursor()
		return true
	return false

func unequip_at(index: int) -> Equipment:
	if index >= 0 and index < equipped_modifiers.size():
		var mod: Equipment = equipped_modifiers[index]
		equipped_modifiers.remove_at(index)
		if index < next_entry_cursor:
			next_entry_cursor = max(0, next_entry_cursor - 1)
		clamp_cursor()
		return mod
	return null

## Calculates how many sequential equipment entries this match context triggers.
## Confirmed rules:
## - 3-tile match = 1 trigger
## - Every extra tile above 3 adds +1 trigger (4 = 2, 5 = 3, etc.)
## - L_SHAPE or T_SHAPE adds +1 extra trigger to the total
func get_trigger_budget(ctx: MatchContext) -> int:
	if ctx == null:
		return 1
	var count: int = max(3, ctx.match_count)
	var budget: int = max(1, count - 2)
	if ctx.shape_type in ["L_SHAPE", "T_SHAPE"]:
		budget += 1
	return budget

## Advances the chain by 1 step and returns the Equipment at the cursor before advancing.
## Returns null if the track has no filled entries.
func step_next_entry() -> Equipment:
	clamp_cursor()
	if equipped_modifiers.is_empty():
		return null
	var idx: int = next_entry_cursor
	var mod: Equipment = equipped_modifiers[idx]
	next_entry_cursor = (idx + 1) % equipped_modifiers.size()
	return mod

## Returns the Equipment currently at next_entry_cursor without advancing.
func get_next_entry() -> Equipment:
	clamp_cursor()
	if equipped_modifiers.is_empty():
		return null
	return equipped_modifiers[next_entry_cursor]

## Pure, non-mutating preview of which slot indices will actually fire for a prospective MatchContext.
func peek_firing_indices(ctx: MatchContext, actor: Resource = null) -> Array[int]:
	var firing: Array[int] = []
	_compact_null_entries()
	var n: int = equipped_modifiers.size()
	if n == 0 or ctx == null:
		return firing

	var budget: int = get_trigger_budget(ctx)
	var sim_cursor: int = posmod(next_entry_cursor, n)
	var sim_cooldowns: Dictionary = {}
	var sim_used: Dictionary = {}
	for i in range(n):
		var m: Equipment = equipped_modifiers[i]
		sim_cooldowns[i] = m.current_cooldown if m != null else 0
		sim_used[i] = m.used_this_battle if m != null else false

	for _step in range(budget):
		var idx: int = sim_cursor
		sim_cursor = (sim_cursor + 1) % n
		var mod: Equipment = equipped_modifiers[idx]
		if mod == null:
			continue
		if mod.once_per_battle and sim_used[idx]:
			continue
		if sim_cooldowns[idx] > 0:
			continue
		if mod.can_trigger(ctx):
			if not firing.has(idx):
				firing.append(idx)
			if mod.once_per_battle:
				sim_used[idx] = true
			var eff_cd: int = mod.get_effective_cooldown_turns()
			if eff_cd > 0:
				var cdr: int = 0
				if actor != null and "cooldown_reduction" in actor and "spirit" in actor:
					cdr = int(actor.cooldown_reduction) + int(floor(float(actor.spirit) * 0.25))
				sim_cooldowns[idx] = max(0, eff_cd - cdr)

	return firing

func reset_for_battle() -> void:
	next_entry_cursor = 0
	for mod in equipped_modifiers:
		if mod != null:
			mod.reset_for_battle()

func tick_cooldowns(amount: int = 1) -> void:
	for mod in equipped_modifiers:
		if mod != null:
			mod.tick_cooldown(amount)
