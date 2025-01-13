extends Resource
class_name Reward

@export_category("General")
@export var name: String
@export_multiline var description: String
@export var base: Texture2D
@export var icon: Texture2D

@export_category("Boosts")
@export var passive_boost: Array[String]
@export var piece_boost: Array[String]
@export var boost_self: bool = false

@export_category("Rarity")
@export_enum("COMMON", "UNCOMMON", "RARE", "LEGENDARY") var rearity: String = "COMMON"

func activate():
	pass

func boost():
	if !passive_boost.is_empty():
		var rewards: Array[Reward] = []
		for nm in passive_boost:
			var reward: Reward = load("res://rewards/passives/%s.tres" % nm)
			rewards.append(reward)
		Global.cur_char.add_piece(Global.cur_char.rewards_passive, rewards)
	if !piece_boost.is_empty():
		var rewards: Array[Reward] = []
		for nm in piece_boost:
			var reward: Reward = load("res://rewards/pieces/%s.tres" % nm)
			rewards.append(reward)
		Global.cur_char.add_piece(Global.cur_char.rewards_piece, rewards)
	if boost_self:
		Global.cur_char.rewards_piece.append(self)
