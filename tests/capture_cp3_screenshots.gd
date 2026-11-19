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

	if _frame == 4:
		_save_viewport_png("cp3_bach_dang_round1_water_hidden.png")
		var safety: int = 0
		while ctrl.outcome == BattleGameController.BattleOutcome.ONGOING and ctrl.current_round < 4 and safety < 12:
			_sandbox.call("run_ai_for_current_faction")
			safety += 1
		print("[CP3_CAPTURE_R4] round=%d triggered=%s" % [ctrl.current_round, str(ctrl.event_manager.triggered_event_ids)])
	elif _frame == 10:
		_save_viewport_png("cp3_bach_dang_round4_tide_fall_stakes.png")
		var safety_fin: int = 0
		while ctrl.outcome == BattleGameController.BattleOutcome.ONGOING and safety_fin < 20:
			_sandbox.call("run_ai_for_current_faction")
			safety_fin += 1
		print("[CP3_CAPTURE_END_AI] outcome=%d round=%d" % [int(ctrl.outcome), ctrl.current_round])
		if ctrl.outcome != BattleGameController.BattleOutcome.VICTORY:
			_sandbox.call("load_bach_dang_preview_12x10")
			ctrl = _sandbox.call("get_controller") as BattleGameController
			_drive_dai_viet_tactical_victory(ctrl)
		var ok: bool = bool(_sandbox.call("verify_deterministic_replay_live"))
		print("[CP3_LIVE_REPLAY_CHECK] verify_deterministic_replay_live = %s (outcome=%d round=%d)" % [
			str(ok),
			int(ctrl.outcome),
			ctrl.current_round,
		])
	elif _frame == 16:
		_save_viewport_png("cp3_bach_dang_victory_stars.png")
		quit(0)
		return true

	return false


func _drive_dai_viet_tactical_victory(ctrl: BattleGameController) -> void:
	var map_view: BattleMapView = _sandbox.call("get_map_view") as BattleMapView
	var enemy_ai := AIDecisionMatrix.new(AIDifficultyProfile.create_preset(&"easy"))
	var safety: int = 0

	while ctrl.outcome == BattleGameController.BattleOutcome.ONGOING and safety < 24:
		if ctrl.current_faction_id == 1:
			_execute_focused_dai_viet_turn(ctrl)
		else:
			enemy_ai.execute_faction_turn(ctrl, ctrl.current_faction_id, ctrl.director)
		safety += 1

	_sandbox.call("_sync_objective_markers")
	map_view.refresh_all_layers()


func _execute_focused_dai_viet_turn(ctrl: BattleGameController) -> void:
	var ms: BattleMapState = ctrl.context.map_state
	var nav: HexGridNavigator = ctrl.context.navigator

	var unit_ids: Array[int] = []
	for u: BattleUnit in ms.get_all_units():
		if u.faction_id == 1 and u.state.is_alive() and not u.state.has_acted:
			unit_ids.append(u.unit_id)
	unit_ids.sort()

	for uid: int in unit_ids:
		if ctrl.outcome != BattleGameController.BattleOutcome.ONGOING or ctrl.current_faction_id != 1:
			break
		var unit: BattleUnit = ctrl.context.get_unit(uid)
		if unit == null or not unit.state.is_alive() or unit.state.has_acted:
			continue

		var o_ma_nhi: BattleUnit = _find_general(ms, 9001)
		if uid == 101:
			var direct_atks: Array[Vector2i] = nav.get_attackable_hexes(ms, unit, unit.hex_position)
			if o_ma_nhi != null and direct_atks.has(o_ma_nhi.hex_position):
				ctrl.submit_command(BattleCommands.AttackCommand.new(1, uid, o_ma_nhi.unit_id))
			elif unit.state.can_use_skill():
				ctrl.submit_command(BattleCommands.CastSkillCommand.new(1, uid, 10001, unit.hex_position))
			else:
				ctrl.submit_command(BattleCommands.WaitCommand.new(1, uid))
			continue

		if o_ma_nhi == null:
			ctrl.submit_command(BattleCommands.WaitCommand.new(1, uid))
			continue

		var reach: Dictionary[Vector2i, int] = nav.get_reachable_hexes(ms, unit)
		var best_dest: Vector2i = unit.hex_position
		var best_score: float = -INF
		var best_target_id: int = -1

		for dest: Vector2i in reach.keys():
			var atk_hexes: Array[Vector2i] = nav.get_attackable_hexes(ms, unit, dest)
			var dist_boss: int = HexMath.hex_distance(dest, o_ma_nhi.hex_position)
			var local_target: int = -1
			var attack_bonus: float = -float(dist_boss) * 12.0

			if atk_hexes.has(o_ma_nhi.hex_position):
				local_target = o_ma_nhi.unit_id
				attack_bonus += 2000.0
			else:
				var lowest_hp: int = 999999
				for ah: Vector2i in atk_hexes:
					var foe: BattleUnit = ms.get_unit_at(ah)
					if foe != null and ms.is_hostile(1, foe.faction_id) and foe.state.current_hp < lowest_hp:
						lowest_hp = foe.state.current_hp
						local_target = foe.unit_id
				if local_target > 0:
					attack_bonus += 250.0 - float(lowest_hp) * 0.25

			if attack_bonus > best_score:
				best_score = attack_bonus
				best_dest = dest
				best_target_id = local_target

		if best_dest != unit.hex_position:
			ctrl.submit_command(BattleCommands.MarchCommand.new(1, uid, unit.hex_position, best_dest))
		if ctrl.outcome != BattleGameController.BattleOutcome.ONGOING:
			break
		unit = ctrl.context.get_unit(uid)
		if unit != null and not unit.state.has_acted:
			if best_target_id > 0:
				var foe_now: BattleUnit = ctrl.context.get_unit(best_target_id)
				var post_atks: Array[Vector2i] = nav.get_attackable_hexes(ms, unit, unit.hex_position)
				if foe_now != null and foe_now.state.is_alive() and post_atks.has(foe_now.hex_position):
					ctrl.submit_command(BattleCommands.AttackCommand.new(1, uid, best_target_id))
					continue
			ctrl.submit_command(BattleCommands.WaitCommand.new(1, uid))

	if ctrl.outcome == BattleGameController.BattleOutcome.ONGOING and ctrl.current_faction_id == 1:
		ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))


func _find_general(map_state: BattleMapState, gid: int) -> BattleUnit:
	for u: BattleUnit in map_state.get_all_units():
		if u.general_id == gid:
			return u
	return null


func _save_viewport_png(filename: String) -> void:
	var img: Image = root.get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path(_out_dir.path_join(filename))
	var err: Error = img.save_png(full_path)
	print("[SCREENSHOT] %s -> err=%d (%dx%d)" % [full_path, int(err), img.get_width(), img.get_height()])
