class_name EvtChoiseEvent
extends EventChoise

@export var next_event: Event

var type: int = 4
var handled_in_place: bool = false


func activate() -> void:
	if handled_in_place:
		handled_in_place = false
		return
	Global.game_is_played = false
	Global.area_cur_event = next_event
	SceneManager.change_scene("res://events/event_screen.tscn", { "pattern": "diagonal", "color": Color("#2e222f"), "skip_fade_out": true, "skip_fade_in": true })

