class_name StageDef
extends Resource
## Complete campaign battle stage configuration editable in Godot Inspector (`res://data/defs/`).

@export_group("Identity")
@export var stage_id: int = 10101
@export var code: String = ""
@export var stage_name: String = ""
@export var chapter_id: int = 1
@export var historical_era: String = "Tran_Nguyen"
@export_enum("easy", "normal", "hard", "nightmare") var recommended_difficulty: String = "normal"
@export_enum("historical_claim", "fixture", "abstraction", "what_if") var modeling_type: String = "historical_claim"
@export_multiline var source_ref: String = ""

@export_group("Map & Rules")
@export var map_scene: PackedScene
@export_enum("odd_r", "axial") var coordinate_space: String = "odd_r"
@export_range(6, 60) var map_width: int = 12
@export_range(6, 60) var map_height: int = 10
@export_range(1, 50) var max_rounds: int = 10
@export var enable_economy: bool = false
@export var player_faction_id: int = 1
@export var staked_water_owner_faction: int = 1
@export_enum("Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var default_terrain: int = 0
@export var turn_order: Array[int] = [1, 2]
@export var max_general_seats: int = 2
@export var preset_general_ids: Array[int] = []
@export var banned_troop_ids: Array[int] = []

@export_group("Factions & Terrain")
@export var factions: Array[StageFactionDef] = []
@export var terrain_overrides: Array[TerrainOverrideDef] = []
@export var areas: Array[NamedAreaDef] = []
@export var facilities: Array[StageFacilityDef] = []

@export_group("Units & Objectives")
@export var placements: Array[UnitPlacementDef] = []
@export var victory_conditions: Array[VictoryConditionDef] = []
@export var defeat_conditions: Array[DefeatConditionDef] = []
@export var star_conditions: Array[StarConditionDef] = []

@export_group("Scripted Events & Dialogues")
@export var scripted_events: Array[ScenarioEventDef] = []
@export var dialogues: Array[DialogueLineDef] = []


static func _to_int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for item: Variant in raw:
			out.append(int(item))
	return out


## Constructs a StageDef from paired stage_settings.json and battle_<id>.json dictionaries.
static func from_stage_and_battle_dicts(stage_meta: Dictionary, battle_data: Dictionary) -> StageDef:
	var def := StageDef.new()
	def.stage_id = int(stage_meta.get("id", battle_data.get("stage_id", 10101)))
	def.code = str(stage_meta.get("code", "stage_%d" % def.stage_id))
	def.stage_name = str(stage_meta.get("name", battle_data.get("name", def.code)))
	def.chapter_id = int(stage_meta.get("chapter", 1))
	def.historical_era = str(stage_meta.get("historical_era", "Tran_Nguyen"))
	var diff_str: String = str(stage_meta.get("recommended_difficulty", "normal")).to_lower()
	def.recommended_difficulty = diff_str if diff_str in ["easy", "normal", "hard", "nightmare"] else "normal"
	var mod_str: String = str(stage_meta.get("modeling_type", "historical_claim"))
	def.modeling_type = mod_str if mod_str in ["historical_claim", "fixture", "abstraction", "what_if"] else "historical_claim"
	def.source_ref = str(stage_meta.get("source_ref", ""))

	var coord: String = str(battle_data.get("coordinate_space", "odd_r"))
	def.coordinate_space = coord if coord in ["odd_r", "axial"] else "odd_r"
	def.map_width = maxi(6, int(battle_data.get("map_width", 12)))
	def.map_height = maxi(6, int(battle_data.get("map_height", 10)))
	def.max_rounds = maxi(1, int(battle_data.get("max_rounds", stage_meta.get("max_rounds", 10))))
	def.enable_economy = bool(battle_data.get("enable_economy", stage_meta.get("enable_economy", false)))
	def.player_faction_id = int(battle_data.get("player_faction_id", 1))
	def.staked_water_owner_faction = int(battle_data.get("staked_water_owner_faction", 1))
	def.default_terrain = maxi(0, TroopDef.parse_terrain_id(battle_data.get("default_terrain", "Plains")))
	def.turn_order = _to_int_array(battle_data.get("turn_order", [1, 2]))
	if def.turn_order.is_empty():
		def.turn_order = [1, 2]
	def.max_general_seats = int(stage_meta.get("max_general_seats", 2))
	def.preset_general_ids = _to_int_array(stage_meta.get("preset_general_ids", []))
	def.banned_troop_ids = _to_int_array(stage_meta.get("banned_troop_ids", []))

	_parse_factions_and_economy(def, battle_data)
	_parse_map_and_units(def, battle_data)
	_parse_conditions_and_events(def, battle_data)
	return def


static func _parse_factions_and_economy(def: StageDef, battle_data: Dictionary) -> void:
	var raw_eco: Variant = battle_data.get("economy", {})
	var eco_dict: Dictionary = raw_eco as Dictionary if raw_eco is Dictionary else {}
	var eco_factions: Variant = eco_dict.get("factions", {})
	var eco_fac_map: Dictionary = eco_factions as Dictionary if eco_factions is Dictionary else {}

	var fac_out: Array[StageFactionDef] = []
	var raw_factions: Variant = battle_data.get("factions", [])
	if raw_factions is Array:
		for f_var: Variant in raw_factions:
			if f_var is Dictionary:
				var fd: Dictionary = f_var as Dictionary
				var fid_key: String = str(int(fd.get("faction_id", 1)))
				var f_eco: Dictionary = eco_fac_map.get(fid_key, {}) as Dictionary
				fac_out.append(StageFactionDef.from_dict(fd, f_eco))
	def.factions = fac_out

	var facil_out: Array[StageFacilityDef] = []
	var raw_facils: Variant = eco_dict.get("facilities", [])
	if raw_facils is Array:
		for fl_var: Variant in raw_facils:
			if fl_var is Dictionary:
				facil_out.append(StageFacilityDef.from_dict(fl_var as Dictionary))
	def.facilities = facil_out


static func _parse_map_and_units(def: StageDef, battle_data: Dictionary) -> void:
	var ov_out: Array[TerrainOverrideDef] = []
	var raw_ov: Variant = battle_data.get("terrain_overrides", [])
	if raw_ov is Array:
		for ov_var: Variant in raw_ov:
			if ov_var is Dictionary:
				ov_out.append(TerrainOverrideDef.from_dict(ov_var as Dictionary))
	def.terrain_overrides = ov_out

	var areas_out: Array[NamedAreaDef] = []
	var raw_areas: Variant = battle_data.get("areas", [])
	if raw_areas is Array:
		for a_var: Variant in raw_areas:
			if a_var is Dictionary:
				areas_out.append(NamedAreaDef.from_dict(a_var as Dictionary))
	def.areas = areas_out

	var place_out: Array[UnitPlacementDef] = []
	var raw_places: Variant = battle_data.get("placements", [])
	if raw_places is Array:
		for p_var: Variant in raw_places:
			if p_var is Dictionary:
				place_out.append(UnitPlacementDef.from_dict(p_var as Dictionary))
	def.placements = place_out


static func _parse_conditions_and_events(def: StageDef, battle_data: Dictionary) -> void:
	var vc_out: Array[VictoryConditionDef] = []
	var raw_vc: Variant = battle_data.get("victory_conditions", [])
	if raw_vc is Array:
		for v_var: Variant in raw_vc:
			if v_var is Dictionary:
				vc_out.append(VictoryConditionDef.from_dict(v_var as Dictionary))
	def.victory_conditions = vc_out

	var dc_out: Array[DefeatConditionDef] = []
	var raw_dc: Variant = battle_data.get("defeat_conditions", [])
	if raw_dc is Array:
		for d_var: Variant in raw_dc:
			if d_var is Dictionary:
				dc_out.append(DefeatConditionDef.from_dict(d_var as Dictionary))
	def.defeat_conditions = dc_out

	var sc_out: Array[StarConditionDef] = []
	var raw_sc: Variant = battle_data.get("star_conditions", [])
	if raw_sc is Array:
		for s_var: Variant in raw_sc:
			if s_var is Dictionary:
				sc_out.append(StarConditionDef.from_dict(s_var as Dictionary))
	def.star_conditions = sc_out

	var evt_out: Array[ScenarioEventDef] = []
	var raw_evts: Variant = battle_data.get("events", [])
	if raw_evts is Array:
		for e_var: Variant in raw_evts:
			if e_var is Dictionary:
				evt_out.append(ScenarioEventDef.from_dict(e_var as Dictionary))
	def.scripted_events = evt_out

	var dlg_out: Array[DialogueLineDef] = []
	var raw_dlgs: Variant = battle_data.get("dialogues", {})
	if raw_dlgs is Dictionary:
		for dlg_id_var: Variant in (raw_dlgs as Dictionary).keys():
			var dlg_id: String = str(dlg_id_var)
			var val: Variant = (raw_dlgs as Dictionary)[dlg_id_var]
			if val is Dictionary:
				var vd: Dictionary = val as Dictionary
				if vd.has("lines") and vd["lines"] is Array:
					for line_var: Variant in vd["lines"] as Array:
						if line_var is Dictionary:
							dlg_out.append(DialogueLineDef.from_dict(dlg_id, line_var as Dictionary))
				else:
					dlg_out.append(DialogueLineDef.from_dict(dlg_id, vd))
			elif val is Array:
				for item_var: Variant in val as Array:
					if item_var is Dictionary:
						dlg_out.append(DialogueLineDef.from_dict(dlg_id, item_var as Dictionary))
	def.dialogues = dlg_out


## Serializes stage catalog metadata matching stage_settings.json entries.
func to_stage_meta_dict() -> Dictionary:
	return {
		"id": stage_id,
		"code": code,
		"name": stage_name,
		"chapter": chapter_id,
		"max_rounds": max_rounds,
		"enable_economy": enable_economy,
		"recommended_difficulty": recommended_difficulty,
		"preset_general_ids": Array(preset_general_ids),
		"max_general_seats": max_general_seats,
		"banned_troop_ids": Array(banned_troop_ids),
		"modeling_type": modeling_type,
		"source_ref": source_ref,
	}


## Groups DialogueLineDef items by dialogue_id (single dict or array of dicts) for DialogueModal.
func get_dialogues_dict() -> Dictionary:
	var grouped: Dictionary = {}
	for line_def: DialogueLineDef in dialogues:
		if line_def == null or line_def.dialogue_id.is_empty():
			continue
		if not grouped.has(line_def.dialogue_id):
			grouped[line_def.dialogue_id] = []
		(grouped[line_def.dialogue_id] as Array).append(line_def.to_line_dict())

	var out: Dictionary = {}
	for dlg_id: Variant in grouped.keys():
		var arr: Array = grouped[dlg_id] as Array
		out[dlg_id] = arr[0] if arr.size() == 1 else arr
	return out


## Serializes the full battle definition to a dictionary compatible with ScenarioLoader.
func to_battle_dict() -> Dictionary:
	var fac_dicts: Array[Dictionary] = []
	var eco_factions: Dictionary = {}
	for f: StageFactionDef in factions:
		if f != null:
			fac_dicts.append(f.to_dict())
			eco_factions[str(f.faction_id)] = f.to_economy_dict()

	var ov_dicts: Array[Dictionary] = []
	for ov: TerrainOverrideDef in terrain_overrides:
		if ov != null:
			ov_dicts.append(ov.to_dict())

	var area_dicts: Array[Dictionary] = []
	for a: NamedAreaDef in areas:
		if a != null:
			area_dicts.append(a.to_dict())

	var place_dicts: Array[Dictionary] = []
	for p: UnitPlacementDef in placements:
		if p != null:
			place_dicts.append(p.to_dict())

	var vc_dicts: Array[Dictionary] = []
	for vc: VictoryConditionDef in victory_conditions:
		if vc != null:
			vc_dicts.append(vc.to_dict())

	var dc_dicts: Array[Dictionary] = []
	for dc: DefeatConditionDef in defeat_conditions:
		if dc != null:
			dc_dicts.append(dc.to_dict())

	var sc_dicts: Array[Dictionary] = []
	for sc: StarConditionDef in star_conditions:
		if sc != null:
			sc_dicts.append(sc.to_dict())

	var evt_dicts: Array[Dictionary] = []
	for evt: ScenarioEventDef in scripted_events:
		if evt != null:
			evt_dicts.append(evt.to_dict())

	var out: Dictionary = {
		"stage_id": stage_id,
		"name": stage_name,
		"coordinate_space": coordinate_space,
		"map_width": map_width,
		"map_height": map_height,
		"max_rounds": max_rounds,
		"enable_economy": enable_economy,
		"player_faction_id": player_faction_id,
		"staked_water_owner_faction": staked_water_owner_faction,
		"default_terrain": TroopDef.terrain_to_name(default_terrain),
		"turn_order": Array(turn_order),
		"factions": fac_dicts,
		"terrain_overrides": ov_dicts,
		"areas": area_dicts,
		"placements": place_dicts,
		"victory_conditions": vc_dicts,
		"defeat_conditions": dc_dicts,
		"star_conditions": sc_dicts,
		"events": evt_dicts,
		"dialogues": get_dialogues_dict(),
	}

	if enable_economy or not facilities.is_empty():
		var facil_dicts: Array[Dictionary] = []
		for fl: StageFacilityDef in facilities:
			if fl != null:
				facil_dicts.append(fl.to_dict())
		out["economy"] = {
			"factions": eco_factions,
			"facilities": facil_dicts,
		}
	return out
