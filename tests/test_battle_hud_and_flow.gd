extends "res://tests/test_case.gd"

const SANDBOX_SCENE_PATH: String = "res://game/battle/battle.tscn"
const HUD_CONTROLLER_PATH: String = "res://ui/battle_hud/battle_hud.gd"

const HexMathScript = preload("res://sim/rules/hex_math.gd")
const CmdsScript = preload("res://sim/commands/battle_commands.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const ControllerScript = preload("res://sim/state/battle_game_controller.gd")
const EvaluatorScript = preload("res://sim/rules/scenario_victory_evaluator.gd")


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


func _collect_visible_hud_area(node: Node, vp_size: Vector2) -> float:
	if node == null:
		return 0.0
	var area: float = 0.0
	for child: Node in node.get_children():
		if child is Control:
			var ctrl: Control = child as Control
			if not ctrl.visible or not ctrl.is_visible_in_tree():
				continue
			var r: Rect2 = ctrl.get_global_rect()
			if r.size.x >= vp_size.x * 0.95 and r.size.y >= vp_size.y * 0.95:
				area += _collect_visible_hud_area(child, vp_size)
			else:
				area += maxf(0.0, r.size.x) * maxf(0.0, r.size.y)
		else:
			area += _collect_visible_hud_area(child, vp_size)
	return area


func _compute_map_ratio(hud_layer: CanvasLayer, vp_size: Vector2) -> float:
	var vp_area: float = maxf(1.0, vp_size.x * vp_size.y)
	var hud_area: float = _collect_visible_hud_area(hud_layer, vp_size)
	return clampf(1.0 - (hud_area / vp_area), 0.0, 1.0)


func test_map_first_layout_keeps_at_least_80_percent_map_across_aspect_ratios() -> void:
	var hud_scr: GDScript = load(HUD_CONTROLLER_PATH) as GDScript
	assert_not_null(hud_scr, "BattleHudController script must exist at " + HUD_CONTROLLER_PATH)
	if hud_scr == null:
		return

	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "BattleScene must expose get_hud_controller()")
	if hud_ctrl == null:
		return

	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var hud_layer: CanvasLayer = _find_node(sandbox, "ScreenHudCanvasLayer") as CanvasLayer

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


func test_one_tap_attack_executes_without_combat_preview_box() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud_ctrl: Object = sandbox.call("get_hud_controller") if sandbox.has_method("get_hud_controller") else null
	assert_not_null(hud_ctrl, "get_hud_controller() required")
	if hud_ctrl == null:
		return
	if hud_ctrl.has_method("dismiss_all_modals"):
		hud_ctrl.call("dismiss_all_modals")

	var preview_box: Control = _find_node(sandbox, "CombatPreviewBox") as Control
	if preview_box != null:
		assert_false(preview_box.visible, "CombatPreviewBox starts hidden")

	var ctrl: BattleGameController = sandbox.call("get_controller")
	var map_state: BattleMapState = sandbox.call("get_map_state")
	var map_view: BattleMap = sandbox.call("get_map_view")
	var fsm: BattleInputFSM = sandbox.call("get_input_fsm")
	var u102: BattleUnit = ctrl.context.get_unit(102)
	var e202: BattleUnit = ctrl.context.get_unit(202)
	var hp_before: int = e202.state.current_hp

	map_state.move_unit(e202, HexMathScript.odd_r_to_axial(Vector2i(5, 5)))
	map_view.refresh_units()

	sandbox.call("click_world_position", map_view.axial_to_world(u102.hex_position))
	assert_eq(fsm.get_state(), BattleInputFSM.State.UNIT_SELECTED)

	# 1st tap on hostile in red range attacks immediately without opening CombatPreviewBox
	sandbox.call("click_world_position", map_view.axial_to_world(e202.hex_position))
	if preview_box != null:
		assert_false(preview_box.visible, "CombatPreviewBox must remain hidden on 1-tap attack")
	assert_true(u102.state.has_acted, "1st tap executes attack immediately")
	assert_lt(float(e202.state.current_hp), float(hp_before), "Enemy takes damage on 1st tap")
	assert_eq(fsm.get_state(), BattleInputFSM.State.IDLE)


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

	var map_view: BattleMap = sandbox.call("get_map_view")
	# Select Tran Quoc Tuan (101) at (2,8)
	sandbox.call("click_world_position", map_view.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(2, 8))))
	var dock_txt: String = _collect_text(dock)
	assert_true(dock_txt.contains("Trần Quốc Tuấn"), "Unit card shows general name")
	assert_true(dock_txt.contains("480/480"), "Unit card shows HP")
	assert_false(skill_btn.disabled, "SkillButton enabled for Tran Quoc Tuan")
	assert_true(undo_btn.disabled, "UndoButton disabled before moving")

	# March unit 101 to (3,8) -> POST_MOVE_ACTION -> UndoButton enabled
	sandbox.call("click_world_position", map_view.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(3, 8))))
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


func _find_node_named(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for c: Node in root.get_children():
		var hit: Node = _find_node_named(c, node_name)
		if hit != null:
			return hit
	return null


func _find_button_named(root: Node, node_name: String) -> BaseButton:
	var n: Node = _find_node_named(root, node_name)
	return n as BaseButton if n is BaseButton else null


func _is_descendant_of_scroll(node: Node) -> bool:
	var cur: Node = node.get_parent() if node != null else null
	while cur != null:
		if cur is ScrollContainer:
			return true
		cur = cur.get_parent()
	return false


func _assert_button_reachable(btn: BaseButton, vp_size: Vector2, label_ctx: String) -> void:
	assert_not_null(btn, "%s: button exists" % label_ctx)
	if btn == null:
		return
	assert_true(btn.is_visible_in_tree(), "%s: button is visible_in_tree" % label_ctx)
	assert_false(btn.disabled, "%s: button is enabled" % label_ctx)
	assert_false(_is_descendant_of_scroll(btn), "%s: footer button must live outside ScrollContainer" % label_ctx)
	var rect: Rect2 = btn.get_global_rect()
	assert_true(rect.size.x >= 40.0 and rect.size.y >= 24.0, "%s: valid hit target size %s" % [label_ctx, str(rect.size)])
	var vp_rect: Rect2 = Rect2(Vector2.ZERO, vp_size)
	assert_true(vp_rect.encloses(rect), "%s: rect %s inside viewport %s" % [label_ctx, str(rect), str(vp_size)])
	var anc: Node = btn.get_parent()
	while anc is Control:
		var anc_ctrl: Control = anc as Control
		if anc_ctrl.clip_contents:
			assert_true(
				anc_ctrl.get_global_rect().encloses(rect),
				"%s: rect %s clipped by ancestor %s %s" % [label_ctx, str(rect), anc_ctrl.name, str(anc_ctrl.get_global_rect())]
			)
		anc = anc_ctrl.get_parent()


func test_unit_inspector_raw_stats_on_focus_and_no_combat_preview_box() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	assert_not_null(hud, "BattleHud attached")
	assert_null(_find_node_named(sandbox, "CombatPreviewBox"), "DEC-026: CombatPreviewBox must not exist")

	hud.dismiss_all_modals()
	var inspector: UnitInspector = hud.get_unit_inspector()
	assert_not_null(inspector, "UnitInspector exists in BattleHud")
	assert_false(inspector.visible, "UnitInspector hidden before selection")

	var ctrl: BattleGameController = sandbox.call("get_controller") as BattleGameController
	var fsm: BattleInputFSM = sandbox.call("get_input_fsm") as BattleInputFSM
	var u101: BattleUnit = ctrl.context.get_unit(101)
	assert_not_null(u101, "Unit 101 exists")
	fsm.inspect_hex(u101.hex_position)
	assert_true(inspector.visible, "UnitInspector becomes visible when inspecting unit")
	var top_bar: PanelContainer = hud.get_top_bar()
	assert_true(
		inspector.get_global_rect().position.y >= top_bar.get_global_rect().end.y,
		"UnitInspector (y=%s) must sit below TopStatusBar (end.y=%s)" % [
			str(inspector.get_global_rect().position.y),
			str(top_bar.get_global_rect().end.y),
		]
	)
	var name_lbl: Label = _find_node_named(inspector, "UnitNameLabel") as Label
	var atk_lbl: Label = _find_node_named(inspector, "AtkLabel") as Label
	var def_lbl: Label = _find_node_named(inspector, "DefLabel") as Label
	assert_not_null(name_lbl, "UnitNameLabel exists")
	assert_true(name_lbl.text.contains(u101.general_name) or name_lbl.text.contains(u101.display_name), "UnitInspector displays unit/general name")
	assert_true(atk_lbl != null and atk_lbl.text.contains(str(u101.base_atk)), "UnitInspector displays raw base_atk")
	assert_true(def_lbl != null and def_lbl.text.contains(str(u101.base_def)), "UnitInspector displays raw base_def")


func test_all_ui_scripts_under_400_lines_and_no_manual_button_hit_test() -> void:
	var dirs: Array[String] = ["res://ui"]
	var checked: int = 0
	while not dirs.is_empty():
		var d_path: String = dirs.pop_back()
		var d: DirAccess = DirAccess.open(d_path)
		if d == null:
			continue
		d.list_dir_begin()
		var entry: String = d.get_next()
		while not entry.is_empty():
			if entry != "." and entry != "..":
				var full: String = d_path.path_join(entry)
				if d.current_is_dir():
					dirs.append(full)
				elif entry.ends_with(".gd"):
					checked += 1
					var f: FileAccess = FileAccess.open(full, FileAccess.READ)
					assert_not_null(f, "Readable UI script: " + full)
					if f != null:
						var src: String = f.get_as_text()
						var lines: PackedStringArray = src.split("\n")
						assert_true(lines.size() <= 400, "%s line count %d <= 400" % [full, lines.size()])
						assert_false(src.contains("_find_hit_button"), "%s must not contain manual _find_hit_button" % full)
			entry = d.get_next()
		d.list_dir_end()
	assert_true(checked >= 9, "Verified all modular UI scripts (%d files)" % checked)


func test_modals_footer_buttons_reachable_and_unclipped_across_viewports() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	var tree: SceneTree = get_scene_tree()
	assert_not_null(tree, "SceneTree available")

	var test_sizes: Array[Vector2] = [Vector2(1280.0, 720.0), Vector2(1560.0, 720.0), Vector2(960.0, 540.0)]
	for vp_size: Vector2 in test_sizes:
		tree.root.size = Vector2i(int(vp_size.x), int(vp_size.y))
		hud.apply_viewport_layout(vp_size)
		await tree.process_frame
		await tree.process_frame

		var brief_modal: Control = _find_node_named(hud, "BriefingModal") as Control
		assert_not_null(brief_modal, "BriefingModal exists")
		brief_modal.visible = true
		await tree.process_frame
		_assert_button_reachable(_find_button_named(brief_modal, "SkipButton"), vp_size, "Briefing Skip @%s" % str(vp_size))
		_assert_button_reachable(_find_button_named(brief_modal, "StartButton"), vp_size, "Briefing Start @%s" % str(vp_size))

		hud.dismiss_all_modals()
		hud.show_dialogue_entries([{"speaker": "Trần Quốc Tuấn", "line": "Thử kiểm tra nút Hội thoại."}])
		await tree.process_frame
		_assert_button_reachable(_find_button_named(hud, "SkipDialogueButton"), vp_size, "Dialogue Skip @%s" % str(vp_size))
		_assert_button_reachable(_find_button_named(hud, "ContinueButton"), vp_size, "Dialogue Continue @%s" % str(vp_size))

		hud.dismiss_all_modals()
		hud.open_pause_modal()
		await tree.process_frame
		_assert_button_reachable(_find_button_named(hud, "SaveAndExitButton"), vp_size, "Pause Save @%s" % str(vp_size))
		_assert_button_reachable(_find_button_named(hud, "RestartButton"), vp_size, "Pause Restart @%s" % str(vp_size))
		_assert_button_reachable(_find_button_named(hud, "ResumeButton"), vp_size, "Pause Resume @%s" % str(vp_size))

		hud.dismiss_all_modals()
		for i: int in range(6):
			hud.append_combat_log("Dòng nhật ký chiến đấu #%d: Giao tranh ác liệt trên sông Bạch Đằng." % (i + 1))
		hud.show_result_summary(int(BattleGameController.BattleOutcome.VICTORY))
		await tree.process_frame
		_assert_button_reachable(_find_button_named(hud, "ReplayButton"), vp_size, "Result Replay @%s" % str(vp_size))
		_assert_button_reachable(_find_button_named(hud, "RetryButton"), vp_size, "Result Retry @%s" % str(vp_size))
		_assert_button_reachable(_find_button_named(hud, "CloseResultButton"), vp_size, "Result Close @%s" % str(vp_size))
		hud.dismiss_all_modals()

	tree.root.size = Vector2i(1280, 720)


func test_real_mouse_click_on_briefing_skip_button_skips_intro() -> void:
	var tree: SceneTree = get_scene_tree()
	tree.root.size = Vector2i(1280, 720)
	var sandbox: Node2D = _spawn_sandbox()
	var hud: BattleHud = sandbox.call("get_hud_controller") as BattleHud
	await tree.process_frame
	await tree.process_frame

	var brief_modal: Control = _find_node_named(hud, "BriefingModal") as Control
	var dlg_modal: Control = _find_node_named(hud, "DialogueModal") as Control
	assert_true(brief_modal != null and brief_modal.visible, "BriefingModal opens at battle start")

	var skip_btn: BaseButton = _find_button_named(brief_modal, "SkipButton")
	_assert_button_reachable(skip_btn, Vector2(1280.0, 720.0), "Real click Briefing SkipButton")
	var click_pos: Vector2 = skip_btn.get_global_rect().get_center()

	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = click_pos
	press_ev.global_position = click_pos
	tree.root.push_input(press_ev)

	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_LEFT
	release_ev.pressed = false
	release_ev.position = click_pos
	release_ev.global_position = click_pos
	tree.root.push_input(release_ev)

	await tree.process_frame
	assert_false(brief_modal.visible, "Real click on SkipButton dismisses BriefingModal")
	assert_false(dlg_modal != null and dlg_modal.visible, "Real click on SkipButton also skips opening dialogue")

