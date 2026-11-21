extends GdTestCase

const TMP_DIR: String = "user://tmp_test_data_defs"


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


func _build_registry_from_json() -> DataRegistry:
	var reg := DataRegistry.new()
	for d: Variant in StaticDataLoader.load_json_array("res://data/settings/troop_settings.json"):
		if d is Dictionary:
			reg.troops.append(TroopDef.from_dict(d as Dictionary))
	for d: Variant in StaticDataLoader.load_json_array("res://data/settings/general_settings.json"):
		if d is Dictionary:
			reg.generals.append(GeneralDef.from_dict(d as Dictionary))
	for d: Variant in StaticDataLoader.load_json_array("res://data/settings/tactic_settings.json"):
		if d is Dictionary:
			reg.tactics.append(TacticDef.from_dict(d as Dictionary))
	for d: Variant in StaticDataLoader.load_json_array("res://data/settings/facility_settings.json"):
		if d is Dictionary:
			reg.facilities.append(FacilityDef.from_dict(d as Dictionary))
	for d: Variant in StaticDataLoader.load_json_array("res://data/settings/codex_entries.json"):
		if d is Dictionary:
			reg.codex_entries.append(CodexEntryDef.from_dict(d as Dictionary))
	return reg


func test_troop_def_json_parity_and_battle_unit_equivalence() -> void:
	var raw_troops: Array = StaticDataLoader.load_json_array("res://data/settings/troop_settings.json")
	assert_eq(raw_troops.size(), 12, "troop_settings.json has 12 entries")

	for item: Variant in raw_troops:
		var d: Dictionary = item as Dictionary
		var def := TroopDef.from_dict(d)
		assert_eq(def.troop_id, int(d.get("id", 0)), "troop_id parity")
		assert_eq(def.code, str(d.get("code", "")), "code parity")
		assert_eq(def.display_name, str(d.get("name", "")), "display_name parity")
		assert_eq(def.base_hp, int(d.get("strength", 0)), "base_hp parity")
		assert_eq(def.max_stack, int(d.get("max_stack", 0)), "max_stack parity")
		assert_eq(def.min_attack, int(d.get("min_attack", 0)), "min_attack parity")
		assert_eq(def.base_atk, int(d.get("max_attack", 0)), "base_atk parity")
		assert_eq(def.base_def, int(d.get("defence", 0)), "base_def parity")
		assert_eq(def.mobility, int(d.get("mobility", 0)), "mobility parity")
		assert_eq(def.vision_range, int(d.get("vision_range", 0)), "vision_range parity")
		assert_eq(def.min_range, int(d.get("min_range", 0)), "min_range parity")
		assert_eq(def.max_range, int(d.get("max_range", 0)), "max_range parity")
		assert_eq(def.critical_percent, int(d.get("critical_percent", 0)), "critical_percent parity")
		assert_eq(def.counter_percent, int(d.get("counter_percent", 0)), "counter_percent parity")
		assert_eq(def.ignore_zoc, bool(d.get("ignore_zoc", false)), "ignore_zoc parity")
		assert_eq(def.ignore_coc, bool(d.get("ignore_coc", false)), "ignore_coc parity")
		assert_eq(def.devoid_zoc, bool(d.get("devoid_zoc", false)), "devoid_zoc parity")
		assert_eq(def.cost_coin, int(d.get("cost_coin", 0)), "cost_coin parity")
		assert_eq(def.cost_food, int(d.get("cost_food", 0)), "cost_food parity")
		assert_eq(def.meal_food, int(d.get("meal_food", 0)), "meal_food parity")
		var raw_feats: Array = d.get("features", []) as Array
		assert_eq(def.features.size(), raw_feats.size(), "features size parity")

		var unit_raw: BattleUnit = BattleUnit.from_troop_dict(1, 1, Vector2i.ZERO, d)
		var unit_def: BattleUnit = BattleUnit.from_troop_dict(1, 1, Vector2i.ZERO, def.to_troop_dict())
		assert_eq(unit_def.troop_id, unit_raw.troop_id, "BattleUnit troop_id match")
		assert_eq(unit_def.code, unit_raw.code, "BattleUnit code match")
		assert_eq(unit_def.display_name, unit_raw.display_name, "BattleUnit display_name match")
		assert_eq(unit_def.domain, unit_raw.domain, "BattleUnit domain match")
		assert_eq(unit_def.command_branch, unit_raw.command_branch, "BattleUnit command_branch match")
		assert_eq(unit_def.attack_mode, unit_raw.attack_mode, "BattleUnit attack_mode match")
		assert_eq(unit_def.defense_mode, unit_raw.defense_mode, "BattleUnit defense_mode match")
		assert_eq(unit_def.base_hp, unit_raw.base_hp, "BattleUnit base_hp match")
		assert_eq(unit_def.base_atk, unit_raw.base_atk, "BattleUnit base_atk match")
		assert_eq(unit_def.base_def, unit_raw.base_def, "BattleUnit base_def match")
		assert_eq(unit_def.max_mp, unit_raw.max_mp, "BattleUnit max_mp match")
		assert_eq(unit_def.vision_range, unit_raw.vision_range, "BattleUnit vision_range match")
		assert_eq(unit_def.min_range, unit_raw.min_range, "BattleUnit min_range match")
		assert_eq(unit_def.max_range, unit_raw.max_range, "BattleUnit max_range match")
		assert_eq(unit_def.base_crit, unit_raw.base_crit, "BattleUnit base_crit match")
		assert_eq(unit_def.counter_percent, unit_raw.counter_percent, "BattleUnit counter_percent match")
		assert_eq(unit_def.fond_terrain, unit_raw.fond_terrain, "BattleUnit fond_terrain match")
		assert_eq(unit_def.ignore_zoc, unit_raw.ignore_zoc, "BattleUnit ignore_zoc match")
		assert_eq(unit_def.ignore_coc, unit_raw.ignore_coc, "BattleUnit ignore_coc match")
		assert_eq(unit_def.devoid_zoc, unit_raw.devoid_zoc, "BattleUnit devoid_zoc match")
		assert_eq(unit_def.ambush_forest, unit_raw.ambush_forest, "BattleUnit ambush_forest match")


func test_general_tactic_facility_codex_json_parity() -> void:
	var raw_generals: Array = StaticDataLoader.load_json_array("res://data/settings/general_settings.json")
	assert_eq(raw_generals.size(), 9, "general_settings.json has 9 entries")
	for g_var: Variant in raw_generals:
		var gd: Dictionary = g_var as Dictionary
		var g := GeneralDef.from_dict(gd)
		assert_eq(g.general_id, int(gd.get("id", 0)), "general_id parity")
		assert_eq(g.code, str(gd.get("code", "")), "general code parity")
		assert_eq(g.display_name, str(gd.get("name", "")), "general name parity")
		assert_eq(g.faction_id, int(gd.get("faction_id", 0)), "general faction parity")
		assert_eq(g.is_commander_in_chief, bool(gd.get("is_commander_in_chief", false)), "cic parity")
		assert_eq(g.command_stat, int(gd.get("command_stat", 0)), "command_stat parity")
		assert_eq(g.luck, int(gd.get("luck", 0)), "luck parity")
		assert_almost_eq(g.m_command, float(gd.get("m_command", 1.0)), 0.001, "m_command parity")
		var prof: Dictionary = gd.get("command_profile", {}) as Dictionary
		assert_almost_eq(g.get_branch_multiplier("Infantry"), float(prof.get("Infantry", 1.0)), 0.001, "Infantry mult")
		assert_almost_eq(g.get_branch_multiplier("Archer"), float(prof.get("Archer", 1.0)), 0.001, "Archer mult")
		assert_almost_eq(g.get_branch_multiplier("Cavalry"), float(prof.get("Cavalry", 1.0)), 0.001, "Cavalry mult")
		assert_almost_eq(g.get_branch_multiplier("Naval"), float(prof.get("Naval", 1.0)), 0.001, "Naval mult")
		var aura: Dictionary = gd.get("command_aura", {}) as Dictionary
		assert_eq(g.aura_radius_hex, int(aura.get("radius_hex", 0)), "aura radius")
		assert_eq(g.aura_damage_deepen, int(aura.get("damage_deepen", 0)), "aura deepen")
		assert_eq(g.aura_damage_resist, int(aura.get("damage_resist", 0)), "aura resist")
		assert_eq(g.grants_dead_mate_immunity, bool(aura.get("dead_mate_immunity", false)), "dead_mate_immunity")
		var sk: Dictionary = gd.get("unique_skill", {}) as Dictionary
		assert_eq(g.unique_skill_id, int(sk.get("skill_id", 0)), "skill_id")
		assert_eq(g.unique_skill_name, str(sk.get("name", "")), "skill_name")
		assert_eq(g.modeling_type, str(gd.get("modeling_type", "")), "general modeling_type")
		assert_eq(g.source_ref, str(gd.get("source_ref", "")), "general source_ref")
		assert_eq(int(g.to_dict().get("id", 0)), g.general_id, "general to_dict id")

	var raw_tactics: Array = StaticDataLoader.load_json_array("res://data/settings/tactic_settings.json")
	assert_eq(raw_tactics.size(), 1, "tactic_settings.json has 1 entry")
	var td: Dictionary = raw_tactics[0] as Dictionary
	var tc := TacticDef.from_dict(td)
	assert_eq(tc.tactic_id, int(td.get("id", 0)), "tactic_id parity")
	assert_eq(tc.code, str(td.get("code", "")), "tactic code parity")
	assert_eq(tc.owner_general_id, int(td.get("owner_general_id", 0)), "owner_general_id parity")
	assert_eq(tc.range_hex, int(td.get("range_hex", 0)), "range_hex parity")
	assert_eq(tc.aoe_radius, int(td.get("aoe_radius", 0)), "aoe_radius parity")
	assert_eq(tc.cooldown_turns, int(td.get("cooldown_turns", 0)), "cooldown_turns parity")
	assert_eq(tc.morale_shift, int(td.get("morale_shift", 0)), "morale_shift parity")
	assert_eq(tc.clears_chaos, bool(td.get("clears_chaos", false)), "clears_chaos parity")
	assert_eq(int(tc.to_dict().get("id", 0)), tc.tactic_id, "tactic to_dict id")

	var raw_facilities: Array = StaticDataLoader.load_json_array("res://data/settings/facility_settings.json")
	assert_eq(raw_facilities.size(), 7, "facility_settings.json has 7 entries")
	for f_var: Variant in raw_facilities:
		var fd: Dictionary = f_var as Dictionary
		var f := FacilityDef.from_dict(fd)
		assert_eq(f.facility_id, str(fd.get("id", "")), "facility_id parity")
		assert_eq(f.type_code, int(fd.get("type", 0)), "facility type_code parity")
		assert_eq(f.display_name, str(fd.get("name", "")), "facility display_name parity")
		assert_eq(str(f.to_dict().get("id", "")), f.facility_id, "facility to_dict id")
		if f.facility_id == "Farm":
			assert_eq(FacilityDef.get_level_value(f.food_yield_per_level, 2), 120, "Farm lv2 yield 120")
			assert_eq(FacilityDef.get_level_value(f.upgrade_coin_cost, 1), 120, "Farm lv1 upgrade 120")
		if f.facility_id == "Granary":
			assert_almost_eq(f.rob_protection_multiplier, 0.5, 0.001, "Granary rob protection 0.5")

	var raw_codex: Array = StaticDataLoader.load_json_array("res://data/settings/codex_entries.json")
	assert_eq(raw_codex.size(), 7, "codex_entries.json has 7 entries")
	for c_var: Variant in raw_codex:
		var cd: Dictionary = c_var as Dictionary
		var c := CodexEntryDef.from_dict(cd)
		assert_eq(c.entry_id, str(cd.get("id", "")), "codex entry_id parity")
		assert_eq(c.category, str(cd.get("category", "")), "codex category parity")
		assert_eq(c.evidence_grade, str(cd.get("evidence_grade", "")), "codex evidence_grade parity")
		assert_eq(c.modeling_type, str(cd.get("modeling_type", "")), "codex modeling_type parity")
		assert_eq(str(c.to_dict().get("id", "")), c.entry_id, "codex to_dict id")
		if c.category == "mechanics":
			assert_eq(c.evidence_grade, "", "mechanics codex keeps empty evidence_grade")


func test_data_registry_lookups_and_validation() -> void:
	var reg: DataRegistry = _build_registry_from_json()
	assert_eq(reg.validate().size(), 0, "Registry built from JSON validates cleanly")

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
	var errs: Array[String] = bad.validate()
	assert_true(errs.size() >= 3, "validate() catches duplicate troop ID, invalid range, and Grade D claim")


func test_tres_save_and_reload_roundtrip() -> void:
	_cleanup_tmp_dir()
	var make_err: Error = DirAccess.make_dir_recursive_absolute(TMP_DIR)
	assert_eq(make_err, OK, "Create user://tmp_test_data_defs")

	var reg: DataRegistry = _build_registry_from_json()
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
