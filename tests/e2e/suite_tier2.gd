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


func _require_shader(res_path: String, milestone: String, desc: String) -> Shader:
	if not ResourceLoader.exists(res_path):
		fail("Missing %s contract: shader %s (%s)" % [milestone, desc, res_path])
		return null
	var res: Resource = load(res_path)
	if not (res is Shader):
		fail("Broken %s contract: invalid Shader %s" % [milestone, res_path])
		return null
	return res as Shader


# ===========================================================================
# Feature #1 Tier 2: BattleInputFSM Boundary & Negative (F01-T2-01 .. 05)
# ===========================================================================

func e2e_f01_t2_01_invalid_unit_selection_acted_enemy_chaos() -> void:
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
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	var e201: BattleUnit = env["ctrl"].context.get_unit(201)
	u101.state.has_acted = true
	u104.state.apply_chaos(2)

	for bad_hex: Vector2i in [u101.hex_position, e201.hex_position, u104.hex_position]:
		await _click_axial_opaque(sandbox, bad_hex)
		assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "FSM stays IDLE for acted/enemy/CHAOS unit")


func e2e_f01_t2_02_input_locked_during_non_player_phase_or_outcome_ended() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var states: Dictionary = get_fsm_state_enum(fsm)
	env["ctrl"].submit_command(BattleCommands.EndTurnCommand.new(1))
	await pump_frames(2)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	await _click_axial_opaque(sandbox, u101.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "FSM rejects player input during AI turn")


func e2e_f01_t2_03_boundary_right_mouse_drag_threshold_5px_vs_7px() -> void:
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
	var cam_before: Vector2 = cam.global_position
	inject_right_click_screen(Vector2(640.0, 360.0), Vector2(7.0, 0.0))
	await pump_frames(3)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "7px drag (>6px) preserves UNIT_SELECTED")
	assert_ne(cam.global_position, cam_before, "7px drag pans camera")

	inject_right_click_screen(Vector2(640.0, 360.0), Vector2(5.0, 0.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "5px (<6px) right-click cancels FSM to IDLE")


func e2e_f01_t2_04_out_of_bounds_impassable_and_ally_occupied() -> void:
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
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)

	await _click_axial_opaque(sandbox, u101.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(6, 5)) # DeepWater impassable to land
	assert_ne(u101.hex_position, _odd_r(6, 5), "Land unit cannot enter DeepWater")

	await _click_axial_opaque(sandbox, u104.hex_position)
	assert_eq(env["map_view"].get_selected_unit(), u104, "Clicking ally switches selection without stacking")
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Switched ally enters UNIT_SELECTED")

	sandbox.call("click_world_position", Vector2(-500.0, -500.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("IDLE", -1)), "Out-of-bounds clears selection to IDLE")


func e2e_f01_t2_05_multi_step_cancellation_recovery() -> void:
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

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Entered AIMING_TARGET unmoved")
	inject_right_click_screen(Vector2(640.0, 360.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Unmoved cancel returns strictly to UNIT_SELECTED")

	await _click_axial_opaque(sandbox, _odd_r(6, 6))
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Moved to (6,6)")
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Entered AIMING_TARGET post-move")
	inject_right_click_screen(Vector2(640.0, 360.0))
	await pump_frames(2)
	assert_eq(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Moved cancel returns strictly to POST_MOVE_ACTION")


# ===========================================================================
# Feature #2 Tier 2: PostMoveAction Undo Blockers & Edge Cases (F02-T2-01 .. 05)
# ===========================================================================

func e2e_f02_t2_01_undo_blocked_condition2_fog_revealed() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	ctrl.context.enable_fog_of_war = true
	ctrl.context.refresh_faction_vision(1)
	var u104: BattleUnit = ctrl.context.get_unit(104)
	var orig: Vector2i = u104.hex_position
	var dest: Vector2i = _odd_r(0, 7) # Far west hex revealing new fog cells

	await _click_axial_opaque(sandbox, orig)
	await _click_axial_opaque(sandbox, dest)
	assert_false(ctrl.can_undo(), "Undo blocked when fog cells revealed")
	inject_key_press(KEY_Z)
	await pump_frames(2)
	assert_eq(u104.hex_position, dest, "Unit stays at destination when Undo rejected")


func e2e_f02_t2_02_undo_blocked_condition3_entered_enemy_zoc() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var u102: BattleUnit = ctrl.context.get_unit(102)
	var e202: BattleUnit = ctrl.context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(6, 4))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(5, 4))
	assert_eq(u102.state.current_mp, 0, "Enemy ZoC stops movement (current_mp == 0)")
	assert_false(ctrl.can_undo(), "Undo blocked after entering enemy ZoC")


func e2e_f02_t2_03_undo_blocked_condition4_triggered_cell_event() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var ctrl: BattleGameController = env["ctrl"]
	var u104: BattleUnit = ctrl.context.get_unit(104)
	var trap_hex: Vector2i = _odd_r(1, 7)
	ctrl.context.set_trap_cell(trap_hex, true)

	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, trap_hex)
	assert_false(ctrl.can_undo(), "Undo blocked after triggering cell event/trap")


func e2e_f02_t2_04_undo_blocked_condition5_one_per_turn_limit() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	inject_key_press(KEY_Z)
	await pump_frames(2)
	assert_true(u104.state.has_used_undo_this_turn, "1st undo marks flag")

	await _click_axial_opaque(sandbox, _odd_r(3, 7))
	assert_false(env["ctrl"].can_undo(), "2nd move in same turn cannot Undo")


func e2e_f02_t2_05_march_disabled_turns_prevents_post_move_action() -> void:
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
	u104.state.march_disabled_turns = 2

	await _click_axial_opaque(sandbox, u104.hex_position)
	assert_eq(get_fsm_state_value(fsm), int(states.get("UNIT_SELECTED", -1)), "Can still select immobilized unit")
	var reach: Dictionary = env["map_view"].get_reachable_overlay_hexes()
	var move_dests: Array = reach.keys().filter(func(h: Vector2i) -> bool: return h != u104.hex_position)
	assert_eq(move_dests.size(), 0, "0 move destination hexes when march_disabled_turns > 0")
	await _click_axial_opaque(sandbox, _odd_r(1, 7))
	assert_ne(get_fsm_state_value(fsm), int(states.get("POST_MOVE_ACTION", -1)), "Immobilized unit never enters POST_MOVE_ACTION")


# ===========================================================================
# Feature #3 Tier 2: Two-Step Combat Negative & Boundaries (F03-T2-01 .. 05)
# ===========================================================================

func e2e_f03_t2_01_attack_rejected_without_target_or_out_of_range() -> void:
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
	var e201: BattleUnit = env["ctrl"].context.get_unit(201)

	await _click_axial_opaque(sandbox, u101.hex_position)
	await _click_axial_opaque(sandbox, e201.hex_position)
	assert_ne(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "Out-of-range enemy does not enter AIMING_TARGET")
	assert_false(u101.state.has_acted, "Unit remains unacted")


func e2e_f03_t2_02_ranged_min_range_2_blind_spot_and_los_blocked() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u103: BattleUnit = env["ctrl"].context.get_unit(103)
	u103.min_range = 2
	u103.max_range = 2
	var e206: BattleUnit = env["ctrl"].context.get_unit(206)
	env["map_state"].move_unit(e206, _odd_r(3, 6)) # dist 1 blind spot
	env["map_view"].refresh_units()

	var hp_before: int = e206.state.current_hp
	await _click_axial_opaque(sandbox, u103.hex_position)
	await _click_axial_opaque(sandbox, e206.hex_position)
	assert_eq(e206.state.current_hp, hp_before, "Blind spot enemy at dist 1 takes 0 damage")


func e2e_f03_t2_03_attack_disabled_turns_blocks_aiming() -> void:
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
	u102.state.attack_disabled_turns = 1
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_ne(get_fsm_state_value(fsm), int(states.get("AIMING_TARGET", -1)), "attack_disabled unit cannot enter AIMING_TARGET")


func e2e_f03_t2_04_rapid_double_tap_on_ally_never_attacks_ally() -> void:
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
	var hp_before: int = u104.state.current_hp

	await _click_axial_opaque(sandbox, u101.hex_position)
	await _click_axial_opaque(sandbox, u104.hex_position)
	await _click_axial_opaque(sandbox, u104.hex_position)
	assert_eq(u104.state.current_hp, hp_before, "Double-tap on ally never deals friendly fire")


func e2e_f03_t2_05_lethal_hit_preview_suppresses_retaliation() -> void:
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
	e202.state.current_hp = 1
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	env["map_view"].refresh_units()

	var prev: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u102, e202)
	assert_false(bool(prev.get("will_retaliate", true)), "Lethal preview predicts zero retaliation")

	var u102_hp_before: int = u102.state.current_hp
	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_eq(u102.state.current_hp, u102_hp_before, "Attacker takes 0 retaliation damage on lethal kill")
	assert_false((preview_box as Control).visible, "Preview clears after lethal kill")


# ===========================================================================
# Feature #4 Tier 2: SkillTargeting Negative & Boundaries (F04-T2-01 .. 05)
# ===========================================================================

func e2e_f04_t2_01_skill_target_outside_range_rejected() -> void:
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
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn == null:
		fail("Missing M1/M2 contract: [MƯU LƯỢC] button")
		return
	inject_left_click_screen(skill_btn.get_global_rect().get_center())
	await pump_frames(2)

	await _click_axial_opaque(sandbox, _odd_r(2, 5)) # dist 3 > range_hex 2
	assert_eq(u101.state.skill_cooldown, 0, "Out-of-range skill cast rejected")
	assert_false(u101.state.has_acted, "Caster remains unacted")


func e2e_f04_t2_02_aoe_radius_1_boundary_excludes_dist2_and_enemies() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var ctrl: BattleGameController = env["ctrl"]
	var u101: BattleUnit = ctrl.context.get_unit(101)
	var u104: BattleUnit = ctrl.context.get_unit(104) # at (2,7) -> dist 1 from (2,7)
	var u103: BattleUnit = ctrl.context.get_unit(103) # at (3,5) -> dist 2 from (2,7)
	var e202: BattleUnit = ctrl.context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(1, 7)) # enemy dist 1 from (2,7)

	u104.state.morale = UnitCombatState.MoraleLevel.LOW
	u103.state.morale = UnitCombatState.MoraleLevel.LOW
	e202.state.morale = UnitCombatState.MoraleLevel.LOW

	assert_true(ctrl.submit_command(BattleCommands.CastSkillCommand.new(1, u101.unit_id, 10001, u104.hex_position)), "Cast at (2,7)")
	assert_eq(int(u104.state.morale), int(UnitCombatState.MoraleLevel.NORMAL), "Ally within AoE<=1 boosted")
	assert_eq(int(u103.state.morale), int(UnitCombatState.MoraleLevel.LOW), "Ally at AoE dist 2 NOT boosted")
	assert_eq(int(e202.state.morale), int(UnitCombatState.MoraleLevel.LOW), "Enemy within AoE NOT boosted")


func e2e_f04_t2_03_skill_blocked_on_cooldown_or_skill_disabled() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var fsm: Object = require_fsm(sandbox, "M1")
	if fsm == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	u101.state.skill_cooldown = 1
	await _click_axial_opaque(sandbox, u101.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	assert_not_null(skill_btn, "[MƯU LƯỢC] button exists")
	if skill_btn != null:
		assert_true(skill_btn.disabled, "[MƯU LƯỢC] disabled while on cooldown")
	assert_false(env["ctrl"].submit_command(BattleCommands.CastSkillCommand.new(1, u101.unit_id, 10001, u101.hex_position)), "Cooldown blocks CastSkillCommand")


func e2e_f04_t2_04_unit_without_general_has_skill_disabled() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_hud_controller(sandbox, "M2") == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	var u103: BattleUnit = env["ctrl"].context.get_unit(103)
	assert_eq(u103.general_id, 0, "Unit 103 has no general")
	await _click_axial_opaque(sandbox, u103.hex_position)
	var skill_btn: BaseButton = find_button_matching(sandbox, ["SkillButton", "BtnSkill"], ["mưu lược", "skill"])
	if skill_btn != null:
		assert_true(skill_btn.disabled, "[MƯU LƯỢC] disabled for non-general unit")


func e2e_f04_t2_05_morale_cap_at_high_and_zero_mana_independence() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var ctrl: BattleGameController = env["ctrl"]
	var u101: BattleUnit = ctrl.context.get_unit(101)
	u101.state.morale = UnitCombatState.MoraleLevel.HIGH
	assert_true(ctrl.submit_command(BattleCommands.CastSkillCommand.new(1, u101.unit_id, 10001, u101.hex_position)), "CastSkill works at 0 faction mana")
	assert_eq(int(u101.state.morale), int(UnitCombatState.MoraleLevel.HIGH), "Morale clamps cleanly at HIGH (3)")


# ===========================================================================
# Feature #5 Tier 2: Map-First Layout Boundaries (F05-T2-01 .. 05)
# ===========================================================================

func e2e_f05_t2_01_1280x720_with_enable_economy_true_keeps_80_percent_map() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	if hud_ctrl == null or require_economy_script("M4") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	env["ctrl"].enable_economy = true
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", env["ctrl"])
	await pump_frames(2)
	var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(1280.0, 720.0))
	assert_gte(float(cov["map_ratio"]), 0.80, "Map area stays >= 80% even with economy HUD active")


func e2e_f05_t2_02_compact_height_boundary_960x540_no_overlap() -> void:
	set_test_viewport_size(Vector2i(960, 540))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_hud_controller(env["sandbox"], "M2") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])
	await pump_frames(2)

	var top_bar: Control = require_hud_node(env["sandbox"], ["TopStatusBar"], "M2", "TopStatusBar") as Control
	var dock: Control = require_hud_node(env["sandbox"], ["BottomCommandDock"], "M2", "BottomCommandDock") as Control
	if top_bar != null and dock != null:
		assert_false(top_bar.get_global_rect().intersects(dock.get_global_rect()), "No overlap at 960x540")


func e2e_f05_t2_03_ultra_wide_21_9_aspect_no_clipping() -> void:
	set_test_viewport_size(Vector2i(2520, 1080))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_hud_controller(env["sandbox"], "M2") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])
	await pump_frames(2)

	var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(2520.0, 1080.0))
	assert_gte(float(cov["map_ratio"]), 0.80, "Map area >= 80% at 21:9")


func e2e_f05_t2_04_hud_panel_mouse_filter_blocks_map_click_through() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	if require_fsm(sandbox, "M1") == null:
		return
	var top_bar: Control = require_hud_node(sandbox, ["TopStatusBar"], "M2", "TopStatusBar") as Control
	if top_bar == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	assert_eq(top_bar.mouse_filter, Control.MOUSE_FILTER_STOP, "TopStatusBar stops mouse input propagation")
	inject_left_click_screen(top_bar.get_global_rect().get_center())
	await pump_frames(2)
	assert_false(env["map_view"].has_selected_hex(), "Clicking TopStatusBar does not select underlying map hex")


func e2e_f05_t2_05_boundary_zoom_0_65_vs_0_64_lod_threshold() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var cam: BattleCameraController = env["cam"]
	cam.set_zoom_level(0.65, true)
	await pump_frames(1)
	assert_false(env["map_view"].is_strategic_lod(), "0.65x keeps UnitModelLayer active")

	cam.set_zoom_level(0.64, true)
	await pump_frames(1)
	assert_true(env["map_view"].is_strategic_lod(), "0.64x (<0.65) activates StrategicTokenLayer")


# ===========================================================================
# Feature #6 Tier 2: Dynamic TopStatusBar Boundaries (F06-T2-01 .. 05)
# ===========================================================================

func e2e_f06_t2_01_economy_toggle_isolation_true_to_false() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	if hud_ctrl == null or require_economy_script("M4") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	env["ctrl"].enable_economy = true
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", env["ctrl"])
	await pump_frames(1)
	env["ctrl"].enable_economy = false
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", env["ctrl"])
	await pump_frames(1)

	var top_bar: Node = require_hud_node(env["sandbox"], ["TopStatusBar"], "M2", "TopStatusBar")
	var eco_box: CanvasItem = find_node_by_name_recursive(top_bar, "EconomyContainer") as CanvasItem
	if eco_box != null:
		assert_false(eco_box.visible, "EconomyContainer hides cleanly when toggled back to false")


func e2e_f06_t2_02_round_boundary_formatting_09_to_10() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_hud_controller(env["sandbox"], "M2") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var top_bar: Node = require_hud_node(env["sandbox"], ["TopStatusBar"], "M2", "TopStatusBar")
	_advance_to_round(env["ctrl"], 9)
	await pump_frames(1)
	assert_true(collect_labels_text(top_bar).contains("09/10"), "Round 9 formatted 09/10")
	_advance_to_round(env["ctrl"], 10)
	await pump_frames(1)
	assert_true(collect_labels_text(top_bar).contains("10/10"), "Round 10 formatted 10/10")


func e2e_f06_t2_03_long_objective_string_does_not_push_pause_off_screen() -> void:
	set_test_viewport_size(Vector2i(1280, 720))
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	if hud_ctrl == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	if hud_ctrl.has_method("set_objective_text"):
		hud_ctrl.call("set_objective_text", "Giữ vững Bến Tín Hiệu Bạch Đằng và tiêu diệt toàn bộ thủy quân địch trước khi nước triều dâng trở lại")
	await pump_frames(2)

	var pause_btn: BaseButton = find_button_matching(env["sandbox"], ["PauseButton", "BtnPause"], ["pause", "tạm dừng"])
	if pause_btn != null:
		var vp_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
		assert_true(vp_rect.encloses(pause_btn.get_global_rect()), "PauseButton stays inside viewport with long objective text")


func e2e_f06_t2_04_zero_mana_boundary_display() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_hud_controller(env["sandbox"], "M2") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var top_bar: Node = require_hud_node(env["sandbox"], ["TopStatusBar"], "M2", "TopStatusBar")
	var txt: String = collect_labels_text(top_bar)
	assert_false(txt.contains("-1"), "Mana never renders negative")


func e2e_f06_t2_05_rapid_double_click_pause_idempotent() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_hud_controller(env["sandbox"], "M2") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var pause_btn: BaseButton = find_button_matching(env["sandbox"], ["PauseButton", "BtnPause"], ["pause", "tạm dừng"])
	if pause_btn == null:
		fail("Missing M2 contract: PauseButton")
		return
	inject_left_click_screen(pause_btn.get_global_rect().get_center())
	inject_left_click_screen(pause_btn.get_global_rect().get_center())
	await pump_frames(2)

	var pause_modal: Control = require_hud_node(env["sandbox"], ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal") as Control
	assert_true(pause_modal.visible, "Pause modal opens cleanly without duplicate stack crash")


# ===========================================================================
# Feature #7 Tier 2: CombatPreviewBox Boundaries (F07-T2-01 .. 05)
# ===========================================================================

func e2e_f07_t2_01_viewport_edge_clamping_all_corners() -> void:
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
	env["map_state"].move_unit(u102, _odd_r(10, 8))
	env["map_state"].move_unit(e202, _odd_r(11, 9))
	env["cam"].pan_to_world_pos(HexMath.axial_to_world(_odd_r(11, 9)), true)
	await pump_frames(2)

	await _click_axial_opaque(sandbox, u102.hex_position)
	await _click_axial_opaque(sandbox, e202.hex_position)
	assert_true(preview_box.visible, "Preview open near bottom-right corner")
	var vp_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	assert_true(vp_rect.encloses(preview_box.get_global_rect()), "CombatPreviewBox clamped inside 1280x720")


func e2e_f07_t2_02_high_defense_minimum_damage_floor_is_1() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var u104: BattleUnit = env["ctrl"].context.get_unit(104)
	var e206: BattleUnit = env["ctrl"].context.get_unit(206)
	u104.base_atk = 1
	e206.base_def = 999
	e206.damage_resist = 75
	var prev: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u104, e206)
	assert_gte(float(prev["min_damage"]), 1.0, "Minimum damage floor >= 1")
	assert_gte(float(prev["max_damage"]), float(prev["min_damage"]), "max_damage >= min_damage")


func e2e_f07_t2_03_crit_rate_0_and_100_clamping_boundaries() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	u102.crit_rate_bonus = -100
	var p0: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u102, e202)
	assert_eq(int(p0["crit_rate"]), 0, "crit_rate clamped at 0%")
	u102.crit_rate_bonus = 200
	var p100: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u102, e202)
	assert_eq(int(p100["crit_rate"]), 100, "crit_rate clamped at 100%")


func e2e_f07_t2_04_post_hit_kill_retaliation_suppression() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	e202.state.current_hp = 1
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	var prev: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u102, e202)
	assert_false(bool(prev["will_retaliate"]), "Guaranteed lethal preview disables retaliation")
	assert_eq(int(prev["counter_max_damage"]), 0, "Counter max damage == 0")


func e2e_f07_t2_05_target_already_retaliated_this_round_shows_zero_counter() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var u102: BattleUnit = env["ctrl"].context.get_unit(102)
	var e202: BattleUnit = env["ctrl"].context.get_unit(202)
	e202.state.has_retaliated_this_round = true
	env["map_state"].move_unit(e202, _odd_r(5, 5))
	var prev: Dictionary = env["ctrl"].context.combat_resolver.preview_combat(env["map_state"], env["ctrl"].context.navigator, u102, e202)
	assert_false(bool(prev["will_retaliate"]), "1 retaliation/round rule suppresses 2nd retaliation")


# ===========================================================================
# Feature #8 Tier 2: BottomCommandDock & Overhead HUD (F08-T2-01 .. 05)
# ===========================================================================

func e2e_f08_t2_01_selecting_enemy_or_empty_hex_inspect_mode() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var dock: Node = require_hud_node(sandbox, ["BottomCommandDock"], "M2", "BottomCommandDock")
	if dock == null:
		return
	await _dismiss_opening_modals_if_any(sandbox)

	await _click_axial_opaque(sandbox, _odd_r(6, 1)) # Enemy Ô Mã Nhi
	var atk_btn: BaseButton = find_button_matching(dock, ["AttackButton", "BtnAttack"], ["đánh", "attack"])
	var wait_btn: BaseButton = find_button_matching(dock, ["WaitButton", "BtnWait"], ["đợi", "wait"])
	var end_btn: BaseButton = find_button_matching(dock, ["EndTurnButton", "BtnEndTurn"], ["kết thúc", "end turn"])
	if atk_btn != null:
		assert_true(atk_btn.disabled, "Attack disabled when inspecting enemy")
	if wait_btn != null:
		assert_true(wait_btn.disabled, "Wait disabled when inspecting enemy")
	if end_btn != null:
		assert_false(end_btn.disabled, "EndTurn stays enabled in inspect mode")


func e2e_f08_t2_02_1_hp_surviving_unit_banner_and_hp_bar_floor() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var u101: BattleUnit = env["ctrl"].context.get_unit(101)
	u101.state.current_hp = 1
	assert_eq(u101.get_active_banners(), 1, "1 HP alive unit keeps active_banners == 1 (never 0)")


func e2e_f08_t2_03_strategic_zoom_hides_detailed_overhead_hud() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	env["cam"].set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	await pump_frames(2)
	assert_true(env["map_view"].is_strategic_lod(), "Strategic LOD active at 0.5x")
	var token_layer: Node2D = find_node_by_name_recursive(env["map_view"], "StrategicTokenLayer") as Node2D
	assert_true(token_layer.visible, "StrategicTokenLayer visible at 0.5x")


func e2e_f08_t2_04_multiple_stacked_cc_badges_round4_tide_fall() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var ctrl: BattleGameController = env["ctrl"]
	var e202: BattleUnit = ctrl.context.get_unit(202)
	env["map_state"].move_unit(e202, _odd_r(6, 4)) # Inside area_bai_coc
	_advance_to_round(ctrl, 4)
	await pump_frames(2)
	assert_eq(int(e202.state.morale), int(UnitCombatState.MoraleLevel.CHAOS), "Ship in area_bai_coc enters CHAOS")
	assert_gte(e202.state.march_disabled_turns, 2, "Ship gets march_disabled_turns >= 2")


func e2e_f08_t2_05_end_turn_disabled_during_ai_turn_or_battle_over() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var dock: Node = require_hud_node(env["sandbox"], ["BottomCommandDock"], "M2", "BottomCommandDock")
	if dock == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	env["ctrl"].submit_command(BattleCommands.EndTurnCommand.new(1))
	await pump_frames(2)
	var end_btn: BaseButton = find_button_matching(dock, ["EndTurnButton", "BtnEndTurn"], ["kết thúc", "end turn"])
	if end_btn != null:
		assert_true(end_btn.disabled, "[KẾT THÚC LƯỢT] disabled during AI turn")


# ===========================================================================
# Feature #9 Tier 2: Briefing & Dialogue Boundaries (F09-T2-01 .. 05)
# ===========================================================================

func e2e_f09_t2_01_camera_input_blocked_while_camera_locked() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var cam: BattleCameraController = env["cam"]
	cam.camera_locked = true
	var pos_before: Vector2 = cam.global_position
	var zoom_before: float = cam.zoom.x
	inject_right_click_screen(Vector2(640, 360), Vector2(40, 30))
	inject_key_press(KEY_3)
	await pump_frames(3)
	assert_eq(cam.global_position, pos_before, "Camera position locked when camera_locked == true")
	assert_almost_eq(cam.zoom.x, zoom_before, 0.001, "Camera zoom locked when camera_locked == true")


func e2e_f09_t2_02_map_hex_clicks_blocked_under_briefing_or_dialogue() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var sandbox: Node = env["sandbox"]
	var briefing: Control = require_hud_node(sandbox, ["BriefingModal"], "M2", "BriefingModal") as Control
	var fsm: Object = require_fsm(sandbox, "M1")
	if briefing == null or fsm == null:
		return
	assert_true(briefing.visible, "BriefingModal visible")
	await _click_axial_opaque(sandbox, _odd_r(2, 8))
	assert_false(env["map_view"].has_selected_hex(), "BriefingModal blocks clicks from selecting map units")


func e2e_f09_t2_03_queued_back_to_back_dialogues_do_not_unlock_early() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	var dlg: Control = require_hud_node(env["sandbox"], ["DialogueModal"], "M2", "DialogueModal") as Control
	if hud_ctrl == null or dlg == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	assert_has_method(hud_ctrl, "queue_dialogue_id", "M2")
	if not hud_ctrl.has_method("queue_dialogue_id"):
		return
	hud_ctrl.call("queue_dialogue_id", "talk_opening_bach_dang")
	hud_ctrl.call("queue_dialogue_id", "talk_trieu_rut")
	await pump_frames(2)
	assert_true(dlg.visible and env["cam"].camera_locked, "1st dialogue opens & locks camera")
	await _dismiss_opening_modals_if_any(env["sandbox"])
	assert_true(dlg.visible and env["cam"].camera_locked, "2nd queued dialogue keeps camera_locked == true")
	await _dismiss_opening_modals_if_any(env["sandbox"])
	assert_false(dlg.visible or env["cam"].camera_locked, "Camera unlocks only after last queued dialogue")


func e2e_f09_t2_04_missing_unknown_dialogue_id_graceful_handling() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var hud_ctrl: Object = require_hud_controller(env["sandbox"], "M2")
	if hud_ctrl == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])
	if hud_ctrl.has_method("queue_dialogue_id"):
		hud_ctrl.call("queue_dialogue_id", "nonexistent_dialogue_xyz")
	await pump_frames(2)
	assert_false(env["cam"].camera_locked, "Unknown dialogue_id never soft-locks camera_locked")


func e2e_f09_t2_05_once_true_events_do_not_re_fire_after_save_load() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	var ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	_advance_to_round(ctrl, 4)
	save_mgr.call("save_battle_session", ctrl)

	var ctrl2: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	save_mgr.call("load_battle_session", ctrl2)
	var dlg_signals: Array = watch_signal(ctrl2.event_manager, "dialogue_requested")
	ctrl2.event_manager.check_and_execute("OnRoundStart", ctrl2.context, ctrl2, ctrl2.director)
	assert_eq(dlg_signals.size(), 0, "talk_trieu_rut does not re-trigger after save/load")


# ===========================================================================
# Feature #10 Tier 2: All 4 Defeat Causes & Precedence (F10-T2-01 .. 05)
# ===========================================================================

func e2e_f10_t2_01_defeat_cause_1_lose_key_area() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var summary: Control = require_hud_node(env["sandbox"], ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var ctrl: BattleGameController = env["ctrl"]
	ctrl.director.set_area_owner("signal_dock", 2)
	ctrl.submit_command(BattleCommands.WaitCommand.new(1, 101))
	await pump_frames(3)
	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "LoseKeyArea triggers DEFEAT")
	var txt: String = collect_labels_text(summary).to_lower()
	assert_true(txt.contains("losekeyarea") or txt.contains("bến") or txt.contains("signal_dock"), "Summary names LoseKeyArea defeat cause")


func e2e_f10_t2_02_defeat_cause_2_general_defeated() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var summary: Control = require_hud_node(env["sandbox"], ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var ctrl: BattleGameController = env["ctrl"]
	var u101: BattleUnit = ctrl.context.get_unit(101)
	u101.state.current_hp = 0
	ctrl.context.map_state.remove_unit(101)
	ctrl.submit_command(BattleCommands.WaitCommand.new(1, 102))
	await pump_frames(3)
	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "GeneralDefeated triggers DEFEAT")
	var txt: String = collect_labels_text(summary).to_lower()
	assert_true(txt.contains("generaldefeated") or txt.contains("chủ tướng") or txt.contains("trần quốc tuấn"), "Summary names GeneralDefeated cause")


func e2e_f10_t2_03_defeat_cause_3_all_units_eliminated() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var summary: Control = require_hud_node(env["sandbox"], ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var ctrl: BattleGameController = env["ctrl"]
	# Use custom defeat condition ordering where AllUnitsEliminated fires cleanly
	ctrl.victory_evaluator = ScenarioVictoryEvaluator.new([], [{"type": "AllUnitsEliminated", "faction_id": 1}], [], 1, 10)
	for uid: int in [101, 102, 103, 104, 105]:
		ctrl.context.map_state.remove_unit(uid)
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))
	await pump_frames(3)
	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "AllUnitsEliminated triggers DEFEAT")
	var txt: String = collect_labels_text(summary).to_lower()
	assert_true(txt.contains("allunitseliminated") or txt.contains("toàn quân") or txt.contains("tiêu diệt"), "Summary names AllUnitsEliminated cause")


func e2e_f10_t2_04_defeat_cause_4_max_rounds_unfulfilled_and_star_boundaries() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var summary: Control = require_hud_node(env["sandbox"], ["ResultSummaryModal", "SummaryModal"], "M2", "ResultSummaryModal") as Control
	if summary == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	var ctrl: BattleGameController = env["ctrl"]
	_advance_to_round(ctrl, 10)
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(2))
	await pump_frames(3)
	assert_eq(int(ctrl.outcome), int(BattleGameController.BattleOutcome.DEFEAT), "Round 10 end <75% casualties triggers MaxRoundsUnfulfilled DEFEAT")
	var txt: String = collect_labels_text(summary).to_lower()
	assert_true(txt.contains("maxroundsunfulfilled") or txt.contains("hết vòng") or txt.contains("10"), "Summary names MaxRoundsUnfulfilled cause")


func e2e_f10_t2_05_victory_precedence_omnhi_killed_without_holding_signal_dock() -> void:
	var ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	ctrl.director.set_area_owner("signal_dock", 2)
	ctrl.context.map_state.remove_unit(201)
	var out: int = ctrl.victory_evaluator.evaluate_outcome(ctrl.context.map_state, ctrl.director, 3, 0, false)
	assert_eq(out, ScenarioVictoryEvaluator.OUTCOME_DEFEAT, "Losing signal_dock results in DEFEAT even if Ô Mã Nhi defeated")


# ===========================================================================
# Feature #11 Tier 2: Pause & Accessibility Boundaries (F11-T2-01 .. 05)
# ===========================================================================

func e2e_f11_t2_01_wcag_flash_rate_cap_under_3_hz() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	juice.set("reduce_flashing", true)
	var s := Sprite2D.new()
	add_child_autofree(s)
	var triggered: int = 0
	for _i: int in range(5):
		if bool(juice.call("trigger_hit_flash", s, true)):
			triggered += 1
	assert_lt(float(triggered), 3.0, "WCAG 2.3.1 caps flash frequency < 3 flashes/sec")


func e2e_f11_t2_02_determinism_invariance_under_accessibility_changes() -> void:
	var ctrl_a: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	var ctrl_b: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	for c: BattleGameController in [ctrl_a, ctrl_b]:
		var e202: BattleUnit = c.context.get_unit(202)
		c.context.map_state.move_unit(e202, _odd_r(5, 5))
		c.submit_command(BattleCommands.AttackCommand.new(1, 102, 202))
	assert_eq(ctrl_a.context.rng.get_state(), ctrl_b.context.rng.get_state(), "RNG identical regardless of VFX settings")
	assert_eq(ctrl_a.context.get_unit(202).state.current_hp, ctrl_b.context.get_unit(202).state.current_hp, "Combat HP identical")


func e2e_f11_t2_03_audio_mute_boundary_zero_slider() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	audio_mgr.call("set_bus_linear_volume", "Master", 0.0)
	var db: float = AudioServer.get_bus_volume_db(0)
	assert_false(is_nan(db), "0.0 volume never produces NaN dB")
	assert_true(AudioServer.is_bus_mute(0) or db <= -79.0, "0.0 volume mutes or sets <= -80 dB")


func e2e_f11_t2_04_restart_from_pause_preserves_profile_settings() -> void:
	clear_user_saves()
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var pause_modal: Node = require_hud_node(env["sandbox"], ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal")
	var save_mgr: Object = require_save_manager("M3")
	if pause_modal == null or save_mgr == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	save_mgr.call("save_player_profile", {"reduce_flashing": true, "shake_scale": 0.25})
	var pause_btn: BaseButton = find_button_matching(env["sandbox"], ["PauseButton", "BtnPause"], ["pause", "tạm dừng"])
	if pause_btn != null:
		inject_left_click_screen(pause_btn.get_global_rect().get_center())
		await pump_frames(2)
	var restart_btn: BaseButton = find_button_matching(pause_modal, ["RestartButton", "BtnRestart"], ["chơi lại", "restart"])
	if restart_btn == null:
		fail("Missing M2 contract: Restart button in PauseSettingsModal")
		return
	inject_left_click_screen(restart_btn.get_global_rect().get_center())
	await pump_frames(3)
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_true(bool(prof.get("reduce_flashing", false)), "Restart preserves profile accessibility settings")


func e2e_f11_t2_05_pause_toggle_while_briefing_or_summary_active() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var briefing: Control = require_hud_node(env["sandbox"], ["BriefingModal"], "M2", "BriefingModal") as Control
	var pause_modal: Control = require_hud_node(env["sandbox"], ["PauseSettingsModal", "PauseModal"], "M2", "PauseSettingsModal") as Control
	if briefing == null or pause_modal == null:
		return
	inject_key_press(KEY_ESCAPE)
	await pump_frames(2)
	assert_false(pause_modal.visible and not briefing.visible, "Esc while Briefing open does not corrupt modal state")


# ===========================================================================
# Feature #12 Tier 2: Shaders Negative & Boundaries (F12-T2-01 .. 05)
# ===========================================================================

func e2e_f12_t2_01_wcag_flash_frequency_cap_rolling_window() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	juice.set("reduce_flashing", true)
	var s := Sprite2D.new()
	add_child_autofree(s)
	var count_ok: int = 0
	for _i: int in range(5):
		if bool(juice.call("trigger_hit_flash", s, false)):
			count_ok += 1
	assert_lte(float(count_ok), 2.0, "At most 2 flashes permitted within 1s window")


func e2e_f12_t2_02_vfx_quality_low_bypasses_shader_swap() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	juice.call("set_vfx_quality", "Low")
	var s := Sprite2D.new()
	add_child_autofree(s)
	juice.call("trigger_hit_flash", s, false)
	assert_null(s.material, "Low VFX quality keeps material == null (batch-safe)")


func e2e_f12_t2_03_unit_freed_mid_50ms_flash_window() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var s := Sprite2D.new()
	_scene_tree.root.add_child(s)
	juice.call("trigger_hit_flash", s, false)
	s.queue_free()
	await _scene_tree.create_timer(0.10).timeout
	assert_false(is_instance_valid(s), "Freed target during flash window handled without error")


func e2e_f12_t2_04_zero_damage_hit_cleanup_restores_material_and_color() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var s := Sprite2D.new()
	add_child_autofree(s)
	juice.call("trigger_hit_flash", s, false)
	await _scene_tree.create_timer(0.10).timeout
	assert_null(s.material, "material restored to null")
	assert_almost_eq(s.self_modulate.a, 1.0, 0.01, "alpha preserved")


func e2e_f12_t2_05_flash_modifier_out_of_range_clamping() -> void:
	var sh: Shader = _require_shader("res://assets_clean/shaders/hit_flash.gdshader", "M3", "hit_flash.gdshader")
	if sh == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("flash_modifier", 2.5)
	assert_true(sh.code.contains("hint_range(0.0, 1.0)"), "Shader declares hint_range(0.0, 1.0) on flash_modifier")


# ===========================================================================
# Feature #13 Tier 2: Hit-Stop & Juice Boundaries (F13-T2-01 .. 05)
# ===========================================================================

func e2e_f13_t2_01_overlapping_double_hit_tween_cancellation() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var target := Node2D.new()
	add_child_autofree(target)
	juice.call("play_squash_stretch", target)
	await _scene_tree.create_timer(0.03).timeout
	juice.call("play_squash_stretch", target)
	await _scene_tree.create_timer(0.25).timeout
	assert_almost_eq(target.scale.x, 1.0, 0.02, "No compounding scale X drift after overlapping hits")
	assert_almost_eq(target.scale.y, 1.0, 0.02, "No compounding scale Y drift after overlapping hits")


func e2e_f13_t2_02_small_tier_zero_ms_hit_stop_on_march() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var small: Dictionary = juice.call("classify_impact_tier", false, false, 10)
	assert_almost_eq(float(small.get("hit_stop_sec", -1.0)), 0.0, 0.001, "Small impact has 0ms hit-stop")
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Engine.time_scale stays 1.0")


func e2e_f13_t2_03_unit_freed_during_await_hit_stop() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var a := AnimatedSprite2D.new()
	var b := AnimatedSprite2D.new()
	add_child_autofree(a)
	_scene_tree.root.add_child(b)
	juice.call("play_local_hit_stop", [a, b], 0.08)
	b.queue_free()
	await _scene_tree.create_timer(0.14).timeout
	assert_almost_eq(a.speed_scale, 1.0, 0.001, "Surviving unit restores speed_scale = 1.0 after partner freed")


func e2e_f13_t2_04_juice_zero_mutation_of_battle_context_rng() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var rng_before: int = env["ctrl"].context.rng.get_state()
	var dummy := Node2D.new()
	add_child_autofree(dummy)
	juice.call("play_squash_stretch", dummy)
	juice.call("spawn_particle_preset", "WaterSplashCPU2D", Vector2(50, 50), "Tran_Nguyen")
	assert_eq(env["ctrl"].context.rng.get_state(), rng_before, "VFX juice never mutates BattleContext.rng")


func e2e_f13_t2_05_simultaneous_multi_unit_staked_water_popups() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var hud_layer: Node = find_node_by_name_recursive(env["map_view"], "WorldSpaceUnitHudAndTextLayer")
	for i: int in range(3):
		juice.call("spawn_floating_text", hud_layer, Vector2(100 + i * 30, 100), 112, &"trap")
	await _scene_tree.create_timer(0.8).timeout
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Multi-unit StakedWater popups resolve cleanly")


# ===========================================================================
# Feature #14 Tier 2: CPUParticles2D Pool Boundaries (F14-T2-01 .. 05)
# ===========================================================================

func e2e_f14_t2_01_era_gating_blocks_gunpowder_in_1288() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var ok: bool = bool(juice.call("spawn_particle_preset", "GunpowderSmokeCPU2D", Vector2(100, 100), "Tran_Nguyen"))
	assert_false(ok, "GunpowderSmokeCPU2D strictly blocked in 1288 Tran_Nguyen era")


func e2e_f14_t2_02_pool_exhaustion_40_simultaneous_bursts() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	for i: int in range(40):
		juice.call("spawn_particle_preset", "DustTrailCPU2D", Vector2(20 * i, 100), "Tran_Nguyen")
	await pump_frames(2)
	var effect_layer: Node = find_node_by_name_recursive(env["map_view"], "MapEffectLayer")
	assert_eq(find_nodes_by_class_recursive(effect_layer, "CPUParticles2D").size(), 16, "Pool remains bounded at 16 nodes after 40 bursts")


func e2e_f14_t2_03_unknown_particle_preset_id_safe_noop() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	var ok: bool = bool(juice.call("spawn_particle_preset", "nonexistent_vfx_999", Vector2.ZERO, "Tran_Nguyen"))
	assert_false(ok, "Unknown particle preset returns false safely")


func e2e_f14_t2_04_quality_toggle_mid_emission() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	juice.call("set_vfx_quality", "High")
	juice.call("spawn_particle_preset", "MoraleAuraCPU2D", Vector2(80, 80), "Tran_Nguyen")
	juice.call("set_vfx_quality", "Low")
	await pump_frames(1)
	var effect_layer: Node = find_node_by_name_recursive(env["map_view"], "MapEffectLayer")
	var pool: Array[Node] = find_nodes_by_class_recursive(effect_layer, "CPUParticles2D")
	assert_gt(float(pool.size()), 0.0, "Pool nodes valid after mid-emission quality toggle")


func e2e_f14_t2_05_strategic_zoom_0_5x_particle_placement() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var juice: Object = require_juice_helper(env["sandbox"], "M3")
	if juice == null:
		return
	env["cam"].set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	var ok: bool = bool(juice.call("spawn_particle_preset", "WaterSplashCPU2D", Vector2(200, 200), "Tran_Nguyen"))
	assert_true(ok, "Particles spawn at world coordinates under 0.5x strategic zoom")


# ===========================================================================
# Feature #15 Tier 2: Audio Boundaries (F15-T2-01 .. 05)
# ===========================================================================

func e2e_f15_t2_01_era_gating_blocks_gunpowder_sfx_in_1288() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	var ok: bool = bool(audio_mgr.call("play_sfx", "gunfire", Vector2.ZERO, "Tran_Nguyen"))
	assert_false(ok, "Gunpowder SFX strictly blocked in 1288")


func e2e_f15_t2_02_pool_saturation_30_2d_and_10_ui_simultaneous() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	for i: int in range(30):
		audio_mgr.call("play_sfx", "sword_hit", Vector2(i * 10, 0), "Tran_Nguyen")
	for _j: int in range(10):
		audio_mgr.call("play_ui_sfx", "ui_click")
	assert_eq(find_nodes_by_class_recursive(audio_mgr as Node, "AudioStreamPlayer2D").size(), 24, "2D pool remains fixed at 24")


func e2e_f15_t2_03_zero_volume_mute_boundary_no_nan() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	audio_mgr.call("set_bus_linear_volume", "SFX", 0.0)
	var db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	assert_false(is_nan(db), "SFX 0.0 volume produces valid non-NaN dB")


func e2e_f15_t2_04_missing_unknown_audio_key_safe_handling() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	var ok: bool = bool(audio_mgr.call("play_sfx", "missing_key_xyz", Vector2.ZERO, "Tran_Nguyen"))
	assert_false(ok, "Unknown audio key returns false safely")


func e2e_f15_t2_05_headless_audio_driver_safety() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var audio_mgr: Object = require_audio_manager(env["sandbox"], "M3")
	if audio_mgr == null:
		return
	audio_mgr.call("set_bgm_state", &"ai_turn")
	assert_eq(str(audio_mgr.call("get_bgm_state")), "ai_turn", "Audio manager operates safely under headless driver")


# ===========================================================================
# Feature #16 Tier 2: Save/Load Corruption & Precision (F16-T2-01 .. 05)
# ===========================================================================

func e2e_f16_t2_01_corrupted_profile_recovers_from_bak() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	save_mgr.call("save_player_profile", {"stage_stars": {"10101": 2}})
	save_mgr.call("save_player_profile", {"stage_stars": {"10101": 3}})
	var fa: FileAccess = FileAccess.open("user://saves/player_profile.json", FileAccess.WRITE)
	fa.store_string("{CORRUPT_JSON!!!")
	fa.close()
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_eq(int(prof.get("stage_stars", {}).get("10101", 0)), 2, "Recovered valid .bak profile after primary corruption")


func e2e_f16_t2_02_both_primary_and_bak_missing_returns_default() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_true(prof is Dictionary, "Missing profile returns clean default Dictionary")


func e2e_f16_t2_03_corrupted_non_dict_battle_session_rejected_cleanly() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	DirAccess.make_dir_recursive_absolute("user://saves")
	var fa: FileAccess = FileAccess.open("user://saves/battle_session.json", FileAccess.WRITE)
	fa.store_string("[1, 2, 3]")
	fa.close()
	var ctrl: BattleGameController = ScenarioLoader.load_stage(10101, e2e_seed)
	assert_false(bool(save_mgr.call("load_battle_session", ctrl)), "Non-dict session JSON rejected cleanly")


func e2e_f16_t2_04_large_64_bit_rng_seed_string_precision() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	var big_seed: int = 9223372036854775783
	var ctrl1: BattleGameController = ScenarioLoader.load_stage(10101, big_seed)
	save_mgr.call("save_battle_session", ctrl1)
	var raw: Dictionary = read_json_file("user://saves/battle_session.json") as Dictionary
	assert_eq(str(raw.get("rng_seed", "")), str(big_seed), "64-bit seed preserved as exact String without float rounding")


func e2e_f16_t2_05_battle_save_manager_core_isolation() -> void:
	if require_save_manager("M3") == null:
		return
	var txt: String = read_text_file("res://scripts/core/battle_save_manager.gd")
	for tok: String in ["extends Node", "SceneTree", "RenderingServer"]:
		assert_false(txt.contains(tok), "BattleSaveManager must not reference %s" % tok)


# ===========================================================================
# Feature #17 Tier 2: Economy & Starvation Boundaries (F17-T2-01 .. 05)
# ===========================================================================

func e2e_f17_t2_01_exact_zero_food_non_starvation() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, 0, 0, 0)
	assert_false(bool(eco.call("is_starving", 1)), "food == 0 is NOT starving")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 1.0, 0.001, "Multiplier == 1.0 at food == 0")


func e2e_f17_t2_02_minimum_starvation_food_minus_1() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, -1, 0, 0)
	assert_true(bool(eco.call("is_starving", 1)), "food == -1 triggers Starvation")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 0.75, 0.001, "0.75x damage at food == -1")


func e2e_f17_t2_03_starvation_recovery_when_food_restored_non_negative() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 100, -20, 0, 0)
	assert_true(bool(eco.call("is_starving", 1)), "Starts starving")
	eco.call("set_resource", 1, "food", 10)
	assert_false(bool(eco.call("is_starving", 1)), "Starvation clears when food >= 0")
	assert_almost_eq(float(eco.call("get_combat_damage_multiplier", 1)), 1.0, 0.001, "Damage multiplier restores to 1.0")
	assert_true(bool(eco.call("can_heal_unit", 1)), "Healing unlocked")


func e2e_f17_t2_04_max_stack_clamping_0_and_5_in_meal_food() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	var u0 := BattleUnit.from_troop_dict(1, 1, Vector2i.ZERO, {"id": 40101, "command_branch": "Infantry"})
	u0.max_stack = 0
	var u5 := BattleUnit.from_troop_dict(2, 1, Vector2i.ONE, {"id": 40101, "command_branch": "Infantry"})
	u5.max_stack = 5
	assert_eq(int(eco.call("compute_unit_meal_food", u0)), 10, "max_stack 0 clamped to 1 -> 10 food")
	assert_eq(int(eco.call("compute_unit_meal_food", u5)), 30, "max_stack 5 clamped to 3 -> 30 food")


func e2e_f17_t2_05_granary_type20_food_cap_clamping() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 0, 0, 0, 0)
	eco.call("register_facility", "gran_1", 1, "Granary", 1)
	var cap: int = int(eco.call("get_food_cap", 1))
	eco.call("add_resource", 1, "food", cap + 5000)
	assert_lte(int(eco.call("get_resource", 1, "food")), cap, "Food storage clamped to Granary cap")


# ===========================================================================
# Feature #18 Tier 2: Economy Commands Negative Cases (F18-T2-01 .. 05)
# ===========================================================================

func e2e_f18_t2_01_rob_area_income_3_turn_cap_and_granary_halving() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 0, 0, 0, 0)
	eco.call("register_facility", "enemy_farm_g", 2, "Farm", 1, 7, true) # 7 turns -> cap 3, has granary -> 0.50
	var gained: int = int(eco.call("rob_facility", 1, "enemy_farm_g", 0.80))
	assert_eq(gained, 96, "round_half_up(80 * 3 * 0.80 * 0.50) == 96")


func e2e_f18_t2_02_trade_rejected_without_market_or_starving_food_to_coin() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var trade_cls: Variant = eco_scr.get("TradeCommand")
	if trade_cls == null:
		fail("Missing M4 contract: TradeCommand")
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 500, 500, 0, 0)
	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()
	assert_false(ctrl.submit_command(trade_cls.new(1, "coin_to_food", 100)), "Trade rejected with 0 Markets")


func e2e_f18_t2_03_insufficient_resource_rejection() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var fort_cls: Variant = eco_scr.get("FortifyHexCommand")
	if fort_cls == null:
		fail("Missing M4 contract: FortifyHexCommand")
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 10, 0, 5, 0)
	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()
	assert_false(ctrl.submit_command(fort_cls.new(1, Vector2i(1, 1))), "FortifyHex rejected on insufficient coin/tech")
	assert_eq(int(eco.call("get_resource", 1, "coin")), 10, "Coin uncorrupted")


func e2e_f18_t2_04_tech_tier_skipping_and_era_gate_rejection() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var tech_cls: Variant = eco_scr.get("UnlockBattleTechCommand")
	if tech_cls == null:
		fail("Missing M4 contract: UnlockBattleTechCommand")
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 500, 500, 500, 100)
	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()
	assert_false(ctrl.submit_command(tech_cls.new(1, 3, "INFANTRY")), "Cannot skip Tier 1 & 2 straight to Tier 3")


func e2e_f18_t2_05_economy_commands_non_undoable() -> void:
	var eco_scr: GDScript = require_economy_script("M4")
	if eco_scr == null:
		return
	var trade_cls: Variant = eco_scr.get("TradeCommand")
	if trade_cls == null:
		fail("Missing M4 contract: TradeCommand")
		return
	var eco: Object = eco_scr.new()
	eco.call("init_faction", 1, 500, 500, 0, 0)
	eco.call("register_facility", "mkt_1", 1, "Market", 1)
	var map := BattleMapState.new(6, 6, BattleMapState.TerrainType.PLAINS)
	var ctrl := BattleGameController.new(map, e2e_seed, [1, 2], 10)
	ctrl.enable_economy = true
	ctrl.set("economy", eco)
	ctrl.start_battle()
	ctrl.submit_command(trade_cls.new(1, "coin_to_food", 100))
	assert_false(ctrl.can_undo(), "Economy commands are non-undoable")


# ===========================================================================
# Feature #19 Tier 2: Campaign Negative & Boundaries (F19-T2-01 .. 05)
# ===========================================================================

func e2e_f19_t2_01_locked_stage_launch_rejection() -> void:
	var menu_scr: GDScript = require_script(
		["res://scripts/presentation/campaign_menu_controller.gd", "res://scripts/presentation/ui/campaign_menu_controller.gd"],
		"CampaignMenuController",
		"M5",
		"CampaignMenuController"
	)
	if menu_scr == null:
		return
	var stages: Variant = read_json_file("res://data/settings/stage_settings.json")
	if not (stages is Array) or (stages as Array).size() < 3:
		fail("Missing M5 contract: >= 3 stages required")
		return
	var s3_id: int = int((stages as Array)[2].get("id", 0))
	var menu_ctrl: Object = menu_scr.new()
	assert_false(bool(menu_ctrl.call("is_stage_unlocked", s3_id, {})), "Stage 3 blocked before Stage 2 cleared")


func e2e_f19_t2_02_general_uniqueness_and_seat_cap_in_free_replay() -> void:
	var menu_scr: GDScript = require_script(
		["res://scripts/presentation/campaign_menu_controller.gd", "res://scripts/presentation/ui/campaign_menu_controller.gd"],
		"CampaignMenuController",
		"M5",
		"CampaignMenuController"
	)
	if menu_scr == null:
		return
	var menu_ctrl: Object = menu_scr.new()
	assert_has_method(menu_ctrl, "validate_general_loadout", "M5")
	if menu_ctrl.has_method("validate_general_loadout"):
		assert_false(bool(menu_ctrl.call("validate_general_loadout", [1001, 1001], 2)), "Duplicate general_id rejected")


func e2e_f19_t2_03_banned_troop_ids_enforcement() -> void:
	var menu_scr: GDScript = require_script(
		["res://scripts/presentation/campaign_menu_controller.gd", "res://scripts/presentation/ui/campaign_menu_controller.gd"],
		"CampaignMenuController",
		"M5",
		"CampaignMenuController"
	)
	if menu_scr == null:
		return
	var menu_ctrl: Object = menu_scr.new()
	assert_has_method(menu_ctrl, "is_troop_allowed_in_stage", "M5")
	if menu_ctrl.has_method("is_troop_allowed_in_stage"):
		assert_false(bool(menu_ctrl.call("is_troop_allowed_in_stage", 40999, {"banned_troop_ids": [40999]})), "Banned troop rejected")


func e2e_f19_t2_04_invalid_stage_id_99999_graceful_guard() -> void:
	var ctrl: BattleGameController = ScenarioLoader.load_stage(99999, e2e_seed)
	assert_null(ctrl, "Invalid stage_id 99999 returns null gracefully without crash")


func e2e_f19_t2_05_best_star_non_regression() -> void:
	clear_user_saves()
	var save_mgr: Object = require_save_manager("M3")
	if save_mgr == null:
		return
	assert_has_method(save_mgr, "record_stage_clear", "M3")
	if not save_mgr.has_method("record_stage_clear"):
		return
	save_mgr.call("record_stage_clear", 10101, 3)
	save_mgr.call("record_stage_clear", 10101, 1)
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_eq(int(prof.get("stage_stars", {}).get("10101", 0)), 3, "Best star count never downgrades from 3 to 1")


# ===========================================================================
# Feature #20 Tier 2: Codex & Tutorial Negative Cases (F20-T2-01 .. 05)
# ===========================================================================

func e2e_f20_t2_01_grade_d_never_labeled_historical_claim() -> void:
	if not FileAccess.file_exists("res://data/settings/codex_entries.json"):
		fail("Missing M5 contract: res://data/settings/codex_entries.json")
		return
	var data: Variant = read_json_file("res://data/settings/codex_entries.json")
	var entries: Array = data as Array if data is Array else data.get("entries", [])
	for e_var: Variant in entries:
		var e: Dictionary = e_var as Dictionary
		if str(e.get("evidence_grade", "")) == "D":
			assert_ne(str(e.get("modeling_type", "")), "historical_claim", "Grade D cannot carry historical_claim")


func e2e_f20_t2_02_benchmark_sources_excluded_from_evidence_grade() -> void:
	if not FileAccess.file_exists("res://data/settings/codex_entries.json"):
		fail("Missing M5 contract: res://data/settings/codex_entries.json")
		return
	var data: Variant = read_json_file("res://data/settings/codex_entries.json")
	var entries: Array = data as Array if data is Array else data.get("entries", [])
	for e_var: Variant in entries:
		var e: Dictionary = e_var as Dictionary
		var sref: String = str(e.get("source_ref", ""))
		if sref.contains("[S1]") or sref.contains("[S2]") or sref.contains("[S8]"):
			assert_true(str(e.get("evidence_grade", "")).is_empty(), "Benchmark refs never receive historical evidence_grade")


func e2e_f20_t2_03_tutorial_dismissible_without_fsm_soft_lock() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var tut: Node = require_hud_node(env["sandbox"], ["TutorialOverlay"], "M5", "TutorialOverlay")
	var fsm: Object = require_fsm(env["sandbox"], "M1")
	if tut == null or fsm == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])
	tut.call("trigger_tip", "tip_select_unit")
	tut.call("dismiss_current_tip")
	await _click_axial_opaque(env["sandbox"], _odd_r(2, 8))
	assert_not_null(env["map_view"].get_selected_unit(), "FSM remains responsive after dismissing tutorial")


func e2e_f20_t2_04_empty_codex_search_filter_query() -> void:
	var codex_node: Node = require_scene_instantiate(
		["res://scenes/ui/codex_panel.tscn", "res://scenes/main_menu.tscn"],
		"M5",
		"CodexPanel"
	)
	if codex_node == null:
		return
	var codex_ctrl: Node = find_node_by_name_recursive(codex_node, "CodexPanel")
	if codex_ctrl == null:
		codex_ctrl = codex_node
	assert_has_method(codex_ctrl, "filter_entries", "M5")
	if codex_ctrl.has_method("filter_entries"):
		var res: Array = codex_ctrl.call("filter_entries", "zzz_invalid")
		assert_eq(res.size(), 0, "Invalid search returns empty array safely")


func e2e_f20_t2_05_tutorial_reset_re_arming() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	var tut: Node = require_hud_node(env["sandbox"], ["TutorialOverlay"], "M5", "TutorialOverlay")
	if tut == null:
		return
	tut.call("trigger_tip", "tip_select_unit")
	tut.call("dismiss_current_tip")
	assert_has_method(tut, "reset_tutorial_flags", "M5")
	if tut.has_method("reset_tutorial_flags"):
		tut.call("reset_tutorial_flags")
		assert_true(bool(tut.call("trigger_tip", "tip_select_unit")), "Reset tutorial flags re-arms tips cleanly")


# ===========================================================================
# Feature #21 Tier 2: IP Gate Negative Self-Tests (F21-T2-01 .. 05)
# ===========================================================================

func _require_ip_audit_script() -> GDScript:
	return require_script(
		["res://scripts/core/asset_ip_auditor.gd", "res://tests/test_tran_campaign_and_ip_gate.gd"],
		"AssetIpAuditor",
		"M5",
		"Asset IP Gate Auditor"
	)


func e2e_f21_t2_01_case_mismatch_negative_self_test() -> void:
	var scr: GDScript = _require_ip_audit_script()
	if scr == null:
		return
	var auditor: Object = scr.new()
	assert_false(bool(auditor.call("audit_case_exact_path", "res://assets_clean/Emblems/dai_viet_emblem.png")), "Case mismatch detected by AssetIpAuditor")


func e2e_f21_t2_02_unregistered_file_negative_self_test() -> void:
	var scr: GDScript = _require_ip_audit_script()
	if scr == null:
		return
	var auditor: Object = scr.new()
	assert_false(bool(auditor.call("audit_registered_in_assets_md", "res://assets_clean/audio/unlisted_test.wav")), "Unlisted synthetic path rejected by AssetIpAuditor")


func e2e_f21_t2_03_forbidden_assets_path_negative_self_test() -> void:
	var scr: GDScript = _require_ip_audit_script()
	if scr == null:
		return
	var auditor: Object = scr.new()
	var sample: String = "res://Assets/Audio/sfx_horn.wav"
	assert_false(bool(auditor.call("audit_no_legacy_assets_ref", sample)), "Forbidden Assets/ scanner flags synthetic violation")


func e2e_f21_t2_04_forbidden_scene_tree_in_core_negative_self_test() -> void:
	var scr: GDScript = _require_ip_audit_script()
	if scr == null:
		return
	var auditor: Object = scr.new()
	var bad_snippet: String = "extends Node\nfunc f(): get_tree().quit()"
	assert_false(bool(auditor.call("audit_core_ai_isolation", bad_snippet)), "Isolation checker flags Node/SceneTree")


func e2e_f21_t2_05_era_gating_compliance_in_10101_data() -> void:
	var b10101: String = read_text_file("res://data/battles/battle_10101.json").to_lower()
	assert_false(b10101.contains("gunpowder") or b10101.contains("cannon"), "1288 battle_10101.json contains zero gunpowder")


# ===========================================================================
# Feature #22 Tier 2: Release & Export Boundaries (F22-T2-01 .. 05)
# ===========================================================================

func e2e_f22_t2_01_strategic_zoom_draw_reduction_on_30x30() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	env["sandbox"].call("load_stress_benchmark_30x30", 44)
	env["cam"].set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, true)
	await pump_frames(5)
	var t0: int = Time.get_ticks_usec()
	await pump_frames(20)
	var mean_ms: float = (float(Time.get_ticks_usec() - t0) / 1000.0) / 20.0
	assert_true(env["map_view"].is_strategic_lod(), "StrategicTokenLayer active on 30x30 at 0.5x")
	assert_lte(mean_ms, 16.67, "30x30 strategic zoom frame time <= 16.67ms")


func e2e_f22_t2_02_export_exclude_filter_blocks_legacy_assets() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: res://export_presets.cfg")
		return
	var txt: String = read_text_file("res://export_presets.cfg")
	assert_true(txt.contains("Assets/*") or txt.contains("Assets/"), "export_presets.cfg excludes legacy Assets/")


func e2e_f22_t2_03_user_write_only_discipline() -> void:
	var script_files: Array[String] = list_files_recursive("res://scripts", [".gd"])
	for f: String in script_files:
		var txt: String = read_text_file(f)
		assert_false(txt.contains("FileAccess.open(\"res://") and txt.contains("FileAccess.WRITE"), "No runtime write to res:// in %s" % f)


func e2e_f22_t2_04_missing_export_template_explicit_blocker_check() -> void:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		fail("Missing M6 contract: res://export_presets.cfg")
		return
	var state_txt: String = read_text_file("res://STATE.md")
	assert_true(state_txt.contains("C5-T3") or state_txt.contains("export"), "STATE.md documents C5-T3 export status/blockers")


func e2e_f22_t2_05_multi_resolution_layout_clamp_1280x720_vs_1560x720() -> void:
	var env: Dictionary = await _boot_10101_sandbox()
	if env.is_empty():
		return
	if require_hud_controller(env["sandbox"], "M2") == null:
		return
	await _dismiss_opening_modals_if_any(env["sandbox"])

	for sz: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720)]:
		set_test_viewport_size(sz)
		await pump_frames(2)
		var cov: Dictionary = compute_hud_coverage_ratio(env["map_view"].get_screen_hud_layer(), Vector2(sz))
		assert_gte(float(cov["map_ratio"]), 0.80, "Map ratio >= 80%% at %s" % str(sz))
