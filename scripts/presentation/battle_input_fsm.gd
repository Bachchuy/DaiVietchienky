class_name BattleInputFSM
extends Node

enum State {
	IDLE,
	UNIT_SELECTED,
	MOVING,
	POST_MOVE_ACTION,
	AIMING_TARGET,
	ATTACKING,
	SKILL_TARGETING,
	EXECUTE_SKILL,
}

signal state_changed(old_state: State, new_state: State)
signal unit_focused(unit: BattleUnit)
signal target_preview_requested(attacker: BattleUnit, defender: BattleUnit, preview_dict: Dictionary)
signal target_preview_cleared()
signal action_rejected(reason: String)

const DEFAULT_SKILL_ID: int = 10001
const DEFAULT_SKILL_RANGE: int = 2
const DEFAULT_SKILL_AOE_RADIUS: int = 1

@export var auto_complete_execution: bool = true

var _controller: BattleGameController = null
var _map_view: BattleMapView = null
var _camera: BattleCameraController = null

var _current_state: State = State.IDLE
var _active_unit: BattleUnit = null
var _moved_this_action: bool = false
var _aim_target: BattleUnit = null
var _active_skill_id: int = DEFAULT_SKILL_ID
var _skill_range_hexes: Array[Vector2i] = []
var _pending_exec_outcome_state: State = State.IDLE
var _input_locked: bool = false


func bind(
	controller: BattleGameController,
	map_view: BattleMapView,
	camera: BattleCameraController = null
) -> void:
	_controller = controller
	_map_view = map_view
	_camera = camera
	_reset_to_idle(false)


func get_state() -> State:
	return _current_state


func get_active_unit() -> BattleUnit:
	return _active_unit


func get_aim_target() -> BattleUnit:
	return _aim_target


func has_moved_this_action() -> bool:
	return _moved_this_action


func set_input_locked(locked: bool) -> void:
	_input_locked = locked


func is_input_locked() -> bool:
	return _input_locked


func can_undo_post_move() -> bool:
	return (
		_current_state == State.POST_MOVE_ACTION
		and _controller != null
		and _controller.can_undo()
	)


func can_active_unit_use_skill() -> bool:
	if _active_unit == null:
		return false
	return (
		_active_unit.general_id > 0
		and not _active_unit.state.has_acted
		and _active_unit.state.can_use_skill()
	)


func sync_with_controller() -> void:
	if _controller == null:
		_reset_to_idle(true)
		return
	if (
		_controller.outcome != BattleGameController.BattleOutcome.ONGOING
		or _controller.current_faction_id != _controller.player_faction_id
	):
		_reset_to_idle(true)


func tap_world_position(world_pos: Vector2) -> void:
	var h_size: float = _map_view.hex_size if _map_view != null else HexMath.DEFAULT_HEX_SIZE
	var axial: Vector2i = HexMath.world_to_axial(world_pos, h_size)
	tap_hex(axial)


func hover_world_position(world_pos: Vector2) -> void:
	var h_size: float = _map_view.hex_size if _map_view != null else HexMath.DEFAULT_HEX_SIZE
	var axial: Vector2i = HexMath.world_to_axial(world_pos, h_size)
	hover_hex(axial)


func tap_hex(axial: Vector2i) -> void:
	if not _check_player_input_allowed():
		return
	if _is_executing_state():
		action_rejected.emit("execution_in_progress")
		return

	var map_state: BattleMapState = _controller.context.map_state
	var is_valid: bool = map_state != null and map_state.is_valid_hex(axial)

	match _current_state:
		State.IDLE:
			_handle_tap_idle(axial, is_valid)
		State.UNIT_SELECTED:
			_handle_tap_unit_selected(axial, is_valid)
		State.POST_MOVE_ACTION:
			_handle_tap_post_move_action(axial, is_valid)
		State.AIMING_TARGET:
			_handle_tap_aiming_target(axial, is_valid)
		State.SKILL_TARGETING:
			_handle_tap_skill_targeting(axial, is_valid)
		_:
			action_rejected.emit("invalid_state")


func hover_hex(axial: Vector2i) -> void:
	if _controller == null or _controller.context == null or _map_view == null:
		return
	var map_state: BattleMapState = _controller.context.map_state
	if map_state == null:
		return

	match _current_state:
		State.UNIT_SELECTED:
			_map_view.preview_path_to(axial)
		State.SKILL_TARGETING:
			if map_state.is_valid_hex(axial) and _skill_range_hexes.has(axial):
				var aoe: Array[Vector2i] = _compute_hexes_within_radius(map_state, axial, DEFAULT_SKILL_AOE_RADIUS)
				_map_view.set_skill_area_hexes(_skill_range_hexes, aoe)
			else:
				_map_view.set_skill_area_hexes(_skill_range_hexes, [])
		_:
			pass


func confirm_attack() -> bool:
	if not _check_player_input_allowed():
		return false
	if _current_state != State.AIMING_TARGET:
		action_rejected.emit("not_aiming_target")
		return false
	if _active_unit == null or _aim_target == null or not _aim_target.state.is_alive():
		_cancel_aiming_to_previous()
		action_rejected.emit("invalid_target")
		return false
	if not _active_unit.state.can_attack():
		action_rejected.emit("attack_disabled")
		return false
	return _execute_attack()


func enter_skill_targeting(skill_id: int = DEFAULT_SKILL_ID) -> bool:
	if not _check_player_input_allowed():
		return false
	if _current_state != State.UNIT_SELECTED and _current_state != State.POST_MOVE_ACTION:
		action_rejected.emit("skill_not_allowed_in_state")
		return false
	if not can_active_unit_use_skill():
		action_rejected.emit("skill_unavailable")
		return false

	var map_state: BattleMapState = _controller.context.map_state
	_active_skill_id = skill_id
	_skill_range_hexes = _compute_hexes_within_radius(
		map_state,
		_active_unit.hex_position,
		DEFAULT_SKILL_RANGE
	)
	if _map_view != null:
		_map_view.clear_aim_target_hex()
		_map_view.clear_move_and_attack_overlays()
		_map_view.set_skill_area_hexes(_skill_range_hexes, [])
	_transition_to(State.SKILL_TARGETING)
	return true


func request_undo() -> bool:
	if not _check_player_input_allowed():
		return false
	if _current_state != State.POST_MOVE_ACTION or not _controller.can_undo():
		action_rejected.emit("undo_unavailable")
		return false
	if not _controller.undo_last_action():
		action_rejected.emit("undo_unavailable")
		return false

	_moved_this_action = false
	if _map_view != null:
		_map_view.refresh_all_layers()
		if _active_unit != null:
			_map_view.select_hex(_active_unit.hex_position)
	_transition_to(State.UNIT_SELECTED)
	if _active_unit != null:
		unit_focused.emit(_active_unit)
	return true


func request_wait() -> bool:
	if not _check_player_input_allowed():
		return false
	if _current_state != State.UNIT_SELECTED and _current_state != State.POST_MOVE_ACTION:
		action_rejected.emit("wait_not_allowed_in_state")
		return false
	if _active_unit == null or _active_unit.state.has_acted:
		action_rejected.emit("unit_has_acted")
		return false

	var cmd := BattleCommands.WaitCommand.new(_controller.current_faction_id, _active_unit.unit_id)
	if not _controller.submit_command(cmd):
		action_rejected.emit("wait_failed")
		return false

	_reset_to_idle(true)
	if _map_view != null:
		_map_view.refresh_units()
	return true


func cancel_or_deselect() -> bool:
	if not _check_player_input_allowed():
		return false

	match _current_state:
		State.UNIT_SELECTED:
			_reset_to_idle(true)
			return true
		State.POST_MOVE_ACTION:
			if _controller.can_undo():
				return request_undo()
			action_rejected.emit("cannot_undo_use_wait_or_action")
			return false
		State.AIMING_TARGET:
			_cancel_aiming_to_previous()
			return true
		State.SKILL_TARGETING:
			_cancel_skill_to_previous()
			return true
		State.IDLE:
			if _map_view != null and _map_view.has_selected_hex():
				_map_view.clear_selection()
				unit_focused.emit(null)
			return false
		_:
			return false


func complete_execution() -> void:
	match _current_state:
		State.MOVING:
			if (
				_pending_exec_outcome_state == State.IDLE
				or _controller == null
				or _controller.outcome != BattleGameController.BattleOutcome.ONGOING
				or _active_unit == null
				or not _active_unit.state.is_alive()
			):
				_reset_to_idle(true)
				if _map_view != null:
					_map_view.refresh_all_layers()
			else:
				if _map_view != null:
					_map_view.refresh_all_layers()
					_map_view.set_post_move_overlays(_active_unit)
				unit_focused.emit(_active_unit)
				_transition_to(State.POST_MOVE_ACTION)
		State.ATTACKING, State.EXECUTE_SKILL:
			_reset_to_idle(true)
			if _map_view != null:
				_map_view.refresh_all_layers()
		_:
			pass


func _handle_tap_idle(axial: Vector2i, is_valid: bool) -> void:
	if not is_valid:
		if _map_view != null:
			_map_view.clear_selection()
		unit_focused.emit(null)
		return

	var map_state: BattleMapState = _controller.context.map_state
	var clicked_unit: BattleUnit = map_state.get_unit_at(axial)
	if clicked_unit == null:
		if _map_view != null:
			_map_view.clear_selection()
		unit_focused.emit(null)
		return

	if clicked_unit.faction_id != _controller.player_faction_id:
		unit_focused.emit(clicked_unit)
		action_rejected.emit("not_player_unit")
		return

	if clicked_unit.state.has_acted:
		unit_focused.emit(clicked_unit)
		action_rejected.emit("unit_has_acted")
		return

	if (
		clicked_unit.state.morale == UnitCombatState.MoraleLevel.CHAOS
		or clicked_unit.state.chaos_turns > 0
	):
		unit_focused.emit(clicked_unit)
		action_rejected.emit("unit_in_chaos")
		return

	_enter_unit_selected(clicked_unit)


func _handle_tap_unit_selected(axial: Vector2i, is_valid: bool) -> void:
	if _active_unit == null or not _active_unit.state.is_alive():
		_reset_to_idle(true)
		return
	if not is_valid:
		_reset_to_idle(true)
		return

	if axial == _active_unit.hex_position:
		_reset_to_idle(true)
		return

	var map_state: BattleMapState = _controller.context.map_state
	var nav: HexGridNavigator = _controller.context.navigator
	var clicked_unit: BattleUnit = map_state.get_unit_at(axial)

	if clicked_unit != null:
		if map_state.is_hostile(_active_unit.faction_id, clicked_unit.faction_id):
			if not _active_unit.state.can_attack():
				action_rejected.emit("attack_disabled")
				return
			var atk_hexes: Array[Vector2i] = nav.get_attackable_hexes(
				map_state,
				_active_unit,
				_active_unit.hex_position
			)
			if not atk_hexes.has(axial):
				action_rejected.emit("target_out_of_range")
				return
			_enter_aiming_target(clicked_unit)
			return

		if clicked_unit.faction_id == _controller.player_faction_id:
			if clicked_unit.state.has_acted:
				action_rejected.emit("unit_has_acted")
				return
			if (
				clicked_unit.state.morale == UnitCombatState.MoraleLevel.CHAOS
				or clicked_unit.state.chaos_turns > 0
			):
				action_rejected.emit("unit_in_chaos")
				return
			_enter_unit_selected(clicked_unit)
			return

		action_rejected.emit("not_player_unit")
		return

	var reach: Dictionary[Vector2i, int] = nav.get_reachable_hexes(map_state, _active_unit)
	if reach.has(axial) and axial != _active_unit.hex_position:
		if not _active_unit.state.can_move():
			action_rejected.emit("march_disabled")
			return
		_execute_march(axial)
		return

	_reset_to_idle(true)


func _handle_tap_post_move_action(axial: Vector2i, is_valid: bool) -> void:
	if _active_unit == null or not _active_unit.state.is_alive():
		_reset_to_idle(true)
		return
	if not is_valid:
		action_rejected.emit("post_move_must_act_undo_or_wait")
		return

	if axial == _active_unit.hex_position:
		request_wait()
		return

	var map_state: BattleMapState = _controller.context.map_state
	var nav: HexGridNavigator = _controller.context.navigator
	var clicked_unit: BattleUnit = map_state.get_unit_at(axial)
	if clicked_unit != null and map_state.is_hostile(_active_unit.faction_id, clicked_unit.faction_id):
		if not _active_unit.state.can_attack():
			action_rejected.emit("attack_disabled")
			return
		var atk_hexes: Array[Vector2i] = nav.get_attackable_hexes(
			map_state,
			_active_unit,
			_active_unit.hex_position
		)
		if not atk_hexes.has(axial):
			action_rejected.emit("target_out_of_range")
			return
		_enter_aiming_target(clicked_unit)
		return

	action_rejected.emit("post_move_must_act_undo_or_wait")


func _handle_tap_aiming_target(axial: Vector2i, is_valid: bool) -> void:
	if _active_unit == null or _aim_target == null or not _aim_target.state.is_alive():
		_cancel_aiming_to_previous()
		return
	if not is_valid:
		_cancel_aiming_to_previous()
		return

	if axial == _aim_target.hex_position:
		confirm_attack()
		return

	var map_state: BattleMapState = _controller.context.map_state
	var nav: HexGridNavigator = _controller.context.navigator
	var clicked_unit: BattleUnit = map_state.get_unit_at(axial)
	if clicked_unit != null and map_state.is_hostile(_active_unit.faction_id, clicked_unit.faction_id):
		var atk_hexes: Array[Vector2i] = nav.get_attackable_hexes(
			map_state,
			_active_unit,
			_active_unit.hex_position
		)
		if atk_hexes.has(axial):
			_enter_aiming_target(clicked_unit)
		else:
			action_rejected.emit("target_out_of_range")
		return

	_cancel_aiming_to_previous()


func _handle_tap_skill_targeting(axial: Vector2i, is_valid: bool) -> void:
	if is_valid and _skill_range_hexes.has(axial):
		_execute_skill(axial)
		return
	action_rejected.emit("skill_target_out_of_range")
	_cancel_skill_to_previous()


func _enter_unit_selected(unit: BattleUnit) -> void:
	_moved_this_action = false
	_aim_target = null
	_skill_range_hexes.clear()
	_active_unit = unit
	if _map_view != null:
		_map_view.clear_aim_target_hex()
		_map_view.clear_skill_area_hexes()
		_map_view.select_hex(unit.hex_position)
	_transition_to(State.UNIT_SELECTED)
	unit_focused.emit(unit)


func _enter_aiming_target(target_unit: BattleUnit) -> void:
	_aim_target = target_unit
	var preview: Dictionary = _controller.context.combat_resolver.preview_combat(
		_controller.context.map_state,
		_controller.context.navigator,
		_active_unit,
		target_unit
	)
	if _map_view != null:
		_map_view.set_aim_target_hex(target_unit.hex_position)
	_transition_to(State.AIMING_TARGET)
	target_preview_requested.emit(_active_unit, target_unit, preview)


func _cancel_aiming_to_previous() -> void:
	var had_aim: bool = (_aim_target != null or _current_state == State.AIMING_TARGET)
	_aim_target = null
	if _map_view != null:
		_map_view.clear_aim_target_hex()
	if had_aim:
		target_preview_cleared.emit()
	var back_state: State = State.POST_MOVE_ACTION if _moved_this_action else State.UNIT_SELECTED
	_transition_to(back_state)


func _cancel_skill_to_previous() -> void:
	_skill_range_hexes.clear()
	var back_state: State = State.POST_MOVE_ACTION if _moved_this_action else State.UNIT_SELECTED
	if _map_view != null:
		_map_view.clear_skill_area_hexes()
		if _active_unit != null and _active_unit.state.is_alive():
			if _moved_this_action:
				_map_view.set_post_move_overlays(_active_unit)
			else:
				_map_view.select_hex(_active_unit.hex_position)
	_transition_to(back_state)


func _execute_march(dest_axial: Vector2i) -> void:
	var unit: BattleUnit = _active_unit
	var from_hex: Vector2i = unit.hex_position
	_transition_to(State.MOVING)

	var cmd := BattleCommands.MarchCommand.new(
		_controller.current_faction_id,
		unit.unit_id,
		from_hex,
		dest_axial
	)
	if not _controller.submit_command(cmd):
		action_rejected.emit("march_failed")
		_transition_to(State.UNIT_SELECTED)
		return

	_moved_this_action = true
	var died_or_ended: bool = (
		_controller.outcome != BattleGameController.BattleOutcome.ONGOING
		or not unit.state.is_alive()
	)
	_pending_exec_outcome_state = State.IDLE if died_or_ended else State.POST_MOVE_ACTION
	if auto_complete_execution:
		complete_execution()


func _execute_attack() -> bool:
	var attacker: BattleUnit = _active_unit
	var defender: BattleUnit = _aim_target
	_transition_to(State.ATTACKING)
	if _map_view != null:
		_map_view.clear_aim_target_hex()
	target_preview_cleared.emit()

	var cmd := BattleCommands.AttackCommand.new(
		_controller.current_faction_id,
		attacker.unit_id,
		defender.unit_id
	)
	if not _controller.submit_command(cmd):
		action_rejected.emit("attack_failed")
		_aim_target = null
		_transition_to(State.POST_MOVE_ACTION if _moved_this_action else State.UNIT_SELECTED)
		return false

	_pending_exec_outcome_state = State.IDLE
	if auto_complete_execution:
		complete_execution()
	return true


func _execute_skill(target_hex: Vector2i) -> bool:
	var caster: BattleUnit = _active_unit
	_transition_to(State.EXECUTE_SKILL)
	if _map_view != null:
		_map_view.clear_skill_area_hexes()

	var cmd := BattleCommands.CastSkillCommand.new(
		_controller.current_faction_id,
		caster.unit_id,
		_active_skill_id,
		target_hex
	)
	if not _controller.submit_command(cmd):
		action_rejected.emit("skill_failed")
		_transition_to(State.POST_MOVE_ACTION if _moved_this_action else State.UNIT_SELECTED)
		return false

	_pending_exec_outcome_state = State.IDLE
	if auto_complete_execution:
		complete_execution()
	return true


func _reset_to_idle(emit_signals: bool) -> void:
	var had_aim: bool = (_aim_target != null)
	var had_unit: bool = (_active_unit != null)
	_active_unit = null
	_moved_this_action = false
	_aim_target = null
	_skill_range_hexes.clear()
	_pending_exec_outcome_state = State.IDLE

	if _map_view != null:
		_map_view.clear_selection()
	if emit_signals:
		if had_aim:
			target_preview_cleared.emit()
		_transition_to(State.IDLE)
		if had_unit:
			unit_focused.emit(null)
	else:
		_current_state = State.IDLE


func _transition_to(new_state: State) -> void:
	if _current_state == new_state:
		return
	var old_state: State = _current_state
	_exit_state(old_state)
	_current_state = new_state
	_enter_state(new_state)
	state_changed.emit(old_state, new_state)


func _enter_state(_state: State) -> void:
	pass


func _exit_state(_state: State) -> void:
	pass


func _is_executing_state() -> bool:
	return (
		_current_state == State.MOVING
		or _current_state == State.ATTACKING
		or _current_state == State.EXECUTE_SKILL
	)


func _check_player_input_allowed() -> bool:
	if _controller == null or _controller.context == null:
		action_rejected.emit("no_controller")
		return false
	if _controller.outcome != BattleGameController.BattleOutcome.ONGOING:
		if _current_state != State.IDLE:
			_reset_to_idle(true)
		action_rejected.emit("battle_ended")
		return false
	if _input_locked or (_camera != null and _camera.camera_locked):
		action_rejected.emit("input_locked")
		return false
	if _controller.current_faction_id != _controller.player_faction_id:
		if _current_state != State.IDLE:
			_reset_to_idle(true)
		action_rejected.emit("not_player_turn")
		return false
	if _controller.current_phase != BattleGameController.BattlePhase.PHASE_3_DECISION_AND_PREVIEW:
		action_rejected.emit("invalid_phase")
		return false
	return true


func _compute_hexes_within_radius(
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
