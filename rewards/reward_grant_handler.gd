extends RefCounted
class_name RewardGrantHandler

## Unified adapter for direct Equipment resources and non-equipment/bundle Reward resources.

static func is_supported_reward(res: Resource) -> bool:
	return res is Equipment or res is Reward

static func rarity_name_to_equipment_enum(r_name: String) -> Equipment.Rarity:
	match r_name.to_upper():
		"COMMON": return Equipment.Rarity.COMMON
		"UNCOMMON": return Equipment.Rarity.UNCOMMON
		"RARE": return Equipment.Rarity.RARE
		"EPIC": return Equipment.Rarity.EPIC
		"LEGENDARY": return Equipment.Rarity.LEGENDARY
		"GODLY": return Equipment.Rarity.GODLY
	return Equipment.Rarity.COMMON

static func get_rarity_name(res: Resource) -> String:
	if res == null:
		return "COMMON"
	if res is Equipment:
		return (res as Equipment).rearity
	if res is Reward:
		return (res as Reward).rearity
	var r = res.get("rearity")
	if r != null and str(r) != "":
		return str(r).to_upper()
	return "COMMON"

static func get_display_name(res: Resource) -> String:
	if res == null:
		return ""
	if res is Equipment:
		var eq := res as Equipment
		if eq.piece_name != "":
			return eq.piece_name
		return eq.resource_path.get_file().get_basename()
	if res is Reward:
		var rew := res as Reward
		if rew.name != "":
			return rew.name
		return rew.resource_path.get_file().get_basename()
	var n = res.get("name")
	if n != null and str(n) != "":
		return str(n)
	return res.resource_path.get_file().get_basename()

static func get_icon(res: Resource) -> Texture2D:
	if res == null:
		return null
	if "icon" in res:
		return res.icon
	return null

static func get_base_texture(res: Resource) -> Texture2D:
	if res == null:
		return null
	if res is Equipment:
		return (res as Equipment).base
	if "base" in res and res.base != null:
		return res.base
	if not Engine.is_editor_hint() and is_instance_valid(Global) and ("get_color_base_texture" in Global):
		return Global.get_color_base_texture(0)
	return preload("res://assets/white_0_sq.png")

static func get_description(res: Resource) -> String:
	if res == null:
		return ""
	if res.has_method("get_effect_description"):
		return res.get_effect_description()
	if "description" in res:
		return str(res.description)
	return ""

static func get_source_template(res: Resource) -> Resource:
	if res == null:
		return null
	if res is Equipment and (res as Equipment).source_template != null:
		return (res as Equipment).source_template
	return res

static func get_identity_key(res: Resource) -> String:
	if res == null:
		return ""
	var tpl: Resource = get_source_template(res)
	if tpl.resource_path != "":
		return tpl.resource_path
	return "%s:%s" % [tpl.get_class(), get_display_name(tpl)]

## Creates a non-mutating draft presentation instance for a reward slot.
## Direct Equipment resources receive an independent instance rolled to `rolled_rarity_name`.
static func prepare_draft_instance(res: Resource, rolled_rarity_name: String = "COMMON") -> Resource:
	if res == null:
		return null
	if res is Equipment:
		var eq := res as Equipment
		var target_enum: Equipment.Rarity = rarity_name_to_equipment_enum(rolled_rarity_name)
		return eq.duplicate_with_rarity(target_enum)
	return res

static func get_resolved_modifiers(res: Resource) -> Array[Equipment]:
	var mods: Array[Equipment] = []
	if res == null:
		return mods
	if res is Equipment:
		var eq := res as Equipment
		mods.append(eq.duplicate_with_rarity(eq.rarity))
		return mods
	if res.has_method("get_resolved_modifiers"):
		return res.get_resolved_modifiers()
	return mods

## Grants the chosen reward to `player` (defaults to Global.cur_char).
## If `grant_equipment` is false, assumes equipment items were already handled by SlotEquipModal.
static func grant_reward(res: Resource, grant_equipment: bool = true, player: PlayerResource = null) -> void:
	if res == null:
		push_error("RewardGrantHandler.grant_reward called with null resource.")
		return
	var p: PlayerResource = player
	if p == null and not Engine.is_editor_hint() and is_instance_valid(Global) and ("cur_char" in Global):
		p = Global.cur_char
	if p == null:
		return

	if res is Equipment:
		var eq := res as Equipment
		if grant_equipment:
			var owned_copy: Equipment = eq.duplicate_with_rarity(eq.rarity)
			p.add_modifier_reward(owned_copy, true)
		for tag in eq.unlock_tags:
			p.set_flag(tag, true)
		if p.active_reward_tree != null:
			p.active_reward_tree.on_reward_chosen(eq, p)
		var tpl: Resource = get_source_template(eq)
		if eq.remove_from_pool_when_picked and p.rewards_piece != null:
			p.rewards_piece.erase(eq)
			p.rewards_piece.erase(tpl)
		return

	if res is Reward:
		var rew := res as Reward
		if not Engine.is_editor_hint() and is_instance_valid(Global) and ("cur_char" in Global) and p == Global.cur_char:
			rew.activate(grant_equipment)
		else:
			# Direct application on explicit PlayerResource (e.g. in isolated tests)
			if rew.might != 0.0: p.modify_stat("might", rew.might)
			if rew.grit != 0.0: p.modify_stat("grit", rew.grit)
			if rew.spirit != 0.0: p.modify_stat("spirit", rew.spirit)
			if rew.speed != 0: p.modify_stat("speed", rew.speed)
			if rew.max_health != 0.0: p.modify_stat("max_health", rew.max_health)
			if rew.heal_hp != 0.0: p.modify_stat("cur_health", rew.heal_hp)
			if rew.gold != 0: p.modify_stat("gold", rew.gold)
			if rew.rerolls != 0: p.modify_stat("rerolls", rew.rerolls)
			if rew.crit_chance != 0: p.modify_stat("crit_chance", rew.crit_chance)
			if rew.unlock_row_bombs: p.set_flag("flg_can_spawn_row_bombs", true)
			if rew.unlock_col_bombs: p.set_flag("flg_can_spawn_col_bombs", true)
			if rew.unlock_adj_bombs: p.set_flag("flg_can_spawn_adj_bombs", true)
			for f in rew.custom_flags:
				p.set_flag(f, true)
			if grant_equipment:
				for eq_item in rew.get_resolved_modifiers():
					p.add_modifier_reward(eq_item, true)
			if p.active_reward_tree != null:
				p.active_reward_tree.on_reward_chosen(rew, p)
		return

	push_error("Unsupported reward resource type: %s" % [res.get_class()])
