extends "res://tests/test_case.gd"

const BattleSandboxScene = preload("res://scenes/battle/battle_sandbox_cp1.tscn")
const ScenarioLoader = preload("res://sim/state/scenario_loader.gd")
const BattleCommands = preload("res://sim/commands/battle_commands.gd")
const AIDecisionMatrix = preload("res://sim/ai/ai_decision_matrix.gd")


func test_export_presets_web_and_android_contracts() -> void:
	assert_true(FileAccess.file_exists("res://export_presets.cfg"), "export_presets.cfg must exist at project root")
	var cfg := ConfigFile.new()
	var err: Error = cfg.load("res://export_presets.cfg")
	assert_eq(err, OK, "export_presets.cfg must parse cleanly via ConfigFile")
	if err != OK:
		return

	var found_web: bool = false
	var found_android: bool = false
	for sec: String in cfg.get_sections():
		if not sec.begins_with("preset.") or sec.ends_with(".options"):
			continue
		var p_name: String = str(cfg.get_value(sec, "name", ""))
		var platform: String = str(cfg.get_value(sec, "platform", ""))
		var exclude_filter: String = str(cfg.get_value(sec, "exclude_filter", ""))
		var export_path: String = str(cfg.get_value(sec, "export_path", ""))
		var opt_sec: String = sec + ".options"

		if p_name == "Web" or platform == "Web":
			found_web = true
			assert_true(exclude_filter.contains("Assets/*"), "Web preset must exclude legacy Assets/*")
			assert_true(export_path.ends_with(".html"), "Web preset must target .html output")
			assert_eq(bool(cfg.get_value(opt_sec, "variant/thread_support", true)), false, "Web preset must disable thread_support for COOP/COEP-free hosting")
		elif p_name == "Android" or platform == "Android":
			found_android = true
			assert_true(exclude_filter.contains("Assets/*"), "Android preset must exclude legacy Assets/*")
			assert_true(export_path.ends_with(".apk") or export_path.ends_with(".aab"), "Android preset must target .apk or .aab")
			assert_eq(str(cfg.get_value(opt_sec, "package/unique_name", "")), "com.daiviet.chienky", "Android unique package name must be com.daiviet.chienky")
			assert_eq(bool(cfg.get_value(opt_sec, "architectures/arm64-v8a", false)), true, "Android preset must enable arm64-v8a")

	assert_true(found_web, "Web export preset must be configured")
	assert_true(found_android, "Android export preset must be configured")

	var renderer_pc: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var renderer_mobile: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	assert_eq(renderer_pc, "gl_compatibility", "Desktop/Web rendering method must be gl_compatibility")
	assert_eq(renderer_mobile, "gl_compatibility", "Mobile rendering method must be gl_compatibility")


func test_stress_30x30_44_units_and_campaign_stages_60fps_budget() -> void:
	var sandbox: Node2D = BattleSandboxScene.instantiate()
	add_child_autofree(sandbox)

	var map_state: BattleMapState = sandbox.call("get_map_state") as BattleMapState
	var map_view: BattleMapView = sandbox.call("get_map_view") as BattleMapView
	var camera: BattleCameraController = sandbox.call("get_camera") as BattleCameraController

	var t0_12x10: int = Time.get_ticks_usec()
	for i: int in range(24):
		camera._process(1.0 / 60.0)
		sandbox.call("_process", 1.0 / 60.0)
	var mean_12x10_ms: float = (float(Time.get_ticks_usec() - t0_12x10) / 1000.0) / 24.0
	assert_true(mean_12x10_ms <= 16.67, "12x10 Bach Dang frame time <= 16.67ms (60 FPS)")

	sandbox.call("load_stress_benchmark_30x30", 44)
	map_state = sandbox.call("get_map_state") as BattleMapState
	assert_eq(map_state.width, 30, "Stress map width is 30")
	assert_eq(map_state.height, 30, "Stress map height is 30")
	assert_true(map_state.get_all_units().size() >= 44, "Stress map has >= 44 active units")

	var t0_30x30: int = Time.get_ticks_usec()
	for i: int in range(36):
		camera._process(1.0 / 60.0)
		sandbox.call("_process", 1.0 / 60.0)
	var mean_30x30_ms: float = (float(Time.get_ticks_usec() - t0_30x30) / 1000.0) / 36.0
	assert_true(mean_30x30_ms <= 16.67, "30x30 44-unit stress frame time <= 16.67ms (60 FPS)")

	camera.set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, false)
	for i: int in range(20):
		camera._process(1.0 / 60.0)
	assert_true(map_view.is_strategic_lod(), "StrategicTokenLayer LOD active at 0.5x strategic zoom")
	assert_false((map_view.get_node("UnitModelLayer") as CanvasItem).visible, "UnitModelLayer hidden at 0.5x strategic zoom")
	assert_true((map_view.get_node("StrategicTokenLayer") as CanvasItem).visible, "StrategicTokenLayer visible at 0.5x strategic zoom")

	# Verify AI turn calculation budget on tactical stage 10101 (< 1500 ms) and economy stage 10105 (< 3000 ms)
	var ai := AIDecisionMatrix.new()
	var ctrl_10101 := ScenarioLoader.load_stage(10101, 20260405)
	ctrl_10101.submit_command(BattleCommands.EndTurnCommand.new(1))
	var t0_10101: int = Time.get_ticks_usec()
	ai.execute_faction_turn(ctrl_10101, 2)
	var elapsed_10101_ms: float = float(Time.get_ticks_usec() - t0_10101) / 1000.0
	assert_true(elapsed_10101_ms < 1500.0, "Stage 10101 AI turn must complete under 1500ms")

	var ctrl_10105 := ScenarioLoader.load_stage(10105, 20260405)
	ctrl_10105.submit_command(BattleCommands.EndTurnCommand.new(1))
	var t0_10105: int = Time.get_ticks_usec()
	ai.execute_faction_turn(ctrl_10105, 2)
	var elapsed_10105_ms: float = float(Time.get_ticks_usec() - t0_10105) / 1000.0
	assert_true(elapsed_10105_ms < 3000.0, "Stage 10105 Economy AI turn must complete under 3000ms")


func test_user_fs_write_only_discipline_and_export_state_documentation() -> void:
	var scripts: Array[String] = []
	for root_dir: String in ["res://sim", "res://game", "res://ui", "res://scripts"]:
		scripts.append_array(_collect_gd_files(root_dir))
	assert_true(scripts.size() >= 25, "At least 25 project scripts audited")
	var write_regex := RegEx.new()
	write_regex.compile("FileAccess\\.open\\s*\\(\\s*\"res://[^\"]+\"\\s*,\\s*FileAccess\\.(WRITE|READ_WRITE|WRITE_READ)")

	for path: String in scripts:
		var src: String = FileAccess.get_file_as_string(path)
		assert_eq(write_regex.search(src), null, "No script may open res:// for writing: %s" % path)
		assert_false(src.contains("SharedArrayBuffer"), "No SharedArrayBuffer assumption in %s" % path)

	assert_true(FileAccess.file_exists("res://STATE.md"), "STATE.md must exist")
	var state_text: String = FileAccess.get_file_as_string("res://STATE.md")
	assert_true(state_text.contains("C5-T3"), "STATE.md must document C5-T3 status")


func _collect_gd_files(root_dir: String) -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(root_dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var full: String = root_dir.path_join(name)
			if d.current_is_dir():
				out.append_array(_collect_gd_files(full))
			elif name.ends_with(".gd"):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out
