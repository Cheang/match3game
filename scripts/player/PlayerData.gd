extends Node

var cur_char: PlayerResource

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
	if cur_char != null:
		max_health = cur_char.max_health
		cur_health = cur_char.max_health
		speed = cur_char.speed
		mana = cur_char.mana
		sprite = cur_char.sprite
		deck = cur_char.deck
		fluf = cur_char.fluf
		crit_chanse = cur_char.crit_chanse
		crit_dmg = cur_char.crit_dmg
		dmg = cur_char.dmg
		fluf_dmg = cur_char.fluf_dmg
		life_steal = cur_char.life_steal

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
