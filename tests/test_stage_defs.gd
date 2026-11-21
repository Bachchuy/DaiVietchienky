extends GdTestCase

const TMP_DIR: String = "user://tmp_test_stage_defs"
const BATTLE_FILE_TEMPLATE: String = "res://data/battles/battle_%d.json"


func after_each() -> void:
	_cleanup_tmp_dir()
	super.after_each()


func _cleanup_tmp_dir() -> void:
	if not DirAccess.dir_exists_absolute(TMP_DIR):
		return
	var da: DirAccess = DirAccess.open(TMP_DIR)
	if da != null:
		da.list_dir_begin()
		var f: String = da.get_next()
		while not f.is_empty():
			if f != "." and f != ".." and not da.current_is_dir():
				da.remove(f)
			f = da.get_next()
		da.list_dir_end()
	DirAccess.remove_absolute(TMP_DIR)


func test_all_six_registry_stages_match_battle_json_parity() -> void:
	var reg: DataRegistry = StaticDataLoader.load_registry()
	assert_not_null(reg, "DataRegistry loads from res://data/registry.tres")
	if reg == null:
		return
	assert_eq(reg.stages.size(), 6, "Registry has 6 StageDef resources")

	for st: StageDef in reg.stages:
		var battle: Dictionary = StaticDataLoader.load_json_dict(BATTLE_FILE_TEMPLATE % st.stage_id)
		assert_false(battle.is_empty(), "Battle JSON exists for parity check: %d" % st.stage_id)
		assert_eq(st.max_rounds, int(battle.get("max_rounds", 10)), "max_rounds parity")
		assert_eq(st.enable_economy, bool(battle.get("enable_economy", false)), "enable_economy parity")
		assert_eq(st.map_width, int(battle.get("map_width", 12)), "map_width parity")
		assert_eq(st.map_height, int(battle.get("map_height", 10)), "map_height parity")
		assert_eq(st.factions.size(), (battle.get("factions", []) as Array).size(), "factions count parity")
		assert_eq(st.terrain_overrides.size(), (battle.get("terrain_overrides", []) as Array).size(), "terrain_overrides count")
		assert_eq(st.areas.size(), (battle.get("areas", []) as Array).size(), "areas count parity")
		assert_eq(st.placements.size(), (battle.get("placements", []) as Array).size(), "placements count parity")
		assert_eq(st.victory_conditions.size(), (battle.get("victory_conditions", []) as Array).size(), "victory_conditions count")
		assert_eq(st.defeat_conditions.size(), (battle.get("defeat_conditions", []) as Array).size(), "defeat_conditions count")
		assert_eq(st.star_conditions.size(), (battle.get("star_conditions", []) as Array).size(), "star_conditions count")
		assert_eq(st.scripted_events.size(), (battle.get("events", []) as Array).size(), "events count parity")

		if st.stage_id == 10105:
			assert_true(st.enable_economy, "Stage 10105 enables economy")
			assert_eq(st.facilities.size(), 4, "Stage 10105 has 4 facilities")
			var bd_10105: Dictionary = st.to_battle_dict()
			assert_true(bd_10105.has("economy"), "Stage 10105 to_battle_dict includes economy")
			assert_eq(((bd_10105["economy"] as Dictionary).get("facilities", []) as Array).size(), 4, "Stage 10105 economy facilities")


func test_scenario_loader_resource_matches_battle_json_and_injected_registry() -> void:
	var ctrl_res: BattleGameController = ScenarioLoader.load_stage(10101, 12880409)
	var ctrl_json: BattleGameController = ScenarioLoader.load_battle_file("res://data/battles/battle_10101.json", 12880409)
	assert_not_null(ctrl_res, "load_stage(10101) succeeds via registry.tres")
	assert_not_null(ctrl_json, "load_battle_file(10101) succeeds")
	if ctrl_res == null or ctrl_json == null:
		return

	var units_res: Array[BattleUnit] = ctrl_res.context.map_state.get_all_units()
	var units_json: Array[BattleUnit] = ctrl_json.context.map_state.get_all_units()
	assert_eq(units_res.size(), units_json.size(), "Identical initial unit count")
	for u_r: BattleUnit in units_res:
		var u_j: BattleUnit = ctrl_json.context.get_unit(u_r.unit_id)
		assert_not_null(u_j, "Unit %d exists in both" % u_r.unit_id)
		if u_j != null:
			assert_eq(u_r.hex_position, u_j.hex_position, "Unit %d position match" % u_r.unit_id)
			assert_eq(u_r.base_hp, u_j.base_hp, "Unit %d base_hp match" % u_r.unit_id)
			assert_eq(u_r.base_atk, u_j.base_atk, "Unit %d base_atk match" % u_r.unit_id)
			assert_eq(u_r.state.max_hp, u_j.state.max_hp, "Unit %d max_hp match" % u_r.unit_id)
	assert_eq(ctrl_res.director.get_area_hexes("area_bai_coc"), ctrl_json.director.get_area_hexes("area_bai_coc"), "area_bai_coc hexes match")
	assert_eq(ScenarioLoader.load_stage_dialogues(10101).size(), 3, "Stage 10101 dialogues count == 3")

	# Inject in-memory mock DataRegistry + StageDef (zero disk I/O)
	var mock_reg := DataRegistry.new()
	var mock_troop := TroopDef.new()
	mock_troop.troop_id = 49999
	mock_troop.code = "mock_spear"
	mock_troop.display_name = "Mock Spear"
	mock_troop.base_hp = 222
	mock_troop.base_atk = 55
	mock_reg.troops = [mock_troop]

	var mock_stage := StageDef.new()
	mock_stage.stage_id = 99101
	mock_stage.code = "mock_stage"
	mock_stage.source_ref = "Test"
	var p := UnitPlacementDef.new()
	p.unit_id = 501
	p.faction_id = 1
	p.troop_id = 49999
	p.hex_pos = Vector2i(2, 2)
	mock_stage.placements = [p]
	mock_reg.stages = [mock_stage]

	var ctrl_mock: BattleGameController = ScenarioLoader.load_stage_def(mock_stage, 777, mock_reg)
	assert_not_null(ctrl_mock, "load_stage_def works with injected mock DataRegistry")
	var mock_u: BattleUnit = ctrl_mock.context.get_unit(501)
	assert_not_null(mock_u, "Mock unit 501 spawned")
	if mock_u != null:
		assert_eq(mock_u.base_hp, 222, "Mock troop base_hp applied from injected DataRegistry")


func test_data_registry_stage_lookups_and_validation() -> void:
	var reg: DataRegistry = StaticDataLoader.load_registry()
	assert_not_null(reg, "Registry loaded")
	if reg == null:
		return
	assert_eq(reg.validate().size(), 0, "Registry stages validate cleanly")

	var s10101: StageDef = reg.get_stage(10101)
	assert_not_null(s10101, "get_stage(10101)")
	assert_eq(s10101.code, "bach_dang_1288", "get_stage(10101) code")
	var s_vandon: StageDef = reg.get_stage_by_code("van_don_1288")
	assert_not_null(s_vandon, "get_stage_by_code('van_don_1288')")
	assert_eq(s_vandon.stage_id, 10105, "van_don_1288 stage_id")
	assert_null(reg.get_stage(99999), "get_stage missing -> null")

	var bad_reg := DataRegistry.new()
	var dup_a := StageDef.new()
	dup_a.stage_id = 10101
	dup_a.code = "dup_stage"
	dup_a.source_ref = "Src"
	var p1 := UnitPlacementDef.new()
	p1.unit_id = 101
	var p2 := UnitPlacementDef.new()
	p2.unit_id = 101
	dup_a.placements = [p1, p2]
	var bad_evt := ScenarioEventDef.new()
	bad_evt.event_id = "e_missing_dlg"
	var bad_act := ScenarioEventActionDef.new()
	bad_act.action_type = "PlayDialogue"
	bad_act.dialogue_id = "nonexistent_dlg"
	bad_evt.results = [bad_act]
	dup_a.scripted_events = [bad_evt]

	var dup_b := StageDef.new()
	dup_b.stage_id = 10101
	dup_b.code = "dup_stage"
	dup_b.source_ref = "Src"
	bad_reg.stages = [dup_a, dup_b]
	assert_true(bad_reg.validate().size() >= 4, "validate() catches duplicate stage_id/code, unit_id, missing dialogue_id")


func test_stage_def_tres_save_and_reload_roundtrip() -> void:
	_cleanup_tmp_dir()
	assert_eq(DirAccess.make_dir_recursive_absolute(TMP_DIR), OK, "Create user://tmp_test_stage_defs")

	var reg: DataRegistry = StaticDataLoader.load_registry()
	var s10101: StageDef = reg.get_stage(10101)
	var s10105: StageDef = reg.get_stage(10105)
	var p10101: String = TMP_DIR.path_join("stage_10101.tres")
	var p10105: String = TMP_DIR.path_join("stage_10105.tres")

	assert_eq(ResourceSaver.save(s10101, p10101), OK, "Save stage_10101.tres")
	assert_eq(ResourceSaver.save(s10105, p10105), OK, "Save stage_10105.tres")

	var r1 := ResourceLoader.load(p10101, "", ResourceLoader.CACHE_MODE_IGNORE) as StageDef
	var r5 := ResourceLoader.load(p10105, "", ResourceLoader.CACHE_MODE_IGNORE) as StageDef
	assert_not_null(r1, "Reload stage_10101.tres")
	assert_not_null(r5, "Reload stage_10105.tres")
	if r1 == null or r5 == null:
		return

	assert_eq(r1.placements.size(), 12, "Reloaded 10101 placements")
	assert_eq(r1.areas[1].hexes.size(), 6, "Reloaded 10101 area_bai_coc 6 hexes")
	assert_eq(r1.scripted_events[1].conditions[0].numeric_value, 4.0, "Reloaded TideFall round == 4")
	assert_eq(r1.scripted_events[1].results[2].new_terrain, 8, "Reloaded AlterTerrain StakedWater (8)")
	assert_eq(r1.scripted_events[1].results[4].reinforcements.size(), 2, "Reloaded SpawnReinforcements 2 units")
	assert_eq(r1.dialogues.size(), 3, "Reloaded 10101 3 dialogue lines")

	assert_true(r5.enable_economy, "Reloaded 10105 enable_economy")
	assert_eq(r5.facilities.size(), 4, "Reloaded 10105 4 facilities")
	assert_eq(r5.factions[0].start_coin, 360, "Reloaded 10105 faction 1 start_coin")
	assert_eq(r5.facilities[2].facility_type, "Granary", "Reloaded 10105 Granary")
