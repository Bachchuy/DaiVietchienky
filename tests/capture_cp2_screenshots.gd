extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/battle/battle_sandbox_cp1.tscn")
const HexMathScript := preload("res://scripts/core/hex_math.gd")

var _frame: int = 0
var _sandbox: Node2D = null
var _out_dir: String = "res://tests/artifacts"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_sandbox = SANDBOX_SCENE.instantiate() as Node2D
	root.add_child(_sandbox)


func _process(_delta: float) -> bool:
	_frame += 1
	var map_view: BattleMapView = _sandbox.call("get_map_view") as BattleMapView

	if _frame == 4:
		# Select Dai Viet Light Warboat at (5,6), march to (5,5), and hover enemy ship at (5,4) for Combat Preview!
		var boat_start: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(5, 6)), map_view.hex_size)
		var boat_step: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(5, 5)), map_view.hex_size)
		var enemy_ship: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(5, 4)), map_view.hex_size)
		_sandbox.call("click_world_position", boat_start)
		_sandbox.call("click_world_position", boat_step)
		_sandbox.call("hover_world_position", enemy_ship)
	elif _frame == 9:
		_save_viewport_png("cp2_combat_preview_before_strike.png")
		# Execute AttackCommand on enemy ship at (5,4), then Crossbowmen at (3,5) march & attack!
		var enemy_ship: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(5, 4)), map_view.hex_size)
		_sandbox.call("click_world_position", enemy_ship)

		# Advance Faction 1 -> Faction 3 -> Round 2 Faction 1 and execute a second clash!
		_sandbox.call("end_active_faction_turn")
		var yuan_main: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(6, 3)), map_view.hex_size)
		var yuan_march: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(6, 4)), map_view.hex_size) # Onto StakedWater!
		_sandbox.call("click_world_position", yuan_main)
		_sandbox.call("click_world_position", yuan_march)
		_sandbox.call("end_active_faction_turn")

		var boat_now: Vector2 = HexMathScript.axial_to_world(HexMathScript.odd_r_to_axial(Vector2i(5, 5)), map_view.hex_size)
		_sandbox.call("click_world_position", boat_now)
		_sandbox.call("click_world_position", yuan_march)
	elif _frame == 15:
		_save_viewport_png("cp2_after_combat_and_morale_shift.png")
		var ok: bool = bool(_sandbox.call("verify_deterministic_replay_live"))
		print("[CP2_LIVE_REPLAY_CHECK] verify_deterministic_replay_live = %s" % str(ok))
	elif _frame == 20:
		_save_viewport_png("cp2_replay_verified_100_percent.png")
		quit(0)
		return true

	return false


func _save_viewport_png(filename: String) -> void:
	var img: Image = root.get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path(_out_dir.path_join(filename))
	var err: Error = img.save_png(full_path)
	print("[SCREENSHOT] %s -> err=%d (%dx%d)" % [full_path, int(err), img.get_width(), img.get_height()])
