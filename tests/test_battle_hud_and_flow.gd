extends "res://tests/test_case.gd"

const SANDBOX_SCENE_PATH: String = "res://scenes/battle/battle_sandbox_cp1.tscn"
const HUD_CONTROLLER_PATH: String = "res://scripts/presentation/battle_hud_controller.gd"

const HexMathScript = preload("res://scripts/core/hex_math.gd")
const CmdsScript = preload("res://scripts/core/battle_commands.gd")
const UnitStateScript = preload("res://scripts/core/unit_combat_state.gd")
const ControllerScript = preload("res://scripts/core/battle_game_controller.gd")
const EvaluatorScript = preload("res://scripts/core/scenario_victory_evaluator.gd")


func _spawn_sandbox() -> Node2D:
	var packed: PackedScene = load(SANDBOX_SCENE_PATH) as PackedScene
	assert_not_null(packed, "Sandbox scene must exist at " + SANDBOX_SCENE_PATH)
	if packed == null:
		return null
	var inst: Node2D = packed.instantiate() as Node2D
	add_child_autofree(inst)
	return inst


func _find_node(root_node: Node, target_name: String) -> Node:
	if root_node == null:
		return null
	if str(root_node.name).to_lower() == target_name.to_lower():
		return root_node
	for child: Node in root_node.get_children():
		var hit: Node = _find_node(child, target_name)
		if hit != null:
			return hit
	return null


func _collect_text(root_node: Node) -> String:
	if root_node == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if root_node is Label and (root_node as Label).visible:
		parts.append((root_node as Label).text)
	elif root_node is RichTextLabel and (root_node as RichTextLabel).visible:
		parts.append((root_node as RichTextLabel).text)
	for child: Node in root_node.get_children():
		var sub: String = _collect_text(child)
		if not sub.is_empty():
			parts.append(sub)
	return "\n".join(parts)


func _compute_map_ratio(hud_layer: CanvasLayer, vp_size: Vector2) -> float:
	var vp_area: float = maxf(1.0, vp_size.x * vp_size.y)
	var hud_area: float = 0.0
	if hud_layer != null:
		for child: Node in hud_layer.get_children():
			if child is Control and (child as Control).visible:
				var r: Rect2 = (child as Control).get_global_rect()
				if r.size.x >= vp_size.x * 0.95 and r.size.y >= vp_size.y * 0.95:
					continue
				hud_area += maxf(0.0, r.size.x) * maxf(0.0, r.size.y)
	return clampf(1.0 - (hud_area / vp_area), 0.0, 1.0)


func test_map_first_layout_keeps_at_least_80_percent_map_across_aspect_ratios() -> void:
	var hud_scr: GDScript = load(HUD_CONTROLLER_PATH) as GDScript
	assert_not_null(hud_scr, "BattleHudController script must exist at " + HUD_CONTROLLER_PATH)
	if hud_scr == null:
		return

	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "BattleSandboxCP1 must expose get_hud_controller()")
	if hud_ctrl == null:
		return

	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var map_view: BattleMapView = sandbox.call("get_map_view")
	var hud_layer: CanvasLayer = map_view.get_screen_hud_layer()

	for vp: Vector2 in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(960, 540)]:
		if hud_ctrl.has_method("apply_viewport_layout"):
			hud_ctrl.call("apply_viewport_layout", vp)
		var ratio: float = _compute_map_ratio(hud_layer, vp)
		assert_gte(ratio, 0.80, "Map-First HUD must keep >= 80%% unobstructed map at %s (got %.3f)" % [str(vp), ratio])

		var top_bar: Control = _find_node(hud_layer, "TopStatusBar") as Control
		var bottom_dock: Control = _find_node(hud_layer, "BottomCommandDock") as Control
		assert_not_null(top_bar, "TopStatusBar must exist")
		assert_not_null(bottom_dock, "BottomCommandDock must exist")
		if top_bar != null and bottom_dock != null:
			assert_false(top_bar.get_global_rect().intersects(bottom_dock.get_global_rect()), "TopStatusBar and BottomCommandDock must never overlap")


func test_top_status_bar_hides_economy_when_disabled_and_shows_when_enabled() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return

	var ctrl: BattleGameController = sandbox.call("get_controller")
	var top_bar: Node = _find_node(sandbox, "TopStatusBar")
	assert_not_null(top_bar, "TopStatusBar must exist")
	if top_bar == null:
		return

	assert_false(ctrl.enable_economy, "Stage 10101 has enable_economy == false")
	var eco_box: Control = _find_node(top_bar, "EconomyContainer") as Control
	assert_not_null(eco_box, "EconomyContainer must exist inside TopStatusBar")
	if eco_box != null:
		assert_false(eco_box.visible, "EconomyContainer hidden when enable_economy == false")

	var txt: String = _collect_text(top_bar)
	assert_true(txt.contains("01/10"), "TopStatusBar displays round 01/10")
	assert_true(txt.to_lower().contains("đại việt"), "TopStatusBar displays active faction Đại Việt")

	ctrl.enable_economy = true
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", ctrl)
	if eco_box != null:
		assert_true(eco_box.visible, "EconomyContainer becomes visible when enable_economy == true")

	ctrl.enable_economy = false
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", ctrl)
	if eco_box != null:
		assert_false(eco_box.visible, "EconomyContainer hides again when enable_economy == false")


func test_combat_preview_box_opens_on_first_tap_clamps_to_viewport_and_closes_on_confirm_or_cancel() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var preview_box: Control = _find_node(sandbox, "CombatPreviewBox") as Control
	assert_not_null(preview_box, "CombatPreviewBox node must exist")
	if preview_box == null:
		return
	assert_false(preview_box.visible, "CombatPreviewBox starts hidden")

	var ctrl: BattleGameController = sandbox.call("get_controller")
	var map_state: BattleMapState = sandbox.call("get_map_state")
	var map_view: BattleMapView = sandbox.call("get_map_view")
	var u102: BattleUnit = ctrl.context.get_unit(102)
	var e202: BattleUnit = ctrl.context.get_unit(202)
	var u105: BattleUnit = ctrl.context.get_unit(105)

	# Position E202 between U102 (5,6) and U105 (5,4) for Flank +15%
	map_state.move_unit(e202, HexMathScript.odd_r_to_axial(Vector2i(5, 5)))
	map_state.move_unit(u105, HexMathScript.odd_r_to_axial(Vector2i(5, 4)))
	map_view.refresh_units()

	var expected: Dictionary = ctrl.context.combat_resolver.preview_combat(
		map_state,
		ctrl.context.navigator,
		u102,
		e202
	)

	sandbox.call("click_world_position", HexMathScript.axial_to_world(u102.hex_position, map_view.hex_size))
	sandbox.call("click_world_position", HexMathScript.axial_to_world(e202.hex_position, map_view.hex_size))

	assert_true(preview_box.visible, "CombatPreviewBox opens on 1st tap (AIMING_TARGET)")
	var p_txt: String = _collect_text(preview_box)
	assert_true(p_txt.contains(str(int(expected["min_damage"]))), "Shows expected min_damage")
	assert_true(p_txt.contains(str(int(expected["max_damage"]))), "Shows expected max_damage")
	assert_true(p_txt.contains(str(int(expected["crit_rate"]))), "Shows expected crit_rate")
	assert_true(p_txt.to_lower().contains("bọc sườn") or p_txt.to_lower().contains("flank"), "Shows Flank modifier")

	var vp_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	assert_true(vp_rect.encloses(preview_box.get_global_rect()), "CombatPreviewBox clamped inside viewport")

	# 2nd tap confirms attack and closes CombatPreviewBox
	sandbox.call("click_world_position", HexMathScript.axial_to_world(e202.hex_position, map_view.hex_size))
	assert_false(preview_box.visible, "CombatPreviewBox closes after attack confirmation")


func test_bottom_command_dock_buttons_and_overhead_hud_layers() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var dock: Node = _find_node(sandbox, "BottomCommandDock")
	assert_not_null(dock, "BottomCommandDock must exist")
	if dock == null:
		return

	var move_btn: BaseButton = _find_node(dock, "MoveButton") as BaseButton
	var atk_btn: BaseButton = _find_node(dock, "AttackButton") as BaseButton
	var skill_btn: BaseButton = _find_node(dock, "SkillButton") as BaseButton
	var undo_btn: BaseButton = _find_node(dock, "UndoButton") as BaseButton
	var wait_btn: BaseButton = _find_node(dock, "WaitButton") as BaseButton
	var end_btn: BaseButton = _find_node(dock, "EndTurnButton") as BaseButton

	assert_not_null(move_btn, "MoveButton exists")
	assert_not_null(atk_btn, "AttackButton exists")
	assert_not_null(skill_btn, "SkillButton exists")
	assert_not_null(undo_btn, "UndoButton exists")
	assert_not_null(wait_btn, "WaitButton exists")
	assert_not_null(end_btn, "EndTurnButton exists")

	var map_view: BattleMapView = sandbox.call("get_map_view")
	# Select Tran Quoc Tuan (101) at (2,8)
	sandbox.call("click_world_position", HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(2, 8)), map_view.hex_size))
	var dock_txt: String = _collect_text(dock)
	assert_true(dock_txt.contains("Trần Quốc Tuấn"), "Unit card shows general name")
	assert_true(dock_txt.contains("480/480"), "Unit card shows HP")
	assert_false(skill_btn.disabled, "SkillButton enabled for Tran Quoc Tuan")
	assert_true(undo_btn.disabled, "UndoButton disabled before moving")

	# March unit 101 to (3,8) -> POST_MOVE_ACTION -> UndoButton enabled
	sandbox.call("click_world_position", HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(3, 8)), map_view.hex_size))
	assert_false(undo_btn.disabled, "UndoButton enabled after safe march")
	assert_false(wait_btn.disabled, "WaitButton enabled in POST_MOVE_ACTION")


func test_briefing_modal_scripted_dialogue_camera_lock_and_multi_line_queue() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return

	var briefing: Control = _find_node(sandbox, "BriefingModal") as Control
	var dlg_modal: Control = _find_node(sandbox, "DialogueModal") as Control
	var cam: BattleCameraController = sandbox.call("get_camera")
	assert_not_null(briefing, "BriefingModal exists")
	assert_not_null(dlg_modal, "DialogueModal exists")
	if briefing == null or dlg_modal == null:
		return

	assert_true(briefing.visible, "BriefingModal opens on stage 10101 entry")
	var b_txt: String = _collect_text(briefing).to_lower()
	assert_true(b_txt.contains("bạch đằng"), "Briefing contains stage title")
	assert_true(b_txt.contains("historical_claim"), "Briefing contains modeling_type")

	# Dismiss Briefing -> Opening Dialogue opens and locks camera
	if hud_ctrl.has_method("dismiss_briefing"):
		hud_ctrl.call("dismiss_briefing")
	assert_false(briefing.visible, "BriefingModal closed")
	assert_true(dlg_modal.visible, "Opening dialogue opens after Briefing closes")
	assert_true(cam.camera_locked, "Camera locked while DialogueModal is open")

	if hud_ctrl.has_method("advance_dialogue"):
		hud_ctrl.call("advance_dialogue")
	assert_false(dlg_modal.visible, "DialogueModal closes after single opening line")
	assert_false(cam.camera_locked, "Camera unlocked after dialogue closes")

	# Multi-line dialogue queue & unknown dialogue safety
	hud_ctrl.call("queue_dialogue_id", "unknown_nonexistent_id")
	assert_false(cam.camera_locked, "Unknown dialogue ID must not lock camera")

	hud_ctrl.call("show_dialogue_entries", [
		{"speaker": "Trần Quốc Tuấn", "line": "Câu thoại 1"},
		{"speaker": "Trần Khánh Dư", "line": "Câu thoại 2"},
	])
	assert_true(dlg_modal.visible and cam.camera_locked, "Multi-line dialogue locks camera on line 1")
	hud_ctrl.call("advance_dialogue")
	assert_true(dlg_modal.visible and cam.camera_locked, "Camera stays locked on line 2")
	hud_ctrl.call("advance_dialogue")
	assert_false(dlg_modal.visible or cam.camera_locked, "Camera unlocks after final line")


func test_three_star_victory_summary_all_four_defeat_causes_and_combat_log() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var summary: Control = _find_node(sandbox, "ResultSummaryModal") as Control
	assert_not_null(summary, "ResultSummaryModal exists")
	if summary == null:
		return

	var ctrl: BattleGameController = sandbox.call("get_controller")
	var map_state: BattleMapState = sandbox.call("get_map_state")
	var u102: BattleUnit = ctrl.context.get_unit(102)
	var e201: BattleUnit = ctrl.context.get_unit(201)
	e201.state.current_hp = 1
	map_state.move_unit(e201, HexMathScript.odd_r_to_axial(Vector2i(5, 5)))
	ctrl.submit_command(CmdsScript.AttackCommand.new(1, u102.unit_id, e201.unit_id))

	assert_true(summary.visible, "ResultSummaryModal opens on victory")
	var s_txt: String = _collect_text(summary)
	assert_true(s_txt.contains("3/3"), "3-Star victory displays 3/3")
	var log_node: Node = _find_node(summary, "CombatLogPanel")
	assert_not_null(log_node, "CombatLogPanel exists inside ResultSummaryModal")
	assert_gt(float(_collect_text(log_node).length()), 15.0, "CombatLog records combat actions")

	# Defeat cause 1: LoseKeyArea
	sandbox.call("load_bach_dang_preview_12x10")
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")
	ctrl = sandbox.call("get_controller")
	ctrl.director.set_area_owner("signal_dock", 2)
	ctrl.submit_command(CmdsScript.WaitCommand.new(1, 101))
	assert_true(summary.visible, "Summary opens on LoseKeyArea defeat")
	assert_true(_collect_text(summary).to_lower().contains("losekeyarea"), "Names LoseKeyArea")

	# Defeat cause 2: GeneralDefeated
	sandbox.call("load_bach_dang_preview_12x10")
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")
	ctrl = sandbox.call("get_controller")
	ctrl.context.map_state.remove_unit(101)
	ctrl.submit_command(CmdsScript.WaitCommand.new(1, 102))
	assert_true(_collect_text(summary).to_lower().contains("generaldefeated"), "Names GeneralDefeated")

	# Defeat cause 3: AllUnitsEliminated
	sandbox.call("load_bach_dang_preview_12x10")
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")
	ctrl = sandbox.call("get_controller")
	ctrl.victory_evaluator = EvaluatorScript.new([], [{"type": "AllUnitsEliminated", "faction_id": 1}], [], 1, 10)
	for uid: int in [101, 102, 103, 104, 105]:
		ctrl.context.map_state.remove_unit(uid)
	ctrl.submit_command(CmdsScript.EndTurnCommand.new(1))
	if hud_ctrl.has_method("sync_with_controller"):
		hud_ctrl.call("sync_with_controller", ctrl)
	assert_true(_collect_text(summary).to_lower().contains("allunitseliminated"), "Names AllUnitsEliminated")


func test_pause_settings_modal_shake_scale_reduce_flashing_and_vfx_quality() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var pause_modal: Control = _find_node(sandbox, "PauseSettingsModal") as Control
	assert_not_null(pause_modal, "PauseSettingsModal exists")
	if pause_modal == null:
		return

	var shake_slider: Range = _find_node(pause_modal, "ShakeScaleSlider") as Range
	var flash_check: BaseButton = _find_node(pause_modal, "ReduceFlashingCheck") as BaseButton
	var vfx_opt: OptionButton = _find_node(pause_modal, "VfxQualityOption") as OptionButton
	assert_not_null(shake_slider, "ShakeScaleSlider exists")
	assert_not_null(flash_check, "ReduceFlashingCheck exists")
	assert_not_null(vfx_opt, "VfxQualityOption exists")

	var cam: BattleCameraController = sandbox.call("get_camera")
	shake_slider.value = 0.0
	assert_almost_eq(cam.shake_user_scale, 0.0, 0.01, "ShakeScaleSlider 0 sets camera.shake_user_scale = 0.0")
	shake_slider.value = 100.0
	assert_almost_eq(cam.shake_user_scale, 1.0, 0.01, "ShakeScaleSlider 100 sets camera.shake_user_scale = 1.0")
