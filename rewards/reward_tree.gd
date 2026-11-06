extends Resource
class_name RewardTree

@export_group("Tree Configuration")
## Display name of this reward tree (e.g. "Warrior Arsenal", "Arcane Paths").
@export var tree_name: String = "Default Reward Tree"
## Starting cards/equipment available in standard combat reward drafts from the start of the run.
@export var starting_combat_rewards: Array[Resource] = []
## Starting cards/equipment available in post-boss passive/talent reward drafts.
@export var starting_passive_rewards: Array[Resource] = []
## Visual progression nodes representing branching paths and conditional unlocks.
@export var nodes: Array[RewardTreeNode] = []

# ==============================================================================
# RUNTIME PROGRESSION STATE
# ==============================================================================
var active_combat_pool: Array[Resource] = []
var active_passive_pool: Array[Resource] = []
var unlocked_tags: Dictionary = {}
var activated_node_ids: Dictionary = {}

## Initializes active pools at the start of a player run.
func initialize_run(_player = null) -> void:
	active_combat_pool.clear()
	active_passive_pool.clear()
	unlocked_tags.clear()
	activated_node_ids.clear()

	for r in starting_combat_rewards:
		if r != null:
			active_combat_pool.append(r)

	for r in starting_passive_rewards:
		if r != null:
			active_passive_pool.append(r)

## Called when any reward card or direct Equipment is chosen by the player.
func on_reward_chosen(reward: Resource, _player = null) -> void:
	if reward == null:
		return

	var tpl: Resource = RewardGrantHandler.get_source_template(reward)

	# Record tags emitted by this reward or its template
	var tags = reward.get("unlock_tags")
	if tags is Array:
		for tag in tags:
			unlocked_tags[str(tag)] = true
	if tpl != reward and tpl != null:
		var tpl_tags = tpl.get("unlock_tags")
		if tpl_tags is Array:
			for tag in tpl_tags:
				unlocked_tags[str(tag)] = true

	# Remove reward from pool if configured
	var rem = reward.get("remove_from_pool_when_picked")
	if rem == null and tpl != null:
		rem = tpl.get("remove_from_pool_when_picked")
	if rem == null or rem == true:
		active_combat_pool.erase(reward)
		active_passive_pool.erase(reward)
		if tpl != null:
			active_combat_pool.erase(tpl)
			active_passive_pool.erase(tpl)
		var id_key: String = RewardGrantHandler.get_identity_key(reward)
		if id_key != "":
			for i in range(active_combat_pool.size() - 1, -1, -1):
				if RewardGrantHandler.get_identity_key(active_combat_pool[i]) == id_key:
					active_combat_pool.remove_at(i)
			for i in range(active_passive_pool.size() - 1, -1, -1):
				if RewardGrantHandler.get_identity_key(active_passive_pool[i]) == id_key:
					active_passive_pool.remove_at(i)

	# Evaluate progression nodes to unlock new branches
	check_progression()

## Evaluates all nodes in the tree and unlocks any whose requirements have been met.
func check_progression() -> void:
	var newly_activated := false

	for node in nodes:
		if node == null:
			continue
		var n_id = str(node.get("id"))
		if n_id == "" or activated_node_ids.has(n_id):
			continue

		var satisfied := true
		var reqs = node.get("required_tags")
		if reqs is Array:
			for req in reqs:
				if not unlocked_tags.has(str(req)):
					satisfied = false
					break

		if satisfied:
			activated_node_ids[n_id] = true
			newly_activated = true

			# Unlock new rewards into active pools
			var unl = node.get("unlocked_rewards")
			if unl is Array:
				for rew in unl:
					if rew != null:
						var cat = rew.get("category")
						if cat != null and int(cat) == 1:
							if not active_passive_pool.has(rew):
								active_passive_pool.append(rew)
						else:
							if not active_combat_pool.has(rew):
								active_combat_pool.append(rew)

			# Remove pruned rewards from active pools
			var rem = node.get("removed_rewards")
			if rem is Array:
				for rew in rem:
					if rew != null:
						active_combat_pool.erase(rew)
						active_passive_pool.erase(rew)

	# Recurse if new nodes activated downstream tags
	if newly_activated:
		check_progression()

## Returns all currently available combat rewards for draft generation.
func get_combat_pool() -> Array[Resource]:
	if active_combat_pool.is_empty() and not starting_combat_rewards.is_empty():
		initialize_run()
	return active_combat_pool

## Returns all currently available passive rewards for draft generation.
func get_passive_pool() -> Array[Resource]:
	if active_passive_pool.is_empty() and not starting_passive_rewards.is_empty():
		initialize_run()
	return active_passive_pool
