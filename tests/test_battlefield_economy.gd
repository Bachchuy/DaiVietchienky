extends "res://tests/test_case.gd"

const ECONOMY_SCRIPT_PATH: String = "res://scripts/core/battle_economy.gd"
const SAVE_SCRIPT_PATH: String = "res://scripts/core/battle_save_manager.gd"
const MapStateScript = preload("res://scripts/core/battle_map_state.gd")
const UnitScript = preload("res://scripts/core/battle_unit.gd")
const UnitStateScript = preload("res://scripts/core/unit_combat_state.gd")
const ControllerScript = preload("res://scripts/core/battle_game_controller.gd")
const CmdsScript = preload("res://scripts/core/battle_commands.gd")
const ScenarioLoaderScript = preload("res://scripts/core/scenario_loader.gd")
const AIMatrixScript = preload("res://scripts/ai/ai_decision_matrix.gd")
const AIProfileScript = preload("res://scripts/ai/ai_difficulty_profile.gd")


func _load_economy_script() -> GDScript:
	var s: GDScript = load(ECONOMY_SCRIPT_PATH) as GDScript
	assert_not_null(s, "BattleEconomy script must exist at " + ECONOMY_SCRIPT_PATH)
	return s


func test_facility_harvest_total_meal_food_and_granary_cap() -> void:
	var eco_scr: GDScript = _load_economy_script()
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 0, 0, 0, 0)
	eco.call("register_facility", "farm_1", 1, "Farm", 1)
	eco.call("register_facility", "mkt_1", 1, "Market", 1)
	eco.call("register_facility", "mine_1", 1, "Mine", 1)
	eco.call("register_facility", "tpl_1", 1, "Temple", 1)

	var map_state := MapStateScript.new(6, 6, MapStateScript.TerrainType.PLAINS)
	var u_inf: BattleUnit = UnitScript.from_troop_dict(1, 1, Vector2i(0, 0), {"id": 40101, "command_branch": "Infantry", "strength": 160})
	u_inf.max_stack = 2
	var u_cav: BattleUnit = UnitScript.from_troop_dict(2, 1, Vector2i(1, 0), {"id": 40103, "command_branch": "Cavalry", "strength": 150})
	u_cav.max_stack = 3
	map_state.place_unit(u_inf)
	map_state.place_unit(u_cav)

	eco.call("process_begin_round", 1, map_state)
	assert_eq(int(eco.call("get_resource", 1, "coin")), 90, "Market +60 & Mine +30 = 90 coin")
	assert_eq(int(eco.call("get_resource", 1, "tech")), 25, "Mine +25 tech")
	assert_eq(int(eco.call("get_resource", 1, "mana")), 25, "Temple +25 mana")
	assert_eq(int(eco.call("get_resource", 1, "food")), 0, "Farm +80 - (20 + 60) MealFood = 0 food")

	var elephant: BattleUnit = UnitScript.from_troop_dict(10, 1, Vector2i(2, 0), {"id": 40104, "command_branch": "Cavalry", "features": ["elephant"]})
	elephant.max_stack = 3
	assert_eq(int(eco.call("compute_unit_meal_food", elephant)), 90, "3x Elephant consumes 90 food")

	var u0: BattleUnit = UnitScript.from_troop_dict(11, 1, Vector2i(3, 0), {"id": 40101, "command_branch": "Infantry"})
	u0.max_stack = 0
	var u5: BattleUnit = UnitScript.from_troop_dict(12, 1, Vector2i(4, 0), {"id": 40101, "command_branch": "Infantry"})
	u5.max_stack = 5
	assert_eq(int(eco.call("compute_unit_meal_food", u0)), 10, "max_stack 0 clamped to 1 -> 10 food")
	assert_eq(int(eco.call("compute_unit_meal_food", u5)), 30, "max_stack 5 clamped to 3 -> 30 food")

	eco.call("register_facility", "gran_1", 1, "Granary", 1)
	var cap: int = int(eco.call("get_food_cap", 1))
	eco.call("add_resource", 1, "food", cap + 3000)
	assert_lte(int(eco.call("get_resource", 1, "food")), cap, "Food clamped to Granary cap")


func test_starvation_morale_drop_floored_at_low_0_75x_damage_and_zero_healing() -> void:
	var eco_scr: GDScript = _load_economy_script()
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, 0, 0, 0)
	assert_false(bool(eco.call("is_starving", 1)), "food == 0 is NOT starving")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 1.0, 0.001, "1.0x damage at food == 0")

	eco.call("set_resource", 1, "food", -1)
	assert_true(bool(eco.call("is_starving", 1)), "food == -1 triggers Starvation")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 0.75, 0.001, "0.75x damage when starving")
	assert_false(bool(eco.call("can_heal_unit", 1)), "0 HP healing when starving")

	var map_state := MapStateScript.new(6, 6, MapStateScript.TerrainType.PLAINS)
	var u_high: BattleUnit = UnitScript.from_troop_dict(1, 1, Vector2i(0, 0), {"id": 40101})
	u_high.state.morale = UnitStateScript.MoraleLevel.HIGH
	var u_norm: BattleUnit = UnitScript.from_troop_dict(2, 1, Vector2i(1, 0), {"id": 40101})
	u_norm.state.morale = UnitStateScript.MoraleLevel.NORMAL
	var u_low: BattleUnit = UnitScript.from_troop_dict(3, 1, Vector2i(2, 0), {"id": 40101})
	u_low.state.morale = UnitStateScript.MoraleLevel.LOW
	map_state.place_unit(u_high)
	map_state.place_unit(u_norm)
	map_state.place_unit(u_low)

	eco.call("apply_starvation_effects", 1, map_state)
	assert_eq(int(u_high.state.morale), int(UnitStateScript.MoraleLevel.NORMAL), "HIGH -> NORMAL")
	assert_eq(int(u_norm.state.morale), int(UnitStateScript.MoraleLevel.LOW), "NORMAL -> LOW")
	assert_eq(int(u_low.state.morale), int(UnitStateScript.MoraleLevel.LOW), "LOW floors at LOW (never CHAOS)")

	eco.call("set_resource", 1, "food", 10)
	assert_false(bool(eco.call("is_starving", 1)), "Starvation clears when food >= 0")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 1.0, 0.001, "Multiplier restores to 1.0")
	assert_true(bool(eco.call("can_heal_unit", 1)), "Healing unlocked")


func test_rob_area_income_and_trade_normal_vs_crisis_and_market_guard() -> void:
	var eco_scr: GDScript = _load_economy_script()
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 300, 100, 0, 0)
	eco.call("register_facility", "enemy_farm", 2, "Farm", 1, 2, false)
	var gained1: int = int(eco.call("rob_facility", 1, "enemy_farm", 0.80))
	assert_eq(gained1, 128, "round_half_up(80 * 2 * 0.80 * 1.0) == 128")
	assert_eq(int(eco.call("rob_facility", 1, "enemy_farm", 0.80)), 0, "turns_unrobbed reset to 0")

	eco.call("register_facility", "enemy_farm_g", 2, "Farm", 1, 7, true)
	var gained2: int = int(eco.call("rob_facility", 1, "enemy_farm_g", 0.80))
	assert_eq(gained2, 96, "round_half_up(80 * 3 * 0.80 * 0.50) == 96")

	var map_state := MapStateScript.new(6, 6, MapStateScript.TerrainType.PLAINS)
	var ctrl := ControllerScript.new(map_state, 1288, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()

	var trade_cls: Variant = eco_scr.get("TradeCommand")
	assert_not_null(trade_cls, "TradeCommand inner class exists")
	if trade_cls == null:
		return

	# Without Market -> rejected
	assert_false(ctrl.submit_command(trade_cls.new(1, "coin_to_food", 100)), "Trade rejected with 0 Markets")

	eco.call("register_facility", "mkt_1", 1, "Market", 1)
	eco.call("set_resource", 1, "food", 100)
	assert_true(ctrl.submit_command(trade_cls.new(1, "coin_to_food", 100)), "Normal coin_to_food succeeds")
	assert_eq(int(eco.call("get_resource", 1, "food")), 175, "Normal trade adds +75 food")
	assert_false(ctrl.can_undo(), "Economy commands are non-undoable")

	eco.call("set_resource", 1, "food", -10)
	assert_false(ctrl.submit_command(trade_cls.new(1, "food_to_coin", 50)), "Cannot sell food while starving")
	assert_true(ctrl.submit_command(trade_cls.new(1, "coin_to_food", 100)), "Crisis coin_to_food succeeds")
	assert_eq(int(eco.call("get_resource", 1, "food")), 28, "Crisis trade adds +38 food (-10 + 38 = 28)")


func test_upgrade_fortify_unlock_tech_recruit_and_apply_tactic_commands() -> void:
	var eco_scr: GDScript = _load_economy_script()
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 1200, 1000, 500, 150)
	eco.call("register_facility", "aca_1", 1, "Academy", 1)
	eco.call("register_facility", "fort_1", 1, "Fort", 1)

	var map_state := MapStateScript.new(6, 6, MapStateScript.TerrainType.PLAINS)
	map_state.set_terrain(Vector2i(1, 1), MapStateScript.TerrainType.FORT)
	map_state.set_fort_owner(Vector2i(1, 1), 1)
	var u1: BattleUnit = UnitScript.from_troop_dict(101, 1, Vector2i(0, 0), {"id": 40101})
	map_state.place_unit(u1)

	var ctrl := ControllerScript.new(map_state, 1288, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()

	assert_true(ctrl.submit_command(eco_scr.get("UpgradeFacilityCommand").new(1, "fort_1")), "UpgradeFacility 1->2 succeeds")
	assert_true(ctrl.submit_command(eco_scr.get("FortifyHexCommand").new(1, Vector2i(2, 2))), "FortifyHex succeeds")
	assert_eq(int(map_state.get_terrain(Vector2i(2, 2))), int(MapStateScript.TerrainType.FORT), "Hex (2,2) fortified")

	assert_false(ctrl.submit_command(eco_scr.get("UnlockBattleTechCommand").new(1, 3, "INFANTRY")), "Cannot skip Tier 1 & 2 straight to Tier 3")
	assert_true(ctrl.submit_command(eco_scr.get("UnlockBattleTechCommand").new(1, 1, "INFANTRY")), "Unlock Tier 1 INFANTRY succeeds")

	assert_true(ctrl.submit_command(eco_scr.get("RecruitCommand").new(1, 40101, 2, Vector2i(1, 1))), "Recruit 2x unit at Fort (1,1) succeeds")
	assert_not_null(map_state.get_unit_at(Vector2i(1, 1)), "Recruited unit placed at (1,1)")

	var mana_before: int = int(eco.call("get_resource", 1, "mana"))
	assert_true(ctrl.submit_command(eco_scr.get("ApplyTacticCommand").new(1, "forced_march", u1.unit_id)), "ApplyTacticCommand succeeds")
	assert_lt(float(int(eco.call("get_resource", 1, "mana"))), float(mana_before), "ApplyTactic consumes faction mana")
	assert_false(u1.state.has_acted, "ApplyTactic leaves unit available to act/CastSkill")


func test_economy_save_load_persistence_and_ai_turn_under_3_seconds() -> void:
	var eco_scr: GDScript = _load_economy_script()
	var save_scr: GDScript = load(SAVE_SCRIPT_PATH) as GDScript
	if eco_scr == null or save_scr == null:
		return

	var save_mgr: Object = save_scr.new()
	var ctrl1: BattleGameController = ScenarioLoaderScript.load_stage(10101, 12880409)
	ctrl1.enable_economy = true
	var eco1: Object = eco_scr.new()
	eco1.call("init_faction", 1, 500, -20, 140, 80)
	eco1.call("init_faction", 2, 250, 200, 100, 100)
	ctrl1.set("economy", eco1)
	assert_true(bool(save_mgr.call("save_battle_session", ctrl1)), "Save session with economy")

	var ctrl2: BattleGameController = ScenarioLoaderScript.load_stage(10101, 12880409)
	assert_true(bool(save_mgr.call("load_battle_session", ctrl2)), "Load session with economy")
	assert_true(ctrl2.enable_economy, "enable_economy restored")
	var eco2: Object = ctrl2.get("economy") as Object
	assert_not_null(eco2, "economy object restored")
	assert_eq(int(eco2.call("get_resource", 1, "coin")), 500, "Coin 500 restored")
	assert_eq(int(eco2.call("get_resource", 1, "food")), -20, "Negative starving food -20 restored")
	assert_true(bool(eco2.call("is_starving", 1)), "Starvation state restored")

	ctrl2.submit_command(CmdsScript.EndTurnCommand.new(1))
	var ai := AIMatrixScript.new(AIProfileScript.create_preset(&"normal"))
	var rep: Dictionary = ai.execute_faction_turn(ctrl2, 2, ctrl2.director)
	assert_lt(float(rep.get("elapsed_ms", 9999.0)), 3000.0, "Economy AI turn completes < 3.0s")
