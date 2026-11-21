extends "res://tests/test_case.gd"

const MORALE_ENGINE_PATH: String = "res://sim/rules/morale_engine.gd"
const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const UnitStateScript = preload("res://sim/state/unit_combat_state.gd")


func _load_engine() -> Variant:
	var eng_s: GDScript = load(MORALE_ENGINE_PATH) as GDScript
	assert_not_null(eng_s, "MoraleEngine script must exist at " + MORALE_ENGINE_PATH)
	if eng_s == null:
		return null
	return eng_s.new()


func _spawn(map_state: BattleMapState, uid: int, faction: int, axial: Vector2i) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.hex_position = axial
	map_state.place_unit(u)
	return u


func test_trapped_levels_0_to_3_and_back_to_river_safety() -> void:
	var engine: Variant = _load_engine()
	if engine == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var center: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(5, 5))
	var victim: BattleUnit = _spawn(map_state, 1, 1, center)

	# Put impassable DEEP_WATER on 3 sides + only 1 enemy -> TrappedLevel MUST be 0 (safe!)
	map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[0], MapStateScript.TerrainType.DEEP_WATER)
	map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[1], MapStateScript.TerrainType.DEEP_WATER)
	map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[2], MapStateScript.TerrainType.DEEP_WATER)
	var e1: BattleUnit = _spawn(map_state, 101, 3, center + HexMathScript.AXIAL_DIRECTIONS[3])
	assert_eq(int(engine.call("evaluate_unit_trapped_level", map_state, victim)), 0, "1 enemy + water behind is still TrappedLevel 0")

	# Clear water, place 2 non-opposite enemies (dir 3 and dir 4 -> 2 blocked dirs, not 180 deg) -> TrappedLevel 1
	map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[0], MapStateScript.TerrainType.PLAINS)
	map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[1], MapStateScript.TerrainType.PLAINS)
	map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[2], MapStateScript.TerrainType.PLAINS)
	var e2: BattleUnit = _spawn(map_state, 102, 3, center + HexMathScript.AXIAL_DIRECTIONS[4])
	assert_eq(int(engine.call("evaluate_unit_trapped_level", map_state, victim)), 1, "2 adjacent non-pincer enemies = TrappedLevel 1")

	# Move e2 to dir 0 (180 deg opposite dir 3!) -> TrappedLevel 2 (Pincer!)
	map_state.move_unit(e2, center + HexMathScript.AXIAL_DIRECTIONS[0])
	assert_eq(int(engine.call("evaluate_unit_trapped_level", map_state, victim)), 2, "180-deg pincer = TrappedLevel 2")

	# If e1 is in CHAOS, e1 does not count as active surrounding enemy -> drops back to 0!
	e1.state.apply_chaos(1)
	assert_eq(int(engine.call("evaluate_unit_trapped_level", map_state, victim)), 0, "CHAOS enemy cannot pincer")
	e1.state.clear_chaos(UnitStateScript.MoraleLevel.NORMAL)

	# Block remaining 4 directions with impassable water while 2 enemies hold dir 0 & dir 3 -> 6/6 blocked -> TrappedLevel 3!
	for d: int in [1, 2, 4, 5]:
		map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[d], MapStateScript.TerrainType.DEEP_WATER)
	assert_eq(int(engine.call("evaluate_unit_trapped_level", map_state, victim)), 3, "6/6 blocked with >=2 enemies = TrappedLevel 3")


func test_chaos_duration_auto_recovery_to_low_and_trapped3_persistence() -> void:
	var engine: Variant = _load_engine()
	if engine == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var center: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(5, 5))
	var u: BattleUnit = _spawn(map_state, 1, 1, center)
	u.state.march_disabled_turns = 2
	u.state.apply_chaos(1)

	assert_eq(u.state.morale, UnitStateScript.MoraleLevel.CHAOS)
	assert_false(u.state.can_move())
	assert_false(u.state.can_attack())

	# End turn when TrappedLevel == 0 -> chaos_turns ticks 1 -> 0 and morale recovers CHAOS -> LOW!
	engine.call("process_faction_turn_end", map_state, 1)
	assert_eq(u.state.morale, UnitStateScript.MoraleLevel.LOW, "CHAOS must auto-recover to LOW at end of turn")
	assert_eq(u.state.march_disabled_turns, 1, "march_disabled_turns decrements by 1")

	# Now put unit in TrappedLevel 3 (2 enemies + 4 deep water = 6/6 blocked) -> CHAOS persists across turn end!
	_spawn(map_state, 101, 3, center + HexMathScript.AXIAL_DIRECTIONS[0])
	_spawn(map_state, 102, 3, center + HexMathScript.AXIAL_DIRECTIONS[3])
	for d: int in [1, 2, 4, 5]:
		map_state.set_terrain(center + HexMathScript.AXIAL_DIRECTIONS[d], MapStateScript.TerrainType.DEEP_WATER)

	engine.call("apply_immediate_trapped_effects", map_state)
	assert_eq(u.state.morale, UnitStateScript.MoraleLevel.CHAOS)
	engine.call("process_faction_turn_end", map_state, 1)
	assert_eq(u.state.morale, UnitStateScript.MoraleLevel.CHAOS, "TrappedLevel 3 keeps unit locked in CHAOS")


func test_neighboring_dead_mates_commander_immunity_and_decapitation_shock() -> void:
	var engine: Variant = _load_engine()
	if engine == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var center: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(5, 5))
	var killer: BattleUnit = _spawn(map_state, 1, 1, center + Vector2i(-1, 0))
	var dying_grunt: BattleUnit = _spawn(map_state, 10, 3, center)
	var adj_ally: BattleUnit = _spawn(map_state, 11, 3, center + Vector2i(1, 0))
	var immune_ally: BattleUnit = _spawn(map_state, 12, 3, center + Vector2i(0, 1))
	var orange_general: BattleUnit = _spawn(map_state, 13, 3, center + Vector2i(0, 2)) # 1 hex from immune_ally, 2 from center
	orange_general.general_id = 9001
	orange_general.grants_dead_mate_immunity = true

	map_state.remove_unit(dying_grunt.unit_id)
	dying_grunt.state.current_hp = 0
	engine.call("on_unit_defeated", map_state, killer, dying_grunt, center)

	assert_eq(killer.state.morale, UnitStateScript.MoraleLevel.HIGH, "Killer gains +1 morale (NORMAL -> HIGH)")
	assert_eq(adj_ally.state.morale, UnitStateScript.MoraleLevel.LOW, "Adjacent mate drops -1 morale (NORMAL -> LOW)")
	assert_eq(immune_ally.state.morale, UnitStateScript.MoraleLevel.NORMAL, "Mate adjacent to Orange/Red General is immune to NeighboringDeadMates")

	# Now test Commander-in-Chief decapitation shock (radius 3 hexes -1 morale, killer allies radius 2 +1 morale)
	orange_general.is_commander_in_chief = true
	var far_mate_3hex: BattleUnit = _spawn(map_state, 14, 3, orange_general.hex_position + Vector2i(3, 0))
	var killer_ally_2hex: BattleUnit = _spawn(map_state, 2, 1, orange_general.hex_position + Vector2i(-2, 0))

	map_state.remove_unit(orange_general.unit_id)
	orange_general.state.current_hp = 0
	engine.call("on_unit_defeated", map_state, killer, orange_general, orange_general.hex_position)

	assert_eq(far_mate_3hex.state.morale, UnitStateScript.MoraleLevel.LOW, "Commander-in-chief defeat shocks allies up to 3 hexes")
	assert_eq(killer_ally_2hex.state.morale, UnitStateScript.MoraleLevel.HIGH, "Allies within 2 hexes of slain enemy General gain +1 morale")


func test_starvation_never_drops_below_low() -> void:
	var engine: Variant = _load_engine()
	if engine == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var u: BattleUnit = _spawn(map_state, 1, 1, HexMathScript.odd_r_to_axial(Vector2i(2, 2)))
	u.state.morale = UnitStateScript.MoraleLevel.LOW
	engine.call("apply_faction_starvation", map_state, 1)
	assert_eq(u.state.morale, UnitStateScript.MoraleLevel.LOW, "Starvation floors at LOW and never causes CHAOS")
