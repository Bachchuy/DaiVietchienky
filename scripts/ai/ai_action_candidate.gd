class_name AIActionCandidate
extends RefCounted

enum ActionKind {
	WAIT = 0,
	ATTACK = 1,
	CAST_SKILL = 2,
}

var action_kind: ActionKind = ActionKind.WAIT
var dest_hex: Vector2i = Vector2i.ZERO
var target_unit_id: int = 0
var target_hex: Vector2i = Vector2i.ZERO
var skill_id: int = 0
var mana_cost: int = 0


func to_commands(unit: BattleUnit) -> Array[BattleCommands.BaseCommand]:
	var cmds: Array[BattleCommands.BaseCommand] = []
	if unit == null:
		return cmds

	if dest_hex != unit.hex_position:
		cmds.append(
			BattleCommands.MarchCommand.new(
				unit.faction_id,
				unit.unit_id,
				unit.hex_position,
				dest_hex
			)
		)

	match action_kind:
		ActionKind.ATTACK:
			cmds.append(
				BattleCommands.AttackCommand.new(
					unit.faction_id,
					unit.unit_id,
					target_unit_id
				)
			)
		ActionKind.CAST_SKILL:
			cmds.append(
				BattleCommands.CastSkillCommand.new(
					unit.faction_id,
					unit.unit_id,
					skill_id,
					target_hex
				)
			)
		_:
			cmds.append(
				BattleCommands.WaitCommand.new(
					unit.faction_id,
					unit.unit_id
				)
			)
	return cmds
