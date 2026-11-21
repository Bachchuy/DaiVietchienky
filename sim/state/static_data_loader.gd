class_name StaticDataLoader
extends RefCounted
## Loads static definitions from DataRegistry (.tres) and JSON runtime/fixture files.

const DEFAULT_REGISTRY_PATH: String = "res://data/registry.tres"


## Loads a DataRegistry resource from disk (or null if missing).
static func load_registry(registry_path: String = DEFAULT_REGISTRY_PATH) -> DataRegistry:
	if not ResourceLoader.exists(registry_path):
		push_error("StaticDataLoader: registry resource does not exist: %s" % registry_path)
		return null
	var res: Resource = ResourceLoader.load(registry_path)
	if res is DataRegistry:
		return res as DataRegistry
	push_error("StaticDataLoader: expected DataRegistry resource at %s" % registry_path)
	return null


static func _resolve_registry(registry: DataRegistry) -> DataRegistry:
	return registry if registry != null else load_registry()


## Returns TroopDef definitions from an injected DataRegistry or default registry.tres.
static func load_troop_defs(registry: DataRegistry = null) -> Array[TroopDef]:
	var reg: DataRegistry = _resolve_registry(registry)
	return reg.troops if reg != null else []


## Returns GeneralDef definitions from an injected DataRegistry or default registry.tres.
static func load_general_defs(registry: DataRegistry = null) -> Array[GeneralDef]:
	var reg: DataRegistry = _resolve_registry(registry)
	return reg.generals if reg != null else []


## Returns TacticDef definitions from an injected DataRegistry or default registry.tres.
static func load_tactic_defs(registry: DataRegistry = null) -> Array[TacticDef]:
	var reg: DataRegistry = _resolve_registry(registry)
	return reg.tactics if reg != null else []


## Returns FacilityDef definitions from an injected DataRegistry or default registry.tres.
static func load_facility_defs(registry: DataRegistry = null) -> Array[FacilityDef]:
	var reg: DataRegistry = _resolve_registry(registry)
	return reg.facilities if reg != null else []


## Returns CodexEntryDef definitions from an injected DataRegistry or default registry.tres.
static func load_codex_defs(registry: DataRegistry = null) -> Array[CodexEntryDef]:
	var reg: DataRegistry = _resolve_registry(registry)
	return reg.codex_entries if reg != null else []


## Returns StageDef definitions from an injected DataRegistry or default registry.tres.
static func load_stage_defs(registry: DataRegistry = null) -> Array[StageDef]:
	var reg: DataRegistry = _resolve_registry(registry)
	return reg.stages if reg != null else []


static func _load_json_variant(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_error("StaticDataLoader: file does not exist: %s" % file_path)
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("StaticDataLoader: failed to open: %s" % file_path)
		return null
	var raw_text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(raw_text)


static func load_json_array(file_path: String) -> Array:
	var parsed: Variant = _load_json_variant(file_path)
	if parsed is Array:
		return parsed
	if parsed != null:
		push_error("StaticDataLoader: expected top-level JSON Array in %s" % file_path)
	return []


static func load_json_dict(file_path: String) -> Dictionary:
	var parsed: Variant = _load_json_variant(file_path)
	if parsed is Dictionary:
		return parsed
	if parsed != null:
		push_error("StaticDataLoader: expected top-level JSON Dictionary in %s" % file_path)
	return {}


static func _index_array_by_id(items: Array) -> Dictionary[int, Dictionary]:
	var out: Dictionary[int, Dictionary] = {}
	for entry: Variant in items:
		if entry is Dictionary:
			var dict_entry: Dictionary = entry
			var id_val: int = int(dict_entry.get("id", 0))
			if id_val > 0:
				out[id_val] = dict_entry
	return out


## Loads troop dictionaries keyed by troop_id from DataRegistry (.tres), registry path, or JSON fallback.
static func load_troop_settings(source: Variant = DEFAULT_REGISTRY_PATH) -> Dictionary[int, Dictionary]:
	if source is String and (source as String).ends_with(".json"):
		return _index_array_by_id(load_json_array(source as String))
	var reg: DataRegistry = source as DataRegistry if source is DataRegistry else load_registry(str(source))
	var out: Dictionary[int, Dictionary] = {}
	if reg == null:
		return out
	for t: TroopDef in reg.troops:
		if t != null and t.troop_id > 0:
			out[t.troop_id] = t.to_troop_dict()
	return out


## Loads stage metadata dictionaries keyed by stage_id from DataRegistry (.tres), registry path, or JSON fallback.
static func load_stage_settings(source: Variant = DEFAULT_REGISTRY_PATH) -> Dictionary[int, Dictionary]:
	if source is String and (source as String).ends_with(".json"):
		return _index_array_by_id(load_json_array(source as String))
	var reg: DataRegistry = source as DataRegistry if source is DataRegistry else load_registry(str(source))
	var out: Dictionary[int, Dictionary] = {}
	if reg == null:
		return out
	for st: StageDef in reg.stages:
		if st != null and st.stage_id > 0:
			out[st.stage_id] = st.to_stage_meta_dict()
	return out
