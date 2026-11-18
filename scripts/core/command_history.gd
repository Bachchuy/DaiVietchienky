class_name CommandHistory
extends RefCounted

var initial_seed: int = 1
var _next_command_id: int = 1
var _active_turn_stack: Array[BattleCommands.BaseCommand] = []
var _replay_stream: Array[Dictionary] = []


func _init(p_seed: int = 1) -> void:
	initial_seed = p_seed


func execute_command(cmd: BattleCommands.BaseCommand, ctx: BattleContext) -> bool:
	if cmd == null or ctx == null:
		return false
	cmd.command_id = _next_command_id
	if not cmd.execute(ctx):
		return false

	_next_command_id += 1
	_active_turn_stack.append(cmd)
	_replay_stream.append(cmd.to_dict())

	if cmd is BattleCommands.EndTurnCommand:
		_active_turn_stack.clear()
	return true


func can_undo_last(ctx: BattleContext) -> bool:
	if _active_turn_stack.is_empty() or ctx == null:
		return false
	var top_cmd: BattleCommands.BaseCommand = _active_turn_stack[_active_turn_stack.size() - 1]
	return top_cmd.can_undo(ctx)


func undo_last_command(ctx: BattleContext) -> bool:
	if not can_undo_last(ctx):
		return false
	var top_cmd: BattleCommands.BaseCommand = _active_turn_stack[_active_turn_stack.size() - 1]
	if not top_cmd.undo(ctx):
		return false
	_active_turn_stack.pop_back()
	_replay_stream.append({
		"type": "UndoLastMarch",
		"target_command_id": top_cmd.command_id,
		"faction_id": top_cmd.faction_id,
	})
	return true


func clear_turn_undo_stack() -> void:
	_active_turn_stack.clear()


func get_replay_stream_size() -> int:
	return _replay_stream.size()


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"initial_seed": str(initial_seed),
		"stream": _replay_stream.duplicate(true),
	}


static func from_dict(data: Dictionary) -> CommandHistory:
	var s_val: int = int(str(data.get("initial_seed", "1")))
	var hist := CommandHistory.new(s_val)
	var raw_stream: Variant = data.get("stream", [])
	if raw_stream is Array:
		for entry: Variant in raw_stream:
			if entry is Dictionary:
				hist._replay_stream.append((entry as Dictionary).duplicate(true))
	return hist


func replay_into(ctx: BattleContext) -> bool:
	if ctx == null:
		return false
	ctx.rng = SeededRng.new(initial_seed)
	var live_stack: Array[BattleCommands.BaseCommand] = []

	for entry: Dictionary in _replay_stream:
		var entry_type: String = str(entry.get("type", ""))
		if entry_type == "UndoLastMarch":
			if live_stack.is_empty():
				return false
			var last_cmd: BattleCommands.BaseCommand = live_stack[live_stack.size() - 1]
			if not last_cmd.undo(ctx):
				return false
			live_stack.pop_back()
		else:
			var cmd: BattleCommands.BaseCommand = BattleCommands.command_from_dict(entry)
			if cmd == null or not cmd.execute(ctx):
				return false
			live_stack.append(cmd)
			if cmd is BattleCommands.EndTurnCommand:
				live_stack.clear()
	return true
