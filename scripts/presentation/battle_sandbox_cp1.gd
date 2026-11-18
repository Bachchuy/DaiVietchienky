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

var _mode_label: Label = null
var _selection_label: Label = null
var _perf_label: Label = null
var _current_mode_title: String = ""
var _is_stress_mode: bool = false
var _stress_unit_count: int = 44
var _status_banner: String = ""


func _ready() -> void:
	_troop_defs = StaticDataLoader.load_troop_settings()
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

	_camera.strategic_lod_changed.connect(_on_camera_strategic_lod_changed)
	_map_view.hex_selected.connect(_on_hex_selected)


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
	_selection_label.text = "Click trái: Chọn quân / Đi ô xanh / Đánh địch đỏ | [Z] Undo Đi | [W] Đợi | [Space] Kết thúc lượt | [R] Kiểm chứng Replay | [F1/F2] Đổi bản đồ"
	bottom_panel.add_child(_selection_label)


func _process(_delta: float) -> void:
	if _perf_label != null and _camera != null and _map_state != null and _controller != null:
		var fps: int = Engine.get_frames_per_second()
		var lod_text: String = "TOKEN" if _map_view.is_strategic_lod() else "MODEL"
		var fac_text: String = "ĐẠI VIỆT" if _controller.current_faction_id == 1 else "ĐẠI NGUYÊN"
		if _mode_label != null:
			_mode_label.text = "%s | VÒNG %02d/%02d | LƯỢT: %s" % [
				_current_mode_title,
				_controller.current_round,
				_controller.max_rounds,
				fac_text,
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
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			click_world_position(get_global_mouse_position())
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_map_view.clear_selection()
			_update_selection_hud(Vector2i.ZERO, null)
	elif event is InputEventMouseMotion:
		if _map_view.get_selected_unit() != null:
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
				KEY_SPACE, KEY_ENTER:
					end_active_faction_turn()
				KEY_R:
					verify_deterministic_replay_live()
				KEY_T:
					_camera.add_trauma(0.45)
				_:
					pass


func _populate_bach_dang_12x10(target_map: BattleMapState) -> void:
	target_map.staked_water_owner_faction = 1
	for row: int in range(10):
		for col: int in range(12):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if col >= 5 and col <= 7:
				target_map.set_terrain(ax, BattleMapState.TerrainType.DEEP_WATER)
			elif col == 4 or col == 8:
				target_map.set_terrain(ax, BattleMapState.TerrainType.SHALLOW_RIVER)
			elif col <= 2 and row <= 4:
				target_map.set_terrain(ax, BattleMapState.TerrainType.FOREST)
			elif col >= 9 and row >= 2 and row <= 6:
				target_map.set_terrain(ax, BattleMapState.TerrainType.HILLS)

	for stake_cell: Vector2i in [Vector2i(6, 4), Vector2i(6, 5), Vector2i(7, 5)]:
		target_map.set_terrain(HexMath.odd_r_to_axial(stake_cell), BattleMapState.TerrainType.STAKED_WATER)

	var signal_dock: Vector2i = HexMath.odd_r_to_axial(Vector2i(2, 8))
	target_map.set_terrain(signal_dock, BattleMapState.TerrainType.ROAD_PORT)
	target_map.set_terrain(HexMath.odd_r_to_axial(Vector2i(3, 8)), BattleMapState.TerrainType.ROAD_PORT)

	var enemy_fort: Vector2i = HexMath.odd_r_to_axial(Vector2i(9, 4))
	target_map.set_terrain(enemy_fort, BattleMapState.TerrainType.FORT)
	target_map.set_fort_owner(enemy_fort, 3)

	var u1: BattleUnit = _spawn_unit_into(target_map, 1, 1, 40101, Vector2i(2, 8), 3)
	u1.general_id = 1001
	u1.general_name = "Trần Quốc Tuấn"
	u1.is_commander_in_chief = true
	u1.aura_radius_hex = 2
	u1.aura_damage_deepen = 10
	u1.grants_dead_mate_immunity = true

	_spawn_unit_into(target_map, 2, 1, 40102, Vector2i(3, 5), 3)
	_spawn_unit_into(target_map, 3, 1, 40103, Vector2i(2, 6), 2)
	_spawn_unit_into(target_map, 4, 1, 40104, Vector2i(3, 7), 2)
	_spawn_unit_into(target_map, 5, 1, 40201, Vector2i(5, 6), 3)

	var e1: BattleUnit = _spawn_unit_into(target_map, 101, 3, 40901, Vector2i(6, 3), 3)
	e1.general_id = 9001
	e1.general_name = "Ô Mã Nhi"
	e1.is_commander_in_chief = true
	e1.aura_radius_hex = 2

	_spawn_unit_into(target_map, 102, 3, 40901, Vector2i(7, 4), 3)
	_spawn_unit_into(target_map, 103, 3, 40901, Vector2i(5, 4), 2)
	_spawn_unit_into(target_map, 104, 3, 40101, Vector2i(9, 4), 3)
	_spawn_unit_into(target_map, 105, 3, 40102, Vector2i(9, 5), 2)


func load_bach_dang_preview_12x10() -> void:
	_is_stress_mode = false
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP2] — Bạch Đằng 12×10"
	_map_state = BattleMapState.new(12, 10, BattleMapState.TerrainType.PLAINS)
	_populate_bach_dang_12x10(_map_state)
	_controller = BattleGameController.new(_map_state, DEFAULT_BATTLE_SEED, [1, 3], 10)
	_controller.start_battle()
	_apply_loaded_map()
	_map_view.set_key_area(HexMath.odd_r_to_axial(Vector2i(2, 8)), 1)


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
	var bounds: Rect2 = HexMath.compute_map_world_bounds(_map_state.width, _map_state.height, _map_view.hex_size, 48.0)
	_camera.map_world_bounds = bounds
	_camera.set_zoom_level(BattleCameraController.ZOOM_DEFAULT, true)
	_camera.pan_to_world_pos(bounds.get_center(), true)


func click_world_position(world_pos: Vector2) -> void:
	var axial: Vector2i = HexMath.world_to_axial(world_pos, _map_view.hex_size)
	if not _map_state.is_valid_hex(axial):
		_map_view.clear_selection()
		return

	var selected: BattleUnit = _map_view.get_selected_unit()
	var clicked_unit: BattleUnit = _map_state.get_unit_at(axial)

	# Active turn command dispatch when a current-faction unit is already selected
	if (
		selected != null
		and _controller.outcome == BattleGameController.BattleOutcome.ONGOING
		and selected.faction_id == _controller.current_faction_id
		and not selected.state.has_acted
	):
		# 1. Click empty reachable tile -> MarchCommand
		var reach: Dictionary[Vector2i, int] = _map_view.get_reachable_overlay_hexes()
		if clicked_unit == null and reach.has(axial) and axial != selected.hex_position:
			var m_cmd := BattleCommands.MarchCommand.new(
				_controller.current_faction_id,
				selected.unit_id,
				selected.hex_position,
				axial
			)
			if _controller.submit_command(m_cmd):
				_map_view.refresh_units()
				_map_view.select_hex(selected.hex_position)
				var undo_hint: String = "[Z] Hoàn tác được" if _controller.can_undo() else "Khóa Undo (ZoC/Sự kiện/Đã dùng)"
				_set_bottom_banner("Đã hành quân tới (%d,%d) | %s | Click địch đỏ để Đánh hoặc [W] Đợi" % [
					HexMath.axial_to_odd_r(axial).x,
					HexMath.axial_to_odd_r(axial).y,
					undo_hint,
				])
				return

		# 2. Click hostile unit in attack range -> AttackCommand
		if clicked_unit != null and _map_state.is_hostile(selected.faction_id, clicked_unit.faction_id):
			var atk_hexes: Array[Vector2i] = _controller.context.navigator.get_attackable_hexes(
				_map_state,
				selected,
				selected.hex_position
			)
			if atk_hexes.has(axial):
				var atk_cmd := BattleCommands.AttackCommand.new(
					_controller.current_faction_id,
					selected.unit_id,
					clicked_unit.unit_id
				)
				if _controller.submit_command(atk_cmd):
					var rep: Dictionary = _controller.context.get_last_combat_report()
					var crit_tag: String = " [BẠO KÍCH!]" if bool(rep.get("is_crit", false)) else ""
					var flank_tag: String = " [BỌC SƯỜN]" if bool(rep.get("is_flanked", false)) else ""
					_camera.add_trauma(0.45 if bool(rep.get("is_crit", false)) else 0.22)
					_map_view.refresh_units()
					_map_view.clear_selection()
					_set_bottom_banner("Giao chiến: Gây %d ST%s%s | Phản kích: %d ST | Sĩ khí địch: %s" % [
						int(rep.get("damage", 0)),
						crit_tag,
						flank_tag,
						int(rep.get("counter_damage", 0)),
						MORALE_NAMES.get(int(clicked_unit.state.morale), "Đã hạ"),
					])
					return

	_map_view.select_hex(axial)


func hover_world_position(world_pos: Vector2) -> void:
	var axial: Vector2i = HexMath.world_to_axial(world_pos, _map_view.hex_size)
	_map_view.preview_path_to(axial)

	var selected: BattleUnit = _map_view.get_selected_unit()
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
			_set_bottom_banner("DỰ BÁO ĐÁNH [%s -> %s]: ST %d~%d | Crit %d%% (~%d) | Phản kích %d~%d | Khắc chế %d%%%s" % [
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
	if _controller == null:
		return false
	if _controller.undo_last_action():
		_map_view.refresh_units()
		var sel: BattleUnit = _map_view.get_selected_unit()
		if sel != null:
			_map_view.select_hex(sel.hex_position)
		_set_bottom_banner("Đã Hoàn Tác (Undo 1/1) bước di chuyển về ô cũ & hoàn trả đủ MP!")
		return true
	_set_bottom_banner("Không thể Undo (chưa đi / đã hành động / vào ZoC / dính bẫy / đã dùng 1 lần Undo).")
	return false


func try_wait_selected() -> bool:
	var sel: BattleUnit = _map_view.get_selected_unit()
	if sel == null or sel.faction_id != _controller.current_faction_id:
		return false
	if _controller.submit_command(BattleCommands.WaitCommand.new(_controller.current_faction_id, sel.unit_id)):
		_map_view.refresh_units()
		_map_view.clear_selection()
		_set_bottom_banner("Đơn vị [%s] chốt vị trí Đợi." % sel.display_name)
		return true
	return false


func end_active_faction_turn() -> bool:
	if _controller == null:
		return false
	if _controller.submit_command(BattleCommands.EndTurnCommand.new(_controller.current_faction_id)):
		_map_view.clear_selection()
		_map_view.refresh_units()
		var next_fac: String = "Đại Việt" if _controller.current_faction_id == 1 else "Đại Nguyên"
		_set_bottom_banner("Chuyển sang Vòng %d — Lượt của phe %s!" % [_controller.current_round, next_fac])
		return true
	return false


func verify_deterministic_replay_live() -> bool:
	if _controller == null:
		return false
	var replay_payload: Dictionary = _controller.export_replay()
	var verify_map := BattleMapState.new(_map_state.width, _map_state.height, BattleMapState.TerrainType.PLAINS)
	if _is_stress_mode:
		_populate_stress_30x30(verify_map, _stress_unit_count)
	else:
		_populate_bach_dang_12x10(verify_map)

	var verify_ctrl := BattleGameController.new(verify_map, DEFAULT_BATTLE_SEED, [1, 3], _controller.max_rounds)
	if not verify_ctrl.replay_from_dict(replay_payload):
		_set_bottom_banner("[REPLAY ERROR] Không thể phát lại chuỗi lệnh!")
		return false

	var live_units: Array[BattleUnit] = _map_state.get_all_units()
	var rep_units: Array[BattleUnit] = verify_map.get_all_units()
	if live_units.size() != rep_units.size():
		_set_bottom_banner("[REPLAY DESYNC] Sai lệch quân số!")
		return false

	for u_live: BattleUnit in live_units:
		var u_rep: BattleUnit = verify_ctrl.context.get_unit(u_live.unit_id)
		if u_rep == null or u_rep.state.current_hp != u_live.state.current_hp or u_rep.hex_position != u_live.hex_position:
			_set_bottom_banner("[REPLAY DESYNC] Lệch HP/tọa độ tại đơn vị %d!" % u_live.unit_id)
			return false

	var rng_match: bool = (verify_ctrl.context.rng.get_state() == _controller.context.rng.get_state())
	_set_bottom_banner("[REPLAY VERIFIED 100%%] Phát lại %d lệnh từ Seed %d khớp tuyệt đối từng điểm HP, Sĩ khí & RNG (%s)!" % [
		_controller.command_history.get_replay_stream_size(),
		DEFAULT_BATTLE_SEED,
		"OK" if rng_match else "DIFF",
	])
	return rng_match


func _set_bottom_banner(msg: String) -> void:
	_status_banner = msg
	if _selection_label != null:
		_selection_label.text = msg


func _on_camera_strategic_lod_changed(use_tokens: bool) -> void:
	_map_view.set_strategic_lod(use_tokens)


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
