extends SceneTree

const E2ECaseScript = preload("res://tests/e2e/e2e_case.gd")

const TIER_SUITES: Dictionary[int, String] = {
	1: "res://tests/e2e/suite_tier1.gd",
	2: "res://tests/e2e/suite_tier2.gd",
	3: "res://tests/e2e/suite_tier3.gd",
	4: "res://tests/e2e/suite_tier4.gd",
}

var _did_run: bool = false


func _process(_delta: float) -> bool:
	if _did_run:
		return false
	_did_run = true
	_run_all()
	return false


func _parse_cli_options() -> Dictionary:
	var tiers: Array[int] = [1, 2, 3, 4]
	var seed_val: int = 12880409
	var verbose: bool = false
	var fail_fast: bool = false

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	for arg: String in args:
		if arg == "--verbose":
			verbose = true
		elif arg == "--fail-fast":
			fail_fast = true
		elif arg.begins_with("--seed="):
			var raw_seed: String = arg.substr(7).strip_edges()
			if raw_seed.is_valid_int():
				seed_val = int(raw_seed)
		elif arg.begins_with("--tier="):
			var raw_tiers: String = arg.substr(7).strip_edges()
			var parsed: Array[int] = []
			for tok: String in raw_tiers.split(",", false):
				var t_str: String = tok.strip_edges()
				if t_str.is_valid_int():
					var t_num: int = int(t_str)
					if TIER_SUITES.has(t_num) and not parsed.has(t_num):
						parsed.append(t_num)
			if not parsed.is_empty():
				tiers = parsed

	tiers.sort()
	return {
		"tiers": tiers,
		"seed": seed_val,
		"verbose": verbose,
		"fail_fast": fail_fast,
	}


func _run_all() -> void:
	if root != null and (root.size.x < 320 or root.size.y < 240):
		root.size = Vector2i(1280, 720)
		await process_frame
	var opts: Dictionary = _parse_cli_options()
	var tiers: Array[int] = opts["tiers"]
	var seed_val: int = int(opts["seed"])
	var verbose: bool = bool(opts["verbose"])
	var fail_fast: bool = bool(opts["fail_fast"])

	print("============================================================")
	print(" DAI VIET CHIEN KY — E2E TEST RUNNER (Godot %s)" % Engine.get_version_info().get("string", "4.x"))
	print(" Tiers: %s | Seed: %d | Fail-fast: %s | Verbose: %s" % [
		str(tiers),
		seed_val,
		str(fail_fast),
		str(verbose),
	])
	print("============================================================")

	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	var total_assertions: int = 0
	var aborted_early: bool = false

	for tier_num: int in tiers:
		var path: String = TIER_SUITES[tier_num]
		print("\n--- Tier %d Suite: %s ---" % [tier_num, path])

		if not ResourceLoader.exists(path):
			print("  [FAIL] Suite file not found: %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted_early = true
				break
			continue

		var res: Resource = load(path)
		if res == null or not (res is GDScript):
			print("  [FAIL] Could not load/compile GDScript: %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted_early = true
				break
			continue

		var script: GDScript = res as GDScript
		if not script.can_instantiate():
			print("  [FAIL] Suite cannot instantiate (compile error): %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted_early = true
				break
			continue

		var instance: Variant = script.new()
		if not is_instance_of(instance, E2ECaseScript):
			print("  [FAIL] Suite does not extend e2e_case.gd: %s" % path)
			failed_tests += 1
			total_tests += 1
			if fail_fast:
				aborted_early = true
				break
			continue

		var suite: RefCounted = instance as RefCounted
		var methods: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var m_name: String = str(m.get("name", ""))
			if m_name.begins_with("e2e_"):
				methods.append(m_name)
		methods.sort()

		var tier_passed: int = 0
		var tier_failed: int = 0
		var tier_total: int = 0

		for method_name: String in methods:
			total_tests += 1
			tier_total += 1
			suite.setup_context(self)
			suite.set("e2e_seed", seed_val)
			suite.set("verbose", verbose)
			suite.before_each()
			await suite.call(method_name)
			suite.after_each()

			var assertions: int = int(suite.get_assertion_count())
			total_assertions += assertions
			var failures: Array[String] = suite.get_failures()
			if failures.is_empty():
				passed_tests += 1
				tier_passed += 1
				if verbose:
					print("  [PASS] %s (%d assertions)" % [method_name, assertions])
			else:
				failed_tests += 1
				tier_failed += 1
				print("  [FAIL] %s" % method_name)
				for failure_msg: String in failures:
					print("         -> %s" % failure_msg)
				if fail_fast:
					aborted_early = true
					break

		print("  >> Tier %d Summary: %d/%d passed | %d failed" % [
			tier_num,
			tier_passed,
			tier_total,
			tier_failed,
		])
		if aborted_early:
			break

	print("\n============================================================")
	print(" E2E SUMMARY: %d/%d tests passed | %d failed | %d assertions%s" % [
		passed_tests,
		total_tests,
		failed_tests,
		total_assertions,
		" (ABORTED BY --fail-fast)" if aborted_early else "",
	])
	print("============================================================")
	quit(0 if failed_tests == 0 else 1)
