class_name BattleScene
extends Node2D
## Editor-First Battle root scene orchestrating BattleSession, BattleMap, Camera2D, InputFSM, VFX/Audio, and BattleHud (`res://game/battle/`).

const TERRAIN_NAMES: Dictionary[int, String] = {
	0: "Đồng bằng (2 MP)",
	1: "Rừng tre (+20% Thủ)",
	2: "Đồi cao (+15% Thủ, Cao điểm)",
	3: "Đầm lầy (-10% Thủ)",
	4: "Sông cạn / Bờ bãi",
	5: "Sông sâu Bạch Đằng",
	6: "Thành lũy (+30% Thủ, CoC x2)",
	7: "Đường cái / Bến thuyền (1 MP)",
	8: "Bãi cọc ngầm lộ diện",
}
const MORALE_NAMES: Dictionary[int, String] = {
	0: "HỖN LOẠN (CHAOS)",
	1: "Dao Động (LOW)",
	2: "Ổn Định",
	3: "Hưng Phấn (HIGH)",
}
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"

@export_group("Scene Nodes")
@export var session: BattleSession
@export var battle_map: BattleMap
@export var camera: BattleCameraController
@export var input_fsm: BattleInputFSM
@export var juice_helper: CombatJuiceHelper
@export var audio_manager: BattleAudioManager
@export var hud_canvas_layer: CanvasLayer
@export var hud: BattleHud

@export_group("Stage Defaults")
@export var initial_stage_id: int = 10101

var _troop_defs: Dictionary[int, Dictionary] = {}
var _map_state: BattleMapState = null
var _controller: BattleGameController = null
var _save_manager: BattleSaveManager = null
var _ai_brain: AIDecisionMatrix = null
var _auto_enemy_ai: bool = true
var _last_event_text: String = ""
var _dialogues: Dictionary = {}
var _mode_label: Label = null
var _selection_label: Label = null
var _perf_label: Label = null
var _current_mode_title: String = ""
var _is_stress_mode: bool = false
var _stress_unit_count: int = 44
var _current_stage_id: int = 10101


func _ready() -> void:
	_troop_defs = StaticDataLoader.load_troop_settings()
	_ai_brain = AIDecisionMatrix.new(AIDifficultyProfile.create_preset(&"normal"))
	_save_manager = BattleSaveManager.new()
	_ensure_wiring()
	var launch_stage_id: int = initial_stage_id
	if get_tree() != null and get_tree().has_meta(&"pending_stage_id"):
		launch_stage_id = int(get_tree().get_meta(&"pending_stage_id"))
		get_tree().remove_meta(&"pending_stage_id")
	load_stage(launch_stage_id)


func _ensure_wiring() -> void:
	if juice_helper != null: juice_helper.setup(battle_map, camera)
	if audio_manager != null: audio_manager.setup()
	if hud != null:
		hud.setup(self, session, battle_map, camera, input_fsm)
		_mode_label = hud.get_mode_label()
		_selection_label = hud.get_selection_label()
		_perf_label = hud.get_perf_label()
		if not hud.save_and_exit_requested.is_connected(_on_hud_save_and_exit):
			hud.save_and_exit_requested.connect(_on_hud_save_and_exit)
	if camera != null:
		if not camera.strategic_lod_changed.is_connected(_on_camera_strategic_lod_changed):
			camera.strategic_lod_changed.connect(_on_camera_strategic_lod_changed)
		if not camera.clean_right_clicked.is_connected(_on_camera_clean_right_clicked):
			camera.clean_right_clicked.connect(_on_camera_clean_right_clicked)
	if battle_map != null and not battle_map.hex_selected.is_connected(_on_hex_selected):
		battle_map.hex_selected.connect(_on_hex_selected)
	if input_fsm != null:
		if not input_fsm.state_changed.is_connected(_on_fsm_state_changed):
			input_fsm.state_changed.connect(_on_fsm_state_changed)
		if not input_fsm.unit_focused.is_connected(_on_fsm_unit_focused):
			input_fsm.unit_focused.connect(_on_fsm_unit_focused)
		if not input_fsm.action_rejected.is_connected(_on_fsm_action_rejected):
			input_fsm.action_rejected.connect(_on_fsm_action_rejected)


func _process(_delta: float) -> void:
	if _perf_label == null or camera == null or _map_state == null or _controller == null:
		return
	var fps: int = Engine.get_frames_per_second()
	var lod_text: String = "TOKEN" if battle_map != null and battle_map.is_strategic_lod() else "MODEL"
	var fac_text: String = "ĐẠI VIỆT" if _controller.current_faction_id == 1 else "ĐẠI NGUYÊN"
	var status_text: String = "LƯỢT: %s" % fac_text
	if _controller.outcome == BattleGameController.BattleOutcome.VICTORY:
		var stars_n: int = int(_controller.victory_evaluator.evaluate_stars(_controller).get("stars", 1)) if _controller.victory_evaluator != null else 1
		status_text = "CHIẾN THẮNG (%d/3 SAO)" % stars_n
	elif _controller.outcome == BattleGameController.BattleOutcome.DEFEAT:
		status_text = "THẤT BẠI"
	if _mode_label != null:
		_mode_label.text = "%s | VÒNG %02d/%02d | %s" % [_current_mode_title, _controller.current_round, _controller.max_rounds, status_text]
	_perf_label.text = "FPS: %d | Zoom: %.2fx [%s] | Quân: %d" % [fps if fps > 0 else 60, camera.zoom.x, lod_text, _map_state.get_all_units().size()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _is_screen_point_on_hud(mb.position):
			click_world_position(get_canvas_transform().affine_inverse() * mb.position)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if not _is_screen_point_on_hud(mm.position) and input_fsm != null and input_fsm.get_state() != BattleInputFSM.State.IDLE:
			hover_world_position(get_canvas_transform().affine_inverse() * mm.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and not _is_screen_point_on_hud(st.position):
			click_world_position(get_canvas_transform().affine_inverse() * st.position)
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			_handle_hotkey(ke.keycode)


func _handle_hotkey(keycode: int) -> void:
	match keycode:
		KEY_F1: load_stage(_current_stage_id)
		KEY_F2: load_stress_benchmark_30x30(44)
		KEY_Z: try_undo_march()
		KEY_W: try_wait_selected()
		KEY_K, KEY_Q: try_enter_skill_targeting()
		KEY_ENTER, KEY_SPACE: end_active_faction_turn()
		KEY_A: run_ai_for_current_faction()
		KEY_R: verify_deterministic_replay_live()
		KEY_T:
			if camera != null: camera.add_trauma(0.45)
		KEY_ESCAPE:
			if hud != null and hud.is_any_modal_open(): hud.close_pause_modal()
			elif input_fsm != null and input_fsm.get_state() != BattleInputFSM.State.IDLE: input_fsm.cancel_or_deselect()
			elif hud != null: hud.toggle_pause_modal()


func load_stage(p_stage_id: int = 10101) -> void:
	_disconnect_controller_signals()
	_is_stress_mode = false
	_last_event_text = ""
	_current_stage_id = p_stage_id
	if battle_map != null:
		battle_map.reset_for_procedural_map()
	var reg: DataRegistry = session.registry if session != null and session.registry != null else StaticDataLoader.load_registry()
	var stage_res: StageDef = reg.get_stage(p_stage_id) if reg != null else null
	if session != null:
		session.registry = reg
		session.stage_def = stage_res
		if not session.start_stage(p_stage_id, BattleFxBridge.DEFAULT_BATTLE_SEED):
			return
		_controller = session.get_controller()
		_dialogues = session.get_stage_dialogues()
	else:
		_controller = ScenarioLoader.load_stage(p_stage_id, BattleFxBridge.DEFAULT_BATTLE_SEED, reg)
		if _controller == null:
			return
		_dialogues = ScenarioLoader.load_stage_dialogues(p_stage_id, reg)

	_map_state = _controller.context.map_state
	_connect_controller_signals()
	var stage_name: String = stage_res.stage_name if stage_res != null and not stage_res.stage_name.is_empty() else "Bạch Đằng 1288"
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ — %s" % stage_name
	_apply_loaded_map()
	var stage_meta: Dictionary = stage_res.to_stage_meta_dict() if stage_res != null else {"id": p_stage_id, "name": stage_name}
	if hud != null:
		hud.set_mode_title(_current_mode_title)
		hud.bind_battle(_controller, stage_meta, _dialogues, true)
	var open_dlg: Dictionary = _dialogues.get("talk_opening_bach_dang", {})
	if not open_dlg.is_empty():
		_set_bottom_banner("[VÒNG 1] %s: \"%s\" | [A] AI đi | [Space] Kết thúc lượt | [R] Replay" % [str(open_dlg.get("speaker", "Tướng lĩnh")), str(open_dlg.get("line", ""))])


func load_bach_dang_preview_12x10() -> void:
	load_stage(10101)


func load_stress_benchmark_30x30(unit_count: int = 44) -> void:
	_disconnect_controller_signals()
	_is_stress_mode = true
	_stress_unit_count = unit_count
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ — Stress 30×30 (%d Quân)" % unit_count
	if battle_map != null:
		battle_map.reset_for_procedural_map()
	_map_state = BattleFxBridge.build_stress_30x30_map(unit_count, _troop_defs)
	_controller = BattleGameController.new(_map_state, BattleFxBridge.DEFAULT_BATTLE_SEED, [1, 3], 30)
	_controller.start_battle()
	_connect_controller_signals()
	if session != null:
		session.stage_def = null
		session.attach_controller(_controller, 99999, {})
	_apply_loaded_map()
	if hud != null:
		hud.set_mode_title(_current_mode_title)
		hud.bind_battle(_controller, {"id": 99999, "name": "Stress 30x30"}, {}, false)


func _apply_loaded_map() -> void:
	if battle_map != null:
		if session != null and not _is_stress_mode:
			battle_map.bind_session(session, _controller.context.navigator)
		else:
			battle_map.bind_battle_state(_map_state, _controller.context.navigator, session.registry if session != null else null, null)
		if camera != null:
			var bounds: Rect2 = battle_map.get_map_world_bounds()
			camera.map_world_bounds = bounds
			camera.set_zoom_level(BattleCameraController.ZOOM_DEFAULT, true)
			camera.pan_to_world_pos(bounds.get_center(), true)
	if input_fsm != null:
		if session != null: input_fsm.bind_session(session, battle_map, camera)
		else: input_fsm.bind(_controller, battle_map, camera)


func click_world_position(world_pos: Vector2) -> void:
	if input_fsm != null: input_fsm.tap_world_position(world_pos)

func hover_world_position(world_pos: Vector2) -> void:
	if input_fsm != null and _controller != null and _map_state != null: input_fsm.hover_world_position(world_pos)

func try_undo_march() -> bool:
	if _controller == null or input_fsm == null: return false
	if input_fsm.request_undo():
		_set_bottom_banner("Đã Hoàn Tác (Undo 1/1) bước di chuyển về ô cũ & hoàn trả đủ MP!")
		return true
	_set_bottom_banner("Không thể Undo (chưa đi / đã hành động / vào ZoC / dính bẫy / đã dùng 1 lần Undo).")
	return false

func try_wait_selected() -> bool:
	if input_fsm == null: return false
	var sel: BattleUnit = input_fsm.get_active_unit()
	if input_fsm.request_wait():
		if sel != null: _set_bottom_banner("Đơn vị [%s] chốt vị trí Đợi." % sel.display_name)
		return true
	return false

func try_enter_skill_targeting() -> bool:
	return input_fsm != null and input_fsm.enter_skill_targeting()

func end_active_faction_turn() -> bool:
	if _controller == null or not _controller.submit_command(BattleCommands.EndTurnCommand.new(_controller.current_faction_id)):
		return false
	if input_fsm != null: input_fsm.sync_with_controller()
	if battle_map != null:
		battle_map.clear_selection()
		battle_map.refresh_all_layers()
	if _auto_enemy_ai and not _is_stress_mode and _controller.outcome == BattleGameController.BattleOutcome.ONGOING and _controller.current_faction_id != _controller.player_faction_id:
		run_ai_for_current_faction()
		return true
	if _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
		var next_fac: String = "Đại Việt" if _controller.current_faction_id == 1 else "Đại Nguyên"
		_set_bottom_banner("Chuyển sang Vòng %d — Lượt của phe %s!" % [_controller.current_round, next_fac])
	return true

func run_ai_for_current_faction() -> Dictionary:
	if _controller == null or _ai_brain == null or _controller.outcome != BattleGameController.BattleOutcome.ONGOING:
		return {}
	var active_fac: int = _controller.current_faction_id
	_last_event_text = ""
	var rep: Dictionary = _ai_brain.execute_faction_turn(_controller, active_fac, _controller.director)
	if input_fsm != null: input_fsm.sync_with_controller()
	if battle_map != null:
		battle_map.clear_selection()
		battle_map.refresh_all_layers()
	if _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
		_set_bottom_banner(_last_event_text if not _last_event_text.is_empty() else "[AI] Hoàn tất %d lệnh -> Vòng %d" % [int(rep.get("executed_commands", 0)), _controller.current_round])
	return rep

func verify_deterministic_replay_live() -> bool:
	var res: Dictionary = BattleFxBridge.verify_deterministic_replay(_controller, _current_stage_id, _is_stress_mode, _stress_unit_count, _troop_defs)
	_set_bottom_banner(str(res.get("banner", "")))
	return bool(res.get("ok", false))

func save_session_and_profile() -> bool:
	if _save_manager == null: return false
	var ok_s: bool = _save_manager.save_battle_session(_controller)
	var prof: Dictionary = _save_manager.load_player_profile()
	if hud != null:
		prof["reduce_flashing"] = hud.reduce_flashing
		prof["vfx_quality"] = hud.vfx_quality_index
	if camera != null: prof["shake_scale"] = camera.shake_user_scale
	return ok_s and _save_manager.save_player_profile(prof)

func _is_screen_point_on_hud(screen_pos: Vector2) -> bool:
	if hud != null and hud.is_any_modal_open(): return true
	var root_ui: Node = hud_canvas_layer if hud_canvas_layer != null else (hud as Node)
	return root_ui != null and _has_blocking_control_at(root_ui, screen_pos)

func _has_blocking_control_at(node: Node, screen_pos: Vector2) -> bool:
	for child: Node in node.get_children():
		if child is Control:
			var ctrl: Control = child as Control
			if not ctrl.visible or not ctrl.is_visible_in_tree(): continue
			if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and ctrl.get_global_rect().has_point(screen_pos): return true
		if _has_blocking_control_at(child, screen_pos): return true
	return false

func _connect_controller_signals() -> void:
	if _controller == null: return
	if _controller.event_manager != null and not _controller.event_manager.event_triggered.is_connected(_on_scenario_event_triggered):
		_controller.event_manager.event_triggered.connect(_on_scenario_event_triggered)
	if not _controller.battle_finished.is_connected(_on_battle_finished): _controller.battle_finished.connect(_on_battle_finished)
	if not _controller.command_executed.is_connected(_on_controller_command_executed): _controller.command_executed.connect(_on_controller_command_executed)

func _disconnect_controller_signals() -> void:
	if _controller == null: return
	if _controller.event_manager != null and _controller.event_manager.event_triggered.is_connected(_on_scenario_event_triggered):
		_controller.event_manager.event_triggered.disconnect(_on_scenario_event_triggered)
	if _controller.battle_finished.is_connected(_on_battle_finished): _controller.battle_finished.disconnect(_on_battle_finished)
	if _controller.command_executed.is_connected(_on_controller_command_executed): _controller.command_executed.disconnect(_on_controller_command_executed)

func _on_scenario_event_triggered(event_id: String, event_name: String) -> void:
	if battle_map != null: battle_map.refresh_all_layers()
	if hud != null: hud.append_combat_log("Sự kiện kịch bản: %s (%s)" % [event_name, event_id])
	_last_event_text = BattleFxBridge.format_scenario_event_banner(event_id, event_name, _dialogues)
	_set_bottom_banner(_last_event_text)

func _on_battle_finished(outcome_code: int) -> void:
	if hud != null: hud.show_result_summary(outcome_code)
	if outcome_code == int(BattleGameController.BattleOutcome.VICTORY):
		var stars_n: int = int(_controller.victory_evaluator.evaluate_stars(_controller).get("stars", 1)) if _controller != null and _controller.victory_evaluator != null else 1
		_set_bottom_banner("[CHIẾN THẮNG — %d/3 SAO] Hoàn thành tại Vòng %d! | [R] Kiểm chứng Replay | [F1] Chơi lại" % [stars_n, _controller.current_round if _controller != null else 0])
	elif outcome_code == int(BattleGameController.BattleOutcome.DEFEAT):
		_set_bottom_banner("[THẤT BẠI] Trận chiến chưa đạt mục tiêu tại Vòng %d | [F1] Tải lại" % (_controller.current_round if _controller != null else 0))

func _on_controller_command_executed(command_type: String, faction_id: int) -> void:
	var msg: String = BattleFxBridge.handle_command_executed(command_type, faction_id, _controller, battle_map, hud, juice_helper, audio_manager, camera, _save_manager, _is_stress_mode)
	if not msg.is_empty(): _set_bottom_banner(msg)

func _on_fsm_state_changed(_old_s: BattleInputFSM.State, new_s: BattleInputFSM.State) -> void:
	if hud != null: hud.update_dock_buttons()
	if _controller == null or input_fsm == null: return
	if new_s == BattleInputFSM.State.POST_MOVE_ACTION and _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
		var u: BattleUnit = input_fsm.get_active_unit()
		if u != null:
			var off: Vector2i = HexMath.axial_to_odd_r(u.hex_position)
			_set_bottom_banner("Sau hành quân (%d,%d) | %s | Click địch đỏ để Đánh ngay | [W] Đợi" % [off.x, off.y, "[Z] Hoàn tác được" if input_fsm.can_undo_post_move() else "Khóa Undo"])
	elif new_s == BattleInputFSM.State.SKILL_TARGETING:
		_set_bottom_banner("MƯU LƯỢC [Hịch Tướng Sĩ]: Chọn ô vàng (tầm 2, AoE 1) | Chuột phải / [Esc] Hủy")

func _on_fsm_unit_focused(unit: BattleUnit) -> void: _update_selection_hud(unit.hex_position if unit != null else Vector2i.ZERO, unit)
func _on_fsm_action_rejected(reason: String) -> void:
	if reason == "post_move_must_act_undo_or_wait": _set_bottom_banner("Đã di chuyển: Chọn Địch để Đánh, [K] Mưu lược, [Z] Hoàn tác, hoặc [W]/click lại ô để Đợi!")
	elif reason == "cannot_undo_use_wait_or_action": _set_bottom_banner("Không thể Hoàn tác (ZoC/Sự kiện/FoW/Đã dùng Undo) — Hãy chọn Đánh, Mưu lược hoặc [W] Đợi!")
func _on_hex_selected(axial: Vector2i, unit: BattleUnit) -> void: _update_selection_hud(axial, unit)
func _on_camera_strategic_lod_changed(use_tokens: bool) -> void:
	if battle_map != null: battle_map.set_strategic_lod(use_tokens)
func _on_camera_clean_right_clicked(screen_pos: Vector2) -> void:
	if input_fsm == null: return
	if input_fsm.get_state() == BattleInputFSM.State.IDLE and battle_map != null:
		input_fsm.inspect_hex(battle_map.world_to_axial(get_canvas_transform().affine_inverse() * screen_pos))
	else:
		input_fsm.cancel_or_deselect()
func _on_hud_save_and_exit() -> void:
	if get_tree() != null and get_tree().current_scene == self and ResourceLoader.exists(MAIN_MENU_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _update_selection_hud(axial: Vector2i, unit: BattleUnit) -> void:
	if hud != null: hud.update_unit_card(axial, unit)
	if _selection_label == null or _map_state == null: return
	if unit == null and (battle_map == null or not battle_map.has_selected_hex()):
		_selection_label.text = "Click trái: Chọn quân / Đi ô xanh / Đánh địch đỏ | [Z] Undo Đi | [W] Đợi | [Space] Kết thúc lượt | [R] Replay"
		return
	var offset: Vector2i = HexMath.axial_to_odd_r(axial)
	var t_name: String = TERRAIN_NAMES.get(int(_map_state.get_terrain(axial)), "Địa hình")
	if unit == null:
		_selection_label.text = "Ô (%d, %d) | %s | (Ô trống) — [Space] Kết thúc lượt | [R] Kiểm chứng Replay" % [offset.x, offset.y, t_name]
		return
	var fac_str: String = "Đại Việt" if unit.faction_id == 1 else "Đại Nguyên"
	var mor_str: String = MORALE_NAMES.get(int(unit.state.morale), "Ổn Định")
	_selection_label.text = "[%s] %s | HP: %d/%d (%d cờ) | Sĩ khí: %s | MP: %d/%d | Ô (%d,%d) %s" % [fac_str, unit.display_name, unit.state.current_hp, unit.state.max_hp, unit.get_active_banners(), mor_str, unit.state.current_mp, unit.max_mp, offset.x, offset.y, t_name]

func _set_bottom_banner(msg: String) -> void:
	if _selection_label != null: _selection_label.text = msg

func get_battle_session() -> BattleSession: return session
func get_map_state() -> BattleMapState: return _map_state
func get_navigator() -> HexGridNavigator: return _controller.context.navigator if _controller != null and _controller.context != null else null
func get_controller() -> BattleGameController: return _controller
func get_map_view() -> BattleMap: return battle_map
func get_battle_map() -> BattleMap: return battle_map
func get_camera() -> BattleCameraController: return camera
func get_input_fsm() -> BattleInputFSM: return input_fsm
func get_hud_controller() -> BattleHud: return hud
func get_juice_helper() -> CombatJuiceHelper: return juice_helper
func get_audio_manager() -> BattleAudioManager: return audio_manager
func get_save_manager() -> BattleSaveManager: return _save_manager
func get_tutorial_overlay() -> TutorialOverlay: return hud.get_tutorial_overlay() if hud != null else null
func get_codex_panel() -> CodexPanel: return hud.get_codex_panel() if hud != null else null
