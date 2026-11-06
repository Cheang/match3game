extends Resource
class_name ColorLoadoutTrack

const NORMAL_MAX_SLOTS: int = 5
const TOTAL_MAX_SLOTS: int = 6
const DEFAULT_MAX_SLOTS: int = 5

enum NormalSlotVisualState {
	EMPTY = 0,  # Slot has no skill equipped; transparent so base texture shows through
	DARK = 1,   # Equipped skill is used in this cycle or on cooldown
	NEXT = 2,   # Next skill to be used (lighter state)
	NORMAL = 3  # Ready to be used later in this cycle
}

enum UltimateVisualState {
	NO_ULTIMATE = 0, # The "U" is missing, just color indicator
	NORMAL = 1,      # Has ultimate, but not active for this cycle (or on cooldown)
	ACTIVATED = 2    # Lighter "U", active and will be used
}

const PALETTES: Dictionary = {
	100: { # Red
		"highlight": Color("#F9C22B"),
		"lightbase": Color("#FB6B1D"),
		"base": Color("#E83B3B"),
		"shadebase": Color("#AE2334"),
		"deepshade": Color("#7A3045")
	},
	200: { # Blue
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#8FD3FF"),
		"base": Color("#4D9BE6"),
		"shadebase": Color("#4D65B4"),
		"deepshade": Color("#484A77")
	},
	300: { # Green
		"highlight": Color("#FBFF86"),
		"lightbase": Color("#91DB69"),
		"base": Color("#1EBC73"),
		"shadebase": Color("#239063"),
		"deepshade": Color("#165A4C")
	},
	400: { # Purple
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#EAADED"),
		"base": Color("#A884F3"),
		"shadebase": Color("#905EA9"),
		"deepshade": Color("#6B3E75")
	},
	500: { # White
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#FFFFFF"),
		"base": Color("#c7dcd0"),
		"shadebase": Color("#9babb2"),
		"deepshade": Color("#694f62")
	},
	0: { # Wild / Colorless
		"highlight": Color("#FFFFFF"),
		"lightbase": Color("#FDCBB0"),
		"base": Color("#AB947A"),
		"shadebase": Color("#966C6C"),
		"deepshade": Color("#3E3546")
	}
}

static func get_palette_for_color(c: int) -> Dictionary:
	var base_c: int = (c - (c % 100)) if c > 0 else 0
	return PALETTES.get(base_c, PALETTES[0])

static func get_base_family(c: int) -> int:
	return (c - (c % 100)) if c > 0 else 0

static func get_color_name(c: int) -> String:
	var base_c: int = get_base_family(c)
	match base_c:
		100: return "Red"
		200: return "Blue"
		300: return "Green"
		400: return "Purple"
		500: return "White"
		_: return "Wild"

@export var color: int = 100
@export var max_slots: int = DEFAULT_MAX_SLOTS
@export var ultimate_skill: Equipment = null
@export var equipped_modifiers: Array[Equipment] = []
@export var next_entry_cursor: int = 0

var activated_slot_flags: Array[bool] = [false, false, false, false, false]
var is_ultimate_active_for_cycle: bool = false
var ultimate_activated_this_cycle: bool = false

func _compact_null_entries() -> void:
	for i in range(equipped_modifiers.size() - 1, -1, -1):
		if equipped_modifiers[i] == null:
			equipped_modifiers.remove_at(i)

func get_cycle_length() -> int:
	_compact_null_entries()
	var total: int = equipped_modifiers.size()
	if ultimate_skill != null:
		total += 1
	return total

func clamp_cursor() -> void:
	var total: int = get_cycle_length()
	if total == 0:
		next_entry_cursor = 0
	else:
		next_entry_cursor = posmod(next_entry_cursor, total)

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
	return equipped_modifiers.size() + (1 if ultimate_skill != null else 0)

func can_fit(mod: Equipment) -> bool:
	return can_equip(mod)

func can_equip(mod: Equipment) -> bool:
	if mod == null:
		return false
	if not is_color_compatible(mod):
		return false
	if mod.is_ultimate:
		return ultimate_skill == null
	return get_used_slots() + clampi(mod.slot_cost, 1, max_slots) <= max_slots

func is_color_compatible(mod: Equipment) -> bool:
	if mod == null:
		return false
	if color == 0:
		return true
	return mod.is_allowed_on_color(color)

func equip_ultimate(mod: Equipment) -> bool:
	if mod == null or not mod.is_ultimate:
		return false
	if not is_color_compatible(mod):
		return false
	ultimate_skill = mod
	clamp_cursor()
	check_ultimate_ready_at_cycle_start()
	return true

func unequip_ultimate() -> Equipment:
	var old: Equipment = ultimate_skill
	ultimate_skill = null
	clamp_cursor()
	is_ultimate_active_for_cycle = false
	return old

func equip_modifier(mod: Equipment, insert_index: int = -1) -> bool:
	if mod == null or mod.is_ultimate:
		return false
	if not can_equip(mod):
		return false
	if insert_index >= 0 and insert_index < equipped_modifiers.size():
		equipped_modifiers.insert(insert_index, mod)
	else:
		equipped_modifiers.append(mod)
	clamp_cursor()
	check_ultimate_ready_at_cycle_start()
	return true

func unequip_modifier(mod: Equipment) -> bool:
	if mod != null and mod == ultimate_skill:
		unequip_ultimate()
		return true
	var idx: int = equipped_modifiers.find(mod)
	if idx != -1:
		equipped_modifiers.remove_at(idx)
		if idx < next_entry_cursor:
			next_entry_cursor = max(0, next_entry_cursor - 1)
		clamp_cursor()
		check_ultimate_ready_at_cycle_start()
		return true
	return false

func unequip_at(index: int) -> Equipment:
	if index == 0 and ultimate_skill != null and equipped_modifiers.is_empty():
		return unequip_ultimate()
	if index >= 0 and index < equipped_modifiers.size():
		var mod: Equipment = equipped_modifiers[index]
		equipped_modifiers.remove_at(index)
		if index < next_entry_cursor:
			next_entry_cursor = max(0, next_entry_cursor - 1)
		clamp_cursor()
		check_ultimate_ready_at_cycle_start()
		return mod
	return null

func get_slot_indices_for_modifier(mod: Equipment) -> Array[int]:
	var result: Array[int] = []
	var cur_slot: int = 0
	for m in equipped_modifiers:
		if m == null:
			continue
		var cost: int = clampi(m.slot_cost, 1, max_slots)
		if m == mod:
			for s in range(cost):
				if cur_slot + s < NORMAL_MAX_SLOTS:
					result.append(cur_slot + s)
			return result
		cur_slot += cost
	return result

func get_modifier_at_slot_index(slot_index: int) -> Equipment:
	var cur_slot: int = 0
	for m in equipped_modifiers:
		if m == null:
			continue
		var cost: int = clampi(m.slot_cost, 1, max_slots)
		if slot_index >= cur_slot and slot_index < cur_slot + cost:
			return m
		cur_slot += cost
	return null

func is_modifier_activated(mod: Equipment) -> bool:
	if mod == null:
		return false
	var cur_slot: int = 0
	var flag_count: int = activated_slot_flags.size()
	for m in equipped_modifiers:
		if m == null:
			continue
		var cost: int = clampi(m.slot_cost, 1, max_slots)
		if m == mod:
			var checked_any: bool = false
			for s in range(cost):
				var idx: int = cur_slot + s
				if idx < NORMAL_MAX_SLOTS and idx < flag_count:
					checked_any = true
					if not activated_slot_flags[idx]:
						return false
			return checked_any
		cur_slot += cost
	return false

func get_next_normal_entry() -> Equipment:
	if equipped_modifiers.is_empty():
		return null
	var total: int = equipped_modifiers.size()
	for offset in range(total):
		var idx: int = posmod(next_entry_cursor + offset, total)
		var candidate: Equipment = equipped_modifiers[idx]
		if candidate != null:
			var is_on_cd: bool = candidate.current_cooldown > 0 or (candidate.once_per_battle and candidate.used_this_battle)
			var is_used: bool = is_modifier_activated(candidate)
			if not is_on_cd and not is_used:
				return candidate
	return null

func check_ultimate_ready_at_cycle_start() -> void:
	if ultimate_skill == null:
		is_ultimate_active_for_cycle = false
		return
	if ultimate_skill.bypass_activation_check:
		is_ultimate_active_for_cycle = true
		return
	if get_used_slots() < NORMAL_MAX_SLOTS:
		is_ultimate_active_for_cycle = false
		return
	for m in equipped_modifiers:
		if m == null:
			is_ultimate_active_for_cycle = false
			return
		if m.current_cooldown > 0 or (m.once_per_battle and m.used_this_battle):
			is_ultimate_active_for_cycle = false
			return
	is_ultimate_active_for_cycle = true

func record_skill_activated(mod: Equipment) -> void:
	if mod == null or mod == ultimate_skill:
		return
	var cur_slot: int = 0
	var flag_count: int = activated_slot_flags.size()
	for m in equipped_modifiers:
		if m == null:
			continue
		var cost: int = clampi(m.slot_cost, 1, max_slots)
		if m == mod:
			for s in range(cost):
				var idx: int = cur_slot + s
				if idx < NORMAL_MAX_SLOTS and idx < flag_count:
					activated_slot_flags[idx] = true
			return
		cur_slot += cost

func record_ultimate_activated() -> void:
	ultimate_activated_this_cycle = true

func has_activatable_tiles() -> bool:
	if get_filled_entry_count() == 0:
		return false

	# 1. Check normal modifiers
	for mod in equipped_modifiers:
		if mod == null:
			continue
		if mod.current_cooldown > 0 or (mod.once_per_battle and mod.used_this_battle):
			continue
		if not is_modifier_activated(mod):
			return true

	# 2. Check ultimate skill
	if ultimate_skill != null and not ultimate_activated_this_cycle:
		if ultimate_skill.current_cooldown == 0 and not (ultimate_skill.once_per_battle and ultimate_skill.used_this_battle):
			if ultimate_skill.bypass_activation_check:
				return true
			elif is_ultimate_active_for_cycle and are_all_normal_slots_activated():
				return true

	return false

func are_all_normal_slots_activated() -> bool:
	if get_used_slots() < NORMAL_MAX_SLOTS:
		return false
	for flag in activated_slot_flags:
		if not flag:
			return false
	return true

func can_trigger_ultimate(ctx: MatchContext) -> bool:
	if ultimate_skill == null or ultimate_activated_this_cycle:
		return false
	if ultimate_skill.current_cooldown > 0 or (ultimate_skill.once_per_battle and ultimate_skill.used_this_battle):
		return false
	if not ultimate_skill.bypass_activation_check:
		if not is_ultimate_active_for_cycle:
			return false
	return ultimate_skill.can_trigger(ctx)

func reset_activation_cycle() -> void:
	tick_cooldowns(1)
	if activated_slot_flags.size() != NORMAL_MAX_SLOTS:
		activated_slot_flags.resize(NORMAL_MAX_SLOTS)
	activated_slot_flags.fill(false)
	ultimate_activated_this_cycle = false
	next_entry_cursor = 0
	check_ultimate_ready_at_cycle_start()

func get_normal_slot_visual_state(slot_index: int) -> NormalSlotVisualState:
	if slot_index < 0 or slot_index >= NORMAL_MAX_SLOTS:
		return NormalSlotVisualState.EMPTY
	var mod: Equipment = get_modifier_at_slot_index(slot_index)
	if mod == null:
		return NormalSlotVisualState.EMPTY
	if slot_index < activated_slot_flags.size() and activated_slot_flags[slot_index]:
		return NormalSlotVisualState.DARK
	if mod.current_cooldown > 0 or (mod.once_per_battle and mod.used_this_battle):
		return NormalSlotVisualState.DARK

	var next_mod: Equipment = get_next_normal_entry()
	if next_mod != null and mod == next_mod:
		return NormalSlotVisualState.NEXT

	return NormalSlotVisualState.NORMAL

func get_ultimate_visual_state() -> UltimateVisualState:
	if ultimate_skill == null:
		return UltimateVisualState.NO_ULTIMATE
	if is_ultimate_active_for_cycle and ultimate_skill.current_cooldown == 0 and not (ultimate_skill.once_per_battle and ultimate_skill.used_this_battle):
		return UltimateVisualState.ACTIVATED
	return UltimateVisualState.NORMAL

## Backward-compatibility helper for any legacy state calls
func get_slot_state(slot_index: int) -> int:
	return get_normal_slot_visual_state(slot_index) as int

## Calculates how many sequential equipment entries this match context triggers.
func get_trigger_budget(ctx: MatchContext) -> int:
	if ctx == null:
		return 1
	var count: int = max(3, ctx.match_count)
	var budget: int = max(1, count - 2)
	if ctx.shape_type in ["L_SHAPE", "T_SHAPE"]:
		budget += 1
	return budget

## Advances the chain by 1 step and returns the Equipment at the cursor before advancing.
## If there are no more activatable tiles, or if the chain wraps around to 0, a reset of the loadout automatically happens.
func step_next_entry() -> Equipment:
	if not has_activatable_tiles():
		reset_activation_cycle()

	clamp_cursor()
	var total: int = get_cycle_length()
	if total == 0:
		return null
	var idx: int = next_entry_cursor
	var next_idx: int = (idx + 1) % total
	next_entry_cursor = next_idx

	var mod: Equipment = null
	if idx < equipped_modifiers.size():
		mod = equipped_modifiers[idx]
	else:
		mod = ultimate_skill

	return mod

## Returns the Equipment currently at next_entry_cursor without advancing.
func get_next_entry() -> Equipment:
	clamp_cursor()
	var total: int = get_cycle_length()
	if total == 0:
		return null
	if next_entry_cursor < equipped_modifiers.size():
		return equipped_modifiers[next_entry_cursor]
	return ultimate_skill

## Pure preview of which slot indices will fire for a prospective MatchContext.
func peek_firing_indices(ctx: MatchContext, actor: Resource = null) -> Array[int]:
	var firing: Array[int] = []
	_compact_null_entries()
	var total: int = get_cycle_length()
	if total == 0 or ctx == null:
		return firing

	var budget: int = get_trigger_budget(ctx)
	var sim_cursor: int = posmod(next_entry_cursor, total)
	var sim_cooldowns: Dictionary = {}
	var sim_used: Dictionary = {}

	for i in range(equipped_modifiers.size()):
		var m: Equipment = equipped_modifiers[i]
		sim_cooldowns[i] = m.current_cooldown if m != null else 0
		sim_used[i] = m.used_this_battle if m != null else false
	if ultimate_skill != null:
		sim_cooldowns[-1] = ultimate_skill.current_cooldown
		sim_used[-1] = ultimate_skill.used_this_battle

	var remaining_budget: int = budget
	while remaining_budget > 0:
		var idx: int = sim_cursor
		sim_cursor = (sim_cursor + 1) % total
		if idx < equipped_modifiers.size():
			var mod: Equipment = equipped_modifiers[idx]
			if mod == null:
				remaining_budget -= 1
				continue
			if is_modifier_activated(mod):
				remaining_budget -= 1
				continue
			if mod.once_per_battle and sim_used.get(idx, false):
				remaining_budget -= 1
				continue
			if sim_cooldowns.get(idx, 0) > 0:
				remaining_budget -= 1
				continue
			var cost: int = mod.get_trigger_cost() if mod.has_method("get_trigger_cost") else 1
			if remaining_budget >= cost and mod.can_trigger(ctx):
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
				remaining_budget -= cost
			else:
				remaining_budget -= 1
		elif ultimate_skill != null:
			var ult: Equipment = ultimate_skill
			if ultimate_activated_this_cycle:
				remaining_budget -= 1
				continue
			if ult.once_per_battle and sim_used.get(-1, false):
				remaining_budget -= 1
				continue
			if sim_cooldowns.get(-1, 0) > 0:
				remaining_budget -= 1
				continue
			var ready: bool = ult.bypass_activation_check or is_ultimate_active_for_cycle
			var cost: int = ult.get_trigger_cost() if ult.has_method("get_trigger_cost") else 1
			if ready and remaining_budget >= cost and ult.can_trigger(ctx):
				if not firing.has(-1):
					firing.append(-1)
				remaining_budget -= cost
			else:
				remaining_budget -= 1

	return firing

func reset_for_battle() -> void:
	next_entry_cursor = 0
	if activated_slot_flags.size() != NORMAL_MAX_SLOTS:
		activated_slot_flags.resize(NORMAL_MAX_SLOTS)
	activated_slot_flags.fill(false)
	ultimate_activated_this_cycle = false
	for mod in equipped_modifiers:
		if mod != null:
			mod.reset_for_battle()
	if ultimate_skill != null:
		ultimate_skill.reset_for_battle()
	check_ultimate_ready_at_cycle_start()

func tick_cooldowns(amount: int = 1) -> void:
	for mod in equipped_modifiers:
		if mod != null:
			mod.tick_cooldown(amount)
	if ultimate_skill != null:
		ultimate_skill.tick_cooldown(amount)
