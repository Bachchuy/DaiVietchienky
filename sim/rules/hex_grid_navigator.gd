class_name HexGridNavigator
extends RefCounted

enum FogState {
	UNEXPLORED = 0,
	SHROUDED = 1,
	VISIBLE = 2,
}

const IMPASSABLE_MP: int = BattleMapState.IMPASSABLE_MP


func has_line_of_sight(
	map_state: BattleMapState,
	from_hex: Vector2i,
	to_hex: Vector2i
) -> bool:
	var line: Array[Vector2i] = HexMath.hex_linedraw(from_hex, to_hex)
	if line.size() <= 2:
		return true

	var from_terrain: BattleMapState.TerrainType = map_state.get_terrain(from_hex)
	var to_terrain: BattleMapState.TerrainType = map_state.get_terrain(to_hex)
	var observer_elevated: bool = (
		from_terrain == BattleMapState.TerrainType.HILLS
		or from_terrain == BattleMapState.TerrainType.FORT
	)
	var target_elevated: bool = (to_terrain == BattleMapState.TerrainType.HILLS)

	for i: int in range(1, line.size() - 1):
		var mid_terrain: BattleMapState.TerrainType = map_state.get_terrain(line[i])
		if observer_elevated:
			if mid_terrain == BattleMapState.TerrainType.HILLS and not target_elevated:
				return false
		else:
			if (
				mid_terrain == BattleMapState.TerrainType.FOREST
				or mid_terrain == BattleMapState.TerrainType.HILLS
				or mid_terrain == BattleMapState.TerrainType.FORT
			):
				return false
	return true


func is_in_active_enemy_zoc(
	map_state: BattleMapState,
	hex: Vector2i,
	mover_faction: int
) -> bool:
	for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
		var adj: Vector2i = hex + dir
		if not map_state.is_valid_hex(adj):
			continue
		var occupant: BattleUnit = map_state.get_unit_at(adj)
		if occupant == null or not map_state.is_hostile(mover_faction, occupant.faction_id):
			continue
		if not occupant.state.emits_zoc():
			continue
		if _is_enemy_zoc_suppressed_by_devoid(map_state, adj, mover_faction):
			continue
		return true
	return false


func _is_enemy_zoc_suppressed_by_devoid(
	map_state: BattleMapState,
	enemy_hex: Vector2i,
	mover_faction: int
) -> bool:
	for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
		var around: Vector2i = enemy_hex + dir
		if not map_state.is_valid_hex(around):
			continue
		var ally: BattleUnit = map_state.get_unit_at(around)
		if ally != null and map_state.is_allied(mover_faction, ally.faction_id):
			if ally.devoid_zoc and ally.state.emits_zoc():
				return true
	return false


func _build_active_coc_set(map_state: BattleMapState, mover_faction: int) -> Dictionary[Vector2i, bool]:
	var coc: Dictionary[Vector2i, bool] = {}
	for fort_hex: Vector2i in map_state.get_fort_hexes():
		var owner_id: int = map_state.get_fort_owner(fort_hex)
		if owner_id == 0 or not map_state.is_hostile(mover_faction, owner_id):
			continue
		for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
			var nb: Vector2i = fort_hex + dir
			if map_state.is_valid_hex(nb):
				coc[nb] = true
	return coc


func _build_active_zoc_set(map_state: BattleMapState, mover_faction: int) -> Dictionary[Vector2i, bool]:
	var zoc: Dictionary[Vector2i, bool] = {}
	for u: BattleUnit in map_state.get_all_units():
		if not map_state.is_hostile(mover_faction, u.faction_id):
			continue
		if not u.state.emits_zoc():
			continue
		if _is_enemy_zoc_suppressed_by_devoid(map_state, u.hex_position, mover_faction):
			continue
		for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
			var nb: Vector2i = u.hex_position + dir
			if map_state.is_valid_hex(nb):
				zoc[nb] = true
	return zoc


func get_hex_step_cost(
	map_state: BattleMapState,
	_from_hex: Vector2i,
	to_hex: Vector2i,
	unit: BattleUnit,
	remaining_mp: int
) -> int:
	if remaining_mp <= 0 or not map_state.is_valid_hex(to_hex):
		return IMPASSABLE_MP

	var occupant: BattleUnit = map_state.get_unit_at(to_hex)
	if occupant != null and map_state.is_hostile(unit.faction_id, occupant.faction_id):
		return IMPASSABLE_MP

	var to_terrain: BattleMapState.TerrainType = map_state.get_terrain(to_hex)
	var step_cost: int = map_state.get_base_terrain_mp(to_terrain, unit)
	if step_cost >= IMPASSABLE_MP:
		return IMPASSABLE_MP

	if unit.fond_terrain == int(to_terrain):
		step_cost = maxi(1, step_cost - 1)

	if map_state.is_in_enemy_coc(to_hex, unit.faction_id) and not unit.ignore_coc:
		step_cost *= 2

	if is_in_active_enemy_zoc(map_state, to_hex, unit.faction_id) and not unit.ignore_zoc:
		step_cost = maxi(step_cost, remaining_mp)

	return step_cost


func _fast_step_cost(
	map_state: BattleMapState,
	to_hex: Vector2i,
	unit: BattleUnit,
	remaining_mp: int,
	coc_set: Dictionary[Vector2i, bool],
	zoc_set: Dictionary[Vector2i, bool]
) -> int:
	if remaining_mp <= 0 or not map_state.is_valid_hex(to_hex):
		return IMPASSABLE_MP

	var occupant: BattleUnit = map_state.get_unit_at(to_hex)
	if occupant != null and map_state.is_hostile(unit.faction_id, occupant.faction_id):
		return IMPASSABLE_MP

	var to_terrain: BattleMapState.TerrainType = map_state.get_terrain(to_hex)
	var step_cost: int = map_state.get_base_terrain_mp(to_terrain, unit)
	if step_cost >= IMPASSABLE_MP:
		return IMPASSABLE_MP

	if unit.fond_terrain == int(to_terrain):
		step_cost = maxi(1, step_cost - 1)

	if not unit.ignore_coc and coc_set.has(to_hex):
		step_cost *= 2

	if not unit.ignore_zoc and zoc_set.has(to_hex):
		step_cost = maxi(step_cost, remaining_mp)

	return step_cost


func can_unit_march(unit: BattleUnit) -> bool:
	if unit == null or not unit.state.is_alive():
		return false
	if unit.state.morale == UnitCombatState.MoraleLevel.CHAOS or unit.state.chaos_turns > 0:
		return false
	if unit.state.march_disabled_turns > 0 or unit.state.has_acted:
		return false
	return unit.state.current_mp > 0


func get_reachable_hexes(
	map_state: BattleMapState,
	unit: BattleUnit
) -> Dictionary[Vector2i, int]:
	var stoppable: Dictionary[Vector2i, int] = {}
	if unit == null or not map_state.is_valid_hex(unit.hex_position):
		return stoppable

	stoppable[unit.hex_position] = 0
	if not can_unit_march(unit):
		return stoppable

	var budget_mp: int = unit.state.current_mp
	var coc_set: Dictionary[Vector2i, bool] = _build_active_coc_set(map_state, unit.faction_id)
	var zoc_set: Dictionary[Vector2i, bool] = _build_active_zoc_set(map_state, unit.faction_id)

	var best_g: Dictionary[Vector2i, int] = {unit.hex_position: 0}
	# Dial's bucket queue indexed by exact integer MP spent [0 .. budget_mp] -> O(1) extract-min!
	var buckets: Array = []
	buckets.resize(budget_mp + 1)
	for b_idx: int in range(budget_mp + 1):
		var empty_bucket: Array[Vector2i] = []
		buckets[b_idx] = empty_bucket
	(buckets[0] as Array[Vector2i]).append(unit.hex_position)

	for cost_cursor: int in range(budget_mp):
		var bucket: Array[Vector2i] = buckets[cost_cursor]
		var idx: int = 0
		while idx < bucket.size():
			var current: Vector2i = bucket[idx]
			idx += 1
			if best_g[current] < cost_cursor:
				continue
			var remaining_mp: int = budget_mp - cost_cursor
			for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
				var next_hex: Vector2i = current + dir
				var step_cost: int = _fast_step_cost(
					map_state,
					next_hex,
					unit,
					remaining_mp,
					coc_set,
					zoc_set
				)
				if step_cost >= IMPASSABLE_MP:
					continue
				var next_g: int = cost_cursor + step_cost
				if next_g > budget_mp:
					continue
				if not best_g.has(next_hex) or next_g < best_g[next_hex]:
					best_g[next_hex] = next_g
					(buckets[next_g] as Array[Vector2i]).append(next_hex)

	for hex: Vector2i in best_g.keys():
		var occ: BattleUnit = map_state.get_unit_at(hex)
		if occ == null or occ == unit:
			stoppable[hex] = best_g[hex]

	return stoppable


func find_path(
	map_state: BattleMapState,
	unit: BattleUnit,
	target_hex: Vector2i
) -> Array[Vector2i]:
	if unit == null or not map_state.is_valid_hex(target_hex):
		return []
	if target_hex == unit.hex_position:
		return [unit.hex_position]
	if not can_unit_march(unit):
		return []

	var target_occ: BattleUnit = map_state.get_unit_at(target_hex)
	if target_occ != null and target_occ != unit:
		return []

	var budget_mp: int = unit.state.current_mp
	var start: Vector2i = unit.hex_position
	var coc_set: Dictionary[Vector2i, bool] = _build_active_coc_set(map_state, unit.faction_id)
	var zoc_set: Dictionary[Vector2i, bool] = _build_active_zoc_set(map_state, unit.faction_id)

	var best_g: Dictionary[Vector2i, int] = {start: 0}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var open_hexes: Array[Vector2i] = [start]
	var open_f: Array[int] = [HexMath.hex_distance(start, target_hex)]

	while not open_hexes.is_empty():
		var best_idx: int = 0
		var best_f_val: int = open_f[0]
		for i: int in range(1, open_f.size()):
			if open_f[i] < best_f_val:
				best_f_val = open_f[i]
				best_idx = i

		var current: Vector2i = open_hexes[best_idx]
		open_hexes.remove_at(best_idx)
		open_f.remove_at(best_idx)

		if current == target_hex:
			return _reconstruct_path(came_from, start, target_hex)

		var g_so_far: int = best_g[current]
		var remaining_mp: int = budget_mp - g_so_far
		if remaining_mp <= 0:
			continue

		for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
			var next_hex: Vector2i = current + dir
			var step_cost: int = _fast_step_cost(
				map_state,
				next_hex,
				unit,
				remaining_mp,
				coc_set,
				zoc_set
			)
			if step_cost >= IMPASSABLE_MP:
				continue
			var next_g: int = g_so_far + step_cost
			if next_g > budget_mp:
				continue
			if not best_g.has(next_hex) or next_g < best_g[next_hex]:
				best_g[next_hex] = next_g
				came_from[next_hex] = current
				open_hexes.append(next_hex)
				open_f.append(next_g + HexMath.hex_distance(next_hex, target_hex))

	return []


func _reconstruct_path(
	came_from: Dictionary[Vector2i, Vector2i],
	start: Vector2i,
	goal: Vector2i
) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = [goal]
	var cursor: Vector2i = goal
	while cursor != start and came_from.has(cursor):
		cursor = came_from[cursor]
		reversed_path.append(cursor)
	reversed_path.reverse()
	return reversed_path


func get_attackable_hexes(
	map_state: BattleMapState,
	unit: BattleUnit,
	origin_hex: Vector2i
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit == null or not map_state.is_valid_hex(origin_hex):
		return out
	if unit.state.morale == UnitCombatState.MoraleLevel.CHAOS or unit.state.attack_disabled_turns > 0:
		return out

	var min_r: int = maxi(1, unit.min_range)
	var max_r: int = maxi(min_r, unit.max_range)

	for dq: int in range(-max_r, max_r + 1):
		var r_min: int = maxi(-max_r, -dq - max_r)
		var r_max: int = mini(max_r, -dq + max_r)
		for dr: int in range(r_min, r_max + 1):
			var cand: Vector2i = origin_hex + Vector2i(dq, dr)
			var dist: int = HexMath.hex_distance(origin_hex, cand)
			if dist < min_r or dist > max_r:
				continue
			if not map_state.is_valid_hex(cand):
				continue
			if has_line_of_sight(map_state, origin_hex, cand):
				out.append(cand)
	return out


func get_engageable_enemy_hexes(
	map_state: BattleMapState,
	unit: BattleUnit,
	reachable: Dictionary[Vector2i, int]
) -> Array[Vector2i]:
	var enemy_hexes: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for move_hex: Vector2i in reachable.keys():
		for atk_hex: Vector2i in get_attackable_hexes(map_state, unit, move_hex):
			if seen.has(atk_hex):
				continue
			var occ: BattleUnit = map_state.get_unit_at(atk_hex)
			if occ != null and map_state.is_hostile(unit.faction_id, occ.faction_id):
				seen[atk_hex] = true
				enemy_hexes.append(atk_hex)
	return enemy_hexes
