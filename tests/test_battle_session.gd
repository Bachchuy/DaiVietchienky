extends "res://tests/test_case.gd"

const BattleSessionScript = preload("res://game/battle/battle_session.gd")
const BattleCommandsScript = preload("res://sim/commands/battle_commands.gd")
const HexMathScript = preload("res://sim/rules/hex_math.gd")


func test_battle_session_start_stage_and_typed_signals() -> void:
	var session: BattleSession = BattleSessionScript.new()
	add_child_autofree(session)

	var started_stages: Array[int] = []
	var moved_events: Array[Dictionary] = []
	var undo_units: Array[int] = []
	var combat_events: Array[Dictionary] = []
	var skill_events: Array[Dictionary] = []
	var waited_units: Array[int] = []
	var ended_factions: Array[int] = []
	var started_turns: Array[Array] = []
	var refresh_count := [0]

	session.battle_started.connect(func(sid: int) -> void: started_stages.append(sid))
	session.unit_moved.connect(func(uid: int, from_h: Vector2i, to_h: Vector2i) -> void:
		moved_events.append({"uid": uid, "from": from_h, "to": to_h})
	)
	session.undo_executed.connect(func(uid: int) -> void: undo_units.append(uid))
	session.combat_resolved.connect(func(atk_id: int, def_id: int, rep: Dictionary) -> void:
		combat_events.append({"atk": atk_id, "def": def_id, "rep": rep})
	)
	session.skill_cast.connect(func(cid: int, sk_id: int, tgt: Vector2i) -> void:
		skill_events.append({"cid": cid, "skill_id": sk_id, "target": tgt})
	)
	session.unit_waited.connect(func(uid: int) -> void: waited_units.append(uid))
	session.faction_turn_ended.connect(func(fid: int) -> void: ended_factions.append(fid))
	session.faction_turn_started.connect(func(fid: int, rnd: int) -> void: started_turns.append([fid, rnd]))
	session.state_refreshed.connect(func() -> void: refresh_count[0] = int(refresh_count[0]) + 1)

	assert_true(session.start_stage(10101, 12880409), "start_stage(10101) succeeds")
	assert_has(started_stages, 10101)
	assert_true(session.is_ongoing(), "Session is ongoing")
	assert_true(session.is_player_turn(), "Player turn active")
	assert_eq(session.get_current_round(), 1)
	assert_eq(session.get_max_rounds(), 10)
	assert_false(session.is_economy_enabled(), "Stage 10101 keeps economy disabled")
	assert_gt(float(session.get_stage_dialogues().size()), 0.0, "Stage dialogues loaded")

	var u101: BattleUnit = session.get_unit(101)
	assert_not_null(u101)
	var from_hex: Vector2i = u101.hex_position
	var step_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 8))
	assert_true(session.submit(BattleCommandsScript.MarchCommand.new(1, 101, from_hex, step_hex)), "March via session.submit")
	assert_eq(moved_events.size(), 1)
	assert_eq(int(moved_events[0]["uid"]), 101)
	assert_eq(moved_events[0]["from"], from_hex)
	assert_eq(moved_events[0]["to"], step_hex)

	assert_true(session.can_undo(), "Session allows undo after safe march")
	assert_true(session.undo_last_action(), "undo_last_action succeeds")
	assert_has(undo_units, 101)
	assert_eq(u101.hex_position, from_hex, "Undo restored u101 hex_position")

	assert_true(session.submit(BattleCommandsScript.CastSkillCommand.new(1, 101, 10001, from_hex)), "CastSkill via session.submit")
	assert_eq(skill_events.size(), 1)
	assert_eq(int(skill_events[0]["skill_id"]), 10001)

	assert_true(session.submit(BattleCommandsScript.WaitCommand.new(1, 103)), "Wait via session.submit")
	assert_has(waited_units, 103)

	var ms: BattleMapState = session.get_map_state()
	var u102: BattleUnit = session.get_unit(102)
	var e201: BattleUnit = session.get_unit(201)
	ms.move_unit(e201, HexMathScript.odd_r_to_axial(Vector2i(5, 5)))
	assert_true(session.submit(BattleCommandsScript.AttackCommand.new(1, u102.unit_id, e201.unit_id)), "Attack via session.submit")
	assert_eq(combat_events.size(), 1)
	assert_eq(int(combat_events[0]["atk"]), 102)
	assert_eq(int(combat_events[0]["def"]), 201)
	assert_true(bool((combat_events[0]["rep"] as Dictionary).get("ok", false)))

	assert_true(session.end_player_turn(), "end_player_turn succeeds")
	assert_has(ended_factions, 1)
	assert_has(started_turns, [2, 1])
	assert_gt(float(refresh_count[0]), 4.0)


func test_battle_economy_command_aliases_backward_compatible() -> void:
	var eco_scr: GDScript = load("res://sim/rules/battle_economy.gd") as GDScript
	assert_not_null(eco_scr, "BattleEconomy script loads cleanly")
	var direct_trade := BattleEconomy.TradeCommand.new(1, "coin_to_food", 100)
	assert_true(direct_trade is BattleCommandsScript.BaseCommand, "BattleEconomy.TradeCommand direct access works")
	var cmd_names: Array[String] = [
		"RobAreaIncomeCommand",
		"TradeCommand",
		"UpgradeFacilityCommand",
		"FortifyHexCommand",
		"UnlockBattleTechCommand",
		"RecruitCommand",
		"ApplyTacticCommand",
	]
	for cname: String in cmd_names:
		var cls_var: Variant = eco_scr.get(cname)
		assert_not_null(cls_var, "BattleEconomy script exposes constant alias '%s'" % cname)
		if cls_var != null:
			var inst: Variant = cls_var.new()
			assert_true(inst is BattleCommandsScript.BaseCommand, "%s instantiates as BaseCommand" % cname)


func test_sim_and_game_battle_scripts_strictly_under_400_lines_and_isolated() -> void:
	var sim_files: Array[String] = _collect_gd("res://sim")
	var game_battle_files: Array[String] = _collect_gd("res://game/battle")
	assert_gte(float(sim_files.size()), 24.0, "At least 24 scripts in res://sim/")
	assert_gte(float(game_battle_files.size()), 2.0, "At least 2 scripts in res://game/battle/")

	for path: String in sim_files:
		var src: String = FileAccess.get_file_as_string(path)
		var lines: int = src.split("\n").size()
		assert_lte(lines, 400, "%s must be <= 400 lines (got %d)" % [path, lines])
		for tok: String in ["extends Node", "SceneTree", "RenderingServer", "CanvasItem", "AudioStreamPlayer", "get_tree()"]:
			assert_false(src.contains(tok), "Sim isolation: '%s' forbidden in %s" % [tok, path])

	for g_path: String in game_battle_files:
		var g_src: String = FileAccess.get_file_as_string(g_path)
		var g_lines: int = g_src.split("\n").size()
		assert_lte(g_lines, 400, "%s must be <= 400 lines (got %d)" % [g_path, g_lines])


func _collect_gd(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry: String = d.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full: String = dir_path.path_join(entry)
			if d.current_is_dir():
				out.append_array(_collect_gd(full))
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out
