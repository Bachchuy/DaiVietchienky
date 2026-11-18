class_name BattleContext
extends RefCounted

var map_state: BattleMapState = null
var navigator: HexGridNavigator = null
var combat_resolver: CombatResolver = null
var morale_engine: MoraleEngine = null
var rng: SeededRng = null
var enable_fog_of_war: bool = false

var _explored_hexes: Dictionary[int, Dictionary] = {}
var _trap_cells: Dictionary[Vector2i, bool] = {}
var _last_combat_report: Dictionary = {}


func _init(p_map_state: BattleMapState, p_seed: int = 1) -> void:
	map_state = p_map_state
	navigator = HexGridNavigator.new()
	combat_resolver = CombatResolver.new()
	morale_engine = MoraleEngine.new()
	rng = SeededRng.new(p_seed)


func get_unit(unit_id: int) -> BattleUnit:
	if map_state == null:
		return null
	for u: BattleUnit in map_state.get_all_units():
		if u.unit_id == unit_id:
			return u
	return null


func set_trap_cell(axial: Vector2i, active: bool = true) -> void:
	if active:
		_trap_cells[axial] = true
	else:
		_trap_cells.erase(axial)


func refresh_faction_vision(faction_id: int) -> Array[Vector2i]:
	var newly_explored: Array[Vector2i] = []
	if not enable_fog_of_war or map_state == null:
		return newly_explored

	if not _explored_hexes.has(faction_id):
		_explored_hexes[faction_id] = {}
	var fac_map: Dictionary = _explored_hexes[faction_id]

	for u: BattleUnit in map_state.get_all_units():
		if not map_state.is_allied(faction_id, u.faction_id):
			continue
		var vr: int = maxi(1, u.vision_range)
		for dq: int in range(-vr, vr + 1):
			var r_min: int = maxi(-vr, -dq - vr)
			var r_max: int = mini(vr, -dq + vr)
			for dr: int in range(r_min, r_max + 1):
				var cand: Vector2i = u.hex_position + Vector2i(dq, dr)
				if not map_state.is_valid_hex(cand):
					continue
				if cand == u.hex_position or navigator.has_line_of_sight(map_state, u.hex_position, cand):
					if not fac_map.has(cand):
						fac_map[cand] = true
						newly_explored.append(cand)
	return newly_explored


func move_unit_along_valid_path(
	unit: BattleUnit,
	from_hex: Vector2i,
	to_hex: Vector2i
) -> Dictionary:
	if unit == null or unit.hex_position != from_hex or from_hex == to_hex:
		return {"ok": false}

	var reachable: Dictionary[Vector2i, int] = navigator.get_reachable_hexes(map_state, unit)
	if not reachable.has(to_hex):
		return {"ok": false}

	var mp_cost: int = reachable[to_hex]
	var path: Array[Vector2i] = navigator.find_path(map_state, unit, to_hex)
	if path.size() < 2:
		return {"ok": false}

	var delta_step: Vector2i = path[path.size() - 1] - path[path.size() - 2]
	for d: int in range(HexMath.AXIAL_DIRECTIONS.size()):
		if HexMath.AXIAL_DIRECTIONS[d] == delta_step:
			unit.facing = d
			break

	map_state.move_unit(unit, to_hex)
	unit.state.current_mp = maxi(0, unit.state.current_mp - mp_cost)

	var entered_zoc: bool = (
		navigator.is_in_active_enemy_zoc(map_state, to_hex, unit.faction_id)
		and not unit.ignore_zoc
	)

	var triggered_event: bool = false
	if _trap_cells.has(to_hex):
		triggered_event = true
		_trap_cells.erase(to_hex)

	# StakedWater hazard for enemy naval vessels (GDD hex_grid_pathfinding.md Section 2)
	if (
		map_state.get_terrain(to_hex) == BattleMapState.TerrainType.STAKED_WATER
		and unit.domain == BattleUnit.Domain.NAVAL
		and map_state.is_hostile(unit.faction_id, map_state.staked_water_owner_faction)
	):
		triggered_event = true
		var stake_dmg: int = maxi(1, CombatResolver.round_half_up(float(unit.state.max_hp) * 0.35))
		unit.state.current_hp = maxi(0, unit.state.current_hp - stake_dmg)
		unit.state.march_disabled_turns = maxi(unit.state.march_disabled_turns, 2)
		if not unit.state.is_alive():
			map_state.remove_unit(unit.unit_id)

	var newly_chaosed: Array[int] = morale_engine.apply_immediate_trapped_effects(map_state)
	if not newly_chaosed.is_empty():
		triggered_event = true

	var revealed: Array[Vector2i] = refresh_faction_vision(unit.faction_id)

	return {
		"ok": true,
		"mp_cost": mp_cost,
		"revealed_fog_cells": revealed,
		"entered_enemy_zoc": entered_zoc,
		"triggered_cell_event": triggered_event,
	}


func teleport_unit_without_triggers(unit: BattleUnit, target_hex: Vector2i) -> bool:
	if unit == null or map_state == null:
		return false
	return map_state.move_unit(unit, target_hex)


func execute_attack(attacker_id: int, defender_id: int) -> bool:
	var attacker: BattleUnit = get_unit(attacker_id)
	var defender: BattleUnit = get_unit(defender_id)
	if attacker == null or defender == null:
		return false
	if attacker.state.has_acted or not attacker.state.can_attack():
		return false
	if not map_state.is_hostile(attacker.faction_id, defender.faction_id):
		return false

	var atk_hexes: Array[Vector2i] = navigator.get_attackable_hexes(map_state, attacker, attacker.hex_position)
	if not atk_hexes.has(defender.hex_position):
		return false

	var atk_pos_before: Vector2i = attacker.hex_position
	var def_pos_before: Vector2i = defender.hex_position

	var report: Dictionary = combat_resolver.resolve_attack(
		map_state,
		navigator,
		attacker,
		defender,
		rng
	)
	if not bool(report.get("ok", false)):
		return false

	_last_combat_report = report
	attacker.state.has_acted = true

	if bool(report.get("defender_defeated", false)):
		morale_engine.on_unit_defeated(map_state, attacker, defender, def_pos_before)
	if bool(report.get("attacker_defeated", false)):
		morale_engine.on_unit_defeated(map_state, defender, attacker, atk_pos_before)

	morale_engine.apply_immediate_trapped_effects(map_state)
	refresh_faction_vision(attacker.faction_id)
	return true


func execute_skill_effect(caster: BattleUnit, skill_id: int, target_hex: Vector2i) -> bool:
	if caster == null or caster.state.has_acted or not caster.state.can_use_skill():
		return false
	if not map_state.is_valid_hex(target_hex):
		return false
	if HexMath.hex_distance(caster.hex_position, target_hex) > 2:
		return false

	# Canonical CP2 rally/inspire skill (e.g. 10001 Hich Tuong Si / Inspire): clear Chaos & +1 Morale in 1-hex radius
	for u: BattleUnit in map_state.get_all_units():
		if map_state.is_allied(caster.faction_id, u.faction_id):
			if HexMath.hex_distance(u.hex_position, target_hex) <= 1:
				if u.state.morale == UnitCombatState.MoraleLevel.CHAOS:
					u.state.clear_chaos(UnitCombatState.MoraleLevel.NORMAL)
				else:
					u.state.shift_morale(1)

	caster.state.skill_cooldown = 3 if skill_id == 10001 else 2
	caster.state.has_acted = true
	return true


func get_last_combat_report() -> Dictionary:
	return _last_combat_report
