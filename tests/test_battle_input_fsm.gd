extends "res://tests/test_case.gd"

const FSM_PATH: String = "res://game/battle/battle_input_fsm.gd"
const VIEW_PATH: String = "res://game/battle/map/battle_map.tscn"
const CAM_PATH: String = "res://scripts/presentation/battle_camera_controller.gd"

const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")
const ControllerScript = preload("res://sim/state/battle_game_controller.gd")
const DirectorScript = preload("res://sim/state/scenario_director.gd")


func _make_unit(
	uid: int,
	faction: int,
	offset_cell: Vector2i,
	general_id: int = 0,
	hp: int = 120,
	mp: int = 6,
	min_r: int = 1,
	max_r: int = 1
) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.general_id = general_id
	u.display_name = "Đơn vị %d" % uid
	u.command_branch = UnitScript.CommandBranch.INFANTRY if max_r == 1 else UnitScript.CommandBranch.ARCHER
	u.domain = UnitScript.Domain.LAND
	u.hex_position = HexMathScript.odd_r_to_axial(offset_cell)
	u.max_mp = mp
	u.min_range = min_r
	u.max_range = max_r
	u.base_atk = 36
	u.base_def = 14
	u.max_stack = 3
	u.troop_stack = 3
	u.state.max_hp = hp
	u.state.current_hp = hp
	u.state.current_mp = mp
	return u


func _create_rig(
	width: int = 10,
	height: int = 10,
	fog_enabled: bool = false,
	seed_val: int = 128801
) -> Dictionary:
	var fsm_s: GDScript = load(FSM_PATH) as GDScript
	var view_scene: PackedScene = load(VIEW_PATH) as PackedScene
	var cam_s: GDScript = load(CAM_PATH) as GDScript
	assert_not_null(fsm_s, "BattleInputFSM script must exist at " + FSM_PATH)
	assert_not_null(view_scene, "BattleMap scene must exist at " + VIEW_PATH)
	assert_not_null(cam_s, "BattleCameraController script must exist at " + CAM_PATH)
	if fsm_s == null or view_scene == null or cam_s == null:
		return {}

	var map_state := MapStateScript.new(width, height, BattleMapState.TerrainType.PLAINS)
	var ctrl := ControllerScript.new(map_state, seed_val, [1, 3], 10)
	ctrl.context.enable_fog_of_war = fog_enabled
	ctrl.player_faction_id = 1

	var view: Node2D = view_scene.instantiate() as Node2D
	add_child_autofree(view)
	view.call("reset_for_procedural_map")
	view.call("bind_battle_state", map_state, ctrl.context.navigator)

	var cam: Camera2D = cam_s.new() as Camera2D
	add_child_autofree(cam)
	cam.set("map_world_bounds", Rect2(0.0, 0.0, 2400.0, 1800.0))
	cam.call("pan_to_world_pos", Vector2(1200.0, 900.0), true)

	var fsm: Node = fsm_s.new() as Node
	add_child_autofree(fsm)
	fsm.call("bind", ctrl, view, cam)

	return {
		"map_state": map_state,
		"controller": ctrl,
		"view": view,
		"camera": cam,
		"fsm": fsm,
		"fsm_script": fsm_s,
	}


func _start_rig(rig: Dictionary) -> void:
	var ctrl: BattleGameController = rig["controller"]
	var view: Node2D = rig["view"]
	ctrl.start_battle()
	view.call("refresh_all_layers")


func _bind_signal_recorders(fsm: Node) -> Dictionary:
	var rec := {
		"states": [],
		"focused": [],
		"inspected": [],
		"rejected": [],
	}
	fsm.connect("state_changed", func(old_s: int, new_s: int) -> void:
		(rec["states"] as Array).append([old_s, new_s])
	)
	fsm.connect("unit_focused", func(u: BattleUnit) -> void:
		(rec["focused"] as Array).append(u)
	)
	fsm.connect("hex_inspected", func(ax: Vector2i, u: BattleUnit) -> void:
		(rec["inspected"] as Array).append({"axial": ax, "unit": u})
	)
	fsm.connect("action_rejected", func(reason: String) -> void:
		(rec["rejected"] as Array).append(reason)
	)
	return rec


func test_initial_state_and_idle_selection_guards() -> void:
	var rig: Dictionary = _create_rig()
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var ctrl: BattleGameController = rig["controller"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var state_idle: int = int(fsm_s.get("State")["IDLE"])
	var state_selected: int = int(fsm_s.get("State")["UNIT_SELECTED"])

	assert_eq(int(fsm.call("get_state")), state_idle, "FSM must initialize in IDLE")

	var ready_unit: BattleUnit = _make_unit(101, 1, Vector2i(2, 2))
	var acted_unit: BattleUnit = _make_unit(102, 1, Vector2i(2, 4))
	acted_unit.state.has_acted = true
	var chaos_unit: BattleUnit = _make_unit(103, 1, Vector2i(2, 6))
	chaos_unit.state.morale = UnitStateScript.MoraleLevel.CHAOS
	chaos_unit.state.chaos_turns = 1
	var enemy_unit: BattleUnit = _make_unit(201, 3, Vector2i(7, 2))

	map_state.place_unit(ready_unit)
	map_state.place_unit(acted_unit)
	map_state.place_unit(chaos_unit)
	map_state.place_unit(enemy_unit)
	_start_rig(rig)
	acted_unit.state.has_acted = true
	chaos_unit.state.morale = UnitStateScript.MoraleLevel.CHAOS
	chaos_unit.state.chaos_turns = 1

	# Empty hex stays IDLE
	fsm.call("tap_hex", HexMathScript.odd_r_to_axial(Vector2i(5, 5)))
	assert_eq(int(fsm.call("get_state")), state_idle)

	# Enemy unit rejected in IDLE
	fsm.call("tap_hex", enemy_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_gt(float((rec["rejected"] as Array).size()), 0.0)

	# Acted friendly unit rejected in IDLE
	(rec["rejected"] as Array).clear()
	fsm.call("tap_hex", acted_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_gt(float((rec["rejected"] as Array).size()), 0.0)

	# CHAOS friendly unit rejected in IDLE
	(rec["rejected"] as Array).clear()
	fsm.call("tap_hex", chaos_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_gt(float((rec["rejected"] as Array).size()), 0.0)

	# Camera locked rejects input
	var cam: Camera2D = rig["camera"]
	cam.set("camera_locked", true)
	(rec["rejected"] as Array).clear()
	fsm.call("tap_hex", ready_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_has(rec["rejected"], "input_locked")
	cam.set("camera_locked", false)

	# Valid friendly !has_acted transitions IDLE -> UNIT_SELECTED
	fsm.call("tap_hex", ready_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)
	assert_eq(fsm.call("get_active_unit"), ready_unit)
	assert_has(rec["states"], [state_idle, state_selected])
	assert_eq((rec["focused"] as Array).back(), ready_unit)

	# Non-player faction turn rejects input
	fsm.call("cancel_or_deselect")
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(1))
	assert_eq(ctrl.current_faction_id, 3)
	(rec["rejected"] as Array).clear()
	fsm.call("tap_hex", ready_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_has(rec["rejected"], "not_player_turn")

	# Battle ended rejects input
	ctrl.submit_command(BattleCommands.EndTurnCommand.new(3))
	ctrl.outcome = BattleGameController.BattleOutcome.VICTORY
	(rec["rejected"] as Array).clear()
	fsm.call("tap_hex", ready_unit.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_has(rec["rejected"], "battle_ended")


func test_unit_selected_deselect_switch_and_wait_in_place() -> void:
	var rig: Dictionary = _create_rig()
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var view: Node2D = rig["view"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var state_idle: int = int(fsm_s.get("State")["IDLE"])
	var state_selected: int = int(fsm_s.get("State")["UNIT_SELECTED"])

	var u1: BattleUnit = _make_unit(101, 1, Vector2i(1, 2), 0, 120, 4)
	var u2: BattleUnit = _make_unit(102, 1, Vector2i(1, 5), 0, 120, 4)
	var dummy_enemy: BattleUnit = _make_unit(299, 3, Vector2i(9, 9))
	map_state.place_unit(u1)
	map_state.place_unit(u2)
	map_state.place_unit(dummy_enemy)
	_start_rig(rig)

	# Select u1
	fsm.call("tap_hex", u1.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)

	# Tap empty non-reachable hex -> IDLE
	fsm.call("tap_hex", HexMathScript.odd_r_to_axial(Vector2i(8, 8)))
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_null(view.call("get_selected_unit"))

	# Re-select u1 and tap self hex -> IDLE
	fsm.call("tap_hex", u1.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)
	fsm.call("tap_hex", u1.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)

	# Re-select u1 and cancel_or_deselect() -> IDLE
	fsm.call("tap_hex", u1.hex_position)
	assert_true(bool(fsm.call("cancel_or_deselect")))
	assert_eq(int(fsm.call("get_state")), state_idle)

	# Select u1, then switch to u2
	fsm.call("tap_hex", u1.hex_position)
	fsm.call("tap_hex", u2.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)
	assert_eq(fsm.call("get_active_unit"), u2)
	assert_eq(view.call("get_selected_unit"), u2)

	# In-place WaitCommand sets has_acted = true -> IDLE
	(rec["states"] as Array).clear()
	assert_true(bool(fsm.call("request_wait")))
	assert_true(u2.state.has_acted)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_has(rec["states"], [state_selected, state_idle])


func test_march_to_post_move_action_and_closed_hub_guards() -> void:
	var rig: Dictionary = _create_rig()
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var view: Node2D = rig["view"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var state_selected: int = int(fsm_s.get("State")["UNIT_SELECTED"])
	var state_moving: int = int(fsm_s.get("State")["MOVING"])
	var state_post_move: int = int(fsm_s.get("State")["POST_MOVE_ACTION"])
	var state_idle: int = int(fsm_s.get("State")["IDLE"])

	var u1: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 0, 120, 6)
	var u2: BattleUnit = _make_unit(102, 1, Vector2i(2, 6), 0, 120, 6)
	var dummy_enemy: BattleUnit = _make_unit(299, 3, Vector2i(9, 9))
	map_state.place_unit(u1)
	map_state.place_unit(u2)
	map_state.place_unit(dummy_enemy)
	_start_rig(rig)

	fsm.call("tap_hex", u1.hex_position)
	var dest: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 2))
	fsm.call("tap_hex", dest)

	assert_eq(u1.hex_position, dest)
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_has(rec["states"], [state_selected, state_moving])
	assert_has(rec["states"], [state_moving, state_post_move])
	assert_eq((view.call("get_reachable_overlay_hexes") as Dictionary).size(), 0, "POST_MOVE_ACTION must clear blue move hexes")

	# Closed-hub guards: reject clicking another empty hex (no 2nd March) and reject clicking another friendly unit
	(rec["rejected"] as Array).clear()
	var second_empty: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(4, 2))
	fsm.call("tap_hex", second_empty)
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_eq(u1.hex_position, dest)
	assert_gt(float((rec["rejected"] as Array).size()), 0.0)

	(rec["rejected"] as Array).clear()
	fsm.call("tap_hex", u2.hex_position)
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_eq(fsm.call("get_active_unit"), u1)
	assert_gt(float((rec["rejected"] as Array).size()), 0.0)

	# Branch (d): tap self hex -> WaitCommand -> IDLE (has_acted = true)
	fsm.call("tap_hex", dest)
	assert_true(u1.state.has_acted)
	assert_eq(int(fsm.call("get_state")), state_idle)


func test_post_move_action_five_condition_undo_branch_c() -> void:
	# 1. Safe march -> Undo succeeds once -> UNIT_SELECTED, restores MP & from_hex, sets has_used_undo_this_turn
	var rig: Dictionary = _create_rig(10, 10, false)
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var ctrl: BattleGameController = rig["controller"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var state_selected: int = int(fsm_s.get("State")["UNIT_SELECTED"])
	var state_post_move: int = int(fsm_s.get("State")["POST_MOVE_ACTION"])

	var u1: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 0, 120, 6)
	var start_hex: Vector2i = u1.hex_position
	var step1: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 2))
	map_state.place_unit(u1)
	map_state.place_unit(_make_unit(299, 3, Vector2i(9, 9)))
	_start_rig(rig)

	fsm.call("tap_hex", start_hex)
	fsm.call("tap_hex", step1)
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_true(bool(fsm.call("can_undo_post_move")))
	assert_lt(float(u1.state.current_mp), 6.0)

	# Clean right-click (cancel_or_deselect) in POST_MOVE_ACTION triggers Undo when allowed
	assert_true(bool(fsm.call("cancel_or_deselect")))
	assert_eq(int(fsm.call("get_state")), state_selected)
	assert_eq(u1.hex_position, start_hex)
	assert_eq(u1.state.current_mp, 6)
	assert_true(u1.state.has_used_undo_this_turn)

	# Condition 5: 2nd march in same turn cannot Undo
	fsm.call("tap_hex", step1)
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_false(bool(fsm.call("can_undo_post_move")))
	(rec["rejected"] as Array).clear()
	assert_false(bool(fsm.call("request_undo")))
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_has(rec["rejected"], "undo_unavailable")
	# Right-click cancel when Undo unavailable stays in POST_MOVE_ACTION
	assert_false(bool(fsm.call("cancel_or_deselect")))
	assert_eq(int(fsm.call("get_state")), state_post_move)

	# 2. Condition 3: entering enemy ZoC rejects Undo
	var rig_zoc: Dictionary = _create_rig(10, 10, false)
	var ms_zoc: BattleMapState = rig_zoc["map_state"]
	var fsm_zoc: Node = rig_zoc["fsm"]
	var uz: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 0, 120, 6)
	var ez: BattleUnit = _make_unit(201, 3, Vector2i(4, 2), 0, 120, 6)
	ms_zoc.place_unit(uz)
	ms_zoc.place_unit(ez)
	_start_rig(rig_zoc)
	fsm_zoc.call("tap_hex", uz.hex_position)
	fsm_zoc.call("tap_hex", HexMathScript.odd_r_to_axial(Vector2i(3, 2)))
	assert_eq(int(fsm_zoc.call("get_state")), state_post_move)
	assert_false(bool(fsm_zoc.call("request_undo")), "Entering enemy ZoC must block Undo")
	assert_eq(int(fsm_zoc.call("get_state")), state_post_move)

	# 3. Condition 2: revealing FoW cell rejects Undo
	var rig_fow: Dictionary = _create_rig(10, 10, true)
	var ms_fow: BattleMapState = rig_fow["map_state"]
	var fsm_fow: Node = rig_fow["fsm"]
	var uf: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 0, 120, 6)
	uf.vision_range = 2
	ms_fow.place_unit(uf)
	ms_fow.place_unit(_make_unit(299, 3, Vector2i(9, 9)))
	_start_rig(rig_fow)
	fsm_fow.call("tap_hex", uf.hex_position)
	fsm_fow.call("tap_hex", HexMathScript.odd_r_to_axial(Vector2i(4, 2)))
	assert_eq(int(fsm_fow.call("get_state")), state_post_move)
	assert_false(bool(fsm_fow.call("request_undo")), "Revealing new FoW cells must block Undo")
	assert_eq(int(fsm_fow.call("get_state")), state_post_move)

	# 4. Condition 4: triggering cell/stake event rejects Undo
	var rig_trap: Dictionary = _create_rig(10, 10, false)
	var ms_trap: BattleMapState = rig_trap["map_state"]
	var ctrl_trap: BattleGameController = rig_trap["controller"]
	var fsm_trap: Node = rig_trap["fsm"]
	var ut: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 0, 120, 6)
	var trap_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 2))
	ms_trap.place_unit(ut)
	ms_trap.place_unit(_make_unit(299, 3, Vector2i(9, 9)))
	ctrl_trap.context.set_trap_cell(trap_hex)
	_start_rig(rig_trap)
	fsm_trap.call("tap_hex", ut.hex_position)
	fsm_trap.call("tap_hex", trap_hex)
	assert_eq(int(fsm_trap.call("get_state")), state_post_move)
	assert_false(bool(fsm_trap.call("request_undo")), "Triggering trap/cell event must block Undo")

	# 5. Condition 1: once has_acted == true (WaitCommand), Undo is unavailable
	assert_true(bool(fsm_trap.call("request_wait")))
	assert_false(ctrl_trap.can_undo())
	assert_false(bool(fsm_trap.call("request_undo")))


func test_one_tap_direct_attack_in_place_and_post_move() -> void:
	# Part A: 7-state contract + In-place 1-tap attack (UNIT_SELECTED -> ATTACKING -> IDLE), out-of-range focus
	var rig: Dictionary = _create_rig(10, 10, false)
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var states_dict: Dictionary = fsm_s.get("State") as Dictionary
	assert_eq(states_dict.size(), 7, "FSM must have exactly 7 states (DEC-026)")
	assert_false(states_dict.has("AIMING_TARGET"), "AIMING_TARGET must be removed")

	var state_selected: int = int(states_dict["UNIT_SELECTED"])
	var state_post_move: int = int(states_dict["POST_MOVE_ACTION"])
	var state_attacking: int = int(states_dict["ATTACKING"])
	var state_idle: int = int(states_dict["IDLE"])

	var archer: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 0, 120, 6, 1, 2)
	var foe_a: BattleUnit = _make_unit(201, 3, Vector2i(3, 2), 0, 120, 6)
	var foe_far: BattleUnit = _make_unit(203, 3, Vector2i(7, 7), 0, 120, 6)
	map_state.place_unit(archer)
	map_state.place_unit(foe_a)
	map_state.place_unit(foe_far)
	_start_rig(rig)

	fsm.call("tap_hex", archer.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)

	# Out-of-range hostile focuses UnitInspector, stays UNIT_SELECTED, deals 0 damage
	(rec["rejected"] as Array).clear()
	(rec["focused"] as Array).clear()
	fsm.call("tap_hex", foe_far.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)
	assert_eq((rec["focused"] as Array).back(), foe_far, "Out-of-range enemy emits unit_focused for UnitInspector")
	assert_has(rec["rejected"], "target_out_of_range")
	assert_eq(foe_far.state.current_hp, 120)
	assert_false(archer.state.has_acted)

	# 1st tap on foe_a in range -> immediately ATTACKING -> IDLE
	(rec["states"] as Array).clear()
	fsm.call("tap_hex", foe_a.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_true(archer.state.has_acted)
	assert_lt(float(foe_a.state.current_hp), 120.0)
	assert_has(rec["states"], [state_selected, state_attacking])
	assert_has(rec["states"], [state_attacking, state_idle])

	# Part B: PostMoveAction 1-tap immediate attack (POST_MOVE_ACTION -> ATTACKING -> IDLE)
	var rig_pm: Dictionary = _create_rig(10, 10, false)
	var ms_pm: BattleMapState = rig_pm["map_state"]
	var fsm_pm: Node = rig_pm["fsm"]
	var rec_pm: Dictionary = _bind_signal_recorders(fsm_pm)

	var mover: BattleUnit = _make_unit(110, 1, Vector2i(1, 3), 0, 120, 6)
	var target_pm: BattleUnit = _make_unit(210, 3, Vector2i(3, 3), 0, 120, 6)
	ms_pm.place_unit(mover)
	ms_pm.place_unit(target_pm)
	_start_rig(rig_pm)

	fsm_pm.call("tap_hex", mover.hex_position)
	fsm_pm.call("tap_hex", HexMathScript.odd_r_to_axial(Vector2i(2, 3)))
	assert_eq(int(fsm_pm.call("get_state")), state_post_move)

	(rec_pm["states"] as Array).clear()
	fsm_pm.call("tap_hex", target_pm.hex_position)
	assert_eq(int(fsm_pm.call("get_state")), state_idle)
	assert_true(mover.state.has_acted)
	assert_lt(float(target_pm.state.current_hp), 120.0)
	assert_has(rec_pm["states"], [state_post_move, state_attacking])
	assert_has(rec_pm["states"], [state_attacking, state_idle])


func test_skill_targeting_skill_area_layer_and_execute_skill() -> void:
	var rig: Dictionary = _create_rig(10, 10, false)
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var view: Node2D = rig["view"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var state_selected: int = int(fsm_s.get("State")["UNIT_SELECTED"])
	var state_post_move: int = int(fsm_s.get("State")["POST_MOVE_ACTION"])
	var state_skill_target: int = int(fsm_s.get("State")["SKILL_TARGETING"])
	var state_exec_skill: int = int(fsm_s.get("State")["EXECUTE_SKILL"])
	var state_idle: int = int(fsm_s.get("State")["IDLE"])

	var regular: BattleUnit = _make_unit(102, 1, Vector2i(1, 2), 0, 120, 6)
	var commander: BattleUnit = _make_unit(101, 1, Vector2i(2, 4), 1001, 150, 6)
	var ally_chaos: BattleUnit = _make_unit(103, 1, Vector2i(4, 4), 0, 120, 6)
	map_state.place_unit(regular)
	map_state.place_unit(commander)
	map_state.place_unit(ally_chaos)
	map_state.place_unit(_make_unit(299, 3, Vector2i(9, 9)))
	_start_rig(rig)
	ally_chaos.state.morale = UnitStateScript.MoraleLevel.CHAOS
	ally_chaos.state.chaos_turns = 2

	# Non-commander rejects skill targeting
	fsm.call("tap_hex", regular.hex_position)
	assert_false(bool(fsm.call("enter_skill_targeting")))
	assert_eq(int(fsm.call("get_state")), state_selected)
	assert_has(rec["rejected"], "skill_unavailable")

	# Commander on cooldown or skill_disabled rejects
	commander.state.skill_cooldown = 2
	fsm.call("tap_hex", commander.hex_position)
	assert_false(bool(fsm.call("enter_skill_targeting")))
	commander.state.skill_cooldown = 0
	commander.state.skill_disabled_turns = 1
	assert_false(bool(fsm.call("enter_skill_targeting")))
	commander.state.skill_disabled_turns = 0

	# From UNIT_SELECTED: enter_skill_targeting -> highlights SkillAreaLayer -> cancel returns to UNIT_SELECTED
	assert_true(bool(fsm.call("enter_skill_targeting")))
	assert_eq(int(fsm.call("get_state")), state_skill_target)
	var skill_hexes: Array[Vector2i] = view.call("get_skill_range_hexes")
	assert_gt(float(skill_hexes.size()), 0.0, "SkillAreaLayer must be populated for range 2")
	assert_true(bool(fsm.call("cancel_or_deselect")))
	assert_eq(int(fsm.call("get_state")), state_selected)
	assert_eq((view.call("get_skill_range_hexes") as Array).size(), 0, "SkillAreaLayer must clear on cancel")

	# Move commander -> POST_MOVE_ACTION -> Branch (b) enter_skill_targeting -> cancel returns to POST_MOVE_ACTION
	var moved_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 4))
	fsm.call("tap_hex", moved_hex)
	assert_eq(int(fsm.call("get_state")), state_post_move)
	assert_true(bool(fsm.call("enter_skill_targeting")))
	assert_eq(int(fsm.call("get_state")), state_skill_target)
	assert_true(bool(fsm.call("cancel_or_deselect")))
	assert_eq(int(fsm.call("get_state")), state_post_move)

	# Re-enter skill targeting, hover valid target hex, tap valid target hex -> EXECUTE_SKILL -> IDLE
	assert_true(bool(fsm.call("enter_skill_targeting")))
	var cast_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(4, 4))
	fsm.call("hover_hex", cast_hex)
	assert_gt(float((view.call("get_skill_aoe_hexes") as Array).size()), 0.0)
	(rec["states"] as Array).clear()
	fsm.call("tap_hex", cast_hex)

	assert_eq(int(fsm.call("get_state")), state_idle)
	assert_has(rec["states"], [state_skill_target, state_exec_skill])
	assert_has(rec["states"], [state_exec_skill, state_idle])
	assert_true(commander.state.has_acted)
	assert_eq(commander.state.skill_cooldown, 3)
	assert_eq(ally_chaos.state.morale, UnitStateScript.MoraleLevel.NORMAL, "CastSkill 10001 must clear ally CHAOS within AoE 1")
	assert_eq((view.call("get_skill_range_hexes") as Array).size(), 0)


func test_march_into_staked_water_death_or_victory_exits_to_idle() -> void:
	# Case 1: Naval unit dies from StakedWater damage during MOVING -> exits to IDLE
	var rig_stake: Dictionary = _create_rig(10, 10, false)
	if rig_stake.is_empty():
		return
	var ms_s: BattleMapState = rig_stake["map_state"]
	var fsm_s_node: Node = rig_stake["fsm"]
	var fsm_script: GDScript = rig_stake["fsm_script"]

	var state_moving: int = int(fsm_script.get("State")["MOVING"])
	var state_idle: int = int(fsm_script.get("State")["IDLE"])

	var start_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(2, 2))
	var stake_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 2))
	ms_s.set_terrain(start_hex, BattleMapState.TerrainType.DEEP_WATER)
	ms_s.set_terrain(stake_hex, BattleMapState.TerrainType.STAKED_WATER)
	ms_s.staked_water_owner_faction = 3 # Hostile to player faction 1

	var boat: BattleUnit = _make_unit(105, 1, Vector2i(2, 2), 0, 100, 8, 1, 2)
	boat.domain = UnitScript.Domain.NAVAL
	boat.command_branch = UnitScript.CommandBranch.NAVAL_LIGHT
	boat.state.current_hp = 20 # 35% of 100 = 35 stake dmg -> lethal
	ms_s.place_unit(boat)
	ms_s.place_unit(_make_unit(199, 1, Vector2i(0, 9)))
	ms_s.place_unit(_make_unit(299, 3, Vector2i(9, 9)))
	_start_rig(rig_stake)

	var rec_s: Dictionary = _bind_signal_recorders(fsm_s_node)
	fsm_s_node.call("tap_hex", start_hex)
	fsm_s_node.call("tap_hex", stake_hex)

	assert_false(boat.state.is_alive())
	assert_eq(int(fsm_s_node.call("get_state")), state_idle, "Dead unit during MOVING must exit to IDLE, never POST_MOVE_ACTION")
	assert_has(rec_s["states"], [state_moving, state_idle])

	# Case 2: Marching onto primary objective triggers VICTORY -> exits to IDLE
	var rig_vic: Dictionary = _create_rig(10, 10, false)
	var ms_v: BattleMapState = rig_vic["map_state"]
	var ctrl_v: BattleGameController = rig_vic["controller"]
	var fsm_v: Node = rig_vic["fsm"]

	var goal_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(3, 2))
	var director := DirectorScript.new()
	director.register_area("area_goal", [goal_hex], 3, true)
	ctrl_v.director = director
	var eval := ScenarioVictoryEvaluator.new(
		[{"type": "DefeatGeneralWhileHoldingArea", "target_general_id": 9999, "required_area_id": "area_goal", "instant": true}],
		[],
		[],
		1,
		10
	)
	ctrl_v.victory_evaluator = eval

	var capturer: BattleUnit = _make_unit(106, 1, Vector2i(2, 2), 0, 120, 6)
	ms_v.place_unit(capturer)
	ms_v.place_unit(_make_unit(299, 3, Vector2i(9, 9)))
	eval.register_initial_units(ms_v)
	_start_rig(rig_vic)
	fsm_v.call("tap_hex", capturer.hex_position)
	fsm_v.call("tap_hex", goal_hex)

	assert_eq(ctrl_v.outcome, BattleGameController.BattleOutcome.VICTORY)
	assert_eq(int(fsm_v.call("get_state")), state_idle, "Battle ending during MOVING must exit to IDLE")


func test_right_click_vs_camera_drag_threshold_harmony() -> void:
	var rig: Dictionary = _create_rig(10, 10, false)
	if rig.is_empty():
		return
	var map_state: BattleMapState = rig["map_state"]
	var cam: Camera2D = rig["camera"]
	var fsm: Node = rig["fsm"]
	var fsm_s: GDScript = rig["fsm_script"]
	var rec: Dictionary = _bind_signal_recorders(fsm)

	var state_idle: int = int(fsm_s.get("State")["IDLE"])
	var state_selected: int = int(fsm_s.get("State")["UNIT_SELECTED"])
	var state_skill: int = int(fsm_s.get("State")["SKILL_TARGETING"])

	cam.connect("clean_right_clicked", func(_screen_pos: Vector2) -> void:
		fsm.call("cancel_or_deselect")
	)

	var u1: BattleUnit = _make_unit(101, 1, Vector2i(2, 2), 1001, 120, 6, 1, 2)
	var enemy: BattleUnit = _make_unit(201, 3, Vector2i(3, 2), 0, 120, 6)
	map_state.place_unit(u1)
	map_state.place_unit(enemy)
	_start_rig(rig)

	fsm.call("tap_hex", u1.hex_position)
	assert_eq(int(fsm.call("get_state")), state_selected)

	# 1. Right-drag 15px (> 6px threshold): pans camera and does NOT deselect UNIT_SELECTED
	var cam_pos_before: Vector2 = cam.global_position
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_RIGHT
	press_ev.pressed = true
	press_ev.position = Vector2(300.0, 300.0)
	cam.call("_unhandled_input", press_ev)

	var drag_ev := InputEventMouseMotion.new()
	drag_ev.position = Vector2(315.0, 300.0)
	drag_ev.relative = Vector2(15.0, 0.0)
	cam.call("_unhandled_input", drag_ev)

	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_RIGHT
	release_ev.pressed = false
	release_ev.position = Vector2(315.0, 300.0)
	cam.call("_unhandled_input", release_ev)

	for _i: int in range(90):
		cam.call("_process", 1.0 / 60.0)

	assert_gt(cam.global_position.distance_to(cam_pos_before), 5.0, "Right-drag > 6px must pan camera")
	assert_eq(int(fsm.call("get_state")), state_selected, "Right-drag > 6px must NOT deselect UNIT_SELECTED")

	# 2. Enter SKILL_TARGETING, then clean right-click (<= 6px, e.g. 2px): does NOT pan, cancels to UNIT_SELECTED
	assert_true(bool(fsm.call("enter_skill_targeting")))
	assert_eq(int(fsm.call("get_state")), state_skill)
	var cam_pos_mid: Vector2 = cam.global_position

	var p2 := InputEventMouseButton.new()
	p2.button_index = MOUSE_BUTTON_RIGHT
	p2.pressed = true
	p2.position = Vector2(400.0, 400.0)
	cam.call("_unhandled_input", p2)

	var m2 := InputEventMouseMotion.new()
	m2.position = Vector2(402.0, 400.0)
	m2.relative = Vector2(2.0, 0.0)
	cam.call("_unhandled_input", m2)

	var r2 := InputEventMouseButton.new()
	r2.button_index = MOUSE_BUTTON_RIGHT
	r2.pressed = false
	r2.position = Vector2(402.0, 400.0)
	cam.call("_unhandled_input", r2)

	for _j: int in range(10):
		cam.call("_process", 1.0 / 60.0)

	assert_almost_eq(cam.global_position.distance_to(cam_pos_mid), 0.0, 0.01, "Clean right-click <= 6px must NOT pan camera")
	assert_eq(int(fsm.call("get_state")), state_selected, "Clean right-click <= 6px must cancel SKILL_TARGETING -> UNIT_SELECTED")

	# 3. Clean right-click again in UNIT_SELECTED -> IDLE
	var p3 := InputEventMouseButton.new()
	p3.button_index = MOUSE_BUTTON_RIGHT
	p3.pressed = true
	p3.position = Vector2(400.0, 400.0)
	cam.call("_unhandled_input", p3)
	var r3 := InputEventMouseButton.new()
	r3.button_index = MOUSE_BUTTON_RIGHT
	r3.pressed = false
	r3.position = Vector2(400.0, 400.0)
	cam.call("_unhandled_input", r3)
	assert_eq(int(fsm.call("get_state")), state_idle, "Clean right-click in UNIT_SELECTED must deselect -> IDLE")

	# 4. Inspecting an enemy hex in IDLE focuses UnitInspector without leaving IDLE
	(rec["focused"] as Array).clear()
	fsm.call("inspect_hex", enemy.hex_position)
	assert_eq(int(fsm.call("get_state")), state_idle, "inspect_hex keeps FSM in IDLE")
	assert_eq((rec["focused"] as Array).back(), enemy, "inspect_hex focuses enemy unit")


func test_battle_sandbox_cp1_fsm_integration() -> void:
	var packed: PackedScene = load("res://game/battle/battle.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var sandbox: Node2D = packed.instantiate() as Node2D
	add_child_autofree(sandbox)

	var fsm: BattleInputFSM = sandbox.call("get_input_fsm") as BattleInputFSM
	var map_state: BattleMapState = sandbox.call("get_map_state") as BattleMapState
	var map_view: BattleMap = sandbox.call("get_map_view") as BattleMap
	assert_not_null(fsm)
	assert_eq(fsm.get_state(), BattleInputFSM.State.IDLE)

	# Select Tran Quoc Tuan (unit_id 101, general_id 1001) via click_world_position
	var tqt: BattleUnit = null
	for u: BattleUnit in map_state.get_all_units():
		if u.unit_id == 101:
			tqt = u
			break
	assert_not_null(tqt)
	sandbox.call("click_world_position", map_view.axial_to_world(tqt.hex_position))
	assert_eq(fsm.get_state(), BattleInputFSM.State.UNIT_SELECTED)
	assert_true(bool(sandbox.call("try_enter_skill_targeting")))
	assert_eq(fsm.get_state(), BattleInputFSM.State.SKILL_TARGETING)
	assert_gt(float(map_view.get_skill_range_hexes().size()), 0.0)
	assert_true(fsm.cancel_or_deselect())
	assert_eq(fsm.get_state(), BattleInputFSM.State.UNIT_SELECTED)
	assert_true(bool(sandbox.call("try_wait_selected")))
	assert_true(tqt.state.has_acted)
	assert_eq(fsm.get_state(), BattleInputFSM.State.IDLE)
