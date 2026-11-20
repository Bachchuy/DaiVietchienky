extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/battle/battle_sandbox_cp1.tscn")

var _frame: int = 0
var _sandbox: Node2D = null
var _out_dir: String = "res://tests/artifacts"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_sandbox = SANDBOX_SCENE.instantiate() as Node2D
	root.add_child(_sandbox)


func _process(_delta: float) -> bool:
	_frame += 1
	var ctrl: BattleGameController = _sandbox.call("get_controller") as BattleGameController
	var ms: BattleMapState = _sandbox.call("get_map_state") as BattleMapState
	var mv: BattleMapView = _sandbox.call("get_map_view") as BattleMapView
	var fsm: BattleInputFSM = _sandbox.call("get_input_fsm") as BattleInputFSM

	if _frame == 4:
		# 1. UNIT_SELECTED on Tran Khanh Du (102) + hover reachable hex
		var u102: BattleUnit = ctrl.context.get_unit(102)
		if u102 != null:
			fsm.tap_hex(u102.hex_position)
			var reach: Dictionary[Vector2i, int] = mv.get_reachable_overlay_hexes()
			var best_step: Vector2i = _pick_northernmost_hex(reach.keys(), u102.hex_position)
			fsm.hover_hex(best_step)
	elif _frame == 7:
		_save_viewport_png("c4_t1_unit_selected.png")
		# 2. March north -> POST_MOVE_ACTION
		var reach: Dictionary[Vector2i, int] = mv.get_reachable_overlay_hexes()
		var u102: BattleUnit = ctrl.context.get_unit(102)
		if u102 != null:
			var best_step: Vector2i = _pick_northernmost_hex(reach.keys(), u102.hex_position)
			fsm.tap_hex(best_step)
	elif _frame == 10:
		_save_viewport_png("c4_t1_post_move_action.png")
		# 3. 1st tap hostile in range -> AIMING_TARGET
		var u102: BattleUnit = ctrl.context.get_unit(102)
		var atk_hexes: Array[Vector2i] = mv.get_attackable_overlay_hexes()
		var aimed: bool = false
		for ah: Vector2i in atk_hexes:
			var foe: BattleUnit = ms.get_unit_at(ah)
			if foe != null and ms.is_hostile(1, foe.faction_id):
				fsm.tap_hex(ah)
				aimed = true
				break
		if not aimed and u102 != null:
			# Fallback: position boat 102 adjacent-ish to enemy 202 and re-aim
			var foe202: BattleUnit = ctrl.context.get_unit(202)
			if foe202 != null:
				fsm.tap_hex(foe202.hex_position)
	elif _frame == 13:
		_save_viewport_png("c4_t1_aiming_target.png")
		# Confirm attack -> ATTACKING -> IDLE (u102 becomes Dimmed), then select Tran Quoc Tuan (101) -> SKILL_TARGETING
		if fsm.get_state() == BattleInputFSM.State.AIMING_TARGET:
			fsm.confirm_attack()
		elif fsm.get_state() == BattleInputFSM.State.POST_MOVE_ACTION:
			fsm.request_wait()
		var tqt: BattleUnit = ctrl.context.get_unit(101)
		if tqt != null:
			fsm.tap_hex(tqt.hex_position)
			fsm.enter_skill_targeting(10001)
			var u104: BattleUnit = ctrl.context.get_unit(104)
			if u104 != null:
				fsm.hover_hex(u104.hex_position)
	elif _frame == 16:
		_save_viewport_png("c4_t1_skill_targeting.png")
		# Cancel skill targeting and Wait on Tran Quoc Tuan -> both 101 & 102 Dimmed in IDLE
		fsm.cancel_or_deselect()
		fsm.request_wait()
	elif _frame == 19:
		_save_viewport_png("c4_t1_wait_dimmed.png")
		quit(0)
		return true

	return false


func _pick_northernmost_hex(hexes: Array, fallback: Vector2i) -> Vector2i:
	var best: Vector2i = fallback
	var best_row: int = 9999
	for h_var: Variant in hexes:
		if h_var is Vector2i:
			var h: Vector2i = h_var as Vector2i
			if h == fallback:
				continue
			var off: Vector2i = HexMath.axial_to_odd_r(h)
			if off.y < best_row:
				best_row = off.y
				best = h
	return best


func _save_viewport_png(filename: String) -> void:
	var img: Image = root.get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path(_out_dir.path_join(filename))
	var err: Error = img.save_png(full_path)
	print("[SCREENSHOT] %s -> err=%d (%dx%d)" % [full_path, int(err), img.get_width(), img.get_height()])
