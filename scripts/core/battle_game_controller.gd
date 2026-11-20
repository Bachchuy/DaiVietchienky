class_name BattleGameController
extends RefCounted

signal phase_changed(new_phase: int)
signal round_started(round_number: int)
signal faction_turn_started(faction_id: int, round_number: int)
signal command_executed(command_type: String, faction_id: int)
signal faction_turn_ended(faction_id: int)
signal round_ended(round_number: int)
signal battle_finished(outcome_code: int)

enum BattlePhase {
	PHASE_0_NOT_STARTED = 0,
	PHASE_1_BEGIN_ROUND = 1,
	PHASE_2_FACTION_TURN_START = 2,
	PHASE_3_DECISION_AND_PREVIEW = 3,
	PHASE_4_COMMAND_EXECUTION = 4,
	PHASE_5_IMMEDIATE_RESOLUTION = 5,
	PHASE_6_FACTION_TURN_END = 6,
	PHASE_7_END_ROUND = 7,
}

enum BattleOutcome {
	ONGOING = 0,
	VICTORY = 1,
	DEFEAT = 2,
}

var context: BattleContext = null
var command_history: CommandHistory = null
var director: ScenarioDirector = null
var event_manager: ScenarioEventManager = null
var victory_evaluator: ScenarioVictoryEvaluator = null
var economy: RefCounted = null:
	set(value):
		economy = value
		if context != null:
			context.economy = value

var faction_turn_order: Array[int] = [1, 3]
var player_faction_id: int = 1
var max_rounds: int = 10
var enable_economy: bool = false

var current_round: int = 0
var current_faction_id: int = 1
var current_phase: BattlePhase = BattlePhase.PHASE_0_NOT_STARTED
var outcome: BattleOutcome = BattleOutcome.ONGOING

var _turn_order_index: int = 0
var _custom_victory_evaluator: Callable = Callable()
var _had_initial_player_units: bool = false
var _had_initial_hostile_units: bool = false


func _init(
	p_map_state: BattleMapState,
	p_seed: int = 1,
	p_turn_order: Array = [1, 3],
	p_max_rounds: int = 10
) -> void:
	context = BattleContext.new(p_map_state, p_seed)
	command_history = CommandHistory.new(p_seed)
	faction_turn_order.clear()
	for f_val: Variant in p_turn_order:
		faction_turn_order.append(int(f_val))
	if faction_turn_order.is_empty():
		faction_turn_order = [1, 3]
	max_rounds = maxi(1, p_max_rounds)


func set_custom_victory_evaluator(eval_cb: Callable) -> void:
	_custom_victory_evaluator = eval_cb


func _sync_context_links() -> void:
	if director != null:
		context.director = director
	if victory_evaluator != null:
		context.victory_evaluator = victory_evaluator
	context.economy = economy
	context.current_round = current_round
	context.current_faction_id = current_faction_id


func start_battle() -> void:
	current_round = 0
	outcome = BattleOutcome.ONGOING
	context.forced_battle_outcome = 0
	command_history.clear_turn_undo_stack()
	_had_initial_player_units = false
	_had_initial_hostile_units = false
	for u: BattleUnit in context.map_state.get_all_units():
		if context.map_state.is_allied(player_faction_id, u.faction_id):
			_had_initial_player_units = true
		elif context.map_state.is_hostile(player_faction_id, u.faction_id):
			_had_initial_hostile_units = true
	_sync_context_links()
	_begin_next_round()


func _set_phase(p: BattlePhase) -> void:
	current_phase = p
	phase_changed.emit(int(p))


func _begin_next_round() -> void:
	if outcome != BattleOutcome.ONGOING:
		return
	_set_phase(BattlePhase.PHASE_1_BEGIN_ROUND)
	current_round += 1
	_sync_context_links()

	if enable_economy and economy != null and economy.has_method("process_begin_round") and current_round > 1:
		for f_id: int in faction_turn_order:
			economy.call("process_begin_round", f_id, context.map_state)

	if event_manager != null:
		event_manager.check_and_execute("OnRoundStart", context, self, director)
	round_started.emit(current_round)
	_check_immediate_victory_or_defeat()
	if outcome != BattleOutcome.ONGOING:
		return

	_turn_order_index = 0
	_start_faction_turn(faction_turn_order[_turn_order_index])


func _start_faction_turn(faction_id: int) -> void:
	if outcome != BattleOutcome.ONGOING:
		return
	_set_phase(BattlePhase.PHASE_2_FACTION_TURN_START)
	current_faction_id = faction_id
	_sync_context_links()
	command_history.clear_turn_undo_stack()

	var units: Array[BattleUnit] = context.map_state.get_all_units()
	units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.unit_id < b.unit_id)
	for u: BattleUnit in units:
		if u.faction_id == current_faction_id:
			u.state.on_faction_turn_start(u.max_mp)

	context.refresh_faction_vision(current_faction_id)
	if event_manager != null:
		event_manager.check_and_execute("OnFactionTurnStart", context, self, director)
	faction_turn_started.emit(current_faction_id, current_round)
	_check_immediate_victory_or_defeat()
	if outcome == BattleOutcome.ONGOING:
		_set_phase(BattlePhase.PHASE_3_DECISION_AND_PREVIEW)


func submit_command(cmd: BattleCommands.BaseCommand) -> bool:
	if cmd == null or outcome != BattleOutcome.ONGOING:
		return false
	if current_phase != BattlePhase.PHASE_3_DECISION_AND_PREVIEW:
		return false
	if cmd.faction_id != current_faction_id:
		return false

	if cmd is BattleCommands.EndTurnCommand:
		_set_phase(BattlePhase.PHASE_6_FACTION_TURN_END)
		if not command_history.execute_command(cmd, context):
			_set_phase(BattlePhase.PHASE_3_DECISION_AND_PREVIEW)
			return false
		command_executed.emit(cmd.get_command_type(), current_faction_id)
		faction_turn_ended.emit(current_faction_id)
		_advance_after_faction_turn_end()
		return true

	_set_phase(BattlePhase.PHASE_4_COMMAND_EXECUTION)
	context.last_command_payload.clear()
	if not command_history.execute_command(cmd, context):
		_set_phase(BattlePhase.PHASE_3_DECISION_AND_PREVIEW)
		return false
	command_executed.emit(cmd.get_command_type(), current_faction_id)

	_set_phase(BattlePhase.PHASE_5_IMMEDIATE_RESOLUTION)
	if event_manager != null:
		event_manager.check_and_execute(
			"OnAfterCommand",
			context,
			self,
			director,
			context.last_command_payload
		)
	_check_immediate_victory_or_defeat()
	if outcome == BattleOutcome.ONGOING:
		_set_phase(BattlePhase.PHASE_3_DECISION_AND_PREVIEW)
	return true


func _advance_after_faction_turn_end() -> void:
	_check_immediate_victory_or_defeat()
	if outcome != BattleOutcome.ONGOING:
		return

	_turn_order_index += 1
	if _turn_order_index < faction_turn_order.size():
		_start_faction_turn(faction_turn_order[_turn_order_index])
		return

	# Phase 7: OnEndRound
	_set_phase(BattlePhase.PHASE_7_END_ROUND)
	if event_manager != null:
		event_manager.check_and_execute("OnRoundEnd", context, self, director)
	_check_round_end_victory_or_defeat()
	round_ended.emit(current_round)
	if outcome == BattleOutcome.ONGOING:
		_begin_next_round()


func _check_immediate_victory_or_defeat() -> void:
	if _custom_victory_evaluator.is_valid():
		var res: int = int(_custom_victory_evaluator.call(self, false))
		if res != int(BattleOutcome.ONGOING):
			_finish_battle(res as BattleOutcome)
			return

	if victory_evaluator != null:
		var eval_res: int = victory_evaluator.evaluate_outcome(
			context.map_state,
			director,
			current_round,
			context.forced_battle_outcome,
			false
		)
		if eval_res != int(BattleOutcome.ONGOING):
			_finish_battle(eval_res as BattleOutcome)
		return

	if context.forced_battle_outcome != 0:
		_finish_battle(context.forced_battle_outcome as BattleOutcome)
		return

	var has_player_units: bool = false
	var has_hostile_units: bool = false
	for u: BattleUnit in context.map_state.get_all_units():
		if context.map_state.is_allied(player_faction_id, u.faction_id):
			has_player_units = true
		elif context.map_state.is_hostile(player_faction_id, u.faction_id):
			has_hostile_units = true

	if _had_initial_player_units and not has_player_units:
		_finish_battle(BattleOutcome.DEFEAT)
	elif _had_initial_hostile_units and not has_hostile_units:
		_finish_battle(BattleOutcome.VICTORY)


func _check_round_end_victory_or_defeat() -> void:
	if _custom_victory_evaluator.is_valid():
		var res: int = int(_custom_victory_evaluator.call(self, true))
		if res != int(BattleOutcome.ONGOING):
			_finish_battle(res as BattleOutcome)
			return

	if victory_evaluator != null:
		var eval_res: int = victory_evaluator.evaluate_outcome(
			context.map_state,
			director,
			current_round,
			context.forced_battle_outcome,
			true
		)
		if eval_res != int(BattleOutcome.ONGOING):
			_finish_battle(eval_res as BattleOutcome)
		return

	if current_round >= max_rounds and outcome == BattleOutcome.ONGOING:
		_finish_battle(BattleOutcome.DEFEAT)


func _finish_battle(final_outcome: BattleOutcome) -> void:
	outcome = final_outcome
	battle_finished.emit(int(outcome))


func can_undo() -> bool:
	if outcome != BattleOutcome.ONGOING or current_phase != BattlePhase.PHASE_3_DECISION_AND_PREVIEW:
		return false
	return command_history.can_undo_last(context)


func undo_last_action() -> bool:
	if not can_undo():
		return false
	return command_history.undo_last_command(context)


func export_replay() -> Dictionary:
	var data: Dictionary = command_history.to_dict()
	data["faction_turn_order"] = faction_turn_order.duplicate()
	data["max_rounds"] = max_rounds
	return data


func replay_from_dict(replay_dict: Dictionary) -> bool:
	var seed_val: int = int(str(replay_dict.get("initial_seed", "1")))
	context.rng = SeededRng.new(seed_val)
	command_history = CommandHistory.new(seed_val)
	if event_manager != null:
		event_manager.reset_runtime_state()
	if replay_dict.has("max_rounds"):
		max_rounds = int(replay_dict.get("max_rounds", max_rounds))
	if replay_dict.has("faction_turn_order") and replay_dict["faction_turn_order"] is Array:
		faction_turn_order.clear()
		for f_val: Variant in replay_dict["faction_turn_order"]:
			faction_turn_order.append(int(f_val))

	start_battle()

	var raw_stream: Variant = replay_dict.get("stream", [])
	if not (raw_stream is Array):
		return false

	for entry_var: Variant in raw_stream:
		if not (entry_var is Dictionary):
			return false
		var entry: Dictionary = entry_var
		var entry_type: String = str(entry.get("type", ""))
		if entry_type == "UndoLastMarch":
			if not undo_last_action():
				return false
		else:
			var cmd: BattleCommands.BaseCommand = BattleCommands.command_from_dict(entry)
			if cmd == null or not submit_command(cmd):
				return false
	return true
