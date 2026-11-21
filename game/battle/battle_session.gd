class_name BattleSession
extends Node

signal battle_started(stage_id: int)
signal phase_changed(new_phase: int)
signal round_started(round_number: int)
signal faction_turn_started(faction_id: int, round_number: int)
signal faction_turn_ended(faction_id: int)
signal round_ended(round_number: int)
signal command_executed(command_type: String, faction_id: int, payload: Dictionary)
signal unit_moved(unit_id: int, from_hex: Vector2i, to_hex: Vector2i)
signal combat_resolved(attacker_id: int, defender_id: int, report: Dictionary)
signal skill_cast(caster_id: int, skill_id: int, target_hex: Vector2i)
signal unit_waited(unit_id: int)
signal undo_executed(unit_id: int)
signal scenario_event_triggered(event_id: String, action_type: String, payload: Dictionary)
signal battle_ended(outcome_code: int)
signal state_refreshed()

@export var registry: DataRegistry
@export var stage_def: StageDef
@export var stage_id: int = 10101
@export var default_seed: int = 12880409

var dialogues: Dictionary = {}
var _controller: BattleGameController = null
var _event_manager: ScenarioEventManager = null


func start_stage(p_stage_id: int = 10101, p_seed: int = 20260405) -> bool:
	var ctrl: BattleGameController = null
	var dlg: Dictionary = {}
	var resolved_id: int = p_stage_id
	if stage_def != null and (p_stage_id <= 0 or stage_def.stage_id == p_stage_id):
		ctrl = ScenarioLoader.load_stage_def(stage_def, p_seed, registry)
		dlg = stage_def.get_dialogues_dict()
		resolved_id = stage_def.stage_id
	else:
		ctrl = ScenarioLoader.load_stage(p_stage_id, p_seed, registry)
		dlg = ScenarioLoader.load_stage_dialogues(p_stage_id, registry)
	if ctrl == null:
		return false
	attach_controller(ctrl, resolved_id, dlg)
	battle_started.emit(stage_id)
	state_refreshed.emit()
	return true


func attach_controller(
	p_controller: BattleGameController,
	p_stage_id: int = 0,
	p_dialogues: Dictionary = {}
) -> void:
	_disconnect_controller_signals()
	_controller = p_controller
	if p_stage_id > 0:
		stage_id = p_stage_id
	dialogues = p_dialogues.duplicate(true)
	if _controller == null:
		return

	_controller.phase_changed.connect(_on_controller_phase_changed)
	_controller.round_started.connect(_on_controller_round_started)
	_controller.faction_turn_started.connect(_on_controller_faction_turn_started)
	_controller.command_executed.connect(_on_controller_command_executed)
	_controller.faction_turn_ended.connect(_on_controller_faction_turn_ended)
	_controller.round_ended.connect(_on_controller_round_ended)
	_controller.battle_finished.connect(_on_controller_battle_finished)

	_event_manager = _controller.event_manager
	if _event_manager != null:
		_event_manager.event_triggered.connect(_on_event_manager_triggered)


func submit(command: BattleCommands.BaseCommand) -> bool:
	if _controller == null or command == null:
		return false
	var ok: bool = _controller.submit_command(command)
	if not ok:
		return false

	if command is BattleCommands.MarchCommand:
		var m_cmd: BattleCommands.MarchCommand = command as BattleCommands.MarchCommand
		unit_moved.emit(m_cmd.unit_id, m_cmd.from_hex, m_cmd.to_hex)
	elif command is BattleCommands.AttackCommand:
		var a_cmd: BattleCommands.AttackCommand = command as BattleCommands.AttackCommand
		var rep: Dictionary = _controller.context.get_last_combat_report().duplicate(true) if _controller.context != null else {}
		combat_resolved.emit(a_cmd.attacker_id, a_cmd.target_id, rep)
	elif command is BattleCommands.CastSkillCommand:
		var s_cmd: BattleCommands.CastSkillCommand = command as BattleCommands.CastSkillCommand
		skill_cast.emit(s_cmd.caster_id, s_cmd.skill_id, s_cmd.target_hex)
	elif command is BattleCommands.WaitCommand:
		var w_cmd: BattleCommands.WaitCommand = command as BattleCommands.WaitCommand
		unit_waited.emit(w_cmd.unit_id)

	state_refreshed.emit()
	return true


func undo_last_action() -> bool:
	if not can_undo():
		return false
	var undo_uid: int = 0
	if _controller.command_history != null:
		var last_cmd: BattleCommands.BaseCommand = _controller.command_history.get_last_command()
		if last_cmd is BattleCommands.MarchCommand:
			undo_uid = (last_cmd as BattleCommands.MarchCommand).unit_id
	if not _controller.undo_last_action():
		return false
	undo_executed.emit(undo_uid)
	state_refreshed.emit()
	return true


func can_undo() -> bool:
	return _controller != null and _controller.can_undo()


func end_player_turn() -> bool:
	if not is_ongoing() or not is_player_turn():
		return false
	return submit(BattleCommands.EndTurnCommand.new(get_current_faction_id()))


func get_controller() -> BattleGameController:
	return _controller


func get_map_state() -> BattleMapState:
	if _controller == null or _controller.context == null:
		return null
	return _controller.context.map_state


func get_navigator() -> HexGridNavigator:
	if _controller == null or _controller.context == null:
		return null
	return _controller.context.navigator


func get_context() -> BattleContext:
	if _controller == null:
		return null
	return _controller.context


func get_unit(unit_id: int) -> BattleUnit:
	if _controller == null or _controller.context == null:
		return null
	return _controller.context.get_unit(unit_id)


func get_unit_at(axial: Vector2i) -> BattleUnit:
	var ms: BattleMapState = get_map_state()
	return ms.get_unit_at(axial) if ms != null else null


func get_current_round() -> int:
	return _controller.current_round if _controller != null else 0


func get_max_rounds() -> int:
	return _controller.max_rounds if _controller != null else 0


func get_current_faction_id() -> int:
	return _controller.current_faction_id if _controller != null else 0


func get_player_faction_id() -> int:
	return _controller.player_faction_id if _controller != null else 1


func get_outcome() -> int:
	return int(_controller.outcome) if _controller != null else int(BattleGameController.BattleOutcome.ONGOING)


func is_player_turn() -> bool:
	return _controller != null and _controller.current_faction_id == _controller.player_faction_id


func is_ongoing() -> bool:
	return _controller != null and _controller.outcome == BattleGameController.BattleOutcome.ONGOING


func is_economy_enabled() -> bool:
	return _controller != null and _controller.enable_economy


func get_stage_dialogues() -> Dictionary:
	return dialogues


func _disconnect_controller_signals() -> void:
	if _controller != null:
		if _controller.phase_changed.is_connected(_on_controller_phase_changed):
			_controller.phase_changed.disconnect(_on_controller_phase_changed)
		if _controller.round_started.is_connected(_on_controller_round_started):
			_controller.round_started.disconnect(_on_controller_round_started)
		if _controller.faction_turn_started.is_connected(_on_controller_faction_turn_started):
			_controller.faction_turn_started.disconnect(_on_controller_faction_turn_started)
		if _controller.command_executed.is_connected(_on_controller_command_executed):
			_controller.command_executed.disconnect(_on_controller_command_executed)
		if _controller.faction_turn_ended.is_connected(_on_controller_faction_turn_ended):
			_controller.faction_turn_ended.disconnect(_on_controller_faction_turn_ended)
		if _controller.round_ended.is_connected(_on_controller_round_ended):
			_controller.round_ended.disconnect(_on_controller_round_ended)
		if _controller.battle_finished.is_connected(_on_controller_battle_finished):
			_controller.battle_finished.disconnect(_on_controller_battle_finished)
	if _event_manager != null and _event_manager.event_triggered.is_connected(_on_event_manager_triggered):
		_event_manager.event_triggered.disconnect(_on_event_manager_triggered)
	_event_manager = null


func _on_controller_phase_changed(new_phase: int) -> void:
	phase_changed.emit(new_phase)


func _on_controller_round_started(round_number: int) -> void:
	round_started.emit(round_number)


func _on_controller_faction_turn_started(faction_id: int, round_number: int) -> void:
	faction_turn_started.emit(faction_id, round_number)
	state_refreshed.emit()


func _on_controller_command_executed(command_type: String, faction_id: int) -> void:
	var payload: Dictionary = (
		_controller.context.last_command_payload.duplicate(true)
		if _controller != null and _controller.context != null
		else {}
	)
	command_executed.emit(command_type, faction_id, payload)


func _on_controller_faction_turn_ended(faction_id: int) -> void:
	faction_turn_ended.emit(faction_id)


func _on_controller_round_ended(round_number: int) -> void:
	round_ended.emit(round_number)


func _on_controller_battle_finished(outcome_code: int) -> void:
	battle_ended.emit(outcome_code)
	state_refreshed.emit()


func _on_event_manager_triggered(event_id: String, event_name: String) -> void:
	scenario_event_triggered.emit(event_id, event_name, {"event_name": event_name})
	state_refreshed.emit()
