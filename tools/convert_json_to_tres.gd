extends SceneTree
## One-time converter: migrates res://data/settings/*.json + battle_*.json to .tres + registry.tres.

const REGISTRY_PATH: String = "res://data/registry.tres"
const STAGE_SLUGS: Dictionary = {
	10101: "10101_bach_dang",
	10102: "10102_binh_than",
	10103: "10103_ham_tu",
	10104: "10104_chuong_duong",
	10105: "10105_van_don",
	10106: "10106_noi_bang",
}


func _initialize() -> void:
	if not FileAccess.file_exists("res://data/settings/troop_settings.json"):
		print("convert_json_to_tres: source JSON files already removed; nothing to convert.")
		quit(0)
		return

	var exit_code: int = _run_conversion()
	quit(exit_code)


func _run_conversion() -> int:
	_ensure_dirs()
	var reg := DataRegistry.new()

	var raw_troops: Array = _read_json_array("res://data/settings/troop_settings.json")
	for item: Variant in raw_troops:
		var d: Dictionary = item as Dictionary
		var def := TroopDef.from_dict(d)
		var path: String = "res://data/defs/troops/%d_%s.tres" % [def.troop_id, def.code.to_lower()]
		reg.troops.append(_save_and_reload(def, path) as TroopDef)

	var raw_generals: Array = _read_json_array("res://data/settings/general_settings.json")
	for item: Variant in raw_generals:
		var d: Dictionary = item as Dictionary
		var def := GeneralDef.from_dict(d)
		var path: String = "res://data/defs/generals/%d_%s.tres" % [def.general_id, def.code.to_lower()]
		reg.generals.append(_save_and_reload(def, path) as GeneralDef)

	var raw_tactics: Array = _read_json_array("res://data/settings/tactic_settings.json")
	for item: Variant in raw_tactics:
		var d: Dictionary = item as Dictionary
		var def := TacticDef.from_dict(d)
		var path: String = "res://data/defs/tactics/%d_%s.tres" % [def.tactic_id, def.code.to_lower()]
		reg.tactics.append(_save_and_reload(def, path) as TacticDef)

	var raw_facilities: Array = _read_json_array("res://data/settings/facility_settings.json")
	for item: Variant in raw_facilities:
		var d: Dictionary = item as Dictionary
		var def := FacilityDef.from_dict(d)
		var path: String = "res://data/defs/facilities/%s.tres" % def.facility_id.to_lower()
		reg.facilities.append(_save_and_reload(def, path) as FacilityDef)

	var raw_codex: Array = _read_json_array("res://data/settings/codex_entries.json")
	for item: Variant in raw_codex:
		var d: Dictionary = item as Dictionary
		var def := CodexEntryDef.from_dict(d)
		var path: String = "res://data/defs/codex/%s.tres" % def.entry_id.to_lower()
		reg.codex_entries.append(_save_and_reload(def, path) as CodexEntryDef)

	var raw_stages: Array = _read_json_array("res://data/settings/stage_settings.json")
	for item: Variant in raw_stages:
		var meta: Dictionary = item as Dictionary
		var sid: int = int(meta.get("id", 0))
		var battle_data: Dictionary = _read_json_dict(str(meta.get("battle_file", "")))
		var st := StageDef.from_stage_and_battle_dicts(meta, battle_data)
		var slug: String = str(STAGE_SLUGS.get(sid, "%d_%s" % [sid, st.code.to_lower()]))
		var path: String = "res://data/stages/%s/stage_%d.tres" % [slug, sid]
		reg.stages.append(_save_and_reload(st, path) as StageDef)

	var errs: Array[String] = reg.validate()
	if not errs.is_empty():
		printerr("DataRegistry validation failed: %s" % str(errs))
		return 1

	var reg_err: Error = ResourceSaver.save(reg, REGISTRY_PATH)
	if reg_err != OK:
		printerr("Failed to save registry.tres: %d" % reg_err)
		return 1

	var reloaded := ResourceLoader.load(REGISTRY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as DataRegistry
	if reloaded == null or not _verify_parity(reloaded, raw_troops, raw_generals, raw_tactics, raw_facilities, raw_codex, raw_stages):
		return 1

	print("PARITY OK (%d troops, %d generals, %d tactics, %d facilities, %d codex, %d stages)" % [
		reloaded.troops.size(),
		reloaded.generals.size(),
		reloaded.tactics.size(),
		reloaded.facilities.size(),
		reloaded.codex_entries.size(),
		reloaded.stages.size(),
	])
	return 0


func _ensure_dirs() -> void:
	var dirs: Array[String] = [
		"res://data/defs/troops",
		"res://data/defs/generals",
		"res://data/defs/tactics",
		"res://data/defs/facilities",
		"res://data/defs/codex",
	]
	for slug: Variant in STAGE_SLUGS.values():
		dirs.append("res://data/stages/%s" % str(slug))
	for d: String in dirs:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))


func _save_and_reload(res: Resource, path: String) -> Resource:
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		printerr("Failed saving %s (err=%d)" % [path, err])
		return res
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


func _read_json_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Array if parsed is Array else []


func _read_json_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _verify_parity(
	reg: DataRegistry,
	raw_troops: Array,
	raw_generals: Array,
	raw_tactics: Array,
	raw_facilities: Array,
	raw_codex: Array,
	raw_stages: Array
) -> bool:
	if reg.troops.size() != raw_troops.size() or reg.generals.size() != raw_generals.size():
		return _fail("Troop or general count mismatch")
	if reg.tactics.size() != raw_tactics.size() or reg.facilities.size() != raw_facilities.size():
		return _fail("Tactic or facility count mismatch")
	if reg.codex_entries.size() != raw_codex.size() or reg.stages.size() != raw_stages.size():
		return _fail("Codex or stage count mismatch")

	for item: Variant in raw_troops:
		var d: Dictionary = item as Dictionary
		var t: TroopDef = reg.get_troop(int(d.get("id", 0)))
		if t == null or t.base_hp != int(d.get("strength", 0)) or t.base_atk != int(d.get("max_attack", 0)) or t.base_def != int(d.get("defence", 0)) or t.meal_food != int(d.get("meal_food", 0)):
			return _fail("Troop parity mismatch for %s" % str(d.get("id")))

	for item: Variant in raw_generals:
		var d: Dictionary = item as Dictionary
		var g: GeneralDef = reg.get_general(int(d.get("id", 0)))
		if g == null or g.command_stat != int(d.get("command_stat", 0)) or not is_equal_approx(g.m_command, float(d.get("m_command", 1.0))):
			return _fail("General parity mismatch for %s" % str(d.get("id")))

	for item: Variant in raw_tactics:
		var d: Dictionary = item as Dictionary
		var tc: TacticDef = reg.get_tactic(int(d.get("id", 0)))
		if tc == null or tc.cooldown_turns != int(d.get("cooldown_turns", 0)) or tc.clears_chaos != bool(d.get("clears_chaos", false)):
			return _fail("Tactic parity mismatch for %s" % str(d.get("id")))

	for item: Variant in raw_facilities:
		var d: Dictionary = item as Dictionary
		var f: FacilityDef = reg.get_facility(str(d.get("id", "")))
		var expected_coins: Array[int] = _to_int_array(d.get("upgrade_coin_cost", []))
		if f == null or f.type_code != int(d.get("type", 0)) or f.upgrade_coin_cost != expected_coins:
			return _fail("Facility parity mismatch for %s" % str(d.get("id")))

	for item: Variant in raw_codex:
		var d: Dictionary = item as Dictionary
		var c: CodexEntryDef = reg.get_codex_entry(str(d.get("id", "")))
		if c == null or c.evidence_grade != str(d.get("evidence_grade", "")) or c.modeling_type != str(d.get("modeling_type", "")):
			return _fail("Codex parity mismatch for %s" % str(d.get("id")))

	for item: Variant in raw_stages:
		var meta: Dictionary = item as Dictionary
		var sid: int = int(meta.get("id", 0))
		var b: Dictionary = _read_json_dict(str(meta.get("battle_file", "")))
		var st: StageDef = reg.get_stage(sid)
		if st == null or st.placements.size() != (b.get("placements", []) as Array).size() or st.scripted_events.size() != (b.get("events", []) as Array).size() or st.map_width != int(b.get("map_width", 0)) or st.enable_economy != bool(b.get("enable_economy", false)):
			return _fail("Stage parity mismatch for %d" % sid)
	return true


func _to_int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for x: Variant in raw as Array:
			out.append(int(x))
	return out


func _fail(msg: String) -> bool:
	printerr("PARITY ERROR: %s" % msg)
	return false
