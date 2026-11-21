class_name MoraleEngine
extends RefCounted


static func evaluate_trapped_arrays(
	enemy_at_dir: Array[bool],
	impassable_at_dir: Array[bool]
) -> int:
	if enemy_at_dir.size() != 6 or impassable_at_dir.size() != 6:
		return 0

	var adjacent_enemies: int = 0
	var blocked_dirs: int = 0

	for d: int in range(6):
		if enemy_at_dir[d]:
			adjacent_enemies += 1
			blocked_dirs += 1
		elif impassable_at_dir[d]:
			blocked_dirs += 1

	if adjacent_enemies < 2 or blocked_dirs <= 1:
		return 0

	if blocked_dirs == 6:
		return 3

	var has_pincer_180: bool = false
	for d: int in range(3):
		if enemy_at_dir[d] and enemy_at_dir[d + 3]:
			has_pincer_180 = true
			break

	if has_pincer_180 or (adjacent_enemies >= 3 and blocked_dirs >= 4):
		return 2

	return 1


func evaluate_unit_trapped_level(
	map_state: BattleMapState,
	unit: BattleUnit
) -> int:
	if map_state == null or unit == null or not unit.state.is_alive():
		return 0

	var enemy_at_dir: Array[bool] = [false, false, false, false, false, false]
	var impassable_at_dir: Array[bool] = [false, false, false, false, false, false]

	for d: int in range(6):
		var adj: Vector2i = unit.hex_position + HexMath.AXIAL_DIRECTIONS[d]
		if not map_state.is_valid_hex(adj):
			impassable_at_dir[d] = true
			continue

		var occ: BattleUnit = map_state.get_unit_at(adj)
		if occ != null and map_state.is_hostile(unit.faction_id, occ.faction_id):
			if occ.state.emits_zoc():
				enemy_at_dir[d] = true
				continue
			# Even a CHAOS enemy occupies the tile physically (impassable to step onto)
			impassable_at_dir[d] = true
			continue

		var base_mp: int = map_state.get_base_terrain_mp(map_state.get_terrain(adj), unit)
		if base_mp >= BattleMapState.IMPASSABLE_MP:
			impassable_at_dir[d] = true

	return evaluate_trapped_arrays(enemy_at_dir, impassable_at_dir)


func apply_immediate_trapped_effects(map_state: BattleMapState) -> Array[int]:
	var newly_chaosed_ids: Array[int] = []
	var units: Array[BattleUnit] = _get_sorted_units(map_state)
	for u: BattleUnit in units:
		var lv: int = evaluate_unit_trapped_level(map_state, u)
		if lv >= 2 and u.state.morale != UnitCombatState.MoraleLevel.CHAOS and not u.state.is_morale_locked:
			u.state.apply_chaos(1)
			newly_chaosed_ids.append(u.unit_id)
	return newly_chaosed_ids


func _has_adjacent_dead_mate_immunity(map_state: BattleMapState, unit: BattleUnit) -> bool:
	for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
		var adj: Vector2i = unit.hex_position + dir
		if not map_state.is_valid_hex(adj):
			continue
		var ally: BattleUnit = map_state.get_unit_at(adj)
		if ally != null and map_state.is_allied(unit.faction_id, ally.faction_id):
			if ally.grants_dead_mate_immunity and ally.state.emits_zoc():
				return true
	return false


func on_unit_defeated(
	map_state: BattleMapState,
	killer: BattleUnit,
	defeated: BattleUnit,
	defeated_hex: Vector2i
) -> void:
	if map_state == null or defeated == null:
		return

	var units: Array[BattleUnit] = _get_sorted_units(map_state)
	var rewarded_ids: Dictionary[int, bool] = {}

	# 1. Killer & allied General-kill morale boost (+1 tier, max HIGH)
	if killer != null and killer.state.is_alive():
		killer.state.shift_morale(1)
		rewarded_ids[killer.unit_id] = true

	if defeated.general_id > 0 and killer != null:
		for u: BattleUnit in units:
			if rewarded_ids.has(u.unit_id):
				continue
			if map_state.is_allied(killer.faction_id, u.faction_id):
				if HexMath.hex_distance(u.hex_position, defeated_hex) <= 2:
					u.state.shift_morale(1)
					rewarded_ids[u.unit_id] = true

	# 2. Defeated faction morale shock (-1 tier)
	if defeated.general_id > 0:
		var shock_radius: int = 3 if defeated.is_commander_in_chief else 2
		for u: BattleUnit in units:
			if map_state.is_allied(defeated.faction_id, u.faction_id):
				if HexMath.hex_distance(u.hex_position, defeated_hex) <= shock_radius:
					u.state.shift_morale(-1)
	else:
		for u: BattleUnit in units:
			if map_state.is_allied(defeated.faction_id, u.faction_id):
				if HexMath.hex_distance(u.hex_position, defeated_hex) == 1:
					if not _has_adjacent_dead_mate_immunity(map_state, u):
						u.state.shift_morale(-1)


func process_faction_turn_end(map_state: BattleMapState, faction_id: int) -> void:
	var units: Array[BattleUnit] = _get_sorted_units(map_state)
	for u: BattleUnit in units:
		if u.faction_id != faction_id:
			continue
		var trapped_lv: int = evaluate_unit_trapped_level(map_state, u)
		u.state.on_faction_turn_end(trapped_lv)


func apply_faction_starvation(map_state: BattleMapState, faction_id: int) -> void:
	var units: Array[BattleUnit] = _get_sorted_units(map_state)
	for u: BattleUnit in units:
		if u.faction_id == faction_id:
			u.state.apply_starvation_morale_penalty()


func _get_sorted_units(map_state: BattleMapState) -> Array[BattleUnit]:
	var list: Array[BattleUnit] = map_state.get_all_units()
	list.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.unit_id < b.unit_id)
	return list
