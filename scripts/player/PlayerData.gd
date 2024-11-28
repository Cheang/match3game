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
var marked_this_turn_blue: float
var marked_this_turn_green: float
var marked_this_turn_purple: float
var marked_this_turn_white: float


func set_player_stats():
	if resource != null:
		max_health = resource.health
		cur_health = resource.health
		speed = resource.speed
		mana = resource.mana
		sprite = resource.sprite
		deck = resource.deck
		fluf = resource.fluf
		crit_chanse = resource.crit_chanse
		crit_dmg = resource.crit_dmg
		dmg = resource.dmg
		fluf_dmg = resource.fluf_dmg
		life_steal = resource.life_steal

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
