extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/battle/battle_sandbox_cp1.tscn")
const HexMathScript := preload("res://scripts/core/hex_math.gd")

var _frame: int = 0
var _sandbox: Node2D = null
var _out_dir: String = "res://tests/artifacts"
var _stress_frame_times_usec: Array[int] = []
var _last_tick_usec: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_sandbox = SANDBOX_SCENE.instantiate() as Node2D
	root.add_child(_sandbox)
	_last_tick_usec = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	var now_usec: int = Time.get_ticks_usec()
	var dt_usec: int = now_usec - _last_tick_usec
	_last_tick_usec = now_usec
	_frame += 1

	var map_view: BattleMapView = _sandbox.call("get_map_view") as BattleMapView
	var cam: BattleCameraController = _sandbox.call("get_camera") as BattleCameraController

	if _frame == 4:
		# Select Dai Viet Light Warboat (offset 5,7) & preview path up the channel to (5,5)
		var boat_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(5, 7))
		var path_goal: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(5, 5))
		_sandbox.call("click_world_position", HexMathScript.axial_to_world(boat_hex, map_view.hex_size))
		_sandbox.call("hover_world_position", HexMathScript.axial_to_world(path_goal, map_view.hex_size))
	elif _frame == 10:
		_save_viewport_png("cp1_bach_dang_12x10_tactical.png")
		# Switch to Strategic Zoom 0.5x on 12x10
		cam.set_zoom_level(0.5, true)
	elif _frame == 16:
		_save_viewport_png("cp1_bach_dang_12x10_strategic_tokens.png")
		# Switch to 30x30 Stress Benchmark with 44 units
		_sandbox.call("load_stress_benchmark_30x30", 44)
		cam.set_zoom_level(0.60, true) # Strategic Token mode on 30x30
		var sample_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(8, 14))
		_sandbox.call("click_world_position", HexMathScript.axial_to_world(sample_hex, map_view.hex_size))
	elif _frame > 18 and _frame <= 48:
		_stress_frame_times_usec.append(dt_usec)
	elif _frame == 50:
		_save_viewport_png("cp1_stress_30x30_44units.png")
		var sum_u: int = 0
		for v: int in _stress_frame_times_usec:
			sum_u += v
		var avg_ms: float = (float(sum_u) / maxf(1.0, float(_stress_frame_times_usec.size()))) / 1000.0
		var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("[CP1_VISUAL_BENCHMARK] 30x30 (44 units) rendered avg frame = %.2f ms (%.1f FPS equiv) | Draw calls = %d" % [
			avg_ms,
			1000.0 / maxf(avg_ms, 0.1),
			int(draw_calls),
		])
		quit(0)
		return true

	return false


func _save_viewport_png(filename: String) -> void:
	var img: Image = root.get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path(_out_dir.path_join(filename))
	var err: Error = img.save_png(full_path)
	print("[SCREENSHOT] %s -> err=%d (%dx%d)" % [full_path, int(err), img.get_width(), img.get_height()])
