extends "res://tests/test_case.gd"

const SANDBOX_SCENE_PATH: String = "res://scenes/battle/battle_sandbox_cp1.tscn"
const HexMathScript = preload("res://scripts/core/hex_math.gd")


func _load_sandbox() -> Node2D:
	var packed: PackedScene = load(SANDBOX_SCENE_PATH) as PackedScene
	assert_not_null(packed, "CP1 sandbox scene must exist at " + SANDBOX_SCENE_PATH)
	if packed == null:
		return null
	var inst: Node2D = packed.instantiate() as Node2D
	add_child_autofree(inst)
	return inst


func test_cp1_bach_dang_12x10_scene_loads_and_unit_selection_overlays_exact() -> void:
	var sandbox: Node2D = _load_sandbox()
	if sandbox == null:
		return

	var map_state: BattleMapState = sandbox.call("get_map_state") as BattleMapState
	var nav: HexGridNavigator = sandbox.call("get_navigator") as HexGridNavigator
	var map_view: BattleMapView = sandbox.call("get_map_view") as BattleMapView

	assert_not_null(map_state)
	assert_not_null(nav)
	assert_not_null(map_view)
	assert_eq(map_state.width, 12)
	assert_eq(map_state.height, 10)

	var signal_dock_axial: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(2, 8))
	assert_eq(map_state.get_terrain(signal_dock_axial), BattleMapState.TerrainType.ROAD_PORT, "SignalDock (2,8) is ROAD_PORT")

	var all_units: Array[BattleUnit] = map_state.get_all_units()
	assert_gte(float(all_units.size()), 8.0, "12x10 Bach Dang preview should spawn tactical units")

	var target_unit: BattleUnit = null
	for u: BattleUnit in all_units:
		if u.faction_id == 1:
			target_unit = u
			break
	assert_not_null(target_unit, "Must have at least one Dai Viet unit")

	var click_pos: Vector2 = HexMathScript.axial_to_world(target_unit.hex_position, map_view.hex_size)
	sandbox.call("click_world_position", click_pos)

	assert_eq(map_view.get_selected_unit(), target_unit)
	var expected_reach: Dictionary = nav.get_reachable_hexes(map_state, target_unit)
	var actual_reach: Dictionary = map_view.get_reachable_overlay_hexes()
	assert_eq(actual_reach.size(), expected_reach.size(), "Blue reachable hexes must match 100%")
	for hex_key: Vector2i in expected_reach.keys():
		assert_has(actual_reach, hex_key)

	# Pick a reachable destination and verify A* path preview
	for r_hex: Vector2i in actual_reach.keys():
		if r_hex != target_unit.hex_position:
			sandbox.call("hover_world_position", HexMathScript.axial_to_world(r_hex, map_view.hex_size))
			assert_gte(float(map_view.get_preview_path().size()), 2.0, "Hovering reachable hex draws A* path")
			break


func test_cp1_stress_30x30_with_44_units_maintains_60fps_budget_and_strategic_zoom() -> void:
	var sandbox: Node2D = _load_sandbox()
	if sandbox == null:
		return

	sandbox.call("load_stress_benchmark_30x30", 44)
	var map_state: BattleMapState = sandbox.call("get_map_state") as BattleMapState
	var map_view: BattleMapView = sandbox.call("get_map_view") as BattleMapView
	var camera: BattleCameraController = sandbox.call("get_camera") as BattleCameraController

	assert_eq(map_state.width, 30)
	assert_eq(map_state.height, 30)
	assert_gte(float(map_state.get_all_units().size()), 44.0, "Stress test must spawn >= 44 active units")

	# Select a central unit so blue/red overlays are active during frame benchmark
	var units: Array[BattleUnit] = map_state.get_all_units()
	sandbox.call("click_world_position", HexMathScript.axial_to_world(units[0].hex_position, map_view.hex_size))

	camera.set_zoom_level(BattleCameraController.ZOOM_STRATEGIC, false)
	var start_usec: int = Time.get_ticks_usec()
	var frames: int = 60
	for i: int in range(frames):
		camera._process(1.0 / 60.0)
		sandbox.call("_process", 1.0 / 60.0)
		if i == 20 or i == 40:
			var sample_u: BattleUnit = units[i % units.size()]
			sandbox.call("click_world_position", HexMathScript.axial_to_world(sample_u.hex_position, map_view.hex_size))
	var total_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_frame_ms: float = total_ms / float(frames)

	assert_true(map_view.is_strategic_lod(), "Zooming to 0.5x must activate StrategicTokenLayer LOD")
	assert_lt(avg_frame_ms, 16.67, "CP1 Tech DoD: 30x30 + 44 units must stay <= 16.67 ms/frame (60 FPS)")
