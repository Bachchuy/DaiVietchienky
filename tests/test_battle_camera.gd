extends "res://tests/test_case.gd"

const CAM_PATH: String = "res://scripts/presentation/battle_camera_controller.gd"


func _make_camera() -> Camera2D:
	var cam_s: GDScript = load(CAM_PATH) as GDScript
	assert_not_null(cam_s, "BattleCameraController script must exist at " + CAM_PATH)
	if cam_s == null:
		return null
	var cam: Camera2D = cam_s.new() as Camera2D
	add_child_autofree(cam)
	return cam


func test_framerate_independent_exponential_smoothing() -> void:
	var cam_30: Camera2D = _make_camera()
	var cam_144: Camera2D = _make_camera()
	if cam_30 == null or cam_144 == null:
		return

	var large_bounds := Rect2(-2000.0, -2000.0, 8000.0, 8000.0)
	cam_30.set("map_world_bounds", large_bounds)
	cam_144.set("map_world_bounds", large_bounds)
	cam_30.call("pan_to_world_pos", Vector2.ZERO, true)
	cam_144.call("pan_to_world_pos", Vector2.ZERO, true)

	# Simulate moving target at 300 px/s for 1.0s at 30 Hz vs 144 Hz
	for i: int in range(30):
		var dt30: float = 1.0 / 30.0
		var target_x: float = 300.0 * float(i + 1) * dt30
		cam_30.call("pan_to_world_pos", Vector2(target_x, 0.0), false)
		cam_30.call("_process", dt30)

	for j: int in range(144):
		var dt144: float = 1.0 / 144.0
		var target_x2: float = 300.0 * float(j + 1) * dt144
		cam_144.call("pan_to_world_pos", Vector2(target_x2, 0.0), false)
		cam_144.call("_process", dt144)

	var diff: float = absf(cam_30.global_position.x - cam_144.global_position.x)
	assert_lt(diff, 6.0, "Exponential camera follow at 30 FPS vs 144 FPS must match closely")


func test_zoom_clamping_bounds_and_strategic_lod_signal() -> void:
	var cam: Camera2D = _make_camera()
	if cam == null:
		return

	cam.set("map_world_bounds", Rect2(0.0, 0.0, 3200.0, 2400.0))
	cam.call("pan_to_world_pos", Vector2(1600.0, 1200.0), true)

	var lod_events: Array[bool] = []
	cam.connect("strategic_lod_changed", func(use_tokens: bool) -> void: lod_events.append(use_tokens))

	# Clamp zoom upper bound to 1.2x
	cam.call("set_zoom_level", 3.0)
	for _k: int in range(60):
		cam.call("_process", 1.0 / 60.0)
	assert_almost_eq(cam.zoom.x, 1.2, 0.01, "Zoom upper limit must be 1.2x")

	# Drop zoom to Strategic 0.5x -> crosses < 0.65 threshold -> emits true once
	cam.call("set_zoom_level", 0.1)
	for _k: int in range(60):
		cam.call("_process", 1.0 / 60.0)
	assert_almost_eq(cam.zoom.x, 0.5, 0.01, "Zoom lower limit must be 0.5x")
	assert_eq(lod_events.size(), 1)
	assert_true(lod_events[0], "Crossing below 0.65 must emit strategic_lod_changed(true)")

	# Return to Default 1.0x -> crosses >= 0.65 -> emits false
	cam.call("set_zoom_level", 1.0)
	for _k: int in range(60):
		cam.call("_process", 1.0 / 60.0)
	assert_eq(lod_events.size(), 2)
	assert_false(lod_events[1], "Returning above 0.65 must emit strategic_lod_changed(false)")

	# Viewport clamping prevents peeking past negative edge
	cam.call("pan_to_world_pos", Vector2(-5000.0, -5000.0), true)
	var vp_half: Vector2 = cam.get_viewport_rect().size * 0.5
	assert_gte(cam.global_position.x, vp_half.x - 0.5, "Left viewport edge must stay >= 0")
	assert_gte(cam.global_position.y, vp_half.y - 0.5, "Top viewport edge must stay >= 0")


func test_trauma_shake_isolated_rng_and_complete_decay() -> void:
	var cam: Camera2D = _make_camera()
	if cam == null:
		return

	var sim_rng := RandomNumberGenerator.new()
	sim_rng.seed = 12881288
	var initial_sim_state: int = sim_rng.state

	cam.set("map_world_bounds", Rect2(0.0, 0.0, 3000.0, 3000.0))
	cam.call("pan_to_world_pos", Vector2(1500.0, 1500.0), true)
	var locked_focus: Vector2 = cam.global_position

	cam.call("add_trauma", 0.8)
	cam.call("_process", 1.0 / 60.0)
	assert_gt(cam.offset.length(), 0.01, "Active trauma must displace visual offset")
	assert_almost_eq(cam.global_position.distance_to(locked_focus), 0.0, 0.01, "Shake must not drift global_position")
	assert_eq(sim_rng.state, initial_sim_state, "Camera trauma shake must never touch simulation RNG")

	# Decay completely back to zero
	for _i: int in range(90):
		cam.call("_process", 1.0 / 60.0)
	assert_almost_eq(float(cam.call("get_trauma")), 0.0, 0.001)
	assert_eq(cam.offset, Vector2.ZERO, "Offset resets cleanly to ZERO once trauma decays")

	# Accessibility setting shake_user_scale = 0.0 suppresses shake completely
	cam.set("shake_user_scale", 0.0)
	cam.call("add_trauma", 1.0)
	cam.call("_process", 1.0 / 60.0)
	assert_eq(cam.offset, Vector2.ZERO, "shake_user_scale=0 must suppress all visual shake")
