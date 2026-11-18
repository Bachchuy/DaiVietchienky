class_name StaticDataLoader
extends RefCounted


static func load_json_array(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		push_error("StaticDataLoader: file does not exist: %s" % file_path)
		return []
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("StaticDataLoader: failed to open: %s" % file_path)
		return []
	var raw_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Array:
		return parsed
	push_error("StaticDataLoader: expected top-level JSON Array in %s" % file_path)
	return []


static func load_troop_settings(
	file_path: String = "res://data/settings/troop_settings.json"
) -> Dictionary[int, Dictionary]:
	var out: Dictionary[int, Dictionary] = {}
	var items: Array = load_json_array(file_path)
	for entry: Variant in items:
		if entry is Dictionary:
			var dict_entry: Dictionary = entry
			var id_val: int = int(dict_entry.get("id", 0))
			if id_val > 0:
				out[id_val] = dict_entry
	return out
