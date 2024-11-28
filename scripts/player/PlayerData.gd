extends Node

var resource: PlayerResource

#stats that are set
var max_health: float 
var speed: int 
var mana: float 
var sprite: PackedScene
var deck: Array[PackedScene]
var fluf: Array[PackedScene]
var crit_chanse: int 
var crit_dmg: float 
var dmg: float 
var fluf_dmg: float 
var life_steal: float

#stats that are aquiered 
var cur_health: float
var armor: float 
var mage_armor: float 

#marked
var marked_this_turn_all: float
var marked_this_turn_red: float


func set_player_stats(player: PlayerResource):
	if player != null:
		resource = player
		max_health = player.health
		cur_health = player.health
		speed = player.speed
		mana = player.mana
		sprite = player.sprite
		deck = player.deck
		fluf = player.fluf
		crit_chanse = player.crit_chanse
		crit_dmg = player.crit_dmg
		dmg = player.dmg
		fluf_dmg = player.fluf_dmg
		life_steal = player.life_steal

func take_damage(enemy_damage, piercing: bool = false):
	if !piercing:
		var temp
		temp = armor - enemy_damage 
		if temp >= 0:
			armor = temp
		else:
			armor = 0
			temp = mage_armor + temp
			if temp >= 0:
				mage_armor = temp
			else:
				mage_armor = 0
				cur_health += temp
	else:
		var temp
		temp = mage_armor - enemy_damage
		if temp >= 0:
			mage_armor = temp
		else:
			mage_armor = 0
			cur_health += temp
