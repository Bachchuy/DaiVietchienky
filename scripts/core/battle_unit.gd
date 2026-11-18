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
var facing: int = 0
var domain: Domain = Domain.LAND
var command_branch: CommandBranch = CommandBranch.INFANTRY

# Combat & mobility attributes (GDD combat_formulas.md Section 1)
var base_hp: int = 160
var max_stack: int = 1
var troop_stack: int = 1
var base_atk: int = 40
var damage_roll_min: int = 80
var damage_roll_max: int = 100
var attack_mode: int = 1
var base_def: int = 10
var defense_mode: int = 2
var max_mp: int = 6
var vision_range: int = 3
var min_range: int = 1
var max_range: int = 1

# Crit, counter & modifiers
var base_crit: int = 5
var crit_rate_bonus: int = 0
var crit_damage_bonus: int = 0
var counter_percent: int = 75
var damage_deepen: int = 0
var damage_resist: int = 0

# Commander & aura attributes
var is_commander_in_chief: bool = false
var general_command_stat: int = 0
var general_luck: int = 0
var m_command: float = 1.00
var aura_radius_hex: int = 0
var aura_damage_deepen: int = 0
var aura_damage_resist: int = 0
var grants_dead_mate_immunity: bool = false

# Spatial & terrain traits
var fond_terrain: int = -1
var ignore_zoc: bool = false
var ignore_coc: bool = false
var devoid_zoc: bool = false
var ambush_forest: bool = false
var no_retaliation: bool = false

var state: UnitCombatState = UnitCombatState.new()


func is_cavalry_or_siege() -> bool:
	return command_branch == CommandBranch.CAVALRY or command_branch == CommandBranch.SIEGE


func get_effective_stack() -> int:
	return clampi(maxi(max_stack, troop_stack), 1, 3)


func get_active_banners() -> int:
	if not state.is_alive():
		return 0
	var s_max: int = get_effective_stack()
	var hp_ratio: float = clampf(float(state.current_hp) / maxf(1.0, float(state.max_hp)), 0.0, 1.0)
	return clampi(ceili(hp_ratio * float(s_max)), 1, s_max)


static func parse_domain(raw: String) -> Domain:
	if raw.to_lower() == "naval":
		return Domain.NAVAL
	return Domain.LAND


static func parse_branch(raw: String) -> CommandBranch:
	match raw.to_lower():
		"infantry":
			return CommandBranch.INFANTRY
		"archer", "archery", "ranged":
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


static func parse_attack_mode(raw: Variant, branch: CommandBranch) -> int:
	if raw is int or raw is float:
		return clampi(int(raw), 1, 6)
	var s: String = str(raw).strip_edges().to_lower()
	match s:
		"1", "melee", "piercing":
			return 1
		"2", "charge", "slashing", "blunt":
			return 2 if branch == CommandBranch.CAVALRY else 1
		"3", "ranged", "archery":
			return 5 if (branch == CommandBranch.NAVAL_LIGHT or branch == CommandBranch.NAVAL_HEAVY) else 3
		"4", "siege", "cannon":
			return 4
		"5", "naval":
			return 5
		"6", "fire":
			return 6
		_:
			match branch:
				CommandBranch.CAVALRY:
					return 2
				CommandBranch.ARCHER:
					return 3
				CommandBranch.SIEGE:
					return 4
				CommandBranch.NAVAL_LIGHT, CommandBranch.NAVAL_HEAVY:
					return 5
				_:
					return 1


static func parse_defense_mode(raw: Variant) -> int:
	if raw is int or raw is float:
		return clampi(int(raw), 1, 5)
	match str(raw).strip_edges().to_lower():
		"1", "light", "lightarmor", "light_armor":
			return 1
		"2", "medium", "mediumarmor", "medium_armor":
			return 2
		"3", "heavy", "heavyarmor", "heavy_armor":
			return 3
		"4", "beast", "elephant":
			return 4
		"5", "fort", "building":
			return 5
		_:
			return 2


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
	unit.attack_mode = parse_attack_mode(def.get("attack_mode", ""), unit.command_branch)
	unit.defense_mode = parse_defense_mode(def.get("defense_mode", "MediumArmor"))

	unit.base_atk = int(def.get("base_atk", def.get("max_attack", 40)))
	unit.damage_roll_min = int(def.get("damage_roll_min", 80))
	unit.damage_roll_max = int(def.get("damage_roll_max", 100))
	unit.base_def = int(def.get("base_def", def.get("defence", 10)))
	unit.base_crit = int(def.get("critical_percent", def.get("base_crit", 5)))
	unit.counter_percent = int(def.get("counter_percent", 75))
	unit.damage_deepen = int(def.get("damage_deepen", 0))
	unit.damage_resist = int(def.get("damage_resist", 0))

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
			elif f_str == "elephant":
				unit.defense_mode = 4

	unit.base_hp = int(def.get("strength", 160))
	unit.max_stack = 1
	unit.troop_stack = 1
	unit.state.max_hp = unit.base_hp
	unit.state.current_hp = unit.base_hp
	unit.state.current_mp = unit.max_mp
	return unit
