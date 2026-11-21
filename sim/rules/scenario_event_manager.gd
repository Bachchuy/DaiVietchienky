class_name ScenarioEventManager
extends RefCounted

signal event_triggered(event_id: String, event_name: String)
signal dialogue_requested(dialogue_id: String)
signal camera_focus_requested(target_hex: Vector2i, duration: float)
signal area_trap_triggered(cell_hex: Vector2i, unit_id: int, damage: int)

var scripted_events: Array[Dictionary] = []
var triggered_event_ids: Array[String] = []
var dialogue_queue: Array[String] = []
var camera_focus_queue: Array[Dictionary] = []


func setup(events_data: Array, restored_triggered_ids: Array = []) -> void:
	scripted_events.clear()
	for raw_evt: Variant in events_data:
		if raw_evt is Dictionary:
			scripted_events.append((raw_evt as Dictionary).duplicate(true))

	triggered_event_ids.clear()
	for raw_id: Variant in restored_triggered_ids:
		triggered_event_ids.append(str(raw_id))

	dialogue_queue.clear()
	camera_focus_queue.clear()


func reset_runtime_state() -> void:
	triggered_event_ids.clear()
	dialogue_queue.clear()
	camera_focus_queue.clear()


func check_and_execute(
	trigger_type: String,
	ctx: BattleContext,
	_controller: RefCounted = null,
	director: ScenarioDirector = null,
	payload: Dictionary = {}
) -> int:
	if ctx == null:
		return 0
	var active_director: ScenarioDirector = director if director != null else ctx.director
	var executed_count: int = 0

	for evt: Dictionary in scripted_events:
		var evt_id: String = str(evt.get("event_id", ""))
		var is_once: bool = bool(evt.get("once", true))
		if is_once and triggered_event_ids.has(evt_id):
			continue
		if str(evt.get("trigger_type", "")) != trigger_type:
			continue

		var conditions: Array[Dictionary] = []
		var raw_conds: Variant = evt.get("conditions", [])
		if raw_conds is Array:
			for c: Variant in raw_conds:
				if c is Dictionary:
					conditions.append(c as Dictionary)

		var logic_op: String = str(evt.get("logic_operator", "AND")).to_upper()
		if _evaluate_conditions(conditions, logic_op, ctx, active_director, payload):
			if is_once and not evt_id.is_empty():
				triggered_event_ids.append(evt_id)

			var results: Array[Dictionary] = []
			var raw_res: Variant = evt.get("results", [])
			if raw_res is Array:
				for r: Variant in raw_res:
					if r is Dictionary:
						results.append(r as Dictionary)

			_execute_results(results, ctx, active_director)
			executed_count += 1
			event_triggered.emit(evt_id, str(evt.get("name", evt_id)))

	return executed_count


func _evaluate_conditions(
	conditions: Array[Dictionary],
	logic_op: String,
	ctx: BattleContext,
	director: ScenarioDirector,
	payload: Dictionary
) -> bool:
	if conditions.is_empty():
		return true

	if logic_op == "OR":
		for cond: Dictionary in conditions:
			if _evaluate_single_condition(cond, ctx, director, payload):
				return true
		return false

	for cond: Dictionary in conditions:
		if not _evaluate_single_condition(cond, ctx, director, payload):
			return false
	return true


func _evaluate_single_condition(
	cond: Dictionary,
	ctx: BattleContext,
	director: ScenarioDirector,
	payload: Dictionary
) -> bool:
	var field: String = str(cond.get("field", ""))
	var op: String = str(cond.get("op", "=="))
	var expected: Variant = cond.get("value", true)

	match field:
		"current_round":
			return _compare_num(float(ctx.current_round), float(expected), op)
		"current_faction_id":
			return _compare_num(float(ctx.current_faction_id), float(expected), op)
		"event_triggered":
			var req_evt: String = str(cond.get("event_id", ""))
			return triggered_event_ids.has(req_evt) == bool(expected)
		"general_alive":
			var gid: int = int(cond.get("general_id", 0))
			return _is_general_alive(ctx.map_state, gid) == bool(expected)
		"general_defeated":
			var gid_d: int = int(cond.get("general_id", 0))
			return (not _is_general_alive(ctx.map_state, gid_d)) == bool(expected)
		"unit_hp_ratio":
			var target_u: BattleUnit = _find_unit_by_condition(ctx.map_state, cond)
			if target_u == null:
				return false
			var ratio: float = float(target_u.state.current_hp) / maxf(1.0, float(target_u.state.max_hp))
			return _compare_num(ratio, float(expected), op)
		"area_owner":
			if director == null:
				return false
			var owner_id: int = director.get_area_owner(str(cond.get("area_id", "")))
			return _compare_num(float(owner_id), float(expected), op)
		"unit_in_area":
			if director == null:
				return false
			var area_hexes: Array[Vector2i] = director.get_area_hexes(str(cond.get("area_id", "")))
			var req_fac: int = int(cond.get("faction_id", -1))
			var req_gen: int = int(cond.get("general_id", 0))
			var found: bool = false
			for h: Vector2i in area_hexes:
				var u: BattleUnit = ctx.map_state.get_unit_at(h)
				if u == null:
					continue
				if req_fac != -1 and u.faction_id != req_fac:
					continue
				if req_gen > 0 and u.general_id != req_gen:
					continue
				found = true
				break
			return found == bool(expected)
		"general_clash":
			if str(payload.get("command_type", "")) != "Attack":
				return false
			var g1: int = int(payload.get("attacker_general_id", 0))
			var g2: int = int(payload.get("defender_general_id", 0))
			var req_g: int = int(cond.get("general_id", 0))
			var req_g2: int = int(cond.get("other_general_id", 0))
			var matched: bool = false
			if req_g > 0 and req_g2 > 0:
				matched = (g1 == req_g and g2 == req_g2) or (g1 == req_g2 and g2 == req_g)
			elif req_g > 0:
				matched = (g1 == req_g or g2 == req_g)
			else:
				matched = (g1 > 0 or g2 > 0)
			return matched == bool(expected)
		"enemy_defeated_percent":
			if ctx.victory_evaluator == null:
				return false
			var pct: float = ctx.victory_evaluator.get_enemy_defeated_percent(ctx.map_state)
			return _compare_num(pct, float(expected), op)
		_:
			push_warning("ScenarioEventManager: Unsupported condition field '%s'" % field)
			return false


func _compare_num(lhs: float, rhs: float, op: String) -> bool:
	match op:
		"==":
			return absf(lhs - rhs) < 0.0001
		"!=":
			return absf(lhs - rhs) >= 0.0001
		">=":
			return lhs >= rhs - 0.0001
		"<=":
			return lhs <= rhs + 0.0001
		">":
			return lhs > rhs + 0.0001
		"<":
			return lhs < rhs - 0.0001
		_:
			return false


func _is_general_alive(map_state: BattleMapState, general_id: int) -> bool:
	if map_state == null or general_id <= 0:
		return false
	for u: BattleUnit in map_state.get_all_units():
		if u.general_id == general_id and u.state.is_alive():
			return true
	return false


func _find_unit_by_condition(map_state: BattleMapState, cond: Dictionary) -> BattleUnit:
	if map_state == null:
		return null
	var uid: int = int(cond.get("unit_id", 0))
	var gid: int = int(cond.get("general_id", 0))
	for u: BattleUnit in map_state.get_all_units():
		if uid > 0 and u.unit_id == uid:
			return u
		if gid > 0 and u.general_id == gid:
			return u
	return null


func _execute_results(
	results: Array[Dictionary],
	ctx: BattleContext,
	director: ScenarioDirector
) -> void:
	for action_data: Dictionary in results:
		var action_type: String = str(action_data.get("action", ""))
		match action_type:
			"CameraFocus":
				var hex_dict: Dictionary = action_data.get("target_hex", {})
				var target_ax: Vector2i = ctx.parse_hex_dict(hex_dict)
				var duration: float = float(action_data.get("duration", 1.0))
				camera_focus_queue.append({"target_hex": target_ax, "duration": duration})
				camera_focus_requested.emit(target_ax, duration)
			"PlayDialogue":
				var dlg_id: String = str(action_data.get("dialogue_id", ""))
				if not dlg_id.is_empty():
					dialogue_queue.append(dlg_id)
					dialogue_requested.emit(dlg_id)
			"AlterTerrain":
				if director != null:
					var area_id: String = str(action_data.get("area_id", ""))
					var terrain_type: BattleMapState.TerrainType = parse_terrain_enum(str(action_data.get("new_terrain", "Plains")))
					for cell_hex: Vector2i in director.get_area_hexes(area_id):
						ctx.map_state.set_terrain(cell_hex, terrain_type)
			"ApplyAreaEffect":
				_apply_area_effect(action_data, ctx, director)
			"SpawnReinforcements":
				_spawn_reinforcements(action_data, ctx)
			"ModifyMorale":
				_apply_modify_morale(action_data, ctx, director)
			"ResolveBattle":
				ctx.forced_battle_outcome = int(action_data.get("outcome", 1))
			_:
				push_warning("ScenarioEventManager: Unsupported action '%s'" % action_type)


func _apply_area_effect(
	action_data: Dictionary,
	ctx: BattleContext,
	director: ScenarioDirector
) -> void:
	if director == null:
		return
	var area_id: String = str(action_data.get("area_id", ""))
	var target_faction_id: int = int(action_data.get("target_faction_id", -1))
	var hp_loss_ratio: float = float(action_data.get("hp_loss_max_ratio", 0.35))
	var march_lock: int = int(action_data.get("march_disabled_turns", 0))
	var chaos_lock: int = int(action_data.get("chaos_turns", 0))

	for cell_hex: Vector2i in director.get_area_hexes(area_id):
		var unit: BattleUnit = ctx.map_state.get_unit_at(cell_hex)
		if unit == null:
			continue
		if target_faction_id != -1 and unit.faction_id != target_faction_id:
			continue

		var stake_damage: int = maxi(1, CombatResolver.round_half_up(float(unit.state.max_hp) * hp_loss_ratio))
		unit.state.current_hp = maxi(0, unit.state.current_hp - stake_damage)
		if unit.state.is_alive():
			if march_lock > 0:
				unit.state.march_disabled_turns = maxi(unit.state.march_disabled_turns, march_lock)
			if chaos_lock > 0:
				unit.state.apply_chaos(chaos_lock)
		else:
			ctx.map_state.remove_unit(unit.unit_id)
		area_trap_triggered.emit(cell_hex, unit.unit_id, stake_damage)


func _spawn_reinforcements(action_data: Dictionary, ctx: BattleContext) -> void:
	var placements: Variant = action_data.get("placements", [])
	if not (placements is Array):
		return
	for raw_item: Variant in placements:
		if not (raw_item is Dictionary):
			continue
		var p: Dictionary = raw_item as Dictionary
		var desired_hex: Vector2i = ctx.parse_hex_dict(p.get("hex", {}))
		var troop_id: int = int(p.get("troop_id", 0))
		var t_def: Dictionary = ctx.troop_defs.get(troop_id, {})
		var domain: BattleUnit.Domain = BattleUnit.parse_domain(str(t_def.get("domain", p.get("domain", "Land"))))

		var spawn_hex: Vector2i = find_nearest_free_hex(desired_hex, domain, ctx)
		if spawn_hex.x == -9999:
			push_warning("ScenarioEventManager: No free hex near %s for reinforcement." % str(desired_hex))
			continue
		ctx.spawn_unit_from_placement(p, spawn_hex)


func _apply_modify_morale(
	action_data: Dictionary,
	ctx: BattleContext,
	director: ScenarioDirector
) -> void:
	var target_faction: int = int(action_data.get("faction_id", -1))
	var delta: int = int(action_data.get("delta", 0))
	var area_id: String = str(action_data.get("area_id", ""))
	var area_hexes: Array[Vector2i] = []
	if director != null and not area_id.is_empty():
		area_hexes = director.get_area_hexes(area_id)

	for u: BattleUnit in ctx.map_state.get_all_units():
		if target_faction != -1 and u.faction_id != target_faction:
			continue
		if not area_hexes.is_empty() and not area_hexes.has(u.hex_position):
			continue
		if delta > 0 and u.state.morale == UnitCombatState.MoraleLevel.CHAOS:
			u.state.clear_chaos(UnitCombatState.MoraleLevel.NORMAL)
		else:
			u.state.shift_morale(delta)


## Concentric BFS over Axial neighbors to find nearest unoccupied & domain-passable hex.
func find_nearest_free_hex(
	origin_hex: Vector2i,
	domain: BattleUnit.Domain,
	ctx: BattleContext
) -> Vector2i:
	if _is_hex_free_and_passable(origin_hex, domain, ctx):
		return origin_hex

	var visited: Dictionary[Vector2i, bool] = {origin_hex: true}
	var queue: Array[Vector2i] = [origin_hex]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
			var neighbor: Vector2i = current + dir
			if visited.has(neighbor) or not ctx.map_state.is_valid_hex(neighbor):
				continue
			visited[neighbor] = true
			if _is_hex_free_and_passable(neighbor, domain, ctx):
				return neighbor
			queue.append(neighbor)

	return Vector2i(-9999, -9999)


func _is_hex_free_and_passable(
	axial: Vector2i,
	domain: BattleUnit.Domain,
	ctx: BattleContext
) -> bool:
	if not ctx.map_state.is_valid_hex(axial):
		return false
	if ctx.map_state.get_unit_at(axial) != null:
		return false
	var probe := BattleUnit.new()
	probe.domain = domain
	probe.faction_id = 1
	return ctx.map_state.get_base_terrain_mp(ctx.map_state.get_terrain(axial), probe) < BattleMapState.IMPASSABLE_MP


static func parse_terrain_enum(raw_name: String) -> BattleMapState.TerrainType:
	match raw_name.strip_edges().to_lower():
		"plains", "plain":
			return BattleMapState.TerrainType.PLAINS
		"forest":
			return BattleMapState.TerrainType.FOREST
		"hills", "hill":
			return BattleMapState.TerrainType.HILLS
		"swamp":
			return BattleMapState.TerrainType.SWAMP
		"shallowriver", "shallow_river":
			return BattleMapState.TerrainType.SHALLOW_RIVER
		"deepwater", "deep_water", "water":
			return BattleMapState.TerrainType.DEEP_WATER
		"fort":
			return BattleMapState.TerrainType.FORT
		"roadport", "road_port", "signaldock", "signal_dock", "port", "road":
			return BattleMapState.TerrainType.ROAD_PORT
		"stakedwater", "staked_water":
			return BattleMapState.TerrainType.STAKED_WATER
		_:
			return BattleMapState.TerrainType.PLAINS
