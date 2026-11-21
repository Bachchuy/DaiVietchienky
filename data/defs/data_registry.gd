class_name DataRegistry
extends Resource
## Read-only aggregate registry of static game definitions (`res://data/registry.tres`).

@export_group("Definitions")
@export var troops: Array[TroopDef] = []
@export var generals: Array[GeneralDef] = []
@export var tactics: Array[TacticDef] = []
@export var facilities: Array[FacilityDef] = []
@export var codex_entries: Array[CodexEntryDef] = []
@export var stages: Array[StageDef] = []


## Looks up a TroopDef by numeric troop_id, or null if absent.
func get_troop(troop_id: int) -> TroopDef:
	for t: TroopDef in troops:
		if t != null and t.troop_id == troop_id:
			return t
	return null


## Looks up a TroopDef by string code, or null if absent.
func get_troop_by_code(code: String) -> TroopDef:
	for t: TroopDef in troops:
		if t != null and t.code == code:
			return t
	return null


## Looks up a GeneralDef by numeric general_id, or null if absent.
func get_general(general_id: int) -> GeneralDef:
	for g: GeneralDef in generals:
		if g != null and g.general_id == general_id:
			return g
	return null


## Looks up a GeneralDef by string code, or null if absent.
func get_general_by_code(code: String) -> GeneralDef:
	for g: GeneralDef in generals:
		if g != null and g.code == code:
			return g
	return null


## Looks up a TacticDef by numeric tactic_id, or null if absent.
func get_tactic(tactic_id: int) -> TacticDef:
	for tc: TacticDef in tactics:
		if tc != null and tc.tactic_id == tactic_id:
			return tc
	return null


## Looks up a TacticDef by string code, or null if absent.
func get_tactic_by_code(code: String) -> TacticDef:
	for tc: TacticDef in tactics:
		if tc != null and tc.code == code:
			return tc
	return null


## Looks up a FacilityDef by facility_id (exact match first, then case-insensitive).
func get_facility(facility_id: String) -> FacilityDef:
	for f: FacilityDef in facilities:
		if f != null and f.facility_id == facility_id:
			return f
	var lower_id: String = facility_id.strip_edges().to_lower()
	for f: FacilityDef in facilities:
		if f != null and f.facility_id.to_lower() == lower_id:
			return f
	return null


## Looks up a CodexEntryDef by string entry_id, or null if absent.
func get_codex_entry(entry_id: String) -> CodexEntryDef:
	for c: CodexEntryDef in codex_entries:
		if c != null and c.entry_id == entry_id:
			return c
	return null


## Returns all CodexEntryDef items matching the query string.
func filter_codex(query: String) -> Array[CodexEntryDef]:
	var matched: Array[CodexEntryDef] = []
	for c: CodexEntryDef in codex_entries:
		if c != null and c.matches_query(query):
			matched.append(c)
	return matched


## Looks up a StageDef by numeric stage_id, or null if absent.
func get_stage(stage_id: int) -> StageDef:
	for st: StageDef in stages:
		if st != null and st.stage_id == stage_id:
			return st
	return null


## Looks up a StageDef by string code, or null if absent.
func get_stage_by_code(code: String) -> StageDef:
	for st: StageDef in stages:
		if st != null and st.code == code:
			return st
	return null


## Validates uniqueness, ranges, and historical metadata across all registered definitions.
func validate() -> Array[String]:
	var errors: Array[String] = []
	_validate_troops(errors)
	_validate_generals(errors)
	_validate_tactics(errors)
	_validate_facilities(errors)
	_validate_codex(errors)
	_validate_stages(errors)
	return errors


func _validate_int_id_and_code(
	label: String,
	idx: int,
	id_val: int,
	code: String,
	seen_ids: Dictionary,
	seen_codes: Dictionary,
	errors: Array[String]
) -> void:
	if id_val <= 0:
		errors.append("%s at [%d] has non-positive id=%d" % [label, idx, id_val])
	elif seen_ids.has(id_val):
		errors.append("Duplicate %s id=%d" % [label, id_val])
	seen_ids[id_val] = true
	if code.strip_edges().is_empty():
		errors.append("%s %d has empty code" % [label, id_val])
	elif seen_codes.has(code):
		errors.append("Duplicate %s code=%s" % [label, code])
	seen_codes[code] = true


func _validate_string_id(
	label: String,
	idx: int,
	id_val: String,
	seen_ids: Dictionary,
	errors: Array[String]
) -> void:
	if id_val.strip_edges().is_empty():
		errors.append("%s at [%d] has empty id" % [label, idx])
	elif seen_ids.has(id_val):
		errors.append("Duplicate %s id=%s" % [label, id_val])
	seen_ids[id_val] = true


func _validate_troops(errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	var seen_codes: Dictionary = {}
	for i: int in range(troops.size()):
		var t: TroopDef = troops[i]
		if t == null:
			errors.append("troops[%d] is null" % i)
			continue
		_validate_int_id_and_code("TroopDef", i, t.troop_id, t.code, seen_ids, seen_codes, errors)
		if t.min_range < 1 or t.min_range > t.max_range:
			errors.append("TroopDef %d has invalid range %d..%d" % [t.troop_id, t.min_range, t.max_range])
		if t.damage_roll_min > t.damage_roll_max:
			errors.append("TroopDef %d has damage_roll_min > damage_roll_max" % t.troop_id)
		if t.base_hp <= 0 or t.mobility <= 0:
			errors.append("TroopDef %d has non-positive base_hp or mobility" % t.troop_id)


func _validate_generals(errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	var seen_codes: Dictionary = {}
	for i: int in range(generals.size()):
		var g: GeneralDef = generals[i]
		if g == null:
			errors.append("generals[%d] is null" % i)
			continue
		_validate_int_id_and_code("GeneralDef", i, g.general_id, g.code, seen_ids, seen_codes, errors)
		if g.source_ref.strip_edges().is_empty():
			errors.append("GeneralDef %d has empty source_ref" % g.general_id)


func _validate_tactics(errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	var seen_codes: Dictionary = {}
	for i: int in range(tactics.size()):
		var tc: TacticDef = tactics[i]
		if tc == null:
			errors.append("tactics[%d] is null" % i)
			continue
		_validate_int_id_and_code("TacticDef", i, tc.tactic_id, tc.code, seen_ids, seen_codes, errors)
		if tc.source_ref.strip_edges().is_empty():
			errors.append("TacticDef %d has empty source_ref" % tc.tactic_id)


func _validate_facilities(errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	for i: int in range(facilities.size()):
		var f: FacilityDef = facilities[i]
		if f == null:
			errors.append("facilities[%d] is null" % i)
			continue
		_validate_string_id("FacilityDef", i, f.facility_id, seen_ids, errors)


func _validate_codex(errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	for i: int in range(codex_entries.size()):
		var c: CodexEntryDef = codex_entries[i]
		if c == null:
			errors.append("codex_entries[%d] is null" % i)
			continue
		_validate_string_id("CodexEntryDef", i, c.entry_id, seen_ids, errors)
		if c.source_ref.strip_edges().is_empty():
			errors.append("CodexEntryDef %s has empty source_ref" % c.entry_id)
		if c.modeling_type.strip_edges().is_empty():
			errors.append("CodexEntryDef %s has empty modeling_type" % c.entry_id)
		if c.category == "historical" and not ["A", "B", "C", "D"].has(c.evidence_grade):
			errors.append("Historical CodexEntryDef %s has invalid evidence_grade='%s'" % [c.entry_id, c.evidence_grade])
		if c.evidence_grade == "D" and c.modeling_type == "historical_claim":
			errors.append("Grade D CodexEntryDef %s cannot be historical_claim" % c.entry_id)
		if (c.source_ref.contains("[S1]") or c.source_ref.contains("[S2]") or c.source_ref.contains("[S8]")) and not c.evidence_grade.is_empty():
			errors.append("Benchmark CodexEntryDef %s must have empty evidence_grade" % c.entry_id)


func _validate_stages(errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	var seen_codes: Dictionary = {}
	for i: int in range(stages.size()):
		var st: StageDef = stages[i]
		if st == null:
			errors.append("stages[%d] is null" % i)
			continue
		_validate_int_id_and_code("StageDef", i, st.stage_id, st.code, seen_ids, seen_codes, errors)
		_validate_single_stage(st, errors)


func _validate_single_stage(st: StageDef, errors: Array[String]) -> void:
	if st.map_width <= 0 or st.map_height <= 0 or st.max_rounds <= 0:
		errors.append("StageDef %d has non-positive map dimensions or max_rounds" % st.stage_id)
	if st.turn_order.is_empty():
		errors.append("StageDef %d has empty turn_order" % st.stage_id)
	if st.source_ref.strip_edges().is_empty():
		errors.append("StageDef %d has empty source_ref" % st.stage_id)

	var seen_units: Dictionary = {}
	for p: UnitPlacementDef in st.placements:
		if p == null:
			errors.append("StageDef %d has null placement" % st.stage_id)
			continue
		if p.unit_id <= 0 or seen_units.has(p.unit_id):
			errors.append("StageDef %d has invalid/duplicate unit_id=%d" % [st.stage_id, p.unit_id])
		seen_units[p.unit_id] = true

	var seen_areas: Dictionary = {}
	for a: NamedAreaDef in st.areas:
		if a == null or a.area_id.strip_edges().is_empty() or seen_areas.has(a.area_id):
			errors.append("StageDef %d has invalid/duplicate area_id" % st.stage_id)
			continue
		seen_areas[a.area_id] = true

	var dlg_ids: Dictionary = {}
	for line_def: DialogueLineDef in st.dialogues:
		if line_def != null and not line_def.dialogue_id.is_empty():
			dlg_ids[line_def.dialogue_id] = true

	var seen_events: Dictionary = {}
	for evt: ScenarioEventDef in st.scripted_events:
		if evt == null or evt.event_id.strip_edges().is_empty() or seen_events.has(evt.event_id):
			errors.append("StageDef %d has invalid/duplicate event_id" % st.stage_id)
			continue
		seen_events[evt.event_id] = true
		for act: ScenarioEventActionDef in evt.results:
			if act != null and act.action_type == "PlayDialogue" and not dlg_ids.has(act.dialogue_id):
				errors.append("StageDef %d event %s references missing dialogue_id=%s" % [st.stage_id, evt.event_id, act.dialogue_id])
