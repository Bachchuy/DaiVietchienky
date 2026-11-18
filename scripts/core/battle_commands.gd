class_name BattleCommands
extends RefCounted


class BaseCommand extends RefCounted:
	var command_id: int = 0
	var faction_id: int = 0

	func get_command_type() -> String:
		return "Base"

	func execute(_ctx: BattleContext) -> bool:
		return false

	func can_undo(_ctx: BattleContext) -> bool:
		return false

	func undo(_ctx: BattleContext) -> bool:
		return false

	func to_dict() -> Dictionary:
		return {
			"type": get_command_type(),
			"command_id": command_id,
			"faction_id": faction_id,
		}


class MarchCommand extends BaseCommand:
	var unit_id: int = 0
	var from_hex: Vector2i = Vector2i.ZERO
	var to_hex: Vector2i = Vector2i.ZERO
	var mp_consumed: int = 0
	var prev_facing: int = 0
	var revealed_fog_cells: Array[Vector2i] = []
	var entered_enemy_zoc: bool = false
	var triggered_cell_event: bool = false

	func _init(p_faction: int = 0, p_unit_id: int = 0, p_from: Vector2i = Vector2i.ZERO, p_to: Vector2i = Vector2i.ZERO) -> void:
		faction_id = p_faction
		unit_id = p_unit_id
		from_hex = p_from
		to_hex = p_to

	func get_command_type() -> String:
		return "March"

	func execute(ctx: BattleContext) -> bool:
		var unit: BattleUnit = ctx.get_unit(unit_id)
		if unit == null or unit.faction_id != faction_id or unit.state.has_acted:
			return false
		prev_facing = unit.facing
		var report: Dictionary = ctx.move_unit_along_valid_path(unit, from_hex, to_hex)
		if not bool(report.get("ok", false)):
			return false
		mp_consumed = int(report.get("mp_cost", 0))
		revealed_fog_cells.assign(report.get("revealed_fog_cells", []))
		entered_enemy_zoc = bool(report.get("entered_enemy_zoc", false))
		triggered_cell_event = bool(report.get("triggered_cell_event", false))
		return true

	func can_undo(ctx: BattleContext) -> bool:
		var unit: BattleUnit = ctx.get_unit(unit_id)
		if unit == null or unit.hex_position != to_hex:
			return false
		if unit.state.has_acted:
			return false
		if unit.state.has_used_undo_this_turn:
			return false
		if not revealed_fog_cells.is_empty():
			return false
		if entered_enemy_zoc:
			return false
		if triggered_cell_event:
			return false
		var from_occ: BattleUnit = ctx.map_state.get_unit_at(from_hex)
		if from_occ != null and from_occ != unit:
			return false
		return true

	func undo(ctx: BattleContext) -> bool:
		if not can_undo(ctx):
			return false
		var unit: BattleUnit = ctx.get_unit(unit_id)
		if not ctx.teleport_unit_without_triggers(unit, from_hex):
			return false
		unit.state.current_mp = mini(unit.max_mp, unit.state.current_mp + mp_consumed)
		unit.facing = prev_facing
		unit.state.has_used_undo_this_turn = true
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["unit_id"] = unit_id
		d["from_hex"] = {"q": from_hex.x, "r": from_hex.y}
		d["to_hex"] = {"q": to_hex.x, "r": to_hex.y}
		return d


class AttackCommand extends BaseCommand:
	var attacker_id: int = 0
	var target_id: int = 0

	func _init(p_faction: int = 0, p_attacker_id: int = 0, p_target_id: int = 0) -> void:
		faction_id = p_faction
		attacker_id = p_attacker_id
		target_id = p_target_id

	func get_command_type() -> String:
		return "Attack"

	func execute(ctx: BattleContext) -> bool:
		var atk: BattleUnit = ctx.get_unit(attacker_id)
		if atk == null or atk.faction_id != faction_id:
			return false
		return ctx.execute_attack(attacker_id, target_id)

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["attacker_id"] = attacker_id
		d["target_id"] = target_id
		return d


class CastSkillCommand extends BaseCommand:
	var caster_id: int = 0
	var skill_id: int = 0
	var target_hex: Vector2i = Vector2i.ZERO

	func _init(p_faction: int = 0, p_caster_id: int = 0, p_skill_id: int = 0, p_target_hex: Vector2i = Vector2i.ZERO) -> void:
		faction_id = p_faction
		caster_id = p_caster_id
		skill_id = p_skill_id
		target_hex = p_target_hex

	func get_command_type() -> String:
		return "CastSkill"

	func execute(ctx: BattleContext) -> bool:
		var caster: BattleUnit = ctx.get_unit(caster_id)
		if caster == null or caster.faction_id != faction_id:
			return false
		return ctx.execute_skill_effect(caster, skill_id, target_hex)

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["caster_id"] = caster_id
		d["skill_id"] = skill_id
		d["target_hex"] = {"q": target_hex.x, "r": target_hex.y}
		return d


class WaitCommand extends BaseCommand:
	var unit_id: int = 0

	func _init(p_faction: int = 0, p_unit_id: int = 0) -> void:
		faction_id = p_faction
		unit_id = p_unit_id

	func get_command_type() -> String:
		return "Wait"

	func execute(ctx: BattleContext) -> bool:
		var unit: BattleUnit = ctx.get_unit(unit_id)
		if unit == null or unit.faction_id != faction_id or unit.state.has_acted:
			return false
		unit.state.has_acted = true
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["unit_id"] = unit_id
		return d


class EndTurnCommand extends BaseCommand:
	func _init(p_faction: int = 0) -> void:
		faction_id = p_faction

	func get_command_type() -> String:
		return "EndTurn"

	func execute(ctx: BattleContext) -> bool:
		ctx.morale_engine.process_faction_turn_end(ctx.map_state, faction_id)
		return true


static func _vec2i_from_dict(raw: Variant) -> Vector2i:
	if raw is Dictionary:
		var d: Dictionary = raw
		return Vector2i(int(d.get("q", 0)), int(d.get("r", 0)))
	return Vector2i.ZERO


static func command_from_dict(data: Dictionary) -> BaseCommand:
	var c_type: String = str(data.get("type", ""))
	var f_id: int = int(data.get("faction_id", 0))
	var cmd: BaseCommand = null

	match c_type:
		"March":
			cmd = MarchCommand.new(
				f_id,
				int(data.get("unit_id", 0)),
				_vec2i_from_dict(data.get("from_hex", {})),
				_vec2i_from_dict(data.get("to_hex", {}))
			)
		"Attack":
			cmd = AttackCommand.new(
				f_id,
				int(data.get("attacker_id", 0)),
				int(data.get("target_id", 0))
			)
		"CastSkill":
			cmd = CastSkillCommand.new(
				f_id,
				int(data.get("caster_id", 0)),
				int(data.get("skill_id", 0)),
				_vec2i_from_dict(data.get("target_hex", {}))
			)
		"Wait":
			cmd = WaitCommand.new(f_id, int(data.get("unit_id", 0)))
		"EndTurn":
			cmd = EndTurnCommand.new(f_id)
		_:
			return null

	cmd.command_id = int(data.get("command_id", 0))
	return cmd
