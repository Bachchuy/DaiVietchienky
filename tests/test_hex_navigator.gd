extends "res://tests/test_case.gd"

const NAV_PATH: String = "res://scripts/core/hex_grid_navigator.gd"
const HexMathScript = preload("res://scripts/core/hex_math.gd")
const MapStateScript = preload("res://scripts/core/battle_map_state.gd")
const UnitScript = preload("res://scripts/core/battle_unit.gd")
const UnitStateScript = preload("res://scripts/core/unit_combat_state.gd")


func _load_nav() -> Variant:
	var nav_s: GDScript = load(NAV_PATH) as GDScript
	assert_not_null(nav_s, "HexGridNavigator script must exist at " + NAV_PATH)
	if nav_s == null:
		return null
	return nav_s.new()


func _make_infantry(uid: int, faction: int, col: int, row: int, mp: int = 6) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(col, row))
	u.domain = UnitScript.Domain.LAND
	u.command_branch = UnitScript.CommandBranch.INFANTRY
	u.max_mp = mp
	u.state.current_mp = mp
	u.min_range = 1
	u.max_range = 1
	return u


func test_fond_terrain_and_coc_step_costs() -> void:
	var nav: Variant = _load_nav()
	if nav == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var u: BattleUnit = _make_infantry(1, 1, 2, 2, 8)
	u.fond_terrain = int(MapStateScript.TerrainType.FOREST)
	map_state.place_unit(u)

	var forest_hex: Vector2i = u.hex_position + HexMathScript.AXIAL_DIRECTIONS[0]
	map_state.set_terrain(forest_hex, MapStateScript.TerrainType.FOREST)
	# Forest base cost for infantry is 3 -> fond_terrain reduces by 1 -> 2 MP
	assert_eq(nav.get_hex_step_cost(map_state, u.hex_position, forest_hex, u, 8), 2)

	# Road/Port base cost is 1 -> fond_terrain floor keeps it >= 1 MP
	var road_hex: Vector2i = u.hex_position + HexMathScript.AXIAL_DIRECTIONS[1]
	map_state.set_terrain(road_hex, MapStateScript.TerrainType.ROAD_PORT)
	u.fond_terrain = int(MapStateScript.TerrainType.ROAD_PORT)
	assert_eq(nav.get_hex_step_cost(map_state, u.hex_position, road_hex, u, 8), 1)

	# Enemy FORT emits CoC doubling terrain step cost (Plains 2 -> 4), unless ignore_coc
	u.fond_terrain = -1
	var fort_hex: Vector2i = u.hex_position + Vector2i(2, 0)
	var coc_hex: Vector2i = u.hex_position + Vector2i(1, 0)
	map_state.set_terrain(coc_hex, MapStateScript.TerrainType.PLAINS)
	map_state.set_terrain(fort_hex, MapStateScript.TerrainType.FORT)
	map_state.set_fort_owner(fort_hex, 3)

	assert_eq(nav.get_hex_step_cost(map_state, u.hex_position, coc_hex, u, 8), 4, "CoC must double Plains 2 -> 4")
	u.ignore_coc = true
	assert_eq(nav.get_hex_step_cost(map_state, u.hex_position, coc_hex, u, 8), 2, "ignore_coc bypasses CoC penalty")


func test_zoc_stopping_start_in_zoc_withdrawal_and_pinning() -> void:
	var nav: Variant = _load_nav()
	if nav == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var mover: BattleUnit = _make_infantry(1, 1, 3, 5, 6) # 6 MP
	var enemy: BattleUnit = _make_infantry(2, 3, 5, 5, 6) # 2 hexes east
	map_state.place_unit(mover)
	map_state.place_unit(enemy)

	# Hex (4, 5) is adjacent to enemy at (5, 5) -> in active ZoC!
	var zoc_entry_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(4, 5))
	var beyond_zoc_hex: Vector2i = zoc_entry_hex + Vector2i(0, -1)
	var reachable: Dictionary = nav.get_reachable_hexes(map_state, mover)

	assert_has(reachable, zoc_entry_hex, "Unit can enter enemy ZoC tile")
	assert_eq(int(reachable[zoc_entry_hex]), 6, "Entering ZoC must consume all 6 remaining MP")

	# Verify Start-in-ZoC Withdrawal vs ZoC-to-ZoC Pinning:
	# Move unit so it starts its turn ALREADY inside enemy ZoC at (4, 5) with 6 MP
	map_state.move_unit(mover, zoc_entry_hex)
	mover.state.current_mp = 6

	var safe_west_1: Vector2i = zoc_entry_hex + Vector2i(-1, 0) # hex_distance to enemy = 2 (outside ZoC)
	var safe_west_2: Vector2i = zoc_entry_hex + Vector2i(-2, 0) # 2 steps west (4 MP total)
	# Adjacent tile (4, 4) in axial relative to enemy: enemy + (-1, 0) is zoc_entry_hex; enemy + (0, -1) is also in enemy ZoC AND adjacent to zoc_entry_hex!
	var other_zoc_hex: Vector2i = enemy.hex_position + Vector2i(0, -1)
	assert_eq(HexMathScript.hex_distance(zoc_entry_hex, other_zoc_hex), 1)

	var withdraw_reach: Dictionary = nav.get_reachable_hexes(map_state, mover)
	assert_eq(int(withdraw_reach[safe_west_1]), 2, "Withdrawing out of ZoC costs normal 2 MP")
	assert_eq(int(withdraw_reach[safe_west_2]), 4, "After withdrawing out of ZoC, unit can keep moving")
	assert_eq(int(withdraw_reach[other_zoc_hex]), 6, "ZoC-to-ZoC slide consumes all MP immediately")

	var behind_enemy: Vector2i = enemy.hex_position + Vector2i(1, -1)
	assert_does_not_have(withdraw_reach, behind_enemy, "Cannot slide around enemy via ZoC-to-ZoC in one turn")
	assert_true(beyond_zoc_hex != Vector2i(999, 999))


func test_ignore_zoc_devoid_zoc_and_chaos_enemy_zoc() -> void:
	var nav: Variant = _load_nav()
	if nav == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var scout: BattleUnit = _make_infantry(1, 1, 3, 5, 6)
	var enemy: BattleUnit = _make_infantry(2, 3, 5, 5, 6)
	map_state.place_unit(scout)
	map_state.place_unit(enemy)

	var zoc_hex: Vector2i = enemy.hex_position + Vector2i(-1, 0)
	var slip_past_hex: Vector2i = zoc_hex + Vector2i(1, -1) # total 2 Plains steps = 4 MP if ZoC ignored

	# 1. ignore_zoc bypasses ZoC completely
	scout.ignore_zoc = true
	var r_ignore: Dictionary = nav.get_reachable_hexes(map_state, scout)
	assert_eq(int(r_ignore[zoc_hex]), 2)
	assert_eq(int(r_ignore[slip_past_hex]), 4)
	scout.ignore_zoc = false

	# 2. Allied devoid_zoc adjacent to enemy suppresses enemy ZoC
	var elephant: BattleUnit = _make_infantry(3, 1, 6, 5, 6)
	elephant.hex_position = enemy.hex_position + Vector2i(1, 0)
	elephant.devoid_zoc = true
	map_state.place_unit(elephant)

	assert_false(nav.is_in_active_enemy_zoc(map_state, zoc_hex, 1), "Elephant devoid_zoc suppresses enemy ZoC")
	var r_devoid: Dictionary = nav.get_reachable_hexes(map_state, scout)
	assert_eq(int(r_devoid[zoc_hex]), 2)

	# If elephant itself falls into CHAOS, its devoid_zoc no longer suppresses enemy ZoC
	elephant.state.morale = UnitStateScript.MoraleLevel.CHAOS
	assert_true(nav.is_in_active_enemy_zoc(map_state, zoc_hex, 1), "CHAOS ally loses devoid_zoc suppression")

	# 3. If enemy falls into CHAOS, enemy emits no ZoC
	enemy.state.morale = UnitStateScript.MoraleLevel.CHAOS
	assert_false(nav.is_in_active_enemy_zoc(map_state, zoc_hex, 1), "CHAOS enemy emits no ZoC")


func test_pass_through_ally_but_cannot_stop_on_ally_or_pass_enemy() -> void:
	var nav: Variant = _load_nav()
	if nav == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var mover: BattleUnit = _make_infantry(1, 1, 2, 4, 6)
	var ally: BattleUnit = _make_infantry(2, 1, 3, 4, 6)
	map_state.place_unit(mover)
	map_state.place_unit(ally)

	var past_ally_hex: Vector2i = ally.hex_position + Vector2i(1, 0)
	var reachable: Dictionary = nav.get_reachable_hexes(map_state, mover)
	assert_does_not_have(reachable, ally.hex_position, "Cannot stop on allied unit's hex")
	assert_has(reachable, past_ally_hex, "Can pass through allied unit to empty hex beyond")
	assert_eq(int(reachable[past_ally_hex]), 4)

	var path_to_ally: Array[Vector2i] = nav.find_path(map_state, mover, ally.hex_position)
	assert_eq(path_to_ally.size(), 0, "find_path must reject occupied destination")

	var path_past: Array[Vector2i] = nav.find_path(map_state, mover, past_ally_hex)
	assert_eq(path_past.size(), 3, "Path includes start -> ally -> past_ally")
	assert_eq(path_past[0], mover.hex_position)
	assert_eq(path_past[2], past_ally_hex)


func test_los_blocking_elevated_vision_and_attackable_hexes() -> void:
	var nav: Variant = _load_nav()
	if nav == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var archer: BattleUnit = _make_infantry(1, 1, 2, 5, 6)
	archer.min_range = 1
	archer.max_range = 3
	map_state.place_unit(archer)

	var mid_hex: Vector2i = archer.hex_position + Vector2i(1, 0)
	var target_hex: Vector2i = archer.hex_position + Vector2i(2, 0)

	# Ground archer blocked by intermediate FOREST
	map_state.set_terrain(mid_hex, MapStateScript.TerrainType.FOREST)
	assert_false(nav.has_line_of_sight(map_state, archer.hex_position, target_hex), "Ground LOS blocked by Forest")

	var ground_atk: Array[Vector2i] = nav.get_attackable_hexes(map_state, archer, archer.hex_position)
	assert_does_not_have(ground_atk, target_hex, "Blocked LOS hex must NOT be in attackable red area")
	assert_has(ground_atk, mid_hex, "Adjacent forest itself at distance 1 is visible & attackable")

	# Put archer on HILLS -> sees over intermediate FOREST!
	map_state.set_terrain(archer.hex_position, MapStateScript.TerrainType.HILLS)
	assert_true(nav.has_line_of_sight(map_state, archer.hex_position, target_hex), "Hills observer sees over Forest")
	var hill_atk: Array[Vector2i] = nav.get_attackable_hexes(map_state, archer, archer.hex_position)
	assert_has(hill_atk, target_hex, "Hills archer can target beyond Forest")

	# Intermediate HILLS blocks Hills observer if target is on low ground, UNLESS target is also on HILLS
	map_state.set_terrain(mid_hex, MapStateScript.TerrainType.HILLS)
	assert_false(nav.has_line_of_sight(map_state, archer.hex_position, target_hex), "Mid Hills blocks low target")
	map_state.set_terrain(target_hex, MapStateScript.TerrainType.HILLS)
	assert_true(nav.has_line_of_sight(map_state, archer.hex_position, target_hex), "Peak-to-peak LOS allowed")


func test_30x30_pathfinding_stress_performance() -> void:
	var nav: Variant = _load_nav()
	if nav == null:
		return

	var map_state := MapStateScript.new(30, 30)
	for r: int in range(30):
		for c: int in range(30):
			if (c + r) % 5 == 0:
				map_state.set_terrain(HexMathScript.odd_r_to_axial(Vector2i(c, r)), MapStateScript.TerrainType.FOREST)
			elif (c + r) % 7 == 0:
				map_state.set_terrain(HexMathScript.odd_r_to_axial(Vector2i(c, r)), MapStateScript.TerrainType.ROAD_PORT)

	var cav: BattleUnit = _make_infantry(1, 1, 15, 15, 12)
	cav.command_branch = UnitScript.CommandBranch.CAVALRY
	map_state.place_unit(cav)

	var t0: int = Time.get_ticks_usec()
	var reachable: Dictionary = nav.get_reachable_hexes(map_state, cav)
	var target: Vector2i = cav.hex_position
	for k: Vector2i in reachable.keys():
		if HexMathScript.hex_distance(cav.hex_position, k) > HexMathScript.hex_distance(cav.hex_position, target):
			target = k
	var path: Array[Vector2i] = nav.find_path(map_state, cav, target)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	assert_gt(float(reachable.size()), 20.0, "12 MP cavalry on 30x30 reaches >20 hexes")
	assert_gt(float(path.size()), 2.0, "A* finds valid multi-step path")
	assert_lt(elapsed_ms, 15.0, "30x30 reachable + A* path must complete well under 1 frame (<15ms)")
