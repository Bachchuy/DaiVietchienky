class_name BattleContext
extends RefCounted

var map_state: BattleMapState = null
var navigator: HexGridNavigator = null
var combat_resolver: CombatResolver = null
var morale_engine: MoraleEngine = null
var rng: SeededRng = null
var enable_fog_of_war: bool = false

var troop_defs: Dictionary = {}
var director: ScenarioDirector = null
var victory_evaluator: ScenarioVictoryEvaluator = null
var current_round: int = 0
var current_faction_id: int = 1
var coordinate_space: String = "odd_r"
var forced_battle_outcome: int = 0
var last_command_payload: Dictionary = {}

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


func parse_hex_dict(hex_dict: Dictionary, space_override: String = "") -> Vector2i:
	if hex_dict.has("col") or hex_dict.has("row"):
		return HexMath.odd_r_to_axial(Vector2i(int(hex_dict.get("col", 0)), int(hex_dict.get("row", 0))))
	var active_space: String = space_override if not space_override.is_empty() else coordinate_space
	var q_val: int = int(hex_dict.get("q", 0))
	var r_val: int = int(hex_dict.get("r", 0))
	if active_space == "odd_r":
		return HexMath.odd_r_to_axial(Vector2i(q_val, r_val))
	return Vector2i(q_val, r_val)


static func _parse_morale_override(raw_morale: Variant) -> UnitCombatState.MoraleLevel:
	if raw_morale is String:
		match (raw_morale as String).strip_edges().to_upper():
			"HIGH":
				return UnitCombatState.MoraleLevel.HIGH
			"LOW":
				return UnitCombatState.MoraleLevel.LOW
			"CHAOS":
				return UnitCombatState.MoraleLevel.CHAOS
			_:
				return UnitCombatState.MoraleLevel.NORMAL
	var num: int = int(raw_morale)
	if num >= 0 and num <= 3:
		return num as UnitCombatState.MoraleLevel
	if num >= 90:
		return UnitCombatState.MoraleLevel.HIGH
	if num <= 0:
		return UnitCombatState.MoraleLevel.CHAOS
	if num < 50:
		return UnitCombatState.MoraleLevel.LOW
	return UnitCombatState.MoraleLevel.NORMAL


func spawn_unit_from_placement(
	p: Dictionary,
	axial_override: Vector2i = Vector2i(-9999, -9999)
) -> BattleUnit:
	if map_state == null:
		return null
	var uid: int = int(p.get("unit_id", 0))
	var faction_id: int = int(p.get("faction_id", 1))
	var troop_id: int = int(p.get("troop_id", 0))
	var axial: Vector2i = axial_override if axial_override.x != -9999 else parse_hex_dict(p.get("hex", {}))
	var t_def: Dictionary = troop_defs.get(troop_id, {})

	var u: BattleUnit = BattleUnit.from_troop_dict(uid, faction_id, axial, t_def)
	if p.has("name"):
		u.display_name = str(p.get("name", u.display_name))
	u.general_id = int(p.get("general_id", 0))
	u.general_name = str(p.get("general_name", ""))
	u.is_commander_in_chief = bool(p.get("is_commander_in_chief", false))
	u.general_command_stat = int(p.get("general_command_stat", 0))
	u.general_luck = int(p.get("general_luck", 0))
	u.m_command = float(p.get("m_command", 1.00))
	u.aura_radius_hex = int(p.get("aura_radius_hex", 0))
	u.aura_damage_deepen = int(p.get("aura_damage_deepen", 0))
	u.aura_damage_resist = int(p.get("aura_damage_resist", 0))
	u.grants_dead_mate_immunity = bool(p.get("grants_dead_mate_immunity", false))
	u.facing = int(p.get("facing", 0))

	var stack_n: int = clampi(int(p.get("troop_stack", p.get("max_stack", 1))), 1, 3)
	u.max_stack = stack_n
	u.troop_stack = stack_n
	u.state.max_hp = int(p.get("max_hp", u.base_hp * stack_n))
	u.state.current_hp = clampi(int(p.get("current_hp", u.state.max_hp)), 1, u.state.max_hp)

	if p.has("initial_morale"):
		u.state.morale = _parse_morale_override(p.get("initial_morale", 2))
	if p.has("is_invisible"):
		u.state.is_invisible = bool(p.get("is_invisible", false))
	if p.has("is_morale_locked"):
		u.state.is_morale_locked = bool(p.get("is_morale_locked", false))
	if p.has("fond_terrain"):
		var parsed_ft: int = BattleUnit.parse_terrain_name(str(p.get("fond_terrain", "")))
		if parsed_ft >= 0:
			u.fond_terrain = parsed_ft

	if not map_state.place_unit(u):
		return null
	if victory_evaluator != null:
		victory_evaluator.register_unit(u, map_state)
	return u


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

	if director != null:
		for area_id: String in director.find_areas_containing_hex(to_hex):
			if director.primary_objective_area_ids.has(area_id):
				if director.get_area_owner(area_id) != unit.faction_id:
					director.set_area_owner(area_id, unit.faction_id)
					triggered_event = true

	# StakedWater hazard for enemy naval vessels
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
	last_command_payload = {
		"command_type": "March",
		"unit_id": unit.unit_id,
		"faction_id": unit.faction_id,
		"to_hex": to_hex,
	}

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
	var atk_gen: int = attacker.general_id
	var def_gen: int = defender.general_id
	var atk_fac: int = attacker.faction_id
	var def_fac: int = defender.faction_id

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
	last_command_payload = {
		"command_type": "Attack",
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"attacker_general_id": atk_gen,
		"defender_general_id": def_gen,
		"attacker_faction": atk_fac,
		"defender_faction": def_fac,
		"defender_defeated": bool(report.get("defender_defeated", false)),
		"attacker_defeated": bool(report.get("attacker_defeated", false)),
	}
	return true


func execute_skill_effect(caster: BattleUnit, skill_id: int, target_hex: Vector2i) -> bool:
	if caster == null or caster.state.has_acted or not caster.state.can_use_skill():
		return false
	if not map_state.is_valid_hex(target_hex):
		return false
	if HexMath.hex_distance(caster.hex_position, target_hex) > 2:
		return false

	for u: BattleUnit in map_state.get_all_units():
		if map_state.is_allied(caster.faction_id, u.faction_id):
			if HexMath.hex_distance(u.hex_position, target_hex) <= 1:
				if u.state.morale == UnitCombatState.MoraleLevel.CHAOS:
					u.state.clear_chaos(UnitCombatState.MoraleLevel.NORMAL)
				else:
					u.state.shift_morale(1)

	caster.state.skill_cooldown = 3 if skill_id == 10001 else 2
	caster.state.has_acted = true
	last_command_payload = {
		"command_type": "CastSkill",
		"caster_id": caster.unit_id,
		"skill_id": skill_id,
		"target_hex": target_hex,
	}
	return true


func get_last_combat_report() -> Dictionary:
	return _last_combat_report
