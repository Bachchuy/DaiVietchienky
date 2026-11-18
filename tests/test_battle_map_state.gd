extends "res://tests/test_case.gd"

const MAP_STATE_PATH: String = "res://scripts/core/battle_map_state.gd"
const UNIT_PATH: String = "res://scripts/core/battle_unit.gd"
const UNIT_STATE_PATH: String = "res://scripts/core/unit_combat_state.gd"
const LOADER_PATH: String = "res://scripts/core/static_data_loader.gd"
const HexMathScript = preload("res://scripts/core/hex_math.gd")


func _load_scripts() -> Dictionary:
	var map_s: GDScript = load(MAP_STATE_PATH) as GDScript
	var unit_s: GDScript = load(UNIT_PATH) as GDScript
	var state_s: GDScript = load(UNIT_STATE_PATH) as GDScript
	var loader_s: GDScript = load(LOADER_PATH) as GDScript
	assert_not_null(map_s, "BattleMapState script must exist")
	assert_not_null(unit_s, "BattleUnit script must exist")
	assert_not_null(state_s, "UnitCombatState script must exist")
	assert_not_null(loader_s, "StaticDataLoader script must exist")
	return {
		"map": map_s,
		"unit": unit_s,
		"state": state_s,
		"loader": loader_s,
	}


func test_map_bounds_12x10_and_30x30() -> void:
	var s: Dictionary = _load_scripts()
	if s["map"] == null:
		return

	var map_12x10: RefCounted = s["map"].new(12, 10)
	assert_eq(map_12x10.width, 12)
	assert_eq(map_12x10.height, 10)
	assert_true(map_12x10.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(0, 0))))
	assert_true(map_12x10.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(11, 9))))
	assert_true(map_12x10.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(2, 8))), "SignalDock (2,8) must be valid")
	assert_false(map_12x10.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(12, 0))))
	assert_false(map_12x10.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(-1, 5))))
	assert_false(map_12x10.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(3, 10))))

	var map_30x30: RefCounted = s["map"].new(30, 30)
	assert_true(map_30x30.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(29, 29))))
	assert_false(map_30x30.is_valid_hex(HexMathScript.odd_r_to_axial(Vector2i(30, 29))))


func test_nine_terrains_mp_costs_and_def_multipliers() -> void:
	var s: Dictionary = _load_scripts()
	if s["map"] == null or s["unit"] == null:
		return

	var map_s: GDScript = s["map"]
	var unit_s: GDScript = s["unit"]
	var map_state: RefCounted = map_s.new(12, 10)

	var inf: RefCounted = unit_s.new()
	inf.domain = unit_s.Domain.LAND
	inf.command_branch = unit_s.CommandBranch.INFANTRY
	inf.faction_id = 1

	var cav: RefCounted = unit_s.new()
	cav.domain = unit_s.Domain.LAND
	cav.command_branch = unit_s.CommandBranch.CAVALRY
	cav.faction_id = 1

	var light_boat: RefCounted = unit_s.new()
	light_boat.domain = unit_s.Domain.NAVAL
	light_boat.command_branch = unit_s.CommandBranch.NAVAL_LIGHT
	light_boat.faction_id = 1

	var enemy_ship: RefCounted = unit_s.new()
	enemy_ship.domain = unit_s.Domain.NAVAL
	enemy_ship.command_branch = unit_s.CommandBranch.NAVAL_HEAVY
	enemy_ship.faction_id = 3

	# 0: PLAINS -> Inf 2, Cav 2, Naval Impassable
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.PLAINS, inf), 2)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.PLAINS, cav), 2)
	assert_gte(map_state.get_base_terrain_mp(map_s.TerrainType.PLAINS, light_boat), map_s.IMPASSABLE_MP)

	# 1: FOREST -> Inf 3, Cav 4, DefMult 1.20
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.FOREST, inf), 3)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.FOREST, cav), 4)
	assert_almost_eq(map_state.get_terrain_def_mult(map_s.TerrainType.FOREST, inf), 1.20, 0.001)

	# 2: HILLS -> Inf 4, Cav 5, DefMult 1.15
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.HILLS, inf), 4)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.HILLS, cav), 5)
	assert_almost_eq(map_state.get_terrain_def_mult(map_s.TerrainType.HILLS, inf), 1.15, 0.001)

	# 3: SWAMP -> Inf 4, Cav 6, LightBoat 4, HeavyShip Impassable
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SWAMP, inf), 4)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SWAMP, cav), 6)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SWAMP, light_boat), 4)
	assert_gte(map_state.get_base_terrain_mp(map_s.TerrainType.SWAMP, enemy_ship), map_s.IMPASSABLE_MP)

	# 4: SHALLOW_RIVER -> Inf 4, Cav 5, LightBoat 2, HeavyShip 3
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SHALLOW_RIVER, inf), 4)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SHALLOW_RIVER, cav), 5)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SHALLOW_RIVER, light_boat), 2)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.SHALLOW_RIVER, enemy_ship), 3)

	# 5: DEEP_WATER -> Land Impassable unless transported (3 MP), Naval 2 MP
	assert_gte(map_state.get_base_terrain_mp(map_s.TerrainType.DEEP_WATER, inf), map_s.IMPASSABLE_MP)
	inf.state.is_transported = true
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.DEEP_WATER, inf), 3)
	inf.state.is_transported = false
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.DEEP_WATER, enemy_ship), 2)

	# 6: FORT -> Inf 2, Cav 3, DefMult 1.30
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.FORT, inf), 2)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.FORT, cav), 3)
	assert_almost_eq(map_state.get_terrain_def_mult(map_s.TerrainType.FORT, inf), 1.30, 0.001)

	# 7: ROAD_PORT -> Land 1, Naval 2
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.ROAD_PORT, inf), 1)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.ROAD_PORT, light_boat), 2)

	# 8: STAKED_WATER -> Ally Naval 2, Enemy Naval 4, Land Impassable
	map_state.staked_water_owner_faction = 1
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.STAKED_WATER, light_boat), 2)
	assert_eq(map_state.get_base_terrain_mp(map_s.TerrainType.STAKED_WATER, enemy_ship), 4)
	assert_gte(map_state.get_base_terrain_mp(map_s.TerrainType.STAKED_WATER, inf), map_s.IMPASSABLE_MP)


func test_fort_coc_and_unit_zoc_emission_state() -> void:
	var s: Dictionary = _load_scripts()
	if s["map"] == null or s["unit"] == null or s["state"] == null:
		return

	var map_s: GDScript = s["map"]
	var unit_s: GDScript = s["unit"]
	var state_s: GDScript = s["state"]
	var map_state: RefCounted = map_s.new(12, 10)

	var fort_hex: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(5, 5))
	map_state.set_terrain(fort_hex, map_s.TerrainType.FORT)
	map_state.set_fort_owner(fort_hex, 3) # Enemy faction 3 owns fort

	for nb: Vector2i in HexMathScript.get_neighbors(fort_hex):
		assert_true(map_state.is_in_enemy_coc(nb, 1), "Player faction 1 should feel enemy CoC around fort")
		assert_false(map_state.is_in_enemy_coc(nb, 3), "Owner faction 3 should not feel own CoC as enemy")

	var u: RefCounted = unit_s.new()
	u.unit_id = 101
	u.faction_id = 3
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(4, 4))
	map_state.place_unit(u)
	assert_eq(map_state.get_unit_at(u.hex_position), u)
	assert_true(u.state.emits_zoc(), "Healthy normal morale unit emits ZoC")

	u.state.morale = state_s.MoraleLevel.CHAOS
	assert_false(u.state.emits_zoc(), "CHAOS unit must NOT emit ZoC")


func test_static_troop_json_loading_is_clean_and_typed() -> void:
	var s: Dictionary = _load_scripts()
	if s["loader"] == null or s["unit"] == null:
		return

	var troops: Dictionary = s["loader"].load_troop_settings("res://data/settings/troop_settings.json")
	assert_gte(troops.size(), 5, "Should load canonical troop definitions")
	assert_has(troops, 40101, "Must include Dai Viet Spear Infantry (40101)")

	var spear_def: Dictionary = troops[40101]
	var unit: RefCounted = s["unit"].from_troop_dict(1, 1, Vector2i(0, 0), spear_def)
	assert_eq(unit.troop_id, 40101)
	assert_eq(unit.max_mp, 6)
	assert_eq(unit.state.current_mp, 6)
	assert_eq(unit.fond_terrain, 1, "Spear infantry fond_terrain should resolve to FOREST (1)")
