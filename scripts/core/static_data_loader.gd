class_name StaticDataLoader
extends RefCounted


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


static func load_troop_settings(
	file_path: String = "res://data/settings/troop_settings.json"
) -> Dictionary[int, Dictionary]:
	return _index_array_by_id(load_json_array(file_path))


static func load_stage_settings(
	file_path: String = "res://data/settings/stage_settings.json"
) -> Dictionary[int, Dictionary]:
	return _index_array_by_id(load_json_array(file_path))
