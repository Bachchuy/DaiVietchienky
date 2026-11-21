extends "res://tests/test_case.gd"

const SCENARIO_LOADER_PATH: String = "res://sim/state/scenario_loader.gd"

const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const CmdsScript = preload("res://sim/commands/battle_commands.gd")
const ControllerScript = preload("res://sim/state/battle_game_controller.gd")
const AIProfileScript = preload("res://sim/ai/ai_difficulty_profile.gd")
const AIMatrixScript = preload("res://sim/ai/ai_decision_matrix.gd")
const LoaderScript = preload("res://sim/state/static_data_loader.gd")


func _load_scenario_loader() -> GDScript:
	var s: GDScript = load(SCENARIO_LOADER_PATH) as GDScript
	assert_not_null(s, "ScenarioLoader script must exist at " + SCENARIO_LOADER_PATH)
	return s


func test_slice01_json_schema_and_zero_maphack_before_round4() -> void:
	var sl: GDScript = _load_scenario_loader()
	if sl == null:
		return

	var loader_cls: GDScript = LoaderScript
	var stages: Dictionary = loader_cls.call("load_stage_settings")
	assert_has(stages, 10101, "registry.tres must contain stage_id 10101")
	var tactics: Array[TacticDef] = LoaderScript.load_tactic_defs()
	assert_gte(float(tactics.size()), 1.0, "registry.tres must contain Hich Tuong Si")

	var ctrl: BattleGameController = sl.call("load_stage", 10101, 12880409) as BattleGameController
	assert_not_null(ctrl)
	if ctrl == null:
		return

	assert_eq(ctrl.context.map_state.width, 12)
	assert_eq(ctrl.context.map_state.height, 10)
	assert_eq(ctrl.max_rounds, 10)
	assert_false(ctrl.enable_economy, "Slice-01 MUST have enable_economy = false")

	var dock_axial: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(2, 8))
	assert_eq(ctrl.context.map_state.get_terrain(dock_axial), MapStateScript.TerrainType.ROAD_PORT)
	assert_eq(ctrl.director.get_area_owner("signal_dock"), 1, "Dai Viet holds SignalDock at battle start")

	var stake_hexes: Array[Vector2i] = ctrl.director.get_area_hexes("area_bai_coc")
	assert_gte(float(stake_hexes.size()), 4.0)
	for sh: Vector2i in stake_hexes:
		assert_eq(
			ctrl.context.map_state.get_terrain(sh),
			MapStateScript.TerrainType.DEEP_WATER,
			"Pre-Round-4 area_bai_coc MUST appear as normal DEEP_WATER (Zero Map-Hack)"
		)

	# Verify key generals Tran Quoc Tuan (1001), Tran Khanh Du (1002), and O Ma Nhi (9001) exist
	var found_1001: bool = false
	var found_1002: bool = false
	var found_9001: bool = false
	for u: BattleUnit in ctrl.context.map_state.get_all_units():
		if u.general_id == 1001:
			found_1001 = true
		elif u.general_id == 1002:
			found_1002 = true
		elif u.general_id == 9001:
			found_9001 = true
	assert_true(found_1001, "Tran Quoc Tuan (1001) must be placed")
	assert_true(found_1002, "Tran Khanh Du (1002) must be placed")
	assert_true(found_9001, "O Ma Nhi (9001) must be placed")


func test_slice01_round4_tide_fall_and_instant_victory_both_branches() -> void:
	var sl: GDScript = _load_scenario_loader()
	if sl == null:
		return

	var ctrl: BattleGameController = sl.call("load_stage", 10101, 1288) as BattleGameController
	assert_not_null(ctrl)
	if ctrl == null:
		return

	var stake_hexes: Array[Vector2i] = ctrl.director.get_area_hexes("area_bai_coc")
	var trap_hex: Vector2i = stake_hexes[0]
	var enemy_ship: BattleUnit = null
	for u: BattleUnit in ctrl.context.map_state.get_all_units():
		if u.faction_id == 2 and u.domain == UnitScript.Domain.NAVAL and u.general_id == 0:
			enemy_ship = u
			break
	assert_not_null(enemy_ship)

	# Ensure enemy warship sits inside area_bai_coc when Round 4 begins
	if ctrl.context.map_state.get_unit_at(trap_hex) != null:
		ctrl.context.map_state.remove_unit(ctrl.context.map_state.get_unit_at(trap_hex).unit_id)
	ctrl.context.map_state.move_unit(enemy_ship, trap_hex)
	var pre_hp: int = enemy_ship.state.current_hp
	var expected_loss: int = maxi(1, int(floor(float(enemy_ship.state.max_hp) * 0.35 + 0.5)))

	# Advance Rounds 1 -> 3
	for _r: int in range(3):
		assert_false(ctrl.event_manager.triggered_event_ids.has("evt_10101_tide_fall"))
		ctrl.submit_command(CmdsScript.EndTurnCommand.new(1))
		ctrl.submit_command(CmdsScript.EndTurnCommand.new(2))

	# Head of Round 4: MapPhase_TideFall executes!
	assert_eq(ctrl.current_round, 4)
	assert_has(ctrl.event_manager.triggered_event_ids, "evt_10101_tide_fall")
	for sh: Vector2i in stake_hexes:
		assert_eq(ctrl.context.map_state.get_terrain(sh), MapStateScript.TerrainType.STAKED_WATER)
	assert_eq(enemy_ship.state.current_hp, pre_hp - expected_loss, "Enemy warship takes exact 35% MaxHP stake damage")
	assert_eq(enemy_ship.state.march_disabled_turns, 2)
	assert_eq(enemy_ship.state.morale, UnitStateScript.MoraleLevel.CHAOS)

	# Ambush reinforcements spawned cleanly
	assert_not_null(ctrl.context.get_unit(106), "Dai Viet ambush unit 106 spawns on Round 4 TideFall")
	assert_not_null(ctrl.context.get_unit(107), "Dai Viet ambush unit 107 spawns on Round 4 TideFall")

	# Branch 1 (Instant Victory): Defeat O Ma Nhi (9001) while SignalDock held by Dai Viet -> Victory at Round 4!
	var o_ma_nhi: BattleUnit = null
	for u: BattleUnit in ctrl.context.map_state.get_all_units():
		if u.general_id == 9001:
			o_ma_nhi = u
			break
	assert_not_null(o_ma_nhi)
	var dv_striker: BattleUnit = ctrl.context.get_unit(101)
	o_ma_nhi.state.current_hp = 5
	ctrl.context.map_state.move_unit(o_ma_nhi, dv_striker.hex_position + Vector2i(1, 0))
	assert_true(ctrl.submit_command(CmdsScript.AttackCommand.new(1, dv_striker.unit_id, o_ma_nhi.unit_id)))
	assert_eq(ctrl.outcome, ControllerScript.BattleOutcome.VICTORY, "Slaying O Ma Nhi while holding SignalDock wins instantly")
	var stars_res: Dictionary = ctrl.victory_evaluator.evaluate_stars(ctrl)
	assert_eq(int(stars_res["stars"]), 3, "Round 4 instant win with low casualties earns 3 stars")

	# Branch 2 (Hold SignalDock & >=75% enemy casualties at Round 10 end while 9001 alive)
	var ctrl2: BattleGameController = sl.call("load_stage", 10101, 4444) as BattleGameController
	var enemies_removed: int = 0
	var all_e: Array[BattleUnit] = []
	for u: BattleUnit in ctrl2.context.map_state.get_all_units():
		if u.faction_id == 2 and u.general_id != 9001:
			all_e.append(u)
	for eu: BattleUnit in all_e:
		ctrl2.context.map_state.remove_unit(eu.unit_id)
		enemies_removed += 1
	assert_gte(float(enemies_removed), 6.0)
	for _r2: int in range(10):
		if ctrl2.outcome != ControllerScript.BattleOutcome.ONGOING:
			break
		ctrl2.submit_command(CmdsScript.EndTurnCommand.new(1))
		if ctrl2.outcome != ControllerScript.BattleOutcome.ONGOING:
			break
		ctrl2.submit_command(CmdsScript.EndTurnCommand.new(2))
	assert_eq(ctrl2.outcome, ControllerScript.BattleOutcome.VICTORY, "Hold & >=75% casualties at Round 10 wins")


func test_slice01_100_consecutive_ai_vs_ai_matches_no_softlock_and_fast_turns() -> void:
	var sl: GDScript = _load_scenario_loader()
	if sl == null:
		return

	var ai_p1 := AIMatrixScript.new(AIProfileScript.create_preset(&"normal"))
	var ai_p2 := AIMatrixScript.new(AIProfileScript.create_preset(&"normal"))

	var max_turn_ms: float = 0.0
	var victories: int = 0
	var defeats: int = 0
	var tide_events_verified: int = 0

	var first_replay: Dictionary = {}
	var first_outcome: int = 0
	var first_round: int = 0
	var first_rng_state: int = 0
	var first_unit_hps: Dictionary = {}

	var match_count: int = 100 if stress_mode else 4
	var fog_limit: int = 20 if stress_mode else 2
	for match_idx: int in range(match_count):
		var seed_val: int = 1001 + match_idx
		var ctrl: BattleGameController = sl.call("load_stage", 10101, seed_val) as BattleGameController
		if match_idx < fog_limit:
			ctrl.context.enable_fog_of_war = true

		var safety_turns: int = 0
		while ctrl.outcome == ControllerScript.BattleOutcome.ONGOING and safety_turns < 24:
			var fac: int = ctrl.current_faction_id
			var ai_brain: AIDecisionMatrix = ai_p1 if fac == 1 else ai_p2
			var rep: Dictionary = ai_brain.execute_faction_turn(ctrl, fac, ctrl.director)
			var elapsed: float = float(rep.get("elapsed_ms", 0.0))
			if elapsed > max_turn_ms:
				max_turn_ms = elapsed
			safety_turns += 1

		assert_ne(ctrl.outcome, ControllerScript.BattleOutcome.ONGOING, "Match %d must terminate (no soft-lock)" % match_idx)
		assert_lt(float(safety_turns), 24.0)

		if ctrl.current_round >= 4 and ctrl.outcome != ControllerScript.BattleOutcome.DEFEAT or ctrl.event_manager.triggered_event_ids.has("evt_10101_tide_fall"):
			if ctrl.current_round >= 4 and ctrl.event_manager.triggered_event_ids.has("evt_10101_tide_fall"):
				tide_events_verified += 1

		if ctrl.outcome == ControllerScript.BattleOutcome.VICTORY:
			victories += 1
		else:
			defeats += 1

		if match_idx == 0:
			first_replay = ctrl.export_replay()
			first_outcome = int(ctrl.outcome)
			first_round = ctrl.current_round
			first_rng_state = ctrl.context.rng.get_state()
			for u: BattleUnit in ctrl.context.map_state.get_all_units():
				first_unit_hps[u.unit_id] = [u.hex_position, u.state.current_hp]

	assert_eq(victories + defeats, match_count, "All %d AI-vs-AI matches must complete cleanly" % match_count)
	assert_lt(max_turn_ms, 1500.0, "Max AI turn time across 100 matches must stay < 1500ms")
	assert_gt(float(tide_events_verified), 0.0, "Round 4 TideFall event must fire in multi-round AI matches")

	# Verify deterministic replay of AI-vs-AI match #0
	var replay_json: String = JSON.stringify(first_replay)
	var parsed_replay: Dictionary = JSON.parse_string(replay_json) as Dictionary
	var ctrl_rep: BattleGameController = sl.call("load_stage", 10101, 1001) as BattleGameController
	ctrl_rep.context.enable_fog_of_war = true
	assert_true(ctrl_rep.replay_from_dict(parsed_replay), "AI-vs-AI match #0 replay must succeed")
	assert_eq(int(ctrl_rep.outcome), first_outcome)
	assert_eq(ctrl_rep.current_round, first_round)
	assert_eq(ctrl_rep.context.rng.get_state(), first_rng_state)
	for uid: int in first_unit_hps.keys():
		var rep_u: BattleUnit = ctrl_rep.context.get_unit(uid)
		assert_not_null(rep_u)
		var snap: Array = first_unit_hps[uid]
		assert_eq(rep_u.hex_position, snap[0])
		assert_eq(rep_u.state.current_hp, snap[1])
