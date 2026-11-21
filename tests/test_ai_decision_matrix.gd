extends "res://tests/test_case.gd"

const DIRECTOR_PATH: String = "res://sim/state/scenario_director.gd"
const VIEW_PATH: String = "res://sim/state/ai_visible_map_view.gd"
const PROFILE_PATH: String = "res://sim/ai/ai_difficulty_profile.gd"
const CANDIDATE_PATH: String = "res://sim/ai/ai_action_candidate.gd"
const MATRIX_PATH: String = "res://sim/ai/ai_decision_matrix.gd"

const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const ContextScript = preload("res://sim/state/battle_context.gd")
const ControllerScript = preload("res://sim/state/battle_game_controller.gd")
const RngScript = preload("res://sim/rules/seeded_rng.gd")


func _load_ai_scripts() -> Dictionary:
	var dir_s: GDScript = load(DIRECTOR_PATH) as GDScript
	var view_s: GDScript = load(VIEW_PATH) as GDScript
	var prof_s: GDScript = load(PROFILE_PATH) as GDScript
	var cand_s: GDScript = load(CANDIDATE_PATH) as GDScript
	var mat_s: GDScript = load(MATRIX_PATH) as GDScript
	assert_not_null(dir_s, "ScenarioDirector script must exist at " + DIRECTOR_PATH)
	assert_not_null(view_s, "AIVisibleMapView script must exist at " + VIEW_PATH)
	assert_not_null(prof_s, "AIDifficultyProfile script must exist at " + PROFILE_PATH)
	assert_not_null(cand_s, "AIActionCandidate script must exist at " + CANDIDATE_PATH)
	assert_not_null(mat_s, "AIDecisionMatrix script must exist at " + MATRIX_PATH)
	return {
		"director": dir_s,
		"view": view_s,
		"profile": prof_s,
		"candidate": cand_s,
		"matrix": mat_s,
	}


func _make_unit(uid: int, faction: int, col: int, row: int, mp: int = 6) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(col, row))
	u.max_mp = mp
	u.state.current_mp = mp
	u.base_atk = 40
	u.base_def = 10
	u.state.max_hp = 160
	u.state.current_hp = 160
	u.vision_range = 3
	return u


func test_ai_difficulty_profiles_exact_weights_and_additive_noise_order() -> void:
	var s: Dictionary = _load_ai_scripts()
	if s["profile"] == null:
		return
	var prof_s: GDScript = s["profile"]

	var easy: Resource = prof_s.create_preset(&"easy")
	assert_almost_eq(float(easy.get("w_atk")), 0.50, 0.001)
	assert_almost_eq(float(easy.get("w_pos")), 0.15, 0.001)
	assert_almost_eq(float(easy.get("w_obj")), 0.20, 0.001)
	assert_almost_eq(float(easy.get("w_skill")), 0.15, 0.001)
	assert_almost_eq(float(easy.get("noise_amp")), 18.0, 0.001)

	var normal: Resource = prof_s.create_preset(&"normal")
	assert_almost_eq(float(normal.get("w_atk")), 0.35, 0.001)
	assert_almost_eq(float(normal.get("w_pos")), 0.25, 0.001)
	assert_almost_eq(float(normal.get("w_obj")), 0.25, 0.001)
	assert_almost_eq(float(normal.get("w_skill")), 0.15, 0.001)
	assert_almost_eq(float(normal.get("noise_amp")), 6.0, 0.001)

	var hard: Resource = prof_s.create_preset(&"hard")
	assert_almost_eq(float(hard.get("w_atk")), 0.30, 0.001)
	assert_almost_eq(float(hard.get("w_pos")), 0.25, 0.001)
	assert_almost_eq(float(hard.get("w_obj")), 0.25, 0.001)
	assert_almost_eq(float(hard.get("w_skill")), 0.20, 0.001)
	assert_almost_eq(float(hard.get("noise_amp")), 1.5, 0.001)

	var challenge: Resource = prof_s.create_preset(&"challenge")
	assert_almost_eq(float(challenge.get("w_atk")), 0.28, 0.001)
	assert_almost_eq(float(challenge.get("w_pos")), 0.27, 0.001)
	assert_almost_eq(float(challenge.get("w_obj")), 0.25, 0.001)
	assert_almost_eq(float(challenge.get("w_skill")), 0.20, 0.001)
	assert_almost_eq(float(challenge.get("noise_amp")), 0.5, 0.001)

	# Additive noise preserves negative score inequality (-20.0 + eta > -30.0 + eta for |eta| <= 0.5)
	var rng := RngScript.new(42)
	var amp: float = float(challenge.get("noise_amp"))
	for _i: int in range(50):
		var eta_a: float = rng.roll_float_range(-amp, amp)
		var eta_b: float = rng.roll_float_range(-amp, amp)
		assert_gt(-20.0 + eta_a, -30.0 + eta_b, "Additive noise preserves negative utility ordering")


func test_zero_map_hack_fog_of_war_and_hidden_stakes() -> void:
	var s: Dictionary = _load_ai_scripts()
	if s["view"] == null or s["matrix"] == null or s["profile"] == null:
		return

	var map_state := MapStateScript.new(12, 10, MapStateScript.TerrainType.DEEP_WATER)
	map_state.staked_water_owner_faction = 1

	var ai_ship: BattleUnit = _make_unit(201, 3, 2, 5, 8)
	ai_ship.domain = UnitScript.Domain.NAVAL
	ai_ship.command_branch = UnitScript.CommandBranch.NAVAL_HEAVY
	ai_ship.vision_range = 2
	map_state.place_unit(ai_ship)

	# Enemy unit far outside vision range (col 9, row 5 -> distance 7)
	var far_enemy: BattleUnit = _make_unit(101, 1, 9, 5, 6)
	far_enemy.domain = UnitScript.Domain.NAVAL
	map_state.place_unit(far_enemy)

	# Enemy scout inside vision_range = 2, standing in FOREST with is_invisible = true (dist == 2)
	var forest_hex: Vector2i = ai_ship.hex_position + Vector2i(2, 0)
	map_state.set_terrain(forest_hex, MapStateScript.TerrainType.FOREST)
	var hidden_scout: BattleUnit = _make_unit(102, 1, 0, 0, 6)
	hidden_scout.hex_position = forest_hex
	hidden_scout.state.is_invisible = true
	map_state.place_unit(hidden_scout)

	var ctx := ContextScript.new(map_state, 1288)
	ctx.enable_fog_of_war = true
	ctx.set_trap_cell(ai_ship.hex_position + Vector2i(1, 0), true)

	var vis_view: RefCounted = s["view"].from_context(ctx, 3)
	var vis_enemies: Array = vis_view.call("get_visible_enemies")
	assert_eq(vis_enemies.size(), 0, "Zero Map-Hack: far enemy & invisible forest scout must be hidden")

	var matrix: RefCounted = s["matrix"].new(s["profile"].create_preset(&"hard"))
	var cands: Array = matrix.call("generate_candidates", ai_ship, vis_view)
	for c: RefCounted in cands:
		assert_ne(int(c.get("action_kind")), int(s["candidate"].ActionKind.ATTACK), "AI must not target invisible/unseen units")

	# Before Round 4 TideFall, future stake cell is DEEP_WATER -> NO -50.0 stake penalty!
	var future_stake_hex: Vector2i = ai_ship.hex_position + Vector2i(1, 0)
	var score_water: float = float(matrix.call("evaluate_position", future_stake_hex, ai_ship, vis_view, null))
	assert_gt(score_water, -30.0, "Hidden trap on DEEP_WATER must NOT incur StakedWater penalty")

	# After MapPhase_TideFall reveals STAKED_WATER -> AI sees it and penalizes -50.0!
	map_state.set_terrain(future_stake_hex, MapStateScript.TerrainType.STAKED_WATER)
	var vis_after: RefCounted = s["view"].from_context(ctx, 3)
	var score_staked: float = float(matrix.call("evaluate_position", future_stake_hex, ai_ship, vis_after, null))
	assert_lte(score_staked, score_water - 45.0, "Revealed STAKED_WATER must apply -50.0 penalty")


func test_evaluators_kill_securing_objective_and_pincer_priority() -> void:
	var s: Dictionary = _load_ai_scripts()
	if s["director"] == null or s["view"] == null or s["matrix"] == null:
		return

	var map_state := MapStateScript.new(12, 10, MapStateScript.TerrainType.PLAINS)
	var ai_unit: BattleUnit = _make_unit(201, 3, 4, 5, 6)
	ai_unit.base_atk = 50
	map_state.place_unit(ai_unit)

	# Low-HP killable enemy vs Healthy enemy
	var low_enemy: BattleUnit = _make_unit(101, 1, 5, 5, 6)
	low_enemy.state.current_hp = 10
	map_state.place_unit(low_enemy)

	var healthy_enemy: BattleUnit = _make_unit(102, 1, 4, 4, 6)
	healthy_enemy.state.current_hp = 160
	map_state.place_unit(healthy_enemy)

	var ctx := ContextScript.new(map_state, 555)
	var vis_view: RefCounted = s["view"].from_context(ctx, 3)
	var matrix: RefCounted = s["matrix"].new(s["profile"].create_preset(&"hard"))

	var cand_kill: RefCounted = s["candidate"].new()
	cand_kill.set("action_kind", s["candidate"].ActionKind.ATTACK)
	cand_kill.set("dest_hex", ai_unit.hex_position)
	cand_kill.set("target_unit_id", low_enemy.unit_id)

	var cand_chip: RefCounted = s["candidate"].new()
	cand_chip.set("action_kind", s["candidate"].ActionKind.ATTACK)
	cand_chip.set("dest_hex", ai_unit.hex_position)
	cand_chip.set("target_unit_id", healthy_enemy.unit_id)

	var s_kill: float = float(matrix.call("evaluate_attack", cand_kill, ai_unit, vis_view))
	var s_chip: float = float(matrix.call("evaluate_attack", cand_chip, ai_unit, vis_view))
	assert_gt(s_kill, s_chip + 70.0, "KillSecuring (+80) must strongly beat chipping healthy target")

	# ObjectiveEvaluator: capturing SignalDock (+90) & targeting scenario General (+50)
	var director: RefCounted = s["director"].new()
	var dock_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(2, 8))
	director.call("register_area", "signal_dock", [dock_hex], 1, true)
	var obj_gens: Array[int] = [1001]
	director.call("set_target_generals", 3, obj_gens)

	var cand_capture: RefCounted = s["candidate"].new()
	cand_capture.set("action_kind", s["candidate"].ActionKind.WAIT)
	cand_capture.set("dest_hex", dock_hex)
	var obj_cap_score: float = float(matrix.call("evaluate_objective", cand_capture, ai_unit, vis_view, director))
	assert_gte(obj_cap_score, 90.0, "Stepping on enemy SignalDock must yield >= +90.0 objective score")

	low_enemy.general_id = 1001
	var vis_gen_view: RefCounted = s["view"].from_context(ctx, 3)
	var obj_gen_score: float = float(matrix.call("evaluate_objective", cand_kill, ai_unit, vis_gen_view, director))
	assert_gte(obj_gen_score, 50.0, "Attacking scenario target general must yield >= +50.0 objective score")


func _build_skirmish_for_ai_perf() -> BattleMapState:
	var map_state := MapStateScript.new(12, 10, MapStateScript.TerrainType.PLAINS)
	for i: int in range(4):
		var ai_u: BattleUnit = _make_unit(200 + i, 3, 8, 2 + i * 2, 6)
		map_state.place_unit(ai_u)
		var pl_u: BattleUnit = _make_unit(100 + i, 1, 3, 2 + i * 2, 6)
		map_state.place_unit(pl_u)
	# Extra AI archers & cavalry to total 8 AI units
	for j: int in range(4):
		var extra: BattleUnit = _make_unit(210 + j, 3, 9, 1 + j * 2, 8)
		extra.max_range = 2
		map_state.place_unit(extra)
	return map_state


func test_ai_full_turn_determinism_and_under_1_5s_budget() -> void:
	var s: Dictionary = _load_ai_scripts()
	if s["matrix"] == null or s["director"] == null:
		return

	var director: RefCounted = s["director"].new()
	director.call("register_area", "signal_dock", [HexMathScript.odd_r_to_axial(Vector2i(2, 8))], 1, true)

	var map_a: BattleMapState = _build_skirmish_for_ai_perf()
	var ctrl_a := ControllerScript.new(map_a, 12880409, [3, 1], 10)
	ctrl_a.start_battle()
	var ai_a: RefCounted = s["matrix"].new(s["profile"].create_preset(&"normal"))

	var t0: int = Time.get_ticks_usec()
	ai_a.call("execute_faction_turn", ctrl_a, 3, director)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	assert_lt(elapsed_ms, 1500.0, "Full AI faction turn (8 units) must finish in < 1.5s")
	assert_eq(ctrl_a.current_faction_id, 1, "AI turn must cleanly end and hand over to Faction 1")

	# Run identical scenario B with same seed -> 100% deterministic
	var map_b: BattleMapState = _build_skirmish_for_ai_perf()
	var ctrl_b := ControllerScript.new(map_b, 12880409, [3, 1], 10)
	ctrl_b.start_battle()
	var ai_b: RefCounted = s["matrix"].new(s["profile"].create_preset(&"normal"))
	ai_b.call("execute_faction_turn", ctrl_b, 3, director)

	assert_eq(ctrl_b.context.rng.get_state(), ctrl_a.context.rng.get_state(), "AI turn RNG state must match 100%")
	var units_a: Array[BattleUnit] = map_a.get_all_units()
	units_a.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.unit_id < b.unit_id)
	for ua: BattleUnit in units_a:
		var ub: BattleUnit = ctrl_b.context.get_unit(ua.unit_id)
		assert_not_null(ub)
		assert_eq(ub.hex_position, ua.hex_position, "AI unit %d hex must match" % ua.unit_id)
		assert_eq(ub.state.current_hp, ua.state.current_hp, "AI unit %d HP must match" % ua.unit_id)


func test_ai_scripts_are_scenetree_independent() -> void:
	var dir: DirAccess = DirAccess.open("res://sim/ai")
	assert_not_null(dir, "res://sim/ai must exist")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry.ends_with(".gd"):
			var path: String = "res://sim/ai/".path_join(entry)
			var f: FileAccess = FileAccess.open(path, FileAccess.READ)
			var src: String = f.get_as_text()
			f.close()
			assert_false(src.contains("extends Node"), path + " must NOT extend Node")
			assert_false(src.contains("get_tree()"), path + " must NOT touch SceneTree")
			assert_false(src.contains("RenderingServer"), path + " must NOT touch RenderingServer")
		entry = dir.get_next()
	dir.list_dir_end()
