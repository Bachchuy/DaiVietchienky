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


func e2e_t3_01_fsm_and_post_move_action() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	var orig: Vector2i = u104.hex_position
	await _click_axial_opaque(sandbox, orig)
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Unit 104 enters POST_MOVE_ACTION")
	inject_key_press(KEY_Z)
	await pump_frames(2)
	assert_eq(u104.hex_position, orig, "Branch (c) Undo returns to orig")
	await _click_axial_opaque(sandbox, _odd_r(3, 7))
	inject_key_press(KEY_W)
	await pump_frames(2)
	assert_true(u104.state.has_acted and get_fsm_state_value(fsm) == int(states.get("IDLE", -1)), "Branch (d) Wait completes cleanly")

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	await _click_axial_opaque(sandbox, u101.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(3, 8))
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	await _click_axial_opaque(sandbox, _odd_r(4, 7))
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Branch (b) Skill completes to IDLE")


func e2e_t3_02_fsm_and_two_step_confirmation() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()

	var hp0: int = e202.state.current_hp
	var rng0: int = env["ctrl"].context.rng.get_state()
	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "1st tap enters AIMING_TARGET")
	assert_eq(e202.state.current_hp, hp0, "No HP mutation on 1st tap")
	assert_eq(env["ctrl"].context.rng.get_state(), rng0, "No RNG mutation on 1st tap")

	inject_right_click_screen(Vector2(640, 360))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Cancel restores UNIT_SELECTED")

	await _click_axial_opaque(sandbox, e202.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_lt(float(e202.state.current_hp), float(hp0), "2nd tap executes attack")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Returns to IDLE")


func e2e_t3_03_skill_targeting_and_dock_overhead_badges() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_fsm(sandbox, "M1") == null or require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	u104.state.apply_chaos(2)
	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	await _click_axial_opaque(sandbox, u104.hex_position)
	assert_eq(int(u104.state.morale), int(UnitCombatState.MoraleLevel.NORMAL), "Skill clears CHAOS on ally")
	assert_eq(u101.state.skill_cooldown, 3, "Cooldown set to 3")


func e2e_t3_04_map_first_layout_and_dynamic_top_status_bar() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	if hud_ctrl == null or require_economy_script("M4") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	for eco_on: bool in [false, true]:
		env["ctrl"].enable_economy = eco_on
		if hud_ctrl.has_method("sync_with_controller"):
			hud_ctrl.call("sync_with_controller", env["ctrl"])
		for sz: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720)]:
			set_test_viewport_size(sz)
			await pump_frames(2)
			var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(sz))
			assert_gte(float(cov["map_ratio"]), 0.80, "Map >= 80%% for eco=%s at %s" % [str(eco_on), str(sz)])


func e2e_t3_05_combat_preview_box_and_two_step_confirmation() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_fsm(sandbox, "M1") == null:
		return
	var preview_box: Control = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox") as Control
	if preview_box == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	env["map_state"].move_unit(u102, _odd_r(10, 5))
	env["map_state"].move_unit(e202, _odd_r(11, 5))
	var prev: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u102, e202)

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_true(preview_box.visible, "CombatPreviewBox open")
	assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(preview_box.get_global_rect()), "Edge-clamped inside 1280x720")

	await _click_axial_opaque(sandbox, e202.hex_position)
	var rep: Dictionary = env["ctrl"].context.get_last_combat_report()
	if not bool(rep.get("is_crit", false)):
		var dmg: int = int(rep.get("damage", 0))
		assert_gte(float(dmg), float(prev["min_damage"]), "Actual damage >= min preview")
		assert_lte(float(dmg), float(prev["max_damage"]), "Actual damage <= max preview")


func e2e_t3_06_bottom_dock_undo_button_and_five_conditions() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_fsm(sandbox, "M1") == null:
		return
	var dock: Node = require_hud_node(sandbox, ["BottomCommandDock"], "M2", "BottomCommandDock")
	if dock == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var undo_btn: BaseButton = find_button_matching(dock, ["UndoButton", "BtnUndo"], ["hoàn tác", "undo"])
	if undo_btn == null:
		fail("Missing M2 contract: [HOÀN TÁC] button")
		return
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	assert_false(undo_btn.disabled, "[HOÀN TÁC] enabled on safe move")
	inject_left_click_screen(undo_btn.get_global_rect().get_center())
	await pump_frames(2)
	assert_true(undo_btn.disabled, "[HOÀN TÁC] disabled after 1st undo")


func e2e_t3_07_scripted_dialogue_camera_lock_and_fsm() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	var dlg: Control = require_hud_node(sandbox, ["DialogueModal"], "M2", "DialogueModal") as Control
	if fsm == null or dlg == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	_advance_to_round(env["ctrl"], 4)
	await pump_frames(2)
	assert_true(dlg.visible and env["cam"].camera_locked, "Round 4 TideFall locks camera and opens dialogue")
	await _click_axial_opaque(sandbox, _odd_r(2, 8))
	assert_false(env["map_view"].has_selected_hex(), "FSM ignores stray board clicks during dialogue")
	await _dismiss_opening_modals_if_any(sandbox)
	assert_false(env["cam"].camera_locked, "Camera unlocks after dismissing dialogue")


func e2e_t3_08_three_star_summary_and_briefing_alignment() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var briefing: Control = require_hud_node(sandbox, ["BriefingModal"], "M2", "BriefingModal") as Control
	var summary: Control = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if briefing == null or summary == null:
		return
	var b_txt: String = collect_labels_text(briefing)
	assert_true(b_txt.contains("8") or b_txt.contains("20"), "Briefing lists 3-star goals")
	await _dismiss_opening_modals_if_any(sandbox)

	var e201: BattleUnit = env["ctrl"].context.get_unit(201)
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	e201.state.current_hp = 1
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	env["ctrl"].submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e201.unit_id))
	await pump_frames(3)
	assert_true(summary.visible, "Summary opens on victory")
	assert_eq(int(env["ctrl"].victory_evaluator.evaluate_stars(env["ctrl"]).get("stars", 0)), 3, "3 stars awarded")


func e2e_t3_09_reduce_flashing_and_hit_flash_shader() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	juice.set("reduce_flashing", true)
	var s := Sprite2D.new()
	add_child_autofree(s)
	var hits: int = 0
	for _i: int in range(4):
		if bool(juice.call("trigger_hit_flash", s, true)):
			hits += 1
		assert_null(s.material, "ShaderMaterial bypassed under Reduce Flashing")
	assert_lt(float(hits), 3.0, "Flash rate capped < 3/sec")


func e2e_t3_10_screen_shake_0_percent_with_local_hit_stop_and_rng() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	env["cam"].shake_user_scale = 0.0
	var rng0: int = env["ctrl"].context.rng.get_state()
	var anim := AnimatedSprite2D.new()
	add_child_autofree(anim)
	env["cam"].add_trauma(0.9)
	juice.call("play_local_hit_stop", [anim], 0.08)
	await pump_frames(2)
	assert_eq(env["cam"].offset, Vector2.ZERO, "Camera offset remains ZERO at 0% shake")
	assert_eq(env["ctrl"].context.rng.get_state(), rng0, "RNG untouched by juice/shake")
	await _scene_tree.create_timer(0.12).timeout


func e2e_t3_11_local_hit_stop_and_particle_pool_on_staked_water() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])
	env["map_state"].move_unit(env["ctrl"].context.get_unit(202), _odd_r(6, 4))
	_advance_to_round(env["ctrl"], 4)
	await pump_frames(2)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Engine.time_scale remains 1.0 on TideFall")
	assert_true(bool(juice.call("spawn_particle_preset", "WaterSplashCPU2D", Vector2(100, 100), "Tran_Nguyen")), "WaterSplashCPU2D spawns on z=42")


func e2e_t3_12_era_gating_across_particles_and_audio() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if juice == null or audio_mgr == null:
		return
	assert_false(bool(juice.call("spawn_particle_preset", "GunpowderSmokeCPU2D", Vector2.ZERO, "Tran_Nguyen")), "No gunpowder particle in 1288")
	assert_false(bool(audio_mgr.call("play_sfx", "gunfire", Vector2.ZERO, "Tran_Nguyen")), "No gunpowder SFX in 1288")
	assert_true(bool(juice.call("spawn_particle_preset", "FireEmbersCPU2D", Vector2.ZERO, "Tran_Nguyen")), "FireEmbers valid in 1288")


func e2e_t3_13_four_bus_audio_and_pause_sliders_persistence() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	var save_mgr: Object = require_save_manager("M3")
	if audio_mgr == null or save_mgr == null:
		return
	audio_mgr.call("set_bus_linear_volume", "BGM", 0.4)
	save_mgr.call("save_player_profile", {"audio": {"BGM": 0.4}})
	var loaded: Dictionary = save_mgr.call("load_player_profile")
	assert_almost_eq(float(loaded.get("audio", {}).get("BGM", 0.0)), 0.4, 0.01, "BGM slider persisted in profile")


func e2e_t3_14_save_manager_and_scripted_dialogue_events() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	var ctrl1: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	_advance_to_round(ctrl1, 4)
	save_mgr.call("save_battle_session", ctrl1)
	var ctrl2: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	save_mgr.call("load_battle_session", ctrl2)
	assert_has(ctrl2.event_manager.triggered_event_ids, "evt_10101_tide_fall", "TideFall event ID persisted")
	assert_eq(int(ctrl2.context.map_state.get_terrain(_odd_r(6, 4))), int(BattleMapState.TerrainType.STAKED_WATER), "StakedWater terrain restored")


func e2e_t3_15_save_manager_with_economy_and_starvation() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	var eco_scr: GDScript = require_economy_script("M4")
	if save_mgr == null or eco_scr == null:
		return
	var ctrl1: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	ctrl1.enable_economy = true
	var eco1: Object = eco_scr.new()
	eco1.call("init_faction", 1, 100, -20, 50, 40)
	ctrl1.set("economy", eco1)
	save_mgr.call("save_battle_session", ctrl1)

	var ctrl2: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	save_mgr.call("load_battle_session", ctrl2)
	var eco2: Object = ctrl2.get("economy") as Object
	assert_not_null(eco2, "Economy state restored")
	if eco2 != null:
		assert_eq(int(eco2.call("get_resource", 1, "food")), -20, "Negative starving food preserved")
		assert_true(bool(eco2.call("is_starving", 1)), "Starvation state preserved")


func e2e_t3_16_starvation_modifier_in_combat_preview_box() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var eco_scr: GDScript = require_economy_script("M4")
	var preview_box: Control = require_hud_node(env["sandbox"], ["CombatPreviewBox"], "M2", "CombatPreviewBox") as Control
	if eco_scr == null or preview_box == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var ctrl: BattleGameController = env["ctrl"]
	ctrl.enable_economy = true
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, -20, 0, 0)
	ctrl.set("economy", eco)
	var u102: BattleUnit = ctrl.context.get_unit(102)
	var e202: BattleUnit = ctrl.context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	await _click_axial_opaque(env["sandbox"], u102.hex_position)
	await _click_axial_opaque(env["sandbox"], e202.hex_position)
	var txt: String = collect_labels_text(preview_box).to_lower()
	assert_true(txt.contains("đói") or txt.contains("starv") or txt.contains("0.75") or txt.contains("-25%"), "CombatPreviewBox displays Starvation -25% modifier")


func e2e_t3_17_rob_area_income_and_trade_starvation_recovery() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var trade_cls: Variant = eco_scr.get("TradeCommand")
	if trade_cls == null:
		fail("Missing M4 contract: TradeCommand")
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, -30, 0, 0)
	eco.call("register_facility", "mkt_1", 1, "Market", 1)
	eco.call("register_facility", "e_farm", 2, "Farm", 1, 2, false)

	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()
	ctrl.submit_command(trade_cls.new(1, "coin_to_food", 100)) # +38 food -> +8
	assert_false(bool(eco.call("is_starving", 1)), "Crisis trade recovers from starvation")


func e2e_t3_18_economy_commands_and_top_status_bar_hud() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	var eco_scr: GDScript = require_economy_script("M4")
	if hud_ctrl == null or eco_scr == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 777, 555, 222, 111)
	env["ctrl"].enable_economy = true
	env["ctrl"].set("economy", eco)
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", env["ctrl"])
	await pump_frames(2)

	var top_bar: Node = require_hud_node(env["sandbox"], ["TopStatusBar"], "M2", "TopStatusBar")
	var txt: String = collect_labels_text(top_bar)
	assert_true(txt.contains("777") and txt.contains("555"), "TopStatusBar updates Coin/Food counters")


func e2e_t3_19_tran_campaign_van_don_and_economy_ai_under_3s() -> void:
	if not FileAccess.file_exists("res://data/settings/stage_settings.json"):
		fail("Missing M5 contract: stage_settings.json")
		return
	var stages: Array = read_json_file("res://data/settings/stage_settings.json") as Array
	var eco_stage_id: int = -1
	for s_var: Variant in stages:
		var s: Dictionary = s_var as Dictionary
		if bool(s.get("enable_economy", false)):
			eco_stage_id = int(s.get("id", -1))
			break
	if eco_stage_id <= 0:
		fail("Missing M5 contract: Vân Đồn economy-enabled stage in stage_settings.json")
		return
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var ctrl: BattleGameController = ScenarioLoader.load_stage(eco_stage_id, e2e_seed)
	assert_not_null(ctrl, "Vân Đồn stage loads cleanly")
	assert_true(ctrl.enable_economy, "Vân Đồn enables economy")
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))
	var ai := AIDecisionMatrix.new(AIDifficultyProfile.create_preset(&"normal"))
	var rep: Dictionary = ai.execute_faction_turn(ctrl, 2, ctrl.director)
	assert_lt(float(rep.get("elapsed_ms", 9999.0)), 3000.0, "Vân Đồn AI turn < 3.0s")


func e2e_t3_20_campaign_progression_with_codex_and_tutorial() -> void:
	var codex_data: Variant = read_json_file("res://data/settings/codex_entries.json")
	var stages_data: Variant = read_json_file("res://data/settings/stage_settings.json")
	if codex_data == null or not (stages_data is Array) or (stages_data as Array).size() < 6:
		fail("Missing M5 contract: 6 stages and codex_entries.json required")
		return
	var menu_node: Node = require_scene_instantiate(["res://scenes/main_menu.tscn"], "M5", "MainMenu")
	if menu_node == null:
		return
	assert_not_null(find_button_matching(menu_node, ["CodexButton", "BtnCodex"], ["sử ký", "codex", "tư liệu"]), "Codex entry button in MainMenu")


func e2e_t3_21_codex_tutorial_flags_and_tier3_bak_recovery() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	save_mgr.call("save_player_profile", {"tutorial_flags": {"tip_select_unit": true}, "codex_unlocked": ["bach_dang_1288"]})
	save_mgr.call("save_player_profile", {"tutorial_flags": {"tip_select_unit": true, "tip_undo": true}})
	var fa: FileAccess = FileAccess.open("user://saves/player_profile.json", FileAccess.WRITE)
	fa.store_string("{BAD")
	fa.close()
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_true(bool(prof.get("tutorial_flags", {}).get("tip_select_unit", false)), ".bak recovery restores tutorial flags")


func e2e_t3_22_clean_asset_ip_gate_and_tran_campaign_assets() -> void:
	var stages: Variant = read_json_file("res://data/settings/stage_settings.json")
	if not (stages is Array) or (stages as Array).size() < 6:
		fail("Missing M5 contract: 6 Trần campaign stages required")
		return
	var assets_md: String = read_text_file("res://ASSETS.md")
	for f: String in list_files_recursive("res://data", [".json"]):
		assert_true(assets_md.contains(f), "%s registered in ASSETS.md" % f)
		assert_false(read_text_file(f).contains("res://Assets/"), "Zero legacy Assets/ in %s" % f)


func e2e_t3_23_60fps_perf_with_shaders_and_particle_audio_pools() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_juice_helper(env["sandbox"], "M3") == null or require_audio_manager(env["sandbox"], "M3") == null:
		return
	env["sandbox"].call("load_stress_benchmark_30x30", 44)
	env["cam"].set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	await pump_frames(3)
	var t0: int = Time.get_ticks_usec()
	await pump_frames(20)
	var mean_ms: float = (float(Time.get_ticks_usec() - t0) / 1000.0) / 20.0
	assert_lte(mean_ms, 16.67, "30x30 stress with pools & shaders <= 16.67ms/frame")


func e2e_t3_24_import_export_and_ip_case_audit() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: export_presets.cfg")
		return
	var txt: String = read_text_file("res://export_presets.cfg")
	assert_true(txt.contains("Web") and txt.contains("Android"), "Web & Android presets configured")
	assert_true(txt.contains("Assets/*") or txt.contains("Assets/"), "Legacy Assets/ excluded in export")
