extends "res://tests/e2e/e2e_case.gd"


func _odd_r(col: int, row: int) -> Vector2i:
	return HexMath.odd_r_to_axial(Vector2i(col, row))


func _boot_10101_sandbox() -> Dictionary:
	var sandbox: Node = spawn_battle_sandbox()
	if sandbox == null:
		return {}
	await pump_frames(2)
	return {
		"sandbox": sandbox,
		"ctrl": sandbox.call("get_controller"),
		"map_view": sandbox.call("get_map_view"),
		"map_state": sandbox.call("get_map_state"),
		"cam": sandbox.call("get_camera"),
	}


func _click_axial_opaque(sandbox: Node, axial: Vector2i) -> void:
	inject_left_click_screen(axial_to_screen(sandbox, axial))
	await pump_frames(2)


func _dismiss_opening_modals_if_any(sandbox: Node) -> void:
	for modal_name: String in ["BriefingModal", "DialogueModal"]:
		var m: Node = find_node_by_name_recursive(sandbox, modal_name)
		if m != null and m is Control and (m as Control).visible:
			var btn: BaseButton = find_button_matching(
				m,
				["StartButton", "ConfirmButton", "ContinueButton", "CloseButton", "NextButton"],
				["bắt đầu", "tiếp tục", "đóng", "start", "continue", "ok"]
			)
			if btn != null and not btn.disabled:
				inject_left_click_screen(btn.get_global_rect().get_center())
				await pump_frames(2)


func _advance_to_round(ctrl: RefCounted, target_round: int) -> void:
	var guard: int = 0
	while int(ctrl.get("current_round")) < target_round and int(ctrl.get("outcome")) == 0 and guard < 60:
		guard += 1
		ctrl.call("submit_command", BattleCommands.EndTurnCommand.new(int(ctrl.get("current_faction_id"))))


func e2e_t4_01_bach_dang_1288_three_star_victory_journey() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_fsm(sandbox, "M1") == null or require_hud_controller(sandbox, "M2") == null:
		return
	if require_juice_helper(sandbox, "M3") == null or require_audio_manager(sandbox, "M3") == null:
		return
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return

	var briefing: Control = require_hud_node(sandbox, ["BriefingModal"], "M2", "BriefingModal") as Control
	var dlg: Control = require_hud_node(sandbox, ["DialogueModal"], "M2", "DialogueModal") as Control
	var top_bar: Control = require_hud_node(sandbox, ["TopStatusBar"], "M2", "TopStatusBar") as Control
	var summary: Control = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if briefing == null or dlg == null or top_bar == null or summary == null:
		return

	assert_true(briefing.visible, "Briefing visible at launch")
	var start_btn: BaseButton = find_button_matching(briefing, ["StartButton", "ConfirmBriefingButton"], ["bắt đầu", "vào trận", "start"])
	if start_btn != null:
		inject_left_click_screen(start_btn.get_global_rect().get_center())
	else:
		inject_key_press(KEY_ENTER)
	await pump_frames(2)
	assert_true(dlg.visible and env["cam"].camera_locked, "Opening dialogue opens & locks camera")
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	assert_false(ctrl.enable_economy, "10101 enable_economy == false")

	# Rounds 1-3 maneuver + Undo check
	var u104: BattleUnit = ctrl.context.get_unit(104)
	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	inject_key_press(KEY_Z)
	await pump_frames(2)
	inject_key_press(KEY_W)
	await pump_frames(2)

	# Move enemy ship into area_bai_coc before Round 4 TideFall
	var e202: BattleUnit = ctrl.context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(6, 4))
	_advance_to_round(ctrl, 4)
	await pump_frames(2)

	assert_true(dlg.visible, "Round 4 TideFall opens talk_trieu_rut")
	await _dismiss_opening_modals_if_any(sandbox)
	assert_eq(int(env["map_state"].get_terrain(_odd_r(6, 4))), int(BattleMapState.TerrainType.STAKED_WATER), "area_bai_coc altered to StakedWater")
	assert_not_null(ctrl.context.get_unit(106), "Reinforcement 106 spawned")
	assert_not_null(ctrl.context.get_unit(107), "Reinforcement 107 spawned")

	# Cast 10001 Hịch Tướng Sĩ and defeat Ô Mã Nhi by Round 6 while holding signal_dock (2,8)
	var u101: BattleUnit = ctrl.context.get_unit(101)
	ctrl.submit_command(BattleCommands.CastSkillCommand.new(1, u101.unit_id, 10001, u101.hex_position))
	var e201: BattleUnit = ctrl.context.get_unit(201)
	var u106: BattleUnit = ctrl.context.get_unit(106)
	e201.state.current_hp = 1
	env["map_state"].move_unit(e201, _odd_r(5, 4))
	await _click_axial_opaque(sandbox, u106.hex_position)
	await _click_axial_opaque(sandbox, e201.hex_position)
	await _click_axial_opaque(sandbox, e201.hex_position)

	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.VICTORY), "Immediate VICTORY at Phase 5")
	assert_true(summary.visible, "ResultSummaryModal opens")
	assert_eq(int(ctrl.victory_evaluator.evaluate_stars(ctrl).get("stars", 0)), 3, "3 Stars awarded")


func e2e_t4_02_bach_dang_1288_attrition_victory_and_all_4_defeat_causes() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var summary: Control = require_hud_node(env["sandbox"], ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	# (a) Attrition victory at Round 10 holding signal_dock with >= 75% defeated
	var c_win: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	for eid: int in [202, 203, 204, 205, 206, 207]: # 6/7 = 85.7% >= 75%
		c_win.context.map_state.remove_unit(eid)
	_advance_to_round(c_win, 10)
	c_win.submit_command(BattleCommands.EndTurnCommand.new(1))
	c_win.submit_command(BattleCommands.EndTurnCommand.new(2))
	assert_eq(int(c_win.outcome), int(BattleGameController.BattleOutcome.VICTORY), "Attrition victory at Round 10")

	# (b) LoseKeyArea on live sandbox
	var ctrl: BattleGameController = env["ctrl"]
	ctrl.director.set_area_owner("signal_dock", 2)
	ctrl.submit_command(BattleCommands.WaitCommand.new(1, 101))
	await pump_frames(3)
	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "LoseKeyArea triggers DEFEAT")
	assert_true(summary.visible, "Summary visible for LoseKeyArea")

	# (c) GeneralDefeated, AllUnitsEliminated, and MaxRoundsUnfulfilled
	var c_gen: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	c_gen.context.map_state.remove_unit(101)
	c_gen.submit_command(BattleCommands.WaitCommand.new(1, 102))
	assert_eq(int(c_gen.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "GeneralDefeated triggers DEFEAT")

	var c_all: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	for pid: int in [101, 102, 103, 104, 105]:
		c_all.context.map_state.remove_unit(pid)
	c_all.submit_command(BattleCommands.EndTurnCommand.new(1))
	assert_eq(int(c_all.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "AllUnitsEliminated triggers DEFEAT")

	var c_max: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	_advance_to_round(c_max, 10)
	c_max.submit_command(BattleCommands.EndTurnCommand.new(1))
	c_max.submit_command(BattleCommands.EndTurnCommand.new(2))
	assert_eq(int(c_max.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "MaxRoundsUnfulfilled triggers DEFEAT")


func e2e_t4_03_van_don_supply_cut_starvation_and_recovery() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var stages: Variant = read_json_file("res://data/settings/stage_settings.json")
	if not (stages is Array):
		fail("Missing M5 contract: stage_settings.json")
		return
	var van_don_id: int = -1
	for s_var: Variant in stages as Array:
		if bool((s_var as Dictionary).get("enable_economy", false)):
			van_don_id = int((s_var as Dictionary).get("id", -1))
			break
	if van_don_id <= 0:
		fail("Missing M5 contract: Vân Đồn enable_economy stage")
		return

	var ctrl: BattleGameController = ScenarioLoader.load_stage(van_don_id, e2e_seed)
	assert_not_null(ctrl, "Vân Đồn loads cleanly")
	var eco: Object = ctrl.get("economy") as Object
	assert_not_null(eco, "Vân Đồn initializes economy module")
	if eco == null:
		return
	eco.call("set_resource", 1, "food", -25)
	assert_true(bool(eco.call("is_starving", 1)), "Starvation active at food = -25")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 0.75, 0.001, "0.75x damage under starvation")

	eco.call("set_resource", 1, "coin", 200)
	var trade_cls: Variant = eco_scr.get("TradeCommand")
	if trade_cls != null:
		ctrl.submit_command(trade_cls.new(1, "coin_to_food", 200))
	assert_false(bool(eco.call("is_starving", 1)), "Starvation clears after crisis trade recovery")


func e2e_t4_04_mid_battle_save_resume_determinism_across_tide_fall() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return

	var base_ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	_advance_to_round(base_ctrl, 4)
	save_mgr.call("save_battle_session", base_ctrl)

	var resumed_ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	save_mgr.call("load_battle_session", resumed_ctrl)

	assert_has(resumed_ctrl.event_manager.triggered_event_ids, "evt_10101_tide_fall", "TideFall not duplicated")
	assert_eq(resumed_ctrl.context.rng.get_state(), base_ctrl.context.rng.get_state(), "RNG state identical on resume")

	for c: BattleGameController in [base_ctrl, resumed_ctrl]:
		var e201: BattleUnit = c.context.get_unit(201)
		c.context.map_state.move_unit(e201, _odd_r(5, 5))
		c.submit_command(BattleCommands.AttackCommand.new(1, 102, 201))

	assert_eq(resumed_ctrl.context.get_unit(201).state.current_hp, base_ctrl.context.get_unit(201).state.current_hp, "Bit-identical post-resume combat")


func e2e_t4_05_tier3_profile_corruption_and_bak_disaster_recovery() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	save_mgr.call("save_player_profile", {
		"stage_stars": {"10101": 2},
		"reduce_flashing": true,
		"audio": {"SFX": 0.6},
		"tutorial_flags": {"tip_select_unit": true},
		"codex_unlocked": ["bach_dang_1288"],
	})
	save_mgr.call("save_player_profile", {
		"stage_stars": {"10101": 3},
		"reduce_flashing": true,
		"audio": {"SFX": 0.6},
	})
	var fa: FileAccess = FileAccess.open("user://saves/player_profile.json", FileAccess.WRITE)
	fa.store_string("{TRUNCATED_CORRUPT")
	fa.close()

	var recovered: Dictionary = save_mgr.call("load_player_profile")
	assert_eq(int(recovered.get("stage_stars", {}).get("10101", 0)), 2, "Recovered stars from .bak")
	assert_true(bool(recovered.get("reduce_flashing", false)), "Recovered accessibility flag from .bak")
	assert_true(bool(recovered.get("tutorial_flags", {}).get("tip_select_unit", false)), "Recovered tutorial flags from .bak")


func e2e_t4_06_accessibility_and_low_end_comfort_playthrough() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if juice == null or audio_mgr == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	env["cam"].shake_user_scale = 0.0
	juice.set("reduce_flashing", true)
	juice.call("set_vfx_quality", "Low")
	audio_mgr.call("set_bus_linear_volume", "SFX", 0.4)
	audio_mgr.call("set_bus_linear_volume", "BGM", 0.3)

	var s := Sprite2D.new()
	add_child_autofree(s)
	juice.call("trigger_hit_flash", s, true)
	assert_null(s.material, "Zero hit_flash shader swaps under Reduce Flashing + Low VFX")
	env["cam"].add_trauma(1.0)
	await pump_frames(2)
	assert_eq(env["cam"].offset, Vector2.ZERO, "Zero camera shake offset")

	env["cam"].set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	await pump_frames(1)
	assert_true(env["map_view"].is_strategic_lod(), "StrategicTokenLayer active < 0.65")


func e2e_t4_07_full_tran_dynasty_campaign_progression_and_what_if() -> void:
	clear_user_saves()
	var stages: Variant = read_json_file("res://data/settings/stage_settings.json")
	if not (stages is Array) or (stages as Array).size() < 6:
		fail("Missing M5 contract: 6-stage Trần Dynasty campaign required")
		return
	var save_mgr: Object = require_save_manager("M3")
	var menu_scr: GDScript = require_script(
		["res://scripts/presentation/campaign_menu_controller.gd", "res://scripts/presentation/ui/campaign_menu_controller.gd"],
		"CampaignMenuController",
		"M5",
		"CampaignMenuController"
	)
	if save_mgr == null or menu_scr == null:
		return

	var menu_ctrl: Object = menu_scr.new()
	for s_var: Variant in stages as Array:
		var sid: int = int((s_var as Dictionary).get("id", 0))
		assert_not_null(ScenarioLoader.load_stage(sid, e2e_seed), "Stage %d loads cleanly" % sid)
		save_mgr.call("record_stage_clear", sid, 3)

	var first_id: int = int((stages as Array)[0].get("id", 0))
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_true(bool(menu_ctrl.call("can_customize_general_seats", first_id, true, prof.get("stage_stars", {}))), "Free Replay / What-If unlocked after clear")
	save_mgr.call("record_stage_clear", first_id, 1)
	prof = save_mgr.call("load_player_profile")
	assert_eq(int(prof.get("stage_stars", {}).get(str(first_id), 0)), 3, "3-star best never downgrades on 1-star replay")


func e2e_t4_08_onboarding_contextual_tutorial_and_historical_codex() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var tut: Node = require_hud_node(env["sandbox"], ["TutorialOverlay"], "M5", "TutorialOverlay")
	if tut == null:
		return
	if not FileAccess.file_exists("res://data/settings/codex_entries.json"):
		fail("Missing M5 contract: codex_entries.json")
		return

	assert_true(bool(tut.call("trigger_tip", "tip_select_unit")), "First tip fires")
	tut.call("dismiss_current_tip")
	assert_false(bool(tut.call("trigger_tip", "tip_select_unit")), "Tip never repeats after dismissal")
	var codex_txt: String = read_text_file("res://data/settings/codex_entries.json")
	assert_true(codex_txt.contains("938") and codex_txt.contains("981") and codex_txt.contains("1288"), "Codex separates 938/981/1288")


func e2e_t4_09_economy_escalation_upgrade_fortify_tech_recruit_tactic_ai() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 1000, 1000, 500, 200)
	eco.call("init_faction", 2, 500, 500, 200, 100)
	eco.call("register_facility", "aca_1", 1, "Academy", 1)
	eco.call("register_facility", "fort_1", 1, "Fort", 1)

	var map := BattleMapState.new(8, 8, BattleMapState.TerrainType.PLAINS)
	map.set_terrain(Vector2i(1, 1), BattleMapState.TerrainType.FORT)
	map.set_fort_owner(Vector2i(1, 1), 1)
	var u_enemy := BattleUnit.from_troop_dict(20, 2, Vector2i(6, 6), {"id": 40101})
	map.place_unit(u_enemy)

	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()

	assert_true(ctrl.submit_command(eco_scr.get("UpgradeFacilityCommand").new(1, "fort_1")), "UpgradeFacility 1->2")
	assert_true(ctrl.submit_command(eco_scr.get("FortifyHexCommand").new(1, Vector2i(2, 2))), "FortifyHex")
	assert_true(ctrl.submit_command(eco_scr.get("UnlockBattleTechCommand").new(1, 1, "INFANTRY")), "UnlockBattleTech Tier 1")
	assert_true(ctrl.submit_command(eco_scr.get("RecruitCommand").new(1, 40101, 3, Vector2i(1, 1))), "Recruit 3x stack")
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))

	var ai := AIDecisionMatrix.new(AIDifficultyProfile.create_preset(&"normal"))
	var rep: Dictionary = ai.execute_faction_turn(ctrl, 2, ctrl.director)
	assert_lt(float(rep.get("elapsed_ms", 9999.0)), 3000.0, "Economy AI turn < 3.0s")


func e2e_t4_10_responsive_desktop_16_9_and_mobile_19_5_9_input_journey() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null or require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	for sz: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720)]:
		set_test_viewport_size(sz)
		await pump_frames(2)
		var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(sz))
		assert_gte(float(cov["map_ratio"]), 0.80, "Map >= 80%% at %s" % str(sz))

		var u101: BattleUnit = env["ctrl"].context.get_unit(101)
		await _click_axial_opaque(sandbox, u101.hex_position)
		inject_right_click_screen(Vector2(640, 360), Vector2(15, 0)) # drag > 6px keeps selection
		await pump_frames(2)
		assert_true(env["map_view"].has_selected_hex(), "Drag >6px preserves selection at %s" % str(sz))
		inject_right_click_screen(Vector2(640, 360), Vector2(2, 0)) # click < 6px cancels
		await pump_frames(2)
		assert_false(env["map_view"].has_selected_hex(), "Right-click <6px cancels FSM at %s" % str(sz))


func e2e_t4_11_60fps_high_density_30x30_stress_and_pooling_endurance() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if juice == null or audio_mgr == null:
		return
	env["sandbox"].call("load_stress_benchmark_30x30", 44)
	await pump_frames(3)
	for i: int in range(20):
		juice.call("spawn_particle_preset", "MetalSparksCPU2D", Vector2(i * 20, 100), "Tran_Nguyen")
		audio_mgr.call("play_sfx", "sword_hit", Vector2(i * 20, 100), "Tran_Nguyen")
	env["cam"].set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	var t0: int = Time.get_ticks_usec()
	await pump_frames(25)
	var mean_ms: float = (float(Time.get_ticks_usec() - t0) / 1000.0) / 25.0
	assert_lte(mean_ms, 16.67, "30x30 endurance <= 16.67ms/frame (got %.2f ms)" % mean_ms)


func e2e_t4_12_release_readiness_gate_ip_import_export_regression() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: export_presets.cfg")
		return
	var assets_md: String = read_text_file("res://ASSETS.md")
	for f: String in list_files_recursive("res://assets_clean"):
		if not f.ends_with(".import") and not f.ends_with(".uid"):
			assert_true(assets_md.contains(f), "Asset %s registered in ASSETS.md" % f)
	for f: String in list_files_recursive("res://scripts/core", [".gd"]):
		assert_false(read_text_file(f).contains("SceneTree"), "Core isolation in %s" % f)

	var out_imp: Array = []
	var code_imp: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], out_imp, true)
	assert_eq(code_imp, 0, "godot --headless --import exits 0")

	var out_tst: Array = []
	var code_tst: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_tests.gd"], out_tst, true)
	assert_eq(code_tst, 0, "tests/run_tests.gd exits 0")
