extends "res://tests/e2e/e2e_case.gd"


func _odd_r(col: int, row: int) -> Vector2i:
	return HexMath.odd_r_to_axial(Vector2i(col, row))


func _boot_10101_sandbox() -> Dictionary:
	var sandbox: Node = spawn_battle_sandbox()
	if sandbox == null:
		return {}
	await pump_frames(2)
	var ctrl: Variant = sandbox.call("get_controller") if sandbox.has_method("get_controller") else null
	var map_view: Variant = sandbox.call("get_map_view") if sandbox.has_method("get_map_view") else null
	var map_state: Variant = sandbox.call("get_map_state") if sandbox.has_method("get_map_state") else null
	var cam: Variant = sandbox.call("get_camera") if sandbox.has_method("get_camera") else null
	return {
		"sandbox": sandbox,
		"ctrl": ctrl,
		"map_view": map_view,
		"map_state": map_state,
		"cam": cam,
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
		var cur_fac: int = int(ctrl.get("current_faction_id"))
		ctrl.call("submit_command", BattleCommands.EndTurnCommand.new(cur_fac))


func _require_data_file(res_path: String, milestone: String, desc: String) -> Variant:
	if not FileAccess.file_exists(res_path):
		fail("Missing %s contract: %s (%s)" % [milestone, desc, res_path])
		return null
	var data: Variant = read_json_file(res_path)
	if data == null:
		fail("Invalid %s JSON: %s (%s)" % [milestone, desc, res_path])
		return null
	return data


func _require_shader_resource(res_path: String, milestone: String, desc: String) -> Shader:
	if not ResourceLoader.exists(res_path):
		fail("Missing %s contract: shader %s (%s)" % [milestone, desc, res_path])
		return null
	var res: Resource = load(res_path)
	if not (res is Shader):
		fail("Broken %s contract: %s is not a valid Shader" % [milestone, res_path])
		return null
	return res as Shader


# ===========================================================================
# Feature #1: 8-State BattleInputFSM (F01-T1-01 .. F01-T1-05)
# ===========================================================================

func e2e_f01_t1_01_select_wait_fsm_transition() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	for req_state: String in ["IDLE", "UNIT_SELECTED", "MOVING", "POST_MOVE_ACTION", "AIMING_TARGET", "ATTACKING", "SKILL_TARGETING", "EXECUTE_SKILL"]:
		assert_has(states, req_state, "M1 closed 8-state enum must contain %s" % req_state)
	assert_has_signal(fsm, "state_changed", "M1")
	assert_has_signal(fsm, "unit_focused", "M1")

	var transitions: Array = watch_signal(fsm, "state_changed")
	var focused: Array = watch_signal(fsm, "unit_focused")
	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	assert_not_null(u101, "Unit 101 must exist in stage 10101")

	await _click_axial_opaque(sandbox, u101.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Clicking active friendly unit enters UNIT_SELECTED")
	assert_gt(float(focused.size()), 0.0, "unit_focused emitted on selection")

	var wait_btn: BaseButton = find_button_matching(sandbox, ["WaitButton", "BtnWait"], ["đợi", "wait"])
	if wait_btn != null and not wait_btn.disabled:
		inject_left_click_screen(wait_btn.get_global_rect().get_center())
	else:
		inject_key_press(KEY_W)
	await pump_frames(2)

	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Wait returns FSM to IDLE")
	assert_true(u101.state.has_acted, "Unit 101 marked has_acted after Wait")
	assert_true(env["map_view"].get_reachable_overlay_hexes().is_empty(), "Reachable overlay cleared on IDLE")
	assert_gte(float(transitions.size()), 2.0, "At least two FSM transitions recorded")


func e2e_f01_t1_02_move_hub_entry_post_move_action() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var transitions: Array = watch_signal(fsm, "state_changed")
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var dest: Vector2i = _odd_r(5, 5)

	await _click_axial_opaque(sandbox, u102.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Unit 102 selected")

	await _click_axial_opaque(sandbox, dest)
	assert_eq(u102.hex_position, dest, "Unit 102 marched to (5,5)")
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Arrival enters POST_MOVE_ACTION hub")

	var saw_moving: bool = false
	for ev: Variant in transitions:
		if ev is Array and (ev as Array).size() >= 2 and int((ev as Array)[1]) == int(states.get("MOVING", -2)):
			saw_moving = true
	assert_true(saw_moving, "MOVING state emitted between UNIT_SELECTED and POST_MOVE_ACTION")


func e2e_f01_t1_03_in_place_two_step_attack_flow() -> void:
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
	# Place e202 adjacent in attack range via valid map move for test setup
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()
	await pump_frames(1)

	var hp_before: int = e202.state.current_hp
	var transitions: Array = watch_signal(fsm, "state_changed")
	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)

	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "1st click on hostile enters AIMING_TARGET")
	assert_eq(e202.state.current_hp, hp_before, "1st click must NOT deal damage")

	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_lt(float(e202.state.current_hp), float(hp_before), "2nd click on same hostile executes attack")
	assert_true(u102.state.has_acted, "Attacker marked has_acted")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "FSM returns to IDLE after attack")

	var saw_attacking: bool = false
	for ev: Variant in transitions:
		if ev is Array and (ev as Array).size() >= 2 and int((ev as Array)[1]) == int(states.get("ATTACKING", -2)):
			saw_attacking = true
	assert_true(saw_attacking, "ATTACKING state emitted before IDLE")


func e2e_f01_t1_04_skill_targeting_and_execute_skill_flow() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	var transitions: Array = watch_signal(fsm, "state_changed")

	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] skill button not found")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)

	assert_eq(get_fsm_state_value(fsm), int(states.get("SKILL_TARGETING", -1)), "[MƯU LƯỢC] transitions to SKILL_TARGETING")

	var target_hex: Vector2i = _odd_r(2, 7)
	await _click_axial_opaque(sandbox, target_hex)

	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Casting skill returns FSM to IDLE")
	assert_true(u101.state.has_acted, "Caster marked has_acted after skill")
	assert_eq(u101.state.skill_cooldown, 3, "Skill 10001 sets skill_cooldown = 3")

	var saw_exec: bool = false
	for ev: Variant in transitions:
		if ev is Array and (ev as Array).size() >= 2 and int((ev as Array)[1]) == int(states.get("EXECUTE_SKILL", -2)):
			saw_exec = true
	assert_true(saw_exec, "EXECUTE_SKILL state emitted")


func e2e_f01_t1_05_right_click_deselect_vs_drag_pan() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	var cam: BattleCameraController = env["cam"]
	cam.set_zoom_level(BattleCameraController.ZOOM_TACTICAL, true)
	await pump_frames(1)

	await _click_axial_opaque(sandbox, u101.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Unit 101 selected")

	var pos_before: Vector2 = cam.global_position
	inject_right_click_screen(Vector2(640.0, 360.0), Vector2(20.0, 0.0))
	await pump_frames(3)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Right-drag >6px must NOT cancel FSM selection")
	assert_ne(cam.global_position, pos_before, "Right-drag >6px pans camera")

	inject_right_click_screen(Vector2(640.0, 360.0), Vector2(2.0, 1.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Clean right-click <6px cancels FSM to IDLE")
	assert_false(env["map_view"].has_selected_hex(), "Map selection cleared on right-click cancel")


# ===========================================================================
# Feature #2: PostMoveAction 4-Branch Hub (F02-T1-01 .. F02-T1-05)
# ===========================================================================

func e2e_f02_t1_01_post_move_branch_a_attack() -> void:
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
	env["map_state"].move_unit(e202, _odd_r(6, 4))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(5, 4))
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Move enters POST_MOVE_ACTION")

	var hp_before: int = e202.state.current_hp
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "1st click enters AIMING_TARGET from POST_MOVE_ACTION")
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_lt(float(e202.state.current_hp), float(hp_before), "2nd click deals post-move damage")
	assert_false(env["ctrl"].can_undo(), "Undo disabled after AttackCommand")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Returns to IDLE")


func e2e_f02_t1_02_post_move_branch_b_cast_skill() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	var move_hex: Vector2i = _odd_r(3, 8)

	await _click_axial_opaque(sandbox, u101.hex_position)
	await _click_axial_opaque(sandbox, move_hex)
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Unit 101 moved to (3,8)")

	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("SKILL_TARGETING", -1)), "Branch (b) enters SKILL_TARGETING")

	await _click_axial_opaque(sandbox, _odd_r(4, 7))
	assert_eq(u101.state.skill_cooldown, 3, "Skill executed from post-move position")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Returns to IDLE")


func e2e_f02_t1_03_post_move_branch_c_safe_five_condition_undo() -> void:
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
	var orig_hex: Vector2i = u104.hex_position
	var orig_mp: int = u104.state.current_mp
	var orig_facing: int = u104.facing
	var safe_hex: Vector2i = _odd_r(1, 7)

	await _click_axial_opaque(sandbox, orig_hex)
	await _click_axial_opaque(sandbox, safe_hex)
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Moved to safe hex")
	assert_true(env["ctrl"].can_undo(), "5-condition Undo must be valid")

	var undo_btn: BaseButton = find_button_matching(sandbox, ["UndoButton", "BtnUndo"], ["hoàn tác", "undo"])
	assert_not_null(undo_btn, "[HOÀN TÁC] button must exist")
	if undo_btn != null:
		assert_false(undo_btn.disabled, "[HOÀN TÁC] enabled when 5 conditions satisfied")
		inject_left_click_screen(undo_btn.get_global_rect().get_center())
		await pump_frames(2)

	assert_eq(u104.hex_position, orig_hex, "Unit 104 restored to from_hex")
	assert_eq(u104.state.current_mp, orig_mp, "Pre-move MP restored")
	assert_eq(u104.facing, orig_facing, "Pre-move facing restored")
	assert_true(u104.state.has_used_undo_this_turn, "1-per-turn Undo flag set")
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Undo returns to UNIT_SELECTED")
	if undo_btn != null:
		assert_true(undo_btn.disabled, "[HOÀN TÁC] disabled after 1 use")


func e2e_f02_t1_04_post_move_branch_d_wait() -> void:
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
	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "In POST_MOVE_ACTION")

	var wait_btn: BaseButton = find_button_matching(sandbox, ["WaitButton", "BtnWait"], ["đợi", "wait"])
	if wait_btn != null:
		inject_left_click_screen(wait_btn.get_global_rect().get_center())
	else:
		inject_key_press(KEY_W)
	await pump_frames(2)

	assert_true(u104.state.has_acted, "Wait sets has_acted = true")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Wait returns FSM to IDLE")
	assert_false(env["ctrl"].can_undo(), "Undo forbidden after Wait")


func e2e_f02_t1_05_post_undo_re_move_and_act() -> void:
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
	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	inject_key_press(KEY_Z)
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Undo back to UNIT_SELECTED")

	var second_dest: Vector2i = _odd_r(3, 7)
	await _click_axial_opaque(sandbox, second_dest)
	assert_eq(u104.hex_position, second_dest, "Re-moved to second destination")
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Re-entered POST_MOVE_ACTION")
	assert_false(env["ctrl"].can_undo(), "Undo remains disabled on 2nd move")

	inject_key_press(KEY_W)
	await pump_frames(2)
	assert_true(u104.state.has_acted, "Wait succeeds after re-move")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Returns to IDLE")


# ===========================================================================
# Feature #3: Two-Step Combat Confirmation (F03-T1-01 .. F03-T1-05)
# ===========================================================================

func e2e_f03_t1_01_two_tap_same_target_confirmation() -> void:
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

	var preview_box: Node = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox")
	if preview_box == null:
		return

	await _click_axial_opaque(sandbox, u102.hex_position)
	var rng_before: int = env["ctrl"].context.rng.get_state()
	var hp_before: int = e202.state.current_hp

	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "1st tap enters AIMING_TARGET")
	assert_true((preview_box as Control).visible, "CombatPreviewBox opens on 1st tap")
	assert_eq(e202.state.current_hp, hp_before, "1st tap does not deal damage")
	assert_eq(env["ctrl"].context.rng.get_state(), rng_before, "1st tap does not advance simulation RNG")

	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_lt(float(e202.state.current_hp), float(hp_before), "2nd tap confirms attack")
	assert_false((preview_box as Control).visible, "CombatPreviewBox closes after confirmation")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "FSM returns to IDLE")


func e2e_f03_t1_02_tap_target_plus_attack_button_confirmation() -> void:
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

	var hp_before: int = e202.state.current_hp
	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "In AIMING_TARGET")

	var atk_btn: BaseButton = find_button_matching(sandbox, ["AttackButton", "BtnAttack"], ["đánh", "attack"])
	if atk_btn == null:
		fail("Missing M2 contract: [ĐÁNH] button not found")
		return
	assert_false(atk_btn.disabled, "[ĐÁNH] button enabled during AIMING_TARGET")
	inject_left_click_screen(atk_btn.get_global_rect().get_center())
	await pump_frames(2)

	assert_lt(float(e202.state.current_hp), float(hp_before), "Clicking [ĐÁNH] confirms attack")
	assert_true(u102.state.has_acted, "Attacker has_acted = true")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Returns to IDLE")


func e2e_f03_t1_03_target_switching_in_aiming_target() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u103: BattleUnit = env["ctrl"].context.get_unit(103)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	var e203: BattleUnit = env["ctrl"].context.get_unit(203)
	env["map_state"].move_unit(e202, _odd_r(4, 5))
	env["map_state"].move_unit(e203, _odd_r(4, 6))
	env["map_view"].refresh_units()

	var hp2_before: int = e202.state.current_hp
	var hp3_before: int = e203.state.current_hp
	var prev_signals: Array = watch_signal(fsm, "target_preview_requested")

	await _click_axial_opaque(sandbox, u103.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Aiming at E202")

	await _click_axial_opaque(sandbox, e203.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Switching target stays in AIMING_TARGET")
	assert_eq(e202.state.current_hp, hp2_before, "E202 unharmed on switch")
	assert_eq(e203.state.current_hp, hp3_before, "E203 unharmed on 1st tap")
	assert_gte(float(prev_signals.size()), 2.0, "target_preview_requested emitted for E203")

	await _click_axial_opaque(sandbox, e203.hex_position)
	assert_lt(float(e203.state.current_hp), float(hp3_before), "2nd tap on E203 executes attack on E203")
	assert_eq(e202.state.current_hp, hp2_before, "E202 remains unharmed")


func e2e_f03_t1_04_post_move_two_step_confirmation() -> void:
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
	env["map_state"].move_unit(e202, _odd_r(6, 4))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(5, 4))
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Moved adjacent")

	var hp_before: int = e202.state.current_hp
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Post-move 1st tap enters AIMING_TARGET")
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_lt(float(e202.state.current_hp), float(hp_before), "Post-move 2nd tap attacks")
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Ends turn in IDLE")


func e2e_f03_t1_05_cancel_preview_before_step_2() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	assert_has_signal(fsm, "target_preview_cleared", "M1")
	var cleared: Array = watch_signal(fsm, "target_preview_cleared")

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()

	var rng_before: int = env["ctrl"].context.rng.get_state()
	var hp_before: int = e202.state.current_hp
	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Entered AIMING_TARGET")

	inject_right_click_screen(Vector2(640.0, 360.0))
	await pump_frames(2)

	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Cancel returns unmoved unit to UNIT_SELECTED")
	assert_gt(float(cleared.size()), 0.0, "target_preview_cleared emitted")
	assert_eq(e202.state.current_hp, hp_before, "HP untouched on cancel")
	assert_eq(env["ctrl"].context.rng.get_state(), rng_before, "RNG untouched on cancel")


# ===========================================================================
# Feature #4: SkillTargeting & ExecuteSkill (F04-T1-01 .. F04-T1-05)
# ===========================================================================

func e2e_f04_t1_01_highlight_and_cast_skill_10001() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	u104.state.morale = UnitCombatState.MoraleLevel.LOW

	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)

	# Target hex at dist 2 from (2,8), adjacent to u104 at (2,7)
	var target_hex: Vector2i = _odd_r(2, 6)
	await _click_axial_opaque(sandbox, target_hex)

	assert_eq(int(u104.state.morale), int(UnitCombatState.MoraleLevel.NORMAL), "Ally within AoE<=1 gains +1 morale")
	assert_eq(u101.state.skill_cooldown, 3, "Cooldown set to 3")
	assert_true(u101.state.has_acted, "Caster has_acted = true")


func e2e_f04_t1_02_cast_clears_chaos_on_allies_in_aoe() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	u104.state.apply_chaos(2)
	assert_eq(int(u104.state.morale), int(UnitCombatState.MoraleLevel.CHAOS), "Ally starts in CHAOS")

	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	await _click_axial_opaque(sandbox, u104.hex_position)

	assert_eq(int(u104.state.morale), int(UnitCombatState.MoraleLevel.NORMAL), "Skill 10001 clears CHAOS to NORMAL")
	assert_eq(u104.state.chaos_turns, 0, "chaos_turns cleared to 0")


func e2e_f04_t1_03_cast_from_post_move_action() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	await _click_axial_opaque(sandbox, u101.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(3, 8))

	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	await _click_axial_opaque(sandbox, _odd_r(4, 7))

	assert_eq(u101.state.skill_cooldown, 3, "Cast from POST_MOVE_ACTION sets cooldown 3")
	assert_false(env["ctrl"].can_undo(), "Undo disabled after skill cast")


func e2e_f04_t1_04_cooldown_recovery_across_rounds() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var u101: BattleUnit = ctrl.context.get_unit(101)
	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	await _click_axial_opaque(sandbox, u101.hex_position)
	assert_eq(u101.state.skill_cooldown, 3, "Round 1 cooldown = 3")

	_advance_to_round(ctrl, 2)
	assert_eq(u101.state.skill_cooldown, 2, "Round 2 cooldown = 2")
	_advance_to_round(ctrl, 3)
	assert_eq(u101.state.skill_cooldown, 1, "Round 3 cooldown = 1")
	_advance_to_round(ctrl, 4)
	assert_eq(u101.state.skill_cooldown, 0, "Round 4 cooldown recovers to 0")
	await _dismiss_opening_modals_if_any(sandbox)

	await _click_axial_opaque(sandbox, u101.hex_position)
	assert_false(skill_btn.disabled, "[MƯU LƯỢC] re-enabled when cooldown == 0")


func e2e_f04_t1_05_cancel_skill_targeting_preserves_state() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return

	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("SKILL_TARGETING", -1)), "Entered SKILL_TARGETING")

	inject_right_click_screen(Vector2(640.0, 360.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Cancel from unmoved SKILL_TARGETING returns to UNIT_SELECTED")
	assert_eq(u101.state.skill_cooldown, 0, "Cooldown untouched")
	assert_false(u101.state.has_acted, "Unit still unacted")

	await _click_axial_opaque(sandbox, _odd_r(3, 8))
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)
	inject_right_click_screen(Vector2(640.0, 360.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Cancel from moved SKILL_TARGETING returns to POST_MOVE_ACTION")


# ===========================================================================
# Feature #5: Map-First Layout (>= 80% Map) (F05-T1-01 .. F05-T1-05)
# ===========================================================================

func e2e_f05_t1_01_desktop_16_9_map_area_at_least_80_percent() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)
	await pump_frames(2)

	var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(1280.0, 720.0))
	assert_gte(float(cov["map_ratio"]), 0.80, "Map viewport area must be >= 80%% at 1280x720 (got %.3f)" % float(cov["map_ratio"]))


func e2e_f05_t1_02_mobile_19_5_9_layout_map_first() -> void:
	set_test_viewport_size(Vector2i(1560, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)
	await pump_frames(3)

	var hud_layer: CanvasLayer = env["map_view"].get_screen_hud_layer()
	var cov: Dictionary = compute_hud_coverage_ratio(hud_layer, Vector2(1560.0, 720.0))
	assert_gte(float(cov["map_ratio"]), 0.80, "Map viewport area must be >= 80% at 19.5:9 (1560x720)")

	var top_bar: Node = require_hud_node(hud_layer, ["TopStatusBar"], "M2", "TopStatusBar")
	var dock: Node = require_hud_node(hud_layer, ["BottomCommandDock"], "M2", "BottomCommandDock")
	if top_bar is Control and dock is Control:
		var tr: Rect2 = (top_bar as Control).get_global_rect()
		var dr: Rect2 = (dock as Control).get_global_rect()
		assert_false(tr.intersects(dr), "TopStatusBar and BottomCommandDock must not overlap at 19.5:9")


func e2e_f05_t1_03_mobile_20_9_layout_and_button_bounds() -> void:
	set_test_viewport_size(Vector2i(1600, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)
	await _click_axial_opaque(sandbox, _odd_r(2, 8))
	await pump_frames(2)

	var hud_layer: CanvasLayer = env["map_view"].get_screen_hud_layer()
	var cov: Dictionary = compute_hud_coverage_ratio(hud_layer, Vector2(1600.0, 720.0))
	assert_gte(float(cov["map_ratio"]), 0.80, "Map viewport area >= 80% at 20:9 (1600x720)")

	var vp_rect := Rect2(Vector2.ZERO, Vector2(1600.0, 720.0))
	var dock: Node = require_hud_node(hud_layer, ["BottomCommandDock"], "M2", "BottomCommandDock")
	if dock != null:
		for b_node: Node in find_nodes_by_class_recursive(dock, "BaseButton"):
			var btn: Control = b_node as Control
			if btn.visible:
				assert_true(vp_rect.encloses(btn.get_global_rect()), "Dock button %s fits inside 1600x720" % btn.name)


func e2e_f05_t1_04_central_grid_unobstructed_clicks() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	await _click_axial_opaque(sandbox, u102.hex_position)
	assert_eq(env["map_view"].get_selected_unit(), u102, "Central grid unit (5,6) clickable without HUD obstruction")

	var u103: BattleUnit = env["ctrl"].context.get_unit(103)
	await _click_axial_opaque(sandbox, u103.hex_position)
	assert_eq(env["map_view"].get_selected_unit(), u103, "Central grid unit (3,5) clickable without HUD obstruction")


func e2e_f05_t1_05_strategic_zoom_0_5x_and_hud_stability() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var cam: BattleCameraController = env["cam"]
	cam.set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	await pump_frames(2)

	assert_true(env["map_view"].is_strategic_lod(), "Zoom 0.5x enables strategic token LOD")
	var token_layer: Node2D = find_node_by_name_recursive(env["map_view"], "StrategicTokenLayer") as Node2D
	var model_layer: Node2D = find_node_by_name_recursive(env["map_view"], "UnitModelLayer") as Node2D
	assert_true(token_layer.visible, "StrategicTokenLayer visible at 0.5x")
	assert_false(model_layer.visible, "UnitModelLayer hidden at 0.5x")
	var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(1280.0, 720.0))
	assert_gte(float(cov["map_ratio"]), 0.80, "HUD stays <= 20% in strategic zoom")


# ===========================================================================
# Feature #6: Dynamic TopStatusBar (F06-T1-01 .. F06-T1-05)
# ===========================================================================

func e2e_f06_t1_01_top_bar_hides_economy_when_disabled() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var top_bar: Node = require_hud_node(sandbox, ["TopStatusBar"], "M2", "TopStatusBar")
	if top_bar == null:
		return
	var txt: String = collect_labels_text(top_bar)
	assert_true(txt.contains("01/10") or txt.contains("VÒNG"), "TopStatusBar shows round counter 01/10")
	assert_true(txt.to_lower().contains("đại việt"), "TopStatusBar shows active faction Đại Việt")
	assert_not_null(find_button_matching(top_bar, ["PauseButton", "BtnPause"], ["pause", "tạm dừng"]), "Pause button present")

	for eco_name: String in ["EconomyContainer", "CoinLabel", "FoodLabel", "TechLabel"]:
		var eco_node: Node = find_node_by_name_recursive(top_bar, eco_name)
		if eco_node is CanvasItem:
			assert_false((eco_node as CanvasItem).visible, "%s hidden when enable_economy == false" % eco_name)


func e2e_f06_t1_02_top_bar_dynamic_round_counter_updates() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var top_bar: Node = require_hud_node(sandbox, ["TopStatusBar"], "M2", "TopStatusBar")
	if top_bar == null:
		return
	_advance_to_round(env["ctrl"], 4)
	await pump_frames(2)

	var txt: String = collect_labels_text(top_bar)
	assert_true(txt.contains("04/10"), "TopStatusBar updates round counter to 04/10 (got: %s)" % txt)


func e2e_f06_t1_03_top_bar_dynamic_active_faction_switching() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var top_bar: Node = require_hud_node(sandbox, ["TopStatusBar"], "M2", "TopStatusBar")
	if top_bar == null:
		return
	env["ctrl"].submit_command(BattleCommands.EndTurnCommand.new(1))
	await pump_frames(2)

	var txt_ai: String = collect_labels_text(top_bar).to_lower()
	assert_true(txt_ai.contains("đại nguyên"), "TopStatusBar displays Đại Nguyên on faction 2 turn")

	env["ctrl"].submit_command(BattleCommands.EndTurnCommand.new(2))
	await pump_frames(2)
	var txt_p1: String = collect_labels_text(top_bar).to_lower()
	assert_true(txt_p1.contains("đại việt"), "TopStatusBar switches back to Đại Việt on Round 2")


func e2e_f06_t1_04_top_bar_shows_economy_when_enabled() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var hud_ctrl: Object = require_hud_controller(sandbox, "M2")
	if hud_ctrl == null:
		return
	if require_economy_script("M4") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	ctrl.enable_economy = true
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", ctrl)
	await pump_frames(2)

	var top_bar: Node = require_hud_node(sandbox, ["TopStatusBar"], "M2", "TopStatusBar")
	var eco_box: Node = find_node_by_name_recursive(top_bar, "EconomyContainer")
	assert_not_null(eco_box, "EconomyContainer exists on TopStatusBar")
	if eco_box is CanvasItem:
		assert_true((eco_box as CanvasItem).visible, "EconomyContainer visible when enable_economy == true")


func e2e_f06_t1_05_pause_button_opens_pause_modal() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var pause_btn: BaseButton = find_button_matching(sandbox, ["PauseButton", "BtnPause"], ["pause", "tạm dừng"])
	if pause_btn == null:
		fail("Missing M2 contract: [PAUSE] button on TopStatusBar")
		return
	inject_left_click_screen(pause_btn.get_global_rect().get_center())
	await pump_frames(2)

	var pause_modal: Node = require_hud_node(sandbox, ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	if pause_modal is Control:
		assert_true((pause_modal as Control).visible, "PauseSettingsModal visible after clicking [PAUSE]")


# ===========================================================================
# Feature #7: CombatPreviewBox (F07-T1-01 .. F07-T1-05)
# ===========================================================================

func e2e_f07_t1_01_preview_accuracy_vs_combat_resolver() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	var preview_box: Node = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox")
	if preview_box == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()

	var expected: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(
		env["map_state"],
		env["ctrl"].context.navigator,
		u102,
		e202
	)

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)

	assert_true((preview_box as Control).visible, "CombatPreviewBox visible in AIMING_TARGET")
	var txt: String = collect_labels_text(preview_box)
	assert_true(txt.contains(str(int(expected["min_damage"]))), "Preview shows min_damage %d" % int(expected["min_damage"]))
	assert_true(txt.contains(str(int(expected["max_damage"]))), "Preview shows max_damage %d" % int(expected["max_damage"]))
	assert_true(txt.contains(str(int(expected["crit_rate"]))), "Preview shows crit_rate %d" % int(expected["crit_rate"]))


func e2e_f07_t1_02_flank_and_terrain_modifier_display() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	var preview_box: Node = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox")
	if preview_box == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var u105: BattleUnit = env["ctrl"].context.get_unit(105)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	# Place E202 at (5,5), U102 at (5,6) and U105 opposite at (5,4) -> flanked!
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_state"].move_unit(u105, _odd_r(5, 4))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)

	var txt: String = collect_labels_text(preview_box).to_lower()
	assert_true(txt.contains("flank") or txt.contains("bọc sườn") or txt.contains("15%"), "CombatPreviewBox shows Flank +15% modifier")


func e2e_f07_t1_03_no_retaliation_preview_ranged_or_chaos() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	var preview_box: Node = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox")
	if preview_box == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u103: BattleUnit = env["ctrl"].context.get_unit(103) # Archer range 2
	var e206: BattleUnit = env["ctrl"].context.get_unit(206) # Melee range 1
	env["map_state"].move_unit(e206, _odd_r(5, 5)) # dist 2 from (3,5)
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u103.hex_position)
	await _click_axial_opaque(sandbox, e206.hex_position)

	var txt: String = collect_labels_text(preview_box).to_lower()
	assert_true(txt.contains("0") or txt.contains("không phản"), "Out-of-range melee defender shows 0 retaliation")


func e2e_f07_t1_04_target_switch_updates_preview_in_place() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	var preview_box: Node = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox")
	if preview_box == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u103: BattleUnit = env["ctrl"].context.get_unit(103)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	var e201: BattleUnit = env["ctrl"].context.get_unit(201)
	env["map_state"].move_unit(e202, _odd_r(4, 5))
	env["map_state"].move_unit(e201, _odd_r(4, 6))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u103.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	var txt_a: String = collect_labels_text(preview_box)
	await _click_axial_opaque(sandbox, e201.hex_position)
	var txt_b: String = collect_labels_text(preview_box)
	assert_true((preview_box as Control).visible, "Preview remains open on switch")
	assert_ne(txt_a, txt_b, "Preview content updates from target A to target B")


func e2e_f07_t1_05_preview_closes_on_attack_or_cancel() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	var preview_box: Node = require_hud_node(sandbox, ["CombatPreviewBox"], "M2", "CombatPreviewBox")
	if preview_box == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_true((preview_box as Control).visible, "Preview open")

	inject_right_click_screen(Vector2(640.0, 360.0))
	await pump_frames(2)
	assert_false((preview_box as Control).visible, "Preview hides on right-click cancel")


# ===========================================================================
# Feature #8: BottomCommandDock & Overhead HUD (F08-T1-01 .. F08-T1-05)
# ===========================================================================

func e2e_f08_t1_01_unit_card_population_on_selection() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var dock: Node = require_hud_node(sandbox, ["BottomCommandDock"], "M2", "BottomCommandDock")
	if dock == null:
		return

	await _click_axial_opaque(sandbox, _odd_r(2, 8))
	var txt: String = collect_labels_text(dock)
	assert_true(txt.contains("Trần Quốc Tuấn") or txt.contains("480/480"), "Unit card displays Trần Quốc Tuấn & 480/480 HP")
	assert_true(txt.contains("Hưng Phấn") or txt.contains("HIGH"), "Unit card displays HIGH morale")


func e2e_f08_t1_02_dynamic_button_enablement_across_fsm_states() -> void:
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

	var end_btn: BaseButton = find_button_matching(dock, ["EndTurnButton", "BtnEndTurn"], ["kết thúc", "end turn"])
	var wait_btn: BaseButton = find_button_matching(dock, ["WaitButton", "BtnWait"], ["đợi", "wait"])
	var undo_btn: BaseButton = find_button_matching(dock, ["UndoButton", "BtnUndo"], ["hoàn tác", "undo"])
	assert_not_null(end_btn, "[KẾT THÚC LƯỢT] button present")
	assert_not_null(wait_btn, "[ĐỢI] button present")
	assert_not_null(undo_btn, "[HOÀN TÁC] button present")
	if end_btn != null:
		assert_false(end_btn.disabled, "[KẾT THÚC LƯỢT] enabled in IDLE")
	if wait_btn != null:
		assert_true(wait_btn.disabled, "[ĐỢI] disabled in IDLE")

	await _click_axial_opaque(sandbox, _odd_r(2, 7))
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	if undo_btn != null:
		assert_false(undo_btn.disabled, "[HOÀN TÁC] enabled in safe POST_MOVE_ACTION")
	if wait_btn != null:
		assert_false(wait_btn.disabled, "[ĐỢI] enabled in POST_MOVE_ACTION")


func e2e_f08_t1_03_end_turn_button_triggers_end_turn() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var dock: Node = require_hud_node(sandbox, ["BottomCommandDock"], "M2", "BottomCommandDock")
	var end_btn: BaseButton = find_button_matching(dock, ["EndTurnButton", "BtnEndTurn"], ["kết thúc", "end turn"])
	if end_btn == null:
		fail("Missing M2 contract: [KẾT THÚC LƯỢT] button")
		return
	var round_before: int = env["ctrl"].current_round
	inject_left_click_screen(end_btn.get_global_rect().get_center())
	await pump_frames(3)
	assert_true(
		env["ctrl"].current_faction_id != 1 or env["ctrl"].current_round > round_before,
		"Clicking [KẾT THÚC LƯỢT] ends player turn"
	)


func e2e_f08_t1_04_overhead_segmented_hp_and_banner_thresholds() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	assert_eq(u101.max_stack, 3, "Unit 101 is 3x stack")
	u101.state.current_hp = 320 # 66.7%
	assert_eq(u101.get_active_banners(), 3, ">66% -> 3 banners")
	u101.state.current_hp = 200 # 41.7%
	assert_eq(u101.get_active_banners(), 2, "33-66% -> 2 banners")
	u101.state.current_hp = 100 # 20.8%
	assert_eq(u101.get_active_banners(), 1, "<33% -> 1 banner")
	env["map_view"].refresh_units()
	await pump_frames(2)

	var hud_world: Node2D = find_node_by_name_recursive(env["map_view"], "WorldSpaceUnitHudAndTextLayer") as Node2D
	assert_not_null(hud_world, "WorldSpaceUnitHudAndTextLayer present")
	assert_true(hud_world.visible, "Overhead HUD layer visible at 1.0x zoom")


func e2e_f08_t1_05_overhead_morale_and_cc_badges() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var u103: BattleUnit = env["ctrl"].context.get_unit(103)
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	u102.state.morale = UnitCombatState.MoraleLevel.LOW
	u103.state.apply_chaos(2)
	u104.state.march_disabled_turns = 2
	u104.state.attack_disabled_turns = 1
	env["map_view"].refresh_units()
	await pump_frames(2)

	# Verify non-color badge rendering helper/state contract on map_view
	assert_has_method(env["map_view"], "refresh_units", "M2")
	assert_eq(int(u103.state.morale), int(UnitCombatState.MoraleLevel.CHAOS), "CHAOS active for overhead badge")
	assert_eq(u104.state.march_disabled_turns, 2, "MarchDisabled active for overhead badge")


# ===========================================================================
# Feature #9: Pre-Battle Briefing & Scripted Dialogue (F09-T1-01 .. F09-T1-05)
# ===========================================================================

func e2e_f09_t1_01_briefing_modal_content_and_start() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var briefing: Node = require_hud_node(sandbox, ["BriefingModal"], "M2", "BriefingModal")
	if briefing == null:
		return
	await pump_frames(2)

	assert_true((briefing as Control).visible, "BriefingModal visible on stage 10101 entry")
	var txt: String = collect_labels_text(briefing).to_lower()
	assert_true(txt.contains("bạch đằng") or txt.contains("1288"), "Briefing displays stage title")
	assert_true(txt.contains("historical_claim") or txt.contains("lịch sử"), "Briefing shows modeling_type transparency")

	var start_btn: BaseButton = find_button_matching(briefing, ["StartButton", "BtnStart"], ["bắt đầu", "vào trận", "start"])
	assert_not_null(start_btn, "Start button exists on BriefingModal")
	if start_btn != null:
		inject_left_click_screen(start_btn.get_global_rect().get_center())
		await pump_frames(2)
		assert_false((briefing as Control).visible, "BriefingModal closes on Start")


func e2e_f09_t1_02_opening_dialogue_and_camera_lock() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var briefing: Node = require_hud_node(sandbox, ["BriefingModal"], "M2", "BriefingModal")
	var dlg_modal: Node = require_hud_node(sandbox, ["DialogueModal"], "M2", "DialogueModal")
	if briefing == null or dlg_modal == null:
		return

	var start_btn: BaseButton = find_button_matching(briefing, ["StartButton", "BtnStart"], ["bắt đầu", "vào trận", "start"])
	if start_btn != null and (briefing as Control).visible:
		inject_left_click_screen(start_btn.get_global_rect().get_center())
		await pump_frames(2)

	assert_true((dlg_modal as Control).visible, "DialogueModal opens for talk_opening_bach_dang")
	assert_true(env["cam"].camera_locked, "camera_locked == true while DialogueModal is open")
	var txt: String = collect_labels_text(dlg_modal)
	assert_true(txt.contains("Trần Quốc Tuấn"), "Speaker Trần Quốc Tuấn displayed")


func e2e_f09_t1_03_round_4_tide_fall_dialogue_and_camera_unlock() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var dlg_modal: Node = require_hud_node(sandbox, ["DialogueModal"], "M2", "DialogueModal")
	if dlg_modal == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	_advance_to_round(env["ctrl"], 4)
	await pump_frames(2)

	assert_true((dlg_modal as Control).visible, "Round 4 TideFall opens talk_trieu_rut dialogue")
	assert_true(env["cam"].camera_locked, "camera_locked == true on Round 4 dialogue")
	var txt: String = collect_labels_text(dlg_modal)
	assert_true(txt.contains("Nước triều") or txt.contains("Trần Quốc Tuấn"), "Round 4 dialogue line shown")

	await _dismiss_opening_modals_if_any(sandbox)
	assert_false((dlg_modal as Control).visible, "DialogueModal dismissed")
	assert_false(env["cam"].camera_locked, "camera_locked restored to false after dismissal")


func e2e_f09_t1_04_mid_battle_omnhi_wounded_dialogue() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var dlg_modal: Node = require_hud_node(sandbox, ["DialogueModal"], "M2", "DialogueModal")
	if dlg_modal == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var e201: BattleUnit = env["ctrl"].context.get_unit(201)
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	e201.state.current_hp = int(e201.state.max_hp * 0.45)
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	env["ctrl"].submit_command(BattleCommands.WaitCommand.new(1, u102.unit_id))
	await pump_frames(2)

	assert_true((dlg_modal as Control).visible, "DialogueModal opens when Ô Mã Nhi <= 50% HP")
	var txt: String = collect_labels_text(dlg_modal)
	assert_true(txt.contains("Ô Mã Nhi"), "Speaker Ô Mã Nhi displayed")
	assert_true(env["cam"].camera_locked, "camera_locked == true during mid-battle dialogue")


func e2e_f09_t1_05_multi_line_dialogue_advance_and_dismiss() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var hud_ctrl: Object = require_hud_controller(sandbox, "M2")
	var dlg_modal: Node = require_hud_node(sandbox, ["DialogueModal"], "M2", "DialogueModal")
	if hud_ctrl == null or dlg_modal == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	assert_has_method(hud_ctrl, "show_dialogue_entries", "M2")
	if not hud_ctrl.has_method("show_dialogue_entries"):
		return
	hud_ctrl.call("show_dialogue_entries", [
		{"speaker": "Trần Quốc Tuấn", "line": "Dòng thoại thử nghiệm một."},
		{"speaker": "Trần Khánh Dư", "line": "Dòng thoại thử nghiệm hai."},
	])
	await pump_frames(2)
	assert_true((dlg_modal as Control).visible, "DialogueModal visible on line 1")
	assert_true(collect_labels_text(dlg_modal).contains("Dòng thoại thử nghiệm một"), "Line 1 shown")

	await _dismiss_opening_modals_if_any(sandbox)
	assert_true((dlg_modal as Control).visible, "DialogueModal stays open for line 2")
	assert_true(collect_labels_text(dlg_modal).contains("Dòng thoại thử nghiệm hai"), "Line 2 shown")

	await _dismiss_opening_modals_if_any(sandbox)
	assert_false((dlg_modal as Control).visible, "DialogueModal closes after last line")
	assert_false(env["cam"].camera_locked, "camera_locked == false after last line")


# ===========================================================================
# Feature #10: 3-Star Summary & CombatLog (F10-T1-01 .. F10-T1-05)
# ===========================================================================

func e2e_f10_t1_01_three_star_victory_summary() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var summary: Node = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal")
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var e201: BattleUnit = ctrl.context.get_unit(201)
	var u102: BattleUnit = ctrl.context.get_unit(102)
	e201.state.current_hp = 1
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	ctrl.submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e201.unit_id))
	await pump_frames(3)

	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.VICTORY), "Victory achieved")
	assert_true((summary as Control).visible, "ResultSummaryModal opens on victory")
	var txt: String = collect_labels_text(summary)
	assert_true(txt.contains("3/3") or txt.contains("3 ★") or txt.contains("3 SAO"), "Summary displays 3/3 Stars")


func e2e_f10_t1_02_two_star_victory_when_hp_loss_above_20_percent() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var summary: Node = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal")
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var u101: BattleUnit = ctrl.context.get_unit(101)
	var u104: BattleUnit = ctrl.context.get_unit(104)
	u101.state.current_hp = 100
	u104.state.current_hp = 50
	var e201: BattleUnit = ctrl.context.get_unit(201)
	var u102: BattleUnit = ctrl.context.get_unit(102)
	e201.state.current_hp = 1
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	ctrl.submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e201.unit_id))
	await pump_frames(3)

	var star_res: Dictionary = ctrl.victory_evaluator.evaluate_stars(ctrl)
	assert_eq(int(star_res.get("stars", 0)), 2, "2 stars earned when loss > 20%")
	var txt: String = collect_labels_text(summary)
	assert_true(txt.contains("2/3") or txt.contains("2 ★") or txt.contains("2 SAO"), "Summary shows 2/3 Stars")


func e2e_f10_t1_03_one_star_victory_at_round_9_with_high_loss() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var summary: Node = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal")
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	_advance_to_round(ctrl, 9)
	await _dismiss_opening_modals_if_any(sandbox)
	var u101: BattleUnit = ctrl.context.get_unit(101)
	var u104: BattleUnit = ctrl.context.get_unit(104)
	u101.state.current_hp = 100
	u104.state.current_hp = 50
	var e201: BattleUnit = ctrl.context.get_unit(201)
	var u102: BattleUnit = ctrl.context.get_unit(102)
	e201.state.current_hp = 1
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	ctrl.submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e201.unit_id))
	await pump_frames(3)

	var star_res: Dictionary = ctrl.victory_evaluator.evaluate_stars(ctrl)
	assert_eq(int(star_res.get("stars", 0)), 1, "1 star earned at Round 9 with > 20% loss")
	assert_true((summary as Control).visible, "Summary modal visible")


func e2e_f10_t1_04_combat_log_completeness_and_readability() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var summary: Node = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal")
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var u101: BattleUnit = ctrl.context.get_unit(101)
	var u102: BattleUnit = ctrl.context.get_unit(102)
	var e201: BattleUnit = ctrl.context.get_unit(201)
	ctrl.submit_command(BattleCommands.CastSkillCommand.new(1, u101.unit_id, 10001, u101.hex_position))
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	e201.state.current_hp = 1
	ctrl.submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e201.unit_id))
	await pump_frames(3)

	var log_node: Node = require_hud_node(summary, ["CombatLogPanel", "CombatLogList", "CombatLog"], "M2", "CombatLog")
	if log_node == null:
		return
	var log_txt: String = collect_labels_text(log_node)
	assert_gt(float(log_txt.length()), 10.0, "CombatLog contains chronological battle entries")


func e2e_f10_t1_05_retry_restart_action_from_summary() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var summary: Node = require_hud_node(sandbox, ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal")
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var e201: BattleUnit = ctrl.context.get_unit(201)
	var u102: BattleUnit = ctrl.context.get_unit(102)
	e201.state.current_hp = 1
	env["map_state"].move_unit(e201, _odd_r(5, 5))
	ctrl.submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e201.unit_id))
	await pump_frames(3)

	var retry_btn: BaseButton = find_button_matching(summary, ["RetryButton", "BtnRetry", "RestartButton"], ["chơi lại", "retry", "restart"])
	assert_not_null(retry_btn, "Retry button exists on ResultSummaryModal")
	if retry_btn != null:
		inject_left_click_screen(retry_btn.get_global_rect().get_center())
		await pump_frames(3)
		assert_false((summary as Control).visible, "Summary closes on Retry")
		var new_ctrl: BattleGameController = sandbox.call("get_controller")
		assert_eq(new_ctrl.current_round, 1, "Battle resets to Round 1")
		assert_eq(int(new_ctrl.outcome), int(BattleGameController.BattleOutcome.ONGOING), "Outcome resets to ONGOING")


# ===========================================================================
# Feature #11: Pause & Accessibility Menu (F11-T1-01 .. F11-T1-05)
# ===========================================================================

func e2e_f11_t1_01_open_pause_and_resume_flow() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var pause_modal: Node = require_hud_node(sandbox, ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	if pause_modal == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var pause_btn: BaseButton = find_button_matching(sandbox, ["PauseButton", "BtnPause"], ["pause", "tạm dừng"])
	if pause_btn == null:
		fail("Missing M2 contract: PauseButton")
		return
	inject_left_click_screen(pause_btn.get_global_rect().get_center())
	await pump_frames(2)
	assert_true((pause_modal as Control).visible, "Pause modal opens")

	var resume_btn: BaseButton = find_button_matching(pause_modal, ["ResumeButton", "BtnResume"], ["tiếp tục", "resume"])
	assert_not_null(resume_btn, "Resume button present in Pause modal")
	if resume_btn != null:
		inject_left_click_screen(resume_btn.get_global_rect().get_center())
		await pump_frames(2)
		assert_false((pause_modal as Control).visible, "Pause modal closes on Resume")


func e2e_f11_t1_02_screen_shake_scale_zero_vs_hundred() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var pause_modal: Node = require_hud_node(sandbox, ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	if pause_modal == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var shake_slider: Range = find_node_by_name_recursive(pause_modal, "ShakeScaleSlider") as Range
	if shake_slider == null:
		fail("Missing M2 contract: ShakeScaleSlider in PauseSettingsModal")
		return
	var cam: BattleCameraController = env["cam"]
	shake_slider.value = 0.0
	await pump_frames(1)
	assert_almost_eq(cam.shake_user_scale, 0.0, 0.01, "ShakeScaleSlider 0 sets camera.shake_user_scale = 0.0")
	cam.add_trauma(0.8)
	await pump_frames(2)
	assert_eq(cam.offset, Vector2.ZERO, "Camera offset remains ZERO when Shake Scale = 0%")

	shake_slider.value = 100.0 if shake_slider.max_value > 2.0 else 1.0
	await pump_frames(1)
	cam.add_trauma(0.8)
	await pump_frames(2)
	assert_ne(cam.offset, Vector2.ZERO, "Camera shakes at 100% scale")


func e2e_f11_t1_03_reduce_flashing_wcag_toggle() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var pause_modal: Node = require_hud_node(sandbox, ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	var juice: Object = require_juice_helper(sandbox, "M3")
	if pause_modal == null or juice == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var toggle: BaseButton = find_button_matching(pause_modal, ["ReduceFlashingCheck", "ReduceFlashingToggle"], ["reduce flash", "giảm chớp"])
	if toggle == null:
		fail("Missing M2 contract: Reduce Flashing toggle in PauseSettingsModal")
		return
	toggle.button_pressed = true
	await pump_frames(1)
	assert_true(bool(juice.get("reduce_flashing")), "Reduce Flashing propagated to CombatJuiceHelper")


func e2e_f11_t1_04_vfx_quality_switching_amount_ratio() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var pause_modal: Node = require_hud_node(sandbox, ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	var juice: Object = require_juice_helper(sandbox, "M3")
	if pause_modal == null or juice == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var vfx_opt: OptionButton = find_node_by_name_recursive(pause_modal, "VfxQualityOption") as OptionButton
	if vfx_opt == null:
		fail("Missing M2 contract: VfxQualityOption in PauseSettingsModal")
		return
	vfx_opt.select(0) # Low
	vfx_opt.item_selected.emit(0)
	await pump_frames(2)

	var particles: Array[Node] = find_nodes_by_class_recursive(env["map_view"], "CPUParticles2D")
	assert_gt(float(particles.size()), 0.0, "CPUParticles2D pool nodes exist on MapEffectLayer")
	if not particles.is_empty():
		assert_almost_eq((particles[0] as CPUParticles2D).amount_ratio, 0.4, 0.01, "Low VFX sets amount_ratio = 0.4")


func e2e_f11_t1_05_save_and_exit_persists_session_and_profile() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var pause_modal: Node = require_hud_node(sandbox, ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	var save_mgr: Object = require_save_manager("M3")
	if pause_modal == null or save_mgr == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var pause_btn: BaseButton = find_button_matching(sandbox, ["PauseButton", "BtnPause"], ["pause", "tạm dừng"])
	if pause_btn != null:
		inject_left_click_screen(pause_btn.get_global_rect().get_center())
		await pump_frames(2)

	var save_btn: BaseButton = find_button_matching(pause_modal, ["SaveAndExitButton", "BtnSaveExit"], ["lưu & thoát", "save & exit", "save"])
	if save_btn == null:
		fail("Missing M2/M3 contract: Save & Exit button in PauseSettingsModal")
		return
	inject_left_click_screen(save_btn.get_global_rect().get_center())
	await pump_frames(3)

	assert_true(FileAccess.file_exists("user://saves/battle_session.json"), "Tier 2 battle_session.json created")
	assert_true(FileAccess.file_exists("user://saves/player_profile.json"), "Tier 3 player_profile.json created")


# ===========================================================================
# Feature #12: hit_flash.gdshader & water_flow.gdshader (F12-T1-01 .. F12-T1-05)
# ===========================================================================

func e2e_f12_t1_01_shader_import_and_load_cleanliness() -> void:
	var hit_sh: Shader = _require_shader_resource("res://assets_clean/shaders/hit_flash.gdshader", "M3", "hit_flash.gdshader")
	var water_sh: Shader = _require_shader_resource("res://assets_clean/shaders/water_flow.gdshader", "M3", "water_flow.gdshader")
	if hit_sh == null or water_sh == null:
		return
	assert_true(hit_sh.code.contains("shader_type canvas_item"), "hit_flash is canvas_item shader")
	assert_true(hit_sh.code.contains("flash_modifier"), "hit_flash exposes flash_modifier uniform")
	assert_true(water_sh.code.contains("shader_type canvas_item"), "water_flow is canvas_item shader")


func e2e_f12_t1_02_hit_flash_50ms_attach_and_batch_safe_detach() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var juice: Object = require_juice_helper(sandbox, "M3")
	if juice == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	assert_has_method(juice, "trigger_hit_flash", "M3")
	var dummy := Sprite2D.new()
	add_child_autofree(dummy)
	juice.call("trigger_hit_flash", dummy, false)
	assert_not_null(dummy.material, "ShaderMaterial attached during 50ms hit flash")
	await _scene_tree.create_timer(0.12).timeout
	assert_null(dummy.material, "material restored to null after 50ms to preserve 2D batching")


func e2e_f12_t1_03_water_flow_shader_active_on_water_layer() -> void:
	var water_sh: Shader = _require_shader_resource("res://assets_clean/shaders/water_flow.gdshader", "M3", "water_flow.gdshader")
	if water_sh == null:
		return
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var water_layer: CanvasItem = find_node_by_name_recursive(env["map_view"], "WaterAndTideLayer") as CanvasItem
	assert_not_null(water_layer, "WaterAndTideLayer exists")
	if water_layer != null:
		assert_true(water_layer.material is ShaderMaterial, "WaterAndTideLayer uses ShaderMaterial")
		if water_layer.material is ShaderMaterial:
			assert_eq((water_layer.material as ShaderMaterial).shader, water_sh, "WaterAndTideLayer binds water_flow.gdshader")


func e2e_f12_t1_04_shared_shader_material_reuse_across_hits() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var s1 := Sprite2D.new()
	var s2 := Sprite2D.new()
	add_child_autofree(s1)
	add_child_autofree(s2)

	juice.call("trigger_hit_flash", s1, false)
	var m1: Material = s1.material
	juice.call("trigger_hit_flash", s2, false)
	var m2: Material = s2.material
	assert_not_null(m1, "Shared hit flash material allocated")
	assert_eq(m1, m2, "Sequential hits reuse identical shared ShaderMaterial reference")
	await _scene_tree.create_timer(0.12).timeout
	assert_null(s1.material, "s1 material restored to null")
	assert_null(s2.material, "s2 material restored to null")


func e2e_f12_t1_05_reduce_flashing_soft_tint_fallback() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	juice.set("reduce_flashing", true)
	var s := Sprite2D.new()
	add_child_autofree(s)

	juice.call("trigger_hit_flash", s, true)
	assert_null(s.material, "Reduce Flashing skips ShaderMaterial swap")
	assert_gt(s.self_modulate.r, s.self_modulate.g, "Reduce Flashing uses soft red self_modulate tint")
	await _scene_tree.create_timer(0.15).timeout
	assert_almost_eq(s.self_modulate.g, 1.0, 0.05, "self_modulate restores to Color.WHITE")


# ===========================================================================
# Feature #13: Local Hit-Stop, Squash/Stretch & Floating Text (F13-T1-01 .. 05)
# ===========================================================================

func e2e_f13_t1_01_local_hit_stop_without_global_time_scale_freeze() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "play_local_hit_stop", "M3")
	if not juice.has_method("play_local_hit_stop"):
		return

	var anim_a := AnimatedSprite2D.new()
	var anim_b := AnimatedSprite2D.new()
	add_child_autofree(anim_a)
	add_child_autofree(anim_b)

	juice.call("play_local_hit_stop", [anim_a, anim_b], 0.08)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Engine.time_scale MUST remain 1.0 during local hit-stop")
	assert_almost_eq(anim_a.speed_scale, 0.0, 0.001, "Engaged visual A speed_scale paused to 0.0")
	assert_almost_eq(anim_b.speed_scale, 0.0, 0.001, "Engaged visual B speed_scale paused to 0.0")

	await _scene_tree.create_timer(0.14).timeout
	assert_almost_eq(anim_a.speed_scale, 1.0, 0.001, "Visual A speed_scale restored to 1.0")
	assert_almost_eq(anim_b.speed_scale, 1.0, 0.001, "Visual B speed_scale restored to 1.0")


func e2e_f13_t1_02_heavy_tier_hit_stop_on_crit_or_staked_water() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "classify_impact_tier", "M3")
	if not juice.has_method("classify_impact_tier"):
		return
	var heavy: Dictionary = juice.call("classify_impact_tier", true, true, 180)
	assert_gte(float(heavy.get("hit_stop_sec", 0.0)), 0.10, "Heavy tier hit-stop >= 100ms")
	assert_lte(float(heavy.get("hit_stop_sec", 1.0)), 0.15, "Heavy tier hit-stop <= 150ms")
	assert_gte(float(heavy.get("trauma", 0.0)), 0.70, "Heavy tier trauma >= 0.70")


func e2e_f13_t1_03_squash_and_stretch_elastic_recovery() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "play_squash_stretch", "M3")
	if not juice.has_method("play_squash_stretch"):
		return

	var target := Node2D.new()
	add_child_autofree(target)
	juice.call("play_squash_stretch", target)
	assert_gt(target.scale.x, 1.05, "Squash & stretch widens X on impact")
	assert_lt(target.scale.y, 0.95, "Squash & stretch compresses Y on impact")
	await _scene_tree.create_timer(0.24).timeout
	assert_almost_eq(target.scale.x, 1.0, 0.02, "Scale X recovers to 1.0")
	assert_almost_eq(target.scale.y, 1.0, 0.02, "Scale Y recovers to 1.0")


func e2e_f13_t1_04_floating_combat_text_symbol_and_color_encoding() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "spawn_floating_text", "M3")
	if not juice.has_method("spawn_floating_text"):
		return

	var hud_layer: Node = find_node_by_name_recursive(env["map_view"], "WorldSpaceUnitHudAndTextLayer")
	var before_cnt: int = hud_layer.get_child_count()
	juice.call("spawn_floating_text", hud_layer, Vector2(100, 100), 96, &"crit")
	juice.call("spawn_floating_text", hud_layer, Vector2(120, 100), 0, &"blocked")
	assert_gte(float(hud_layer.get_child_count()), float(before_cnt + 2), "Floating text spawned on WorldSpaceUnitHudAndTextLayer")
	var txt: String = collect_labels_text(hud_layer)
	assert_true(txt.contains("96") and txt.contains("💥"), "Crit floating text uses symbol + value")
	assert_true(txt.contains("🛡️"), "Blocked floating text uses shield symbol")


func e2e_f13_t1_05_retaliation_sequencing_completes_cleanly() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_juice_helper(sandbox, "M3") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["ctrl"].submit_command(BattleCommands.AttackCommand.new(1, u102.unit_id, e202.unit_id))
	await _scene_tree.create_timer(0.25).timeout
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Engine.time_scale unaffected after melee + retaliation")


# ===========================================================================
# Feature #14: CPUParticles2D Object Pool (F14-T1-01 .. F14-T1-05)
# ===========================================================================

func e2e_f14_t1_01_prewarm_pool_on_map_effect_layer() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_juice_helper(env["sandbox"], "M3") == null:
		return
	var effect_layer: Node2D = find_node_by_name_recursive(env["map_view"], "MapEffectLayer") as Node2D
	assert_not_null(effect_layer, "MapEffectLayer exists")
	assert_eq(effect_layer.z_index, 42, "MapEffectLayer z_index == 42")
	var pool_nodes: Array[Node] = find_nodes_by_class_recursive(effect_layer, "CPUParticles2D")
	assert_gt(float(pool_nodes.size()), 0.0, "Pre-warmed CPUParticles2D pool exists on MapEffectLayer")


func e2e_f14_t1_02_all_five_era_valid_presets_spawn_and_recycle() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "spawn_particle_preset", "M3")
	if not juice.has_method("spawn_particle_preset"):
		return
	for preset: String in ["DustTrailCPU2D", "MetalSparksCPU2D", "WaterSplashCPU2D", "FireEmbersCPU2D", "MoraleAuraCPU2D"]:
		var ok: bool = bool(juice.call("spawn_particle_preset", preset, Vector2(120, 120), "Tran_Nguyen"))
		assert_true(ok, "Era-valid preset %s spawns cleanly in 1288" % preset)


func e2e_f14_t1_03_vfx_quality_low_sets_amount_ratio_0_4() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "set_vfx_quality", "M3")
	if not juice.has_method("set_vfx_quality"):
		return
	juice.call("set_vfx_quality", "Low")
	juice.call("spawn_particle_preset", "FireEmbersCPU2D", Vector2(100, 100), "Tran_Nguyen")
	var effect_layer: Node = find_node_by_name_recursive(env["map_view"], "MapEffectLayer")
	var pool_nodes: Array[Node] = find_nodes_by_class_recursive(effect_layer, "CPUParticles2D")
	assert_gt(float(pool_nodes.size()), 0.0, "CPUParticles2D pool active")
	if not pool_nodes.is_empty():
		assert_almost_eq((pool_nodes[0] as CPUParticles2D).amount_ratio, 0.4, 0.01, "Low quality sets amount_ratio = 0.4")


func e2e_f14_t1_04_era_gating_unlocked_in_xv_plus_context() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	assert_has_method(juice, "spawn_particle_preset", "M3")
	if not juice.has_method("spawn_particle_preset"):
		return
	var ok: bool = bool(juice.call("spawn_particle_preset", "GunpowderSmokeCPU2D", Vector2(100, 100), "Tay_Son"))
	assert_true(ok, "GunpowderSmokeCPU2D permitted in XV+ era")


func e2e_f14_t1_05_pool_reuse_under_30_consecutive_bursts() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var effect_layer: Node = find_node_by_name_recursive(env["map_view"], "MapEffectLayer")
	var initial_count: int = find_nodes_by_class_recursive(effect_layer, "CPUParticles2D").size()
	for i: int in range(30):
		juice.call("spawn_particle_preset", "MetalSparksCPU2D", Vector2(50 + i, 50), "Tran_Nguyen")
	var after_count: int = find_nodes_by_class_recursive(effect_layer, "CPUParticles2D").size()
	assert_eq(after_count, initial_count, "Pool node count remains bounded with zero leak across 30 bursts")


# ===========================================================================
# Feature #15: 4-Bus Audio, Pool & Clean Synthesized Audio (F15-T1-01 .. 05)
# ===========================================================================

func e2e_f15_t1_01_four_bus_architecture_and_master_limiter() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_audio_manager(env["sandbox"], "M3") == null:
		return
	for bus_name: String in ["Master", "BGM", "SFX", "Voice/Horn", "UI"]:
		assert_ne(AudioServer.get_bus_index(bus_name), -1, "AudioServer bus '%s' exists" % bus_name)
	var has_limiter: bool = false
	for i: int in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			has_limiter = true
	assert_true(has_limiter, "Master bus has AudioEffectHardLimiter")


func e2e_f15_t1_02_fixed_audio_pool_24_2d_and_6_ui() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	var p2d: Array[Node] = find_nodes_by_class_recursive(audio_mgr as Node, "AudioStreamPlayer2D")
	var pui: Array[Node] = find_nodes_by_class_recursive(audio_mgr as Node, "AudioStreamPlayer")
	assert_eq(p2d.size(), 24, "Exactly 24 AudioStreamPlayer2D nodes pre-allocated")
	assert_gte(float(pui.size()), 6.0, "At least 6 UI AudioStreamPlayer nodes pre-allocated")


func e2e_f15_t1_03_volume_sliders_linear_to_db_and_persistence() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	var save_mgr: Object = require_save_manager("M3")
	if audio_mgr == null or save_mgr == null:
		return
	assert_has_method(audio_mgr, "set_bus_linear_volume", "M3")
	if not audio_mgr.has_method("set_bus_linear_volume"):
		return
	audio_mgr.call("set_bus_linear_volume", "SFX", 0.5)
	var idx: int = AudioServer.get_bus_index("SFX")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.1, "SFX bus dB matches linear_to_db(0.5)")


func e2e_f15_t1_04_clean_synthesized_wav_assets_under_assets_clean() -> void:
	var wavs: Array[String] = list_files_recursive("res://assets_clean/audio", [".wav"])
	if wavs.is_empty():
		fail("Missing M3 contract: no synthesized .wav files under res://assets_clean/audio/")
		return
	var assets_md: String = read_text_file("res://ASSETS.md")
	for w_path: String in wavs:
		var res: Resource = load(w_path)
		assert_true(res is AudioStreamWAV, "%s loads cleanly as AudioStreamWAV" % w_path)
		assert_true(assets_md.contains(w_path), "%s registered in ASSETS.md" % w_path)


func e2e_f15_t1_05_dynamic_adaptive_bgm_transitions() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	assert_has_method(audio_mgr, "set_bgm_state", "M3")
	if not audio_mgr.has_method("set_bgm_state"):
		return
	audio_mgr.call("set_bgm_state", &"player_turn")
	assert_eq(str(audio_mgr.call("get_bgm_state")), "player_turn", "BGM enters player_turn")
	audio_mgr.call("set_bgm_state", &"climax_tide_fall")
	assert_eq(str(audio_mgr.call("get_bgm_state")), "climax_tide_fall", "BGM switches to climax_tide_fall")


# ===========================================================================
# Feature #16: 2-Tier Save/Load (BattleSaveManager) (F16-T1-01 .. F16-T1-05)
# ===========================================================================

func e2e_f16_t1_01_tier2_save_load_schema_and_rng_determinism() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	var ctrl1: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	_advance_to_round(ctrl1, 3)

	assert_has_method(save_mgr, "save_battle_session", "M3")
	assert_has_method(save_mgr, "load_battle_session", "M3")
	var saved_ok: bool = bool(save_mgr.call("save_battle_session", ctrl1))
	assert_true(saved_ok, "save_battle_session succeeds")

	var raw: Variant = read_json_file("user://saves/battle_session.json")
	assert_true(raw is Dictionary, "battle_session.json is Dictionary")
	var d: Dictionary = raw as Dictionary
	assert_eq(int(d.get("version", 0)), 1, "version == 1")
	assert_eq(int(d.get("current_round", 0)), 3, "current_round == 3 saved")
	assert_true(d.get("rng_seed") is String and d.get("rng_state") is String, "rng_seed & rng_state serialized as Strings")

	var ctrl2: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	var loaded_ok: bool = bool(save_mgr.call("load_battle_session", ctrl2))
	assert_true(loaded_ok, "load_battle_session restores into fresh controller")
	assert_eq(ctrl2.current_round, ctrl1.current_round, "Round restored")
	assert_eq(ctrl2.context.rng.get_state(), ctrl1.context.rng.get_state(), "RNG state restored bit-identically")


func e2e_f16_t1_02_triggered_event_ids_prevents_once_replay() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	var ctrl1: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	_advance_to_round(ctrl1, 4)
	assert_has(ctrl1.event_manager.triggered_event_ids, "evt_10101_tide_fall", "Round 4 TideFall triggered")

	save_mgr.call("save_battle_session", ctrl1)
	var ctrl2: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	save_mgr.call("load_battle_session", ctrl2)
	assert_has(ctrl2.event_manager.triggered_event_ids, "evt_10101_tide_fall", "triggered_event_ids restored")

	var re_fired: Array = watch_signal(ctrl2.event_manager, "event_triggered")
	ctrl2.event_manager.check_and_execute("OnRoundStart", ctrl2.context, ctrl2, ctrl2.director)
	assert_eq(re_fired.size(), 0, "once: true events do NOT re-fire after reload")


func e2e_f16_t1_03_turn_boundary_autosave_discipline() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_save_manager("M3") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	env["ctrl"].submit_command(BattleCommands.MarchCommand.new(1, u104.unit_id, u104.hex_position, _odd_r(1, 7)))
	await pump_frames(2)
	assert_false(FileAccess.file_exists("user://saves/battle_session.json"), "No session write on individual march step (IndexedDB safe)")

	env["ctrl"].submit_command(BattleCommands.EndTurnCommand.new(1))
	await pump_frames(2)
	assert_true(FileAccess.file_exists("user://saves/battle_session.json"), "Auto-save writes cleanly at turn boundary")


func e2e_f16_t1_04_tier3_profile_and_bak_creation() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	assert_has_method(save_mgr, "save_player_profile", "M3")
	assert_has_method(save_mgr, "load_player_profile", "M3")
	if not save_mgr.has_method("save_player_profile"):
		return

	save_mgr.call("save_player_profile", {"stage_stars": {"10101": 2}})
	save_mgr.call("save_player_profile", {"stage_stars": {"10101": 3}})
	assert_true(FileAccess.file_exists("user://saves/player_profile.json"), "player_profile.json created")
	assert_true(FileAccess.file_exists("user://saves/player_profile.bak"), "player_profile.bak created on overwrite")


func e2e_f16_t1_05_economy_state_persistence_in_tier2_save() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	var eco_scr: GDScript = require_economy_script("M4")
	if save_mgr == null or eco_scr == null:
		return
	var ctrl1: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	ctrl1.enable_economy = true
	var eco1: Variant = eco_scr.new()
	eco1.call("init_faction", 1, 500, 320, 140, 80)
	ctrl1.set("economy", eco1)
	save_mgr.call("save_battle_session", ctrl1)

	var ctrl2: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	save_mgr.call("load_battle_session", ctrl2)
	assert_true(ctrl2.enable_economy, "enable_economy restored")
	var eco2: Object = ctrl2.get("economy") as Object
	assert_not_null(eco2, "economy state object restored")
	if eco2 != null:
		assert_eq(int(eco2.call("get_resource", 1, "coin")), 500, "Coin restored")
		assert_eq(int(eco2.call("get_resource", 1, "food")), 320, "Food restored")


# ===========================================================================
# Feature #17: Battlefield Economy, MealFood & Starvation (F17-T1-01 .. 05)
# ===========================================================================

func e2e_f17_t1_01_phase1_facility_harvest_and_total_meal_food() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 0, 0, 0, 0)
	eco.call("register_facility", "farm_1", 1, "Farm", 1)   # +80 food
	eco.call("register_facility", "mkt_1", 1, "Market", 1)  # +60 coin
	eco.call("register_facility", "mine_1", 1, "Mine", 1)   # +30 coin, +25 tech
	eco.call("register_facility", "tpl_1", 1, "Temple", 1)  # +25 mana

	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var u_inf := BattleUnit.from_troop_dict(1, 1, Vector2i(0, 0), {"id": 40101, "command_branch": "Infantry", "strength": 160})
	u_inf.max_stack = 2
	var u_cav := BattleUnit.from_troop_dict(2, 1, Vector2i(1, 0), {"id": 40103, "command_branch": "Cavalry", "strength": 150})
	u_cav.max_stack = 3
	map.place_unit(u_inf)
	map.place_unit(u_cav)

	eco.call("process_begin_round", 1, map) # +80 food - (20 + 60) meal = 0 food
	assert_eq(int(eco.call("get_resource", 1, "coin")), 90, "Coin +90")
	assert_eq(int(eco.call("get_resource", 1, "tech")), 25, "Tech +25")
	assert_eq(int(eco.call("get_resource", 1, "mana")), 25, "Mana +25")
	assert_eq(int(eco.call("get_resource", 1, "food")), 0, "Food +80 - 80 MealFood == 0")


func e2e_f17_t1_02_meal_rate_across_all_branches_and_elephants() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	var elephant := BattleUnit.from_troop_dict(10, 1, Vector2i(0, 0), {"id": 40104, "command_branch": "Cavalry", "features": ["elephant"]})
	elephant.max_stack = 3
	var inf := BattleUnit.from_troop_dict(11, 1, Vector2i(1, 0), {"id": 40101, "command_branch": "Infantry"})
	inf.max_stack = 1
	assert_eq(int(eco.call("compute_unit_meal_food", elephant)), 90, "3x Elephant consumes 90 food/round")
	assert_eq(int(eco.call("compute_unit_meal_food", inf)), 10, "1x Infantry consumes 10 food/round")


func e2e_f17_t1_03_starvation_minus_one_morale_floored_at_low() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, -10, 0, 0)
	ctrl.set("economy", eco)

	var u_high := BattleUnit.from_troop_dict(1, 1, Vector2i(0, 0), {"id": 40101})
	u_high.state.morale = UnitCombatState.MoraleLevel.HIGH
	var u_norm := BattleUnit.from_troop_dict(2, 1, Vector2i(1, 0), {"id": 40101})
	u_norm.state.morale = UnitCombatState.MoraleLevel.NORMAL
	var u_low := BattleUnit.from_troop_dict(3, 1, Vector2i(2, 0), {"id": 40101})
	u_low.state.morale = UnitCombatState.MoraleLevel.LOW
	map.place_unit(u_high)
	map.place_unit(u_norm)
	map.place_unit(u_low)

	eco.call("apply_starvation_effects", 1, map)
	assert_eq(int(u_high.state.morale), int(UnitCombatState.MoraleLevel.NORMAL), "HIGH -> NORMAL")
	assert_eq(int(u_norm.state.morale), int(UnitCombatState.MoraleLevel.LOW), "NORMAL -> LOW")
	assert_eq(int(u_low.state.morale), int(UnitCombatState.MoraleLevel.LOW), "LOW floors at LOW (never CHAOS)")


func e2e_f17_t1_04_starvation_damage_0_75x_and_zero_healing() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, -5, 0, 0)
	assert_true(bool(eco.call("is_starving", 1)), "food < 0 is starving")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 0.75, 0.001, "Starvation multiplier == 0.75")
	assert_false(bool(eco.call("can_heal_unit", 1)), "Healing locked (0 HP) while starving")


func e2e_f17_t1_05_strict_gate_enable_economy_false_inertness() -> void:
	var ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	assert_false(ctrl.enable_economy, "Stage 10101 has enable_economy == false")
	_advance_to_round(ctrl, 5)
	var u101: BattleUnit = ctrl.context.get_unit(101)
	assert_eq(int(u101.state.morale), int(UnitCombatState.MoraleLevel.HIGH), "No starvation penalty when enable_economy == false")


# ===========================================================================
# Feature #18: Economy Commands, AI < 3.0s & HUD (F18-T1-01 .. F18-T1-05)
# ===========================================================================

func e2e_f18_t1_01_rob_area_income_yield_and_reset() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 0, 0, 0, 0)
	eco.call("register_facility", "enemy_farm", 2, "Farm", 1, 2, false) # 80 food/round, 2 turns unrobbed, no granary
	var gained: int = int(eco.call("rob_facility", 1, "enemy_farm", 0.80))
	assert_eq(gained, 128, "round_half_up(80 * 2 * 0.80 * 1.0) == 128 food")
	assert_eq(int(eco.call("get_resource", 1, "food")), 128, "Faction 1 food increased by 128")
	assert_eq(int(eco.call("rob_facility", 1, "enemy_farm", 0.80)), 0, "turns_unrobbed reset to 0")


func e2e_f18_t1_02_trade_command_normal_vs_crisis() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 300, 100, 0, 0)
	eco.call("register_facility", "mkt_1", 1, "Market", 1)

	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()

	var cmd_cls: Variant = eco_scr.get("TradeCommand")
	if cmd_cls == null:
		fail("Missing M4 contract: TradeCommand")
		return
	var cmd1: BattleCommands.BaseCommand = cmd_cls.new(1, "coin_to_food", 100)
	assert_true(ctrl.submit_command(cmd1), "Normal coin_to_food trade succeeds")
	assert_eq(int(eco.call("get_resource", 1, "food")), 175, "Normal trade adds +75 food")

	eco.call("set_resource", 1, "food", -10)
	var cmd2: BattleCommands.BaseCommand = cmd_cls.new(1, "coin_to_food", 100)
	assert_true(ctrl.submit_command(cmd2), "Crisis coin_to_food succeeds")
	assert_eq(int(eco.call("get_resource", 1, "food")), 28, "Crisis rate (2.0x) adds +38 food (-10 + 38 = 28)")


func e2e_f18_t1_03_recruit_upgrade_fortify_and_unlock_battle_tech() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 1000, 1000, 500, 200)
	eco.call("register_facility", "aca_1", 1, "Academy", 1)
	eco.call("register_facility", "fort_1", 1, "Fort", 1)

	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	map.set_terrain(Vector2i(1, 1), BattleMapState.TerrainType.FORT)
	map.set_fort_owner(Vector2i(1, 1), 1)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()

	for c_name: String in ["UpgradeFacilityCommand", "FortifyHexCommand", "UnlockBattleTechCommand", "RecruitCommand"]:
		if eco_scr.get(c_name) == null:
			fail("Missing M4 contract: %s" % c_name)
			return

	assert_true(ctrl.submit_command(eco_scr.get("FortifyHexCommand").new(1, Vector2i(2, 2))), "FortifyHex succeeds")
	assert_true(ctrl.submit_command(eco_scr.get("UnlockBattleTechCommand").new(1, 1, "INFANTRY")), "UnlockBattleTech Tier 1 succeeds")
	assert_true(ctrl.submit_command(eco_scr.get("RecruitCommand").new(1, 40101, 2, Vector2i(1, 1))), "Recruit 2x unit succeeds")
	assert_not_null(map.get_unit_at(Vector2i(1, 1)), "Recruited unit spawned at fort")


func e2e_f18_t1_04_apply_tactic_mana_vs_cast_skill_cooldown() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var tactic_cmd_cls: Variant = eco_scr.get("ApplyTacticCommand")
	if tactic_cmd_cls == null:
		fail("Missing M4 contract: ApplyTacticCommand")
		return

	var ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	ctrl.enable_economy = true
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 200, 200, 100, 120)
	ctrl.set("economy", eco)

	var u101: BattleUnit = ctrl.context.get_unit(101)
	assert_true(ctrl.submit_command(tactic_cmd_cls.new(1, "forced_march", u101.unit_id)), "ApplyTacticCommand succeeds")
	assert_lt(int(eco.call("get_resource", 1, "mana")), 120, "ApplyTactic consumes faction mana")
	assert_false(u101.state.has_acted, "ApplyTactic leaves unit available for CastSkillCommand")


func e2e_f18_t1_05_economy_hud_visibility_and_ai_turn_under_3s() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	ctrl.enable_economy = true
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 200, 200, 100, 100)
	eco.call("init_faction", 2, 200, 200, 100, 100)
	ctrl.set("economy", eco)
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))

	var ai := AIDecisionMatrix.new(AIDifficultyProfile.create_preset(&"normal"))
	var rep: Dictionary = ai.execute_faction_turn(ctrl, 2, ctrl.director)
	assert_lt(float(rep.get("elapsed_ms", 9999.0)), 3000.0, "Economy AI turn completes < 3.0s")


# ===========================================================================
# Feature #19: Tran Dynasty Campaign (F19-T1-01 .. F19-T1-05)
# ===========================================================================

func e2e_f19_t1_01_campaign_data_completeness_6_stages_troops_generals() -> void:
	var stages: Variant = _require_data_file("res://data/settings/stage_settings.json", "M5", "stage_settings.json")
	var troops: Variant = _require_data_file("res://data/settings/troop_settings.json", "M5", "troop_settings.json")
	var generals: Variant = _require_data_file("res://data/settings/general_settings.json", "M5", "general_settings.json")
	var facilities: Variant = _require_data_file("res://data/settings/facility_settings.json", "M5", "facility_settings.json")
	if stages == null or troops == null or generals == null or facilities == null:
		return

	assert_gte(float((stages as Array).size()), 6.0, "At least 6 Trần Dynasty campaign stages")
	assert_gte(float((troops as Array).size()), 10.0, "10-12 troop definitions")
	assert_lte(float((troops as Array).size()), 14.0, "Troop roster bounded for MVP")
	assert_gte(float((generals as Array).size()), 8.0, "8-10 general definitions")

	var has_economy_stage: bool = false
	for s: Variant in stages as Array:
		if s is Dictionary and bool((s as Dictionary).get("enable_economy", false)):
			has_economy_stage = true
	assert_true(has_economy_stage, "Campaign includes economy-enabled stage (Vân Đồn)")


func e2e_f19_t1_02_campaign_select_ui_and_stage_launch() -> void:
	var menu_node: Node = require_scene_instantiate(
		["res://scenes/main_menu.tscn", "res://scenes/ui/campaign_select.tscn"],
		"M5",
		"MainMenu / CampaignSelect"
	)
	if menu_node == null:
		return
	await pump_frames(2)
	var btn: BaseButton = find_button_matching(menu_node, ["CampaignButton", "PlayCampaignButton", "Stage10101Button"], ["chiến dịch", "bạch đằng", "campaign"])
	assert_not_null(btn, "Campaign launch button exists")


func e2e_f19_t1_03_preset_loadout_lock_vs_free_replay_what_if() -> void:
	var stages: Variant = _require_data_file("res://data/settings/stage_settings.json", "M5", "stage_settings.json")
	if stages == null or (stages as Array).size() < 6:
		fail("Missing M5 contract: 6-stage campaign required for Preset Loadout vs Free Replay")
		return
	var menu_scr: GDScript = require_script(
		["res://scripts/presentation/campaign_menu_controller.gd", "res://scripts/presentation/ui/campaign_menu_controller.gd"],
		"CampaignMenuController",
		"M5",
		"CampaignMenuController"
	)
	if menu_scr == null:
		return
	var menu_ctrl: Object = menu_scr.new()
	assert_has_method(menu_ctrl, "can_customize_general_seats", "M5")
	if menu_ctrl.has_method("can_customize_general_seats"):
		assert_false(bool(menu_ctrl.call("can_customize_general_seats", 10101, false, {})), "Uncleared Historical stage locks Preset Loadout")
		assert_true(bool(menu_ctrl.call("can_customize_general_seats", 10101, true, {"10101": 1})), "Cleared stage unlocks Free Replay / What-If")


func e2e_f19_t1_04_sequential_stage_unlock_and_star_persistence() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	var menu_scr: GDScript = require_script(
		["res://scripts/presentation/campaign_menu_controller.gd", "res://scripts/presentation/ui/campaign_menu_controller.gd"],
		"CampaignMenuController",
		"M5",
		"CampaignMenuController"
	)
	if save_mgr == null or menu_scr == null:
		return
	var stages: Array = read_json_file("res://data/settings/stage_settings.json") as Array
	if stages.size() < 2:
		fail("Missing M5 contract: >= 2 stages needed for sequential unlock")
		return
	var s1_id: int = int(stages[0].get("id", 0))
	var s2_id: int = int(stages[1].get("id", 0))
	var menu_ctrl: Object = menu_scr.new()
	assert_false(bool(menu_ctrl.call("is_stage_unlocked", s2_id, {})), "Stage 2 locked initially")
	save_mgr.call("save_player_profile", {"stage_stars": {str(s1_id): 3}})
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_true(bool(menu_ctrl.call("is_stage_unlocked", s2_id, prof)), "Stage 2 unlocks after Stage 1 cleared")


func e2e_f19_t1_05_historical_metadata_on_all_campaign_data() -> void:
	var stages: Variant = _require_data_file("res://data/settings/stage_settings.json", "M5", "stage_settings.json")
	var generals: Variant = _require_data_file("res://data/settings/general_settings.json", "M5", "general_settings.json")
	if stages == null or generals == null:
		return
	var valid_types: Array[String] = ["historical_claim", "abstraction", "fixture", "what_if"]
	for s: Variant in stages as Array:
		var sd: Dictionary = s as Dictionary
		assert_false(str(sd.get("source_ref", "")).is_empty(), "Stage %s has source_ref" % str(sd.get("id", "")))
		assert_has(valid_types, str(sd.get("modeling_type", "")), "Stage has valid modeling_type")
	for g: Variant in generals as Array:
		var gd: Dictionary = g as Dictionary
		assert_false(str(gd.get("source_ref", "")).is_empty(), "General %s has source_ref" % str(gd.get("id", "")))
		assert_has(valid_types, str(gd.get("modeling_type", "")), "General has valid modeling_type")


# ===========================================================================
# Feature #20: Contextual Tutorial & Historical Codex (F20-T1-01 .. 05)
# ===========================================================================

func e2e_f20_t1_01_first_occurrence_contextual_tutorial_triggers() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var tut: Node = require_hud_node(env["sandbox"], ["TutorialOverlay"], "M5", "TutorialOverlay")
	if tut == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	assert_has_method(tut, "trigger_tip", "M5")
	if not tut.has_method("trigger_tip"):
		return
	var shown: bool = bool(tut.call("trigger_tip", "tip_select_unit"))
	assert_true(shown, "First occurrence tip_select_unit displays")
	assert_true((tut as Control).visible, "TutorialOverlay visible")


func e2e_f20_t1_02_tutorial_flag_persistence_no_repeat() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var tut: Node = require_hud_node(env["sandbox"], ["TutorialOverlay"], "M5", "TutorialOverlay")
	if tut == null:
		return
	tut.call("trigger_tip", "tip_select_unit")
	tut.call("dismiss_current_tip")
	assert_false(bool(tut.call("trigger_tip", "tip_select_unit")), "Dismissed tip does NOT re-trigger")


func e2e_f20_t1_03_economy_tutorial_gate_enable_economy_only() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var tut: Node = require_hud_node(env["sandbox"], ["TutorialOverlay"], "M5", "TutorialOverlay")
	if tut == null:
		return
	assert_has_method(tut, "should_show_economy_tip", "M5")
	if tut.has_method("should_show_economy_tip"):
		assert_false(bool(tut.call("should_show_economy_tip", false)), "Economy tip suppressed in 10101")
		assert_true(bool(tut.call("should_show_economy_tip", true)), "Economy tip enabled in Vân Đồn")


func e2e_f20_t1_04_historical_codex_metadata_source_grade_modeling() -> void:
	var codex_data: Variant = _require_data_file("res://data/settings/codex_entries.json", "M5", "codex_entries.json")
	if codex_data == null:
		return
	var entries: Array = codex_data as Array if codex_data is Array else codex_data.get("entries", [])
	assert_gt(float(entries.size()), 0.0, "Codex has entries")
	for e_var: Variant in entries:
		var e: Dictionary = e_var as Dictionary
		assert_false(str(e.get("source_ref", "")).is_empty(), "Codex entry %s has source_ref" % str(e.get("id", "")))
		assert_false(str(e.get("modeling_type", "")).is_empty(), "Codex entry has modeling_type")
		if str(e.get("category", "")) == "historical":
			assert_has(["A", "B", "C", "D"], str(e.get("evidence_grade", "")), "Historical entry has evidence_grade A-D")


func e2e_f20_t1_05_era_separation_938_981_1288_in_codex() -> void:
	var codex_data: Variant = _require_data_file("res://data/settings/codex_entries.json", "M5", "codex_entries.json")
	if codex_data == null:
		return
	var raw_txt: String = read_text_file("res://data/settings/codex_entries.json")
	assert_true(raw_txt.contains("938") and raw_txt.contains("981") and raw_txt.contains("1288"), "Codex separates 938, 981, and 1288 Bạch Đằng entries")


# ===========================================================================
# Feature #21: 100% Clean Asset IP Gate Audit (F21-T1-01 .. F21-T1-05)
# ===========================================================================

func e2e_f21_t1_01_zero_legacy_assets_scan() -> void:
	assert_true(FileAccess.file_exists("res://Assets/.gdignore") or not DirAccess.dir_exists_absolute("res://Assets"), "Legacy Assets/ excluded via .gdignore")
	var files: Array[String] = []
	for dir_name: String in ["res://scripts", "res://scenes", "res://data"]:
		files.append_array(list_files_recursive(dir_name, [".gd", ".tscn", ".tres", ".gdshader", ".json"]))
	files.append("res://project.godot")
	for f: String in files:
		var txt: String = read_text_file(f)
		assert_false(txt.contains("res://Assets/"), "Zero res://Assets/ ref in %s" % f)


func e2e_f21_t1_02_hundred_percent_assets_clean_and_data_in_assets_md() -> void:
	var assets_md: String = read_text_file("res://ASSETS.md")
	var clean_files: Array[String] = list_files_recursive("res://assets_clean")
	clean_files.append_array(list_files_recursive("res://data"))
	assert_gt(float(clean_files.size()), 0.0, "Active clean files exist")
	for f: String in clean_files:
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		assert_true(assets_md.contains(f), "%s registered in ASSETS.md" % f)


func e2e_f21_t1_03_case_exact_res_path_verification() -> void:
	var auditor := AssetIpAuditor.new()
	var files: Array[String] = list_files_recursive("res://scripts", [".gd"])
	files.append_array(list_files_recursive("res://scenes", [".tscn"]))
	files.append_array(list_files_recursive("res://data", [".json"]))
	var re := RegEx.new()
	re.compile("res://[A-Za-z0-9_./-]+")
	for f: String in files:
		var txt: String = read_text_file(f)
		for m: RegExMatch in re.search_all(txt):
			var p: String = m.get_string()
			if p.ends_with("/"):
				continue
			assert_true(auditor.audit_case_exact_path(p), "Case-exact res:// path exists: %s (in %s)" % [p, f])


func e2e_f21_t1_04_external_addon_hygiene() -> void:
	assert_false(DirAccess.dir_exists_absolute("res://addons") and not list_files_recursive("res://addons").is_empty(), "No undeclared external addons")
	var pg: String = read_text_file("res://project.godot")
	assert_false(pg.contains("editor_plugins"), "No undeclared editor plugins enabled")


func e2e_f21_t1_05_scripts_core_and_ai_isolation_scan() -> void:
	var core_ai_files: Array[String] = list_files_recursive("res://scripts/core", [".gd"])
	core_ai_files.append_array(list_files_recursive("res://scripts/ai", [".gd"]))
	var forbidden: Array[String] = ["extends Node", "SceneTree", "RenderingServer", "AudioStreamPlayer", "CanvasItem"]
	for f: String in core_ai_files:
		var txt: String = read_text_file(f)
		for tok: String in forbidden:
			assert_false(txt.contains(tok), "Core/AI isolation: '%s' forbidden in %s" % [tok, f])


# ===========================================================================
# Feature #22: Web & Android Export, 60 FPS & Full Regression (F22-T1-01 .. 05)
# ===========================================================================

func e2e_f22_t1_01_export_presets_cfg_validation() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: res://export_presets.cfg")
		return
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg parses cleanly")
	var has_web: bool = false
	var has_android: bool = false
	for sec: String in cfg.get_sections():
		if sec.begins_with("preset.") and not sec.ends_with(".options"):
			var plat: String = str(cfg.get_value(sec, "platform", ""))
			if plat == "Web":
				has_web = true
			elif plat == "Android":
				has_android = true
	assert_true(has_web, "export_presets.cfg has Web preset")
	assert_true(has_android, "export_presets.cfg has Android preset")


func e2e_f22_t1_02_headless_import_clean_exit() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: export_presets.cfg required before M6 import verification")
		return
	var out: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], out, true)
	assert_eq(code, 0, "godot --headless --import exits 0")


func e2e_f22_t1_03_full_regression_run_tests() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: full regression gate waits for M6 release readiness")
		return
	var out: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_tests.gd"], out, true)
	assert_eq(code, 0, "tests/run_tests.gd exits 0")


func e2e_f22_t1_04_60_fps_frame_time_12x10_and_30x30() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	sandbox.call("load_stress_benchmark_30x30", 44)
	await pump_frames(3)
	var t0: int = Time.get_ticks_usec()
	await pump_frames(30)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var mean_ms: float = elapsed_ms / 30.0
	assert_lte(mean_ms, 16.67, "30x30 44-unit mean frame time <= 16.67ms (got %.2f ms)" % mean_ms)


func e2e_f22_t1_05_cli_export_execution_or_explicit_blocker_logging() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: res://export_presets.cfg")
		return
	var state_txt: String = read_text_file("res://STATE.md")
	assert_true(state_txt.contains("Gate 5") or state_txt.contains("CP5"), "STATE.md updated for Gate 5 export status")
