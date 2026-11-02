@tool
extends Control
class_name AttackDock

func _ready() -> void:
	if not Engine.is_editor_hint():
		if Global.cur_enemy != null:
			refresh_tracks(Global.cur_enemy)

func get_diamond_slots() -> Array[MonsterTrackDiamond]:
	var list: Array[MonsterTrackDiamond] = []
	for child in get_children():
		if child is MonsterTrackDiamond:
			list.append(child)
	return list

func refresh_tracks(enemy_res: EnemyResource) -> void:
	var slots: Array[MonsterTrackDiamond] = get_diamond_slots()
	if slots.is_empty():
		return

	if enemy_res == null:
		for s in slots:
			s.visible = false
		return

	enemy_res.ensure_loadout_tracks()

	# Collect all tracks the enemy possesses (up to slots.size(), max 7)
	var active_tracks: Array[Dictionary] = []

	var standard_colors: Array[int] = [100, 200, 300, 400, 500]
	for c in standard_colors:
		if enemy_res.color_loadouts.has(c):
			var tr: ColorLoadoutTrack = enemy_res.color_loadouts[c]
			if tr != null and not tr.equipped_modifiers.is_empty():
				active_tracks.append({ "color": c, "modifiers": tr.equipped_modifiers })

	# Fallback / wild track
	if enemy_res.colorless_fallback_track != null and not enemy_res.colorless_fallback_track.equipped_modifiers.is_empty():
		active_tracks.append({ "color": 0, "modifiers": enemy_res.colorless_fallback_track.equipped_modifiers })
	elif active_tracks.is_empty():
		var default_eq := Equipment.new()
		default_eq.piece_name = enemy_res.name + " Attack"
		default_eq.base_damage = max(1.0, enemy_res.damage)
		active_tracks.append({ "color": 0, "modifiers": [default_eq] })

	# Populate pre-positioned slots from the editor
	for i in range(slots.size()):
		var slot: MonsterTrackDiamond = slots[i]
		if i < active_tracks.size():
			slot.visible = true
			var data: Dictionary = active_tracks[i]
			slot.setup_track(data.color, data.modifiers)
		else:
			# Hide unassigned slots during gameplay
			slot.visible = false
