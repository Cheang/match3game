extends RefCounted
class_name RewardGrantHandler

## Unified adapter and build-affinity selector for Reward resources and direct Equipment resources.

## Bonus weight multiplier added per matching family item equipped on the player.
const BUILD_AFFINITY_WEIGHT_PER_ITEM: float = 0.75

static func is_supported_reward(res: Resource) -> bool:
	return res is Reward or res is Equipment

static func normalize_to_reward(res: Resource, rolled_rarity_name: String = "") -> Reward:
	if res == null:
		return null
	if res is Reward:
		var r := res as Reward
		if rolled_rarity_name != "":
			var dup_r: Reward = r.duplicate(true)
			dup_r.rearity = rolled_rarity_name
			dup_r.source_template = r.source_template if r.source_template != null else r
			return dup_r
		return r
	if res is Equipment:
		var eq := res as Equipment
		var r_enum: int = int(rarity_name_to_equipment_enum(rolled_rarity_name)) if rolled_rarity_name != "" else int(eq.rarity)
		return Reward.from_equipment(eq, r_enum)
	return null

static func get_reward_type(res: Resource) -> Reward.RewardType:
	if res is Reward:
		return (res as Reward).get_effective_reward_type()
	if res is Equipment:
		return Reward.RewardType.EQUIPMENT
	return Reward.RewardType.EQUIPMENT

static func get_family(res: Resource) -> String:
	if res == null:
		return ""
	if res is Reward:
		return (res as Reward).get_effective_family()
	if res is Equipment:
		return (res as Equipment).family.to_lower()
	var fam = res.get("family")
	return str(fam).to_lower() if fam != null else ""

static func get_drop_weight(res: Resource) -> float:
	if res == null:
		return 1.0
	if res is Reward:
		return maxf(0.01, (res as Reward).drop_weight)
	var w = res.get("drop_weight")
	if w != null:
		return maxf(0.01, float(w))
	return 1.0

static func can_be_offered_to(res: Resource, player: Object) -> bool:
	if res == null:
		return false
	if player == null:
		return true
	if res is Reward:
		var rew := res as Reward
		if not rew.meets_requirements(player):
			return false
		if rew.is_already_unlocked(player):
			return false
	return true

## Computes the selection weight for a candidate reward, optionally boosted by the player's build affinity.
static func compute_selection_weight(res: Resource, player: Object = null, use_build_affinity: bool = false) -> float:
	var base_w: float = get_drop_weight(res)
	if not use_build_affinity or player == null:
		return base_w
	var fam: String = get_family(res)
	if fam == "":
		return base_w
	var family_counts: Dictionary = {}
	if player.has_method("get_build_family_counts"):
		family_counts = player.get_build_family_counts()
	var count: int = int(family_counts.get(fam, 0))
	if count <= 0:
		return base_w
	return base_w * (1.0 + BUILD_AFFINITY_WEIGHT_PER_ITEM * float(count))

## Picks a single candidate from `candidates` using weighted random selection.
static func pick_weighted_candidate(candidates: Array[Resource], player: Object = null, use_build_affinity: bool = false) -> Resource:
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]

	var weights: Array[float] = []
	var total_weight: float = 0.0
	for cand in candidates:
		var w: float = compute_selection_weight(cand, player, use_build_affinity)
		weights.append(w)
		total_weight += w

	if total_weight <= 0.0:
		return candidates[randi() % candidates.size()]

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for i in range(candidates.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return candidates[i]
	return candidates[candidates.size() - 1]

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
	if res is Reward:
		return (res as Reward).get_display_name()
	if res is Equipment:
		var eq := res as Equipment
		if eq.piece_name != "":
			return eq.piece_name
		return eq.resource_path.get_file().get_basename()
	var n = res.get("name")
	if n != null and str(n) != "":
		return str(n)
	return res.resource_path.get_file().get_basename()

static func get_icon(res: Resource) -> Texture2D:
	if res == null:
		return null
	if res is Reward:
		return (res as Reward).get_display_icon()
	if "icon" in res:
		return res.icon
	return null

static func get_base_texture(res: Resource) -> Texture2D:
	if res == null:
		return null
	if res is Reward:
		return (res as Reward).get_display_base()
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
	if res.get_class() != "ScriptPlaceholderResource" and res.has_method("get_effect_description"):
		return res.get_effect_description()
	if "description" in res:
		return str(res.description)
	return ""

static func get_source_template(res: Resource) -> Resource:
	if res == null:
		return null
	if res is Equipment and (res as Equipment).source_template != null:
		return (res as Equipment).source_template
	if res is Reward and (res as Reward).source_template != null:
		return (res as Reward).source_template
	return res

static func get_identity_key(res: Resource) -> String:
	if res == null:
		return ""
	var tpl: Resource = get_source_template(res)
	if tpl.resource_path != "":
		return tpl.resource_path
	return "%s:%s" % [tpl.get_class(), get_display_name(tpl)]

static func can_roll_at_rarity(res: Resource, rolled_rarity_name: String) -> bool:
	if res == null:
		return false
	var target_r: int = int(rarity_name_to_equipment_enum(rolled_rarity_name))
	if res is Reward:
		return (res as Reward).can_roll_at_rarity(target_r)
	if res is Equipment:
		return (res as Equipment).can_roll_at_rarity(target_r)
	return get_rarity_name(res) == rolled_rarity_name.to_upper()

## Creates a non-mutating draft presentation instance for a reward slot.
## Both Reward and direct Equipment resources receive an independent instance rolled/clamped to `rolled_rarity_name`.
static func prepare_draft_instance(res: Resource, rolled_rarity_name: String = "COMMON") -> Resource:
	if res == null:
		return null
	var target_enum: Equipment.Rarity = rarity_name_to_equipment_enum(rolled_rarity_name)
	if res is Equipment:
		var eq := res as Equipment
		return eq.duplicate_with_rarity(target_enum)
	if res is Reward:
		var rew := res as Reward
		return rew.duplicate_with_rarity(int(target_enum) as Reward.Rarity)
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
		if p.has_method("on_reward_chosen"):
			p.on_reward_chosen(eq)
		return

	if res is Reward:
		var rew := res as Reward
		rew.apply_to_player(p, grant_equipment)
		return

	push_error("Unsupported reward resource type: %s" % [res.get_class()])
