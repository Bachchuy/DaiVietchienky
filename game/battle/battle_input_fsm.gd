class_name BattleInputFSM
extends Node

enum State {
	IDLE,
	UNIT_SELECTED,
	MOVING,
	POST_MOVE_ACTION,
	ATTACKING,
	SKILL_TARGETING,
	EXECUTE_SKILL,
}

signal state_changed(old_state: State, new_state: State)
signal unit_focused(unit: BattleUnit)
signal hex_inspected(axial: Vector2i, unit: BattleUnit)
signal action_rejected(reason: String)

const DEFAULT_SKILL_ID: int = 10001
const DEFAULT_SKILL_RANGE: int = 2
const DEFAULT_SKILL_AOE_RADIUS: int = 1

@export var session: BattleSession = null
@export var auto_complete_execution: bool = true

var _controller: BattleGameController = null
var _map_view: BattleMap = null
var _camera: BattleCameraController = null
var _current_state: State = State.IDLE
var _active_unit: BattleUnit = null
var _moved_this_action: bool = false
var _active_skill_id: int = DEFAULT_SKILL_ID
var _skill_range_hexes: Array[Vector2i] = []
var _pending_exec_outcome_state: State = State.IDLE
var _input_locked: bool = false

func bind_session(p_session: BattleSession, map_view: BattleMap, camera: BattleCameraController = null) -> void:
	session = p_session
	_controller = p_session.get_controller() if p_session != null else null
	_map_view = map_view
	_camera = camera
	_reset_to_idle(false)

func bind(controller: BattleGameController, map_view: BattleMap, camera: BattleCameraController = null) -> void:
	session = null
	_controller = controller
	_map_view = map_view
	_camera = camera
	_reset_to_idle(false)

func get_state() -> State:
	return _current_state

func get_active_unit() -> BattleUnit:
	return _active_unit

func has_moved_this_action() -> bool:
	return _moved_this_action

func set_input_locked(locked: bool) -> void:
	_input_locked = locked

func is_input_locked() -> bool:
	return _input_locked

func can_undo_post_move() -> bool:
	var ctrl: BattleGameController = _get_controller()
	return _current_state == State.POST_MOVE_ACTION and ctrl != null and ctrl.can_undo()

func can_active_unit_use_skill() -> bool:
	return _active_unit != null and _active_unit.general_id > 0 and not _active_unit.state.has_acted and _active_unit.state.can_use_skill()

func sync_with_controller() -> void:
	var ctrl: BattleGameController = _get_controller()
	if ctrl == null or ctrl.outcome != BattleGameController.BattleOutcome.ONGOING or ctrl.current_faction_id != ctrl.player_faction_id:
		_reset_to_idle(true)

func tap_world_position(world_pos: Vector2) -> void:
	var axial: Vector2i = _map_view.world_to_axial(world_pos) if _map_view != null else HexMath.world_to_axial(world_pos, HexMath.DEFAULT_HEX_SIZE)
	tap_hex(axial)

func hover_world_position(world_pos: Vector2) -> void:
	var axial: Vector2i = _map_view.world_to_axial(world_pos) if _map_view != null else HexMath.world_to_axial(world_pos, HexMath.DEFAULT_HEX_SIZE)
	hover_hex(axial)

func inspect_hex(axial: Vector2i) -> void:
	var ctrl: BattleGameController = _get_controller()
	if ctrl == null or ctrl.context == null or ctrl.context.map_state == null:
		return
	var map_state: BattleMapState = ctrl.context.map_state
	var unit: BattleUnit = map_state.get_unit_at(axial) if map_state.is_valid_hex(axial) else null
	unit_focused.emit(unit)
	hex_inspected.emit(axial, unit)

func tap_hex(axial: Vector2i) -> void:
	if not _check_player_input_allowed():
		return
	if _is_executing_state():
		action_rejected.emit("execution_in_progress")
		return
	var map_state: BattleMapState = _get_controller().context.map_state
	var is_valid: bool = map_state != null and map_state.is_valid_hex(axial)
	match _current_state:
		State.IDLE:
			_handle_tap_idle(axial, is_valid)
		State.UNIT_SELECTED:
			_handle_tap_unit_selected(axial, is_valid)
		State.POST_MOVE_ACTION:
			_handle_tap_post_move_action(axial, is_valid)
		State.SKILL_TARGETING:
			_handle_tap_skill_targeting(axial, is_valid)
		_:
			action_rejected.emit("invalid_state")

func hover_hex(axial: Vector2i) -> void:
	BattleInputRules.apply_hover_overlay(
		_get_controller(), _map_view, _current_state == State.UNIT_SELECTED,
		_current_state == State.SKILL_TARGETING, axial, _skill_range_hexes, DEFAULT_SKILL_AOE_RADIUS
	)

func enter_skill_targeting(skill_id: int = DEFAULT_SKILL_ID) -> bool:
	if not _check_player_input_allowed():
		return false
	if _current_state != State.UNIT_SELECTED and _current_state != State.POST_MOVE_ACTION:
		action_rejected.emit("skill_not_allowed_in_state")
		return false
	if not can_active_unit_use_skill():
		action_rejected.emit("skill_unavailable")
		return false
	_active_skill_id = skill_id
	_skill_range_hexes = BattleInputRules.compute_hexes_within_radius(_get_controller().context.map_state, _active_unit.hex_position, DEFAULT_SKILL_RANGE)
	if _map_view != null:
		_map_view.clear_move_and_attack_overlays()
		_map_view.set_skill_area_hexes(_skill_range_hexes, [])
	_transition_to(State.SKILL_TARGETING)
	return true

func request_undo() -> bool:
	if not _check_player_input_allowed():
		return false
	var ctrl: BattleGameController = _get_controller()
	if _current_state != State.POST_MOVE_ACTION or not ctrl.can_undo() or not BattleInputRules.undo_cmd(session, ctrl):
		action_rejected.emit("undo_unavailable")
		return false
	_moved_this_action = false
	BattleInputRules.refresh_after_undo(_map_view, _active_unit)
	_transition_to(State.UNIT_SELECTED)
	if _active_unit != null:
		unit_focused.emit(_active_unit)
		hex_inspected.emit(_active_unit.hex_position, _active_unit)
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
	var ctrl: BattleGameController = _get_controller()
	if not BattleInputRules.submit_cmd(session, ctrl, BattleCommands.WaitCommand.new(ctrl.current_faction_id, _active_unit.unit_id)):
		action_rejected.emit("wait_failed")
		return false
	_reset_to_idle(true)
	if _map_view != null:
		_map_view.refresh_units()
	return true

func cancel_or_deselect() -> bool:
	if not _check_player_input_allowed():
		return false
	var ctrl: BattleGameController = _get_controller()
	match _current_state:
		State.UNIT_SELECTED:
			_reset_to_idle(true)
			return true
		State.POST_MOVE_ACTION:
			if ctrl.can_undo():
				return request_undo()
			action_rejected.emit("cannot_undo_use_wait_or_action")
			return false
		State.SKILL_TARGETING:
			_cancel_skill_to_previous()
			return true
		State.IDLE:
			if _map_view != null and _map_view.has_selected_hex():
				_map_view.clear_selection()
				unit_focused.emit(null)
				hex_inspected.emit(Vector2i(-1, -1), null)
			return false
		_:
			return false

func complete_execution() -> void:
	var ctrl: BattleGameController = _get_controller()
	if _current_state == State.MOVING:
		var keep_unit: bool = _pending_exec_outcome_state != State.IDLE and ctrl != null and ctrl.outcome == BattleGameController.BattleOutcome.ONGOING and _active_unit != null and _active_unit.state.is_alive()
		if not keep_unit:
			_reset_to_idle(true)
			if _map_view != null:
				_map_view.refresh_all_layers()
			return
		BattleInputRules.refresh_after_move_complete(_map_view, _active_unit, true)
		unit_focused.emit(_active_unit)
		hex_inspected.emit(_active_unit.hex_position, _active_unit)
		_transition_to(State.POST_MOVE_ACTION)
	elif _current_state == State.ATTACKING or _current_state == State.EXECUTE_SKILL:
		_reset_to_idle(true)
		if _map_view != null:
			_map_view.refresh_all_layers()

func _handle_tap_idle(axial: Vector2i, is_valid: bool) -> void:
	var ctrl: BattleGameController = _get_controller()
	var clicked_unit: BattleUnit = ctrl.context.map_state.get_unit_at(axial) if is_valid else null
	if clicked_unit == null:
		if _map_view != null:
			_map_view.clear_selection()
		unit_focused.emit(null)
		hex_inspected.emit(axial, null)
		return
	_try_select_unit(clicked_unit, axial, ctrl.player_faction_id)

func _handle_tap_unit_selected(axial: Vector2i, is_valid: bool) -> void:
	if _active_unit == null or not _active_unit.state.is_alive() or not is_valid or axial == _active_unit.hex_position:
		_reset_to_idle(true)
		return
	var ctrl: BattleGameController = _get_controller()
	var map_state: BattleMapState = ctrl.context.map_state
	var clicked_unit: BattleUnit = map_state.get_unit_at(axial)
	if clicked_unit != null:
		if map_state.is_hostile(_active_unit.faction_id, clicked_unit.faction_id):
			_try_attack_hostile(clicked_unit, axial)
		else:
			_try_select_unit(clicked_unit, axial, ctrl.player_faction_id)
		return
	var reach: Dictionary[Vector2i, int] = ctrl.context.navigator.get_reachable_hexes(map_state, _active_unit)
	if reach.has(axial):
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
	var map_state: BattleMapState = _get_controller().context.map_state
	var clicked_unit: BattleUnit = map_state.get_unit_at(axial)
	if clicked_unit != null and map_state.is_hostile(_active_unit.faction_id, clicked_unit.faction_id):
		_try_attack_hostile(clicked_unit, axial)
		return
	action_rejected.emit("post_move_must_act_undo_or_wait")

func _try_select_unit(unit: BattleUnit, axial: Vector2i, player_faction_id: int) -> void:
	var reason: String = BattleInputRules.check_selectable_unit(unit, player_faction_id)
	if not reason.is_empty():
		_emit_reject_with_focus(unit, axial, reason)
		return
	_moved_this_action = false
	_skill_range_hexes.clear()
	_active_unit = unit
	if _map_view != null:
		_map_view.clear_skill_area_hexes()
		_map_view.select_hex(unit.hex_position)
	_transition_to(State.UNIT_SELECTED)
	unit_focused.emit(unit)
	hex_inspected.emit(unit.hex_position, unit)

func _try_attack_hostile(target_unit: BattleUnit, axial: Vector2i) -> void:
	var reason: String = BattleInputRules.check_hostile_target(_get_controller(), _active_unit, axial)
	if not reason.is_empty():
		if reason == "target_out_of_range":
			_emit_reject_with_focus(target_unit, axial, reason)
		else:
			action_rejected.emit(reason)
		return
	var ctrl: BattleGameController = _get_controller()
	_run_terminal_command(State.ATTACKING, BattleCommands.AttackCommand.new(ctrl.current_faction_id, _active_unit.unit_id, target_unit.unit_id), "attack_failed")

func _handle_tap_skill_targeting(axial: Vector2i, is_valid: bool) -> void:
	if is_valid and _skill_range_hexes.has(axial):
		var ctrl: BattleGameController = _get_controller()
		if _map_view != null:
			_map_view.clear_skill_area_hexes()
		_run_terminal_command(State.EXECUTE_SKILL, BattleCommands.CastSkillCommand.new(ctrl.current_faction_id, _active_unit.unit_id, _active_skill_id, axial), "skill_failed")
		return
	action_rejected.emit("skill_target_out_of_range")
	_cancel_skill_to_previous()

func _cancel_skill_to_previous() -> void:
	_skill_range_hexes.clear()
	BattleInputRules.refresh_post_skill_cancel_view(_map_view, _active_unit, _moved_this_action)
	_transition_to(State.POST_MOVE_ACTION if _moved_this_action else State.UNIT_SELECTED)

func _execute_march(dest_axial: Vector2i) -> void:
	var ctrl: BattleGameController = _get_controller()
	var unit: BattleUnit = _active_unit
	_transition_to(State.MOVING)
	var cmd := BattleCommands.MarchCommand.new(ctrl.current_faction_id, unit.unit_id, unit.hex_position, dest_axial)
	if not BattleInputRules.submit_cmd(session, ctrl, cmd):
		action_rejected.emit("march_failed")
		_transition_to(State.UNIT_SELECTED)
		return
	_moved_this_action = true
	var ended: bool = ctrl.outcome != BattleGameController.BattleOutcome.ONGOING or not unit.state.is_alive()
	_pending_exec_outcome_state = State.IDLE if ended else State.POST_MOVE_ACTION
	if auto_complete_execution:
		complete_execution()

func _run_terminal_command(exec_state: State, cmd: BattleCommands.BaseCommand, fail_reason: String) -> bool:
	var ctrl: BattleGameController = _get_controller()
	_transition_to(exec_state)
	if not BattleInputRules.submit_cmd(session, ctrl, cmd):
		action_rejected.emit(fail_reason)
		_transition_to(State.POST_MOVE_ACTION if _moved_this_action else State.UNIT_SELECTED)
		return false
	_pending_exec_outcome_state = State.IDLE
	if auto_complete_execution:
		complete_execution()
	return true

func _reset_to_idle(emit_signals: bool) -> void:
	var had_unit: bool = (_active_unit != null)
	_active_unit = null
	_moved_this_action = false
	_skill_range_hexes.clear()
	_pending_exec_outcome_state = State.IDLE
	if _map_view != null:
		_map_view.clear_selection()
	if emit_signals:
		_transition_to(State.IDLE)
		if had_unit:
			unit_focused.emit(null)
	else:
		_current_state = State.IDLE

func _transition_to(new_state: State) -> void:
	if _current_state == new_state:
		return
	var old_state: State = _current_state
	_current_state = new_state
	state_changed.emit(old_state, new_state)

func _emit_reject_with_focus(unit: BattleUnit, axial: Vector2i, reason: String) -> void:
	unit_focused.emit(unit)
	hex_inspected.emit(axial, unit)
	action_rejected.emit(reason)

func _is_executing_state() -> bool:
	return _current_state == State.MOVING or _current_state == State.ATTACKING or _current_state == State.EXECUTE_SKILL

func _get_controller() -> BattleGameController:
	return session.get_controller() if session != null else _controller

func _check_player_input_allowed() -> bool:
	var reason: String = BattleInputRules.check_input_allowed(_get_controller(), _camera, _input_locked)
	if reason.is_empty():
		return true
	if (reason == "battle_ended" or reason == "not_player_turn") and _current_state != State.IDLE:
		_reset_to_idle(true)
	action_rejected.emit(reason)
	return false
