extends "res://tests/test_case.gd"

const RNG_PATH: String = "res://scripts/core/seeded_rng.gd"
const RESOLVER_PATH: String = "res://scripts/core/combat_resolver.gd"
const HexMathScript = preload("res://scripts/core/hex_math.gd")
const MapStateScript = preload("res://scripts/core/battle_map_state.gd")
const UnitScript = preload("res://scripts/core/battle_unit.gd")
const UnitStateScript = preload("res://scripts/core/unit_combat_state.gd")
const NavScript = preload("res://scripts/core/hex_grid_navigator.gd")


func _load_combat_scripts() -> Dictionary:
	var rng_s: GDScript = load(RNG_PATH) as GDScript
	var res_s: GDScript = load(RESOLVER_PATH) as GDScript
	assert_not_null(rng_s, "SeededRng script must exist at " + RNG_PATH)
	assert_not_null(res_s, "CombatResolver script must exist at " + RESOLVER_PATH)
	return {"rng": rng_s, "resolver": res_s}


func _make_unit(uid: int, faction: int, col: int, row: int) -> BattleUnit:
	var u := UnitScript.new()
	u.unit_id = uid
	u.faction_id = faction
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(col, row))
	u.max_mp = 6
	u.state.current_mp = 6
	u.state.max_hp = 160
	u.state.current_hp = 160
	return u


func test_seeded_rng_determinism_and_state_serialization() -> void:
	var s: Dictionary = _load_combat_scripts()
	if s["rng"] == null:
		return

	var rng_a: RefCounted = s["rng"].new(12880409)
	var rng_b: RefCounted = s["rng"].new(12880409)

	for _i: int in range(10):
		assert_almost_eq(
			float(rng_a.call("roll_float_range", 0.80, 1.00)),
			float(rng_b.call("roll_float_range", 0.80, 1.00)),
			0.000001
		)
		assert_eq(
			int(rng_a.call("roll_int_range", 1, 100)),
			int(rng_b.call("roll_int_range", 1, 100))
		)

	# Snapshot mid-stream state via Dictionary and verify restored generator matches 100%
	var snap: Dictionary = rng_a.call("to_dict")
	var rng_restored: RefCounted = s["rng"].new(1)
	rng_restored.call("from_dict", snap)

	for _j: int in range(25):
		assert_eq(
			int(rng_a.call("roll_int_range", 1, 10000)),
			int(rng_restored.call("roll_int_range", 1, 10000)),
			"Restored RNG state must produce identical roll stream"
		)


func test_armor_curve_round_half_up_troop_stack_and_matchup_matrix() -> void:
	var s: Dictionary = _load_combat_scripts()
	if s["resolver"] == null:
		return
	var res_s: GDScript = s["resolver"]

	assert_eq(int(res_s.round_half_up(12.5)), 13)
	assert_eq(int(res_s.round_half_up(12.49)), 12)

	# Def = 100 on NORMAL -> 100 / (100 + 100) = 0.50
	var eff_normal: float = res_s.compute_effective_def(100, 1.0, UnitStateScript.MoraleLevel.NORMAL)
	assert_almost_eq(res_s.compute_def_reduction(eff_normal), 0.50, 0.0001)

	# Def = 100 on LOW (-20% Def -> 80) -> 100 / 180 = 0.55555...
	var eff_low: float = res_s.compute_effective_def(100, 1.0, UnitStateScript.MoraleLevel.LOW)
	assert_almost_eq(eff_low, 80.0, 0.001)
	assert_almost_eq(res_s.compute_def_reduction(eff_low), 100.0 / 180.0, 0.0001)

	# Matchup matrix spot checks (GDD Section 4)
	assert_eq(int(res_s.get_matchup_percent(1, 2)), 120, "Melee vs Medium Armor = 120%")
	assert_eq(int(res_s.get_matchup_percent(2, 1)), 135, "Cavalry Charge vs Light Armor = 135%")
	assert_eq(int(res_s.get_matchup_percent(3, 5)), 35, "Archery vs Fort = 35%")
	assert_eq(int(res_s.get_matchup_percent(4, 5)), 150, "Siege vs Fort = 150%")
	assert_eq(int(res_s.get_matchup_percent(5, 5)), 130, "Naval vs Fort = 130%")

	# TroopStack No-Damage-Cliff check: 3-stack at 50% HP keeps M_stack = 2.20 and M_hp = 0.75
	var map_state := MapStateScript.new(12, 10)
	var nav := NavScript.new()
	var atk: BattleUnit = _make_unit(1, 1, 4, 4)
	atk.set("base_atk", 50)
	atk.set("max_stack", 3)
	atk.troop_stack = 3
	atk.state.max_hp = 480
	atk.state.current_hp = 240 # 50% HP -> M_hp = 0.75
	atk.set("attack_mode", 1)
	atk.set("defense_mode", 2)

	var def_u: BattleUnit = _make_unit(2, 3, 5, 4)
	def_u.set("base_def", 0)
	def_u.set("defense_mode", 3) # Melee(1) vs Heavy(3) = 100%
	map_state.place_unit(atk)
	map_state.place_unit(def_u)

	var resolver: RefCounted = res_s.new()
	var preview: Dictionary = resolver.call("preview_combat", map_state, nav, atk, def_u)
	# At roll 1.00: atk_rolled = 50 * 0.75 = 37.5; * M_stack(2.20) = 82.5 -> round_half_up = 83
	# At roll 0.80: atk_rolled = 40 * 0.75 = 30.0; * M_stack(2.20) = 66.0 -> 66
	assert_eq(int(preview["min_damage"]), 66)
	assert_eq(int(preview["max_damage"]), 83)


func test_flank_geometry_preview_immutability_and_crit_morale_drop() -> void:
	var s: Dictionary = _load_combat_scripts()
	if s["resolver"] == null or s["rng"] == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var nav := NavScript.new()
	var resolver: RefCounted = s["resolver"].new()
	var rng: RefCounted = s["rng"].new(99991)

	var target: BattleUnit = _make_unit(10, 3, 5, 5)
	var atk: BattleUnit = _make_unit(1, 1, 4, 5) # West of target
	var ally_60: BattleUnit = _make_unit(2, 1, 5, 4) # Adjacent to BOTH target AND atk (60 deg) -> NOT flank!
	map_state.place_unit(target)
	map_state.place_unit(atk)
	map_state.place_unit(ally_60)
	assert_eq(HexMathScript.hex_distance(atk.hex_position, ally_60.hex_position), 1)
	assert_false(bool(resolver.call("is_flank_attack", map_state, atk, target)), "60-deg adjacent ally must NOT trigger flank")

	# Move ally to opposite side (180 deg east of target) -> dist to atk == 2 -> FLANK!
	map_state.move_unit(ally_60, target.hex_position + Vector2i(1, 0))
	assert_true(bool(resolver.call("is_flank_attack", map_state, atk, target)), "180-deg opposite ally triggers flank")

	# Preview must NOT advance RNG state
	var rng_before: int = int(rng.call("get_state"))
	var preview: Dictionary = resolver.call("preview_combat", map_state, nav, atk, target)
	assert_eq(int(rng.call("get_state")), rng_before, "CombatPreview must never consume RNG")
	assert_true(bool(preview["is_flanked"]))

	# Force 100% crit via crit_rate_bonus = 100, verify 1.5x damage & morale drops from Flank + Crit
	atk.set("crit_rate_bonus", 100)
	target.state.morale = UnitStateScript.MoraleLevel.HIGH
	var report: Dictionary = resolver.call("resolve_attack", map_state, nav, atk, target, rng)
	assert_true(bool(report["is_crit"]))
	assert_true(bool(report["is_flanked"]))
	# HIGH (-1 flank, -1 crit) -> LOW!
	assert_eq(target.state.morale, UnitStateScript.MoraleLevel.LOW, "Flank + Crit drops HIGH by 2 tiers to LOW")


func test_retaliation_once_per_round_los_and_forest_ambush() -> void:
	var s: Dictionary = _load_combat_scripts()
	if s["resolver"] == null or s["rng"] == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var nav := NavScript.new()
	var resolver: RefCounted = s["resolver"].new()
	var rng: RefCounted = s["rng"].new(20261118)

	var defender: BattleUnit = _make_unit(10, 3, 5, 5)
	defender.state.max_hp = 500
	defender.state.current_hp = 500
	defender.set("counter_percent", 75)

	var atk1: BattleUnit = _make_unit(1, 1, 4, 5)
	atk1.set("crit_rate_bonus", -100) # Prevent random crit from dropping morale
	var atk2: BattleUnit = _make_unit(2, 1, 5, 4) # 60 deg so no flank either
	atk2.set("crit_rate_bonus", -100)
	map_state.place_unit(defender)
	map_state.place_unit(atk1)
	map_state.place_unit(atk2)

	var r1: Dictionary = resolver.call("resolve_attack", map_state, nav, atk1, defender, rng)
	assert_true(bool(r1["retaliated"]), "Defender retaliates against 1st attack in round")
	assert_gt(float(r1["counter_damage"]), 0.0)
	assert_lt(float(atk1.state.current_hp), 160.0)

	var r2: Dictionary = resolver.call("resolve_attack", map_state, nav, atk2, defender, rng)
	assert_false(bool(r2["retaliated"]), "Defender CANNOT retaliate a 2nd time in the same round")
	assert_eq(int(r2["counter_damage"]), 0)

	# Reset round retaliation flag, test Forest Ambush suppresses retaliation
	defender.state.on_faction_turn_start()
	atk1.ambush_forest = true
	map_state.set_terrain(atk1.hex_position, MapStateScript.TerrainType.FOREST)
	var r_ambush: Dictionary = resolver.call("resolve_attack", map_state, nav, atk1, defender, rng)
	assert_false(bool(r_ambush["retaliated"]), "Forest ambush attack must suppress retaliation")

	# Ranged LOS block prevents defender retaliation
	defender.min_range = 1
	defender.max_range = 2
	defender.state.on_faction_turn_start()
	var hill_archer: BattleUnit = _make_unit(3, 1, 3, 5) # 2 hexes away, standing on HILLS shooting over FOREST at (4,5)!
	hill_archer.min_range = 1
	hill_archer.max_range = 2
	map_state.remove_unit(atk1.unit_id)
	map_state.set_terrain(HexMathScript.odd_r_to_axial(Vector2i(4, 5)), MapStateScript.TerrainType.FOREST)
	map_state.set_terrain(hill_archer.hex_position, MapStateScript.TerrainType.HILLS)
	# Wait: target on HILLS lets ground defender see peak, so put hill_archer on FORT!
	# Remember hex_grid_pathfinding.md: observer on FORT sees over FOREST, while ground defender at (5,5) is blocked by FOREST at (4,5)!
	map_state.set_terrain(hill_archer.hex_position, MapStateScript.TerrainType.FORT)
	map_state.place_unit(hill_archer)
	var r_los: Dictionary = resolver.call("resolve_attack", map_state, nav, hill_archer, defender, rng)
	assert_gt(float(r_los["damage"]), 0.0)
	assert_false(bool(r_los["retaliated"]), "Ground defender blocked by Forest LOS cannot retaliate against Fort archer")
