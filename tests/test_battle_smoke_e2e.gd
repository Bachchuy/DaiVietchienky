extends "res://tests/test_case.gd"

const SANDBOX_SCENE_PATH: String = "res://game/battle/battle.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

const HexMathScript = preload("res://sim/rules/hex_math.gd")
const CmdsScript = preload("res://sim/commands/battle_commands.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const ControllerScript = preload("res://sim/state/battle_game_controller.gd")
const SaveMgrScript = preload("res://sim/state/battle_save_manager.gd")


func _spawn_sandbox() -> Node2D:
	var packed: PackedScene = load(SANDBOX_SCENE_PATH) as PackedScene
	assert_not_null(packed, "Sandbox scene loads")
	if packed == null:
		return null
	var inst: Node2D = packed.instantiate() as Node2D
	add_child_autofree(inst)
	return inst


func _find_node_named(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if str(root.name) == target_name:
		return root
	for child: Node in root.get_children():
		var hit: Node = _find_node_named(child, target_name)
		if hit != null:
			return hit
	return null


func _find_btn(root: Node, target_name: String) -> BaseButton:
	var n: Node = _find_node_named(root, target_name)
	return n as BaseButton if n is BaseButton else null


func _push_click_screen(screen_pos: Vector2) -> void:
	var tree: SceneTree = get_scene_tree()
	if tree == null or tree.root == null:
		return
	for pressed_flag: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed_flag
		ev.position = screen_pos
		ev.global_position = screen_pos
		tree.root.push_input(ev)


func _click_hex_real_input(sandbox: Node2D, map_view: BattleMap, axial: Vector2i) -> void:
	var world_pos: Vector2 = map_view.axial_to_world(axial)
	var screen_pos: Vector2 = sandbox.get_canvas_transform() * world_pos
	_push_click_screen(screen_pos)


func _advance_to_round(ctrl: BattleGameController, target_round: int) -> void:
	var guard: int = 0
	while ctrl.current_round < target_round and ctrl.outcome == ControllerScript.BattleOutcome.ONGOING and guard < 40:
		guard += 1
		ctrl.submit_command(CmdsScript.EndTurnCommand.new(ctrl.current_faction_id))


func test_smoke_all_modals_reachable_and_clickable_across_viewports() -> void:
	var tree: SceneTree = get_scene_tree()
	var orig_size: Vector2i = tree.root.size
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	var cam: BattleCameraController = sandbox.call("get_camera") as BattleCameraController
	for vp_i: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720)]:
		tree.root.size = vp_i
		var vp: Vector2 = Vector2(vp_i)
		sandbox.call("load_bach_dang_preview_12x10")
		hud.apply_viewport_layout(vp)
		await tree.process_frame
		await tree.process_frame

		var brief: Control = _find_node_named(hud, "BriefingModal") as Control
		var dlg: Control = _find_node_named(hud, "DialogueModal") as Control
		var pause_m: Control = _find_node_named(hud, "PauseSettingsModal") as Control
		var summary: Control = _find_node_named(hud, "ResultSummaryModal") as Control
		assert_true(brief != null and brief.visible, "BriefingModal opens at start @%s" % str(vp_i))
		assert_button_reachable(_find_btn(brief, "SkipButton"), vp, "Briefing Skip @%s" % str(vp_i))
		var start_btn: BaseButton = _find_btn(brief, "StartButton")
		assert_button_reachable(start_btn, vp, "Briefing Start @%s" % str(vp_i))
		push_click_control(start_btn)
		await tree.process_frame
		assert_false(brief.visible, "StartButton dismisses BriefingModal")
		assert_true(dlg != null and dlg.visible, "StartButton opens opening DialogueModal")

		assert_button_reachable(_find_btn(dlg, "ContinueButton"), vp, "Dialogue Continue @%s" % str(vp_i))
		var skip_dlg: BaseButton = _find_btn(dlg, "SkipDialogueButton")
		assert_button_reachable(skip_dlg, vp, "Dialogue Skip @%s" % str(vp_i))
		push_click_control(skip_dlg)
		await tree.process_frame
		assert_false(dlg.visible, "SkipDialogueButton closes DialogueModal")
		assert_false(cam.camera_locked, "Camera unlocked after dialogue closed")

		var pause_btn: BaseButton = _find_btn(hud, "PauseButton")
		assert_button_reachable(pause_btn, vp, "TopBar PauseButton @%s" % str(vp_i))
		push_click_control(pause_btn)
		await tree.process_frame
		assert_true(pause_m != null and pause_m.visible, "PauseButton opens PauseSettingsModal")
		assert_button_reachable(_find_btn(pause_m, "SaveAndExitButton"), vp, "Pause Save @%s" % str(vp_i))
		assert_button_reachable(_find_btn(pause_m, "RestartButton"), vp, "Pause Restart @%s" % str(vp_i))
		var resume_btn: BaseButton = _find_btn(pause_m, "ResumeButton")
		assert_button_reachable(resume_btn, vp, "Pause Resume @%s" % str(vp_i))
		push_click_control(resume_btn)
		await tree.process_frame
		assert_false(pause_m.visible, "ResumeButton closes PauseSettingsModal")

		for i: int in range(6):
			hud.append_combat_log("Nhật ký chiến đấu #%d" % (i + 1))
		hud.show_result_summary(int(ControllerScript.BattleOutcome.VICTORY))
		await tree.process_frame
		assert_true(summary != null and summary.visible, "ResultSummaryModal opens")
		assert_button_reachable(_find_btn(summary, "ReplayButton"), vp, "Result Replay @%s" % str(vp_i))
		assert_button_reachable(_find_btn(summary, "RetryButton"), vp, "Result Retry @%s" % str(vp_i))
		var close_res: BaseButton = _find_btn(summary, "CloseResultButton")
		assert_button_reachable(close_res, vp, "Result Close @%s" % str(vp_i))
		push_click_control(close_res)
		await tree.process_frame
		assert_false(summary.visible, "CloseResultButton closes ResultSummaryModal")

	tree.root.size = orig_size


func test_smoke_one_tap_attack_and_unit_inspector_no_preview() -> void:
	var tree: SceneTree = get_scene_tree()
	tree.root.size = Vector2i(1280, 720)
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	var ctrl: BattleGameController = sandbox.call("get_controller") as BattleGameController
	var fsm: BattleInputFSM = sandbox.call("get_input_fsm") as BattleInputFSM
	var map_view: BattleMap = sandbox.call("get_map_view") as BattleMap
	var cam: BattleCameraController = sandbox.call("get_camera") as BattleCameraController
	await tree.process_frame

	push_click_control(_find_btn(hud, "SkipButton"))
	await tree.process_frame
	assert_false(hud.is_any_modal_open(), "SkipButton clears intro modals")
	assert_null(_find_node_named(hud, "CombatPreviewBox"), "DEC-026: no CombatPreviewBox in HUD")
	assert_false(BattleInputFSM.State.keys().has("AIMING_TARGET"), "DEC-026: 7-state FSM has no AIMING_TARGET")

	var u101: BattleUnit = ctrl.context.get_unit(101)
	var e202: BattleUnit = ctrl.context.get_unit(202)
	var target_hex: Vector2i = u101.hex_position + Vector2i(1, 0)
	if ctrl.context.map_state.get_unit_at(target_hex) != null:
		ctrl.context.map_state.remove_unit(ctrl.context.map_state.get_unit_at(target_hex).unit_id)
	ctrl.context.map_state.move_unit(e202, target_hex)
	cam.pan_to_world_pos(map_view.axial_to_world(u101.hex_position), true)
	await tree.process_frame

	_click_hex_real_input(sandbox, map_view, u101.hex_position)
	await tree.process_frame
	assert_eq(fsm.get_state(), BattleInputFSM.State.UNIT_SELECTED, "Click unit 101 selects it")
	var inspector: UnitInspector = hud.get_unit_inspector()
	assert_true(inspector.visible, "UnitInspector visible on selection")
	assert_true(inspector.get_global_rect().position.y >= hud.get_top_bar().get_global_rect().end.y, "UnitInspector sits below TopStatusBar")

	var pre_hp: int = e202.state.current_hp
	_click_hex_real_input(sandbox, map_view, e202.hex_position)
	await tree.process_frame
	assert_lt(float(e202.state.current_hp), float(pre_hp), "Single tap on enemy in red range executes attack immediately")
	assert_true(u101.state.has_acted, "Attacker marked has_acted after 1-tap strike")
	assert_eq(fsm.get_state(), BattleInputFSM.State.IDLE, "FSM returns to IDLE after 1-tap attack")


func test_smoke_move_undo_wait_and_skill_flow() -> void:
	var tree: SceneTree = get_scene_tree()
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	var ctrl: BattleGameController = sandbox.call("get_controller") as BattleGameController
	var fsm: BattleInputFSM = sandbox.call("get_input_fsm") as BattleInputFSM
	await tree.process_frame
	hud.skip_intro()

	var u104: BattleUnit = ctrl.context.get_unit(104)
	var orig_hex: Vector2i = u104.hex_position
	fsm.tap_hex(orig_hex)
	assert_eq(fsm.get_state(), BattleInputFSM.State.UNIT_SELECTED)

	var reach: Dictionary[Vector2i, int] = ctrl.context.navigator.get_reachable_hexes(ctrl.context.map_state, u104)
	var dest_hex: Vector2i = orig_hex
	for h: Vector2i in reach.keys():
		if h != orig_hex and ctrl.context.map_state.get_unit_at(h) == null:
			dest_hex = h
			break
	assert_ne(dest_hex, orig_hex, "Unit 104 has reachable destination")
	fsm.tap_hex(dest_hex)
	assert_eq(fsm.get_state(), BattleInputFSM.State.POST_MOVE_ACTION)
	assert_true(fsm.request_undo(), "Undo allowed before acting/FoG/ZoC")
	assert_eq(u104.hex_position, orig_hex, "Undo restores origin hex")
	assert_eq(fsm.get_state(), BattleInputFSM.State.UNIT_SELECTED)

	fsm.tap_hex(dest_hex)
	assert_true(fsm.request_wait(), "Wait transitions POST_MOVE_ACTION -> IDLE")
	assert_true(u104.state.has_acted)
	assert_eq(fsm.get_state(), BattleInputFSM.State.IDLE)

	var u101: BattleUnit = ctrl.context.get_unit(101)
	fsm.tap_hex(u101.hex_position)
	assert_true(fsm.enter_skill_targeting(10001), "General 101 enters SKILL_TARGETING")
	assert_eq(fsm.get_state(), BattleInputFSM.State.SKILL_TARGETING)
	fsm.tap_hex(u101.hex_position)
	assert_gt(float(u101.state.skill_cooldown), 0.0, "Skill cast sets cooldown")
	assert_eq(fsm.get_state(), BattleInputFSM.State.IDLE)


func test_smoke_bach_dang_tide_fall_and_victory_journey() -> void:
	var tree: SceneTree = get_scene_tree()
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	var ctrl: BattleGameController = sandbox.call("get_controller") as BattleGameController
	await tree.process_frame
	hud.skip_intro()

	var stake_hex: Vector2i = ctrl.director.get_area_hexes("area_bai_coc")[0]
	var e202: BattleUnit = ctrl.context.get_unit(202)
	if ctrl.context.map_state.get_unit_at(stake_hex) != null:
		ctrl.context.map_state.remove_unit(ctrl.context.map_state.get_unit_at(stake_hex).unit_id)
	ctrl.context.map_state.move_unit(e202, stake_hex)
	var pre_hp: int = e202.state.current_hp

	_advance_to_round(ctrl, 4)
	await tree.process_frame
	assert_eq(int(ctrl.context.map_state.get_terrain(stake_hex)), int(MapStateScript.TerrainType.STAKED_WATER), "Round 4 TideFall exposes stakes")
	assert_lt(float(e202.state.current_hp), float(pre_hp), "Stake trap damages enemy ship")
	assert_eq(e202.state.march_disabled_turns, 2, "Stake trap pins movement")
	assert_not_null(ctrl.context.get_unit(106), "Ambush reinforcement 106 spawned")
	var dlg: Control = _find_node_named(hud, "DialogueModal") as Control
	assert_true(dlg != null and dlg.visible, "Round 4 TideFall triggers dialogue")
	hud.dismiss_all_modals()

	var o_ma_nhi: BattleUnit = null
	for u: BattleUnit in ctrl.context.map_state.get_all_units():
		if u.general_id == 9001:
			o_ma_nhi = u
			break
	assert_not_null(o_ma_nhi)
	var u101: BattleUnit = ctrl.context.get_unit(101)
	var strike_hex: Vector2i = u101.hex_position + Vector2i(1, 0)
	if ctrl.context.map_state.get_unit_at(strike_hex) != null:
		ctrl.context.map_state.remove_unit(ctrl.context.map_state.get_unit_at(strike_hex).unit_id)
	o_ma_nhi.state.current_hp = 1
	ctrl.context.map_state.move_unit(o_ma_nhi, strike_hex)
	assert_true(ctrl.submit_command(CmdsScript.AttackCommand.new(1, u101.unit_id, o_ma_nhi.unit_id)))
	assert_eq(int(ctrl.outcome), int(ControllerScript.BattleOutcome.VICTORY), "Slaying O Ma Nhi wins immediately")
	var summary: Control = _find_node_named(hud, "ResultSummaryModal") as Control
	assert_true(summary != null and summary.visible, "ResultSummaryModal opens on victory")


func test_smoke_main_menu_and_save_resume_roundtrip() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene", "")), MAIN_MENU_SCENE_PATH, "Project main_scene must launch main_menu.tscn")
	for legacy_path: String in [
		"res://scripts/presentation/battle_map_view.gd",
		"res://scripts/presentation/battle_sandbox_cp1.gd",
		"res://scenes/battle/battle_sandbox_cp1.tscn",
		"res://ui/battle_hud/hud_sandbox_bridge.gd",
	]:
		assert_false(ResourceLoader.exists(legacy_path) or FileAccess.file_exists(legacy_path), "Legacy file removed in R3-T4: " + legacy_path)

	var menu_packed: PackedScene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	assert_not_null(menu_packed, "main_menu.tscn loads")
	if menu_packed != null:
		var menu: Node = menu_packed.instantiate()
		add_child_autofree(menu)
		assert_not_null(menu)

	var test_save_path: String = "user://saves/smoke_test_session.json"
	var sl: GDScript = load("res://sim/state/scenario_loader.gd") as GDScript
	var ctrl: BattleGameController = sl.call("load_stage", 10101, 12880409) as BattleGameController
	_advance_to_round(ctrl, 2)
	var mgr := SaveMgrScript.new()
	assert_true(mgr.save_battle_session(ctrl, test_save_path), "Save session succeeds")

	var loaded: BattleGameController = sl.call("load_stage", 10101, 9999) as BattleGameController
	assert_true(mgr.load_battle_session(loaded, test_save_path), "Load session succeeds")
	assert_eq(loaded.current_round, ctrl.current_round)
	assert_eq(loaded.context.rng.get_state(), ctrl.context.rng.get_state())
	assert_eq(loaded.context.map_state.get_all_units().size(), ctrl.context.map_state.get_all_units().size())
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
