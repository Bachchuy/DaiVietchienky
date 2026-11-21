extends "res://tests/test_case.gd"

const EVT_MGR_PATH: String = "res://sim/rules/scenario_event_manager.gd"
const VIC_EVAL_PATH: String = "res://sim/rules/scenario_victory_evaluator.gd"

const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const DirectorScript = preload("res://sim/state/scenario_director.gd")
const ControllerScript = preload("res://sim/state/battle_game_controller.gd")
const CmdsScript = preload("res://sim/commands/battle_commands.gd")
const LoaderScript = preload("res://sim/state/static_data_loader.gd")


func _load_scenario_scripts() -> Dictionary:
	var evt_s: GDScript = load(EVT_MGR_PATH) as GDScript
	var vic_s: GDScript = load(VIC_EVAL_PATH) as GDScript
	assert_not_null(evt_s, "ScenarioEventManager script must exist at " + EVT_MGR_PATH)
	assert_not_null(vic_s, "ScenarioVictoryEvaluator script must exist at " + VIC_EVAL_PATH)
	return {"evt": evt_s, "vic": vic_s}


func _make_unit(uid: int, faction: int, col: int, row: int, hp: int = 200) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(col, row))
	u.max_mp = 6
	u.state.current_mp = 6
	u.base_hp = hp
	u.state.max_hp = hp
	u.state.current_hp = hp
	return u


func test_trigger_conditions_and_or_once_flag_and_restore() -> void:
	var s: Dictionary = _load_scenario_scripts()
	if s["evt"] == null:
		return

	var map_state := MapStateScript.new(12, 10)
	map_state.set_faction_team(2, 2)
	var u1: BattleUnit = _make_unit(1, 1, 2, 8)
	u1.general_id = 1001
	map_state.place_unit(u1)

	var director := DirectorScript.new()
	director.register_area("signal_dock", [HexMathScript.odd_r_to_axial(Vector2i(2, 8))], 1, true)

	var ctrl := ControllerScript.new(map_state, 100, [1, 2], 10)
	var evt_mgr: RefCounted = s["evt"].new()

	var events_cfg: Array[Dictionary] = [
		{
			"event_id": "evt_and_check",
			"trigger_type": "OnRoundStart",
			"logic_operator": "AND",
			"once": true,
			"conditions": [
				{"field": "current_round", "op": "==", "value": 1},
				{"field": "area_owner", "area_id": "signal_dock", "op": "==", "value": 1},
			],
			"results": [{"action": "PlayDialogue", "dialogue_id": "dlg_and"}],
		},
		{
			"event_id": "evt_or_check",
			"trigger_type": "OnRoundStart",
			"logic_operator": "OR",
			"once": true,
			"conditions": [
				{"field": "current_round", "op": "==", "value": 99},
				{"field": "general_alive", "general_id": 1001, "op": "==", "value": true},
			],
			"results": [{"action": "PlayDialogue", "dialogue_id": "dlg_or"}],
		},
	]

	evt_mgr.call("setup", events_cfg, ["evt_and_check"]) # Simulate Save/Resume where evt_and_check already ran!
	ctrl.current_round = 1
	ctrl.context.set("current_round", 1)
	evt_mgr.call("check_and_execute", "OnRoundStart", ctrl.context, ctrl, director)

	var triggered: Array = evt_mgr.get("triggered_event_ids")
	assert_has(triggered, "evt_and_check")
	assert_has(triggered, "evt_or_check", "OR gate fires when 2nd condition is true")

	var dlg_queue: Array = evt_mgr.get("dialogue_queue")
	assert_eq(dlg_queue.size(), 1, "Restored once-event evt_and_check MUST NOT fire again")
	assert_eq(str(dlg_queue[0]), "dlg_or")


func test_tide_fall_alter_terrain_area_effect_and_bfs_reinforcements() -> void:
	var s: Dictionary = _load_scenario_scripts()
	if s["evt"] == null:
		return

	var map_state := MapStateScript.new(12, 10, MapStateScript.TerrainType.PLAINS)
	map_state.set_faction_team(2, 2)
	map_state.staked_water_owner_faction = 1

	var stake_offsets: Array[Vector2i] = [Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5), Vector2i(7, 5)]
	var stake_axials: Array[Vector2i] = []
	for off: Vector2i in stake_offsets:
		var ax: Vector2i = HexMathScript.odd_r_to_axial(off)
		stake_axials.append(ax)
		map_state.set_terrain(ax, MapStateScript.TerrainType.DEEP_WATER)

	# Enemy heavy warship inside area_bai_coc (max_hp = 600)
	var enemy_ship: BattleUnit = _make_unit(201, 2, 6, 4, 600)
	enemy_ship.domain = UnitScript.Domain.NAVAL
	enemy_ship.command_branch = UnitScript.CommandBranch.NAVAL_HEAVY
	map_state.place_unit(enemy_ship)

	# Friendly Dai Viet boat also inside area_bai_coc (must NOT take stake trap damage!)
	var ally_boat: BattleUnit = _make_unit(102, 1, 5, 4, 300)
	ally_boat.domain = UnitScript.Domain.NAVAL
	ally_boat.command_branch = UnitScript.CommandBranch.NAVAL_LIGHT
	map_state.place_unit(ally_boat)

	# Occupy desired reinforcement hex (3, 4) so BFS find_nearest_free_hex must shift to adjacent free Land hex!
	var blocker: BattleUnit = _make_unit(101, 1, 3, 4, 300)
	map_state.place_unit(blocker)

	var director := DirectorScript.new()
	director.register_area("area_bai_coc", stake_axials, 0, false)

	var ctrl := ControllerScript.new(map_state, 1288, [1, 2], 10)
	ctrl.context.set("troop_defs", LoaderScript.load_troop_settings())
	ctrl.set("director", director)

	var evt_mgr: RefCounted = s["evt"].new()
	var events_cfg: Array[Dictionary] = [
		{
			"event_id": "evt_10101_tide_fall",
			"name": "MapPhase_TideFall",
			"trigger_type": "OnRoundStart",
			"logic_operator": "AND",
			"once": true,
			"conditions": [{"field": "current_round", "op": "==", "value": 4}],
			"results": [
				{"action": "CameraFocus", "target_hex": {"col": 6, "row": 5}, "duration": 1.0},
				{"action": "PlayDialogue", "dialogue_id": "talk_trieu_rut"},
				{"action": "AlterTerrain", "area_id": "area_bai_coc", "new_terrain": "StakedWater"},
				{
					"action": "ApplyAreaEffect",
					"area_id": "area_bai_coc",
					"target_faction_id": 2,
					"hp_loss_max_ratio": 0.35,
					"march_disabled_turns": 2,
					"chaos_turns": 1,
				},
				{
					"action": "SpawnReinforcements",
					"spawn_policy": "find_nearest_free_hex",
					"placements": [
						{
							"unit_id": 106,
							"faction_id": 1,
							"troop_id": 40101,
							"troop_stack": 2,
							"hex": {"col": 3, "row": 4},
						}
					],
				},
			],
		}
	]
	evt_mgr.call("setup", events_cfg, [])
	ctrl.set("event_manager", evt_mgr)
	ctrl.start_battle()

	# Rounds 1..3: stakes MUST remain hidden DEEP_WATER!
	for r: int in range(1, 4):
		assert_eq(ctrl.current_round, r)
		assert_eq(map_state.get_terrain(stake_axials[1]), MapStateScript.TerrainType.DEEP_WATER)
		ctrl.submit_command(CmdsScript.EndTurnCommand.new(1))
		ctrl.submit_command(CmdsScript.EndTurnCommand.new(2))

	# Now Round 4 just started -> MapPhase_TideFall MUST have fired!
	assert_eq(ctrl.current_round, 4)
	assert_has(evt_mgr.get("triggered_event_ids"), "evt_10101_tide_fall")
	for ax: Vector2i in stake_axials:
		assert_eq(map_state.get_terrain(ax), MapStateScript.TerrainType.STAKED_WATER, "TideFall transforms area_bai_coc to STAKED_WATER")

	assert_eq(enemy_ship.state.current_hp, 390, "Enemy ship takes 35% of 600 = 210 damage -> 390 HP")
	assert_eq(enemy_ship.state.march_disabled_turns, 2)
	assert_eq(enemy_ship.state.morale, UnitStateScript.MoraleLevel.CHAOS)
	assert_eq(enemy_ship.state.chaos_turns, 1)
	assert_eq(ally_boat.state.current_hp, 300, "Dai Viet boat immune to own stakes")

	var ambusher: BattleUnit = ctrl.context.get_unit(106)
	assert_not_null(ambusher, "Reinforcement unit 106 must spawn")
	assert_ne(ambusher.hex_position, blocker.hex_position, "BFS find_nearest_free_hex must NOT overwrite occupied hex")
	assert_eq(HexMathScript.hex_distance(ambusher.hex_position, blocker.hex_position), 1)


func test_victory_two_branches_defeat_and_three_star_evaluator() -> void:
	var s: Dictionary = _load_scenario_scripts()
	if s["vic"] == null:
		return

	var victory_cfg: Array[Dictionary] = [
		{"type": "DefeatGeneralWhileHoldingArea", "target_general_id": 9001, "required_area_id": "signal_dock", "instant": true},
		{"type": "HoldAreaAndEnemyCasualtyAtMaxRound", "required_area_id": "signal_dock", "min_enemy_defeated_percent": 75, "at_round": 10},
	]
	var defeat_cfg: Array[Dictionary] = [
		{"type": "LoseKeyArea", "area_id": "signal_dock"},
		{"type": "GeneralDefeated", "target_general_id": 1001},
		{"type": "AllUnitsEliminated", "faction_id": 1},
		{"type": "MaxRoundsUnfulfilled", "max_rounds": 10},
	]
	var star_cfg: Array[Dictionary] = [
		{"star": 1, "type": "Victory"},
		{"star": 2, "type": "MaxRoundLimit", "max_rounds": 8},
		{"star": 3, "type": "CasualtyHpPercentLimit", "max_loss_percent": 20},
	]

	# Branch 1: Instant victory at Round 1 by defeating General 9001 while holding SignalDock -> 3 Stars!
	var map1 := MapStateScript.new(12, 10)
	map1.set_faction_team(2, 2)
	var dv_lord: BattleUnit = _make_unit(101, 1, 2, 8, 500)
	dv_lord.general_id = 1001
	dv_lord.base_atk = 150
	var dv_guard: BattleUnit = _make_unit(102, 1, 3, 8, 500)
	var o_ma_nhi: BattleUnit = _make_unit(201, 2, 2, 7, 40)
	o_ma_nhi.general_id = 9001
	var extra_enemy: BattleUnit = _make_unit(202, 2, 9, 2, 200)
	for u: BattleUnit in [dv_lord, dv_guard, o_ma_nhi, extra_enemy]:
		map1.place_unit(u)

	var dir1 := DirectorScript.new()
	dir1.register_area("signal_dock", [HexMathScript.odd_r_to_axial(Vector2i(2, 8))], 1, true)
	var vic1: RefCounted = s["vic"].new(victory_cfg, defeat_cfg, star_cfg, 1, 10)
	vic1.call("register_initial_units", map1)

	var ctrl1 := ControllerScript.new(map1, 9001, [1, 2], 10)
	ctrl1.set("director", dir1)
	ctrl1.set("victory_evaluator", vic1)
	ctrl1.start_battle()

	ctrl1.submit_command(CmdsScript.AttackCommand.new(1, 101, 201))
	assert_eq(ctrl1.outcome, ControllerScript.BattleOutcome.VICTORY, "Killing 9001 while holding SignalDock wins instantly")
	var stars1: Dictionary = vic1.call("evaluate_stars", ctrl1)
	assert_eq(int(stars1["stars"]), 3, "Fast victory with low HP loss earns 3 stars")

	# Branch 2: Hold SignalDock at Round 10 with 75% enemy casualties (3/4 enemies dead, 9001 alive) -> Victory, 2 Stars (missed <=8 rounds)
	var map2 := MapStateScript.new(12, 10)
	map2.set_faction_team(2, 2)
	var dv2: BattleUnit = _make_unit(101, 1, 2, 8, 500)
	dv2.general_id = 1001
	map2.place_unit(dv2)
	var boss2: BattleUnit = _make_unit(201, 2, 9, 2, 200)
	boss2.general_id = 9001
	map2.place_unit(boss2)
	var e2_a: BattleUnit = _make_unit(202, 2, 9, 3, 200)
	var e2_b: BattleUnit = _make_unit(203, 2, 9, 4, 200)
	var e2_c: BattleUnit = _make_unit(204, 2, 9, 5, 200)
	map2.place_unit(e2_a)
	map2.place_unit(e2_b)
	map2.place_unit(e2_c)

	var dir2 := DirectorScript.new()
	dir2.register_area("signal_dock", [HexMathScript.odd_r_to_axial(Vector2i(2, 8))], 1, true)
	var vic2: RefCounted = s["vic"].new(victory_cfg, defeat_cfg, star_cfg, 1, 10)
	vic2.call("register_initial_units", map2)

	# Eliminate 3 out of 4 enemies -> 75% defeated
	map2.remove_unit(202)
	map2.remove_unit(203)
	map2.remove_unit(204)

	var ctrl2 := ControllerScript.new(map2, 42, [1, 2], 10)
	ctrl2.set("director", dir2)
	ctrl2.set("victory_evaluator", vic2)
	ctrl2.start_battle()
	for _round: int in range(9):
		ctrl2.submit_command(CmdsScript.EndTurnCommand.new(1))
		ctrl2.submit_command(CmdsScript.EndTurnCommand.new(2))
	assert_eq(ctrl2.current_round, 10)
	ctrl2.submit_command(CmdsScript.EndTurnCommand.new(1))
	ctrl2.submit_command(CmdsScript.EndTurnCommand.new(2))
	assert_eq(ctrl2.outcome, ControllerScript.BattleOutcome.VICTORY, "Hold SignalDock + >=75% casualties at Round 10 wins")
	var stars2: Dictionary = vic2.call("evaluate_stars", ctrl2)
	assert_eq(int(stars2["stars"]), 2, "Round 10 win skips Star 2 (<=8 rounds) -> 2 stars")

	# Defeat branch (a): Enemy steps onto SignalDock -> immediate LoseKeyArea DEFEAT
	var map3 := MapStateScript.new(12, 10)
	map3.set_faction_team(2, 2)
	var dv3: BattleUnit = _make_unit(101, 1, 1, 8, 300)
	dv3.general_id = 1001
	var raider: BattleUnit = _make_unit(201, 2, 3, 8, 200)
	raider.general_id = 9001
	map3.place_unit(dv3)
	map3.place_unit(raider)
	var dir3 := DirectorScript.new()
	var dock3: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(2, 8))
	dir3.register_area("signal_dock", [dock3], 1, true)
	var vic3: RefCounted = s["vic"].new(victory_cfg, defeat_cfg, star_cfg, 1, 10)
	vic3.call("register_initial_units", map3)
	var ctrl3 := ControllerScript.new(map3, 42, [1, 2], 10)
	ctrl3.set("director", dir3)
	ctrl3.set("victory_evaluator", vic3)
	ctrl3.start_battle()
	assert_eq(ctrl3.outcome, ControllerScript.BattleOutcome.ONGOING)
	ctrl3.submit_command(CmdsScript.EndTurnCommand.new(1))
	ctrl3.submit_command(CmdsScript.MarchCommand.new(2, 201, raider.hex_position, dock3))
	assert_eq(ctrl3.outcome, ControllerScript.BattleOutcome.DEFEAT, "Enemy capturing SignalDock causes instant LoseKeyArea defeat")

	# Defeat branch (b): Player Commander-in-Chief 1001 defeated -> immediate GeneralDefeated DEFEAT
	var map4 := MapStateScript.new(12, 10)
	map4.set_faction_team(2, 2)
	var dv4_lord: BattleUnit = _make_unit(101, 1, 2, 8, 20)
	dv4_lord.general_id = 1001
	var dv4_guard: BattleUnit = _make_unit(102, 1, 1, 8, 300)
	var killer4: BattleUnit = _make_unit(201, 2, 3, 8, 300)
	killer4.general_id = 9001
	killer4.base_atk = 150
	for u: BattleUnit in [dv4_lord, dv4_guard, killer4]:
		map4.place_unit(u)
	var dir4 := DirectorScript.new()
	dir4.register_area("signal_dock", [HexMathScript.odd_r_to_axial(Vector2i(2, 8))], 1, true)
	var vic4: RefCounted = s["vic"].new(victory_cfg, defeat_cfg, star_cfg, 1, 10)
	vic4.call("register_initial_units", map4)
	var ctrl4 := ControllerScript.new(map4, 42, [1, 2], 10)
	ctrl4.set("director", dir4)
	ctrl4.set("victory_evaluator", vic4)
	ctrl4.start_battle()
	ctrl4.submit_command(CmdsScript.EndTurnCommand.new(1))
	ctrl4.submit_command(CmdsScript.AttackCommand.new(2, 201, 101))
	assert_eq(ctrl4.outcome, ControllerScript.BattleOutcome.DEFEAT, "General 1001 defeated causes immediate GeneralDefeated defeat")

	# Defeat branch (c): Round 10 ends with < 75% enemy casualties -> MaxRoundsUnfulfilled DEFEAT
	var map5 := MapStateScript.new(12, 10)
	map5.set_faction_team(2, 2)
	var dv5: BattleUnit = _make_unit(101, 1, 2, 8, 300)
	dv5.general_id = 1001
	var e5_boss: BattleUnit = _make_unit(201, 2, 9, 2, 200)
	e5_boss.general_id = 9001
	var e5_b: BattleUnit = _make_unit(202, 2, 9, 3, 200)
	for u: BattleUnit in [dv5, e5_boss, e5_b]:
		map5.place_unit(u)
	var dir5 := DirectorScript.new()
	dir5.register_area("signal_dock", [HexMathScript.odd_r_to_axial(Vector2i(2, 8))], 1, true)
	var vic5: RefCounted = s["vic"].new(victory_cfg, defeat_cfg, star_cfg, 1, 10)
	vic5.call("register_initial_units", map5)
	var ctrl5 := ControllerScript.new(map5, 42, [1, 2], 10)
	ctrl5.set("director", dir5)
	ctrl5.set("victory_evaluator", vic5)
	ctrl5.start_battle()
	for _r: int in range(10):
		ctrl5.submit_command(CmdsScript.EndTurnCommand.new(1))
		ctrl5.submit_command(CmdsScript.EndTurnCommand.new(2))
	assert_eq(ctrl5.outcome, ControllerScript.BattleOutcome.DEFEAT, "Round 10 end with <75% casualties causes MaxRoundsUnfulfilled defeat")
