extends "res://tests/test_case.gd"

const CTX_PATH: String = "res://scripts/core/battle_context.gd"
const CMDS_PATH: String = "res://scripts/core/battle_commands.gd"
const HIST_PATH: String = "res://scripts/core/command_history.gd"
const HexMathScript = preload("res://scripts/core/hex_math.gd")
const MapStateScript = preload("res://scripts/core/battle_map_state.gd")
const UnitScript = preload("res://scripts/core/battle_unit.gd")
const UnitStateScript = preload("res://scripts/core/unit_combat_state.gd")


func _load_cmd_scripts() -> Dictionary:
	var ctx_s: GDScript = load(CTX_PATH) as GDScript
	var cmds_s: GDScript = load(CMDS_PATH) as GDScript
	var hist_s: GDScript = load(HIST_PATH) as GDScript
	assert_not_null(ctx_s, "BattleContext script must exist at " + CTX_PATH)
	assert_not_null(cmds_s, "BattleCommands script must exist at " + CMDS_PATH)
	assert_not_null(hist_s, "CommandHistory script must exist at " + HIST_PATH)
	return {"ctx": ctx_s, "cmds": cmds_s, "hist": hist_s}


func _make_unit(uid: int, faction: int, col: int, row: int) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(col, row))
	u.max_mp = 8
	u.state.current_mp = 8
	u.state.max_hp = 200
	u.state.current_hp = 200
	return u


func test_march_undo_five_conditions_and_one_undo_per_turn_limit() -> void:
	var s: Dictionary = _load_cmd_scripts()
	if s["ctx"] == null or s["cmds"] == null or s["hist"] == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var ctx: RefCounted = s["ctx"].new(map_state, 1288)
	var hist: RefCounted = s["hist"].new(1288)
	var cmds: GDScript = s["cmds"]

	var u: BattleUnit = _make_unit(1, 1, 2, 5)
	map_state.place_unit(u)

	var start_hex: Vector2i = u.hex_position
	var step1_hex: Vector2i = start_hex + Vector2i(1, 0) # Safe plains (2 MP)

	# 1. Safe march -> can_undo == true -> undo restores position & MP and locks 2nd undo
	var m1: RefCounted = cmds.MarchCommand.new(1, u.unit_id, start_hex, step1_hex)
	assert_true(bool(hist.call("execute_command", m1, ctx)))
	assert_eq(u.hex_position, step1_hex)
	assert_eq(u.state.current_mp, 6)
	assert_true(bool(hist.call("can_undo_last", ctx)), "Safe march must be undoable")
	assert_true(bool(hist.call("undo_last_command", ctx)))
	assert_eq(u.hex_position, start_hex)
	assert_eq(u.state.current_mp, 8)
	assert_true(u.state.has_used_undo_this_turn)

	# Condition 5: 2nd march in same turn CANNOT be undone (1x Undo limit!)
	var m2: RefCounted = cmds.MarchCommand.new(1, u.unit_id, start_hex, step1_hex)
	assert_true(bool(hist.call("execute_command", m2, ctx)))
	assert_false(bool(hist.call("can_undo_last", ctx)), "Condition 5: Cannot undo twice in one turn")

	# Reset turn flags; test Condition 1: Acting (WaitCommand) blocks Undo
	u.state.on_faction_turn_start(u.max_mp)
	var step2_hex: Vector2i = step1_hex + Vector2i(1, 0)
	var m3: RefCounted = cmds.MarchCommand.new(1, u.unit_id, step1_hex, step2_hex)
	assert_true(bool(hist.call("execute_command", m3, ctx)))
	assert_true(bool(hist.call("can_undo_last", ctx)))
	var wait_cmd: RefCounted = cmds.WaitCommand.new(1, u.unit_id)
	assert_true(bool(hist.call("execute_command", wait_cmd, ctx)))
	assert_false(bool(hist.call("can_undo_last", ctx)), "Condition 1: WaitCommand locks undo")

	# Condition 3: Entering enemy ZoC blocks Undo
	u.state.on_faction_turn_start(u.max_mp)
	var enemy: BattleUnit = _make_unit(99, 3, 6, 5)
	map_state.place_unit(enemy)
	var zoc_hex: Vector2i = enemy.hex_position + Vector2i(-1, 0)
	map_state.move_unit(u, zoc_hex + Vector2i(-1, 0))
	var m_zoc: RefCounted = cmds.MarchCommand.new(1, u.unit_id, u.hex_position, zoc_hex)
	assert_true(bool(hist.call("execute_command", m_zoc, ctx)))
	assert_false(bool(hist.call("can_undo_last", ctx)), "Condition 3: Entering enemy ZoC forbids Undo")

	# Condition 2: Revealing Fog of War blocks Undo
	var fow_map := MapStateScript.new(12, 10)
	var fow_ctx: RefCounted = s["ctx"].new(fow_map, 1288)
	fow_ctx.set("enable_fog_of_war", true)
	var fow_hist: RefCounted = s["hist"].new(1288)
	var scout: BattleUnit = _make_unit(5, 1, 2, 2)
	scout.vision_range = 2
	fow_map.place_unit(scout)
	fow_ctx.call("refresh_faction_vision", 1) # Explore initial radius 2 around (2,2)
	var march_reveal: RefCounted = cmds.MarchCommand.new(1, scout.unit_id, scout.hex_position, scout.hex_position + Vector2i(1, 0))
	assert_true(bool(fow_hist.call("execute_command", march_reveal, fow_ctx)))
	assert_false(bool(fow_hist.call("can_undo_last", fow_ctx)), "Condition 2: Revealing new FoW cells forbids Undo")

	# Condition 4: Stepping onto trap / StakedWater blocks Undo
	var naval_map := MapStateScript.new(12, 10, MapStateScript.TerrainType.DEEP_WATER)
	naval_map.staked_water_owner_faction = 1
	var naval_ctx: RefCounted = s["ctx"].new(naval_map, 1288)
	var naval_hist: RefCounted = s["hist"].new(1288)
	var yuan_ship: BattleUnit = _make_unit(50, 3, 4, 4)
	yuan_ship.domain = UnitScript.Domain.NAVAL
	yuan_ship.command_branch = UnitScript.CommandBranch.NAVAL_HEAVY
	naval_map.place_unit(yuan_ship)
	var stake_hex: Vector2i = yuan_ship.hex_position + Vector2i(1, 0)
	naval_map.set_terrain(stake_hex, MapStateScript.TerrainType.STAKED_WATER)
	var march_stake: RefCounted = cmds.MarchCommand.new(3, yuan_ship.unit_id, yuan_ship.hex_position, stake_hex)
	assert_true(bool(naval_hist.call("execute_command", march_stake, naval_ctx)))
	assert_false(bool(naval_hist.call("can_undo_last", naval_ctx)), "Condition 4: Triggering StakedWater trap forbids Undo")
	assert_lt(float(yuan_ship.state.current_hp), 200.0, "StakedWater inflicts 35% MaxHP piercing damage")
	assert_eq(yuan_ship.state.march_disabled_turns, 2)


func test_non_march_commands_never_allow_undo() -> void:
	var s: Dictionary = _load_cmd_scripts()
	if s["ctx"] == null or s["cmds"] == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var ctx: RefCounted = s["ctx"].new(map_state, 777)
	var cmds: GDScript = s["cmds"]

	var atk_u: BattleUnit = _make_unit(1, 1, 4, 4)
	var def_u: BattleUnit = _make_unit(2, 3, 5, 4)
	map_state.place_unit(atk_u)
	map_state.place_unit(def_u)

	var atk_cmd: RefCounted = cmds.AttackCommand.new(1, atk_u.unit_id, def_u.unit_id)
	assert_true(bool(atk_cmd.call("execute", ctx)))
	assert_false(bool(atk_cmd.call("can_undo", ctx)), "AttackCommand must never undo")
	assert_false(bool(atk_cmd.call("undo", ctx)))

	var end_cmd: RefCounted = cmds.EndTurnCommand.new(1)
	assert_false(bool(end_cmd.call("can_undo", ctx)), "EndTurnCommand must never undo")


func test_json_serialized_replay_reproduces_exact_state_and_rng() -> void:
	var s: Dictionary = _load_cmd_scripts()
	if s["ctx"] == null or s["cmds"] == null or s["hist"] == null:
		return

	var cmds: GDScript = s["cmds"]
	var seed_val: int = 12889999

	# Build Scenario Run A
	var map_a := MapStateScript.new(12, 10)
	var u1_a: BattleUnit = _make_unit(1, 1, 3, 5)
	var u2_a: BattleUnit = _make_unit(2, 1, 3, 6)
	u2_a.general_id = 1001
	var e1_a: BattleUnit = _make_unit(10, 3, 5, 5)
	map_a.place_unit(u1_a)
	map_a.place_unit(u2_a)
	map_a.place_unit(e1_a)

	var ctx_a: RefCounted = s["ctx"].new(map_a, seed_val)
	var hist_a: RefCounted = s["hist"].new(seed_val)

	# Execute March -> Undo -> March adjacent to enemy -> Attack -> CastSkill -> EndTurn
	var step_wrong: Vector2i = u1_a.hex_position + Vector2i(0, -1)
	var step_engage: Vector2i = e1_a.hex_position + Vector2i(-1, 0)
	assert_true(bool(hist_a.call("execute_command", cmds.MarchCommand.new(1, 1, u1_a.hex_position, step_wrong), ctx_a)))
	assert_true(bool(hist_a.call("undo_last_command", ctx_a)))
	assert_true(bool(hist_a.call("execute_command", cmds.MarchCommand.new(1, 1, u1_a.hex_position, step_engage), ctx_a)))
	assert_true(bool(hist_a.call("execute_command", cmds.AttackCommand.new(1, 1, 10), ctx_a)))
	assert_true(bool(hist_a.call("execute_command", cmds.CastSkillCommand.new(1, 2, 10001, u1_a.hex_position), ctx_a)))
	assert_true(bool(hist_a.call("execute_command", cmds.EndTurnCommand.new(1), ctx_a)))

	var json_str: String = JSON.stringify(hist_a.call("to_dict"))
	var parsed: Dictionary = JSON.parse_string(json_str) as Dictionary

	# Build Fresh Scenario Run B and replay from JSON!
	var map_b := MapStateScript.new(12, 10)
	var u1_b: BattleUnit = _make_unit(1, 1, 3, 5)
	var u2_b: BattleUnit = _make_unit(2, 1, 3, 6)
	u2_b.general_id = 1001
	var e1_b: BattleUnit = _make_unit(10, 3, 5, 5)
	map_b.place_unit(u1_b)
	map_b.place_unit(u2_b)
	map_b.place_unit(e1_b)

	var hist_b: RefCounted = s["hist"].from_dict(parsed)
	var ctx_b: RefCounted = s["ctx"].new(map_b, int(hist_b.get("initial_seed")))
	assert_true(bool(hist_b.call("replay_into", ctx_b)))

	assert_eq(u1_b.hex_position, u1_a.hex_position)
	assert_eq(u1_b.state.current_hp, u1_a.state.current_hp, "Attacker post-counter HP must match 100%")
	assert_eq(u1_b.state.morale, u1_a.state.morale, "Attacker morale must match 100%")
	assert_eq(u1_b.state.has_used_undo_this_turn, u1_a.state.has_used_undo_this_turn)
	assert_eq(e1_b.state.current_hp, e1_a.state.current_hp, "Defender HP must match 100%")
	assert_eq(e1_b.state.morale, e1_a.state.morale, "Defender morale must match 100%")
	assert_eq(ctx_b.get("rng").call("get_state"), ctx_a.get("rng").call("get_state"), "RNG state must match bit-for-bit")
