class_name BattleUnit
extends RefCounted

enum Domain {
	LAND = 0,
	NAVAL = 1,
}

enum CommandBranch {
	INFANTRY = 0,
	ARCHER = 1,
	CAVALRY = 2,
	SIEGE = 3,
	NAVAL_LIGHT = 4,
	NAVAL_HEAVY = 5,
}

var unit_id: int = 0
var troop_id: int = 0
var general_id: int = 0
var code: String = ""
var display_name: String = ""
var general_name: String = ""
var faction_id: int = 1
var hex_position: Vector2i = Vector2i.ZERO
var domain: Domain = Domain.LAND
var command_branch: CommandBranch = CommandBranch.INFANTRY
var max_mp: int = 6
var vision_range: int = 3
var min_range: int = 1
var max_range: int = 1
var fond_terrain: int = -1
var ignore_zoc: bool = false
var ignore_coc: bool = false
var devoid_zoc: bool = false
var ambush_forest: bool = false
var troop_stack: int = 1
var state: UnitCombatState = UnitCombatState.new()


func is_cavalry_or_siege() -> bool:
	return command_branch == CommandBranch.CAVALRY or command_branch == CommandBranch.SIEGE


static func parse_domain(raw: String) -> Domain:
	if raw.to_lower() == "naval":
		return Domain.NAVAL
	return Domain.LAND


static func parse_branch(raw: String) -> CommandBranch:
	match raw.to_lower():
		"infantry":
			return CommandBranch.INFANTRY
		"archer", "ranged":
			return CommandBranch.ARCHER
		"cavalry":
			return CommandBranch.CAVALRY
		"siege":
			return CommandBranch.SIEGE
		"navallight", "naval_light":
			return CommandBranch.NAVAL_LIGHT
		"navalheavy", "naval_heavy", "naval":
			return CommandBranch.NAVAL_HEAVY
		_:
			return CommandBranch.INFANTRY


static func parse_terrain_name(raw: String) -> int:
	match raw.strip_edges().to_lower():
		"plains":
			return 0
		"forest":
			return 1
		"hills":
			return 2
		"swamp":
			return 3
		"shallowriver", "shallow_river":
			return 4
		"deepwater", "deep_water":
			return 5
		"fort":
			return 6
		"roadport", "road_port":
			return 7
		"stakedwater", "staked_water":
			return 8
		_:
			return -1


static func from_troop_dict(
	uid: int,
	faction: int,
	axial_pos: Vector2i,
	def: Dictionary
) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_id = uid
	unit.troop_id = int(def.get("id", 0))
	unit.code = str(def.get("code", ""))
	unit.display_name = str(def.get("name", unit.code))
	unit.faction_id = faction
	unit.hex_position = axial_pos
	unit.domain = parse_domain(str(def.get("domain", "Land")))
	unit.command_branch = parse_branch(str(def.get("command_branch", "Infantry")))
	unit.max_mp = int(def.get("mobility", 6))
	unit.vision_range = int(def.get("vision_range", 3))
	unit.min_range = int(def.get("min_range", 1))
	unit.max_range = int(def.get("max_range", 1))
	unit.fond_terrain = parse_terrain_name(str(def.get("fond_terrain", "")))
	unit.ignore_zoc = bool(def.get("ignore_zoc", false))
	unit.ignore_coc = bool(def.get("ignore_coc", false))
	unit.devoid_zoc = bool(def.get("devoid_zoc", false))

	var features: Variant = def.get("features", [])
	if features is Array:
		for feat: Variant in features:
			var f_str: String = str(feat)
			if f_str == "forest_ambush" or f_str == "ambush_forest":
				unit.ambush_forest = true
			elif f_str == "ignore_zoc":
				unit.ignore_zoc = true
			elif f_str == "ignore_coc":
				unit.ignore_coc = true
			elif f_str == "devoid_zoc":
				unit.devoid_zoc = true

	var base_hp: int = int(def.get("strength", 160))
	unit.state.max_hp = base_hp
	unit.state.current_hp = base_hp
	unit.state.current_mp = unit.max_mp
	return unit
