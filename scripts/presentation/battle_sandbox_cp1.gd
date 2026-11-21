class_name BattleSandboxCP1
extends Node2D

const DEFAULT_BATTLE_SEED: int = 12880409
const BATTLE_HUD_SCENE: PackedScene = preload("res://ui/battle_hud/battle_hud.tscn")

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

var _troop_defs: Dictionary[int, Dictionary] = {}
var _map_state: BattleMapState = null
var _controller: BattleGameController = null
var _map_view: BattleMapView = null
var _camera: BattleCameraController = null
var _input_fsm: BattleInputFSM = null
var _hud_controller: BattleHud = null
var _juice_helper: CombatJuiceHelper = null
var _audio_manager: BattleAudioManager = null
var _save_manager: BattleSaveManager = null
var _battle_session: BattleSession = null

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
var _status_banner: String = ""


func _ready() -> void:
	_troop_defs = StaticDataLoader.load_troop_settings()
	_ai_brain = AIDecisionMatrix.new(AIDifficultyProfile.create_preset(&"normal"))
	_setup_scene_nodes()
	_build_hud()
	load_bach_dang_preview_12x10()


func _setup_scene_nodes() -> void:
	_map_view = BattleMapView.new()
	_map_view.name = "BattleMapView"
	add_child(_map_view)

	_camera = BattleCameraController.new()
	_camera.name = "BattleCameraController"
	add_child(_camera)

	_input_fsm = BattleInputFSM.new()
	_input_fsm.name = "BattleInputFSM"
	add_child(_input_fsm)

	_juice_helper = CombatJuiceHelper.new()
	_juice_helper.name = "CombatJuiceHelper"
	add_child(_juice_helper)
	_juice_helper.setup(_map_view, _camera)

	_audio_manager = BattleAudioManager.new()
	_audio_manager.name = "BattleAudioManager"
	add_child(_audio_manager)
	_audio_manager.setup()

	_save_manager = BattleSaveManager.new()

	_battle_session = BattleSession.new()
	_battle_session.name = "BattleSession"
	add_child(_battle_session)

	_camera.strategic_lod_changed.connect(_on_camera_strategic_lod_changed)
	_camera.clean_right_clicked.connect(_on_camera_clean_right_clicked)
	_map_view.hex_selected.connect(_on_hex_selected)

	_input_fsm.state_changed.connect(_on_fsm_state_changed)
	_input_fsm.unit_focused.connect(_on_fsm_unit_focused)
	_input_fsm.action_rejected.connect(_on_fsm_action_rejected)


func _build_hud() -> void:
	var hud_layer: CanvasLayer = _map_view.get_screen_hud_layer()
	if hud_layer == null:
		return
	if _hud_controller == null:
		_hud_controller = BATTLE_HUD_SCENE.instantiate() as BattleHud
		if _hud_controller == null:
			return
		_hud_controller.name = "BattleHud"
		hud_layer.add_child(_hud_controller)
	_hud_controller.setup(self, _battle_session, _map_view, _camera, _input_fsm)
	_mode_label = _hud_controller.get_mode_label()
	_selection_label = _hud_controller.get_selection_label()
	_perf_label = _hud_controller.get_perf_label()


func _process(_delta: float) -> void:
	if _perf_label != null and _camera != null and _map_state != null and _controller != null:
		var fps: int = Engine.get_frames_per_second()
		var lod_text: String = "TOKEN" if _map_view.is_strategic_lod() else "MODEL"
		var fac_text: String = "ĐẠI VIỆT" if _controller.current_faction_id == 1 else "ĐẠI NGUYÊN"
		var status_text: String = "LƯỢT: %s" % fac_text
		if _controller.outcome == BattleGameController.BattleOutcome.VICTORY:
			var stars_n: int = 1
			if _controller.victory_evaluator != null:
				stars_n = int(_controller.victory_evaluator.evaluate_stars(_controller).get("stars", 1))
			status_text = "CHIẾN THẮNG (%d/3 SAO)" % stars_n
		elif _controller.outcome == BattleGameController.BattleOutcome.DEFEAT:
			status_text = "THẤT BẠI"
		if _mode_label != null:
			_mode_label.text = "%s | VÒNG %02d/%02d | %s" % [
				_current_mode_title,
				_controller.current_round,
				_controller.max_rounds,
				status_text,
			]
		_perf_label.text = "FPS: %d | Zoom: %.2fx [%s] | Quân: %d" % [
			fps if fps > 0 else 60,
			_camera.zoom.x,
			lod_text,
			_map_state.get_all_units().size(),
		]


func _is_screen_point_on_hud(screen_pos: Vector2) -> bool:
	if _hud_controller != null and _hud_controller.is_any_modal_open():
		return true
	if _map_view == null:
		return false
	var hud_layer: CanvasLayer = _map_view.get_screen_hud_layer()
	if hud_layer == null:
		return false
	return _has_blocking_control_at(hud_layer, screen_pos)


func _has_blocking_control_at(node: Node, screen_pos: Vector2) -> bool:
	for child: Node in node.get_children():
		if child is Control:
			var ctrl: Control = child as Control
			if not ctrl.visible or not ctrl.is_visible_in_tree():
				continue
			if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and ctrl.get_global_rect().has_point(screen_pos):
				return true
		if _has_blocking_control_at(child, screen_pos):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _is_screen_point_on_hud(mb.position):
				return
			var canvas_inv: Transform2D = get_canvas_transform().affine_inverse()
			click_world_position(canvas_inv * mb.position)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_screen_point_on_hud(mm.position):
			return
		if _input_fsm != null and _input_fsm.get_state() != BattleInputFSM.State.IDLE:
			var canvas_inv_m: Transform2D = get_canvas_transform().affine_inverse()
			hover_world_position(canvas_inv_m * mm.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if _is_screen_point_on_hud(st.position):
				return
			var canvas_inv: Transform2D = get_canvas_transform().affine_inverse()
			click_world_position(canvas_inv * st.position)
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			match ke.keycode:
				KEY_F1:
					load_bach_dang_preview_12x10()
				KEY_F2:
					load_stress_benchmark_30x30(44)
				KEY_Z:
					try_undo_march()
				KEY_W:
					try_wait_selected()
				KEY_K, KEY_Q:
					try_enter_skill_targeting()
				KEY_ESCAPE:
					if _hud_controller != null and _hud_controller.is_any_modal_open():
						_hud_controller.close_pause_modal()
					elif _input_fsm != null and _input_fsm.get_state() != BattleInputFSM.State.IDLE:
						_input_fsm.cancel_or_deselect()
					elif _hud_controller != null:
						_hud_controller.toggle_pause_modal()
				KEY_ENTER:
					end_active_faction_turn()
				KEY_SPACE:
					end_active_faction_turn()
				KEY_A:
					run_ai_for_current_faction()
				KEY_R:
					verify_deterministic_replay_live()
				KEY_T:
					_camera.add_trauma(0.45)
				_:
					pass


func load_bach_dang_preview_12x10() -> void:
	_is_stress_mode = false
	_last_event_text = ""
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP4] — Bạch Đằng 12×10"
	_controller = ScenarioLoader.load_stage(10101, DEFAULT_BATTLE_SEED)
	if _controller == null:
		return
	_map_state = _controller.context.map_state
	_dialogues = ScenarioLoader.load_stage_dialogues(10101)
	if _controller.event_manager != null and not _controller.event_manager.event_triggered.is_connected(_on_scenario_event_triggered):
		_controller.event_manager.event_triggered.connect(_on_scenario_event_triggered)
	if not _controller.battle_finished.is_connected(_on_battle_finished):
		_controller.battle_finished.connect(_on_battle_finished)
	if not _controller.command_executed.is_connected(_on_controller_command_executed):
		_controller.command_executed.connect(_on_controller_command_executed)
	if _battle_session != null:
		_battle_session.attach_controller(_controller, 10101, _dialogues)
	_apply_loaded_map()
	_sync_objective_markers()
	_map_view.set_fog_of_war_context(_controller.context, _controller.player_faction_id)

	var stages: Dictionary[int, Dictionary] = StaticDataLoader.load_stage_settings()
	var stage_meta: Dictionary = stages.get(10101, {
		"id": 10101,
		"name": "Đại Chiến Bạch Đằng 1288",
		"modeling_type": "historical_claim",
		"source_ref": "Đại Việt Sử Ký Toàn Thư (1288)",
	})
	if _hud_controller != null:
		_hud_controller.set_mode_title(_current_mode_title)
		_hud_controller.bind_battle(_controller, stage_meta, _dialogues, true)

	var open_dlg: Dictionary = _dialogues.get("talk_opening_bach_dang", {})
	if not open_dlg.is_empty():
		_set_bottom_banner("[VÒNG 1] %s: \"%s\" | [A] AI đi | [Space] Kết thúc lượt | [R] Replay" % [
			str(open_dlg.get("speaker", "Tướng lĩnh")),
			str(open_dlg.get("line", "")),
		])


func _sync_objective_markers() -> void:
	if _map_view == null:
		return
	_map_view.clear_key_areas()
	if _controller == null or _controller.director == null:
		return
	for area_id: String in _controller.director.primary_objective_area_ids:
		var owner_f: int = _controller.director.get_area_owner(area_id)
		for hex: Vector2i in _controller.director.get_area_hexes(area_id):
			_map_view.set_key_area(hex, owner_f)


func _populate_stress_30x30(target_map: BattleMapState, unit_count: int) -> void:
	for row: int in range(30):
		for col: int in range(30):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if col >= 13 and col <= 15:
				target_map.set_terrain(ax, BattleMapState.TerrainType.DEEP_WATER)
			elif col == 12 or col == 16:
				target_map.set_terrain(ax, BattleMapState.TerrainType.SHALLOW_RIVER)
			elif (col + row) % 7 == 0:
				target_map.set_terrain(ax, BattleMapState.TerrainType.FOREST)
			elif (col * 3 + row) % 11 == 0:
				target_map.set_terrain(ax, BattleMapState.TerrainType.HILLS)
			elif row == 14:
				target_map.set_terrain(ax, BattleMapState.TerrainType.ROAD_PORT)

	var land_ids: Array[int] = [40101, 40102, 40103, 40104]
	var spawned: int = 0
	var uid: int = 1
	for row: int in range(2, 28, 2):
		for col: int in [4, 8, 20, 24]:
			if spawned >= unit_count:
				break
			var faction: int = 1 if col < 12 else 3
			var t_id: int = land_ids[spawned % land_ids.size()]
			_spawn_unit_into(target_map, uid, faction, t_id, Vector2i(col, row), 3)
			uid += 1
			spawned += 1
		if spawned < unit_count and row % 4 == 0:
			_spawn_unit_into(target_map, uid, 1, 40201, Vector2i(13, row), 3)
			uid += 1
			spawned += 1
		if spawned < unit_count and row % 4 == 2:
			_spawn_unit_into(target_map, uid, 3, 40901, Vector2i(15, row), 3)
			uid += 1
			spawned += 1


func load_stress_benchmark_30x30(unit_count: int = 44) -> void:
	_is_stress_mode = true
	_stress_unit_count = unit_count
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP4] — Stress 30×30 (%d Quân)" % unit_count
	_map_state = BattleMapState.new(30, 30, BattleMapState.TerrainType.PLAINS)
	_populate_stress_30x30(_map_state, unit_count)
	_controller = BattleGameController.new(_map_state, DEFAULT_BATTLE_SEED, [1, 3], 30)
	_controller.start_battle()
	if _battle_session != null:
		_battle_session.attach_controller(_controller, 99999, {})
	_apply_loaded_map()
	if _hud_controller != null:
		_hud_controller.set_mode_title(_current_mode_title)
		_hud_controller.bind_battle(_controller, {"id": 99999, "name": "Stress 30x30"}, {}, false)


func _spawn_unit_into(
	target_map: BattleMapState,
	uid: int,
	faction: int,
	troop_id: int,
	offset_cell: Vector2i,
	stack_count: int = 1
) -> BattleUnit:
	var axial: Vector2i = HexMath.odd_r_to_axial(offset_cell)
	var def: Dictionary = _troop_defs.get(troop_id, {})
	var u: BattleUnit = BattleUnit.from_troop_dict(uid, faction, axial, def)
	u.max_stack = stack_count
	u.troop_stack = stack_count
	u.state.max_hp = u.base_hp * stack_count
	u.state.current_hp = u.state.max_hp
	target_map.place_unit(u)
	return u


func _apply_loaded_map() -> void:
	_map_view.bind_battle_state(_map_state, _controller.context.navigator)
	if _input_fsm != null:
		if _battle_session != null:
			_input_fsm.bind_session(_battle_session, _map_view, _camera)
		else:
			_input_fsm.bind(_controller, _map_view, _camera)
	var bounds: Rect2 = HexMath.compute_map_world_bounds(_map_state.width, _map_state.height, _map_view.hex_size, 48.0)
	_camera.map_world_bounds = bounds
	_camera.set_zoom_level(BattleCameraController.ZOOM_DEFAULT, true)
	_camera.pan_to_world_pos(bounds.get_center(), true)


func click_world_position(world_pos: Vector2) -> void:
	if _input_fsm != null:
		_input_fsm.tap_world_position(world_pos)


func hover_world_position(world_pos: Vector2) -> void:
	if _input_fsm == null or _controller == null or _map_state == null:
		return
	_input_fsm.hover_world_position(world_pos)


func try_undo_march() -> bool:
	if _controller == null or _input_fsm == null:
		return false
	if _input_fsm.request_undo():
		_set_bottom_banner("Đã Hoàn Tác (Undo 1/1) bước di chuyển về ô cũ & hoàn trả đủ MP!")
		return true
	_set_bottom_banner("Không thể Undo (chưa đi / đã hành động / vào ZoC / dính bẫy / đã dùng 1 lần Undo).")
	return false


func try_wait_selected() -> bool:
	if _input_fsm == null:
		return false
	var sel: BattleUnit = _input_fsm.get_active_unit()
	if _input_fsm.request_wait():
		if sel != null:
			_set_bottom_banner("Đơn vị [%s] chốt vị trí Đợi." % sel.display_name)
		return true
	return false


func try_enter_skill_targeting() -> bool:
	if _input_fsm == null:
		return false
	return _input_fsm.enter_skill_targeting()


func end_active_faction_turn() -> bool:
	if _controller == null:
		return false
	if _controller.submit_command(BattleCommands.EndTurnCommand.new(_controller.current_faction_id)):
		if _input_fsm != null:
			_input_fsm.sync_with_controller()
		_map_view.clear_selection()
		_sync_objective_markers()
		_map_view.refresh_all_layers()
		if (
			_auto_enemy_ai
			and not _is_stress_mode
			and _controller.outcome == BattleGameController.BattleOutcome.ONGOING
			and _controller.current_faction_id != _controller.player_faction_id
		):
			run_ai_for_current_faction()
			return true
		if _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
			var next_fac: String = "Đại Việt" if _controller.current_faction_id == 1 else "Đại Nguyên"
			_set_bottom_banner("Chuyển sang Vòng %d — Lượt của phe %s!" % [_controller.current_round, next_fac])
		return true
	return false


func run_ai_for_current_faction() -> Dictionary:
	if _controller == null or _ai_brain == null:
		return {}
	if _controller.outcome != BattleGameController.BattleOutcome.ONGOING:
		return {}
	var active_fac: int = _controller.current_faction_id
	_last_event_text = ""
	var rep: Dictionary = _ai_brain.execute_faction_turn(_controller, active_fac, _controller.director)
	if _input_fsm != null:
		_input_fsm.sync_with_controller()
	_map_view.clear_selection()
	_sync_objective_markers()
	_map_view.refresh_all_layers()
	if _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
		if not _last_event_text.is_empty():
			_set_bottom_banner(_last_event_text)
		else:
			var prev_name: String = "Đại Việt" if active_fac == 1 else "Đại Nguyên"
			var next_name: String = "Đại Việt" if _controller.current_faction_id == 1 else "Đại Nguyên"
			_set_bottom_banner("[AI %s] Hoàn tất %d lệnh trong %.1f ms -> Vòng %d (%s)" % [
				prev_name,
				int(rep.get("executed_commands", 0)),
				float(rep.get("elapsed_ms", 0.0)),
				_controller.current_round,
				next_name,
			])
	return rep


func _on_scenario_event_triggered(event_id: String, event_name: String) -> void:
	_sync_objective_markers()
	_map_view.refresh_all_layers()
	if _hud_controller != null:
		_hud_controller.append_combat_log("Sự kiện kịch bản: %s (%s)" % [event_name, event_id])
	if event_id == "evt_10101_tide_fall":
		var dlg: Dictionary = _dialogues.get("talk_trieu_rut", {})
		_last_event_text = "[SỰ KIỆN VÒNG 4 — NƯỚC RÚT LỘ BÃI CỌC] %s: \"%s\"" % [
			str(dlg.get("speaker", "Trần Quốc Tuấn")),
			str(dlg.get("line", event_name)),
		]
	elif event_id == "evt_10101_omnhi_wounded":
		var dlg_w: Dictionary = _dialogues.get("talk_omnhi_hoang_loan", {})
		_last_event_text = "[SỰ KIỆN] %s: \"%s\"" % [
			str(dlg_w.get("speaker", "Ô Mã Nhi")),
			str(dlg_w.get("line", event_name)),
		]
	else:
		_last_event_text = "[SỰ KIỆN] %s" % event_name
	_set_bottom_banner(_last_event_text)


func _on_battle_finished(outcome_code: int) -> void:
	if _hud_controller != null:
		_hud_controller.show_result_summary(outcome_code)
	if outcome_code == int(BattleGameController.BattleOutcome.VICTORY):
		var stars_res: Dictionary = (
			_controller.victory_evaluator.evaluate_stars(_controller)
			if _controller != null and _controller.victory_evaluator != null
			else {"stars": 1}
		)
		_set_bottom_banner("[CHIẾN THẮNG — %d/3 SAO] Bạch Đằng toàn thắng tại Vòng %d! | [R] Kiểm chứng Replay | [F1] Chơi lại" % [
			int(stars_res.get("stars", 1)),
			_controller.current_round if _controller != null else 0,
		])
	elif outcome_code == int(BattleGameController.BattleOutcome.DEFEAT):
		_set_bottom_banner("[THẤT BẠI] Trận Bạch Đằng chưa giữ được thế trận tại Vòng %d | [F1] Tải lại" % [
			_controller.current_round if _controller != null else 0,
		])


func verify_deterministic_replay_live() -> bool:
	if _controller == null:
		return false
	var replay_payload: Dictionary = _controller.export_replay()
	var verify_ctrl: BattleGameController = null
	if _is_stress_mode:
		var verify_map := BattleMapState.new(_map_state.width, _map_state.height, BattleMapState.TerrainType.PLAINS)
		_populate_stress_30x30(verify_map, _stress_unit_count)
		verify_ctrl = BattleGameController.new(verify_map, DEFAULT_BATTLE_SEED, [1, 3], _controller.max_rounds)
	else:
		verify_ctrl = ScenarioLoader.load_stage(10101, DEFAULT_BATTLE_SEED)

	if verify_ctrl == null or not verify_ctrl.replay_from_dict(replay_payload):
		_set_bottom_banner("[REPLAY ERROR] Không thể phát lại chuỗi lệnh!")
		return false

	var live_units: Array[BattleUnit] = _map_state.get_all_units()
	var rep_units: Array[BattleUnit] = verify_ctrl.context.map_state.get_all_units()
	if live_units.size() != rep_units.size():
		_set_bottom_banner("[REPLAY DESYNC] Sai lệch quân số!")
		return false

	for u_live: BattleUnit in live_units:
		var u_rep: BattleUnit = verify_ctrl.context.get_unit(u_live.unit_id)
		if u_rep == null or u_rep.state.current_hp != u_live.state.current_hp or u_rep.hex_position != u_live.hex_position:
			_set_bottom_banner("[REPLAY DESYNC] Lệch HP/tọa độ tại đơn vị %d!" % u_live.unit_id)
			return false

	var outcome_match: bool = (verify_ctrl.outcome == _controller.outcome)
	var round_match: bool = (verify_ctrl.current_round == _controller.current_round)
	var rng_match: bool = (verify_ctrl.context.rng.get_state() == _controller.context.rng.get_state())
	var all_ok: bool = outcome_match and round_match and rng_match
	_set_bottom_banner("[REPLAY VERIFIED 100%%] Phát lại %d lệnh từ Seed %d khớp tuyệt đối HP, Tọa độ, Vòng %d & RNG (%s)!" % [
		_controller.command_history.get_replay_stream_size(),
		DEFAULT_BATTLE_SEED,
		_controller.current_round,
		"OK" if all_ok else "DIFF",
	])
	return all_ok


func _set_bottom_banner(msg: String) -> void:
	_status_banner = msg
	if _selection_label != null:
		_selection_label.text = msg


func _on_camera_strategic_lod_changed(use_tokens: bool) -> void:
	_map_view.set_strategic_lod(use_tokens)


func _on_camera_clean_right_clicked(screen_pos: Vector2) -> void:
	if _input_fsm == null:
		return
	if _input_fsm.get_state() == BattleInputFSM.State.IDLE and _map_view != null:
		var canvas_inv: Transform2D = get_canvas_transform().affine_inverse()
		var axial: Vector2i = HexMath.world_to_axial(canvas_inv * screen_pos, _map_view.hex_size)
		_input_fsm.inspect_hex(axial)
		return
	_input_fsm.cancel_or_deselect()


func _on_controller_command_executed(command_type: String, faction_id: int) -> void:
	if _controller == null or _controller.context == null:
		return
	if command_type == "March":
		_sync_objective_markers()
		var p: Dictionary = _controller.context.last_command_payload
		var to_ax: Vector2i = p.get("to_hex", Vector2i.ZERO)
		if _hud_controller != null:
			var to_off: Vector2i = HexMath.axial_to_odd_r(to_ax)
			_hud_controller.append_combat_log("Đơn vị #%d hành quân tới (%d,%d)" % [int(p.get("unit_id", 0)), to_off.x, to_off.y])
		if _juice_helper != null and _map_view != null:
			_juice_helper.spawn_particle_preset("DustTrailCPU2D", HexMath.axial_to_world(to_ax, _map_view.hex_size), "Tran_Nguyen")
	elif command_type == "Attack":
		var rep: Dictionary = _controller.context.get_last_combat_report()
		var p_atk: Dictionary = _controller.context.last_command_payload
		var atk_id: int = int(p_atk.get("attacker_id", rep.get("attacker_id", 0)))
		var def_id: int = int(p_atk.get("defender_id", rep.get("defender_id", 0)))
		var dmg_val: int = int(rep.get("damage", 0))
		var is_cr: bool = bool(rep.get("is_crit", false))
		var crit_tag: String = " [BẠO KÍCH!]" if is_cr else ""
		var flank_tag: String = " [BỌC SƯỜN]" if bool(rep.get("is_flanked", false)) else ""
		if _hud_controller != null:
			_hud_controller.append_combat_log("Giao chiến: #%d đánh #%d gây %d ST%s%s | Phản kích: %d ST" % [
				atk_id,
				def_id,
				dmg_val,
				crit_tag,
				flank_tag,
				int(rep.get("counter_damage", 0)),
			])
		var def_u: BattleUnit = _controller.context.get_unit(def_id)
		var def_world: Vector2 = HexMath.axial_to_world(def_u.hex_position, _map_view.hex_size) if def_u != null and _map_view != null else Vector2(200.0, 200.0)
		if _juice_helper != null and _map_view != null:
			_juice_helper.spawn_particle_preset("MetalSparksCPU2D", def_world, "Tran_Nguyen")
			_juice_helper.spawn_floating_text(
				_map_view.get_layer_node("WorldSpaceUnitHudAndTextLayer"),
				def_world,
				dmg_val,
				&"crit" if is_cr else (&"blocked" if dmg_val <= 0 else &"normal")
			)
		if _audio_manager != null:
			_audio_manager.play_sfx("sword_hit", def_world, "Tran_Nguyen")
		if faction_id == _controller.player_faction_id:
			_camera.add_trauma(0.45 if is_cr else 0.22)
			if _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
				_set_bottom_banner("Giao chiến: Gây %d ST%s%s | Phản kích: %d ST" % [
					dmg_val,
					crit_tag,
					flank_tag,
					int(rep.get("counter_damage", 0)),
				])
	elif command_type == "CastSkill":
		if _hud_controller != null:
			_hud_controller.append_combat_log("Thi triển Mưu Lược #10001 Hịch Tướng Sĩ (+Sĩ khí, giải Hỗn Loạn)")
		var p_sk: Dictionary = _controller.context.last_command_payload
		var sk_pos: Vector2 = HexMath.axial_to_world(p_sk.get("target_hex", Vector2i.ZERO), _map_view.hex_size) if _map_view != null else Vector2.ZERO
		if _juice_helper != null:
			_juice_helper.spawn_particle_preset("MoraleAuraCPU2D", sk_pos, "Tran_Nguyen")
		if _audio_manager != null:
			_audio_manager.play_sfx("horn_charge", sk_pos, "Tran_Nguyen")
		if faction_id == _controller.player_faction_id:
			_set_bottom_banner("Đã thi triển Mưu Lược Hịch Tướng Sĩ (CD: 3 lượt)!")
	elif command_type == "EndTurn":
		if not _is_stress_mode and _save_manager != null:
			_save_manager.save_battle_session(_controller)
	if _hud_controller != null:
		_hud_controller.update_dock_buttons()


func _on_fsm_state_changed(_old_state: BattleInputFSM.State, new_state: BattleInputFSM.State) -> void:
	if _hud_controller != null:
		_hud_controller.update_dock_buttons()
	if _controller == null or _input_fsm == null:
		return
	if new_state == BattleInputFSM.State.POST_MOVE_ACTION:
		var u: BattleUnit = _input_fsm.get_active_unit()
		if u != null and _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
			var off: Vector2i = HexMath.axial_to_odd_r(u.hex_position)
			var undo_hint: String = "[Z] Hoàn tác được" if _input_fsm.can_undo_post_move() else "Khóa Undo"
			var skill_hint: String = " | [K] Mưu Lược" if _input_fsm.can_active_unit_use_skill() else ""
			_set_bottom_banner("Sau hành quân (%d,%d) | %s%s | Click địch đỏ để Đánh ngay | [W] hoặc click lại ô để Đợi" % [
				off.x, off.y, undo_hint, skill_hint
			])
	elif new_state == BattleInputFSM.State.SKILL_TARGETING:
		_set_bottom_banner("MƯU LƯỢC [Hịch Tướng Sĩ]: Chọn ô vàng (tầm 2, AoE 1) | Chuột phải / [Esc] Hủy")


func _on_fsm_unit_focused(unit: BattleUnit) -> void:
	if unit == null:
		_update_selection_hud(Vector2i.ZERO, null)
	else:
		_update_selection_hud(unit.hex_position, unit)


func _on_fsm_action_rejected(reason: String) -> void:
	if reason == "post_move_must_act_undo_or_wait":
		_set_bottom_banner("Đã di chuyển: Chọn Địch để Đánh, [K] Mưu lược, [Z] Hoàn tác, hoặc [W]/click lại ô để Đợi!")
	elif reason == "cannot_undo_use_wait_or_action":
		_set_bottom_banner("Không thể Hoàn tác (ZoC/Sự kiện/FoW/Đã dùng Undo) — Hãy chọn Đánh, Mưu lược hoặc [W] Đợi!")


func _on_hex_selected(axial: Vector2i, unit: BattleUnit) -> void:
	_update_selection_hud(axial, unit)


func _update_selection_hud(axial: Vector2i, unit: BattleUnit) -> void:
	if _hud_controller != null:
		_hud_controller.update_unit_card(axial, unit)
	if _selection_label == null or _map_state == null:
		return
	if unit == null and not _map_view.has_selected_hex():
		_selection_label.text = "Click trái: Chọn quân / Đi ô xanh / Đánh địch đỏ | [Z] Undo Đi | [W] Đợi | [Space] Kết thúc lượt | [R] Kiểm chứng Replay"
		return

	var offset: Vector2i = HexMath.axial_to_odd_r(axial)
	var t_enum: int = int(_map_state.get_terrain(axial))
	var t_name: String = TERRAIN_NAMES.get(t_enum, "Địa hình")

	if unit == null:
		_selection_label.text = "Ô (%d, %d) | %s | (Ô trống) — [Space] Kết thúc lượt | [R] Kiểm chứng Replay" % [
			offset.x, offset.y, t_name
		]
	else:
		var faction_str: String = "Đại Việt" if unit.faction_id == 1 else "Đại Nguyên"
		var morale_str: String = MORALE_NAMES.get(int(unit.state.morale), "Ổn Định")
		_selection_label.text = "[%s] %s | HP: %d/%d (%d cờ) | Sĩ khí: %s | MP: %d/%d | Ô (%d,%d) %s" % [
			faction_str,
			unit.display_name,
			unit.state.current_hp,
			unit.state.max_hp,
			unit.get_active_banners(),
			morale_str,
			unit.state.current_mp,
			unit.max_mp,
			offset.x,
			offset.y,
			t_name,
		]


func save_session_and_profile() -> bool:
	var mgr := BattleSaveManager.new()
	var ok_s: bool = mgr.save_battle_session(_controller)
	var prof: Dictionary = mgr.load_player_profile()
	if _hud_controller != null:
		prof["reduce_flashing"] = _hud_controller.reduce_flashing
		prof["vfx_quality"] = _hud_controller.vfx_quality_index
	if _camera != null:
		prof["shake_scale"] = _camera.shake_user_scale
	var ok_p: bool = mgr.save_player_profile(prof)
	return ok_s and ok_p


func get_battle_session() -> BattleSession:
	return _battle_session


func get_map_state() -> BattleMapState:
	return _map_state


func get_navigator() -> HexGridNavigator:
	return _controller.context.navigator


func get_controller() -> BattleGameController:
	return _controller


func get_map_view() -> BattleMapView:
	return _map_view


func get_camera() -> BattleCameraController:
	return _camera


func get_input_fsm() -> BattleInputFSM:
	return _input_fsm


func get_hud_controller() -> BattleHud:
	return _hud_controller


func get_juice_helper() -> CombatJuiceHelper:
	return _juice_helper


func get_audio_manager() -> BattleAudioManager:
	return _audio_manager


func get_save_manager() -> BattleSaveManager:
	return _save_manager


func get_tutorial_overlay() -> TutorialOverlay:
	return _hud_controller.get_tutorial_overlay() if _hud_controller != null else null


func get_codex_panel() -> CodexPanel:
	return _hud_controller.get_codex_panel() if _hud_controller != null else null
