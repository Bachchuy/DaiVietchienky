extends "res://tests/test_case.gd"

const CONTROLLER_PATH: String = "res://sim/state/battle_game_controller.gd"
const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const CmdsScript = preload("res://sim/commands/battle_commands.gd")


func _load_controller_script() -> GDScript:
	var s: GDScript = load(CONTROLLER_PATH) as GDScript
	assert_not_null(s, "BattleGameController script must exist at " + CONTROLLER_PATH)
	return s


func _build_50_turn_arena() -> BattleMapState:
	var map_state := MapStateScript.new(14, 12, MapStateScript.TerrainType.PLAINS)
	for r: int in range(12):
		for c: int in range(14):
			var ax: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(c, r))
			if (c + r) % 6 == 0:
				map_state.set_terrain(ax, MapStateScript.TerrainType.FOREST)
			elif (c * 2 + r) % 9 == 0:
				map_state.set_terrain(ax, MapStateScript.TerrainType.HILLS)

	# 6 Dai Viet units (Faction 1) + 6 Dai Nguyen units (Faction 3) with durable HP for 50+ turns
	for i: int in range(6):
		var dv := UnitScript.new()
		dv.unit_id = i + 1
		dv.faction_id = 1
		dv.display_name = "DaiViet_%d" % (i + 1)
		dv.hex_position = HexMathScript.odd_r_to_axial(Vector2i(2, 1 + i * 2 if i < 5 else 10))
		dv.max_mp = 6
		dv.min_range = 1
		dv.max_range = 2 if (i % 2 == 1) else 1
		dv.base_atk = 28
		dv.base_def = 25
		dv.state.max_hp = 1800
		dv.state.current_hp = 1800
		if i == 0:
			dv.general_id = 1001
			dv.aura_radius_hex = 2
			dv.aura_damage_deepen = 8
		map_state.place_unit(dv)

		var dn := UnitScript.new()
		dn.unit_id = 101 + i
		dn.faction_id = 3
		dn.display_name = "DaiNguyen_%d" % (i + 1)
		dn.hex_position = HexMathScript.odd_r_to_axial(Vector2i(11, 1 + i * 2 if i < 5 else 10))
		dn.max_mp = 6
		dn.min_range = 1
		dn.max_range = 2 if (i % 2 == 1) else 1
		dn.base_atk = 28
		dn.base_def = 25
		dn.state.max_hp = 1800
		dn.state.current_hp = 1800
		if i == 0:
			dn.general_id = 9001
			dn.aura_radius_hex = 2
			dn.aura_damage_resist = 8
		map_state.place_unit(dn)

	return map_state


func test_seven_phase_lifecycle_turn_rotation_and_immediate_victory() -> void:
	var ctrl_s: GDScript = _load_controller_script()
	if ctrl_s == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var dv := UnitScript.new()
	dv.unit_id = 1
	dv.faction_id = 1
	dv.hex_position = HexMathScript.odd_r_to_axial(Vector2i(4, 5))
	dv.base_atk = 120
	dv.max_mp = 6
	dv.state.max_hp = 200
	dv.state.current_hp = 200
	map_state.place_unit(dv)

	var dn := UnitScript.new()
	dn.unit_id = 2
	dn.faction_id = 3
	dn.hex_position = HexMathScript.odd_r_to_axial(Vector2i(5, 5))
	dn.max_mp = 6
	dn.state.max_hp = 40
	dn.state.current_hp = 40
	map_state.place_unit(dn)

	var visited_phases: Array[int] = []
	var ctrl: RefCounted = ctrl_s.new(map_state, 1288, [1, 3], 10)
	ctrl.connect("phase_changed", func(p: int) -> void: visited_phases.append(p))

	ctrl.call("start_battle")
	assert_eq(int(ctrl.get("current_round")), 1, "Battle starts at Round 1")
	assert_eq(int(ctrl.get("current_faction_id")), 1, "Faction 1 acts first")
	assert_eq(int(ctrl.get("current_phase")), ctrl_s.BattlePhase.PHASE_3_DECISION_AND_PREVIEW)
	assert_has(visited_phases, ctrl_s.BattlePhase.PHASE_1_BEGIN_ROUND)
	assert_has(visited_phases, ctrl_s.BattlePhase.PHASE_2_FACTION_TURN_START)

	# End Faction 1 turn -> rotates to Faction 3 -> End Faction 3 turn -> advances to Round 2!
	assert_true(bool(ctrl.call("submit_command", CmdsScript.EndTurnCommand.new(1))))
	assert_eq(int(ctrl.get("current_faction_id")), 3)
	assert_has(visited_phases, ctrl_s.BattlePhase.PHASE_6_FACTION_TURN_END)

	assert_true(bool(ctrl.call("submit_command", CmdsScript.EndTurnCommand.new(3))))
	assert_has(visited_phases, ctrl_s.BattlePhase.PHASE_7_END_ROUND)
	assert_eq(int(ctrl.get("current_round")), 2)
	assert_eq(int(ctrl.get("current_faction_id")), 1)

	# Attack and eliminate last enemy -> Phase 5 triggers IMMEDIATE VICTORY!
	assert_true(bool(ctrl.call("submit_command", CmdsScript.AttackCommand.new(1, 1, 2))))
	assert_has(visited_phases, ctrl_s.BattlePhase.PHASE_4_COMMAND_EXECUTION)
	assert_has(visited_phases, ctrl_s.BattlePhase.PHASE_5_IMMEDIATE_RESOLUTION)
	assert_eq(int(ctrl.get("outcome")), ctrl_s.BattleOutcome.VICTORY)


func test_50_turns_deterministic_replay_zero_hp_or_state_drift() -> void:
	var ctrl_s: GDScript = _load_controller_script()
	if ctrl_s == null:
		return

	var seed_val: int = 12882026
	var map_a: BattleMapState = _build_50_turn_arena()
	var ctrl_a: RefCounted = ctrl_s.new(map_a, seed_val, [1, 3], 40)
	ctrl_a.call("start_battle")

	# Simulate 52 full faction turns (26 rounds) with real movement, undo, skills, and combat!
	var completed_turns: int = 0
	while completed_turns < 52 and int(ctrl_a.get("outcome")) == ctrl_s.BattleOutcome.ONGOING:
		var active_faction: int = int(ctrl_a.get("current_faction_id"))
		var ctx_a: BattleContext = ctrl_a.get("context") as BattleContext
		var units: Array[BattleUnit] = map_a.get_all_units()
		units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.unit_id < b.unit_id)

		var did_try_undo_this_turn: bool = false
		for u: BattleUnit in units:
			if int(ctrl_a.get("outcome")) != ctrl_s.BattleOutcome.ONGOING:
				break
			if u.faction_id != active_faction or not u.state.is_alive():
				continue

			# Find nearest hostile unit
			var nearest_enemy: BattleUnit = null
			var best_dist: int = 9999
			for other: BattleUnit in map_a.get_all_units():
				if map_a.is_hostile(u.faction_id, other.faction_id):
					var d: int = HexMathScript.hex_distance(u.hex_position, other.hex_position)
					if d < best_dist:
						best_dist = d
						nearest_enemy = other

			if nearest_enemy == null:
				break

			# March closer if not yet adjacent / in range
			if u.state.can_move() and best_dist > u.max_range:
				var reachable: Dictionary[Vector2i, int] = ctx_a.navigator.get_reachable_hexes(map_a, u)
				var best_hex: Vector2i = u.hex_position
				var min_d: int = best_dist
				for cand: Vector2i in reachable.keys():
					var cd: int = HexMathScript.hex_distance(cand, nearest_enemy.hex_position)
					if cd < min_d or (cd == min_d and cand.x < best_hex.x):
						min_d = cd
						best_hex = cand
				if best_hex != u.hex_position:
					var from_h: Vector2i = u.hex_position
					ctrl_a.call("submit_command", CmdsScript.MarchCommand.new(active_faction, u.unit_id, from_h, best_hex))
					# Exercise 1-step Undo periodically in replay stream!
					if not did_try_undo_this_turn and completed_turns % 7 == 0 and bool(ctrl_a.call("can_undo")):
						assert_true(bool(ctrl_a.call("undo_last_action")))
						did_try_undo_this_turn = true
						ctrl_a.call("submit_command", CmdsScript.MarchCommand.new(active_faction, u.unit_id, from_h, best_hex))

			# Attack if nearest enemy is now in attackable hexes, else cast skill or wait
			if int(ctrl_a.get("outcome")) == ctrl_s.BattleOutcome.ONGOING and not u.state.has_acted:
				var atk_list: Array[Vector2i] = ctx_a.navigator.get_attackable_hexes(map_a, u, u.hex_position)
				if u.state.can_attack() and atk_list.has(nearest_enemy.hex_position):
					ctrl_a.call("submit_command", CmdsScript.AttackCommand.new(active_faction, u.unit_id, nearest_enemy.unit_id))
				elif u.general_id > 0 and u.state.can_use_skill():
					ctrl_a.call("submit_command", CmdsScript.CastSkillCommand.new(active_faction, u.unit_id, 10001, u.hex_position))
				else:
					ctrl_a.call("submit_command", CmdsScript.WaitCommand.new(active_faction, u.unit_id))

		if int(ctrl_a.get("outcome")) == ctrl_s.BattleOutcome.ONGOING:
			assert_true(bool(ctrl_a.call("submit_command", CmdsScript.EndTurnCommand.new(active_faction))))
			completed_turns += 1

	assert_gte(float(completed_turns), 50.0, "Must execute at least 50 full turns")

	# Serialize Replay to JSON and replay from scratch on fresh Map B!
	var replay_json: String = JSON.stringify(ctrl_a.call("export_replay"))
	var parsed_replay: Dictionary = JSON.parse_string(replay_json) as Dictionary

	var map_b: BattleMapState = _build_50_turn_arena()
	var ctrl_b: RefCounted = ctrl_s.new(map_b, seed_val, [1, 3], 40)
	assert_true(bool(ctrl_b.call("replay_from_dict", parsed_replay)), "50-turn replay must succeed cleanly")

	assert_eq(int(ctrl_b.get("current_round")), int(ctrl_a.get("current_round")))
	assert_eq(int(ctrl_b.get("current_faction_id")), int(ctrl_a.get("current_faction_id")))
	assert_eq(int(ctrl_b.get("outcome")), int(ctrl_a.get("outcome")))
	assert_eq(
		(ctrl_b.get("context") as BattleContext).rng.get_state(),
		(ctrl_a.get("context") as BattleContext).rng.get_state(),
		"50-turn RNG state must match bit-for-bit"
	)

	var units_a: Array[BattleUnit] = map_a.get_all_units()
	var units_b: Array[BattleUnit] = map_b.get_all_units()
	assert_eq(units_b.size(), units_a.size(), "Living unit count after 50+ turns must match")

	units_a.sort_custom(func(x: BattleUnit, y: BattleUnit) -> bool: return x.unit_id < y.unit_id)
	units_b.sort_custom(func(x: BattleUnit, y: BattleUnit) -> bool: return x.unit_id < y.unit_id)

	for idx: int in range(units_a.size()):
		var ua: BattleUnit = units_a[idx]
		var ub: BattleUnit = units_b[idx]
		assert_eq(ub.unit_id, ua.unit_id)
		assert_eq(ub.hex_position, ua.hex_position, "Zero position drift for unit %d" % ua.unit_id)
		assert_eq(ub.state.current_hp, ua.state.current_hp, "Zero HP drift for unit %d" % ua.unit_id)
		assert_eq(ub.state.morale, ua.state.morale, "Zero Morale drift for unit %d" % ua.unit_id)
		assert_eq(ub.state.chaos_turns, ua.state.chaos_turns)
		assert_eq(ub.state.current_mp, ua.state.current_mp)


func test_all_core_scripts_are_100_percent_scenetree_independent() -> void:
	for sim_dir: String in ["res://sim/state", "res://sim/commands", "res://sim/rules"]:
		var dir: DirAccess = DirAccess.open(sim_dir)
		assert_not_null(dir, sim_dir + " must exist")
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			if entry.ends_with(".gd"):
				var path: String = sim_dir.path_join(entry)
				var f: FileAccess = FileAccess.open(path, FileAccess.READ)
				var src: String = f.get_as_text()
				f.close()
				assert_false(src.contains("extends Node"), path + " must NOT extend Node")
				assert_false(src.contains("get_tree()"), path + " must NOT touch SceneTree")
				assert_false(src.contains("RenderingServer"), path + " must NOT touch RenderingServer")
			entry = dir.get_next()
		dir.list_dir_end()
