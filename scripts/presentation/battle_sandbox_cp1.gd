class_name BattleSandboxCP1
extends Node2D

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

var _troop_defs: Dictionary[int, Dictionary] = {}
var _map_state: BattleMapState = null
var _navigator: HexGridNavigator = HexGridNavigator.new()
var _map_view: BattleMapView = null
var _camera: BattleCameraController = null

var _mode_label: Label = null
var _selection_label: Label = null
var _perf_label: Label = null
var _current_mode_title: String = ""


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

	# Top compact status bar (< 46px height -> >90% screen remains pure Map-First!)
	var top_panel := PanelContainer.new()
	top_panel.name = "TopStatusBar"
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 44.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.88)
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

	# Bottom compact inspection bar
	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BottomInspectBar"
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -38.0
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.10, 0.09, 0.08, 0.86)
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
	_selection_label.text = "Click trái: Chọn đơn vị / Xem vùng đi xanh & tầm bắn đỏ | Di chuột: Đường đi A* | [1/2/3] Zoom | [F1] 12x10 | [F2] Stress 30x30 (44 quân) | [T] Trauma Shake"
	bottom_panel.add_child(_selection_label)


func _process(_delta: float) -> void:
	if _perf_label != null and _camera != null and _map_state != null:
		var fps: int = Engine.get_frames_per_second()
		var lod_text: String = "TOKEN (<0.65)" if _map_view.is_strategic_lod() else "MODEL (>=0.65)"
		_perf_label.text = "FPS: %d | Zoom: %.2fx [%s] | Quân số: %d" % [
			fps if fps > 0 else 60,
			_camera.zoom.x,
			lod_text,
			_map_state.get_all_units().size(),
		]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var world_pos: Vector2 = get_global_mouse_position()
			click_world_position(world_pos)
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
				KEY_T:
					_camera.add_trauma(0.45)
				_:
					pass


func load_bach_dang_preview_12x10() -> void:
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP1] — Sa bàn Bạch Đằng 12×10"
	_map_state = BattleMapState.new(12, 10, BattleMapState.TerrainType.PLAINS)

	# Sculpt Bach Dang river channel (diagonal river + shallow banks + hills + bamboo forest + stakes + SignalDock)
	for row: int in range(10):
		for col: int in range(12):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if col >= 5 and col <= 7:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.DEEP_WATER)
			elif col == 4 or col == 8:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.SHALLOW_RIVER)
			elif col <= 2 and row <= 4:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.FOREST)
			elif col >= 9 and row >= 2 and row <= 6:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.HILLS)

	# Sample StakedWater zone in central channel + SignalDock at odd-r (2, 8) + Enemy Fort at (9, 4)
	for stake_cell: Vector2i in [Vector2i(6, 4), Vector2i(6, 5), Vector2i(7, 5)]:
		_map_state.set_terrain(HexMath.odd_r_to_axial(stake_cell), BattleMapState.TerrainType.STAKED_WATER)

	var signal_dock: Vector2i = HexMath.odd_r_to_axial(Vector2i(2, 8))
	_map_state.set_terrain(signal_dock, BattleMapState.TerrainType.ROAD_PORT)
	_map_state.set_terrain(HexMath.odd_r_to_axial(Vector2i(3, 8)), BattleMapState.TerrainType.ROAD_PORT)

	var enemy_fort: Vector2i = HexMath.odd_r_to_axial(Vector2i(9, 4))
	_map_state.set_terrain(enemy_fort, BattleMapState.TerrainType.FORT)
	_map_state.set_fort_owner(enemy_fort, 3)

	# Spawn Dai Viet forces (Faction 1) & Dai Nguyen forces (Faction 3)
	_spawn_unit_from_troop(1, 1, 40101, Vector2i(2, 8), 3) # Spear Guard at SignalDock
	_spawn_unit_from_troop(2, 1, 40102, Vector2i(3, 5), 3) # Crossbowmen on west bank
	_spawn_unit_from_troop(3, 1, 40103, Vector2i(2, 6), 2) # Light Scout Cavalry (ignore_zoc)
	_spawn_unit_from_troop(4, 1, 40104, Vector2i(3, 7), 2) # War Elephant (devoid_zoc)
	_spawn_unit_from_troop(5, 1, 40201, Vector2i(5, 7), 3) # Dai Viet Light Warboat

	_spawn_unit_from_troop(101, 3, 40901, Vector2i(6, 2), 3) # Yuan Vanguard Warship
	_spawn_unit_from_troop(102, 3, 40901, Vector2i(7, 3), 3) # Yuan Main Fleet
	_spawn_unit_from_troop(103, 3, 40901, Vector2i(5, 4), 2) # Yuan Flank Ship
	_spawn_unit_from_troop(104, 3, 40101, Vector2i(9, 4), 3) # Yuan Fort Garrison
	_spawn_unit_from_troop(105, 3, 40102, Vector2i(9, 5), 2) # Yuan Hill Archers

	_apply_loaded_map()
	_map_view.set_key_area(signal_dock, 1)


func load_stress_benchmark_30x30(unit_count: int = 44) -> void:
	_current_mode_title = "ĐẠI VIỆT CHIẾN KỲ [CP1] — Stress Benchmark 30×30 (%d Đơn vị)" % unit_count
	_map_state = BattleMapState.new(30, 30, BattleMapState.TerrainType.PLAINS)

	for row: int in range(30):
		for col: int in range(30):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if col >= 13 and col <= 15:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.DEEP_WATER)
			elif col == 12 or col == 16:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.SHALLOW_RIVER)
			elif (col + row) % 7 == 0:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.FOREST)
			elif (col * 3 + row) % 11 == 0:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.HILLS)
			elif row == 14:
				_map_state.set_terrain(ax, BattleMapState.TerrainType.ROAD_PORT)

	var land_ids: Array[int] = [40101, 40102, 40103, 40104]
	var spawned: int = 0
	var uid: int = 1

	# Spawn balanced armies across west bank, river, and east bank
	for row: int in range(2, 28, 2):
		for col: int in [4, 8, 20, 24]:
			if spawned >= unit_count:
				break
			var faction: int = 1 if col < 12 else 3
			var t_id: int = land_ids[spawned % land_ids.size()]
			_spawn_unit_from_troop(uid, faction, t_id, Vector2i(col, row), 3)
			uid += 1
			spawned += 1
		if spawned < unit_count and row % 4 == 0:
			_spawn_unit_from_troop(uid, 1, 40201, Vector2i(13, row), 3)
			uid += 1
			spawned += 1
		if spawned < unit_count and row % 4 == 2:
			_spawn_unit_from_troop(uid, 3, 40901, Vector2i(15, row), 3)
			uid += 1
			spawned += 1

	_apply_loaded_map()


func _spawn_unit_from_troop(
	uid: int,
	faction: int,
	troop_id: int,
	offset_cell: Vector2i,
	stack_count: int = 1
) -> BattleUnit:
	var axial: Vector2i = HexMath.odd_r_to_axial(offset_cell)
	var def: Dictionary = _troop_defs.get(troop_id, {})
	var u: BattleUnit = BattleUnit.from_troop_dict(uid, faction, axial, def)
	u.troop_stack = stack_count
	u.state.max_hp = u.state.max_hp * stack_count
	u.state.current_hp = u.state.max_hp
	_map_state.place_unit(u)
	return u


func _apply_loaded_map() -> void:
	_map_view.bind_battle_state(_map_state, _navigator)
	var bounds: Rect2 = HexMath.compute_map_world_bounds(_map_state.width, _map_state.height, _map_view.hex_size, 48.0)
	_camera.map_world_bounds = bounds
	_camera.set_zoom_level(BattleCameraController.ZOOM_DEFAULT, true)
	_camera.pan_to_world_pos(bounds.get_center(), true)
	if _mode_label != null:
		_mode_label.text = _current_mode_title


func click_world_position(world_pos: Vector2) -> void:
	var axial: Vector2i = HexMath.world_to_axial(world_pos, _map_view.hex_size)
	_map_view.select_hex(axial)


func hover_world_position(world_pos: Vector2) -> void:
	var axial: Vector2i = HexMath.world_to_axial(world_pos, _map_view.hex_size)
	_map_view.preview_path_to(axial)


func _on_camera_strategic_lod_changed(use_tokens: bool) -> void:
	_map_view.set_strategic_lod(use_tokens)


func _on_hex_selected(axial: Vector2i, unit: BattleUnit) -> void:
	_update_selection_hud(axial, unit)


func _update_selection_hud(axial: Vector2i, unit: BattleUnit) -> void:
	if _selection_label == null or _map_state == null:
		return
	if not _map_view.has_selected_hex():
		_selection_label.text = "Chưa chọn ô | Click trái chọn đạo quân để kiểm tra vùng đi xanh (A* + ZoC/CoC) & vùng bắn đỏ (LOS)"
		return

	var offset: Vector2i = HexMath.axial_to_odd_r(axial)
	var t_enum: int = int(_map_state.get_terrain(axial))
	var t_name: String = TERRAIN_NAMES.get(t_enum, "Địa hình")

	if unit == null:
		_selection_label.text = "Ô Offset (%d, %d) / Axial (%d, %d) | %s | (Ô trống)" % [
			offset.x, offset.y, axial.x, axial.y, t_name
		]
	else:
		var faction_str: String = "Đại Việt" if unit.faction_id == 1 else "Đại Nguyên"
		var reach_count: int = maxi(0, _map_view.get_reachable_overlay_hexes().size() - 1)
		var atk_count: int = _map_view.get_attackable_overlay_hexes().size()
		_selection_label.text = "[%s] %s | Ô (%d,%d) %s | MP: %d/%d | Tầm: %d-%d | Vùng xanh: %d ô | Tầm đỏ: %d ô" % [
			faction_str,
			unit.display_name,
			offset.x,
			offset.y,
			t_name,
			unit.state.current_mp,
			unit.max_mp,
			unit.min_range,
			unit.max_range,
			reach_count,
			atk_count,
		]


func get_map_state() -> BattleMapState:
	return _map_state


func get_navigator() -> HexGridNavigator:
	return _navigator


func get_map_view() -> BattleMapView:
	return _map_view


func get_camera() -> BattleCameraController:
	return _camera
