class_name AssetIpAuditor
extends RefCounted


func audit_case_exact_path(res_path: String) -> bool:
	var prefix: String = "res://"
	if not res_path.begins_with(prefix):
		return false
	var rel: String = res_path.substr(prefix.length()).trim_suffix("/")
	if rel.is_empty():
		return true

	var segments: PackedStringArray = rel.split("/", false)
	var current_dir: String = "res://"
	for i: int in range(segments.size()):
		var seg: String = segments[i]
		var da: DirAccess = DirAccess.open(current_dir)
		if da == null:
			return false
		var found_exact: bool = false
		var is_dir_match: bool = false
		da.list_dir_begin()
		var entry: String = da.get_next()
		while not entry.is_empty():
			if entry == seg:
				found_exact = true
				is_dir_match = da.current_is_dir()
				break
			entry = da.get_next()
		da.list_dir_end()
		if not found_exact:
			return false
		if i < segments.size() - 1 and not is_dir_match:
			return false
		current_dir = current_dir.path_join(seg)
	return true


func audit_registered_in_assets_md(res_path: String, assets_md_text: String = "") -> bool:
	if res_path.ends_with(".import") or res_path.ends_with(".uid"):
		return true
	var md: String = assets_md_text
	if md.is_empty() and FileAccess.file_exists("res://ASSETS.md"):
		md = FileAccess.get_file_as_string("res://ASSETS.md")
	return md.contains(res_path)


func audit_no_legacy_assets_ref(source_text: String) -> bool:
	var legacy_token: String = "res://" + "Assets/"
	return not source_text.contains(legacy_token)


func audit_core_ai_isolation(source_text: String) -> bool:
	var forbidden: Array[String] = [
		"extends " + "Node",
		"Scene" + "Tree",
		"Rendering" + "Server",
		"AudioStream" + "Player",
		"Canvas" + "Item",
		"get_" + "tree()",
	]
	for tok: String in forbidden:
		if source_text.contains(tok):
			return false
	return true


func run_full_audit() -> Dictionary:
	var violations: Array[String] = []
	var assets_md: String = FileAccess.get_file_as_string("res://ASSETS.md") if FileAccess.file_exists("res://ASSETS.md") else ""

	for dir_path: String in ["res://assets_clean", "res://data"]:
		for f: String in _list_files_recursive(dir_path):
			if f.ends_with(".import") or f.ends_with(".uid"):
				continue
			if not audit_registered_in_assets_md(f, assets_md):
				violations.append("Unregistered in ASSETS.md: " + f)
			if not audit_case_exact_path(f):
				violations.append("Case mismatch: " + f)

	for dir_path2: String in ["res://scripts", "res://scenes", "res://data"]:
		for f2: String in _list_files_recursive(dir_path2, [".gd", ".tscn", ".tres", ".gdshader", ".json"]):
			var txt: String = FileAccess.get_file_as_string(f2)
			if not audit_no_legacy_assets_ref(txt):
				violations.append("Legacy Assets ref in: " + f2)

	for dir_path3: String in ["res://scripts/core", "res://scripts/ai"]:
		for f3: String in _list_files_recursive(dir_path3, [".gd"]):
			var txt3: String = FileAccess.get_file_as_string(f3)
			if not audit_core_ai_isolation(txt3):
				violations.append("Core/AI isolation violation in: " + f3)

	return {
		"ok": violations.is_empty(),
		"violations": violations,
	}


func _list_files_recursive(dir_path: String, extensions: Array[String] = []) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				found.append_array(_list_files_recursive(full, extensions))
			else:
				if extensions.is_empty():
					found.append(full)
				else:
					var low: String = entry.to_lower()
					for ext: String in extensions:
						if low.ends_with(ext.to_lower()):
							found.append(full)
							break
		entry = dir.get_next()
	dir.list_dir_end()
	return found
