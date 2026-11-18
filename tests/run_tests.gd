extends SceneTree

const TestCaseScript = preload("res://tests/test_case.gd")

var _did_run: bool = false


func _process(_delta: float) -> bool:
	if _did_run:
		return true
	_did_run = true
	var exit_code: int = _run_all_suites()
	quit(exit_code)
	return true


func _run_all_suites() -> int:
	print("============================================================")
	print(" DAI VIET CHIEN KY — HEADLESS TEST RUNNER (Godot %s)" % Engine.get_version_info().get("string", "4.x"))
	print("============================================================")

	var suite_paths: Array[String] = _discover_test_files("res://tests")
	suite_paths.sort()

	if suite_paths.is_empty():
		print("[WARN] No test files (test_*.gd) found in res://tests/")
		print("============================================================")
		return 0

	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	var total_assertions: int = 0

	for path: String in suite_paths:
		print("\n--- Suite: %s ---" % path)
		var res: Resource = load(path)
		if res == null or not (res is GDScript):
			print("  [FAIL] Could not load/compile GDScript: %s" % path)
			failed_tests += 1
			total_tests += 1
			continue

		var script: GDScript = res as GDScript
		if not script.can_instantiate():
			print("  [FAIL] Script cannot instantiate (compile error): %s" % path)
			failed_tests += 1
			total_tests += 1
			continue

		var instance: Variant = script.new()
		if not is_instance_of(instance, TestCaseScript):
			print("  [FAIL] Suite does not extend GdTestCase: %s" % path)
			failed_tests += 1
			total_tests += 1
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
			suite.before_each()
			suite.call(method_name)
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

	print("\n============================================================")
	print(" SUMMARY: %d/%d tests passed | %d failed | %d assertions" % [
		passed_tests,
		total_tests,
		failed_tests,
		total_assertions,
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
