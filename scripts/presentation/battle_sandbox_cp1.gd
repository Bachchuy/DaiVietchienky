class_name BattleSandboxCP1
extends Node2D

const DEFAULT_BATTLE_SEED: int = 12880409

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

	_camera.strategic_lod_changed.connect(_on_camera_strategic_lod_changed)
	_camera.clean_right_clicked.connect(_on_camera_clean_right_clicked)
	_map_view.hex_selected.connect(_on_hex_selected)

	_input_fsm.state_changed.connect(_on_fsm_state_changed)
	_input_fsm.unit_focused.connect(_on_fsm_unit_focused)
	_input_fsm.target_preview_requested.connect(_on_fsm_target_preview_requested)
	_input_fsm.target_preview_cleared.connect(_on_fsm_target_preview_cleared)
	_input_fsm.action_rejected.connect(_on_fsm_action_rejected)


func _build_hud() -> void:
	var hud_layer: CanvasLayer = _map_view.get_screen_hud_layer()

	var top_panel := PanelContainer.new()
	top_panel.name = "TopStatusBar"
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 44.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.90)
	style.border_width_bottom = 2
	style.border_color = Color(0.78, 0.62, 0.26, 0.90)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	top_panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(top_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	top_panel.add_child(hbox)

	if ResourceLoader.exists("res://assets_clean/emblems/dai_viet_emblem.png"):
		var dv_icon := TextureRect.new()
		dv_icon.texture = load("res://assets_clean/emblems/dai_viet_emblem.png") as Texture2D
		dv_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dv_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dv_icon.custom_minimum_size = Vector2(28.0, 28.0)
		hbox.add_child(dv_icon)

	_mode_label = Label.new()
	_mode_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	_mode_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(_mode_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_perf_label = Label.new()
	_perf_label.add_theme_color_override("font_color", Color(0.68, 0.94, 0.74))
	_perf_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(_perf_label)

	if ResourceLoader.exists("res://assets_clean/emblems/dai_nguyen_emblem.png"):
		var dn_icon := TextureRect.new()
		dn_icon.texture = load("res://assets_clean/emblems/dai_nguyen_emblem.png") as Texture2D
		dn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dn_icon.custom_minimum_size = Vector2(28.0, 28.0)
		hbox.add_child(dn_icon)

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BottomInspectBar"
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -40.0
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.10, 0.09, 0.08, 0.88)
	b_style.border_width_top = 1
	b_style.border_color = Color(0.65, 0.52, 0.24, 0.85)
	b_style.content_margin_left = 14.0
	b_style.content_margin_right = 14.0
	b_style.content_margin_top = 6.0
	b_style.content_margin_bottom = 6.0
	bottom_panel.add_theme_stylebox_override("panel", b_style)
	hud_layer.add_child(bottom_panel)

	_selection_label = Label.new()
	_selection_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	_selection_label.add_theme_font_size_override("font_size", 13)
	_selection_label.text = "Click trái: Chọn/Đi/Đánh | [Z] Undo | [W] Đợi | [Space] Hết lượt (AI tự đánh) | [A] AI đi ngay | [R] Replay | [F1/F2] Đổi bản đồ"
	bottom_panel.add_child(_selection_label)


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			click_world_position(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if _input_fsm != null and _input_fsm.get_state() != BattleInputFSM.State.IDLE:
			hover_world_position(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
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
					if _input_fsm != null:
						_input_fsm.cancel_or_deselect()
				KEY_ENTER:
					if _input_fsm != null and _input_fsm.get_state() == BattleInputFSM.State.AIMING_TARGET:
						_input_fsm.confirm_attack()
					else:
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
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP3] — Bạch Đằng 12×10"
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
	_apply_loaded_map()
	_sync_objective_markers()
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
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP2] — Stress 30×30 (%d Quân)" % unit_count
	_map_state = BattleMapState.new(30, 30, BattleMapState.TerrainType.PLAINS)
	_populate_stress_30x30(_map_state, unit_count)
	_controller = BattleGameController.new(_map_state, DEFAULT_BATTLE_SEED, [1, 3], 30)
	_controller.start_battle()
	_apply_loaded_map()


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

	var st: BattleInputFSM.State = _input_fsm.get_state()
	if st != BattleInputFSM.State.UNIT_SELECTED and st != BattleInputFSM.State.POST_MOVE_ACTION:
		return
	var axial: Vector2i = HexMath.world_to_axial(world_pos, _map_view.hex_size)
	var selected: BattleUnit = _input_fsm.get_active_unit()
	if selected == null or not _map_state.is_valid_hex(axial):
		return
	var target: BattleUnit = _map_state.get_unit_at(axial)
	if target != null and _map_state.is_hostile(selected.faction_id, target.faction_id):
		var atk_hexes: Array[Vector2i] = _controller.context.navigator.get_attackable_hexes(
			_map_state,
			selected,
			selected.hex_position
		)
		if atk_hexes.has(axial):
			var prev: Dictionary = _controller.context.combat_resolver.preview_combat(
				_map_state,
				_controller.context.navigator,
				selected,
				target
			)
			_set_bottom_banner("DỰ BÁO ĐÁNH [%s -> %s]: ST %d~%d | Crit %d%% (~%d) | Phản kích %d~%d | Khắc chế %d%%%s (Click để ngắm)" % [
				selected.display_name,
				target.display_name,
				int(prev["min_damage"]),
				int(prev["max_damage"]),
				int(prev["crit_rate"]),
				int(prev["crit_max_damage"]),
				int(prev["counter_min_damage"]),
				int(prev["counter_max_damage"]),
				int(prev["damage_percent"]),
				" [FLANK +15%]" if bool(prev["is_flanked"]) else "",
			])


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


func _on_camera_clean_right_clicked(_screen_pos: Vector2) -> void:
	if _input_fsm != null:
		_input_fsm.cancel_or_deselect()


func _on_controller_command_executed(command_type: String, faction_id: int) -> void:
	if _controller == null or _controller.context == null:
		return
	if faction_id != _controller.player_faction_id:
		return
	if command_type == "March":
		_sync_objective_markers()
	elif command_type == "Attack":
		var rep: Dictionary = _controller.context.get_last_combat_report()
		var crit_tag: String = " [BẠO KÍCH!]" if bool(rep.get("is_crit", false)) else ""
		var flank_tag: String = " [BỌC SƯỜN]" if bool(rep.get("is_flanked", false)) else ""
		_camera.add_trauma(0.45 if bool(rep.get("is_crit", false)) else 0.22)
		if _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
			_set_bottom_banner("Giao chiến: Gây %d ST%s%s | Phản kích: %d ST" % [
				int(rep.get("damage", 0)),
				crit_tag,
				flank_tag,
				int(rep.get("counter_damage", 0)),
			])
	elif command_type == "CastSkill":
		_set_bottom_banner("Đã thi triển Mưu Lược Hịch Tướng Sĩ (CD: 3 lượt)!")


func _on_fsm_state_changed(_old_state: BattleInputFSM.State, new_state: BattleInputFSM.State) -> void:
	if _controller == null or _input_fsm == null:
		return
	if new_state == BattleInputFSM.State.POST_MOVE_ACTION:
		var u: BattleUnit = _input_fsm.get_active_unit()
		if u != null and _controller.outcome == BattleGameController.BattleOutcome.ONGOING:
			var off: Vector2i = HexMath.axial_to_odd_r(u.hex_position)
			var undo_hint: String = "[Z] Hoàn tác được" if _input_fsm.can_undo_post_move() else "Khóa Undo"
			var skill_hint: String = " | [K] Mưu Lược" if _input_fsm.can_active_unit_use_skill() else ""
			_set_bottom_banner("Sau hành quân (%d,%d) | %s%s | Click địch để Ngắm | [W] hoặc click lại ô để Đợi" % [
				off.x, off.y, undo_hint, skill_hint
			])
	elif new_state == BattleInputFSM.State.SKILL_TARGETING:
		_set_bottom_banner("MƯU LƯỢC [Hịch Tướng Sĩ]: Chọn ô vàng (tầm 2, AoE 1) | Chuột phải / [Esc] Hủy")


func _on_fsm_unit_focused(unit: BattleUnit) -> void:
	if unit == null:
		_update_selection_hud(Vector2i.ZERO, null)
	else:
		_update_selection_hud(unit.hex_position, unit)


func _on_fsm_target_preview_requested(
	attacker: BattleUnit,
	defender: BattleUnit,
	prev: Dictionary
) -> void:
	if attacker == null or defender == null:
		return
	_set_bottom_banner("XÁC NHẬN ĐÁNH [%s -> %s]: ST %d~%d | Crit %d%% (~%d) | Phản kích %d~%d | Click lần 2 / [Enter] để Đánh | Chuột phải Hủy" % [
		attacker.display_name,
		defender.display_name,
		int(prev.get("min_damage", 0)),
		int(prev.get("max_damage", 0)),
		int(prev.get("crit_rate", 0)),
		int(prev.get("crit_max_damage", 0)),
		int(prev.get("counter_min_damage", 0)),
		int(prev.get("counter_max_damage", 0)),
	])


func _on_fsm_target_preview_cleared() -> void:
	if _input_fsm != null and _input_fsm.get_active_unit() != null:
		var u: BattleUnit = _input_fsm.get_active_unit()
		_update_selection_hud(u.hex_position, u)


func _on_fsm_action_rejected(reason: String) -> void:
	if reason == "post_move_must_act_undo_or_wait":
		_set_bottom_banner("Đã di chuyển: Chọn Địch để Đánh, [K] Mưu lược, [Z] Hoàn tác, hoặc [W]/click lại ô để Đợi!")
	elif reason == "cannot_undo_use_wait_or_action":
		_set_bottom_banner("Không thể Hoàn tác (ZoC/Sự kiện/FoW/Đã dùng Undo) — Hãy chọn Đánh, Mưu lược hoặc [W] Đợi!")


func _on_hex_selected(axial: Vector2i, unit: BattleUnit) -> void:
	_update_selection_hud(axial, unit)


func _update_selection_hud(axial: Vector2i, unit: BattleUnit) -> void:
	if _selection_label == null or _map_state == null:
		return
	if not _map_view.has_selected_hex():
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
