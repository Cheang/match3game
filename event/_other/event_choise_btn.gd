extends PanelContainer

const CHOISE_BTN_D = preload("res://event/_other/choise_btn_d.tres")
const CHOISE_BTN_N = preload("res://event/_other/choise_btn_n.tres")

@onready var btn: Button = $btn
@onready var sound: AudioStreamPlayer = $sound

@onready var description: RichTextLabel = $MarginContainer/VBoxContainer/description
@onready var title: Label = $MarginContainer/VBoxContainer/title

var resource: EventChoise

func set_btn():
	if resource != null:
		title.text = resource.text
		if resource.description == "None":
			description.visible = false
		else:
			description.visible = true
			description.text = resource.description
		if resource.gold_cost > 0:
			if resource.gold_cost > Global.cur_char.gold:
				btn.disabled = true
				self.add_theme_stylebox_override("panel", CHOISE_BTN_D)
				title.add_theme_color_override("font_color", Color8(127, 112, 138))
				description.add_theme_color_override("default_color", Color8(127, 112, 138))
			else: 
				btn.disabled = false
				self.add_theme_stylebox_override("panel", CHOISE_BTN_N)
				title.add_theme_color_override("font_color", Color8(55, 78, 74))
				description.add_theme_color_override("default_color", Color8(84, 126, 100))

signal reward_requested(texture: Texture2D, text: String, icon: Texture2D, description: String)
signal next_event_requested(next_event: Event)

func _matches_piece_filter(mod: Equipment, filter_str: String, blacklist_str: String) -> bool:
	if mod == null:
		return false
	if blacklist_str != "" and mod.piece_name == blacklist_str:
		return false
	var target_lower: String = filter_str.to_lower()
	if mod.piece_name.to_lower() == target_lower:
		return true
	for c in mod.get_effective_allowed_colors():
		if Global.get_color_name(c).to_lower() == target_lower:
			return true
	return false

func _remove_matching_modifiers(filter_str: String, blacklist_str: String, max_to_remove: int) -> int:
	if Global.cur_char == null:
		return 0
	var removed_count: int = 0
	Global.cur_char.ensure_loadout_tracks()
	for k in Global.cur_char.color_loadouts.keys():
		var track: ColorLoadoutTrack = Global.cur_char.color_loadouts[k]
		if track == null:
			continue
		var idx: int = 0
		while idx < track.equipped_modifiers.size():
			var mod: Equipment = track.equipped_modifiers[idx]
			if _matches_piece_filter(mod, filter_str, blacklist_str):
				track.equipped_modifiers.remove_at(idx)
				removed_count += 1
				if max_to_remove != 0 and removed_count >= max_to_remove:
					Global.cur_char.loadoutChanged.emit()
					return removed_count
			else:
				idx += 1

	var inv_idx: int = 0
	while inv_idx < Global.cur_char.modifier_inventory.size():
		var mod: Equipment = Global.cur_char.modifier_inventory[inv_idx]
		if _matches_piece_filter(mod, filter_str, blacklist_str):
			Global.cur_char.modifier_inventory.remove_at(inv_idx)
			removed_count += 1
			if max_to_remove != 0 and removed_count >= max_to_remove:
				break
		else:
			inv_idx += 1
	Global.cur_char.loadoutChanged.emit()
	return removed_count

func _on_btn_pressed() -> void:
	if Global.game_is_played == true:
		if resource.gold_cost > 0:
			Global.cur_char.modify_stat("gold", -resource.gold_cost)
		if resource.req_piece_remove:
			Global.event_pieces_removed = _remove_matching_modifiers(
				resource.req_piece_name,
				resource.req_piece_remove_blacklist,
				resource.req_piece_numb
			)
		if resource.failable and resource.req_stat != "None" and resource.fail_state and resource.req_value > 0:
			var stat_to_check = Global.cur_char.get(resource.req_stat)
			if stat_to_check < resource.req_value:
				var new_resource: EventChoise = resource.fail_state
				resource = new_resource
		match resource.type:
			1:
				pass
			2:
				pass
			3:
				_show_reward(resource.reward.base, resource.reward.name, resource.reward.icon, resource.reward.description)
				var mods: Array[Equipment] = resource.reward.get_resolved_modifiers() if (resource.reward != null and resource.reward.has_method("get_resolved_modifiers")) else []
				if not mods.is_empty():
					resource.reward.apply_progression()
					var modal := SlotEquipModal.new()
					get_tree().current_scene.add_child(modal)
					modal.prompt_modifiers(mods)
					await modal.modal_closed
					if resource is EvtChoiseReward:
						var evt_rew: EvtChoiseReward = resource as EvtChoiseReward
						if evt_rew.fight_overwrite and not evt_rew.enemy.is_empty():
							Global.post_combat_event = evt_rew.next_event
							Global.set_up_enemy(evt_rew.enemy.pick_random())
							SceneManager.change_scene("res://game_window.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
							return
						if evt_rew.next_event != null:
							var screen = find_parent("event_screen")
							if screen and screen.has_method("display_event"):
								screen.display_event(evt_rew.next_event, true)
								return
						SceneManager.change_scene(evt_rew.next_scene if evt_rew.next_scene != "" else "res://locations_screen.tscn", { "pattern": "diagonal", "color": Color('#2e222f') })
						return
				await get_tree().create_timer(1.5).timeout
				if resource is EvtChoiseReward and resource.next_event != null:
					resource.handled_in_place = true
					next_event_requested.emit(resource.next_event)
					var screen = find_parent("event_screen")
					if screen and screen.has_method("display_event"):
						screen.display_event(resource.next_event, true)
						return
			4:
				if resource is EvtChoiseEvent and resource.next_event != null:
					resource.handled_in_place = true
					next_event_requested.emit(resource.next_event)
					var screen = find_parent("event_screen")
					if screen and screen.has_method("display_event"):
						screen.display_event(resource.next_event, true)
						return
		resource.activate()

func _show_reward(texture: Texture2D, text: String, icon: Texture2D, desc: String) -> void:
	reward_requested.emit(texture, text, icon, desc)
	var screen = find_parent("event_screen")
	if screen and screen.has_method("get_reward"):
		screen.get_reward(texture, text, icon, desc)
