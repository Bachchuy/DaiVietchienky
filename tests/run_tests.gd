extends SceneTree

const TestCaseScript = preload("res://tests/test_case.gd")

var _did_run: bool = false


func _process(_delta: float) -> bool:
	if _did_run:
		return false
	_did_run = true
	_run_async()
	return false


func _run_async() -> void:
	var exit_code: int = await _run_all_suites()
	quit(exit_code)


func _parse_cli_options() -> Dictionary:
	var suite_filters: Array[String] = []
	var stress_mode: bool = false
	var fail_fast: bool = false

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	for arg: String in args:
		if arg == "--stress":
			stress_mode = true
		elif arg == "--fail-fast":
			fail_fast = true
		elif arg.begins_with("--suite="):
			var raw_suites: String = arg.substr(8).strip_edges()
			for tok: String in raw_suites.split(",", false):
				var clean: String = tok.strip_edges().to_lower()
				if not clean.is_empty() and not suite_filters.has(clean):
					suite_filters.append(clean)

	return {
		"suites": suite_filters,
		"stress": stress_mode,
		"fail_fast": fail_fast,
	}


func _matches_suite_filter(path: String, filters: Array[String]) -> bool:
	if filters.is_empty():
		return true
	var lower_path: String = path.to_lower()
	for f: String in filters:
		if lower_path.contains(f):
			return true
	return false


func _run_all_suites() -> int:
	var t_start_usec: int = Time.get_ticks_usec()
	var opts: Dictionary = _parse_cli_options()
	var suite_filters: Array[String] = opts["suites"]
	var stress_mode: bool = bool(opts["stress"])
	var fail_fast: bool = bool(opts["fail_fast"])

	print("============================================================")
	print(" DAI VIET CHIEN KY — HEADLESS TEST RUNNER (Godot %s)" % Engine.get_version_info().get("string", "4.x"))
	print(" Mode: %s | Filter: %s" % [
		"STRESS" if stress_mode else "FAST",
		str(suite_filters) if not suite_filters.is_empty() else "ALL",
	])
	print("============================================================")

	var discovered: Array[String] = _discover_test_files("res://tests")
	discovered.sort()
	var suite_paths: Array[String] = []
	for p: String in discovered:
		if _matches_suite_filter(p, suite_filters):
			suite_paths.append(p)

	if suite_paths.is_empty():
		print("[WARN] No test files matched in res://tests/")
		print("============================================================")
		return 1 if not suite_filters.is_empty() else 0

	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	var total_assertions: int = 0
	var aborted: bool = false

	for path: String in suite_paths:
		print("\n--- Suite: %s ---" % path)
		var res: Resource = load(path)
		if res == null or not (res is GDScript):
			print("  [FAIL] Could not load/compile GDScript: %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted = true
				break
			continue

		var script: GDScript = res as GDScript
		if not script.can_instantiate():
			print("  [FAIL] Script cannot instantiate (compile error): %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted = true
				break
			continue

		var instance: Variant = script.new()
		if not is_instance_of(instance, TestCaseScript):
			print("  [FAIL] Suite does not extend GdTestCase: %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted = true
				break
			continue

		var suite: RefCounted = instance as RefCounted
		var methods: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var method_name: String = str(m.get("name", ""))
			if method_name.begins_with("test_"):
				methods.append(method_name)
		methods.sort()

		for method_name: String in methods:
			total_tests += 1
			suite.setup_context(self)
			suite.set("stress_mode", stress_mode)
			suite.before_each()
			await suite.call(method_name)
			suite.after_each()

			total_assertions += suite.get_assertion_count()
			var failures: Array[String] = suite.get_failures()
			if failures.is_empty():
				passed_tests += 1
				print("  [PASS] %s (%d assertions)" % [method_name, suite.get_assertion_count()])
			else:
				failed_tests += 1
				print("  [FAIL] %s" % method_name)
				for failure_msg: String in failures:
					print("         -> %s" % failure_msg)
				if fail_fast:
					aborted = true
					break
		if aborted:
			break

	var elapsed_sec: float = float(Time.get_ticks_usec() - t_start_usec) / 1000000.0
	print("\n============================================================")
	print(" SUMMARY: %d/%d tests passed | %d failed | %d assertions | %.2fs" % [
		passed_tests,
		total_tests,
		failed_tests,
		total_assertions,
		elapsed_sec,
	])
	print("============================================================")
	return 0 if failed_tests == 0 else 1


func _discover_test_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found

	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full_path: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				found.append_array(_discover_test_files(full_path))
			elif entry.begins_with("test_") and entry.ends_with(".gd") and entry != "test_case.gd":
				found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
