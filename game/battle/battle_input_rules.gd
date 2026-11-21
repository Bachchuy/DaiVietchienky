class_name BattleInputRules
extends RefCounted


static func check_input_allowed(
	ctrl: BattleGameController,
	camera: BattleCameraController,
	input_locked: bool
) -> String:
	if ctrl == null or ctrl.context == null:
		return "no_controller"
	if ctrl.outcome != BattleGameController.BattleOutcome.ONGOING:
		return "battle_ended"
	if input_locked or (camera != null and camera.camera_locked):
		return "input_locked"
	if ctrl.current_faction_id != ctrl.player_faction_id:
		return "not_player_turn"
	if ctrl.current_phase != BattleGameController.BattlePhase.PHASE_3_DECISION_AND_PREVIEW:
		return "invalid_phase"
	return ""


static func check_selectable_unit(unit: BattleUnit, player_faction_id: int) -> String:
	if unit == null:
		return "no_unit"
	if unit.faction_id != player_faction_id:
		return "not_player_unit"
	if unit.state.has_acted:
		return "unit_has_acted"
	if unit.state.morale == UnitCombatState.MoraleLevel.CHAOS or unit.state.chaos_turns > 0:
		return "unit_in_chaos"
	return ""


static func check_hostile_target(
	ctrl: BattleGameController,
	attacker: BattleUnit,
	target_axial: Vector2i
) -> String:
	if not attacker.state.can_attack():
		return "attack_disabled"
	var atk_hexes: Array[Vector2i] = ctrl.context.navigator.get_attackable_hexes(
		ctrl.context.map_state,
		attacker,
		attacker.hex_position
	)
	if not atk_hexes.has(target_axial):
		return "target_out_of_range"
	return ""


static func submit_cmd(
	session: BattleSession,
	ctrl: BattleGameController,
	cmd: BattleCommands.BaseCommand
) -> bool:
	if session != null:
		return session.submit(cmd)
	return ctrl != null and ctrl.submit_command(cmd)


static func undo_cmd(session: BattleSession, ctrl: BattleGameController) -> bool:
	if session != null:
		return session.undo_last_action()
	return ctrl != null and ctrl.undo_last_action()


static func compute_hexes_within_radius(
	map_state: BattleMapState,
	center: Vector2i,
	radius: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map_state == null:
		return result
	for row: int in range(map_state.height):
		for col: int in range(map_state.width):
			var h: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if HexMath.hex_distance(center, h) <= radius:
				result.append(h)
	return result


static func apply_hover_overlay(
	ctrl: BattleGameController,
	map_view: BattleMapView,
	is_unit_selected: bool,
	is_skill_targeting: bool,
	axial: Vector2i,
	skill_range_hexes: Array[Vector2i],
	aoe_radius: int
) -> void:
	if ctrl == null or ctrl.context == null or map_view == null:
		return
	var map_state: BattleMapState = ctrl.context.map_state
	if map_state == null:
		return
	if is_unit_selected:
		map_view.preview_path_to(axial)
	elif is_skill_targeting:
		var aoe: Array[Vector2i] = []
		if map_state.is_valid_hex(axial) and skill_range_hexes.has(axial):
			aoe = compute_hexes_within_radius(map_state, axial, aoe_radius)
		map_view.set_skill_area_hexes(skill_range_hexes, aoe)


static func refresh_post_skill_cancel_view(
	map_view: BattleMapView,
	active_unit: BattleUnit,
	moved_this_action: bool
) -> void:
	if map_view == null:
		return
	map_view.clear_skill_area_hexes()
	if active_unit != null and active_unit.state.is_alive():
		if moved_this_action:
			map_view.set_post_move_overlays(active_unit)
		else:
			map_view.select_hex(active_unit.hex_position)


static func refresh_after_undo(map_view: BattleMapView, active_unit: BattleUnit) -> void:
	if map_view == null:
		return
	map_view.refresh_all_layers()
	if active_unit != null:
		map_view.select_hex(active_unit.hex_position)


static func refresh_after_move_complete(map_view: BattleMapView, active_unit: BattleUnit, keep_unit: bool) -> void:
	if map_view == null:
		return
	map_view.refresh_all_layers()
	if keep_unit and active_unit != null:
		map_view.set_post_move_overlays(active_unit)
