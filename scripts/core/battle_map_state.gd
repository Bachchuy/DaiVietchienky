class_name BattleMapState
extends RefCounted

enum TerrainType {
	PLAINS = 0,
	FOREST = 1,
	HILLS = 2,
	SWAMP = 3,
	SHALLOW_RIVER = 4,
	DEEP_WATER = 5,
	FORT = 6,
	ROAD_PORT = 7,
	STAKED_WATER = 8,
}

const IMPASSABLE_MP: int = 999999

var width: int = 12
var height: int = 10
var staked_water_owner_faction: int = 1

var _terrains: Dictionary[Vector2i, int] = {}
var _fort_owners: Dictionary[Vector2i, int] = {}
var _units_by_hex: Dictionary[Vector2i, BattleUnit] = {}
var _units_by_id: Dictionary[int, BattleUnit] = {}
var _faction_teams: Dictionary[int, int] = {
	1: 1, # Player (Dai Viet)
	2: 1, # Ally
	3: 2, # Enemy (Dai Nguyen)
	4: 0, # Neutral
}


func _init(map_width: int = 12, map_height: int = 10, default_terrain: TerrainType = TerrainType.PLAINS) -> void:
	width = maxi(1, map_width)
	height = maxi(1, map_height)
	for row: int in range(height):
		for col: int in range(width):
			var axial: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			_terrains[axial] = int(default_terrain)


func is_valid_hex(axial: Vector2i) -> bool:
	var offset: Vector2i = HexMath.axial_to_odd_r(axial)
	return offset.x >= 0 and offset.x < width and offset.y >= 0 and offset.y < height


func get_terrain(axial: Vector2i) -> TerrainType:
	return int(_terrains.get(axial, int(TerrainType.PLAINS))) as TerrainType


func set_terrain(axial: Vector2i, terrain: TerrainType) -> void:
	if is_valid_hex(axial):
		_terrains[axial] = int(terrain)


func set_fort_owner(axial: Vector2i, faction_id: int) -> void:
	if is_valid_hex(axial):
		_fort_owners[axial] = faction_id


func get_fort_owner(axial: Vector2i) -> int:
	return int(_fort_owners.get(axial, 0))


func set_faction_team(faction_id: int, team_id: int) -> void:
	_faction_teams[faction_id] = team_id


func is_allied(faction_a: int, faction_b: int) -> bool:
	if faction_a == faction_b:
		return true
	var team_a: int = int(_faction_teams.get(faction_a, faction_a))
	var team_b: int = int(_faction_teams.get(faction_b, faction_b))
	return team_a != 0 and team_a == team_b


func is_hostile(faction_a: int, faction_b: int) -> bool:
	if faction_a == faction_b:
		return false
	var team_a: int = int(_faction_teams.get(faction_a, faction_a))
	var team_b: int = int(_faction_teams.get(faction_b, faction_b))
	if team_a == 0 or team_b == 0:
		return false
	return team_a != team_b


func is_in_enemy_coc(axial: Vector2i, mover_faction: int) -> bool:
	for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
		var adj: Vector2i = axial + dir
		if not is_valid_hex(adj):
			continue
		if get_terrain(adj) != TerrainType.FORT:
			continue
		var owner_faction: int = get_fort_owner(adj)
		if owner_faction != 0 and is_hostile(mover_faction, owner_faction):
			return true
	return false


func place_unit(unit: BattleUnit) -> bool:
	if unit == null or not is_valid_hex(unit.hex_position):
		return false
	_units_by_hex[unit.hex_position] = unit
	_units_by_id[unit.unit_id] = unit
	return true


func move_unit(unit: BattleUnit, target_axial: Vector2i) -> bool:
	if unit == null or not is_valid_hex(target_axial):
		return false
	var existing: BattleUnit = get_unit_at(target_axial)
	if existing != null and existing != unit:
		return false
	_units_by_hex.erase(unit.hex_position)
	unit.hex_position = target_axial
	_units_by_hex[target_axial] = unit
	_units_by_id[unit.unit_id] = unit
	return true


func remove_unit(unit_id: int) -> void:
	if not _units_by_id.has(unit_id):
		return
	var unit: BattleUnit = _units_by_id[unit_id]
	if _units_by_hex.get(unit.hex_position) == unit:
		_units_by_hex.erase(unit.hex_position)
	_units_by_id.erase(unit_id)


func get_unit_at(axial: Vector2i) -> BattleUnit:
	var u: BattleUnit = _units_by_hex.get(axial, null)
	if u != null and not u.state.is_alive():
		return null
	return u


func get_all_units() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for uid: int in _units_by_id.keys():
		var u: BattleUnit = _units_by_id[uid]
		if u != null and u.state.is_alive():
			result.append(u)
	return result


func get_base_terrain_mp(terrain: TerrainType, unit: BattleUnit) -> int:
	if unit == null:
		return IMPASSABLE_MP

	var is_naval: bool = (unit.domain == BattleUnit.Domain.NAVAL)
	var is_cav_siege: bool = unit.is_cavalry_or_siege()
	var is_light_boat: bool = (unit.command_branch == BattleUnit.CommandBranch.NAVAL_LIGHT)

	match terrain:
		TerrainType.PLAINS:
			if is_naval:
				return IMPASSABLE_MP
			return 2
		TerrainType.FOREST:
			if is_naval:
				return IMPASSABLE_MP
			return 4 if is_cav_siege else 3
		TerrainType.HILLS:
			if is_naval:
				return IMPASSABLE_MP
			return 5 if is_cav_siege else 4
		TerrainType.SWAMP:
			if is_naval:
				return 4 if is_light_boat else IMPASSABLE_MP
			return 6 if is_cav_siege else 4
		TerrainType.SHALLOW_RIVER:
			if is_naval:
				return 2 if is_light_boat else 3
			return 5 if is_cav_siege else 4
		TerrainType.DEEP_WATER:
			if is_naval:
				return 2
			if unit.state.is_transported:
				return 3
			return IMPASSABLE_MP
		TerrainType.FORT:
			if is_naval:
				return IMPASSABLE_MP
			return 3 if is_cav_siege else 2
		TerrainType.ROAD_PORT:
			if is_naval:
				return 2
			return 1
		TerrainType.STAKED_WATER:
			if not is_naval:
				return IMPASSABLE_MP
			if is_allied(unit.faction_id, staked_water_owner_faction):
				return 2
			return 4
		_:
			return IMPASSABLE_MP


func get_terrain_def_mult(terrain: TerrainType, unit: BattleUnit = null) -> float:
	match terrain:
		TerrainType.PLAINS:
			return 1.00
		TerrainType.FOREST:
			return 1.20
		TerrainType.HILLS:
			return 1.15
		TerrainType.SWAMP:
			return 0.90
		TerrainType.SHALLOW_RIVER:
			if unit != null and unit.domain == BattleUnit.Domain.NAVAL:
				return 1.00
			return 0.90
		TerrainType.DEEP_WATER:
			if unit != null and unit.domain == BattleUnit.Domain.LAND and unit.state.is_transported:
				return 0.80
			return 1.00
		TerrainType.FORT:
			return 1.30
		TerrainType.ROAD_PORT:
			return 1.00
		TerrainType.STAKED_WATER:
			return 0.85
		_:
			return 1.00
