extends GdTestCase

const TMP_DIR: String = "user://tmp_test_data_defs"
const REMOVED_JSON_PATHS: Array[String] = [
	"res://data/settings/troop_settings.json",
	"res://data/settings/general_settings.json",
	"res://data/settings/tactic_settings.json",
	"res://data/settings/facility_settings.json",
	"res://data/settings/codex_entries.json",
	"res://data/settings/stage_settings.json",
]


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


func test_registry_tres_counts_validation_and_json_settings_removed() -> void:
	for removed_path: String in REMOVED_JSON_PATHS:
		assert_false(FileAccess.file_exists(removed_path), "Removed legacy JSON: %s" % removed_path)

	var reg: DataRegistry = StaticDataLoader.load_registry()
	assert_not_null(reg, "res://data/registry.tres loads as DataRegistry")
	if reg == null:
		return

	assert_eq(reg.troops.size(), 12, "Registry has 12 TroopDef resources")
	assert_eq(reg.generals.size(), 9, "Registry has 9 GeneralDef resources")
	assert_eq(reg.tactics.size(), 1, "Registry has 1 TacticDef resource")
	assert_eq(reg.facilities.size(), 7, "Registry has 7 FacilityDef resources")
	assert_eq(reg.codex_entries.size(), 7, "Registry has 7 CodexEntryDef resources")
	assert_eq(reg.stages.size(), 6, "Registry has 6 StageDef resources")
	assert_eq(reg.validate().size(), 0, "res://data/registry.tres passes validate() cleanly")

	assert_not_null(reg.get_troop(40101), "get_troop(40101)")
	assert_not_null(reg.get_troop_by_code("dai_viet_fire_boat"), "get_troop_by_code")
	assert_null(reg.get_troop(99999), "get_troop missing -> null")
	assert_not_null(reg.get_general(1001), "get_general(1001)")
	assert_not_null(reg.get_general_by_code("o_ma_nhi"), "get_general_by_code")
	assert_not_null(reg.get_tactic(10001), "get_tactic(10001)")
	assert_not_null(reg.get_tactic_by_code("hich_tuong_si"), "get_tactic_by_code")
	assert_not_null(reg.get_facility("Farm"), "get_facility exact")
	assert_not_null(reg.get_facility("farm"), "get_facility case-insensitive")
	assert_not_null(reg.get_codex_entry("bach_dang_1288"), "get_codex_entry")
	assert_gt(float(reg.filter_codex("1288").size()), 0.0, "filter_codex('1288')")
	assert_eq(reg.filter_codex("zzz_no_match").size(), 0, "filter_codex unmatched -> empty")


func test_troop_def_roundtrip_and_battle_unit_equivalence() -> void:
	var reg: DataRegistry = StaticDataLoader.load_registry()
	assert_not_null(reg, "Registry loaded")
	if reg == null:
		return

	var troop_map: Dictionary[int, Dictionary] = StaticDataLoader.load_troop_settings(reg)
	assert_eq(troop_map.size(), 12, "load_troop_settings(reg) yields 12 entries")

	for t: TroopDef in reg.troops:
		var d: Dictionary = t.to_troop_dict()
		var rt: TroopDef = TroopDef.from_dict(d)
		assert_eq(rt.troop_id, t.troop_id, "TroopDef troop_id roundtrip")
		assert_eq(rt.code, t.code, "TroopDef code roundtrip")
		assert_eq(rt.domain, t.domain, "TroopDef domain roundtrip")
		assert_eq(rt.command_branch, t.command_branch, "TroopDef command_branch roundtrip")
		assert_eq(rt.attack_mode, t.attack_mode, "TroopDef attack_mode roundtrip")
		assert_eq(rt.defense_mode, t.defense_mode, "TroopDef defense_mode roundtrip")
		assert_eq(rt.base_hp, t.base_hp, "TroopDef base_hp roundtrip")
		assert_eq(rt.base_atk, t.base_atk, "TroopDef base_atk roundtrip")
		assert_eq(rt.base_def, t.base_def, "TroopDef base_def roundtrip")
		assert_eq(rt.fond_terrain, t.fond_terrain, "TroopDef fond_terrain roundtrip")
		assert_eq(rt.meal_food, t.meal_food, "TroopDef meal_food roundtrip")

		var u: BattleUnit = BattleUnit.from_troop_dict(1, 1, Vector2i.ZERO, d)
		assert_eq(u.troop_id, t.troop_id, "BattleUnit troop_id match")
		assert_eq(u.base_hp, t.base_hp, "BattleUnit base_hp match")
		assert_eq(u.base_atk, t.base_atk, "BattleUnit base_atk match")
		assert_eq(u.base_def, t.base_def, "BattleUnit base_def match")
		assert_eq(u.max_mp, t.mobility, "BattleUnit max_mp match")
		assert_eq(u.fond_terrain, t.fond_terrain, "BattleUnit fond_terrain match")
		if t.troop_id == 40104:
			assert_eq(u.defense_mode, 4, "War elephant resolves Beast defense_mode (4)")
			assert_true(u.devoid_zoc, "War elephant keeps devoid_zoc")
		if t.troop_id == 40201:
			assert_eq(u.attack_mode, 5, "Naval light warboat resolves Naval attack_mode (5)")


func test_general_tactic_facility_codex_roundtrip_and_validation() -> void:
	var reg: DataRegistry = StaticDataLoader.load_registry()
	assert_not_null(reg, "Registry loaded")
	if reg == null:
		return

	for g: GeneralDef in reg.generals:
		var rt_g: GeneralDef = GeneralDef.from_dict(g.to_dict())
		assert_eq(rt_g.general_id, g.general_id, "GeneralDef roundtrip id")
		assert_almost_eq(rt_g.get_branch_multiplier("Naval"), g.naval_mult, 0.001, "GeneralDef naval_mult")
		assert_eq(rt_g.unique_skill_name, g.unique_skill_name, "GeneralDef skill_name")

	var tc: TacticDef = reg.get_tactic(10001)
	var rt_tc: TacticDef = TacticDef.from_dict(tc.to_dict())
	assert_eq(rt_tc.tactic_id, 10001, "TacticDef roundtrip id")
	assert_eq(rt_tc.clears_chaos, true, "TacticDef clears_chaos")

	var farm: FacilityDef = reg.get_facility("Farm")
	assert_eq(FacilityDef.get_level_value(farm.food_yield_per_level, 2), 120, "Farm lv2 yield 120")
	assert_eq(FacilityDef.get_level_value(farm.upgrade_coin_cost, 1), 120, "Farm lv1 upgrade 120")
	var granary: FacilityDef = reg.get_facility("Granary")
	assert_almost_eq(granary.rob_protection_multiplier, 0.5, 0.001, "Granary rob protection 0.5")

	for c: CodexEntryDef in reg.codex_entries:
		var rt_c: CodexEntryDef = CodexEntryDef.from_dict(c.to_dict())
		assert_eq(rt_c.entry_id, c.entry_id, "CodexEntryDef roundtrip id")
		assert_eq(rt_c.evidence_grade, c.evidence_grade, "CodexEntryDef evidence_grade")
		if c.category == "mechanics":
			assert_eq(c.evidence_grade, "", "Mechanics codex keeps empty evidence_grade")

	var bad := DataRegistry.new()
	var t1 := TroopDef.new()
	t1.troop_id = 40101
	t1.code = "dup"
	t1.min_range = 3
	t1.max_range = 1
	var t2 := TroopDef.new()
	t2.troop_id = 40101
	t2.code = "dup"
	bad.troops = [t1, t2]
	var bad_codex := CodexEntryDef.new()
	bad_codex.entry_id = "bad_d"
	bad_codex.category = "historical"
	bad_codex.evidence_grade = "D"
	bad_codex.modeling_type = "historical_claim"
	bad_codex.source_ref = "Oral"
	bad.codex_entries = [bad_codex]
	assert_true(bad.validate().size() >= 3, "validate() catches duplicate troop ID, invalid range, Grade D claim")


func test_tres_save_and_reload_roundtrip() -> void:
	_cleanup_tmp_dir()
	assert_eq(DirAccess.make_dir_recursive_absolute(TMP_DIR), OK, "Create user://tmp_test_data_defs")

	var reg: DataRegistry = StaticDataLoader.load_registry()
	var paths: Dictionary = {
		"reg": TMP_DIR.path_join("registry.tres"),
		"troop": TMP_DIR.path_join("troop_40101.tres"),
		"general": TMP_DIR.path_join("general_1001.tres"),
		"tactic": TMP_DIR.path_join("tactic_10001.tres"),
		"facility": TMP_DIR.path_join("facility_granary.tres"),
		"codex_mech": TMP_DIR.path_join("codex_mechanics.tres"),
	}
	assert_eq(ResourceSaver.save(reg.get_troop(40101), str(paths["troop"])), OK, "Save TroopDef")
	assert_eq(ResourceSaver.save(reg.get_general(1001), str(paths["general"])), OK, "Save GeneralDef")
	assert_eq(ResourceSaver.save(reg.get_tactic(10001), str(paths["tactic"])), OK, "Save TacticDef")
	assert_eq(ResourceSaver.save(reg.get_facility("Granary"), str(paths["facility"])), OK, "Save FacilityDef")
	assert_eq(ResourceSaver.save(reg.get_codex_entry("wargame_hex_abstraction"), str(paths["codex_mech"])), OK, "Save CodexEntryDef")
	assert_eq(ResourceSaver.save(reg, str(paths["reg"])), OK, "Save DataRegistry")

	var r_troop := ResourceLoader.load(str(paths["troop"]), "", ResourceLoader.CACHE_MODE_IGNORE) as TroopDef
	var r_gen := ResourceLoader.load(str(paths["general"]), "", ResourceLoader.CACHE_MODE_IGNORE) as GeneralDef
	var r_tac := ResourceLoader.load(str(paths["tactic"]), "", ResourceLoader.CACHE_MODE_IGNORE) as TacticDef
	var r_fac := ResourceLoader.load(str(paths["facility"]), "", ResourceLoader.CACHE_MODE_IGNORE) as FacilityDef
	var r_codex := ResourceLoader.load(str(paths["codex_mech"]), "", ResourceLoader.CACHE_MODE_IGNORE) as CodexEntryDef
	var r_reg := ResourceLoader.load(str(paths["reg"]), "", ResourceLoader.CACHE_MODE_IGNORE) as DataRegistry

	assert_not_null(r_troop, "Reloaded TroopDef")
	assert_eq(r_troop.features, Array(["anti_cavalry_brace", "forest_ambush"], TYPE_STRING_NAME, &"", null), "TroopDef StringName array roundtrip")
	assert_eq(r_troop.fond_terrain, 1, "TroopDef fond_terrain enum roundtrip")
	assert_almost_eq(r_gen.m_command, 1.25, 0.001, "GeneralDef float roundtrip")
	assert_eq(r_tac.clears_chaos, true, "TacticDef clears_chaos roundtrip")
	assert_eq(r_fac.food_cap_bonus_per_level, Array([500, 1000, 1500], TYPE_INT, &"", null), "FacilityDef int array roundtrip")
	assert_almost_eq(r_fac.rob_protection_multiplier, 0.5, 0.001, "FacilityDef float roundtrip")
	assert_eq(r_codex.evidence_grade, "", "CodexEntryDef empty evidence_grade roundtrip")
	assert_eq(r_reg.troops.size(), 12, "DataRegistry reloaded 12 troops")
	assert_eq(r_reg.validate().size(), 0, "Reloaded DataRegistry validates cleanly")
